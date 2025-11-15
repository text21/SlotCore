--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Comm = require(Packages.Comm)
local ClientComm = Comm.ClientComm
local Signal = require(Packages.Signal)

local NetClient = {}
NetClient.__index = NetClient

function NetClient.new(storeName: string)
    local self = setmetatable({}, NetClient)

    local root = script.Parent
    local folder = root:WaitForChild(storeName)

    local clientComm = ClientComm.new(folder, false)

    self._getSlots = clientComm:GetFunction("GetSlots")
    self._loadSlot = clientComm:GetFunction("LoadSlot")

    self.SlotLoaded = Signal.new()
    local slotLoadedSignal = clientComm:GetSignal("SlotLoaded")
    slotLoadedSignal:Connect(function(slotId: string, meta: any)
        self.SlotLoaded:Fire(slotId, meta)
    end)

    return self
end

function NetClient:GetSlotsAsync()
    return self._getSlots()
end

function NetClient:LoadSlotAsync(slotId: string)
    return self._loadSlot(slotId)
end

return NetClient
