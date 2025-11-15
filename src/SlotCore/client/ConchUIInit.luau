--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local conch = require(Packages.conch)
local ui = require(Packages.conch_ui)

conch.initiate_default_lifecycle()
ui.mount(conch)
ui.bind_to(Enum.KeyCode.F4)

return {}
