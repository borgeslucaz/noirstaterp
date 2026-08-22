import React, { useEffect, useRef, useState } from 'react'
import Input from './inputFields/Input'
import { inputFields } from './inputFields/inputFields'
import Option from './inputFields/Option'
import SelectGender from './inputFields/SelectGender'
import RangeSlider from './inputFields/RangeSlider'
import SubmitButton from './inputFields/SubmitButton'
import DatePicker from './inputFields/DatePicker'
import ESCButton from './inputFields/ESCButton'
import { useNavigate } from 'react-router-dom'

import { useDispatch } from 'react-redux'
import { useSelector } from 'react-redux'

import { nuicallback } from '../../utils/nuicallback'

import { useConfig } from '../../providers/configprovider'
import { updatescreen } from '../../store/screen/screen'

const Register = () => {
  const [user, setUser] = useState({
    slot: 0,
    firstName: '',
    lastName: '',
    DOB: '',
    nationality: '',
    height: 50,
    gender: ''
  })
  const [dobVisible, setDobVisible] = useState(false);
  const [optionsPopup, setOptionsPopup] = useState(false);

  const ref = useRef();
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const { config } = useConfig();

  const scene = useSelector((state) => state.screen)


  const handleDOBToggle = () => {
    setOptionsPopup(false)
    setDobVisible(prev => !prev)
  }

  const handleOptionsPopup = () => {
    setDobVisible(false)
    setOptionsPopup(prev => !prev)
  }

  const handleChange = e => {
    if (['DOB'].includes(e.tag)) {
      return setUser({ ...user, DOB: e.value })
    }

    const { name, value } = e.target
    setUser({ ...user, [name]: value })
  }

  const handleSubmit = e => {
    e.preventDefault()
    nuicallback('CreateCharacter',user).then((response) => {
      if (response == true){
        dispatch(updatescreen(''))
      }
    });
  }

  const exit = () => {
    dispatch(updatescreen(''))
    nuicallback('exitcharactercreator').then((response) => {
       dispatch(updatescreen('characterselection'))
    })
  }


  useEffect(() => {

    const handlekey = (e) => {

      if (e.key === 'Escape' && scene == 'charactercreator') {
        exit();
      }
    }
  

    window.addEventListener('keydown',handlekey);
    return () => window.removeEventListener('keydown',handlekey);
  })



  const handleUseRef = () => {
    ref.current.focus()
  }


  useEffect(() => {
    handleUseRef()
    // dispatch(addplayer(players))

    const handlemessage = (event) => {
      switch (event.data.action) {
        case 'charactercreator':
          dispatch(updatescreen('charactercreator'))
          setUser({ ...user, slot: event.data.data })
          break
      }
    }

    window.addEventListener('message',handlemessage);
    return () => window.removeEventListener('message',handlemessage);

  }, [])


  return (
    <div
      className='flex flex-col items-end justify-center h-screen an '
      style={{display: scene == 'charactercreator' ? 'flex' : 'none'}}
      ref={ref}
      // onKeyDown={handlekey}
      tabIndex='0'
    >
      <div className='mr-[320px] flex flex-col gap-[7px] items-center scale-110 '>
        <h1 className='flex flex-col items-center text-center gap-2 text-white relative top-2'>
          <span className='text-[23px] tracking-[6px] uppercase text-[#ffffff86] font-bold  relative top-[17px] '>{config.Lang.create}</span>
          <span className='text-[36px] font-bold uppercase  text-[#FFFFFF] '>{config.Lang.character}</span>
        </h1>
        <p className='text-[#ffffffe0] font-bold text-[9px] w-[240px] uppercase text-center'>
        {config.Lang.description}
        </p>
        <form
          onSubmit={handleSubmit}
          className='flex flex-col w-[240px] items-center gap-4 mt-3 font-bold text-[14px]'
        >
          {inputFields.map(field => {
            if (['firstName', 'lastName'].includes(field.name)) {
              return (
                <Input
                  key={field.id}
                  name={field.name}
                  value={user[field.name]}
                  placeholder={config.Lang[field.name]}
                  handleChange={handleChange}
                />
              )
            } else if (['DOB'].includes(field.name)) {
              return (
                <DatePicker
                  key={field.name}
                  handleDate={handleDOBToggle}
                  dobVisible={dobVisible}
                  handleChange={handleChange}
                />
              )
            } else if (['nationality'].includes(field.name)) {
              return (
                <Option
                  key={field.id}
                  name={field.name}
                  handleChange={handleChange}
                  optionsPopup={optionsPopup}
                  handleOptionsPopup={handleOptionsPopup}
                />
              )
            } else if (['height'].includes(field.name)) {
              return (
                <RangeSlider
                  key={field.id}
                  height={user[field.name]}
                  handleChange={handleChange}
                />
              )
            } else if (['gender'].includes(field.name)) {
              return (
                <SelectGender
                  key={field.id}
                  gValue={user[field.name]}
                  handleChange={handleChange}
                />
              )
            }
          })}
          <SubmitButton/>
        </form>
      </div>
      <ESCButton  exitfunc={exit}  />
    </div>
  )
}

export default Register
