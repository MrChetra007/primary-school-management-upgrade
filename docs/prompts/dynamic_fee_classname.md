# TASK: Evolve my school management SaaS (read fully before coding)

## Context

Existing app: Primary School Management System (Vue 3 + Vite + Tailwind + Supabase, multi-tenant via school_id + RLS, Pinia, PWA with offline queue for teachers). Roadmap v17, schema v10. I am a solo developer.

I'm turning it into a paid SaaS for small private schools in Cambodia. Three target school types: PRIMARY schools, ENGLISH schools, COMPUTER schools. The system is for managing STUDENTS and STUDENT FEES only (no staff payroll).

## Rules for how you work

1. First inspect the repo (schema, migrations, stores, views) and report conflicts with this plan. Do not start coding until you've given me a short summary of what you found.
2. Work one phase at a time, in the order below. After each phase, stop and tell me what changed and how to test it.
3. Write migrations as new files. Never edit old migrations. Never assume production; everything is tested on staging first.
4. All money calculations live in the database (SQL functions), not in Vue components. The frontend displays results only.
5. Every new table gets school_id + RLS. Provide SQL tests for each phase.
6. Ask me before any destructive change (dropping columns, data migrations).
7. Keep it simple: configuration over custom code. No school-specific logic.

## Existing draft

There is already a draft migration_v12_saas.sql and docs/ plan (plans, subscription_invoices, fee_structures, student_fees, fee_payments, school_active(), has_feature(), enforce_student_plan_limit). Revise it according to this prompt; do not duplicate it.

## PHASE 0: Multi-tenant safety

Create two test schools and an automated test script proving no cross-tenant read/write on every table (anon role included for parent report links). Fix any leak before continuing.

## PHASE 1: Dynamic structure

- schools.school_type: 'primary' | 'english' | 'computer'. It drives default LABELS (Grade→Level/Course, Teacher→Instructor), default fee cycle, and default scoring mode. Labels come from a config map, not hardcoded strings.
- Class names are free text. Remove hardcoded primary-school rules or apply them only when school_type='primary': Grade 1-6 assumptions, "Grade 6 → graduated", Khmer digit parsing in rollup, "Grade 1-3 no English / 4-6 includes English".
- "Academic year" becomes a generic term/period. Courses can have start_date, end_date, schedule (days + time slot), optional room.
- NEW table student_enrollments (school_id, student_id, class_id, start_date, end_date nullable, status 'active'|'completed'|'withdrawn'). A student can have several active enrollments (e.g. English + Computer), join mid-term, and withdraw. Migrate existing students.class_id into enrollments safely (ask me before running).
- Scoring mode per class: 'subject_scores' (existing system, primary) or 'simple_result' (level/grade/pass-fail + certificate, for courses). Gate existing score pages by mode instead of rewriting them.
- Rollup becomes generic "promote / complete" with per-school config.

## PHASE 2: Plans, limits, hard block

- Plans: Basic $30 (max 200 students; students, attendance, scores, reports, parent report links, approval flow, fees) and Pro $50 (unlimited + library, budget, inventory, honor board, certificates). Limits and feature flags live in the plans table (max_students, features jsonb).
- Student cap = number of DISTINCT students with an active enrollment. Enforce with a BEFORE INSERT trigger on enrollments (and on UPDATE of status/class) so the 200th student is allowed and the 201st is rejected. Also handle Excel import and promote/complete without half-failing. Test at exactly 199, 200, 201.
- No free trial. New school is created inactive and must pay first.
- Expiry: school_active() = now() < plan_expires_at + grace period (default 7 days, configurable). After that, WRITES are blocked on ALL tenant tables via a school_is_writable() check in write policies (not only library/budget/inventory). READS stay open so the admin can still log in, open Billing, renew, and export students/scores/payments. Parent report links stay readable.
- 7 days before plan_expires_at: show an admin banner and create ONE notification (scheduled job such as pg_cron or a scheduled Edge Function, unique per school+expiry date, no duplicates).
- Offline queue: if sync fails because the school is blocked, processQueue() must stop retrying, keep the queued entries, and show a clear message. Never silently drop data.
- Super admin keeps a manual "mark paid / set expiry" button for pilots and cash payers (billing_type='manual').

## PHASE 3: Fee module (staff-recorded; parents pay in person)

Tables:

- fee_structures (per class/course): cycle (monthly|term|yearly|one_time), amount, currency (KHR|USD), due_day, proration_mode (none|daily|next_period|per_session), rounding (none|100|500), late_join_cutoff_day, active.
- student_fees = one invoice per enrollment per period: enrollment_id, period key, amount (snapshot), discount_amount, discount_reason, note (e.g. "prorated 11/30 days"), due_date, amount_paid. Status 'overdue' is COMPUTED from due_date and balance, not stored. Uniqueness must handle NULL month/semester (use a generated period key or NULLS NOT DISTINCT).
- fee_payments: amount, currency, exchange_rate if paid in a different currency, method (cash|bank|khqr_ref|wing|other), reference, received_by, receipt_no, voided_at, void_reason. NEVER edit or delete payments; void with a reason.
- Receipt numbers: per-school sequential, concurrency-safe (counter row with lock, not max()+1).
- Roles: add 'cashier'. Teachers have no access to fee data.
- One SQL function calculate_fee_amount(structure, enrollment, period) handles proration/rounding/cutoff. Invoice generation is idempotent (running twice never duplicates). Admin can override an invoice amount with a required reason.
- Bulk "mark paid" must create real payment rows with receipts.
- Withdrawal: void unpaid future invoices; refunds are manual recorded adjustments.
- UI: collection grid, structures, payments/receipts (Khmer receipt with existing signature + stamp), reports (arrears, daily cash, monthly income, per-student ledger).
- Provide a test table of 15-20 proration cases (join day 1, day 20 of 30-day month, after cutoff, join+withdraw same month, 28 vs 31 day months, rounding) with expected values I can verify by hand.

## PHASE 4: KHQR.dev subscription billing (school pays me)

Reuse the pattern from docs/khqrdev_payment_implementation.md and my my-saas project, tenant = schools. Edge functions: khqr-payment (JWT, computes amount server-side, reuses unexpired QR, respects 1 req/s) and khqr-webhook (--no-verify-jwt; HMAC over raw body, replay window, amount check, idempotent). KHQR is one-off payment, so use PREPAID PERIODS (1, 3, 12 months, with a yearly discount), not recurring subscriptions. On payment: plan_expires_at = max(now(), current plan_expires_at) + purchased period. If a payment arrives after the pending invoice expired, still credit it (match by md5); flag amount mismatches for super admin review. Secrets only via supabase secrets. Billing route must be reachable by unpaid/blocked schools.

## PHASE 5: Gating and onboarding

Plan store, nav/route gating by hasFeature, upgrade page, public /pricing, super admin billing views, email verification on self-signup (new school → Basic, inactive until first payment).

## Output expectations per phase

1. Short plan of files to add/change. 2. The code/migration. 3. SQL or script tests. 4. How I verify it on staging. 5. Risks or decisions you need from me.
