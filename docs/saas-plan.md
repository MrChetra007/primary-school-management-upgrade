# SaaS School Management — Plan

Turning the multi-tenant Primary School Management System into a paid SaaS
with two plans, KHQR.dev subscription billing, and a full student-fee module.

**Status:** planning / Phase 1 (schema) started
**Migration:** `database/migrations/migration_v12_saas.sql`
**Billing reference:** `docs/khqrdev_payment_implementation.md`
**Adapted from:** `D:\SAAS\my-saas\` (`002_khqr_billing.sql`, `003_khqr_proof_flow.sql`, `004_khqrdev_payment.sql`)

---

## 1. Plans

| | **Basic — $30/mo** | **Pro — $50/mo** |
|---|---|---|
| Students | up to **200** active (current academic year) | **unlimited** |
| Students, attendance, scores, reports | ✅ | ✅ |
| Parent report links | ✅ | ✅ |
| Approval flow | ✅ | ✅ |
| Student fees (fee collection) | ✅ | ✅ |
| Library (books, borrows) | ❌ | ✅ |
| Budget | ❌ | ✅ |
| Inventory | ❌ | ✅ |
| Honor board | ❌ | ✅ |
| Certificates | ❌ | ✅ |

There is **no free trial**. A school is created but remains blocked until its
first subscription payment succeeds.

Plan limits and feature flags live in the `plans` table (`max_students`,
`features jsonb`) so they can be tuned without a redeploy.

---

## 2. Confirmed decisions

| Decision | Choice |
|---|---|
| Plan split | Basic $30 ≤200 students; Pro $50 unlimited + pro modules |
| Subscription billing | **KHQR.dev** automated flow (not ABA PayWay) |
| Trial | **None** — must pay before use |
| Expiry warning | Flag/banner shown **7 days before** plan end |
| Fees module | **Full** — structures → invoices → payments → reports |
| Approval flow | Included in **Basic** (report links publish via approval) |
| Enforcement | **Hard block** (DB + UI) |
| Student cap basis | **Current-year active** students (graduated/historical excluded) |

### Assumptions (adjust if wrong)
- **Unpaid new school (no trial):** the admin is created, lands on the
  Billing page, and every other write/read is blocked by `school_active()`
  until the first payment. (Option A from planning.)
- **Student-fee collection:** staff-recorded payments (cash / bank / KHQR
  reference / Wing). Parents do **not** self-pay online yet. Each school
  would need its own KHQR merchant account to accept online fee payments —
  deferred to a later phase.
- **Currency:** subscription is **USD**; school fees default to **KHR**
  (each `fee_structure` carries its own `currency`).
- **Grace period:** optional `grace_period_ends_at` column exists but is
  `null` by default (no automatic grace).

---

## 3. Data model — `migration_v12_saas.sql`

New tables:
- **`platform_settings`** — single row (boolean PK): `currency`, `app_config`
  (editable prices + `sandbox_mode`), merchant info.
- **`plans`** — `id ('basic'|'pro')`, `display_name`, `monthly_fee`,
  `max_students`, `features jsonb`, `is_active`.
- **`subscription_invoices`** — one row per billing cycle: `school_id`,
  `plan_id`, period, `total_amount` (server-computed),
  `khqrdev_md5` / `khqrdev_tran_id` / `khqrdev_checkout_url`,
  `status ('pending','paid','expired','void')`, `paid_at`.
- **`fee_structures`** — the billing rule per class (cycle, amount, due day).
- **`student_fees`** — one invoice row per student per period; unique per
  `(student_id, fee_structure_id, month, semester)`.
- **`fee_payments`** — money received; a trigger keeps
  `student_fees.amount_paid` and `status` in sync.

Changed table:
- **`schools`** += `plan`, `plan_expires_at`, `grace_period_ends_at`,
  `billing_type`.

Helper functions & enforcement:
- **`school_active()`** — paid-up subscription check.
- **`has_feature(text)`** — `school_active()` + plan feature flag.
- **`enforce_student_plan_limit()`** — BEFORE INSERT trigger on `students`;
  blocks the 201st current-year student on Basic.
- RLS: new tables gated by `school_active()` / `has_feature('fees')`; all
  core `"<table>: admin manage own school"` policies recreated with
  `school_active()` (hard block when unpaid/expired); `books`, `book_borrows`,
  `budget_transactions`, `inventory_items` gated by their pro feature.

---

## 4. Billing flow (KHQR.dev)

Adapted from `docs/khqrdev_payment_implementation.md`, tenant = `schools`:

```
Admin ─► khqr-payment (JWT edge fn) ─► generate_qr ─► KHQR.dev
              │
              └─ insert subscription_invoices(status=pending, khqrdev_md5)
   render QR (api.khqr.dev/v1/generate_khqr_image/<md5>) + poll invoice.status

Customer pays in bank app ─► KHQR.dev ─signed webhook─► khqr-webhook
   verify HMAC + replay window + amount + idempotency
   → invoice 'paid' → schools.plan_expires_at = period_end + 30 days
```

Edge functions to add under `supabase/functions/`:
- `khqr-payment` — verifies the caller belongs to the school (or is super
  admin), computes the fee server-side from `plans`/`app_config`, reuses an
  unexpired pending QR (KHQR.dev is 1 req/s, QR lives ~10 min).
- `khqr-webhook` — deploy with `--no-verify-jwt`; HMAC-SHA256 over the raw
  body (`X-RBK-Signature`), `X-RBK-Delivery` (ms) 5-min replay window,
  idempotent, then extends `plan_expires_at`.

Secrets (Supabase Edge secrets only — never in DB/bundle/git):
```bash
supabase secrets set KHQRDEV_TOKEN=RBK_xxxx
supabase secrets set KHQRDEV_WEBHOOK_SECRET=xxxx
```
Register the webhook URL in the KHQR.dev dashboard:
`https://<project-ref>.supabase.co/functions/v1/khqr-webhook`

---

## 5. Frontend work

- **Plan store** (`src/stores/plan.js`): `plan`, `planExpiresAt`, `daysLeft`,
  `hasFeature(f)`, `studentCap`, getters `expiringSoon` (≤7 days) and
  `isActive`. Loaded during auth init.
- **Billing view** (`/admin/billing`): current plan, expiry countdown,
  invoice history, **Renew / Upgrade → KHQR modal**. Route placed **outside**
  the academic-year guard (like `/admin/academic-years`) so unpaid schools can
  reach it.
- **KHQR payment modal**: invoke `khqr-payment`, render `qr_image_url`,
  countdown from `remaining_seconds`, poll the invoice row every ~3s.
- **Expiry banner** in `AdminLayout.vue`: warning when ≤7 days left; hard
  block/redirect to Billing after expiry.
- **Nav & route gating**: filter `AdminLayout` / `TeacherLayout` /
  `LibrarianLayout` nav by `hasFeature`; add `meta.feature` to pro routes;
  blocked feature → Upgrade modal/pricing page.
- **Public `/pricing`** page with the two cards (wire to the existing
  `docs/landingpage.md` "Pricing" spec) → subscribe.
- **Super admin**: SchoolsList shows plan + expiry + student-vs-cap;
  platform-settings card to edit prices/`sandbox_mode`; per-school invoices.
- **Fees module** (Basic): `/admin/fees` collection grid, `/admin/fees/structures`,
  `/admin/fees/payments` (receipts), `/admin/fees/reports`.

---

## 6. Build order

1. **Phase 1 — Schema** ✅ `migration_v12_saas.sql` (this deliverable)
2. **Phase 2 — KHQR billing** — edge functions + secrets + webhook; plan
   store; billing view + KHQR modal; expiry banner; super-admin billing
3. **Phase 3 — Feature gating** — nav/route gating, upgrade modal, pricing
   page, onboarding (no-trial pay-first)
4. **Phase 4 — Fees module UI** — structures, collection, payments/receipts,
   reports
5. **Phase 5 (later)** — per-school KHQR for student fees; optional
   auto-post of collected fees into `budget_transactions`

---

## 7. Open items / follow-ups

- No-trial gap behavior (assumed Option A): confirm admin lands on Billing.
- Student-fee online payment (per-school KHQR) — deferred.
- Grace period length after expiry — currently none (null).
- Apply `migration_v12_saas.sql` to a staging Supabase project and run its
  verification queries before production.
