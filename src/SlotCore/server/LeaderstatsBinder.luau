--!strict

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages.Trove)

local types = require(script.Parent.Parent.SlotTypes)
type SlotStore = types.SlotStore
type SlotHandle = types.SlotHandle

local Binder = {}
Binder.__index = Binder

local function ensureLeaderstats(player: Player, mapping: { [string]: (SlotHandle) -> number }): Folder
	local folder = player:FindFirstChild("leaderstats") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end

	for name in pairs(mapping) do
		local v = folder:FindFirstChild(name) :: IntValue?
		if not v then
			v = Instance.new("IntValue")
			v.Name = name
			v.Value = 0
			v.Parent = folder
		end
	end

	return folder
end

local function updateStats(player: Player, handle: SlotHandle, mapping: { [string]: (SlotHandle) -> number })
	local folder = ensureLeaderstats(player, mapping)

	for name, resolver in pairs(mapping) do
		local v = folder:FindFirstChild(name) :: IntValue?
		if v then
			local ok, result = pcall(resolver, handle)
			if ok and typeof(result) == "number" then
				v.Value = result
			end
		end
	end
end

function Binder.Bind(store: SlotStore, mapping: { [string]: (SlotHandle) -> number })
	local perPlayerTrove: { [Player]: any } = {}

	local function getTrove(plr: Player)
		local t = perPlayerTrove[plr]
		if not t then
			t = Trove.new()
			perPlayerTrove[plr] = t
		end
		return t
	end

	store.SlotLoaded:Connect(function(player: Player, handle: SlotHandle)
		getTrove(player)
		updateStats(player, handle, mapping)
	end)

	store.SlotSaved:Connect(function(player: Player, handle: SlotHandle)
		updateStats(player, handle, mapping)
	end)

	store.SlotReleased:Connect(function(player: Player)
		-- keep stats, or uncomment to clean up:
		-- local t = perPlayerTrove[player]
		-- if t then
		--     t:Destroy()
		--     perPlayerTrove[player] = nil
		-- end
	end)
end

return Binder
