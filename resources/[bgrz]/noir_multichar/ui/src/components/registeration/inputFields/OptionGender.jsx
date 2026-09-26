import React from 'react'
import { nuicallback } from '../../../utils/nuicallback'

const icons = {
  Male: <path d='M12 2a2 2 0 1 1 0 4 2 2 0 0 1 0-4Zm-2.5 5.5h5A1.5 1.5 0 0 1 16 9v5h-1.6v8h-4.8v-8H8V9a1.5 1.5 0 0 1 1.5-1.5Z' />,
  Female: <path d='M12 2a2 2 0 1 1 0 4 2 2 0 0 1 0-4Zm-2 5.5h4c.7 0 1.3.5 1.5 1.1L17.5 16H15v6h-2v-5h-2v5H9v-6H6.5l2-7.4c.2-.6.8-1.1 1.5-1.1Z' />,
}

const OptionGender = ({ gValue, value, label, handleChange }) => (
  <button
    type='button'
    className={`noir-create__gender-option${gValue === value ? ' is-active' : ''}`}
    name='gender'
    onMouseEnter={() => nuicallback('hover')}
    onClick={() => handleChange({ target: { name: 'gender', value } })}
    aria-pressed={gValue === value}
    aria-label={label}
    title={label}
  >
    <svg viewBox='0 0 24 24' aria-hidden='true'>{icons[value]}</svg>
  </button>
)

export default OptionGender
