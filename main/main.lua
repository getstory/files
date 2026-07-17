local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local NORMAL_SPEED = 16
local BOOST_SPEED = 700

local KEY = Enum.KeyCode.V -- Change this key

local enabled = false

local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.WalkSpeed = NORMAL_SPEED

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == KEY then
			enabled = not enabled

			if enabled then
				humanoid.WalkSpeed = BOOST_SPEED
				print("WalkSpeed ON")
			else
				humanoid.WalkSpeed = NORMAL_SPEED
				print("WalkSpeed OFF")
			end
		end
	end)
end

if player.Character then
	setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)
