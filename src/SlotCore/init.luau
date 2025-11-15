--!strict

local ConfigDefaults = require(script.ConfigDefaults)
local SlotStore = require(script.SlotStore)
local types = require(script.SlotTypes)

type SlotConfig = types.SlotConfig
type SlotStoreType = types.SlotStore

local SlotCore = {}
local _stores: { [string]: SlotStoreType } = {}

function SlotCore.CreateStore(name: string, config: SlotConfig): SlotStoreType
    assert(not _stores[name], ("SlotCore store '%s' already exists"):format(name))
    local cfg = ConfigDefaults.apply(name, config)
    local store = SlotStore.new(name, cfg)
    _stores[name] = store
    return store
end

function SlotCore.GetStore(name: string): SlotStoreType?
    return _stores[name]
end

return SlotCore
