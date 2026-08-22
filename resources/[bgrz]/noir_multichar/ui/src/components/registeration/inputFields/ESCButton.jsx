import React from 'react'
import { useConfig } from '../../../providers/configprovider'
import { nuicallback } from '../../../utils/nuicallback'

const ESCButton = (data) => {
  const { config } = useConfig();
  return (
    <div className='flex items-center justify-center gap-2 absolute bottom-[35px] right-[45px]'>
      <div
      onMouseEnter={() => nuicallback('hover')}
      onClick={data.exitfunc}
        className=' text-black text-[14px]  px-[10px] font-bold bg-white hover:bg-slate-50'
      >
        {config.Lang.esc}
      </div>
      <span className='text-white text-[14px]'>{config.Lang.back}</span>
    </div>
  )
}

export default ESCButton
