# Design

<!-- impeccable:design-schema 1 -->

## World

Calm native Mac utility: flat midnight-blue ground, restrained indigo surfaces, blue primary actions and copper attention accents. Open Sans is bundled and registered locally; SF Symbols remain the icon system. Menu bar opens a window popover with live status tiles.

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

## Main window and Smart Care

- Narrow native sidebar (224 pt ideal) with tools and secondary utilities; scan categories live in the overview, without duplicate navigation entries.
- Compact summary distinguishes all reclaimable cleanable bytes from selected bytes in the persistent footer. Scanned bytes include informational categories.
- Native checkbox rows sorted by the scan engine, full category labels, sizes, and detail navigation. Zero-byte categories collapse into a disclosure group.
- Review sheet lists actual selected paths and sizes before moving files to Trash. Existing permission prompts and stop controls remain available.
- Palette: canvas `#101B2C`, elevated surface approximately `#172438`; Open Sans 13 pt body, 28 pt page title, 42 pt summary value. Materials and gradients removed from shared panels and background.
- Italian and English copy follow the app language setting.
