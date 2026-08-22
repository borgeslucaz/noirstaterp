import React from 'react'
import { nuicallback } from '../../../utils/nuicallback'

const ESCButton = ({ exitfunc }) => (
  <button type='button' className='noir-create__back' onMouseEnter={() => nuicallback('hover')} onClick={exitfunc}>
    <span className='noir-create__key'>ESC</span>
    <span>BACK</span>
  </button>
)

export default ESCButton
