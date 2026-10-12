// =====================================================================
// Edge Function: khqr-webhook
// Confirms a KHQR.dev payment: verifies the HMAC signature, marks the
// invoice paid, and extends the school's subscription.
// Adapted from docs/khqrdev_payment_implementation.md (tenant = schools).
//
// Deploy with --no-verify-jwt (authentication is the HMAC signature).
// Secrets: KHQRDEV_WEBHOOK_SECRET (env) + SUPABASE_SERVICE_ROLE_KEY.
// =====================================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

  // 1. Raw body FIRST (before any JSON parse — HMAC is over raw bytes)
  const bodyBytes = new Uint8Array(await req.arrayBuffer())

  const serviceClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // 2. Webhook secret from env (+ pricing config for the amount check)
  const { data: settings } = await serviceClient
    .from('platform_settings')
    .select('app_config')
    .eq('id', true)
    .single()

  const secret = Deno.env.get('KHQRDEV_WEBHOOK_SECRET')
  if (!secret) {
    console.error('Webhook secret not configured')
    // 200 so KHQR.dev does NOT retry a config problem
    return json({ ok: false, reason: 'webhook_secret_not_configured' }, 200)
  }

  // 3. Replay window (X-RBK-Delivery is unix ms)
  const delivery = Number(req.headers.get('x-rbk-delivery'))
  if (!Number.isFinite(delivery) || Math.abs(Date.now() - delivery) > 300_000) {
    return json({ ok: false, reason: 'expired_timestamp' }, 400)
  }

  // 4. HMAC-SHA256, constant-time compare
  const signature = (req.headers.get('x-rbk-signature') ?? '').toLowerCase()
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  )
  const sig = await crypto.subtle.sign('HMAC', key, bodyBytes)
  const expected = Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, '0')).join('')

  const a = new TextEncoder().encode(signature)
  const b = new TextEncoder().encode(expected)
  let diff = a.length ^ b.length
  for (let i = 0; i < a.length && i < b.length; i++) diff |= a[i] ^ b[i]
  if (diff !== 0) return json({ ok: false, reason: 'invalid_signature' }, 400)

  // 5. Parse only after signature verified
  let payload: {
    event: string
    data: { md5?: string; tran_id?: string; paid_at?: string; amount?: number }
  }
  try {
    payload = JSON.parse(new TextDecoder().decode(bodyBytes))
  } catch {
    return json({ ok: false, reason: 'invalid_json' }, 400)
  }

  const { event, data } = payload
  if (event !== 'payment.success') return json({ ok: true, result: 'ignored' }, 200)

  const { md5 } = data
  if (!md5) return json({ ok: false, reason: 'missing_md5' }, 400)

  // 6. Find the invoice
  const { data: invoice } = await serviceClient
    .from('subscription_invoices')
    .select('id, school_id, plan_id, period_end, status, total_amount')
    .eq('khqrdev_md5', md5)
    .single()

  if (!invoice) return json({ ok: true, result: 'unknown_invoice' }, 200)

  // 7. Amount verification (same price source as khqr-payment)
  const cfg = settings?.app_config || {}
  const override =
    invoice.plan_id === 'pro' ? cfg.pro_price_manual
    : invoice.plan_id === 'basic' ? cfg.basic_price_manual
    : null

  let expectedFee: number
  if (override !== undefined && override !== null && override !== '') {
    expectedFee = Number(override)
  } else {
    const { data: plan } = await serviceClient
      .from('plans').select('monthly_fee').eq('id', invoice.plan_id).single()
    expectedFee = plan?.monthly_fee != null ? Number(plan.monthly_fee) : 30
  }

  const invoiceAmount = Number(invoice.total_amount)
  if (!cfg.sandbox_mode && invoiceAmount < expectedFee) {
    console.error(`Underbilling: invoice ${invoiceAmount} < configured ${expectedFee}`)
    return json({ ok: false, reason: 'amount_mismatch' }, 400)
  }
  if (data.amount !== undefined && Number(data.amount) < invoiceAmount) {
    return json({ ok: false, reason: 'underpaid' }, 400)
  }

  // 8. Idempotency — never reprocess a paid invoice
  if (invoice.status === 'paid') return json({ ok: true, result: 'duplicate' }, 200)

  // 9. Mark paid
  const { error: invErr } = await serviceClient
    .from('subscription_invoices')
    .update({
      status: 'paid',
      paid_at: data.paid_at ? new Date(data.paid_at).toISOString() : new Date().toISOString(),
      khqrdev_tran_id: data.tran_id || invoice.id,
    })
    .eq('id', invoice.id)

  if (invErr) {
    console.error('Failed to update invoice:', invErr)
    return json({ ok: false, reason: 'db_error' }, 500) // 500 → KHQR.dev retries
  }

  // 10. Activate / renew the school (paid through period_end)
  const { error: accErr } = await serviceClient
    .from('schools')
    .update({
      plan: invoice.plan_id,
      plan_expires_at: invoice.period_end,
      grace_period_ends_at: null,
    })
    .eq('id', invoice.school_id)

  if (accErr) {
    console.error('Failed to update school:', accErr)
    return json({ ok: false, reason: 'school_update_failed' }, 500)
  }

  console.log(`Payment confirmed: invoice ${invoice.id}, school ${invoice.school_id}`)
  return json({ ok: true, result: 'paid', invoice_id: invoice.id }, 200)
})

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
