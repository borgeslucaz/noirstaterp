# Security Policy

## Reporting a vulnerability

If you find a security issue in ShadowForge DevTools — anything that could let a player escalate privilege, execute server commands they shouldn't, exfiltrate data, or crash a server — **please don't open a public issue.**

Instead, use GitHub's private vulnerability reporting:

1. Go to the [Security tab](https://github.com/TonyHinojosa4/Shadowforge-devtools/security) of this repo.
2. Click **"Report a vulnerability"**.
3. Fill out the form with as much detail as you can: reproduction steps, affected versions, impact.

I'll acknowledge within a few days and work with you on a fix and coordinated disclosure timing.

## Supported versions

Only the latest `v1.x` release receives security fixes. If a serious issue is found in an older version, the recommendation will be to upgrade.

## Scope

In scope:

- The resource code in this repository
- Default configuration as shipped

Out of scope:

- Vulnerabilities in third-party dependencies (report to that project)
- Issues caused by user-modified `config.lua`
- Social engineering or physical attacks
- Anything that requires server owner privileges to exploit (those are admin commands, not vulnerabilities)
