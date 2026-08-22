import React from 'react'
import OptionGender from './OptionGender'

const SelectGender = ({ gValue, handleChange }) => (
  <fieldset className='noir-create__field noir-create__gender'>
    <legend className='noir-create__label'>GENDER</legend>
    <div className='noir-create__segments'>
      {['Male', 'Female'].map((option) => (
        <OptionGender key={option} gValue={gValue} value={option} handleChange={handleChange} />
      ))}
    </div>
  </fieldset>
)

export default SelectGender
