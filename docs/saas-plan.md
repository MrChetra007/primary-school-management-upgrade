# SaaS School Management — Plan & Progress

Turn the multi-tenant, Primary-focused school system into a paid SaaS for
small Cambodian private schools (primary / English / computer / private),
with KHQR.dev subscription billing and a full student-fee module.

**Status:** Most SaaS + billing + feature-gating shipped. Dynamic school
structure (types, scoring modes, enrollment cap) implemented DB-side. Fee
module v1 shipped; Phase 3 extras (cashier, proration, receipts) remain.

**Live spec for how we work:** `docs/prompts/dynamic_fee_classname.md`
(one phase at a time · new migration files only · never edit old migrations
· money math in SQL · every new table = `school_id` + RLS · SQL tests per
phase · **ask before any data migration** · configuration over code).

**Billing reference:** `docs/khqrdev_payment_implementation.md`
**Adapted from:** `D:\SAAS\my-saas\` (`002_khqr_billing.sql`,
`003_khqr_proof_flow.sql`, `004_khqrdev_payment.sql`)

---

## 0. Migration index (keep this current)

| # | File | What it does | Status |
|---|---|---|---|
| v12 | `database/migrations/migration_v12_saas.sql` | SaaS foundation: `platform_settings`, `plans`, `subscription_invoices`, `schools` billing cols (`plan`, `plan_expires_at`, `grace_period_ends_at`, `billing_type`), fee tables (`fee_structures`, `student_fees`, `fee_payments` + `sync_student_fee_paid` trigger), `school_active()`, `has_feature()`, v1 student cap trigger, RLS re-gate | ✅ Applied |
| v12.1 | `.../migration_v12_1_grandfather_existing_schools.sql` | One-time: every pre-existing school with `plan_expires_at = null` → `now() + 12 months` (12-month grandfather window; ran 2026-10-12) | ✅ Applied |
| v12.2 | `.../migration_v12_2_block_staff_when_inactive.sql` | Paywall hardening: teacher/librarian reads on library tables gated by `school_active()` + `has_feature('library')` | ✅ Applied |
| v13 | `.../migration_v13_dynamic_structure.sql` | Phase 1 dynamic: `school_type` enum + column, `rollup_mode`/`rollup_config`, `scoring_mode` enum + `classes` generic fields, `student_enrollments` + enrollment trigger + RLS, rewritten `perform_student_rollup` | ⏳ **Apply (re-run)** — premature `cashier` policy removed, ready |
| v13.1 | `.../migration_v13_1_backfill_enrollments.sql` | Data backfill: migrate `students.class_id` → `student_enrollments` | ⏸ **Deferred — needs owner approval (data migration)** |
| v14 | `.../migration_v14_plan_limits_read_write.sql` | Phase 2: `grace_period_days` (default 7), `school_is_writable()`, `plan_has_feature()`, read/**write** policy split on every tenant table, **enrollment-based cap** (drops students-insert trigger, new cap trigger on `student_enrollments`), `school_student_usage()`, `check_rollup_capacity()` | ⏳ **Written — apply after v13** |
| v15 | `.../migration_v15_school_scoring_schedule_defaults.sql` | `school_settings` + `default_scoring_mode`, `default_weekly_schedule` (school-wide scoring/schedule defaults) | ⏳ **Written — apply after v14** |
| v16 | `.../migration_v16_fee_cycles_private_type.sql` | Adds `'private'` to `school_type` enum; widens `fee_structures`/`student_fees` `cycle` to allow `one_time` (course fees) | ⏳ **Written — apply after v15** |

**Apply order:** v12 → v12.1 → v12.2 → **v13 (re-run)** → **v14** → **v15** → **v16**.
`v13_1` only after explicit approval. Never edit applied/fixed migrations —
add a new file instead.

Tests: `database/tests/phase1_dynamic_structure_test.sql` (passes when v13
applied), `database/tests/phase2_plan_limits_test.sql` (v14),
`database/tests/migration_v16_fee_cycles_private_type_test.sql` (v16).

---

## 1. Plans

| | **Basic — $30/mo** | **Pro — $50/mo** |
|---|---|---|
| Students | up to **200** distinct, actively-enrolled | **unlimited** |
| Students, attendance, scores, reports | ✅ | ✅ |
| Parent report links | ✅ | ✅ |
| Approval flow | ✅ | ✅ |
| Student fees (fee collection) | ✅ | ✅ |
| Library (books, borrows) | ❌ | ✅ |
| Budget | ❌ | ✅ |
| Inventory | ❌ | ✅ |
| Honor board | ❌ | ✅ |
| Certificates | ❌ | ✅ |

There is **no free trial**. New schools start `plan_expires_at = null`
(blocked until first payment). **Existing** schools were grandfathered **12
months** from rollout (v12.1 — one update, never re-run).

Plan limits/flags live in the `plans` table (`max_students`,
`features jsonb`) — tunable without a redeploy. `src/config/schoolTypes.js`
holds the *front-of-UI* per-type config; `plans.features` is the *source of
truth* for gating.

---

## 2. Confirmed decisions

| Decision | Choice |
|---|---|
| Plan split | Basic $30 ≤200 students; Pro $50 unlimited + pro modules |
| Subscription billing | **KHQR.dev** (one-off prepaid periods; no recurring) |
| Trial | **None** — must pay before use; existing schools grandfathered 12 months |
| Expiry warning | Admin banner **7 days before** end (+ notification job planned) |
| Expiry grace | Default **7 days** (`schools.grace_period_days`, overridable per school) |
| Enforcement | **Hard block (DB + UI)**; paywall blocks the *whole school* (teachers + librarians), not admin-only |
| Read/write split | **Reads stay open** (log in, export, renew) · **writes blocked** on ALL tenant tables when inactive |
| Student cap basis | **Distinct students with an active `student_enrollments` row** (200th ok / 201st rejected); transitional fallback counts legacy students until backfill |
| Fees module | Full — structures → invoices → payments (v1); proration/cashier/receipts = Phase 3 follow-up |
| Approval flow | Included in **Basic** |
| School types | `primary` · `english` · `computer` · `private` (drives labels, scoring, fee cycles, rollup) |
| Currency | Subscription **USD**; school fees default **KHR** (each `fee_structure` carries its own `currency` KHR/USD) |

### Assumptions
- Unpaid new school: admin is created, lands on Billing, everything else
  blocked until first payment (Option A — confirmed).
- Student fees are staff-recorded (cash/bank/KHQR-ref/Wing). Parents do not
  self-pay online; per-school KHQR merchant accounts = deferred.
- Inactive-admin routing: keep the **billing-only redirect** (no router change).

---

## 3. School-type dynamism

`schools.school_type` (`primary`|`english`|`computer`|`private`) drives
**labels, default scoring mode, fee cycles and rollup behaviour** via
`src/config/schoolTypes.js` (never hardcode grade terms in views).

| Type | Label | Default scoring | Fee cycles | Grade parsing / rollup |
|---|---|---|---|---|
| primary | សាលាបឋមសិក្សា | subject_scores | monthly · semester · yearly | ✅ `grade_promotion` (ថ្នាក់ទី១→២, max 6) |
| english | សាលាភាសាអង់គ្លេស | simple_result | monthly · semester · yearly | ❌ `level_up` / `complete_only` |
| computer | សាលាកុំព្យូទ័រ | simple_result | **one_time** · monthly | ❌ `level_up` / `complete_only` |
| private | សាលាឯកជន (ទូទៅ) | subject_scores | all four | ❌ `complete_only` / `level_up` |

- **Class names are free text.** Khmer-digit grade parsing / "Grade 6 → graduated"
  apply **only** when the school uses grade parsing (`usesGradeParsing`).
- **`classes`** generic fields: `scoring_mode`, `start_date`, `end_date`,
  `schedule` (weekday + time slot), `room`. A class form can inherit the
  school's scoring/schedule defaults (`school_settings`, v15).
- **Scoring modes**: `subject_scores` (existing monthly/semester/yearly
  system) vs `simple_result` (pass/fail courses). Scores pages gate on the
  active class's mode instead of being rewritten.
- **Yearly scores**: frontend-only (never stored / shared). Monthly, semester,
  yearly averages computed in `src/utils/scoreCalculator.js`; `yearly` is
  excluded from ranking, certificates, honor board.
- **Rollup**: generic promote/complete per `schools.rollup_mode`
  (`grade_promotion` | `level_up` | `complete_only`); `perform_student_rollup()`
  branches on mode and returns jsonb. Rollup label
  (`rollup_label = src/config/schoolTypes.js#rollupLabel`) is config-driven in
  `AcademicYearsView`.

---

## 4. RLS & enforcement model (Phase 2 — migration v14)

Single source of truth in SQL:

- **`school_active()`** — `status='active'` AND (`now() < plan_expires_at +
  grace_period_days` default 7, OR `grace_period_ends_at > now()`).
- **`plan_has_feature(f)`** — the *plan's* feature flag only (ignores
  subscription). Gates **reads** of Pro-module tables so a Basic school can't
  even read them.
- **`has_feature(f)`** — `plan_has_feature(f) AND school_active()` → **writes**.
- **`school_is_writable()`** — `school_active()`; used by **write** policies
  on every tenant table.
- Every tenant table has a **read** (SELECT, ownership-only) + **write**
  (ALL, ownership + `school_is_writable()`) policy split — applied across
  core admin tables, teacher student-scoped tables, `students`,
  `report_links`/`report_messages`, fee tables, and Pro modules.

**Student cap (enrollment-based):** distinct students with an active
`student_enrollments` row (multiple active enrollments count once). Trigger
`on_enrollment_check_plan_limit` (BEFORE INSERT / UPDATE of `status`,`class_id`
on `student_enrollments`) → `enforce_student_plan_limit()`; 200th allowed,
201st rejected. The old `students`-insert trigger is **dropped**. For schools
with zero enrollment rows (pre-backfill), a transitional fallback counts
legacy non-graduated-with-class students.

**Bulk operations:**
- `school_student_usage()` → `{ used, max_students }` — pre-checked by
  `StudentsView` save/import before inserting enrollments (Khmer toast,
  no half-import).
- `check_rollup_capacity(old_year, new_year)` — mode-aware projection;
  `AcademicYearsView` refuses a rollup that would exceed the cap.

**Parent report links** stay public/readable even when the school is inactive.

---

## 5. SLA / billing data model (v12)

- **`platform_settings`** — single row: `currency`, `app_config` (editable
  prices + `sandbox_mode`), merchant info.
- **`plans`** — `id ('basic'|'pro')`, `display_name`, `monthly_fee`,
  `max_students`, `features jsonb`, `is_active`.
- **`subscription_invoices`** — one row per billing cycle: `school_id`,
  `plan_id`, period, `total_amount` (server-computed), `khqrdev_md5` /
  `khqrdev_tran_id` / `khqrdev_checkout_url`, `status
  ('pending','paid','expired','void')`, `paid_at`.
- **`schools`** += `plan`, `plan_expires_at`, `grace_period_ends_at`,
  `billing_type`, `school_type`, `rollup_mode`/`rollup_config` (v13).
- **`school_settings`** += `default_scoring_mode`, `default_weekly_schedule`
  (v15).

---

## 6. Billing flow (KHQR.dev) — implemented

```
Admin ─► khqr-payment (JWT edge fn) ─► generate_qr ─► KHQR.dev
              │
              └─ insert subscription_invoices(status=pending, khqrdev_md5)
   render QR (api.khqr.dev/v1/generate_khqr_image/<md5>) + poll invoice.status

Customer pays in bank app ─► KHQR.dev ─signed webhook─► khqr-webhook
   verify HMAC + replay window + amount + idempotency
   → invoice 'paid' → schools.plan_expires_at = max(now, current) + purchased period
```

Edge functions (`supabase/functions/`):
- `khqr-payment` — verifies caller is in the school (or super admin),
  computes the fee server-side from `plans`/`app_config`, reuses an
  unexpired pending QR (KHQR.dev is 1 req/s, QR ~10 min live).
- `khqr-webhook` — deploy with `--no-verify-jwt`; HMAC-SHA256 over raw body
  (`X-RBK-Signature`), `X-RBK-Delivery` 5-min replay window, idempotent,
  then extends `plan_expires_at`.

Secrets (Edge secrets only — never in DB/bundle/git):
```bash
supabase secrets set KHQRDEV_TOKEN=RBK_xxxx
supabase secrets set KHQRDEV_WEBHOOK_SECRET=xxxx
```
Webhook URL to register: `https://<project-ref>.supabase.co/functions/v1/khqr-webhook`

---

## 7. Fees module

**v1 (shipped, ready once v14/v16 applied):**
- `fee_structures` — per academic year **and optionally per class**
  (`class_id` null = whole year): `cycle` (**monthly / semester / yearly /
  one_time** v16), `semester`, `amount`, `currency` (KHR/USD), monthly
  `due_day`, `is_active`.
- `student_fees` — one invoice per student per period; unique
  `(student_id, fee_structure_id, month, semester)`; status
  `due/partial/paid/overdue/waived`.
- `fee_payments` — money received (cash/bank/khqr/wing/other) +
  `sync_student_fee_paid()` trigger keeps `amount_paid`/`status` in sync
  (never overwrites an explicit waiver).
- UI: `/admin/fees` (collection grid, instant invoices per
  structure+period, record payment) and `/admin/fees/structures`.
- Fee form is **config-driven** from the school type:
  `school.typeConfig.feeCycles` + `defaultFeeCycle`; `one_time` generates a
  single invoice per student per structure (no month/semester).

**Phase 3 follow-ups (not yet built):** `term` cycle, `cashier` role (must
`alter type user_role add value 'cashier'` in its own committed migration —
`user_role` currently has **no** `cashier` value → hard SQL error if used),
proration (none/daily/next_period/per_session) + rounding + late-join
cutoff in a `calculate_fee_amount()` function, per-enrollment invoicing
(`enrollment_id`), **receipt numbers** (per-school sequential, concurrency-
safe counter, not `max()+1`), **void-only** payments (never edit/delete),
per-school KHQR for student fees.

---

## 8. Frontend work (implemented)

- **Plan store** `src/stores/plan.js` — `plan`, `planExpiresAt`,
  `gracePeriodEndsAt`, `status`, `isActive`, `daysLeft`, `expiringSoon` (≤7),
  `daysOverdue`, `features`, `studentCap`, `hasFeature(f)`, `fetchPlan`/
  `clearPlan`. Loaded for **every role** during auth init
  (`src/stores/auth.js#fetchProfile`).
- **`src/stores/school.js`** — school type, rollup mode, scoring/schedule
  defaults; `typeConfig`/`labels`/`rollupButtonLabel` computeds; localStorage
  cache.
- **Billing** — `/admin/billing` (`BillingView.vue`), `KhqrPaymentModal.vue`,
  plan banner in `AdminLayout.vue` (warning ≤7 days / danger when expired),
  `/admin/settings` subscription section in super admin `SchoolEditView.vue`.
- **Route gating** `src/router/index.js` — guard 3b hard-block (admin →
  Billing; teacher/librarian → `school-inactive`) · guard 3c `meta.feature`
  → `/upgrade` (`UpgradeView.vue`), registered on budget, inventory, library,
  fees, honor_board (admin+teacher), certificates (teacher), and the whole
  `/librarian/*` app.
- **In-page Pro gates** — honor board (`admin/ScoresView.vue`) and
  certificates + honor board (`teacher/ScoresRankingView.vue`) buttons hide
  lock+`PRO` and route to `/upgrade` on Basic.
- **`SchoolInactiveView.vue`** for blocked staff.
- **Phase 1 gating** — admin/teacher `ScoresView` empty-state for
  `simple_result` classes; config-driven rollup text (`AcademicYearsView`).
- **Cap handling** — `StudentsView` save/import pre-check
  `school_student_usage()` and create `student_enrollments` rows (compensating
  delete on failure); `AcademicYearsView` runs `check_rollup_capacity()` first.
- **School defaults UI** — `SettingsView` "ការវាយតម្លៃ និងកាលវិភាគ" tab
  (scoring select + weekday toggles + start/end) → `ClassesView` pre-fills.
- **Khmer date picker** `src/components/shared/KhmerDatePicker.vue` — lunar
  hint, clear + today actions, flip-up / edge-aware positioning; used for
  class start/end dates.
- **Yearly scores** — `ScoresYearlyView.vue` + `computeYearlyAverage()` +
  `generateYearlyScorePDF()` (frontend-only).

---

## 9. Prompt phases — status & remaining work

| Prompt phase | Status |
|---|---|
| 0 · Multi-tenant safety tests | ⏸ **Not started** — two-school + anon cross-tenant test script |
| 1 · Dynamic structure | ✅ DB (v13) + frontend; **v13.1 backfill deferred** (approval) |
| 2 · Plans / limits / hard block | ✅ DB (v12,+v12.2, v14) + UI; **v14 not yet applied** |
| 3 · Fee module | ⏳ v1 done; cashier / proration / receipts / void pending |
| 4 · KHQR.dev billing | ✅ edge fns + billing UI + webhook |
| 5 · Gating & onboarding | ⏳ store/gating/upgrade done; **`/pricing` public page + signup email verification + super-admin per-school invoices** pending |

**Remaining roadmap (roughly in order):**
1. Apply migrations v13 → v14 → v15 → v16 on staging; run SQL tests.
2. **Phase 0** multi-tenant safety tests (incl. anon report-link reads).
3. **Phase 3 (fee)**: `cashier` role + proration/receipts/void; manual test
   table of 15–20 proration cases.
4. Manual UI test of `perform_student_rollup` (needs seeded schools + real
   roles — can't be exercised in pure SQL).
5. Phase 5 finishing: `/pricing`, email verification on self-signup,
   super-admin billing views.

---

## 10. Open items / follow-ups

- **`migration_v13_1_backfill_enrollments.sql`** is a data migration — **run
  only with owner approval**. Until then the cap uses the transitional
  fallback for schools with zero enrollment rows.
- Migrations v13–v16 are written but **not yet applied**; v13 must be
  re-run (it was fixed by removing the premature `cashier` policy).
- `perform_student_rollup()` binary/RPC and RLS policy behaviour need a
  real staged test (seeded schools + roles via PostgREST/UI).
- Add `'cashier'` to `user_role` as its own committed migration **before**
  any policy references it (Phase 3).
- Offline queue behaviour on a blocked school (stop retrying, keep data,
  show message) — not yet wired.
- `fee_structures` still requires an `academic_year_id`; short-course
  (computer/one-time) schools must still create a year. Consider relaxing.
- Signup email verification + public `/pricing` page (Phase 5).