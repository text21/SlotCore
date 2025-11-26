--!strict

local Validators = {}

function Validators.NoNegativeNumbers(fields)
    return {
        name = "NoNegativeNumbers",
        validate = function(ctx, handle)
            for _, f in ipairs(fields) do
                local v = handle.Data[f]
                if v ~= nil and type(v) == "number" and v < 0 then
                    return false, "field '" .. f .. "' is negative"
                end
            end
            return true
        end,
    }
end

function Validators.MaxFieldDelta(opts)
    local last = {}
    return {
        name = "MaxFieldDelta",
        validate = function(ctx, handle)
            local user = ctx.userId
            local cur = handle.Data[opts.field] or 0
            local prev = last[user] or cur
            local delta = cur - prev
            if delta > (opts.maxDelta or 100000) then
                return false, "delta too large"
            end
            last[user] = cur
            return true
        end,
    }
end

function Validators.MaxDocumentSize(maxBytes)
    local HttpService = game:GetService("HttpService")
    return {
        name = "MaxDocumentSize",
        validate = function(ctx, handle)
            local ok, encoded = pcall(function()
                return HttpService:JSONEncode(handle.Data)
            end)
            if not ok then return false, "json encode failed" end
            if #encoded > (maxBytes or 64 * 1024) then
                return false, "document too large"
            end
            return true
        end,
    }
end

local RateLimiter = {}
function RateLimiter.new()
    local self = { buckets = {} }
    function self:allow(key, maxPerWindow, windowSeconds)
        local now = os.time()
        local b = self.buckets[key] or { count = 0, windowStart = now }
        if now - b.windowStart > windowSeconds then
            b.count = 0
            b.windowStart = now
        end
        if b.count >= maxPerWindow then
            self.buckets[key] = b
            return false
        end
        b.count = b.count + 1
        self.buckets[key] = b
        return true
    end
    return self
end

Validators.RateLimiter = RateLimiter

return Validators
