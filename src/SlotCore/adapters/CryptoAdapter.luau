local HttpService = game:GetService("HttpService")

local CryptoAdapter = {}

local function toBytes(str)
    local bytes = {}
    for i = 1, #str do
        bytes[i] = string.byte(str, i)
    end
    return bytes
end

local function fromBytes(bytes)
    local chars = {}
    for i = 1, #bytes do
        chars[i] = string.char(bytes[i])
    end
    return table.concat(chars)
end

local function hexEncode(str)
    return (str:gsub('.', function(c) return string.format('%02x', string.byte(c)) end))
end

local function hexDecode(hex)
    return (hex:gsub('..', function(cc) return string.char(tonumber(cc, 16)) end))
end

function CryptoAdapter.new(key)
    assert(key and #tostring(key) > 0, "CryptoAdapter requires a non-empty key")
    local self = {}
    self._key = tostring(key)

    function self:encrypt(value)
        local plaintext
        if type(value) == "string" then
            plaintext = value
        else
            plaintext = HttpService:JSONEncode(value)
        end
        local keyBytes = toBytes(self._key)
        local outBytes = {}
        for i = 1, #plaintext do
            local b = string.byte(plaintext, i)
            local k = keyBytes[((i - 1) % #keyBytes) + 1]
            outBytes[i] = bit32.bxor(b, k)
        end
        local ob = fromBytes(outBytes)
        return hexEncode(ob)
    end

    function self:decrypt(hexstr)
        if not hexstr or type(hexstr) ~= "string" then
            return nil
        end
        local ob = hexDecode(hexstr)
        local keyBytes = toBytes(self._key)
        local outBytes = {}
        for i = 1, #ob do
            local b = string.byte(ob, i)
            local k = keyBytes[((i - 1) % #keyBytes) + 1]
            outBytes[i] = bit32.bxor(b, k)
        end
        local plain = fromBytes(outBytes)
        local ok, val = pcall(function() return HttpService:JSONDecode(plain) end)
        if ok then
            return val
        end
        return plain
    end

    return self
end

return CryptoAdapter
