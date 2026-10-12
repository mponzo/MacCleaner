# Design

<!-- impeccable:design-schema 1 -->

## World

Blue glass Mac utility: deep indigo ground, frosted material tiles with blue wash, soft cyan CTAs, copper heat accents. Menu bar opens a one-click window popover with live status tiles.

## Color

| Token | Role | Approx |
|---|---|---|
| canvas | Night indigo ground | `#0A1A33` |
| card / glass | Ultra-thin material + blue wash | translucent |
| ink | Primary text | near-white |
| muted / faint | Secondary / tertiary | cool blue greys |
| sea | Primary action / links | soft blue |
| accent | Heat / attention | copper |
| glass | Panel tint | `#2E6BD1` |

## Components

- Menu bar popover (`MenuBarExtraStyle.window`)
- Glass tiles for storage, memory, battery, CPU, network, activity
- Ready strip (local tools — not a malware claim)
- Smart Care tip card + footer actions

## Motion

Press scale on primary buttons; live network sampling ~1.2s.
