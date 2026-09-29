import { configureStore } from '@reduxjs/toolkit'
import screenSlice  from './screen/screen'

export const store = configureStore({
  reducer: {screen: screenSlice},
})