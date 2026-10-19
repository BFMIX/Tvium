# Design System

The approved brand assets, reference screens, and implementation rules are indexed in [Design Sources](design/README.md). The written rules in this document and [Brand Guidelines](design/BRAND_GUIDELINES.md) are authoritative; mockups are directional references rather than pixel-perfect specifications.

## Direction

Tvium uses a calm, premium, TV-first media-library language: deep navy canvases, layered graphite-blue surfaces, a restrained cyan accent, crisp typography, and content-first cinematic imagery. Background artwork stays dimmed or blurred behind readable controls. Avoid excessive glow, crowded cards, decorative frames, tiny metadata, and imitation of generic IPTV dashboards.

On TV and desktop, the primary header is a single capsule with the validated Tvium logo centered. Home and Live TV appear to its left; Movies and TV Shows appear to its right. Search, Settings, time/date, and Profile remain global actions outside the capsule. The active destination uses a cyan focus pill, with spacing rather than divider bars between destinations.

## Tokens

| Token | Dark | Light |
|---|---|---|
| Canvas | `#071320` | `#F6F7F8` |
| Secondary canvas | `#0A1A2A` | `#EEF4F8` |
| Surface | `#102338` | `#FFFFFF` |
| Raised | `#162C44` | `#E4EDF4` |
| Primary text | `#F3F7FF` | `#13161A` |
| Secondary text | `#A9B7C8` | `#5B6572` |
| Accent | `#24D9FF` | `#007A99` |
| Accent deep | `#00B7FF` | `#006A99` |
| Amber | `#FFCA5A` | `#8A5600` |
| Live | `#FF4E68` | `#B4233C` |
| Error | `#FF6B6B` | `#B42318` |

Spacing follows 4, 8, 12, 16, 24, 32, 48, and 64 logical pixels. Radii are 8 for controls, 12 for cards, and 16 for major surfaces. Minimum touch targets are 48×48; TV targets are at least 56×56.

Typography uses the platform sans-serif initially. Roles are display, title, body, label, and metadata; sizes scale by form factor and user text settings. Do not encode hierarchy with color alone.

## Component states

Every interactive component defines normal, hover, pressed, focused, selected, and disabled states. TV focus combines a high-contrast outline, slight scale/elevation, and semantic announcement. Motion is 100–180 ms and disabled or reduced when platform preferences request it.

Buttons, cards, fields, dialogs, skeletons, empty states, errors, and player overlays use semantic tokens rather than literal colors. Broken images never render: logo/poster components show a neutral monogram or media icon.

## Responsive layouts

- Phone: touch-first, compact navigation, horizontal primary-section rail.
- Tablet: wider grids and optional supporting panes.
- Desktop: centered capsule navigation, keyboard/mouse density, and resizable multi-pane Live TV.
- TV: centered capsule navigation, large targets, shallow hierarchy, persistent directional focus, and overscan-safe margins.

Secondary home rails render only when they contain data.
