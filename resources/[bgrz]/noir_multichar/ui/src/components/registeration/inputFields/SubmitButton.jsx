import React from 'react'
import plus from '../../../assets/plus.svg'
import { nuicallback } from '../../../utils/nuicallback'
const SubmitButton = () => {
  
  
  return (
    <button
      type='submit'
      onMouseEnter={() => nuicallback('hover')}
      className='border w-[110px] p-1    flex justify-center hover:bg-[rgba(255,255,255,0.8)] bg-[rgba(255,255,255,1.0)]'
    >
      <img  src={plus} alt='plus' className='w-[25px] invert' />
    </button>
  )
}

export default SubmitButton
