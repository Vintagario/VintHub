local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local ALLOWED_PLACE_ID = 124216119978534

if ALLOWED_PLACE_ID ~= 0 and game.PlaceId ~= ALLOWED_PLACE_ID then
    warn("RideAPet: this script is locked to PlaceId " .. ALLOWED_PLACE_ID
        .. ", but you're in " .. game.PlaceId .. ". Aborting.")
    return
end

local LUCK_LOOKUP = {
    ["Cherub Egg"] = "1T",
    ["Blackhole Egg"] = "100B",
    ["Galaxy Egg"] = "1.5B",
    ["Aurora Egg"] = "300M",
    ["Soul Egg"] = "7M",
    ["Sinister Egg"] = "3M",
    ["Flaming Egg"] = "1M",
    ["Dominus Egg"] = "700K",
    ["Asteroid Egg"] = "500K",
    ["Skull Egg"] = "250K",
    ["Crystal Egg"] = "150K",
    ["Diamond Egg"] = "90K",
    ["Golden Egg"] = "30K",
    ["Glass Egg"] = "10K",
    ["Ice Egg"] = "3K",
    ["Slime Egg"] = "1K",
    ["Flower Egg"] = "750",
    ["Mushroom Egg"] = "500",
    ["Leaf Egg"] = "200",
    ["Stone Egg"] = "100",
    ["Easter Egg"] = "50",
    ["Cracked Egg"] = "30",
    ["Brown Egg"] = "5",
    ["White Egg"] = "1",
}

local function getLuck(eggName)
    return LUCK_LOOKUP[eggName] or "Unknown"
end

local RARITY_NAME_OVERRIDES = {
    ["White Egg"] = "Common",
    ["Brown Egg"] = "Common",
}
local COMMON_COLOR = Color3.fromRGB(190, 190, 190)

local UTILITY_CLASS_NAMES = {
    UIStroke = true,
    UIAspectRatioConstraint = true,
    UIListLayout = true,
    UICorner = true,
    UIPadding = true,
    UIGridLayout = true,
    UITableLayout = true,
    UIScale = true,
    UIPageLayout = true,
    UISizeConstraint = true,
    UITextSizeConstraint = true,
    UIFlexItem = true,
}

local EXCLUDED_CARD_NAMES = {
    Count = true,
    Amount = true,
    Luck = true,
    LuckDisplay = true,
}

local function isIndexUtilityChild(child)
    if UTILITY_CLASS_NAMES[child.ClassName] then return true end
    if child.ClassName == "ViewportFrame" then return true end
    if child.ClassName == "ImageLabel" then return true end
    if EXCLUDED_CARD_NAMES[child.Name] then return true end
    return false
end

local KNOWN_RARITY_KEYWORDS = {
    "common", "uncommon", "rare", "epic", "legendary", "mythic", "mythical",
    "secret", "divine", "celestial", "ethereal", "ancient", "godly", "exotic",
    "exclusive", "limited", "special", "unique", "vip",
}

local function looksLikeRarityName(name)
    local lower = string.lower(name)
    for _, keyword in ipairs(KNOWN_RARITY_KEYWORDS) do
        if string.find(lower, keyword, 1, true) then
            return true
        end
    end
    return false
end

local function getEggIndexCard(eggName)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    return playerGui
        and playerGui:FindFirstChild("Main")
        and playerGui.Main:FindFirstChild("Index")
        and playerGui.Main.Index:FindFirstChild("Holders")
        and playerGui.Main.Index.Holders:FindFirstChild("EggsHolder")
        and playerGui.Main.Index.Holders.EggsHolder:FindFirstChild(eggName)
end

local function extractColor(inst)
    local ok1, bg = pcall(function() return inst.BackgroundColor3 end)
    if ok1 and typeof(bg) == "Color3" then return bg end

    local ok2, val = pcall(function() return inst.Value end)
    if ok2 and typeof(val) == "Color3" then return val end

    local ok3, seq = pcall(function() return inst.Color end)
    if ok3 and typeof(seq) == "ColorSequence" then
        return seq.Keypoints[1].Value
    end

    return nil
end

local function getRarityInfo(eggName)
    if RARITY_NAME_OVERRIDES[eggName] then
        return RARITY_NAME_OVERRIDES[eggName], COMMON_COLOR
    end

    local card = getEggIndexCard(eggName)
    if not card then
        warn("RideAPet: couldn't find index card for " .. eggName .. " (PlayerGui.Main.Index.Holders.EggsHolder)")
        return "Unknown", nil
    end

    local candidates = {}
    for _, child in ipairs(card:GetChildren()) do
        if not isIndexUtilityChild(child) then
            table.insert(candidates, child)
        end
    end

    if #candidates == 0 then
        warn("RideAPet: no rarity node found under the index card for " .. eggName)
        return "Unknown", nil
    end

    local chosen = candidates[1]
    for _, c in ipairs(candidates) do
        if looksLikeRarityName(c.Name) then
            chosen = c
            break
        end
    end

    if not looksLikeRarityName(chosen.Name) then
        warn("RideAPet: rarity guess for " .. eggName .. " ('" .. chosen.Name
            .. "') doesn't match a known rarity word - might be another stray label")
    end

    return chosen.Name, extractColor(chosen)
end

local function color3ToInt(c)
    if not c then return nil end
    return math.floor(c.R * 255 + 0.5) * 65536
        + math.floor(c.G * 255 + 0.5) * 256
        + math.floor(c.B * 255 + 0.5)
end

local function getEggIconAssetId(eggName)
    local card = getEggIndexCard(eggName)
    if not card then return nil end
    local imageLabel = card:FindFirstChildOfClass("ImageLabel")
    if not imageLabel then return nil end
    return string.match(imageLabel.Image, "(%d+)")
end

local EGG_NAMES = {
    "Asteroid Egg", "Aurora Egg", "Blackhole Egg", "Brown Egg", "Cherub Egg",
    "Cracked Egg", "Crystal Egg", "Diamond Egg", "Dominus Egg", "Easter Egg",
    "Flaming Egg", "Flower Egg", "Galaxy Egg", "Glass Egg", "Golden Egg",
    "Ice Egg", "Leaf Egg", "Mushroom Egg", "Sinister Egg", "Skull Egg",
    "Slime Egg", "Soul Egg", "Stone Egg", "White Egg",
}

local COLORS = {
    bg = Color3.fromRGB(24, 24, 27),
    card = Color3.fromRGB(32, 32, 36),
    cardHover = Color3.fromRGB(40, 40, 45),
    accent = Color3.fromRGB(59, 130, 246),
    accentHover = Color3.fromRGB(80, 148, 255),
    text = Color3.fromRGB(235, 235, 240),
    subtext = Color3.fromRGB(150, 150, 158),
    danger = Color3.fromRGB(220, 90, 90),
    dangerHover = Color3.fromRGB(235, 110, 110),
    stroke = Color3.fromRGB(48, 48, 54),
}

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or COLORS.stroke
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end

local function tween(obj, props, time)
    TweenService:Create(obj, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad), props):Play()
end

local modalCount = 0

local FOLDER = "RideAPet"
local FILE = FOLDER .. "/state_" .. game.PlaceId .. ".json"

local function ensureFolder()
    if not isfolder(FOLDER) then
        makefolder(FOLDER)
    end
end

local State = {
    selected = {},
    farmEnabled = false,
    webhookUrl = "",
    notifyEnabled = false,
    notifyEggs = {},
}

local function saveState()
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, State)
    if ok then
        ensureFolder()
        pcall(writefile, FILE, encoded)
    else
        warn("RideAPet: failed to encode state for saving")
    end
end

local function loadState()
    ensureFolder()
    if isfile(FILE) then
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(FILE))
        end)
        if ok and type(decoded) == "table" then
            if type(decoded.selected) == "table" then State.selected = decoded.selected end
            if type(decoded.farmEnabled) == "boolean" then State.farmEnabled = decoded.farmEnabled end
            if type(decoded.webhookUrl) == "string" then State.webhookUrl = decoded.webhookUrl end
            if type(decoded.notifyEnabled) == "boolean" then State.notifyEnabled = decoded.notifyEnabled end
            if type(decoded.notifyEggs) == "table" then State.notifyEggs = decoded.notifyEggs end
        end
    end
end

loadState()

local selectedEggs = State.selected
local notifyEggs = State.notifyEggs

local function countTable(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local container = (gethui and gethui()) or game.CoreGui

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RideAPetGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = container

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 300)
Main.AnchorPoint = Vector2.new(0.5, 0)
Main.Position = UDim2.new(0.5, -220, 0, 20)
Main.BackgroundColor3 = COLORS.bg
Main.Parent = ScreenGui
corner(Main, 14)
stroke(Main, COLORS.stroke, 1)

do
    local dragging, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 50)
Header.BackgroundTransparency = 1
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Text = "Ride a Pet"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = COLORS.text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextYAlignment = Enum.TextYAlignment.Top
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 18, 0, 6)
Title.Size = UDim2.new(1, -80, 0, 20)
Title.Parent = Header

local SubLabel = Instance.new("TextLabel")
SubLabel.Font = Enum.Font.Gotham
SubLabel.TextSize = 12
SubLabel.TextColor3 = COLORS.subtext
SubLabel.TextXAlignment = Enum.TextXAlignment.Left
SubLabel.TextYAlignment = Enum.TextYAlignment.Top
SubLabel.TextTruncate = Enum.TextTruncate.AtEnd
SubLabel.BackgroundTransparency = 1
SubLabel.Position = UDim2.new(0, 18, 0, 28)
SubLabel.Size = UDim2.new(1, -80, 0, 16)
SubLabel.Text = "Target: None"
SubLabel.Parent = Header

local function iconButton(text, xOffsetFromRight)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 32, 0, 32)
    b.Position = UDim2.new(1, xOffsetFromRight, 0, 9)
    b.BackgroundColor3 = COLORS.card
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.TextColor3 = COLORS.text
    b.AutoButtonColor = false
    b.Parent = Header
    corner(b, 8)
    b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = COLORS.cardHover }) end)
    b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = COLORS.card }) end)
    return b
end

local MinBtn = iconButton("—", -44)
MinBtn.TextSize = 16

local Body = Instance.new("ScrollingFrame")
Body.Name = "Body"
Body.Position = UDim2.new(0, 10, 0, 54)
Body.Size = UDim2.new(1, -20, 1, -64)
Body.BackgroundTransparency = 1
Body.BorderSizePixel = 0
Body.ScrollBarThickness = 4
Body.ScrollBarImageColor3 = COLORS.accent
Body.CanvasSize = UDim2.new(0, 0, 0, 0)
Body.AutomaticCanvasSize = Enum.AutomaticSize.Y
Body.Parent = Main

local BodyLayout = Instance.new("UIListLayout")
BodyLayout.Padding = UDim.new(0, 8)
BodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
BodyLayout.Parent = Body

local function buildActionRow(labelText, descText, buttonText, order)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 62)
    Row.BackgroundColor3 = COLORS.card
    Row.LayoutOrder = order
    Row.Parent = Body
    corner(Row, 10)

    local NameLbl = Instance.new("TextLabel")
    NameLbl.Text = labelText
    NameLbl.Font = Enum.Font.GothamBold
    NameLbl.TextSize = 14
    NameLbl.TextColor3 = COLORS.text
    NameLbl.TextXAlignment = Enum.TextXAlignment.Left
    NameLbl.BackgroundTransparency = 1
    NameLbl.Position = UDim2.new(0, 12, 0, 8)
    NameLbl.Size = UDim2.new(1, -110, 0, 18)
    NameLbl.Parent = Row

    local DescLbl = Instance.new("TextLabel")
    DescLbl.Text = descText
    DescLbl.Font = Enum.Font.Gotham
    DescLbl.TextSize = 12
    DescLbl.TextColor3 = COLORS.subtext
    DescLbl.TextXAlignment = Enum.TextXAlignment.Left
    DescLbl.TextTruncate = Enum.TextTruncate.AtEnd
    DescLbl.BackgroundTransparency = 1
    DescLbl.Position = UDim2.new(0, 12, 0, 28)
    DescLbl.Size = UDim2.new(1, -110, 0, 22)
    DescLbl.Parent = Row

    local ActionBtn = Instance.new("TextButton")
    ActionBtn.Text = buttonText
    ActionBtn.Font = Enum.Font.GothamBold
    ActionBtn.TextSize = 13
    ActionBtn.TextColor3 = Color3.new(1, 1, 1)
    ActionBtn.BackgroundColor3 = COLORS.accent
    ActionBtn.Position = UDim2.new(1, -92, 0.5, -15)
    ActionBtn.Size = UDim2.new(0, 80, 0, 30)
    ActionBtn.AutoButtonColor = false
    ActionBtn.Parent = Row
    corner(ActionBtn, 8)
    ActionBtn.MouseEnter:Connect(function() tween(ActionBtn, { BackgroundColor3 = COLORS.accentHover }) end)
    ActionBtn.MouseLeave:Connect(function() tween(ActionBtn, { BackgroundColor3 = COLORS.accent }) end)

    return Row, ActionBtn, DescLbl
end

local selectRow, selectBtn, selectDesc = buildActionRow("Egg Type", "Tap to choose eggs", "Select", 1)
local teleportRow, teleportBtn, teleportDesc = buildActionRow("Teleport", "Pick at least one egg type", "Go", 2)
local baseRow, baseBtn, baseDesc = buildActionRow("Base", "Saving location...", "Go", 3)
local farmRow, farmBtn, farmDesc = buildActionRow("Auto Farm", "Pick an egg type first", "OFF", 4)
local webhookRow, webhookBtn, webhookDesc = buildActionRow("Webhook", "Not set", "Set", 5)
local notifyRow, notifyBtn, notifyDesc = buildActionRow("Notify On", "All grabbed eggs", "Select", 6)
local notifyToggleRow, notifyToggleBtn, notifyToggleDesc = buildActionRow("Notifications", "Set a webhook first", "OFF", 7)

local function prompt(titleText, defaultText, placeholderText, onConfirm)
    local Overlay = Instance.new("Frame")
    Overlay.Size = UDim2.new(1, 0, 1, 0)
    Overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    Overlay.BackgroundTransparency = 0.4
    Overlay.ZIndex = 10
    Overlay.Active = true
    Overlay.Parent = Main
    modalCount = modalCount + 1

    local Box = Instance.new("Frame")
    Box.Size = UDim2.new(0, 250, 0, 130)
    Box.Position = UDim2.new(0.5, -125, 0.5, -65)
    Box.BackgroundColor3 = COLORS.card
    Box.ZIndex = 11
    Box.Parent = Overlay
    corner(Box, 10)
    stroke(Box, COLORS.stroke, 1)

    local Lbl = Instance.new("TextLabel")
    Lbl.Text = titleText
    Lbl.Font = Enum.Font.GothamBold
    Lbl.TextSize = 14
    Lbl.TextColor3 = COLORS.text
    Lbl.BackgroundTransparency = 1
    Lbl.Position = UDim2.new(0, 12, 0, 10)
    Lbl.Size = UDim2.new(1, -24, 0, 20)
    Lbl.ZIndex = 11
    Lbl.Parent = Box

    local Input = Instance.new("TextBox")
    Input.Text = defaultText or ""
    Input.PlaceholderText = placeholderText or "Enter text..."
    Input.Font = Enum.Font.Gotham
    Input.TextSize = 13
    Input.TextColor3 = COLORS.text
    Input.BackgroundColor3 = COLORS.bg
    Input.ClearTextOnFocus = false
    Input.Position = UDim2.new(0, 12, 0, 38)
    Input.Size = UDim2.new(1, -24, 0, 34)
    Input.ZIndex = 11
    Input.Parent = Box
    corner(Input, 6)

    local Confirm = Instance.new("TextButton")
    Confirm.Text = "Confirm"
    Confirm.Font = Enum.Font.GothamBold
    Confirm.TextSize = 13
    Confirm.TextColor3 = Color3.new(1, 1, 1)
    Confirm.BackgroundColor3 = COLORS.accent
    Confirm.Position = UDim2.new(0, 12, 1, -38)
    Confirm.Size = UDim2.new(1, -24, 0, 28)
    Confirm.ZIndex = 11
    Confirm.AutoButtonColor = false
    Confirm.Parent = Box
    corner(Confirm, 6)
    Confirm.MouseEnter:Connect(function() tween(Confirm, { BackgroundColor3 = COLORS.accentHover }) end)
    Confirm.MouseLeave:Connect(function() tween(Confirm, { BackgroundColor3 = COLORS.accent }) end)

    local function finish()
        local text = Input.Text
        Overlay:Destroy()
        modalCount = modalCount - 1
        onConfirm(text)
    end

    Confirm.MouseButton1Click:Connect(finish)
    Input.FocusLost:Connect(function(enterPressed)
        if enterPressed then finish() end
    end)
end

local function openMultiSelectPicker(panelTitle, targetTable, onClose)
    local Overlay = Instance.new("Frame")
    Overlay.Size = UDim2.new(1, 0, 1, 0)
    Overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    Overlay.BackgroundTransparency = 0.4
    Overlay.ZIndex = 10
    Overlay.Active = true
    Overlay.Parent = Main
    modalCount = modalCount + 1

    local Panel = Instance.new("Frame")
    Panel.Size = UDim2.new(0, 240, 0, 280)
    Panel.Position = UDim2.new(0.5, -120, 0.5, -140)
    Panel.BackgroundColor3 = COLORS.card
    Panel.ZIndex = 11
    Panel.Parent = Overlay
    corner(Panel, 10)
    stroke(Panel, COLORS.stroke, 1)

    local Lbl = Instance.new("TextLabel")
    Lbl.Text = panelTitle
    Lbl.Font = Enum.Font.GothamBold
    Lbl.TextSize = 13
    Lbl.TextColor3 = COLORS.text
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.BackgroundTransparency = 1
    Lbl.Position = UDim2.new(0, 12, 0, 10)
    Lbl.Size = UDim2.new(1, -40, 0, 20)
    Lbl.ZIndex = 11
    Lbl.Parent = Panel

    local EggList = Instance.new("ScrollingFrame")
    EggList.Position = UDim2.new(0, 12, 0, 38)
    EggList.Size = UDim2.new(1, -24, 1, -48)
    EggList.BackgroundTransparency = 1
    EggList.BorderSizePixel = 0
    EggList.ScrollBarThickness = 4
    EggList.ScrollBarImageColor3 = COLORS.accent
    EggList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    EggList.CanvasSize = UDim2.new(0, 0, 0, 0)
    EggList.ZIndex = 11
    EggList.Parent = Panel

    local EggListLayout = Instance.new("UIListLayout")
    EggListLayout.Padding = UDim.new(0, 6)
    EggListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    EggListLayout.Parent = EggList

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Text = "X"
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 14
    CloseBtn.TextColor3 = COLORS.subtext
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Position = UDim2.new(1, -30, 0, 6)
    CloseBtn.Size = UDim2.new(0, 24, 0, 24)
    CloseBtn.ZIndex = 12
    CloseBtn.Parent = Panel
    CloseBtn.MouseButton1Click:Connect(function()
        Overlay:Destroy()
        modalCount = modalCount - 1
        onClose()
    end)

    for i, eggName in ipairs(EGG_NAMES) do
        local Row = Instance.new("TextButton")
        Row.Text = ""
        Row.Size = UDim2.new(1, 0, 0, 32)
        Row.BackgroundColor3 = targetTable[eggName] and COLORS.accent or COLORS.bg
        Row.AutoButtonColor = false
        Row.LayoutOrder = i
        Row.ZIndex = 11
        Row.Parent = EggList
        corner(Row, 7)

        local NameLbl = Instance.new("TextLabel")
        NameLbl.Text = eggName
        NameLbl.Font = Enum.Font.Gotham
        NameLbl.TextSize = 13
        NameLbl.TextColor3 = COLORS.text
        NameLbl.TextXAlignment = Enum.TextXAlignment.Left
        NameLbl.BackgroundTransparency = 1
        NameLbl.Position = UDim2.new(0, 10, 0, 0)
        NameLbl.Size = UDim2.new(1, -20, 1, 0)
        NameLbl.ZIndex = 11
        NameLbl.Parent = Row

        Row.MouseButton1Click:Connect(function()
            if targetTable[eggName] then
                targetTable[eggName] = nil
            else
                targetTable[eggName] = true
            end
            Row.BackgroundColor3 = targetTable[eggName] and COLORS.accent or COLORS.bg
            saveState()
        end)
    end
end

local function refreshSelectedLabels()
    local n = countTable(selectedEggs)
    if n == 0 then
        selectDesc.Text = "Tap to choose eggs"
        SubLabel.Text = "Target: None"
    elseif n == 1 then
        local onlyName
        for name in pairs(selectedEggs) do onlyName = name end
        selectDesc.Text = onlyName
        SubLabel.Text = "Target: " .. onlyName
    else
        selectDesc.Text = n .. " eggs selected"
        SubLabel.Text = "Target: " .. n .. " eggs"
    end
end
refreshSelectedLabels()

local function refreshNotifyLabels()
    local n = countTable(notifyEggs)
    if n == 0 then
        notifyDesc.Text = "All grabbed eggs"
    elseif n == 1 then
        local onlyName
        for name in pairs(notifyEggs) do onlyName = name end
        notifyDesc.Text = onlyName
    else
        notifyDesc.Text = n .. " eggs selected"
    end
end
refreshNotifyLabels()

selectBtn.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end
    openMultiSelectPicker("Choose Eggs (tap to toggle)", selectedEggs, refreshSelectedLabels)
end)

notifyBtn.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end
    openMultiSelectPicker("Notify On (tap to toggle)", notifyEggs, refreshNotifyLabels)
end)

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getEggPosition(inst)
    if inst:IsA("Model") then
        return inst:GetPivot().Position
    elseif inst:IsA("BasePart") then
        return inst.Position
    end
    return nil
end

local function findNearestAmongSelected(selectedSet)
    local hrp = getHRP()
    if not hrp then
        warn("RideAPet: no HumanoidRootPart found")
        return nil
    end

    local root = workspace:FindFirstChild("RenderedEggs", true)
    if not root then
        warn("RideAPet: could not find a 'RenderedEggs' instance anywhere under workspace")
        return nil
    end

    local nearestInst, nearestDist, nearestName
    local checked = 0
    for _, child in ipairs(root:GetChildren()) do
        if selectedSet[child.Name] then
            checked = checked + 1
            local pos = getEggPosition(child)
            if pos then
                local dist = (pos - hrp.Position).Magnitude
                if not nearestDist or dist < nearestDist then
                    nearestDist = dist
                    nearestInst = child
                    nearestName = child.Name
                end
            end
        end
    end

    warn(string.format("RideAPet: matched %d candidate(s) across selected egg types", checked))
    return nearestInst, nearestDist, nearestName
end

teleportBtn.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end
    if countTable(selectedEggs) == 0 then
        teleportDesc.Text = "Pick at least one egg type"
        return
    end
    local hrp = getHRP()
    if not hrp then
        teleportDesc.Text = "Character not found"
        return
    end
    local nearest, dist, name = findNearestAmongSelected(selectedEggs)
    if nearest then
        local pos = getEggPosition(nearest)
        hrp.CFrame = CFrame.new(pos) + Vector3.new(0, 3, 0)
        hrp.Velocity = Vector3.new()
        hrp.RotVelocity = Vector3.new()
        teleportDesc.Text = string.format("At %s (%.0f studs)", name, dist)
    else
        teleportDesc.Text = "No matching eggs found (check console)"
    end
end)

local baseCFrame = nil

task.spawn(function()
    task.wait(2)
    local hrp = getHRP()
    if hrp then
        baseCFrame = hrp.CFrame
        baseDesc.Text = "Base saved"
    else
        baseDesc.Text = "Could not save base (no character)"
    end
end)

baseBtn.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end
    if not baseCFrame then
        baseDesc.Text = "Base not saved yet"
        return
    end
    local hrp = getHRP()
    if not hrp then
        baseDesc.Text = "Character not found"
        return
    end
    hrp.CFrame = baseCFrame
    hrp.Velocity = Vector3.new()
    hrp.RotVelocity = Vector3.new()
    baseDesc.Text = "Teleported to base"
end)

local function findRequestFunction()
    if typeof(request) == "function" then return request end
    if typeof(http_request) == "function" then return http_request end
    if syn and typeof(syn.request) == "function" then return syn.request end
    return nil
end

local iconUrlCache = {}

local function getIconUrl(eggName)
    if iconUrlCache[eggName] then return iconUrlCache[eggName] end

    local assetId = getEggIconAssetId(eggName)
    if not assetId then
        warn("RideAPet: couldn't find an icon ImageLabel for " .. eggName)
        return nil
    end

    local url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. assetId
        .. "&size=150x150&format=Png"

    local reqFunc = findRequestFunction()
    if not reqFunc then
        warn("RideAPet: no HTTP request function found - can't fetch icon thumbnail")
        return nil
    end

    local ok, res = pcall(reqFunc, { Url = url, Method = "GET" })
    if not ok or not res or not res.Body then
        warn("RideAPet: thumbnail request failed for " .. eggName)
        return nil
    end

    local decodeOk, decoded = pcall(function()
        return HttpService:JSONDecode(res.Body)
    end)
    if decodeOk and decoded and decoded.data and decoded.data[1] and decoded.data[1].imageUrl then
        iconUrlCache[eggName] = decoded.data[1].imageUrl
        return iconUrlCache[eggName]
    end

    warn("RideAPet: couldn't parse thumbnail response for " .. eggName)
    return nil
end

local function sendWebhookPayload(payload)
    if State.webhookUrl == "" then return false end
    local reqFunc = findRequestFunction()
    if not reqFunc then
        warn("RideAPet: no HTTP request function found (request/http_request/syn.request) - can't send webhook")
        return false
    end
    local ok, body = pcall(HttpService.JSONEncode, HttpService, payload)
    if not ok then
        warn("RideAPet: failed to encode webhook payload")
        return false
    end
    local reqOk, res = pcall(reqFunc, {
        Url = State.webhookUrl,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
    if not reqOk then
        warn("RideAPet: webhook request failed -> " .. tostring(res))
        return false
    end
    return true
end

local function getGrabbedEggData(eggName, timeout)
    local start = tick()
    repeat
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local inst = backpack and backpack:FindFirstChild(eggName)
        if not inst then
            local char = LocalPlayer.Character
            inst = char and char:FindFirstChild(eggName)
        end
        if inst then
            local data = inst:FindFirstChild("Data")
            if data then
                local weight = data:GetAttribute("Weight")
                if weight == nil then
                    local weightVal = data:FindFirstChild("Weight")
                    if weightVal then weight = weightVal.Value end
                end
                if weight ~= nil then
                    local mutation = data:GetAttribute("Mutation")
                    return weight, mutation
                end
            end
        end
        task.wait(0.2)
    until tick() - start > (timeout or 2)

    warn("RideAPet: gave up waiting for " .. eggName .. "'s Data to appear in Backpack")
    return nil, nil
end

local function shouldNotifyFor(eggName)
    if not State.notifyEnabled or State.webhookUrl == "" then return false end
    if countTable(notifyEggs) == 0 then return true end
    return notifyEggs[eggName] == true
end

local function formatDateTime()
    local d = os.date("*t")
    local hour12 = d.hour % 12
    if hour12 == 0 then hour12 = 12 end
    local ampm = d.hour < 12 and "AM" or "PM"
    return string.format("%d/%d/%d %d:%02d %s", d.month, d.day, d.year, hour12, d.min, ampm)
end

local function sendEggGrabbedNotification(eggName)
    local weight, mutation = getGrabbedEggData(eggName)
    local iconUrl = getIconUrl(eggName)
    local rarityName, rarityColor = getRarityInfo(eggName)
    local embedColor = color3ToInt(rarityColor) or 3900150

    local lines = {}

    table.insert(lines, "**User:** ||" .. LocalPlayer.Name .. "||")
    table.insert(lines, "")
    table.insert(lines, "**Egg:** " .. eggName)
    table.insert(lines, "**Luck:** " .. getLuck(eggName))
    table.insert(lines, "**Rarity:** " .. rarityName)
    if weight then
        table.insert(lines, "**Weight:** " .. tostring(weight) .. " Kg")
    end
    if mutation and type(mutation) == "string" and mutation:match("%S") then
        table.insert(lines, "**Mutation:** " .. mutation)
    end

    local payload = {
        username = "Ride a Pet",
        embeds = {
            {
                title = "🥚 Egg Grabbed",
                color = embedColor,
                description = table.concat(lines, "\n"),
                thumbnail = iconUrl and { url = iconUrl } or nil,
                footer = { text = formatDateTime() },
            },
        },
    }

    task.spawn(sendWebhookPayload, payload)
end

webhookBtn.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end
    prompt("Discord Webhook URL", State.webhookUrl, "https://discord.com/api/webhooks/...", function(text)
        State.webhookUrl = text or ""
        saveState()
        if State.webhookUrl == "" then
            webhookDesc.Text = "Not set"
        else
            webhookDesc.Text = "Saved"
        end
    end)
end)

local function setNotifyToggleVisuals(on)
    if on then
        notifyToggleBtn.Text = "ON"
        notifyToggleBtn.BackgroundColor3 = COLORS.danger
        notifyToggleDesc.Text = "Notifications active"
    else
        notifyToggleBtn.Text = "OFF"
        notifyToggleBtn.BackgroundColor3 = COLORS.accent
        notifyToggleDesc.Text = State.webhookUrl == "" and "Set a webhook first" or "Stopped"
    end
end
setNotifyToggleVisuals(State.notifyEnabled)
if State.webhookUrl ~= "" then webhookDesc.Text = "Saved" end

notifyToggleBtn.MouseEnter:Connect(function()
    tween(notifyToggleBtn, { BackgroundColor3 = State.notifyEnabled and COLORS.dangerHover or COLORS.accentHover })
end)
notifyToggleBtn.MouseLeave:Connect(function()
    tween(notifyToggleBtn, { BackgroundColor3 = State.notifyEnabled and COLORS.danger or COLORS.accent })
end)

notifyToggleBtn.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end
    if not State.notifyEnabled and State.webhookUrl == "" then
        notifyToggleDesc.Text = "Set a webhook first"
        return
    end
    State.notifyEnabled = not State.notifyEnabled
    saveState()
    setNotifyToggleVisuals(State.notifyEnabled)
end)

local function waitForPrompt(eggModel, timeout)
    local start = tick()
    local prompt2 = eggModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    while not prompt2 and eggModel.Parent and tick() - start < timeout do
        task.wait(0.1)
        prompt2 = eggModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    end
    return prompt2
end

local function attemptGrab(eggModel, maxAttempts)
    task.wait(0.75)

    for attempt = 1, maxAttempts do
        if not eggModel.Parent then
            return true
        end

        local promptInst = waitForPrompt(eggModel, 1.5)
        if promptInst then
            if typeof(fireproximityprompt) == "function" then
                pcall(fireproximityprompt, promptInst)
            else
                warn("RideAPet: your executor doesn't expose fireproximityprompt")
                return false
            end
        else
            warn("RideAPet: no ProximityPrompt found on " .. eggModel:GetFullName() .. " (attempt " .. attempt .. ")")
        end

        task.wait(0.5)

        if not eggModel.Parent then
            return true
        end
    end

    return not eggModel.Parent
end

local farmEnabled = State.farmEnabled

local function setFarmState(on)
    farmEnabled = on
    State.farmEnabled = on
    saveState()
    if on then
        farmBtn.Text = "ON"
        farmBtn.BackgroundColor3 = COLORS.danger
        farmDesc.Text = countTable(selectedEggs) > 0 and "Searching..." or "Pick an egg type first"
    else
        farmBtn.Text = "OFF"
        farmBtn.BackgroundColor3 = COLORS.accent
        farmDesc.Text = "Stopped"
    end
end

do
    if farmEnabled then
        farmBtn.Text = "ON"
        farmBtn.BackgroundColor3 = COLORS.danger
        farmDesc.Text = countTable(selectedEggs) > 0 and "Searching..." or "Pick an egg type first"
    else
        farmBtn.Text = "OFF"
        farmBtn.BackgroundColor3 = COLORS.accent
        farmDesc.Text = countTable(selectedEggs) > 0 and "Stopped" or "Pick an egg type first"
    end
end

farmBtn.MouseEnter:Connect(function()
    tween(farmBtn, { BackgroundColor3 = farmEnabled and COLORS.dangerHover or COLORS.accentHover })
end)
farmBtn.MouseLeave:Connect(function()
    tween(farmBtn, { BackgroundColor3 = farmEnabled and COLORS.danger or COLORS.accent })
end)

farmBtn.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end
    if not farmEnabled and countTable(selectedEggs) == 0 then
        farmDesc.Text = "Pick an egg type first"
        return
    end
    setFarmState(not farmEnabled)
end)

task.spawn(function()
    while true do
        task.wait(1)
        if not baseCFrame then
            if farmEnabled then
                farmDesc.Text = "Waiting for base to save..."
            end
        elseif farmEnabled and countTable(selectedEggs) > 0 and modalCount == 0 then
            local nearest, dist, name = findNearestAmongSelected(selectedEggs)
            if nearest then
                local hrp = getHRP()
                if hrp then
                    local pos = getEggPosition(nearest)
                    hrp.CFrame = CFrame.new(pos) + Vector3.new(0, 3, 0)
                    hrp.Velocity = Vector3.new()
                    hrp.RotVelocity = Vector3.new()
                    farmDesc.Text = "Grabbing " .. name .. "..."

                    local grabbed = attemptGrab(nearest, 6)

                    local hrp2 = getHRP()
                    if hrp2 then
                        hrp2.CFrame = baseCFrame
                        hrp2.Velocity = Vector3.new()
                        hrp2.RotVelocity = Vector3.new()
                    end

                    if grabbed then
                        farmDesc.Text = "Grabbed " .. name
                        if shouldNotifyFor(name) then
                            sendEggGrabbedNotification(name)
                        end
                    else
                        farmDesc.Text = "Couldn't grab " .. name .. " (check console)"
                    end
                end
            else
                farmDesc.Text = "No matching eggs found"
            end
        end
    end
end)

local EXPANDED_SIZE = Main.Size
local MINIMIZED_SIZE = UDim2.new(0, 220, 0, 50)
local minimized = false

local function toggleMinimize()
    if modalCount > 0 then return end
    minimized = not minimized

    if minimized then
        MinBtn.Text = "▢"
        Body.Visible = false
        SubLabel.Visible = false
        tween(Main, { Size = MINIMIZED_SIZE }, 0.18)
    else
        MinBtn.Text = "—"
        tween(Main, { Size = EXPANDED_SIZE }, 0.18)
        task.delay(0.18, function()
            Body.Visible = true
            SubLabel.Visible = true
        end)
    end
end

MinBtn.MouseButton1Click:Connect(toggleMinimize)

do
    local lastClick = 0
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local now = tick()
            if now - lastClick < 0.35 then
                toggleMinimize()
            end
            lastClick = now
        end
    end)
end
