if not LPH_OBFUSCATED then
    LPH_NO_VIRTUALIZE = function(...) return ... end
    LPH_ENCSTR = function(...) return ... end
    LPH_ENCFUNC = function(...) return ... end
    LPH_CRASH = function() end
end

local HttpService = game:GetService("HttpService")

local SaveFile = "StoryBinds.json"

-- Load saved binds
if isfile(SaveFile) then
    local Saved = HttpService:JSONDecode(readfile(SaveFile))

    for Name, Key in pairs(Saved) do
        shared.Story.Binds[Name] = Key
    end
end

local OldBinds = shared.Story.Binds

shared.Story.Binds = setmetatable({}, {
    __index = OldBinds,

    __newindex = function(self, key, value)
        OldBinds[key] = value

        writefile(
            SaveFile,
            HttpService:JSONEncode(OldBinds)
        )
    end
})

local Players = game:GetService("Players")
local Workspace = game.Workspace
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Self = Players.LocalPlayer
local Mouse = Self:GetMouse()
local Camera = workspace.CurrentCamera
local GuiInsetOffsetY = game:GetService('GuiService'):GetGuiInset().Y
local Mango = {
    RBXConnections = {},
    Locals = {
        GunScriptDisabled = true, -->: Boolean
        IsDoubleTapping = nil, -->: Boolean
        SilentAimTarget = nil, -->: Player
        AimAssistTarget = nil, -->: Player
        IsWalkSpeeding = nil, -->: Boolean
        IsJumpSpeeding = nil, -->: Boolean
        DoubleTapState = nil, -->: Boolean
        CurrentWeapon = nil, -->: String
        IsBoxFocused = nil, -->: Boolean
        HitPosition = nil, -->: Vector3
        MoveVector = nil, -->: Vector3
        LastShot = 0, -->: Float
        IsAimed = nil, -->: Boolean
        HitPart = nil, -->: Instance
    },
    Visuals = {
        WalkSpeed = nil, -->: Instance
        DoubleTap = nil, -->: Instance
        BoxFOV = nil,
        AimbotFOV = nil,
        SilentFOV = nil,
        AimAssistFOV = nil
    }
}
local Modules = {
    Cache = {}
}
local Velocity_Data = {
    Tick = tick(),
    Sample = nil,
    State = Enum.HumanoidStateType.Running,
    Y = nil,
    Recorded = {
        Alpha = nil,
        B_0 = nil,
        V_T = nil,
        V_B = nil
    }
}
local Environment = {
    Priority = {},
    PriorityLines = {},
    PriorityTexts = {},
    PrioritySquares = {},
    PriorityLabels = {},
    PriorityTools = {},
    PrioritySquaresOutlines = {}
}
local State = {
	Connections = {},
	ToolConnections = {},
	Tracked = {},
	Previous = {},
	Current = nil,
	Tick = tick()
}
local Overlay = {}
local Binds = {}
local KeybindHandler = {}
local SP = true  -- Auto mode is always ON by default
local WeaponInfo = {
    Weapons = {
        Shotguns = {
            "[TacticalShotgun]",
            "[Shotgun]",
            "[Double-Barrel SG]",
        },
        AutoShotguns = {
            "[Drum-Shotgun]"
        },
        Pistols = {
            "[Revolver]",
            "[Silencer]",
            "[Glock]"
        },
        Rifles = {
            "[AR]",
            "[SilencerAR]",
            "[AK47]",
            "[LMG]",
            "[DrumGun]"
        },
        Bursts = {
            "[AUG]",
        },
        SMG = {
            "[SMG]",
            "[P90]"
        },
        Snipers = {
            "[Rifle]"
        }
    },
    Offsets = {
        ["[Double-Barrel SG]"] = CFrame.new(0, 0.35, -2.2),
        ["[TacticalShotgun]"] = CFrame.new(0, 0.25, -2.5),
        ["[Drum-Shotgun]"] = CFrame.new(-0.1, 0.5, -2.5),
        ["[Shotgun]"] = CFrame.new(0, 0.25, -2.5),
        ["[Revolver]"] = CFrame.new(-1, 0.4, 0),
        ["[Silencer]"] = CFrame.new(0, 0.4, 1.3),
        ["[Glock]"] = CFrame.new(0.6, 0.25, 0),
        ["[Rifle]"] = CFrame.new(0, 0.25, 2.5),
        ["[AUG]"] = CFrame.new(-0.1, 0.4, 1.8),
        ["[AR]"] = CFrame.new(2, 0.35, 0),
        ["[SMG]"] = CFrame.new(0, 1, 0.5),
        ["[LMG]"] = CFrame.new(0, 0.7, -3.8),
        ["[P90]"] = CFrame.new(0, 0.2, -1.7),
        ["[AK47]"] = CFrame.new(-0.1, 0.5, -2.5),
        ["[SilencerAR]"] = CFrame.new(2.5, 0.35, 0),
        ["[DrumGun]"] = CFrame.new(0, 0.4, 2.4),
    },
    Delays = {
        ["[Double-Barrel SG]"] = 0.0095 + 0.05,   -- Double-Barrel
        ["[TacticalShotgun]"] = 0.0095,           -- Tactical-Shotgun
        ["[Drum-Shotgun]"] = 0.415,               -- Drum-Shotgun
        ["[Shotgun]"] = 1.2,                      -- Shotgun
        ["[Revolver]"] = 0.0095,                  -- Revolver: 0.0095
        ["[Silencer]"] = 0.0095,                  -- Silencer
        ["[Glock]"] = 0.0095,                     -- Glock
        ["[Rifle]"] = 1.3095,                     -- Rifle
        ["[AUG]"] = 0.0095,                          -- AUG (N/A)
        ["[AR]"] = 0.15,                          -- AR
        ["[SMG]"] = 0.6,                          -- SMG
        ["[LMG]"] = 0.62,                         -- LMG
        ["[P90]"] = 0.6,                          -- P90
        ["[AK47]"] = 0.15,                        -- AK47
        ["[SilencerAR]"] = 0.02                  -- SilencerAR
    }
}
 
local Games = {
    [1008451066] = {
        Name = 'Da Hood',
        Updater = 'UpdateMousePosI2',
        HoodGame = true,
        Functions = {
            KnockedFunction = function(Player)
                if (Player) and Player.Character:FindFirstChild('BodyEffects') then
                    return Player.Character.BodyEffects['K.O'].Value
                end
                --
                return false
            end,
            GrabbedFunction = function(Player)
                if Player and Player.Character then
                    if Player.Character:FindFirstChild('GRABBING_CONSTRAINT') ~= nil then
                        return true
                    else
                        return false
                    end
                else
                    return false
                end
            end,			
            RemotePath = function()
                return game.ReplicatedStorage.MainEvent
            end
        }
    },
    [8916384194] = {
        Name = 'Dee Hood', 
        Updater = nil,
        HoodGame = true,
        Functions = {
            KnockedFunction = function(Player)
                if (Player) and Player.Character:FindFirstChild('BodyEffects') then
                    return Player.Character.BodyEffects['K.O'].Value
                end
                --
                return false
            end,
            GrabbedFunction = function(Player)
                if Player and Player.Character then
                    if Player.Character:FindFirstChild('GRABBING_CONSTRAINT') ~= nil then
                        return true
                    else
                        return false
                    end
                else
                    return false
                end
            end,			
            RemotePath = function()
                return game.ReplicatedStorage.MainEvent
            end
        }
    },
    [86479609106716] = {
        Name = 'Das Hood', -- das hood 
        Updater = "UpdateMousePos",
        HoodGame = true,
        Functions = {
            KnockedFunction = function(Player)
                if (Player) and Player.Character:FindFirstChild('BodyEffects') then
                    return Player.Character.BodyEffects['K.O'].Value
                end
                --
                return false
            end,
            GrabbedFunction = function(Player)
                if Player and Player.Character then
                    if Player.Character:FindFirstChild('GRABBING_CONSTRAINT') ~= nil then
                        return true
                    else
                        return false
                    end
                else
                    return false
                end 
            end,			
            RemotePath = function()
                return game.ReplicatedStorage.MainRemotes.MainRemoteEvent
            end
        }
    },
    [9131407049] = { 
        Name = 'Zee Hood', 
        Updater = "DEAHOODMOUSEPOSx3^3",
        HoodGame = true,
        Functions = {
            KnockedFunction = function(Player)
                if (Player) and Player.Character:FindFirstChild('BodyEffects') then
                    return Player.Character.BodyEffects['K.O'].Value
                end
                --
                return false
            end,
            GrabbedFunction = function(Player)
                if Player and Player.Character then
                    if Player.Character:FindFirstChild('GRABBING_CONSTRAINT') ~= nil then
                        return true
                    else
                        return false
                    end
                else
                    return false
                end
            end,			
            RemotePath = function()
               return game.ReplicatedStorage.MainRemotes.MainRemoteEvent
            end
        }
    },
    [8261267092] = {
        Name = 'Zea Hood', 
        Updater = "DEAHOODMOUSEPOSx3^3",
        HoodGame = true,
        Functions = {
            KnockedFunction = function(Player)
                if (Player) and Player.Character:FindFirstChild('BodyEffects') then
                    return Player.Character.BodyEffects['K.O'].Value
                end
                --
                return false
            end,
            GrabbedFunction = function(Player)
                if Player and Player.Character then
                    if Player.Character:FindFirstChild('GRABBING_CONSTRAINT') ~= nil then
                        return true
                    else
                        return false
                    end
                else
                    return false
                end
            end,			
            RemotePath = function()
                return game.ReplicatedStorage.MainRemotes.MainRemoteEvent
            end
        }
    },
}
 
--[[
if not Games[game.GameId] then
    while true do end
end]]
local CurrentGame 
if Games[game.GameId] then
    CurrentGame = Games[game.GameId]
else
    -- Fallback for Hood-like games if not detected
    CurrentGame = {
        Name = 'Unknown Hood',
        Updater = 'UpdateMousePosI2',
        HoodGame = true,
        Functions = {
            RemotePath = function()
                return game.ReplicatedStorage.MainEvent
            end
        }
    }
end
 
(function()
    do --// Modules
        do --// Overlay
            local CustomLibIndex = 0
            local Clamp = math.clamp
            local UtilityUI = Instance.new('ScreenGui'); UtilityUI.Parent = game:GetService("CoreGui"); UtilityUI.IgnoreGuiInset = true
            local UserInputService = game:GetService("UserInputService")
            local MRandom = math.random
            local Floor = math.floor
            local Round = math.round
            local Clamp = math.clamp
            local Acos = math.acos
            local Atan2 = math.atan2
            local Huge = math.huge
            local Sqrt = math.sqrt
            local Ceil = math.ceil
            local Cos = math.cos
            local Abs = math.abs
            local Sin = math.sin
            local Rad = math.rad
            local Max = math.max
            local Min = math.min
            local Deg = math.deg
            local Pi = math.pi
            local LibraryMeta = setmetatable({
                Visible = true,
                ZIndex = 0,
                Transparency = 1,
                Color = Color3.new(),
                Remove = function(self)
                    setmetatable(self, nil)
                end,
                Destroy = function(self)
                    setmetatable(self, nil)
                end
            }, {
                __add = function(t1, t2)
                    local result = table.clone(t1)
 
                    for index, value in t2 do
                        result[index] = value
                    end
                    return result
                end
            })
            --
            local function ClampTransparency(number)
                return Clamp(1 - number, 0, 1)
            end
            --
            function Overlay.new(ClassType)
                CustomLibIndex += 1
                if ClassType == 'Line' then
                    local LineObject = ({
                        From = Vector2.zero,
                        To = Vector2.zero,
                        Thickness = 1
                    } + LibraryMeta)
                    --
                    local Line = Instance.new('Frame')
                    --
                    Line.Name = CustomLibIndex
                    Line.AnchorPoint = (Vector2.one * .5)
                    Line.BorderSizePixel = 0
                    Line.BackgroundColor3 = LineObject.Color
                    Line.Visible = LineObject.Visible
                    Line.ZIndex = LineObject.ZIndex
                    Line.BackgroundTransparency = ClampTransparency(LineObject.Transparency)
                    Line.Size = UDim2.new()
                    Line.Parent = UtilityUI
                    --
                    return setmetatable(table.create(0), {
                        __newindex = function(_, Property, Value)
                            if Property == 'From' then
                                local Direction = (LineObject.To - Value)
                                local Center = (LineObject.To + Value) / 2
                                local Magnitude = Direction.Magnitude
                                local Theta = Deg(Atan2(Direction.Y, Direction.X))
                                --
                                Line.Position = UDim2.fromOffset(Center.X, Center.Y)
                                Line.Rotation = Theta
                                Line.Size = UDim2.fromOffset(Magnitude, LineObject.Thickness)
                            elseif Property == 'To' then
                                local Direction = (Value - LineObject.From)
                                local Center = (Value + LineObject.From) / 2
                                local Magnitude = Direction.Magnitude
                                local Theta = Deg(Atan2(Direction.Y, Direction.X))
                                --
                                Line.Position = UDim2.fromOffset(Center.X, Center.Y)
                                Line.Rotation = Theta
                                Line.Size = UDim2.fromOffset(Magnitude, LineObject.Thickness)
                            elseif Property == 'Thickness' then
                                local Thickness = (LineObject.To - LineObject.From).Magnitude
                                Line.Size = UDim2.fromOffset(Thickness, Value)
                            elseif Property == 'Visible' then
                                Line.Visible = Value
                            elseif Property == 'ZIndex' then
                                Line.ZIndex = Value
                            elseif Property == 'Transparency' then
                                Line.BackgroundTransparency = ClampTransparency(Value)
                            elseif Property == 'Color' then
                                Line.BackgroundColor3 = Value
                            end
                            LineObject[Property] = Value
                        end,
                        __index = function(self, index)
                            if index == 'Remove' or index == 'Destroy' then
                                return function()
                                    Line:Destroy()
                                    LineObject.Remove(self)
                                    return LineObject:Remove()
                                end
                            end
                            return LineObject[index]
                        end,
                        __tostring = function() return 'CustomLib' end
                    })
                elseif ClassType == 'Square' then
                    local squareObj = ({
                        Size = Vector2.zero,
                        Position = Vector2.zero,
                        Thickness = .7,
                        Filled = false,
                        Drag = false,
                    } + LibraryMeta)
 
                    local squareFrame, uiStroke = Instance.new('Frame'), Instance.new('UIStroke')
                    squareFrame.Name = CustomLibIndex
                    squareFrame.BorderSizePixel = 0
                    local transparency
                    if squareObj.Filled then
                        transparency = ClampTransparency(squareObj.Transparency)
                    else
                        transparency = 1
                    end
                    squareFrame.BackgroundTransparency = transparency
                    squareFrame.ZIndex = squareObj.ZIndex
                    squareFrame.BackgroundColor3 = squareObj.Color
                    squareFrame.Visible = squareObj.Visible
                    uiStroke.Thickness = squareObj.Thickness
                    uiStroke.Enabled = not squareObj.Filled
                    uiStroke.LineJoinMode = Enum.LineJoinMode.Miter
                    squareFrame.Parent, uiStroke.Parent = UtilityUI, squareFrame
 
                    local dragging = false
                    local dragStart = nil
                    local startPos = nil
 
                    squareFrame.MouseEnter:Connect(function()
                        if squareObj.Drag then
                            local inputConnection
                            inputConnection = UserInputService.InputBegan:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                    dragging = true
                                    dragStart = input.Position
                                    startPos = squareFrame.Position
                                end
                            end)
 
                            local leaveConnection
                            leaveConnection = squareFrame.MouseLeave:Connect(function()
                                inputConnection:Disconnect()
                                leaveConnection:Disconnect()
                            end)
                        end
                    end)
 
                    UserInputService.InputChanged:Connect(function(input)
                        if squareObj.Drag then
                            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                                local delta = input.Position - dragStart
                                local newX = startPos.X.Offset + delta.X
                                local newY = startPos.Y.Offset + delta.Y
                                squareFrame.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
                            end
                        end
                    end)
 
                    UserInputService.InputEnded:Connect(function(input)
                        if squareObj.Drag then
                            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                dragging = false
                            end
                        end
                    end)
 
                    return setmetatable(table.create(0), {
                        __newindex = function(_, index, value)
                            if typeof(squareObj[index]) == 'nil' then return end
 
                            if index == 'Size' then
                                squareFrame.Size = UDim2.fromOffset(value.X, value.Y)
                            elseif index == 'Position' then
                                squareFrame.Position = UDim2.fromOffset(value.X, value.Y)
                            elseif index == 'Thickness' then
                                value = Clamp(value, 0.6, 0x7fffffff)
                                uiStroke.Thickness = value
                            elseif index == 'Filled' then
                                squareFrame.BackgroundTransparency = 1
                                uiStroke.Enabled = not value
                            elseif index == 'Visible' then
                                squareFrame.Visible = value
                            elseif index == 'ZIndex' then
                                squareFrame.ZIndex = value
                            elseif index == 'Transparency' then
                                local transparency = ClampTransparency(value)
 
                                squareFrame.BackgroundTransparency = 1
                                uiStroke.Transparency = transparency
                            elseif index == 'Color' then
                                uiStroke.Color = value
                                squareFrame.BackgroundColor3 = value
                            end
                            squareObj[index] = value
                        end,
                        __index = function(self, index)
                            if index == 'Remove' or index == 'Destroy' then
                                return function()
                                    squareFrame:Destroy()
                                    squareObj.Remove(self)
                                    return squareObj:Remove()
                                end
                            end
                            return squareObj[index]
                        end,
                        __tostring = function() return 'CustomLib' end
                    })
                elseif ClassType == 'Text' then
                    local textObj = ({
                        Text = '',
                        Font = Enum.Font.SourceSansBold,
                        Size = 0,
                        Position = Vector2.zero,
                        Center = false,
                        Outline = false,
                        OutlineColor = Color3.new()
                    } + LibraryMeta)
 
                    local textLabel, uiStroke = Instance.new('TextLabel'), Instance.new('UIStroke')
                    textLabel.Name = CustomLibIndex
                    textLabel.AnchorPoint = (Vector2.one * .5)
                    textLabel.BorderSizePixel = 0
                    textLabel.BackgroundTransparency = 1
                    textLabel.RichText = true
                    textLabel.Visible = textObj.Visible
                    textLabel.TextColor3 = textObj.Color
                    textLabel.TextTransparency = ClampTransparency(textObj.Transparency)
                    textLabel.ZIndex = textObj.ZIndex
 
                    textLabel.Font = Enum.Font.SourceSansBold
                    textLabel.TextSize = textObj.Size
 
                    textLabel:GetPropertyChangedSignal('TextBounds'):Connect(function()
                        local textBounds = textLabel.TextBounds
                        local offset = textBounds / 2
 
                        local offsetX
                        if not textObj.Center then
                            offsetX = offset.X
                        else
                            offsetX = 0
                        end
 
                        textLabel.Position = UDim2.fromOffset(textObj.Position.X + offsetX, textObj.Position.Y + offset.Y)
                    end)
 
                    uiStroke.Thickness = 1
                    uiStroke.Enabled = textObj.Outline
                    uiStroke.Color = textObj.Color
 
                    textLabel.Parent, uiStroke.Parent = UtilityUI, textLabel
                    return setmetatable(table.create(0), {
                        __newindex = function(_, index, value)
                            if typeof(textObj[index]) == 'nil' then return end
 
                            if index == 'Text' then
                                textLabel.Text = value
                            elseif index == 'Font' then
                                value = Clamp(value, 0, 3)
                            elseif index == 'Size' then
                                textLabel.TextSize = value
                            elseif index == 'Position' then
                                local offset = textLabel.TextBounds / 2
 
                                local offsetX
                                if not textObj.Center then
                                    offsetX = offset.X
                                else
                                    offsetX = 0
                                end
 
                                textLabel.Position = UDim2.fromOffset(textObj.Position.X + offsetX, textObj.Position.Y + offset.Y)
                            elseif index == 'Center' then
                                local position
                                if value then
                                    position = workspace.CurrentCamera.ViewportSize / 2
                                else
                                    position = textObj.Position
                                end
                                textLabel.Position = UDim2.fromOffset(position.X, position.Y)
                            elseif index == 'Outline' then
                                uiStroke.Enabled = value
                            elseif index == 'OutlineColor' then
                                uiStroke.Color = value
                            elseif index == 'Visible' then
                                textLabel.Visible = value
                            elseif index == 'ZIndex' then
                                textLabel.ZIndex = value
                            elseif index == 'Transparency' then
                                local transparency = ClampTransparency(value)
 
                                textLabel.TextTransparency = transparency
                                uiStroke.Transparency = transparency
                            elseif index == 'Color' then
                                textLabel.TextColor3 = value
                            end
                            textObj[index] = value
                        end,
                        __index = function(self, index)
                            if index == 'Remove' or index == 'Destroy' then
                                return function()
                                    textLabel:Destroy()
                                    textObj.Remove(self)
                                    return textObj:Remove()
                                end
                            elseif index == 'TextBounds' then
                                return textLabel.TextBounds
                            end
                            return textObj[index]
                        end,
                        __tostring = function() return 'CustomLib' end
                    })
                elseif ClassType == 'Image' then
                    local imageObj = ({
                        Data = '',
                        DataURL = 'rbxassetid:/',
                        Size = Vector2.zero,
                        Position = Vector2.zero
                    } + LibraryMeta)
 
                    local imageFrame = Instance.new('ImageLabel')
                    imageFrame.Name = CustomLibIndex
                    imageFrame.BorderSizePixel = 0
                    imageFrame.ScaleType = Enum.ScaleType.Stretch
                    imageFrame.BackgroundTransparency = 1
 
                    imageFrame.Visible = imageObj.Visible
                    imageFrame.ZIndex = imageObj.ZIndex
                    imageFrame.ImageTransparency = ClampTransparency(imageObj.Transparency)
                    imageFrame.ImageColor3 = imageObj.Color
 
                    imageFrame.Parent = UtilityUI
                    return setmetatable(table.create(0), {
                        __newindex = function(_, index, value)
                            if typeof(imageObj[index]) == 'nil' then return end
 
                            if index == 'Data' then
                                -- later
                            elseif index == 'DataURL' then -- temporary property
                                imageFrame.Image = value
                            elseif index == 'Size' then
                                imageFrame.Size = UDim2.fromOffset(value.X, value.Y)
                            elseif index == 'Position' then
                                imageFrame.Position = UDim2.fromOffset(value.X, value.Y)
                            elseif index == 'Visible' then
                                imageFrame.Visible = value
                            elseif index == 'ZIndex' then
                                imageFrame.ZIndex = value
                            elseif index == 'Transparency' then
                                imageFrame.ImageTransparency = ClampTransparency(value)
                            elseif index == 'Color' then
                                imageFrame.ImageColor3 = value
                            end
                            imageObj[index] = value
                        end,
                        __index = function(self, index)
                            if index == 'Remove' or index == 'Destroy' then
                                return function()
                                    imageFrame:Destroy()
                                    imageObj.Remove(self)
                                    return imageObj:Remove()
                                end
                            elseif index == 'Data' then
                                return nil
                            end
                            return imageObj[index]
                        end,
                        __tostring = function() return 'CustomLib' end
                    })
                elseif ClassType == 'Circle' then
                    local circleObj = ({
                        Size = Vector2.zero,
                        Position = Vector2.zero,
                        Thickness = 1,
                        Filled = false,
                    } + LibraryMeta)
 
                    local circleFrame = Instance.new('Frame')
                    local uiStroke = Instance.new('UIStroke')
                    local uiCorner = Instance.new('UICorner')
                    
                    circleFrame.Name = CustomLibIndex
                    circleFrame.BorderSizePixel = 0
                    circleFrame.BackgroundTransparency = 1
                    circleFrame.ZIndex = circleObj.ZIndex
                    circleFrame.Visible = circleObj.Visible
                    
                    uiStroke.Thickness = circleObj.Thickness
                    uiStroke.Enabled = not circleObj.Filled
                    uiStroke.Color = circleObj.Color
                    uiStroke.Transparency = ClampTransparency(circleObj.Transparency)
                    
                    uiCorner.CornerRadius = UDim.new(1, 0) -- Full circle
                    
                    circleFrame.Parent = UtilityUI
                    uiStroke.Parent = circleFrame
                    uiCorner.Parent = circleFrame
 
                    return setmetatable(table.create(0), {
                        __newindex = function(_, index, value)
                            if typeof(circleObj[index]) == 'nil' then return end
 
                            if index == 'Size' then
                                circleFrame.Size = UDim2.fromOffset(value.X, value.Y)
                            elseif index == 'Position' then
                                circleFrame.Position = UDim2.fromOffset(value.X, value.Y)
                            elseif index == 'Thickness' then
                                uiStroke.Thickness = value
                            elseif index == 'Filled' then
                                circleFrame.BackgroundTransparency = value and ClampTransparency(circleObj.Transparency) or 1
                                uiStroke.Enabled = not value
                            elseif index == 'Visible' then
                                circleFrame.Visible = value
                            elseif index == 'ZIndex' then
                                circleFrame.ZIndex = value
                            elseif index == 'Transparency' then
                                local transparency = ClampTransparency(value)
                                if circleObj.Filled then
                                    circleFrame.BackgroundTransparency = transparency
                                end
                                uiStroke.Transparency = transparency
                            elseif index == 'Color' then
                                uiStroke.Color = value
                                circleFrame.BackgroundColor3 = value
                            end
                            circleObj[index] = value
                        end,
                        __index = function(self, index)
                            if index == 'Remove' or index == 'Destroy' then
                                return function()
                                    circleFrame:Destroy()
                                    circleObj.Remove(self)
                                    return circleObj:Remove()
                                end
                            end
                            return circleObj[index]
                        end,
                        __tostring = function() return 'CustomLib' end
                    })
                end
            end
            if not Mango.Visuals.BoxFOV then
                Mango.Visuals.BoxFOV = Overlay.new('Circle')
            end
 
            if not Mango.Visuals.TriggerBotFOV then
                Mango.Visuals.TriggerBotFOV = Overlay.new('Circle')
            end
         --[[
         
            local Text = Overlay.new("Text")
 
            Text.Visible = true
            Text.Position = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 2)
            Text.Size = 13
            Text.Text = "He;lo"
            Text.Outline = true
            Text.Color = Color3.fromRGB(255, 255, 255)]]
        end
        do --// Keybind Handler
            function KeybindHandler.GetBind(Id)
                if (not Id) then
                    return Binds
                end
        
        
                local FoundI = -1
                for i, Bind in ipairs(Binds) do
                    -- // Check if id matches
                    if (Bind.Id == Id) then
                        -- // Set
                        FoundI = i
                        break
                    end
                end
        
        
                if (FoundI == -1) then
                    return false
                end
        
        
                return Binds[FoundI], FoundI
            end
            --
            local ValidInputItems = {"KeyCode", "UserInputType"}
            function KeybindHandler.CreateBind(Data)
                -- // Make sure we gave a keybind
                local Keybind = typeof(Data.Keybind) == "function" and Data.Keybind() or Data.Keybind
                assert(typeof(Keybind) == "EnumItem" and table.find(ValidInputItems, tostring(Keybind.EnumType)), "Invalid keybind")
        
                -- // Add to binds
                local Id = game:GetService("HttpService"):GenerateGUID()
                table.insert(Binds, {
                    Id = Id,
                    Keybind = Data.Keybind,
                    Callback = Data.Callback or function(State, Bind) end,
                    ProcessedCheck = Data.ProcessedCheck or false,
                    Hold = Data.Hold or false,
                    State = Data.State or false
                })
        
                -- // Return the Id
                return Id
            end
            --
            function KeybindHandler.Update(Id, Property, NewValue)
                -- // Get the bind
                local Bind = KeybindHandler.Get(Id)
                if (not Bind) then
                    return false
                end
        
                -- // Set
                Bind[Property] = NewValue
                return true
            end
            --
            function KeybindHandler.UpdateKeybind(Id, NewKeybind)
                return KeybindHandler.Update(Id, "Keybind", NewKeybind)
            end
            --
            function KeybindHandler.UpdateCallback(Id, NewCallback)
                return KeybindHandler.Update(Id, "Callback", NewCallback)
            end
            --
            function KeybindHandler.RemoveBind(Id)
                -- // Get the bind
                local _, FoundI = KeybindHandler.Get(Id)
                if (not FoundI) then
                    return false
                end
        
                -- // Remove
                table.remove(Binds, FoundI)
                return true
            end
            --
            function KeybindHandler.CreateConnection()
                -- // Connects to whenever we make an input
                KeybindHandler.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input, gameProcessedEvent)
                    -- // Loop through all binds
                    for _, Bind in ipairs(Binds) do
                        -- // Check
                        local Keybind = Bind.Keybind
                        Keybind = typeof(Keybind) == "function" and Keybind() or Keybind
                        local Property = tostring(Keybind.EnumType)
                        if (Input[Property] ~= Keybind) or (Bind.ProcessedCheck and gameProcessedEvent) then
                            continue
                        end
        
                        -- // Fire
                        if (Bind.Hold) then
                            Bind.State = true
                        else
                            Bind.State = not Bind.State
                        end
        
                        Bind.Callback(Bind.State, Bind)
                    end
                end)
        
                -- // See whenever we lift up
                KeybindHandler.InputEndedConnection = UserInputService.InputEnded:Connect(function(Input, gameProcessedEvent)
                    -- // Loop through all binds
                    for _, Bind in ipairs(Binds) do
                        -- // Make sure is a hold
                        if (not Bind.Hold) then
                            continue
                        end
        
                        -- // Check
                        local Keybind = Bind.Keybind
                        Keybind = typeof(Keybind) == "function" and Keybind() or Keybind
                        local Property = tostring(Keybind.EnumType)
                        if (Input[Property] ~= Keybind) or (Bind.ProcessedCheck and gameProcessedEvent) then
                            continue
                        end
        
                        -- // Fire
                        Bind.State = false
                        Bind.Callback(Bind.State, Bind)
                    end
                end)
            end
            --
            function KeybindHandler.Destroy(KeepConnection)
                -- // Destroy connection
                if (not KeepConnection) then
                    if (KeybindHandler.InputBeganConnection) then
                        KeybindHandler.InputBeganConnection:Disconnect()
                        KeybindHandler.InputBeganConnection = nil
                    end
        
                    if (KeybindHandler.InputEndedConnection) then
                        KeybindHandler.InputEndedConnection:Disconnect()
                        KeybindHandler.InputEndedConnection = nil
                    end
                end
        
                -- // Empty binds
                Binds = {}
            end
            --
            --KeybindHandler.TestMode = true
            KeybindHandler.CreateConnection()
            if (KeybindHandler.TestMode) then
                KeybindHandler.CreateBind({
                    Keybind = Enum.KeyCode.X,
                    ProcessedCheck = true,
                    Callback = function(State, Bind)
                        print(Bind.Keybind.Name .. " was pressed with state " .. tostring(State))
                    end
                })
                KeybindHandler.CreateBind({
                    Keybind = Enum.UserInputType.MouseButton2,
                    ProcessedCheck = true,
                    Callback = function(State, Bind)
                        print(Bind.Keybind.Name .. " was pressed with state " .. tostring(State))
                    end
                })
        
        
                KeybindHandler.CreateBind({
                    Keybind = Enum.UserInputType.MouseButton2,
                    ProcessedCheck = true,
                    Callback = function(State, Bind)
                        local Action = State and "pressed" or "released"
                        print(Bind.Keybind.Name .. " was " .. Action)
                
                        if State then
                            task.spawn(function() 
                                while State do
                                    print("Holding " .. Bind.Keybind.Name)
                                    task.wait(0.1) 
                                end
                            end)
                        end
                    end,
                    Hold = true
                })
                
            end
        end
        --
        function Modules.Get(Id)
            if not Modules.Cache[Id] then
                Modules.Cache[Id] = {
                    c = Modules[Id](),
                }
            end
        
            return Modules.Cache[Id].c
        end
        --
        function Modules.Utility()
            local function ThreadLoop(Wait, Function)
                task.spawn(function()
                    while true do
                        local Delta = task.wait(Wait)
                        local Success, Error = pcall(Function, Delta)
                        if not Success then
                            warn("thread error " .. Error)
                        elseif Error == "break" then
                            --print("thread stopped")
                            break
                        end
                    end
                end)
            end
 
            local function GetTriggerBotFOVSize()
    local cfg = shared.Story.TriggerBot.FOV.FOV['Weapon Configuration']
    local tool = Self.Character and Self.Character:FindFirstChildOfClass("Tool")
    local name = tool and tool.Name or ""
 
    if table.find(WeaponInfo.Weapons.Shotguns, name) then
        return cfg.Shotguns
    elseif table.find(WeaponInfo.Weapons.Pistols, name) then
        return cfg.Pistols
    else
        return cfg.Others
    end
end
    
            local function ThreadFunction(Func, Name, ...)
                local Func = Name and function()
                    local Passed, Statement = pcall(Func)
                    --
                    if not Passed then
                        warn('ThreadFunction Error:\n', '              ' .. Name .. ':', Statement)
                    end
                end or Func
                local Thread = coroutine.create(Func)
                --
                coroutine.resume(Thread, ...)
                return Thread
            end
    
            local function Connection(connectionType, connectionCallback)
                local connection = connectionType:Connect(connectionCallback)
                Mango.RBXConnections[#Mango.RBXConnections + 1] = connection
                return connection
            end
    
            return {
                ThreadFunction = ThreadFunction,
                ThreadLoop = ThreadLoop,
                Connection = Connection
            }
        end
        --
        function Modules.Engine()
            local function RayCast(Part, Origin, Ignore, Distance)
                local Ignore = Ignore or {}
                local Distance = Distance or 2000
                local Cast = Ray.new(Origin, (Part.Position - Origin).Unit * Distance)
                local Hit = Workspace:FindPartOnRayWithIgnoreList(Cast, Ignore)
                return (Hit and Hit:IsDescendantOf(Part.Parent)) == true, Hit
            end
    
            return {
                RayCast = RayCast
            }
        end
        --
        local Gui 
        function Modules.ScreenGui()
            
            local function Setup()
                if not Gui then
                    Gui = Instance.new("ScreenGui")
                    Gui.ResetOnSpawn = false    
                    Gui.Parent = game:GetService("CoreGui")
                end
            end
        
            local function GetParentInstance()
                return Gui
            end
        
            local function DrawText(Parent)
                Setup() 
                Parent = Parent or GetParentInstance()
                
                local Text = Instance.new("TextLabel", Parent)
                Text.Text = "Label"
                Text.BackgroundTransparency = 1
                Text.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Text.Font = Enum.Font.SourceSansBold 
                Text.TextSize = 42
                Text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                Text.TextStrokeTransparency = 0.85
                Text.Visible = false
                Text.TextXAlignment = Enum.TextXAlignment.Left
    
                task.wait()
                
                local Width = Text.TextBounds.X
                Text.Size = UDim2.new(0, Width + 10, 0, Text.TextSize) 
        
                return Text
            end
        
            local function UpdateDrawings()
                Setup() 
        
                if not Mango.Visuals then
                    Mango.Visuals = {}
                end
        
                if not Mango.Visuals.Triggerbot then
                    Mango.Visuals.Triggerbot = DrawText(Gui)
                end
    
                if not Mango.Visuals.WalkSpeed then
                    Mango.Visuals.WalkSpeed = DrawText(Gui)
                end
    
                if not Mango.Visuals.DoubleTap then
                    Mango.Visuals.DoubleTap = DrawText(Gui)
                end
         
            end
        
            return {
                Setup = Setup,
                DrawText = DrawText,
                UpdateDrawings = UpdateDrawings
            }
        end
        --
        function Modules.Player()
            local Engine = Modules.Get("Engine")
    
            local function ValidateClient(Player)
                local Object = Player.Character
                local Humanoid = (Object and Object:FindFirstChild("Humanoid")) or false
                local RootPart = (Humanoid and Humanoid.RootPart) or false
                return Object, Humanoid, RootPart
            end
 
            --[[
                   local function IsDesynced(Player, X, Y, Z, UseMagnitude, Magnitude, Force)
				X = X or 70
				Y = Y or 100
				Z = Z or 53 -- z axis should never go over 30?
				UseMagnitude = UseMagnitude or true
				Magnitude = Magnitude or 80
				Force = Force or false
				--
				local Object, Humanoid, RootPart = ValidateClient(Player)
				--
				if (Object and Humanoid and RootPart) then
					local Velocity = RootPart.Velocity
					local Cap = Vector3.new(X, Y, Z)
					--
					if Velocity.X >= Cap.X or Velocity.Y >= Cap.Y or Velocity.Z >= Cap.Z then
						return true
					end
					--
					if Velocity.Magnitude >= 75 then
						return true
					end
					--
					if UseMagnitude and Velocity.Magnitude > Magnitude then
						return true
					end
					--
					if Force then
						return true
					end
				end
			end]]
    
 
 
 
 
 
    
            local function GetOrigin(Origin)
                if Origin == 'Head' then
                    local Object, Humanoid, RootPart = ValidateClient(Self)
                    local Head = Object:FindFirstChild('Head')
            
                    if Head and Head:IsA('RootPart') then
                        return Head.CFrame.Position
                    end
                elseif Origin == 'Torso' then
                    local Object, Humanoid, RootPart = ValidateClient(Self)
                
                    if RootPart then
                        return RootPart.CFrame.Position
                    end
                end
                return Workspace.CurrentCamera.CFrame.Position
            end
    
            local function IsKnocked(Character)
                if (Character) and Character:FindFirstChild('BodyEffects') then
                    return Character:FindFirstChild("BodyEffects")['K.O'].Value
                end
                return false
            end
    
            local function IsGrabbed(Character)
                if Character then
                    if Character:FindFirstChild('GRABBING_CONSTRAINT') then
                        return true
                    else
                        return false
                    end
                else
                    return false
                end 
            end
    
            local function GetClosestPlayerToCursor()
                local CurrentCamera = workspace.CurrentCamera
                local MousePosition = UserInputService:GetMouseLocation()
                local Closest
                local Distance = 1/0
            
    
                for _, Player in ipairs(Players:GetPlayers()) do
                    if (Player == Self) then
                        continue
                    end
            
                    local Character = Player.Character
                    if (not Character) then
                        continue
                    end
 
                    if Player.Character then
                        
                        local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
                        if (not HumanoidRootPart) then
                            continue
                        end
        
                        -- Get current mode and checks
                        local selectionMode = shared.Story.Selection['Selection Mode'] or 'Auto'
                        local checks = shared.Story.Selection.Checks[selectionMode] or shared.Story.Selection.Checks.Auto
                        
                        if checks.Test then
                            if not Engine.RayCast(Player.Character.HumanoidRootPart, GetOrigin('Camera'), {Self.Character}) then
                                continue
                            end
                        end
                
                        if checks.Forcefield then
                            if Character:FindFirstChild("ForceField") then
                                continue
                            end
                        end
        
                        if checks.Knocked then
                            if IsKnocked(Character) then
                                continue
                            end
                        end
        
                        if checks.Grabbed then
                            if IsGrabbed(Character) then
                                continue
                            end
                        end
        
                        -- Distance Check
                        local distanceConfig = shared.Story['Distance Check']
                        if distanceConfig and distanceConfig.Enabled then
                            local maxDistance = distanceConfig['Max Distance'] or 300
                            local playerDistance = (Self.Character.HumanoidRootPart.Position - HumanoidRootPart.Position).Magnitude
                            if playerDistance > maxDistance then
                                continue
                            end
                        end
                        
                        local Position, OnScreen = CurrentCamera:WorldToViewportPoint(HumanoidRootPart.Position)
        
                        if checks.Visible then
                            if not OnScreen then
                                continue
                            end
                        end
                        
                        local Magnitude = (Vector2.new(Position.X, Position.Y) - MousePosition).Magnitude
                        if (Magnitude < Distance) then
                            Closest = Player
                            Distance = Magnitude
                        end
                    end
                end
                return Closest
            end
    
            local function GetClosestPartToCursor(Character)
                local CurrentCamera = Workspace.CurrentCamera
                local MousePosition = UserInputService:GetMouseLocation()
                
                -- Get allowed hitparts from config
                local AllowedParts = shared.Story.SilentAim.Hitpart or { 'Head', 'HumanoidRootPart' }
                
                local ClosestPart = nil
                local ClosestDistance = 1/0
                
                -- Find the closest part from Hitpart list to the cursor
                for _, partName in ipairs(AllowedParts) do
                    local Part = Character:FindFirstChild(partName)
                    if Part and Part:IsA("BasePart") then
                        -- Check if part is on screen and in front of camera
                        local Position = CurrentCamera:WorldToViewportPoint(Part.Position)
                        if Position.Z > 0 then
                            local Distance = (Vector2.new(Position.X, Position.Y) - MousePosition).Magnitude
                            if Distance < ClosestDistance then
                                ClosestPart = Part
                                ClosestDistance = Distance
                            end
                        end
                    end
                end
                
                return ClosestPart
            end
    
            local function GetClosestPartToCursorFilter(Character, PointSetting)
                local CurrentCamera = workspace.CurrentCamera
                local Closest
                local Distance = math.huge
 
                local AllowedParts = nil
                if typeof(PointSetting) == "string" then
                    if PointSetting ~= "Nearest Point" then
                        AllowedParts = { PointSetting }
                    end
                elseif typeof(PointSetting) == "table" then
                    AllowedParts = PointSetting
                end
 
                for _, Part in ipairs(Character:GetChildren()) do
                    if not Part:IsA("BasePart") then continue end
                    if AllowedParts and not table.find(AllowedParts, Part.Name) then continue end
 
                    local screenPos = CurrentCamera:WorldToViewportPoint(Part.Position)
                    local mousePos = UserInputService:GetMouseLocation()
                    local mag = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
 
                    if mag < Distance then
                        Closest = Part
                        Distance = mag
                    end
                end
 
                return Closest
            end
            
            local function GetClosestPointOnPart(Part, Scale)
                local PartCFrame = Part.CFrame
                local PartSize = Part.Size
                local PartSizeTransformed = PartSize * (Scale / 2)
        
                local MousePosition = UserInputService:GetMouseLocation()
                local CurrentCamera = Workspace.CurrentCamera
        
                local MouseRay = CurrentCamera:ViewportPointToRay(MousePosition.X, MousePosition.Y)
                local Transformed = PartCFrame:PointToObjectSpace(MouseRay.Origin + (MouseRay.Direction * MouseRay.Direction:Dot(PartCFrame.Position - MouseRay.Origin)))
        
    
                
                if (Mouse.Target == Part) then
                    return Vector3.new(Mouse.Hit.X, Mouse.Hit.Y, Mouse.Hit.Z)
                end
    
                return PartCFrame * Vector3.new(
                    math.clamp(Transformed.X, -PartSizeTransformed.X, PartSizeTransformed.X),
                    math.clamp(Transformed.Y, -PartSizeTransformed.Y, PartSizeTransformed.Y),
                    math.clamp(Transformed.Z, -PartSizeTransformed.Z, PartSizeTransformed.Z)
                )
            end
    
            local function GetClosestPointOnPartBasic(Part)
                if Part then
                    local MouseRay = Mouse.UnitRay
                    MouseRay = MouseRay.Origin + (MouseRay.Direction * (Part.Position - MouseRay.Origin).Magnitude)
                    local Point = (MouseRay.Y >= (Part.Position - Part.Size / 2).Y and MouseRay.Y <= (Part.Position + Part.Size / 2).Y) and (Part.Position + Vector3.new(0, -Part.Position.Y + MouseRay.Y, 0)) or Part.Position
                    local Check = RaycastParams.new()
                    Check.FilterType = Enum.RaycastFilterType.Whitelist
                    Check.FilterDescendantsInstances = {Part}
                    local Ray = Workspace:Raycast(MouseRay, (Point - MouseRay), Check)
    
                    if Mouse.Target == Part then
                        return Mouse.Hit.Position
                    end
    
                    if Ray then
                        return Ray.Position
                    else
                        return Mouse.Hit.Position
                    end
                end 
            end
    
            
    
 
              
 
            local function Resolve(RootPart)
                if not RootPart then return Vector3.new(0, 0, 0) end
                local Suppression = 1
                local Aggression = 1
                local Position = RootPart.Position
                local Tick = tick()
                --
                State.Tracked = State.Tracked or {}
                State.Previous = State.Previous or {}
                --
                table.insert(State.Tracked, Position)
                table.insert(State.Previous, Tick)
                --
                if #State.Tracked >= 3 then
                    local Indexes = #State.Tracked
                    --
                    local TimeData = State.Previous
                    local PositionEntries = State.Tracked
                    --
                    local IndexOne = PositionEntries[Indexes - 2]
                    local IndexTwo = PositionEntries[Indexes - 1]
                    local LastIndex = PositionEntries[Indexes]
                    local TimeOne = TimeData[Indexes - 2]
                    local TimeTwo = TimeData[Indexes - 1]
                    local LastTime = TimeData[Indexes]
                    --
                    if (TimeTwo - TimeOne) ~= 0 and (LastTime - TimeTwo) ~= 0 then
                        local StartVelocity = (IndexTwo - IndexOne) / (TimeTwo - TimeOne)
                        local EndVelocity = (LastIndex - IndexTwo) / (LastTime - TimeTwo)
                        --
                        local ResolvedVelocity = (Aggression - Suppression) * StartVelocity + Suppression * EndVelocity
                        --
                        return ResolvedVelocity
                    else
                        return RootPart.Velocity
                    end
                else    
                    return RootPart.Velocity
                end
            end
 
            local function GetBodySize(Character)
                local Part = GetClosestPartToCursor(Character)
                if (Part) then
                    local l = workspace.CurrentCamera:WorldToScreenPoint(Part.Position - Part.Size / 2)
                    local r = workspace.CurrentCamera:WorldToScreenPoint(Part.Position + Part.Size / 2)
                    local w = math.abs(l.X - r.X)
                    local h = math.abs(l.Y - r.Y)
                    --
                    return w, h
                end
                --
                return 0, 0 
            end
            
            local function get_quad(a, b, c)
                local s = b^2 - 4 * a * c
                if s < 0 then
                    return nil
                end
                local d = math.sqrt(s)
                local t1 = (-b + d) / (2 * a)
                local t2 = (-b - d) / (2 * a)
                --
                if t1 >= 0 and t2 >= 0 then
                    return math.min(t1, t2)
                elseif t1 >= 0 then
                    return t1
                elseif t2 >= 0 then
                    return t2
                end
                --
                return nil
            end
            --
            local function get_interception(A, B0, v_t, v_b)
                local function getCoefficients(A_comp, B_comp, v_t_comp)
                    local a = v_t_comp * v_t_comp - v_b^2
                    local b = 2 * (A_comp - B_comp) * v_t_comp
                    local c = (A_comp - B_comp) * (A_comp - B_comp)
                    return a, b, c
                end
            
                local function solveDimension(A_comp, B_comp, v_t_comp)
                    local a, b, c = getCoefficients(A_comp, B_comp, v_t_comp)
                    return get_quad(a, b, c)
                end
            
                local t_x, err_x = solveDimension(A.x, B0.x, v_t.x)
                local t_y, err_y = solveDimension(A.y, B0.y, v_t.y)
                local t_z, err_z = solveDimension(A.z, B0.z, v_t.z)
            
                if not t_x or not t_y or not t_z then
                    return nil, 'how did we end up here'
                end
            
                local t = math.max(t_x, t_y, t_z)
            
                local Bt = B0 + v_t * t
                return Bt, t_x, t_y, t_z
            end
            --
            local function get_ground(position)
                local ray = Ray.new(position, Vector3.new(0, -1000, 0))
                local hitPart, hitPosition = workspace:FindPartOnRay(ray)
                --
                if hitPart then
                    return hitPosition.Y
                else
                    return position.Y
                end
            end
            --
            local function backup_velocity(t, width, height)
                local average_size = (width + height) / 2
                local base_size = 100
                local size_factor = (average_size / base_size) - 1
                size_factor = math.clamp(size_factor, -1, 1)
                local min_adjustment = 0.05
                local max_adjustment = 0.145
                local adjustment_range = max_adjustment - min_adjustment
                local adjusted_t = min_adjustment + (size_factor ^ 2) * adjustment_range
                return adjusted_t
            end
            --
            local function get_velocity(t, width, height)
                local average_size = (width + height) / 2
                local base_size = 100
                local size_factor = (average_size / base_size) - 1
                size_factor = math.clamp(size_factor, -1, 1)
            
                local min_adjustment = 0.05
                local max_adjustment = 0.145
                local adjustment_range = max_adjustment - min_adjustment
            
                local adjustment = min_adjustment + (size_factor ^ 2) * adjustment_range
                return Vector3.new(adjustment, adjustment, adjustment) * t
            end
            
            local function m_wait()
                local t = tick()
                game.ReplicatedStorage.DefaultChatSystemChatEvents.MutePlayerRequest:InvokeServer()
                return (tick() - t) * 1000 / 0.5
            end
            
            local function AutomatedPrediction()
                local silentAimSettings = shared.Story
                local TargetPlayerData = Mango.Locals.SilentAimTarget
            
                local silentAimTarget = TargetPlayerData
                local playerCharacter = Self.Character
            
                if silentAimTarget and silentAimTarget.Character and playerCharacter and silentAimSettings.Automated then
                    local tool = playerCharacter:FindFirstChildOfClass('Tool')
                    local handle = tool and tool:FindFirstChild('Handle')
                    local shootBBGUI = handle and handle:FindFirstChild('ShootBBGUI')
            
                    if not silentAimTarget.Character:FindFirstChild("Humanoid") then
                        return
                    end
                    if handle and shootBBGUI then
                        local humanoidRootPart = TargetPlayerData.Character.HumanoidRootPart
                        local Velocity = IsDesynced(humanoidRootPart) and Resolve(humanoidRootPart) or humanoidRootPart.Velocity
                        local handlePosition = handle.Position
                        local origin = handlePosition + handle.CFrame:VectorToWorldSpace(shootBBGUI.StudsOffsetWorldSpace)
            
                        Velocity_Data.Recorded = {
                            Alpha = origin,
                            B_0 = humanoidRootPart.Position,
                            V_T = Velocity,
                            V_B = m_wait() * silentAimSettings.SilentAim.Prediction.Stabilize
                        }
                        
                        local Bt, t_x, t_y, t_z = get_interception(
                            origin,
                            humanoidRootPart.Position,
                            Velocity,
                            Velocity_Data.Recorded.V_B
                        )
            
                        if Bt then
                            local predictionVector = Vector3.new(t_x, t_y, t_z)
                            local width, height = GetBodySize(silentAimTarget)
                            silentAimSettings.SilentAim.Prediction.X = backup_velocity(predictionVector.Magnitude, width, height)
                            silentAimSettings.SilentAim.Prediction.Y = backup_velocity(predictionVector.Magnitude, width, height)
            
                            local adjustedPrediction = get_velocity(predictionVector, width, height)
                            if adjustedPrediction then
                                local groundLevel = get_ground(Bt)
                                Bt = Vector3.new(Bt.X, math.max(Bt.Y, groundLevel), Bt.Z)
            
                                local heightAdjustment = math.max(0, Bt.Y - humanoidRootPart.Position.Y)
                                Velocity_Data.Y = adjustedPrediction.Y * (heightAdjustment / (Bt.Y - humanoidRootPart.Position.Y + 1))
                                Velocity_Data.State = TargetPlayerData.Character.Humanoid:GetState()
                            end
                        end
                    end
                end
            end
    
            local function GetClosestPartToCursorAimAssist(Character)
                local CurrentCamera = Workspace.CurrentCamera
                local MousePosition = UserInputService:GetMouseLocation()
                
                local AllowedParts = shared.Story['Aim Assist'].Hitpart or { 'Head', 'HumanoidRootPart' }
                
                local ClosestPart = nil
                local ClosestDistance = 1/0
                
                for _, partName in ipairs(AllowedParts) do
                    local Part = Character:FindFirstChild(partName)
                    if Part and Part:IsA("BasePart") then
                        local Position = CurrentCamera:WorldToViewportPoint(Part.Position)
                        if Position.Z > 0 then
                            local Distance = (Vector2.new(Position.X, Position.Y) - MousePosition).Magnitude
                            if Distance < ClosestDistance then
                                ClosestPart = Part
                                ClosestDistance = Distance
                            end
                        end
                    end
                end
                
                return ClosestPart
            end
 
            local function GetHitPosition(Mode)
    if Mode == 'Assist' then
        if not Mango.Locals.AimAssistTarget then return Vector3.new(0, 0, 0) end
        if not Mango.Locals.AimAssistTarget.Character then return Vector3.new(0, 0, 0) end
        
        local TargetPart = GetClosestPartToCursorAimAssist(Mango.Locals.AimAssistTarget.Character)
        if not TargetPart then return Vector3.new(0, 0, 0) end
        
        local TargetPosition = TargetPart.Position
 
        if shared.Story['Aim Assist'].Prediction.Enabled then
            local RootPart = Mango.Locals.AimAssistTarget.Character.HumanoidRootPart
            local Velocity
            if typeof(IsDesynced) == "function" and typeof(Resolve) == "function" then
                Velocity = IsDesynced(RootPart) and Resolve(RootPart) or RootPart.Velocity
            else
                Velocity = RootPart.Velocity
            end
            local PredictionVector = Vector3.new(
                shared.Story['Aim Assist'].Prediction.X,
                shared.Story['Aim Assist'].Prediction.Y,
                shared.Story['Aim Assist'].Prediction.Z
            )
            return TargetPosition + Velocity * PredictionVector
        else
            return TargetPosition
        end
    end
 
    if Mode == 'Silent' then
        if not Mango.Locals.SilentAimTarget then return Vector3.new(0, 0, 0) end
        if not Mango.Locals.SilentAimTarget.Character then return Vector3.new(0, 0, 0) end
 
        -- Get target part based on Hitpart config priority (Head first, then HumanoidRootPart)
        local TargetPart = GetClosestPartToCursor(Mango.Locals.SilentAimTarget.Character)
        if not TargetPart then return Vector3.new(0, 0, 0) end
        
        local TargetPosition = TargetPart.Position
 
        if shared.Story.SilentAim.Prediction.Enabled then
            local RootPart = Mango.Locals.SilentAimTarget.Character.HumanoidRootPart
            local Velocity
            if typeof(IsDesynced) == "function" and typeof(Resolve) == "function" then
                Velocity = IsDesynced(RootPart) and Resolve(RootPart) or RootPart.Velocity
            else
                Velocity = RootPart.Velocity
            end
 
            local PredictionVector = Vector3.new(
                shared.Story.SilentAim.Prediction.X,
                shared.Story.SilentAim.Prediction.Y,
                shared.Story.SilentAim.Prediction.Z
            )
 
            Mango.Locals.HitPosition = TargetPosition + Velocity * PredictionVector
        else
            Mango.Locals.HitPosition = TargetPosition
        end
 
        return Mango.Locals.HitPosition
    end
end
 
    
            return {
                GetClosestPlayerToCursor = GetClosestPlayerToCursor,
                GetClosestPartToCursorFilter = GetClosestPartToCursorFilter,
                SelfMods = SelfMods,
                GetOrigin = GetOrigin,
                IsKnocked = IsKnocked,
                IsGrabbed = IsGrabbed,
                ValidateClient = ValidateClient,
                GetClosestPointOnPart = GetClosestPointOnPart,
                GetClosestPointOnPartBasic = GetClosestPointOnPartBasic,
                GetClosestPartToCursor = GetClosestPartToCursor,
                GetClosestPartToCursorAimAssist = GetClosestPartToCursorAimAssist,
                GetHitPosition = GetHitPosition,
                AutomatedPrediction = AutomatedPrediction
    
            }
        end
        --
        function Modules.DaHood()
            if CurrentGame.Name == "Da Hood" then
                local IsClient = RunService:IsClient()
                local PlaceIDCheck = game.PlaceId == 88976059384565
        
                local function CanShoot(Character)
                    if Character then
                        local Humanoid = Character:FindFirstChild("Humanoid")
                        if Humanoid and (Humanoid.Health > 0 and Humanoid:GetState() ~= Enum.HumanoidStateType.Dead) then
                            local BodyEffects = Character:FindFirstChild("BodyEffects")
                            if BodyEffects then
                                local Tool = Character:FindFirstChildWhichIsA("Tool")
                                if Tool and (Tool:FindFirstChild("Handle") and Tool:FindFirstChild("Ammo")) then
                                    if not PlaceIDCheck and IsClient then
                                        if BodyEffects:FindFirstChild("Block") then
                                            shared.playerShot(Tool.Handle)
                                            Tool.Handle.NoAmmo:Play()
                                            return
                                        end
                                        if Tool.Ammo.Value == 0 then
                                            Tool.Handle.NoAmmo:Play()
                                            return
                                        end
                                    end
                                    if Character:FindFirstChild("FULLY_LOADED_CHAR") == nil then
                                        return
                                    elseif Character:FindFirstChild("FORCEFIELD") then
                                        return
                                    elseif Character:FindFirstChild("GRABBING_CONSTRAINT") then
                                        return
                                    elseif Character:FindFirstChild("Christmas_Sock") then
                                        return
                                    elseif BodyEffects.Cuff.Value == true then
                                        return
                                    elseif BodyEffects.Attacking.Value == true then
                                        return
                                    elseif BodyEffects["K.O"].Value == true then
                                        return
                                    elseif BodyEffects.Grabbed.Value then
                                        return
                                    elseif BodyEffects.Reload.Value == true then
                                        return
                                    elseif BodyEffects.Dead.Value == true then
                                        return
                                    elseif not Tool:GetAttribute("Cooldown") then
                                        local LastShot = Character:GetAttribute("LastGunShot")
                                        Character:SetAttribute("LastGunShot", Tool.Name)
                                        if not IsClient or (LastShot == Tool.Name or not Character:GetAttribute("ShotgunDebounce")) then
                                            if not IsClient and (not Character:GetAttribute("ShotgunDebounce") and (Tool.Name == "[Shotgun]" or (Tool.Name == "[Double-Barrel SG]" or (Tool.Name == "TacticalShotgun" or Tool.Name == "Drum-Shotgun")))) then
                                                
                                                Character:SetAttribute("ShotgunDebounce", true)
                                                task.delay(0.65, function()
                                                    Character:SetAttribute("ShotgunDebounce", nil)
                                                end)
                                                
                                                --Character:SetAttribute("ShotgunDebounce", nil)
                                            end
                                            return true
                                        end
                                    end
                                else
                                    return
                                end
                            else
                                return
                            end
                        else
                            return
                        end
                    else
                        return
                    end
                end
        
        
                local function ColorTransform(p14, p15)
                    if p15 == 0 then
                        return p14.Keypoints[1].Value
                    end
                    if p15 == 1 then
                        return p14.Keypoints[#p14.Keypoints].Value
                    end
                    for v16 = 1, #p14.Keypoints - 1 do
                        local v17 = p14.Keypoints[v16]
                        local v18 = p14.Keypoints[v16 + 1]
                        if v17.Time <= p15 and p15 < v18.Time then
                            local v19 = (p15 - v17.Time) / (v18.Time - v17.Time)
                            return Color3.new((v18.Value.R - v17.Value.R) * v19 + v17.Value.R, (v18.Value.G - v17.Value.G) * v19 + v17.Value.G, (v18.Value.B - v17.Value.B) * v19 + v17.Value.B)
                        end
                    end
                end
        
                local weaponNames = {
                    "[Shotgun]",
                    "[Drum-Shotgun]",
                    "[Rifle]",
                    "[TacticalShotgun]",
                    "[AR]",
                    "[AUG]",
                    "[AK47]",
                    "[LMG]",
                    "[SilencerAR]",
                }
                
                local replicatedStorage = game:GetService("ReplicatedStorage")
                local playersService = game:GetService("Players")
                local localPlayer = playersService.LocalPlayer
                local playerCharacter = Self.Character or Self.CharacterAdded:Wait()
                local shootAnimation = playerCharacter.Humanoid.Animator:LoadAnimation(
                    replicatedStorage:WaitForChild("Animations"):WaitForChild("GunCombat"):WaitForChild("Shoot")
                )
                local aimShootAnimation = playerCharacter.Humanoid.Animator:LoadAnimation(
                    replicatedStorage:WaitForChild("Animations"):WaitForChild("GunCombat"):WaitForChild("AimShoot")
                )
                
                local v_u_14 = {}
        
                local function changefunc()
                    local v_u_38 = {
                        ["functions"] = {},
                    }
        
                    function v_u_38.connect(_, p36)
                        local v37 = v_u_38.functions
                        table.insert(v37, p36)
                    end
                    local v_u_39 = nil
                    function v_u_38.updatechanges(_, p_u_40)
                        -- upvalues: (copy) v_u_38, (ref) v_u_39
                        for _, v_u_41 in pairs(v_u_38.functions) do
                            spawn(function()
                                -- upvalues: (copy) v_u_41, (copy) p_u_40, (ref) v_u_39
                                v_u_41(p_u_40.Press, p_u_40.Time, v_u_39)
                            end)
                        end
                        v_u_39 = p_u_40.Time
                    end
                    return v_u_38
                end
        
        
                setmetatable(v_u_14, {
                    ["__index"] = function(_, p42)
                        -- upvalues: (copy) v_u_14
                        local v43 = v_u_14
                        if getmetatable(v43)[p42] == nil then
                            v_u_14[p42] = {}
                        end
                        local v44 = v_u_14
                        return getmetatable(v44)[p42]
                    end,
                    ["__newindex"] = function(_, p45, p46)
                        -- upvalues: (copy) v_u_14
                        local v47 = v_u_14
                        if getmetatable(v47)[p45] == nil then
                            local v48 = v_u_14
                            getmetatable(v48)[p45] = {
                                ["val"] = p46,
                                ["changed"] = changefunc()
                            }
                        else
                            local v49 = v_u_14
                            getmetatable(v49)[p45].val = p46
                            local v50 = v_u_14
                            getmetatable(v50)[p45].changed:updatechanges(p46)
                        end
                    end
                })
        
                UserInputService.InputBegan:connect(function(p51, p52)
                    if not p52 or p51.UserInputType == Enum.UserInputType.Keyboard and p51.KeyCode == Enum.KeyCode.LeftShift or p51.UserInputType == Enum.UserInputType.Gamepad1 and p51.KeyCode == Enum.KeyCode.ButtonL2 then
                        if p51.UserInputType == Enum.UserInputType.Keyboard or p51.UserInputType == Enum.UserInputType.Gamepad1 then
                            v_u_14[p51.KeyCode.Name] = {
                                ["Press"] = true,
                                ["Time"] = tick()
                            }
                            return
                        end
                        if p51.UserInputType == Enum.UserInputType.MouseButton2 then
                            v_u_14[Enum.UserInputType.MouseButton2.Name] = {
                                ["Press"] = true,
                                ["Time"] = tick()
                            }
                        end
                    end
                end)
                UserInputService.InputEnded:connect(function(p53, p54)
                    if not p54 or p53.UserInputType == Enum.UserInputType.Keyboard and p53.KeyCode == Enum.KeyCode.LeftShift or p53.UserInputType == Enum.UserInputType.Gamepad1 and p53.KeyCode == Enum.KeyCode.ButtonL2 then
                        if p53.UserInputType == Enum.UserInputType.Keyboard or p53.UserInputType == Enum.UserInputType.Gamepad1 then
                            v_u_14[p53.KeyCode.Name] = {
                                ["Press"] = false,
                                ["Time"] = tick()
                            }
                            return
                        end
                        if p53.UserInputType == Enum.UserInputType.MouseButton2 then
                            v_u_14[Enum.UserInputType.MouseButton2.Name] = {
                                ["Press"] = false,
                                ["Time"] = tick()
                            }
                        end
                    end
                end)
        
        
        
                local v_u_70 = true
                v_u_14.MouseButton2.changed:connect(function(p71, _, _)
                    -- upvalues: (ref) v_u_70, (ref) v_u_20
                    if v_u_70 ~= false then
                        Mango.Locals.IsAimed = p71
                        if Mango.Locals.IsAimed == false then
                            v_u_70 = false
                            wait(0.1)
                            v_u_70 = true
                        end
                    end
                end)
        
                local function Animate(target)
                    playerCharacter = localPlayer.Character or localPlayer.CharacterAdded:Wait()
                
                    if playerCharacter and playerCharacter:FindFirstChild("Humanoid") and playerCharacter.Humanoid:FindFirstChild("Animator") then
                        shootAnimation = playerCharacter.Humanoid.Animator:LoadAnimation(replicatedStorage.Animations.GunCombat.Shoot)
                        aimShootAnimation = playerCharacter.Humanoid.Animator:LoadAnimation(replicatedStorage.Animations.GunCombat.AimShoot)
                
                        if Mango.Locals.IsAimed or table.find(weaponNames, target.Parent.Name) then
                            aimShootAnimation:Play()
                        else
                            shootAnimation:Play()
                        end
                    end
                end
                
        
            
                shared.playerShot = Animate
                local v3 = game:GetService("Players")
                local v_u_5 = game:GetService("TweenService")
                local v_u_7 = v3.LocalPlayer
                local v_u_9 = ReplicatedStorage.SkinAssets
                local v_u_13 = workspace:GetServerTimeNow()
                local _ = game.PlaceId == 88976059384565
                local SoundsPlaying = {}
        
                
                local function GetAim(Position)
            
                    if _G.MobileShiftLock then
                        return (Camera.CFrame.p + Camera.CFrame.LookVector * 60 - Position).unit
                    end
                    local v24
                    if Mouse.Target then
                        v24 = Mouse.Hit.p
                    else
                        local v25 = Camera.CFrame
                        local v26 = v25.p + v25.LookVector * 60
                        local v27 = v25.LookVector
                        local v28 = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
                        local v29 = v28.Direction
                        local v30 = v28.Origin
                        v24 = v30 + v29 * ((v26 - v30):Dot(v27) / v29:Dot(v27))
                    end
                    return (v24 - Position).Unit, (v24 - Position).Magnitude
                end
                
                local function ShootGun(p34)
                
                    local v35 = p34.Shooter
                    local v_u_36 = p34.Handle
                    local v37 = p34.AimPosition
                    local v38 = p34.BeamColor
                    local v39 = p34.isReflecting
                    local v40 = p34.Hit
                    local v41 = p34.Range or 200
                    local LegitPosition = p34.LegitPosition
                    local v_u_42
                    if v_u_36 then
                        v_u_42 = v_u_36:GetAttribute("SkinName")
                    else
                        v_u_42 = v_u_36
                    end
                    local _, v43 = GetAim(v_u_36.Position)
                    local v_u_44 = p34.ForcedOrigin or v_u_36.Muzzle.WorldPosition
                    local v45 = (v37 - v_u_44).Unit
                    local v46 = RaycastParams.new()
                    local v47 = {}
                    local function set_list(targetTable, index, values)
                        for i, v in ipairs(values) do
                            targetTable[index + i - 1] = v
                        end
                    end
                    
                    local v48 = { workspace:WaitForChild("Bush"), workspace:WaitForChild("Ignored") }
                    set_list(v47, 1, {v35, unpack(v48)})
                    
                    v46.FilterDescendantsInstances = v47
                    v46.FilterType = Enum.RaycastFilterType.Exclude
                    v46.IgnoreWater = true
                    local v_u_49, v_u_50, v_u_51
                    if v40 then
                        v_u_49 = p34.Hit
                        v_u_50 = p34.AimPosition
                        v_u_51 = p34.Normal
                    else
                        local v52 = workspace:Raycast(v_u_44, v45 * v41, v46)
                        if v52 then
                            v_u_49 = v52.Instance
                            v_u_50 = v52.Position
                            v_u_51 = v52.Normal
                        else
                            v_u_50 = v_u_44 + v45 * math.min(v43, v41)
                            v_u_51 = nil
                            v_u_49 = nil
                        end
                    end
                    
                    
                    local v_u_53 = Instance.new("Part")
                    v_u_53:SetAttribute("OwnerCharacter", v35.Name)
                    v_u_53.Name = "BULLET_RAYS"
                    v_u_53.Anchored = true
                    v_u_53.CanCollide = false
                    v_u_53.Size = Vector3.new(0, 0, 0)
                    v_u_53.Transparency = 1
                    game.Debris:AddItem(v_u_53, 1)
                    -- Client Redirection removed - use default
                    v_u_53.CFrame = CFrame.new(v_u_44, v_u_50)
                    v_u_53.Material = Enum.Material.SmoothPlastic
                    v_u_53.Parent = workspace.Ignored.Siren.Radius
                    local v54 = Instance.new("Attachment")
                    v54.Position = Vector3.new(0, 0, 0)
                    v54.Parent = v_u_53
                    local v55 = Instance.new("Attachment")
                    local v56 = -(v_u_50 - v_u_44).magnitude
                    v55.Position = Vector3.new(0, 0, v56)
                    v55.Parent = v_u_53
                    local v_u_57 = false
                    local v_u_58 = nil
                    local v59
                    if v_u_36 then
                        local v60 = v_u_36.Parent.Name
                        if v_u_42 and v_u_42 ~= "" then
                            if v_u_9.GunSkinMuzzleParticle:FindFirstChild(v_u_42) then
                                if not v39 then
                                    if v_u_9.GunSkinMuzzleParticle[v_u_42]:FindFirstChild("Muzzle") then
                                        if v_u_36.Parent:FindFirstChild("Default") and (v_u_36.Parent.Default:FindFirstChild("Mesh") and v_u_36.Parent.Default.Mesh:FindFirstChild("Muzzle")) then
                                            local v61
                                            if v_u_9.GunSkinMuzzleParticle[v_u_42].Muzzle:FindFirstChild("Different_GunMuzzle") then
                                                v61 = v_u_9.GunSkinMuzzleParticle[v_u_42].Muzzle.Different_GunMuzzle[v60]
                                            else
                                                v61 = v_u_9.GunSkinMuzzleParticle[v_u_42].Muzzle
                                            end
                                            for _, v62 in pairs(v61:GetChildren()) do
                                                local v63 = v62:GetAttribute("EmitCount") or 1
                                                local v_u_64 = v62:Clone()
                                                v_u_64.Parent = v_u_36.Parent.Default.Mesh.Muzzle
                                                v_u_64:Emit(v63)
                                                task.delay(v_u_64.Lifetime.Max, function()
                                                    -- upvalues: (copy) v_u_64
                                                    v_u_64:Destroy()
                                                end)
                                            end
                                        end
                                    else
                                        local v65 = v_u_9.GunSkinMuzzleParticle[v_u_42]:GetChildren()
                                        local v66 = v65[math.random(#v65)]:Clone()
                                        v66.Parent = v54
                                        v66:Emit(v66.Rate)
                                    end
                                end
                                v_u_57 = true
                            end
                            if v_u_9.GunBeam:FindFirstChild(v_u_42) then
                                if v_u_9.GunBeam[v_u_42].GunBeam:IsA("BasePart") then
                                    v59 = {
                                        ["Parent"] = nil,
                                        ["Attachment0"] = nil,
                                        ["Attachment1"] = nil
                                    }
                                    if v_u_9.GunBeam[v_u_42].GunBeam:FindFirstChild("Different_GunBeam") then
                                        if v_u_9.GunBeam[v_u_42].GunBeam.Different_GunBeam[v60].GunBeam:IsA("BasePart") then
                                            v_u_58 = v_u_9.GunBeam[v_u_42].GunBeam.Different_GunBeam[v60].GunBeam:Clone()
                                        else
                                            v59 = v_u_9.GunBeam[v_u_42].GunBeam.Different_GunBeam[v60].GunBeam:Clone()
                                        end
                                    else
                                        v_u_58 = v_u_9.GunBeam[v_u_42].GunBeam:Clone()
                                    end
                                else
                                    v59 = v_u_9.GunBeam[v_u_42].GunBeam:Clone()
                                end
                            else
                                v59 = game.ReplicatedStorage.GunBeam:Clone()
                                v59.Color = v38 and ColorSequence.new(v38) or v59.Color
                            end
                        else
                            v59 = game.ReplicatedStorage.GunBeam:Clone()
                            v59.Color = v38 and ColorSequence.new(v38) or v59.Color
                        end
                    else
                        v59 = nil
                    end
                    task.spawn(function()
                        -- upvalues: (ref) v_u_58, (ref) v_u_50, (copy) v_u_44, (ref) v_u_21, (ref) v_u_49, (ref) v_u_51, (copy) v_u_42, (ref) v_u_9, (copy) v_u_53, (copy) v_u_36, (ref) v_u_57, (ref) v_u_5
                        if v_u_58 then
                            local v67 = (v_u_50 - v_u_44).magnitude
                            local v68 = v67 / 725
                            v_u_58.Anchored = true
                            v_u_58.CanCollide = false
                            v_u_58.CanQuery = false
                            v_u_58.CFrame = CFrame.new(v_u_44, v_u_50)
                            local v69 = v_u_58.CFrame * CFrame.new(0, 0, -v67)
                            v_u_58.Parent = workspace.Ignored.Siren.Radius
                            task.delay(v68 + 5, function()
                                -- upvalues: (ref) v_u_58
                                v_u_58:Destroy()
                                v_u_58 = nil
                            end)
                            if v_u_58:GetAttribute("SpecialEffects") then
                                for _, v70 in pairs(v_u_58:GetDescendants()) do
                                    if v70:IsA("Trail") and v70:GetAttribute("ColorRandom") then
                                        local v71 = v70:GetAttribute("ColorRandom")
                                        v70.Color = ColorSequence.new(ColorTransform(v71, math.random()))
                                    end
                                end
                            end
                            local v72 = game:GetService("TweenService"):Create(v_u_58, TweenInfo.new(0.05, Enum.EasingStyle.Linear), {
                                ["CFrame"] = v_u_58.CFrame * CFrame.new(0, 0, -0.1)
                            })
                            v72:Play()
                            task.wait(0.05)
                            if v72.PlaybackState ~= Enum.PlaybackState.Completed then
                                v72:Pause()
                            end
                            local v73 = nil
                            if _G.Reduce_Lag and not v_u_58:GetAttribute("NoSlow") or v_u_58:GetAttribute("LOWGFX") then
                                v_u_58.CFrame = v69
                            else
                                v73 = game:GetService("TweenService"):Create(v_u_58, TweenInfo.new(v68, Enum.EasingStyle.Linear), {
                                    ["CFrame"] = v69
                                })
                                v73:Play()
                                task.wait(v68)
                            end
                            if v_u_58:FindFirstChild("Impact") and (v_u_49 and (v_u_51 and not v_u_49.Parent:FindFirstChild("Humanoid"))) then
                                if v73 and v73.PlaybackState ~= Enum.PlaybackState.Completed then
                                    task.wait(0.05)
                                end
                                if not v_u_58:FindFirstChild("NoNormal") then
                                    v_u_58.CFrame = CFrame.new(v_u_50, v_u_50 - v_u_51)
                                end
                                for _, v74 in pairs(v_u_58.Impact:GetChildren()) do
                                    if v74:IsA("ParticleEmitter") then
                                        v74:Emit(v74:GetAttribute("EmitCount") or 1)
                                    end
                                end
                            else
                                for _, v75 in pairs(v_u_58:GetChildren()) do
                                    if v75:IsA("BasePart") then
                                        v75.Transparency = 1
                                    end
                                end
                            end
                            if v_u_58 then
                                for _, v76 in pairs(v_u_58:GetDescendants()) do
                                    if v76:IsA("ParticleEmitter") then
                                        v76.Enabled = false
                                    end
                                end
                            end
                        elseif v_u_49 and (v_u_49:IsDescendantOf(workspace.MAP) and (v_u_42 and (v_u_9.GunBeam:FindFirstChild(v_u_42) and v_u_9.GunBeam[v_u_42]:FindFirstChild("Impact")))) then
                            local v_u_77 = v_u_9.GunBeam[v_u_42].Impact:Clone()
                            v_u_77.Parent = workspace.Ignored
                            v_u_77:PivotTo(CFrame.new(v_u_50, v_u_50 + v_u_51 * 5) * CFrame.Angles(-1.5707963267948966, 0, 0))
                            for _, v78 in pairs(v_u_77:GetDescendants()) do
                                if v78:IsA("ParticleEmitter") then
                                    v78:Emit(v78:GetAttribute("EmitCount") or 1)
                                end
                            end
                            task.delay(1.5, function()
                                -- upvalues: (ref) v_u_77
                                v_u_77:Destroy()
                                v_u_77 = nil
                            end)
                        end
                        local v79 = Instance.new("PointLight")
                        v79.Brightness = 0.5
                        v79.Range = 15
                        v79.Shadows = true
                        v79.Color = Color3.new(1, 1, 1)
                        v79.Parent = v_u_53
                        local v80 = v_u_36:FindFirstChild("ShootBBGUI")
                        local v81 = v80 and (not v_u_57 and v80:FindFirstChild("Shoot"))
                        if v81 then
                            v81.Size = UDim2.new(0, 0, 0, 0)
                            v81.ImageTransparency = 1
                            v81.Visible = true
                            v_u_5:Create(v81, TweenInfo.new(0.4, Enum.EasingStyle.Bounce, Enum.EasingDirection.In, 0, false, 0), {
                                ["Size"] = UDim2.new(1, 0, 1, 0),
                                ["ImageTransparency"] = 0.4
                            }):Play()
                            v_u_5:Create(v79, TweenInfo.new(0.4, Enum.EasingStyle.Bounce, Enum.EasingDirection.In, 0, false, 0), {
                                ["Range"] = 0
                            }):Play()
                            wait(0.4)
                            v_u_53:Destroy()
                            v_u_5:Create(v81, TweenInfo.new(0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.In, 0, false, 0), {
                                ["Size"] = UDim2.new(1, 0, 1, 0),
                                ["ImageTransparency"] = 1
                            }):Play()
                            wait(0.2)
                            v81.Visible = false
                        end
                    end)
                    v59.Attachment0 = v54
                    v59.Attachment1 = v55
                    v59.Name = "NewGunBeam"
                    v59.Parent = v_u_53
                    if v35 == v_u_7.Character and workspace:GetServerTimeNow() - v_u_13 > 0.95 then
                        Animate(v_u_36)
                    end
        
                    local playsound = function(p1, p2)
                        local v3 = p1.ShootSound:GetAttribute("SequenceSFX")
                        if v3 then
                            if p1.ShootSound:GetAttribute("CurrentSequence") == nil then
                                p1.ShootSound:SetAttribute("CurrentSequence", 1)
                            else
                                p1.ShootSound:SetAttribute("CurrentSequence", p1.ShootSound:GetAttribute("CurrentSequence") + 1)
                            end
                            local v4 = p1.ShootSound:GetAttribute("CurrentSequence")
                            local v5 = {}
                            for v6 in string.gmatch(v3, "%d+") do
                                table.insert(v5, v6)
                            end
                            p1.ShootSound.SoundId = "rbxassetid://" .. v5[v4 % #v5 + 1]
                        end
                        if p2 then
                            local v_u_7 = p1.ShootSound:Clone()
                            v_u_7.Name = "MG"
                            v_u_7.Parent = p1
                            v_u_7:Play()
                            delay(1, function()
                                -- upvalues: (copy) v_u_7
                                v_u_7:Destroy()
                            end)
                        else
                            p1.ShootSound:Play()
                        end
                    end    
        
                    if not SoundsPlaying[v_u_36] then
                        task.spawn(playsound, v_u_36, true)
                        SoundsPlaying[v_u_36] = true
                        task.delay(0.021, function()
                            -- upvalues: (ref) SoundsPlaying, (copy) v_u_36
                            SoundsPlaying[v_u_36] = nil
                        end)
                    end
                    if game.Lighting:GetAttribute("printhits") then
                        local v82 = print
                        local v83 = v_u_49
                        if v83 then
                            v83 = v_u_49:GetFullName()
                        end
                        v82(v83)
                    end
        
            
                    return v_u_50, v_u_49, v_u_51
                end
        
                
        
                return {
                    CanShoot = CanShoot,
                    Animate = Animate,
                    GetAim = GetAim,
                    ColorTransform = ColorTransform,
                    ShootGun = ShootGun,
                }
            else
                return {}
            end
        end
        --
        function Modules.Main()
            local Engine = Modules.Get("Engine")
            local Player = Modules.Get("Player")
            local DaHood = Modules.Get("DaHood")
            local Current_t = 0
        
            local function GetGunCategory()
                if Self and Self.Character then
                    local Tool = Self.Character:FindFirstChildWhichIsA("Tool")
                    if Tool then
                        if table.find(WeaponInfo.Weapons.Shotguns, Tool.Name) then
                            return "Shotgun"
                        end
            
                        if table.find(WeaponInfo.Weapons.Pistols, Tool.Name) then
                            return "Pistol"
                        end
    
                        if table.find(WeaponInfo.Weapons.Rifles, Tool.Name) then
                            return "Rifle"
                        end
    
                        if table.find(WeaponInfo.Weapons.Bursts, Tool.Name) then
                            return "Burst"
                        end
    
                        if table.find(WeaponInfo.Weapons.SMG, Tool.Name) then
                            return "SMG"
                        end
    
                        if table.find(WeaponInfo.Weapons.Snipers, Tool.Name) then
                            return "Sniper"
                        end
    
                        if table.find(WeaponInfo.Weapons.AutoShotguns, Tool.Name) then
                            return "Auto"
                        end
                    end
                end
                return nil
            end
    
 
 
 
            local function UpdateBox()
    -- Initialize BoxFOV (Combined Silent Aim + Aim Assist) if not exists
    if not Mango.Visuals.BoxFOV then
        Mango.Visuals.BoxFOV = Overlay.new('Circle')
        Mango.Visuals.BoxFOV.Thickness = 2
        Mango.Visuals.BoxFOV.Transparency = 0
    end
    
    -- Hide the separate Aim Assist FOV if it exists (using combined FOV now)
    if Mango.Visuals.AimAssistFOV then
        Mango.Visuals.AimAssistFOV.Visible = false
    end
    
    -- Always show FOV at screen center (cursor position)
    local screenSize = Camera.ViewportSize
    local centerX = screenSize.X / 2
    local centerY = screenSize.Y / 2
 
    -- Check if combined FOV should be visible
    local fovConfig = shared.Story and shared.Story.Fov
    local fovEnabled = fovConfig and fovConfig.Enabled and fovConfig.Visible
 
    -- Show FOV if enabled and either Silent Aim or Aim Assist is enabled
    local silentAimEnabled = shared.Story and shared.Story.SilentAim and shared.Story.SilentAim.Enabled
    local aimAssistEnabled = shared.Story and shared.Story['Aim Assist'] and shared.Story['Aim Assist'].Enabled
 
    -- Determine FOV size: use config if enabled and visible, otherwise use 2000 (full screen)
    local fovSize = (fovEnabled and fovConfig.Size) or 2000
    local fovColor = fovConfig and fovConfig.Color or Color3.fromRGB(255, 255, 255)
 
    if fovEnabled and (silentAimEnabled or aimAssistEnabled) then
        Mango.Visuals.BoxFOV.Position = Vector2.new(centerX - fovSize/2, centerY - fovSize/2)
        Mango.Visuals.BoxFOV.Size = Vector2.new(fovSize, fovSize)
    end
 
    -- Check if Silent Aim target is within circle FOV
    local hasSilentTarget = false
    if Mango.Locals.SilentAimTarget and Mango.Locals.SilentAimTarget.Character then
        local Object, Humanoid, RootPart = Player.ValidateClient(Mango.Locals.SilentAimTarget)
        if (Object and Humanoid and RootPart) then
            local Pos = RootPart.Position
            local Position, Visible = Camera:WorldToViewportPoint(Pos)
            
            local dist = math.sqrt((Position.X - centerX)^2 + (Position.Y - centerY)^2)
            
            if dist <= fovSize / 2 then
                hasSilentTarget = true
            end
        end
    end
    
    -- Check if Aim Assist target is within circle FOV
    local hasAATarget = false
    if Mango.Locals.AimAssistTarget and Mango.Locals.AimAssistTarget.Character then
        local Object, Humanoid, RootPart = Player.ValidateClient(Mango.Locals.AimAssistTarget)
        if (Object and Humanoid and RootPart) then
            local TargetPart = Player.GetClosestPartToCursorAimAssist(Mango.Locals.AimAssistTarget.Character)
            if TargetPart then
                local Position, Visible = Camera:WorldToViewportPoint(TargetPart.Position)
                if Visible then
                    local dist = math.sqrt((Position.X - centerX)^2 + (Position.Y - centerY)^2)
                    if dist <= fovSize / 2 then
                        hasAATarget = true
                    end
                end
            end
        end
    end
    
    -- Update FOV visual if enabled
    if fovEnabled and (silentAimEnabled or aimAssistEnabled) then
        -- FOV stays white always
        Mango.Locals.IsBoxFocused = hasSilentTarget or hasAATarget
        Mango.Visuals.BoxFOV.Color = fovColor
        Mango.Visuals.BoxFOV.Visible = true
    else
        -- FOV not enabled: hide visual
        Mango.Visuals.BoxFOV.Visible = false
    end
end
 
            local Ticks = {}
            local SGTick = tick()
            local function SilentAim(Tool)
                if shared.Story.SilentAim.Enabled and Tool:FindFirstChild("Ammo") then
                    if CurrentGame.Name == "Da Hood" then
                        if not Ticks[Tool.Name] then
                            Ticks[Tool.Name] = 0
                        end
                        local WeaponOffset = WeaponInfo.Offsets[Tool.Name]
                        local Gun = GetGunCategory()
                        local Check 
                        local ToolHandle = Tool:WaitForChild("Handle")
                        local LocalCharacter = Self.Character
            
                        local Cooldown
                        local NoClueWhatThisIs = game.PlaceId == 88976059384565 and {
                            ["Value"] = 5
                        } or Tool.Ammo
                        local Time = workspace:GetServerTimeNow()
            
                        local ToolEvent = Tool:WaitForChild("RemoteEvent", 2) or {
                            ["FireServer"] = function(_, _) end
                        }
            
                        --[[
                        local function GetSpread()
                            local Spread = 0.05
                            if Gun == "Shotgun" then
                                Spread = 0.05
                            elseif Gun == "Pistol" then
                                Spread = 0.05
                            elseif Gun == "Auto" then
                                Spread = 0.05
                            elseif Gun == "Burst" then
                                Spread = 0.05
                            elseif Gun == "Rifle" then
                                Spread = 0.05
                            elseif Gun == "SMG" then
                                Spread = 0.05
                            elseif Gun == "Sniper" then
                                Spread = 0.05
                            end
                            return Spread
                        end
                        ]]
            
                        Cooldown = Tool:WaitForChild("ShootingCooldown").Value
            
                        --[[
                        local function GetSpread()
                            local Spread = 0.05
                            if Gun == "Shotgun" then
                                Spread = 0.05
                            elseif Gun == "Pistol" then
                                Spread = 0.05
                            elseif Gun == "Auto" then
                                Spread = 0.05
                            elseif Gun == "Burst" then
                                Spread = 0.05
                            elseif Gun == "Rifle" then
                                Spread = 0.05
                            elseif Gun == "SMG" then
                                Spread = 0.05
                            elseif Gun == "Sniper" then
                                Spread = 0.05
                            end
                            return Spread
                        end
                        ]]
            
                        local function ShootFunc(GunType, SilentAim)
                            if GunType == "Shotgun" then
                                if tick() - Ticks[Tool.Name] >= Cooldown + WeaponInfo.Delays[Tool.Name] and (NoClueWhatThisIs.Value >= 1 and (not _G.GUN_COMBAT_TOGGLE and DaHood.CanShoot(Self.Character))) then
                                    Ticks[Tool.Name] = tick()
                                    ToolEvent:FireServer("Shoot")
                                    for _ = 1, 5 do
                                        local HitPosition = Mango.Locals.HitPosition 
                                        local SpreadX 
                                        local SpreadY
                                        local SpreadZ
            
                                        -- Default spread without Enhancements
                                        SpreadX = math.random() > 0.5 and math.random() * 0.05 or -math.random() * 0.05
                                        SpreadY = math.random() > 0.5 and math.random() * 0.1 or -math.random() * 0.1
                                        SpreadZ = math.random() > 0.5 and math.random() * 0.05 or -math.random() * 0.05
            
                                        -- Apply Spread Modification
                                        local spreadConfig = shared.Story['Spread Modification']
                                        if spreadConfig and spreadConfig.Enabled and spreadConfig.Guns then
                                            local spreadMultiplier = spreadConfig.Guns[Tool.Name]
                                            if spreadMultiplier ~= nil then
                                                SpreadX = SpreadX * spreadMultiplier
                                                SpreadY = SpreadY * spreadMultiplier
                                                SpreadZ = SpreadZ * spreadMultiplier
                                            end
                                        end
            
                                        local ForcedOrigin = Tool:FindFirstChild("Default") and (Tool.Default:FindFirstChild("Mesh") and Tool.Default.Mesh:FindFirstChild("Muzzle")) or {
                                            ["WorldPosition"] = (ToolHandle.CFrame * WeaponOffset).Position
                                        }
            
                                        local TotalSpread = Vector3.new(SpreadX, SpreadY, SpreadZ)
            
                                        local AimPosition
                                        local WeaponRange = Tool:WaitForChild("Range")
                                        if SilentAim and (Self.Character.HumanoidRootPart.Position - Mango.Locals.SilentAimTarget.Character.HumanoidRootPart.Position).Magnitude < WeaponRange.Value then
                                            AimPosition = ForcedOrigin.WorldPosition + ((HitPosition - ForcedOrigin.WorldPosition).Unit + TotalSpread) * WeaponRange.Value
                                        else
                                            AimPosition = ForcedOrigin.WorldPosition + (DaHood.GetAim(ForcedOrigin.WorldPosition) + TotalSpread) * WeaponRange.Value
                                        end
            
                                        local Arg0, Arg1, Arg2 = DaHood.ShootGun({
                                            ["Shooter"] = LocalCharacter,
                                            ["Handle"] = ToolHandle,
                                            ["AimPosition"] = AimPosition,
                                            ["BeamColor"] = Color3.new(1, 0.545098, 0.14902),
                                            ["ForcedOrigin"] = ForcedOrigin.WorldPosition,
                                            ["LegitPosition"] = ForcedOrigin.WorldPosition + (DaHood.GetAim(ForcedOrigin.WorldPosition) + TotalSpread) * WeaponRange.Value,
                                            ["Range"] = WeaponRange.Value
                                        })
                                        ReplicatedStorage.MainEvent:FireServer("ShootGun", ToolHandle, ForcedOrigin.WorldPosition, Arg0, Arg1, Arg2, Time)
                                    end
                                    ToolEvent:FireServer()
                                end
                            elseif Gun == "Pistol" then
                                if tick() - Ticks[Tool.Name] >= Cooldown + WeaponInfo.Delays[Tool.Name] and (NoClueWhatThisIs.Value >= 1 and (not _G.GUN_COMBAT_TOGGLE and DaHood.CanShoot(Self.Character))) then
                                    Ticks[Tool.Name] = tick()
                                    local HitPosition = Mango.Locals.HitPosition 
                                    -- Check Double Tap config
                                    local doubleTapConfig = shared.Story['Double Tap']
                                    local isDoubleTapGun = false
                                    if doubleTapConfig and doubleTapConfig.Enabled then
                                        for _, gunName in ipairs(doubleTapConfig.Guns or {}) do
                                            if Tool.Name == gunName then
                                                isDoubleTapGun = true
                                                break
                                            end
                                        end
                                    end
                                    if isDoubleTapGun then
                                        ToolEvent:FireServer("Shoot")
                                        Mango.Locals.DoubleTapState = true
                                        local AimPosition
                                        local ForcedOrigin = Tool:FindFirstChild("Default") and (Tool.Default:FindFirstChild("Mesh") and Tool.Default.Mesh:FindFirstChild("Muzzle")) or {
                                            ["WorldPosition"] = (ToolHandle.CFrame * WeaponOffset).Position
                                        }
            
                                        local WeaponRange = Tool:WaitForChild("Range")
                                        if SilentAim and Mango.Locals.SilentAimTarget and (Self.Character.HumanoidRootPart.Position - Mango.Locals.SilentAimTarget.Character.HumanoidRootPart.Position).Magnitude < WeaponRange.Value then
                                            AimPosition = HitPosition
                                        else
                                            AimPosition = ForcedOrigin.WorldPosition + DaHood.GetAim(ForcedOrigin.WorldPosition) * 200  
                                        end
                                        local Arg0, Arg1, Arg2 = DaHood.ShootGun({
                                            ["Shooter"] = LocalCharacter,
                                            ["Handle"] = ToolHandle,
                                            ["ForcedOrigin"] = ForcedOrigin.WorldPosition,
                                            ["AimPosition"] = AimPosition,
                                            ["BeamColor"] = Color3.new(1, 0.545098, 0.14902),
                                            ["LegitPosition"] = ForcedOrigin.WorldPosition + DaHood.GetAim(ForcedOrigin.WorldPosition) * 200,
                                            ["Range"] = WeaponRange.Value
                                        })
                                        ReplicatedStorage.MainEvent:FireServer("ShootGun", ToolHandle, ForcedOrigin.WorldPosition, Arg0, Arg1, Arg2)
                                        ToolEvent:FireServer()
                                        Mango.Locals.DoubleTapState = false
                                    end
                                    ToolEvent:FireServer("Shoot")
        
                                    local AimPosition
                                    local ForcedOrigin = Tool:FindFirstChild("Default") and (Tool.Default:FindFirstChild("Mesh") and Tool.Default.Mesh:FindFirstChild("Muzzle")) or {
                                        ["WorldPosition"] = (ToolHandle.CFrame * WeaponOffset).Position
                                    }
            
                                    local WeaponRange = Tool:WaitForChild("Range")
                                    if SilentAim and (Self.Character.HumanoidRootPart.Position - Mango.Locals.SilentAimTarget.Character.HumanoidRootPart.Position).Magnitude < WeaponRange.Value then
                                        AimPosition = HitPosition
                                    else
                                        AimPosition = ForcedOrigin.WorldPosition + DaHood.GetAim(ForcedOrigin.WorldPosition) * 200  
                                    end
                                    local WeaponRange = Tool:WaitForChild("Range")
            
                                    local Arg0, Arg1, Arg2 = DaHood.ShootGun({
                                        ["Shooter"] = LocalCharacter,
                                        ["Handle"] = ToolHandle,
                                        ["ForcedOrigin"] = (ForcedOrigin and ForcedOrigin.WorldPosition) or (ToolHandle.CFrame * WeaponOffset).Position,
                                        ["AimPosition"] = AimPosition,
                                        ["BeamColor"] = Color3.new(1, 0.545098, 0.14902),
                                        ["LegitPosition"] = (ForcedOrigin and ForcedOrigin.WorldPosition) or (ToolHandle.CFrame * WeaponOffset).Position + DaHood.GetAim((ForcedOrigin and ForcedOrigin.WorldPosition) or (ToolHandle.CFrame * WeaponOffset).Position) * 200,
                                        ["Range"] = WeaponRange.Value
                                    })
                                    ReplicatedStorage.MainEvent:FireServer("ShootGun", ToolHandle, ForcedOrigin.WorldPosition, Arg0, Arg1, Arg2)
                                    ToolEvent:FireServer()
                                end
                            elseif Gun == "Auto" then
                                if tick() - Ticks[Tool.Name] >= Cooldown + WeaponInfo.Delays[Tool.Name] and (not _G.GUN_COMBAT_TOGGLE and DaHood.CanShoot(LocalCharacter)) then
                                    Ticks[Tool.Name] = tick()
                                    ToolEvent:FireServer("Shoot")
                                    local Flag = true
                                    task.spawn(function()
                                        while Flag and (Tool.Parent == LocalCharacter and (NoClueWhatThisIs.Value > 0 and DaHood.CanShoot(LocalCharacter))) do
                                            local HitPosition = Mango.Locals.HitPosition 
                                            local CurrentTime = workspace:GetServerTimeNow()
                                            for _ = 1, 5 do
                                                local SpreadX 
                                                local SpreadY
                                                local SpreadZ
            
                                                -- Default spread without Enhancements
                                                SpreadX = math.random() > 0.5 and math.random() * 0.05 or -math.random() * 0.05
                                                SpreadY = math.random() > 0.5 and math.random() * 0.1 or -math.random() * 0.1
                                                SpreadZ = math.random() > 0.5 and math.random() * 0.05 or -math.random() * 0.05
            
                                                -- Apply Spread Modification
                                                local spreadConfig = shared.Story['Spread Modification']
                                                if spreadConfig and spreadConfig.Enabled and spreadConfig.Guns then
                                                    local spreadMultiplier = spreadConfig.Guns[Tool.Name]
                                                    if spreadMultiplier ~= nil then
                                                        SpreadX = SpreadX * spreadMultiplier
                                                        SpreadY = SpreadY * spreadMultiplier
                                                        SpreadZ = SpreadZ * spreadMultiplier
                                                    end
                                                end
            
                                                local ForcedOrigin = Tool:FindFirstChild("Default") and (Tool.Default:FindFirstChild("Mesh") and Tool.Default.Mesh:FindFirstChild("Muzzle")) or {
                                                    ["WorldPosition"] = (ToolHandle.CFrame * WeaponOffset).Position
                                                }
            
                                                local TotalSpread = Vector3.new(SpreadX, SpreadY, SpreadZ)
            
                                                local AimPosition
                                                local WeaponRange = Tool:WaitForChild("Range")
                                                if SilentAim and (Self.Character.HumanoidRootPart.Position - Mango.Locals.SilentAimTarget.Character.HumanoidRootPart.Position).Magnitude < WeaponRange.Value then
                                                    AimPosition = ForcedOrigin.WorldPosition + ((HitPosition - ForcedOrigin.WorldPosition).Unit + TotalSpread) * WeaponRange.Value
                                                else
                                                    AimPosition = ForcedOrigin.WorldPosition + (DaHood.GetAim(ForcedOrigin.WorldPosition) + TotalSpread) * WeaponRange.Value
                                                end
            
                                                local Arg0, Arg1, Arg2 = DaHood.ShootGun({
                                                    ["Shooter"] = LocalCharacter,
                                                    ["Handle"] = ToolHandle,
                                                    ["AimPosition"] = AimPosition,
                                                    ["BeamColor"] = Color3.new(1, 0.545098, 0.14902),
                                                    ["ForcedOrigin"] = ForcedOrigin.WorldPosition,
                                                    ["LegitPosition"] = ForcedOrigin.WorldPosition + (DaHood.GetAim(ForcedOrigin.WorldPosition) + TotalSpread) * WeaponRange.Value,
                                                    ["Range"] = WeaponRange.Value
                                                })
                                                ReplicatedStorage.MainEvent:FireServer("ShootGun", ToolHandle, ForcedOrigin.WorldPosition, Arg0, Arg1, Arg2, CurrentTime)
                                            end
                                            task.wait(Cooldown + 0.0095)
                                            Ticks[Tool.Name] = tick()
                                        end
                                        ToolEvent:FireServer()
                                    end)
                                    Tool.Deactivated:Wait()
                                    Flag = false
                                end
                            elseif Gun == "Burst" then
                                local Tolerance = Tool:WaitForChild("ToleranceCooldown").Value
                                local ShootingCool = Tool:WaitForChild("ShootingCooldown").Value
                                if tick() - Ticks[Tool.Name] >= Tolerance and (not _G.GUN_COMBAT_TOGGLE and DaHood.CanShoot(LocalCharacter)) then
                                    Ticks[Tool.Name] = tick()
                                    ToolEvent:FireServer("Shoot")
                                    workspace:GetServerTimeNow()
                                    task.spawn(function()
                                        for _ = 1, NoClueWhatThisIs.Value > 3 and 3 or NoClueWhatThisIs.Value do
                                            local HitPosition = Mango.Locals.HitPosition 
                                            local v17
                                            local ForcedOrigin = Tool:FindFirstChild("Default") and (Tool.Default:FindFirstChild("Mesh") and Tool.Default.Mesh:FindFirstChild("Muzzle")) or {
                                                ["WorldPosition"] = (ToolHandle.CFrame * WeaponOffset).Position
                                            }
            
                                            local WeaponRange = Tool:WaitForChild("Range")
                                            if SilentAim and (Self.Character.HumanoidRootPart.Position - Mango.Locals.SilentAimTarget.Character.HumanoidRootPart.Position).Magnitude < WeaponRange.Value then
                                                v17 = ForcedOrigin.WorldPosition + ((HitPosition - ForcedOrigin.WorldPosition).Unit) * 200
                                                --v17 = ForcedOrigin.WorldPosition + DaHood.GetAim(ForcedOrigin.WorldPosition) * 200
                                            else
                                                v17 = ForcedOrigin.WorldPosition + DaHood.GetAim(ForcedOrigin.WorldPosition) * 200
                                            end
                                            local v18, v19, v20 = DaHood.ShootGun({
                                                ["Shooter"] = LocalCharacter,
                                                ["Handle"] = ToolHandle,
                                                ["ForcedOrigin"] = ForcedOrigin.WorldPosition,
                                                ["AimPosition"] = v17,
                                                ["LegitPosition"] = ForcedOrigin.WorldPosition + DaHood.GetAim(ForcedOrigin.WorldPosition) * 200,
                                                ["BeamColor"] = Color3.new(1, 0.545098, 0.14902),
                                                ["Range"] = WeaponRange.Value
                                            })
                                            ReplicatedStorage.MainEvent:FireServer("ShootGun", ToolHandle, ForcedOrigin.WorldPosition, v18, v19, v20)
                                            task.wait(ShootingCool + 0.0095)
                                        end
                                        ToolEvent:FireServer()
                                    end)
                                end
                            elseif Gun == "Rifle" or GunType == "SMG" then
                                local ShootingCool = Tool:WaitForChild("ShootingCooldown").Value
                                if tick() - Ticks[Tool.Name] >= Cooldown + WeaponInfo.Delays[Tool.Name] and (not _G.GUN_COMBAT_TOGGLE and DaHood.CanShoot(LocalCharacter)) then
                                    Ticks[Tool.Name] = tick()
                                    ToolEvent:FireServer("Shoot")
                                    local Flag = true
                                    task.spawn(function()
                                        while task.wait(ShootingCool + 0.0095) and (Flag and (Tool.Parent == LocalCharacter and (NoClueWhatThisIs.Value > 0 and DaHood.CanShoot(LocalCharacter)))) do
                                            local HitPosition = Mango.Locals.HitPosition 
                                            local ForcedOrigin = Tool:FindFirstChild("Default") and (Tool.Default:FindFirstChild("Mesh") and Tool.Default.Mesh:FindFirstChild("Muzzle")) or {
                                                ["WorldPosition"] = (ToolHandle.CFrame * WeaponOffset).Position
                                            }
            
                                            local AimPosition
                                            local WeaponRange = Tool:WaitForChild("Range")
                                            if SilentAim and (Self.Character.HumanoidRootPart.Position - Mango.Locals.SilentAimTarget.Character.HumanoidRootPart.Position).Magnitude < WeaponRange.Value then
                                                AimPosition =  ForcedOrigin.WorldPosition + ((HitPosition - ForcedOrigin.WorldPosition).Unit) * 200
                                            else
                                                AimPosition = ForcedOrigin.WorldPosition + DaHood.GetAim(ForcedOrigin.WorldPosition) * 200
                                            end
            
                                            local WeaponRange = Tool:WaitForChild("Range")
            
                                            local v18, v19, v20 = DaHood.ShootGun({
                                                ["Shooter"] = LocalCharacter,
                                                ["Handle"] = ToolHandle,
                                                ["ForcedOrigin"] = ForcedOrigin.WorldPosition,
                                                ["AimPosition"] = AimPosition,
                                                ["LegitPosition"] = ForcedOrigin.WorldPosition + DaHood.GetAim(ForcedOrigin.WorldPosition) * 200,
                                                ["BeamColor"] = Color3.new(1, 0.545098, 0.14902),
                                                ["Range"] = WeaponRange.Value
                                            })
                                            ReplicatedStorage.MainEvent:FireServer("ShootGun", ToolHandle, ForcedOrigin.WorldPosition, v18, v19, v20)
                                            Ticks[Tool.Name] = tick()
                                        end
                                        ToolEvent:FireServer()
                                    end)
                                    Tool.Deactivated:Wait()
                                    Flag = false
                                end
                            elseif Gun == "Sniper" then
                                if tick() - Ticks[Tool.Name] >= Cooldown + WeaponInfo.Delays[Tool.Name] and (not _G.GUN_COMBAT_TOGGLE and DaHood.CanShoot(LocalCharacter)) then
                                    Ticks[Tool.Name] = tick()
                                    ToolEvent:FireServer("Shoot")
                                    local HitPosition = Mango.Locals.HitPosition 
                                    local ForcedOrigin = Tool:FindFirstChild("Default") and (Tool.Default:FindFirstChild("Mesh") and Tool.Default.Mesh:FindFirstChild("Muzzle")) or {
                                        ["WorldPosition"] = (ToolHandle.CFrame * WeaponOffset).Position
                                    }
            
                                    local AimPosition
                                    local WeaponRange = Tool:WaitForChild("Range")
                                    if SilentAim and (Self.Character.HumanoidRootPart.Position - Mango.Locals.SilentAimTarget.Character.HumanoidRootPart.Position).Magnitude < WeaponRange.Value then
                                        AimPosition =  ForcedOrigin.WorldPosition + ((HitPosition - ForcedOrigin.WorldPosition).Unit) * 50
                                    else
                                        AimPosition = ForcedOrigin.WorldPosition + DaHood.GetAim(ForcedOrigin.WorldPosition) * 50
                                    end
            
                                    local v16, v17, v18 = DaHood.ShootGun({
                                        ["Shooter"] = LocalCharacter,
                                        ["Handle"] = ToolHandle,
                                        ["ForcedOrigin"] = ForcedOrigin.WorldPosition,
                                        ["AimPosition"] = AimPosition,
                                        ["LegitPosition"] = ForcedOrigin.WorldPosition + DaHood.GetAim(ForcedOrigin.WorldPosition) * 50,
                                        ["BeamColor"] = Color3.new(1, 0.545098, 0.14902),
                                        ["Range"] = WeaponRange.Value
                                    })
                                    ReplicatedStorage.MainEvent:FireServer("ShootGun", ToolHandle, ForcedOrigin.WorldPosition, v16, v17, v18)
                                    ToolEvent:FireServer()
                                end
                            end
                        end
 
                        local function shouldShoot(target)
                            local allConditionsPassed = true
                            -- Get current mode and checks
                            local selectionMode = shared.Story.Selection['Selection Mode'] or 'Auto'
                            local conditions = shared.Story.Selection.Checks[selectionMode] or shared.Story.Selection.Checks.Auto
            
                            if conditions.Test and not Engine.RayCast(target.HumanoidRootPart, Player.GetOrigin('Camera'), {Self.Character}) then
                                allConditionsPassed = false
                            end
            
                            if conditions.Forcefield and target:FindFirstChild("ForceField") then
                                allConditionsPassed = false
                            end
            
                            if conditions.Knocked and Player.IsKnocked(target) then
                                allConditionsPassed = false
                            end
        
                            if conditions.SelfKnocked and Player.IsKnocked(Self.Character) then
                                allConditionsPassed = false
                            end
            
                            if conditions.Grabbed and Player.IsGrabbed(target) then
                                allConditionsPassed = false
                            end
            
                            
                            local screen, _ = Camera:WorldToViewportPoint(Mango.Locals.HitPosition)
                            
                            --[[
                            local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                            local magnitude = (Vector2.new(screen.X, screen.Y) - mousePos).Magnitude
                            
                            if magnitude > fov then
                                allConditionsPassed = false
                            end
                            ]]
        
                            local DistanceX = math.abs(screen.X - Mouse.X)
                            local DistanceY = math.abs(screen.Y - Mouse.Y)
                            -- Always use Circle FOV
                            local fovSize = shared.Story.Fov and shared.Story.Fov.Size or 150
                            local DistanceFromCenterSq = DistanceX^2 + DistanceY^2
                            
                            -- Check if target is within FOV circle (distance from mouse cursor)
                            if DistanceFromCenterSq > fovSize^2 then
                                allConditionsPassed = false
                            end
        
                            return allConditionsPassed
                        end
                        
                        if Mango.Locals.SilentAimTarget and Mango.Locals.SilentAimTarget.Character then
                            local target = Mango.Locals.SilentAimTarget.Character
                            ShootFunc(Gun, shouldShoot(target))
                        else
                            ShootFunc(Gun, false)
                        end
                    else
                        local function shouldShoot(target)
                            local allConditionsPassed = true
                            -- Get current mode and checks
                            local selectionMode = shared.Story.Selection['Selection Mode'] or 'Auto'
                            local conditions = shared.Story.Selection.Checks[selectionMode] or shared.Story.Selection.Checks.Auto
            
                            if conditions.Test and not Engine.RayCast(target.HumanoidRootPart, Player.GetOrigin('Camera'), {Self.Character}) then
                                allConditionsPassed = false
                            end
            
                            if conditions.Forcefield and target:FindFirstChild("ForceField") then
                                allConditionsPassed = false
                            end
            
                            if conditions.Knocked and Player.IsKnocked(target) then
                                allConditionsPassed = false
                            end
        
                            if conditions.SelfKnocked and Player.IsKnocked(Self.Character) then
                                allConditionsPassed = false
                            end
            
                            if conditions.Grabbed and Player.IsGrabbed(target) then
                                allConditionsPassed = false
                            end
                        
                            
                            local screen, _ = Camera:WorldToViewportPoint(Mango.Locals.HitPosition)
                            --[[
                            local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                            local magnitude = (Vector2.new(screen.X, screen.Y) - mousePos).Magnitude
                            
                            if magnitude > fov then
                                allConditionsPassed = false
                            end
                            ]]
        
                            local DistanceX = math.abs(screen.X - Mouse.X)
                            local DistanceY = math.abs(screen.Y - Mouse.Y)
                            -- Always use Circle FOV
                            local fovSize = shared.Story.Fov and shared.Story.Fov.Size or 150
                            local DistanceFromCenterSq = DistanceX^2 + DistanceY^2
                            
                            -- Check if target is within FOV circle (distance from mouse cursor)
                            if DistanceFromCenterSq > fovSize^2 then
                                allConditionsPassed = false
                            end
        
                            return allConditionsPassed
                        end
 
                        if Mango.Locals.SilentAimTarget and Mango.Locals.SilentAimTarget.Character then
                            local target = Mango.Locals.SilentAimTarget.Character
                            
                            -- Try to use CurrentGame if available, otherwise use fallback
                            local Updater = CurrentGame and CurrentGame.Updater or "UpdateMousePosI2"
                            local Remote = CurrentGame and CurrentGame.Functions.RemotePath() or game.ReplicatedStorage.MainEvent
                            
                            if Updater and Remote and shouldShoot(target) then
                                -- Use standard Da Hood format
                                local Send = {
                                    [1] = Updater,
                                    [2] = Mango.Locals.HitPosition
                                }
                                Remote:FireServer(unpack(Send))
                            end
                        end
 
                    end
                end                    
            end
    
            local function ActivateTool()
                local Tool = Self.Character:FindFirstChildOfClass("Tool")
                if Tool ~= nil and Tool:IsDescendantOf(Self.Character) then 
                    Tool:Activate()
                end 
            end     
            
            local function CheckMagnitudeFromMouse(Position, HitScan)
                local Resume = true                         --GuiInsetOffsetY
                local MagnitudeY = (Vector2.new(0, Mouse.Y + 35)-Vector2.new(0, Position.Y)).Magnitude
                local MagnitudeX = (Vector2.new(Mouse.X, 0)-Vector2.new(Position.X, 0)).Magnitude
            
                if (MagnitudeX > HitScan.X or MagnitudeY > HitScan.Y) then 
                    Resume = false
                end 
            
                return Resume
            end
    
 
 
 
--[[
local function CamlockChecksPassed()
    local checks = shared.Story.Camlock.Checks
    local camera = workspace.CurrentCamera
    local rightClickHeld = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
 
    -- zoom distance between camera and its focus
    local zoomDistance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
    local isFirstPerson = zoomDistance < 1
    local isThirdPerson = zoomDistance >= 1
 
    -- Apply checks
    local firstPersonOk = (not checks["First Person"]) or (checks["First Person"] and isFirstPerson)
    local thirdPersonOk = (not checks["Third Person"]) or (checks["Third Person"] and isThirdPerson)
    local rightClickOk = (not checks["Right Clicking"]) or (checks["Right Clicking"] and rightClickHeld)
    return firstPersonOk and thirdPersonOk and rightClickOk
end
]]--
 
local function IsPriority(Player)
    for _, Client in ipairs(Environment.Priority) do
        if Client == Player then
            return true
        end
    end
    return false
end
--
local function AddPriority(Player)
    if not IsPriority(Player) then
        table.insert(Environment.Priority, Player)
    end
end
--
local function RemovePriority(Player)
    for i, p in ipairs(Environment.Priority) do
        if p == Player then
            table.remove(Environment.Priority, i)
            return
        end
    end
end
--
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
--
local function SelectPriority()
    local ClosestPlayer = nil
    local ClosestDistance = math.huge
    local SelectionRadius = 100
    
    -- Get current mode and checks
    local selectionMode = shared.Story.Selection['Selection Mode'] or 'Auto'
    local checks = shared.Story.Selection.Checks[selectionMode] or shared.Story.Selection.Checks.Auto
 
    for _, PossiblePriority in pairs(Players:GetPlayers()) do
        if PossiblePriority == LocalPlayer then continue end 
    
        local Character = PossiblePriority.Character
        local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
                end
                return false
            end
            --
            local function AddPriority(Player)
                if not IsPriority(Player) then
                    table.insert(Environment.Priority, Player)
                end
            end
            --
            local function RemovePriority(Player)
                for i, p in ipairs(Environment.Priority) do
                    if p == Player then
                        table.remove(Environment.Priority, i)
                        return
                    end
                end
            end
            --
            local Players = game:GetService("Players")
            local Workspace = game:GetService("Workspace")
            local Camera = Workspace.CurrentCamera
            local LocalPlayer = Players.LocalPlayer
            local Mouse = LocalPlayer:GetMouse()
            
            local function SelectPriority()
                local ClosestPlayer = nil
                local ClosestDistance = math.huge
                local SelectionRadius = 100
                
                -- Get current mode and checks
                local selectionMode = shared.Story.Selection['Selection Mode'] or 'Auto'
                local checks = shared.Story.Selection.Checks[selectionMode] or shared.Story.Selection.Checks.Auto
            
                for _, PossiblePriority in pairs(Players:GetPlayers()) do
                    if PossiblePriority == LocalPlayer then continue end 
            
                    local Character = PossiblePriority.Character
                    local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
            
                    if RootPart and Character:IsDescendantOf(Workspace) then
 
                        if checks.Test then
                            if not Engine.RayCast(RootPart, Player.GetOrigin('Camera'), {LocalPlayer.Character}) then
                                continue
                            end
                        end
                
                        -- Forcefield Check
                        if checks.Forcefield then
                            if Character:FindFirstChild("ForceField") then
                                continue
                            end
                        end
                
                        -- Knocked Check
                        if checks.Knocked then
                            if Player.IsKnocked(Character) then
                                continue
                            end
                        end
                
                        -- Grabbed Check
                        if checks.Grabbed then
                            if Player.IsGrabbed(Character) then
                                continue
                            end
                        end
 
                        local WorldPos, onScreen = Camera:WorldToViewportPoint(RootPart.Position)
                        if onScreen then
                            local Distance = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(WorldPos.X, WorldPos.Y)).Magnitude
                            if Distance < ClosestDistance and Distance < SelectionRadius then
                                ClosestDistance = Distance
                                ClosestPlayer = PossiblePriority
                            end
                        end
                    end
                end
            
                if ClosestPlayer then
                    if IsPriority(ClosestPlayer) then
                        RemovePriority(ClosestPlayer)
                    else
                        AddPriority(ClosestPlayer)
                    end
                end
            end
                  
            --        
            local function ClearPriority()
                Environment.Priority = {}
            end
 
            local function Clean(tbl)
                for player, element in pairs(tbl) do
                    if not IsPriority(player) or not player.Parent then 
                        element:Remove()
                        tbl[player] = nil
                    end
                end
            end            
 
            local function IsFriendly(Player)
                if Player:IsFriendsWith(Self.UserId) then
                    return false
                else
                    return true
                end
            end
 
            --[[
                        local function DrawESP()
                local Script = shared["F​F​l​a​g​A​X​C​o​m​b​i​n​e​G​e​t​O​u​t​f​i​t​D​i​s​p​a​t​c​h​e​s​I​X​P​2"]
                local RAID_Enabled = Script["Raid Awareness"].Enabled
                local Priority = Environment.Priority
                local CanDraw = true
                --
                if RAID_Enabled then
                    for i = #Priority, 1, -1 do
                        local Player = Priority[i]
                        if not Player or not Player.Character then
                            Lithium:ClearPlayerData(Player)
                        else
                            local RootPart = Player.Character and Player.Character:FindFirstChild('HumanoidRootPart')
                            if not RootPart then
                                return
                            end
                            --
                            if not Client or not Client.Character then
                                return
                            end
                            --
                            local Distance = Client.Character.HumanoidRootPart and (RootPart.Position - Client.Character.HumanoidRootPart.Position).Magnitude or 0
                            local Position, Visible = Camera:WorldToViewportPoint(RootPart.Position)
                            local CharacterSize = (Camera:WorldToViewportPoint(RootPart.Position - Vector3new(0, 3, 0)).Y -
                                                   Camera:WorldToViewportPoint(RootPart.Position + Vector3new(0, 2.6, 0)).Y) / 2
                            
                            local Flag = not Lithium:IsFriendly(Player) and getgenv().Script.Visuals['Specific ESP'].AllyColor or getgenv().Script.Visuals['Specific ESP'].EnemyColor
                            local Box = true
                            if Box then
                                if not Table.Corners[Player] then
                                    Table.Corners[Player] = {}
                                    for i = 1, 8 do
                                        Table.Corners[Player][i] = Overlay.new('Line')
                                        Table.Corners[Player][i].Thickness = 1
                                        Table.Corners[Player][i].Transparency = 1
                                        Table.Corners[Player][i].Color = Flag
                                    end
                                end
                                local BoxWidth = Floor(CharacterSize * 1.1)
                                local BoxHeight = Floor(CharacterSize * 1.9)
                                local BoxPosition = Vector2new(Position.X - BoxWidth / 2, Position.Y - BoxHeight / 2)
            
                                local L_Width = (BoxWidth / 5)
                                local L_Height = (BoxHeight / 6)
                                local L_T = 2
            
                                -- Top left
                                Table.Corners[Player][1].From = Vector2new(BoxPosition.X - L_T, BoxPosition.Y - L_T)
                                Table.Corners[Player][1].To = Vector2new(BoxPosition.X + L_Width, BoxPosition.Y - L_T)
            
                                Table.Corners[Player][2].From = Vector2new(BoxPosition.X - L_T, BoxPosition.Y - L_T)
                                Table.Corners[Player][2].To = Vector2new(BoxPosition.X - L_T, BoxPosition.Y + L_Height)
            
                                -- Top right
                                Table.Corners[Player][3].From = Vector2new(BoxPosition.X + BoxWidth - L_Width, BoxPosition.Y - L_T)
                                Table.Corners[Player][3].To = Vector2new(BoxPosition.X + BoxWidth + L_T, BoxPosition.Y - L_T)
            
                                Table.Corners[Player][4].From = Vector2new(BoxPosition.X + BoxWidth + L_T, BoxPosition.Y - L_T)
                                Table.Corners[Player][4].To = Vector2new(BoxPosition.X + BoxWidth + L_T, BoxPosition.Y + L_Height)
            
                                -- Bottom left
                                Table.Corners[Player][5].From = Vector2new(BoxPosition.X - L_T, BoxPosition.Y + BoxHeight - L_Height)
                                Table.Corners[Player][5].To = Vector2new(BoxPosition.X - L_T, BoxPosition.Y + BoxHeight + L_T)
            
                                Table.Corners[Player][6].From = Vector2new(BoxPosition.X - L_T, BoxPosition.Y + BoxHeight + L_T)
                                Table.Corners[Player][6].To = Vector2new(BoxPosition.X + L_Width, BoxPosition.Y + BoxHeight + L_T)
            
                                -- Bottom right
                                Table.Corners[Player][7].From = Vector2new(BoxPosition.X + BoxWidth - L_Width, BoxPosition.Y + BoxHeight + L_T)
                                Table.Corners[Player][7].To = Vector2new(BoxPosition.X + BoxWidth + L_T, BoxPosition.Y + BoxHeight + L_T)
            
                                Table.Corners[Player][8].From = Vector2new(BoxPosition.X + BoxWidth + L_T, BoxPosition.Y + BoxHeight + L_T)
                                Table.Corners[Player][8].To = Vector2new(BoxPosition.X + BoxWidth + L_T, BoxPosition.Y + BoxHeight - L_Height)
            
                                for _, Line in ipairs(Table.Corners[Player]) do
                                    Line.Visible = CanDraw and Visible
                                    Line.Color = Flag
                                    Line.Transparency = getgenv().Script.Visuals['Specific ESP'].Transparency
                                    Line.Thickness = getgenv().Script.Visuals['Specific ESP'].Thickness
                                end
                            end
                            --
                            if Modules.Name.Visible then
                                local Text = Table.Texts[Player]
                                if not Text then
                                    Text = Overlay.new('Text')
                                    Text.Size = Modules.Name.Size
                                    Text.Outline = Modules.Name.Outline
                                    Text.OutlineColor = Modules.Name.OutlineColor
                                    Text.Color = Flag
                                    Text.Center = true
                                    Text.Transparency = Modules.Name.Transparency
                                    Table.Texts[Player] = Text
                                end
                                local boxSize = Vector2new(Floor(CharacterSize * 1.8), Floor(CharacterSize * 1.9))
                                local boxPosition = Vector2new(Floor(Position.X - CharacterSize * 1.8 / 2), Floor(Position.Y - CharacterSize * 1.6 / 2))
                                   
                                Text.Visible = CanDraw and Visible or false
                                Text.Text = Player.DisplayName
                                Text.Position = Vector2new(boxPosition.X + boxSize.X / 2, boxPosition.Y + boxSize.Y + 5)
                            end
                            --
                            if Modules.Distance.Visible then
                                local Text = Table.Distance[Player]
                                if not Text then
                                    Text = Overlay.new('Text')
                                    Text.Size = Modules.Distance.Size
                                    Text.Outline = Modules.Distance.Outline
                                    Text.OutlineColor = Modules.Distance.OutlineColor
                                    Text.Color = Flag
                                    Text.Center = true
                                    Text.Transparency = Modules.Distance.Transparency
                                    Table.Distance[Player] = Text
                                end
                                local boxSize = Vector2new(Floor(CharacterSize * 1.8), Floor(CharacterSize * 1.9))
                                local boxPosition = Vector2new(Floor(Position.X - CharacterSize * 1.8 / 2), Floor(Position.Y - CharacterSize * 1.6 / 2))
                                   
                                Text.Visible = CanDraw and Visible or false
                                Text.Text = tostring(Floor(Distance)) .. ' std'
                                Text.Position = Vector2new(boxPosition.X + boxSize.X / 2, boxPosition.Y + boxSize.Y + 15)
                            end
                        end
                    end
                else
                    for _, lines in pairs(Table.Corners) do
                        for _, Line in ipairs(lines) do
                            Line:Remove()
                        end
                    end
                    for _, lines in pairs(Table.Outlines) do
                        for _, Line in ipairs(lines) do
                            Line:Remove()
                        end
                    end
                    Table.Outlines = {}
                    Table.Corners = {}
                    Table.Distance = {}
                    Table.Texts = {}
                    Raid.Players = {}
                end
            end]]
 
    
            
    
            return {
                UpdateBox = UpdateBox,
                SilentAim = SilentAim,
                GetGunCategory = GetGunCategory,
                SelectPriority = SelectPriority,
                ClearPriority = ClearPriority
            }
        end
    end
end)()
--
local Main = Modules.Get("Main")
local Player = Modules.Get("Player")
local Utility = Modules.Get("Utility")
local ScreenGui = Modules.Get("ScreenGui")
-- SP is already declared at top of script (always true for Auto mode)
local SP2 = false
local TriggerbotActive = false
local LastTriggerbotShot = 0
local DoubleTap = false
local SpeedEnabled = false
 
-- Aim Assist Camera Function
local function AimAssistCamera()
    if not shared.Story['Aim Assist'].Enabled then return end
    if not Mango.Locals.AimAssistTarget then return end
    if not Mango.Locals.AimAssistTarget.Character then return end
    
    local Target = Mango.Locals.AimAssistTarget
    local TargetChar = Target.Character
    
    local checks = shared.Story.Selection.Checks.Target
    if checks.Knocked and Player.IsKnocked(TargetChar) then return end
    if checks.Grabbed and Player.IsGrabbed(TargetChar) then return end
    
    local TargetPart = Player.GetClosestPartToCursorAimAssist(TargetChar)
    if not TargetPart then return end
    
    local screenPos = Camera:WorldToViewportPoint(TargetPart.Position)
    local mousePos = UserInputService:GetMouseLocation()
    local distanceFromMouse = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
    local fovSize = shared.Story.Fov and shared.Story.Fov.Size or 150
    
    if distanceFromMouse > fovSize then return end
    
    local HitPosition = Player.GetHitPosition("Assist")
    if HitPosition == Vector3.new(0, 0, 0) then return end
    
    local TargetCFrame = CFrame.new(Camera.CFrame.Position, HitPosition)
    local Smoothing = shared.Story['Aim Assist'].Smoothing or 0.5
    Smoothing = math.clamp(Smoothing, 0.01, 0.99)
    
    Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, Smoothing)
end
 
--// Connections
do
    ScreenGui.Setup()
    Utility.Connection(UserInputService.InputBegan, function(Input, Processed)
       -- Check if typing in text box
       if UserInputService:GetFocusedTextBox() then return end
 
local SilentAimKey = Enum.KeyCode[(shared.Story.Binds['Silent Aim'] or 'C'):upper()]
local SelectionMode = shared.Story.Selection['Selection Mode'] or 'Auto'
local SilentAimMode = shared.Story.SilentAim.Mode or 'Toggle'
 
-- Silent Aim Keybind - Handle both Toggle and Hold modes
if Input.KeyCode == SilentAimKey then
    if SelectionMode == "Target" then
        if SilentAimMode == 'Hold' then
            -- Hold mode: Lock while key is held
            if not Mango.Locals.SilentAimTarget then
                local locked = Player.GetClosestPlayerToCursor()
                if locked then
                    local checks = shared.Story.Selection.Checks.Target
                    local char = locked.Character
                    local isKnocked = char and char:FindFirstChild('BodyEffects') and char.BodyEffects:FindFirstChild('K.O') and char.BodyEffects['K.O'].Value
                    local isGrabbed = char and char:FindFirstChild('GRABBING_CONSTRAINT') ~= nil
                    
                    local canLock = true
                    if checks.Knocked and isKnocked then canLock = false end
                    if checks.Grabbed and isGrabbed then canLock = false end
                    
                    if canLock then
                        Mango.Locals.LockedTarget = locked
                        Mango.Locals.SilentAimTarget = locked
                    end
                end
            end
        else
            -- Toggle mode: Toggle lock on key press
            if not Mango.Locals.SilentAimTarget then
                local locked = Player.GetClosestPlayerToCursor()
                if locked then
                    local checks = shared.Story.Selection.Checks.Target
                    local char = locked.Character
                    local isKnocked = char and char:FindFirstChild('BodyEffects') and char.BodyEffects:FindFirstChild('K.O') and char.BodyEffects['K.O'].Value
                    local isGrabbed = char and char:FindFirstChild('GRABBING_CONSTRAINT') ~= nil
                    
                    local canLock = true
                    if checks.Knocked and isKnocked then canLock = false end
                    if checks.Grabbed and isGrabbed then canLock = false end
                    
                    if canLock then
                        Mango.Locals.LockedTarget = locked
                        Mango.Locals.SilentAimTarget = locked
                    end
                end
            else
                Mango.Locals.LockedTarget = nil
                Mango.Locals.SilentAimTarget = nil
            end
        end
    else
        -- Auto mode: Always ON, no toggle
        -- SP remains true, auto targeting is always active
    end
end
 
    -- Get keybinds from Binds table
    local AimAssistKey = Enum.KeyCode[(shared.Story.Binds['Aim Assist'] or 'X'):upper()]
    local TriggerbotKey = Enum.KeyCode[(shared.Story.Binds.Triggerbot or 'V'):upper()]
    local ESPKey = Enum.KeyCode[(shared.Story.Binds.ESP or 'Y'):upper()]
    local SpeedKey = Enum.KeyCode[(shared.Story.Binds.Speed or 'Z'):upper()]
 
    -- Aim Assist Keybind - Toggle/Hold lock on/off
    if Input.KeyCode == AimAssistKey then
        local AimAssistMode = shared.Story['Aim Assist'].Mode or 'Toggle'
        
        if AimAssistMode == 'Hold' then
            -- Hold mode: Lock while key is held
            if not Mango.Locals.AimAssistTarget then
                local locked = Player.GetClosestPlayerToCursor()
                if locked then
                    local checks = shared.Story.Selection.Checks.Target
                    local char = locked.Character
                    local isKnocked = char and char:FindFirstChild('BodyEffects') and char.BodyEffects:FindFirstChild('K.O') and char.BodyEffects['K.O'].Value
                    local isGrabbed = char and char:FindFirstChild('GRABBING_CONSTRAINT') ~= nil
                    
                    local canLock = true
                    if checks.Knocked and isKnocked then canLock = false end
                    if checks.Grabbed and isGrabbed then canLock = false end
                    
                    if canLock then
                        Mango.Locals.AimAssistTarget = locked
                    end
                end
            end
        else
            -- Toggle mode: Toggle lock on key press
            if not Mango.Locals.AimAssistTarget then
                local locked = Player.GetClosestPlayerToCursor()
                if locked then
                    local checks = shared.Story.Selection.Checks.Target
                    local char = locked.Character
                    local isKnocked = char and char:FindFirstChild('BodyEffects') and char.BodyEffects:FindFirstChild('K.O') and char.BodyEffects['K.O'].Value
                    local isGrabbed = char and char:FindFirstChild('GRABBING_CONSTRAINT') ~= nil
                    
                    local canLock = true
                    if checks.Knocked and isKnocked then canLock = false end
                    if checks.Grabbed and isGrabbed then canLock = false end
                    
                    if canLock then
                        Mango.Locals.AimAssistTarget = locked
                    end
                end
            else
                Mango.Locals.AimAssistTarget = nil
            end
        end
    end
 
    -- Triggerbot Keybind - Toggle/Hold
    if Input.KeyCode == TriggerbotKey then
        local TriggerbotMode = shared.Story.Triggerbot.Mode or 'Hold'
        if TriggerbotMode == 'Toggle' then
            TriggerbotActive = not TriggerbotActive
        else
            TriggerbotActive = true
        end
    end
 
    -- ESP Keybind - Toggle lock on/off
    if Input.KeyCode == ESPKey then
        -- ESP logic
    end
 
    -- Speed Keybind - Toggle speed modification on/off
    if Input.KeyCode == SpeedKey then
        SpeedEnabled = not SpeedEnabled
    end
end)
    
    -- Handle key release for Hold mode
    Utility.Connection(UserInputService.InputEnded, function(Input, Processed)
        if UserInputService:GetFocusedTextBox() then return end
        
        local SilentAimKey = Enum.KeyCode[(shared.Story.Binds['Silent Aim'] or 'C'):upper()]
        local SelectionMode = shared.Story.Selection['Selection Mode'] or 'Auto'
        local SilentAimMode = shared.Story.SilentAim.Mode or 'Toggle'
        
        -- In Hold mode, unlock target when key is released
        if Input.KeyCode == SilentAimKey and SelectionMode == "Target" and SilentAimMode == 'Hold' then
            Mango.Locals.LockedTarget = nil
            Mango.Locals.SilentAimTarget = nil
        end
        
        -- Aim Assist Hold mode release
        local AimAssistKey = Enum.KeyCode[(shared.Story.Binds['Aim Assist'] or 'X'):upper()]
        local AimAssistMode = shared.Story['Aim Assist'].Mode or 'Toggle'
        if Input.KeyCode == AimAssistKey and AimAssistMode == 'Hold' then
            Mango.Locals.AimAssistTarget = nil
        end
        
        -- Triggerbot Hold mode release
        local TriggerbotKey = Enum.KeyCode[(shared.Story.Binds.Triggerbot or 'V'):upper()]
        local TriggerbotMode = shared.Story.Triggerbot.Mode or 'Hold'
        if Input.KeyCode == TriggerbotKey and TriggerbotMode == 'Hold' then
            TriggerbotActive = false
        end
    end)
    -- Triggerbot Logic - Shoot when cursor is directly ON a person
    Utility.ThreadLoop(0, function()
        if shared.Story.Triggerbot.Enabled and TriggerbotActive then
            local delay = shared.Story.Triggerbot.Delay or 0.01
            
            -- Check if we can shoot (delay)
            if tick() - LastTriggerbotShot < delay then return end
            
            -- Raycast from camera through mouse position to find what cursor is pointing at
            local mousePos = UserInputService:GetMouseLocation()
            local ray = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            raycastParams.FilterDescendantsInstances = {Self.Character}
            
            local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
            
            if result then
                local hitPart = result.Instance
                local hitModel = hitPart:FindFirstAncestorOfClass('Model')
                
                -- Check if we hit a player character
                if hitModel then
                    local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
                    if hitPlayer and hitPlayer ~= Self then
                        local char = hitModel
                        local checks = shared.Story.Selection.Checks.Auto
                        local isKnocked = char:FindFirstChild('BodyEffects') and char.BodyEffects:FindFirstChild('K.O') and char.BodyEffects['K.O'].Value
                        local isGrabbed = char:FindFirstChild('GRABBING_CONSTRAINT') ~= nil
                        
                        -- Skip if knocked/grabbed (if checks enabled)
                        if checks.Knocked and isKnocked then return end
                        if checks.Grabbed and isGrabbed then return end
                        
                        -- Distance Check for Triggerbot
                        local distanceConfig = shared.Story['Distance Check']
                        if distanceConfig and distanceConfig.Enabled then
                            local maxDistance = distanceConfig['Max Distance'] or 300
                            local targetHRP = char:FindFirstChild('HumanoidRootPart')
                            local selfHRP = Self.Character and Self.Character:FindFirstChild('HumanoidRootPart')
                            if targetHRP and selfHRP then
                                local playerDistance = (selfHRP.Position - targetHRP.Position).Magnitude
                                if playerDistance > maxDistance then
                                    return
                                end
                            end
                        end
                        
                        -- Shoot if hovering over valid target and holding gun
                        local Tool = Self.Character:FindFirstChildWhichIsA('Tool')
                        if Tool and Tool:FindFirstChild('Ammo') then
                            -- Check weapon configuration if enabled
                            local weaponConfig = shared.Story.Triggerbot['Weapon Configuration']
                            if weaponConfig and weaponConfig.Enabled then
                                local gunList = weaponConfig.Gun or {}
                                local gunAllowed = false
                                for _, gunName in ipairs(gunList) do
                                    if Tool.Name == gunName then
                                        gunAllowed = true
                                        break
                                    end
                                end
                                if not gunAllowed then return end
                            end
                            
                            -- Fire the tool (simulate click)
                            Tool:Activate()
                            LastTriggerbotShot = tick()
                        end
                    end
                end
            end
        end
    end)
 
    -- Speed Modification Logic - Uses RenderStepped to continuously apply speed
    local BaseSpeed = 16
    
    -- Apply Headless/Anti Trip with retry logic
    local function ApplyVisualMods(char)
        local speedConfig = shared.Story['Speed Modification']
        if not speedConfig or not speedConfig.Enabled then return end
        
        -- Headless (make head invisible) - run multiple times to catch late loading
        if speedConfig.Headless then
            task.spawn(function()
                for i = 1, 10 do
                    local head = char:FindFirstChild('Head')
                    if head then
                        -- Make head transparent
                        head.Transparency = 1
                        -- Make all decals on head transparent
                        for _, v in pairs(head:GetChildren()) do
                            if v:IsA('Decal') then
                                v.Transparency = 1
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
        
        -- Anti Trip (remove fall impact) - wait for animate script to load
        if speedConfig['Anti Trip'] then
            task.spawn(function()
                local animate = char:WaitForChild('Animate', 5)
                if animate then
                    task.wait(1) -- Wait for animations to load
                    local fall = animate:FindFirstChild('fall')
                    if fall then
                        local fallAnim = fall:FindFirstChild('FallAnim')
                        if fallAnim then
                            fallAnim:Destroy()
                        end
                    end
                end
            end)
        end
    end
    
    -- Apply visual mods on current character
    if Self.Character then
        ApplyVisualMods(Self.Character)
    end
    
    -- Apply visual mods on respawn
    Self.CharacterAdded:Connect(ApplyVisualMods)
    
    -- Main speed loop - runs every frame like user's example
    Utility.Connection(RunService.RenderStepped, function()
        local speedConfig = shared.Story['Speed Modification']
        -- Check if enabled in config AND toggled on via keybind
        if not speedConfig or not speedConfig.Enabled then return end
        if not SpeedEnabled then 
            -- Reset to normal speed when disabled
            local char = Self.Character
            if char then
                local hum = char:FindFirstChildOfClass('Humanoid')
                if hum and hum.WalkSpeed ~= BaseSpeed then
                    hum.WalkSpeed = BaseSpeed
                end
            end
            return 
        end
        
        local char = Self.Character
        if not char then return end
        
        local hum = char:FindFirstChildOfClass('Humanoid')
        if not hum then return end
        
        -- Check for crouch state (Da Hood uses BodyEffects.Crouching or animation)
        local bodyEffects = char:FindFirstChild('BodyEffects')
        local isCrouching = false
        
        if bodyEffects then
            local crouchingValue = bodyEffects:FindFirstChild('Crouching')
            if crouchingValue and crouchingValue.Value then
                isCrouching = true
            end
        end
        
        -- Also check via animation (crouch animation playing)
        local animate = char:FindFirstChild('Animate')
        if animate then
            local crouch = animate:FindFirstChild('crouch')
            if crouch then
                local crouchAnim = crouch:FindFirstChild('CrouchAnim')
                if crouchAnim and crouchAnim:IsA('Animation') then
                    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                        if track.Animation == crouchAnim or (track.Name and track.Name:lower():find('crouch')) then
                            isCrouching = true
                            break
                        end
                    end
                end
            end
        end
        
        -- Set target speed based on crouch state
        local multiplier = speedConfig.Multiplier or 1.5
        local targetSpeed = isCrouching and BaseSpeed or (BaseSpeed * multiplier)
        
        -- Always set WalkSpeed (like user's example)
        hum.WalkSpeed = targetSpeed
    end)
    
    -- Hitbox Expander - Make enemy hitboxes bigger
    Utility.ThreadLoop(0.5, function()
        local hitboxConfig = shared.Story['Hitbox Expander']
        if not hitboxConfig or not hitboxConfig.Enabled then return end
        
        local sizeConfig = hitboxConfig.Size or { X = 5, Y = 5, Z = 5 }
        local newSize = Vector3.new(sizeConfig.X or 5, sizeConfig.Y or 5, sizeConfig.Z or 5)
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Self and player.Character then
                local char = player.Character
                -- Expand Head hitbox
                local head = char:FindFirstChild('Head')
                if head and head:IsA('BasePart') then
                    head.Size = newSize
                    head.Transparency = 1
                    head.CanCollide = false
                end
                -- Expand HumanoidRootPart hitbox
                local hrp = char:FindFirstChild('HumanoidRootPart')
                if hrp and hrp:IsA('BasePart') then
                    hrp.Size = newSize
                    hrp.Transparency = 1
                    hrp.CanCollide = false
                end
            end
        end
    end)
 
    -- Skin Changer Logic
    local KnifeSkins = {
        ["Golden Age Tanto"] = {
            soundid = "rbxassetid://5917819099",
            animationid = "rbxassetid://13473404819",
            positionoffset = Vector3.new(0, -0.20, -1.2),
            rotationoffset = Vector3.new(90, 263.7, 180)
        },
        ["GPO-Knife"] = {
            soundid = "rbxassetid://4604390759",
            animationid = "rbxassetid://14014278925",
            positionoffset = Vector3.new(0.00, -0.32, -1.07),
            rotationoffset = Vector3.new(90, -97.4, 90)
        },
        ["GPO-Knife Prestige"] = {
            soundid = "rbxassetid://4604390759",
            animationid = "rbxassetid://14014278925",
            positionoffset = Vector3.new(0.00, -0.32, -1.07),
            rotationoffset = Vector3.new(90, -97.4, 90)
        },
        ["Heaven"] = {
            soundid = "rbxassetid://14489860007",
            animationid = "rbxassetid://14500266726",
            positionoffset = Vector3.new(-0.02, -0.82, 0.20),
            rotationoffset = Vector3.new(64.42, 3.79, 0.00)
        },
        ["Love Kukri"] = {
            soundid = "",
            animationid = "",
            positionoffset = Vector3.new(-0.14, 0.14, -1.62),
            rotationoffset = Vector3.new(-90.00, 180.00, -4.97),
            particle = true,
            textureid = "rbxassetid://12124159284"
        },
        ["Purple Dagger"] = {
            soundid = "rbxassetid://17822743153",
            animationid = "rbxassetid://17824999722",
            positionoffset = Vector3.new(-0.13, -0.24, -1.80),
            rotationoffset = Vector3.new(89.05, 96.63, 180.00)
        },
        ["Blue Dagger"] = {
            soundid = "rbxassetid://17822737046",
            animationid = "rbxassetid://17824995184",
            positionoffset = Vector3.new(-0.13, -0.24, -1.80),
            rotationoffset = Vector3.new(89.05, 96.63, 180.00)
        },
        ["Green Dagger"] = {
            soundid = "rbxassetid://17822741762",
            animationid = "rbxassetid://17825004320",
            positionoffset = Vector3.new(-0.13, -0.24, -1.07),
            rotationoffset = Vector3.new(89.05, 96.63, 180.00)
        },
        ["Red Dagger"] = {
            soundid = "rbxassetid://17822952417",
            animationid = "rbxassetid://17825008844",
            positionoffset = Vector3.new(-0.13, -0.24, -1.07),
            rotationoffset = Vector3.new(89.05, 96.63, 180.00)
        },
        ["Portal"] = {
            soundid = "rbxassetid://16058846352",
            animationid = "rbxassetid://16058633881",
            positionoffset = Vector3.new(-0.13, -0.35, -0.57),
            rotationoffset = Vector3.new(89.05, 96.63, 180.00)
        },
        ["Emerald Butterfly"] = {
            soundid = "rbxassetid://14931902491",
            animationid = "rbxassetid://14918231706",
            positionoffset = Vector3.new(-0.02, -0.30, -0.65),
            rotationoffset = Vector3.new(180.00, 90.95, 180.00)
        },
        ["Boy"] = {
            soundid = "rbxassetid://18765078331",
            animationid = "rbxassetid://18789158908",
            positionoffset = Vector3.new(-0.02, -0.09, -0.73),
            rotationoffset = Vector3.new(89.05, -88.11, 180.00)
        },
        ["Girl"] = {
            soundid = "rbxassetid://18765078331",
            animationid = "rbxassetid://18789162944",
            positionoffset = Vector3.new(-0.02, -0.16, -0.73),
            rotationoffset = Vector3.new(89.05, -88.11, 180.00)
        },
        ["Dragon"] = {
            soundid = "rbxassetid://14217789230",
            animationid = "rbxassetid://14217804400",
            positionoffset = Vector3.new(-0.02, -0.32, -0.98),
            rotationoffset = Vector3.new(89.05, 90.95, 180.00)
        },
        ["Void"] = {
            soundid = "rbxassetid://14756591763",
            animationid = "rbxassetid://14774699952",
            positionoffset = Vector3.new(-0.02, -0.22, -0.85),
            rotationoffset = Vector3.new(180.00, 90.95, 180.00)
        },
        ["Wild West"] = {
            soundid = "rbxassetid://16058689026",
            animationid = "rbxassetid://16058148839",
            positionoffset = Vector3.new(-0.02, -0.24, -1.15),
            rotationoffset = Vector3.new(-91.89, 90.95, 180.00)
        },
        ["Iced Out"] = {
            soundid = "rbxassetid://14924261405",
            animationid = "rbxassetid://18465353361",
            positionoffset = Vector3.new(0.02, -0.08, 0.99),
            rotationoffset = Vector3.new(180.00, -90.95, -180.00)
        },
        ["Reptile"] = {
            soundid = "rbxassetid://18765103349",
            animationid = "rbxassetid://18788955930",
            positionoffset = Vector3.new(-0.03, -0.06, -0.92),
            rotationoffset = Vector3.new(168.63, 90.00, -180.00)
        },
        ["Emerald"] = {
            soundid = "",
            animationid = "",
            positionoffset = Vector3.new(-0.03, -0.06, -0.92),
            rotationoffset = Vector3.new(168.63, 90.00, 108.00)
        },
        ["Ribbon"] = {
            soundid = "rbxassetid://130974579277249",
            animationid = "rbxassetid://124102609796063",
            positionoffset = Vector3.new(0.02, -0.25, -0.05),
            rotationoffset = Vector3.new(90.00, 0.00, 180.00)
        },
    }
    
    local KnifeData = {}
    
    local function ClearKnife(tool)
        if not tool or not tool:FindFirstChild("Default") then return end
        local mesh = tool.Default
        local data = KnifeData[tool]
        
        if data then
            if data.track then data.track:Stop() data.track:Destroy() end
            if data.welds then
                for _, weld in ipairs(data.welds) do
                    if weld then weld:Destroy() end
                end
            end
            if data.sounds then
                for _, sound in ipairs(data.sounds) do
                    if sound and sound.Parent then sound:Destroy() end
                end
            end
        end
 
        for _, child in ipairs(mesh:GetChildren()) do
            if child.Name == "Handle.R" or child:IsA("Model") or (child:IsA("BasePart") and child.Name ~= "Default") then
                child:Destroy()
            end
        end
        mesh.Transparency = 0
        KnifeData[tool] = nil
    end
    
    local function ApplyKnifeSkin(char, tool, skinName)
        local cfg = KnifeSkins[skinName]
        if not cfg then return end
 
        ClearKnife(tool)
        KnifeData[tool] = { welds = {}, sounds = {} }
        local data = KnifeData[tool]
 
        local mesh = tool:FindFirstChild("Default")
        if not mesh then return end
        mesh.Transparency = 1
 
        local rightHand = char:FindFirstChild("RightHand")
        if not rightHand then return end
 
        local handleR = Instance.new("Part")
        handleR.Name = "Handle.R"
        handleR.Transparency = 1
        handleR.CanCollide = false
        handleR.Anchored = false
        handleR.Size = Vector3.new(0.001, 0.001, 0.001)
        handleR.Massless = true
        handleR.Parent = mesh
 
        local motor = Instance.new("Motor6D")
        motor.Name = "Handle.R"
        motor.Part0 = rightHand
        motor.Part1 = handleR
        motor.Parent = handleR
 
        local offset = CFrame.new(cfg.positionoffset) * 
                       CFrame.Angles(math.rad(cfg.rotationoffset.X), 
                                     math.rad(cfg.rotationoffset.Y), 
                                     math.rad(cfg.rotationoffset.Z))
 
        local skinModules = ReplicatedStorage:FindFirstChild("SkinModules")
        if not skinModules then return end
        local knivesFolder = skinModules:FindFirstChild("Knives")
        if not knivesFolder then return end
 
        local skinModel = knivesFolder:FindFirstChild(skinName)
        if not skinModel then return end
 
        local clone = skinModel:Clone()
        clone.Name = skinName
 
        if clone:IsA("Model") then
            if not clone.PrimaryPart then
                for _, v in ipairs(clone:GetChildren()) do
                    if v:IsA("BasePart") then
                        clone.PrimaryPart = v
                        break
                    end
                end
            end
 
            if clone.PrimaryPart then
                for _, part in ipairs(clone:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        part.Massless = true
                        part.Anchored = false
 
                        local weld = Instance.new("Weld")
                        weld.Part0 = handleR
                        weld.Part1 = part
                        weld.C0 = offset
                        weld.C1 = part.CFrame:ToObjectSpace(clone.PrimaryPart.CFrame)
                        weld.Parent = part
                        table.insert(data.welds, weld)
                    end
                end
            end
            clone.Parent = mesh
 
        elseif clone:IsA("BasePart") then
            clone.CanCollide = false
            clone.Massless = true
            clone.Anchored = false
 
            if clone:IsA("MeshPart") and cfg.textureid then
                clone.TextureID = cfg.textureid
            end
 
            clone.Parent = mesh
 
            local weld = Instance.new("Weld")
            weld.Part0 = handleR
            weld.Part1 = clone
            weld.C0 = offset
            weld.Parent = clone
            table.insert(data.welds, weld)
        end
 
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid and cfg.animationid and cfg.animationid ~= "" then
            local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
            local anim = Instance.new("Animation")
            anim.AnimationId = cfg.animationid
            local track = animator:LoadAnimation(anim)
            track.Looped = false
            track:Play()
            data.track = track
 
            track.Ended:Once(function()
                if data.track == track then data.track = nil end
            end)
        end
 
        if cfg.soundid and cfg.soundid ~= "" then
            local sound = Instance.new("Sound")
            sound.SoundId = cfg.soundid
            sound.Parent = workspace
            sound:Play()
            table.insert(data.sounds, sound)
            sound.Ended:Connect(function() sound:Destroy() end)
        end
 
        tool:SetAttribute("CurrentKnifeSkin", skinName)
    end
    
    local function ApplyGunSkin(tool, skinName)
        local orig = tool:FindFirstChildOfClass("MeshPart")
        if not orig then return end
 
        local skinModules = ReplicatedStorage:FindFirstChild("SkinModules")
        if not skinModules then return end
 
        local success, skinData = pcall(function()
            return require(skinModules)
        end)
 
        if not success or not skinData then return end
 
        local info = skinData[tool.Name] and skinData[tool.Name][skinName]
        if not info then return end
 
        for _, v in ipairs(tool:GetChildren()) do
            if v:IsA("MeshPart") and v ~= orig then
                v:Destroy()
            end
        end
 
        local skinPart = info.TextureID
        if typeof(skinPart) == "Instance" then
            local clone = skinPart:Clone()
            clone.Parent = tool
            clone.CFrame = orig.CFrame
            clone.Name = "CurrentSkin"
 
            local weld = Instance.new("Weld")
            weld.Part0 = clone
            weld.Part1 = orig
            weld.C0 = info.CFrame:Inverse()
            weld.Parent = clone
 
            orig.Transparency = 1
        else
            orig.TextureID = skinPart
            orig.Transparency = 0
        end
 
        local handle = tool:FindFirstChild("Handle")
        if handle then
            handle:SetAttribute("SkinName", skinName)
        end
    end
    
    local function ApplyBatSkin(tool, skinName)
        local mesh = nil
        for _, v in ipairs(tool:GetDescendants()) do
            if v:IsA("MeshPart") and v.Transparency == 0 then
                mesh = v
                break
            end
        end
        if not mesh then return end
 
        local batsFolder = ReplicatedStorage:FindFirstChild("SkinModules") and ReplicatedStorage.SkinModules:FindFirstChild("Bats")
        if not batsFolder then return end
 
        local skin = batsFolder:FindFirstChild(skinName)
        if not skin then return end
 
        local clone = skin:Clone()
        clone.Parent = tool
        clone.CFrame = mesh.CFrame
        clone.Name = "CurrentSkin"
 
        local weld = Instance.new("Weld")
        weld.Part0 = clone
        weld.Part1 = mesh
        weld.Parent = clone
 
        mesh.Transparency = 1
    end
    
    -- Setup tool when equipped
    local function SetupTool(tool)
        if not tool:IsA("Tool") or tool:GetAttribute("GlorySkinSetup") then return end
        tool:SetAttribute("GlorySkinSetup", true)
 
        local skinConfig = shared.Story['Skin Changer']
        if not skinConfig or not skinConfig.Enabled then return end
 
        local skinName = skinConfig.Skins and skinConfig.Skins[tool.Name]
        if not skinName or skinName == "" then return end
 
        tool.Equipped:Connect(function()
            if tool.Parent ~= Self.Character then return end
 
            if tool.Name == "[Knife]" then
                ApplyKnifeSkin(Self.Character, tool, skinName)
            elseif tool.Name == "[Bat]" then
                ApplyBatSkin(tool, skinName)
            else
                ApplyGunSkin(tool, skinName)
            end
        end)
 
        -- Apply immediately if already equipped
        if tool.Parent == Self.Character then
            task.spawn(function()
                if tool.Name == "[Knife]" then
                    ApplyKnifeSkin(Self.Character, tool, skinName)
                elseif tool.Name == "[Bat]" then
                    ApplyBatSkin(tool, skinName)
                else
                    ApplyGunSkin(tool, skinName)
                end
            end)
        end
    end
 
    -- Watch for new tools
    Self.CharacterAdded:Connect(function(char)
        char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                SetupTool(child)
            end
        end)
    end)
 
    -- Setup existing tools
    if Self.Character then
        for _, tool in ipairs(Self.Character:GetChildren()) do
            if tool:IsA("Tool") then
                SetupTool(tool)
            end
        end
    end
 
    for _, tool in ipairs(Self.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            SetupTool(tool)
        end
    end
 
    Self.Backpack.ChildAdded:Connect(SetupTool)
 
Utility.Connection(RunService.PreRender, LPH_NO_VIRTUALIZE(function()
    -- FULL AUTO UNTARGET ON DEATH / KNOCK / GRAB
    local function FullAutoUntarget()
        local function IsDead(char)
            local hum = char:FindFirstChild("Humanoid")
            return not hum or hum.Health <= 0
        end
 
        local function IsKnocked(char)
            local be = char:FindFirstChild("BodyEffects")
            return be and be:FindFirstChild("K.O") and be["K.O"].Value
        end
 
        local function IsGrabbed(char)
            return char:FindFirstChild("GRABBING_CONSTRAINT") ~= nil
        end
 
        local function ClearAll()
            Mango.Locals.SilentAimTarget  = nil
            Mango.Locals.LockedTarget     = nil
            Mango.Locals.HitPosition      = nil
            -- Only reset SP in Target mode, keep it always true in Auto mode
            local selectionMode = shared.Story.Selection['Selection Mode'] or 'Auto'
            if selectionMode == 'Target' then
                SP = false
            end
            -- In Auto mode, SP stays true (always on by default)
        end
 
        -- Check main target (covers SilentAim)
        if Mango.Locals.SilentAimTarget then
            local char = Mango.Locals.SilentAimTarget.Character
            -- Get current mode and checks
            local selectionMode = shared.Story.Selection['Selection Mode'] or 'Auto'
            local checks = shared.Story.Selection.Checks[selectionMode] or shared.Story.Selection.Checks.Auto
            
            if not char or not char.Parent or IsDead(char) or 
               (checks.Knocked and IsKnocked(char)) or 
               (checks.Grabbed and IsGrabbed(char)) then
                ClearAll()
                return
            end
        end
    end
 
    FullAutoUntarget() -- ← This runs every frame
 
    -- Auto Mode: Always ON - automatically acquire closest target every frame
    local SelectionMode = shared.Story.Selection['Selection Mode'] or 'Auto'
    if SelectionMode == 'Auto' and shared.Story.SilentAim.Enabled then
        -- Auto mode is always active (SP is always true)
        local closest = Player.GetClosestPlayerToCursor()
        if closest then
            Mango.Locals.SilentAimTarget = closest
            Mango.Locals.LockedTarget = closest
        else
            Mango.Locals.SilentAimTarget = nil
            Mango.Locals.LockedTarget = nil
        end
    end
 
    -- Normal aimbot logic (only runs if we have a valid target)
    if Mango.Locals.SilentAimTarget and Mango.Locals.SilentAimTarget.Character then
        Mango.Locals.HitPosition = Player.GetHitPosition("Silent")
    end
 
    Player.AutomatedPrediction()
    Main.UpdateBox()
    AimAssistCamera()
    
    -- ESP Logic
    local espConfig = shared.Story.ESP
    if espConfig and espConfig.Enabled then
        -- ESP storage
        if not Mango.Locals.ESPData then
            Mango.Locals.ESPData = {
                NameTexts = {}
            }
        end
        
        local espData = Mango.Locals.ESPData
        
        -- Clean up old ESP elements
        for player, text in pairs(espData.NameTexts) do
            if not player or not player.Parent or not player.Character then
                if text then text:Remove() end
                espData.NameTexts[player] = nil
            end
        end
        
        -- Update ESP for all players
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Self and player.Character then
                local char = player.Character
                local hrp = char:FindFirstChild('HumanoidRootPart')
                local head = char:FindFirstChild('Head')
                
                if hrp and head then
                    -- Check if player is valid (not knocked, etc)
                    local isKnocked = char:FindFirstChild('BodyEffects') and char.BodyEffects:FindFirstChild('K.O') and char.BodyEffects['K.O'].Value
                    local isDead = char:FindFirstChild('Humanoid') and char.Humanoid.Health <= 0
                    
                    if not isKnocked and not isDead then
                        local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                        
                        if onScreen then
                            -- Name ESP
                            if espConfig.Name and espConfig.Name.Enabled then
                                local text = espData.NameTexts[player]
                                if not text then
                                    text = Overlay.new('Text')
                                    text.Size = 14
                                    text.Outline = true
                                    text.Center = true
                                    espData.NameTexts[player] = text
                                end
                                
                                text.Visible = true
                                text.Text = player.DisplayName
                                
                                -- Change color to red if this player is the current target
                                if Mango.Locals.SilentAimTarget == player then
                                    text.Color = Color3.fromRGB(255, 0, 0) -- Red when targeted
                                else
                                    text.Color = espConfig.Name.Color or Color3.fromRGB(255, 255, 255)
                                end
                                
                                -- Position based on config
                                local textPos
                                local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0))
                                local hrpPos = Camera:WorldToViewportPoint(hrp.Position)
                                
                                if espConfig.Name.Position == 'Top' then
                                    textPos = Vector2.new(headPos.X, headPos.Y - 20)
                                elseif espConfig.Name.Position == 'Bottom' then
                                    textPos = Vector2.new(hrpPos.X, hrpPos.Y + 20)
                                else
                                    textPos = Vector2.new(headPos.X, headPos.Y - 20)
                                end
                                text.Position = textPos
                            elseif espData.NameTexts[player] then
                                espData.NameTexts[player].Visible = false
                            end
                            
                        else
                            -- Player off screen, hide ESP
                            if espData.NameTexts[player] then
                                espData.NameTexts[player].Visible = false
                            end
                        end
                    else
                        -- Player knocked/dead, hide ESP
                        if espData.NameTexts[player] then
                            espData.NameTexts[player].Visible = false
                        end
                    end
                end
            end
        end
    end
end))
 
Utility.Connection(RunService.PreRender, LPH_NO_VIRTUALIZE(function()
    if shared.Story.SilentAim.Enabled and CurrentGame.Name == "Da Hood" then
        local GunType = Main.GetGunCategory()
        local Tool = Self.Character:FindFirstChildWhichIsA("Tool")
        if Tool then
            if GunType == "Pistol" or GunType == "Sniper" then
                for I, v in pairs(Tool:GetChildren()) do
                    if v.Name == "GunClient" then
                        v:Destroy()
                        --v.Disabled = Mango.Locals.GunScriptDisabled
                    end
                end
            elseif GunType == "Shotgun" then
                for I, v in pairs(Tool:GetChildren()) do
                    if v.Name == "GunClientShotgun" then
                        v:Destroy()
                        --v.Disabled = Mango.Locals.GunScriptDisabled
                    end
                end
            elseif GunType == "Auto" then
                for I, v in pairs(Tool:GetChildren()) do
                    if v.Name == "GunClientAutomaticShotgun" then
                        v:Destroy()
                        --v.Disabled = Mango.Locals.GunScriptDisabled
                    end
                end
            elseif GunType == "Burst" then
                for I, v in pairs(Tool:GetChildren()) do
                    if v.Name == "GunClientBurst" then
                        v:Destroy()
                        --v.Disabled = Mango.Locals.GunScriptDisabled
                    end
                end
            elseif GunType == "Rifle" or GunType == "SMG" then
                for I, v in pairs(Tool:GetChildren()) do
                    if v.Name == "GunClientAutomatic" then
                        v:Destroy()
                        --v.Disabled = Mango.Locals.GunScriptDisabled
                    end
                end
            end    
        end
    end
end))
 
if CurrentGame.Name == 'Dee Hood' and CurrentGame.Updater == nil then
    local function GetArgument() 
        for _, Player in next, game:GetService("Players"):GetPlayers() do
            if Player.Backpack:GetAttribute(string.upper("muv")) then
                return Player.Backpack:GetAttribute(string.upper("muv"))
            end
        end
        
        return nil
    end
    
    local Argument = GetArgument()
    if Argument then
        CurrentGame.Updater = Argument
    end
end
 
 
 
 
 
 
 
if shared.Story.SilentAim.Enabled then
    local Connections = {}
    local function connectTool(tool)
        if tool:IsA("Tool") and not Connections[tool] then
            Connections[tool] = tool.Activated:Connect(function()
                Main.SilentAim(tool)
            end)
        end
    end
    
    for _, v in ipairs(Self.Backpack:GetChildren()) do
        connectTool(v)
    end
    
    for _, v in ipairs(Self.Character:GetChildren()) do
        connectTool(v)
    end
    
    Self.Character.ChildAdded:Connect(connectTool)
    
    Self.CharacterAdded:Connect(function(character)
        for tool, connection in pairs(Connections) do
            connection:Disconnect()
            Connections[tool] = nil
        end
        
        character.ChildAdded:Connect(connectTool)
    end)
    
    
    task.spawn(function()
        while task.wait() do
            local Tool = Self.Character:FindFirstChildWhichIsA("Tool")
            if Tool and CurrentGame.Name == "Da Hood" then
                Tool:GetPropertyChangedSignal("Grip"):Connect(function()
                    game.ReplicatedStorage:WaitForChild("MainEvent"):FireServer("CHECKER_4")
                end)
            end
        end
    end)
end
 
-- No Jump Cooldown
Utility.Connection(RunService.Heartbeat, LPH_NO_VIRTUALIZE(function()
    local humanoid = Self.Character and Self.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.UseJumpPower = false
    end
end))
 
end
