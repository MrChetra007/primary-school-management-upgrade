/**
 * exportPdf.js
 * Generates Cambodian school ranking PDFs.
 *
 * Strategy: builds an HTML document and opens it in a new window,
 * then triggers the browser's native print dialog (Save as PDF).
 * No html2canvas / jsPDF needed — you can remove them from package.json.
 */

// ─── Helpers ─────────────────────────────────────────────────────────────────
import symbol from "@/assets/symbol.png";
/** Convert any digit characters in a string to Khmer numerals */
function toKhmerNum(str) {
  const k = ['០','១','២','៣','៤','៥','៦','៧','៨','៩']
  return String(str).replace(/\d/g, d => k[+d])
}

function genderLabel(gender) {
  return (gender || '').toLowerCase() === 'female' ? 'ស្រី' : 'ប្រុស'
}

function fmtAvg(val) {
  const n = Number(val)
  if (val === null || val === undefined || val === '' || isNaN(n)) return '—'
  return n.toFixed(2)
}

// ─── HTML Builder ─────────────────────────────────────────────────────────────

function buildRankingHtml({ rankedList, metadata, mode, filename }) {
  const {
    schoolName   = 'សាលាបឋមសិក្សា',
    districtName = '',
    className    = '',
    year         = '',
    month        = '',
    semester     = ''
  } = metadata

  // Convert year digits to Khmer  e.g. "2025-2026" → "២០២៥-២០២៦"
  const khmerYear     = toKhmerNum(year)
  const khmerSemester = toKhmerNum(semester)

  // Sort by rank asc, then name to break ties
  const sorted = [...rankedList].sort(
    (a, b) => (a.rank - b.rank) || a.full_name.localeCompare(b.full_name)
  )

  // ── Summary counts ────────────────────────────────────────────────────────
  const total        = sorted.length
  const female       = sorted.filter(s => (s.gender || '').toLowerCase() === 'female').length
  const passed       = sorted.filter(s => s.average >= 5).length
  const femalePassed = sorted.filter(s => (s.gender || '').toLowerCase() === 'female' && s.average >= 5).length
  const failed       = total - passed
  const femaleFailed = sorted.filter(s => (s.gender || '').toLowerCase() === 'female' && s.average < 5).length

  // ── Report title ──────────────────────────────────────────────────────────
  const reportTitle = mode === 'monthly'
    ? `តារាងចំណាត់ថ្នាក់ប្រចាំខែ ${month}`
    : `តារាងចំណាត់ថ្នាក់ប្រចាំឆមាសទី ${khmerSemester}`

  // ── Row builder — 25 rows per column, supports up to 50 students ──────────
  function buildRows(slice, startNum) {
    return Array.from({ length: 25 }, (_, i) => {
      const s = slice[i]
      if (!s) {
        return `<tr class="empty-row"><td></td><td></td><td></td><td></td><td></td></tr>`
      }
      const hasScore   = s.average !== null && s.average !== undefined && s.average !== ''
      const isPassed   = hasScore && Number(s.average) >= 5
      const rankClass  = !hasScore ? '' : isPassed ? 'rank-ok' : 'rank-fail'
      return `<tr>
        <td>${startNum + i}</td>
        <td class="name-cell">${s.full_name || ''}</td>
        <td class="gender-cell">${genderLabel(s.gender)}</td>
        <td class="avg-cell">${fmtAvg(s.average)}</td>
        <td class="rank-cell ${rankClass}">${hasScore ? s.rank : '—'}</td>
      </tr>`
    }).join('\n')
  }

  // 25 rows per column → supports up to 50 students
  const left  = sorted.slice(0, 25)
  const right = sorted.slice(25, 50)

  // ── Shared table header ───────────────────────────────────────────────────
  // column widths via <colgroup> so table-layout: fixed works correctly:
  //   ល.រ 10% | name 38% | gender 18% | average 18% | rank 16%
  // Name is intentionally narrow so "ចំណាត់ថ្នាក់" never wraps.
  const tableHead = `
    <colgroup>
      <col style="width:10%;">
      <col style="width:38%;">
      <col style="width:18%;">
      <col style="width:18%;">
      <col style="width:16%;">
    </colgroup>
    <thead>
      <tr>
        <th>ល.រ</th>
        <th class="th-name">នាមនិងគោត្តនាម</th>
        <th>ភេទ</th>
        <th>មធ្យមភាគ</th>
        <th class="th-rank">ចំណាត់ថ្នាក់</th>
      </tr>
    </thead>`

  // ── Full HTML document ────────────────────────────────────────────────────
  return `<!DOCTYPE html>
<html lang="km">
<head>
  <meta charset="UTF-8"/>
  <title>${filename}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Khmer:wght@400;600;700&display=block" rel="stylesheet">
  <style>
    *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }

    body {
      font-family: 'Noto Sans Khmer', 'Khmer OS', 'Khmer OS System', sans-serif;
      font-size: 11px;
      color: #111;
      background: #fff;
      padding: 24px 28px;
      width: 210mm;
    }

    /* ── Royal header ── */
    .header       { text-align: center; margin-bottom: 12px; }
    .header .t1   { font-size: 25px; font-weight: 700; }
    .header .t2   { font-size: 20px; font-weight: 700; margin-top: 2px; }
    .header .divider { width: 80px; height: 1px; background: #333; margin: 5px auto; }

    /* ── School meta ── */
    .meta        { font-size: 15px; line-height: 2; margin-bottom: 10px; }
    .meta .label { font-weight: 700; }

    /* ── Report title ── */
    .report-title { text-align: center; font-size: 12.5px; font-weight: 700; margin-bottom: 2px; }
    .report-year  { text-align: center; font-size: 15px; margin-bottom: 10px; }

    /* ── Two-column layout
         Using display:table so it survives the print rendering pipeline.
         display:flex collapses to single column in many browser print engines. ── */
    .dual         { display: table; width: 100%; border-spacing: 6px 0; table-layout: fixed; }
    .dual-col     { display: table-cell; width: 50%; vertical-align: top; }

    /* ── Ranking table ── */
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
      table-layout: fixed;   /* enforces colgroup widths */
    }
    th, td {
      border: 0.6px solid #777;
      padding: 2.5px 3px;
      text-align: center;
      vertical-align: middle;
      line-height: 1.45;
      overflow: hidden;
    }
    th              { background: #f0f0f0; font-weight: 700; font-size: 11px; }
    .th-name        { text-align: left; padding-left: 4px; }
    /* Rank header: no wrap, fits on one line */
    .th-rank        { white-space: nowrap; font-size: 11x; }
    .name-cell      { text-align: left; padding-left: 4px;
                      white-space: nowrap; overflow: hidden; text-overflow: ellipsis; 
    }
    .gender-cell    { font-size: 11px; white-space: nowrap; }
    .avg-cell       { font-weight: 600; }
    .rank-ok        { color: #bf4a00; font-weight: 700; }
    .rank-fail      { color: #aa0000; font-weight: 700; }
    .empty-row td   { height: 25px; border-color: #ccc; }

    /* ── Footer stats ── */
    .stats {
      display: table;           /* also using table so it prints correctly */
      width: 100%;
      border-top: 0.8px solid #777;
      padding-top: 6px;
      margin-top: 8px;
      font-size: 15px;
      font-weight: 600;
    }
    .stats span { display: table-cell; }

    /* ── Signature block ── */
    .sig-block      { display: table; width: 100%; margin-top: 14px; }
    .sig-col        { display: table-cell; width: 50%; vertical-align: top; font-size: 14px; line-height: 1.9; }
    .sig-head       { font-weight: 700; text-align: center; font-size: 12px; margin-bottom: 2px; }
    .sig-sub        { color: #222; }
    .teacher-label  { text-align: center; font-weight: 700; font-size: 13px; margin-top: 6px; }

    /* ── Print ── */
    @media print {
      @page {
        size: A4 portrait;
        margin: 8mm 10mm;
      }
      body {
        width: 100%;
        padding: 0;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
    }
  </style>
</head>
<body>

  <!-- Royal Header -->
  <div class="header">
    <div class="t1">ព្រះរាជាណាចក្រកម្ពុជា</div>
    <div class="t2">ជាតិ សាសនា ព្រះមហាក្សត្រ</div>
    <img src="${symbol}" alt="" style="width: 150px; height: 20px;">
  </div>

  <!-- School Info -->
  <div class="meta">
    <div><span class="label">កម្រងសាលារបប់សិក្សា</span>...................</div>
    <div><span class="label">សាលារបប់សិក្សា</span> ${schoolName}</div>
    <div><span class="label">${className}</span></div>
  </div>

  <!-- Title -->
  <div class="report-title">${reportTitle}</div>
  <div class="report-year">ឆ្នាំសិក្សា ${khmerYear}</div>

  <!-- Two-column Ranking Table -->
  <div class="dual">
    <div class="dual-col">
      <table>
        ${tableHead}
        <tbody>${buildRows(left, 1)}</tbody>
      </table>
    </div>
    <div class="dual-col">
      <table>
        ${tableHead}
        <tbody>${buildRows(right, 26)}</tbody>
      </table>
    </div>
  </div>

  <!-- Summary Stats -->
  <div class="stats">
    <span>សិស្សសរុប: ${total} នាក់ (ស្រី: ${female} នាក់)</span>
    <span>ជាប់មធ្យមភាគ: ${passed} នាក់ (ស្រី: ${femalePassed} នាក់)</span>
    <span>ធ្លាក់មធ្យមភាគ: ${failed} នាក់ (ស្រី: ${femaleFailed} នាក់)</span>
  </div>

  <!-- Signature Block -->
  <div class="sig-block">
    <div class="sig-col">
      <div class="sig-head">បានឃើញ និងឯកភាព</div>
      <div class="sig-sub">ថ្ងៃ..........................ខែ..............ឆ្នាំ........... អស័ក ព.ស ២៤៧....</div>
      <div class="sig-sub">ធ្វើនៅ......................ថ្ងៃទី.............ខែ................ឆ្នាំ ២០......</div>
      <div class="sig-head" style="text-align: center;">នាយក</div>
    </div>
    <div class="sig-col">
      <div class="sig-sub">ថ្ងៃ..........................ខែ..............ឆ្នាំ........... អស័ក ព.ស ២៤៧....</div>
      <div class="sig-sub">ធ្វើនៅ......................ថ្ងៃទី.............ខែ................ឆ្នាំ ២០......</div>
      <div class="teacher-label" style="text-align: center;">គ្រូប្រចាំថ្នាក់</div>
    </div>
  </div>

  <script>
    document.fonts.ready.then(function () {
      setTimeout(function () {
        window.focus();
        window.print();
      }, 300);
    });
    window.addEventListener('afterprint', function () {
      window.close();
    });
  </script>

</body>
</html>`
}

// ─── Core renderer ────────────────────────────────────────────────────────────

function openPrintWindow(htmlString) {
  const win = window.open('', '_blank', 'width=900,height=1100,scrollbars=yes')
  if (!win) {
    alert(
      'បង្អួចលេចឡើងត្រូវបានរារាំង។\n' +
      'សូមអនុញ្ញាត Pop-up សម្រាប់គេហទំព័រនេះ រួចចុច "ទាញយក PDF" ម្ដងទៀត។'
    )
    return
  }
  win.document.open()
  win.document.write(htmlString)
  win.document.close()
}

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * Generate Monthly Ranking PDF
 * @param {Array}  rankedList  [{ full_name, gender, average, rank }, ...]
 * @param {Object} metadata   { schoolName, districtName, className, year, month }
 */
export async function generateMonthlyScorePDF(rankedList, metadata) {
  const filename = `ranking_${metadata.className}_${metadata.month || 'monthly'}`
  openPrintWindow(buildRankingHtml({ rankedList, metadata, mode: 'monthly', filename }))
}

/**
 * Generate Semester Ranking PDF
 * @param {Array}  rankedList  [{ full_name, gender, average, rank }, ...]
 * @param {Object} metadata   { schoolName, districtName, className, year, semester }
 */
export async function generateSemesterScorePDF(rankedList, metadata) {
  const filename = `ranking_${metadata.className}_semester${metadata.semester}`
  openPrintWindow(buildRankingHtml({ rankedList, metadata, mode: 'semester', filename }))
}