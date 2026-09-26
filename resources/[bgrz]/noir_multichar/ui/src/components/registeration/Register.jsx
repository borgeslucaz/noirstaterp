import React, { useCallback, useEffect, useRef, useState } from 'react'
import Input from './inputFields/Input'
import { inputFields } from './inputFields/inputFields'
import Option from './inputFields/Option'
import SelectGender from './inputFields/SelectGender'
import SubmitButton from './inputFields/SubmitButton'
import DatePicker from './inputFields/DatePicker'
import ESCButton from './inputFields/ESCButton'
import NoirLogo from './NoirLogo'
import { useDispatch, useSelector } from 'react-redux'
import { nuicallback } from '../../utils/nuicallback'
import { updatescreen } from '../../store/screen/screen'
import './registration.css'
import { CURTAIN_MS } from './curtain'

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

  // Saída com a cortina ao contrário: o formulário some, o jogo leva a câmera de volta para a
  // cena por trás do preto, e só então a cortina sobe e a seleção aparece.
  const [leaving, setLeaving] = useState('')
  const leavingRef = useRef(false)

  useEffect(() => {
    if (scene === 'charactercreator') {
      leavingRef.current = false
      setLeaving('')
    }
  }, [scene])

  const exit = useCallback(() => {
    if (leavingRef.current) return
    leavingRef.current = true
    setLeaving('out')
    nuicallback('exitcharactercreator').then(() => {
      setLeaving('lift')
      setTimeout(() => dispatch(updatescreen('characterselection')), CURTAIN_MS)
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
    <section className={`noir-create${leaving ? ' is-leaving' : ''}${leaving === 'lift' ? ' is-lifting' : ''}`} ref={ref} tabIndex='-1' aria-label='Novo personagem'>
      <div className='noir-create__curtain' />

      {/* Formulário e logo num bloco centralizado: em tela larga o vão entre eles não cresce. */}
      <div className='noir-create__stage'>
      <main className='noir-create__panel'>
        <div className='noir-create__heading'>
          <h1>NOVO PERSONAGEM</h1>
          <p>Preencha a identidade do seu personagem</p>
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

      <NoirLogo />
      </div>

      <ESCButton exitfunc={exit} />
    </section>
  )
}

export default Register
