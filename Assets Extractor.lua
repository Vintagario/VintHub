local TweenService = game:GetService("TweenService")

local COLORS = {
    bg = Color3.fromRGB(24, 24, 27),
    card = Color3.fromRGB(32, 32, 36),
    cardHover = Color3.fromRGB(40, 40, 45),
    accent = Color3.fromRGB(59, 130, 246),
    accentHover = Color3.fromRGB(80, 148, 255),
    text = Color3.fromRGB(235, 235, 240),
    subtext = Color3.fromRGB(150, 150, 158),
    danger = Color3.fromRGB(220, 90, 90),
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

local function copyToClipboard(text)
    if typeof(setclipboard) == "function" then
        pcall(setclipboard, text)
        return true
    end
    return false
end

local modalCount = 0

local container = (gethui and gethui()) or game.CoreGui

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AssetExtractorGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = container

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 320, 0, 300)
Main.AnchorPoint = Vector2.new(1, 1)
Main.Position = UDim2.new(1, -20, 1, -20)
Main.BackgroundColor3 = COLORS.bg
Main.Parent = ScreenGui
corner(Main, 14)
stroke(Main, COLORS.stroke, 1)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 50)
Header.BackgroundTransparency = 1
Header.Parent = Main

do
    local dragging, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    Header.InputBegan:Connect(function(input)
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

    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

local Title = Instance.new("TextLabel")
Title.Text = "Asset Extractor"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = COLORS.text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextYAlignment = Enum.TextYAlignment.Top
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 18, 0, 6)
Title.Size = UDim2.new(1, -30, 0, 20)
Title.Parent = Header

local TargetLbl = Instance.new("TextLabel")
TargetLbl.Font = Enum.Font.Gotham
TargetLbl.TextSize = 12
TargetLbl.TextColor3 = COLORS.subtext
TargetLbl.TextXAlignment = Enum.TextXAlignment.Left
TargetLbl.TextTruncate = Enum.TextTruncate.AtEnd
TargetLbl.BackgroundTransparency = 1
TargetLbl.Position = UDim2.new(0, 18, 0, 28)
TargetLbl.Size = UDim2.new(1, -30, 0, 16)
TargetLbl.Text = "Target: game"
TargetLbl.Parent = Header

local Body = Instance.new("Frame")
Body.Position = UDim2.new(0, 10, 0, 54)
Body.Size = UDim2.new(1, -20, 1, -64)
Body.BackgroundTransparency = 1
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
    Box.Size = UDim2.new(0, 260, 0, 130)
    Box.Position = UDim2.new(0.5, -130, 0.5, -65)
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
    Input.PlaceholderText = placeholderText or "Enter value..."
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

local targetRow, targetBtn, targetDesc = buildActionRow("Target", "game", "Set", 1)
local scanRow, scanBtn, scanDesc = buildActionRow("Scan", "Not scanned yet", "Scan", 2)
local copyRow, copyBtn, copyDesc = buildActionRow("Results", "0 assets found", "Copy", 3)

local function resolvePath(path)
    if path == "" or path == "game" then return game end
    local parts = string.split(path, ".")
    local current = game
    for i = 2, #parts do
        local part = parts[i]
        local nextInst = current:FindFirstChild(part)
        if not nextInst then
            return nil, "Couldn't find '" .. part .. "' under " .. current:GetFullName()
        end
        current = nextInst
    end
    return current
end

local currentTarget = game

targetBtn.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end
    prompt("Scan Target", "game", "e.g. game.Workspace or game.Players.LocalPlayer.PlayerGui", function(text)
        local path = text and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
        if path == "" then path = "game" end
        local resolved, err = resolvePath(path)
        if resolved then
            currentTarget = resolved
            targetDesc.Text = currentTarget:GetFullName()
        else
            targetDesc.Text = err or "Invalid path"
        end
    end)
end)

local PROPERTY_CHECKS = {
    { function(i) return i:IsA("ImageLabel") or i:IsA("ImageButton") end,
      { "Image", "HoverImage", "PressedImage", "SelectedImage" } },
    { function(i) return i:IsA("Decal") or i:IsA("Texture") end, { "Texture" } },
    { function(i) return i:IsA("MeshPart") end, { "MeshId", "TextureID" } },
    { function(i) return i:IsA("SpecialMesh") end, { "MeshId", "TextureId" } },
    { function(i) return i:IsA("Sound") end, { "SoundId" } },
    { function(i) return i:IsA("Animation") end, { "AnimationId" } },
    { function(i) return i:IsA("ParticleEmitter") end, { "Texture" } },
    { function(i) return i:IsA("Beam") or i:IsA("Trail") end, { "Texture" } },
    { function(i) return i:IsA("SurfaceAppearance") end,
      { "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap" } },
    { function(i) return i:IsA("Clothing") end, { "ClothingAssetId" } },
}

local function looksLikeAsset(value)
    return type(value) == "string"
        and (value:find("^rbxassetid://") or value:find("^rbxasset://"))
end

local lastResults = {}

local function scan()
    local results = {}
    local instances = currentTarget:GetDescendants()
    table.insert(instances, currentTarget)

    for _, inst in ipairs(instances) do
        for _, check in ipairs(PROPERTY_CHECKS) do
            local matchFn, props = check[1], check[2]
            local ok, matches = pcall(matchFn, inst)
            if ok and matches then
                for _, propName in ipairs(props) do
                    local ok2, value = pcall(function() return inst[propName] end)
                    if ok2 and looksLikeAsset(value) then
                        table.insert(results, {
                            path = inst:GetFullName(),
                            property = propName,
                            assetId = value,
                        })
                    end
                end
            end
        end

        local ok3, attrs = pcall(function() return inst:GetAttributes() end)
        if ok3 then
            for attrName, attrValue in pairs(attrs) do
                if looksLikeAsset(attrValue) then
                    table.insert(results, {
                        path = inst:GetFullName(),
                        property = "[Attribute] " .. attrName,
                        assetId = attrValue,
                    })
                end
            end
        end
    end

    return results
end

scanBtn.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end
    scanBtn.Text = "..."
    scanDesc.Text = "Scanning..."
    task.spawn(function()
        local ok, results = pcall(scan)
        if ok then
            lastResults = results
            scanDesc.Text = #results .. " assets found in this scan"
            copyDesc.Text = #results .. " assets found"
        else
            scanDesc.Text = "Scan failed: " .. tostring(results)
        end
        scanBtn.Text = "Scan"
    end)
end)

copyBtn.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end
    if #lastResults == 0 then
        copyDesc.Text = "Nothing to copy - scan first"
        return
    end
    local lines = {}
    for _, r in ipairs(lastResults) do
        table.insert(lines, r.property .. " @ " .. r.path .. ": " .. r.assetId)
    end
    local text = table.concat(lines, "\n")
    if copyToClipboard(text) then
        copyDesc.Text = "Copied " .. #lastResults .. " entries to clipboard"
    else
        copyDesc.Text = "No setclipboard support in this executor"
    end
end)
