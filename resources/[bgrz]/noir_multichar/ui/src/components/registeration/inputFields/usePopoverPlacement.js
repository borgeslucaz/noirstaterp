import { useEffect, useLayoutEffect, useRef, useState } from 'react'

const VIEWPORT_MARGIN = 16
const POPOVER_GAP = 20

export const usePopoverPlacement = (open, onClose) => {
  const anchorRef = useRef(null)
  const popoverRef = useRef(null)
  const [placement, setPlacement] = useState('left')

  useLayoutEffect(() => {
    if (!open) return undefined

    const updatePlacement = () => {
      const anchor = anchorRef.current
      const popover = popoverRef.current
      if (!anchor || !popover) return

      const availableLeft = anchor.getBoundingClientRect().left - VIEWPORT_MARGIN
      const requiredLeft = popover.getBoundingClientRect().width + POPOVER_GAP
      setPlacement(availableLeft >= requiredLeft ? 'left' : 'below')
    }

    const frame = window.requestAnimationFrame(updatePlacement)
    window.addEventListener('resize', updatePlacement)
    return () => {
      window.cancelAnimationFrame(frame)
      window.removeEventListener('resize', updatePlacement)
    }
  }, [open])

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
