import React from 'react'
import { nuicallback } from '../../../utils/nuicallback'

const Input = ({ name, label, value, handleChange }) => (
  <label className='noir-create__field'>
    <span className='noir-create__label'>{label}</span>
    <input
      className='noir-create__control'
      onChange={handleChange}
      type='text'
      name={name}
      value={value}
      onMouseEnter={() => nuicallback('hover')}
      spellCheck='false'
    />
  </label>
)

export default Input
