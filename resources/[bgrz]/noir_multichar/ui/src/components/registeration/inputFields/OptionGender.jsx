import React from 'react'
import { nuicallback } from '../../../utils/nuicallback'

const OptionGender = ({gValue, value, handleChange}) => {
  return (

<>
<input
      type='button'
      className={`w-[6rem] py-1   hover:text-black  border border-3px border-white ${
        gValue === value ? 'text-black  bg-[#ffffff] ' : 'bg-[rgba(0,0,0,0.5)] text-white hover:bg-[#ffffff]'
      } `}
      name='gender'
      onMouseEnter={() => nuicallback('hover')}
      onClick={handleChange}
      value={value}
    />
</>

  )
}

export default OptionGender
