local Players = game:GetService "Players"

local console = require "./console"
local context = require "./context"
local types = require "./types"

local function noop(v: any) return v end

local function wrap_if_not(value)
	return if type(value) == "table" then value else { value }
end

local anyT = {
	convert = noop :: (any) -> any,

	analysis = {
		kind = "argument" :: "argument",
		optional = false,
		name = "any",
		type = "any",
	},
}

local stringT = {
	convert = tostring :: (string) -> string,

	analysis = {
		kind = "argument",
		optional = false,
		name = "string",
		type = "string",
	},
}

local stringsT = {
	convert = function(value)
		if typeof(value) == "table" then
			local copy = table.clone(value)
			for k, v in copy do
				copy[k] = tostring(v)
			end
			return copy
		else
			return { tostring(value) }
		end
	end,

	analysis = {
		kind = "argument",
		optional = false,
		name = "strings",
		type = "{ string }",
	},
}

local numberT = {
	convert = noop,

	analysis = {
		kind = "argument",
		optional = false,
		name = "number",
		type = "number",
	},
}

local numbersT = {
	convert = wrap_if_not,

	analysis = {
		kind = "argument",
		optional = false,
		name = "numbers",
		type = "{ number }",
	},
}

local booleanT = {
	convert = function(v)
		if typeof(v) == "boolean" then
			return v
		elseif typeof(v) == "number" and v > 0 then
			return true
		elseif typeof(v) == "number" and v <= 0 then
			return false
		else
			error(`{typeof(v)} is not a valid boolean`)
		end
	end,

	analysis = {
		kind = "argument",
		optional = false,
		name = "boolean",
		type = "boolean",

		suggestion_generator = function(text: string)
			local suggestions = {}

			if string.sub("true", 1, #text) == text then
				table.insert(suggestions, "true")
			end

			if string.sub("false", 1, #text) == text then
				table.insert(suggestions, "false")
			end

			return suggestions
		end,
	},
}

local booleansT = {
	convert = function(value: unknown): { boolean }
		if typeof(value) == "table" then
			local copy = table.clone(value) :: { [any]: any }
			for k, v in copy do
				if typeof(v) == "boolean" then
					copy[k] = v
				elseif typeof(v) == "number" and v > 0 then
					copy[k] = true
				elseif typeof(v) == "number" and v <= 0 then
					copy[k] = false
				else
					error(`type {typeof(v)} of {k} is not a valid boolean`)
				end
			end
			return copy
		elseif typeof(value) == "boolean" then
			return { value }
		elseif typeof(value) == "number" and value > 0 then
			return { true }
		elseif typeof(value) == "number" and value <= 0 then
			return { false }
		else
			error(`{typeof(value)} is not a valid boolean`)
		end
	end,

	analysis = {
		kind = "argument",
		optional = false,
		name = "boolean",
		type = "boolean",

		suggestion_generator = function(text: string)
			local suggestions = {}

			if string.sub("true", 1, #text) == text then
				table.insert(suggestions, "true")
			end

			if string.sub("false", 1, #text) == text then
				table.insert(suggestions, "false")
			end

			return suggestions
		end,
	},
}

local tableT = {
	convert = noop,

	analysis = {
		kind = "argument",
		optional = false,
		name = "table",
		type = "table",
	},
}

local function into_vector(value: vector | Vector3 | { number }): vector
	if type(value) == "vector" then
		return value
	elseif typeof(value) == "table" then
		return vector.create(value[1] or 0, value[2] or 0, value[3] or 0)
	else
		error(`{value} is not valid`, 0)
	end
end

local vectorT = {
	convert = into_vector,

	analysis = {
		kind = "argument",
		optional = false,
		name = "vector",
		type = "vector",
	},
}
local vectorsT = {
	convert = function(
		value: vector | Vector3 | { vector | Vector3 | { number } }
	): { vector }
		if type(value) == "vector" then
			return { value }
		elseif typeof(value) == "table" then
			local t = {}
			for i, v in value do
				t[i] = into_vector(v)
			end
			return t
		else
			error(`{value} is not valid`, 0)
		end
	end,

	analysis = {
		kind = "argument",
		optional = false,
		name = "vector",
		type = "vector",
	},
}

--[=[
Generates a new enum that can be passed to conch.register_type. It maps each string in a table to a specific value.
]=]
local function enum_map<V>(
	map: { [string]: V },
	name: string?,
	description: string?
)
	return {
		convert = function(value): V
			local key = tostring(value)
			if map[key] == nil then error(`{key} is not valid`, 0) end
			return map[key]
		end,

		analysis = {
			kind = "argument",
			optional = false,
			name = name or "enum",
			description = description,
			type = name or "enum",
			suggestion_generator = function(text: string)
				text = text:lower()
				local suggestions = {}
				for key in map do
					if string.sub(key:lower(), 1, #text) ~= text then
						continue
					end
					table.insert(suggestions, key)
				end
				return suggestions
			end,
		},
	}
end

--[=[
Generates a new enum that can be passed to conch.register_type
]=]
local function enum_new<T>(options: { T }, name: string?, description: string?)
	local map = {}

	for _, value in options do
		map[tostring(value)] = value
	end

	return enum_map(map, name, description)
end

local function convert_arg_to_player(arg: string | number | "@s"): Player
	local ctx = context.get_command_context()
	if arg == "@s" then
		return ctx and ctx.executor.player or error "not executed by a player"
	elseif typeof(arg) == "number" then
		local player = assert(
			Players:GetPlayerByUserId(arg),
			`player with id {arg} is not in this server`
		)
		return player
	elseif typeof(arg) == "string" then
		local player = assert(
			Players:FindFirstChild(arg) :: Player,
			`player "{arg}" is not valid`
		)
		return player
	else
		error(`unknown arg {arg}`)
	end
end

local function convert_arg_to_players(
	arg: string | number | "@s" | "@a" | { any }
)
	if arg == "@a" then
		return Players:GetPlayers()
	elseif typeof(arg) == "table" then
		local copy = table.clone(arg)

		for idx, plr in copy do
			copy[idx] = convert_arg_to_player(plr)
		end

		return copy
	else
		return { convert_arg_to_player(arg) }
	end
end

local playerT = {
	convert = function(player) return convert_arg_to_player(player) end,

	analysis = {
		kind = "argument",
		optional = false,
		name = "player",
		type = "Player",
		suggestion_generator = function(text: string)
			text = text:lower()
			local suggestions = {}

			if string.sub("@s", 1, #text) == text then
				table.insert(suggestions, "@s")
			end

			for _, player in Players:GetPlayers() do
				if
					string.sub(player.Name:lower(), 1, #text) == text
					or string.sub(player.DisplayName:lower(), 1, #text)
						== text
				then
					table.insert(suggestions, player.Name)
				end
			end

			return suggestions
		end,
	},
}

local playersT = {
	kind = "any",
	convert = function(players) return convert_arg_to_players(players) end,

	analysis = {
		kind = "argument",
		optional = false,
		name = "players",
		type = "{ Player }",
		suggestion_generator = function(text: string)
			text = text:lower()
			local suggestions = {}

			if string.sub("@s", 1, #text) == text then
				table.insert(suggestions, "@s")
			end
			if string.sub("@a", 1, #text) == text then
				table.insert(suggestions, "@a")
			end

			for _, player in Players:GetPlayers() do
				if
					string.sub(player.Name:lower(), 1, #text) == text
					or string.sub(player.DisplayName:lower(), 1, #text)
						== text
				then
					table.insert(suggestions, player.Name)
				end
			end

			return suggestions
		end,
	},
}

local function generate_names_for_enum(enum: Enum)
	local map = {}

	for _, item: EnumItem in enum:GetEnumItems() do
		map[item.Name] = item
	end

	return enum_map(map, tostring(enum))
end

type G<T> = (name: string?, description: string?) -> T

local function variadic<T>(argument: T): ...T
	local a: types.Type = argument :: any
	a.kind = "varargs"
	return a
end

local function optional<T>(argument: T): T | nil
	local a: types.Type = argument :: any
	a.optional = true
	return a
end

return {

	any = console.register_type("any", anyT) :: G<any>,
	string = console.register_type("string", stringT) :: G<string>,
	strings = console.register_type("strings", stringsT) :: G<{ string }>,
	number = console.register_type("number", numberT) :: G<number>,
	numbers = console.register_type("numbers", numbersT) :: G<{ number }>,
	boolean = console.register_type("boolean", booleanT) :: G<boolean>,
	booleans = console.register_type("booleans", booleansT) :: G<{ boolean }>,
	table = console.register_type("table", tableT) :: G<{}>,
	vector = console.register_type("vector", vectorT) :: G<vector>,
	vectors = console.register_type("vectors", vectorsT) :: G<{ vector }>,
	player = console.register_type("player", playerT) :: G<Player>,
	players = console.register_type("players", playersT) :: G<{ Player }>,

	userinput = console.register_type(
		"userinput",
		generate_names_for_enum(Enum.UserInputType)
	) :: G<Enum.UserInputType>,

	variadic = variadic,
	optional = optional,
	opt = optional,

	enum_new = enum_new,
	enum_map = enum_map,
}
