--!strict

local DataStoreService = game:GetService("DataStoreService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local types = require(ReplicatedStorage.SlotCore.SlotTypes)

type SlotStore = types.SlotStore
type SlotHandle = types.SlotHandle

type StatMapping = { [string]: (SlotHandle) -> number }

export type GlobalStatsOptions = {
	prefix: string?,
}

local GlobalStatsService = {}

function GlobalStatsService.Bind(store: SlotStore, mapping: StatMapping, opts: GlobalStatsOptions?)
	opts = opts or {}
	local prefix = opts.prefix or ("SlotCore_" .. store.Name)

	local dsCache: { [string]: OrderedDataStore } = {}

	local function getOrdered(statName: string): OrderedDataStore
		local existing = dsCache[statName]
		if existing then
			return existing
		end

		local ds = DataStoreService:GetOrderedDataStore(prefix .. "_" .. statName)
		dsCache[statName] = ds
		return ds
	end

	store.SlotSaved:Connect(function(player: Player, handle: SlotHandle)
		local userId = player.UserId

		for statName, resolver in pairs(mapping) do
			local ok, value = pcall(resolver, handle)
			if ok and typeof(value) == "number" then
				local ds = getOrdered(statName)

				task.spawn(function()
					pcall(function()
						ds:SetAsync(tostring(userId), value)
					end)
				end)
			end
		end
	end)
end

function GlobalStatsService.GetTopAsync(statName: string, opts: { prefix: string?, pageSize: number?, ascending: boolean? }?)
	opts = opts or {}
	local prefix = opts.prefix or "SlotCore"
	local pageSize = opts.pageSize or 10
	local ascending = opts.ascending or false

	local ds = DataStoreService:GetOrderedDataStore(prefix .. "_" .. statName)
	local pages = ds:GetSortedAsync(not ascending, pageSize, -math.huge, math.huge)
	local page = pages:GetCurrentPage()

	local result = {}

	for _, entry in ipairs(page) do
		table.insert(result, {
			userId = tonumber(entry.key),
			value = entry.value,
		})
	end

	return result
end

return GlobalStatsService
