--[[
    Server Hop (optimized rewrite)

    Changes vs. original:
      * No per-frame Heartbeat loop (gradients spin via looping tweens)
      * HTTP runs off the UI thread, uses `request` when available, handles 429s,
        has a search cooldown and pagination
      * "Random Server" now samples up to 3 pages in a random sort order
      * One shared action state: only one teleport at a time, errors go to the right row
      * Duplicate-execution guard + full cleanup of connections on destroy
      * Fixed minimize race, drag is clamped to the screen, drag listener only runs while dragging
      * Join-by-ID validates the GUID and can be cancelled
      * Private server aware rejoin (see notes in the Rejoin row)
      * Optional auto-reload after teleport (queue_on_teleport)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

----------------------------------------------------------------------
-- Config
----------------------------------------------------------------------
local SCRIPT_URL = "https://raw.githubusercontent.com/Vintagario/VintHub/refs/heads/main/Server%20Hop.lua"
local AUTO_RELOAD = true        -- re-run this script after each teleport (needs queue_on_teleport)
local SEARCH_COOLDOWN = 2       -- seconds between server list requests (avoids 429s)
local TELEPORT_TIMEOUT = 25     -- seconds before the UI unlocks if nothing happened
local RANDOM_PAGES = 3          -- pages of 100 servers sampled for "Random Server"

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------
local LocalPlayer = Players.LocalPlayer
local placeId = game.PlaceId
local IS_PRIVATE = game.PrivateServerId ~= ""

local okContainer, container = pcall(function()
    return (gethui and gethui()) or game:GetService("CoreGui")
end)
if not okContainer or not container then
    container = LocalPlayer:WaitForChild("PlayerGui")
end

-- Duplicate-execution guard (old instance cleans up its own connections on Destroying)
local old = container:FindFirstChild("ServerHopGui")
if old then
    old:Destroy()
end

local cleanups = {}
local function track(conn)
    table.insert(cleanups, function()
        conn:Disconnect()
    end)
    return conn
end

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

----------------------------------------------------------------------
-- UI helpers
----------------------------------------------------------------------
local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function circle(parent)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0.5, 0)
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
    local t = TweenService:Create(
        obj,
        TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

local function spin(obj, seconds)
    TweenService:Create(
        obj,
        TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
        { Rotation = 360 }
    ):Play()
end

local function copyToClipboard(text)
    local fn = setclipboard or toclipboard
    if typeof(fn) == "function" then
        return pcall(fn, text)
    end
    return false
end

-- Temporarily shows `text` on a label, then restores `restoreText` (unless something else wrote to it)
local flashTokens = setmetatable({}, { __mode = "k" })
local function flash(label, text, duration, restoreText)
    local t = (flashTokens[label] or 0) + 1
    flashTokens[label] = t
    label.Text = text
    task.delay(duration, function()
        if flashTokens[label] == t and label.Parent then
            label.Text = restoreText
        end
    end)
end

local modalCount = 0

----------------------------------------------------------------------
-- Main window
----------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ServerHopGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = container

ScreenGui.Destroying:Connect(function()
    for _, fn in ipairs(cleanups) do
        pcall(fn)
    end
    table.clear(cleanups)
end)

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
spin(StrokeGradient, 8)

local MainScale = Instance.new("UIScale")
MainScale.Scale = 0.88
MainScale.Parent = Main
tween(MainScale, { Scale = 1 }, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 56)
Header.BackgroundTransparency = 1
Header.Parent = Main

-- Dragging (listener exists only while a drag is in progress, clamped to the screen)
do
    local dragStart, startPos, moveConn

    local function stopDrag()
        if moveConn then
            moveConn:Disconnect()
            moveConn = nil
        end
    end
    table.insert(cleanups, stopDrag)

    local function update(input)
        local delta = input.Position - dragStart
        local screen = ScreenGui.AbsoluteSize
        local size = Main.AbsoluteSize
        local minX = -math.max(screen.X - size.X, 0)
        local minY = -math.max(screen.Y - size.Y, 0)
        local x = math.clamp(startPos.X.Offset + delta.X, minX, 0)
        local y = math.clamp(startPos.Y.Offset + delta.Y, minY, 0)
        Main.Position = UDim2.new(1, x, 1, y)
    end

    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            stopDrag()
            dragStart = input.Position
            startPos = Main.Position

            moveConn = UserInputService.InputChanged:Connect(function(changed)
                if changed.UserInputType == Enum.UserInputType.MouseMovement
                    or changed.UserInputType == Enum.UserInputType.Touch then
                    update(changed)
                end
            end)

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    stopDrag()
                end
            end)
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
spin(LogoGradient, 4)

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
local SUB_DEFAULT = "Place " .. tostring(placeId) .. (IS_PRIVATE and " (Private)" or "")
SubLabel.Text = SUB_DEFAULT
SubLabel.Parent = Header

SubLabel.MouseEnter:Connect(function() tween(SubLabel, { TextColor3 = COLORS.cyan }) end)
SubLabel.MouseLeave:Connect(function() tween(SubLabel, { TextColor3 = COLORS.subtext }) end)

SubLabel.MouseButton1Click:Connect(function()
    if modalCount > 0 then return end

    local currentJobId = getJobId()
    local message
    if currentJobId == "" then
        message = "No server ID available"
    elseif copyToClipboard(currentJobId) then
        message = "Copied server ID!"
    else
        message = "Clipboard not supported"
    end
    flash(SubLabel, message, 1.2, SUB_DEFAULT)
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

----------------------------------------------------------------------
-- Footer / Anti-AFK
----------------------------------------------------------------------
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
circle(Halo)

local Dot = Instance.new("Frame")
Dot.AnchorPoint = Vector2.new(0.5, 0.5)
Dot.Position = UDim2.new(0, 18, 0.5, 0)
Dot.Size = UDim2.new(0, 8, 0, 8)
Dot.BackgroundColor3 = COLORS.green
Dot.Parent = Footer
circle(Dot)

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

local haloTween
local function startHaloPulse()
    if haloTween then haloTween:Cancel() end
    Halo.Size = UDim2.new(0, 8, 0, 8)
    Halo.BackgroundTransparency = 0.4
    haloTween = TweenService:Create(
        Halo,
        TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, 0),
        { Size = UDim2.new(0, 24, 0, 24), BackgroundTransparency = 1 }
    )
    haloTween:Play()
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
        if haloTween then haloTween:Cancel() end
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
    pingToken += 1
    local myToken = pingToken
    PillLabel.Text = "PINGED"
    task.delay(1.5, function()
        if pingToken == myToken and PillLabel.Parent then
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

    track(LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        if onPing then
            onPing()
        end
    end))

    return true
end

setPillState(startAntiAfk(flashPing))

----------------------------------------------------------------------
-- Buttons / rows / prompt
----------------------------------------------------------------------
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

-- onClick receives a context table: { btn, desc, idle, default }
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
    circle(Badge)
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

    local _, ActionBtn = gradientButton(
        Row,
        buttonText,
        UDim2.new(0, 68, 0, 28),
        UDim2.new(1, -46, 0.5, 0)
    )

    local ctx = { btn = ActionBtn, desc = DescLbl, idle = buttonText, default = descText }

    ActionBtn.MouseButton1Click:Connect(function()
        if modalCount > 0 then return end
        task.spawn(onClick, ctx)
    end)

    return ctx
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
    modalCount += 1
    tween(Overlay, { BackgroundTransparency = 0.4 }, 0.2)

    local Box = Instance.new("Frame")
    Box.AnchorPoint = Vector2.new(0.5, 0.5)
    Box.Size = UDim2.new(0, 260, 0, 136)
    Box.Position = UDim2.new(0.5, 0, 0.5, 0)
    Box.BackgroundColor3 = COLORS.card
    Box.ZIndex = 11
    Box.Active = true -- sinks clicks so only clicks outside the box cancel
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

    local done = false
    local function close(confirmed)
        if done then return end
        done = true
        local text = Input.Text
        Overlay:Destroy()
        modalCount -= 1
        if confirmed then
            onConfirm(text)
        end
    end

    -- Cancel button
    local Cancel = Instance.new("TextButton")
    Cancel.AnchorPoint = Vector2.new(0, 0.5)
    Cancel.Position = UDim2.new(0, 14, 1, -28)
    Cancel.Size = UDim2.new(0.5, -21, 0, 30)
    Cancel.BackgroundColor3 = COLORS.bg
    Cancel.Text = "Cancel"
    Cancel.Font = Enum.Font.GothamBold
    Cancel.TextSize = 13
    Cancel.TextColor3 = COLORS.subtext
    Cancel.AutoButtonColor = false
    Cancel.ZIndex = 11
    Cancel.Parent = Box
    corner(Cancel, 9)
    stroke(Cancel, COLORS.stroke, 1)
    Cancel.MouseButton1Click:Connect(function() close(false) end)

    -- Confirm button
    local _, Confirm = gradientButton(
        Box,
        "Confirm",
        UDim2.new(0.5, -21, 0, 30),
        UDim2.new(1, -14, 1, -28),
        Vector2.new(1, 0.5),
        11
    )
    Confirm.MouseButton1Click:Connect(function() close(true) end)

    Input.FocusLost:Connect(function(enterPressed)
        if enterPressed then close(true) end
    end)

    Overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            close(false)
        end
    end)
end

----------------------------------------------------------------------
-- Networking
----------------------------------------------------------------------
local requestFn = (syn and syn.request) or (http and http.request) or http_request or request

local function httpGet(url)
    if requestFn then
        local ok, res = pcall(requestFn, { Url = url, Method = "GET" })
        if not ok or type(res) ~= "table" then
            return nil, nil, "Request failed"
        end
        return res.Body, res.StatusCode
    end

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok then
        return nil, nil, "Request failed"
    end
    return body, 200
end

-- Returns serverList, nextCursor, errorMessage
local function fetchPage(sortOrder, cursor)
    local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100")
        :format(placeId, sortOrder)
    if cursor then
        url ..= "&cursor=" .. HttpService:UrlEncode(cursor)
    end

    local body, status, reqErr = httpGet(url)
    if not body then
        return nil, nil, reqErr
    end
    if status == 429 then
        return nil, nil, "Rate limited - wait a few seconds"
    end
    if status and status ~= 200 then
        return nil, nil, "Roblox API error (" .. tostring(status) .. ")"
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok or type(decoded) ~= "table" or type(decoded.data) ~= "table" then
        return nil, nil, "Bad response from Roblox"
    end

    return decoded.data, decoded.nextPageCursor
end

local function collectServers(sortOrder, maxPages)
    local all = {}
    local cursor
    for page = 1, maxPages do
        local data, nextCursor, err = fetchPage(sortOrder, cursor)
        if not data then
            if #all > 0 then break end -- partial results are fine
            return nil, err
        end
        for _, server in ipairs(data) do
            table.insert(all, server)
        end
        cursor = nextCursor
        if not cursor then break end
        if page < maxPages then
            task.wait(0.3)
        end
    end
    return all
end

local function filterCandidates(list)
    local currentJobId = getJobId()
    local out = {}
    for _, server in ipairs(list) do
        if type(server.playing) == "number"
            and type(server.maxPlayers) == "number"
            and server.playing < server.maxPlayers
            and server.id ~= currentJobId then
            table.insert(out, server)
        end
    end
    return out
end

-- Both finders return (server, errorMessage)
local function findLowestPopServer()
    local list, err = collectServers("Asc", 1)
    if not list then return nil, err end

    local candidates = filterCandidates(list)
    if #candidates == 0 then return nil, "No open servers found" end

    table.sort(candidates, function(a, b)
        if a.playing ~= b.playing then
            return a.playing < b.playing
        end
        return (tonumber(a.ping) or math.huge) < (tonumber(b.ping) or math.huge)
    end)

    return candidates[1]
end

local function findRandomServer()
    local order = (math.random(1, 2) == 1) and "Asc" or "Desc"
    local list, err = collectServers(order, RANDOM_PAGES)
    if not list then return nil, err end

    local candidates = filterCandidates(list)
    if #candidates == 0 then return nil, "No open servers found" end

    return candidates[math.random(1, #candidates)]
end

----------------------------------------------------------------------
-- Shared action state (only one teleport/search at a time)
----------------------------------------------------------------------
local active = nil
local actionCounter = 0

local function beginAction(ctx, status, failHint)
    if active then return nil end
    actionCounter += 1
    active = { ctx = ctx, token = actionCounter, failHint = failHint }
    ctx.btn.Text = "..."
    ctx.desc.Text = status
    return actionCounter
end

local function isCurrent(token)
    return active ~= nil and active.token == token
end

local function endAction(message)
    if not active then return end
    local a = active
    active = nil
    a.ctx.btn.Text = a.ctx.idle
    a.ctx.desc.Text = message
    task.delay(6, function()
        if not active and a.ctx.desc.Text == message then
            a.ctx.desc.Text = a.ctx.default
        end
    end)
end

local function armTimeout(token, message)
    task.delay(TELEPORT_TIMEOUT, function()
        if isCurrent(token) then
            endAction(message or "No response - tap to retry")
        end
    end)
end

local queueTeleport = queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)

local function queueReload()
    if AUTO_RELOAD and queueTeleport then
        pcall(queueTeleport, ('loadstring(game:HttpGet("%s"))()'):format(SCRIPT_URL))
    end
end

local function doTeleport(jobId)
    queueReload()
    return pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
    end)
end

track(TeleportService.TeleportInitFailed:Connect(function(_, teleportResult, errorMessage)
    warn("ServerHop: teleport init failed ->", teleportResult, errorMessage)
    if active then
        local hint = active.failHint
        endAction(hint or ("Failed (" .. tostring(teleportResult) .. ") - tap to retry"))
    end
end))

----------------------------------------------------------------------
-- Rows
----------------------------------------------------------------------
local lastSearch = 0

local function runSearch(ctx, finder, onPick)
    if active then return end

    if os.clock() - lastSearch < SEARCH_COOLDOWN then
        flash(ctx.desc, "Slow down - try again in a sec", 1.5, ctx.desc.Text)
        return
    end

    local token = beginAction(ctx, "Searching...", "Server full or closed - tap to retry")
    if not token then return end
    lastSearch = os.clock()

    local server, err = finder()
    lastSearch = os.clock()

    if not isCurrent(token) then return end -- timed out while searching

    if not server then
        onPick(nil)
        endAction(err or "No server found")
        return
    end

    onPick(server.id)
    local pingValue = tonumber(server.ping)
    local pingText = pingValue and (", " .. math.floor(pingValue) .. "ms") or ""
    ctx.desc.Text = "Joining (" .. server.playing .. " players" .. pingText .. ") - tap to copy ID"

    local ok, tpErr = doTeleport(server.id)
    if not ok then
        endAction("Teleport failed: " .. tostring(tpErr))
        return
    end
    armTimeout(token)
end

local function attachCopyOnClick(ctx, getId)
    ctx.desc.MouseButton1Click:Connect(function()
        if modalCount > 0 then return end
        local id = getId()
        if not id then return end
        local previous = ctx.desc.Text
        if copyToClipboard(id) then
            flash(ctx.desc, "Copied: " .. id, 1.2, previous)
        end
    end)
end

-- Least Players
local lastHopId
local hopCtx = buildActionRow(
    "Least Players",
    "Lowest players, best ping as tiebreaker",
    "Hop",
    1,
    function(ctx)
        runSearch(ctx, findLowestPopServer, function(id) lastHopId = id end)
    end,
    true,
    "L"
)
attachCopyOnClick(hopCtx, function() return lastHopId end)

-- Random Server
local lastRandomId
local randomCtx = buildActionRow(
    "Random Server",
    "Join a random non-full server",
    "Hop",
    2,
    function(ctx)
        runSearch(ctx, findRandomServer, function(id) lastRandomId = id end)
    end,
    true,
    "R"
)
attachCopyOnClick(randomCtx, function() return lastRandomId end)

-- Same Server (private-server aware)
--
-- NOTE: Rejoining a *private/VIP* server by Job ID is blocked by Roblox for
-- client scripts (it needs the server's access code, which the client can't
-- read). In that case this tries anyway, then tells you to use your private
-- server link. Public servers can also fail to rejoin if you were the only
-- player in them, because an empty server shuts down.
local REJOIN_FAIL_HINT = IS_PRIVATE
    and "Private server: Roblox blocks script rejoin - use your private server link"
    or "Server closed? Rejoin fails if you were alone in it"

buildActionRow(
    "Same Server",
    IS_PRIVATE and "Private server - rejoin may be blocked" or "Rejoin this exact server",
    "Rejoin",
    3,
    function(ctx)
        local token = beginAction(ctx, "Rejoining...", REJOIN_FAIL_HINT)
        if not token then return end

        local jobId = getJobId()
        local ok, err
        if jobId == "" then
            queueReload()
            ok, err = pcall(function()
                TeleportService:Teleport(placeId, LocalPlayer)
            end)
        else
            ok, err = doTeleport(jobId)
        end

        if not ok then
            endAction(IS_PRIVATE and REJOIN_FAIL_HINT or ("Teleport failed: " .. tostring(err)))
            return
        end
        armTimeout(token, REJOIN_FAIL_HINT)
    end,
    false,
    "S"
)

-- Join by ID
buildActionRow(
    "Join by ID",
    "Enter a Job ID to join directly",
    "Join",
    4,
    function(ctx)
        if active then return end
        prompt("Join Server by ID", "", "Job ID (GUID)", function(text)
            local id = (text or ""):match("^%s*(.-)%s*$")
            if id == "" then return end

            if not id:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then
                flash(ctx.desc, "Invalid Job ID format", 2, ctx.default)
                return
            end

            local token = beginAction(ctx, "Joining...", "Server is full, closed, or private")
            if not token then return end

            local ok, err = doTeleport(id)
            if not ok then
                endAction("Teleport failed: " .. tostring(err))
                return
            end
            armTimeout(token)
        end)
    end,
    false,
    "ID"
)

----------------------------------------------------------------------
-- Minimize
----------------------------------------------------------------------
local EXPANDED_SIZE = Main.Size
local MINIMIZED_SIZE = UDim2.new(0, 250, 0, 56)
local minimized = false
local minToken = 0

local function toggleMinimize()
    if modalCount > 0 then return end
    minimized = not minimized
    minToken += 1
    local myToken = minToken

    if minimized then
        MinBtn.Text = "+"
        Body.Visible = false
        Footer.Visible = false
        tween(Main, { Size = MINIMIZED_SIZE }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    else
        MinBtn.Text = "—"
        tween(Main, { Size = EXPANDED_SIZE }, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        task.delay(0.2, function()
            if minToken == myToken and not minimized then
                Body.Visible = true
                Footer.Visible = true
            end
        end)
    end
end

MinBtn.MouseButton1Click:Connect(toggleMinimize)

do
    local lastClick = 0
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            local now = os.clock()
            if now - lastClick < 0.35 then
                toggleMinimize()
                lastClick = 0
            else
                lastClick = now
            end
        end
    end)
end
