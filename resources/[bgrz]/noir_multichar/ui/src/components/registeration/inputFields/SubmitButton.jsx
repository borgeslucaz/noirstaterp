import React from 'react'
import { nuicallback } from '../../../utils/nuicallback'

const SubmitButton = () => (
  <button type='submit' onMouseEnter={() => nuicallback('hover')} className='noir-create__submit'>
    <span>CREATE CHARACTER</span>
    <span className='noir-create__submit-arrow' aria-hidden='true'>→</span>
  </button>
)

export default SubmitButton
