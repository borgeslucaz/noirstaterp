import React, { useState } from 'react'
import { countriesList } from '../../../utils/coutries'
import { nuicallback } from '../../../utils/nuicallback'
import { usePopoverPlacement } from './usePopoverPlacement'

const Option = ({ name, handleChange, optionsPopup, handleOptionsPopup, closeOptions }) => {
  const [selectedCountry, setSelectedCountry] = useState('')
  const [searchCountry, setSearchCountry] = useState('')
  const { anchorRef, popoverRef, placement } = usePopoverPlacement(optionsPopup, closeOptions)

  const selectCountry = (event) => {
    setSelectedCountry(event.target.value)
    handleChange(event)
    closeOptions()
    nuicallback('click')
  }

  const countries = countriesList.filter((country) => country.toLowerCase().includes(searchCountry.toLowerCase()))

  return (
    <div ref={anchorRef} className={`noir-create__field noir-create__popover-anchor${optionsPopup ? ' is-open' : ''}`}>
      <span className='noir-create__label'>NATIONALITY</span>
      <button type='button' onClick={handleOptionsPopup} onMouseEnter={() => nuicallback('hover')} className='noir-create__control noir-create__select' aria-expanded={optionsPopup}>
        <span className={selectedCountry ? '' : 'noir-create__placeholder'}>{selectedCountry || 'Select nationality'}</span>
        <span className={`noir-create__chevron${optionsPopup ? ' is-open' : ''}`} aria-hidden='true'>›</span>
      </button>

      <div ref={popoverRef} className={`noir-create__popover noir-create__countries noir-create__popover--${placement}${optionsPopup ? ' noir-create__popover--open' : ''}`} aria-hidden={!optionsPopup}>
        <input className='noir-create__search' type='text' placeholder='SEARCH COUNTRY' value={searchCountry} onChange={(event) => setSearchCountry(event.target.value)} />
        <ul className='noir-create__country-list'>
          {countries.map((country) => (
            <li key={country}>
              <button type='button' className={country === selectedCountry ? 'is-selected' : ''} name={name} value={country} onClick={selectCountry} onMouseEnter={() => nuicallback('hover')}>{country}</button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  )
}

export default Option
