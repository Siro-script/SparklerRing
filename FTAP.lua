-- FireworkSparkler Wing (羽ばたく翼)
-- チェーン遅延付き

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

local Window = OrionLib:MakeWindow({ Name = "FireworkSparkler Wing", HidePremium = true, SaveConfig = false })
local WingTab = Window:MakeTab({ Name = "👼 Wing", Icon = "rbxassetid://448336338" })

-- 設定変数 (Wing)
local WingEnabled = false
local WingVerticalOffset = 2.0
local WingSpread = 5.0
local WingObjectCount = 10
local WingFlapShape = 2.0
local WingFlapSpeed = 1.0
local WingFlapAmount = 3.0
local WingChainDelay = 0.01

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
    
    local maxObjects = WingObjectCount * 2
    local foundCount = 0
    
    for _, d in ipairs(Workspace:GetDescendants()) do
        if foundCount >= maxObjects then break end
        
        if d:IsA("Model") and d.Name == "FireworkSparkler" then
            local part = getPartFromModel(d)
            if part and not part.Anchored then
                local rec = { 
                    model = d, 
                    part = part,
                    index = foundCount + 1,
                    targetPos = part.Position,
                    targetCF = part.CFrame
                }
                table.insert(list, rec)
                foundCount = foundCount + 1
            end
        end
    end
    
    for i = 1, #list do
        attachPhysics(list[i])
    end
end

-- ★ Wing形状計算 (羽ばたく翼) ★
local function getWingPosition(index, total, time)
    local halfTotal = total / 2
    local isLeftWing = index <= halfTotal
    local wingIndex = isLeftWing and index or (index - halfTotal)
    
    local t = (wingIndex - 1) / (halfTotal - 1)
    
    local phase = (time * WingFlapSpeed - wingIndex * 0.05) * WingFlapShape
    local sinValue = math.sin(phase)
    
    local actualFlapAmount
    if sinValue > 0 then
        actualFlapAmount = WingFlapAmount * 0.6
    else
        actualFlapAmount = WingFlapAmount
    end
    
    local flapAngle = sinValue * math.rad(actualFlapAmount)
    
    local baseX = t * WingSpread
    local rotatedY = baseX * math.sin(flapAngle)
    local rotatedX = baseX * math.cos(flapAngle)
    
    local sideOffset = isLeftWing and -(3 + rotatedX) or (3 + rotatedX)
    
    return Vector3.new(
        sideOffset,
        WingVerticalOffset + rotatedY,
        0
    ), isLeftWing, wingIndex
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
        
        tAccum = tAccum + dt
        
        local rootVelocity = root.AssemblyLinearVelocity or root.Velocity or Vector3.new()
        
        for i, rec in ipairs(list) do
            local part = rec.part
            if not part or not part.Parent then continue end
            
            local localPos, isLeftWing, wingIndex = getWingPosition(i, #list, tAccum)
            
            -- プレイヤーの完全な向きを使用
            local targetCF = root.CFrame
            local idealPos = targetCF.Position + (targetCF - targetCF.Position):VectorToWorldSpace(localPos)
            
            -- ★ 修正: Sparklerを左に90度回転（Y軸で-90度回転） ★
            local idealRotation = targetCF * CFrame.Angles(0, -math.pi/2, 0)
            
            -- チェーン効果
            local delayMultiplier = 1 + (wingIndex - 1) * 2
            local actualDelay = WingChainDelay * delayMultiplier
            local delayFactor = math.min(1, dt / actualDelay)
            
            rec.targetPos = rec.targetPos:Lerp(idealPos, delayFactor)
            rec.targetCF = rec.targetCF:Lerp(idealRotation, delayFactor)
            
            local targetPos = rec.targetPos
            local targetRot = rec.targetCF
            
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
                bv.P = 1e6
            end
            
            -- BodyGyroで回転
            local bg = part:FindFirstChild("BodyGyro")
            if bg then
                bg.CFrame = targetRot
                bg.P = 1e6
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
-- UI要素 (Wing) - 羽ばたく翼
-- ====================================================================

WingTab:AddSection({ Name = "👼 Wing 起動" })

WingTab:AddToggle({
    Name = "👼 Wing ON/OFF",
    Default = false,
    Callback = function(v)
        WingEnabled = v
        if v then
            rescan()
            startLoop()
        else
            stopLoop()
        end
    end
})

WingTab:AddSection({ Name = "Wing 設定" })

WingTab:AddSlider({
    Name = "翼の高さ位置",
    Min = -10.0,
    Max = 20.0,
    Default = WingVerticalOffset,
    Increment = 0.5,
    Callback = function(v)
        WingVerticalOffset = v
    end
})

WingTab:AddSlider({
    Name = "翼の広がり (横の長さ)",
    Min = 3.0,
    Max = 30.0,
    Default = WingSpread,
    Increment = 1.0,
    Callback = function(v)
        WingSpread = v
    end
})

WingTab:AddSlider({
    Name = "羽ばたきの形状 (波の細かさ)",
    Min = 0.5,
    Max = 10.0,
    Default = WingFlapShape,
    Increment = 0.5,
    Callback = function(v)
        WingFlapShape = v
    end
})

WingTab:AddSlider({
    Name = "羽ばたく速さ",
    Min = 0.1,
    Max = 5.0,
    Default = WingFlapSpeed,
    Increment = 0.1,
    Callback = function(v)
        WingFlapSpeed = v
    end
})

WingTab:AddSlider({
    Name = "羽ばたく可動域 (折りたたみ角度)",
    Min = 0.0,
    Max = 100.0,
    Default = WingFlapAmount,
    Increment = 1.0,
    Callback = function(v)
        WingFlapAmount = v
    end
})

WingTab:AddSlider({
    Name = "片翼のオブジェクト数",
    Min = 3,
    Max = 15,
    Default = WingObjectCount,
    Increment = 1,
    Callback = function(v)
        WingObjectCount = v
        if WingEnabled then
            rescan()
        end
    end
})

OrionLib:Init()
