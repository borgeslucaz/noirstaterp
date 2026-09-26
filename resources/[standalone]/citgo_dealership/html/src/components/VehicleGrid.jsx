import React, { useState, useEffect, useRef, useMemo, useCallback } from 'react'
import { FixedSizeGrid as Grid } from 'react-window'
import { Search, X, ArrowUpDown } from 'lucide-react'
import { VehicleCard } from './VehicleCard'

const CARD_W = 170
const GAP    = 6
const ROW_H  = 160
const border = (o = 0.06) => `1px solid rgba(255,255,255,${o})`
const bg     = (o = 0.03) => `rgba(255,255,255,${o})`

const SORT_OPTIONS = [
  { id: 'name-asc',   label: 'Name A-Z' },
  { id: 'name-desc',  label: 'Name Z-A' },
  { id: 'price-asc',  label: 'Price Low' },
  { id: 'price-desc', label: 'Price High' },
]

function Cell({ columnIndex, rowIndex, style, data }) {
  const { items, COLS, onSelect } = data
  const idx = rowIndex * COLS + columnIndex
  if (idx >= items.length) return null
  const vehicle = items[idx]
  return (
    <div style={{
      ...style,
      left:   +style.left   + GAP,
      top:    +style.top    + GAP,
      width:  +style.width  - GAP,
      height: +style.height - GAP,
    }}>
      <VehicleCard vehicle={vehicle} onClick={onSelect} />
    </div>
  )
}

export function VehicleGrid({ vehicles, searchQuery, onSearchChange, sortMode, onSortChange, onSelect }) {
  const gridRef = useRef(null)
  const [gridSize, setGridSize] = useState({ width: 0, height: 0 })

  useEffect(() => {
    const measure = () => {
      if (gridRef.current) {
        const r = gridRef.current.getBoundingClientRect()
        setGridSize({ width: r.width, height: r.height })
      }
    }
    measure()
    const t = setTimeout(measure, 50)
    window.addEventListener('resize', measure)
    return () => { window.removeEventListener('resize', measure); clearTimeout(t) }
  }, [])

  const filtered = useMemo(() => {
    let list = vehicles
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase()
      list = list.filter(v =>
        v.name.toLowerCase().includes(q) ||
        v.brand.toLowerCase().includes(q) ||
        v.model.toLowerCase().includes(q)
      )
    }
    const sorted = [...list]
    switch (sortMode) {
      case 'name-asc':   sorted.sort((a, b) => a.name.localeCompare(b.name)); break
      case 'name-desc':  sorted.sort((a, b) => b.name.localeCompare(a.name)); break
      case 'price-asc':  sorted.sort((a, b) => a.price - b.price); break
      case 'price-desc': sorted.sort((a, b) => b.price - a.price); break
    }
    return sorted
  }, [vehicles, searchQuery, sortMode])

  const COLS = Math.max(1, Math.floor((gridSize.width - GAP) / (CARD_W + GAP)))
  const ROWS = Math.ceil(filtered.length / COLS)

  const itemData = useMemo(() => ({
    items: filtered, COLS, onSelect,
  }), [filtered, COLS, onSelect])

  const [sortOpen, setSortOpen] = useState(false)

  return (
    <div className="flex flex-col h-full">
      <div style={{ padding: '12px 14px 10px', flexShrink: 0 }}>
        <p style={{ fontSize: 14, fontWeight: 700, color: '#eee', letterSpacing: '-0.02em' }}>
          Vehicles
        </p>
        <p style={{ fontSize: 10, color: '#444', marginTop: 2 }}>
          {filtered.length} of {vehicles.length} vehicles
        </p>
      </div>

      <div style={{ height: 1, background: bg(0.04) }} />

      <div className="flex items-center gap-2" style={{ padding: '7px 12px' }}>
        <div className="flex items-center gap-2 flex-1" style={{ height: 30, borderRadius: 6, padding: '0 10px', background: bg(0.015), border: border(0.04) }}>
          <Search style={{ width: 11, height: 11, color: '#444', flexShrink: 0 }} />
          <input
            value={searchQuery}
            onChange={e => onSearchChange(e.target.value)}
            placeholder="Search name, brand, model..."
            style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', fontSize: 11, color: '#ccc', caretColor: '#888' }}
          />
          {searchQuery && (
            <button onClick={() => onSearchChange('')} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 0, display: 'flex' }}>
              <X style={{ width: 10, height: 10, color: '#555' }} />
            </button>
          )}
        </div>
        <div style={{ position: 'relative' }}>
          <button
            onClick={() => setSortOpen(!sortOpen)}
            style={{
              height: 30, padding: '0 10px', borderRadius: 6, fontSize: 10, fontWeight: 600,
              background: bg(0.04), border: border(0.06), cursor: 'pointer', color: '#888',
              display: 'flex', alignItems: 'center', gap: 4,
            }}>
            <ArrowUpDown style={{ width: 10, height: 10 }} />
            Sort
          </button>
          {sortOpen && (
            <div style={{
              position: 'absolute', top: 34, right: 0, zIndex: 100,
              background: 'rgba(14,14,16,0.97)', border: border(0.12),
              borderRadius: 8, padding: 4, minWidth: 120,
            }}>
              {SORT_OPTIONS.map(opt => (
                <button
                  key={opt.id}
                  onClick={() => { onSortChange(opt.id); setSortOpen(false) }}
                  style={{
                    width: '100%', padding: '6px 10px', borderRadius: 5, border: 'none',
                    background: sortMode === opt.id ? bg(0.08) : 'transparent',
                    color: sortMode === opt.id ? '#ddd' : '#777',
                    fontSize: 10, fontWeight: sortMode === opt.id ? 600 : 400,
                    cursor: 'pointer', textAlign: 'left',
                  }}>
                  {opt.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      <div style={{ height: 1, background: bg(0.04) }} />

      <div className="flex-1 overflow-hidden" ref={gridRef}>
        {filtered.length > 0 && gridSize.height > 0 ? (
          <Grid
            className="scrollbar-thin"
            columnCount={COLS}
            columnWidth={CARD_W + GAP}
            height={gridSize.height}
            rowCount={ROWS}
            rowHeight={ROW_H}
            width={gridSize.width}
            overscanRowCount={3}
            itemData={itemData}>
            {Cell}
          </Grid>
        ) : (
          <div className="h-full flex flex-col items-center justify-center gap-2">
            <Search style={{ width: 14, height: 14, color: '#2a2a2a' }} />
            <span style={{ fontSize: 10, color: '#444' }}>No vehicles found</span>
          </div>
        )}
      </div>
    </div>
  )
}
