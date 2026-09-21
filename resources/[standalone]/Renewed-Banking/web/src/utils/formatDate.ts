export const formatDate = (
    dateStr: string | number | null,
    locale: string = 'pt-BR',
    options?: Intl.DateTimeFormatOptions
): string => {
    if (!dateStr) return '-'

    let date: Date
    if (typeof dateStr === 'number') {
        date = new Date(dateStr)
    } else {
        const [datePart, timePart] = dateStr.split(' ')
        const [year, month, day] = datePart.split('-').map(Number)
        const [h, m] = (timePart || '00:00').split(':').map(Number)
        date = new Date(year, month - 1, day, h, m, 0)
    }

    if (isNaN(date.getTime())) return '-'

    return date.toLocaleDateString(locale, options ?? {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: locale.startsWith('en')
    })
}