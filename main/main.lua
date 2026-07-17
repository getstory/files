local cfg = shared.Story
local players = game:GetService("Players")
local uis = game:GetService("UserInputService")
local runservice = game:GetService("RunService")
local workspace = game:GetService("Workspace")
local replicatedstorage = game:GetService("ReplicatedStorage")
local camera = workspace.CurrentCamera
local localplayer = players.LocalPlayer
local mouse = localplayer:GetMouse()

local currenttarget = nil
local silentaimactive = false
local camlockactive = false
local triggerenabled = false
local esplabels = {}
local superjumpenabled = false
local speedenabled = false
local isfiring = false
local lastrapidfire = 0
local lastvisibletarget = nil
local lasttriggerclick = 0
local lasttargetscan = 0
local scanrate = 1 / 20

local haswalljumped = false
local walljumpconnection = nil

local rayparams = RaycastParams.new()
rayparams.FilterType = Enum.RaycastFilterType.Exclude
rayparams.IgnoreWater = true

local knifedata = {}

local knifeskins = {
    ["Golden Age Tanto"] = {soundid = "rbxassetid://5917819099", animationid = "rbxassetid://13473404819", positionoffset = Vector3.new(0, -0.20, -1.2), rotationoffset = Vector3.new(90, 263.7, 180)},
    ["GPO-Knife"] = {soundid = "rbxassetid://4604390759", animationid = "rbxassetid://14014278925", positionoffset = Vector3.new(0.00, -0.32, -1.07), rotationoffset = Vector3.new(90, -97.4, 90)},
    ["GPO-Knife Prestige"] = {soundid = "rbxassetid://4604390759", animationid = "rbxassetid://14014278925", positionoffset = Vector3.new(0.00, -0.32, -1.07), rotationoffset = Vector3.new(90, -97.4, 90)},
    ["Heaven"] = {soundid = "rbxassetid://14489860007", animationid = "rbxassetid://14500266726", positionoffset = Vector3.new(-0.02, -0.82, 0.20), rotationoffset = Vector3.new(64.42, 3.79, 0.00)},
    ["Love Kukri"] = {soundid = "", animationid = "", positionoffset = Vector3.new(-0.14, 0.14, -1.62), rotationoffset = Vector3.new(-90.00, 180.00, -4.97), particle = true, textureid = "rbxassetid://12124159284"},
    ["Purple Dagger"] = {soundid = "rbxassetid://17822743153", animationid = "rbxassetid://17824999722", positionoffset = Vector3.new(-0.13, -0.24, -1.80), rotationoffset = Vector3.new(89.05, 96.63, 180.00)},
    ["Blue Dagger"] = {soundid = "rbxassetid://17822737046", animationid = "rbxassetid://17824995184", positionoffset = Vector3.new(-0.13, -0.24, -1.80), rotationoffset = Vector3.new(89.05, 96.63, 180.00)},
    ["Green Dagger"] = {soundid = "rbxassetid://17822741762", animationid = "rbxassetid://17825004320", positionoffset = Vector3.new(-0.13, -0.24, -1.07), rotationoffset = Vector3.new(89.05, 96.63, 180.00)},
    ["Red Dagger"] = {soundid = "rbxassetid://17822952417", animationid = "rbxassetid://17825008844", positionoffset = Vector3.new(-0.13, -0.24, -1.07), rotationoffset = Vector3.new(89.05, 96.63, 180.00)},
    ["Portal"] = {soundid = "rbxassetid://16058846352", animationid = "rbxassetid://16058633881", positionoffset = Vector3.new(-0.13, -0.35, -0.57), rotationoffset = Vector3.new(89.05, 96.63, 180.00)},
    ["Emerald Butterfly"] = {soundid = "rbxassetid://14931902491", animationid = "rbxassetid://14918231706", positionoffset = Vector3.new(-0.02, -0.30, -0.65), rotationoffset = Vector3.new(180.00, 90.95, 180.00)},
    ["Boy"] = {soundid = "rbxassetid://18765078331", animationid = "rbxassetid://18789158908", positionoffset = Vector3.new(-0.02, -0.09, -0.73), rotationoffset = Vector3.new(89.05, -88.11, 180.00)},
    ["Girl"] = {soundid = "rbxassetid://18765078331", animationid = "rbxassetid://18789162944", positionoffset = Vector3.new(-0.02, -0.16, -0.73), rotationoffset = Vector3.new(89.05, -88.11, 180.00)},
    ["Dragon"] = {soundid = "rbxassetid://14217789230", animationid = "rbxassetid://14217804400", positionoffset = Vector3.new(-0.02, -0.32, -0.98), rotationoffset = Vector3.new(89.05, 90.95, 180.00)},
    ["Void"] = {soundid = "rbxassetid://14756591763", animationid = "rbxassetid://14774699952", positionoffset = Vector3.new(-0.02, -0.22, -0.85), rotationoffset = Vector3.new(180.00, 90.95, 180.00)},
    ["Wild West"] = {soundid = "rbxassetid://16058689026", animationid = "rbxassetid://16058148839", positionoffset = Vector3.new(-0.02, -0.24, -1.15), rotationoffset = Vector3.new(-91.89, 90.95, 180.00)},
    ["Iced Out"] = {soundid = "rbxassetid://14924261405", animationid = "rbxassetid://18465353361", positionoffset = Vector3.new(0.02, -0.08, 0.99), rotationoffset = Vector3.new(180.00, -90.95, -180.00)},
    ["Reptile"] = {soundid = "rbxassetid://18765103349", animationid = "rbxassetid://18788955930", positionoffset = Vector3.new(-0.03, -0.06, -0.92), rotationoffset = Vector3.new(168.63, 90.00, -180.00)},
    ["Emerald"] = {soundid = "", animationid = "", positionoffset = Vector3.new(-0.03, -0.06, -0.92), rotationoffset = Vector3.new(168.63, 90.00, 108.00)},
    ["Ribbon"] = {soundid = "rbxassetid://130974579277249", animationid = "rbxassetid://124102609796063", positionoffset = Vector3.new(0.02, -0.25, -0.05), rotationoffset = Vector3.new(90.00, 0.00, 180.00)},
}

local fovparts = {
    silentaim = Instance.new("Part"),
    camlock = Instance.new("Part"),
    triggerbot = Instance.new("Part"),
}

for name, part in pairs(fovparts) do
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Transparency = 1
    part.BrickColor = BrickColor.new("Grey")
    part.Material = Enum.Material.Neon
    part.Name = "fovoutline3d_" .. name
    part.Parent = workspace
end

local fov2dboxes = {
    silentaim = {},
    camlock = {},
    triggerbot = {},
}

for key in pairs(fov2dboxes) do
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        line.Color = Color3.fromRGB(150, 150, 150)
        line.Visible = false
        line.ZIndex = 5
        fov2dboxes[key][i] = line
    end
end

local targetline = Drawing.new("Line")
targetline.Visible = false
targetline.Thickness = cfg['target line']['thickness']
targetline.Transparency = cfg['target line']['transparency']
targetline.ZIndex = 999

local function clearmesh(tool, exclude)
    local children = tool:GetChildren()
    for i = 1, #children do
        local v = children[i]
        if v:IsA("MeshPart") and v ~= exclude then
            v:Destroy()
        end
    end
end

local function applygun(tool, name)
    local orig = tool:FindFirstChildOfClass("MeshPart")
    if not orig then return end

    local skinmodules = replicatedstorage:FindFirstChild("SkinModules")
    if not skinmodules then return end

    local ok, skinmodulesreq = pcall(function()
        return require(skinmodules)
    end)
    if not ok or not skinmodulesreq then return end

    local info = skinmodulesreq[tool.Name] and skinmodulesreq[tool.Name][name]
    if not info then return end

    clearmesh(tool, orig)

    local skinpart = info.TextureID
    if typeof(skinpart) == "Instance" then
        local clone = skinpart:Clone()
        clone.Parent = tool
        clone.CFrame = orig.CFrame
        clone.Name = "CurrentSkin"

        local w = Instance.new("Weld")
        w.Part0 = clone
        w.Part1 = orig
        w.C0 = info.CFrame:Inverse()
        w.Parent = clone

        orig.Transparency = 1
    else
        orig.TextureID = skinpart
        orig.Transparency = 0
    end

    local handle = tool:FindFirstChild("Handle")
    if not handle then return end

    local shoot = handle:FindFirstChild("ShootSound")
    if shoot then
        local skinassets = replicatedstorage:FindFirstChild("SkinAssets")
        if skinassets then
            local gunsounds = skinassets:FindFirstChild("GunShootSounds")
            if gunsounds then
                local sounds = gunsounds:FindFirstChild(tool.Name)
                local obj = sounds and sounds:FindFirstChild(name)
                if obj then
                    shoot.SoundId = obj.Value
                end
            end
        end
    end

    local skinassets = replicatedstorage:FindFirstChild("SkinAssets")
    if skinassets then
        local particlefolder = skinassets:FindFirstChild("GunHandleParticle")
        if particlefolder then
            local particlesource = particlefolder:FindFirstChild(name)
            if particlesource then
                local pe = particlesource:FindFirstChild("ParticleEmitter")
                if pe then
                    for _, existing in ipairs(handle:GetChildren()) do
                        if existing:IsA("ParticleEmitter") then
                            existing:Destroy()
                        end
                    end
                    pe:Clone().Parent = handle
                end
            end
        end
    end

    handle:SetAttribute("SkinName", name)
end

local function cleanknife(tool)
    local data = knifedata[tool]
    if data then
        if data.track then
            data.track:Stop()
            data.track:Destroy()
            data.track = nil
        end
        if data.welds then
            for _, w in ipairs(data.welds) do
                if w then w:Destroy() end
            end
        end
        if data.sounds then
            for _, s in ipairs(data.sounds) do
                if s and s.Parent then s:Destroy() end
            end
        end
    end

    local mesh = tool:FindFirstChild("Default")
    if mesh then
        local children = mesh:GetChildren()
        for i = 1, #children do
            local v = children[i]
            if v.Name == "Handle.R" or v:IsA("Model") or (v:IsA("BasePart") and v.Name ~= "Default") then
                v:Destroy()
            end
        end
        mesh.Transparency = 0
    end

    knifedata[tool] = nil
end

local function applyknife(char, tool, skin)
    local skincfg = knifeskins[skin]
    if not skincfg then return end

    local hum = char:FindFirstChild("Humanoid")
    local rhand = char:FindFirstChild("RightHand")
    if not hum or not rhand then return end

    cleanknife(tool)
    knifedata[tool] = {track = nil, welds = {}, sounds = {}}
    local data = knifedata[tool]

    local mesh = tool:FindFirstChild("Default")
    if not mesh then return end
    mesh.Transparency = 1

    local skinmodules = replicatedstorage:FindFirstChild("SkinModules")
    if not skinmodules then return end
    local knives = skinmodules:FindFirstChild("Knives")
    if not knives then return end

    local skinmodel = knives:FindFirstChild(skin)
    if not skinmodel then return end
    local clone = skinmodel:Clone()
    clone.Name = skin

    local handr = Instance.new("Part")
    handr.Name = "Handle.R"
    handr.Transparency = 1
    handr.CanCollide = false
    handr.Anchored = false
    handr.Size = Vector3.new(0.001, 0.001, 0.001)
    handr.Massless = true
    handr.Parent = mesh

    local m6d = Instance.new("Motor6D")
    m6d.Name = "Handle.R"
    m6d.Part0 = rhand
    m6d.Part1 = handr
    m6d.Parent = handr

    local offset = CFrame.new(skincfg.positionoffset) * CFrame.Angles(math.rad(skincfg.rotationoffset.X), math.rad(skincfg.rotationoffset.Y), math.rad(skincfg.rotationoffset.Z))

    if clone:IsA("Model") then
        if not clone.PrimaryPart then
            local children = clone:GetChildren()
            for i = 1, #children do
                local c = children[i]
                if c:IsA("BasePart") then
                    clone.PrimaryPart = c
                    break
                end
            end
        end
        if clone.PrimaryPart then
            local descendants = clone:GetDescendants()
            for i = 1, #descendants do
                local p = descendants[i]
                if p:IsA("BasePart") then
                    p.CanCollide = false
                    p.Massless = true
                    p.Anchored = false
                    local w = Instance.new("Weld")
                    w.Part0 = handr
                    w.Part1 = p
                    w.C0 = offset
                    w.C1 = p.CFrame:ToObjectSpace(clone.PrimaryPart.CFrame)
                    w.Parent = p
                    table.insert(data.welds, w)
                end
            end
        end
        clone.Parent = mesh
    elseif clone:IsA("BasePart") then
        clone.CanCollide = false
        clone.Massless = true
        clone.Anchored = false

        if clone:IsA("MeshPart") and skincfg.textureid then
            clone.TextureID = skincfg.textureid
        end

        if skincfg.particle then
            local skinassets = replicatedstorage:FindFirstChild("SkinAssets")
            if skinassets then
                local particlefolder = skinassets:FindFirstChild("GunHandleParticle")
                if particlefolder then
                    local particlesource = particlefolder:FindFirstChild(skin)
                    if particlesource then
                        local pe = particlesource:FindFirstChild("ParticleEmitter")
                        if pe then
                            pe:Clone().Parent = clone
                        end
                    end
                end
            end
        end

        clone.Parent = mesh
        local w = Instance.new("Weld")
        w.Part0 = handr
        w.Part1 = clone
        w.C0 = offset
        w.Parent = clone
        table.insert(data.welds, w)
    end

    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    if skincfg.animationid and skincfg.animationid ~= "" then
        local anim = Instance.new("Animation")
        anim.AnimationId = skincfg.animationid
        local track = animator:LoadAnimation(anim)
        track.Looped = false
        track:Play()
        data.track = track
        anim:Destroy()
        track.Ended:Once(function()
            if data.track == track then
                data.track = nil
            end
            track:Destroy()
        end)
    end
    if skincfg.soundid and skincfg.soundid ~= "" then
        local snd = Instance.new("Sound")
        snd.SoundId = skincfg.soundid
        snd.Parent = workspace
        snd:Play()
        table.insert(data.sounds, snd)
        snd.Ended:Connect(function()
            snd:Destroy()
        end)
    end

    tool:SetAttribute("CurrentKnifeSkin", skin)
end

local toolregistry = {}

local function setuptool(tool)
    if not tool:IsA("Tool") then return end
    if toolregistry[tool] then return end
    toolregistry[tool] = true

    tool.Equipped:Connect(function()
        if not cfg['skins']['enabled'] then return end

        local char = tool.Parent
        if char ~= localplayer.Character then return end

        local skin = cfg['skins']['weapons'][tool.Name]
        if not skin or skin == "" then return end

        if tool.Name == "[Knife]" then
            applyknife(char, tool, skin)
        else
            applygun(tool, skin)
        end
    end)

    tool.Unequipped:Connect(function()
        if tool.Name == "[Knife]" then
            local data = knifedata[tool]
            if not data then return end
            if data.welds then
                for _, w in ipairs(data.welds) do
                    if w then w:Destroy() end
                end
                data.welds = {}
            end
            if data.sounds then
                for _, s in ipairs(data.sounds) do
                    if s and s.Parent then s:Destroy() end
                end
                data.sounds = {}
            end
            local mesh = tool:FindFirstChild("Default")
            if mesh then
                local children = mesh:GetChildren()
                for i = 1, #children do
                    local v = children[i]
                    if v.Name == "Handle.R" or v:IsA("Model") or (v:IsA("MeshPart") and v.Name ~= "Default") then
                        v:Destroy()
                    end
                end
                mesh.Transparency = 0
            end
        end
    end)

    if tool.Parent == localplayer.Character then
        if not cfg['skins']['enabled'] then return end

        local skin = cfg['skins']['weapons'][tool.Name]
        if skin and skin ~= "" then
            if tool.Name == "[Knife]" then
                task.spawn(function()
                    applyknife(localplayer.Character, tool, skin)
                end)
            else
                task.spawn(function()
                    applygun(tool, skin)
                end)
            end
        end
    end
end

local function watchchar(char)
    if not char then return end
    local children = char:GetChildren()
    for i = 1, #children do
        local v = children[i]
        if v:IsA("Tool") then
            setuptool(v)
        end
    end
    char.ChildAdded:Connect(function(v)
        if v:IsA("Tool") then
            setuptool(v)
        end
    end)
end

local function applyheadless(char)
    if not cfg['headless']['enabled'] then return end
    if not char then return end

    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 1
        head.CanCollide = false
        local face = head:FindFirstChild("face")
        if face then
            face.Transparency = 1
        end
    end

    if cfg['headless']['remove face accessories'] then
        for _, accessory in ipairs(char:GetChildren()) do
            if accessory:IsA("Accessory") then
                if accessory.AccessoryType == Enum.AccessoryType.Face then
                    local handle = accessory:FindFirstChild("Handle")
                    if handle then
                        handle.Transparency = 1
                        handle.CanCollide = false
                    end
                end
            end
        end
    end

    char.ChildAdded:Connect(function(child)
        if not cfg['headless']['enabled'] then return end
        if child:IsA("Accessory") and child.AccessoryType == Enum.AccessoryType.Face then
            if not cfg['headless']['remove face accessories'] then return end
            local handle = child:FindFirstChild("Handle")
            if not handle then
                handle = child:WaitForChild("Handle", 5)
            end
            if handle then
                handle.Transparency = 1
                handle.CanCollide = false
            end
        end
    end)
end

local function elasticout(t)
    local p = 0.3
    return math.pow(2, -10 * t) * math.sin((t - p / 4) * (2 * math.pi) / p) + 1
end

local function sineinout(t)
    return -(math.cos(math.pi * t) - 1) / 2
end

local function holdingknife()
    if not cfg['settings']['knife check'] then return false end

    local char = localplayer.Character
    if not char then return false end

    local tool = char:FindFirstChildOfClass("Tool")
    if tool and tool.Name == "[Knife]" then return true end

    return false
end

local function playerknocked(player)
    if not cfg['settings']['knock check'] then return false end

    if player.Character then
        local bodyeffects = player.Character:FindFirstChild("BodyEffects")
        if bodyeffects then
            local ko = bodyeffects:FindFirstChild("K.O")
            if ko and ko.Value == true then return true end

            local knocked = bodyeffects:FindFirstChild("Knocked")
            if knocked and knocked.Value == true then return true end
        end
    end

    return false
end

local function selfknocked()
    if not cfg['settings']['self knock check'] then return false end

    if localplayer.Character then
        local bodyeffects = localplayer.Character:FindFirstChild("BodyEffects")
        if bodyeffects then
            local ko = bodyeffects:FindFirstChild("K.O")
            if ko and ko.Value == true then return true end

            local knocked = bodyeffects:FindFirstChild("Knocked")
            if knocked and knocked.Value == true then return true end
        end
    end
    return false
end

local function cansee(part)
    if not cfg['settings']['visible check'] then return true end
    if not part or not part.Parent then return false end

    local char = part.Parent
    local origin = camera.CFrame.Position
    local dir = (part.Position - origin).Unit * (part.Position - origin).Magnitude

    rayparams.FilterDescendantsInstances = {localplayer.Character, char, fovparts.silentaim, fovparts.camlock, fovparts.triggerbot}

    local result = workspace:Raycast(origin, dir, rayparams)

    return result == nil or result.Instance:IsDescendantOf(char)
end

local function withindistance(part, distcfg)
    if not distcfg or not distcfg['enabled'] then return true end
    if not part or not part.Parent then return false end

    local char = localplayer.Character
    if not char then return false end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    return (hrp.Position - part.Position).Magnitude <= distcfg['max distance']
end

local function getbodyparts(char)
    return {
        char:FindFirstChild("Head"),
        char:FindFirstChild("UpperTorso"),
        char:FindFirstChild("HumanoidRootPart"),
        char:FindFirstChild("LowerTorso"),
        char:FindFirstChild("LeftUpperArm"),
        char:FindFirstChild("RightUpperArm"),
        char:FindFirstChild("LeftLowerArm"),
        char:FindFirstChild("RightLowerArm"),
        char:FindFirstChild("LeftHand"),
        char:FindFirstChild("RightHand"),
        char:FindFirstChild("LeftUpperLeg"),
        char:FindFirstChild("RightUpperLeg"),
        char:FindFirstChild("LeftLowerLeg"),
        char:FindFirstChild("RightLowerLeg"),
        char:FindFirstChild("LeftFoot"),
        char:FindFirstChild("RightFoot"),
    }
end

local function closestbodypart(char)
    local closestpart = nil
    local shortestdist = math.huge

    local bodyparts = getbodyparts(char)
    local mousepos = uis:GetMouseLocation()

    for _, part in pairs(bodyparts) do
        if part then
            local screenpos, onscreen = camera:WorldToViewportPoint(part.Position)

            if onscreen then
                local dist = math.sqrt(
                    (screenpos.X - mousepos.X)^2 +
                    (screenpos.Y - mousepos.Y)^2
                )

                if dist < shortestdist then
                    shortestdist = dist
                    closestpart = part
                end
            end
        end
    end

    return closestpart
end

local function mouseinfov3d(fovpart)
    if not fovpart.Parent then return false end

    local mpos = uis:GetMouseLocation()
    local ray = camera:ViewportPointToRay(mpos.X, mpos.Y)

    local cf = fovpart.CFrame
    local size = fovpart.Size / 2

    local localorigin = cf:PointToObjectSpace(ray.Origin)
    local localdir = cf:VectorToObjectSpace(ray.Direction * 1000)

    local tmin, tmax = -math.huge, math.huge

    for _, axis in ipairs({"X", "Y", "Z"}) do
        local o = localorigin[axis]
        local d = localdir[axis]
        local s = size[axis]

        if math.abs(d) < 1e-8 then
            if o < -s or o > s then return false end
        else
            local t1 = (-s - o) / d
            local t2 = ( s - o) / d
            if t1 > t2 then t1, t2 = t2, t1 end
            tmin = math.max(tmin, t1)
            tmax = math.min(tmax, t2)
            if tmin > tmax then return false end
        end
    end

    return tmax > 0
end

local function partinfov3d(part, fovcfg)
    if not fovcfg['enabled'] then return true end

    local char = part.Parent
    if not char then return false end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local sx = fovcfg['size']['x']
    local sy = fovcfg['size']['y']
    local sz = fovcfg['size']['z']

    local fovsize = hrp.Size + Vector3.new(sx, sy, sz)
    local fovcf = hrp.CFrame

    local mpos = uis:GetMouseLocation()
    local ray = camera:ViewportPointToRay(mpos.X, mpos.Y)

    local cf = fovcf
    local size = fovsize / 2

    local localorigin = cf:PointToObjectSpace(ray.Origin)
    local localdir = cf:VectorToObjectSpace(ray.Direction * 1000)

    local tmin, tmax = -math.huge, math.huge

    for _, axis in ipairs({"X", "Y", "Z"}) do
        local o = localorigin[axis]
        local d = localdir[axis]
        local s = size[axis]

        if math.abs(d) < 1e-8 then
            if o < -s or o > s then return false end
        else
            local t1 = (-s - o) / d
            local t2 = ( s - o) / d
            if t1 > t2 then t1, t2 = t2, t1 end
            tmin = math.max(tmin, t1)
            tmax = math.min(tmax, t2)
            if tmin > tmax then return false end
        end
    end

    return tmax > 0
end

local function mouseinfovconfig(fovcfg, targetpart)
    if not fovcfg['enabled'] then return true end
    if not targetpart or not targetpart.Parent then return false end
    if fovcfg['mode'] == '2D' then
        local char = targetpart.Parent
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local sx = (hrp.Size.X + fovcfg['size']['x']) / 2
        local sy = (hrp.Size.Y + fovcfg['size']['y']) / 2
        local sz = (hrp.Size.Z + fovcfg['size']['z']) / 2
        local cf = hrp.CFrame
        local offsets = {
            Vector3.new( sx,  sy,  sz), Vector3.new(-sx,  sy,  sz),
            Vector3.new( sx, -sy,  sz), Vector3.new(-sx, -sy,  sz),
            Vector3.new( sx,  sy, -sz), Vector3.new(-sx,  sy, -sz),
            Vector3.new( sx, -sy, -sz), Vector3.new(-sx, -sy, -sz),
        }
        local minx, miny =  math.huge,  math.huge
        local maxx, maxy = -math.huge, -math.huge
        local valid = false
        for _, offset in ipairs(offsets) do
            local screen = camera:WorldToViewportPoint(cf:PointToWorldSpace(offset))
            if screen.Z > 0 then
                valid = true
                if screen.X < minx then minx = screen.X end
                if screen.Y < miny then miny = screen.Y end
                if screen.X > maxx then maxx = screen.X end
                if screen.Y > maxy then maxy = screen.Y end
            end
        end
        if not valid then return false end
        local mpos = uis:GetMouseLocation()
        return mpos.X >= minx and mpos.X <= maxx and mpos.Y >= miny and mpos.Y <= maxy
    end
    return partinfov3d(targetpart, fovcfg)
end

local function getscreenbounds2d(hrp, fovcfg)
    local sx = (hrp.Size.X + fovcfg['size']['x']) / 2
    local sy = (hrp.Size.Y + fovcfg['size']['y']) / 2
    local sz = (hrp.Size.Z + fovcfg['size']['z']) / 2
    local cf = hrp.CFrame
    local offsets = {
        Vector3.new( sx,  sy,  sz), Vector3.new(-sx,  sy,  sz),
        Vector3.new( sx, -sy,  sz), Vector3.new(-sx, -sy,  sz),
        Vector3.new( sx,  sy, -sz), Vector3.new(-sx,  sy, -sz),
        Vector3.new( sx, -sy, -sz), Vector3.new(-sx, -sy, -sz),
    }
    local minx, miny =  math.huge,  math.huge
    local maxx, maxy = -math.huge, -math.huge
    local valid = false
    for _, offset in ipairs(offsets) do
        local screen = camera:WorldToViewportPoint(cf:PointToWorldSpace(offset))
        if screen.Z > 0 then
            valid = true
            if screen.X < minx then minx = screen.X end
            if screen.Y < miny then miny = screen.Y end
            if screen.X > maxx then maxx = screen.X end
            if screen.Y > maxy then maxy = screen.Y end
        end
    end
    if not valid then return nil, nil end
    return Vector2.new(minx, miny), Vector2.new(maxx, maxy)
end

local function setbox2d(lines, tl, br, color)
    lines[1].From = tl
    lines[1].To   = Vector2.new(br.X, tl.Y)
    lines[2].From = Vector2.new(tl.X, br.Y)
    lines[2].To   = br
    lines[3].From = tl
    lines[3].To   = Vector2.new(tl.X, br.Y)
    lines[4].From = Vector2.new(br.X, tl.Y)
    lines[4].To   = br
    for _, l in ipairs(lines) do
        l.Color   = color
        l.Visible = true
    end
end

local function hidebox2d(lines)
    for _, l in ipairs(lines) do
        l.Visible = false
    end
end

local function findtarget(fovcfg, distcfg, knifecheck)
    if knifecheck and holdingknife() then return nil end

    local besttarget = nil
    local bestdist = math.huge
    local mpos = uis:GetMouseLocation()

    for _, player in pairs(players:GetPlayers()) do
        if player ~= localplayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not playerknocked(player) then
                local char = player.Character
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end

                local screenpos, onscreen = camera:WorldToViewportPoint(hrp.Position)
                if not onscreen then continue end

                if fovcfg and fovcfg['enabled'] and not mouseinfovconfig(fovcfg, hrp) then continue end
                if not cansee(hrp) then continue end
                if not withindistance(hrp, distcfg) then continue end

                local dist = math.sqrt(
                    (screenpos.X - mpos.X)^2 +
                    (screenpos.Y - mpos.Y)^2
                )

                if dist < bestdist then
                    bestdist = dist
                    besttarget = hrp
                end
            end
        end
    end

    if besttarget then
        return closestbodypart(besttarget.Parent) or besttarget
    end

    return nil
end

local function predictedpos(part, config)
    if not config['use prediction'] then return part.Position end

    local vel = part.AssemblyLinearVelocity
    local prediction = config['prediction']

    local predval
    if type(prediction) == "table" then
        predval = prediction['x'] or prediction['y'] or prediction['z'] or 0.133
    else
        predval = (prediction == 0) and 0.133 or prediction
    end

    return part.Position + Vector3.new(
        vel.X * predval,
        vel.Y * predval,
        vel.Z * predval
    )
end

local function getcamlocktarget()
    if camlockactive and currenttarget then
        local player = players:GetPlayerFromCharacter(currenttarget.Parent)
        if player and not playerknocked(player) then
            local targetpart = nil

            if cfg['camera aimbot']['hitpart'] == 'Closest Part' then
                local now = tick()
                if now - lasttargetscan >= scanrate then
                    lasttargetscan = now
                    targetpart = closestbodypart(currenttarget.Parent)
                    if targetpart then
                        currenttarget = targetpart
                    end
                else
                    targetpart = currenttarget
                end
            else
                targetpart = currenttarget.Parent:FindFirstChild(cfg['camera aimbot']['hitpart'])
            end

            if targetpart then
                if cansee(targetpart) and withindistance(targetpart, cfg['camera aimbot']['distance check']) then
                    lastvisibletarget = targetpart
                    return targetpart
                else
                    return nil
                end
            end
        else
            currenttarget = nil
            camlockactive = false
            lastvisibletarget = nil
            targetline.Visible = false
            return nil
        end

        return nil
    else
        return findtarget(cfg['camera aimbot']['fov'], cfg['camera aimbot']['distance check'], true)
    end
end

local function applycamlock()
    if not camlockactive then return end

    if selfknocked() then
        currenttarget = nil
        camlockactive = false
        lastvisibletarget = nil
        targetline.Visible = false
        return
    end

    if holdingknife() then return end

    if cfg['camera aimbot']['fov']['enabled'] and currenttarget and not mouseinfovconfig(cfg['camera aimbot']['fov'], currenttarget) then
        return
    end

    local target = getcamlocktarget()

    if target then
        local targetpos = predictedpos(target, cfg['camera aimbot'])

        local camcf = camera.CFrame
        local targetcf = CFrame.new(camcf.Position, targetpos)

        local smoothcfg = cfg['camera aimbot']['smoothing']
        local bax = 1 / smoothcfg['x']
        local bay = 1 / smoothcfg['y']
        local baz = 1 / smoothcfg['z']

        local eax = elasticout(math.min(bax, 1))
        local eay = elasticout(math.min(bay, 1))
        local eaz = elasticout(math.min(baz, 1))

        local avgea = (eax + eay + eaz) / 3
        local avgba = (bax + bay + baz) / 3

        local smoothcf = camcf:Lerp(targetcf, avgea * avgba)

        local sinea = sineinout(math.min(avgba, 1))
        camera.CFrame = smoothcf:Lerp(targetcf, sinea * avgba)
    else
        if lastvisibletarget then
            local player = players:GetPlayerFromCharacter(lastvisibletarget.Parent)
            if player and not playerknocked(player) then
                local tp = lastvisibletarget
                if tp and cansee(tp) and withindistance(tp, cfg['camera aimbot']['distance check']) then
                    currenttarget = lastvisibletarget
                end
            end
        end
    end
end

local function updatefovbox(fovpart, lines2d, fovcfg, isactive)
    if not fovcfg['enabled'] then
        fovpart.Transparency = 1
        hidebox2d(lines2d)
        return
    end

    if isactive and currenttarget and currenttarget.Parent then
        local char = currenttarget.Parent
        local hrp = char:FindFirstChild("HumanoidRootPart")

        if hrp then
            local sx = fovcfg['size']['x']
            local sy = fovcfg['size']['y']
            local sz = fovcfg['size']['z']

            if fovcfg['mode'] == '2D' then
                fovpart.Transparency = 1
                if fovcfg['visible'] then
                    local tl, br = getscreenbounds2d(hrp, fovcfg)
                    if tl and br then
                        local mpos = uis:GetMouseLocation()
                        local inside = mpos.X >= tl.X and mpos.X <= br.X
                                   and mpos.Y >= tl.Y and mpos.Y <= br.Y
                        local color = inside and fovcfg['active color'] or Color3.fromRGB(150, 150, 150)
                        setbox2d(lines2d, tl, br, color)
                    else
                        hidebox2d(lines2d)
                    end
                else
                    hidebox2d(lines2d)
                end
            else
                hidebox2d(lines2d)
                fovpart.Size = hrp.Size + Vector3.new(sx, sy, sz)
                fovpart.CFrame = hrp.CFrame

                if fovcfg['visible'] then
                    fovpart.Transparency = 0.85
                    if mouseinfov3d(fovpart) then
                        fovpart.BrickColor = BrickColor.new(fovcfg['active color'])
                    else
                        fovpart.BrickColor = BrickColor.new("Grey")
                    end
                else
                    fovpart.Transparency = 1
                end
            end
        else
            fovpart.Transparency = 1
            hidebox2d(lines2d)
        end
    else
        fovpart.Transparency = 1
        hidebox2d(lines2d)
    end
end

local function updatetargetline()
    if not cfg['target line']['enabled'] then
        targetline.Visible = false
        return
    end

    if not currenttarget or not currenttarget.Parent or (not silentaimactive and not camlockactive) then
        targetline.Visible = false
        return
    end

    local char = currenttarget.Parent
    local hrp = char:FindFirstChild("HumanoidRootPart")

    if not hrp then
        targetline.Visible = false
        return
    end

    local screenpos, onscreen = camera:WorldToViewportPoint(hrp.Position)

    if onscreen and screenpos.Z > 0 then
        local mpos = uis:GetMouseLocation()

        targetline.From = Vector2.new(mpos.X, mpos.Y)
        targetline.To = Vector2.new(screenpos.X, screenpos.Y)
        targetline.Thickness = cfg['target line']['thickness']
        targetline.Transparency = cfg['target line']['transparency']

        if cansee(currenttarget) then
            targetline.Color = cfg['target line']['vulnerable']
        else
            targetline.Color = cfg['target line']['invulnerable']
        end

        targetline.Visible = true
    else
        targetline.Visible = false
    end
end

local function triggerbot()
    if not cfg['trigger bot']['enabled'] then return end
    if not triggerenabled then return end
    if holdingknife() then return end
    if tick() - lasttriggerclick < cfg['trigger bot']['delay'] then return end
    if cfg['trigger bot']['require target'] and not currenttarget then return end

    if currenttarget then
        local char = currenttarget.Parent
        if not char then return end

        local player = players:GetPlayerFromCharacter(char)
        if not player then return end

        if playerknocked(player) then return end
        if not cansee(currenttarget) then return end
        if not withindistance(currenttarget, cfg['trigger bot']['distance check']) then return end
        if cfg['trigger bot']['fov']['enabled'] and not mouseinfovconfig(cfg['trigger bot']['fov'], currenttarget) then return end
    end

    local tool = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Tool")
    if not tool then return end

    if cfg['trigger bot']['specific weapons']['enabled'] then
        local valid = false
        for _, wname in pairs(cfg['trigger bot']['specific weapons']['weapons']) do
            local clean = wname:gsub("%[", ""):gsub("%]", "")
            if tool.Name == wname or tool.Name:find(clean) then
                valid = true
                break
            end
        end
        if not valid then return end
    end

    tool:Activate()
    lasttriggerclick = tick()
end

local function getrapidgun()
    local char = localplayer.Character
    if not char then return nil end
    for _, tool in next, char:GetChildren() do
        if tool:IsA("Tool") and tool:FindFirstChild("Ammo") then
            return tool
        end
    end
    return nil
end

local function patchtool(tool)
    pcall(function()
        for _, conn in pairs(getconnections(tool.Activated)) do
            local info = debug.getinfo(conn.Function)
            for i = 1, info.nups do
                local val = debug.getupvalue(conn.Function, i)
                if type(val) == "number" then
                    debug.setupvalue(conn.Function, i, 0)
                end
            end
        end
    end)
end

local function oncharrapidfire(char)
    isfiring = false
    char.ChildAdded:Connect(function(tool)
        if tool:IsA("Tool") and cfg['rapid fire']['enabled'] then
            patchtool(tool)
        end
    end)
end

local function rapidfire()
    if not cfg['rapid fire']['enabled'] then
        isfiring = false
        return
    end

    if not isfiring then return end
    if tick() - lastrapidfire < cfg['rapid fire']['delay'] then return end

    local gun = getrapidgun()
    if not gun then return end

    if cfg['rapid fire']['specific weapons']['enabled'] then
        local valid = false
        for _, wname in pairs(cfg['rapid fire']['specific weapons']['weapons']) do
            local clean = wname:gsub("%[", ""):gsub("%]", "")
            if gun.Name == wname or gun.Name:find(clean) then
                valid = true
                break
            end
        end
        if not valid then
            isfiring = false
            return
        end
    end

    gun:Activate()
    lastrapidfire = tick()
end

local function refreshesp()
    if not cfg['esp']['enabled'] then
        for userid, esp in pairs(esplabels) do
            esp.nametag:Remove()
            esplabels[userid] = nil
        end
        return
    end

    for userid, esp in pairs(esplabels) do
        local player = esp.player
        if not player or not player.Parent then
            esp.nametag.Visible = false
            esp.nametag:Remove()
            esplabels[userid] = nil
            continue
        end

        if player.Character and player.Character.Parent and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Head") then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then
                esp.nametag.Visible = false
                continue
            end

            local head = player.Character.Head
            local hrp = player.Character.HumanoidRootPart

            local worldpos
            if cfg['esp']['name above'] then
                worldpos = head.Position + Vector3.new(0, 1.5, 0)
            else
                worldpos = hrp.Position - Vector3.new(0, 2.8, 0)
            end

            local esppos, onscreen = camera:WorldToViewportPoint(worldpos)

            if onscreen and esppos.Z > 0 then
                local newpos = Vector2.new(esppos.X, esppos.Y)
                local cur = esp.nametag.Position
                if math.abs(newpos.X - cur.X) > 0.5 or math.abs(newpos.Y - cur.Y) > 0.5 then
                    esp.nametag.Position = newpos
                end

                if cfg['esp']['use display name'] then
                    esp.nametag.Text = player.DisplayName
                else
                    esp.nametag.Text = player.Name
                end

                if currenttarget and currenttarget.Parent == player.Character then
                    esp.nametag.Color = cfg['esp']['target color']
                else
                    esp.nametag.Color = cfg['esp']['color']
                end

                esp.nametag.Visible = true
            else
                esp.nametag.Visible = false
            end
        else
            esp.nametag.Visible = false
        end
    end
end

local function touchingwall()
    local char = localplayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local dirs = {
        hrp.CFrame.LookVector * 2.5,
        -hrp.CFrame.LookVector * 2.5,
        hrp.CFrame.RightVector * 2.5,
        -hrp.CFrame.RightVector * 2.5
    }

    for _, dir in pairs(dirs) do
        if workspace:Raycast(hrp.Position, dir, params) then
            return true
        end
    end

    return false
end

local function getjumppower()
    local char = localplayer.Character
    if not char then return cfg['spiderman']['jumppower'] end

    local tool = char:FindFirstChildOfClass("Tool")
    if tool and tool.Name == "[Knife]" then
        return cfg['spiderman']['knifejumppower']
    end

    return cfg['spiderman']['jumppower']
end

local function setupwalljumpreset()
    if walljumpconnection then
        walljumpconnection:Disconnect()
        walljumpconnection = nil
    end

    haswalljumped = false

    local char = localplayer.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then
        task.wait(0.5)
        hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
    end

    walljumpconnection = hum.StateChanged:Connect(function(old, new)
        if new == Enum.HumanoidStateType.Landed or
           new == Enum.HumanoidStateType.Running or
           new == Enum.HumanoidStateType.RunningNoPhysics or
           new == Enum.HumanoidStateType.Jumping then
            haswalljumped = false
        end
    end)
end

local function oncharspiderman(char)
    haswalljumped = false
    task.wait(0.1)
    setupwalljumpreset()
end

local grm = getrawmetatable(game)
local oldindex = grm.__index
setreadonly(grm, false)

grm.__index = LPH_NO_VIRTUALIZE(function(self, key)
    if not checkcaller() and self == mouse and cfg['silent aimbot']['enabled'] then
        if key == "Hit" then
            if cfg['targeting']['mode'] == 'Automatic' then
                silentaimactive = true
            end

            if not silentaimactive then return oldindex(self, key) end
            if not currenttarget then return oldindex(self, key) end

            local char = currenttarget.Parent
            if not char then return oldindex(self, key) end

            local player = players:GetPlayerFromCharacter(char)
            if not player then return oldindex(self, key) end

            if playerknocked(player) then return oldindex(self, key) end
            if not cansee(currenttarget) then return oldindex(self, key) end
            if not withindistance(currenttarget, cfg['silent aimbot']['distance check']) then return oldindex(self, key) end

            if cfg['silent aimbot']['fov']['enabled'] and not mouseinfovconfig(cfg['silent aimbot']['fov'], currenttarget) then
                return oldindex(self, key)
            end

            local targetpart = currenttarget
            if targetpart then
                local predpos = predictedpos(targetpart, cfg['silent aimbot'])
                return CFrame.new(predpos)
            end
        end
    end
    return oldindex(self, key)
end)

local oldrandom
oldrandom = hookfunction(math.random, LPH_NO_VIRTUALIZE(function(...)
    local args = {...}
    if checkcaller() then
        return oldrandom(...)
    end

    if (#args == 0) or (args[1] == -0.05 and args[2] == 0.05) or (args[1] == -0.1) or (args[1] == -0.05) then
        if cfg['spread modifications']['enabled'] then
            if cfg['spread modifications']['specific weapons']['enabled'] then
                local tool = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Tool")
                if tool then
                    local wname = tool.Name
                    local found = false

                    for _, weapon in pairs(cfg['spread modifications']['specific weapons']['weapons']) do
                        if wname == weapon then
                            found = true
                            break
                        end
                    end

                    if found then
                        return oldrandom(...) * (cfg['spread modifications']['amount'] / 100)
                    end
                end
            else
                return oldrandom(...) * (cfg['spread modifications']['amount'] / 100)
            end
        end
    end

    return oldrandom(...)
end))

local function addesp(player)
    if player == localplayer then return end
    if not cfg['esp']['enabled'] then return end

    local esp = {
        player = player,
        nametag = Drawing.new("Text"),
    }

    esp.nametag.Size = 14
    esp.nametag.Center = true
    esp.nametag.Outline = true
    esp.nametag.OutlineColor = Color3.fromRGB(0, 0, 0)
    esp.nametag.Color = cfg['esp']['color']
    esp.nametag.Font = Drawing.Fonts.Plex
    esp.nametag.Visible = false
    esp.nametag.ZIndex = 1000

    esplabels[player.UserId] = esp
end

local function removeesp(player)
    local esp = esplabels[player.UserId]
    if esp then
        esp.nametag:Remove()
        esplabels[player.UserId] = nil
    end
end

for _, player in pairs(players:GetPlayers()) do
    if player ~= localplayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        addesp(player)
    end

    player.CharacterAdded:Connect(function(char)
        removeesp(player)
        char:WaitForChild("HumanoidRootPart")
        task.wait(0.1)
        addesp(player)
    end)

    player.CharacterRemoving:Connect(function()
        removeesp(player)
    end)
end

players.PlayerAdded:Connect(function(player)
    if player ~= localplayer then
        player.CharacterAdded:Connect(function(char)
            removeesp(player)
            char:WaitForChild("HumanoidRootPart")
            task.wait(0.1)
            addesp(player)
        end)

        player.CharacterRemoving:Connect(function()
            removeesp(player)
        end)
    end
end)

players.PlayerRemoving:Connect(function(player)
    removeesp(player)
end)

if localplayer.Character then
    watchchar(localplayer.Character)
    oncharspiderman(localplayer.Character)
    applyheadless(localplayer.Character)
    oncharrapidfire(localplayer.Character)
end

localplayer.CharacterAdded:Connect(function(char)
    speedenabled = false
    watchchar(char)
    oncharspiderman(char)
    oncharrapidfire(char)
    task.defer(function()
        applyheadless(char)
    end)
end)

local backpacktools = localplayer.Backpack:GetChildren()
for i = 1, #backpacktools do
    local v = backpacktools[i]
    if v:IsA("Tool") then
        setuptool(v)
    end
end

localplayer.Backpack.ChildAdded:Connect(function(v)
    if v:IsA("Tool") then
        setuptool(v)
    end
end)

task.spawn(function()
    while task.wait(2) do
        if localplayer.Character then
            local hum = localplayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and not walljumpconnection then
                setupwalljumpreset()
            end
        end
    end
end)

uis.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == Enum.KeyCode.Space then
        if cfg['spiderman']['enabled'] then
            local char = localplayer.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hum and hrp then
                    local state = hum:GetState()
                    if state == Enum.HumanoidStateType.Freefall and touchingwall() and not haswalljumped then
                        haswalljumped = true
                        local power = getjumppower()
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                        local elapsed = 0
                        task.spawn(function()
                            while elapsed < 0.1 do
                                local dt = task.wait()
                                elapsed = elapsed + dt
                                if hrp and hrp.Parent then
                                    hrp.AssemblyLinearVelocity = Vector3.new(
                                        hrp.AssemblyLinearVelocity.X,
                                        power,
                                        hrp.AssemblyLinearVelocity.Z
                                    )
                                end
                            end
                        end)
                    end
                end
            end
        end
    end

    if input.KeyCode == Enum.KeyCode[cfg['binds']['silent aim']] then
        if cfg['targeting']['mode'] == 'Select' then
            if cfg['silent aimbot']['mode'] == 'Toggle' then
                silentaimactive = not silentaimactive
                if not silentaimactive then
                    if not camlockactive then
                        currenttarget = nil
                        lastvisibletarget = nil
                        targetline.Visible = false
                    end
                else
                    local target = findtarget(cfg['silent aimbot']['fov'], cfg['silent aimbot']['distance check'], false)
                    if target then
                        currenttarget = target
                        lastvisibletarget = target
                        updatefovbox(fovparts.silentaim, fov2dboxes.silentaim, cfg['silent aimbot']['fov'], true)
                    end
                end
            elseif cfg['silent aimbot']['mode'] == 'Hold' then
                local target = findtarget(cfg['silent aimbot']['fov'], cfg['silent aimbot']['distance check'], false)
                if target then
                    currenttarget = target
                    lastvisibletarget = target
                    silentaimactive = true
                    updatefovbox(fovparts.silentaim, fov2dboxes.silentaim, cfg['silent aimbot']['fov'], true)
                end
            end
        end
    end

    if input.KeyCode == Enum.KeyCode[cfg['binds']['cam lock']] then
        if cfg['camera aimbot']['mode'] == 'Toggle' then
            if camlockactive then
                camlockactive = false
                if not silentaimactive and cfg['targeting']['mode'] ~= 'Automatic' then
                    currenttarget = nil
                    lastvisibletarget = nil
                    targetline.Visible = false
                end
            else
                local target = findtarget(cfg['camera aimbot']['fov'], cfg['camera aimbot']['distance check'], true)
                if target then
                    currenttarget = target
                    lastvisibletarget = target
                    camlockactive = true
                    updatefovbox(fovparts.camlock, fov2dboxes.camlock, cfg['camera aimbot']['fov'], true)
                end
            end
        elseif cfg['camera aimbot']['mode'] == 'Hold' then
            local target = findtarget(cfg['camera aimbot']['fov'], cfg['camera aimbot']['distance check'], true)
            if target then
                currenttarget = target
                lastvisibletarget = target
                camlockactive = true
                updatefovbox(fovparts.camlock, fov2dboxes.camlock, cfg['camera aimbot']['fov'], true)
            end
        end
    end

    if input.KeyCode == Enum.KeyCode[cfg['binds']['triggerbot']] then
        if cfg['trigger bot']['mode'] == 'Toggle' then
            triggerenabled = not triggerenabled
        elseif cfg['trigger bot']['mode'] == 'Hold' then
            triggerenabled = true
        end
    end

    if input.KeyCode == Enum.KeyCode[cfg['binds']['super jump']] then
        if cfg['super jump']['enabled'] then
            superjumpenabled = not superjumpenabled
        end
    end

    if input.KeyCode == Enum.KeyCode[cfg['binds']['esp']] then
        cfg['esp']['enabled'] = not cfg['esp']['enabled']
        if cfg['esp']['enabled'] then
            for _, player in pairs(players:GetPlayers()) do
                if player ~= localplayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    if not esplabels[player.UserId] then
                        addesp(player)
                    end
                end
            end
        end
    end

    if input.KeyCode == Enum.KeyCode[cfg['binds']['speed']] then
        if cfg['speed modifications']['enabled'] then
            speedenabled = not speedenabled
        end
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if cfg['rapid fire']['enabled'] then
            local gun = getrapidgun()
            if gun then
                isfiring = true
            end
        end
    end
end)

uis.InputEnded:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isfiring = false
    end

    if processed then return end

    if input.KeyCode == Enum.KeyCode[cfg['binds']['silent aim']] then
        if cfg['targeting']['mode'] == 'Select' then
            if cfg['silent aimbot']['mode'] == 'Hold' then
                silentaimactive = false
                if not camlockactive then
                    currenttarget = nil
                    lastvisibletarget = nil
                    targetline.Visible = false
                end
            end
        end
    end

    if input.KeyCode == Enum.KeyCode[cfg['binds']['cam lock']] then
        if cfg['camera aimbot']['mode'] == 'Hold' then
            camlockactive = false
            if not silentaimactive and cfg['targeting']['mode'] ~= 'Automatic' then
                currenttarget = nil
                lastvisibletarget = nil
                targetline.Visible = false
            end
        end
    end

    if input.KeyCode == Enum.KeyCode[cfg['binds']['triggerbot']] then
        if cfg['trigger bot']['mode'] == 'Hold' then
            triggerenabled = false
        end
    end
end)

runservice.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function(dt)
    if cfg['targeting']['mode'] == 'Automatic' then
        local now = tick()
        if now - lasttargetscan >= scanrate then
            lasttargetscan = now
            currenttarget = findtarget(cfg['silent aimbot']['fov'], cfg['silent aimbot']['distance check'], false)
        end
        silentaimactive = currenttarget ~= nil
    end

    if selfknocked() then
        currenttarget = nil
        silentaimactive = false
        camlockactive = false
        lastvisibletarget = nil
        targetline.Visible = false
    end

    triggerbot()
    rapidfire()

    if superjumpenabled and cfg['super jump']['enabled'] then
        local hum = localplayer.Character and localplayer.Character:FindFirstChild("Humanoid")
        if hum then
            if hum.JumpPower ~= cfg['super jump']['jump power'] then
                hum.JumpPower = cfg['super jump']['jump power']
            end
        end
    end

    if cfg['speed modifications']['enabled'] and speedenabled then
        local hum = localplayer.Character and localplayer.Character:FindFirstChild("Humanoid")
        if hum then
            hum.WalkSpeed = 16 * cfg['speed modifications']['multiplier']
        end
    end

    if cfg['hitbox expander']['enabled'] then
        for _, player in pairs(players:GetPlayers()) do
            if player ~= localplayer and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = Vector3.new(cfg['hitbox expander']['size'], cfg['hitbox expander']['size'], cfg['hitbox expander']['size'])

                    if cfg['hitbox expander']['Visualize'] then
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

    updatefovbox(fovparts.silentaim, fov2dboxes.silentaim, cfg['silent aimbot']['fov'], silentaimactive)
    updatefovbox(fovparts.camlock, fov2dboxes.camlock, cfg['camera aimbot']['fov'], camlockactive)
    updatefovbox(fovparts.triggerbot, fov2dboxes.triggerbot, cfg['trigger bot']['fov'], triggerenabled)

    updatetargetline()
    refreshesp()

    if cfg['camera aimbot']['enabled'] then
        applycamlock()
    end
end))
