local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local placeId = game.PlaceId
local jobId = game.JobId

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

local container = (gethui and gethui()) or game.CoreGui

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ServerHopGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = container

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 190)
Main.AnchorPoint = Vector2.new(1, 1)
Main.Position = UDim2.new(1, -20, 1, -80)
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
Title.Text = "Server Hop"
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
SubLabel.Text = "Place " .. tostring(placeId)
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

local Body = Instance.new("Frame")
Body.Name = "Body"
Body.Position = UDim2.new(0, 10, 0, 54)
Body.Size = UDim2.new(1, -20, 1, -64)
Body.BackgroundTransparency = 1
Body.Parent = Main

local BodyLayout = Instance.new("UIListLayout")
BodyLayout.Padding = UDim.new(0, 8)
BodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
BodyLayout.Parent = Body

local function buildActionRow(labelText, descText, buttonText, order, onClick)
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
    ActionBtn.MouseButton1Click:Connect(function() onClick(ActionBtn, DescLbl) end)

    return Row, ActionBtn, DescLbl
end

local function findLowestPopServer()
    local success, serverList = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/" .. placeId ..
                "/servers/Public?sortOrder=Asc&limit=100")
        )
    end)

    if success and serverList and serverList.data then
        for _, server in ipairs(serverList.data) do
            if server.playing and server.playing < server.maxPlayers
                and server.id ~= jobId then
                return server.id, server.playing
            end
        end
    else
        warn("ServerHop: request failed -> " .. tostring(serverList))
    end

    return nil
end

local hopping = false

local hopRow, hopBtn, hopDesc = buildActionRow(
    "Least Players",
    "Find and join the lowest-pop server",
    "Hop",
    1,
    function(btn, desc)
        if hopping then return end
        hopping = true
        btn.Text = "..."
        desc.Text = "Searching..."

        local serverId, playerCount = findLowestPopServer()

        if serverId then
            desc.Text = "Joining (" .. playerCount .. " players)..."
            local ok, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, serverId, LocalPlayer)
            end)
            if not ok then
                warn("ServerHop: teleport failed -> " .. tostring(err))
                desc.Text = "Teleport failed"
                btn.Text = "Hop"
            end
        else
            desc.Text = "No server found"
            btn.Text = "Hop"
        end

        hopping = false
    end
)

local rejoining = false

local rejoinRow, rejoinBtn, rejoinDesc = buildActionRow(
    "Same Server",
    "Rejoin this exact server",
    "Rejoin",
    2,
    function(btn, desc)
        if rejoining then return end
        rejoining = true
        btn.Text = "..."
        desc.Text = "Rejoining..."

        local ok, err = pcall(function()
            if jobId ~= "" then
                TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
            else
                TeleportService:Teleport(placeId, LocalPlayer)
            end
        end)

        if not ok then
            warn("Rejoin failed:", err)
            desc.Text = "Failed - tap to retry"
            btn.Text = "Retry"
            rejoining = false
        end
    end
)

TeleportService.TeleportInitFailed:Connect(function(_, teleportResult, errorMessage)
    warn("Teleport init failed:", teleportResult, errorMessage)
    rejoinDesc.Text = "Failed - tap to retry"
    rejoinBtn.Text = "Retry"
    rejoining = false
end)

local EXPANDED_SIZE = Main.Size
local MINIMIZED_SIZE = UDim2.new(0, 220, 0, 50)
local minimized = false

local function toggleMinimize()
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
