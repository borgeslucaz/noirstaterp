import React, { useState } from 'react'
import { countriesList } from '../../../utils/coutries'
import { nuicallback } from '../../../utils/nuicallback'
import { useConfig } from '../../../providers/configprovider'
import arrow from '../../../assets/arrow.png'

const Option = ({ name, handleChange, optionsPopup, handleOptionsPopup }) => {
  const [selectedCountry, setSelecetedCountry] = useState('')
  const [searchCountry, setSearchCountry] = useState('')
  const handleSelectCountry = e => {
    setSelecetedCountry(e.target.value)
    handleChange(e)
    handleOptionsPopup()
    nuicallback('click')
  }

  const { config } = useConfig();

  const handleSearch = e => setSearchCountry(e.target.value)

  return (
    <>
      <ul
        className={`absolute right-[290px] w-[260px] bg-[rgba(0,0,0,0.5)] border border-1px border-white ${
          optionsPopup ? 'max-h-[300px]' : 'max-h-[0] invisible'
        } transition-all overflow-y-scroll
        scrollbar-thumb-white scrollbar-track-black scrollbar-thin`}
      >
        <li>
          <input
            type='text'
            placeholder={config.Lang.searchcountry}
            onChange={handleSearch}
            className='bg-black text-white w-full pl-1 focus:outline-none '
          />
        </li>
        {countriesList
          .filter(c => {
            if (
              c.toLocaleLowerCase().includes(searchCountry.toLocaleLowerCase())
            ) {
              return c
            }
            return ''
          })
          .map(c => (
            <li className='text-white hover:text-black hover:bg-white' key={c}>
              <button
                onClick={handleSelectCountry}
                onMouseEnter={() => nuicallback('hover')}
                name={name}
                value={c}
                type='button'
                className='text-start p-1 w-full'
              >
                {c}
              </button>
            </li>
          ))}
      </ul>
      <button
        type='button'
        onClick={handleOptionsPopup}
  onMouseEnter={() => nuicallback('hover')}
        className='text-start w-[100%]  border-[1px] border-white focus:outline-none  text-white p-[6px] hover:bg-[rgba(0,0,0,0.8)] bg-[rgba(0,0,0,0.5)]'
      >
        {selectedCountry || config.Lang.nationality}
      </button>

       <img style={{transform: optionsPopup ? 'rotate(90deg)' : 'rotate(0deg)'}} className='absolute ml-[210px] mt-[162px] w-4' src={arrow} alt="" />
    </>
  )
}

export default Option
