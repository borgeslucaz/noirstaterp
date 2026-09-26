import React from 'react'
import OptionGender from './OptionGender'

// Valores continuam 'Male'/'Female': é o que o Lua compara para montar o gender do Qbox.
const labels = { Male: 'MASCULINO', Female: 'FEMININO' }

const SelectGender = ({ gValue, handleChange }) => (
  <div className='noir-create__field noir-create__tile noir-create__gender' role='group' aria-label='Gênero'>
    <span className='noir-create__label'>GÊNERO</span>
    <div className='noir-create__control noir-create__select'>
      <span className={gValue ? '' : 'noir-create__placeholder'}>{labels[gValue] || 'SELECIONE'}</span>
      <span className='noir-create__gender-options'>
        {['Male', 'Female'].map((option) => (
          <OptionGender key={option} gValue={gValue} value={option} label={labels[option]} handleChange={handleChange} />
        ))}
      </span>
    </div>
  </div>
)

export default SelectGender
