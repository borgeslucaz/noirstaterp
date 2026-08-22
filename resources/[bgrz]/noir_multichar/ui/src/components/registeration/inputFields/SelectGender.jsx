import React, { useState } from 'react'
import OptionGender from './OptionGender'
import { nuicallback } from '../../../utils/nuicallback'

const SelectGender = ({ gValue, handleChange }) => {
  return (
    <div>
      <div className='flex justify-center gap-6'>
        {['Male', 'Female'].map(opt => (
          <OptionGender
            key={opt}
            gValue={gValue}
            value={opt}
            onclick={() => nuicallback('click')}
            handleChange={handleChange}
          />
        ))}
      </div>
    </div>
  )
}

export default SelectGender
