import React, { useState, useEffect } from 'react'
import { Pipette } from 'lucide-react'

const border = (o = 0.06) => `1px solid rgba(255,255,255,${o})`
const bg     = (o = 0.03) => `rgba(255,255,255,${o})`

function hexToRgb(hex) {
  hex = hex.replace('#', '')
  if (hex.length === 3) hex = hex.split('').map(c => c + c).join('')
  const n = parseInt(hex, 16)
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 }
}

function rgbToHex({ r, g, b }) {
  return '#' + [r, g, b].map(v => v.toString(16).padStart(2, '0')).join('')
}

const PRESET_COLORS = [
  '#0d1116', '#1c1d21', '#32383d', '#585853', '#848988', '#c8c8c8', '#f5f5f5', '#ffffff',
  '#9a0000', '#c20012', '#da1918', '#b6111b', '#7b1a22', '#ff0000', '#ff4444', '#ff6666',
  '#001a7e', '#0b1e6f', '#253aa7', '#1f4ca8', '#214559', '#0066ff', '#4488ff', '#66aaff',
  '#00735f', '#00613a', '#304b30', '#18391e', '#2a310a', '#00cc66', '#22c55e', '#66ff99',
  '#f2ad30', '#f59e00', '#e2832b', '#cf6a23', '#ff6600', '#ffaa00', '#ffcc33', '#ffe066',
  '#8a4dbd', '#6b1f7b', '#9933cc', '#bb66ee', '#bf9b6e', '#dab46e', '#c2944e', '#d4a460',
]

export function ColorPicker({ label = 'Vehicle Color', selectedColor, onColorChange }) {
  const [hexInput, setHexInput] = useState(rgbToHex(selectedColor))

  useEffect(() => {
    setHexInput(rgbToHex(selectedColor))
  }, [selectedColor.r, selectedColor.g, selectedColor.b])

  const handleHexSubmit = (val) => {
    const clean = val.replace(/[^0-9a-fA-F#]/g, '')
    setHexInput(clean)
    const hex = clean.replace('#', '')
    if (hex.length === 6 || hex.length === 3) {
      onColorChange(hexToRgb(clean))
    }
  }

  const handleSlider = (channel, value) => {
    const next = { ...selectedColor, [channel]: parseInt(value) }
    onColorChange(next)
  }

  return (
    <div>
      <p style={{ fontSize: 10, fontWeight: 600, color: '#888', marginBottom: 8 }}>
        {label}
      </p>

      {/* Preview + Hex Input */}
      <div className="flex items-center gap-2" style={{ marginBottom: 10 }}>
        <div style={{
          width: 36, height: 36, borderRadius: 6,
          background: rgbToHex(selectedColor),
          border: border(0.15), flexShrink: 0,
        }} />
        <div className="flex items-center flex-1" style={{
          height: 32, borderRadius: 6, padding: '0 10px',
          background: bg(0.02), border: border(0.06),
        }}>
          <Pipette style={{ width: 10, height: 10, color: '#555', marginRight: 6, flexShrink: 0 }} />
          <input
            value={hexInput}
            onChange={e => handleHexSubmit(e.target.value)}
            placeholder="#FFFFFF"
            maxLength={7}
            style={{
              flex: 1, background: 'transparent', border: 'none', outline: 'none',
              fontSize: 11, color: '#ccc', caretColor: '#888',
              fontFamily: 'monospace', textTransform: 'uppercase',
            }}
          />
        </div>
      </div>

      {/* RGB Sliders */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 10 }}>
        {[
          { channel: 'r', label: 'R', accent: '#ef4444' },
          { channel: 'g', label: 'G', accent: '#22c55e' },
          { channel: 'b', label: 'B', accent: '#3b82f6' },
        ].map(({ channel, label, accent }) => (
          <div key={channel} className="flex items-center gap-2">
            <span style={{ fontSize: 9, fontWeight: 700, color: accent, width: 10, textAlign: 'center' }}>{label}</span>
            <input
              type="range"
              min={0} max={255}
              value={selectedColor[channel]}
              onChange={e => handleSlider(channel, e.target.value)}
              className="color-slider"
              style={{
                flex: 1, height: 4, appearance: 'none', background: `linear-gradient(to right, #111, ${accent})`,
                borderRadius: 2, outline: 'none', cursor: 'pointer',
              }}
            />
            <span style={{ fontSize: 9, color: '#555', width: 24, textAlign: 'right', fontFamily: 'monospace' }}>
              {selectedColor[channel]}
            </span>
          </div>
        ))}
      </div>

      {/* Preset Swatches */}
      <p style={{ fontSize: 9, color: '#444', marginBottom: 4 }}>Presets</p>
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(8, 1fr)',
        gap: 3,
      }}>
        {PRESET_COLORS.map((hex, i) => {
          const rgb = hexToRgb(hex)
          const isActive = rgb.r === selectedColor.r && rgb.g === selectedColor.g && rgb.b === selectedColor.b
          return (
            <button
              key={i}
              onClick={() => onColorChange(rgb)}
              style={{
                width: '100%', aspectRatio: '1', borderRadius: 4, border: 'none',
                background: hex, cursor: 'pointer',
                outline: isActive ? '2px solid rgba(255,255,255,0.7)' : '1px solid rgba(255,255,255,0.06)',
                outlineOffset: isActive ? -1 : 0,
              }}
            />
          )
        })}
      </div>
    </div>
  )
}
