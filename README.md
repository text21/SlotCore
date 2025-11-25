# SlotCore

Multi-slot save framework for Roblox.
Session-safe, adapter-style, with middleware, migrations, leaderstats, admin console, and global leaderboards.

> **Goal:** A drop-in data framework that works for _every_ game – simulators, RPGs, FPS, tycoons, story games – without forcing a specific architecture.

---

## ✨ Features

- **Multi-slot saves** out of the box (`1`, `2`, `3`, …)
- **Session locking** to prevent double-servers from corrupting data
- **Migrations** so you can ship updates without wiping players
- **Middleware pipeline** (`beforeLoad`, `afterLoad`, `beforeSave`, `afterSave`)
- **Validators** (anti-exploit, rate-limit checks, data sanity)
- **Achievements & hooks** (`AchievementUnlocked`, `LevelUp`, `StatChanged`)
- **Leaderstats binder** – automatic PlayerList stats from SlotCore data
- **Global stats / offline leaderboards** via OrderedDataStore
- **Conch admin integration** for in-game data inspection & editing
- **Client net layer** (Comm) for slot lists and loading from the client
