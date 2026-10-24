# tvium_m3u

Progressive M3U ingestion for user-provided files, URLs, and in-memory data. The parser preserves source fields, emits bounded batches, and reports sanitized diagnostics for malformed entries.

Import `package:tvium_m3u/tvium_m3u.dart` for the parser, source adapters, events, and synthetic playlist generator. The generator is for tests and benchmarks; it contains no real provider data.

See [M3U Format](../../docs/M3U_FORMAT.md) and [Test Strategy](../../docs/TEST_STRATEGY.md).
