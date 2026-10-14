# Design

<!-- impeccable:design-schema 1 -->

## World

Graphite native Mac utility with ivory typography and logo-blue interaction accents. Open Sans is bundled locally; SF Symbols remain the icon system. The existing blue broom app icon appears beside the MacCleaner name in the sidebar. The home uses an open split composition: reclaimed-space metrics at left and proportional category ribbons at right, followed by the selectable file categories.

## Color

| Token | Role | Approx |
|---|---|---|
| canvas | Graphite ground | `#101213` |
| card / glass | Flat graphite surface | `#191C1D` |
| ink | Primary text | ivory `#F2F2E8` |
| muted / faint | Secondary / tertiary | sage grey |
| sea | Primary action / links | blue `#4AA1FF` |
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
- Palette: canvas `#101213`, elevated surface approximately `#191C1D`; Open Sans 13 pt body, 34 pt page title, 40 pt summary value. Materials and gradients removed from shared panels and background.
- Italian and English copy follow the app language setting.

## Home space map

The home title is “Make room for what matters.” Four leading cleanable categories appear as proportional blue ribbons, with the denominator including all cleanable results. Each ribbon opens its category details. Before scanning, the area explains the next action; it never invents values. The metrics distinguish total available space from the selected space in the footer. Native ViewThatFits switches from split to stacked content at narrower window widths. Logo asset: existing packaging/AppIcon.icns, copied into the resource bundle as BrandIcon.icns.

## Before the scan

Logo-blue is the primary accent across the app. Before scanning, a single welcome surface pairs the app logo with a clear scan action, an explanation of the scan, and three compact coverage rows (caches, developer tools, and files to review). No byte placeholders, empty charts or disabled cleanup footer appear before results exist. The welcome explicitly states that scanning does not delete files. The HTML prototype opens in this state and its simulated scan reveals the results.
