local Config = shared.Accuracy
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local currentTarget = nil
local isLocking = false
local triggerEnabled = false
local fovBox = nil
local espLabels = {}
local SpeedEnabled = false
local BaseSpeed = 16
local lastVisibleTarget = nil
local lastTriggerClick = 0
local superJumpActive = false
local guiVisible = true  -- tracks on-screen text display visibility

local function elasticOut(t)
    local p = 0.3
    return math.pow(2, -10 * t) * math.sin((t - p / 4) * (2 * math.pi) / p) + 1
end

local function sineInOut(t)
    return -(math.cos(math.pi * t) - 1) / 2
end

local function isPlayerKnockedOrKO(player)
    if not Config['Settings']['Knock Check'] then return false end
    
    if player.Character then
        local bodyEffects = player.Character:FindFirstChild("BodyEffects")
        if bodyEffects then
            local ko = bodyEffects:FindFirstChild("K.O")
            if ko and ko.Value == true then return true end
            
            local knocked = bodyEffects:FindFirstChild("Knocked")
            if knocked and knocked.Value == true then return true end
        end
    end
    
    return false
end

local function isSelfKnocked()
    if LocalPlayer.Character then
        local bodyEffects = LocalPlayer.Character:FindFirstChild("BodyEffects")
        if bodyEffects then
            local ko = bodyEffects:FindFirstChild("K.O")
            if ko and ko.Value == true then return true end
            
            local knocked = bodyEffects:FindFirstChild("Knocked")
            if knocked and knocked.Value == true then return true end
        end
    end
    return false
end

local function canSeeTarget(part)
    if not Config['Settings']['Visible Check'] then return true end
    
    if not part or not part.Parent then return false end
    
    local character = part.Parent
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    local state = humanoid:GetState()
    local isAirborne = (state == Enum.HumanoidStateType.Jumping or 
                        state == Enum.HumanoidStateType.Freefall or 
                        state == Enum.HumanoidStateType.FallingDown)
    
    local root = character:FindFirstChild("HumanoidRootPart")
    local velY = root and math.abs((root.AssemblyLinearVelocity or root.Velocity or Vector3.new()).Y) or 0
    
    if (isAirborne or velY > 8) and isLocking then
        return true
    end
    
    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin).Unit * (part.Position - origin).Magnitude
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true
    
    local rayResult = Workspace:Raycast(origin, direction, raycastParams)
    return rayResult == nil or rayResult.Instance:IsDescendantOf(character)
end

local function getClosestBodyPart(character)
    local closestPart = nil
    local shortestDist = math.huge
    
    local bodyParts = {
        character:FindFirstChild("Head"),
        character:FindFirstChild("UpperTorso"),
        character:FindFirstChild("HumanoidRootPart"),
        character:FindFirstChild("LowerTorso"),
        character:FindFirstChild("LeftUpperArm"),
        character:FindFirstChild("RightUpperArm"),
        character:FindFirstChild("LeftLowerArm"),
        character:FindFirstChild("RightLowerArm"),
        character:FindFirstChild("LeftHand"),
        character:FindFirstChild("RightHand"),
        character:FindFirstChild("LeftUpperLeg"),
        character:FindFirstChild("RightUpperLeg"),
        character:FindFirstChild("LeftLowerLeg"),
        character:FindFirstChild("RightLowerLeg"),
        character:FindFirstChild("LeftFoot"),
        character:FindFirstChild("RightFoot"),
    }
    
    for _, part in pairs(bodyParts) do
        if part then
            local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
            
            local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local dist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
            
            if dist < shortestDist then
                shortestDist = dist
                closestPart = part
            end
        end
    end
    
    return closestPart
end

local function isMouseInFOV(character)
    if not Config['FOV']['Enabled'] then return true end
    if not character then return false end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    if not rootPart or not head then return false end
    
    local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
    local legPos, legOnScreen = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
    
    if not headOnScreen or not legOnScreen then return false end
    
    local height = math.abs(headPos.Y - legPos.Y)
    local width = height / 2
    
    local rootPos = Camera:WorldToViewportPoint(rootPart.Position)
    
    local padding = 10
    local topLeftX = rootPos.X - width/2 - padding
    local topLeftY = headPos.Y - padding
    local bottomRightX = rootPos.X + width/2 + padding
    local bottomRightY = legPos.Y + padding
    
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    
    return mousePos.X >= topLeftX and mousePos.X <= bottomRightX and mousePos.Y >= topLeftY and mousePos.Y <= bottomRightY
end

local function findClosestTarget()
    local closestTarget = nil
    local shortestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not isPlayerKnockedOrKO(player) then
                local targetPart = nil
                
                if Config['Silent Aim']['Hit Part'] == 'Closest Part' then
                    targetPart = getClosestBodyPart(player.Character)
                else
                    targetPart = player.Character:FindFirstChild(Config['Silent Aim']['Hit Part'])
                end
                
                if targetPart and canSeeTarget(targetPart) then
                    local pos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    
                    if isMouseInFOV(player.Character) then
                        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        local dist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                        
                        if dist < shortestDistance then
                            shortestDistance = dist
                            closestTarget = targetPart
                        end
                    end
                end
            end
        end
    end
    
    return closestTarget
end

local function getPredictedPosition(part, config)
    if not config['Use Prediction'] then return part.Position end
    
    local velocity = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
    local prediction = config['Prediction']
    
    if type(prediction) == "table" then
        local predX = prediction['X'] or 0.133
        local predY = prediction['Y'] or 0.133
        local predZ = prediction['Z'] or 0.133
        
        return part.Position + Vector3.new(velocity.X * predX, velocity.Y * predY, velocity.Z * predZ)
    else
        if prediction == 0 then
            prediction = 0.1245
        end
        
        return part.Position + (velocity * prediction)
    end
end

local function getTargetForCameraLock()
    if Config['Settings']['Target Aim'] and currentTarget then
        local player = Players:GetPlayerFromCharacter(currentTarget.Parent)
        if player and not isPlayerKnockedOrKO(player) then
            local targetPart = nil
            
            if Config['Camera Lock']['Hit Part'] == 'Closest Part' then
                targetPart = getClosestBodyPart(currentTarget.Parent)
            else
                targetPart = currentTarget.Parent:FindFirstChild(Config['Camera Lock']['Hit Part'])
            end
            
            if targetPart then
                if canSeeTarget(targetPart) then
                    lastVisibleTarget = currentTarget
                    return targetPart
                else
                    return nil
                end
            end
        end
        
        currentTarget = nil
        isLocking = false
        lastVisibleTarget = nil
        return nil
    else
        return findClosestTarget()
    end
end

local function applyCameraLock()
    if not isLocking then return end
    
    if isSelfKnocked() then
        currentTarget = nil
        isLocking = false
        lastVisibleTarget = nil
        return
    end
    
    local target = getTargetForCameraLock()
    
    if target then
        local targetPos = getPredictedPosition(target, Config['Camera Lock'])
        
        local cameraCFrame = Camera.CFrame
        local targetCFrame = CFrame.new(cameraCFrame.Position, targetPos)
        
        local smoothValue = Config['Camera Lock']['Smoothing']
        local baseAlpha = 1 / smoothValue
        
        local elasticAlpha = elasticOut(math.min(baseAlpha, 1))
        local smoothCFrame = cameraCFrame:Lerp(targetCFrame, elasticAlpha * baseAlpha)
        
        local sineAlpha = sineInOut(math.min(baseAlpha, 1))
        Camera.CFrame = smoothCFrame:Lerp(targetCFrame, sineAlpha * baseAlpha)
    else
        if lastVisibleTarget then
            local player = Players:GetPlayerFromCharacter(lastVisibleTarget.Parent)
            if player and not isPlayerKnockedOrKO(player) then
                local targetPart = lastVisibleTarget
                if targetPart and canSeeTarget(targetPart) then
                    currentTarget = lastVisibleTarget
                end
            end
        end
    end
end

if not fovBox then
    fovBox = Drawing.new("Square")
    fovBox.Visible = false
    fovBox.Thickness = Config['FOV']['Thickness']
    fovBox.Color = Config['FOV']['Color']
    fovBox.Filled = false
    fovBox.Size = Vector2.new(0, 0)
end

local function updateFOVBox()
    if not Config['FOV']['Enabled'] or not Config['FOV']['Visible'] then
        fovBox.Visible = false
        return
    end
    
    if currentTarget then
        local character = currentTarget.Parent
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local head = character:FindFirstChild("Head")
            
            if rootPart and head then
                local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local legPos, legOnScreen = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
                
                if headOnScreen and legOnScreen then
                    local height = math.abs(headPos.Y - legPos.Y)
                    local width = height / 2
                    
                    local rootPos = Camera:WorldToViewportPoint(rootPart.Position)
                    
                    local padding = 10
                    local topLeft = Vector2.new(rootPos.X - width/2 - padding, headPos.Y - padding)
                    
                    fovBox.Size = Vector2.new(width + padding * 2, height + padding * 2)
                    fovBox.Position = topLeft
                    fovBox.Visible = true
                    return
                end
            end
        end
    end
    
    fovBox.Visible = false
end

local function TriggerBot()
    if not Config['Trigger Bot']['Enabled'] then return end
    if not triggerEnabled then return end
    
    if tick() - lastTriggerClick < Config['Trigger Bot']['Delay'] then return end
    
    if not currentTarget then return end
    
    local character = currentTarget.Parent
    if not character then return end
    
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end
    
    if isPlayerKnockedOrKO(player) then return end
    
    if not canSeeTarget(currentTarget) then return end
    
    if Config['FOV']['Enabled'] and not isMouseInFOV(character) then return end
    
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if not tool then return end
    
    if Config['Trigger Bot']['Knife Check'] then
        local isKnife = tool.Name:lower():find("knife") ~= nil
        if isKnife then return end
    end
    
    if Config['Trigger Bot']['Specific Weapons']['Enabled'] then
        local weaponValid = false
        for _, weaponName in pairs(Config['Trigger Bot']['Specific Weapons']['Weapons']) do
            local cleanName = weaponName:gsub("%[", ""):gsub("%]", "")
            if tool.Name == weaponName or tool.Name:find(cleanName) then
                weaponValid = true
                break
            end
        end
        if not weaponValid then return end
    end
    
    tool:Activate()
    lastTriggerClick = tick()
end

local grm = getrawmetatable(game)
local oldIndex = grm.__index
setreadonly(grm, false)
grm.__index = function(self, key)
    if not checkcaller() and self == Mouse and Config['Silent Aim']['Enabled'] then
        if key == "Hit" then
            if not currentTarget then return oldIndex(self, key) end
            
            local character = currentTarget.Parent
            if not character then return oldIndex(self, key) end
            
            local player = Players:GetPlayerFromCharacter(character)
            if not player then return oldIndex(self, key) end
            
            if isPlayerKnockedOrKO(player) then return oldIndex(self, key) end
            if not canSeeTarget(currentTarget) then return oldIndex(self, key) end
            
            if Config['FOV']['Enabled'] and not isMouseInFOV(character) then
                return oldIndex(self, key)
            end
            
            local targetPart = currentTarget
            if targetPart then
                local predictedPos = getPredictedPosition(targetPart, Config['Silent Aim'])
                return CFrame.new(predictedPos)
            end
        end
    end
    return oldIndex(self, key)
end

local oldRandom
oldRandom = hookfunction(math.random, function(...)
    local args = {...}
    if checkcaller() then
        return oldRandom(...)
    end
    
    if (#args == 0) or (args[1] == -0.05 and args[2] == 0.05) or (args[1] == -0.1) or (args[1] == -0.05) then
        if Config['Spread']['Enabled'] then
            if Config['Spread']['Specific Weapons']['Enabled'] then
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool then
                    local weaponName = tool.Name
                    local foundWeapon = false
                    
                    for _, weapon in pairs(Config['Spread']['Specific Weapons']['Weapons']) do
                        if weaponName == weapon then
                            foundWeapon = true
                            break
                        end
                    end
                    
                    if foundWeapon then
                        return oldRandom(...) * (Config['Spread']['Amount'] / 100)
                    end
                end
            else
                return oldRandom(...) * (Config['Spread']['Amount'] / 100)
            end
        end
    end
    
    return oldRandom(...)
end)

local function addESPToPlayer(player)
    if player == LocalPlayer then return end
    
    local esp = {
        player = player,
        nameTag = Drawing.new("Text"),
    }
    
    esp.nameTag.Size = 14
    esp.nameTag.Center = true
    esp.nameTag.Outline = true
    esp.nameTag.OutlineColor = Color3.fromRGB(0, 0, 0)
    esp.nameTag.Color = Config['Visual Awareness']['Color']
    esp.nameTag.Visible = false
    esp.nameTag.ZIndex = 1000
    
    espLabels[player.UserId] = esp
end

local function removeESPFromPlayer(player)
    local esp = espLabels[player.UserId]
    if esp then
        esp.nameTag:Remove()
        espLabels[player.UserId] = nil
    end
end

local function refreshESP()
    if not Config['Visual Awareness']['Enabled'] then
        for _, esp in pairs(espLabels) do
            esp.nameTag.Visible = false
        end
        return
    end
    
    for userId, esp in pairs(espLabels) do
        local player = esp.player
        if not player or not player.Parent then
            esp.nameTag.Visible = false
            esp.nameTag:Remove()
            espLabels[userId] = nil
            continue
        end
        
        if player.Character and player.Character.Parent and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Head") then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then
                esp.nameTag.Visible = false
                continue
            end
            
            local head = player.Character.Head
            local rootPart = player.Character.HumanoidRootPart
            local legPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
            
            if onScreen and legPos.Z > 0 then
                esp.nameTag.Position = Vector2.new(legPos.X, legPos.Y + 15)
                
                if player.DisplayName and player.DisplayName ~= "" then
                    esp.nameTag.Text = player.DisplayName
                else
                    esp.nameTag.Text = player.Name
                end
                
                if currentTarget and currentTarget.Parent == player.Character then
                    esp.nameTag.Color = Config['Visual Awareness']['Target Color']
                else
                    esp.nameTag.Color = Config['Visual Awareness']['Color']
                end
                
                esp.nameTag.Visible = true
            else
                esp.nameTag.Visible = false
            end
        else
            esp.nameTag.Visible = false
        end
    end
end

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        addESPToPlayer(player)
    end
    
    player.CharacterAdded:Connect(function(char)
        removeESPFromPlayer(player)
        char:WaitForChild("HumanoidRootPart")
        task.wait(0.1)
        addESPToPlayer(player)
    end)
    
    player.CharacterRemoving:Connect(function()
        removeESPFromPlayer(player)
    end)
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function(char)
            removeESPFromPlayer(player)
            char:WaitForChild("HumanoidRootPart")
            task.wait(0.1)
            addESPToPlayer(player)
        end)
        
        player.CharacterRemoving:Connect(function()
            removeESPFromPlayer(player)
        end)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removeESPFromPlayer(player)
end)

RunService.Heartbeat:Connect(function()
    if not Config['Super Jump']['Enabled'] then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not rootPart then return end
    
    local holdingB = UserInputService:IsKeyDown(Enum.KeyCode[Config['Keybinds']['Super Jump']])
    
    if holdingB and (humanoid:GetState() == Enum.HumanoidStateType.Landed or humanoid.FloorMaterial ~= Enum.Material.Air) then
        rootPart.Velocity = Vector3.new(
            rootPart.Velocity.X,
            Config['Super Jump']['Power'],
            rootPart.Velocity.Z
        )
        task.wait(Config['Super Jump']['Cooldown'])
    end
end)

RunService.RenderStepped:Connect(function()
    if isSelfKnocked() and isLocking then
        currentTarget = nil
        isLocking = false
        lastVisibleTarget = nil
    end
    
    TriggerBot()
    
    if SpeedEnabled and Config['Speed']['Enabled'] then
        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            local targetSpeed = BaseSpeed * Config['Speed']['Multiplier']
            
            if humanoid.WalkSpeed ~= targetSpeed then
                humanoid.WalkSpeed = targetSpeed
            end
        end
        
        if Config['Speed']['Anti Fling'] then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local vel = hrp.Velocity
                if vel.Y > 50 or vel.Y < -50 then
                    hrp.Velocity = Vector3.new(vel.X, 0, vel.Z)
                end
            end
        end
    end
    
    if Config['Hitbox Expander']['Enabled'] then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = Vector3.new(Config['Hitbox Expander']['Size'], Config['Hitbox Expander']['Size'], Config['Hitbox Expander']['Size'])
                    
                    if Config['Hitbox Expander']['Visualize'] then
                        hrp.Transparency = 0.7
                        hrp.BrickColor = BrickColor.new("Really blue")
                        hrp.Material = "Neon"
                        hrp.CanCollide = false
                    else
                        hrp.Transparency = 1
                    end
                end
            end
        end
    end
    
    if Config['Spiderman']['Enabled'] then
        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if humanoid and hrp then
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            
            local directions = {
                hrp.CFrame.LookVector * 3,
                hrp.CFrame.RightVector * 3,
                -hrp.CFrame.RightVector * 3,
            }
            
            local foundWall = false
            for _, direction in pairs(directions) do
                local result = Workspace:Raycast(hrp.Position, direction, raycastParams)
                if result and result.Instance then
                    foundWall = true
                    break
                end
            end
            
            if foundWall then
                if humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
                    humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
                end
                
                local bodyVelocity = hrp:FindFirstChild("SpidermanVelocity")
                if not bodyVelocity then
                    bodyVelocity = Instance.new("BodyVelocity")
                    bodyVelocity.Name = "SpidermanVelocity"
                    bodyVelocity.MaxForce = Vector3.new(0, 4000, 0)
                    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    bodyVelocity.Parent = hrp
                end
            else
                local bodyVelocity = hrp:FindFirstChild("SpidermanVelocity")
                if bodyVelocity then
                    bodyVelocity:Destroy()
                end
            end
        end
    else
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bodyVelocity = hrp:FindFirstChild("SpidermanVelocity")
            if bodyVelocity then
                bodyVelocity:Destroy()
            end
        end
    end
    
    updateFOVBox()
    refreshESP()
    
    if Config['Camera Lock']['Enabled'] then
        applyCameraLock()
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Target Lock']['Key']] then
        local mode = Config['Keybinds']['Target Lock']['Mode']
        
        if mode == 'Toggle' then
            if Config['Settings']['Target Aim'] then
                if isLocking then
                    isLocking = false
                    currentTarget = nil
                    lastVisibleTarget = nil
                else
                    local target = findClosestTarget()
                    if target then
                        currentTarget = target
                        lastVisibleTarget = target
                        isLocking = true
                    end
                end
            else
                isLocking = not isLocking
            end
        elseif mode == 'Hold' then
            if Config['Settings']['Target Aim'] then
                local target = findClosestTarget()
                if target then
                    currentTarget = target
                    lastVisibleTarget = target
                    isLocking = true
                end
            else
                isLocking = true
            end
        end
    end
    
    if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Trigger Bot']['Key']] then
        local mode = Config['Keybinds']['Trigger Bot']['Mode']
        
        if mode == 'Toggle' then
            triggerEnabled = not triggerEnabled
        elseif mode == 'Hold' then
            triggerEnabled = true
        end
    end
    
    if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Speed']] then
        local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            if not SpeedEnabled then
                BaseSpeed = 16
                SpeedEnabled = true
            else
                humanoid.WalkSpeed = BaseSpeed
                SpeedEnabled = false
            end
        end
    end
    
    if input.KeyCode == Enum.KeyCode[Config['Keybinds']['ESP']] then
        Config['Visual Awareness']['Enabled'] = not Config['Visual Awareness']['Enabled']
        print("ESP: " .. (Config['Visual Awareness']['Enabled'] and "ON" or "OFF"))
    end
    
    if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Super Jump']] then
        superJumpActive = not superJumpActive
        print("Super Jump: " .. (superJumpActive and "ON" or "OFF"))
    end
    
    if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Toggle GUI']] then
        guiVisible = not guiVisible
        print("GUI Text: " .. (guiVisible and "ON" or "OFF"))
    end
end)

UserInputService.InputEnded:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Target Lock']['Key']] then
        local mode = Config['Keybinds']['Target Lock']['Mode']
        
        if mode == 'Hold' then
            isLocking = false
            currentTarget = nil
            lastVisibleTarget = nil
        end
    end
    
    if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Trigger Bot']['Key']] then
        local mode = Config['Keybinds']['Trigger Bot']['Mode']
        
        if mode == 'Hold' then
            triggerEnabled = false
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
end)
local rapidFireActive = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        rapidFireActive = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        rapidFireActive = false
    end
end)

RunService.Heartbeat:Connect(function()
    if not Config['Rapid Fire']['Enabled'] or not rapidFireActive then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then return end
    
    if Config['Rapid Fire']['Specific Weapons']['Enabled'] then
        local valid = false
        for _, wName in pairs(Config['Rapid Fire']['Specific Weapons']['Weapons']) do
            if tool.Name == wName then
                valid = true
                break
            end
        end
        if not valid then return end
    end
    
    tool:Activate()
    task.wait(Config['Rapid Fire']['Delay'])
end)
local infRangeActive = false

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode[Config['Infinite Range']['Key']] then
        infRangeActive = not infRangeActive
        print("Infinite Range: " .. (infRangeActive and "ON" or "OFF"))
    end
end)

RunService.RenderStepped:Connect(function()
    if not Config['Infinite Range']['Enabled'] or not infRangeActive then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then return end
    
    local rangeProps = {"Range", "MaxRange", "FireRange", "Distance", "MaxDistance"}
    
    for _, propName in pairs(rangeProps) do
        local rangeValue = tool:FindFirstChild(propName)
        if rangeValue and rangeValue:IsA("NumberValue") then
            rangeValue.Value = Config['Infinite Range']['Max Range']
        end
        
        local config = tool:FindFirstChild("Configuration") or tool:FindFirstChild("GunConfig")
        if config then
            local r = config:FindFirstChild(propName)
            if r and r:IsA("NumberValue") then
                r.Value = Config['Infinite Range']['Max Range']
            end
        end
    end
end)


local gui = Instance.new("ScreenGui")
gui.Parent = game.CoreGui

local text = Instance.new("TextLabel")
text.Parent = gui

text.AnchorPoint = Vector2.new(0.5, 1)
text.Position = UDim2.new(0.5, 0, 1, -110)
text.Size = UDim2.new(0, 260, 0, 140)

text.BackgroundTransparency = 1
text.TextXAlignment = Enum.TextXAlignment.Center
text.TextYAlignment = Enum.TextYAlignment.Bottom

text.Font = Enum.Font.Gotham
text.TextSize = 15
text.RichText = true

text.TextStrokeTransparency = 0
text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

RunService.RenderStepped:Connect(function()
    if not guiVisible then
        text.Text = ""
        return
    end
    
    local lines = {}

    table.insert(lines, '<font color="rgb(255,255,255)">ecco.club</font>')

    if Config["Silent Aim"]["Enabled"] and currentTarget then
        local character = currentTarget.Parent
        local player = Players:GetPlayerFromCharacter(character)

        if player and character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")

            if humanoid then
                local health = math.floor(humanoid.Health)


local shield = 0

local bodyEffects = character:FindFirstChild("BodyEffects")
if bodyEffects then
    local armor = bodyEffects:FindFirstChild("Armor")
    if armor and armor.Value then
        shield = math.floor(armor.Value)
    end
end

local healthColor = "rgb(50,205,50)"
local shieldColor = "rgb(135,206,250)"

table.insert(lines,
    '<font color="rgb(255,255,255)">Health </font>' ..
    '<font color="'..healthColor..'">'..health..'</font>' ..
    '<font color="rgb(255,255,255)"> / </font>' ..
    '<font color="'..shieldColor..'">'..shield..'</font>'
)
                local name = (player.DisplayName ~= "" and player.DisplayName) or player.Name

                table.insert(lines,
                    '<font color="rgb(255,255,255)">Silent Aim </font><font color="rgb(50,205,50)">('..name..')</font>'
                )
            end
        end
    end

    if triggerEnabled and Config['Trigger Bot']['Enabled'] then
        if currentTarget then
            local character = currentTarget.Parent
            local player = Players:GetPlayerFromCharacter(character)
            if player then
                local targetName = (player.DisplayName and player.DisplayName ~= "") and player.DisplayName or player.Name
                table.insert(lines,
                    '<font color="rgb(255,255,255)">Trigger Bot </font><font color="rgb(50,205,50)">(' .. targetName .. ')</font>'
                )
            end
        end
    end

    if infRangeActive then
        table.insert(lines,
            '<font color="rgb(255,255,255)">Infinite Range</font>'
        )
    end

    if SpeedEnabled then
        table.insert(lines,
            '<font color="rgb(255,255,255)">WalkSpeed</font>'
        )
    end

    text.Text = table.concat(lines, "\n")
end)
