import styled, { css } from 'styled-components'

export const PickerWrapper = styled.div`
  border: 2px solid white;
  width: 300px
`

export const Header = styled.div`
  display: flex;
  justify-content: space-between;
  align-items: center;
  background-color: rgba(0,0,0,0.5);
  color: white;
`

export const Body = styled.div`
  padding: 5px;
  background-color: rgba(0,0,0,0.5);
  color: white;
`

export const SevenColGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(7, 1fr);
`