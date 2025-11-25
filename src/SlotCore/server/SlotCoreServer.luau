--!strict

local SlotCore = require(script.Parent.Parent)
local NetServer = require(script.Parent.Parent.net.NetServer)
local ConchAdmin = require(script.Parent.ConchAdmin)
local Logger = require(script.Parent.Parent.Logger)

local Server = {}

function Server.CreateStore(name: string, config)
	local store = SlotCore.CreateStore(name, config)
	NetServer.bind(name, store)

	local ok, err = pcall(function()
		ConchAdmin.init(name, store, config)
	end)
	if not ok then
		Logger.warn("Conch admin init failed for store", name, err)
	end

	return store
end

return Server
