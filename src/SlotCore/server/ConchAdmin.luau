--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local types = require(script.Parent.Parent.SlotTypes)
local AdminConfig = require(script.Parent.AdminConfig)

type SlotStore = types.SlotStore
type SlotSummary = types.SlotSummary

local Logger = require(script.Parent.Parent.Logger)
local conch = nil

local ConchAdmin = {}

local function giveRolesFromConfig()
	for userId, roles in pairs(AdminConfig.UserRoles) do
		local plr = Players:GetPlayerByUserId(userId)
		if plr then
			local user = conch.get_user(plr)
			conch.give_roles(user, table.unpack(roles))
		end
	end

	Players.PlayerAdded:Connect(function(plr)
		local roles = AdminConfig.UserRoles[plr.UserId]
		if roles and #roles > 0 then
			local user = conch.get_user(plr)
			conch.give_roles(user, table.unpack(roles))
		end
	end)
end

function ConchAdmin.init(storeName: string, store: SlotStore, rawConfig: any)
	if not AdminConfig.Enabled then
		return
	end

	local ok, mod = pcall(function()
		return require(ReplicatedStorage.Packages.conch)
	end)

	if not ok or not mod then
		Logger.warn("Conch package not available; admin commands disabled for store", storeName)
		return
	end

	conch = mod

	conch.initiate_default_lifecycle()
	conch.register_default_commands()

	for role, perms in pairs(AdminConfig.RolePermissions) do
		conch.set_role_permissions(role, table.unpack(perms))
	end

	giveRolesFromConfig()

	-- slots <player>
	if AdminConfig.Commands.slots then
		conch.register("slots", {
			description = "List SlotCore slots for a player",
			permissions = { "slotcore.view" },
			arguments = function()
				return conch.args.player("player", "Target player")
			end,
			callback = function(targetPlayer: Player)
				local ok, list, err = store:ListSlotsAsync(targetPlayer.UserId)
				if not ok or not list then
					conch.log("error", "slots failed: " .. tostring(err))
					return
				end

				if #list == 0 then
					conch.log("info", "No slots for " .. targetPlayer.Name)
					return
				end

				for _, summary in ipairs(list :: { SlotSummary }) do
					local meta = summary.meta
					local lvl = meta and meta.level or "?"
					local existsStr = summary.exists and "exists" or "empty"
					conch.log(
						"info",
						string.format("[%s] %s (level=%s)", summary.id, existsStr, tostring(lvl))
					)
				end
			end,
		})
	end

	-- load <player> <slotId>
	if AdminConfig.Commands.load then
		conch.register("load", {
			description = "Load / switch slot for a player",
			permissions = { "slotcore.switch" },
			arguments = function()
				return
					conch.args.player("player", "Target player"),
					conch.args.string("slotId", "Slot id (e.g. 1, 2, 3)")
			end,
			callback = function(targetPlayer: Player, slotId: string)
				local ok, _, err =
					store:LoadSlotAsync(targetPlayer, slotId, { createIfMissing = true })

				if not ok then
					conch.log("error", "load failed: " .. tostring(err))
					return
				end

				conch.log(
					"info",
					string.format("Loaded slot '%s' for %s", slotId, targetPlayer.Name)
				)
			end,
		})
	end

	-- wipe <player> <slotId>
	if AdminConfig.Commands.wipe then
		conch.register("wipe", {
			description = "Delete a SlotCore slot for a player",
			permissions = { "slotcore.wipe" },
			arguments = function()
				return
					conch.args.player("player", "Target player"),
					conch.args.string("slotId", "Slot id to wipe")
			end,
			callback = function(targetPlayer: Player, slotId: string)
				local ok, _, err = store:DeleteSlotAsync(targetPlayer.UserId, slotId)
				if not ok then
					conch.log("error", "wipe failed: " .. tostring(err))
					return
				end

				conch.log(
					"info",
					string.format("Deleted slot '%s' for %s", slotId, targetPlayer.Name)
				)
			end,
		})
	end

	-- account <player>
	if AdminConfig.Commands.account then
		conch.register("account", {
			description = "Show SlotCore account data for a player",
			permissions = { "slotcore.view" },
			arguments = function()
				return conch.args.player("player", "Target player")
			end,
			callback = function(targetPlayer: Player)
				local account = store:GetDocumentAccount(targetPlayer)
				if not account then
					conch.log("info", "No account data loaded for this player.")
					return
				end

				local pieces = {}
				for k, v in pairs(account) do
					table.insert(pieces, tostring(k) .. "=" .. tostring(v))
				end

				conch.log("info", "Account: {" .. table.concat(pieces, ", ") .. "}")
			end,
		})
	end

	-- doc <player> (debug)
	if AdminConfig.Commands.doc then
		conch.register("doc", {
			description = "Print full SlotCore document to Output (debug)",
			permissions = { "slotcore.inspect" },
			arguments = function()
				return conch.args.player("player", "Target player")
			end,
			callback = function(targetPlayer: Player)
				local ok, doc, err = store:DebugPeekDocumentAsync(targetPlayer.UserId)
				if not ok or not doc then
					conch.log("error", "doc failed: " .. tostring(err))
					return
				end

				Logger.info("Full document for", targetPlayer.Name, doc)
				conch.log("info", "Printed full document to server Output.")
			end,
		})
	end

	-- add <player> <field> <amount>
	if AdminConfig.Commands.add then
		conch.register("add", {
			description = "Add numeric amount to a SlotCore field",
			permissions = { "slotcore.modify" },
			arguments = function()
				return
					conch.args.player("player", "Target player"),
					conch.args.string("field", "Field name (e.g. coins)"),
					conch.args.number("amount", "Amount to add")
			end,
			callback = function(targetPlayer: Player, field: string, amount: number)
				local handle = store:GetLoadedSlot(targetPlayer)
				if not handle then
					local firstSlot =
						(rawConfig.allowedSlotIds and rawConfig.allowedSlotIds[1]) or "1"

					local ok, h, err = store:LoadSlotAsync(
						targetPlayer,
						firstSlot,
						{ createIfMissing = true }
					)
					if not ok or not h then
						conch.log("error", "add failed to load slot: " .. tostring(err))
						return
					end
					handle = h
				end

				local data = handle.Data
				local current = data[field]
				if current == nil then
					current = 0
				end

				if typeof(current) ~= "number" then
					conch.log("error", "Field '" .. field .. "' is not numeric.")
					return
				end

				local newValue = current + amount
				data[field] = newValue

				local ok, _, err = handle:SaveAsync()
				if not ok then
					conch.log("error", "add failed to save: " .. tostring(err))
					return
				end

				conch.log(
					"info",
					string.format(
						"Updated %s.%s: %s -> %s",
						targetPlayer.Name,
						field,
						tostring(current),
						tostring(newValue)
					)
				)
			end,
		})
	end

		-- set <player> <field> <value>
	if AdminConfig.Commands.set then
		conch.register("set", {
			description = "Set any SlotCore field on a player's active slot.",
			permissions = { "slotcore.modify" },
			arguments = function()
				return
					conch.args.player("player", "Target player"),
					conch.args.string("field", "Field name (e.g. coins)"),
					conch.args.string("value", "Value (number or string)")
			end,
			callback = function(targetPlayer: Player, field: string, value: string)
				local numeric = tonumber(value)
				local newValue: any = numeric or value

				local handle = store:GetLoadedSlot(targetPlayer)
				if not handle then
					local firstSlot =
						(rawConfig.allowedSlotIds and rawConfig.allowedSlotIds[1]) or "1"

					local ok, h, err = store:LoadSlotAsync(
						targetPlayer,
						firstSlot,
						{ createIfMissing = true }
					)

					if not ok or not h then
						conch.log("error", "set failed to load slot: " .. tostring(err))
						return
					end

					handle = h
				end

				local data = handle.Data
				data[field] = newValue

				local ok, _, err = handle:SaveAsync()
				if not ok then
					conch.log("error", "set failed to save: " .. tostring(err))
					return
				end

				conch.log(
					"info",
					string.format(
						"Set %s.%s to %s",
						targetPlayer.Name,
						field,
						tostring(newValue)
					)
				)
			end,
		})
	end

	Logger.info("Conch admin commands registered for store '" .. storeName .. "'")
end

return ConchAdmin
