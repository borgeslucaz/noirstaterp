export const formatNumberToCurrency = (number, currencySymbol = '') => {
  if (typeof number !== 'number') {
    return number
  }

  const scales = [
    { value: 1e9, symbol: ' Billion' },
    { value: 1e7, symbol: ' Crore' },
    { value: 1e6, symbol: ' Million' },
    { value: 1e5, symbol: ' Lac' }
  ]

  for (let i = 0; i < scales.length; i++) {
    if (number >= scales[i].value) {
      const formattedNumber = (number / scales[i].value).toLocaleString(
        'en-IN',
        {
          maximumFractionDigits: 2,
          minimumFractionDigits: 0
        }
      )

      return `${formattedNumber}${scales[i].symbol}`
    }
  }
  return `${currencySymbol}${number.toLocaleString('en-IN')}`
}
