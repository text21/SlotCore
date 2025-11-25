--!strict

local types = require(script.Parent.SlotTypes)
type SlotConfig = types.SlotConfig
local RunService = game:GetService("RunService")
local AdminConfig = require(script.Parent.server.AdminConfig)

local ConfigDefaults = {}

function ConfigDefaults.apply(name: string, config: SlotConfig): SlotConfig
    local cfg = table.clone(config)

    local baseName = cfg.dataStoreName or ("SlotCore_" .. name)
    if RunService:IsStudio() and AdminConfig.UseDevDataInStudio then
        cfg.dataStoreName = "dev-" .. baseName
        cfg.scope = cfg.scope or "dev"
    else
        cfg.dataStoreName = baseName
        cfg.scope = cfg.scope or "global"
    end
    cfg.autoSaveInterval = cfg.autoSaveInterval or 60
    cfg.saveOnLeave = if cfg.saveOnLeave == nil then true else cfg.saveOnLeave
    cfg.saveOnTeleport = if cfg.saveOnTeleport == nil then true else cfg.saveOnTeleport
    cfg.defaultMeta = cfg.defaultMeta or {}
    cfg.accountTemplate = cfg.accountTemplate or {}
    cfg.version = cfg.version or 1

    if not cfg.maxSlots or type(cfg.maxSlots) ~= "number" or cfg.maxSlots < 1 then
        error("SlotCore: config.maxSlots must be a positive number (e.g. 1, 2, 3)")
    end

    if not cfg.slotTemplate or type(cfg.slotTemplate) ~= "table" then
        error("SlotCore: config.slotTemplate must be a table (the default slot data)")
    end

    if not cfg.allowedSlotIds then
        cfg.allowedSlotIds = {}
        for i = 1, cfg.maxSlots do
            table.insert(cfg.allowedSlotIds, tostring(i))
        end
    end

    return cfg
end

return ConfigDefaults
