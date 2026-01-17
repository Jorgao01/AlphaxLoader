local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Jorgao01/AlphaxUI/refs/heads/main/Library"))()

-- ==========================================
-- SERVIÇOS
-- ==========================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

local ScriptConfig = {
    AutoSteal = false,
    AutoStealRarity = false,
    SelectedRarity = "Common",
    AutoLockBase = false,
    EspTimer = false,
    EspPlayer = false,
    EspBrainrot = false,
    EspHighestBrainrot = false,
    BaseNoclip = false
}

-- Variáveis de Controle e Cache
local MyCachedBase = nil       
local IsStealing = false       
local LockDebounce = false     
local ESP_Cache = {}           
local Connections = {}         

-- ==========================================
-- FUNÇÕES AUXILIARES
-- ==========================================

-- Função de análise de valor melhorada
local function ParseValue(text)
    if not text or text == "" then return 0 end
    
    -- Deixa tudo minúsculo e remove o que não é numero ou sufixo
    local clean = text:lower():gsub("[^%d%.kmb]", "")
    
    -- Identifica o multiplicador
    local multiplier = 1
    if clean:find("k") then multiplier = 1000 end
    if clean:find("m") then multiplier = 1000000 end
    if clean:find("b") then multiplier = 1000000000 end
    
    -- Extrai apenas a parte numérica (ex: "1.5m" -> "1.5")
    local numStr = clean:match("[%d%.]+")
    local num = tonumber(numStr) or 0
    
    return num * multiplier
end

local function GetMyBaseModel()
    if MyCachedBase and MyCachedBase.Parent and MyCachedBase:FindFirstChild("PlotTeritory") then
        local frame = MyCachedBase.PlotTeritory:FindFirstChild("BaseUI") and MyCachedBase.PlotTeritory.BaseUI:FindFirstChild("Frame")
        if frame and frame.Visible then return MyCachedBase end
    end
    local BasesFolder = Workspace:FindFirstChild("Bases")
    if not BasesFolder then return nil end
    for _, base in pairs(BasesFolder:GetChildren()) do
        local territory = base:FindFirstChild("PlotTeritory")
        if territory then
            local frame = territory:FindFirstChild("BaseUI") and territory.BaseUI:FindFirstChild("Frame")
            if frame and frame.Visible then
                MyCachedBase = base 
                return base
            end
        end
    end
    return nil
end

local function GetBestBrainrotTarget()
    local BasesFolder = Workspace:FindFirstChild("Bases")
    if not BasesFolder then return nil end
    local myBase = GetMyBaseModel()
    local bestTarget = nil
    local highestEarnings = -1

    for _, base in pairs(BasesFolder:GetChildren()) do
        if base ~= myBase then
            local setBrainrots = base:FindFirstChild("SetBrainrots")
            if setBrainrots then
                for _, brainrot in pairs(setBrainrots:GetChildren()) do
                    if brainrot:FindFirstChild("Head") then
                        local uiMain = brainrot.Head:FindFirstChild("RunwayBGUINew") and brainrot.Head.RunwayBGUINew:FindFirstChild("Main")
                        if uiMain then
                            local rarityLabel = uiMain:FindFirstChild("Rarity")
                            local earningsLabel = uiMain:FindFirstChild("Earnings")
                            local unstealablebrairot = brainrot.HumanoidRootPart.RunwayBGUINew.Main.Unstealable or uiMain.Main.Unstealable

                        if not unstealablebrairot.Visible then
                            if rarityLabel and earningsLabel then
                                if rarityLabel.Text == ScriptConfig.SelectedRarity then
                                    local earningsVal = ParseValue(earningsLabel.Text)
                                    if earningsVal > highestEarnings then
                                        highestEarnings = earningsVal
                                        bestTarget = brainrot
                                    end
                                end
                            end
                            else
                            print("Unstealable Brainrot")
                        end
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- ==========================================
-- FUNÇÃO DE NOCLIP
-- ==========================================
local function SetNoclipState(enableNoclip)
    local bases = Workspace:FindFirstChild("Bases")
    if bases then
        for _, base in pairs(bases:GetChildren()) do
            -- Barreiras (Paredes)
            if base:FindFirstChild("Barriers") then
                for _, part in pairs(base.Barriers:GetChildren()) do
                    if part:IsA("BasePart") then 
                        part.CanCollide = not enableNoclip 
                    end
                end
            end
            
            -- PlotTeritory (Chão) - Remove apenas Query
            if base:FindFirstChild("PlotTeritory") and base.PlotTeritory:IsA("BasePart") then
                if enableNoclip then
                    base.PlotTeritory.CanQuery = false
                else
                    base.PlotTeritory.CanQuery = true
                end
            end
        end
    end
end

-- ==========================================
-- ESP BRAINROT (CORRIGIDO)
-- ==========================================
local function UpdateBrainrotESP()
    -- Se nenhum ESP estiver ligado, não faz nada
    if not ScriptConfig.EspBrainrot and not ScriptConfig.EspHighestBrainrot then return end
    
    local BasesFolder = Workspace:FindFirstChild("Bases")
    if not BasesFolder then return end
    
    local myBase = GetMyBaseModel()
    local globalHighestVal = -1
    local globalHighestModel = nil

    for _, base in pairs(BasesFolder:GetChildren()) do
        if base ~= myBase and base:FindFirstChild("SetBrainrots") then
            for _, rot in pairs(base.SetBrainrots:GetChildren()) do
                if rot:FindFirstChild("Head") then
                    local ui = rot.Head:FindFirstChild("RunwayBGUINew") and rot.Head.RunwayBGUINew:FindFirstChild("Main")
                    if ui and ui:FindFirstChild("Earnings") then
                        -- Aqui usamos a função ParseValue corrigida
                        local val = ParseValue(ui.Earnings.Text)
                        
                        -- Se este valor for maior que o recorde atual, ele vira o novo recorde
                        if val > globalHighestVal then
                            globalHighestVal = val
                            globalHighestModel = rot
                        end
                    end
                end
            end
        end
    end

    -- PASSO 2: Aplicar os visuais
    for _, base in pairs(BasesFolder:GetChildren()) do
        if base ~= myBase and base:FindFirstChild("SetBrainrots") then
            for _, rot in pairs(base.SetBrainrots:GetChildren()) do
                if rot:FindFirstChild("Head") then
                    local head = rot.Head
                    local ui = head:FindFirstChild("RunwayBGUINew") and head.RunwayBGUINew:FindFirstChild("Main")
                    
                    if ui and ui:FindFirstChild("Earnings") and ui:FindFirstChild("Rarity") then
                        local valText = ui.Earnings.Text
                        local rarityText = ui.Rarity.Text
                        local nameText = ui:FindFirstChild("BrainrotName") and ui.BrainrotName.Text or "Brainrot"
                        
                        -- Verifica se este modelo é o vencedor global
                        local isHighest = (rot == globalHighestModel)

                        -- === HIGHLIGHT (Apenas para o Highest) ===
                        local hl = rot:FindFirstChild("AlphaxHighestHighlight")
                        if ScriptConfig.EspHighestBrainrot then
                            if not hl then
                                hl = Instance.new("Highlight")
                                hl.Name = "AlphaxHighestHighlight"
                                hl.Parent = rot
                                hl.FillColor = Color3.fromRGB(0, 255, 0)
                                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                                hl.FillTransparency = 0.5
                            end
                            hl.Enabled = isHighest
                        else
                            if hl then hl:Destroy() end
                        end

                        -- === TEXT ESP (Billboard) ===
                        local bg = head:FindFirstChild("AlphaxBrainrotESP")
                        if not bg then
                            bg = Instance.new("BillboardGui")
                            bg.Name = "AlphaxBrainrotESP"
                            bg.Adornee = head
                            bg.AlwaysOnTop = true
                            bg.Parent = head
                            
                            local lbl = Instance.new("TextLabel", bg)
                            lbl.Name = "MainText"
                            lbl.BackgroundTransparency = 1
                            lbl.Size = UDim2.new(1,0,1,0)
                            lbl.Font = Enum.Font.GothamBold
                            lbl.TextStrokeTransparency = 0.5
                        end
                        
                        local lbl = bg:FindFirstChild("MainText")
                        
                        if isHighest and ScriptConfig.EspHighestBrainrot then
                            -- Visual do Highest
                            bg.Size = UDim2.new(0, 300, 0, 80)
                            bg.StudsOffset = Vector3.new(0, 5, 0)
                            
                            lbl.Text = string.format("HIGHEST ($$): %s\n%s (%s)", nameText, valText, rarityText)
                            lbl.TextColor3 = Color3.fromRGB(0, 255, 0) -- Verde Neon
                            lbl.TextSize = 24
                            bg.Enabled = true
                            
                        elseif ScriptConfig.EspBrainrot and not isHighest then
                            -- Visual dos Normais
                            bg.Size = UDim2.new(0, 200, 0, 60)
                            bg.StudsOffset = Vector3.new(0, 3, 0)
                            
                            lbl.Text = string.format("%s\n%s | %s", nameText, valText, rarityText)
                            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                            lbl.TextSize = 16
                            bg.Enabled = true
                            
                        else
                            -- Desativa se não se encaixar nas configs
                            bg.Enabled = false
                        end
                    end
                end
            end
        end
    end
end

local function ClearBrainrotESP()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v.Name == "AlphaxBrainrotESP" or v.Name == "AlphaxHighestHighlight" then v:Destroy() end
    end
end

-- ==========================================
-- LÓGICA AUTO STEAL (EVENTS)
-- ==========================================
local function OnAnimationPlayed(track)
    if not ScriptConfig.AutoSteal or IsStealing then return end
    if string.find(track.Animation.AnimationId, "77884528416489") then
        IsStealing = true
        task.wait(0.5) 
        local myBase = GetMyBaseModel()
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myBase and root and myBase:FindFirstChild("PlotTeritory") then
            root.CFrame = myBase.PlotTeritory.CFrame + Vector3.new(0, 3, 0)
        end
        task.wait(3) 
        IsStealing = false
    end
end

local function SetupCharacter(character)
    if Connections["Anim"] then Connections["Anim"]:Disconnect() end
    local humanoid = character:WaitForChild("Humanoid", 10)
    if humanoid then
        local animator = humanoid:WaitForChild("Animator", 5)
        if animator then
            Connections["Anim"] = animator.AnimationPlayed:Connect(OnAnimationPlayed)
        end
    end
end

-- ==========================================
-- ESP PLAYER
-- ==========================================
local function RemoveESP(player)
    if ESP_Cache[player] then
        if ESP_Cache[player].NameText then ESP_Cache[player].NameText:Remove() end
        if ESP_Cache[player].Highlight then ESP_Cache[player].Highlight:Destroy() end
        ESP_Cache[player] = nil
    end
end

local function UpdatePlayerESP()
    if not ScriptConfig.EspPlayer then return end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                if root and hum and hum.Health > 0 then
                    if not ESP_Cache[player] then
                        ESP_Cache[player] = {
                            NameText = Drawing.new("Text"),
                            Highlight = Instance.new("Highlight")
                        }
                        local txt = ESP_Cache[player].NameText
                        txt.Center = true; txt.Outline = true; txt.Color = Color3.new(1,1,1); txt.Font = 2; txt.Size = 13
                        local hl = ESP_Cache[player].Highlight
                        hl.Parent = char; hl.FillColor = Color3.fromRGB(255,0,0); hl.OutlineColor = Color3.new(1,1,1); hl.FillTransparency = 0.5
                    end
                    if ESP_Cache[player].Highlight.Parent ~= char then ESP_Cache[player].Highlight.Parent = char end
                    local pos, onScreen = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
                    local txt = ESP_Cache[player].NameText
                    if onScreen then
                        txt.Position = Vector2.new(pos.X, pos.Y)
                        txt.Text = player.Name .. "\n[" .. math.floor((Camera.CFrame.Position - root.Position).Magnitude) .. " m]"
                        txt.Visible = true
                    else
                        txt.Visible = false
                    end
                else
                    RemoveESP(player)
                end
            else
                RemoveESP(player)
            end
        end
    end
end
Players.PlayerRemoving:Connect(RemoveESP)

-- Timer ESP
local function UpdateTimerESP(targetPart, text)
    if not targetPart then return end
    local gui = targetPart:FindFirstChild("AlphaxTimerESP")
    if not gui then
        gui = Instance.new("BillboardGui", targetPart)
        gui.Name = "AlphaxTimerESP"; gui.Size = UDim2.new(0,100,0,50); gui.StudsOffset = Vector3.new(0,2,0); gui.AlwaysOnTop = true
        local lbl = Instance.new("TextLabel", gui)
        lbl.BackgroundTransparency = 1; lbl.Size = UDim2.new(1,0,1,0); lbl.TextColor3 = Color3.fromRGB(255,255,0); lbl.TextStrokeTransparency = 0; lbl.TextSize = 20; lbl.Font = Enum.Font.GothamBold
    end
    if gui:FindFirstChild("TextLabel") then gui.TextLabel.Text = tostring(text) end
end

local function ClearTimerESP()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v.Name == "AlphaxTimerESP" then v:Destroy() end
    end
end

-- ==========================================
-- LOOP 1: LENTO (ESP Update e Noclip)
-- ==========================================
task.spawn(function()
    while true do
        if ScriptConfig.BaseNoclip then SetNoclipState(true) end
        
        UpdateBrainrotESP()
        
        task.wait(0.5) 
    end
end)

-- ==========================================
-- LOOP 2: RÁPIDO (Auto Steal Rarity / Lock / Timer)
-- ==========================================
task.spawn(function()
    while true do
        task.wait(0.05) 
        
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local myBase = GetMyBaseModel()
        
        -- === AUTO STEAL RARITY ===
        if ScriptConfig.AutoStealRarity and not IsStealing and root then
            local targetBrainrot = GetBestBrainrotTarget()
            
            if targetBrainrot then
                local targetBase = targetBrainrot.Parent and targetBrainrot.Parent.Parent
                
                if targetBase and targetBase:FindFirstChild("Buttons") then
                    local ffBuy = targetBase.Buttons:FindFirstChild("ForceFieldBuy")
                    if ffBuy and ffBuy:FindFirstChild("Info") and ffBuy.Info:FindFirstChild("Timer") then
                        local timerText = ffBuy.Info.Timer.Text
                        local totalSeconds = ParseValue(timerText)
                        
                        if totalSeconds <= 1 and totalSeconds < 5000 then
                            IsStealing = true 
                            
                            task.wait(0.1)

                            local oldPos = root.CFrame

                            if targetBrainrot:FindFirstChild("Head") then 
                                root.CFrame = targetBrainrot.Head.CFrame
                            else 
                                root.CFrame = targetBrainrot:GetPivot() 
                            end
                            
                            task.wait(0.2) 
                            
                            local prompt = nil
                            for _, desc in pairs(targetBrainrot:GetDescendants()) do
                                if desc:IsA("ProximityPrompt") then prompt = desc break end
                            end
                            
                            if prompt then
                                fireproximityprompt(prompt)
                                if prompt.HoldDuration > 0 then 
                                    task.wait(prompt.HoldDuration + 0.2) 
                                else 
                                    task.wait(0.5) 
                                end
                            else
                                task.wait(0.5) 
                            end
                            
                            if myBase and myBase:FindFirstChild("PlotTeritory") then
                                root.CFrame = myBase.PlotTeritory.CFrame + Vector3.new(0, 3, 0)
                            else 
                                root.CFrame = oldPos 
                            end
                            
                            task.wait(1.5) 
                            IsStealing = false
                        end
                    end
                end
            end
        end

        -- === AUTO LOCK & ESP TIMER ===
        local bases = Workspace:FindFirstChild("Bases")
        if bases then
            for _, base in pairs(bases:GetChildren()) do
                local buttons = base:FindFirstChild("Buttons")
                if buttons then
                    local ffBuy = buttons:FindFirstChild("ForceFieldBuy")
                    if ffBuy then
                        local plate = ffBuy:FindFirstChild("Plate")
                        local timer = ffBuy:FindFirstChild("Info") and ffBuy.Info:FindFirstChild("Timer")
                        if plate and timer then
                            if ScriptConfig.EspTimer then UpdateTimerESP(plate, timer.Text) end
                            
                            if ScriptConfig.AutoLockBase and root and myBase and base == myBase then
                                local totalSeconds = ParseValue(timer.Text)
                                if totalSeconds <= 1 and totalSeconds < 5000 and not LockDebounce then
                                    LockDebounce = true
                                    task.wait(0.3) 
                                    local oldPos = root.CFrame
                                    root.CFrame = plate.CFrame + Vector3.new(0, 3, 0)
                                    task.wait(0.5)
                                    if root then root.CFrame = oldPos end
                                    task.delay(4, function() LockDebounce = false end)
                                end
                            end
                        end
                    end
                end
            end
        end
        if not ScriptConfig.EspTimer then ClearTimerESP() end
    end
end)

if LocalPlayer.Character then SetupCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(SetupCharacter)
Connections["Render"] = RunService.RenderStepped:Connect(UpdatePlayerESP)

local function FullUnload()
    ScriptConfig.AutoSteal = false
    ScriptConfig.AutoStealRarity = false 
    ScriptConfig.AutoLockBase = false
    ScriptConfig.EspTimer = false
    ScriptConfig.EspPlayer = false
    ScriptConfig.EspBrainrot = false
    ScriptConfig.EspHighestBrainrot = false
    SetNoclipState(false)
    ScriptConfig.BaseNoclip = false
    if Connections["Anim"] then Connections["Anim"]:Disconnect() end
    if Connections["Render"] then Connections["Render"]:Disconnect() end
    ClearTimerESP()
    ClearBrainrotESP()
    for player, _ in pairs(ESP_Cache) do RemoveESP(player) end
    Library:Unload()
end

-- ==========================================
-- UI CONFIGURATION
-- ==========================================
local MainWindow = Library:Window("Alphax Project", "Grow a Brainrot")
local MainTab = Library:Tab("Main")
local VisualsTab = Library:Tab("Visuals")
local SettingsTab = Library:Tab("Settings")

Library:Section(MainTab, "Steal Methods")
Library:Toggle(MainTab, "Auto Steal", ScriptConfig, "AutoSteal", function(state)
    ScriptConfig.AutoSteal = state
    IsStealing = false
end)

Library:Section(MainTab, "Steal by Rarity")
local Rarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"}
Library:Dropdown(MainTab, "Select Rarity", Rarities, ScriptConfig, "SelectedRarity", false)

Library:Toggle(MainTab, "Auto Steal Rarity", ScriptConfig, "AutoStealRarity", function(state)
    ScriptConfig.AutoStealRarity = state
    IsStealing = false
end)

Library:Section(MainTab, "Protection")
Library:Toggle(MainTab, "Auto Lock My Base", ScriptConfig, "AutoLockBase", function(state)
    ScriptConfig.AutoLockBase = state
end)
Library:Toggle(MainTab, "Base Noclip", ScriptConfig, "BaseNoclip", function(state)
    ScriptConfig.BaseNoclip = state
    if state then 
        SetNoclipState(true) 
    else 
        SetNoclipState(false) 
    end
end)

Library:Section(VisualsTab, "Brainrot ESP")
Library:Toggle(VisualsTab, "ESP Brainrots", ScriptConfig, "EspBrainrot", function(state)
    ScriptConfig.EspBrainrot = state
    if not state then ClearBrainrotESP() end
end)
Library:Toggle(VisualsTab, "ESP Highest Value", ScriptConfig, "EspHighestBrainrot", function(state)
    ScriptConfig.EspHighestBrainrot = state
    if not state then ClearBrainrotESP() end
end)

Library:Section(VisualsTab, "World ESP")
Library:Toggle(VisualsTab, "Timer ESP", ScriptConfig, "EspTimer", function(state)
    ScriptConfig.EspTimer = state
    if not state then ClearTimerESP() end
end)
Library:Toggle(VisualsTab, "Player ESP", ScriptConfig, "EspPlayer", function(state)
    ScriptConfig.EspPlayer = state
    if not state then for p, _ in pairs(ESP_Cache) do RemoveESP(p) end end
end)

Library:Section(SettingsTab, "Script")
Library:Button(SettingsTab, "Unload Script", FullUnload)