--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local function isAdminEnabled()
	local parent = script and script.Parent
	if not parent then
		return true
	end
	local root = parent.Parent
	if not root then
		return true
	end
	local serverFolder = root:FindFirstChild("server")
	if not serverFolder then
		return true
	end
	local adminModule = serverFolder:FindFirstChild("AdminConfig")
	if not adminModule then
		return true
	end
	local ok, cfg = pcall(function()
		return require(adminModule)
	end)
	if not ok or not cfg then
		return true
	end
	return cfg.Enabled ~= false
end

if not isAdminEnabled() then
	return {}
end

local function ensureConchNetworking()
	if ReplicatedStorage:FindFirstChild("conch_networking") then
		return
	end

	if RunService:IsStudio() then
		local folder = Instance.new("Folder")
		folder.Name = "conch_networking"
		folder.Parent = ReplicatedStorage
	end
end

local Packages = ReplicatedStorage:WaitForChild("Packages")

ensureConchNetworking()

local okConch, conch = pcall(function() return require(Packages.conch) end)
local okUI, ui = pcall(function() return require(Packages.conch_ui) end)

if not okConch or not conch or not okUI or not ui then
	return {}
end

pcall(function()
	conch.initiate_default_lifecycle()
	ui.mount(conch)
	ui.bind_to(Enum.KeyCode.F4)
end)

return {}
