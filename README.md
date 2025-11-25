# SlotCore

Hello Developers, I have a made Multi-slot save framework for Roblox.

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

### Server

```lua
-- ServerScriptService.MainServer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlotCoreServer = require(ReplicatedStorage.SlotCore.server.SlotCoreServer)
local LeaderstatsBinder = require(ReplicatedStorage.SlotCore.server.LeaderstatsBinder)
local GlobalStatsService = require(ReplicatedStorage.SlotCore.server.GlobalStatsService)

local store = SlotCoreServer.CreateStore("Main", {
	maxSlots = 3,

	slotTemplate = {
		coins = 0,
		level = 1,
		xp = 0,
		kills = 0,
		inventory = {},
	},

	version = 2,

	migrations = {
		[2] = function(doc)
			local d: any = doc
			for _, slot in pairs(d.slots) do
				slot.data.kills = slot.data.kills or 0
				slot.data.xp = slot.data.xp or 0
			end
		end,
	},

	validators = {
		{
			name = "NoNegativeCoins",
			validate = function(ctx, handle)
				local c = handle.Data.coins or 0
				if c < 0 then
					return false, "coins < 0"
				end
				return true
			end,
		},

		(function()
			local lastCoins: { [number]: number } = {}

			return {
				name = "CoinsMaxDelta",
				validate = function(ctx, handle)
					local userId = ctx.userId
					local current = handle.Data.coins or 0
					local prev = lastCoins[userId]

					if prev == nil then
						lastCoins[userId] = current
						return true
					end

					local delta = current - prev
					local maxDeltaPerSave = 100_000

					if delta > maxDeltaPerSave then
						return false, string.format("coins delta too large: %d", delta)
					end

					lastCoins[userId] = current
					return true
				end,
			}
		end)(),

		{
			name = "XPNonNegative",
			validate = function(ctx, handle)
				local xp = handle.Data.xp or 0
				if xp < 0 then
					return false, "xp < 0"
				end
				return true
			end,
		},
	},

	achievementRules = {
		{
			id = "FirstBlood",
			check = function(handle)
				return (handle.Data.kills or 0) >= 1
			end,
		},
		{
			id = "Wealthy",
			check = function(handle)
				return (handle.Data.coins or 0) >= 100_000
			end,
		},
		{
			id = "Millionaire",
			check = function(handle)
				return (handle.Data.coins or 0) >= 1_000_000
			end,
		},
	},

	middleware = {
		beforeLoad = {
			function(ctx, doc)
				local d: any = doc
				local slot = d.slots[ctx.slotId]
				if slot then
					slot.data.coins = slot.data.coins or 0
					slot.data.level = slot.data.level or 1
					slot.data.xp = slot.data.xp or 0
					slot.data.kills = slot.data.kills or 0
				end
			end,
		},

		beforeSave = {
			function(ctx, handle)
				if handle.Data.coins and handle.Data.coins < 0 then
					handle.Data.coins = 0
				end
				if handle.Data.level and handle.Data.level < 1 then
					handle.Data.level = 1
				end
			end,
		},

		afterSave = {
			function(ctx, handle)
				local xp = handle.Data.xp or 0
				local level = handle.Data.level or 1
				local xpPerLevel = 100

				if xp < 0 then xp = 0 end

				while xp >= xpPerLevel do
					xp -= xpPerLevel
					level += 1
				end

				handle.Data.xp = xp
				handle.Data.level = level
			end,
		},
	},
})

LeaderstatsBinder.Bind(store, {
	Coins = function(handle)
		return handle.Data.coins or 0
	end,
	Level = function(handle)
		return handle.Data.level or 1
	end,
	Kills = function(handle)
		return handle.Data.kills or 0
	end,
})

GlobalStatsService.Bind(store, {
	Coins = function(handle)
		return handle.Data.coins or 0
	end,

	Level = function(handle)
		return handle.Data.level or 1
	end,

	Kills = function(handle)
		return handle.Data.kills or 0
	end,
}, {
	prefix = "SlotCore_Main",
})

store.LevelUp:Connect(function(player, handle, oldLevel, newLevel)
	print("[SlotCore] Level up:", player.Name, oldLevel, "→", newLevel)
end)

store.AchievementUnlocked:Connect(function(player, handle, id)
	print("[SlotCore] Achievement:", player.Name, id)
end)

store.ExploitFlagged:Connect(function(player, slotId, validatorName, reason)
	warn("[SlotCore] Exploit flagged:", player.Name, slotId, validatorName, reason)
end)
```

### Client

```lua
-- StarterPlayerScripts.MainClient

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlotCoreClient = require(ReplicatedStorage.SlotCore.client.SlotCoreClient)
require(ReplicatedStorage.SlotCore.client.ConchUIInit) -- optional, F4 console

local net = SlotCoreClient.ForStore("Main")

task.spawn(function()
	local slots = net:GetSlotsAsync()
	print("Slots:", slots)

	net.SlotLoaded:Connect(function(slotId, meta)
		print("Slot loaded client-side:", slotId, meta and meta.level)
	end)

	net:LoadSlotAsync("1")
end)

```

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
- If you repeatedly see `SESSION_LOCKED`, log and surface to ops — it often indicates another server or task is holding the session.

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

Thanks for checking out SlotCore — contributions are welcome!

- Report bugs or request features: open an issue at https://github.com/text21/SlotCore

Every contribution helps — thank you!
