import React from 'react'
import { nuicallback } from '../../../utils/nuicallback'

const OptionGender = ({ gValue, value, handleChange }) => (
  <button
    type='button'
    className={`noir-create__segment${gValue === value ? ' noir-create__segment--active' : ''}`}
    name='gender'
    onMouseEnter={() => nuicallback('hover')}
    onClick={handleChange}
    value={value}
    aria-pressed={gValue === value}
  >
    {value.toUpperCase()}
  </button>
)

export default OptionGender
