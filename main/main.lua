local Config = shared.Story
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local currentTarget = nil
local isLocking = false
local triggerEnabled = false
local fovBox    = nil
local fovCircle = nil
local currentFOV  = 200
local currentFOVX = 7
local currentFOVY = 7
local espLabels = {}
local SpeedEnabled = false
local BaseSpeed = 16
local lastVisibleTarget = nil
local lastTriggerClick = 0
local superJumpActive = false
local guiVisible = true
local knifedata = {}

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
    local saFOV = Config['Silent Aim']['FOV']
    if not saFOV['Enabled'] then return true end
    if not character then return false end

    local fovType  = saFOV['Type']  -- 'Circle', 'Box', '3D'
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local head     = character:FindFirstChild("Head")
    if not rootPart or not head then return false end

    if fovType == 'Circle' then
        local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
        if not onScreen then return false end
        local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
        return dist <= currentFOV

    elseif fovType == 'Box' then
        local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
        if not onScreen then return false end
        local dx = math.abs(pos.X - mousePos.X)
        local dy = math.abs(pos.Y - mousePos.Y)
        return dx <= currentFOVX and dy <= currentFOVY

    else -- '3D' — character bounding box on screen
        local headPos, headOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        local legPos,  legOn  = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
        if not headOn or not legOn then return false end
        local height  = math.abs(headPos.Y - legPos.Y)
        local width   = height / 2
        local rootPos = Camera:WorldToViewportPoint(rootPart.Position)
        local padding = 10
        return mousePos.X >= rootPos.X - width/2 - padding
            and mousePos.X <= rootPos.X + width/2 + padding
            and mousePos.Y >= headPos.Y - padding
            and mousePos.Y <= legPos.Y  + padding
    end
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

local lockedPlayer = nil

local function CheckAnti(Plr)
    if Plr.Character.HumanoidRootPart.Velocity.Y < -70 then
        return true
    elseif Plr and (Plr.Character.HumanoidRootPart.Velocity.X > 450 or Plr.Character.HumanoidRootPart.Velocity.X < -35) then
        return true
    elseif Plr and Plr.Character.HumanoidRootPart.Velocity.Y > 60 then
        return true
    elseif Plr and (Plr.Character.HumanoidRootPart.Velocity.Z > 35 or Plr.Character.HumanoidRootPart.Velocity.Z < -35) then
        return true
    else
        return false
    end
end

local function getClosestPlayerToCursor()
    local closestDist = math.huge
    local closestPlr  = nil
    for _, v in ipairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
            local screenPos, onScreen = Camera:WorldToViewportPoint(v.Character.HumanoidRootPart.Position)
            if onScreen then
                local mousePos = UserInputService:GetMouseLocation()
                local dist = (Vector2.new(mousePos.X, mousePos.Y) - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                if dist < closestDist then
                    closestPlr  = v
                    closestDist = dist
                end
            end
        end
    end
    return closestPlr
end

local function getClosestPartToCursor(Player)
    local closestPart, closestDist = nil, math.huge
    if Player.Character and Player.Character:FindFirstChild("Humanoid") and Player.Character.Humanoid.Health ~= 0 then
        for _, part in pairs(Player.Character:GetChildren()) do
            if part:IsA("BasePart") then
                local screenPos, _ = Camera:WorldToViewportPoint(part.Position)
                local mousePos = UserInputService:GetMouseLocation()
                local dist = (Vector2.new(mousePos.X, mousePos.Y) - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                if dist < closestDist and table.find(Config['Camera Lock']['MultipleTargetPart'], part.Name) then
                    closestPart = part
                    closestDist = dist
                end
            end
        end
    end
    return closestPart
end

local function GetShakedVector3(Setting)
    return Vector3.new(
        math.random(-Setting * 1e9, Setting * 1e9),
        math.random(-Setting * 1e9, Setting * 1e9),
        math.random(-Setting * 1e9, Setting * 1e9)
    ) / 1e9
end

local camVelocity = Vector3.new()
RunService.Heartbeat:Connect(function()
    if lockedPlayer and lockedPlayer.Character and lockedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local old = lockedPlayer.Character.HumanoidRootPart.Position
        task.wait(0.145)
        if lockedPlayer and lockedPlayer.Character and lockedPlayer.Character:FindFirstChild("HumanoidRootPart") then
            camVelocity = (lockedPlayer.Character.HumanoidRootPart.Position - old) / 0.145
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not Config['Camera Lock']['Enabled'] or not isLocking or not lockedPlayer then return end

    local char = lockedPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    local targetPart = char:FindFirstChild(Config['Camera Lock']['Part'])

    if not humanoid or not targetPart then return end

    local bodyEffects = char:FindFirstChild("BodyEffects")
    local koValue = bodyEffects and bodyEffects:FindFirstChild("K.O")
    if humanoid.Health < 1 or (koValue and koValue.Value) or char:FindFirstChild("GRABBING_CONSTRAINT") then
        lockedPlayer = nil
        isLocking = false
        return
    end

    local clientHumanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if clientHumanoid and clientHumanoid.Health < 1 then
        lockedPlayer = nil
        isLocking = false
        return
    end

    local isJumping = humanoid:GetState() == Enum.HumanoidStateType.Freefall
    local Position = isJumping
        and targetPart.Position + Vector3.new(0, Config['Camera Lock']['JumpOffset'], 0)
        or  targetPart.Position

    local Main
    if not CheckAnti(lockedPlayer) then
        Main = CFrame.new(Camera.CFrame.p, Position + camVelocity * Config['Camera Lock']['Prediction'] + GetShakedVector3(Config['Camera Lock']['CameraShake']))
    else
        Main = CFrame.new(Camera.CFrame.p, Position + (humanoid.MoveDirection * humanoid.WalkSpeed) * Config['Camera Lock']['Prediction'] + GetShakedVector3(Config['Camera Lock']['CameraShake']))
    end

    Camera.CFrame = Camera.CFrame:Lerp(Main, Config['Camera Lock']['Smoothing'], Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end)

if not fovBox then
    fovBox = Drawing.new("Square")
    fovBox.Visible   = false
    fovBox.Thickness = 2
    fovBox.Color     = Color3.fromRGB(255, 255, 255)
    fovBox.Filled    = false
    fovBox.Size      = Vector2.new(0, 0)
end

if not fovCircle then
    fovCircle           = Drawing.new("Circle")
    fovCircle.Visible   = false
    fovCircle.Thickness = 2
    fovCircle.Color     = Color3.fromRGB(255, 255, 255)
    fovCircle.Filled    = false
    fovCircle.NumSides  = 64
    fovCircle.Radius    = currentFOV
end

-- Updates currentFOV/X/Y based on the weapon the local player is holding
local function updateWeaponFOV()
    local saFOV   = Config['Silent Aim']['FOV']
    local wc      = saFOV['Weapon Configs']
    if not wc['Enabled'] then
        currentFOV  = saFOV['Circle']
        currentFOVX = saFOV['Box'][1]
        currentFOVY = saFOV['Box'][2]
        return
    end
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if not tool then
        currentFOV  = saFOV['Circle']
        currentFOVX = saFOV['Box'][1]
        currentFOVY = saFOV['Box'][2]
        return
    end
    local shotguns = { 'Shotgun', 'Pump', 'Spas', 'Mossberg', 'DB', 'Sawed' }
    local pistols  = { 'Pistol', 'Revolver', 'Glock', 'Silencer', 'Desert Eagle', 'Deagle' }
    local isShotgun, isPistol = false, false
    for _, kw in ipairs(shotguns) do
        if tool.Name:lower():find(kw:lower()) then isShotgun = true break end
    end
    if not isShotgun then
        for _, kw in ipairs(pistols) do
            if tool.Name:lower():find(kw:lower()) then isPistol = true break end
        end
    end
    if isShotgun then
        currentFOV  = wc['Shotguns']['Circle']
        currentFOVX = wc['Shotguns']['Box'][1]
        currentFOVY = wc['Shotguns']['Box'][2]
    elseif isPistol then
        currentFOV  = wc['Pistols']['Circle']
        currentFOVX = wc['Pistols']['Box'][1]
        currentFOVY = wc['Pistols']['Box'][2]
    else
        currentFOV  = wc['Others']['Circle']
        currentFOVX = wc['Others']['Box'][1]
        currentFOVY = wc['Others']['Box'][2]
    end
end

local function updateFOVBox()
    local saFOV = Config['Silent Aim']['FOV']
    local fovType = saFOV['Type'] -- 'Circle', 'Box', or '3D'

    -- hide both by default, show only the active type
    fovBox.Visible    = false
    fovCircle.Visible = false

    if not saFOV['Enabled'] or not saFOV['Visible'] then return end

    updateWeaponFOV()

    local mousePos = Vector2.new(Mouse.X, Mouse.Y)

    if fovType == 'Circle' then
        fovCircle.Radius   = currentFOV
        fovCircle.Position = mousePos
        fovCircle.Visible  = true
    elseif fovType == 'Box' then
        fovBox.Size     = Vector2.new(currentFOVX * 2, currentFOVY * 2)
        fovBox.Position = Vector2.new(mousePos.X - currentFOVX, mousePos.Y - currentFOVY)
        fovBox.Visible  = true
    elseif fovType == '3D' then
        -- 3D type: box follows locked target's character bounds (same as old behaviour)
        if currentTarget then
            local character = currentTarget.Parent
            if character then
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                local head     = character:FindFirstChild("Head")
                if rootPart and head then
                    local headPos, headOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    local legPos,  legOn  = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
                    if headOn and legOn then
                        local height  = math.abs(headPos.Y - legPos.Y)
                        local width   = height / 2
                        local rootPos = Camera:WorldToViewportPoint(rootPart.Position)
                        local padding = 10
                        fovBox.Size     = Vector2.new(width + padding * 2, height + padding * 2)
                        fovBox.Position = Vector2.new(rootPos.X - width/2 - padding, headPos.Y - padding)
                        fovBox.Visible  = true
                    end
                end
            end
        end
    end
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
    
    if Config['Silent Aim']['FOV']['Enabled'] and not isMouseInFOV(character) then return end
    
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

local SilentTracked  = {}
local SilentTimes    = {}
local SilentState    = { Current = nil, Tick = nil }

local function SilentFilter(obj)
    if string.find(obj.Name, 'Gun') then return end
    if obj:IsA('BasePart') or obj:IsA('MeshPart') then return true end
end

local function SilentGetAllBodyParts(character)
    local closestDist = math.huge
    local bodyPart    = nil
    if character and character:GetChildren() then
        for _, part in next, character:GetChildren() do
            if SilentFilter(part) then
                local pos  = Camera:WorldToScreenPoint(part.Position)
                local dist = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(pos.X, pos.Y)).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    bodyPart    = part
                end
            end
        end
    end
    return bodyPart
end

local function SilentGetNearestPointOnCharacter(character, scale, maxDist)
    local part = SilentGetAllBodyParts(character)
    if not part then return nil end

    local clamp = math.clamp
    local mousePoint = UserInputService:GetMouseLocation()
    local pointRay   = Camera:ViewportPointToRay(mousePoint.X, mousePoint.Y)
    local intersect  = pointRay.Origin + pointRay.Direction * pointRay.Direction:Dot(part.Position - pointRay.Origin)
    local transform  = part.CFrame:PointToObjectSpace(intersect)
    local reduced    = (part.Size - (part.Size * (scale == 'Dynamic' and 0 or 0) / 100))
    local half       = reduced / 2

    return part.CFrame * Vector3.new(
        clamp(transform.X, -half.X, half.X),
        clamp(transform.Y, -half.Y, half.Y),
        clamp(transform.Z, -half.Z, half.Z)
    )
end

local function SilentGetVelocity(rootPart)
    local pos  = rootPart.Position
    local tick = tick()
    table.insert(SilentTracked, pos)
    table.insert(SilentTimes,   tick)
    if #SilentTracked >= 3 then
        local n  = #SilentTracked
        local p1, p2, p3 = SilentTracked[n-2], SilentTracked[n-1], SilentTracked[n]
        local t1, t2, t3 = SilentTimes[n-2],   SilentTimes[n-1],   SilentTimes[n]
        if (t2 - t1) ~= 0 and (t3 - t2) ~= 0 then
            local v1 = (p2 - p1) / (t2 - t1)
            local v2 = (p3 - p2) / (t3 - t2)
            return v2
        end
    end
    return rootPart.Velocity or Vector3.new()
end

local function SilentGetEndpoint(velocity, position, prediction, adjustment)
    local camCF    = Camera.CFrame
    local relVel   = camCF:VectorToObjectSpace(velocity)
    local predVel  = adjustment and adjustment[1]
        and relVel * prediction * adjustment[2]
        or  relVel * prediction
    return position + camCF:VectorToWorldSpace(predVel)
end

local function SilentUpdatePing()
    if not Config['Silent Aim']['Ping Prediction']['Enabled'] then return end
    local ok, raw = pcall(function()
        return game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValueString()
    end)
    if not ok then return end
    local ping = tonumber(string.split(raw, '(')[1])
    if not ping then return end
    local pp = Config['Silent Aim']['Ping Prediction']
    if    ping < 30  then Config['Silent Aim']['Prediction'] = pp['20-30']
    elseif ping < 40  then Config['Silent Aim']['Prediction'] = pp['30 40']
    elseif ping < 50  then Config['Silent Aim']['Prediction'] = pp['40 50']
    elseif ping < 60  then Config['Silent Aim']['Prediction'] = pp['50 60']
    elseif ping < 70  then Config['Silent Aim']['Prediction'] = pp['60 70']
    elseif ping < 80  then Config['Silent Aim']['Prediction'] = pp['70 80']
    elseif ping < 90  then Config['Silent Aim']['Prediction'] = pp['80 90']
    elseif ping < 100 then Config['Silent Aim']['Prediction'] = pp['90 100']
    elseif ping < 110 then Config['Silent Aim']['Prediction'] = pp['100 110']
    elseif ping < 120 then Config['Silent Aim']['Prediction'] = pp['110 120']
    elseif ping < 130 then Config['Silent Aim']['Prediction'] = pp['120 130']
    elseif ping < 140 then Config['Silent Aim']['Prediction'] = pp['130 140']
    else                    Config['Silent Aim']['Prediction'] = pp['140 150']
    end
end

local function SilentGetHitChance()
    local cfg = Config['Silent Aim']['Hit Chance']
    return (math.floor(math.random() * 100) / 100) <= (cfg['HitChance'] / 100) - cfg['Miss Chance']
end

local function SilentGetHitPosition(player)
    local character = player.Character
    if not character then return nil end
    local humanoid  = character:FindFirstChild('Humanoid')
    local rootPart  = character:FindFirstChild('HumanoidRootPart')
    if not humanoid or not rootPart then return nil end

    local sa       = Config['Silent Aim']
    local mult     = sa['Prediction']
    local power    = sa['Prediction Adjustment']
    if power ~= 1 then mult = mult * (1 - (power - 1) / 2) end

    if sa['Prediction Points']['Enabled'] then
        local nearest = SilentGetAllBodyParts(character)
        if nearest then
            local pm = sa['Prediction Points']['Hit Points'][nearest.Name]
            if pm then mult = Vector3.new(pm, pm, pm) end
        end
    end

    local hitTarget = sa['Hit Location']['Hit Target']
    local hitPos

    if hitTarget == 'Nearest Point' then
        local np = SilentGetNearestPointOnCharacter(character, sa['Hit Location']['Point Scale'], sa['Hit Location']['Max Nearest Point'])
        hitPos   = np and Vector3.new(np.X, np.Y, np.Z) or rootPart.Position
    elseif hitTarget == 'Nearest Part' then
        local np = SilentGetAllBodyParts(character)
        hitPos   = np and np.Position or rootPart.Position
    else
        hitPos   = rootPart.Position
    end

    local velocity = SilentGetVelocity(rootPart)

    local override = sa['OverrideYAxis']
    if type(mult) == 'number' then
        if     override == 'Full'    then mult = Vector3.new(mult, 0, mult)
        elseif override == 'Partial' then mult = Vector3.new(mult, rootPart.Velocity.Y / 5, mult)
        else                              mult = Vector3.new(mult, mult, mult)
        end
    end

    return SilentGetEndpoint(velocity, hitPos, mult, sa['3D Adjustment'])
end

local MainEvent = game:GetService('ReplicatedStorage'):FindFirstChild('MainEvent')
local SilentUpdater = 'UpdateMousePosI2'

local function connectSilentAim(tool)
    if not tool:IsA('Tool') then return end
    if not tool:FindFirstChild('Ammo') then return end
    tool.Activated:Connect(function()
        if not Config['Silent Aim']['Enabled'] then return end
        if not currentTarget then return end
        local character = currentTarget.Parent
        if not character then return end
        local player = Players:GetPlayerFromCharacter(character)
        if not player then return end
        if isPlayerKnockedOrKO(player) then return end
        if not SilentGetHitChance() then return end
        SilentUpdatePing()
        local hit = SilentGetHitPosition(player)
        if not hit then return end
        if MainEvent then
            MainEvent:FireServer(SilentUpdater, hit)
            if Config['Double Tap']['Enabled'] then
                task.delay(Config['Double Tap']['Delay'], function()
                    if currentTarget and currentTarget.Parent then
                        local h2 = SilentGetHitPosition(player)
                        if h2 then MainEvent:FireServer(SilentUpdater, h2) end
                    end
                end)
            end
        end
    end)
end

if LocalPlayer.Character then
    for _, v in pairs(LocalPlayer.Character:GetChildren()) do connectSilentAim(v) end
end
if LocalPlayer.Character then
    LocalPlayer.Character.ChildAdded:Connect(connectSilentAim)
end
LocalPlayer.CharacterAdded:Connect(function(char)
    char.ChildAdded:Connect(connectSilentAim)
end)

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
    
    if SpeedEnabled then
        local character = LocalPlayer.Character
        local humanoid  = character and character:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health > 0 then
            local speed = Config['Speed']['Normal']['Multiplier']
            local lh    = Config['Speed']['Low Health']
            local rl    = Config['Speed']['Reloading']
            local sh    = Config['Speed']['Shooting']
            if lh['Enabled'] and humanoid.Health <= lh['Threshold'] then
                speed = lh['Multiplier']
            elseif rl['Enabled'] then
                local tool = character:FindFirstChildOfClass('Tool')
                if tool and tool:FindFirstChild('Reloading') and tool.Reloading.Value then
                    speed = rl['Multiplier']
                end
            elseif sh['Enabled'] then
                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    speed = sh['Multiplier']
                end
            end
            humanoid.WalkSpeed = speed
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
    

end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Target Lock']['Key']] then
        local mode = Config['Keybinds']['Target Lock']['Mode']
        
        if mode == 'Toggle' then
            if isLocking then
                isLocking = false
                currentTarget = nil
                lastVisibleTarget = nil
                lockedPlayer = nil
            else
                lockedPlayer = getClosestPlayerToCursor()
                if Config['Settings']['Target Aim'] then
                    local target = findClosestTarget()
                    if target then
                        currentTarget = target
                        lastVisibleTarget = target
                    end
                end
                if lockedPlayer then
                    isLocking = true
                end
            end
        elseif mode == 'Hold' then
            lockedPlayer = getClosestPlayerToCursor()
            if Config['Settings']['Target Aim'] then
                local target = findClosestTarget()
                if target then
                    currentTarget = target
                    lastVisibleTarget = target
                end
            end
            if lockedPlayer then
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
local utility = {}
utility.get_gun = function()
    local character = LocalPlayer.Character
    if not character then return nil end
    for _, tool in next, character:GetChildren() do
        if tool:IsA("Tool") and tool:FindFirstChild("Ammo") then return tool end
    end
end

getgenv().is_firing = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local gun = utility.get_gun()
        if Config['Rapid Fire']['Enabled'] and gun and not is_firing then
            is_firing = true
            task.spawn(function()
                while is_firing do
                    local currentGun = utility.get_gun()
                    if not currentGun then break end

                    if Config['Rapid Fire']['Specific Weapons']['Enabled'] then
                        local valid = false
                        for _, wName in pairs(Config['Rapid Fire']['Specific Weapons']['Weapons']) do
                            if currentGun.Name == wName then
                                valid = true
                                break
                            end
                        end
                        if not valid then
                            task.wait(Config['Rapid Fire']['Delay'])
                            continue
                        end
                    end

                    currentGun:Activate()
                    task.wait(Config['Rapid Fire']['Delay'])
                end
            end)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        is_firing = false
    end
end)

local infRangeActive = false

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Infinite Range']] then
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

-- ── Prada Skin Changer ──
shared.skin_modules = shared.skin_modules or {}
shared.skin_modules["[Revolver]"] = shared.skin_modules["[Revolver]"] or {}
shared.skin_modules["[Silencer]"] = shared.skin_modules["[Silencer]"] or {}
shared.skin_modules["[Glock]"] = shared.skin_modules["[Glock]"] or {}
shared.skin_modules["[AK47]"] = shared.skin_modules["[AK47]"] or {}
shared.skin_modules["[AR]"] = shared.skin_modules["[AR]"] or {}
shared.skin_modules["[AUG]"] = shared.skin_modules["[AUG]"] or {}
shared.skin_modules["[DrumGun]"] = shared.skin_modules["[DrumGun]"] or {}
shared.skin_modules["[Flintlock]"] = shared.skin_modules["[Flintlock]"] or {}
shared.skin_modules["[LMG]"] = shared.skin_modules["[LMG]"] or {}
shared.skin_modules["[P90]"] = shared.skin_modules["[P90]"] or {}
shared.skin_modules["[Rifle]"] = shared.skin_modules["[Rifle]"] or {}
shared.skin_modules["[SMG]"] = shared.skin_modules["[SMG]"] or {}
shared.skin_modules["[Shotgun]"] = shared.skin_modules["[Shotgun]"] or {}
shared.skin_modules["[TacticalShotgun]"] = shared.skin_modules["[TacticalShotgun]"] or {}
shared.skin_modules["[SilencerAR]"] = shared.skin_modules["[SilencerAR]"] or {}
shared.skin_modules["[Flamethrower]"] = shared.skin_modules["[Flamethrower]"] or {}
shared.skin_modules["[RPG]"] = shared.skin_modules["[RPG]"] or {}
shared.skin_modules["[Bat]"] = shared.skin_modules["[Bat]"] or {}
shared.skin_modules["[Knife]"] = shared.skin_modules["[Knife]"] or {}
shared.skin_modules["[Mask]"] = shared.skin_modules["[Mask]"] or {}
shared.skin_modules["[Wallet]"] = shared.skin_modules["[Wallet]"] or {}
shared.skin_modules["[Vehicle]"] = shared.skin_modules["[Vehicle]"] or {}
shared.skin_modules["[House]"] = shared.skin_modules["[House]"] or {}

local v1 = { Color3.new(1, 0.560784, 0.956863), ColorSequence.new(Color3.new(1, 0.560784, 0.956863), Color3.new(1, 0.027451, 0.839216)) }
    local v2 = { Color3.new(1, 0.027451, 0.839216), ColorSequence.new(Color3.new(0.0588235, 0.0313725, 0.054902), Color3.new(1, 0.027451, 0.839216)) }
    local v3 = { Color3.new(1, 0, 0.4), ColorSequence.new(Color3.new(0.0588235, 0.0313725, 0.054902), Color3.new(1, 0.027451, 0.839216)) }
    local v4 = { Color3.new(0.560784, 0.470588, 1), ColorSequence.new(Color3.new(0.560784, 0.470588, 1), Color3.new(0.576471, 0.380392, 1)) }
    local v5 = { Color3.new(0, 0.270588, 0.67451), ColorSequence.new(Color3.new(0, 0.192157, 0.611765), Color3.new(0, 0.486275, 0.811765)) }
    local v6 = { Color3.new(0.00392157, 0.486275, 1), ColorSequence.new(Color3.new(0, 0.235294, 0.611765), Color3.new(1, 0.188235, 0.129412)) }
    local v7 = { Color3.new(1, 0.666667, 0), ColorSequence.new(Color3.new(1, 0.666667, 0), Color3.new(1, 0.286275, 0.0470588)) }
    local v8 = { Color3.new(0, 0.482353, 1), ColorSequence.new(Color3.new(0, 0.482353, 1), Color3.new(1, 0.333333, 0)) }
    local v9 = { Color3.new(1, 0.333333, 1), ColorSequence.new(Color3.new(1, 0.333333, 1), Color3.new(0.666667, 0.333333, 1)) }
    local v10 = { Color3.new(1, 0.333333, 1), ColorSequence.new(Color3.new(1, 0.333333, 1), Color3.new(0.666667, 0.462745, 0.32549)) }
    local v11 = { Color3.new(0.164706, 0.333333, 0.0862745), ColorSequence.new(Color3.new(1, 0.94902, 0.862745), Color3.new(0.196078, 0.333333, 0.0823529)) }
    local v12 = { Color3.new(0, 0.47451, 0.709804), ColorSequence.new(Color3.new(1, 0.94902, 0.862745), Color3.new(0, 0.47451, 0.713725)) }
    local v13 = { Color3.new(0, 0.984314, 1), ColorSequence.new(Color3.new(0, 1, 1), Color3.new(0, 1, 0.701961)) }
    local v14 = { Color3.new(1, 1, 1), ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.705882, 0.705882, 0.705882)) }
    local v15 = { Color3.new(1, 0.329412, 0.741176), ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 0, 0)),
            ColorSequenceKeypoint.new(0.14285714285714285, Color3.new(1, 0.666667, 0)),
            ColorSequenceKeypoint.new(0.2857142857142857, Color3.new(1, 1, 0)),
            ColorSequenceKeypoint.new(0.42857142857142855, Color3.new(0.333333, 1, 0)),
            ColorSequenceKeypoint.new(0.5714285714285714, Color3.new(0, 0.333333, 1)),
            ColorSequenceKeypoint.new(0.7142857142857143, Color3.new(0.666667, 0.333333, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 0.333333, 1))
        }) }
    local v16 = { Color3.new(1, 1, 1), ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.14285714285714285, Color3.new(1, 0, 0)),
            ColorSequenceKeypoint.new(0.2857142857142857, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.42857142857142855, Color3.new(1, 0, 0)),
            ColorSequenceKeypoint.new(0.5714285714285714, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.7142857142857143, Color3.new(1, 0, 0)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
        }) }
    local v17 = { Color3.new(0, 1, 0.498039), ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0, 1, 0.498039)),
            ColorSequenceKeypoint.new(0.14285714285714285, Color3.new(0, 0.223529, 0.109804)),
            ColorSequenceKeypoint.new(0.2857142857142857, Color3.new(0, 1, 0.498039)),
            ColorSequenceKeypoint.new(0.42857142857142855, Color3.new(0, 0.223529, 0.109804)),
            ColorSequenceKeypoint.new(0.5714285714285714, Color3.new(0, 1, 0.498039)),
            ColorSequenceKeypoint.new(0.7142857142857143, Color3.new(0, 0.223529, 0.109804)),
            ColorSequenceKeypoint.new(1, Color3.new(0, 1, 0.498039))
        }) }
    local v18 = { Color3.new(0.666667, 0, 1), ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.14285714285714285, Color3.new(0.666667, 0, 1)),
            ColorSequenceKeypoint.new(0.2857142857142857, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.42857142857142855, Color3.new(0.666667, 0, 1)),
            ColorSequenceKeypoint.new(0.5714285714285714, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.7142857142857143, Color3.new(0.666667, 0, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
        }) }
    local v19 = { Color3.new(0, 1, 1), ColorSequence.new(Color3.new(0, 1, 1), Color3.new(0.666667, 1, 1)) }
    local v20 = { Color3.new(0.415686, 0, 1), ColorSequence.new(Color3.new(0.431373, 0.0235294, 1), Color3.new(0.54902, 0, 1)) }
    local v21 = { Color3.new(0, 0, 0), ColorSequence.new(Color3.new(0, 0.101961, 0.101961), Color3.new(0.113725, 0.113725, 0.113725)) }
    local v22 = { Color3.new(0, 1, 0.498039), ColorSequence.new(Color3.new(0, 1, 0.498039), Color3.new(0, 0.729412, 0.352941)) }
    local v23 = { Color3.new(1, 1, 0), ColorSequence.new(Color3.new(1, 1, 0), Color3.new(1, 0.85098, 0.00784314)) }
    local v24 = { Color3.new(0.282353, 0.792157, 0.945098), ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0.164706, 0.890196, 1)),
            ColorSequenceKeypoint.new(0.25, Color3.new(0.27451, 1, 0.164706)),
            ColorSequenceKeypoint.new(0.5, Color3.new(0.658824, 0.219608, 0.658824)),
            ColorSequenceKeypoint.new(1, Color3.new(0.341176, 1, 0.976471))
        }) }
    local v25 = { Color3.new(0.917647, 0, 0), ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 0, 0)),
            ColorSequenceKeypoint.new(0.25, Color3.new(0.615686, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.new(0.32549, 0, 0)),
            ColorSequenceKeypoint.new(1, Color3.new(0.196078, 0, 0))
        }) }
    local v26 = { Color3.new(1, 0.690196, 0.882353), ColorSequence.new(Color3.new(1, 0.690196, 0.882353), Color3.new(1, 0.929412, 0.964706)) }
    local v27 = { Color3.new(1, 0.666667, 0), ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(0, 1, 0)), ColorSequenceKeypoint.new(0.5, Color3.new(0.666667, 0.333333, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 0.666667, 0)) }) }
    local v28 = { Color3.new(1, 0, 0), ColorSequence.new(Color3.new(1, 0, 0), Color3.new(1, 1, 1)) }
    local v29 = { Color3.new(1, 0, 0), ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0.74902, 0, 0)),
            ColorSequenceKeypoint.new(0.25, Color3.new(0.133333, 0.133333, 0.133333)),
            ColorSequenceKeypoint.new(0.5, Color3.new(0.486275, 0.243137, 0.729412)),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 0))
        }) }
    local v30 = { Color3.new(1, 0.666667, 0), ColorSequence.new(Color3.new(1, 1, 0), Color3.new(0.109804, 0.317647, 1)) }
    local v31 = { Color3.new(0.235294, 1, 0), ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 1, 0)) }
    local v32 = { Color3.new(0.752941, 0.294118, 0.796078), ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(0.501961, 0.760784, 0.862745)), ColorSequenceKeypoint.new(0.5, Color3.new(0.823529, 0.839216, 0.870588)), ColorSequenceKeypoint.new(1, Color3.new(0.776471, 0.458824, 0.584314)) }) }
    local v33 = { Color3.new(0.333333, 1, 0.498039), ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(0.333333, 1, 0.498039)), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 0)), ColorSequenceKeypoint.new(1, Color3.new(1, 0, 1)) }) }
    local v34 = { Color3.new(1, 1, 0), ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 0)), ColorSequenceKeypoint.new(0.5, Color3.new(1, 0.333333, 1)), ColorSequenceKeypoint.new(1, Color3.new(0.333333, 0.666667, 1)) }) }
    local v35 = { Color3.new(0.666667, 0.666667, 1), ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(0.666667, 0.666667, 1)), ColorSequenceKeypoint.new(0.5, Color3.new(0.666667, 0.333333, 1)), ColorSequenceKeypoint.new(1, Color3.new(0.333333, 0.333333, 1)) }) }
    local v36 = { Color3.new(1, 0.372549, 0.0588235), ColorSequence.new(Color3.new(1, 0.333333, 0), Color3.new(0.8, 0.690196, 0.0666667)) }
    local v37 = { Color3.new(0.45098, 0, 1), ColorSequence.new(Color3.new(0.501961, 0, 1), Color3.new(1, 0, 0.298039)) }
    local v38 = { Color3.new(0.831373, 1, 0), ColorSequence.new(Color3.new(0.831373, 1, 0), Color3.new(0.945098, 0.839216, 0.231373)) }
    local v39 = { Color3.new(0.643137, 0.952941, 1), ColorSequence.new(Color3.new(0.752941, 0.976471, 1), Color3.new(0.196078, 0.945098, 0.882353)) }
    local v40 = { Color3.new(0.133333, 0.133333, 0.133333), ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(0.133333, 0.133333, 0.133333)), ColorSequenceKeypoint.new(0.5, Color3.new(0.972549, 0.203922, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) }) }
    local v41 = { Color3.new(0.133333, 0.133333, 0.133333), ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(0, 1, 0.498039)), ColorSequenceKeypoint.new(0.5, Color3.new(0, 1, 0.498039)), ColorSequenceKeypoint.new(1, Color3.new(1, 0, 0.498039)) }) }
    shared.skin_modules = {}
    local v43 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12110413906",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Testing"] = {
            ["DisplayName"] = "N/A",
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Testing,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0, 0, 0),
            ["BorderColor"] = { Color3.new(0.945098, 1, 0.882353), ColorSequence.new(Color3.new(0.831373, 1, 0.756863), Color3.new(0.890196, 0.737255, 0.431373)) }
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.RevolverGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.0000152587891, 0, 0, 1, 0, 8.74227766e-8, 0, 1, 0, -8.74227766e-8, 0, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8174665752",
            ["Rarity"] = "Common"
        },
        ["Battleworn Lilac"] = {
            ["TextureID"] = "rbxassetid://8175141275",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://8175126370",
            ["Rarity"] = "Common"
        },
        ["Battleworn Yellowish"] = {
            ["TextureID"] = "rbxassetid://8175111007",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8174703251",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8174725170",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8174602579",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8174185468",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8174245185",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8174472966",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8174086219",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8173928665",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8173955378",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9370252940",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9370759030",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9378802766",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9370655779",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9370881350",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9381169424",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9381205789",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9379588832",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9381087467",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9381241993",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9367918526",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9380928144",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9370936730",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9370404463",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12804964131",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Golden Age"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.GoldenAge.Revolver,
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(0.0295257568, 0.0725820661, -0.000946044922, 1, -4.89858741e-16, -7.98081238e-23, 4.89858741e-16, 1, 3.2584137e-7, -7.98081238e-23, -3.2584137e-7, 1),
            ["Crate"] = 999
        },
        ["Web-Hero II"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.HERO.HeroWeb2,
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(-0.0891418457, -0.0215809345, -0.0041809082, -1.99520325e-23, -1.62920685e-7, 1, 2.44929371e-16, 1, 1.62920685e-7, -1, 2.44929371e-16, 1.99520294e-23),
            ["BorderColor"] = v29,
            ["Crate"] = 999
        },
        ["Web-Hero III"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.HERO.HeroWeb3,
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(-0.0891418457, -0.0215809345, -0.0041809082, -1.99520325e-23, -1.62920685e-7, 1, 2.44929371e-16, 1, 1.62920685e-7, -1, 2.44929371e-16, 1.99520294e-23),
            ["BorderColor"] = v29,
            ["Crate"] = 999
        },
        ["Dragon"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Dragon.DragonRev,
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(0.0384216309, 0.0450432301, -0.000671386719, 1.87045402e-31, 4.21188801e-16, -0.99999994, 1.77635684e-15, 1, -4.21188827e-16, 1, 1.77635684e-15, -1.87045413e-31),
            ["Crate"] = 999
        },
        ["Heaven"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Heaven.Revolver,
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(-0.0829315186, -0.0831851959, -0.00296020508, -0.999999881, 2.94089277e-17, 8.27179774e-25, -2.94089277e-17, 0.999999881, 6.85215614e-16, 8.27179922e-25, -6.85215667e-16, -1),
            ["Crate"] = 999
        },
        ["Thunder II"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Stars.RevolverII,
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(-0.0765533447, 0.0790345669, 0.00277709961, 1.99520325e-23, 1.62920685e-7, -1, 2.44929371e-16, 1, 1.62920685e-7, 1, -2.44929371e-16, -1.99520294e-23),
            ["Crate"] = 999
        },
        ["Void"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Void.rev,
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(-0.00503540039, 0.0082899332, -0.00164794922, 0, 0, -1, 0, 1, 0, 1, 0, 0),
            ["Crate"] = 999,
            ["BorderColor"] = v20
        },
        ["Raygun"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Raygun.rev,
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(-0.130737305, -0.0714715123, 0.00900268555, -1, 0, 0, 0, 1, 0, 0, 0, -1),
            ["Crate"] = 999
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11691734370",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11691558717",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11691406715",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698051393",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[Revolver]"] = v43
    local v44 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12110731451",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.DrumgunGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.0000114440918, 0, 0, 1, 0, 8.74227766e-8, 0, 1, 0, -8.74227766e-8, 0, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8185356861",
            ["Rarity"] = "Common"
        },
        ["Battleworn Silver"] = {
            ["TextureID"] = "rbxassetid://8185395568",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://8185380857",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8185410368",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8185370548",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8200161894",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8185515967",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8185562852",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8185721916",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8185793923",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8185845811",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8186385983",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8186168230",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9381458764",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9381540698",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9381571514",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9381523079",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9381562454",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9381636386",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9381646935",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9381588907",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9381609962",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9381654654",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9381379210",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9381601709",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9381577172",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9381496666",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12805073311",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698166618",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698163446",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698156920",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698171250",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[DrumGun]"] = v44
    local v45 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12110803753",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.SMGGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(-0.0000114440918, 1.78813934e-7, -0.0263671875, 1, 0, 0, 0, 1, 0, 0, 0, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8199419655",
            ["Rarity"] = "Common"
        },
        ["Battleworn Silver"] = {
            ["TextureID"] = "rbxassetid://8199458294",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://8199451863",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8199473055",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8199431005",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8199477007",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8199481436",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8199502936",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8199514095",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8199653818",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8199866150",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8199875638",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8199883519",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9383258180",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9387602769",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9387673853",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9387598203",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9387607679",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9387692876",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9387695275",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9387676494",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9387686285",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9387705178",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9383235024",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9387681455",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9387614760",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9387593777",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12805137874",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698181071",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698185046",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698177379",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698207341",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[SMG]"] = v45
    local v46 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12111111962",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Fish"] = {
            ["TextureID"] = "rbxassetid://11990563033",
            ["Rarity"] = "Exclusive"
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.ShotgunGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.0000305175781, 0.199999928, 3.81469727e-6, -1, 0, -4.37113883e-8, 0, 1, 0, 4.37113883e-8, 0, -1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8200212723",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://8200231458",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8200235920",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8200227785",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8200239202",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8200263229",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8200281207",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8200452630",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8200567741",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8200611946",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8200647420",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8200657428",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9387823994",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9387838948",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9387936870",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9387835160",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9387930616",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9387966449",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9387971280",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9387941195",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9387953763",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9387975634",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9387819403",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9387945198",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9387933478",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9387831940",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12805506654",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698286812",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698229652",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698222649",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698280015",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[Shotgun]"] = v46
    local v47 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12115564779",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.RifleGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.000244140625, -0.100267321, -0.0000915527344, 1, 0, 0, 0, 1, 0, 0, 0, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://11005121335",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://11004990352",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://11005088938",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://11005107116",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://11005005067",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://11004865054",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://11003890838",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://11003588453",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://11003474703",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://11002735610",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://11002464706",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://11002383233",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://11005316501",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://11005598085",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://11005666467",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://11005542274",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://11005631418",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://11005808616",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://11005835348",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://11005735080",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://11005714634",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://11005857694",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://11005271062",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://11005757368",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://11005648299",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://11005464864",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12806251553",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698600572",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698597549",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698595906",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698603515",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[Rifle]"] = v47
    local v48 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12115525020",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.TacticalShotgunGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(-0.148262024, 0, 0, 1, 0, 8.74227766e-8, 0, 1, 0, -8.74227766e-8, 0, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://9202807512",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://9202860371",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://9202877794",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://9202833643",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://9202903532",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://9203188586",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://9203220557",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://9203241308",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://9203412138",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://9203513612",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://9203641766",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://9203647967",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9402233425",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9402269596",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9402283247",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9402258939",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9402275753",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9402318974",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9402324986",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9402291717",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9402301039",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9402335893",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9402226585",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9402295362",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9402279010",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9402244359",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12806214848",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Void"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Void.tact,
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(0.0505371094, -0.0487936139, 0.00158691406, 0, 0, 1, 0, 1, 0, -1, 0, 0),
            ["Crate"] = 999,
            ["BorderColor"] = v20
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698587778",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698585498",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698582341",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698590246",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[TacticalShotgun]"] = v48
    local v49 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12114648605",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.RPGGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.000122070312, 0.0625389814, 0.00672149658, 1, 0, -8.74227766e-8, 5.00610797e-21, 1, 5.72632016e-14, 8.74227766e-8, 5.72632016e-14, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8200732479",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://8200751938",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8200757388",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8200745198",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8200764100",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8200822253",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8200850424",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8200866435",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8200890494",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8201028034",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8201055935",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8201059812",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9399823174",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9399837867",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9399845630",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9399835270",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9399840628",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9399855314",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9399857061",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9399847783",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9399852838",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9399859827",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9399820193",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9399850204",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9399842353",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9399831924",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12805600861",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698310571",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698306888",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698303361",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698313175",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[RPG]"] = v49
    local v50 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12114736740",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.P90Ghost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.0000686645508, 0.000218153, 0.0000305175781, 1, 0, 0, 0, 1, 0, 0, 0, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8205069485",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://8205089535",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8205123590",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8205076879",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8205144857",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8205219107",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8205257625",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8205265666",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8205325456",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8205367433",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8205381104",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8205397990",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9399869525",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9399883452",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9399890039",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9399880968",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9399886010",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9399899904",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9399901738",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9399892203",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9399897656",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9399907224",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9399866877",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9399894480",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9399887933",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9399878713",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12805653252",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698324470",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698322674",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698320640",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698328153",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[P90]"] = v50
    local v51 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12114906111",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.LMGGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.374502182, -0.25, -0.25, -1, 0, -1.31134158e-7, 0, 1, 0, 1.31134158e-7, 0, -1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8205498477",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://8205510598",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8205517033",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8205505332",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8205523035",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8205558639",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8205575208",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8205585472",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8205620131",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8205697183",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8205713344",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8205719479",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9400157516",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9400165161",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9400173576",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9400162704",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9400167413",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9400184078",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9400186284",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9400176153",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9400182123",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9400188666",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9399928853",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9400178599",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9400170566",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9400160302",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12805709973",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698342231",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698339260",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698336424",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698345931",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[LMG]"] = v51
    local v52 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12114451976",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.FlamethrowerGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(-0.219947815, 0.339559376, 0.000274658203, 1, 0, 0, 0, 1, 0, 0, 0, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8205935393",
            ["Rarity"] = "Common"
        },
        ["Battleworn Silver"] = {
            ["TextureID"] = "rbxassetid://8205943484",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8205948312",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8205939544",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8206047590",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8206051335",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8213235948",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8206268974",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8206347935",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8206488418",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8206707126",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8208010648",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9400231739",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9400536953",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9400569162",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9400520290",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9400550556",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9400770169",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9400778632",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9400576948",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9400735643",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9400780662",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9400200285",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9400582867",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9400558000",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9400503673",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12805759408",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698374020",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698368556",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698359790",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698381683",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[Flamethrower]"] = v52
    local v53 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12114956009",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.DoubleBGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.0250015259, -0.077037394, 0, 1, 0, 0, 0, 0.999998331, 0, 0, 0, 1),
            ["BorderColor"] = v4
        },
        ["DH-Stars"] = {
            ["TextureID"] = "rbxassetid://9379871038",
            ["Rarity"] = "Exclusive"
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8212275962",
            ["Rarity"] = "Common"
        },
        ["Battleworn Silver"] = {
            ["TextureID"] = "rbxassetid://8212286567",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8212282697",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8212279414",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8212290557",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8212316849",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8213280304",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8212323155",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8212348203",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8212375936",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8212384179",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8212394280",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9401115062",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9401429541",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9401449568",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9401418244",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9401436298",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9401505985",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9401510373",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9401454599",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9401462565",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9401514811",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9400904953",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9401457713",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9401441647",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9401416743",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Fish"] = {
            ["TextureID"] = "rbxassetid://11982219253",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12805836044",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Golden Age"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.GoldenAge["Double Barrel"],
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(-0.00664520264, 0.0538104773, 0.0124816895, -1, 4.89858741e-16, 7.98081238e-23, 4.89858741e-16, 1, 3.2584137e-7, 7.98081238e-23, 3.2584137e-7, -1),
            ["Crate"] = 999
        },
        ["Dragon"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Dragon.DBDragon,
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(-0.123794556, 0.0481165648, 0.00048828125, 7.14693442e-7, 3.13283705e-10, 1, -4.56658222e-9, 1, -3.13281678e-10, -1, -4.56658533e-9, 7.14693442e-7),
            ["Crate"] = 999
        },
        ["Heaven"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Heaven.DB,
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(-0.0303955078, 0.022110641, 0.00296020508, -0.999997139, -7.05812226e-16, 7.85568618e-30, 7.05812226e-16, 0.999997139, -2.06501178e-14, 6.44518474e-30, 2.06501042e-14, -0.999999046),
            ["Crate"] = 999
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698405675",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698398802",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698395299",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698411164",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[Double-Barrel SG]"] = v53
    local v54 = {
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://16689483120",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://16689465255",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Light Camo"] = {
            ["TextureID"] = "rbxassetid://16689491845",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://16677029205",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Battleworn Blue"] = {
            ["TextureID"] = "rbxassetid://16677041651",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://16677121846",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://16677050965",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://16677013306",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://16677055685",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Black White"] = {
            ["TextureID"] = "rbxassetid://16677918724",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Rainbow"] = {
            ["TextureID"] = "rbxassetid://16677272911",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://16677149439",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://16677910627",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://16677229978",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://16689431385",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://16689527835",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://16677186951",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://16677641392",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://16689348102",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://16689728694",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        }
    }
    shared.skin_modules["[Drum-Shotgun]"] = v54
    local v55 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12115024879",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.GlockGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0, 0, -0.200004578, 1, 0, 4.37113883e-8, 0, 1, 0, -4.37113883e-8, 0, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8212444417",
            ["Rarity"] = "Common"
        },
        ["Battleworn Lilac"] = {
            ["TextureID"] = "rbxassetid://8212451534",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8212455391",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8212448336",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8212459430",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8212481264",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8213282241",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8212487510",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8212534706",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8212630941",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8212637463",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8212667115",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9401623473",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9401696528",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9401719450",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9401683246",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9401714006",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9401747845",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9401750648",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9401723658",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9401734730",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9401756373",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9401611034",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9401727978",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9401709916",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9401670081",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12805896214",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698428136",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698455542",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698421659",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698450494",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[Glock]"] = v55
    local v56 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12115024879",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.GlockGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0, 0, -0.200004578, 1, 0, 4.37113883e-8, 0, 1, 0, -4.37113883e-8, 0, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8212444417",
            ["Rarity"] = "Common"
        },
        ["Battleworn Lilac"] = {
            ["TextureID"] = "rbxassetid://8212451534",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8212455391",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8212448336",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8212459430",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8212481264",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8213282241",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8212487510",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8212534706",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8212630941",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8212637463",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8212667115",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9401623473",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9401696528",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9401719450",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9401683246",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9401714006",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9401747845",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9401750648",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9401723658",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9401734730",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9401756373",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9401611034",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9401727978",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9401709916",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9401670081",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12805896214",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698428136",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698455542",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698421659",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698450494",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[Silencer]"] = v56
    local v57 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12115122137",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.AUGGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(-7.62939453e-6, 0.0499991775, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8212698585",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://8212702975",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8212708853",
            ["Rarity"] = "Common"
        },
        ["Battleworn Silver"] = {
            ["TextureID"] = "rbxassetid://8212718221",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8212740914",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8212725557",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8212747403",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8213284596",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8212749719",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8212763285",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8212784351",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8212802637",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8212809463",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9401790525",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9401825845",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9401844534",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9401812015",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9401836335",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9401873003",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9401877388",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9401850278",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9401860175",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9401880668",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9401784838",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9401855319",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9401832956",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9401802930",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12806062046",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698517061",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698514224",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698511107",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698520432",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[AUG]"] = v57
    local v58 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12115236401",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.ARGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.116256714, 0.0750004649, 0.0000610351562, 1, 0, 0, 0, 1, 0, 0, 0, 1),
            ["BorderColor"] = v4
        },
        ["Halloween"] = {
            ["TextureID"] = "rbxassetid://11241216355",
            ["Rarity"] = "Exclusive"
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8212952678",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://8212959581",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8212975065",
            ["Rarity"] = "Common"
        },
        ["Battleworn Blue"] = {
            ["TextureID"] = "rbxassetid://8212972476",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8212955941",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8212991595",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8213019535",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8213155212",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8213025576",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8213028694",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8213165917",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8213168054",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8213175568",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9401951892",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9401997867",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9402011516",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9401985175",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9402003717",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9402044786",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9402049161",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9402014215",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9402025791",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9402055602",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9401937265",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9402023983",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9402007158",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9401972413",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12806134043",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698536498",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698534667",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698532205",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698542283",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[AR]"] = v58
    local v59 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12115236401",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.ARGhost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.116256714, 0.0750004649, 0.0000610351562, 1, 0, 0, 0, 1, 0, 0, 0, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8212952678",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://8212959581",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8212975065",
            ["Rarity"] = "Common"
        },
        ["Battleworn Blue"] = {
            ["TextureID"] = "rbxassetid://8212972476",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8212955941",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8212991595",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8213019535",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8213155212",
            ["Rarity"] = "Rare"
        },
        ["Future"] = {
            ["TextureID"] = "rbxassetid://8213025576",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8213028694",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8213165917",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8213168054",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8213175568",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9401951892",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9401997867",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9402011516",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9401985175",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9402003717",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9402044786",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9402049161",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9402014215",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9402025791",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9402055602",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9401937265",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9402023983",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9402007158",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9401972413",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12806134043",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698536498",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698534667",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698532205",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698542283",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[SilencerAR]"] = v59
    local v60 = {
        ["Valentine"] = {
            ["TextureID"] = "rbxassetid://12115438326",
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shadow.AK47Ghost,
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(-0.750015259, 4.76837158e-7, -0.0000305175781, 1, 0, 0, 0, 1, 0, 0, 0, 1),
            ["BorderColor"] = v4
        },
        ["Battleworn Green"] = {
            ["TextureID"] = "rbxassetid://8213540594",
            ["Rarity"] = "Common"
        },
        ["Battleworn Red"] = {
            ["TextureID"] = "rbxassetid://8213544761",
            ["Rarity"] = "Common"
        },
        ["Battleworn Orange"] = {
            ["TextureID"] = "rbxassetid://8213558744",
            ["Rarity"] = "Common"
        },
        ["Battleworn Blue"] = {
            ["TextureID"] = "rbxassetid://8213551140",
            ["Rarity"] = "Common"
        },
        ["Battleworn Purple"] = {
            ["TextureID"] = "rbxassetid://8213553838",
            ["Rarity"] = "Common"
        },
        ["Battleworn Pink"] = {
            ["TextureID"] = "rbxassetid://8213556073",
            ["Rarity"] = "Common"
        },
        ["Danger"] = {
            ["TextureID"] = "rbxassetid://8213561927",
            ["Rarity"] = "Rare"
        },
        ["Black & White"] = {
            ["TextureID"] = "rbxassetid://8213564638",
            ["Rarity"] = "Rare"
        },
        ["Icey"] = {
            ["TextureID"] = "rbxassetid://8213567693",
            ["Rarity"] = "Epic"
        },
        ["Biohazard"] = {
            ["TextureID"] = "rbxassetid://8213570295",
            ["Rarity"] = "Epic"
        },
        ["Red Death"] = {
            ["TextureID"] = "rbxassetid://8213572965",
            ["Rarity"] = "Legendary"
        },
        ["Gold Glory"] = {
            ["TextureID"] = "rbxassetid://8213606202",
            ["Rarity"] = "Legendary"
        },
        ["Jungle Blaster"] = {
            ["TextureID"] = "rbxassetid://9402075015",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["1984"] = {
            ["TextureID"] = "rbxassetid://9402123344",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["White Stripes"] = {
            ["TextureID"] = "rbxassetid://9402137566",
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Venom"] = {
            ["TextureID"] = "rbxassetid://9402109360",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Red Tiger"] = {
            ["TextureID"] = "rbxassetid://9402128607",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Red"] = {
            ["TextureID"] = "rbxassetid://9402165796",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Premium Yellow"] = {
            ["TextureID"] = "rbxassetid://9402168602",
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Pink Fuchsia"] = {
            ["TextureID"] = "rbxassetid://9402143081",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Patriot"] = {
            ["TextureID"] = "rbxassetid://9402153356",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Glassy"] = {
            ["TextureID"] = "rbxassetid://9402177431",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Red Hot"] = {
            ["TextureID"] = "rbxassetid://9368888318",
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Matrix"] = {
            ["TextureID"] = "rbxassetid://9402147406",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Galaxy"] = {
            ["TextureID"] = "rbxassetid://9402132929",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Inferno"] = {
            ["TextureID"] = "rbxassetid://9402094255",
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Luck"] = {
            ["TextureID"] = "rbxassetid://12806176107",
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Purple Yellow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698565005",
            ["Rarity"] = "Common",
            ["Crate"] = 3
        },
        ["Blue Wrap"] = {
            ["TextureID"] = "rbxassetid://11698561489",
            ["Rarity"] = "Rare",
            ["Crate"] = 3
        },
        ["Christmas Wrap"] = {
            ["TextureID"] = "rbxassetid://11698558392",
            ["Rarity"] = "Epic",
            ["Crate"] = 3
        },
        ["Snow Wrap"] = {
            ["TextureID"] = "rbxassetid://11698567925",
            ["Rarity"] = "Legendary",
            ["Crate"] = 3
        }
    }
    shared.skin_modules["[AK47]"] = v60
    shared.skin_modules["[Flintlock]"] = {}
    local v61 = {
        ["Love Kukri"] = {
            ["CFrame"] = CFrame.new(0.650018692, 0.419342041, -0.0283660889, 0, 1, 0, 0, 0, -1, -1, 0, 0),
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v1
        },
        ["Shadow"] = {
            ["CFrame"] = CFrame.new(1.1250186, 0.0000305175781, 0.000396728516, 0, 1, 0, 1, 0, -4.37113883e-8, -4.37113883e-8, 0, -1),
            ["Rarity"] = "Exclusive",
            ["BorderColor"] = v4
        },
        ["Katar"] = {
            ["CFrame"] = CFrame.new(-0.555824697, -0.533429861, 0.0668983459, 0, 1, 0, 0, 0, 1, 1, 0, 0),
            ["Rarity"] = "Common",
            ["Crate"] = 2
        },
        ["Kunai"] = {
            ["CFrame"] = CFrame.new(0.0728008747, 0.0431479923, 0.0373959541, 0, -1, 0, -0.99999994, 0, 0, 0, 0, -1),
            ["Rarity"] = "Common",
            ["Crate"] = 2
        },
        ["Pink"] = {
            ["CFrame"] = CFrame.new(-0.200906992, -0.0210727006, -0.00665473938, 0, 1, 0, -0.99999994, 0, 0, 0, 0, 1),
            ["Rarity"] = "Common",
            ["Crate"] = 2
        },
        ["Screw Driver"] = {
            ["CFrame"] = CFrame.new(0.109568655, -0.0280584544, 0.000621795654, 0, 1, 0, 0, 0, -0.99999994, -1, 0, 0),
            ["Rarity"] = "Common",
            ["Crate"] = 2
        },
        ["Kitchen"] = {
            ["CFrame"] = CFrame.new(0.0464496613, -0.208359778, -0.0175123215, 0, 0, -1, 0, 1, 0, 1, 0, 0),
            ["Rarity"] = "Common",
            ["Crate"] = 2
        },
        ["Buster"] = {
            ["CFrame"] = CFrame.new(0.284334183, -0.00799623132, 0.0138845444, 0, 1, 0, 0, 0, 1, 1, 0, 0),
            ["Rarity"] = "Rare",
            ["Crate"] = 2
        },
        ["Scissor"] = {
            ["CFrame"] = CFrame.new(0.0672817826, 0.0748512968, -0.0330171585, -1, 0, 0, 0, -0.99999994, 0, 0, 0, 1),
            ["Rarity"] = "Rare",
            ["Crate"] = 2
        },
        ["Boxcutter"] = {
            ["CFrame"] = CFrame.new(0.133508801, -0.0368869603, 0.0361539125, 1, 0, 0, 0, -1, 0, 0, 0, -1),
            ["Rarity"] = "Rare",
            ["Crate"] = 2
        },
        ["Bat Sharp"] = {
            ["CFrame"] = CFrame.new(0.0205659866, 0.0712812394, -0.0301570892, 1, 0, 0, 0, -0.99999994, 0, 0, 0, -1),
            ["Rarity"] = "Epic",
            ["Crate"] = 2
        },
        ["Red Tiger"] = {
            ["CFrame"] = CFrame.new(0.176477551, 0.0276881456, 0.0265624225, 0, 1, 0, -1, 0, 0, 0, 0, 1),
            ["Rarity"] = "Epic",
            ["Crate"] = 2
        },
        ["Golden Age Tanto"] = {
            ["CFrame"] = CFrame.new(0.395452857, -0.00876617432, -0.0173950195, 4.89857682e-16, 1, 1.62920671e-7, 1, -2.70329972e-14, 1.62920628e-7, 1.62920628e-7, 1.62920671e-7, -1),
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Emerald"] = {
            ["CFrame"] = CFrame.new(0.154518723, 0.116676092, 0.000304222107, 0, 1, 0, -1, 0, 0, 0, 0, 1),
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Golden"] = {
            ["CFrame"] = CFrame.new(0.269160748, 0.00606650487, -0.00481987, 0, 1, 0, 0, 0, -1, -1, 0, 0),
            ["Rarity"] = "Legendary",
            ["Crate"] = 2
        },
        ["Galactic-Red"] = {
            ["CFrame"] = CFrame.new(-0.261539459, 0.0143127441, 0.0307006836, 0, 1, 0, 0, 0, 1, 1, 0, 0),
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Dragon"] = {
            ["CFrame"] = CFrame.new(0.171493769, -0.0721282959, -0.0171813965, 8.15480348e-7, 0.99999994, 4.55676854e-7, -1.00000203, 6.4963109e-7, 2.51534473e-8, 2.88709696e-8, -4.56442649e-7, 1.00000012),
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Heaven"] = {
            ["CFrame"] = CFrame.new(0.147634387, 0.286956787, -0.00314331055, 8.88577406e-14, 0.798631966, 0.601811886, 1.75618051e-14, -0.601811886, 0.798631966, 1, 6.03960173e-14, 6.75013837e-14),
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Void"] = {
            ["CFrame"] = CFrame.new(0.0116134882, 0.0246582031, 0.00231933594, 1, 0, 0, 0, 1, 0, 0, 0, 1),
            ["Rarity"] = "Legendary",
            ["Crate"] = 999,
            ["BorderColor"] = v20
        },
        ["Raygun"] = {
            ["CFrame"] = CFrame.new(-0.406901479, 0.0661621094, 0.0101928711, 1, 0, 0, 0, -1, 0, 0, 0, -1),
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["RGB Butterfly"] = {
            ["CFrame"] = CFrame.new(0.129888415, 0.0243530273, -0.0148620605, 1, 0, 0, 0, -1, 0, 0, 0, -1),
            ["Rarity"] = "Legendary",
            ["Crate"] = 2
        },
        ["Emerald Butterfly"] = {
            ["CFrame"] = CFrame.new(0.129888415, 0.0243530273, -0.0148620605, 1, 0, 0, 0, -1, 0, 0, 0, -1),
            ["Rarity"] = "Exclusive"
        },
        ["Black Marker"] = {
            ["CFrame"] = CFrame.new(0.0356717706, 0.0152872801, 0.023607254, 0, 1, 0, 0, 0, 1, 1, 0, 0),
            ["Rarity"] = "Exclusive"
        },
        ["Red Marker"] = {
            ["CFrame"] = CFrame.new(0.0356717706, 0.0152872801, 0.023607254, 0, 1, 0, 0, 0, 1, 1, 0, 0),
            ["Rarity"] = "Exclusive"
        },
        ["Purple Marker"] = {
            ["CFrame"] = CFrame.new(0.0356717706, 0.0152872801, 0.023607254, 0, 1, 0, 0, 0, 1, 1, 0, 0),
            ["Rarity"] = "Exclusive"
        },
        ["Pink Marker"] = {
            ["CFrame"] = CFrame.new(0.0356717706, 0.0152872801, 0.023607254, 0, 1, 0, 0, 0, 1, 1, 0, 0),
            ["Rarity"] = "Exclusive"
        },
        ["Orange Marker"] = {
            ["CFrame"] = CFrame.new(0.0356717706, 0.0152872801, 0.023607254, 0, 1, 0, 0, 0, 1, 1, 0, 0),
            ["Rarity"] = "Exclusive"
        },
        ["Green Marker"] = {
            ["CFrame"] = CFrame.new(0.0356717706, 0.0152872801, 0.023607254, 0, 1, 0, 0, 0, 1, 1, 0, 0),
            ["Rarity"] = "Exclusive"
        },
        ["Brown Marker"] = {
            ["CFrame"] = CFrame.new(0.0356717706, 0.0152872801, 0.023607254, 0, 1, 0, 0, 0, 1, 1, 0, 0),
            ["Rarity"] = "Exclusive"
        },
        ["Blue Marker"] = {
            ["CFrame"] = CFrame.new(0.0356717706, 0.0152872801, 0.023607254, 0, 1, 0, 0, 0, 1, 1, 0, 0),
            ["Rarity"] = "Exclusive"
        }
    }
    shared.skin_modules["[Knife]"] = v61
    local v62 = {
        ["House 2"] = {
            ["Rarity"] = "Common",
            ["Crate"] = 1
        },
        ["Brick"] = {
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Town"] = {
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Classic 1"] = {
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Contemporary House"] = {
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Container House"] = {
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Da Restaurant"] = {
            ["Rarity"] = "Epic",
            ["Crate"] = 1
        },
        ["Pink House II"] = {
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Modern"] = {
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Studio House"] = {
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Brick Modern"] = {
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Villa"] = {
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Pink House"] = {
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["Cliff House"] = {
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        }
    }
    shared.skin_modules["[House]"] = v62
    local v63 = {
        ["Bitcoin"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.0482025146, 0.0281861424, 0.00436401367, 0, 0, -1, 0, 1, 0, 1, 0, 0)
        },
        ["Pig"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(-0.0382080078, -0.05485636, 0.126846313, -1, 0, 0, 0, 1, 0, 0, 0, -1)
        },
        ["Designer"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.0162658691, -0.257393897, 0.0985870361, 0, 0, -1, 0, 1, 0, 1, 0, 0)
        },
        ["Designer Pink"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.0162658691, -0.257393897, 0.0985870361, 0, 0, -1, 0, 1, 0, 1, 0, 0)
        },
        ["Credit Card"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(-0.0554199219, -0.0202098489, -0.0571899414, 0, 0, 1, 0, -1, 0, 1, 0, 0)
        },
        ["Credit Card Pink"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(-0.0554199219, -0.0202098489, -0.0571899414, 0, 0, 1, 0, -1, 0, 1, 0, 0)
        },
        ["Kin"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.0292358398, -0.706313014, 0.605987549, 0, 0, 1, 0, 1, 0, -1, 0, 0)
        },
        ["Pink Purse"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(-0.00854492188, -0.838884234, 0.602813721, 0, 0, 1, 0, 1, 0, -1, 0, 0)
        },
        ["Stacks"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(-0.0927200317, 0.473638803, 0.502807617, 1, 0, 0, 0, 1, 0, 0, 0, 1)
        },
        ["Pink Purse II"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(-0.00854492188, -0.838884234, 0.602813721, 0, 0, 1, 0, 1, 0, -1, 0, 0)
        },
        ["Turtle"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(-0.00854492188, -0.838884234, 0.602813721, 0, 0, 1, 0, 1, 0, -1, 0, 0)
        },
        ["Roblex"] = {
            ["Rarity"] = "Legendary",
            ["DisplayName"] = "Pepsi Roblex",
            ["CFrame"] = CFrame.new(0.15, -0.55, 0.8, 0, 0, -1, 1, 0, 0, 0, -1, 0),
            ["BorderColor"] = v6,
            ["Crate"] = 999
        },
        ["Emerald Roblex"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.15, -0.55, 0.8, 0, 0, -1, 1, 0, 0, 0, -1, 0),
            ["BorderColor"] = v22
        },
        ["Rose Roblex"] = {
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(0.15, -0.55, 0.8, 0, 0, -1, 1, 0, 0, 0, -1, 0),
            ["BorderColor"] = v1,
            ["Crate"] = 999
        },
        ["Audemoon"] = {
            ["Rarity"] = "Legendary",
            ["CFrame"] = CFrame.new(0.165, -0.53, 0.8, 0, 0, -1, 1, 0, 0, 0, -1, 0),
            ["BorderColor"] = v5,
            ["Crate"] = 999
        }
    }
    shared.skin_modules["[Wallet]"] = v63
    local v64 = {
        ["Pink Spiked"] = {
            ["Rarity"] = "Exclusive",
            ["CFrame"] = CFrame.new(0.0482025146, 0.0281861424, 0.00436401367, 0, 0, -1, 0, 1, 0, 1, 0, 0),
            ["BorderColor"] = v1
        }
    }
    shared.skin_modules["[Bat]"] = v64
    local v65 = {
        ["Moped"] = {
            ["Rarity"] = "Common",
            ["Crate"] = 999
        },
        ["Motorcycle"] = {
            ["Rarity"] = "Common",
            ["Crate"] = 999
        },
        ["Motorcycle Side Seat"] = {
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Car"] = {
            ["Rarity"] = "Exclusive"
        },
        ["Kart"] = {
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Golf Cart"] = {
            ["Rarity"] = "Rare",
            ["Crate"] = 1
        },
        ["Burger"] = {
            ["Rarity"] = "Exclusive",
            ["NoTrade"] = true
        },
        ["Luxe"] = {
            ["Rarity"] = "Exclusive"
        },
        ["Turbo"] = {
            ["DisplayName"] = "811 Turbo (G)",
            ["BorderColor"] = v7,
            ["Rarity"] = "Exclusive"
        },
        ["TurboSCyan"] = {
            ["DisplayName"] = "811 Turbo S (C)",
            ["BorderColor"] = v7,
            ["Rarity"] = "Exclusive"
        },
        ["TurboSOrange"] = {
            ["DisplayName"] = "811 Turbo S (O)",
            ["BorderColor"] = v7,
            ["Rarity"] = "Legendary",
            ["Crate"] = 1
        },
        ["Cyber"] = {
            ["Rarity"] = "Legendary",
            ["Crate"] = 999
        },
        ["School Bus"] = {
            ["Rarity"] = "Exclusive",
            ["NoTrade"] = true
        },
        ["Dirt Bike"] = {
            ["Rarity"] = "Exclusive"
        },
        ["ATV"] = {
            ["Rarity"] = "Exclusive"
        },
        ["Reindeer"] = {
            ["Rarity"] = "Common",
            ["Crate"] = 999
        }
    }
    shared.skin_modules["[Vehicle]"] = v65
    local v66 = {
        ["Bandana Black"] = {
            ["Rarity"] = "Common"
        },
        ["Bandana DH"] = {
            ["Rarity"] = "Common"
        },
        ["Hockey"] = {
            ["Rarity"] = "Common"
        },
        ["Ski Mask"] = {
            ["Rarity"] = "Common"
        },
        ["Ski Mask II"] = {
            ["Rarity"] = "Common"
        },
        ["Hockey DH"] = {
            ["Rarity"] = "Rare"
        },
        ["Hockey Gradient"] = {
            ["Rarity"] = "Rare"
        },
        ["Ski Mask Saint"] = {
            ["Rarity"] = "Rare"
        },
        ["Ski Mask DH"] = {
            ["Rarity"] = "Rare"
        },
        ["Ski Mask Red Eye"] = {
            ["Rarity"] = "Rare"
        },
        ["Ski Mask Saint II"] = {
            ["Rarity"] = "Rare"
        },
        ["Ski Mask X)"] = {
            ["Rarity"] = "Rare"
        },
        ["Ski Mask Half Green"] = {
            ["Rarity"] = "Epic"
        },
        ["Ski Mask Blue"] = {
            ["Rarity"] = "Epic"
        },
        ["Ski Mask II DH"] = {
            ["Rarity"] = "Epic"
        },
        ["Ski Mask Pink"] = {
            ["Rarity"] = "Epic"
        },
        ["Ski Mask Red"] = {
            ["Rarity"] = "Epic"
        },
        ["Ski Mask Skull"] = {
            ["Rarity"] = "Epic"
        },
        ["Ski Mask Horns"] = {
            ["Rarity"] = "Legendary"
        },
        ["Ski Mask Horns DH"] = {
            ["Rarity"] = "Legendary"
        },
        ["Ski Mask Horns Pink"] = {
            ["Rarity"] = "Legendary"
        },
        ["Ski Mask Horns White"] = {
            ["Rarity"] = "Legendary"
        }
    }
    shared.skin_modules["[Mask]"] = v66
    shared.skin_modules["[Revolver]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12898879990",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[DrumGun]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899291391",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[SMG]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899335260",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[Shotgun]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899388473",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[Rifle]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899704735",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[TacticalShotgun]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899678631",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[RPG]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899423289",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[P90]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899451616",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[LMG]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899469894",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[Flamethrower]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899496204",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[Double-Barrel SG]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899533307",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[Glock]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899580244",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[Silencer]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899580244",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[AUG]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899730688",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[AR]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899633890",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[SilencerAR]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899633890",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[AK47]"].Rainbow = {
        ["TextureID"] = "rbxassetid://12899655828",
        ["Rarity"] = "Rare",
        ["Crate"] = 1,
        ["BorderColor"] = v15
    }
    shared.skin_modules["[Revolver]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricRevolver,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.185462952, 0.0312761068, 0.000610351562, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[DrumGun]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricDrum,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.471969604, 0.184426308, 0.075378418, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[SMG]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricSMG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0620956421, 0.109580457, 0.00729370117, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Shotgun]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricShotgun,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0000610351562, 0.180232108, -0.624732971, 1, 0, -4.37113883e-8, 0, 1, 0, 4.37113883e-8, 0, 1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Rifle]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricRifle,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.181793213, -0.0415201783, 0.00421142578, 1.8189894e-12, 6.6174449e-24, 1, 7.27595761e-12, 1, 6.6174449e-24, -1, -7.27595761e-12, -1.8189894e-12),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[TacticalShotgun]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricTac,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0838031769, -0.0377542973, 0.00717163086, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[RPG]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricRPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.022277832, -0.0413781404, 0.00997161865, 1, -5.35309611e-24, -4.37113883e-8, 2.49770094e-21, 0.99999994, 5.72632016e-14, 4.37113883e-8, 5.72631948e-14, 1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[P90]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricP90,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.166191101, -0.225557804, -0.0075378418, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[LMG]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricLMG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.142379761, 0.104723871, -0.303771973, -1, 0, -4.37113883e-8, 0, 1, 0, 4.37113883e-8, 0, -1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Flamethrower]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricFT,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.158782959, 0.173444271, 0.00640869141, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Double-Barrel SG]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricDB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0755996704, -0.0420352221, 0.00543212891, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Glock]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricGlock,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00207519531, 0.0318723917, 0.0401077271, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Silencer]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricGlock,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00207519531, 0.0318723917, 0.0401077271, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[AUG]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricAUG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.331085205, -0.0117390156, 0.00155639648, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[AR]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricAR,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.16942215, 0.0508521795, 0.0669250488, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[SilencerAR]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricAR,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.16942215, 0.0508521795, 0.0669250488, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[AK47]"].Electric = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Electric.ElectricAK,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.155792236, 0.18423444, 0.00140380859, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Revolver]"]["8-BIT"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.BIT8.RPixel,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0261230469, -0.042888701, 0.00260925293, -1, 1.355249e-20, -3.55271071e-15, 1.355249e-20, 1, -1.81903294e-27, 3.55271071e-15, -1.81903294e-27, -1),
        ["BorderColor"] = v24
    }
    shared.skin_modules["[Flamethrower]"]["8-BIT"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.BIT8.FTPixel,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0906066895, -0.0161985159, -0.0117645264, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v24
    }
    shared.skin_modules["[Double-Barrel SG]"]["8-BIT"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.BIT8.DBPixel,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.240386963, -0.127295256, -0.00776672363, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v24
    }
    shared.skin_modules["[RPG]"]["8-BIT"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.BIT8.RPGPixel,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0102081299, 0.0659624338, 0.362945557, 4.37113883e-8, 0, 1, -5.72632016e-14, 1, 2.50305399e-21, -1, 5.72632016e-14, 4.37113883e-8),
        ["BorderColor"] = v24
    }
    shared.skin_modules["[Revolver]"]["Red Skull"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.RedSkull.RedSkullRev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0043258667, 0.0084195137, -0.00238037109, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v25
    }
    shared.skin_modules["[Shotgun]"]["Red Skull"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.RedSkull.RedSkullShotgun,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00326538086, 0.0239292979, -0.039352417, -4.37113883e-8, 0, -1, 0, 1, 0, 1, 0, -4.37113883e-8),
        ["BorderColor"] = v25
    }
    shared.skin_modules["[Double-Barrel SG]"]["Red Skull"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.RedSkull.RedSkullDB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0143432617, -0.151709318, 0.00820922852, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v25
    }
    shared.skin_modules["[RPG]"]["Red Skull"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.RedSkull.RedSkullRPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00149536133, 0.254377961, 0.804840088, -1, 0, 4.37113883e-8, -2.50305399e-21, 1, -5.72632016e-14, -4.37113883e-8, 5.72632016e-14, -1),
        ["BorderColor"] = v25
    }
    shared.skin_modules["[Revolver]"].Kitty = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Kitty.KittyRevolver,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0310440063, 0.0737591386, 0.0226745605, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v26
    }
    shared.skin_modules["[Flamethrower]"].Kitty = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Kitty.KittyFT,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.265670776, 0.115545571, 0.00997924805, -1, 9.74078034e-21, 5.47124086e-13, 9.74092898e-21, 1, 3.12638804e-13, -5.47126309e-13, 3.12638804e-13, -1),
        ["BorderColor"] = v26
    }
    shared.skin_modules["[RPG]"].Kitty = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Kitty.KittyRPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0268554688, 0.0252066851, 0.117408752, -1, 2.51111284e-40, 4.37113883e-8, -3.7545812e-20, 1, -8.58948004e-13, -4.37113883e-8, 8.58948004e-13, -1),
        ["BorderColor"] = v26
    }
    shared.skin_modules["[Shotgun]"].Kitty = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Kitty.KittyShotgun,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0233459473, 0.223892093, -0.0213623047, 4.37118963e-8, -6.53699317e-13, 1, 3.47284736e-20, 1, 7.38964445e-13, -0.999997139, 8.69506734e-21, 4.37119354e-8),
        ["BorderColor"] = v26
    }
    shared.skin_modules["[Revolver]"].Toy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Toy.RevolverTOY,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0250854492, -0.144362092, -0.00266647339, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v27
    }
    shared.skin_modules["[LMG]"].Toy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Toy.LMGTOY,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.285247803, -0.0942560434, -0.270412445, 1, 0, 4.37113883e-8, 0, 1, 0, -4.37113883e-8, 0, 1),
        ["BorderColor"] = v27
    }
    shared.skin_modules["[Double-Barrel SG]"].Toy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Toy.DBToy,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0484313965, -0.00164616108, -0.0190467834, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v27
    }
    shared.skin_modules["[RPG]"].Toy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Toy.RPGToy,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00121307373, 0.261434197, -0.318969727, 1, 2.5768439e-12, -4.37113883e-8, 2.57684412e-12, 1, 6.29895225e-12, 4.37113883e-8, 6.29895225e-12, 1),
        ["BorderColor"] = v27,
        ["LauncherCFrame"] = CFrame.new(-0.00020980835, 0.000125527382, -0.837677002, 1, 2.5768439e-12, -4.37113883e-8, 2.57684412e-12, 1, 6.29895225e-12, 4.37113883e-8, 6.29895225e-12, 1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Toy.RPG_LAUNCHER
    }
    shared.skin_modules["[Revolver]"].Galactic = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Galactic.galacticRev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.049041748, 0.0399398208, -0.00772094727, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v28
    }
    shared.skin_modules["[TacticalShotgun]"].Galactic = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Galactic.TacticalGalactic,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0411682129, -0.0281000137, 0.00103759766, 0, 5.68434189e-14, 1, -1.91456822e-13, 1, 5.68434189e-14, -1, 1.91456822e-13, 0),
        ["BorderColor"] = v28
    }
    shared.skin_modules["[Knife]"].Galactic = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.261539459, 0.0143127441, 0.0307006836, 0, 1, 0, 0, 0, 1, 1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Revolver]"]["Web-Hero"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.HERO.HeroWeb,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0891418457, -0.0215809345, -0.0041809082, -1.99520325e-23, -1.62920685e-7, 1, 2.44929371e-16, 1, 1.62920685e-7, -1, 2.44929371e-16, 1.99520294e-23),
        ["BorderColor"] = v29
    }
    shared.skin_modules["[Shotgun]"]["Bat-Hero"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.HERO.HeroBat,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00122070312, 0.141189337, 0.146026611, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v29
    }
    shared.skin_modules["[Double-Barrel SG]"]["Angry-Hero"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.HERO.HeroAngry,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.171646118, -0.0197404027, -0.00314331055, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v29
    }
    shared.skin_modules["[RPG]"]["Robot-Hero"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.HERO.HeroRobot,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00689697266, -0.0342824459, 0.105255127, -1, -1.821688e-44, 4.37113883e-8, -2.50305399e-21, 1, -5.72632016e-14, -4.37113883e-8, 5.72632016e-14, -1),
        ["BorderColor"] = v29,
        ["LauncherCFrame"] = CFrame.new(0.00717163086, 0.000218987465, 0.119476318, 1, -2.44930165e-16, 0, 2.44929344e-16, 1, 1.19209346e-7, 0, -1.19209226e-7, 1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.HERO.RobotLauncher
    }
    shared.skin_modules["[Revolver]"].Water = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Water.WaterGunRevolver,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0440063477, 0.028675437, -0.00469970703, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Double-Barrel SG]"].Water = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Water.DBWater,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0710754395, 0.00169920921, -0.0888671875, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[TacticalShotgun]"].Water = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Water.TactWater,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0238037109, -0.00912904739, 0.00485229492, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Flamethrower]"].Water = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Water.FTWater,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0941314697, 0.593509138, 0.0191040039, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Revolver]"].Tact = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Tact.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.318634033, -0.055095911, 0.00491333008, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v8
    }
    shared.skin_modules["[TacticalShotgun]"].Tact = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Tact.Tact,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0687713623, -0.0684046745, 0.12701416, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v8
    }
    shared.skin_modules["[Shotgun]"].Tact = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Tact.Shotgun,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0610046387, 0.171100497, -0.00495910645, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v8
    }
    shared.skin_modules["[Double-Barrel SG]"].Tact = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Tact.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0701141357, -0.0506889224, -0.0826416016, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v8
    }
    shared.skin_modules["[Silencer]"].Tact = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Tact.Silencer,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0766601562, -0.0350288749, -0.648864746, 1, 0, -4.37113883e-8, 0, 1, 0, 4.37113883e-8, 0, 1),
        ["BorderColor"] = v8
    }
    shared.skin_modules["[SMG]"].Tact = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Tact.Uzi,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0408782959, 0.0827783346, -0.0423583984, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v8
    }
    shared.skin_modules["[RPG]"]["GPO-Ice"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.GPO.Bazooka,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0184631348, 0.0707798004, 0.219360352, 4.37113883e-8, 1.07062025e-23, 1, -5.75081297e-14, 1, 1.14251725e-36, -1, 5.70182736e-14, 4.37113883e-8),
        ["BorderColor"] = v30,
        ["LauncherCFrame"] = CFrame.new(-0.044708252, -0.0522594452, -0.688751221, 4.37113883e-8, 1.07062025e-23, 1, -5.75081297e-14, 1, 1.14251725e-36, -1, 5.70182736e-14, 4.37113883e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.GPO.IceBoom
    }
    shared.skin_modules["[TacticalShotgun]"]["GPO-Magma"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.GPO.MaguTact,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.282501221, 0.0472121239, -0.0065612793, -6.60624482e-6, 1.5649757e-8, -1, -5.68434189e-14, 1, -1.56486806e-8, 1, 5.68434189e-14, -6.60624482e-6),
        ["BorderColor"] = v30
    }
    shared.skin_modules["[Rifle]"]["GPO-Light"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.GPO.Rifle,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.208007812, 0.185256913, 0.000610351562, -3.37081539e-14, 1.62803403e-7, -1.00000012, -8.74227695e-8, 0.999999881, 1.63036205e-7, 1, 8.74227766e-8, -1.94552524e-14),
        ["BorderColor"] = v30
    }
    shared.skin_modules["[Knife]"]["GPO-Knife"] = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.693048477, -0.0903320312, -0.00289916992, -1, 2.44929371e-16, 1.99520294e-23, 2.44929371e-16, 1, 1.62920685e-7, 1.99520325e-23, 1.62920685e-7, -1),
        ["BorderColor"] = v16
    }
    shared.skin_modules["[Knife]"]["GPO-Knife Prestige"] = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.693048477, -0.0903320312, -0.00289916992, -1, 2.44929371e-16, 1.99520294e-23, 2.44929371e-16, 1, 1.62920685e-7, 1.99520325e-23, 1.62920685e-7, -1),
        ["BorderColor"] = v18
    }
    shared.skin_modules["[Revolver]"].Devil = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.CyanPack.Devil,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0185699463, 0.293397784, -0.00256347656, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v32
    }
    shared.skin_modules["[TacticalShotgun]"].Cloud = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.CyanPack.Cloud,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0441589355, -0.0269355774, -0.000701904297, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v32
    }
    shared.skin_modules["[Double-Barrel SG]"].Flower = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.CyanPack.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00828552246, 0.417651355, -0.00537109375, 4.18358377e-6, -1.62920685e-7, 1, 3.4104116e-13, 1, 1.62920685e-7, -1, 3.41041052e-13, -4.18358377e-6),
        ["BorderColor"] = v32
    }
    shared.skin_modules["[RPG]"].Cookie = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.CyanPack.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00448608398, 0.211129785, 0.108352661, -1, -6.87656033e-15, 4.37113883e-8, 2.44926856e-16, 1, 1.62920628e-7, -4.37113883e-8, 1.62920742e-7, -1),
        ["BorderColor"] = v32,
        ["LauncherCFrame"] = CFrame.new(0.000183105469, 0.000218987465, -0.0145568848, 4.37113883e-8, -1.62920671e-7, 1, -5.70182736e-14, 1, 1.62920671e-7, -1, 5.03866426e-14, 4.37113883e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.CyanPack.Rocket
    }
    shared.skin_modules["[Knife]"].Frog = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.763793707, 0.0409240723, -0.0497436523, 0.37460658, 0.927183867, 1.51057435e-7, -0.927183867, 0.37460658, 6.10311588e-8, -1.99520325e-23, -1.62920685e-7, 1),
        ["BorderColor"] = v32
    }
    shared.skin_modules["[Knife]"].Cartoon = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.009542346, 0.0122070312, 0.00538635254, 2.38220323e-8, 1.00000095, -7.88475063e-10, -1.00000298, -2.35862601e-8, 1.92318112e-7, -1.9185245e-7, -7.88077159e-10, 1.00000429),
        ["BorderColor"] = v33
    }
    shared.skin_modules["[Revolver]"].Cartoon = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cartoon.CartoonRev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.015411377, 0.0135096312, 0.00338745117, 1.00000095, 3.41326549e-13, 2.84217399e-14, 3.41326549e-13, 1.00000191, -9.89490712e-10, 2.84217399e-14, -9.89490712e-10, 1.00000191),
        ["BorderColor"] = v33
    }
    shared.skin_modules["[Double-Barrel SG]"].Cartoon = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cartoon.DBCartoon,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00927734375, -0.00691050291, 0.000732421875, -1, -2.79396772e-8, -9.31322797e-10, -2.79396772e-8, 1, 1.42607872e-8, 9.31322575e-10, 1.42607872e-8, -1),
        ["BorderColor"] = v33
    }
    shared.skin_modules["[RPG]"].Cartoon = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cartoon.RPGCartoon,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0201721191, 0.289476752, -0.0727844238, 4.37113883e-8, 6.58276836e-37, 1, -5.72632016e-14, 1, 2.50305399e-21, -1, 5.72632016e-14, 4.37113883e-8),
        ["BorderColor"] = v33,
        ["LauncherCFrame"] = CFrame.new(-0.00137329102, 0.00280761719, -0.321243286, -1, -1.30858874e-16, 4.36997354e-8, -2.50242694e-21, 1, 2.99444292e-9, -4.36997354e-8, 2.99455749e-9, -1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cartoon.RPGCartoonLauncher
    }
    shared.skin_modules["[Flamethrower]"].Cartoon = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cartoon.CartoonFT,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.272186279, 0.197086751, 0.0440063477, -1, 4.8018768e-7, 8.7078952e-8, 4.80187623e-7, 1, -3.54779985e-7, -8.70791226e-8, -3.54779957e-7, -1),
        ["BorderColor"] = v33
    }
    shared.skin_modules["[Knife]"].Stars = {
        ["DisplayName"] = "Star",
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.983487725, 0.0367431641, -0.00146484375, 0, 1, 0, -1, 0, 0, 0, 0, 1),
        ["BorderColor"] = v34
    }
    shared.skin_modules["[Revolver]"].Stars = {
        ["DisplayName"] = "Thunder",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Stars.Revolver,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0765533447, 0.0790345669, 0.00277709961, 1.99520325e-23, 1.62920685e-7, -1, 2.44929371e-16, 1, 1.62920685e-7, 1, -2.44929371e-16, -1.99520294e-23),
        ["BorderColor"] = v34
    }
    shared.skin_modules["[Double-Barrel SG]"].Stars = {
        ["DisplayName"] = "Dino",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Stars.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0697937012, 0.0765505433, 0.00863647461, 7.54618668e-7, -1.62920685e-7, 1, 6.1716413e-14, 1, 1.62920685e-7, -1, 6.17164197e-14, -7.54618668e-7),
        ["BorderColor"] = v34
    }
    shared.skin_modules["[RPG]"].Stars = {
        ["DisplayName"] = "Speed",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Stars.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00457763672, -0.0361404419, -0.636352539, -1, -2.30390549e-28, 4.37113883e-8, -2.50305399e-21, 1, -5.72632084e-14, -4.37113883e-8, 5.72632084e-14, -1),
        ["BorderColor"] = v34,
        ["LauncherCFrame"] = CFrame.new(0.00271606445, -0.0138825178, -0.384429932, 4.37113883e-8, -2.30390549e-28, 1, -5.72632084e-14, 1, 2.50305399e-21, -1, 5.72632084e-14, 4.37113883e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Stars.Rocket
    }
    shared.skin_modules["[Flamethrower]"].Stars = {
        ["DisplayName"] = "Starry",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Stars.Flamethrower,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0000610351562, 0.229534328, 0.0126647949, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v34
    }
    shared.skin_modules["[Revolver]"]["DH-Verified"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Popular.VERIFIEDREV,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.049407959, -0.0454721451, 0.00158691406, -1, 0, 0, 0, 1, 2.22044605e-15, 0, -2.22044605e-15, -1),
        ["NoTrade"] = true
    }
    shared.skin_modules["[Revolver]"]["DH-Stars II"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Popular.STARSREV,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0578613281, -0.0479719043, -0.00115966797, -1.00000405, 1.15596135e-16, 1.64267286e-30, -1.15596135e-16, 1, 2.99751983e-14, 1.66683049e-30, -2.99751983e-14, -1.00000405),
        ["NoTrade"] = true
    }
    shared.skin_modules["[Revolver]"].Arcade = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Arcade.Rev,
        ["Rarity"] = "Legendary",
        ["CFrame"] = CFrame.new(0.0578613281, -0.0479719043, -0.00115966797, -1.00000405, 1.15596135e-16, 1.64267286e-30, -1.15596135e-16, 1, 2.99751983e-14, 1.66683049e-30, -2.99751983e-14, -1.00000405),
        ["NoTrade"] = false,
        ["Crate"] = 999
    }
    shared.skin_modules["[Double-Barrel SG]"].Arcade = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Arcade.DB,
        ["Rarity"] = "Legendary",
        ["CFrame"] = CFrame.new(0.0578613281, -0.0479719043, -0.00115966797, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["NoTrade"] = false,
        ["Crate"] = 999
    }
    shared.skin_modules["[Revolver]"].Spectre = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Spectre.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0578613281, -0.0479719043, -0.00115966797, -1.00000405, 1.15596135e-16, 1.64267286e-30, -1.15596135e-16, 1, 2.99751983e-14, 1.66683049e-30, -2.99751983e-14, -1.00000405)
    }
    shared.skin_modules["[Revolver]"].Blaze = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Blaze.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.3, -0.0479719043, -0.00115966797, 1.00000405, 1.15596135e-16, -1.64267286e-30, 1.15596135e-16, 1, -2.99751983e-14, -1.66683049e-30, -2.99751983e-14, 1.00000405),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Revolver]"].CandyCane = {
        ["DisplayName"] = "GPO-Rev",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.CandyCane.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.3, -0.0479719043, -0.00115966797, -1.00000405, 1.15596135e-16, 1.64267286e-30, -1.15596135e-16, 1, 2.99751983e-14, 1.66683049e-30, -2.99751983e-14, -1.00000405),
        ["BorderColor"] = v16
    }
    shared.skin_modules["[Revolver]"].PrestigeCandyCane = {
        ["DisplayName"] = "GPO-Rev Prestige",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.CandyCane.PrestigeRev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.3, -0.0479719043, -0.00115966797, -1.00000405, 1.15596135e-16, 1.64267286e-30, -1.15596135e-16, 1, 2.99751983e-14, 1.66683049e-30, -2.99751983e-14, -1.00000405),
        ["BorderColor"] = v18
    }
    shared.skin_modules["[Knife]"].CyanKarambit = {
        ["DisplayName"] = "Cyan",
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0699813366, -0.0199928284, 0.151672363, 6.21539241e-22, 1, 0, 1, 6.21539241e-22, -3.57623663e-17, 3.57623663e-17, 0, -1),
        ["BorderColor"] = v13
    }
    shared.skin_modules["[Knife]"].Mystical = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.146238923, 0.0104064941, -0.0165710449, -3.94430029e-31, 1, 0, 1.00000429, 0, 0, 0, 0, -1.00000429),
        ["BorderColor"] = v35
    }
    shared.skin_modules["[Revolver]"].Mystical = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Mystical.Revolver,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.015838623, -0.0802496076, 0.00772094727, 1, 0, 4.37113883e-8, 0, 1, 0, -4.37113883e-8, 0, 1),
        ["BorderColor"] = v35
    }
    shared.skin_modules["[Double-Barrel SG]"].Mystical = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Mystical.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00408935547, -0.021312356, 0.00366210938, -1, -1.95924309e-33, 2.03287907e-20, 1.95924309e-33, 1, 0, -2.0328781e-20, 0, -0.999999523),
        ["BorderColor"] = v35
    }
    shared.skin_modules["[RPG]"].Mystical = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Mystical.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0104980469, -0.132928133, 0.311920166, 4.37113883e-8, -3.72594783e-24, 1, -1.46422097e-10, 1, 6.40030916e-18, -1, 1.46422097e-10, 4.37113883e-8),
        ["BorderColor"] = v35,
        ["LauncherCFrame"] = CFrame.new(-0.00402832031, -0.00254774094, -0.735931396, -1, -3.30872245e-24, 4.37113883e-8, -6.40531526e-18, 1, -1.46536616e-10, -4.37113883e-8, 1.46536616e-10, -1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Mystical.Launcher
    }
    shared.skin_modules["[Flamethrower]"].Mystical = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Mystical.Flamethrower,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.192108154, 0.183631241, 0.0121765137, 1, -6.33751573e-17, 2.28174031e-8, 1.47408879e-18, 1.00000465, -1.34514666e-8, 1.35041773e-8, -7.12136439e-9, 1),
        ["BorderColor"] = v35
    }
    shared.skin_modules["[Knife]"]["RGB Karambit"] = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.147634387, 0.286956787, -0.00314331055, 8.88577406e-14, 0.798631966, 0.601811886, 1.75618051e-14, -0.601811886, 0.798631966, 1, 6.03960173e-14, 6.75013837e-14),
        ["BorderColor"] = v15
    }
    shared.skin_modules["[Knife]"].Candy = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.844940186, 0.132034421, -0.0134277344, -2.27373675e-13, 3.69608081e-26, -1, -4.33481159e-13, 0.999999523, -3.69608266e-26, 1, -4.33480942e-13, 2.27373675e-13),
        ["BorderColor"] = v35
    }
    shared.skin_modules["[Revolver]"].Candy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Candy.RevolverCandy,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.35, -0.0681198835, 0.00198364258, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v35
    }
    shared.skin_modules["[Double-Barrel SG]"].Candy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Candy.DBCandy,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0430603027, -0.0375298262, -0.00198364258, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v35
    }
    shared.skin_modules["[LMG]"].Candy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Candy.LMG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.125213623, -0.30771935, -0.0625305176, -4.37113883e-8, 0, 1, 0, 1, 0, -1, 0, -4.37113883e-8),
        ["BorderColor"] = v35
    }
    shared.skin_modules["[RPG]"].Candy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Candy.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00387573242, -0.14110744, -0.552215576, -1, 5.55111512e-17, 4.37113883e-8, -5.58290533e-17, 1, -7.27279868e-12, -4.37113883e-8, 7.27279868e-12, -1),
        ["BorderColor"] = v35,
        ["LauncherCFrame"] = CFrame.new(0.00396728516, 0.00116837025, 0.855957031, -1, 5.55111479e-17, 4.37113883e-8, -5.58340561e-17, 1, -7.38732513e-12, -4.37113883e-8, 7.38732513e-12, -1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Candy.RPGLAUNCHER
    }
    shared.skin_modules["[RPG]"].Cake = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Barbie.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0417480469, 0.253171682, 1.63067627, 4.37113883e-8, 3.46944654e-18, 1, -4.00865674e-13, 1, 3.48696912e-18, -1, 4.00865674e-13, 4.37113883e-8),
        ["BorderColor"] = v1,
        ["LauncherCFrame"] = CFrame.new(-0.0161437988, 0.275420427, -0.27822876, 3.46944675e-18, -4.37113883e-8, 1, 1, 5.15392091e-13, 3.49197522e-18, 5.15392091e-13, 1, 4.37113883e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Barbie.rpglaunhcher
    }
    shared.skin_modules["[Double-Barrel SG]"].Car = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Barbie.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0457763672, 0.0508109927, 0.000579833984, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Revolver]"].Skeleton = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Barbie.Revol,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0218505859, -0.0277693868, 0.0029296875, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Flamethrower]"].Doll = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Barbie.FT,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.450744629, -0.232652962, 0.0798339844, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Knife]"].Banana = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.371171594, -0.131195068, 0.0763549805, 0, 1, 0, 0, 0, -1, -1, 0, 0)
    }
    shared.skin_modules["[RPG]"].Soul = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Soul.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0071105957, -0.0523811579, -1.09643555, -4.37113883e-8, -1.16415322e-10, -1, 7.68569407e-6, 1, -1.16751275e-10, 1, -7.68569407e-6, -4.37113847e-8),
        ["BorderColor"] = v36,
        ["LauncherCFrame"] = CFrame.new(-0.0195617676, 0.0611854792, -0.0733947754, -4.37113883e-8, -1.16415322e-10, -1, 7.68569407e-6, 1, -1.16751275e-10, 1, -7.68569407e-6, -4.37113847e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Soul.launcher
    }
    shared.skin_modules["[Double-Barrel SG]"].Soul = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Soul.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.405822754, 0.0975035429, -0.00506591797, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Revolver]"].Soul = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Soul.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0646362305, 0.2725088, -0.00242614746, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[TacticalShotgun]"].Soul = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Soul.tact,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.347473145, 0.0268714428, 0.00553894043, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Knife]"].Soul = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.129888415, 0.0243530273, -0.0148620605, 1, 0, 0, 0, -1, 0, 0, 0, -1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Silencer]"].Mummy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Raygun.mummy,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0105285645, -0.00735360384, -0.277282715, -1, -2.44256403e-16, 4.37114309e-8, 0, 0.999999046, -5.58793545e-9, -4.37113883e-8, 5.58793545e-9, -1.00000095),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Revolver]"].Halloween23 = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Halloween.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0257873535, -0.0117108226, -0.00671386719, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Knife]"].Halloween23 = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.293486953, -0.203857422, 0.0588989258, -6.05363013e-8, 1, -3.97904366e-13, 1, 6.05363013e-8, 9.94765387e-14, 9.94765658e-14, -3.97904366e-13, -1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Double-Barrel SG]"].Halloween23 = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Halloween.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00271606445, -0.0485508144, 0.000732421875, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[TacticalShotgun]"].Halloween23 = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Halloween.Tact,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0715637207, -0.0843618512, 0.00582885742, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Shotgun]"].Halloween23 = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Halloween.SG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00573730469, 0.294590235, -0.115814209, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[RPG]"].Halloween23 = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Halloween.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0249633789, -0.048746109, 0.659362793, -1, 1.73472327e-18, 4.37113883e-8, -1.74223304e-18, 1, -1.7180124e-13, -4.37113883e-8, 1.7180124e-13, -1),
        ["BorderColor"] = v36,
        ["LauncherCFrame"] = CFrame.new(0.0485229492, 0.0587707758, -0.265991211, -1, 1.73472337e-18, 4.37113883e-8, -1.74723913e-18, 1, -2.86327629e-13, -4.37113883e-8, 2.86327629e-13, -1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Halloween.Launcher
    }
    shared.skin_modules["[TacticalShotgun]"].Numbers = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Numbers.Tactical,
        ["Rarity"] = "Legendary",
        ["CFrame"] = CFrame.new(-0.347015381, -0.101575613, -0.0437011719, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v36,
        ["Crate"] = 999
    }
    shared.skin_modules["[Double-Barrel SG]"].Magma = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Numbers.MagmaDB,
        ["Rarity"] = "Legendary",
        ["CFrame"] = CFrame.new(-0.750671387, 0.339070976, 0.0111999512, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v36,
        ["Crate"] = 999
    }
    shared.skin_modules["[TacticalShotgun]"].Undead = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Undead.Tact,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.558105469, -0.00996416807, 0.0152893066, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[RPG]"].Undead = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Undead.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0429077148, 0.0559833646, 2.07913208, -4.37113883e-8, -7.27595761e-12, -1, 1.20086924e-7, 1, 7.27070834e-12, 1, 1.20086924e-7, -4.37113883e-8),
        ["BorderColor"] = v36,
        ["LauncherCFrame"] = CFrame.new(0.0203552246, -0.0671813488, 0.119415283, -4.37113883e-8, -7.27595761e-12, -1, 1.20087037e-7, 1, 7.27070834e-12, 1, 1.20087037e-7, -4.37113883e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Undead.Rocket
    }
    shared.skin_modules["[Revolver]"].Undead = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Undead.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.202331543, 0.0300472379, -0.00631713867, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Knife]"].Undead = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0730648041, 0.029083252, 0.00421142578, -1, 0, 0, 0, -1, 0, 0, 0, 1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Double-Barrel SG]"].Undead = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Undead.AstroDB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.193084717, 0.17139101, 0.00225830078, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Revolver]"].Spooky = {
        ["DisplayName"] = "Jason",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Spooky.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0029296875, -0.0561903119, -0.011138916, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[TacticalShotgun]"].Spooky = {
        ["DisplayName"] = "Blood",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Spooky.tact,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.199981689, -0.124790192, -0.00152587891, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[RPG]"].Spooky = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Spooky.Rocket,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00857543945, -0.00493192673, -0.046875, -1, 2.8421706e-14, 4.37113883e-8, -2.90778652e-14, 1, -1.5011139e-8, -4.37113883e-8, 1.5011139e-8, -1),
        ["BorderColor"] = v36,
        ["LauncherCFrame"] = CFrame.new(-0.0168762207, 0.0170578957, 0.00112915039, -1, 2.84217043e-14, 4.37113883e-8, -2.9077872e-14, 1, -1.50112527e-8, -4.37113883e-8, 1.50112527e-8, -1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Spooky.Launcher
    }
    shared.skin_modules["[Flamethrower]"].Spooky = {
        ["DisplayName"] = "Eye",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Spooky.FT,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.415008545, 0.349902928, -0.00164794922, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Double-Barrel SG]"].Spooky = {
        ["DisplayName"] = "Eye",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Spooky.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.170593262, 0.0795405507, -0.0000610351562, 1, 0, 0, 0, 0.999999762, 0, 0, 0, 0.999999762),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Knife]"].Spooky = {
        ["DisplayName"] = "Magma",
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.10736084, -0.0247398615, -0.0214538574, 1.19212316e-7, 1, -2.78531907e-12, 0.999999523, -1.1921226e-7, 6.96321581e-13, 6.96321635e-13, -2.78531885e-12, -1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Revolver]"].Etheral = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Etheral.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0255432129, -0.0427106023, 0.0140380859, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v38
    }
    shared.skin_modules["[Double-Barrel SG]"].Etheral = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Etheral.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0578613281, -0.0133004785, 0.0168457031, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v38
    }
    shared.skin_modules["[Flamethrower]"].Etheral = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Etheral.ft,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.119934082, 0.0947337747, -0.00924682617, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v38
    }
    shared.skin_modules["[RPG]"].Etheral = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Etheral.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00695800781, 0.150677085, 0.714691162, 4.74366786e-8, -1.11847207e-16, 1, -6.00474408e-8, 1, 2.51291001e-15, -1, 6.00474408e-8, 3.9986098e-8),
        ["BorderColor"] = v38,
        ["LauncherCFrame"] = CFrame.new(-0.0138549805, -0.0158934593, 0.209564209, 4.74366786e-8, -1.11847313e-16, 1, -6.00475545e-8, 1, 2.51291467e-15, -1, 6.00475545e-8, 3.9986098e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Etheral.Launcher
    }
    shared.skin_modules["[Knife]"].Etheral = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.540863037, -0.00247907639, 0.124786377, -1, 0, 0, 0, 0.999999523, 0, 0, 0, -1),
        ["BorderColor"] = v38
    }
    shared.skin_modules["[Revolver]"].Ice = {
        ["DisplayName"] = "Frozen",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ice.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0299072266, 0.0293902755, -0.0108032227, 1, 0, 0, 0, 0, 1, 0, -1, 0),
        ["BorderColor"] = v39
    }
    shared.skin_modules["[TacticalShotgun]"].Ice = {
        ["DisplayName"] = "Frozen",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ice.tact,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.151062012, 0.0138154626, 0.000366210938, 1, 0, 0, 0, 0, 1, 0, -1, 0),
        ["BorderColor"] = v39
    }
    shared.skin_modules["[Knife]"]["Ice Sword"] = {
        ["DisplayName"] = "Ice Dagger",
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.248702049, 0.00454711914, -0.00390625, 2.44929371e-16, 1, 1.62920657e-7, 1.99519599e-23, 1.62920202e-7, -0.999997616, -1, 2.44929371e-16, 1.99520262e-23),
        ["BorderColor"] = v39
    }
    shared.skin_modules["[Double-Barrel SG]"].Ice = {
        ["DisplayName"] = "Frozen",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ice.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.574920654, 0.309675515, 0.0344848633, -1, 0, 0, 0, 0, 1, 0, 1, 0),
        ["BorderColor"] = v39
    }
    shared.skin_modules["[RPG]"].Ice = {
        ["DisplayName"] = "Frozen",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ice.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00628662109, -0.0235987902, -1.82954407, -4.37113883e-8, 1, 1.62920685e-7, 4.00923896e-13, -1.62920685e-7, 1, 1, 4.37113883e-8, 4.08045397e-13),
        ["BorderColor"] = v39,
        ["LauncherCFrame"] = CFrame.new(-0.00628662109, 0.00532734394, 0.364135742, -4.37113883e-8, 1, 0, 5.15450313e-13, 2.2531046e-20, 1, 1, 4.37113883e-8, 5.15450313e-13),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ice.Launcher
    }
    shared.skin_modules["[Revolver]"].Hoodmas = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Hoodmas.revolver,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00862121582, -0.000740110874, -0.0009765625, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    }
    shared.skin_modules["[Double-Barrel SG]"].Hoodmas = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Hoodmas.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0) * CFrame.Angles(0, 3.141592653589793, 0)
    }
    shared.skin_modules["[Shotgun]"].Hoodmas = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Hoodmas.shotgun,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0) * CFrame.Angles(0, -1.5707963267948966, 0)
    }
    shared.skin_modules["[AR]"].Hoodmas = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Hoodmas.ar,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0) * CFrame.Angles(0, 3.141592653589793, 0)
    }
    shared.skin_modules["[TacticalShotgun]"].Hoodmas = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Hoodmas.tact,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0)
    }
    shared.skin_modules["[Flamethrower]"].Hoodmas = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Hoodmas.flamethrower,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0) * CFrame.Angles(0, 3.141592653589793, 0)
    }
    shared.skin_modules["[RPG]"].Hoodmas = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Hoodmas.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0) * CFrame.Angles(0, -1.5707963267948966, 0)
    }
    shared.skin_modules["[Knife]"].Hoodmas = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0)
    }
    shared.skin_modules["[Revolver]"].XMAS = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.XMAS.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0034942627, -0.0323467255, -0.000244140625, -1.00000095, 7.45058149e-9, 0, -7.45058149e-9, 0.999999523, 0, 0, 0, -1)
    }
    shared.skin_modules["[Knife]"].XMAS = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-1.27282023, -0.128097534, -0.0394134521, 2.75315642e-7, 0.719339967, 0.694658518, -4.80564211e-9, 0.694658518, -0.719339967, -1, 1.94707184e-7, 1.94707169e-7)
    }
    shared.skin_modules["[Flamethrower]"].XMAS = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.XMAS.Flamethrower,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.528900146, 0.0900247097, 0.00065612793, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    }
    shared.skin_modules["[RPG]"].XMAS = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.XMAS.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0332183838, -0.105202198, -2.14428711, 4.37113883e-8, 0, 1, -5.72632016e-14, 1, 2.50305399e-21, -1, 5.72632016e-14, 4.37113883e-8),
        ["LauncherCFrame"] = CFrame.new(0.0412902832, 0.0782194138, -0.438598633, 4.37113883e-8, 8.14188054e-17, 1, -1.86270244e-9, 1, 2.50305399e-21, -1, -1.86258786e-9, 4.37113883e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.XMAS.Ornament
    }
    shared.skin_modules["[Double-Barrel SG]"].XMAS = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.XMAS.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(1.39941406, 0.0596529841, -0.0409545898, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    }
    shared.skin_modules["[Knife]"]["Crystal Karambit"] = {
        ["DisplayName"] = "King Karambit",
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-1.59968805, -0.0777282715, -0.0473022461, 0, 0.37460658, -0.927183867, 0, 0.927183867, 0.37460658, 1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Knife]"]["Galaxy Karambit"] = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-1.28114009, -0.0814056396, -0.0313110352, -0.342020094, -0.939692557, 0, -0.939692557, 0.342020094, 0, -0, 0, -1),
        ["BorderColor"] = v20
    }
    shared.skin_modules["[Revolver]"]["Wild West"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.WildWest.Rev,
        ["Rarity"] = "Legendary",
        ["CFrame"] = CFrame.new(0.00323486328, -0.110876054, -0.00628662109, 0, 0, 0.999995708, 0, 1, 0, -1, 0, 0),
        ["Crate"] = 999
    }
    shared.skin_modules["[Double-Barrel SG]"]["Wild West"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.WildWest.DB,
        ["Rarity"] = "Legendary",
        ["CFrame"] = CFrame.new(-0.159378052, -0.123334587, -0.00241088867, 0, 0, -0.999995232, 0, 1, 0, 1, 0, 0),
        ["Crate"] = 999
    }
    shared.skin_modules["[Knife]"]["Wild West"] = {
        ["Rarity"] = "Legendary",
        ["CFrame"] = CFrame.new(0.383782029, 0.0114746094, -0.00112915039, 0, -1, 0, 1, 0, 0, 0, 0, 1),
        ["Crate"] = 999
    }
    shared.skin_modules["[Revolver]"].Portal = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Portal.rev,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v2,
        ["CFrame"] = CFrame.new(0.072303772, 0.0471935868, -0.0138244629, -1, 0, 0, 0, 0.99999994, 0, 0, 0, -1)
    }
    shared.skin_modules["[TacticalShotgun]"].Portal = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Portal.Tact,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v2,
        ["CFrame"] = CFrame.new(-1.0434494, 0.0293064713, -0.063079834, -1, 0, 0, 0, 1, 0, 0, 0, -1)
    }
    shared.skin_modules["[Double-Barrel SG]"].Portal = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Portal.DB,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v2,
        ["CFrame"] = CFrame.new(0.296951294, -0.054553628, 0.0379638672, 0.99999702, 0, 0, 0, 1, 0, 0, 0, 1)
    }
    shared.skin_modules["[Knife]"].Portal = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v2,
        ["CFrame"] = CFrame.new(-0.102067709, 0.150634766, -0.00653076172, 0, 0.999999225, 0, 0.999999166, 0, 0, 0, 0, -1)
    }
    shared.skin_modules["[RPG]"].Portal = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Portal.rpg,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v2,
        ["CFrame"] = CFrame.new(0.00946044922, -0.19871664, 0.647293091, 4.37114167e-8, -6.46234854e-27, 1, -4.00862828e-13, 1, 1.75222655e-20, -1, 4.00862828e-13, 4.37113599e-8),
        ["LauncherCFrame"] = CFrame.new(-0.0126037598, 0.00348734856, -0.17477417, 4.37114167e-8, -8.07793567e-27, 1, -5.15389272e-13, 1, 2.2528369e-20, -1, 5.15389272e-13, 4.37113599e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Portal.launcher
    }
    shared.skin_modules["[Revolver]"].Ninja = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ninja.NinjaRev,
        ["Rarity"] = "Legendary",
        ["CFrame"] = CFrame.new(0.0598754883, 0.102456093, 0.00305175781, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["Crate"] = 999
    }
    shared.skin_modules["[Double-Barrel SG]"].Ninja = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ninja.NinjaDB,
        ["Rarity"] = "Legendary",
        ["CFrame"] = CFrame.new(-0.0128631592, 0.0259246826, -0.00207519531, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["Crate"] = 999
    }
    shared.skin_modules["[Revolver]"].Love = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Love.rev,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v1,
        ["CFrame"] = CFrame.new(-0.0348358154, -0.112736881, 0.0156860352, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    }
    shared.skin_modules["[TacticalShotgun]"].Love = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Love.Tact,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v1,
        ["CFrame"] = CFrame.new(-0.0231781006, -0.114733696, 0.0161743164, 0, 0, 0.999999821, 0, 0.999998748, 0, -1, 0, 0)
    }
    shared.skin_modules["[Double-Barrel SG]"].Love = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Love.DB,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v1,
        ["CFrame"] = CFrame.new(0.159469604, -0.16393137, -0.00659179688, -1, 0, 0, 0, 0.999999106, 0, 0, 0, -1)
    }
    shared.skin_modules["[RPG]"].Love = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Love.rpg,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v1,
        ["CFrame"] = CFrame.new(0.020324707, -0.0424976349, 0.149459839, -4.37113883e-8, -5.55111512e-17, -1, 3.60756173e-12, 1, 5.53534575e-17, 1, 3.60756173e-12, -4.37113883e-8),
        ["LauncherCFrame"] = CFrame.new(0.020690918, 0.02942276, -0.542907715, -4.37113883e-8, -5.55111512e-17, -1, 3.72208818e-12, 1, 5.53484481e-17, 1, 3.72208818e-12, -4.37113883e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Love.Launcher
    }
    shared.skin_modules["[Flamethrower]"].Love = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Love.FT,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.306655884, -0.30743885, -0.00744628906, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Knife]"].Love = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v1,
        ["CFrame"] = CFrame.new(-0.352311015, 0.0614624023, -0.0600585938, 5.96049716e-8, 1, 3.97904366e-13, -1, 5.96049716e-8, -9.94765387e-14, -9.94765658e-14, -3.97904366e-13, 1)
    }
    shared.skin_modules["[Revolver]"].Cupid = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cupid.rev,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v1,
        ["CFrame"] = CFrame.new(0.0240020752, 0.229963183, -0.0170898438, 0, 0, -1, 0, 1, 0, 1, 0, 0)
    }
    shared.skin_modules["[Double-Barrel SG]"].Cupid = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cupid.db,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v1,
        ["CFrame"] = CFrame.new(-0.0375976562, 0.048615396, 0.00555419922, 0, 0, 1, 0, 0.999998212, 0, -1, 0, 0)
    }
    shared.skin_modules["[Knife]"].Cupid = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v1,
        ["CFrame"] = CFrame.new(0.248047352, -0.0400543213, -0.0659179688, 0, 1, 0, 0.999998093, 0, 0, 0, 0, -1)
    }
    shared.skin_modules["[RPG]"].Cupid = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cupid.rpg,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v1,
        ["CFrame"] = CFrame.new(0.00213623047, 0.156091571, 1.50897217, -4.37113883e-8, 1, -8.8817842e-16, 1.4601792e-11, -8.87540127e-16, 1, 1, 4.37113883e-8, 1.4601792e-11),
        ["LauncherCFrame"] = CFrame.new(0.282226562, 0.142233849, -0.418685913, -4.37113883e-8, 1, -8.8817842e-16, 1.47163184e-11, -8.87535151e-16, 1, 1, 4.37113883e-8, 1.47163184e-11),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cupid.Launcher
    }
    shared.skin_modules["[Revolver]"].Shader = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shader.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00216674805, 0.0199100971, -0.00390625, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["DisplayName"] = "Squid",
        ["BorderColor"] = v24
    }
    shared.skin_modules["[Double-Barrel SG]"].Shader = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shader.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0402069092, -0.0140712261, -0.0110473633, 0, 0, 1, 0, 0.999995232, 0, -1, 0, 0),
        ["DisplayName"] = "Panda",
        ["BorderColor"] = v24
    }
    shared.skin_modules["[RPG]"].Shader = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shader.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.020324707, 0.0273060203, 0.97354126, 1, 0, -4.37113883e-8, 1.05004345e-14, 1, 2.40221937e-7, 4.37113883e-8, 2.40221937e-7, 1),
        ["LauncherCFrame"] = CFrame.new(-0.00769042969, -0.0627783537, -1.30299377, 1, 0, -4.37113883e-8, 1.05004396e-14, 1, 2.4022205e-7, 4.37113883e-8, 2.4022205e-7, 1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shader.Bear,
        ["DisplayName"] = "Arcade",
        ["BorderColor"] = v24
    }
    shared.skin_modules["[Knife]"].Shader = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.338645697, 0.000183105469, 0.0258331299, -1, 0, 0, 0, -1, 0, 0, 0, 1),
        ["DisplayName"] = "Chain",
        ["BorderColor"] = v24
    }
    shared.skin_modules["[Flamethrower]"].Shader = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shader.FT,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.144821167, 0.0677314401, -0.00170898438, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["DisplayName"] = "Boba",
        ["BorderColor"] = v24
    }
    shared.skin_modules["[Knife]"]["Dual Bayonets"] = {
        ["CFrame"] = CFrame.new(-0.520424962, 0.0484008789, -0.00109863281, 0, 1, 0, 1, 0, 0, 0, 0, -1),
        ["Rarity"] = "Legendary",
        ["Crate"] = 999
    }
    shared.skin_modules["[Knife]"]["RGB Dual Bayonets"] = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.520424962, 0.0484008789, -0.00109863281, 0, 1, 0, 1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v15
    }
    shared.skin_modules["[Revolver]"].Military = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Military.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0181350708, -0.10841608, -0.00543212891, 0, 0, 1, 1.49010297e-8, 1, 0, -1, 1.49010297e-8, 0),
        ["BorderColor"] = v11
    }
    shared.skin_modules["[TacticalShotgun]"].Military = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Military.Tact,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.916564941, -0.0996659398, 0.128448486, 0, 0, 0.999999642, 2.98023224e-8, 1.00000012, 0, -1.00000012, -2.98023224e-8, 0),
        ["BorderColor"] = v11
    }
    shared.skin_modules["[AUG]"].Military = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Military.Aug,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.108810425, 0.0431235433, 0.018737793, 0, 0, 1, 0, 1.00000012, 0, -1.00000012, 0, 0),
        ["BorderColor"] = v11
    }
    shared.skin_modules["[RPG]"].Military = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Military.RPG,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v11,
        ["CFrame"] = CFrame.new(-0.0317993164, 0.0230810642, 0.252548218, -1, -4.06575815e-20, 4.37113883e-8, -3.3601404e-13, 1, -7.68710379e-6, -4.37113883e-8, -7.68710379e-6, -1),
        ["LauncherCFrame"] = CFrame.new(0.000793457031, 0.00350522995, 0.530632019, -1, -2.71050543e-20, 4.37113883e-8, -3.3601404e-13, 1, -7.68710379e-6, -4.37113883e-8, -7.68710379e-6, -1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Military.Launcher
    }
    shared.skin_modules["[Double-Barrel SG]"].Military = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Military.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.547592163, 0.0359069705, -0.00466918945, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v11
    }
    shared.skin_modules["[Knife]"].Military = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0253430605, 0.106079102, 0.000465393066, 0, 3.25960725e-9, -1, 0, 1, 3.25960747e-9, 1, 0, -0),
        ["BorderColor"] = v11
    }
    shared.skin_modules["[Vehicle]"]["Toy Tank"] = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v11
    }
    shared.skin_modules["[Vehicle]"].Tractor = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v11
    }
    shared.skin_modules["[Vehicle]"].Cow = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v11
    }
    shared.skin_modules["[Revolver]"].Ruby = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ruby.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0331878662, -0.0243580937, 0.000518798828, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v3
    }
    shared.skin_modules["[Double-Barrel SG]"].Ruby = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ruby.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0772705078, -0.0124946237, -0.00723266602, 0, 0, 0.999999642, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v3
    }
    shared.skin_modules["[RPG]"].Ruby = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ruby.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00457763672, 0.226767719, 0.190460205, 1, 5.82076609e-11, -4.37113883e-8, -5.78716935e-11, 1, 7.68612699e-6, 4.37113883e-8, -7.68612699e-6, 1),
        ["LauncherCFrame"] = CFrame.new(0.00180053711, 0.000730276108, 0.176605225, 1, 5.82076609e-11, -4.37113883e-8, -5.78716935e-11, 1, 7.68612699e-6, 4.37113883e-8, -7.68612699e-6, 1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ruby.Launcher,
        ["BorderColor"] = v3
    }
    shared.skin_modules["[Flamethrower]"].Ruby = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ruby.ft,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.262329102, 0.352797449, -0.00415039062, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v3
    }
    shared.skin_modules["[Knife]"]["Ruby Fan"] = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.531107247, -0.00726318359, 0.0272521973, 0, 1, 0, -1, 0, 0, 0, 0, 1),
        ["BorderColor"] = v3
    }
    shared.skin_modules["[Vehicle]"].Beatle = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Vehicle]"].TriWheel = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Vehicle]"]["TriWheel Red"] = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 999
    }
    shared.skin_modules["[House]"]["Modern Town"] = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[House]"]["Holiday Town"] = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[House]"]["Gingerbread House"] = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Knife]"].Spatula = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.301204205, 0.0112304688, -0.0121459961, 0, 1, 0, 0, 0, -1, -1, 0, 0)
    }
    shared.skin_modules["[House]"]["Pizza Restaurant"] = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Vehicle]"]["Delivery Moped"] = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Vehicle]"]["Delivery Car"] = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Revolver]"].Gothic = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.gothic.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0787200928, 0.0141905546, -0.00573730469, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v8
    }
    shared.skin_modules["[Double-Barrel SG]"].Gothic = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.gothic.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.194915771, 0.174392939, -0.001953125, 0.999998927, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v8
    }
    shared.skin_modules["[Drum-Shotgun]"].Gothic = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.gothic.Drum,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0383834839, 0.183659613, 0.00665283203, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v8
    }
    shared.skin_modules["[RPG]"].Gothic = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.gothic.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0112915039, -0.00845080614, 0.563346863, 4.37113883e-8, 3.97903932e-13, 1, -2.4017919e-7, 1, 4.08402479e-13, -1, 2.4017919e-7, 4.37113883e-8),
        ["LauncherCFrame"] = CFrame.new(0.0000610351562, 0.00457000732, -0.492790222, 4.37113883e-8, 3.97903932e-13, 0.999999642, -2.40179304e-7, 1, 4.08402343e-13, -1, 2.40179304e-7, 4.37113741e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.gothic.Launcher,
        ["BorderColor"] = v8
    }
    shared.skin_modules["[Knife]"].Gothic = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.140083313, 0.0152206421, 0.00164794922, 0, 1, 0, 1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v8
    }
    shared.skin_modules["[House]"]["Garage Home"] = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Vehicle]"]["Muscle B"] = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Vehicle]"]["Muscle B [Black]"] = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 999
    }
    shared.skin_modules["[Vehicle]"]["Muscle C"] = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Vehicle]"]["Muscle C [Black]"] = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 999
    }
    shared.skin_modules["[Vehicle]"]["Muscle C [Purple]"] = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 999
    }
    shared.skin_modules["[Vehicle]"]["SUV [Black]"] = {
        ["DisplayName"] = "PogiMobile [SUV]",
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Vehicle]"].Police = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Vehicle]"].Sedan = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Vehicle]"]["GT Kart"] = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 999
    }
    shared.skin_modules["[Vehicle]"]["Supe Kart"] = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 999
    }
    shared.skin_modules["[Vehicle]"].McMelon = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 999
    }
    shared.skin_modules["[Knife]"]["Blue Dagger"] = {
        ["DisplayName"] = "Blue Blaze",
        ["BorderColor"] = v19,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.672592163, -0.0405571461, -0.129821777, 5.96044032e-8, 0.999998093, -3.97903607e-13, -0.999990463, -5.96044032e-8, 9.94756171e-14, -9.94756171e-14, -3.97903607e-13, 1)
    }
    shared.skin_modules["[Knife]"]["Purple Dagger"] = {
        ["DisplayName"] = "Purple Blaze",
        ["BorderColor"] = v4,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.680389404, -0.0405454636, -0.0369262695, 5.96057674e-8, 0.999998093, 1.19371158e-12, 0.999990463, -1.78813664e-7, -2.98427868e-13, -9.94784563e-14, 3.97905884e-13, -1)
    }
    shared.skin_modules["[Knife]"]["Green Dagger"] = {
        ["DisplayName"] = "Green Blaze",
        ["BorderColor"] = v33,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0952148438, -0.0405509472, -0.0215454102, 5.96057674e-8, 0.999998093, 1.19371158e-12, 0.999990463, -1.78813664e-7, -2.98427868e-13, -9.94784563e-14, 3.97905884e-13, -1)
    }
    shared.skin_modules["[Knife]"]["Red Dagger"] = {
        ["DisplayName"] = "Red Blaze",
        ["BorderColor"] = v25,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.105102539, -0.0555841923, -0.0150146484, -5.96057674e-8, 0.999998093, -1.19371158e-12, -0.999990463, -1.78813664e-7, 2.98427868e-13, 9.94784563e-14, 3.97905884e-13, 1)
    }
    shared.skin_modules["[Knife]"]["Penguin Ice Cream"] = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0781555176, 0.0322579145, -0.172119141, -8.67361738e-19, 1, 4.18487431e-8, 1.86264515e-9, -4.55740334e-8, 1, 1, -8.22861671e-17, 1.86264515e-9),
        ["BorderColor"] = v12
    }
    shared.skin_modules["[Revolver]"].Penguin = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Penguin.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.202697754, 0.0907911062, 0.0120239258, 2.46913861e-12, -3.7252903e-8, 1, 2.98028908e-8, 1.00000191, -3.7252903e-8, -1, -2.98028908e-8, -2.46916289e-12),
        ["BorderColor"] = v12
    }
    shared.skin_modules["[Double-Barrel SG]"].Penguin = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Penguin.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00805664062, 0.10456717, -0.0380859375, -2.87964097e-16, -9.31328259e-9, -0.99999994, 9.31322686e-10, 1.00000036, 8.38193159e-9, 1, 1.86264537e-9, 2.90566156e-16),
        ["BorderColor"] = v12
    }
    shared.skin_modules["[RPG]"].Penguin = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Penguin.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0556030273, 0.0265565515, 1.0914917, 1, 5.58498714e-9, -4.37113989e-8, 5.5850089e-9, 1.0000031, 4.9060327e-7, 4.37113918e-8, 4.90604634e-7, 1.00000024),
        ["LauncherCFrame"] = CFrame.new(-0.00408935547, -0.00542700291, 0.0866088867, 1, -4.37113883e-8, -9.28367105e-10, 9.283877e-10, 4.82221196e-7, -1.0000006, 4.37113883e-8, 1, -4.82221481e-7),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Penguin.Launcher,
        ["BorderColor"] = v12
    }
    shared.skin_modules["[Flamethrower]"].Penguin = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Penguin.FT,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.146240234, 0.487559378, -0.0191040039, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v12
    }
    shared.skin_modules["[Knife]"].Metal = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.273397565, 0.00601196289, 0.00988769531, 0, 1, 0, -0.999998927, 0, 0, 0, 0, 1)
    }
    shared.skin_modules["[Revolver]"].Metal = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Metal.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0964050293, -0.0217685103, -0.000549316406, 1, 0, -1.50995803e-7, 0, 0.999999642, 0, 1.50995803e-7, 0, 1)
    }
    shared.skin_modules["[Double-Barrel SG]"].Metal = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Metal.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.125686646, -0.135336846, 0.00628662109, 0, 0, -1, 0, 0.999998212, 0, 1, 0, 0)
    }
    shared.skin_modules["[Flamethrower]"].Metal = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Metal.ft,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.14163208, 0.573509276, 0.024230957, 0, 0, -1, 0, 0.999999046, 0, 1, 0, 0)
    }
    shared.skin_modules["[Rifle]"].Metal = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Metal.rifle,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.285713196, 0.0110580921, -0.000793457031, 2.01746307e-17, -2.32830588e-10, 1.00000024, -3.18550298e-17, 0.999999523, -2.32830644e-10, -1, 3.18550232e-17, -2.01746307e-17)
    }
    shared.skin_modules["[RPG]"].Metal = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Metal.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00189208984, 0.109036505, 0.657577515, -1, 8.88178314e-16, 4.37113741e-8, -9.08680958e-16, 0.999999881, -4.69042416e-10, -4.37113883e-8, 4.69042527e-10, -0.999999642),
        ["LauncherCFrame"] = CFrame.new(-0.00189208984, -0.000738143921, -0.14730072, -1, 8.8817842e-16, 4.37113812e-8, -9.0868604e-16, 0.999999881, -4.69157047e-10, -4.37113883e-8, 4.69157102e-10, -0.999999821),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Metal.launcher
    }
    shared.skin_modules["[Revolver]"]["Iced Out"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.IcedOut.rev,
        ["Rarity"] = "Legendary",
        ["Crate"] = 1,
        ["CFrame"] = CFrame.new(-0.0419578552, -0.0496253371, -0.0009765625, 0, 0, -1, 0, 1, 0, 1, 0, 0)
    }
    shared.skin_modules["[Double-Barrel SG]"]["Iced Out"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.IcedOut.db,
        ["Rarity"] = "Legendary",
        ["Crate"] = 1,
        ["CFrame"] = CFrame.new(-0.0154724121, -0.0110113621, -0.00543212891, 0, 0, 1.00000036, 0, 1.00000036, 0, -1, 0, 0)
    }
    shared.skin_modules["[Knife]"]["Iced Out"] = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 1,
        ["CFrame"] = CFrame.new(-1.58911133, 0.185030937, -0.00385284424, -1.00000036, 0, 0, 0, 0.999999881, 0, 0, 0, -1)
    }
    shared.skin_modules["[Revolver]"].Cat = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cat.Rev,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v9,
        ["CFrame"] = CFrame.new(-0.0353851318, 0.0917409062, -0.001953125, 1, 0, 0, 0, 1, -3.25059848e-30, 0, -3.25059848e-30, 1)
    }
    shared.skin_modules["[RPG]"].Cat = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cat.rpg,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v9,
        ["CFrame"] = CFrame.new(-0.0182495117, 0.288909316, -0.0680465698, -4.37113883e-8, 4.54747351e-13, -1, 1.92143443e-6, 1, -5.3873594e-13, 1, 1.92143443e-6, -4.37113883e-8),
        ["LauncherCFrame"] = CFrame.new(0.00256347656, 0.0618466139, -0.43542099, -1, 4.54747351e-13, 0, -4.54747351e-13, 1, -1.92143443e-6, 0, 1.92143443e-6, -1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cat.Rocket
    }
    shared.skin_modules["[Drum-Shotgun]"].Cat = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cat.drum,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v9,
        ["CFrame"] = CFrame.new(-0.0637664795, 0.164270639, 0.00408935547, -1, 1.62920685e-7, 1.79568244e-22, 1.62920685e-7, 1, -2.44927253e-16, 1.99519584e-23, -2.44929794e-16, -1)
    }
    shared.skin_modules["[Knife]"].Cat = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v9,
        ["CFrame"] = CFrame.new(-1.25782871, 0.0180130005, 0.0354003906, 0, 5.96046448e-8, 1, 0, 1, -5.96046448e-8, -1, 0, 0)
    }
    shared.skin_modules["[Double-Barrel SG]"].Cat = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Cat.db,
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v9,
        ["CFrame"] = CFrame.new(-0.321357727, -0.021577239, -0.000366210938, -1, 0, 0, 0, 1, -3.25059773e-30, 0, 3.25059773e-30, -1)
    }
    shared.skin_modules["[Revolver]"].Unicorn = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Unicorn.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.105384827, 0.208259106, 0.00799560547, 1, -5.87381323e-27, 0, -5.87381323e-27, 1, 0, 0, 0, 1),
        ["BorderColor"] = v26
    }
    shared.skin_modules["[Knife]"].Unicorn = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0699813366, -0.0199928284, 0.151672363, 6.21539241e-22, 1, 0, 1, 6.21539241e-22, -3.57623663e-17, 3.57623663e-17, 0, -1),
        ["BorderColor"] = v26
    }
    shared.skin_modules["[Double-Barrel SG]"].Unicorn = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Unicorn.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.204410553, 0.268578529, 0.0223999023, -1.00000572, 2.90278896e-27, 0, -2.90275526e-27, 0.999988556, 0, 0, 0, -0.999994278),
        ["BorderColor"] = v26
    }
    shared.skin_modules["[TacticalShotgun]"].Unicorn = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Unicorn.tact,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-1.15197754, 0.214885235, 0.00622558594, 0.999999523, -5.68433918e-14, 1.8623002e-9, -8.04312603e-14, 1.00000012, -4.54747351e-12, 1.86229743e-9, 4.54747351e-12, 1.00000012),
        ["BorderColor"] = v26
    }
    shared.skin_modules["[RPG]"].Unicorn = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Unicorn.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0617675781, 0.388903856, 0.322414398, -4.37113883e-8, 2.84217128e-14, -1, 1.20089595e-7, 1, -3.36709962e-14, 1, 1.20089595e-7, -4.37113883e-8),
        ["LauncherCFrame"] = CFrame.new(0.00793457031, -0.00685334206, 0.199073792, -4.37115126e-8, 2.84215908e-14, -0.999998569, 1.2009005e-7, 0.999995708, -3.36709556e-14, 1.00000286, 1.20089197e-7, -4.37113243e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Unicorn.launcher,
        ["BorderColor"] = v26
    }
    shared.skin_modules["[Vehicle]"].Unicorn = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v26
    }
    shared.skin_modules["[Knife]"].Reptile = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 1,
        ["CFrame"] = CFrame.new(0.117903709, 0.274299622, -0.0466308594, 1, 0, 0, 0, 0.999995708, 0, 0, 0, 0.999995708)
    }
    shared.skin_modules["[Revolver]"].Reptile = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Reptile.rev,
        ["Rarity"] = "Legendary",
        ["Crate"] = 1,
        ["CFrame"] = CFrame.new(0.0178756714, 0.0200323462, -0.00146484375, 1, 0, 0, 0, 0.999995708, 0, 0, 0, 0.999995708)
    }
    shared.skin_modules["[Double-Barrel SG]"].Reptile = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Reptile.db,
        ["Rarity"] = "Legendary",
        ["Crate"] = 1,
        ["CFrame"] = CFrame.new(-0.277816772, -0.0448647141, 0.0176391602, -1, 0, 0, 0, 0.999995708, 0, 0, 0, -0.999995708)
    }
    shared.skin_modules["[Knife]"].Boy = {
        ["Rarity"] = "Exclusive",
        ["DisplayName"] = "His",
        ["CFrame"] = CFrame.new(-0.0212402344, 0.169678688, -0.0283966064, -5.96044032e-8, 0.999998093, 3.97903607e-13, 0.999990463, -5.96044032e-8, -9.94756171e-14, 9.94756171e-14, -3.97903607e-13, -1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Knife]"].Girl = {
        ["Rarity"] = "Exclusive",
        ["DisplayName"] = "Hers",
        ["CFrame"] = CFrame.new(0.168884277, 0.0223870277, 0.0336074829, 1.03316403e-7, 0.999998093, -8.7420851e-8, 0.999990463, -2.22523965e-7, -2.82794675e-13, -1.03298595e-13, -8.74220518e-8, -0.999997139),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Vehicle]"]["Electric Car"] = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 1
    }
    shared.skin_modules["[Vehicle]"].Ultra = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 1
    }
    shared.skin_modules["[Vehicle]"].Rayliner = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 1
    }
    shared.skin_modules["[Vehicle]"].Ranger = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 1
    }
    shared.skin_modules["[Vehicle]"].Ambulance = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Knife]"].Aqua = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0699813366, -0.0199928284, 0.151672363, 6.21539241e-22, 1, 0, 1, 6.21539241e-22, -3.57623663e-17, 3.57623663e-17, 0, -1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[RPG]"].Aqua = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Aqua.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0422363281, 0.243108392, -0.243370056, -4.37113883e-8, 1.79695434e-18, -1, -5.64731205e-13, 1, -1.7722692e-18, 1, -5.64731205e-13, -4.37113883e-8),
        ["LauncherCFrame"] = CFrame.new(0.00384521484, 0.00943088531, -0.653934479, -1, 1.73472337e-18, 4.37113883e-8, -1.7772753e-18, 1, -9.73473906e-13, -4.37113883e-8, 9.73473906e-13, -1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Aqua.Rocket,
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Revolver]"].Aqua = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Aqua.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.105384827, 0.208259106, 0.00799560547, 1, -5.87381323e-27, 0, -5.87381323e-27, 1, 0, 0, 0, 1),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Double-Barrel SG]"].Aqua = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Aqua.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.204410553, 0.268578529, 0.0223999023, -1.00000572, 2.90278896e-27, 0, -2.90275526e-27, 0.999988556, 0, 0, 0, -0.999994278),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Knife]"].Wire = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.114868164, 0.13845396, -0.0218524933, 3.97903038e-13, 0.999998093, 4.0978243e-8, -9.94754816e-14, -7.07802172e-8, -0.999992371, -0.999998569, -3.97903607e-13, -9.94758068e-14),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Revolver]"].Wire = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Wire.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00971221924, 0.0132867098, 0.000122070312, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Double-Barrel SG]"].Wire = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Wire.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.12754631, -0.0147626996, -0.0191040039, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[SMG]"].Wire = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Wire.smg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.228622437, -0.115716159, -0.0379638672, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Flamethrower]"].Wire = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Wire.ft,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.484739304, 0.240048289, 0.0125732422, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v19
    }
    shared.skin_modules["[RPG]"].Wire = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Wire.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.000854492188, 0.044478178, 0.30198288, -1, 2.27373621e-13, 4.37113883e-8, -2.27537661e-13, 1, -3.75266085e-9, -4.37113883e-8, 3.75266085e-9, -1),
        ["LauncherCFrame"] = CFrame.new(-0.000854492188, -0.00822412968, 0.0817947388, -1, 2.27373621e-13, 4.37113883e-8, -2.27537661e-13, 1, -3.75277542e-9, -4.37113883e-8, 3.75277542e-9, -1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Wire.Rocket,
        ["BorderColor"] = v19
    }
    shared.skin_modules["[Knife]"].SoulII = {
        ["DisplayName"] = "Ghost",
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0699813366, -0.0199928284, 0.151672363, 6.21539241e-22, 1, 0, 1, 6.21539241e-22, -3.57623663e-17, 3.57623663e-17, 0, -1),
        ["BorderColor"] = v37
    }
    shared.skin_modules["[RPG]"].SoulII = {
        ["DisplayName"] = "Ghost",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.SoulII.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0422363281, 0.243108392, -0.243370056, -4.37113883e-8, 1.79695434e-18, -1, -5.64731205e-13, 1, -1.7722692e-18, 1, -5.64731205e-13, -4.37113883e-8),
        ["LauncherCFrame"] = CFrame.new(0.00384521484, 0.00943088531, -0.653934479, -1, 1.73472337e-18, 4.37113883e-8, -1.7772753e-18, 1, -9.73473906e-13, -4.37113883e-8, 9.73473906e-13, -1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.SoulII.Rocket,
        ["BorderColor"] = v37
    }
    shared.skin_modules["[Revolver]"].SoulII = {
        ["DisplayName"] = "Ghost",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.SoulII.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.105384827, 0.208259106, 0.00799560547, 1, -5.87381323e-27, 0, -5.87381323e-27, 1, 0, 0, 0, 1),
        ["BorderColor"] = v37
    }
    shared.skin_modules["[Double-Barrel SG]"].SoulII = {
        ["DisplayName"] = "Ghost",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.SoulII.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.15, 0, 0, -1.00000572, 2.90278896e-27, 0, -2.90275526e-27, 0.999988556, 0, 0, 0, -0.999994278),
        ["BorderColor"] = v37
    }
    shared.skin_modules["[Vehicle]"].SoulII = {
        ["DisplayName"] = "Ghost",
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v37
    }
    shared.skin_modules["[Knife]"].Nightmare = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0172729492, 0.016535759, -0.0452766418, -3.97903607e-13, -5.96044032e-8, -0.999998093, 9.94756171e-14, 0.999990463, 5.96044032e-8, 1, 9.94756171e-14, 3.97903607e-13),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Revolver]"].Nightmare = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Nightmare.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.200012207, -0.0815875828, 0.0110473633, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Double-Barrel SG]"].Nightmare = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Nightmare.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.36031723, 0.00864857435, -0.00158691406, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[RPG]"].Nightmare = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Nightmare.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00720214844, 0.0332263708, 0.887256622, -4.37113883e-8, -3.23117427e-27, -1, 8.58948112e-13, 1, -3.75458152e-20, 1, 8.58948112e-13, -4.37113883e-8),
        ["LauncherCFrame"] = CFrame.new(-0.0835571289, -0.00100052357, 0.105564117, 3.23117427e-27, -4.37113741e-8, -1, -1, 9.73474231e-13, -4.25519252e-20, -9.73474556e-13, 0.999999642, -4.37113883e-8),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Nightmare.launcher,
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Flamethrower]"].Nightmare = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Nightmare.ft,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.395851135, 0.238022804, 0.079284668, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Vehicle]"].Nightmare = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Revolver]"].Butterfly = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Butterfly.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0578613281, -0.0479719043, -0.00115966797, -1.00000405, 1.15596135e-16, 1.64267286e-30, -1.15596135e-16, 1, 2.99751983e-14, 1.66683049e-30, -2.99751983e-14, -1.00000405),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Knife]"].Butterfly = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.248047352, -0.0400543213, -0.0659179688, 0, 1, 0, 0.999998093, 0, 0, 0, 0, -1),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Double-Barrel SG]"].Butterfly = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Butterfly.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.36031723, 0.00864857435, -0.00158691406, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Revolver]"].Emerald = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Emerald.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.200012207, -0.0815875828, 0.0110473633, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v22
    }
    shared.skin_modules["[Knife]"]["Emerald-Bayonet"] = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.248047352, -0.0400543213, -0.0659179688, 0, 1, 0, 0.999998093, 0, 0, 0, 0, -1),
        ["BorderColor"] = v22
    }
    shared.skin_modules["[Double-Barrel SG]"].Emerald = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Emerald.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.200012207, -0.0815875828, 0.0110473633, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v22
    }
    shared.skin_modules["[AK47]"].Emerald = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Emerald.AK,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.200012207, -0.0815875828, 0.0110473633, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v22
    }
    shared.skin_modules["[Knife]"].GPOII = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.248047352, -0.0400543213, -0.0659179688, 0, 1, 0, 0.999998093, 0, 0, 0, 0, -1),
        ["BorderColor"] = v30
    }
    shared.skin_modules["[SMG]"].GPOII = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.GPOII.Uzi,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.300012207, -0.0815875828, 0.0110473633, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v30
    }
    shared.skin_modules["[AK47]"].GPOII = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.GPOII.AK,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.200012207, -0.0815875828, 0.0110473633, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v30
    }
    shared.skin_modules["[AUG]"].GPOII = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.GPOII.AUG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.200012207, -0.0815875828, 0.0110473633, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v30
    }
    shared.skin_modules["[RPG]"].GPOII = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.GPOII.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.4, 0.2, 0.9, -4.37113883e-8, -3.23117427e-27, 1, 8.58948112e-13, 1, -3.75458152e-20, -1, 8.58948112e-13, -4.37113883e-8),
        ["LauncherCFrame"] = CFrame.new(-0.35, 0.3, -0.1, 0, 0, 1, 0, -1, 0, 1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.GPOII.Rocket,
        ["BorderColor"] = v30
    }
    shared.skin_modules["[Double-Barrel SG]"].GPOII = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.GPOII.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.15, -0.0815875828, 0.0110473633, 1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v30
    }
    shared.skin_modules["[Knife]"].XMAS24 = {
        ["DisplayName"] = "Hoodmas24",
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.248047352, -1, -0.0659179688, 0, 1, 0, 0.999998093, 0, 0, 0, 0, -1),
        ["BorderColor"] = v31
    }
    shared.skin_modules["[Revolver]"].XMAS24 = {
        ["DisplayName"] = "Hoodmas24",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.XMAS24.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.15, -0.0815875828, 0.0110473633, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v31
    }
    shared.skin_modules["[AK47]"].XMAS24 = {
        ["DisplayName"] = "Hoodmas24",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.XMAS24.AK,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.200012207, -0.0815875828, 0.0110473633, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v31
    }
    shared.skin_modules["[RPG]"].XMAS24 = {
        ["DisplayName"] = "Hoodmas24",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.XMAS24.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.4, 0.3, 0.9, -4.37113883e-8, -3.23117427e-27, 1, 8.58948112e-13, 1, -3.75458152e-20, -1, 8.58948112e-13, -4.37113883e-8),
        ["LauncherCFrame"] = CFrame.new(-0.35, 0.15, -0.4, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.XMAS24.Rocket,
        ["BorderColor"] = v31
    }
    shared.skin_modules["[Flamethrower]"].XMAS24 = {
        ["DisplayName"] = "Hoodmas24",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.XMAS24.Flamethrower,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.200012207, -0.0815875828, 0.0110473633, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v31
    }
    shared.skin_modules["[Double-Barrel SG]"].XMAS24 = {
        ["DisplayName"] = "Hoodmas24",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.XMAS24.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.05, -0.0815875828, 0.0110473633, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v31
    }
    shared.skin_modules["[Revolver]"].Grumpy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Grumpy.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.083902359, -0.000752657652, -0.00531005859, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v22
    }
    shared.skin_modules["[LMG]"].Grumpy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Grumpy.lmg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0024433136, -0.184990644, -0.284179688, 4.37113883e-8, 0, -1, 0, 1, 0, 1, 0, 4.37113883e-8),
        ["BorderColor"] = v22
    }
    shared.skin_modules["[Rifle]"].Grumpy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Grumpy.rifle,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0986032486, 0.155781806, 0.00201416016, 2.01746307e-17, -2.32830644e-10, 1.00000024, -3.18550298e-17, 0.999999762, -2.32830644e-10, -1, 3.18550298e-17, -2.01746307e-17),
        ["BorderColor"] = v22
    }
    shared.skin_modules["[Double-Barrel SG]"].Grumpy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Grumpy.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.00919914246, -0.0474078655, 0.0112304688, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v22
    }
    shared.skin_modules["[Knife]"].Grumpy = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0426330566, -0.0864753723, 0.0100708008, 0.00275234436, 1, 0, 1, -0.00275234436, 0, 0, 0, -1),
        ["BorderColor"] = v22
    }
    shared.skin_modules["[RPG]"].Grumpy = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Grumpy.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0670776367, 0.0477321744, 0.919996262, 1, 1.1920929e-7, 1.58932565e-8, 1.1920929e-7, 1, 2.65151563e-8, 1.03316033e-7, 2.65151598e-8, 1),
        ["LauncherCFrame"] = CFrame.new(-0.164367676, 0.0731297731, -1.37745857, 1, 1.1920929e-7, 1.58932565e-8, 1.1920929e-7, 1, 2.651527e-8, 1.03316033e-7, 2.65152735e-8, 1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Grumpy.launcher,
        ["BorderColor"] = v22
    }
    shared.skin_modules["[Revolver]"].Wrapped = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Wrapped.WrappedRev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0514059067, -0.0242098272, -0.00512695312, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v31
    }
    shared.skin_modules["[Revolver]"].Shrimp = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shrimp.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.083902359, -0.000752657652, -0.00531005859, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v41
    }
    shared.skin_modules["[Flamethrower]"].Shrimp = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shrimp.Flamethrower,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.06, 0.156, 0, -1.00000024, -2.32830644e-10, 2.01746307e-17, 2.32830644e-10, 0.999999762, -3.18550298e-17, 2.01746307e-17, 3.18550298e-17, -1),
        ["BorderColor"] = v41
    }
    shared.skin_modules["[Double-Barrel SG]"].Shrimp = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shrimp.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.18, -0.001, -0.005, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v41
    }
    shared.skin_modules["[Double-Barrel SG]"].ShrimpII = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shrimp.DB2,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.083902359, -0.000752657652, -0.00531005859, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v41
    }
    shared.skin_modules["[RPG]"].Shrimp = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shrimp.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.3, 0.2, 0.5, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherCFrame"] = CFrame.new(-0.3, 0.25, -1.4, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Shrimp.Rocket,
        ["BorderColor"] = v41
    }
    shared.skin_modules["[Knife]"].Shrimp = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.142807961, -0.019982338, -0.0357666016, 0, 1, 0, 0, 0, -1, -1, 0, 0),
        ["BorderColor"] = v41
    }
    shared.skin_modules["[Mask]"].Shrimp = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v41
    }
    shared.skin_modules["[Mask]"].VIP = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v40
    }
    shared.skin_modules["[Revolver]"].VIP = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.VIP.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0300045013, -0.0102914572, -0.00360107422, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v40
    }
    shared.skin_modules["[Rifle]"].VIP = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.VIP.rifle,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.772966385, 0.218811929, -0.0607299805, 1.00000024, -2.32830644e-10, -2.01746307e-17, -2.32830644e-10, 0.999999762, 3.18550298e-17, -2.01746307e-17, 3.18550298e-17, 1),
        ["BorderColor"] = v40
    }
    shared.skin_modules["[Flamethrower]"].VIP = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.VIP.ft,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.394266129, 0.377692699, -0.0838623047, -1.00000036, 0, -3.57802492e-7, 0, 1, 0, -3.57802492e-7, 0, -1.00000083),
        ["BorderColor"] = v40
    }
    shared.skin_modules["[Knife]"].VIP = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.142807961, -0.019982338, -0.0357666016, 0, 1, 0, 0, 0, -1, -1, 0, 0),
        ["BorderColor"] = v40
    }
    shared.skin_modules["[Revolver]"]["Short Cake"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes["Short Cake"].rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0156040192, -0.0425030291, -0.00393676758, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Knife]"]["Short Cake"] = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0201357603, -0.0473470688, -0.0000610351562, 1.94706445e-7, 0.999996185, -0.00275226892, -5.35878009e-10, -0.00275226892, -0.999996185, -1, 1.94707184e-7, -8.51092183e-15),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Double-Barrel SG]"]["Short Cake"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes["Short Cake"].DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0057888031, -0.0116384625, -0.0263671875, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Flamethrower]"]["Short Cake"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes["Short Cake"].ft,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.162924767, -0.108296156, -0.00122070312, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[RPG]"]["Short Cake"] = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes["Short Cake"].rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0000610351562, 0.427747428, 1.7615099, -1, 8.88178526e-16, 4.37113883e-8, -1.0522162e-15, 1, -3.75274434e-9, -4.37113883e-8, 3.75274434e-9, -1),
        ["LauncherCFrame"] = CFrame.new(-0.0078125, 0.0242747664, -0.0585517883, -1, 8.88178526e-16, 4.37113883e-8, -1.05222128e-15, 1, -3.75285891e-9, -4.37113883e-8, 3.75285891e-9, -1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes["Short Cake"].launcher,
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Revolver]"].Beary = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Beary.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.083902359, -0.000752657652, -0.00531005859, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Double-Barrel SG]"].Beary = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Beary.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.18, -0.001, -0.005, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[RPG]"].Beary = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Beary.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.3, 0.2, 0.5, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["LauncherCFrame"] = CFrame.new(-0.3, 0.25, -1.27, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Beary.Rocket,
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Knife]"].Beary = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.1, -0.08, -1.8, 0, 1, 0, 1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[TacticalShotgun]"].Beary = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Beary.Tac,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.02, -0.001, -0.005, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Vehicle]"].Beary = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Knife]"]["Ban Hammer"] = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0201357603, -0.0473470688, -0.0000610351562, 1.94706445e-7, 0.999996185, -0.00275226892, -5.35878009e-10, -0.00275226892, -0.999996185, -1, 1.94707184e-7, -8.51092183e-15),
        ["NoTrade"] = true,
        ["BorderColor"] = v5
    }
    shared.skin_modules["[Knife]"].Blossom = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.599981308, 0.0271587372, -0.161071777, 0, 1, 0, -1, 0, 0, 0, 0, 1),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Revolver]"].Blossom = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Blossom.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.084897995, -0.0264527202, -0.00415039062, 1, 0, 0, 0, 0.999996185, 0, 0, 0, 1),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Double-Barrel SG]"].Blossom = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Blossom.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.0497989655, -0.104448169, 0.0203857422, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Vehicle]"].Blossom = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Vehicle]"].Duck = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Revolver]"].Duck = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Duck.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.15, 0.15, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Double-Barrel SG]"].Duck = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Duck.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.5, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[RPG]"].Duck = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Duck.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.1, 0.3, 0.7, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherCFrame"] = CFrame.new(-0.1, 0.1, -1.07, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Duck.Rocket,
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Knife]"].Duck = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 0, 1, 0, -1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Flamethrower]"].Duck = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Duck.Flamethrower,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.02, -0.001, -0.005, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[RPG]"].Skull = {
        ["DisplayName"] = "Midnight",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Skull.rpg,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.151672363, 0.272811234, 0.710029602, -4.37113883e-8, 2.84217094e-14, -1, 3.75293441e-9, 1, -2.8585756e-14, 1, 3.75293441e-9, -4.37113883e-8),
        ["LauncherCFrame"] = CFrame.new(-0.0116577148, 0.152510166, -0.45423317, 1, 2.84217094e-14, -4.37113883e-8, 2.85857628e-14, 1, 3.75304898e-9, 4.37113883e-8, 3.75304898e-9, 1),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Skull.Launcher
    }
    shared.skin_modules["[Revolver]"].Skull = {
        ["DisplayName"] = "Midnight",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Skull.rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0100040436, 0.00174093246, -0.156860352, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    }
    shared.skin_modules["[Double-Barrel SG]"].Skull = {
        ["DisplayName"] = "Midnight",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Skull.db,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.818656921, -0.0885771513, 0.00787353516, -1, 0, 0, 0, 1, 0, 0, 0, -1)
    }
    shared.skin_modules["[Knife]"].Skull = {
        ["DisplayName"] = "Midnight",
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.599981308, -0.0305194855, -0.0527648926, 0, 1, 0, -1, 0, 0, 0, 0, 1)
    }
    shared.skin_modules["[Vehicle]"].Skull = {
        ["DisplayName"] = "Midnight",
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Revolver]"].Sushi = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Sushi.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0.15, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Double-Barrel SG]"].Sushi = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Sushi.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.5, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[TacticalShotgun]"].Sushi = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Sushi.Tact,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[RPG]"].Sushi = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Sushi.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.1, 0.3, 0.7, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherCFrame"] = CFrame.new(-0.1, 0.2, -1.3, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Sushi.Rocket,
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Knife]"].Sushi = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 0, 1, 0, -1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Knife]"].Arcane = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 0, 1, 0, -1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v5
    }
    shared.skin_modules["[Revolver]"].Arcane = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Arcane.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0.15, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v5
    }
    shared.skin_modules["[Vehicle]"].Arcane = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v5
    }
    shared.skin_modules["[Vehicle]"].ArcanePlus = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v5
    }
    shared.skin_modules["[Revolver]"].Samurai = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Samurai.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.014251709, -0.0334861875, 0.00100708008, 0, 0, -1, 0, 1, 0, 1, 0, 0)
    }
    shared.skin_modules["[Double-Barrel SG]"].Samurai = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Samurai.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.116455078, -0.106102258, 0.0293884277, 0, 0, 1, 0, 1, 0, -1, 0, 0)
    }
    shared.skin_modules["[Knife]"].Samurai = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.599975586, 0.0550231934, 0.0923461914, 0, 1, 0, 1, 0, 0, 0, 0, -1)
    }
    shared.skin_modules["[Vehicle]"].Samurai = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[House]"]["Classic 1"] = {
        ["Rarity"] = "Epic",
        ["Crate"] = 1
    }
    shared.skin_modules["[House]"]["Container House"] = {
        ["Rarity"] = "Epic",
        ["Crate"] = 1
    }
    shared.skin_modules["[House]"]["Contemporary House"] = {
        ["Rarity"] = "Epic",
        ["Crate"] = 1
    }
    shared.skin_modules["[House]"]["Studio House"] = {
        ["Rarity"] = "Legendary",
        ["Crate"] = 1
    }
    shared.skin_modules["[House]"]["Villa Oxa Lux"] = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[House]"]["Villa Nova"] = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Knife]"].Jellyfish = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 0, 1, 0, -1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v20
    }
    shared.skin_modules["[Revolver]"].Jellyfish = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Jellyfish.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0.15, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v20
    }
    shared.skin_modules["[Double-Barrel SG]"].Jellyfish = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Jellyfish.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v20
    }
    shared.skin_modules["[TacticalShotgun]"].Jellyfish = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Jellyfish.Tact,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.2, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v20
    }
    shared.skin_modules["[RPG]"].Jellyfish = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Jellyfish.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.1, 0.3, 0.7, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherCFrame"] = CFrame.new(-0.1, 0.2, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Jellyfish.Rocket,
        ["BorderColor"] = v20
    }
    shared.skin_modules["[Vehicle]"].Jellyfish = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v20
    }
    shared.skin_modules["[Revolver]"].Summer = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Summer.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0.15, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v13
    }
    shared.skin_modules["[TacticalShotgun]"].Summer = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Summer.Tac,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.2, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v13
    }
    shared.skin_modules["[Revolver]"].Kingpin = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Kingpin.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0528564453, -0.0851585865, -0.00579833984, -1.99520325e-23, -1.62920685e-7, 1, 2.44929371e-16, 1, 1.62920685e-7, -1, 2.44929371e-16, 1.99520294e-23),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Double-Barrel SG]"].Kingpin = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Kingpin.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.3, -0.0851585865, -0.2579833984, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[AK47]"].Kingpin = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Kingpin.AK,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.9, -0.0851585865, -0.00579833984, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Knife]"].Kingpin = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.599975586, 0.014465332, 0.00958251953, 0, 1, 0, 0, 0, -1, -1, 0, 0),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Vehicle]"].Truck = {
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Knife]"].RoseKarambit = {
        ["DisplayName"] = "Rose",
        ["Rarity"] = "Legendary",
        ["Crate"] = 999,
        ["CFrame"] = CFrame.new(-0.0699813366, -0.0199928284, 0.151672363, 6.21539241e-22, 1, 0, 1, 6.21539241e-22, -3.57623663e-17, 3.57623663e-17, 0, -1),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Revolver]"].Bubu = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Bubu.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0609436035, -0.0713346004, 0.000366210938, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v26
    }
    shared.skin_modules["[Double-Barrel SG]"].Bubu = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Bubu.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.25567627, 0.0182077289, -0.0701293945, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v26
    }
    shared.skin_modules["[Knife]"].Bubu = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00598144531, 0.521871805, 0.0137939453, -4.76834288e-7, 1.31245104e-9, -0.999996185, 0.999997973, -2.41678208e-7, 4.76834259e-7, 2.41911039e-7, -0.999996066, 1.31245104e-9),
        ["BorderColor"] = v26
    }
    shared.skin_modules["[RPG]"].Bubu = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Bubu.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.3609436035, -0.0713346004, 1.000366210938, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["LauncherCFrame"] = CFrame.new(-0.3152893066, 0.0218440592, 0.51171875, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Bubu.Rocket,
        ["BorderColor"] = v26
    }
    shared.skin_modules["[Knife]"]["RGB Bubu"] = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00598144531, 0.521871805, 0.0137939453, -4.76834288e-7, 1.31245104e-9, -0.999996185, 0.999997973, -2.41678208e-7, 4.76834259e-7, 2.41911039e-7, -0.999996066, 1.31245104e-9),
        ["BorderColor"] = v15
    }
    shared.skin_modules["[Knife]"].Music = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 0, 1, 0, -1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v7
    }
    shared.skin_modules["[Revolver]"].Music = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Music.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0.15, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v7
    }
    shared.skin_modules["[Double-Barrel SG]"].Music = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Music.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v7
    }
    shared.skin_modules["[Flintlock]"].Music = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Music.Flintlock,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0.15, -0.1, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["BorderColor"] = v7
    }
    shared.skin_modules["[Drum-Shotgun]"].Music = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Music.Drum,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.7, 0.25, 0.35, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v7
    }
    shared.skin_modules["[RPG]"].Music = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Music.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.1, 0.3, 0.7, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherCFrame"] = CFrame.new(-0.1, 0.2, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Music.Rocket,
        ["BorderColor"] = v7
    }
    shared.skin_modules["[Vehicle]"].Music = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v7
    }
    shared.skin_modules["[Knife]"].Brainrot = {
        ["DisplayName"] = "Bananini",
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 0, 1, 0, -1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Revolver]"].Brainrot = {
        ["DisplayName"] = "Cappuccina",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Brainrot.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0.15, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v10
    }
    shared.skin_modules["[Double-Barrel SG]"].Brainrot = {
        ["DisplayName"] = "Watermelini",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Brainrot.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v17
    }
    shared.skin_modules["[TacticalShotgun]"].Brainrot = {
        ["DisplayName"] = "Tung",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Brainrot.Tac,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Shotgun]"].Brainrot = {
        ["DisplayName"] = "Frulla",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Brainrot.Shotgun,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["BorderColor"] = v7
    }
    shared.skin_modules["[RPG]"].Brainrot = {
        ["DisplayName"] = "Bombardino",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Brainrot.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.1, 0.3, 0.7, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherCFrame"] = CFrame.new(-0.1, 0.3, -0.5, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Brainrot.ROCKET,
        ["BorderColor"] = v22
    }
    shared.skin_modules["[RPG]"].BrainrotShark = {
        ["DisplayName"] = "Tralalero",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Brainrot.SharkRPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.1, 0.3, 0.7, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherCFrame"] = CFrame.new(-0.1, 0, -0.5, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Brainrot.SharkROCKET,
        ["BorderColor"] = v5
    }
    shared.skin_modules["[RPG]"].BrainrotSharkGolden = {
        ["DisplayName"] = "Tralalero",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Brainrot.SharkGoldRPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.1, 0.3, 0.7, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherCFrame"] = CFrame.new(-0.1, 0, -0.5, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Brainrot.SharkGoldROCKET,
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Double-Barrel SG]"].Ribbon = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ribbon.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.273925781, -0.0719049275, -0.0044708252, 1.59256203e-7, -1.28089744e-6, -1.00000286, 3.02059533e-9, 1.00000072, 1.60673972e-6, 1, 3.02062375e-9, -1.59256246e-7),
        ["BorderColor"] = v21
    }
    shared.skin_modules["[Revolver]"].Ribbon = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ribbon.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.027923584, 0.012791872, -0.00779724121, -1.99520294e-23, -1.62920671e-7, 1, 2.44929371e-16, 1, 1.62920671e-7, -1, 2.44929371e-16, 1.99520294e-23),
        ["BorderColor"] = v21
    }
    shared.skin_modules["[RPG]"].Ribbon = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ribbon.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.00366973877, 0.237731695, 0.447662354, 1, 1.32440608e-13, -1.9937153e-23, 1.32930451e-13, 1, 1.62920671e-7, -2.16371546e-20, -1.62920671e-7, 1),
        ["LauncherCFrame"] = CFrame.new(0, 0, -0.5, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Ribbon.Rocket,
        ["BorderColor"] = v21
    }
    shared.skin_modules["[Vehicle]"].Ribbon = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v21
    }
    shared.skin_modules["[Knife]"].Ribbon = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0296325684, 0.5272789, -0.0353269577, 4.3711065e-8, -0.0000729402382, -1, 1, 1.59829455e-10, 4.37112142e-8, 7.69139682e-11, -1, 0.0000686496351),
        ["BorderColor"] = v21
    }
    shared.skin_modules["[Knife]"].Popsicle = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0296325684, 0.5272789, -0.0353269577, 4.3711065e-8, -0.0000729402382, -1, 1, 1.59829455e-10, 4.37112142e-8, 7.69139682e-11, -1, 0.0000686496351),
        ["BorderColor"] = v13
    }
    shared.skin_modules["[Knife]"].Watermelon = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.160507202, 0.0066832304, 0.00640869141, 2.44929344e-16, 0.99999994, -7.54978942e-8, 9.24582452e-24, 7.54978942e-8, 0.99999994, 0.99999994, -2.44929344e-16, 9.2458261e-24),
        ["BorderColor"] = v22
    }
    shared.skin_modules["[Knife]"].Mochi = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.0296325684, 0.5272789, -0.0353269577, 4.3711065e-8, -0.0000729402382, -1, 1, 1.59829455e-10, 4.37112142e-8, 7.69139682e-11, -1, 0.0000686496351),
        ["BorderColor"] = v1
    }
    shared.skin_modules["[Revolver]"].PurpleRedDualRev = {
        ["DisplayName"] = "Absolute Authority Revolvers",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.PurpleRedDualRev.DisplayRev,
        ["CFrame"] = CFrame.new(-0.520424962, 0.0484008789, -0.00109863281, 0, 1, 0, 1, 0, 0, 0, 0, -1),
        ["Rarity"] = "Exclusive"
    }
    shared.skin_modules["[Knife]"].Moon = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 0, 1, 0, -1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v20
    }
    shared.skin_modules["[Knife]"].Solar = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 0, 1, 0, -1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v23
    }
    shared.skin_modules["[Knife]"].Jade = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 0, 1, 0, -1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v22
    }
    shared.skin_modules["[Double-Barrel SG]"].Wraith = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Wraith.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.1, -0.056758523, 0.016998291, 1, 2.44929371e-16, -1.99520325e-23, -2.44929371e-16, 1, -1.62920685e-7, -1.99520294e-23, 1.62920685e-7, 1),
        ["BorderColor"] = v25
    }
    shared.skin_modules["[Revolver]"].Wraith = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Wraith.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0.4128, -0.0078, -0, 0, 1, 0, 1, 0, -1, 0, -0),
        ["BorderColor"] = v25
    }
    shared.skin_modules["[Knife]"].Wraith = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 0, 1, 0, -1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v25
    }
    shared.skin_modules["[Mask]"].Wraith = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v25
    }
    shared.skin_modules["[Vehicle]"].Wraith = {
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v25
    }
    shared.skin_modules["[Knife]"].PumpkinCat = {
        ["DisplayName"] = "Halloween25",
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 0, 1, 0, -1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Revolver]"].PumpkinCat = {
        ["DisplayName"] = "Halloween25",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.PumpkinCat.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0.15, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Double-Barrel SG]"].PumpkinCat = {
        ["DisplayName"] = "Halloween25",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.PumpkinCat.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v36
    }
    shared.skin_modules["[RPG]"].PumpkinCat = {
        ["DisplayName"] = "Halloween25",
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.PumpkinCat.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.1, 0.3, 0.7, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherCFrame"] = CFrame.new(-0.1, 0, 0.5, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.PumpkinCat.Explosion,
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Vehicle]"].PumpkinCat = {
        ["DisplayName"] = "Halloween25",
        ["Rarity"] = "Exclusive",
        ["BorderColor"] = v36
    }
    shared.skin_modules["[Revolver]"].Paper = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Paper.Rev,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0.15, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1),
        ["BorderColor"] = v14
    }
    shared.skin_modules["[Double-Barrel SG]"].Paper = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Paper.DB,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0.2, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1),
        ["BorderColor"] = v14
    }
    shared.skin_modules["[RPG]"].Paper = {
        ["TextureID"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Paper.RPG,
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(-0.1, 0.3, 0.7, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherCFrame"] = CFrame.new(-0.1, -0.1, 0.5, 0, 0, -1, 0, 1, 0, 1, 0, 0),
        ["LauncherMesh"] = game:GetService("ReplicatedStorage").SkinModules.Meshes.Paper.Rocket,
        ["BorderColor"] = v14,
        ["ShootAnimation"] = 92090024228161
    }
    shared.skin_modules["[Knife]"].Paper = {
        ["Rarity"] = "Exclusive",
        ["CFrame"] = CFrame.new(0, 0, 0, 0, 1, 0, -1, 0, 0, 0, 0, -1),
        ["BorderColor"] = v14
    }

-- Apply selected skins when local player equips a weapon
local function applyPradaSkin(tool)
    if not tool:IsA('Tool') then return end
    local sc = Config['Skin Changer']
    if not sc['Enabled'] then return end

    -- Find the weapon slot key for this tool
    local slot = nil
    for _, key in ipairs({
        '[Revolver]','[Silencer]','[Glock]','[AK47]','[AR]','[AUG]','[DrumGun]',
        '[Flintlock]','[LMG]','[P90]','[Rifle]','[SMG]','[Shotgun]','[TacticalShotgun]',
        '[SilencerAR]','[Flamethrower]','[RPG]','[Bat]','[Knife]','[Mask]','[Wallet]',
        '[Vehicle]','[House]'
    }) do
        local clean = key:gsub('%[',''):gsub('%]','')
        if tool.Name == key or tool.Name:find(clean) then
            slot = key
            break
        end
    end
    if not slot then return end

    local skinName = sc['Selected'][slot]
    if not skinName or skinName == 'Default' then return end

    local skinData = shared.skin_modules[slot] and shared.skin_modules[slot][skinName]
    if not skinData then return end

    -- Apply CFrame offset
    local handle = tool:FindFirstChild('Handle') or tool:FindFirstChildOfClass('BasePart')
    if not handle then return end

    if skinData['CFrame'] then
        handle.CFrame = handle.CFrame * skinData['CFrame']
    end

    -- Apply TextureID
    if skinData['TextureID'] then
        local texId = skinData['TextureID']
        if typeof(texId) == 'string' then
            handle.TextureID = texId
        elseif typeof(texId) == 'Instance' then
            handle.TextureID = 'rbxassetid://' .. texId.TextureId
        end
    end
end

-- Hook into character tool equip
local function hookSkinChanger(char)
    char.ChildAdded:Connect(function(child)
        task.wait()
        applyPradaSkin(child)
    end)
    for _, child in ipairs(char:GetChildren()) do
        applyPradaSkin(child)
    end
end

if LocalPlayer.Character then
    hookSkinChanger(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(hookSkinChanger)


RunService.RenderStepped:Connect(function()
    if stepAntiCurveOverlay then stepAntiCurveOverlay() end

    local shouldDrawTargetLine = Config['Silent Aim'] and Config['Silent Aim']['Target Line']
        and Config['Silent Aim']['Enabled'] and currentTarget
    if silentTargetLine then
        if shouldDrawTargetLine then
            local targetHead = currentTarget.Parent and currentTarget.Parent:FindFirstChild('Head')
            local tracerPart = targetHead or currentTarget
            if tracerPart then
                local targetScreenPos3D, onScreen3D = Camera:WorldToViewportPoint(tracerPart.Position)
                if onScreen3D and targetScreenPos3D.Z > 0 then
                    local mouseLocation = UserInputService:GetMouseLocation()
                    silentTargetLine.From = vector2New(mouseLocation.X, mouseLocation.Y)
                    silentTargetLine.To = vector2New(targetScreenPos3D.X, targetScreenPos3D.Y)
                    silentTargetLine.Visible = true
                else
                    silentTargetLine.Visible = false
                end
            else
                silentTargetLine.Visible = false
            end
        else
            silentTargetLine.Visible = false
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not RaidAwarenessConfig or not RaidAwarenessConfig['Enabled'] then
        for target, _ in pairs(espDrawings) do
            cleanupEspDrawings(target)
        end
        return
    end
    updateFovVisuals()
    local maxRenderDistance = RaidAwarenessConfig['Max Render Distance'] or 1000
    for i = #espTargets, 1, -1 do
        local target = espTargets[i]
        if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            table.remove(espTargets, i)
            cleanupEspDrawings(target)
        end
    end
    for _, target in ipairs(espTargets) do
        if target and target.Character then
            local character = target.Character
            local hrp = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if hrp and humanoid then
                local distance = (hrp.Position - Camera.CFrame.Position).Magnitude
                if distance > maxRenderDistance then
                    local drawings = getEspDrawings(target)
                    if drawings then
                        if drawings.box then drawings.box.Visible = false end
                        if drawings.name then drawings.name.Visible = false end
                        if drawings.healthBarBg then drawings.healthBarBg.Visible = false end
                    end
                end
                local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen and screenPos.Z > 0 then
                    local drawings = getEspDrawings(target)
                    local ViewportTop = hrp.Position + (hrp.CFrame.UpVector * 1.8) + Camera.CFrame.UpVector
                    local ViewportBottom = hrp.Position - (hrp.CFrame.UpVector * 2.5) - Camera.CFrame.UpVector
                    local topPoint, topOnScreen = Camera:WorldToViewportPoint(ViewportTop)
                    local bottomPoint, bottomOnScreen = Camera:WorldToViewportPoint(ViewportBottom)
                    if not (topOnScreen and bottomOnScreen) then
                        cleanupEspDrawings(target)
                    else
                        local top = vector2New(topPoint.X, topPoint.Y)
                        local bottom = vector2New(bottomPoint.X, bottomPoint.Y)
                        local width = mathMax(mathFloor(mathAbs(top.X - bottom.X)), 8)
                        local height = mathMax(mathFloor(mathMax(mathAbs(bottom.Y - top.Y), width * 0.5)), 12)
                        local boxWidth = mathFloor(mathMax(height / 1.5, width))
                        local boxPos = vector2New(
                            mathFloor(top.X * 0.5 + bottom.X * 0.5 - boxWidth * 0.5),
                            mathFloor(mathMin(top.Y, bottom.Y))
                        )
                        if RaidAwarenessConfig['Box'] and RaidAwarenessConfig['Box']['Enabled'] then
                            local boxColor = RaidAwarenessConfig['Box']['Box Color'] or Color3.fromRGB(255, 255, 255)
                            drawings.holder.Size = UDim2.new(0, boxWidth, 0, height)
                            drawings.holder.Position = UDim2.new(0, boxPos.X, 0, boxPos.Y)
                            drawings.holder.Visible = true
                            drawings.box.Visible = true
                            drawings.boxStroke.Color = boxColor
                        else
                            if drawings.box then drawings.box.Visible = false end
                        end
                        if RaidAwarenessConfig['Name'] and RaidAwarenessConfig['Name']['Enabled'] then
                            local nameType = RaidAwarenessConfig['Name']['Type'] or 'Display'
                            local displayName = nameType == 'Display' and target.DisplayName or target.Name
                            local nameColor = RaidAwarenessConfig['Name']['Color'] or Color3.fromRGB(255, 255, 255)
                            local nameSize = RaidAwarenessConfig['Name']['Size'] or 13
                            drawings.name.Text = displayName
                            drawings.name.TextColor3 = nameColor
                            drawings.name.TextSize = nameSize
                            drawings.name.Position = UDim2.new(0.5, 0, 0, -20)
                            drawings.name.AnchorPoint = Vector2.new(0.5, 1)
                            drawings.name.Visible = true
                        else
                            if drawings.name then drawings.name.Visible = false end
                        end
                        if RaidAwarenessConfig['Health'] and RaidAwarenessConfig['Health']['Enabled'] then
                            local healthType = RaidAwarenessConfig['Health']['Type'] or 'Bar'
                            local currentHealth = humanoid.Health
                            local maxHealth = humanoid.MaxHealth
                            local healthPercent = math.clamp(currentHealth / maxHealth, 0, 1)
                            if healthType == 'Bar' then
                                local barWidth = 3
                                local barHeight = height
                                drawings.healthBarBg.Size = UDim2.new(0, barWidth + 2, 0, barHeight + 2)
                                drawings.healthBarBg.Position = UDim2.new(1, 4, 0, -1)
                                drawings.healthBarBg.Visible = true
                                drawings.healthBarEmpty.Visible = true
                                drawings.healthBarFill.Size = UDim2.new(1, -2, healthPercent, -2)
                                drawings.healthBarFill.Position = UDim2.new(0, 1, 1 - healthPercent, 1)
                                drawings.healthBarFill.Visible = true
                                local lowColor = RaidAwarenessConfig['Health']['Missing Health Color'] or Color3.fromRGB(255, 0, 0)
                                local highColor = RaidAwarenessConfig['Health']['High Health Color'] or Color3.fromRGB(0, 255, 0)
                                drawings.healthBarEmpty.BackgroundColor3 = lowColor
                                drawings.healthBarFill.BackgroundColor3 = highColor
                            end
                        else
                            if drawings.healthBarBg then drawings.healthBarBg.Visible = false end
                        end
                        if RaidAwarenessConfig['Lines'] and RaidAwarenessConfig['Lines']['Enabled'] then
                            if not drawings.line then
                                drawings.line = Drawing.new("Line")
                                drawings.lineOutline = Drawing.new("Line")
                            end
                            local lineType = RaidAwarenessConfig['Lines']['Type'] or 'Top'
                            local lineColor = RaidAwarenessConfig['Lines']['Color'] or Color3.fromRGB(255, 255, 255)
                            local lineFrom = Vector2.new(0, 0)
                            if lineType == 'Top' then
                                lineFrom = Vector2.new(Camera.ViewportSize.X / 2, 0)
                            elseif lineType == 'Bottom' then
                                lineFrom = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            elseif lineType == 'Mouse' then
                                lineFrom = UserInputService:GetMouseLocation()
                            elseif lineType == 'Middle' then
                                lineFrom = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                            end
                            local screenPosition = vector2New(screenPos.X, screenPos.Y)
                            drawings.lineOutline.From = lineFrom
                            drawings.lineOutline.To = screenPosition
                            drawings.lineOutline.Color = Color3.fromRGB(0, 0, 0)
                            drawings.lineOutline.Thickness = 2.8
                            drawings.lineOutline.Visible = true
                            drawings.line.From = lineFrom
                            drawings.line.To = screenPosition
                            drawings.line.Color = lineColor
                            drawings.line.Thickness = 2
                            drawings.line.Visible = true
                        else
                            if drawings.line then drawings.line.Visible = false end
                            if drawings.lineOutline then drawings.lineOutline.Visible = false end
                        end
                    end
                else
                    cleanupEspDrawings(target)
                end
            else
                cleanupEspDrawings(target)
            end
        else
            cleanupEspDrawings(target)
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if RaidAwarenessConfig['Enabled'] then
        local binds = RaidAwarenessConfig['Binds'] or {}
        local addKey = binds['Add Target'] and Enum.KeyCode[binds['Add Target']:upper()]
        local removeKey = binds['Remove Target'] and Enum.KeyCode[binds['Remove Target']:upper()]
        if addKey and input.KeyCode == addKey then
            local mouseTarget = Mouse.Target
            if mouseTarget then
                local character = mouseTarget.Parent
                if character and not character:FindFirstChild("Humanoid") then
                    character = character.Parent
                end
                if character and character:FindFirstChild("Humanoid") then
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Character == character then
                            addEspTarget(player)
                            return
                        end
                    end
                end
            end
        elseif removeKey and input.KeyCode == removeKey then
            local mouseTarget = Mouse.Target
            if mouseTarget then
                local character = mouseTarget.Parent
                if character and not character:FindFirstChild("Humanoid") then
                    character = character.Parent
                end
                if character and character:FindFirstChild("Humanoid") then
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Character == character then
                            removeEspTarget(player)
                            cleanupEspDrawings(player)
                            return
                        end
                    end
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removeEspTarget(player)
    cleanupEspDrawings(player)
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

    table.insert(lines, '<font color="rgb(97,222,241)">Story</font>')

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
                    '<font color="rgb(255,255,255)">Silent Aim </font><font color="rgb(97,222,241)">('..name..')</font>'
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

do
    local SpinToggle = false
    local LastRenderTime = 0
    local TotalRotation = 0

    UserInputService.InputBegan:Connect(function(Input, GameProcessedEvent)
        if GameProcessedEvent then return end
        if Input.KeyCode == Enum.KeyCode[Config['Keybinds']['Spin']] then
            SpinToggle = not SpinToggle
            TotalRotation = 0
        end
    end)

    RunService.RenderStepped:Connect(function()
        if not Config['Spin']['Enabled'] or not SpinToggle then return end
        local CurrentTime = tick()
        local TimeDelta = math.min(CurrentTime - LastRenderTime, 0.01)
        LastRenderTime = CurrentTime

        local RotationAngle = Config['Spin']['SpinSpeed'] * TimeDelta
        local Rotation = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.rad(RotationAngle))
        Camera.CFrame = Camera.CFrame * Rotation

        TotalRotation = TotalRotation + RotationAngle
        if TotalRotation >= Config['Spin']['Degrees'] then
            SpinToggle = false
            TotalRotation = 0
        end
    end)
end

do
    local SpeedGlitch = false

    local function toggleSpeedGlitch()
        SpeedGlitch = not SpeedGlitch
        if SpeedGlitch then
            if Config['Macro']['Type'] == "Third" then
                task.spawn(function()
                    repeat
                        task.wait(Config['Macro']['Speed'] / 100)
                        game:GetService("VirtualInputManager"):SendKeyEvent(true, "I", false, game)
                        task.wait(Config['Macro']['Speed'] / 100)
                        game:GetService("VirtualInputManager"):SendKeyEvent(true, "O", false, game)
                    until not SpeedGlitch or not Config['Macro']['Enabled']
                end)
            elseif Config['Macro']['Type'] == "First" then
                task.spawn(function()
                    repeat
                        task.wait(Config['Macro']['Speed'] / 100)
                        game:GetService("VirtualInputManager"):SendMouseWheelEvent(0, 0, true, game)
                        task.wait(Config['Macro']['Speed'] / 100)
                        game:GetService("VirtualInputManager"):SendMouseWheelEvent(0, 0, false, game)
                    until not SpeedGlitch or not Config['Macro']['Enabled']
                end)
            end
        end
    end

    Mouse.KeyDown:Connect(function(Key)
        if not Config['Macro']['Enabled'] then return end
        if string.lower(Key) == string.lower(Config['Keybinds']['Macro']) then
            toggleSpeedGlitch()
        end
    end)
end

do
    local AimAssistActive = false

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Aim Assist']] then
            AimAssistActive = not AimAssistActive
        end
    end)

    RunService.RenderStepped:Connect(function()
        if not Config['Aim Assist']['Enabled'] or not AimAssistActive then return end
        if not currentTarget then return end
        local character = currentTarget.Parent
        if not character then return end
        local player = Players:GetPlayerFromCharacter(character)
        if not player then return end
        if isPlayerKnockedOrKO(player) then return end
        local rootPart = character:FindFirstChild('HumanoidRootPart')
        if not rootPart then return end

        if Config['Aim Assist']['Wall Check'] and not canSeeTarget(currentTarget) then return end

        local mousePos = UserInputService:GetMouseLocation()
        local rootScreen, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
        if not onScreen then return end

        local dist = (Vector2.new(mousePos.X, mousePos.Y) - Vector2.new(rootScreen.X, rootScreen.Y)).Magnitude
        if dist > Config['Aim Assist']['FOV'] then return end

        local velocity = SilentGetVelocity(rootPart)
        local mult     = Config['Aim Assist']['Prediction']
        local ov       = Config['Aim Assist']['OverrideYAxis']
        local vmult
        if     ov == 'Full'    then vmult = Vector3.new(mult, 0,    mult)
        elseif ov == 'Partial' then vmult = Vector3.new(mult, rootPart.Velocity.Y / 5, mult)
        else                        vmult = Vector3.new(mult, mult, mult)
        end
        local hitPos = SilentGetEndpoint(velocity, rootPart.Position, vmult, {false})
        local target = CFrame.new(Camera.CFrame.Position, hitPos)
        Camera.CFrame = Camera.CFrame:Lerp(target, Config['Aim Assist']['Smoothing'])
    end)
end

do
    local NoClipActive = false

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode[Config['Keybinds']['NoClip']] then
            NoClipActive = not NoClipActive
        end
    end)

    RunService.Stepped:Connect(function()
        if not Config['NoClip']['Enabled'] or not NoClipActive then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA('BasePart') then
                part.CanCollide = false
            end
        end
    end)
end

do
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Bounding']] then
            Config['Bounding']['Enabled'] = not Config['Bounding']['Enabled']
        end
    end)
end

do
    local VelocitySpoofActive = false

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Velocity Spoof']] then
            VelocitySpoofActive = not VelocitySpoofActive
        end
    end)

    RunService.Heartbeat:Connect(function()
        if not Config['Velocity Spoof']['Enabled'] or not VelocitySpoofActive then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild('HumanoidRootPart')
        if not root then return end
        local orig    = root.Velocity
        local spoofType = Config['Velocity Spoof']['Type']
        if spoofType == 'Prediction Disabler' then
            root.Velocity = Vector3.new(0, 0, 0)
        elseif spoofType == 'Sides' then
            local r = Random.new():NextNumber(-2, 2)
            local m = 8
            root.Velocity = Vector3.new(
                math.clamp((-orig.X) * m, -27, 27) + r,
                36 + r,
                math.clamp((-orig.Z) * m, -27, 27) + r
            )
        end
        RunService.RenderStepped:Wait()
        root.Velocity = orig
    end)
end

do
    local chamsHighlights = {}

    local function applyChams(player)
        if player == LocalPlayer then return end
        local function tryHighlight(char)
            if chamsHighlights[player] then
                pcall(function() chamsHighlights[player]:Destroy() end)
            end
            local h = Instance.new('Highlight')
            h.FillColor          = Config['Chams']['Fill Color']
            h.FillTransparency   = Config['Chams']['Fill Transparency']
            h.OutlineColor       = Config['Chams']['Outline Color']
            h.OutlineTransparency = Config['Chams']['Outline Transparency']
            h.DepthMode          = Enum.HighlightDepthMode[Config['Chams']['Depth Mode']]
            h.Adornee            = char
            h.Parent             = char
            chamsHighlights[player] = h
        end
        if player.Character then tryHighlight(player.Character) end
        player.CharacterAdded:Connect(tryHighlight)
    end

    local function removeChams(player)
        if chamsHighlights[player] then
            pcall(function() chamsHighlights[player]:Destroy() end)
            chamsHighlights[player] = nil
        end
    end

    local ChamsActive = Config['Chams']['Enabled']

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Chams']] then
            ChamsActive = not ChamsActive
            if ChamsActive then
                for _, p in pairs(Players:GetPlayers()) do applyChams(p) end
            else
                for _, p in pairs(Players:GetPlayers()) do removeChams(p) end
            end
        end
    end)

    if ChamsActive then
        for _, p in pairs(Players:GetPlayers()) do applyChams(p) end
    end
    Players.PlayerAdded:Connect(function(p)
        if ChamsActive then applyChams(p) end
    end)
    Players.PlayerRemoving:Connect(removeChams)
end

do
    local overrideParts = Config['Hit Part Override']['Parts']
    local overrideIdx   = 1

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not Config['Hit Part Override']['Enabled'] then return end
        if input.KeyCode == Enum.KeyCode[Config['Keybinds']['Hit Override']] then
            overrideIdx = (overrideIdx % #overrideParts) + 1
            Config['Silent Aim']['Hit Location']['R15'] = { overrideParts[overrideIdx] }
            Config['Silent Aim']['Hit Part']            = overrideParts[overrideIdx]
        end
    end)
end

do
    local autoPredPrev  = nil
    local autoPredTick  = nil

    RunService.Heartbeat:Connect(function()
        if not Config['Automated Prediction']['Enabled'] then return end
        if not currentTarget then return end
        local character = currentTarget.Parent
        if not character then return end
        local root = character:FindFirstChild('HumanoidRootPart')
        if not root then return end

        local now = tick()
        local pos = root.Position

        if autoPredPrev and autoPredTick and (now - autoPredTick) > 0 then
            local velocity = (pos - autoPredPrev) / (now - autoPredTick)
            local speed    = velocity.Magnitude
            if speed > 1 then
                local root2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart')
                local dist  = root2 and (root.Position - root2.Position).Magnitude or 50
                local scale = math.clamp(speed / 50, 0.08, 0.22)
                local adjusted = scale * (dist / 50)
                Config['Silent Aim']['Prediction'] = math.clamp(adjusted, 0.08, 0.22)
            end
        end

        autoPredPrev = pos
        autoPredTick = now
    end)
end

-- Client Redirection: destroys client scripts for specified guns
RunService.Heartbeat:Connect(function()
    if not Config['Silent Aim']['Client Redirection']['Enabled'] then return end
    local character = LocalPlayer.Character
    if not character then return end
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then return end
    local weapons = Config['Silent Aim']['Client Redirection']['Weapons']
    for _, weaponName in ipairs(weapons) do
        local clean = weaponName:gsub("%[", ""):gsub("%]", "")
        if tool.Name == weaponName or tool.Name:find(clean) then
            for _, child in ipairs(tool:GetChildren()) do
                if child:IsA("LocalScript") or child:IsA("Script") then
                    child:Destroy()
                end
            end
            break
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if Config['Silent Aim']['Hit Scan'] ~= 'Automatic' then return end
    if not Config['Silent Aim']['Enabled'] then return end
    if not currentTarget then return end
    local character = currentTarget.Parent
    if not character then return end
    local player = Players:GetPlayerFromCharacter(character)
    if not player or isPlayerKnockedOrKO(player) then return end
    if not SilentGetHitChance() then return end
    SilentUpdatePing()
    local hit = SilentGetHitPosition(player)
    if hit and MainEvent then
        MainEvent:FireServer(SilentUpdater, hit)
    end
end)
