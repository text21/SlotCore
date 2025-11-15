--!strict

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Signal = require(Packages.Signal)
local TableUtil = require(Packages.TableUtil)
local Trove = require(Packages.Trove)

local types = require(script.Parent.SlotTypes)
local DataLayer = require(script.Parent.DataLayer)

type SlotId = types.SlotId
type SlotData = types.SlotData
type SlotMeta = types.SlotMeta
type SlotConfig = types.SlotConfig
type SlotSummary = types.SlotSummary
type SlotStore = types.SlotStore
type SlotHandle = types.SlotHandle
type AdapterResult<T> = types.AdapterResult<T>
type Document = types.Document
type MiddlewareConfig = types.MiddlewareConfig

local SlotStoreClass = {}
SlotStoreClass.__index = SlotStoreClass

local function cloneSlotTemplate(cfg: SlotConfig): SlotData
	return TableUtil.Copy(cfg.slotTemplate)
end

local function cloneMetaTemplate(cfg: SlotConfig): SlotMeta
	return TableUtil.Copy(cfg.defaultMeta or {})
end

local function ensureSlot(doc: Document, cfg: SlotConfig, slotId: SlotId): (SlotData, SlotMeta)
	local d: any = doc
	if not d.slots[slotId] then
		d.slots[slotId] = {
			data = cloneSlotTemplate(cfg),
			meta = cloneMetaTemplate(cfg),
		}
	end
	return d.slots[slotId].data, d.slots[slotId].meta
end

local function buildSummaryList(doc: Document, cfg: SlotConfig): { SlotSummary }
	local list: { SlotSummary } = {}
	local d: any = doc
	for _, slotId in ipairs(cfg.allowedSlotIds :: { SlotId }) do
		local slot = d.slots[slotId]
		table.insert(list, {
			id = slotId,
			exists = slot ~= nil,
			meta = if slot then slot.meta else nil,
		})
	end
	return list
end

local function runMiddleware(list: { (ctx: any, ...any) -> () }?, ctx: any, ...: any)
	if not list then
		return
	end
	for _, fn in ipairs(list) do
		fn(ctx, ...)
	end
end

local function newSessionToken(): string
	return HttpService:GenerateGUID(false)
end

function SlotStoreClass.new(name: string, config: SlotConfig): SlotStore
	local self: any = setmetatable({}, SlotStoreClass)

	self.Name = name
	self._cfg = config
	self._data = DataLayer.new(config)
	self._trove = Trove.new()

	self._documents = {} :: { [number]: Document }
	self._handles = {} :: { [number]: SlotHandle }
	self._sessionTokens = {} :: { [number]: string }

	self._middleware = (config :: any).middleware or {} :: MiddlewareConfig?
	self._validators = (config :: any).validators
	self._achievementRules = (config :: any).achievementRules

	self.SlotLoaded = Signal.new()
	self.SlotReleased = Signal.new()
	self.SlotDeleted = Signal.new()
	self.PlayerDocumentLoaded = Signal.new()
	self.PlayerDocumentReleased = Signal.new()

	self.SlotSaved = Signal.new()
	self.StatChanged = Signal.new()
	self.LevelUp = Signal.new()
	self.AchievementUnlocked = Signal.new()
	self.ExploitFlagged = Signal.new()

	if config.autoSaveInterval and config.autoSaveInterval > 0 then
		self._trove:Add(task.spawn(function()
			while true do
				task.wait(config.autoSaveInterval)
				for _, plr in ipairs(Players:GetPlayers()) do
					self:SavePlayerAsync(plr)
				end
			end
		end))
	end

	self._trove:Add(Players.PlayerRemoving:Connect(function(plr)
		self:SavePlayerAsync(plr)
		self:_releaseSession(plr)
	end))

	return self
end

function SlotStoreClass:_getSessionToken(userId: number): string
	local token = self._sessionTokens[userId]
	if not token then
		token = newSessionToken()
		self._sessionTokens[userId] = token
	end
	return token
end

function SlotStoreClass:_releaseSession(player: Player)
	local userId = player.UserId
	local token = self._sessionTokens[userId]
	self._sessionTokens[userId] = nil
	self._handles[userId] = nil

	local doc = self._documents[userId]
	self._documents[userId] = nil

	if token then
		self._data:ReleaseSessionAsync(userId, token)
	end

	self.PlayerDocumentReleased:Fire(player, doc)
end

function SlotStoreClass:GetDocumentAccount(player: Player)
	local doc = self._documents[player.UserId]
	if doc then
		local d: any = doc
		return d.account
	end
	return nil
end

function SlotStoreClass:ListSlotsAsync(userId: number): AdapterResult<{ SlotSummary }>
	local ok, doc, err = self._data:PeekDocumentAsync(userId)
	if not ok or not doc then
		return false, nil, err
	end
	return true, buildSummaryList(doc, self._cfg), nil
end

function SlotStoreClass:_makeHandle(userId: number, slotId: SlotId, data: SlotData, meta: SlotMeta): SlotHandle
	local store = self

	local handle: any = {}
	handle.Id = slotId
	handle.Data = data
	handle.Meta = meta
	handle._snapshot = TableUtil.Copy(data)
	handle._achievementUnlocked = {} :: { [string]: boolean }

	function handle:SaveAsync(): AdapterResult<nil>
		local doc = store._documents[userId]
		if not doc then
			return false, nil, "No document loaded"
		end

		local d: any = doc
		local slot = d.slots[slotId]
		if not slot then
			return false, nil, "Slot not present in document"
		end

		slot.data = handle.Data
		slot.meta = handle.Meta

		local ctx = {
			store = store,
			player = Players:GetPlayerByUserId(userId),
			userId = userId,
			slotId = slotId,
		}

		local oldSnapshot = handle._snapshot or {}
		local changes: { [string]: { old: number, new: number } } = {}

		for key, newVal in pairs(handle.Data) do
			local oldVal = (oldSnapshot :: any)[key]
			if typeof(newVal) == "number" and typeof(oldVal) == "number" and newVal ~= oldVal then
				changes[key] = { old = oldVal, new = newVal }
			end
		end

		runMiddleware((store._middleware :: any).beforeSave, ctx, handle, doc)

		local validators = (store._validators :: any)
		if validators then
			for _, entry in ipairs(validators) do
				local vName = entry.name or "validator"
				local validate = entry.validate or entry

				local okV, result, reason = pcall(validate, ctx, handle, doc)
				if not okV or result == false then
					local reasonStr = if not okV then tostring(result) else (reason or "validation failed")

					handle.Data = TableUtil.Copy(oldSnapshot)
					slot.data = handle.Data

					if ctx.player then
						store.ExploitFlagged:Fire(ctx.player, slotId, vName, reasonStr)
					end

					return false, nil, "VALIDATION_FAILED: " .. vName
				end
			end
		end

		local token = store._sessionTokens[userId]
		if not token then
			return false, nil, "No active session"
		end

		local ok, _, err = store._data:SaveDocumentAsync(userId, token, doc)
		if not ok then
			return false, nil, err
		end

		runMiddleware((store._middleware :: any).afterSave, ctx, handle, doc)

		local player = ctx.player
		if player then
			for key, delta in pairs(changes) do
				store.StatChanged:Fire(player, handle, key, delta.old, delta.new)
				if key == "level" and delta.new > delta.old then
					store.LevelUp:Fire(player, handle, delta.old, delta.new)
				end
			end

			local rules = (store._achievementRules :: any)
			if rules then
				for _, rule in ipairs(rules) do
					local id = rule.id or "achievement"
					if not handle._achievementUnlocked[id] then
						local okC, satisfied = pcall(rule.check, handle, doc, ctx)
						if okC and satisfied then
							handle._achievementUnlocked[id] = true
							store.AchievementUnlocked:Fire(player, handle, id)
						end
					end
				end
			end

			store.SlotSaved:Fire(player, handle)
		end

		handle._snapshot = TableUtil.Copy(handle.Data)

		return true, nil, nil
	end

	function handle:Release()
		local current = store._handles[userId]
		if current == handle then
			store._handles[userId] = nil
		end
		store.SlotReleased:Fire(Players:GetPlayerByUserId(userId), slotId)
	end

	return handle :: SlotHandle
end

function SlotStoreClass:_ensureDocument(player: Player): AdapterResult<Document>
	local userId = player.UserId
	local existing = self._documents[userId]
	if existing then
		return true, existing, nil
	end

	local token = self:_getSessionToken(userId)
	local ok, doc, err = self._data:AcquireSessionAsync(userId, token)
	if not ok or not doc then
		return false, nil, err
	end

	self._documents[userId] = doc
	self.PlayerDocumentLoaded:Fire(player, doc)

	return true, doc, nil
end

function SlotStoreClass:LoadSlotAsync(player: Player, slotId: SlotId, opts: { createIfMissing: boolean }?): AdapterResult<SlotHandle>
	opts = opts or {}

	local cfg = self._cfg
	if not table.find(cfg.allowedSlotIds :: { SlotId }, slotId) then
		return false, nil, "Slot not allowed"
	end

	local ok, doc, err = self:_ensureDocument(player)
	if not ok or not doc then
		return false, nil, err
	end

	local d: any = doc
	local slotEntry = d.slots[slotId]
	if not slotEntry and not opts.createIfMissing then
		return false, nil, "Slot does not exist"
	end

	local ctx = {
		store = self,
		player = player,
		userId = player.UserId,
		slotId = slotId,
	}

	runMiddleware((self._middleware :: any).beforeLoad, ctx, doc)

	local data, meta = ensureSlot(doc, cfg, slotId)
	d.activeSlot = slotId

	local handle = self:_makeHandle(player.UserId, slotId, data, meta)
	self._handles[player.UserId] = handle

	local token = self._sessionTokens[player.UserId]
	if not token then
		return false, nil, "No active session"
	end

	local saveOk, _, saveErr = self._data:SaveDocumentAsync(player.UserId, token, doc)
	if not saveOk then
		return false, nil, saveErr
	end

	runMiddleware((self._middleware :: any).afterLoad, ctx, handle, doc)

	self.SlotLoaded:Fire(player, handle)
	return true, handle, nil
end

function SlotStoreClass:SwitchSlotAsync(player: Player, slotId: SlotId, opts: { createIfMissing: boolean }?): AdapterResult<SlotHandle>
	local current = self._handles[player.UserId]
	if current then
		current:SaveAsync()
		current:Release()
	end
	return self:LoadSlotAsync(player, slotId, opts)
end

function SlotStoreClass:GetLoadedSlot(player: Player): SlotHandle?
	return self._handles[player.UserId]
end

function SlotStoreClass:SavePlayerAsync(player: Player): AdapterResult<nil>
	local userId = player.UserId
	local doc = self._documents[userId]
	if not doc then
		return true, nil, nil
	end

	local handle = self._handles[userId]
	if handle then
		return handle:SaveAsync()
	end

	local token = self._sessionTokens[userId]
	if not token then
		return false, nil, "No active session"
	end

	local ok, _, err = self._data:SaveDocumentAsync(userId, token, doc)
	return ok, nil, err
end

function SlotStoreClass:DeleteSlotAsync(userId: number, slotId: SlotId): AdapterResult<nil>
	local doc = self._documents[userId]
	if not doc then
		return false, nil, "No loaded document for user"
	end

	local d: any = doc
	d.slots[slotId] = nil
	if d.activeSlot == slotId then
		d.activeSlot = nil
	end

	local token = self._sessionTokens[userId]
	if not token then
		return false, nil, "No active session"
	end

	local ok, _, err = self._data:SaveDocumentAsync(userId, token, doc)
	if not ok then
		return false, nil, err
	end

	self.SlotDeleted:Fire(userId, slotId)
	return true, nil, nil
end

function SlotStoreClass:FlushAndLockAsync(userId: number): AdapterResult<nil>
	return self._data:FlushAndLockAsync(userId)
end

function SlotStoreClass:DebugPeekDocumentAsync(userId: number): AdapterResult<Document>
	return self._data:PeekDocumentAsync(userId)
end

return SlotStoreClass
