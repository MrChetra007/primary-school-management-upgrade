/**
 * Computes the monthly average for a student.
 * @param {Array} scores - Array of score objects for the month.
 * @returns {number} Average rounded to 2 decimal places.
 */
export function computeMonthlyAverage(scores) {
  if (!scores || scores.length === 0) return 0;
  const validScores = scores.filter(s => s.score !== null && s.score !== undefined && s.score !== '');
  if (validScores.length === 0) return 0;
  
  const sum = validScores.reduce((acc, curr) => acc + Number(curr.score), 0);
  return Number((sum / validScores.length).toFixed(2));
}

/**
 * Computes the semester average.
 * @param {Array} monthlyAverages - Array of monthly averages (e.g. [80, 85, 90]).
 * @param {number} examAverage - The average of the semester exam subjects.
 * @returns {number} Final semester average rounded to 2 decimal places.
 */
export function computeSemesterAverage(monthlyAverages, examAverage) {
  const validMonths = monthlyAverages.filter(m => m !== null && m !== undefined && m > 0);
  if (validMonths.length === 0) return Number(Number(examAverage).toFixed(2));

  const monthlyAvg = validMonths.reduce((acc, curr) => acc + curr, 0) / validMonths.length;
  return Number(((monthlyAvg + Number(examAverage)) / 2).toFixed(2));
}

/**
 * Computes the rank for a list of students based on their average.
 * Logic: Ties share the same rank, next rank skips (e.g., 1, 1, 3).
 * @param {Array} students - Array of objects containing { average }.
 * @returns {Array} The same array with a 'rank' property added to each object.
 */
export function computeRank(students) {
  if (!students || students.length === 0) return [];

  const sorted = [...students].sort((a, b) => (b.average || 0) - (a.average || 0));

  let rank = 1
  return sorted.map((student, i) => {
    if (i > 0 && sorted[i].average !== sorted[i - 1].average) {
      rank = i + 1
    }
    return { ...student, rank }
  })
}
