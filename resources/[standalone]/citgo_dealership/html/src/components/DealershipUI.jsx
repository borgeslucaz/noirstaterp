import React, { useMemo, useEffect, useRef, useCallback } from 'react'
import { CategorySidebar } from './CategorySidebar'
import { VehicleGrid } from './VehicleGrid'
import { VehicleDetail } from './VehicleDetail'
import { fetchNUI } from '../utils/fetchNUI'

const border = (o = 0.06) => `1px solid rgba(255,255,255,${o})`

export function DealershipUI({
  vehicles, categories, shopLabel,
  activeCategory, onCategoryChange,
  searchQuery, onSearchChange,
  sortMode, onSortChange,
  selectedVehicle, onSelectVehicle, onBack,
  primaryColor, onPrimaryColorChange,
  secondaryColor, onSecondaryColorChange, onToggleSecondary,
  secondaryColorPrice,
  plateText, onPlateChange, plateAvailable, onCheckPlate,
  purchasing, onPurchase, onClose,
  previewing, onPreview, onExitPreview,
  financeEnabled, financeInfo, financeLoading,
  onGetFinanceInfo, onFinance,
}) {
  const categoryVehicles = useMemo(() => {
    if (!activeCategory) return vehicles
    return vehicles.filter(v => v.category === activeCategory)
  }, [vehicles, activeCategory])

  const dragging = useRef(false)
  const lastX    = useRef(0)

  const handleMouseDown = useCallback((e) => {
    if (!previewing) return
    if (e.target.closest('[data-no-orbit]')) return
    dragging.current = true
    lastX.current = e.clientX
  }, [previewing])

  const handleMouseMove = useCallback((e) => {
    if (!dragging.current || !previewing) return
    const dx = (e.clientX - lastX.current) * 0.4
    lastX.current = e.clientX
    if (Math.abs(dx) > 0.1) {
      fetchNUI('camRotate', { dx })
    }
  }, [previewing])

  const handleMouseUp = useCallback(() => {
    dragging.current = false
  }, [])

  const handleWheel = useCallback((e) => {
    if (!previewing) return
    if (e.target.closest('[data-no-orbit]')) return
    const direction = e.deltaY < 0 ? 1 : -1
    fetchNUI('camZoom', { direction })
  }, [previewing])

  const handleKeyDown = useCallback((e) => {
    if (!previewing) return
    if (e.key === 'w' || e.key === 'W') {
      fetchNUI('camHeight', { delta: 0.15 })
    } else if (e.key === 's' || e.key === 'S') {
      fetchNUI('camHeight', { delta: -0.15 })
    }
  }, [previewing])

  useEffect(() => {
    window.addEventListener('mousedown', handleMouseDown)
    window.addEventListener('mousemove', handleMouseMove)
    window.addEventListener('mouseup', handleMouseUp)
    window.addEventListener('wheel', handleWheel)
    window.addEventListener('keydown', handleKeyDown)
    return () => {
      window.removeEventListener('mousedown', handleMouseDown)
      window.removeEventListener('mousemove', handleMouseMove)
      window.removeEventListener('mouseup', handleMouseUp)
      window.removeEventListener('wheel', handleWheel)
      window.removeEventListener('keydown', handleKeyDown)
    }
  }, [handleMouseDown, handleMouseMove, handleMouseUp, handleWheel, handleKeyDown])

  return (
    <div className="fixed inset-0 z-9998 bg-transparent pointer-events-none">

      {/* LEFT: Category sidebar — hidden during preview */}
      {!previewing && (
        <div
          data-no-orbit
          className="pointer-events-auto fixed left-5 top-5 z-9999 flex flex-col glass animate-enter"
          style={{ width: 260, maxHeight: 'calc(100vh - 40px)', borderRadius: 14, border: border(), boxShadow: '0 8px 40px rgba(0,0,0,0.7)', overflow: 'hidden' }}>
          <CategorySidebar
            categories={categories}
            vehicles={vehicles}
            activeCategory={activeCategory}
            onSelect={onCategoryChange}
            shopLabel={shopLabel}
          />
        </div>
      )}

      {/* RIGHT: Vehicles / Detail panel */}
      <div
        data-no-orbit
        className="pointer-events-auto fixed right-5 top-5 bottom-5 z-9999 flex flex-col glass animate-enter"
        style={{ width: 400, borderRadius: 14, border: border(), boxShadow: '0 8px 40px rgba(0,0,0,0.7)', overflow: 'hidden' }}>

        {selectedVehicle ? (
          <VehicleDetail
            vehicle={selectedVehicle}
            primaryColor={primaryColor}
            onPrimaryColorChange={onPrimaryColorChange}
            secondaryColor={secondaryColor}
            onSecondaryColorChange={onSecondaryColorChange}
            onToggleSecondary={onToggleSecondary}
            secondaryColorPrice={secondaryColorPrice}
            plateText={plateText}
            onPlateChange={onPlateChange}
            plateAvailable={plateAvailable}
            onCheckPlate={onCheckPlate}
            purchasing={purchasing}
            onPurchase={onPurchase}
            onBack={onBack}
            previewing={previewing}
            onPreview={onPreview}
            onExitPreview={onExitPreview}
            financeEnabled={financeEnabled}
            financeInfo={financeInfo}
            financeLoading={financeLoading}
            onGetFinanceInfo={onGetFinanceInfo}
            onFinance={onFinance}
          />
        ) : (
          <VehicleGrid
            vehicles={categoryVehicles}
            searchQuery={searchQuery}
            onSearchChange={onSearchChange}
            sortMode={sortMode}
            onSortChange={onSortChange}
            onSelect={onSelectVehicle}
          />
        )}
      </div>

      {/* Preview camera hints */}
      {previewing && (
        <div className="pointer-events-none fixed bottom-8 left-1/2 z-9999 animate-enter"
          style={{ transform: 'translateX(-50%)' }}>
          <div className="glass pointer-events-none" style={{
            padding: '8px 20px', borderRadius: 10, border: border(0.1),
          }}>
            <span style={{ fontSize: 10, color: '#888' }}>
              <span style={{ color: '#aaa', fontWeight: 600 }}>Drag</span> rotate &nbsp;·&nbsp;
              <span style={{ color: '#aaa', fontWeight: 600 }}>Scroll</span> zoom &nbsp;·&nbsp;
              <span style={{ color: '#aaa', fontWeight: 600 }}>W/S</span> height
            </span>
          </div>
        </div>
      )}
    </div>
  )
}
