--!strict

local TableUtil = require(script.Parent.Packages.TableUtil)

local Schema = {}

-- Example schema format:
-- { required = {"coins"}, defaults = { coins = 0 }, types = { coins = "number" } }
function Schema.CreateSchema(def: any)
    local obj = {}
    obj._def = def or {}

    function obj:applyDefaults(doc: any)
        doc = doc or {}
        doc.slots = doc.slots or {}
        for slotId, slot in pairs(doc.slots) do
            slot.data = slot.data or {}
            for k, v in pairs(obj._def.defaults or {}) do
                if slot.data[k] == nil then
                    slot.data[k] = TableUtil.Copy(v)
                end
            end
        end
    end

    function obj:validate(doc: any)
        local missing = {}
        for slotId, slot in pairs(doc.slots or {}) do
            for _, req in ipairs(obj._def.required or {}) do
                if slot.data[req] == nil then
                    table.insert(missing, string.format("slot %s missing required field '%s'", tostring(slotId), tostring(req)))
                end
            end
        end
        if #missing > 0 then
            return false, table.concat(missing, "; ")
        end
        return true, nil
    end

    return obj
end

return Schema
