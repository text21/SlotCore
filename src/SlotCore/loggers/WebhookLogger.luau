local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local WebhookLogger = {}

function WebhookLogger.new(config)
    assert(config and config.url, "WebhookLogger requires config.url")
    local self = {}
    self.url = config.url
    self.authHeader = config.authHeader
    return self
end

function WebhookLogger:send(payload)
    local body = HttpService:JSONEncode(payload)
    local headers = { ["Content-Type"] = "application/json" }
    if self.authHeader then headers["Authorization"] = self.authHeader end
    pcall(function()
        HttpService:PostAsync(self.url, body, Enum.HttpContentType.ApplicationJson, false, headers)
    end)
end

function WebhookLogger:log(level, message, meta)
    local payload = {
        level = level,
        message = message,
        meta = meta,
        ts = os.time(),
    }
    self:send(payload)
end

return WebhookLogger
