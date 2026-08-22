import React, { useState } from 'react'
import { monthNames } from '../../../utils/monthNames'
import {
  getNumberOfDaysInMonth,
  getYears,
  range
} from '../../../utils/dateHandler'
import { nuicallback } from '../../../utils/nuicallback'
import { useConfig } from '../../../providers/configprovider'
import calendericon from '../../../assets/dob.png'
const passCurrentYear = new Date().getFullYear()

const DatePicker = ({ handleDate, dobVisible, handleChange }) => {
  const { config } = useConfig();
  

  const [currentMonth, setCurrentMonth] = useState(new Date().getMonth())
  const [currentYear, setCurrentYear] = useState(passCurrentYear)
  const [currentDay, setCurrentDay] = useState(new Date().getUTCDate())
  const [buttonValue, setButtonValue] = useState(config.Lang.dob)


  const handleDateChange = () => {
    const dob = {
      tag: 'DOB',
      value: currentYear + '/' + currentDay + '/' + (currentMonth + 1)
    }

    handleChange(dob)
    setButtonValue(dob.value)
    handleDate()
    nuicallback('click')
  }

  return (
    <>
      <div
        className={`text-[13px] absolute right-[290px] top-[100px] flex flex-col bg-[rgba(0,0,0,0.5)] w-[230px] ${
          dobVisible ? 'max-h-full' : 'max-h-0'
        } overflow-hidden transition-all`}
      >
        <div className='flex justify-center items-center h-[400px]'>
          <div className='flex flex-col items-center'>
            <span className='text-white text-center mt-4'>{config.Lang.year}</span>
            <ul className='h-[340px] overflow-y-scroll border border-white m-1 p-1 scrollbar-thumb-white scrollbar-track-black scrollbar-thin'>
              {getYears(passCurrentYear).map(year => (
                (year > config.mindob && year < config.maxdob) &&
                <li key={year}>
                  <button
                    type='button'
                    onClick={() => {setCurrentYear(year); nuicallback('click')}}
                    className={`scrollbar-thumb-white scrollbar-track-black scrollbar-thin ${
                      year === currentYear ? 'text-black bg-white px-1' : 'text-white px-1'
                    }`}
                  >
                    {year}
                  </button>
                </li>
              ))}
            </ul>
          </div>
          <div className='flex flex-col items-center mt-4'>
            <span className='text-white'>{config.Lang.day}</span>
            <ul className='h-[340px] overflow-y-scroll border border-white m-1 p-1 scrollbar-thumb-white scrollbar-track-black scrollbar-thin'>
              {range(
                1,
                getNumberOfDaysInMonth(currentYear, currentMonth) + 1
              ).map(day => (
                <li key={day}>
                  <button
                    type='button'
                    className={`day  ${
                      day === currentDay ? 'text-black bg-white px-1' : 'text-white px-1'
                    }`}
                    onClick={() => {setCurrentDay(day); nuicallback('click')}}
                  >
                    {day}
                  </button>
                </li>
              ))}
            </ul>
          </div>
          <div className='flex flex-col items-center mt-4'>
            <span className='text-white'>{config.Lang.month}</span>
            <ul className='h-[340px] border border-white m-1 p-1'>
              {monthNames.map((month, i) => (
                <li key={i}>
                  <button
                    type='button'
                    onClick={() => {setCurrentMonth(i); nuicallback('click')}}
                    className={`month ${
                      i === currentMonth ? 'text-black bg-white px-1' : 'text-white px-1'
                    }`}
                  >
                    {month}
                  </button>
                </li>
              ))}
            </ul>
          </div>
        </div>
        <button
          onClick={handleDateChange}
          onMouseEnter={() => nuicallback('hover')}
          type='button'
          className='bg-slate-50 hover:bg-white text-black self-justify-end'
        >
          {config.Lang.done}
        </button>
      </div>
      <button
        type='button'
        onClick={handleDate}
        onMouseEnter={() => nuicallback('hover')}
        className='w-[100%] text-start  border-[1px] border-white focus:outline-none  text-white p-[6px] hover:bg-[rgba(0,0,0,0.8)]  bg-[rgba(0,0,0,0.5)] '
      >
        {buttonValue}
      </button>
      <img className='absolute ml-[210px] mt-[111px] w-[13px]' src={calendericon} alt="" />
    </>
  )
}

export default DatePicker
