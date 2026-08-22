import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './App.scss'
import Loading from './components/loading'



createRoot(document.getElementById('root')).render(
  <StrictMode>
    <Loading />
  </StrictMode>,
)
