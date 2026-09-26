import React, { useState, useEffect } from 'react'
import { ArrowLeft, Eye, EyeOff, ShoppingCart, CheckCircle, XCircle, Search, Check, X, CreditCard, TrendingUp, Loader2 } from 'lucide-react'
import { ColorPicker } from './ColorPicker'

const border = (o = 0.06) => `1px solid rgba(255,255,255,${o})`
const bg     = (o = 0.03) => `rgba(255,255,255,${o})`

function tierColor(tier) {
  switch (tier) {
    case 'Excellent': return '#22c55e'
    case 'Good':      return '#4ade80'
    case 'Fair':      return '#eab308'
    case 'Poor':      return '#f97316'
    case 'Bad':       return '#ef4444'
    default:          return '#888'
  }
}

export function VehicleDetail({
  vehicle,
  primaryColor, onPrimaryColorChange,
  secondaryColor, onSecondaryColorChange, onToggleSecondary,
  secondaryColorPrice,
  plateText, onPlateChange, plateAvailable, onCheckPlate,
  purchasing, onPurchase, onBack,
  previewing, onPreview, onExitPreview,
  financeEnabled, financeInfo, financeLoading,
  onGetFinanceInfo, onFinance,
}) {
  const [thumbSrc, setThumbSrc] = useState(null)
  const [thumbError, setThumbError] = useState(false)

  useEffect(() => {
    let cancelled = false
    setThumbSrc(null)
    setThumbError(false)
    if (!vehicle.photo) { setThumbError(true); return }
    fetch(vehicle.photo)
      .then(r => { if (!r.ok) throw 0; return r.blob() })
      .then(b => { if (!cancelled) setThumbSrc(URL.createObjectURL(b)) })
      .catch(() => { if (!cancelled) setThumbError(true) })
    return () => { cancelled = true }
  }, [vehicle.photo])

  const hasSecondary = secondaryColor !== null
  const surcharge = hasSecondary ? secondaryColorPrice : 0
  const totalPrice = vehicle.price + surcharge
  const priceStr = '$' + totalPrice.toLocaleString()

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div style={{ padding: '15px 16px 11px', flexShrink: 0 }}>
        <button
          onClick={onBack}
          style={{
            display: 'flex', alignItems: 'center', gap: 6,
            background: 'none', border: 'none', cursor: 'pointer',
            color: '#888', fontSize: 11, fontWeight: 500, padding: 0, marginBottom: 8,
          }}>
          <ArrowLeft style={{ width: 12, height: 12 }} />
          Back
        </button>
        <p style={{ fontSize: 16, fontWeight: 700, color: '#eee', letterSpacing: '-0.02em' }}>
          {vehicle.name}
        </p>
        <p style={{ fontSize: 11, color: '#444', marginTop: 3 }}>
          {vehicle.brand} · {vehicle.category}
        </p>
      </div>

      <div style={{ height: 1, background: bg(0.04) }} />

      {/* Scrollable content */}
      <div className="flex-1 overflow-y-auto scrollbar-thin" style={{ padding: '12px 16px' }}>

        {/* Thumbnail + Preview button */}
        <div style={{
          width: '100%', aspectRatio: '16/9', borderRadius: 8, overflow: 'hidden',
          background: 'rgba(0,0,0,0.2)', border: border(0.04),
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          marginBottom: 8, position: 'relative',
        }}>
          {!thumbSrc && !thumbError && <div className="skeleton" style={{ position: 'absolute', inset: 0 }} />}
          {thumbError && (
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
              <span style={{ fontSize: 28 }}>🚗</span>
              <span style={{ fontSize: 10, color: '#555' }}>{vehicle.model}</span>
            </div>
          )}
          {thumbSrc && (
            <img src={thumbSrc} alt="" draggable={false} style={{
              position: 'absolute', inset: 0, width: '100%', height: '100%',
              objectFit: 'contain', padding: 8,
            }} />
          )}
        </div>

        {/* Preview button */}
        <button
          onClick={previewing ? onExitPreview : onPreview}
          style={{
            width: '100%', height: 30, borderRadius: 6, marginBottom: 12,
            background: previewing ? 'rgba(239,68,68,0.15)' : bg(0.06),
            border: previewing ? '1px solid rgba(239,68,68,0.3)' : border(0.08),
            color: previewing ? '#ef4444' : '#aaa',
            fontSize: 11, fontWeight: 600, cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          }}>
          {previewing ? (
            <><EyeOff style={{ width: 12, height: 12 }} /> Exit Preview</>
          ) : (
            <><Eye style={{ width: 12, height: 12 }} /> Preview Vehicle</>
          )}
        </button>

        {/* Price */}
        <div className="flex items-center gap-2" style={{ marginBottom: 14 }}>
          <p style={{ fontSize: 18, fontWeight: 700, color: '#22c55e' }}>
            {priceStr}
          </p>
          {surcharge > 0 && (
            <span style={{ fontSize: 10, color: '#888', fontWeight: 500 }}>
              (includes +${secondaryColorPrice.toLocaleString()} secondary)
            </span>
          )}
        </div>

        <div style={{ height: 1, background: bg(0.04), margin: '0 0 12px' }} />

        {/* Primary Color */}
        <ColorPicker label="Primary Color" selectedColor={primaryColor} onColorChange={onPrimaryColorChange} />

        <div style={{ height: 1, background: bg(0.04), margin: '12px 0' }} />

        {/* Secondary Color Toggle + Picker */}
        <div>
          <div className="flex items-center gap-2" style={{ marginBottom: hasSecondary ? 8 : 0 }}>
            <button
              onClick={() => onToggleSecondary(!hasSecondary)}
              style={{
                width: 32, height: 18, borderRadius: 9, border: 'none', cursor: 'pointer',
                background: hasSecondary ? '#22c55e' : 'rgba(255,255,255,0.1)',
                position: 'relative', transition: 'background 0.15s',
              }}>
              <span style={{
                position: 'absolute', top: 2,
                left: hasSecondary ? 16 : 2,
                width: 14, height: 14, borderRadius: '50%',
                background: '#fff', transition: 'left 0.15s',
                boxShadow: '0 1px 3px rgba(0,0,0,0.3)',
              }} />
            </button>
            <span style={{ fontSize: 10, fontWeight: 600, color: '#888', flex: 1 }}>
              Secondary Color
            </span>
            <span style={{ fontSize: 9, color: hasSecondary ? '#22c55e' : '#444' }}>
              +${secondaryColorPrice.toLocaleString()}
            </span>
          </div>
          {hasSecondary && (
            <ColorPicker label="Secondary Color" selectedColor={secondaryColor} onColorChange={onSecondaryColorChange} />
          )}
        </div>

        <div style={{ height: 1, background: bg(0.04), margin: '12px 0' }} />

        {/* License Plate */}
        <div>
          <p style={{ fontSize: 10, fontWeight: 600, color: '#888', marginBottom: 6 }}>
            License Plate
          </p>
          <div className="flex items-center gap-2">
            <div className="flex items-center flex-1" style={{
              height: 32, borderRadius: 6, padding: '0 10px',
              background: bg(0.02), border: border(0.06),
            }}>
              <input
                value={plateText}
                onChange={e => onPlateChange(e.target.value)}
                placeholder="Custom plate (max 8)"
                maxLength={8}
                style={{
                  flex: 1, background: 'transparent', border: 'none', outline: 'none',
                  fontSize: 11, color: '#ccc', caretColor: '#888',
                  fontFamily: 'monospace', letterSpacing: '0.1em', textTransform: 'uppercase',
                }}
              />
            </div>
            <button
              onClick={onCheckPlate}
              disabled={!plateText.trim()}
              style={{
                height: 32, padding: '0 12px', borderRadius: 6, fontSize: 10, fontWeight: 600,
                background: plateText.trim() ? bg(0.06) : bg(0.02),
                border: border(0.06), cursor: plateText.trim() ? 'pointer' : 'default',
                color: plateText.trim() ? '#aaa' : '#444',
                display: 'flex', alignItems: 'center', gap: 4,
              }}>
              <Search style={{ width: 10, height: 10 }} />
              Check
            </button>
          </div>
          {plateAvailable !== null && (
            <div className="flex items-center gap-1" style={{ marginTop: 6 }}>
              {plateAvailable ? (
                <>
                  <CheckCircle style={{ width: 11, height: 11, color: '#22c55e' }} />
                  <span style={{ fontSize: 10, color: '#22c55e' }}>Plate available</span>
                </>
              ) : (
                <>
                  <XCircle style={{ width: 11, height: 11, color: '#ef4444' }} />
                  <span style={{ fontSize: 10, color: '#ef4444' }}>Plate taken</span>
                </>
              )}
            </div>
          )}
          <p style={{ fontSize: 9, color: '#333', marginTop: 4 }}>
            Leave empty for a random plate
          </p>
        </div>

        {/* Finance Section */}
        {financeEnabled && (
          <>
            <div style={{ height: 1, background: bg(0.04), margin: '12px 0' }} />
            <div>
              <div className="flex items-center gap-2" style={{ marginBottom: 8 }}>
                <CreditCard style={{ width: 12, height: 12, color: '#888' }} />
                <p style={{ fontSize: 10, fontWeight: 600, color: '#888' }}>Financing</p>
              </div>

              {!financeInfo && (
                <button
                  onClick={onGetFinanceInfo}
                  disabled={financeLoading}
                  style={{
                    width: '100%', height: 30, borderRadius: 6,
                    background: bg(0.06), border: border(0.08),
                    color: financeLoading ? '#555' : '#aaa',
                    fontSize: 11, fontWeight: 600, cursor: financeLoading ? 'default' : 'pointer',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
                  }}>
                  {financeLoading ? (
                    <><Loader2 style={{ width: 12, height: 12, animation: 'spin 1s linear infinite' }} /> Checking...</>
                  ) : (
                    <><TrendingUp style={{ width: 12, height: 12 }} /> Check Financing Eligibility</>
                  )}
                </button>
              )}

              {financeInfo && !financeInfo.available && (
                <div style={{
                  padding: '8px 10px', borderRadius: 6,
                  background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.15)',
                }}>
                  <div className="flex items-center gap-1.5">
                    <XCircle style={{ width: 11, height: 11, color: '#ef4444' }} />
                    <span style={{ fontSize: 10, fontWeight: 600, color: '#ef4444' }}>Not Eligible</span>
                  </div>
                  <p style={{ fontSize: 9, color: '#888', marginTop: 4 }}>{financeInfo.reason}</p>
                </div>
              )}

              {financeInfo && financeInfo.available && (
                <div style={{
                  padding: '10px', borderRadius: 6,
                  background: bg(0.03), border: border(0.06),
                }}>
                  <div className="flex items-center justify-between" style={{ marginBottom: 8 }}>
                    <span style={{ fontSize: 10, color: '#888' }}>Credit Score</span>
                    <span style={{ fontSize: 11, fontWeight: 700, color: '#eee' }}>{financeInfo.score}</span>
                  </div>
                  <div className="flex items-center justify-between" style={{ marginBottom: 4 }}>
                    <span style={{ fontSize: 10, color: '#888' }}>Tier</span>
                    <span style={{ fontSize: 10, fontWeight: 600, color: tierColor(financeInfo.tier) }}>{financeInfo.tier}</span>
                  </div>
                  <div className="flex items-center justify-between" style={{ marginBottom: 4 }}>
                    <span style={{ fontSize: 10, color: '#888' }}>Interest Rate</span>
                    <span style={{ fontSize: 10, fontWeight: 600, color: '#ccc' }}>{financeInfo.rate}%</span>
                  </div>
                  <div className="flex items-center justify-between" style={{ marginBottom: 4 }}>
                    <span style={{ fontSize: 10, color: '#888' }}>Interest</span>
                    <span style={{ fontSize: 10, fontWeight: 600, color: '#ef4444' }}>+${Math.floor(financeInfo.interest).toLocaleString()}</span>
                  </div>
                  <div style={{ height: 1, background: bg(0.06), margin: '6px 0' }} />
                  <div className="flex items-center justify-between" style={{ marginBottom: 4 }}>
                    <span style={{ fontSize: 10, color: '#888' }}>Total Owed</span>
                    <span style={{ fontSize: 11, fontWeight: 700, color: '#eee' }}>${Math.floor(financeInfo.totalOwed).toLocaleString()}</span>
                  </div>
                  <div className="flex items-center justify-between" style={{ marginBottom: 4 }}>
                    <span style={{ fontSize: 10, color: '#888' }}>Duration</span>
                    <span style={{ fontSize: 10, fontWeight: 600, color: '#ccc' }}>{financeInfo.duration} days</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span style={{ fontSize: 10, color: '#888' }}>Daily Payment</span>
                    <span style={{ fontSize: 11, fontWeight: 700, color: '#22c55e' }}>${Math.floor(financeInfo.dailyPayment).toLocaleString()}/day</span>
                  </div>
                </div>
              )}
            </div>
          </>
        )}
      </div>

      {/* Bottom bar */}
      <div style={{ height: 1, background: bg(0.04) }} />
      <div className="flex items-center gap-2 shrink-0" style={{ padding: '8px 12px' }}>
        <span style={{ flex: 1 }} />
        {financeEnabled && financeInfo?.available && (
          <button
            onClick={onFinance}
            disabled={purchasing}
            className="flex items-center justify-center gap-1.5 cursor-pointer"
            style={{
              height: 32, padding: '0 16px', borderRadius: 7,
              fontSize: 11, fontWeight: 700,
              background: purchasing ? '#333' : 'rgba(34,197,94,0.15)',
              color: purchasing ? '#666' : '#22c55e',
              border: '1px solid rgba(34,197,94,0.3)',
            }}>
            <CreditCard style={{ width: 11, height: 11 }} />
            {purchasing ? 'Processing...' : 'Finance'}
          </button>
        )}
        <button
          onClick={onPurchase}
          disabled={purchasing}
          className="flex items-center justify-center gap-1.5 cursor-pointer"
          style={{
            height: 32, padding: '0 20px', borderRadius: 7,
            fontSize: 12, fontWeight: 700,
            background: purchasing ? '#333' : '#f5f5f5',
            color: purchasing ? '#666' : '#000',
            border: 'none',
          }}>
          <Check style={{ width: 11, height: 11 }} strokeWidth={3} />
          {purchasing ? 'Processing...' : `Purchase — ${priceStr}`}
        </button>
        <button
          onClick={onBack}
          className="flex items-center justify-center gap-1.5 cursor-pointer"
          style={{
            height: 32, padding: '0 16px', borderRadius: 7,
            fontSize: 12, fontWeight: 600,
            background: 'transparent', color: '#666',
            border: border(0.12),
          }}>
          <X style={{ width: 10, height: 10 }} />
          Cancel
        </button>
      </div>
    </div>
  )
}
