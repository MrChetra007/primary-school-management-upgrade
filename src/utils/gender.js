const FEMALE_VARIANTS = ['female', 'femal', 'f', 'girl']

export function isFemale(gender) {
  if (!gender) return false
  const g = String(gender).toLowerCase().trim()
  return FEMALE_VARIANTS.includes(g)
}

export function genderLabel(gender) {
  return isFemale(gender) ? 'ស្រី' : 'ប្រុស'
}

export function genderColor(gender) {
  return isFemale(gender) ? '#ec4899' : '#3b82f6'
}
