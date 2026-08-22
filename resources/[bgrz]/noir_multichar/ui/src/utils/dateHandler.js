import { dayNames } from './monthNames'

export const getNumberOfDaysInMonth = (year, month) => {
  return new Date(year, month + 1, 0).getDate()
}

export const getSortedDays = (year, month) => {
  const dayIndex = getNumberOfDaysInMonth(year, month)
  const firstHalf = dayNames.slice(dayIndex)
  return [...firstHalf, ...dayNames.slice(0, dayIndex)]
}

export const range = (start, end) => {
  const length = Math.abs((end - start) / 1)
  const { result } = Array.from({ length }).reduce(
    ({ result, current }) => ({
      result: [...result, current],
      current: current + 1
    }),
    { result: [], current: start }
  )
  return result
}

export const getYears = (currentYear) => {
  const startYear = 1900
  const endYear = currentYear + 1
  return range(startYear, endYear)
}