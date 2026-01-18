-- FireworkSparkler オーラ MOD + クリスマスツリー + Wing
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
local ChristmasTab = Window:MakeTab({ Name = "🎄 Christmas Tree", Icon = "rbxassetid://448336338" })
local WingTab = Window:MakeTab({ Name = "👼 Wing", Icon = "rbxassetid://448336338" })

-- 設定変数 (通常オーラ)
local Enabled = false
local FollowPlayerEnabled = false
local TargetPlayerName = ""
local RingHeight = 5.0
local RingSize = 5.0
local ObjectCount = 30
local RotationSpeed = 20.0
local ShapeType = "Circle"

-- 設定変数 (クリスマスツリー)
local TreeEnabled = false
local TreeFollowPlayerEnabled = false
local TreeTargetPlayerName = ""
local TreeHeight = 15.0
local TreeLayers = 5
local TreeRotationSpeed = 20.0
local TreeObjectCount = 25
local TreeRingSize = 8.0

-- 設定変数 (Wing)
local WingEnabled = false
local WingVerticalOffset = 2.0  -- 縦方向のオフセット
local WingSpread = 5.0          -- 横の広がり
local WingObjectCount = 10      -- 片翼のオブジェクト数
local WingFlapShape = 2.0       -- 羽ばたきの形状（波の周波数）
local WingFlapSpeed = 1.0       -- 羽ばたく速さ（時間の進み）
local WingFlapAmount = 3.0      -- 羽ばたく可動域（折りたたみの角度）

local list = {}
local loopConn = nil
local tAccum = 0

-- HRP取得
local function HRP()
    local c = LP.Character or LP.CharacterAdded:Wait()
    return c:FindFirstChild("HumanoidRootPart")
end

-- ターゲットプレイヤーのHRP取得
local function getTargetHRP(playerName)
    if playerName == "" then return nil end
    
    local targetPlayer = Players:FindFirstChild(playerName)
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
    
    local maxObjects
    if WingEnabled then
        maxObjects = WingObjectCount * 2  -- 左右の翼
    elseif TreeEnabled then
        maxObjects = TreeObjectCount
    else
        maxObjects = ObjectCount
    end
    
    local foundCount = 0
    
    for _, d in ipairs(Workspace:GetDescendants()) do
        if foundCount >= maxObjects then break end
        
        if d:IsA("Model") and d.Name == "FireworkSparkler" then
            local part = getPartFromModel(d)
            if part and not part.Anchored then
                local rec = { 
                    model = d, 
                    part = part,
                    index = foundCount + 1  -- インデックスを保存
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

-- ★ 形状計算関数 (通常オーラ) ★
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
        local angle = (t * 2 * math.pi) + rotation
        local x = 16 * (math.sin(angle))^3
        local y = 13 * math.cos(angle) - 5 * math.cos(2*angle) - 2 * math.cos(3*angle) - math.cos(4*angle)
        local scale = size / 30
        
        return Vector3.new(
            -y * scale,
            0,
            x * scale
        )
    end
    
    return Vector3.new()
end

-- ★ クリスマスツリー形状計算 ★
local function getTreePosition(index, total, rotation)
    -- オブジェクトをレイヤーに分配
    local objectsPerLayer = math.ceil(total / TreeLayers)
    local layerIndex = math.floor((index - 1) / objectsPerLayer)
    local indexInLayer = (index - 1) % objectsPerLayer
    
    -- 層ごとの高さと半径を計算（下から上に向かって小さくなる）
    local layerHeight = (layerIndex / TreeLayers) * TreeHeight
    local radiusAtLayer = (1 - layerIndex / TreeLayers) * TreeRingSize
    
    -- 各層での角度
    local t = indexInLayer / objectsPerLayer
    local angle = t * math.pi * 2 + rotation + (layerIndex * 0.5)
    
    return Vector3.new(
        radiusAtLayer * math.cos(angle),
        layerHeight,
        radiusAtLayer * math.sin(angle)
    )
end

-- ★ Wing形状計算 (羽ばたく翼) ★
local function getWingPosition(index, total, time)
    local halfTotal = total / 2
    local isLeftWing = index <= halfTotal
    local wingIndex = isLeftWing and index or (index - halfTotal)
    
    -- 翼の位置計算（根元から外側へ均等配置）
    local t = (wingIndex - 1) / (halfTotal - 1)  -- 0から1の範囲
    
    -- 羽ばたき計算（角度として計算）
    local phase = (time * WingFlapSpeed - wingIndex * 0.05) * WingFlapShape
    local sinValue = math.sin(phase)
    
    -- 上下で折りたたみ角度を変える
    local actualFlapAmount
    if sinValue > 0 then
        -- 上に来た時：折りたたみ角度を60%に
        actualFlapAmount = WingFlapAmount * 0.6
    else
        -- 下に来た時：通常の折りたたみ角度
        actualFlapAmount = WingFlapAmount
    end
    
    local flapAngle = sinValue * math.rad(actualFlapAmount)
    
    -- 基本の横位置（等間隔）
    local baseX = t * WingSpread
    
    -- 羽ばたきによる位置変化（角度による回転）
    -- Z軸（前後）とY軸（上下）の両方を計算
    local rotatedY = baseX * math.sin(flapAngle)
    local rotatedX = baseX * math.cos(flapAngle)
    
    -- 左右の位置
    local sideOffset = isLeftWing and -(3 + rotatedX) or (3 + rotatedX)
    
    return Vector3.new(
        sideOffset,
        WingVerticalOffset + rotatedY,  -- 高さ + 羽ばたきによる上下
        0  -- 前後は固定
    ), isLeftWing
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
        
        if WingEnabled then
            tAccum = tAccum + dt
        else
            local currentRotationSpeed = TreeEnabled and TreeRotationSpeed or RotationSpeed
            tAccum = tAccum + dt * (currentRotationSpeed / 10)
        end
        
        -- ターゲットとなるルートパーツを決定
        local targetRoot = root
        
        if not WingEnabled then
            if TreeEnabled then
                if TreeFollowPlayerEnabled then
                    local targetHRP = getTargetHRP(TreeTargetPlayerName)
                    if targetHRP then targetRoot = targetHRP end
                end
            else
                if FollowPlayerEnabled then
                    local targetHRP = getTargetHRP(TargetPlayerName)
                    if targetHRP then targetRoot = targetHRP end
                end
            end
        end
        
        local rootVelocity = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.new()
        
        for i, rec in ipairs(list) do
            local part = rec.part
            if not part or not part.Parent then continue end
            
            -- 形状に応じた位置を計算
            local localPos, isLeftWing
            if WingEnabled then
                localPos, isLeftWing = getWingPosition(i, #list, tAccum)
            elseif TreeEnabled then
                localPos = getTreePosition(i, #list, tAccum * 0.5)
            else
                localPos = getShapePosition(i, #list, RingSize, tAccum * 0.5)
                localPos = localPos + Vector3.new(0, RingHeight, 0)
            end
            
            -- ワールド座標に変換（プレイヤーの向きを考慮するがY軸回転のみ）
            local targetCF
            if WingEnabled then
                -- Y軸回転のみを取り出す（水平方向の向きのみ）
                local _, yRot, _ = targetRoot.CFrame:ToEulerAnglesYXZ()
                targetCF = CFrame.new(targetRoot.Position) * CFrame.Angles(0, yRot, 0)
            else
                targetCF = targetRoot.CFrame
            end
            
            local targetPos = targetCF.Position + (targetCF - targetCF.Position):VectorToWorldSpace(localPos)
            
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
                if WingEnabled and isLeftWing then
                    -- 左翼：逆向き（プレイヤーから離れる方向）
                    local lookAtCFrame = CFrame.lookAt(targetPos, targetRoot.Position)
                    bg.CFrame = lookAtCFrame
                else
                    -- 右翼・通常オーラ・ツリー：前向き（プレイヤーの方を向く）
                    local lookAtCFrame = CFrame.lookAt(targetPos, targetRoot.Position) * CFrame.Angles(0, math.pi, 0)
                    bg.CFrame = lookAtCFrame
                end
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
-- UI要素 (通常オーラ)
-- ====================================================================

Tab:AddSection({ Name = "起動/停止" })

Tab:AddToggle({
    Name = "FireworkSparkler オーラ ON/OFF",
    Default = false,
    Callback = function(v)
        Enabled = v
        if v then
            TreeEnabled = false
            WingEnabled = false
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
    Max = 1000.0,
    Default = RotationSpeed,
    Increment = 10.0,
    Callback = function(v)
        RotationSpeed = v
    end
})

-- ====================================================================
-- UI要素 (クリスマスツリー)
-- ====================================================================

ChristmasTab:AddSection({ Name = "🎄 Christmas Tree 起動" })

ChristmasTab:AddToggle({
    Name = "🎄 Christmas Tree ON/OFF",
    Default = false,
    Callback = function(v)
        TreeEnabled = v
        if v then
            Enabled = false
            WingEnabled = false
            rescan()
            startLoop()
        else
            stopLoop()
        end
    end
})

ChristmasTab:AddSection({ Name = "Follow Player (ツリー)" })

ChristmasTab:AddDropdown({
    Name = "ターゲットプレイヤー選択",
    Default = "",
    Options = getPlayerNames(),
    Callback = function(v)
        TreeTargetPlayerName = v
    end
})

ChristmasTab:AddToggle({
    Name = "Follow Player",
    Default = false,
    Callback = function(v)
        TreeFollowPlayerEnabled = v
    end
})

ChristmasTab:AddSection({ Name = "ツリー設定" })

ChristmasTab:AddSlider({
    Name = "ツリーの高さ",
    Min = 5.0,
    Max = 200.0,
    Default = TreeHeight,
    Increment = 5.0,
    Callback = function(v)
        TreeHeight = v
    end
})

ChristmasTab:AddSlider({
    Name = "ツリーの幅 (リング最大半径)",
    Min = 3.0,
    Max = 100.0,
    Default = TreeRingSize,
    Increment = 1.0,
    Callback = function(v)
        TreeRingSize = v
    end
})

ChristmasTab:AddSlider({
    Name = "ツリーの層数",
    Min = 1,
    Max = 30,
    Default = TreeLayers,
    Increment = 1,
    Callback = function(v)
        TreeLayers = v
    end
})

ChristmasTab:AddSlider({
    Name = "オブジェクト数",
    Min = 10,
    Max = 30,
    Default = TreeObjectCount,
    Increment = 1,
    Callback = function(v)
        TreeObjectCount = v
        if TreeEnabled then
            rescan()
        end
    end
})

ChristmasTab:AddSlider({
    Name = "回転速度",
    Min = 0.0,
    Max = 1000.0,
    Default = TreeRotationSpeed,
    Increment = 10.0,
    Callback = function(v)
        TreeRotationSpeed = v
    end
})

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
            Enabled = false
            TreeEnabled = false
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
