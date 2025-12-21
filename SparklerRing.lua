-- FireworkSparkler オーラ MOD
-- 高さ5の位置に直径5のリング状に配置・回転 (飛行中も安定)

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
local RingHeight = 5.0      -- 高さ5
local RingDiameter = 5.0    -- 直径5 (半径2.5)
local ObjectCount = 10      -- リングのオブジェクト数
local RotationSpeed = 20.0  -- 回転速度

local list = {}
local loopConn = nil
local tAccum = 0

-- HRP取得
local function HRP()
    local c = LP.Character or LP.CharacterAdded:Wait()
    return c:FindFirstChild("HumanoidRootPart")
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

-- 物理演算アタッチ (BodyVelocity & BodyGyro)
local function attachPhysics(rec)
    local model = rec.model
    local part = rec.part
    if not model or not part or not part.Parent then return end
    
    -- ネットワークオーナー設定
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() p:SetNetworkOwner(LP) end)
            p.CanCollide = false
            p.CanTouch = false
        end
    end
    
    -- BodyVelocity追加
    if not part:FindFirstChild("BodyVelocity") then
        local bv = Instance.new("BodyVelocity")
        bv.Name = "BodyVelocity"
        bv.MaxForce = Vector3.new(1e8, 1e8, 1e8)
        bv.Velocity = Vector3.new()
        bv.P = 1e6
        bv.Parent = part
    end
    
    -- BodyGyro追加
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

-- メインループ (リング配置と回転) - 飛行中も安定
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
        
        local radius = RingDiameter / 2
        local angleIncrement = 360 / #list
        
        -- HRPの速度を取得 (飛行中も追従させるため)
        local rootVelocity = root.AssemblyLinearVelocity or root.Velocity or Vector3.new()
        
        for i, rec in ipairs(list) do
            local part = rec.part
            if not part or not part.Parent then continue end
            
            -- 回転角度計算
            local angle = math.rad(i * angleIncrement + tAccum * 50)
            
            -- リング上の位置計算 (HRPの向きに関係なく水平リングを維持)
            local localPos = Vector3.new(
                radius * math.cos(angle),
                RingHeight,
                radius * math.sin(angle)
            )
            
            -- ワールド座標での目標位置 (HRPの回転を無視して水平を維持)
            local targetPos = root.Position + localPos
            
            -- BodyVelocityで移動 (飛行中の速度も加算)
            local dir = targetPos - part.Position
            local distance = dir.Magnitude
            local bv = part:FindFirstChild("BodyVelocity")
            
            if bv then
                if distance > 0.1 then
                    -- HRPの速度を加算して飛行中も追従
                    local moveVelocity = dir.Unit * math.min(3000, distance * 50)
                    bv.Velocity = moveVelocity + rootVelocity
                else
                    bv.Velocity = rootVelocity
                end
            end
            
            -- BodyGyroで回転 (外側を向く)
            local bg = part:FindFirstChild("BodyGyro")
            if bg then
                local lookAtCFrame = CFrame.lookAt(targetPos, root.Position) * CFrame.Angles(0, math.pi, 0)
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

-- ====================================================================
-- UI要素
-- ====================================================================

Tab:AddSection({ Name = "FireworkSparkler リング設定" })

Tab:AddSlider({
    Name = "リングの高さ",
    Min = 1.0,
    Max = 50.0,
    Default = RingHeight,
    Increment = 0.5,
    Callback = function(v)
        RingHeight = v
    end
})

Tab:AddSlider({
    Name = "リングの直径",
    Min = 3.0,
    Max = 100.0,
    Default = RingDiameter,
    Increment = 1.0,
    Callback = function(v)
        RingDiameter = v
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

OrionLib:Init()
