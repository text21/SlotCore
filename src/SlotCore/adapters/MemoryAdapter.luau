--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local TableUtil = require(Packages.TableUtil)

local MemoryAdapter = {}
MemoryAdapter.__index = MemoryAdapter

local SESSION_LOCKED = "SESSION_LOCKED"

function MemoryAdapter.new()
    local self: any = setmetatable({}, MemoryAdapter)
    self._store = {}
    self._locks = {}
    return self
end

function MemoryAdapter:AcquireSessionAsync(userId: number, token: string)
    local lock = self._locks[userId]
    if lock and lock ~= token then
        return false, nil, SESSION_LOCKED
    end
    self._locks[userId] = token
    local doc = self._store[userId]
    if not doc then
        doc = { version = 1, createdAt = os.time(), updatedAt = os.time(), account = {}, slots = {}, activeSlot = nil, session = nil }
        self._store[userId] = doc
    end
    doc.session = { token = token, lastSeen = os.time() }
    return true, TableUtil.Copy(doc), nil
end

function MemoryAdapter:SaveDocumentAsync(userId: number, token: string, doc: any)
    local lock = self._locks[userId]
    if not lock or lock ~= token then
        return false, nil, "SESSION_LOCKED"
    end
    local copy = TableUtil.Copy(doc)
    copy.updatedAt = os.time()
    self._store[userId] = copy
    return true, nil, nil
end

function MemoryAdapter:PeekDocumentAsync(userId: number)
    local doc = self._store[userId]
    if not doc then
        return true, { version = 1, createdAt = os.time(), updatedAt = os.time(), account = {}, slots = {}, activeSlot = nil, session = nil }, nil
    end
    return true, TableUtil.Copy(doc), nil
end

function MemoryAdapter:ReleaseSessionAsync(userId: number, token: string)
    local lock = self._locks[userId]
    if lock and lock == token then
        self._locks[userId] = nil
        local doc = self._store[userId]
        if doc then
            doc.session = nil
        end
    end
    return true, nil, nil
end

function MemoryAdapter:FlushAndLockAsync(userId: number)
    return true, nil, nil
end

return MemoryAdapter
