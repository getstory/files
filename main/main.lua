local Config = shared.Story

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Enabled = false
local DefaultSpeed = 16

local function GetHumanoid()
    local Character = LocalPlayer.Character
    if not Character then return end

    return Character:FindFirstChildOfClass("Humanoid")
end

local function UpdateSpeed()
    local Humanoid = GetHumanoid()
    if not Humanoid then return end

    if Enabled and Config.Character.WalkSpeed.Enabled then
        Humanoid.WalkSpeed = Config.Character.WalkSpeed.Speed
    else
        Humanoid.WalkSpeed = DefaultSpeed
    end
end

RunService.RenderStepped:Connect(UpdateSpeed)

LocalPlayer.CharacterAdded:Connect(function(Character)
    Character:WaitForChild("Humanoid")
    UpdateSpeed()
end)

UIS.InputBegan:Connect(function(Input, Processed)
    if Processed then return end

    local Key = Enum.KeyCode[(Config.Binds.WalkSpeed or "T"):upper()]

    if Input.KeyCode == Key then
        Enabled = not Enabled
        UpdateSpeed()
    end
end)
