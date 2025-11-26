--!strict

local DataStoreService = game:GetService("DataStoreService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Promise = require(Packages.Promise)

local types = require(script.Parent.SlotTypes)
type Document = types.Document
type SlotConfig = types.SlotConfig
type AdapterResult<T> = types.AdapterResult<T>
type MigrationFn = types.MigrationFn

local DataLayer = {}
DataLayer.__index = DataLayer

local SESSION_LOCK_ERR = "SlotCore::SessionLocked"

-- Public error constant consumers can check against
DataLayer.SESSION_LOCKED = "SESSION_LOCKED"

local function withRetries<T>(fn: () -> AdapterResult<T>, maxRetries: number?): AdapterResult<T>
    local tries = maxRetries or 5
    local lastErr: string? = nil
    for i = 1, tries do
        local ok, value, err = fn()
        if ok then
            return true, value, nil
        end
        lastErr = err
        task.wait(0.15 * i)
    end
    return false, nil, lastErr or "Unknown DataStore error"
end

local function newDocument(cfg: SlotConfig): Document
    local now = os.time()
    local doc: any = {
        version = cfg.version or 1,
        createdAt = now,
        updatedAt = now,
        account = table.clone(cfg.accountTemplate or {}),
        slots = {},
        activeSlot = nil,
        session = nil,
    }
    return doc
end

function DataLayer.new(config: SlotConfig)
    local self: any = setmetatable({}, DataLayer)
    self._cfg = config
    self._ds = DataStoreService:GetDataStore(config.dataStoreName :: string, config.scope)
    self._sessionTTL = (config :: any).sessionTTL or 120
    self._migrations = (config :: any).migrations or {} :: { [number]: MigrationFn }
    self._crypto = (config :: any).cryptoAdapter
    if not self._crypto and (config :: any).cryptoKey then
        local ok, adapter = pcall(function()
            return require(script.Parent.adapters.CryptoAdapter).new((config :: any).cryptoKey)
        end)
        if ok then
            self._crypto = adapter
        end
    end
    self._chaos = (config :: any).chaosMode or false
    self._chaosChance = (config :: any).chaosChance or 0.1
    return self
end

function DataLayer:_key(userId: number): string
    return tostring(userId)
end

function DataLayer:_applyMigrations(doc: Document)
    local cfg: SlotConfig = self._cfg
    local currentVersion = cfg.version or 1
    local docVersion = (doc :: any).version or 1
    if docVersion >= currentVersion then
        return
    end

    for v = docVersion + 1, currentVersion do
        local fn = self._migrations[v]
        if fn then
            fn(doc)
        end
    end

    (doc :: any).version = currentVersion
end

local function encryptFields(self, doc)
    local crypto = self._crypto
    local fields = (self._cfg :: any).secureFields or {}
    if not crypto or #fields == 0 then return end
    local d: any = doc
    d.account = d.account or {}
    for _, f in ipairs(fields) do
        if type(f) == "string" then
            local accVal = d.account[f]
            if accVal ~= nil and crypto.encrypt then
                d.account[f] = crypto.encrypt(accVal)
            end
            for slotId, slot in pairs(d.slots or {}) do
                slot.data = slot.data or {}
                local v = slot.data[f]
                if v ~= nil and crypto.encrypt then
                    slot.data[f] = crypto.encrypt(v)
                end
            end
        end
    end
end

local function decryptFields(self, doc)
    local crypto = self._crypto
    local fields = (self._cfg :: any).secureFields or {}
    if not crypto or #fields == 0 then return end
    local d: any = doc
    d.account = d.account or {}
    for _, f in ipairs(fields) do
        if type(f) == "string" then
            local accVal = d.account[f]
            if accVal ~= nil and crypto.decrypt then
                local ok, dec = pcall(crypto.decrypt, accVal)
                if ok then d.account[f] = dec end
            end
            for slotId, slot in pairs(d.slots or {}) do
                slot.data = slot.data or {}
                local v = slot.data[f]
                if v ~= nil and crypto.decrypt then
                    local ok, dec = pcall(crypto.decrypt, v)
                    if ok then slot.data[f] = dec end
                end
            end
        end
    end
end

function DataLayer:AcquireSessionAsync(userId: number, sessionToken: string): AdapterResult<Document>
    local cfg = self._cfg
    local ttl = self._sessionTTL
    local key = self:_key(userId)

    return withRetries(function()
        local ok, result = pcall(function()
            return self._ds:UpdateAsync(key, function(doc: any?)
                local now = os.time()
                if not doc then
                    doc = newDocument(cfg)
                end
                local session = doc.session
                if session and session.token ~= sessionToken then
                    local lastSeen = session.lastSeen or 0
                    if (now - lastSeen) < ttl then
                        error(SESSION_LOCK_ERR)
                    end
                end

                if self._chaos and math.random() < self._chaosChance then
                    error("SIMULATED_CHAOS_FAILURE")
                end

                doc.session = {
                    token = sessionToken,
                    lastSeen = now,
                }

                self:_applyMigrations(doc)

                if self._crypto then
                    pcall(function() decryptFields(self, doc) end)
                end

                return doc
            end)
        end)

        if not ok then
            local msg = tostring(result)
            if string.find(msg, SESSION_LOCK_ERR, 1, true) then
                return false, nil, "SESSION_LOCKED"
            end
            return false, nil, msg
        end

        return true, result :: Document, nil
    end)
end

function DataLayer:SaveDocumentAsync(userId: number, sessionToken: string, doc: Document): AdapterResult<nil>
    local cfg = self._cfg
    local ttl = self._sessionTTL
    local key = self:_key(userId)

    local docAny: any = doc
    docAny.updatedAt = os.time()
    doc = docAny

    return withRetries(function()
        local ok, result = pcall(function()
            return self._ds:UpdateAsync(key, function(current: any?)
                local now = os.time()
                current = current or newDocument(cfg)
                if self._chaos and math.random() < self._chaosChance then
                    error("SIMULATED_CHAOS_FAILURE")
                end

                local session = current.session
                if not session or session.token ~= sessionToken or (now - (session.lastSeen or 0)) > ttl then
                    error(SESSION_LOCK_ERR)
                end

                session.lastSeen = now

                local d: any = doc
                d.session = session
                d.updatedAt = now

                if self._crypto then
                    pcall(function() encryptFields(self, d) end)
                end

                return d
            end)
        end)

        if not ok then
            local msg = tostring(result)
            if string.find(msg, SESSION_LOCK_ERR, 1, true) then
                return false, nil, "SESSION_LOCKED"
            end
            return false, nil, msg
        end

        return true, nil, nil
    end)
end

function DataLayer:PeekDocumentAsync(userId: number): AdapterResult<Document>
    local cfg = self._cfg
    local key = self:_key(userId)

    return withRetries(function()
        local ok, result = pcall(function()
            return self._ds:GetAsync(key)
        end)

        if not ok then
            return false, nil, tostring(result)
        end

        local doc: any = result
        if not doc then
            doc = newDocument(cfg)
        else
            self:_applyMigrations(doc)
            if self._crypto then
                pcall(function() decryptFields(self, doc) end)
            end
        end

        return true, doc :: Document, nil
    end)
end

function DataLayer:ReleaseSessionAsync(userId: number, sessionToken: string): AdapterResult<nil>
    local cfg = self._cfg
    local key = self:_key(userId)

    return withRetries(function()
        local ok, result = pcall(function()
            return self._ds:UpdateAsync(key, function(doc: any?)
                doc = doc or newDocument(cfg)
                local session = doc.session
                if session and session.token == sessionToken then
                    doc.session = nil
                end
                return doc
            end)
        end)

        if not ok then
            return false, nil, tostring(result)
        end

        return true, nil, nil
    end)
end

function DataLayer:FlushAndLockAsync(userId: number): AdapterResult<nil>
    local key = self:_key(userId)

    return withRetries(function()
        local ok, result = pcall(function()
            return self._ds:UpdateAsync(key, function(doc: any?)
                if doc then
                    (doc :: any).updatedAt = os.time()
                end
                return doc
            end)
        end)

        if not ok then
            return false, nil, tostring(result)
        end

        return true, nil, nil
    end)
end

return DataLayer
