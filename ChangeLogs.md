# Changelog

All notable changes to SlotCore are documented in this file.

## [1.1] - 2025-11-26

### Added

- Pluggable persistence adapters: `MemoryAdapter`, `FileAdapter` (Studio offline JSON), and `MirrorAdapter` (best-effort mirror writes to a secondary DataStore).
- Dev-grade crypto adapter: `CryptoAdapter` (XOR/JSON obfuscator) for testing.
- `WebhookLogger` and `MetricsExporter` adapters for structured log forwarding and in-memory metrics collection.
- `BadgeIntegration` and `DevProductIntegration` modules for easy wiring of achievements and dev-product handlers to SlotCore stores.
- `SlotSelect` client UI module - a small built-in slot selection screen that fires a RemoteEvent.
- `TestHarness` enhancements: `RunFakeSession` simulates a full player session lifecycle for tests.
- `GlobalStatsService` improvements: segmented leaderboards, period prefix helper (daily/weekly/monthly), and `GetPlayerRankAsync` for best-effort rank lookups.

### Changed

- `DataLayer` now supports optional `cryptoAdapter` and will auto-create a dev adapter when `cryptoKey` is provided in config. It also exposes `chaosMode` and `chaosChance` (dev/testing only) to simulate transient failures.
- `SlotStore` now accepts `config.dataAdapter` allowing pluggable adapters and uses `MemoryAdapter`/`FileAdapter`/`MirrorAdapter` transparently.
- Default autosave behavior added: when `config.autoSaveInterval` is omitted the store will autosave every 15 seconds. Set to `0` to disable.
- Logger extended with adapter support (`Logger.registerAdapter`) so custom log sinks can be wired (webhooks, metrics, etc.).
- Validators, Schema, and middleware behavior expanded to support quarantine counters and best-effort quarantine persistence on repeated validation failures.

### Deprecated

- No breaking deprecations in 1.1, but note: the shipped `CryptoAdapter` is intended for development only - do not treat it as secure.

### Migration notes

- If you enable `secureFields` or switch to a crypto adapter in `DataLayer`, provide migration functions to encrypt existing plaintext fields.
- If you have custom `MarketplaceService.ProcessReceipt` handlers, integrate them with `DevProductIntegration` carefully because SlotCore's helper sets `ProcessReceipt` when bound; prefer composing handlers in your own code.

### Security & Ops

- `WebhookLogger` performs HTTP requests via `HttpService` - ensure your game has HTTP enabled and that you whitelist required endpoints.

---

For previous releases, see Git history.
