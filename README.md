# SlotCore

SlotCore is a production-minded multi-slot data framework for Roblox. It provides session-safe, adapter-driven persistence with middleware, validators, achievements, leaderboards, and optional admin tooling.

Goal: A drop-in data backend that works for simulators, RPGs, tycoons, story games, and more - without forcing a specific game architecture.

Version: 1.1 - Released 2025-11-26

Highlights (v1.1) (Release version is still useable)

- Pluggable persistence adapters: `MemoryAdapter`, `FileAdapter` (Studio JSON), and `MirrorAdapter`.
- Webhook logging and a simple metrics exporter adapter.
- Badge and DevProduct integration helpers.
- Test harness improvements and a small client `SlotSelect` UI module.
- Default autosave (15s) with configurable interval; leaderboards improvements and on-demand rank lookup.

## Core Features

- Multi-slot saves out of the box (`1`, `2`, `3`, …)
- Session locking to prevent concurrent server write conflicts
- Adapter-based persistence (DataLayer, MemoryAdapter, FileAdapter, MirrorAdapter)
- Migrations to evolve document shape without wipes
- Middleware pipeline (`beforeLoad`, `afterLoad`, `beforeSave`, `afterSave`)
- Validators (anti-exploit, rate-limit checks, data sanity)
- Achievements & hooks (`AchievementUnlocked`, `LevelUp`, `StatChanged`)
- Leaderstats binder + GlobalStatsService (ordered datastore leaderboards)
- Optional Conch admin integration for in-game inspection & editing
- Test harness helpers for local/session testing

---

### Installation

You can either:

- **Import the `.rbxm`** (attached below), or
- **Install from GitHub / Wally** (see repository for setup)

RBXM: _[SlotCore.rbxm|attachment](upload://RFStEY1pTaE63rQo47QPcBolyL.rbxm) (183.9 KB)_

GitHub:
https://github.com/text21/SlotCore

---

### Quickstart

Server snippet (abridged):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SlotCoreServer = require(ReplicatedStorage.SlotCore.server.SlotCoreServer)
local LeaderstatsBinder = require(ReplicatedStorage.SlotCore.server.LeaderstatsBinder)
local GlobalStatsService = require(ReplicatedStorage.SlotCore.server.GlobalStatsService)

local store = SlotCoreServer.CreateStore("Main", {
	maxSlots = 3,
	slotTemplate = { coins = 0, level = 1, xp = 0, kills = 0 },
	version = 2,
	-- migrations, validators, middleware, achievements omitted for brevity
})

LeaderstatsBinder.Bind(store, {
	Coins = function(handle) return handle.Data.coins or 0 end,
	Level = function(handle) return handle.Data.level or 1 end,
	Kills = function(handle) return handle.Data.kills or 0 end,
})

GlobalStatsService.Bind(store, {
	Coins = function(handle) return handle.Data.coins or 0 end,
	Level = function(handle) return handle.Data.level or 1 end,
}, { prefix = "SlotCore_Main" })

store.AchievementUnlocked:Connect(function(player, handle, id)
	print("Achievement:", player.Name, id)
end)
```

Client snippet (abridged):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SlotCoreClient = require(ReplicatedStorage.SlotCore.client.SlotCoreClient)
local net = SlotCoreClient.ForStore("Main")

local slots = net:GetSlotsAsync()
net:LoadSlotAsync("1")
```

---

## Advanced Examples

Below are a few focused examples you can copy into your game to wire the new features introduced in v1.1.

### Crypto adapter configuration

DataLayer supports two ways to enable field encryption:

1. Provide a simple `cryptoKey` (dev use) — DataLayer will create the dev obfuscation adapter automatically:

```lua
local store = SlotCoreServer.CreateStore("Main", {
	dataStoreName = "MyDS",
	-- dev-safe obfuscation adapter will be created from this key
	cryptoKey = "dev-only-key-123",
	secureFields = { "email", "ssn" },
})
```

Notes:

- `secureFields` is an array of field names; `DataLayer` will call `encrypt` before writing and `decrypt` after reading for each named field (both on `account` and per-slot `data`).

### Logger + metrics wiring

You can register custom sinks with `Logger.registerAdapter(name, fn)`. Example wiring `WebhookLogger` and `MetricsExporter`:

```lua
local Logger = require(ReplicatedStorage.SlotCore.Logger)
local WebhookImpl = require(ReplicatedStorage.SlotCore.loggers.WebhookLogger)
local MetricsImpl = require(ReplicatedStorage.SlotCore.loggers.MetricsExporter)

local webhook = WebhookImpl.new({ url = "https://hooks.example.com/push", authHeader = "Bearer token" })
local metrics = MetricsImpl.new({ flushFn = function(k,v) print("FLUSH", k, v) end })

-- Adapter that forwards Level+Message to webhook and increments a counter
Logger.registerAdapter("webhook", function(level, msg)
	webhook:log(level, msg, { source = "SlotCore" })
	metrics:inc("logs_total")
end)

-- Example: increment saves counter on store save
store.SlotSaved:Connect(function(player, handle)
	metrics:inc("saves")
end)

-- Read values from the metrics exporter anywhere in your server tools
local counters = metrics:getCounters()
print("Saves so far:", counters["saves"])
```

Notes:

- `WebhookLogger` uses `HttpService:PostAsync`; ensure HTTP requests are enabled for your place and endpoints are trusted.
- `MetricsExporter` is a small in-memory collector; replace `flushFn` with an external push to Prometheus/Datadog or your own telemetry endpoint for production.

### DevProductIntegration — composing `ProcessReceipt` safely

Roblox allows a single `MarketplaceService.ProcessReceipt` function. To avoid stomping other handlers, compose yours with any existing handler like this:

```lua
local MarketplaceService = game:GetService("MarketplaceService")
local existing = MarketplaceService.ProcessReceipt

local function makeCompositeHandler(store, handlers)
	-- handlers: map productId -> function(playerId, receipt, store) -> boolean (granted)
	return function(receiptInfo)
		local productId = receiptInfo.ProductId or receiptInfo.PurchaseId
		local playerId = receiptInfo.PlayerId

		local granted = false
		local handler = handlers[productId]
		if handler then
			local ok, res = pcall(function() return handler(playerId, receiptInfo, store) end)
			if ok and res then
				granted = true
			end
		end

		-- call existing handler if present (preserve behavior)
		if existing then
			local ok2, decision = pcall(function() return existing(receiptInfo) end)
			if ok2 and decision == Enum.ProductPurchaseDecision.PurchaseGranted then
				granted = true
			end
		end

		if granted then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

-- Usage
local DevProductIntegration = require(ReplicatedStorage.SlotCore.integrations.DevProductIntegration)
local handlers = {
	[123456] = function(userId, receipt, store)
		-- give 100 coins to the buyer
		local player = game:GetService("Players"):GetPlayerByUserId(userId)
		if player then
			store:IncrementAsync(player, "coins", 100)
			return true
		end
		return false
	end,
}

MarketplaceService.ProcessReceipt = makeCompositeHandler(store, handlers)
```

Notes:

- `DevProductIntegration.Bind` in `src/SlotCore/integrations/DevProductIntegration.luau` provides a simple binding; the example above shows how to compose handlers so you don't overwrite other code that uses `ProcessReceipt`.

---

### Core Concepts

### Stores

Each store is a logical save container:

```lua
local store = SlotCoreServer.CreateStore("Main", configTable)
```

- maxSlots – highest slot number to manage (e.g. 3 → {"1","2","3"})
- slotTemplate – base data per slot (table copied for each slot)
- accountTemplate – optional shared data (non-slot-specific)
- allowedSlotIds – override default slot IDs
- version – document version, used by migrations
- migrations – map of version → function(doc) to migrate

### Handles

When a slot is loaded, you get a handle:

```lua
local ok, handle, err = store:LoadSlotAsync(player, "1", { createIfMissing = true })
if ok then
	handle.Data.coins += 10
	handle:SaveAsync()
end
```

`handle.Data` is what gets stored.
`handle.Meta` is for meta fields (name, lastPlayed, etc).

---

### Server API

`SlotCoreServer.CreateStore(name, config)`
Creates a server-side store, wires networking + Conch admin.

### Store methods

```lua
store:ListSlotsAsync(userId) -> (ok, {SlotSummary}?, err?)
store:LoadSlotAsync(player, slotId, opts?) -> (ok, SlotHandle?, err?)
store:SwitchSlotAsync(player, slotId, opts?) -> (ok, SlotHandle?, err?)
store:GetLoadedSlot(player) -> SlotHandle?
store:GetDocumentAccount(player) -> AccountData?
store:SavePlayerAsync(player) -> (ok, _, err?)
store:DeleteSlotAsync(userId, slotId) -> (ok, _, err?)
store:FlushAndLockAsync(userId) -> (ok, _, err?)
store:DebugPeekDocumentAsync(userId) -> (ok, Document?, err?)
```

`opts` is usually `{ createIfMissing = true }.`

### Handle methods

```lua
handle.Id : string
handle.Data : table
handle.Meta : table

handle:SaveAsync() -> (ok, _, err?)
handle:Release()
```

### Client API

From `SlotCoreClient:`

```lua
local net = SlotCoreClient.ForStore("Main")

local slots = net:GetSlotsAsync() -- array of SlotSummary
net:LoadSlotAsync("1")
```

Events:

```lua
net.SlotLoaded:Connect(function(slotId, meta) end)
```

---

### Config: Middleware / Validators / Achievements

### Middleware

```lua
middleware = {
	beforeLoad = { fn(ctx, doc) end, ... },
	afterLoad  = { fn(ctx, handle, doc) end, ... },
	beforeSave = { fn(ctx, handle, doc) end, ... },
	afterSave  = { fn(ctx, handle, doc) end, ... },
}
```

`ctx` contains:

```lua
ctx = {
	store = store,
	player = Player?,
	userId = number,
	slotId = string,
}
```

### Validators

Run during `SaveAsync` (after middleware `beforeSave`, before DataStore):

```lua
validators = {
	{
		name = "NoNegativeCoins",
		validate = function(ctx, handle, doc)
			if (handle.Data.coins or 0) < 0 then
				return false, "coins < 0"
			end
			return true
		end,
	},
}
```

On failure:

- Save is aborted
- Data is reverted to previous snapshot
- `store.ExploitFlagged:Fire(player, slotId, validatorName, reason)`

### Achievements

```lua
achievementRules = {
	{
		id = "Millionaire",
		check = function(handle, doc, ctx)
			return (handle.Data.coins or 0) >= 1_000_000
		end,
	},
}
```

Emits:

```lua
store.AchievementUnlocked:Connect(function(player, handle, id) end)
```

---

### Global Stats / Offline Leaderboards

GlobalStatsService uses OrderedDataStore on top of SlotCore:

```lua
local GlobalStatsService = require(ReplicatedStorage.SlotCore.server.GlobalStatsService)

GlobalStatsService.Bind(store, {
	Coins = function(handle)
		return handle.Data.coins or 0
	end,
	Level = function(handle)
		return handle.Data.level or 1
	end,
}, {
	prefix = "SlotCore_Main", -- data store key prefix
})
```

To show a leaderboard UI:

```lua
local topCoins = GlobalStatsService.GetTopAsync("Coins", {
	prefix = "SlotCore_Main",
	pageSize = 25,
	ascending = false,
})

for rank, entry in ipairs(topCoins) do
	print(rank, entry.userId, entry.value)
end
```

---

### Admin Console (Conch)

SlotCore integrates with conch(https://alicesaidhi.github.io/conch/)

Commands (if enabled in AdminConfig):

- `slots <player>` – list slot IDs + levels
- `load <player> <slotId>` – load/switch a slot
- `wipe <player> <slotId>` – delete a slot
- `account <player>` – print account-level data
- `doc <player>` – print full document to server output
- `add <player> <field> <amount>` – add to a numeric field
- `set <player> <field> <value>` – set any field

**Session Locking and Errors**

SlotCore uses a session lock to prevent multiple servers from modifying a player's document concurrently. When a session conflict occurs the DataLayer returns the constant string `SESSION_LOCKED`. Consumers should treat this as a transient error and retry with backoff. Example strategy:

- Wait 100–500ms and retry up to a few times.
- If you repeatedly see `SESSION_LOCKED`, log and surface to ops - it often indicates another server or task is holding the session.

The `DataLayer` module exposes `DataLayer.SESSION_LOCKED` which you can check against when handling adapter errors.

**Admin integration is opt-in**

For safety, admin console integration is disabled by default in the shipped `AdminConfig`.

Client mount (F4 by default):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local conch = require(Packages.conch)
local ui = require(Packages.conch_ui)

conch.initiate_default_lifecycle()
ui.mount(conch)
ui.bind_to(Enum.KeyCode.F4)
```

---

### FAQ

Q: Why should I use SlotCore instead of ProfileService?
A: ProfileService is great, but it’s focused on “one profile per player”. SlotCore is built around multi-slot saves from the start and adds a few things on top:

- Config-driven multi-slot (1, 2, 3, …) with summaries and meta
- Built-in middleware and validators so you can plug in anti-exploit / data rules without scattering checks everywhere
- Achievements / hooks (LevelUp, AchievementUnlocked, StatChanged) baked into the save pipeline
- Session locking + retry logic inside the DataLayer instead of DIY
- First-class leaderstats binder and global stats service (offline leaderboards)

If you just need a single profile and are already deep into ProfileService, that’s fine. SlotCore is aimed at games that want multiple slots, strong validation, and tooling out of the box.

Q: Can I use SlotCore without Conch?
A: Yes. Conch integration is completely optional and controlled by AdminConfig. If you don’t want any in-game cmds:

- just set `AdminConfig.Enabled = false`
- The store, middleware, migrations, validators, leaderboards, etc. all work without Conch.

Q: Does SlotCore replace my existing framework (Knit, GameCore, custom systems)?
A: No. SlotCore is data-layer only. It doesn’t care whether you use Knit, GameCore, Aero, custom OOP, or no framework at all. You just:

- Require SlotCoreServer on the server
- Wire whatever systems you want to the store and handle.Data
- Think of it as “data backend” you plug your systems into.

Q: Can I migrate existing data into SlotCore?
A: Yes. That’s what migrations are for. You can:

- Start with version = 1 and write a migration that reshapes your old datastore schema into SlotCore’s document format, or
- Import once via a script that reads your old keys and writes SlotCore documents, then keep future changes in migrations.
- The idea is: no mass wipes when you add or change fields.

Q: Is it safe to use in bigger games / multiple servers per player?
A: SlotCore uses session locking to avoid two servers writing the same document at once. When a conflict happens, the DataLayer returns a special SESSION_LOCKED error and the framework retries with backoff internally. You can also check this constant yourself if you write custom adapters or tooling.

Q: Does SlotCore support offline / global leaderboards?
A: Yes. GlobalStatsService sits on top of SlotCore and uses OrderedDataStore:

- It listens to saves and pushes the selected fields (coins, level, kills, etc.) into ordered keys
- You can query with GetTopAsync to build global or mode-specific leaderboards, even when the player is offline.

Q: How many slots can I safely use per player?
A: SlotCore is flexible – you configure maxSlots and allowedSlotIds. In practice most games stick to 3–5 slots to keep document size and DataStore throughput reasonable. The framework itself doesn’t hard-limit you, but Roblox’s DataStore limits still apply.

Q: Can I turn pieces off if I don’t need them (validators, achievements, leaderboards)?
A: Yes. Everything is opt-in:

- Leave validators, achievementRules, or middleware out of the config to disable them
- Don’t require GlobalStatsService if you don’t want global leaderboards
- Disable admin commands per-command in AdminConfig.Commands

---

## Contributing

Thanks for checking out SlotCore - contributions are welcome!

- Report bugs or request features: open an issue at https://github.com/text21/SlotCore

Every contribution helps - thank you!
