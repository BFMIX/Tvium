# tvium_database

Tvium's local library boundary. It provides an in-memory adapter for focused tests and a versioned Drift/SQLite adapter for native platforms.

Indexed rows contain display metadata and opaque source references only. Stream URLs and credentials belong in a separate secure-storage adapter.

`PlaylistSynchronizer` calculates deterministic added, changed, removed, and unchanged sets before committing a replacement. Duplicate identities abort the refresh without modifying the stored library.

Run the package checks from this directory:

```sh
dart run build_runner build
dart analyze --fatal-infos
flutter test
```
