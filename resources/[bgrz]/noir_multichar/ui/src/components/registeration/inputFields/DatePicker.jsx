import React, { useState } from 'react'
import { monthNames } from '../../../utils/monthNames'
import { getNumberOfDaysInMonth, getYears, range } from '../../../utils/dateHandler'
import { nuicallback } from '../../../utils/nuicallback'
import { useConfig } from '../../../providers/configprovider'
import { usePopoverPlacement } from './usePopoverPlacement'

const currentCalendarYear = new Date().getFullYear()
const twoDigits = (value) => String(value).padStart(2, '0')

const DatePicker = ({ handleDate, closeDate, dobVisible, handleChange }) => {
  const { config } = useConfig()
  const [currentMonth, setCurrentMonth] = useState(new Date().getMonth())
  const [currentYear, setCurrentYear] = useState(currentCalendarYear)
  const [currentDay, setCurrentDay] = useState(new Date().getUTCDate())
  const [selectedDate, setSelectedDate] = useState('')
  const { anchorRef, popoverRef, placement } = usePopoverPlacement(dobVisible, closeDate)

  const selectDate = () => {
    // Preserve the date format already consumed by the FiveM backend.
    const value = `${currentYear}/${currentDay}/${currentMonth + 1}`
    handleChange({ tag: 'DOB', value })
    setSelectedDate(`${twoDigits(currentMonth + 1)} / ${twoDigits(currentDay)} / ${currentYear}`)
    closeDate()
    nuicallback('click')
  }

  return (
    <div ref={anchorRef} className={`noir-create__field noir-create__popover-anchor${dobVisible ? ' is-open' : ''}`}>
      <span className='noir-create__label'>DATE OF BIRTH</span>
      <button type='button' onClick={handleDate} onMouseEnter={() => nuicallback('hover')} className='noir-create__control noir-create__select' aria-expanded={dobVisible}>
        <span className={selectedDate ? '' : 'noir-create__placeholder'}>{selectedDate || 'MM / DD / YYYY'}</span>
        <span className='noir-create__diamond' aria-hidden='true'>◇</span>
      </button>

      <div ref={popoverRef} className={`noir-create__popover noir-create__date noir-create__popover--${placement}${dobVisible ? ' noir-create__popover--open' : ''}`} aria-hidden={!dobVisible}>
        <div className='noir-create__date-columns'>
          <DateColumn label='MONTH' values={monthNames.map((month, index) => ({ label: month.slice(0, 3).toUpperCase(), value: index }))} selected={currentMonth} onSelect={setCurrentMonth} />
          <DateColumn label='DAY' values={range(1, getNumberOfDaysInMonth(currentYear, currentMonth) + 1).map((day) => ({ label: twoDigits(day), value: day }))} selected={currentDay} onSelect={setCurrentDay} />
          <DateColumn label='YEAR' values={getYears(currentCalendarYear).filter((year) => year > config.mindob && year < config.maxdob).map((year) => ({ label: year, value: year }))} selected={currentYear} onSelect={setCurrentYear} />
        </div>
        <button type='button' className='noir-create__popover-done' onClick={selectDate} onMouseEnter={() => nuicallback('hover')}>CONFIRM DATE <span>→</span></button>
      </div>
    </div>
  )
}

const DateColumn = ({ label, values, selected, onSelect }) => (
  <div className='noir-create__date-column'>
    <span>{label}</span>
    <ul className='noir-create__date-list'>
      {values.map((item) => (
        <li key={item.value}>
          <button type='button' className={item.value === selected ? 'is-selected' : ''} onClick={() => { onSelect(item.value); nuicallback('click') }}>{item.label}</button>
        </li>
      ))}
    </ul>
  </div>
)

export default DatePicker
