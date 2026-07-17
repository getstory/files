local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Config = shared.Story

local WalkSpeedConfig = Config.Character.WalkSpeed
local Keybind = Config.General.HotKeys.WalkSpeed

local enabled = false

local function getKey()
	return Enum.KeyCode[Keybind]
end

local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.WalkSpeed = WalkSpeedConfig.Default

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end

		if input.KeyCode == getKey() then
			enabled = not enabled

			if enabled and WalkSpeedConfig.Enabled then
				humanoid.WalkSpeed = WalkSpeedConfig.Value
			else
				humanoid.WalkSpeed = WalkSpeedConfig.Default
			end
		end
	end)
end

if player.Character then
	setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)
