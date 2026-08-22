import React, { useCallback, useEffect, useRef, useState } from 'react'
import Input from './inputFields/Input'
import { inputFields } from './inputFields/inputFields'
import Option from './inputFields/Option'
import SelectGender from './inputFields/SelectGender'
import SubmitButton from './inputFields/SubmitButton'
import DatePicker from './inputFields/DatePicker'
import ESCButton from './inputFields/ESCButton'
import { useDispatch, useSelector } from 'react-redux'
import { nuicallback } from '../../utils/nuicallback'
import { updatescreen } from '../../store/screen/screen'
import './registration.css'

const Register = () => {
  const [user, setUser] = useState({
    slot: 0,
    firstName: '',
    lastName: '',
    DOB: '',
    nationality: '',
    gender: ''
  })
  const [dobVisible, setDobVisible] = useState(false)
  const [optionsPopup, setOptionsPopup] = useState(false)
  const ref = useRef()
  const dispatch = useDispatch()
  const scene = useSelector((state) => state.screen)

  const closeDate = useCallback(() => setDobVisible(false), [])
  const closeOptions = useCallback(() => setOptionsPopup(false), [])

  const handleDOBToggle = useCallback(() => {
    setOptionsPopup(false)
    setDobVisible((current) => !current)
  }, [])

  const handleOptionsPopup = useCallback(() => {
    setDobVisible(false)
    setOptionsPopup((current) => !current)
  }, [])

  const handleChange = (event) => {
    if (event.tag === 'DOB') {
      setUser((current) => ({ ...current, DOB: event.value }))
      return
    }

    const { name, value } = event.target
    setUser((current) => ({ ...current, [name]: value }))
  }

  const handleSubmit = (event) => {
    event.preventDefault()
    nuicallback('CreateCharacter', user).then((response) => {
      if (response === true) dispatch(updatescreen(''))
    })
  }

  const exit = useCallback(() => {
    dispatch(updatescreen(''))
    nuicallback('exitcharactercreator').then(() => {
      dispatch(updatescreen('characterselection'))
    })
  }, [dispatch])

  useEffect(() => {
    const handleKey = (event) => {
      if (event.key !== 'Escape' || scene !== 'charactercreator') return

      if (dobVisible || optionsPopup) {
        event.preventDefault()
        closeDate()
        closeOptions()
        return
      }

      exit()
    }

    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [closeDate, closeOptions, dobVisible, exit, optionsPopup, scene])

  useEffect(() => {
    const handleMessage = (event) => {
      if (event.data.action === 'charactercreator') {
        dispatch(updatescreen('charactercreator'))
        setUser((current) => ({ ...current, slot: event.data.data }))
      }
    }

    window.addEventListener('message', handleMessage)
    return () => window.removeEventListener('message', handleMessage)
  }, [dispatch])

  useEffect(() => {
    if (scene === 'charactercreator') ref.current?.focus()
  }, [scene])

  if (scene !== 'charactercreator') return null

  return (
    <section className='noir-create' ref={ref} tabIndex='-1' aria-label='Create character'>
      <div className='noir-create__vignette' />
      <header className='noir-brand'>
        <span className='noir-brand__mark'>◇</span>
        <div><strong>NOIR STATE</strong><small>ROLEPLAY</small></div>
      </header>

      <main className='noir-create__panel'>
        <div className='noir-create__heading'>
          <span className='noir-create__section'>02</span>
          <h1>CREATE CHARACTER</h1>
          <p>CREATE YOUR STORY</p>
          <div className='noir-create__divider' />
        </div>

        <form className='noir-create__form' onSubmit={handleSubmit} autoComplete='off'>
          {inputFields.map((field) => {
            if (['firstName', 'lastName'].includes(field.name)) {
              return <Input key={field.id} name={field.name} value={user[field.name]} label={field.label} handleChange={handleChange} />
            }
            if (field.name === 'DOB') {
              return <DatePicker key={field.id} handleDate={handleDOBToggle} closeDate={closeDate} dobVisible={dobVisible} handleChange={handleChange} />
            }
            if (field.name === 'nationality') {
              return <Option key={field.id} name={field.name} handleChange={handleChange} optionsPopup={optionsPopup} handleOptionsPopup={handleOptionsPopup} closeOptions={closeOptions} />
            }
            if (field.name === 'gender') {
              return <SelectGender key={field.id} gValue={user[field.name]} handleChange={handleChange} />
            }
            return null
          })}
          <SubmitButton />
        </form>
      </main>

      <ESCButton exitfunc={exit} />
    </section>
  )
}

export default Register
