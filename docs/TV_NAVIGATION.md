# TV Navigation

TV support is architectural, not a post-processing accessibility pass. Every reusable interactive primitive exposes a `FocusNode`, semantics, and visible focus style.

## Directional rules

- Left/right moves within a rail or control row.
- Up/down moves between logical rows or panes.
- OK/Enter activates; Back returns or closes the top overlay.
- Play/Pause controls active media when an editable field is not focused.
- Channel Up/Down changes live channels in fullscreen playback.
- Escape exits fullscreen before navigating away on desktop.

Focus order follows visual order. Explicit traversal overrides geometry when grids, sidebars, or overlays make nearest-neighbor behavior ambiguous. Disabled/hidden nodes are removed from traversal.

## Persistence

Each route remembers its last meaningful focused item. When a dialog/player overlay closes, focus returns to its invoker. When an item disappears after filtering or refresh, focus moves to the nearest surviving sibling, then the parent action. Focus must never fall onto the application root with no visible target.

## `TviumFocusable`

The design-system primitive owns hover, press, focus outline, optional scale, semantics, activation keys, and focus-node lifecycle. It does not choose business navigation. Screens compose explicit focus groups and may provide directional policies.

## Test matrix

Widget tests send arrow, Enter, Escape, and media-key events and assert the focused semantic target. A Google TV ARM64 emulator verifies initial focus and centre-button/D-pad activation on the onboarding screen. Physical Android TV and Apple TV checks are still required for long-press behavior, platform Back/Menu semantics, safe areas, and focus-engine interoperability.

Text input should be avoidable for common TV tasks. QR/deep-link setup may be explored later but is not part of Phase 0.
