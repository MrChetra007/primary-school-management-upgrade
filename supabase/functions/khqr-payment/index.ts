// =====================================================================
// Edge Function: khqr-payment
// Creates a KHQR.dev payment QR for a school subscription invoice.
// Adapted from docs/khqrdev_payment_implementation.md (tenant = schools).
//
// Auth: Supabase JWT (caller must be admin of the school or super_admin).
// Reads:  KHQRDEV_TOKEN (env), plans / platform_settings (service role).
// Writes: subscription_invoices (status = pending).
// =====================================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// KHQR.dev rate limit: 1 req/s for generate_qr. Reuse an unexpired invoice's
// khqrdev_md5 instead of creating a fresh QR every page load.
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } },
    )
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data: { user }, error: userError } = await authClient.auth.getUser()
    if (userError || !user) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const { data: caller } = await serviceClient
      .from('users')
      .select('role, school_id')
      .eq('id', user.id)
      .single()

    const { school_id, plan_id, period_start, period_end, force_new } = await req.json()
    if (!school_id || !plan_id || !period_start || !period_end) {
      return json({ error: 'Missing required fields' }, 400)
    }
    if (caller?.role !== 'super_admin' && caller?.school_id !== school_id) {
      return json({ error: 'Forbidden' }, 403)
    }

    // ── Credentials from env ──────────────────────────────────────────
    const khqrdevToken = Deno.env.get('KHQRDEV_TOKEN')
    if (!khqrdevToken) return json({ error: 'KHQR.dev token not configured' }, 500)

    // ── Pricing: app_config override first, then plans fallback ───────
    const { data: settings } = await serviceClient
      .from('platform_settings')
      .select('currency, app_config')
      .eq('id', true)
      .single()

    const cfg = settings?.app_config || {}
    const override =
      plan_id === 'pro' ? cfg.pro_price_manual
      : plan_id === 'basic' ? cfg.basic_price_manual
      : null

    let monthlyFee: number
    if (override !== undefined && override !== null && override !== '') {
      monthlyFee = Number(override)
    } else {
      const { data: plan } = await serviceClient
        .from('plans').select('monthly_fee').eq('id', plan_id).single()
      if (!plan) return json({ error: 'Plan not found' }, 400)
      monthlyFee = Number(plan.monthly_fee)
    }

    if (cfg.sandbox_mode === true && cfg.sandbox_amount) {
      monthlyFee = Number(cfg.sandbox_amount)
    }

    const totalAmount = parseFloat(monthlyFee.toFixed(2))

    // ── Reuse an existing unexpired pending invoice for this school ───
    const { data: existing } = await serviceClient
      .from('subscription_invoices')
      .select('*')
      .eq('school_id', school_id)
      .in('status', ['pending'])
      .order('created_at', { ascending: false })
      .limit(1)

    if (existing?.length) {
      const inv = existing[0]
      const elapsedMs = Date.now() - new Date(inv.created_at).getTime()
      const isExpired = elapsedMs >= 9.5 * 60 * 1000 // QR lives ~10 min
      const amountMismatch = Math.abs(Number(inv.total_amount) - totalAmount) > 0.001
      const planMismatch = inv.plan_id !== plan_id

      if (force_new || isExpired || amountMismatch || planMismatch) {
        await serviceClient
          .from('subscription_invoices')
          .update({ status: 'expired' })
          .eq('id', inv.id)
      } else if (inv.khqrdev_md5) {
        return json({
          invoice: inv,
          md5: inv.khqrdev_md5,
          checkout_url: inv.khqrdev_checkout_url,
          qr_image_url: `https://api.khqr.dev/v1/generate_khqr_image/${inv.khqrdev_md5}`,
          remaining_seconds: Math.max(10, Math.floor((10 * 60 * 1000 - elapsedMs) / 1000)),
          amount: totalAmount,
          deduped: true,
        }, 200)
      }
    }

    // ── Create QR via KHQR.dev ────────────────────────────────────────
    const qrRes = await fetch('https://api.khqr.dev/v1/generate_qr', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${khqrdevToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ amount: totalAmount }),
      signal: AbortSignal.timeout(8000),
    })

    if (qrRes.status === 429) return json({ error: 'Rate limited. Retry shortly.' }, 429)
    if (!qrRes.ok) {
      const errBody = await qrRes.text().catch(() => 'unknown error')
      return json({ error: `KHQR.dev error: ${errBody}` }, 502)
    }

    const qrJson = await qrRes.json()
    const { md5, tran_id, checkout_url } = (qrJson.data || qrJson) as {
      md5: string; tran_id: string; checkout_url: string
    }
    if (!md5) return json({ error: 'KHQR.dev did not return a valid md5' }, 502)

    const { data: invoice, error: invoiceError } = await serviceClient
      .from('subscription_invoices')
      .insert({
        school_id, plan_id, period_start, period_end,
        base_fee: monthlyFee, total_amount: totalAmount,
        currency: settings?.currency || 'USD',
        khqrdev_md5: md5, khqrdev_tran_id: tran_id,
        khqrdev_checkout_url: checkout_url,
        status: 'pending',
      })
      .select()
      .single()

    if (invoiceError) return json({ error: invoiceError.message }, 500)

    return json({
      invoice, md5, checkout_url,
      qr_image_url: `https://api.khqr.dev/v1/generate_khqr_image/${md5}`,
    }, 200)
  } catch (err) {
    console.error('Unexpected error:', err)
    return json({ error: 'Internal server error' }, 500)
  }
})

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
