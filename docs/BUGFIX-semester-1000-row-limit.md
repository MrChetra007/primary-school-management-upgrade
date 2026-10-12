# Bug Fix: Semester Score Monthly Averages Showing "---"

## Problem

In the **Semester Score Entry** view (`ScoresSemesterView`), some students' monthly average columns displayed "---" (dash) instead of computed scores, even though those students' monthly scores existed in the database and displayed correctly in the **Monthly Score Entry** view.

### Affected Views

| View | File |
|------|------|
| Semester Score Entry | `src/views/teacher/ScoresSemesterView.vue` |
| Score Ranking (semester mode) | `src/views/teacher/ScoresRankingView.vue` |
| Admin Scores (semester mode) | `src/views/admin/ScoresView.vue` |
| Certificate Design (semester mode) | `src/views/teacher/CertificateDesignView.vue` |

### Symptoms

- Students at the **end** of the alphabetical list had zero monthly averages in semester mode
- The same students' scores displayed correctly in monthly mode
- The `monthlyScores` ref contained zero rows for the affected students despite their scores existing in Supabase

---

## Root Cause: Supabase Default 1000-Row Limit

Supabase (PostgREST) enforces a **default row limit of 1000** per query. The semester view queried all monthly scores for a class in a single request:

```
30 students x 10 subjects x 4 months = ~1200 possible rows
```

The query returned exactly **1000 rows** (the server cap), truncating the last ~200 rows. Students whose scores fell past the cutoff received empty results, causing their monthly averages to compute as 0 and display as "---".

### Why Monthly Mode Was Not Affected

The monthly view queries one month at a time:

```
30 students x 10 subjects x 1 month = ~300 rows  (well under 1000)
```

### Why `.limit(5000)` Did Not Help

Adding `.limit(5000)` to the Supabase client sets the `Limit` header, but PostgREST **caps it at the server-configured max** (1000 by default). The extra rows were still silently truncated.

---

## Fix: Per-Month Queries

Instead of one large query fetching all months at once, each semester month is queried **individually** and the results are merged. Each per-month request returns ~300 rows, staying safely under the 1000-row cap.

### Before (single query, hit 1000-row cap)

```js
const { data: mData } = await supabase
  .from('scores')
  .select('*')
  .in('student_id', studentIds)
  .eq('academic_year_id', academicYearId)
  .eq('score_type', 'monthly')
```

### After (per-month queries, each under 1000)

```js
const monthResults = await Promise.all(
  semesterMonths.value.map(m =>
    supabase
      .from('scores')
      .select('*')
      .in('student_id', studentIds)
      .eq('academic_year_id', academicYearId)
      .eq('score_type', 'monthly')
      .eq('month', m)
  )
)
const mData = monthResults.flatMap(r => r.data || [])
```

All per-month requests run in parallel via `Promise.all`, so there is no noticeable performance penalty.

### Files Changed

| File | Change |
|------|--------|
| `src/views/teacher/ScoresSemesterView.vue` | Replaced single monthly scores query with per-month `Promise.all` |
| `src/views/teacher/ScoresRankingView.vue` | Same pattern in semester ranking path |
| `src/views/admin/ScoresView.vue` | Same pattern in admin semester scores path |
| `src/views/teacher/CertificateDesignView.vue` | Same pattern in semester certificate path |

---

## Why The Fix Works

| Scenario | Rows per query | Under 1000 cap? |
|----------|---------------|-----------------|
| Monthly mode (1 month) | ~300 | Yes |
| Semester mode (old, single query) | ~1200 | **No** - truncated |
| Semester mode (fixed, per-month) | ~300 each | Yes |

Each per-month query returns a manageable number of rows. `Promise.all` fires them all in parallel, and `flatMap` merges the results into a single array that `buildMatrix` consumes as before.

---

## Additional Cleanup

During investigation, the following issues were also discovered and fixed:

1. **Vue Reactive Proxy + Supabase `.in()` incompatibility** - `semesterMonths.value` returned a Vue reactive `Proxy(Array)`. Passing it directly to `.in('month', ...)` caused serialization issues. The per-month approach uses `.eq('month', singleValue)` instead, avoiding the Proxy entirely.

2. **All debug logging removed** - Extensive `console.log`, `console.group`, and diagnostic logging added during debugging was cleaned up.
