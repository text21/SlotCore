--!strict

local Logger = {}

local enabled = true
local prefix = "[SlotCore]"
local conch_log = nil
local adapters = {}

function Logger.setEnabled(e)
    enabled = e
end

function Logger.setPrefix(p)
    prefix = p
end

function Logger.setConch(c)
    conch_log = c
end

function Logger.registerAdapter(name, fn)
    adapters[name] = fn
end

local function callAdapters(level, msg)
    for name, fn in pairs(adapters) do
        pcall(fn, level, msg)
    end
end

local function format(...)
    local parts = {}
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        table.insert(parts, tostring(v))
    end
    return table.concat(parts, " ")
end

function Logger.debug(...)
    if not enabled then
        return
    end
    local msg = format(...)
    if conch_log then
        pcall(function() conch_log("debug", prefix .. " " .. msg) end)
    else
        print(prefix, msg)
    end
    pcall(function() callAdapters("debug", prefix .. " " .. msg) end)
end

function Logger.info(...)
    if not enabled then
        return
    end
    local msg = format(...)
    if conch_log then
        pcall(function() conch_log("info", prefix .. " " .. msg) end)
    else
        print(prefix, msg)
    end
    pcall(function() callAdapters("info", prefix .. " " .. msg) end)
end

function Logger.warn(...)
    if not enabled then
        return
    end
    local msg = format(...)
    if conch_log then
        pcall(function() conch_log("warn", prefix .. " " .. msg) end)
    else
        warn(prefix, msg)
    end
    pcall(function() callAdapters("warn", prefix .. " " .. msg) end)
end

function Logger.error(...)
    if not enabled then
        return
    end
    local msg = format(...)
    if conch_log then
        pcall(function() conch_log("error", prefix .. " " .. msg) end)
    else
        warn(prefix, msg)
    end
    pcall(function() callAdapters("error", prefix .. " " .. msg) end)
end

return Logger
