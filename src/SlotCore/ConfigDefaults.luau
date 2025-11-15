--!strict

local types = require(script.Parent.SlotTypes)
type SlotConfig = types.SlotConfig

local ConfigDefaults = {}

function ConfigDefaults.apply(name: string, config: SlotConfig): SlotConfig
    local cfg = table.clone(config)

    cfg.dataStoreName = cfg.dataStoreName or ("SlotCore_" .. name)
    cfg.scope = cfg.scope or "global"
    cfg.autoSaveInterval = cfg.autoSaveInterval or 60
    cfg.saveOnLeave = if cfg.saveOnLeave == nil then true else cfg.saveOnLeave
    cfg.saveOnTeleport = if cfg.saveOnTeleport == nil then true else cfg.saveOnTeleport
    cfg.defaultMeta = cfg.defaultMeta or {}
    cfg.accountTemplate = cfg.accountTemplate or {}
    cfg.version = cfg.version or 1

    if not cfg.allowedSlotIds then
        cfg.allowedSlotIds = {}
        for i = 1, cfg.maxSlots do
            table.insert(cfg.allowedSlotIds, tostring(i))
        end
    end

    return cfg
end

return ConfigDefaults
