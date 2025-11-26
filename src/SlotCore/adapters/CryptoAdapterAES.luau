-- Production-grade CryptoAdapter sample (wrapper)
-- This module attempts to use a proper AES implementation from `Packages.AES` if available.
-- If not found, it falls back to the dev `CryptoAdapter` (XOR obfuscator) and logs a warning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:FindFirstChild("Packages")
local HttpService = game:GetService("HttpService")

local AES = nil
local ok, aesMod = pcall(function()
    if Packages and Packages:FindFirstChild("AES") then
        return require(Packages.AES)
    end
    return nil
end)
if ok and aesMod then
    AES = aesMod
end

local fallback = nil
local function loadFallback()
    if not fallback then
        local ok2, dev = pcall(function()
            return require(script.Parent.adapters.CryptoAdapter)
        end)
        if ok2 and dev then
            fallback = dev
        end
    end
    return fallback
end

local CryptoAdapterAES = {}

function CryptoAdapterAES.new(opts)
    opts = opts or {}
    assert(opts.key and #tostring(opts.key) > 0, "CryptoAdapterAES requires a 'key' option")

    if AES then
        -- If an AES package exists, wrap its interface
        local instance = {}
        instance._aes = AES.new(tostring(opts.key))

        function instance:encrypt(value)
            local plain
            if type(value) == "string" then plain = value else plain = HttpService:JSONEncode(value) end
            return instance._aes:encrypt(plain)
        end

        function instance:decrypt(cipher)
            local ok, dec = pcall(function() return instance._aes:decrypt(cipher) end)
            if not ok then return nil end
            local ok2, val = pcall(function() return HttpService:JSONDecode(dec) end)
            if ok2 then return val end
            return dec
        end

        return instance
    end

    -- Fallback: warn and use dev adapter
    warn("CryptoAdapterAES: AES package not found in Packages; falling back to dev adapter. Replace with a secure AES provider for production.")
    local dev = loadFallback()
    if dev then
        return dev.new(opts.key)
    end
    error("No crypto provider available")
end

return CryptoAdapterAES
