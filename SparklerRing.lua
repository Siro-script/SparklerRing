-- FireworkSparkler オーラ MOD
-- 高さ5の位置にリング状に配置・回転 (形状選択機能付き)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer

-- ★ OrionLibをロード ★
local OrionLib = nil
pcall(function()
    OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/jadpy/suki/refs/heads/main/orion"))()
end)

if not OrionLib then
    warn("UIライブラリ (OrionLib) のロードに失敗しました。")
    return
end

local Window = OrionLib:MakeWindow({ Name = "FireworkSparkler オーラ", HidePremium = true, SaveConfig = false })
local Tab = Window:MakeTab({ Name = "AURA", Icon = "rbxassetid://448336338" })

-- 設定変数
local Enabled = false
local FollowPlayerEnabled = false
local TargetPlayerName = ""

local RingHeight = 5.0
local RingSize = 5.0
local ObjectCount = 30
local RotationSpeed = 20.0
local ShapeType = "Circle"

local list = {}
local loopConn = nil
local tAccum = 0

-- HRP取得
local function HRP()
    local c = LP.Character or LP.CharacterAdded:Wait()
    return c:FindFirstChild("HumanoidRootPart")
end

-- ターゲットプレイヤーのHRP取得
local function getTargetHRP()
    if TargetPlayerName == "" then return nil end
    
    local targetPlayer = Players:FindFirstChild(TargetPlayerName)
    if not targetPlayer then return nil end
    
    local char = targetPlayer.Character
    if not char then return nil end
    
    return char:FindFirstChild("HumanoidRootPart")
end

-- モデルからパーツ取得
local function getPartFromModel(m)
    if m.PrimaryPart then return m.PrimaryPart end
    for _, child in ipairs(m:GetChildren()) do
        if child:IsA("BasePart") then
            return child
        end
    end
    return nil
end

-- 物理演算アタッチ
local function attachPhysics(rec)
    local model = rec.model
    local part = rec.part
    if not model or not part or not part.Parent then return end
    
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() p:SetNetworkOwner(LP) end)
            p.CanCollide = false
            p.CanTouch = false
        end
    end
    
    if not part:FindFirstChild("BodyVelocity") then
        local bv = Instance.new("BodyVelocity")
        bv.Name = "BodyVelocity"
        bv.MaxForce = Vector3.new(1e8, 1e8, 1e8)
        bv.Velocity = Vector3.new()
        bv.P = 1e6
        bv.Parent = part
    end
    
    if not part:FindFirstChild("BodyGyro") then
        local bg = Instance.new("BodyGyro")
        bg.Name = "BodyGyro"
        bg.MaxTorque = Vector3.new(1e8, 1e8, 1e8)
        bg.CFrame = part.CFrame
        bg.P = 1e6
        bg.Parent = part
    end
end

-- 物理演算デタッチ
local function detachPhysics(rec)
    local model = rec.model
    local part = rec.part
    if not model or not part then return end
    
    local bv = part:FindFirstChild("BodyVelocity")
    if bv then bv:Destroy() end
    
    local bg = part:FindFirstChild("BodyGyro")
    if bg then bg:Destroy() end
    
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            p.CanCollide = true
            p.CanTouch = true
            pcall(function() p:SetNetworkOwner(nil) end)
        end
    end
end

-- FireworkSparklerをスキャン
local function rescan()
    for _, r in ipairs(list) do
        detachPhysics(r)
    end
    list = {}
    
    local foundCount = 0
    
    for _, d in ipairs(Workspace:GetDescendants()) do
        if foundCount >= ObjectCount then break end
        
        if d:IsA("Model") and d.Name == "FireworkSparkler" then
            local part = getPartFromModel(d)
            if part and not part.Anchored then
                local rec = { model = d, part = part }
                table.insert(list, rec)
                foundCount = foundCount + 1
            end
        end
    end
    
    for i = 1, #list do
        attachPhysics(list[i])
    end
end

-- ★ 形状計算関数 ★
local function getShapePosition(index, total, size, rotation)
    local t = (index - 1) / total
    
    if ShapeType == "Circle" then
        -- 円形
        local angle = t * math.pi * 2 + rotation
        local radius = size / 2
        return Vector3.new(
            radius * math.cos(angle),
            0,
            radius * math.sin(angle)
        )
        
    elseif ShapeType == "Heart" then
        -- ハート形
        local angle = t * math.pi * 2 - math.pi / 2 + rotation
        
        -- ハートの媒介変数方程式
        local x = 16 * math.sin(angle)^3
        local y = 13 * math.cos(angle) - 5 * math.cos(2*angle) - 2 * math.cos(3*angle) - math.cos(4*angle)
        
        -- サイズに応じてスケール
        local scale = size / 32
        
        return Vector3.new(
            x * scale,
            0,
            y * scale
        )
    end
    
    return Vector3.new()
end

-- メインループ
local function startLoop()
    if loopConn then
        loopConn:Disconnect()
        loopConn = nil
    end
    tAccum = 0
    
    loopConn = RunService.Heartbeat:Connect(function(dt)
        local root = HRP()
        if not root or #list == 0 then return end
        
        tAccum = tAccum + dt * (RotationSpeed / 10)
        
        -- ターゲットとなるルートパーツを決定
        local targetRoot = root
        if FollowPlayerEnabled then
            local targetHRP = getTargetHRP()
            if targetHRP then
                targetRoot = targetHRP
            end
        end
        
        local rootVelocity = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.new()
        
        for i, rec in ipairs(list) do
            local part = rec.part
            if not part or not part.Parent then continue end
            
            -- 形状に応じた位置を計算
            local localPos = getShapePosition(i, #list, RingSize, tAccum * 0.5)
            localPos = localPos + Vector3.new(0, RingHeight, 0)
            
            local targetPos = targetRoot.Position + localPos
            
            -- BodyVelocityで移動
            local dir = targetPos - part.Position
            local distance = dir.Magnitude
            local bv = part:FindFirstChild("BodyVelocity")
            
            if bv then
                if distance > 0.1 then
                    local moveVelocity = dir.Unit * math.min(3000, distance * 50)
                    bv.Velocity = moveVelocity + rootVelocity
                else
                    bv.Velocity = rootVelocity
                end
            end
            
            -- BodyGyroで回転
            local bg = part:FindFirstChild("BodyGyro")
            if bg then
                local lookAtCFrame = CFrame.lookAt(targetPos, targetRoot.Position) * CFrame.Angles(0, math.pi, 0)
                bg.CFrame = lookAtCFrame
            end
        end
    end)
end

-- ループ停止
local function stopLoop()
    if loopConn then
        loopConn:Disconnect()
        loopConn = nil
    end
    for _, rec in ipairs(list) do
        detachPhysics(rec)
    end
    list = {}
end

-- プレイヤー名リスト取得
local function getPlayerNames()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            table.insert(names, player.Name)
        end
    end
    return names
end

-- ====================================================================
-- UI要素
-- ====================================================================

Tab:AddSection({ Name = "起動/停止" })

Tab:AddToggle({
    Name = "FireworkSparkler オーラ ON/OFF",
    Default = false,
    Callback = function(v)
        Enabled = v
        if v then
            rescan()
            startLoop()
        else
            stopLoop()
        end
    end
})

Tab:AddSection({ Name = "Follow Player" })

Tab:AddDropdown({
    Name = "ターゲットプレイヤー選択",
    Default = "",
    Options = getPlayerNames(),
    Callback = function(v)
        TargetPlayerName = v
    end
})

Tab:AddToggle({
    Name = "Follow Player",
    Default = false,
    Callback = function(v)
        FollowPlayerEnabled = v
    end
})

Tab:AddSection({ Name = "形状選択" })

Tab:AddDropdown({
    Name = "オーラの形状",
    Default = ShapeType,
    Options = {"Circle", "Heart"},
    Callback = function(v)
        ShapeType = v
    end
})

Tab:AddSection({ Name = "FireworkSparkler 設定" })

Tab:AddSlider({
    Name = "形状の高さ",
    Min = 1.0,
    Max = 50.0,
    Default = RingHeight,
    Increment = 0.5,
    Callback = function(v)
        RingHeight = v
    end
})

Tab:AddSlider({
    Name = "形状のサイズ",
    Min = 3.0,
    Max = 100.0,
    Default = RingSize,
    Increment = 1.0,
    Callback = function(v)
        RingSize = v
    end
})

Tab:AddSlider({
    Name = "オブジェクト数",
    Min = 3,
    Max = 30,
    Default = ObjectCount,
    Increment = 1,
    Callback = function(v)
        ObjectCount = v
        if Enabled then
            rescan()
        end
    end
})

Tab:AddSlider({
    Name = "回転速度",
    Min = 0.0,
    Max = 200.0,
    Default = RotationSpeed,
    Increment = 5.0,
    Callback = function(v)
        RotationSpeed = v
    end
})

OrionLib:Init()
