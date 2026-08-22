import React from 'react'
import { nuicallback } from '../../../utils/nuicallback'
const Input = ({ name, placeholder, value, handleChange }) => {
  return (
    <input
      onChange={handleChange}
      type='text'
      name={name}
      placeholder={placeholder}
      value={value}
 onMouseEnter={() => nuicallback('hover')}
      className='border-[1px] w-[100%] border-white focus:outline-none hover:bg-[rgba(0,0,0,0.8)] bg-[rgba(0,0,0,0.5)] text-white placeholder:text-white p-[6px]'
    />
  )
}

export default Input
