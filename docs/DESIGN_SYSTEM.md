# Design System

## Direction

Tvium uses a calm, premium media-library language: near-black graphite, layered neutral surfaces, one restrained accent, crisp typography, and content-first imagery. It avoids loud gradients, decorative frames, novelty effects, and visual imitation of existing IPTV players. Light mode uses the same semantic tokens.

## Tokens

| Token | Dark | Light |
|---|---|---|
| Canvas | `#0B0D10` | `#F6F7F8` |
| Surface | `#14171C` | `#FFFFFF` |
| Raised | `#1C2027` | `#ECEFF2` |
| Primary text | `#F5F7FA` | `#13161A` |
| Secondary text | `#A7AFBA` | `#5B6572` |
| Accent | `#59D6C7` | `#087F73` |
| Error | `#FF6B6B` | `#B42318` |

Spacing follows 4, 8, 12, 16, 24, 32, 48, and 64 logical pixels. Radii are 8 for controls, 12 for cards, and 16 for major surfaces. Minimum touch targets are 48×48; TV targets are at least 56×56.

Typography uses the platform sans-serif initially. Roles are display, title, body, label, and metadata; sizes scale by form factor and user text settings. Do not encode hierarchy with color alone.

## Component states

Every interactive component defines normal, hover, pressed, focused, selected, and disabled states. TV focus combines a high-contrast outline, slight scale/elevation, and semantic announcement. Motion is 100–180 ms and disabled or reduced when platform preferences request it.

Buttons, cards, fields, dialogs, skeletons, empty states, errors, and player overlays use semantic tokens rather than literal colors. Broken images never render: logo/poster components show a neutral monogram or media icon.

## Responsive layouts

- Phone: touch-first, compact navigation, horizontal primary-section rail.
- Tablet: wider grids and optional supporting panes.
- Desktop: keyboard/mouse density and resizable multi-pane Live TV.
- TV: large targets, shallow hierarchy, persistent directional focus, overscan-safe margins.

Secondary home rails render only when they contain data.
