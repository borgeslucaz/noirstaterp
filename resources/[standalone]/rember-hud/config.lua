Config = {}

-- =============================================================================
-- REMBER HUD — WHITE-LABEL SETTINGS
-- This file IS the product. Reskin, reposition, and restyle the entire HUD from
-- here — you never need to touch the UI code. Flip components on/off, change a
-- metric's `style` to instantly restyle it, retheme with one accent color.
-- =============================================================================

Config.Game      = 'gta5'          -- 'gta5' (FiveM) | 'rdr3' (RedM). Selects which
                                   -- native stats are read. RDR2 has no armor and
                                   -- reads health/stamina as "cores" (see client.lua).
Config.Position  = 'bottom-right'  -- bottom-left | bottom-right | top-left | top-right
Config.Scale     = 1.0             -- overall HUD size multiplier
Config.SpeedUnit  = 'mph'          -- mph | kmh
Config.UpdateMs   = 150            -- native value refresh rate (ms)
Config.LayoutVersion = 2           -- bumps once to apply the compact default layout

Config.Theme = {
  accent     = '#c8702f',          -- your brand accent (numbers, highlights)
  panelAlpha = 0.55,               -- background panel opacity (0 = fully transparent)
}

-- =============================================================================
-- COMPONENT LIBRARY
-- Every gauge ships here, ready to go. To turn one on/off, flip `enabled`.
-- To restyle a metric, change `style`. To rearrange, change `order`.
--
--   style : 'radial'  round ring gauge
--           'segment' segmented ring (ticks light up)
--           'bar'     horizontal bar
--           'vbar'    vertical bar
--           'pill'    icon + number pill
--           'text'    big number (e.g. speedometer)
--   flags : hideAtZero  hide while value is 0   (e.g. armor, voice)
--           hideAtFull  hide while value is max (e.g. oxygen)
--           vehicleOnly show only while in a vehicle (e.g. speed)
-- =============================================================================
Config.Components = {
  -- ── enabled demo set ──────────────────────────────────────────────────────
  -- Compact 3 × 3 block in the lower-right. `pos` is the center in screen %.
  { enabled = true,  key = 'health',  style = 'radial',  icon = '❤',  color = '#e4544a', max = 100, order = 1, pos = { x = 82, y = 79 } },
  { enabled = true,  key = 'armor',   style = 'radial',  icon = '🛡',  color = '#4f83cc', max = 100, order = 2, hideAtZero = true, pos = { x = 88, y = 79 } },
  { enabled = true,  key = 'hunger',  style = 'segment', icon = '🍔', color = '#e0a341', max = 100, order = 3, segments = 10, pos = { x = 94, y = 79 } },
  { enabled = true,  key = 'thirst',  style = 'segment', icon = '💧', color = '#3fb0e0', max = 100, order = 4, segments = 10, pos = { x = 82, y = 86 } },
  { enabled = true,  key = 'stamina', style = 'bar',     icon = '⚡', color = '#f0c04a', max = 100, order = 5, pos = { x = 89, y = 86 } },
  { enabled = true,  key = 'voice',   style = 'pill',    icon = '🎤', color = '#4fd18b', max = 100, order = 6, hideAtZero = true, pos = { x = 95, y = 87 } },
  -- Vehicle-only speedometer remains part of the same block.
  { enabled = true,  key = 'speed',   style = 'text',    icon = '',   color = '#f4efe7', max = 220, order = 7, vehicleOnly = true, pos = { x = 88, y = 93 } },

  -- ── extra sample gauges — shipped ready; flip enabled = true to use ────────
  { enabled = true,  key = 'stress',  style = 'vbar',    icon = '🧠', color = '#b072d0', max = 100, order = 8, pos = { x = 82, y = 93 } },
  { enabled = false, key = 'oxygen',  style = 'radial',  icon = '🫁', color = '#7fd0e0', max = 100, order = 9, hideAtFull = true },
  { enabled = false, key = 'stamina', style = 'vbar',    icon = '⚡', color = '#f0c04a', max = 100, order = 10 }, -- same metric, alt style
  { enabled = false, key = 'health',  style = 'segment', icon = '❤',  color = '#e4544a', max = 100, order = 11, segments = 12 }, -- alt style
}
