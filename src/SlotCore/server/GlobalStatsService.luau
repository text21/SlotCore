
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalStatsService = {}

function GlobalStatsService.Bind(store, mapping, opts)
    opts = opts or {}
    local prefix = opts.prefix or ("SlotCore_" .. store.Name)

	-- prefetch options
	local prefetch = opts.prefetch or false
	local prefetchKeys = opts.prefetchKeys or {}

	local dsCache = {}

	local function getOrdered(statName)
		local existing = dsCache[statName]
		if existing then
			return existing
		end

		local ds = DataStoreService:GetOrderedDataStore(prefix .. "_" .. statName)
		dsCache[statName] = ds
		return ds
	end

	store.SlotSaved:Connect(function(player, handle)
		local userId = player and player.UserId

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

	if prefetch then
		store.SlotLoaded:Connect(function(player, handle)
			for _, key in ipairs(prefetchKeys) do
				pcall(function()
					local ds = getOrdered(key)
					local pages = ds:GetSortedAsync(false, 100)
				end)
			end
		end)
	end
end

function GlobalStatsService.GetTopSegmentAsync(statName, segment, opts)
	opts = opts or {}
	local prefixBase = opts.prefix or "SlotCore"
	local pageSize = opts.pageSize or 10
	local ascending = opts.ascending or false
	local fullPrefix = prefixBase .. ":" .. segment
	local ds = DataStoreService:GetOrderedDataStore(fullPrefix .. "_" .. statName)
	local pages = ds:GetSortedAsync(not ascending, pageSize, -math.huge, math.huge)
	local page = pages:GetCurrentPage()
	local result = {}
	for _, entry in ipairs(page) do
		table.insert(result, { userId = tonumber(entry.key), value = entry.value })
	end
	return result
end

function GlobalStatsService.GetCurrentPeriodPrefix(statName, period)
	local now = os.date("!%Y-%m-%d")
	if string.lower(period) == "weekly" then
		local year = os.date("%Y")
		local week = tostring(os.date("%W"))
		return string.format("%s_Weekly_%s_w%s", statName, year, week)
	elseif string.lower(period) == "monthly" then
		local year = os.date("%Y")
		local month = os.date("%m")
		return string.format("%s_Monthly_%s_m%s", statName, year, month)
	else
		return string.format("%s_Daily_%s", statName, now)
	end
end

function GlobalStatsService.GetTopAsync(statName, opts)
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

function GlobalStatsService.GetPlayerRankAsync(statName, userId, opts)
	opts = opts or {}
	local prefix = opts.prefix or "SlotCore"
	local pageSize = opts.pageSize or 100
	local maxPages = opts.maxPages or 50

	local ds = DataStoreService:GetOrderedDataStore(prefix .. "_" .. statName)
	local pages = ds:GetSortedAsync(false, pageSize)
	local pageIndex = 0
	local rankBase = 0

	while true do
		pageIndex = pageIndex + 1
		local page = pages:GetCurrentPage()
		for i, entry in ipairs(page) do
			local keyNum = tonumber(entry.key)
			if keyNum == userId then
				return rankBase + i, entry.value
			end
		end

		if pageIndex >= maxPages then
			return nil, "NOT_FOUND"
		end

		local ok, err = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not ok then
			return nil, err
		end
		rankBase = rankBase + #page
		local finished = pages.IsFinished
		if finished then
			return nil, "NOT_FOUND"
		end
	end
end

return GlobalStatsService
