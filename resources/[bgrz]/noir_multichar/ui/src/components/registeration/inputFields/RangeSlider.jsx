import React from 'react'
import { nuicallback } from '../../../utils/nuicallback'
const RangeSlider = ({ height, handleChange }) => {
  return (
    <>
      <span className='text-xl text-center text-white mb-[-10px]'>{height}cm</span>
      <div className='flex items-center w-[100%] bg-[#ffffff62] hover:bg-[#ffffff88] h-[10px] relative'>
        <input
          type='range'
          min='1'
          max='300'
          className='appearance-none rounded bg-transparent w-full z-10 range-slider'
          name='height'
          onClick={() => nuicallback('click')}
          onMouseEnter={() => nuicallback('hover')}
          onChange={handleChange}
        />
        <div
          style={{ width: height / 3 + '%' }}
          className='absolute h-full bg-white'
        />
      </div>
    </>
  )
}

export default RangeSlider
