import { useCallback, useEffect, useState } from "react"

export const useKeyPress = targetKey => {
  const [keyPressed, setKeyPressed] = useState(false)

  const keyToggler = useCallback(
    toggle => ({ key }) => {
      if (key === targetKey) {
        setKeyPressed(toggle)
      }
    },
    [targetKey]
  )

  const downHandler = keyToggler(true)
  const upHandler = keyToggler(false)

  useEffect(() => {
    window.addEventListener("keydown", downHandler)
    window.addEventListener("keyup", upHandler)

    return () => {
      window.removeEventListener("keydown", downHandler)
      window.removeEventListener("keyup", upHandler)
    }
  }, [downHandler, upHandler])

  return keyPressed
}

export default useKeyPress
