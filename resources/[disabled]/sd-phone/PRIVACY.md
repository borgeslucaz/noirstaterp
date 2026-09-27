# Data and privacy for server owners

sd-phone runs entirely on your server and stores its data in your database. A few
features, though, send data to third parties, and some of that data is personal data
about your players.

This page exists so you know what those are. Rockstar's Creator Platform License
Agreement makes the person running the server responsible for this, not the resource
author:

> **Section 4** - "you are responsible for... ensuring that the Custom Server complies
> with all applicable laws, rules, and regulations, including without limitation, those
> related to the processing, protection, and privacy of personal data."

Nothing below happens without you enabling it or your players using the feature, and
everything can be turned off.

## What leaves your server

These calls are made by the server itself.

| Service | What is sent | When | Turn it off |
|---|---|---|---|
| **Fivemanage** | Photos, camera videos, voice memos and message attachments created by your players | Whenever a player takes a photo, records a memo, or attaches media | Leave `FivemanageMedia` unset in `configs/server/apikeys.lua`. Uploads then fail and the feature is unavailable. |
| **Giphy** | The GIF search text a player types, plus your API key | Player searches GIFs in Messages | Leave the Giphy key unset in `configs/server/apikeys.lua` |
| **Cloudflare Realtime** | Nothing about players. Provisions short-lived TURN credentials | Resource start and credential refresh | `configs/voice.lua` -> `Turn.Provider = 'none'` |
| **GitHub** | Your server's outbound IP, as part of a version check | Resource start | `bridge/server/version.lua` |

Player media uploaded to Fivemanage is stored on **their** infrastructure, and your
database keeps only the returned URL. Deleting a photo in sd-phone removes your row. It
does not delete the file from Fivemanage. If you need that, use their dashboard or API.

## What leaves each player's game client

These are requests made by the phone UI, from the player's own machine, so the player's
IP address is visible to the service.

| Service | What is sent | When | Turn it off |
|---|---|---|---|
| **Cloudflare TURN relay** | The player's **microphone audio**, and their IP | Recording a camera video or going Live while nearby voice capture is on | `configs/voice.lua` -> `RecordNearbyVoices = false` |
| **Google STUN** | The player's IP | Any voice capture session | `configs/voice.lua` -> empty `StunServers` |
| **Map tile CDN** | The player's IP | Opening the Maps app | Self-host tiles and change the base URL in `web/src/apps/maps/data.ts` |
| **YouTube** | The player's IP and the video id | Only if you set `AllowYouTube` or `AllowedVideos` | `configs/music.lua`, both off by default |

## The microphone one deserves attention

If `RecordNearbyVoices` is on, recording a video or going Live captures the microphones
of **other players standing near you**, not just your own, and mixes them into the
recording. Those players are not asked, and by default they are only captured while
actually transmitting in game (`TransmitGated = true`).

Voice is personal data in most jurisdictions, and in some it is treated more sensitively
than the rest. If you operate in the EU or UK, or your players are there, you should
either tell your players clearly that this happens, or set `RecordNearbyVoices = false`.

## What sd-phone stores about your players

All of this lives in your own database, under tables prefixed `phone_`:

- Phone numbers, contacts, call history
- Message, mail and social content, including anything players write
- Photos and media URLs, and the albums they are in
- App account logins. Passwords are stored as a hash rather than as plain text, but these
  are roleplay logins for in-game apps. Tell your players not to reuse a real password.
- Per-character settings: wallpaper, tones, passcode, Face Unlock preference

Retention is yours to decide. The admin panel can wipe a character's phone data, which is
usually what you need to answer a deletion request.

## Things worth knowing

**Third-party providers can be prohibited at short notice.** PLA section 5.2 lets Rockstar
designate a third-party service an "Unauthorized Service Provider", effective thirty days
after posting. If that ever happened to a service listed above, you would need to disable
the feature. That is a reason to know which ones you have switched on.

**Sharing music is distribution.** If you enable any part of the Music app's YouTube
support, remember that AirShare passes tracks to nearby players. See `configs/music.lua`
for the licensing side of that.

**API keys stay server side.** Fivemanage and Giphy keys are read in
`configs/server/apikeys.lua`, which is deliberately excluded from `fxmanifest.lua`'s
`files{}` block so it is never served to a client. Do not move those keys into a config
that clients can read.
