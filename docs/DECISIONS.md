# Decision Log

Architecture decisions are immutable records under `docs/adr/`. New evidence creates a superseding ADR rather than silently rewriting history.

| ID | Decision | Status |
|---|---|---|
| ADR-001 | Flutter and Dart shared codebase | Accepted |
| ADR-002 | Local-first data ownership | Accepted |
| ADR-003 | Engine-neutral playback interface | Accepted |
| ADR-004 | Repository boundary with Drift/SQLite target | Accepted |
| ADR-005 | Platform secure storage for credentials | Accepted |
| ADR-006 | Focus navigation is a design-system concern | Accepted |
| ADR-007 | Riverpod state and go_router navigation | Accepted |
| ADR-008 | Platform-native playback adapters behind a shared contract | Accepted |

## Dependency notes

- Melos 7.8.2 and Dart workspaces organize packages without global tooling.
- `media_kit` is provisional for the HLS spike and will be replaced per platform after equivalent behavior is verified.
- The Phase 0 in-memory repository proves the persistence boundary; it is not a substitute for the planned indexed Drift/SQLite adapter.
- `file_picker`, `http`, and `cached_network_image` support the vertical prototype only behind app/service boundaries.
- Flutter 3.47.0 still builds the macOS adapter through CocoaPods, but warns that the selected `media_kit` plugins lack Swift Package Manager support.
- No final open-source license is selected.

## Change policy

Record decisions that affect package boundaries, stored data, user privacy, target platforms, player engines, or long-term migration cost. Minor implementation choices belong in code and tests.
