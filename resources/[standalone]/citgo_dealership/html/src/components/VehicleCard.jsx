import React, { useState, useEffect } from 'react'

const border = (o = 0.06) => `1px solid rgba(255,255,255,${o})`
const bg     = (o = 0.03) => `rgba(255,255,255,${o})`

export const VehicleCard = React.memo(function VehicleCard({ vehicle, isSelected, onClick }) {
  const [src, setSrc]     = useState(null)
  const [error, setError] = useState(false)

  useEffect(() => {
    let cancelled = false
    setSrc(null)
    setError(false)
    if (!vehicle.photo) { setError(true); return }
    fetch(vehicle.photo)
      .then(r => { if (!r.ok) throw 0; return r.blob() })
      .then(b => { if (!cancelled) setSrc(URL.createObjectURL(b)) })
      .catch(() => { if (!cancelled) setError(true) })
    return () => { cancelled = true }
  }, [vehicle.photo])

  const priceStr = '$' + vehicle.price.toLocaleString()

  return (
    <div
      onClick={() => onClick(vehicle)}
      style={{
        borderRadius: 8, cursor: 'pointer', overflow: 'hidden',
        width: '100%', height: '100%',
        background: isSelected ? bg(0.07) : bg(0.015),
        border: isSelected ? '1px solid rgba(255,255,255,0.3)' : border(0.04),
        display: 'flex', flexDirection: 'column',
        transition: 'all 0.12s',
      }}>
      <div style={{
        position: 'relative', flex: '1 1 0', minHeight: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        overflow: 'hidden', background: 'rgba(0,0,0,0.15)',
      }}>
        {!src && !error && <div className="skeleton" style={{ position: 'absolute', inset: 0 }} />}
        {error && (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
            <span style={{ fontSize: 20 }}>🚗</span>
            <span style={{ fontSize: 8, color: '#555' }}>{vehicle.model}</span>
          </div>
        )}
        {src && (
          <img src={src} alt="" draggable={false} style={{
            position: 'absolute', inset: 0, width: '100%', height: '100%',
            objectFit: 'contain', padding: 6, transition: 'transform 0.2s',
          }}
          onMouseOver={e => e.currentTarget.style.transform = 'scale(1.06)'}
          onMouseOut={e  => e.currentTarget.style.transform = 'scale(1)'}
          />
        )}
        <span style={{
          position: 'absolute', bottom: 4, right: 4,
          fontSize: 9, fontWeight: 700, color: '#22c55e',
          background: 'rgba(0,0,0,0.7)', borderRadius: 4, padding: '2px 6px',
        }}>
          {priceStr}
        </span>
      </div>

      <div style={{
        padding: '6px 8px', flexShrink: 0,
        borderTop: '1px solid rgba(255,255,255,0.025)',
        background: 'rgba(0,0,0,0.2)',
      }}>
        <p style={{
          fontSize: 10, fontWeight: 600, color: '#ddd',
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        }}>
          {vehicle.name}
        </p>
        <p style={{
          fontSize: 8, color: '#555', marginTop: 1,
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        }}>
          {vehicle.brand}
        </p>
      </div>
    </div>
  )
})
