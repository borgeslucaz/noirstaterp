import React from 'react'
import { Car, Truck, Bike, Plane, Ship, Gauge, ChevronRight, LayoutGrid } from 'lucide-react'

const bg = (o = 0.03) => `rgba(255,255,255,${o})`

const CATEGORY_ICONS = {
  compacts: Car, sedans: Car, suvs: Truck, coupes: Car,
  sports: Gauge, sportsclassic: Car, sportsclassics: Car,
  super: Gauge, muscle: Car, offroad: Truck,
  motorcycles: Bike, vans: Truck, commercial: Truck,
  industrial: Truck, utility: Truck, openwheel: Gauge,
  cycles: Bike, boats: Ship, helicopters: Plane, planes: Plane,
  military: Truck, emergency: Car, service: Car, suv: Truck,
}

const CATEGORY_LABELS = {
  compacts: 'Compacts', sedans: 'Sedans', suvs: 'SUVs', suv: 'SUVs',
  coupes: 'Coupes', sports: 'Sports', sportsclassic: 'Sports Classic',
  sportsclassics: 'Sports Classic', super: 'Super', muscle: 'Muscle',
  offroad: 'Off-Road', motorcycles: 'Motorcycles', vans: 'Vans',
  commercial: 'Commercial', industrial: 'Industrial', utility: 'Utility',
  openwheel: 'Open Wheel', cycles: 'Cycles', boats: 'Boats',
  helicopters: 'Helicopters', planes: 'Planes', military: 'Military',
  emergency: 'Emergency', service: 'Service',
}

function CategoryItem({ icon: Icon, label, active, onClick, count }) {
  return (
    <button
      onClick={onClick}
      style={{
        width: '100%', display: 'flex', alignItems: 'center', gap: 11,
        padding: '8px 16px',
        background: active ? bg(0.07) : 'transparent',
        border: 'none',
        borderLeft: active ? '2px solid rgba(255,255,255,0.35)' : '2px solid transparent',
        cursor: 'pointer', textAlign: 'left',
      }}>
      {Icon && <Icon style={{ width: 14, height: 14, color: active ? '#bbb' : '#484848', flexShrink: 0 }} />}
      <span style={{ fontSize: 13, fontWeight: active ? 600 : 400, color: active ? '#e0e0e0' : '#727272', flex: 1 }}>
        {label}
      </span>
      {count != null && (
        <span style={{ fontSize: 9, color: '#444', flexShrink: 0 }}>{count}</span>
      )}
      {active && (
        <span style={{
          width: 6, height: 6, borderRadius: '50%',
          background: '#22c55e', boxShadow: '0 0 6px rgba(34,197,94,0.5)', flexShrink: 0,
        }} />
      )}
    </button>
  )
}

export function CategorySidebar({ categories, vehicles, activeCategory, onSelect, shopLabel }) {
  const counts = {}
  vehicles.forEach(v => { counts[v.category] = (counts[v.category] || 0) + 1 })

  return (
    <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ padding: '15px 16px 11px', flexShrink: 0 }}>
        <p style={{ fontSize: 16, fontWeight: 700, color: '#eee', letterSpacing: '-0.02em' }}>
          {shopLabel}
        </p>
        <p style={{ fontSize: 11, color: '#444', marginTop: 3 }}>
          Browse available vehicles
        </p>
      </div>
      <div style={{ height: 1, background: 'rgba(255,255,255,0.04)' }} />

      <div className="scrollbar-thin" style={{ flex: 1, overflowY: 'auto', paddingBottom: 10, paddingTop: 6 }}>
        <CategoryItem
          icon={LayoutGrid}
          label="All Vehicles"
          active={activeCategory === null}
          onClick={() => onSelect(null)}
          count={vehicles.length}
        />

        {categories.map(cat => {
          const Icon = CATEGORY_ICONS[cat] || Car
          const label = CATEGORY_LABELS[cat] || cat.charAt(0).toUpperCase() + cat.slice(1)
          return (
            <CategoryItem
              key={cat}
              icon={Icon}
              label={label}
              active={activeCategory === cat}
              onClick={() => onSelect(cat)}
              count={counts[cat] || 0}
            />
          )
        })}
      </div>
    </div>
  )
}
