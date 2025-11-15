--!strict

local NetClient = require(script.Parent.Parent.net:WaitForChild("NetClient"))

local Client = {}

function Client.ForStore(name: string)
    return NetClient.new(name)
end

return Client
