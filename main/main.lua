local Config = shared.Story
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer


repeat task.wait() until shared.Story
local Enabled = Config.Character.WalkSpeed.Enabled
local Speed = Config.Character.WalkSpeed.Value
local Default = Config.Character.WalkSpeed.Default
local Key = Config.General.HotKeys.WalkSpeed

print("Loaded WalkSpeed Config")
print("Speed:", Speed)
print("Key:", Key)

local function updateSpeed()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if Enabled then
		humanoid.WalkSpeed = Speed
	else
		humanoid.WalkSpeed = Default
	end

	print("Current Speed:", humanoid.WalkSpeed)
end


local function setup(character)
	local humanoid = character:WaitForChild("Humanoid")

	if Enabled then
		humanoid.WalkSpeed = Speed
	else
		humanoid.WalkSpeed = Default
	end

	print("Character loaded")
end


player.CharacterAdded:Connect(setup)


UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	print("Pressed:", input.KeyCode)

	if input.KeyCode == Enum.KeyCode[Key] then
		Enabled = not Enabled
		
		print("WalkSpeed Toggle:", Enabled)

		updateSpeed()
	end
end)


if player.Character then
	setup(player.Character)
end
