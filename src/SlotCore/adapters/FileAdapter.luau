--!strict

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local FileAdapter = {}
FileAdapter.__index = FileAdapter

function FileAdapter.new(folderName)
    local self = setmetatable({}, FileAdapter)
    self._folderName = folderName or "SlotCore_OfflineData"
    local folder = ServerStorage:FindFirstChild(self._folderName)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = self._folderName
        folder.Parent = ServerStorage
    end
    self._folder = folder
    return self
end

local function ensureFolder(self)
    if not self._folder then
        local folder = ServerStorage:FindFirstChild(self._folderName)
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = self._folderName
            folder.Parent = ServerStorage
        end
        self._folder = folder
    end
end

function FileAdapter:AcquireSessionAsync(userId, token)
    if not RunService:IsStudio() then
        return false, nil, "FileAdapter only allowed in Studio"
    end
    ensureFolder(self)
    local key = tostring(userId)
    local sv = self._folder:FindFirstChild(key)
    local doc = nil
    if sv and sv:IsA("StringValue") then
        local ok, parsed = pcall(function() return HttpService:JSONDecode(sv.Value) end)
        if ok then doc = parsed end
    end
    if not doc then
        doc = { version = 1, createdAt = os.time(), updatedAt = os.time(), account = {}, slots = {}, activeSlot = nil, session = nil }
    end
    doc.session = { token = token, lastSeen = os.time() }
    return true, doc, nil
end

function FileAdapter:SaveDocumentAsync(userId, token, doc)
    if not RunService:IsStudio() then
        return false, nil, "FileAdapter only allowed in Studio"
    end
    ensureFolder(self)
    local key = tostring(userId)
    local sv = self._folder:FindFirstChild(key)
    if not sv then
        sv = Instance.new("StringValue")
        sv.Name = key
        sv.Parent = self._folder
    end
    sv.Value = HttpService:JSONEncode(doc)
    return true, nil, nil
end

function FileAdapter:PeekDocumentAsync(userId)
    if not RunService:IsStudio() then
        return false, nil, "FileAdapter only allowed in Studio"
    end
    ensureFolder(self)
    local key = tostring(userId)
    local sv = self._folder:FindFirstChild(key)
    if not sv or not sv:IsA("StringValue") then
        return true, { version = 1, createdAt = os.time(), updatedAt = os.time(), account = {}, slots = {}, activeSlot = nil, session = nil }, nil
    end
    local ok, parsed = pcall(function() return HttpService:JSONDecode(sv.Value) end)
    if not ok then
        return false, nil, "JSON parse error"
    end
    return true, parsed, nil
end

function FileAdapter:ReleaseSessionAsync(userId, token)
    return true, nil, nil
end

function FileAdapter:FlushAndLockAsync(userId)
    return true, nil, nil
end

return FileAdapter
