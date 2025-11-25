--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Comm = require(Packages.Comm)
local ServerComm = Comm.ServerComm
local Logger = require(script.Parent.Parent.Logger)

local types = require(script.Parent.Parent.SlotTypes)
type SlotStore = types.SlotStore
type SlotSummary = types.SlotSummary

local NetServer = {}
NetServer.__index = NetServer

function NetServer.bind(storeName: string, store: SlotStore)
    local root = script.Parent
    local folder = Instance.new("Folder")
    folder.Name = storeName
    folder.Parent = root

    local serverComm = ServerComm.new(folder)

    serverComm:BindFunction("GetSlots", function(player: Player): { SlotSummary }?
        local ok, list, err = store:ListSlotsAsync(player.UserId)
        if not ok or not list then
            Logger.warn("GetSlots failed for", player, err)
            return nil
        end
        return list
    end)

    serverComm:BindFunction("LoadSlot", function(player: Player, slotId: string): boolean
        local ok, _slot, err = store:LoadSlotAsync(player, slotId, { createIfMissing = true })
        if not ok then
            Logger.warn("LoadSlot failed for", player, slotId, err)
        end
        return ok
    end)

    local slotLoadedSignal = serverComm:CreateSignal("SlotLoaded")

    store.SlotLoaded:Connect(function(player, handle)
        slotLoadedSignal:Fire(player, handle.Id, handle.Meta)
    end)
end

return NetServer
