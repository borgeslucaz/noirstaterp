# noir_houserobbery

Tier 1 residential burglary for Noir/Qbox. A contract is requested through
`noir_burnerphone`, reserves one of six configured houses, and uses a private
routing bucket. Small loot enters the player inventory; large props must be
carried to the trunk of any valid nearby vehicle.

## Origins and licensing

This resource is derived from
[`qbx_houserobbery`](https://github.com/Qbox-project/qbx_houserobbery) by the
Qbox Project and remains licensed under GPL-3.0. Its routing, randomized loot,
distance validation, skill-check and evidence concepts are retained.

Sleeping-resident and physical-carry gameplay was adapted from
[`TheIndra55/fivem-burglary`](https://github.com/TheIndra55/fivem-burglary),
licensed under MIT. Boxville/ESX mission logic was not retained. See
`NOTICE-fivem-burglary` for attribution.

## Operations

- The resource is started by the existing `ensure [bgrz]` group.
- `qbx_houserobbery` must stay stopped.
- All player actions use `ox_target`, including breaching, searching, carrying,
  leaving, ending the contract, dropping cargo and storing it in a vehicle.
- Debug helpers are disabled by default. Set `debug = true` and grant the
  `noir.houserobbery.debug` ACE to use `/noirhr assign|clear|state`.
