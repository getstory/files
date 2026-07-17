If this is for your own Roblox Studio game, here is a complete LocalScript version that sets your character speed to 50:

-- WalkSpeed LocalScript
-- Put in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local SPEED = 50

local function setWalkSpeed(character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.WalkSpeed = SPEED

	print("WalkSpeed set to:", humanoid.WalkSpeed)
end

if player.Character then
	setWalkSpeed(player.Character)
end

player.CharacterAdded:Connect(function(character)
	setWalkSpeed(character)
end)

For a real game feature, use a ServerScript instead so players cannot just change their own speed:

-- ServerScript
-- Put in ServerScriptService

local Players = game:GetService("Players")

local SPEED = 50

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		humanoid.WalkSpeed = SPEED
	end)
end)

If you're making an anti-cheat, 
I can help you build a detector that flags abnormal WalkSpeed changes (like clients trying to force 50+).

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local WalkSpeed = 700

local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.WalkSpeed = WalkSpeed

	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if humanoid.WalkSpeed ~= WalkSpeed then
			humanoid.WalkSpeed = WalkSpeed
		end
	end)
end

if player.Character then
	setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter) modify this for a keybind in my current config . lua shared.Story = {
	['General'] = {
		['HotKeys'] = {
			['Target'] = 'C',
			['Aim Assist'] = 'C',
			['Silent Aim'] = 'C',
			['Trigger Bot'] = 'C',
			['WalkSpeed'] = 'V',
			['ESP'] = 'T',
			['Macro'] = '',
			['Panic Ground'] = 'X',
		},

		["Visuals"] = {
			["Info"] = {
				["Enabled"] = false,
				["Alias"] = "",

				["Colors"] = {
					["Story Hue"] = Color3.fromRGB(231, 92, 255),
					["Color"] = Color3.fromRGB(255, 255, 255),
					["TargetColor"] = Color3.fromRGB(255, 0, 0)
				},

				["Position"] = {
					["Size"] = 285,
					["X"] = 0.0045,
					["Y"] = 0.5
				}
			},

			["ESP"] = {
				["Enabled"] = false,
				["Name"] = "Name",
				["Distance"] = 500,
				["Color"] = Color3.fromRGB(255, 255, 255),
				["TargetColor"] = Color3.fromRGB(0, 255, 0),
				["Size"] = 8
			}
		}
	},

	['Character'] = {
		['WalkSpeed'] = {
			['Enabled'] = true,
			['Value'] = 50,
			['Default'] = 16
		}
	}
}

If this is for your own Roblox Studio game, here is the Lua version using your config structure:

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Config = shared.Story

local Enabled = false

local Speed = Config.Character.WalkSpeed.Value
local Default = Config.Character.WalkSpeed.Default
local Key = Config.General.HotKeys.WalkSpeed

local function setSpeed()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if Enabled then
		humanoid.WalkSpeed = Speed
	else
		humanoid.WalkSpeed = Default
	end
end

local function characterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")

	if Enabled then
		humanoid.WalkSpeed = Speed
	else
		humanoid.WalkSpeed = Default
	end
end

player.CharacterAdded:Connect(characterAdded)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.KeyCode == Enum.KeyCode[Key] then
		Enabled = not Enabled
		setSpeed()

		print("WalkSpeed Enabled:", Enabled)
	end
end)

if player.Character then
	characterAdded(player.Character)
end

With your config:

['WalkSpeed'] = 'V',

['WalkSpeed'] = {
    ['Enabled'] = true,
    ['Value'] = 50,
    ['Default'] = 16
}

Press V → 50 speed
Press V again → back to 16 speed.

nope aint work

If this is inside your own Roblox Studio project, the reason it probably didn't work is likely your config path or shared.Story loading order.

Try this version with debug prints:

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

repeat task.wait() until shared.Story

local Config = shared.Story

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

Check your output. You should see:

Loaded WalkSpeed Config
Speed: 50
Key: V
Pressed: Enum.KeyCode.V
WalkSpeed Toggle: true
Current Speed: 50

If you only see the first two lines, your keybind is not firing.

If you see the toggle but speed stays 16, another script is resetting Humanoid.WalkSpeed (common with sprint/character controllers).

Your debug shows the keybind is working correctly.

From your output:

Pressed: Enum.KeyCode.V
WalkSpeed Toggle: true
Current Speed: 50

✅ Config loads
✅ V key detects
✅ Toggle works
✅ Humanoid speed changes to 50

Then:

Pressed: Enum.KeyCode.V
WalkSpeed Toggle: false
Current Speed: 16

also works.

So the script itself is fine.

The issue is probably this line in your config:

['WalkSpeed'] = {
    ['Enabled'] = true,
    ['Value'] = 50,
    ['Default'] = 16
}

You are starting with:

local Enabled = Config.Character.WalkSpeed.Enabled

which makes WalkSpeed always start enabled. If you want V to turn it on/off, change it to:

local Enabled = false

Keep the config only for values:

['WalkSpeed'] = {
    ['Enabled'] = true,
    ['Value'] = 50,
    ['Default'] = 16
}

Then your toggle starts off:

Spawn → 16 speed
Press V → 50 speed
Press V again → 16 speed

If you want it to force 50 whenever enabled, replace your updateSpeed() with:

local function updateSpeed()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.WalkSpeed = Enabled and Speed or Default

	print("Current Speed:", humanoid.WalkSpeed)
end

Your logs prove the WalkSpeed part is not broken. The next thing to check is whether another script is changing it after your script runs.
