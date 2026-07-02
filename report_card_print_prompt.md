# Prompt: Printable Report Card Feature (PSMS)

Paste this into Claude Code / your AI assistant working in the PSMS repo.

---

## Goal

Add a **teacher-facing "Print Report Card" feature** to PSMS. It renders, for the
current class + selected period (monthly or semester), a browser-printable page:
**two students per A4 sheet**, stacked top/bottom, separated by a dashed cut line
so the teacher can print and cut with scissors.

This is triggered from the teacher's class/score view (`ReportLinkView.vue` or
similar) with a "បោះពុម្ព / Print" button that opens a dedicated print route/view.
Use `window.print()` with `@media print` CSS — no PDF library needed.

## Data sources (Supabase)

Reuse the existing queries/patterns already in `ReportLinkView.vue`:

| Data | Source | Notes |
|---|---|---|
| Student | `students` | `full_name`, `gender` |
| Class / year | `classes`, `academic_years` | `class_name`, `year_name` |
| Subjects | `class_subjects` → `subjects` | `subject_name` — **count varies per class**, do not assume 12 |
| Scores | `scores` | filtered by `score_type` (`monthly`/`semester`), `month`/`semester` |
| Attendance | `attendances` | status counts for the selected month → present / absent / rate |
| Teacher note | `report_messages` | `teacher_text` |
| Rank / average | computed client-side via existing `computeMonthlyAverage` / `computeRank` | reuse, don't reimplement |
| Grade letter | existing `getGrade(score)` (A–F thresholds) | reuse as-is |
| School info | `schools` table | name, address, logo — **confirm actual column names in schema before wiring up**; if a field is missing, fall back to blank/placeholder, don't hardcode fake data |
| Principal name/signature/stamp | `schools` table, if such columns exist | **optional** — see signature block behavior below |

If the `schools` table doesn't already have principal name/signature/stamp image
columns, don't invent them — just wire the layout to support them later and leave
the print blank (physical pen signature + rubber stamp) for now.

## Layout spec (per student card — repeats twice per page)

Matches the approved sample design, with these corrections from the original draft:

1. **Letterhead**: small logo badge (school logo if available, else initials/placeholder) + school name (Khmer, bold) + address/subtitle in gray, small "សន្លឹកលទ្ធផលសិក្សា / STUDENT REPORT CARD" label top-right.
2. **Student info strip**: name, class, roll number, period label (e.g. "ត្រីមាសទី ១ • ឆ្នាំសិក្សា ២០២៥-២០២៦") — light gray background band.
3. **Subjects table** — **dynamic layout, not a fixed 3×4 grid**:
   - Subject count varies by class, so compute column count based on subject count (e.g. 1 column if ≤5 subjects, 2 columns if 6–10, 3 columns if 11+), so the block stays roughly the same total height regardless of subject count.
   - Each cell: subject name (left) + grade letter, colored per `chip-A`…`chip-F` classes already defined in your codebase.
4. **Attendance + teacher note strip**: light blue background, two columns — present/absent/leave counts on the left, teacher's note text on the right (from `report_messages.teacher_text`, fallback "—" if empty).
5. **Signature block** — corrected layout:
   - Two columns: **principal on the left, teacher on the right** (swap from earlier draft).
   - **Date goes above the signature line**, not below (e.g. "ថ្ងៃទី ___ ខែ ___ ឆ្នាំ ______" then the signature line beneath it).
   - Principal's stamp: if a stamp image exists in the DB, position it **overlapping the bottom portion of the principal's signature** — i.e. absolutely positioned, anchored near the bottom-center/bottom-right of the signature line, overlapping slightly upward onto the signature rather than sitting cleanly above or beside it (this mimics how it's physically stamped over a real signature). If no stamp image, just leave the blank signature line + "(ត្រា និងហត្ថលេខា)" label as today.
   - Teacher's side: just a blank signature line, no stamp.

## Print CSS specifics

- `@page { size: A4; margin: ... }`
- Each card wrapped in a container sized to roughly half the printable page height (`~50vh` equivalent in print units), so two cards + the dashed divider fit one sheet.
- Dashed cut line (`border-bottom: dashed`) between the two cards, with a small scissors icon/label.
- Because subject count is dynamic, guard against overflow: if a card's natural content height exceeds its half-page budget, scale it down (either via a computed `font-size`/`padding` step based on subject count, or a CSS-transform `scale()` fallback measured in JS before printing). Don't let content silently cut off at the page edge.
- Hide all normal app chrome (`nav`, buttons, filters) under `@media print { .no-print { display: none } }`.
- If the class has an odd number of students, the last page has one card + an empty (or "cut here, blank" ) placeholder in the second slot — don't leave a broken/half-rendered card.

## Visual tokens (reuse across cards)

- Accent blue: `#1D4ED8`, light blue section background: `#EFF6FF`, gray for cut line/labels: `#6B7280`/`#9CA3AF`.
- Khmer font: match whatever the rest of PSMS uses for Khmer text (check existing `font-family` in the app's global CSS) — don't introduce a new font just for this view.
- Grade chip colors: reuse existing `.chip-A`…`.chip-F` classes already defined in `ReportLinkView.vue`'s `<style>`.

## Suggested implementation

- New component, e.g. `ReportCardPrint.vue`, taking `classId` + period (`mode`, `month`/`semester`) as props/route params.
- Fetch the same shape of data `ReportLinkView.vue` already fetches (students, subjects, scores, attendance, messages) — consider extracting a shared composable (`useClassReportData`) so both views don't duplicate query logic.
- A `<div class="report-page">` per pair of students, `v-for` over students chunked in 2s.
- Print button triggers `window.print()`; wrap non-printable UI in `.no-print`.

## Edge cases to handle

- Missing score for a subject → show `-` (already the pattern in `getStudentScores`).
- Zero attendance records for the period → show `0%`, not `NaN%`.
- Missing teacher note → `—`.
- Missing school logo/address → omit gracefully, don't show broken image icon.
- Very long student names / subject names → truncate or wrap without breaking the card height budget.
