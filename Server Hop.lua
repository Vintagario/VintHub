local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local LocalPlayer = Players.LocalPlayer
local placeId = game.PlaceId

local function getJobId()
    return game.JobId
end

local COLORS = {
    bg = Color3.fromRGB(11, 13, 28),
    bgAlt = Color3.fromRGB(24, 18, 50),
    card = Color3.fromRGB(21, 24, 48),
    cardHover = Color3.fromRGB(29, 32, 66),
    accent = Color3.fromRGB(99, 102, 241),
    accentAlt = Color3.fromRGB(139, 92, 246),
    cyan = Color3.fromRGB(56, 189, 248),
    green = Color3.fromRGB(34, 197, 94),
    greenDark = Color3.fromRGB(16, 52, 38),
    red = Color3.fromRGB(239, 68, 68),
    redDark = Color3.fromRGB(62, 24, 30),
    text = Color3.fromRGB(235, 237, 250),
    subtext = Color3.fromRGB(140, 146, 180),
    stroke = Color3.fromRGB(44, 48, 90),
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

local function gradient(parent, c0, c1, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c0, c1)
    g.Rotation = rotation or 0
    g.Parent = parent
    return g
end

local function tween(obj, props, time, style, direction)
    TweenService:Create(
        obj,
        TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
        props
    ):Play()
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
ScreenGui.Name = "ServerHopGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = container

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 320, 0, 310)
Main.AnchorPoint = Vector2.new(1, 1)
Main.Position = UDim2.new(1, -20, 1, -80)
Main.BackgroundColor3 = Color3.new(1, 1, 1)
Main.Parent = ScreenGui
corner(Main, 16)
gradient(Main, COLORS.bg, COLORS.bgAlt, 135)

local MainStroke = stroke(Main, Color3.new(1, 1, 1), 1.5)
local StrokeGradient = Instance.new("UIGradient")
StrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLORS.accent),
    ColorSequenceKeypoint.new(0.5, COLORS.cyan),
    ColorSequenceKeypoint.new(1, COLORS.accentAlt),
})
StrokeGradient.Parent = MainStroke

local MainScale = Instance.new("UIScale")
MainScale.Scale = 0.88
MainScale.Parent = Main
tween(MainScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 56)
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

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

local LogoBadge = Instance.new("Frame")
LogoBadge.Size = UDim2.new(0, 36, 0, 36)
LogoBadge.Position = UDim2.new(0, 14, 0, 10)
LogoBadge.BackgroundColor3 = Color3.new(1, 1, 1)
LogoBadge.Parent = Header
corner(LogoBadge, 11)
local LogoGradient = gradient(LogoBadge, COLORS.accent, COLORS.accentAlt, 45)

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.BackgroundTransparency = 1
LogoText.Font = Enum.Font.GothamBlack
LogoText.TextSize = 14
LogoText.TextColor3 = Color3.new(1, 1, 1)
LogoText.Text = "SH"
LogoText.Parent = LogoBadge

local Title = Instance.new("TextLabel")
Title.RichText = true
Title.Text = 'SERVER <font color="#6366F1">HOP</font>'
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 17
Title.TextColor3 = COLORS.text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextYAlignment = Enum.TextYAlignment.Top
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 58, 0, 9)
Title.Size = UDim2.new(1, -112, 0, 22)
Title.Parent = Header

local SubLabel = Instance.new("TextButton")
SubLabel.Font = Enum.Font.GothamMedium
SubLabel.TextSize = 11
SubLabel.TextColor3 = COLORS.subtext
SubLabel.TextXAlignment = Enum.TextXAlignment.Left
SubLabel.TextYAlignment = Enum.TextYAlignment.Top
SubLabel.TextTruncate = Enum.TextTruncate.AtEnd
SubLabel.AutoButtonColor = false
SubLabel.BackgroundTransparency = 1
SubLabel.Position = UDim2.new(0, 58, 0, 31)
SubLabel.Size = UDim2.new(1, -112, 0, 16)
SubLabel.Text = "Place " .. tostring(placeId)
SubLabel.Parent = Header

SubLabel.MouseEnter:Connect(function() tween(SubLabel, { TextColor3 = COLORS.cyan }) end)
SubLabel.MouseLeave:Connect(function() tween(SubLabel, { TextColor3 = COLORS.subtext }) end)

local copyFlashing = false
SubLabel.MouseButton1Click:Connect(function()
    if modalCount > 0 or copyFlashing then return end

    local original = "Place " .. tostring(placeId)
    local currentJobId = getJobId()
    local message

    if currentJobId == "" then
        message = "No server ID available"
    elseif copyToClipboard(currentJobId) then
        message = "Copied server ID!"
    else
        message = "Clipboard not supported"
    end

    copyFlashing = true
    SubLabel.Text = message
    task.delay(1.2, function()
        SubLabel.Text = original
        copyFlashing = false
    end)
end)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -42, 0, 14)
MinBtn.BackgroundColor3 = COLORS.card
MinBtn.Text = "—"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.TextColor3 = COLORS.text
MinBtn.AutoButtonColor = false
MinBtn.Parent = Header
corner(MinBtn, 9)
local MinStroke = stroke(MinBtn, COLORS.stroke, 1)
MinBtn.MouseEnter:Connect(function()
    tween(MinBtn, { BackgroundColor3 = COLORS.cardHover })
    tween(MinStroke, { Color = COLORS.accent })
end)
MinBtn.MouseLeave:Connect(function()
    tween(MinBtn, { BackgroundColor3 = COLORS.card })
    tween(MinStroke, { Color = COLORS.stroke })
end)

local Body = Instance.new("ScrollingFrame")
Body.Name = "Body"
Body.Position = UDim2.new(0, 12, 0, 60)
Body.Size = UDim2.new(1, -24, 1, -112)
Body.BackgroundTransparency = 1
Body.BorderSizePixel = 0
Body.ScrollBarThickness = 3
Body.ScrollBarImageColor3 = COLORS.accent
Body.CanvasSize = UDim2.new(0, 0, 0, 0)
Body.AutomaticCanvasSize = Enum.AutomaticSize.Y
Body.Parent = Main

local BodyLayout = Instance.new("UIListLayout")
BodyLayout.Padding = UDim.new(0, 8)
BodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
BodyLayout.Parent = Body

local Footer = Instance.new("Frame")
Footer.Name = "Footer"
Footer.AnchorPoint = Vector2.new(0, 1)
Footer.Position = UDim2.new(0, 12, 1, -12)
Footer.Size = UDim2.new(1, -24, 0, 34)
Footer.BackgroundColor3 = COLORS.card
Footer.Parent = Main
corner(Footer, 11)
stroke(Footer, COLORS.stroke, 1)

local Halo = Instance.new("Frame")
Halo.AnchorPoint = Vector2.new(0.5, 0.5)
Halo.Position = UDim2.new(0, 18, 0.5, 0)
Halo.Size = UDim2.new(0, 8, 0, 8)
Halo.BackgroundColor3 = COLORS.green
Halo.BackgroundTransparency = 0.4
Halo.Parent = Footer
corner(Halo, 11)

local Dot = Instance.new("Frame")
Dot.AnchorPoint = Vector2.new(0.5, 0.5)
Dot.Position = UDim2.new(0, 18, 0.5, 0)
Dot.Size = UDim2.new(0, 8, 0, 8)
Dot.BackgroundColor3 = COLORS.green
Dot.Parent = Footer
corner(Dot, 4)

local FooterLabel = Instance.new("TextLabel")
FooterLabel.Text = "Anti-AFK Guard"
FooterLabel.Font = Enum.Font.GothamMedium
FooterLabel.TextSize = 12
FooterLabel.TextColor3 = COLORS.text
FooterLabel.TextXAlignment = Enum.TextXAlignment.Left
FooterLabel.BackgroundTransparency = 1
FooterLabel.Position = UDim2.new(0, 34, 0, 0)
FooterLabel.Size = UDim2.new(1, -120, 1, 0)
FooterLabel.Parent = Footer

local Pill = Instance.new("Frame")
Pill.AnchorPoint = Vector2.new(1, 0.5)
Pill.Position = UDim2.new(1, -10, 0.5, 0)
Pill.Size = UDim2.new(0, 70, 0, 20)
Pill.BackgroundColor3 = COLORS.greenDark
Pill.Parent = Footer
corner(Pill, 10)
local PillStroke = stroke(Pill, COLORS.green, 1)

local PillLabel = Instance.new("TextLabel")
PillLabel.Size = UDim2.new(1, 0, 1, 0)
PillLabel.BackgroundTransparency = 1
PillLabel.Font = Enum.Font.GothamBold
PillLabel.TextSize = 10
PillLabel.TextColor3 = COLORS.green
PillLabel.Text = "ACTIVE"
PillLabel.Parent = Pill

local function startHaloPulse()
    Halo.Size = UDim2.new(0, 8, 0, 8)
    Halo.BackgroundTransparency = 0.4
    local info = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, 0)
    TweenService:Create(Halo, info, {
        Size = UDim2.new(0, 24, 0, 24),
        BackgroundTransparency = 1,
    }):Play()
end

local function setPillState(active)
    if active then
        Pill.BackgroundColor3 = COLORS.greenDark
        PillStroke.Color = COLORS.green
        PillLabel.TextColor3 = COLORS.green
        PillLabel.Text = "ACTIVE"
        Dot.BackgroundColor3 = COLORS.green
        Halo.BackgroundColor3 = COLORS.green
        startHaloPulse()
    else
        Pill.BackgroundColor3 = COLORS.redDark
        PillStroke.Color = COLORS.red
        PillLabel.TextColor3 = COLORS.red
        PillLabel.Text = "OFFLINE"
        Dot.BackgroundColor3 = COLORS.red
        Halo.BackgroundTransparency = 1
    end
end

local pingToken = 0
local function flashPing()
    pingToken = pingToken + 1
    local myToken = pingToken
    PillLabel.Text = "PINGED"
    task.delay(1.5, function()
        if pingToken == myToken then
            PillLabel.Text = "ACTIVE"
        end
    end)
end

local function startAntiAfk(onPing)
    local ok, VirtualUser = pcall(function()
        return game:GetService("VirtualUser")
    end)

    if not ok or not VirtualUser then
        warn("ServerHop: VirtualUser unavailable, anti-AFK disabled")
        return false
    end

    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        if onPing then
            onPing()
        end
    end)

    return true
end

setPillState(startAntiAfk(flashPing))

RunService.Heartbeat:Connect(function()
    local t = os.clock()
    StrokeGradient.Rotation = (t * 45) % 360
    LogoGradient.Rotation = (t * 90) % 360
end)

local function gradientButton(parent, text, size, position, anchor, zIndex)
    local z = zIndex or 1

    local wrap = Instance.new("Frame")
    wrap.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
    wrap.Position = position
    wrap.Size = size
    wrap.BackgroundColor3 = Color3.new(1, 1, 1)
    wrap.ZIndex = z
    wrap.Parent = parent
    corner(wrap, 9)
    local grad = gradient(wrap, COLORS.accent, COLORS.accentAlt, 0)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.AutoButtonColor = false
    btn.ZIndex = z + 1
    btn.Parent = wrap

    local hoverSize = UDim2.new(size.X.Scale, size.X.Offset + 6, size.Y.Scale, size.Y.Offset + 2)
    local pressSize = UDim2.new(size.X.Scale, size.X.Offset - 4, size.Y.Scale, size.Y.Offset - 2)

    btn.MouseEnter:Connect(function()
        tween(wrap, { Size = hoverSize }, 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        tween(grad, { Rotation = 40 }, 0.3)
    end)
    btn.MouseLeave:Connect(function()
        tween(wrap, { Size = size }, 0.14)
        tween(grad, { Rotation = 0 }, 0.3)
    end)
    btn.MouseButton1Down:Connect(function()
        tween(wrap, { Size = pressSize }, 0.08)
    end)
    btn.MouseButton1Up:Connect(function()
        tween(wrap, { Size = hoverSize }, 0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)

    return wrap, btn
end

local function buildActionRow(labelText, descText, buttonText, order, onClick, descClickable, iconText)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 62)
    Row.BackgroundColor3 = COLORS.card
    Row.LayoutOrder = order
    Row.Parent = Body
    corner(Row, 12)
    local RowStroke = stroke(Row, COLORS.stroke, 1)

    Row.MouseEnter:Connect(function()
        tween(Row, { BackgroundColor3 = COLORS.cardHover })
        tween(RowStroke, { Color = COLORS.accent })
    end)
    Row.MouseLeave:Connect(function()
        tween(Row, { BackgroundColor3 = COLORS.card })
        tween(RowStroke, { Color = COLORS.stroke })
    end)

    local Badge = Instance.new("Frame")
    Badge.Size = UDim2.new(0, 36, 0, 36)
    Badge.Position = UDim2.new(0, 10, 0.5, -18)
    Badge.BackgroundColor3 = Color3.new(1, 1, 1)
    Badge.Parent = Row
    corner(Badge, 18)
    gradient(Badge, COLORS.accent, COLORS.accentAlt, 45)

    local BadgeText = Instance.new("TextLabel")
    BadgeText.Size = UDim2.new(1, 0, 1, 0)
    BadgeText.BackgroundTransparency = 1
    BadgeText.Font = Enum.Font.GothamBlack
    BadgeText.TextSize = (iconText and #iconText > 1) and 12 or 15
    BadgeText.TextColor3 = Color3.new(1, 1, 1)
    BadgeText.Text = iconText or ""
    BadgeText.Parent = Badge

    local NameLbl = Instance.new("TextLabel")
    NameLbl.Text = labelText
    NameLbl.Font = Enum.Font.GothamBold
    NameLbl.TextSize = 14
    NameLbl.TextColor3 = COLORS.text
    NameLbl.TextXAlignment = Enum.TextXAlignment.Left
    NameLbl.BackgroundTransparency = 1
    NameLbl.Position = UDim2.new(0, 56, 0, 8)
    NameLbl.Size = UDim2.new(1, -142, 0, 18)
    NameLbl.Parent = Row

    local DescLbl = Instance.new(descClickable and "TextButton" or "TextLabel")
    DescLbl.Text = descText
    DescLbl.Font = Enum.Font.Gotham
    DescLbl.TextSize = 11
    DescLbl.TextColor3 = COLORS.subtext
    DescLbl.TextXAlignment = Enum.TextXAlignment.Left
    DescLbl.TextYAlignment = Enum.TextYAlignment.Top
    DescLbl.TextWrapped = true
    DescLbl.TextTruncate = Enum.TextTruncate.AtEnd
    DescLbl.BackgroundTransparency = 1
    DescLbl.Position = UDim2.new(0, 56, 0, 27)
    DescLbl.Size = UDim2.new(1, -142, 0, 28)
    if descClickable then
        DescLbl.AutoButtonColor = false
    end
    DescLbl.Parent = Row

    local wrap, ActionBtn = gradientButton(
        Row,
        buttonText,
        UDim2.new(0, 68, 0, 28),
        UDim2.new(1, -46, 0.5, 0)
    )

    ActionBtn.MouseButton1Click:Connect(function()
        if modalCount > 0 then return end
        onClick(ActionBtn, DescLbl)
    end)

    return Row, ActionBtn, DescLbl
end

local function prompt(titleText, defaultText, placeholderText, onConfirm)
    local Overlay = Instance.new("Frame")
    Overlay.Size = UDim2.new(1, 0, 1, 0)
    Overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    Overlay.BackgroundTransparency = 1
    Overlay.ZIndex = 10
    Overlay.Active = true
    Overlay.Parent = Main
    corner(Overlay, 16)
    modalCount = modalCount + 1
    tween(Overlay, { BackgroundTransparency = 0.4 }, 0.2)

    local Box = Instance.new("Frame")
    Box.AnchorPoint = Vector2.new(0.5, 0.5)
    Box.Size = UDim2.new(0, 260, 0, 136)
    Box.Position = UDim2.new(0.5, 0, 0.5, 0)
    Box.BackgroundColor3 = COLORS.card
    Box.ZIndex = 11
    Box.Parent = Overlay
    corner(Box, 14)
    local BoxStroke = stroke(Box, Color3.new(1, 1, 1), 1.5)
    local BoxGradient = Instance.new("UIGradient")
    BoxGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.accent),
        ColorSequenceKeypoint.new(1, COLORS.accentAlt),
    })
    BoxGradient.Parent = BoxStroke

    local BoxScale = Instance.new("UIScale")
    BoxScale.Scale = 0.85
    BoxScale.Parent = Box
    tween(BoxScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    local Lbl = Instance.new("TextLabel")
    Lbl.Text = titleText
    Lbl.Font = Enum.Font.GothamBold
    Lbl.TextSize = 14
    Lbl.TextColor3 = COLORS.text
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.BackgroundTransparency = 1
    Lbl.Position = UDim2.new(0, 14, 0, 10)
    Lbl.Size = UDim2.new(1, -28, 0, 20)
    Lbl.ZIndex = 11
    Lbl.Parent = Box

    local Input = Instance.new("TextBox")
    Input.Text = defaultText or ""
    Input.PlaceholderText = placeholderText or "Enter value..."
    Input.PlaceholderColor3 = COLORS.subtext
    Input.Font = Enum.Font.Gotham
    Input.TextSize = 13
    Input.TextColor3 = COLORS.text
    Input.BackgroundColor3 = COLORS.bg
    Input.ClearTextOnFocus = false
    Input.Position = UDim2.new(0, 14, 0, 38)
    Input.Size = UDim2.new(1, -28, 0, 36)
    Input.ZIndex = 11
    Input.Parent = Box
    corner(Input, 9)
    local InputStroke = stroke(Input, COLORS.stroke, 1)

    Input.Focused:Connect(function() tween(InputStroke, { Color = COLORS.accent }) end)
    Input.FocusLost:Connect(function() tween(InputStroke, { Color = COLORS.stroke }) end)

    local function finish()
        local text = Input.Text
        Overlay:Destroy()
        modalCount = modalCount - 1
        onConfirm(text)
    end

    local confirmWrap, Confirm = gradientButton(
        Box,
        "Confirm",
        UDim2.new(1, -28, 0, 30),
        UDim2.new(0.5, 0, 1, -28),
        Vector2.new(0.5, 0.5),
        11
    )

    Confirm.MouseButton1Click:Connect(finish)
    Input.FocusLost:Connect(function(enterPressed)
        if enterPressed then finish() end
    end)
end

local function fetchPublicServers()
    local success, serverList = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/" .. placeId ..
                "/servers/Public?sortOrder=Asc&limit=100")
        )
    end)

    if success and serverList and serverList.data then
        return serverList.data
    end

    warn("ServerHop: request failed -> " .. tostring(serverList))
    return nil
end

local function findLowestPopServer()
    local servers = fetchPublicServers()
    if not servers then return nil end

    local currentJobId = getJobId()
    local candidates = {}
    for _, server in ipairs(servers) do
        if server.playing and server.playing < server.maxPlayers
            and server.id ~= currentJobId then
            table.insert(candidates, server)
        end
    end

    if #candidates == 0 then return nil end

    table.sort(candidates, function(a, b)
        if a.playing ~= b.playing then
            return a.playing < b.playing
        end
        local pa = tonumber(a.ping) or math.huge
        local pb = tonumber(b.ping) or math.huge
        return pa < pb
    end)

    local pick = candidates[1]
    return pick.id, pick.playing, tonumber(pick.ping)
end

local function findRandomServer()
    local servers = fetchPublicServers()
    if not servers then return nil end

    local currentJobId = getJobId()
    local candidates = {}
    for _, server in ipairs(servers) do
        if server.playing and server.playing < server.maxPlayers
            and server.id ~= currentJobId then
            table.insert(candidates, server)
        end
    end

    if #candidates == 0 then return nil end

    local pick = candidates[math.random(1, #candidates)]
    return pick.id, pick.playing, tonumber(pick.ping)
end

local function attemptTeleport(targetId, desc, btn, resetFlag, fallbackBtnText)
    local timedOut = false

    task.delay(10, function()
        if desc.Text:find("^Joining") or desc.Text:find("^Rejoining") then
            timedOut = true
            desc.Text = "Timed out (server may be gone) - tap to retry"
            btn.Text = fallbackBtnText
            resetFlag()
        end
    end)

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, targetId, LocalPlayer)
    end)

    if not timedOut and not ok then
        warn("ServerHop: teleport failed -> " .. tostring(err))
        desc.Text = "Teleport failed: " .. tostring(err)
        btn.Text = fallbackBtnText
        resetFlag()
    end
end

local hopping = false
local lastHopId = nil

local hopRow, hopBtn, hopDesc = buildActionRow(
    "Least Players",
    "Lowest players, best ping as tiebreaker",
    "Hop",
    1,
    function(btn, desc)
        if hopping then return end
        hopping = true
        btn.Text = "..."
        desc.Text = "Searching..."

        local serverId, playerCount, ping = findLowestPopServer()

        if serverId then
            lastHopId = serverId
            local pingText = ping and (", " .. math.floor(ping) .. "ms") or ""
            desc.Text = "Joining (" .. playerCount .. " players" .. pingText .. ") - tap to copy ID"
            attemptTeleport(serverId, desc, btn, function() hopping = false end, "Hop")
        else
            lastHopId = nil
            desc.Text = "No server found"
            btn.Text = "Hop"
            hopping = false
        end
    end,
    true,
    "L"
)

hopDesc.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end
    if not lastHopId then return end
    local original = hopDesc.Text
    if copyToClipboard(lastHopId) then
        hopDesc.Text = "Copied: " .. lastHopId
        task.delay(1.2, function()
            if hopDesc.Text == "Copied: " .. lastHopId then
                hopDesc.Text = original
            end
        end)
    end
end)

local randomHopping = false
local lastRandomId = nil

local randomRow, randomBtn, randomDesc = buildActionRow(
    "Random Server",
    "Join any random non-full server",
    "Hop",
    2,
    function(btn, desc)
        if randomHopping then return end
        randomHopping = true
        btn.Text = "..."
        desc.Text = "Searching..."

        local serverId, playerCount = findRandomServer()

        if serverId then
            lastRandomId = serverId
            desc.Text = "Joining (" .. playerCount .. " players) - tap to copy ID"
            attemptTeleport(serverId, desc, btn, function() randomHopping = false end, "Hop")
        else
            lastRandomId = nil
            desc.Text = "No server found"
            btn.Text = "Hop"
            randomHopping = false
        end
    end,
    true,
    "R"
)

randomDesc.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end
    if not lastRandomId then return end
    local original = randomDesc.Text
    if copyToClipboard(lastRandomId) then
        randomDesc.Text = "Copied: " .. lastRandomId
        task.delay(1.2, function()
            if randomDesc.Text == "Copied: " .. lastRandomId then
                randomDesc.Text = original
            end
        end)
    end
end)

local rejoining = false

local rejoinRow, rejoinBtn, rejoinDesc = buildActionRow(
    "Same Server",
    "Rejoin this exact server",
    "Rejoin",
    3,
    function(btn, desc)
        if rejoining then return end
        rejoining = true
        btn.Text = "..."
        desc.Text = "Rejoining..."

        local currentJobId = getJobId()

        if currentJobId == "" then
            local ok, err = pcall(function()
                TeleportService:Teleport(placeId, LocalPlayer)
            end)
            if not ok then
                desc.Text = "Teleport failed: " .. tostring(err)
                btn.Text = "Retry"
                rejoining = false
            end
        else
            attemptTeleport(currentJobId, desc, btn, function() rejoining = false end, "Retry")
        end
    end,
    false,
    "S"
)

TeleportService.TeleportInitFailed:Connect(function(_, teleportResult, errorMessage)
    warn("Teleport init failed:", teleportResult, errorMessage)
    rejoinDesc.Text = "Failed (" .. tostring(teleportResult) .. ") - tap to retry"
    rejoinBtn.Text = "Retry"
    rejoining = false
end)

local joiningById = false

local joinByIdRow, joinByIdBtn, joinByIdDesc = buildActionRow(
    "Join by ID",
    "Enter a Job ID to join directly",
    "Join",
    4,
    function(btn, desc)
        if joiningById then return end
        prompt("Join Server by ID", "", "Job ID (GUID)", function(text)
            local targetId = text and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
            if targetId == "" then
                desc.Text = "Enter a Job ID to join directly"
                return
            end
            joiningById = true
            btn.Text = "..."
            desc.Text = "Joining..."
            attemptTeleport(targetId, desc, btn, function() joiningById = false end, "Join")
        end)
    end,
    false,
    "ID"
)

local EXPANDED_SIZE = Main.Size
local MINIMIZED_SIZE = UDim2.new(0, 250, 0, 56)
local minimized = false

local function toggleMinimize()
    if modalCount > 0 then return end
    minimized = not minimized

    if minimized then
        MinBtn.Text = "+"
        Body.Visible = false
        Footer.Visible = false
        tween(Main, { Size = MINIMIZED_SIZE }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    else
        MinBtn.Text = "—"
        tween(Main, { Size = EXPANDED_SIZE }, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        task.delay(0.2, function()
            Body.Visible = true
            Footer.Visible = true
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
