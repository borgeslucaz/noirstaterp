import { useEffect, useLayoutEffect, useRef, useState } from 'react'

const VIEWPORT_MARGIN = 16
const POPOVER_GAP = 20

export const usePopoverPlacement = (open, onClose, { below = false } = {}) => {
  const anchorRef = useRef(null)
  const popoverRef = useRef(null)
  // O formulário fica à esquerda da tela, então o popover abre à direita dele; sem espaço,
  // abre embaixo.
  const [placement, setPlacement] = useState('right')

  useLayoutEffect(() => {
    if (!open) return undefined

    const updatePlacement = () => {
      const anchor = anchorRef.current
      const popover = popoverRef.current
      if (!anchor || !popover) return
      if (below) {
        setPlacement('below')
        return
      }

      // Abre à direita do formulário inteiro, não só do campo: senão o popover de um campo
      // da coluna da esquerda cobre a coluna da direita.
      const anchorRight = anchor.getBoundingClientRect().right
      const formRight = anchor.closest('form')?.getBoundingClientRect().right ?? anchorRight
      anchor.style.setProperty('--popover-shift', `${formRight - anchorRight}px`)

      const availableRight = window.innerWidth - formRight - VIEWPORT_MARGIN
      const required = popover.getBoundingClientRect().width + POPOVER_GAP
      setPlacement(availableRight >= required ? 'right' : 'below')
    }

    const frame = window.requestAnimationFrame(updatePlacement)
    window.addEventListener('resize', updatePlacement)
    return () => {
      window.cancelAnimationFrame(frame)
      window.removeEventListener('resize', updatePlacement)
    }
  }, [below, open])

  useEffect(() => {
    if (!open) return undefined

    const handleOutside = (event) => {
      if (!anchorRef.current?.contains(event.target)) onClose()
    }

    document.addEventListener('pointerdown', handleOutside)
    return () => document.removeEventListener('pointerdown', handleOutside)
  }, [onClose, open])

  return { anchorRef, popoverRef, placement }
}
