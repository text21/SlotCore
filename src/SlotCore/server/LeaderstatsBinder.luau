--!strict

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages.Trove)

local types = require(script.Parent.Parent.SlotTypes)
type SlotStore = types.SlotStore
type SlotHandle = types.SlotHandle

local Binder = {}
Binder.__index = Binder

local function ensureLeaderstats(player: Player, mapping)
    local folder = player:FindFirstChild("leaderstats") :: Folder?
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "leaderstats"
        folder.Parent = player
    end

    for name in pairs(mapping) do
        local v = folder:FindFirstChild(name) :: IntValue?
        if not v then
            v = Instance.new("IntValue")
            v.Name = name
            v.Value = 0
            v.Parent = folder
        end
    end

    return folder
end

local function updateStats(player: Player, handle: SlotHandle, mapping)
    local folder = ensureLeaderstats(player, mapping)

    for name, resolver in pairs(mapping) do
        local v = folder:FindFirstChild(name) :: IntValue?
        if v then
            local ok, result = pcall(resolver, handle)
            if ok and typeof(result) == "number" then
                v.Value = result
            end
        end
    end
end

function Binder.Bind(store: SlotStore, mapping: { [string]: (SlotHandle) -> number })
    store.SlotLoaded:Connect(function(player: Player, handle: SlotHandle)
        updateStats(player, handle, mapping)
    end)

    store.SlotSaved:Connect(function(player: Player, handle: SlotHandle)
        updateStats(player, handle, mapping)
    end)

    store.SlotReleased:Connect(function(player: Player)
        -- keep last values; no reset
    end)
end

return Binder
