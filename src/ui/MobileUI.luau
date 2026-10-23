--!strict
-- MobileUI.luau: Premium Delta Android Mobile Interface
-- 100% self-contained Luau GUI with touch drag, screen boundary clamping,
-- mini HUD launcher, live metrics, performance toggle, and clean unload.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local UI_NAME = "MM2_Private_CandyFarm_UI"

local PALETTE = {
    BG_MAIN        = Color3.fromRGB(18, 18, 24),     -- #121218
    BG_CARD        = Color3.fromRGB(26, 26, 36),     -- #1a1a24
    BG_CONTAINER   = Color3.fromRGB(36, 36, 50),     -- #242432
    BORDER_SUBTLE  = Color3.fromRGB(50, 50, 68),     -- #323244
    ACCENT_PURPLE  = Color3.fromRGB(138, 75, 255),   -- #8a4bff
    ACCENT_MAGENTA = Color3.fromRGB(168, 85, 247),   -- #a855f7
    STATUS_MINT    = Color3.fromRGB(34, 197, 94),    -- #22c55e (Active / Farming)
    STATUS_RED     = Color3.fromRGB(239, 68, 68),    -- #ef4444 (Stopped / Bag Full)
    STATUS_AMBER   = Color3.fromRGB(245, 158, 11),   -- #f59e0b (Waiting / Intermission)
    STATUS_IDLE    = Color3.fromRGB(148, 163, 184),  -- #94a3b8 (Idle)
    TEXT_WHITE     = Color3.fromRGB(255, 255, 255),
    TEXT_MUTED     = Color3.fromRGB(148, 163, 184),
    TEXT_DIM       = Color3.fromRGB(100, 116, 139),
    PROGRESS_BG    = Color3.fromRGB(30, 30, 42),
}

local FONTS = {
    REGULAR = Enum.Font.GothamMedium,
    BOLD    = Enum.Font.GothamBold,
    BLACK   = Enum.Font.GothamBlack,
}

local function GetSafeGuiParent(): Instance
    if typeof(gethui) == "function" then
        local success, hui = pcall(gethui)
        if success and hui then return hui end
    end
    local success, core = pcall(function() return CoreGui end)
    if success and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function Create(className: string, properties: { [string]: any }, children: { Instance }?): Instance
    local inst = Instance.new(className)
    for k, v in pairs(properties or {}) do
        (inst :: any)[k] = v
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    return inst
end

local function Tween(inst: Instance, duration: number, properties: { [string]: any })
    local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tw = TweenService:Create(inst, info, properties)
    tw:Play()
    return tw
end

-- Clamp GUI position within screen viewport so it cannot be dragged off-screen on Android
local function ClampToViewport(targetFrame: GuiObject, goalOffset: Vector2): UDim2
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
    local frameSize = targetFrame.AbsoluteSize

    local minX = 0
    local maxX = math.max(viewport.X - frameSize.X, 0)
    local minY = 0
    local maxY = math.max(viewport.Y - frameSize.Y, 0)

    local clampedX = math.clamp(goalOffset.X, minX, maxX)
    local clampedY = math.clamp(goalOffset.Y, minY, maxY)

    return UDim2.new(0, clampedX, 0, clampedY)
end

-- Mobile Touch & Mouse Draggable Handler with Boundary Clamping
local function MakeClampedDraggable(dragHandle: GuiObject, targetFrame: GuiObject)
    dragHandle.Active = true
    targetFrame.Active = true

    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            local camera = Workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
            local currentAbsX = startPos.X.Scale * viewport.X + startPos.X.Offset + delta.X
            local currentAbsY = startPos.Y.Scale * viewport.Y + startPos.Y.Offset + delta.Y

            targetFrame.Position = ClampToViewport(targetFrame, Vector2.new(currentAbsX, currentAbsY))
        end
    end)
end

local MobileUI = {}
MobileUI.__index = MobileUI

function MobileUI.Init(userCallbacks: { [string]: any })
    userCallbacks = userCallbacks or {}
    local self = setmetatable({}, MobileUI)

    self.IsFarming = false
    self.CurrentStatus = "IDLE"
    self.Callbacks = userCallbacks
    self.Settings = {
        FarmSpeed = "Fast",
        BagCapacity = "Auto",
        SafePlatform = true,
        AutoResume = true,
        AntiAFK = true,
        PerfMode = false,
    }

    local safeParent = GetSafeGuiParent()
    local existing = safeParent:FindFirstChild(UI_NAME)
    if existing then
        pcall(function() existing:Destroy() end)
    end

    local screenGui = Create("ScreenGui", {
        Name = UI_NAME,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
        Parent = safeParent,
    })
    self.ScreenGui = screenGui

    -- Floating Launcher Pill (Mini HUD when main window is hidden)
    local floatingPill = Create("Frame", {
        Name = "FloatingLauncher",
        Size = UDim2.new(0, 126, 0, 36),
        Position = UDim2.new(0.5, -63, 0, 18),
        BackgroundColor3 = PALETTE.BG_MAIN,
        BorderSizePixel = 0,
        Active = true,
        Parent = screenGui,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 18) }),
        Create("UIStroke", {
            Color = PALETTE.ACCENT_PURPLE,
            Thickness = 1.4,
            Transparency = 0.2,
        }),
    })
    self.FloatingPill = floatingPill

    local pillStatusDot = Create("Frame", {
        Name = "StatusDot",
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(0, 10, 0.5, -4),
        BackgroundColor3 = PALETTE.STATUS_IDLE,
        BorderSizePixel = 0,
        Parent = floatingPill,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })
    self.PillStatusDot = pillStatusDot

    local pillLabel = Create("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, -26, 1, 0),
        Position = UDim2.new(0, 24, 0, 0),
        BackgroundTransparency = 1,
        Text = "🍬 0 / 40",
        Font = FONTS.BOLD,
        TextSize = 11,
        TextColor3 = PALETTE.TEXT_WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = floatingPill,
    })
    self.PillLabel = pillLabel

    MakeClampedDraggable(floatingPill, floatingPill)

    -- Main Window (Compact: 340x260 px)
    local mainWindow = Create("Frame", {
        Name = "MainWindow",
        Size = UDim2.new(0, 340, 0, 260),
        Position = UDim2.new(0.5, -170, 0.5, -130),
        BackgroundColor3 = PALETTE.BG_MAIN,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Parent = screenGui,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
        Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1.2 }),
    })
    self.MainWindow = mainWindow

    -- Header Bar
    local header = Create("Frame", {
        Name = "HeaderBar",
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = mainWindow,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
        Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, PALETTE.BG_CARD),
                ColorSequenceKeypoint.new(1, PALETTE.BG_MAIN),
            }),
            Rotation = 90,
        }),
    })

    local title = Create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0, 180, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "🍬 DELTA CANDY FARM",
        Font = FONTS.BLACK,
        TextSize = 12,
        TextColor3 = PALETTE.TEXT_WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    local versionBadge = Create("TextLabel", {
        Name = "Badge",
        Size = UDim2.new(0, 52, 0, 16),
        Position = UDim2.new(0, 164, 0.5, -8),
        BackgroundColor3 = PALETTE.BG_CONTAINER,
        Text = "PRO v2.0",
        Font = FONTS.BOLD,
        TextSize = 9,
        TextColor3 = PALETTE.ACCENT_MAGENTA,
        Parent = header,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
    })

    local minimizeBtn = Create("TextButton", {
        Name = "MinBtn",
        Size = UDim2.new(0, 26, 0, 22),
        Position = UDim2.new(1, -58, 0.5, -11),
        BackgroundColor3 = PALETTE.BG_CONTAINER,
        Text = "—",
        Font = FONTS.BOLD,
        TextSize = 11,
        TextColor3 = PALETTE.TEXT_MUTED,
        Parent = header,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
    })

    local closeBtn = Create("TextButton", {
        Name = "CloseBtn",
        Size = UDim2.new(0, 26, 0, 22),
        Position = UDim2.new(1, -28, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(44, 24, 28),
        Text = "✕",
        Font = FONTS.BOLD,
        TextSize = 11,
        TextColor3 = PALETTE.STATUS_RED,
        Parent = header,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
    })

    MakeClampedDraggable(header, mainWindow)

    -- Toggle Main Window visibility
    local function ToggleMainWindow()
        if mainWindow.Visible then
            Tween(mainWindow, 0.16, { Size = UDim2.new(0, 310, 0, 235), BackgroundTransparency = 0.5 })
            task.delay(0.16, function()
                mainWindow.Visible = false
                mainWindow.Size = UDim2.new(0, 340, 0, 260)
                mainWindow.BackgroundTransparency = 0
            end)
        else
            mainWindow.Visible = true
            mainWindow.Size = UDim2.new(0, 310, 0, 235)
            mainWindow.BackgroundTransparency = 0.4
            Tween(mainWindow, 0.16, { Size = UDim2.new(0, 340, 0, 260), BackgroundTransparency = 0 })
        end
    end

    minimizeBtn.MouseButton1Click:Connect(ToggleMainWindow)
    closeBtn.MouseButton1Click:Connect(ToggleMainWindow)

    floatingPill.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local startTime = tick()
            local endedConn
            endedConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    endedConn:Disconnect()
                    if (tick() - startTime) < 0.22 then
                        ToggleMainWindow()
                    end
                end
            end)
        end
    end)

    -- Navigation Bar (Dashboard & Settings)
    local tabBar = Create("Frame", {
        Name = "TabBar",
        Size = UDim2.new(1, -16, 0, 26),
        Position = UDim2.new(0, 8, 0, 38),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = mainWindow,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
    })

    local tabDashBtn = Create("TextButton", {
        Name = "TabDash",
        Size = UDim2.new(0.5, -2, 1, -4),
        Position = UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = PALETTE.ACCENT_PURPLE,
        Text = "📊 Dashboard",
        Font = FONTS.BOLD,
        TextSize = 11,
        TextColor3 = PALETTE.TEXT_WHITE,
        Parent = tabBar,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
    })

    local tabSettingsBtn = Create("TextButton", {
        Name = "TabSettings",
        Size = UDim2.new(0.5, -2, 1, -4),
        Position = UDim2.new(0.5, 0, 0, 2),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        Text = "⚙ Settings",
        Font = FONTS.BOLD,
        TextSize = 11,
        TextColor3 = PALETTE.TEXT_MUTED,
        Parent = tabBar,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
    })

    local pagesContainer = Create("Frame", {
        Name = "Pages",
        Size = UDim2.new(1, -16, 1, -74),
        Position = UDim2.new(0, 8, 0, 68),
        BackgroundTransparency = 1,
        Parent = mainWindow,
    })

    -- PAGE 1: DASHBOARD
    local dashPage = Create("Frame", {
        Name = "DashboardPage",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = true,
        Parent = pagesContainer,
    })

    -- Status Card
    local statusCard = Create("Frame", {
        Name = "StatusCard",
        Size = UDim2.new(1, 0, 0, 32),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = dashPage,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
    })

    local statusDot = Create("Frame", {
        Name = "StatusDot",
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(0, 10, 0.5, -4),
        BackgroundColor3 = PALETTE.STATUS_IDLE,
        BorderSizePixel = 0,
        Parent = statusCard,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })
    self.StatusDot = statusDot

    local statusText = Create("TextLabel", {
        Name = "StatusText",
        Size = UDim2.new(0, 130, 1, 0),
        Position = UDim2.new(0, 24, 0, 0),
        BackgroundTransparency = 1,
        Text = "IDLE (READY)",
        Font = FONTS.BOLD,
        TextSize = 10,
        TextColor3 = PALETTE.STATUS_IDLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = statusCard,
    })
    self.StatusText = statusText

    local subInfoText = Create("TextLabel", {
        Name = "SubInfo",
        Size = UDim2.new(1, -165, 1, 0),
        Position = UDim2.new(0, 155, 0, 0),
        BackgroundTransparency = 1,
        Text = "Map: Lobby | Target: —",
        Font = FONTS.REGULAR,
        TextSize = 9.5,
        TextColor3 = PALETTE.TEXT_MUTED,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = statusCard,
    })
    self.SubInfoText = subInfoText

    -- Metric Grid (2x2)
    local metricGrid = Create("Frame", {
        Name = "MetricGrid",
        Size = UDim2.new(1, 0, 0, 96),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundTransparency = 1,
        Parent = dashPage,
    })

    local function CreateMetricCard(name: string, label: string, initialVal: string, posX: number, posY: number)
        local card = Create("Frame", {
            Name = name,
            Size = UDim2.new(0.5, -4, 0, 45),
            Position = UDim2.new(posX, 0, posY, 0),
            BackgroundColor3 = PALETTE.BG_CARD,
            BorderSizePixel = 0,
            Parent = metricGrid,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
            Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
        })

        local caption = Create("TextLabel", {
            Name = "Caption",
            Size = UDim2.new(1, -12, 0, 14),
            Position = UDim2.new(0, 8, 0, 4),
            BackgroundTransparency = 1,
            Text = label,
            Font = FONTS.REGULAR,
            TextSize = 9,
            TextColor3 = PALETTE.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
        })

        local val = Create("TextLabel", {
            Name = "Val",
            Size = UDim2.new(1, -12, 0, 20),
            Position = UDim2.new(0, 8, 0, 18),
            BackgroundTransparency = 1,
            Text = initialVal,
            Font = FONTS.BOLD,
            TextSize = 13,
            TextColor3 = PALETTE.TEXT_WHITE,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
        })

        return card, val
    end

    local cardBag, valBag = CreateMetricCard("CardBag", "BAG CAPACITY", "0 / 40", 0, 0)
    local cardTotal, valTotal = CreateMetricCard("CardTotal", "SESSION HARVEST", "0 🍬", 0.5, 0)
    local cardRounds, valRounds = CreateMetricCard("CardRounds", "ROUNDS FARMED", "0", 0, 0.52)
    local cardTime, valTime = CreateMetricCard("CardTime", "SESSION DURATION", "00:00:00", 0.5, 0.52)

    self.ValBag = valBag
    self.ValTotal = valTotal
    self.ValRounds = valRounds
    self.ValTime = valTime

    local bagProgressBg = Create("Frame", {
        Name = "ProgressBg",
        Size = UDim2.new(1, -16, 0, 3),
        Position = UDim2.new(0, 8, 1, -5),
        BackgroundColor3 = PALETTE.PROGRESS_BG,
        BorderSizePixel = 0,
        Parent = cardBag,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })

    local bagProgressFill = Create("Frame", {
        Name = "ProgressFill",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = PALETTE.ACCENT_PURPLE,
        BorderSizePixel = 0,
        Parent = bagProgressBg,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })
    self.BagProgressFill = bagProgressFill

    -- Primary CTA Button
    local primaryBtn = Create("TextButton", {
        Name = "PrimaryActionButton",
        Size = UDim2.new(1, 0, 0, 38),
        Position = UDim2.new(0, 0, 1, -40),
        BackgroundColor3 = PALETTE.STATUS_MINT,
        Text = "▶  START FARMING",
        Font = FONTS.BLACK,
        TextSize = 13,
        TextColor3 = PALETTE.TEXT_WHITE,
        Parent = dashPage,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 197, 94)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 145, 68)),
            }),
            Rotation = 45,
        }),
    })
    self.PrimaryBtn = primaryBtn

    primaryBtn.MouseButton1Click:Connect(function()
        self:ToggleFarming()
    end)

    -- PAGE 2: SETTINGS
    local settingsPage = Create("ScrollingFrame", {
        Name = "SettingsPage",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = PALETTE.ACCENT_PURPLE,
        CanvasSize = UDim2.new(0, 0, 0, 230),
        Visible = false,
        Parent = pagesContainer,
    })

    local function CreateSegmentedRow(yPos: number, titleText: string, options: { string }, currentOpt: string, onSelect)
        local row = Create("Frame", {
            Size = UDim2.new(1, -4, 0, 28),
            Position = UDim2.new(0, 0, 0, yPos),
            BackgroundColor3 = PALETTE.BG_CARD,
            BorderSizePixel = 0,
            Parent = settingsPage,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
            Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
        })

        local label = Create("TextLabel", {
            Size = UDim2.new(0, 95, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = titleText,
            Font = FONTS.BOLD,
            TextSize = 10,
            TextColor3 = PALETTE.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        local btnContainer = Create("Frame", {
            Size = UDim2.new(1, -105, 1, -6),
            Position = UDim2.new(0, 100, 0, 3),
            BackgroundTransparency = 1,
            Parent = row,
        })

        local buttons = {}
        local count = #options
        local widthPerBtn = 1 / count

        for i, opt in ipairs(options) do
            local btn = Create("TextButton", {
                Name = opt,
                Size = UDim2.new(widthPerBtn, -2, 1, 0),
                Position = UDim2.new((i - 1) * widthPerBtn, 1, 0, 0),
                BackgroundColor3 = (opt == currentOpt) and PALETTE.ACCENT_PURPLE or PALETTE.BG_CONTAINER,
                Text = opt,
                Font = FONTS.BOLD,
                TextSize = 9.5,
                TextColor3 = (opt == currentOpt) and PALETTE.TEXT_WHITE or PALETTE.TEXT_MUTED,
                Parent = btnContainer,
            }, {
                Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
            })

            btn.MouseButton1Click:Connect(function()
                for _, otherBtn in pairs(buttons) do
                    Tween(otherBtn, 0.15, { BackgroundColor3 = PALETTE.BG_CONTAINER, TextColor3 = PALETTE.TEXT_MUTED })
                end
                Tween(btn, 0.15, { BackgroundColor3 = PALETTE.ACCENT_PURPLE, TextColor3 = PALETTE.TEXT_WHITE })
                onSelect(opt)
            end)
            buttons[opt] = btn
        end

        return row
    end

    local function CreateToggleRow(yPos: number, labelText: string, defaultVal: boolean, onToggle)
        local row = Create("Frame", {
            Size = UDim2.new(1, -4, 0, 28),
            Position = UDim2.new(0, 0, 0, yPos),
            BackgroundColor3 = PALETTE.BG_CARD,
            BorderSizePixel = 0,
            Parent = settingsPage,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
            Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
        })

        local label = Create("TextLabel", {
            Size = UDim2.new(1, -55, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = labelText,
            Font = FONTS.BOLD,
            TextSize = 10,
            TextColor3 = PALETTE.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        local switch = Create("Frame", {
            Name = "Switch",
            Size = UDim2.new(0, 36, 0, 18),
            Position = UDim2.new(1, -44, 0.5, -9),
            BackgroundColor3 = defaultVal and PALETTE.STATUS_MINT or PALETTE.BG_CONTAINER,
            BorderSizePixel = 0,
            Parent = row,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
        })

        local knob = Create("Frame", {
            Name = "Knob",
            Size = UDim2.new(0, 14, 0, 14),
            Position = defaultVal and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
            BackgroundColor3 = PALETTE.TEXT_WHITE,
            BorderSizePixel = 0,
            Parent = switch,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
        })

        local clickBtn = Create("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            Parent = row,
        })

        local state = defaultVal
        clickBtn.MouseButton1Click:Connect(function()
            state = not state
            if state then
                Tween(switch, 0.15, { BackgroundColor3 = PALETTE.STATUS_MINT })
                Tween(knob, 0.15, { Position = UDim2.new(1, -16, 0.5, -7) })
            else
                Tween(switch, 0.15, { BackgroundColor3 = PALETTE.BG_CONTAINER })
                Tween(knob, 0.15, { Position = UDim2.new(0, 2, 0.5, -7) })
            end
            onToggle(state)
        end)

        return row
    end

    CreateSegmentedRow(0, "Farm Speed", { "Normal", "Fast", "Instant" }, self.Settings.FarmSpeed, function(val)
        self.Settings.FarmSpeed = val
        if self.Callbacks.OnSpeedChanged then self.Callbacks.OnSpeedChanged(val) end
    end)

    CreateSegmentedRow(32, "Bag Target", { "Auto", "40", "50" }, self.Settings.BagCapacity, function(val)
        self.Settings.BagCapacity = val
        if self.Callbacks.OnBagCapacityChanged then self.Callbacks.OnBagCapacityChanged(val) end
    end)

    CreateToggleRow(64, "Safe Spot (Void Platform on Full)", self.Settings.SafePlatform, function(val)
        self.Settings.SafePlatform = val
        if self.Callbacks.OnSafePlatformChanged then self.Callbacks.OnSafePlatformChanged(val) end
    end)

    CreateToggleRow(96, "Auto-Resume on Respawn", self.Settings.AutoResume, function(val)
        self.Settings.AutoResume = val
        if self.Callbacks.OnAutoResumeChanged then self.Callbacks.OnAutoResumeChanged(val) end
    end)

    CreateToggleRow(128, "Anti-AFK Protection", self.Settings.AntiAFK, function(val)
        self.Settings.AntiAFK = val
        if self.Callbacks.OnAntiAFKChanged then self.Callbacks.OnAntiAFKChanged(val) end
    end)

    CreateToggleRow(160, "Performance Mode (Low-End FPS)", self.Settings.PerfMode, function(val)
        self.Settings.PerfMode = val
        if self.Callbacks.OnPerfModeChanged then self.Callbacks.OnPerfModeChanged(val) end
    end)

    -- Clean Unload Button in Settings
    local unloadBtn = Create("TextButton", {
        Name = "UnloadBtn",
        Size = UDim2.new(1, -4, 0, 28),
        Position = UDim2.new(0, 0, 0, 194),
        BackgroundColor3 = Color3.fromRGB(50, 24, 28),
        Text = "🛑 Clean Unload & Exit Script",
        Font = FONTS.BOLD,
        TextSize = 10,
        TextColor3 = PALETTE.STATUS_RED,
        Parent = settingsPage,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
        Create("UIStroke", { Color = Color3.fromRGB(100, 30, 35), Thickness = 1 }),
    })

    unloadBtn.MouseButton1Click:Connect(function()
        if self.Callbacks.OnUnload then
            self.Callbacks.OnUnload()
        else
            self:Destroy()
        end
    end)

    -- Tab Switching
    tabDashBtn.MouseButton1Click:Connect(function()
        tabDashBtn.BackgroundColor3 = PALETTE.ACCENT_PURPLE
        tabDashBtn.BackgroundTransparency = 0
        tabDashBtn.TextColor3 = PALETTE.TEXT_WHITE

        tabSettingsBtn.BackgroundTransparency = 1
        tabSettingsBtn.TextColor3 = PALETTE.TEXT_MUTED

        dashPage.Visible = true
        settingsPage.Visible = false
    end)

    tabSettingsBtn.MouseButton1Click:Connect(function()
        tabSettingsBtn.BackgroundColor3 = PALETTE.ACCENT_PURPLE
        tabSettingsBtn.BackgroundTransparency = 0
        tabSettingsBtn.TextColor3 = PALETTE.TEXT_WHITE

        tabDashBtn.BackgroundTransparency = 1
        tabDashBtn.TextColor3 = PALETTE.TEXT_MUTED

        settingsPage.Visible = true
        dashPage.Visible = false
    end)

    return self
end

function MobileUI:ToggleFarming()
    self.IsFarming = not self.IsFarming

    if self.IsFarming then
        self.PrimaryBtn.Text = "⏹  STOP FARMING"
        self.PrimaryBtn.BackgroundColor3 = PALETTE.STATUS_RED
        local grad = self.PrimaryBtn:FindFirstChildOfClass("UIGradient")
        if grad then
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(239, 68, 68)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 28, 28)),
            })
        end
        self:SetStatus("FARMING", "Traversing candies...")
    else
        self.PrimaryBtn.Text = "▶  START FARMING"
        self.PrimaryBtn.BackgroundColor3 = PALETTE.STATUS_MINT
        local grad = self.PrimaryBtn:FindFirstChildOfClass("UIGradient")
        if grad then
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 197, 94)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 145, 68)),
            })
        end
        self:SetStatus("IDLE", "Farm stopped by user")
    end

    if self.Callbacks.OnToggleFarm then
        self.Callbacks.OnToggleFarm(self.IsFarming)
    end
end

function MobileUI:SetStatus(statusKey: string, subInfo: string?)
    self.CurrentStatus = statusKey

    local color = PALETTE.STATUS_IDLE
    local title = "IDLE (READY)"

    if statusKey == "FARMING" or statusKey == "MOVING" or statusKey == "COLLECTING" then
        color = PALETTE.STATUS_MINT
        title = "FARMING CANDIES"
    elseif statusKey == "BAG_FULL" then
        color = PALETTE.STATUS_RED
        title = "BAG FULL (40/40)"
    elseif statusKey == "ROUND_OVER" then
        color = PALETTE.STATUS_AMBER
        title = "ROUND OVER"
    elseif statusKey == "WAITING_MAP" then
        color = PALETTE.ACCENT_MAGENTA
        title = "WAITING FOR MAP"
    end

    if self.StatusDot then self.StatusDot.BackgroundColor3 = color end
    if self.PillStatusDot then self.PillStatusDot.BackgroundColor3 = color end
    if self.StatusText then
        self.StatusText.Text = title
        self.StatusText.TextColor3 = color
    end
    if subInfo and self.SubInfoText then
        self.SubInfoText.Text = subInfo
    end
end

function MobileUI:UpdateMetrics(metrics: {
    bagCurrent: number?,
    bagMax: number?,
    totalCandies: number?,
    roundsFarmed: number?,
    elapsedSeconds: number?,
    mapName: string?,
    targetDistance: number?,
    cpm: number?,
})
    if not metrics then return end

    if metrics.bagCurrent ~= nil and metrics.bagMax ~= nil then
        self.ValBag.Text = string.format("%d / %d", metrics.bagCurrent, metrics.bagMax)
        if self.PillLabel then
            self.PillLabel.Text = string.format("🍬 %d / %d", metrics.bagCurrent, metrics.bagMax)
        end

        local progress = math.clamp(metrics.bagCurrent / math.max(metrics.bagMax, 1), 0, 1)
        Tween(self.BagProgressFill, 0.2, { Size = UDim2.new(progress, 0, 1, 0) })
        if progress >= 1 then
            self.BagProgressFill.BackgroundColor3 = PALETTE.STATUS_RED
        else
            self.BagProgressFill.BackgroundColor3 = PALETTE.ACCENT_PURPLE
        end
    end

    if metrics.totalCandies ~= nil then
        self.ValTotal.Text = string.format("%d 🍬", metrics.totalCandies)
    end

    if metrics.roundsFarmed ~= nil then
        self.ValRounds.Text = tostring(metrics.roundsFarmed)
    end

    if metrics.elapsedSeconds ~= nil then
        local hours = math.floor(metrics.elapsedSeconds / 3600)
        local mins = math.floor((metrics.elapsedSeconds % 3600) / 60)
        local secs = math.floor(metrics.elapsedSeconds % 60)
        self.ValTime.Text = string.format("%02d:%02d:%02d", hours, mins, secs)
    end

    if metrics.mapName or metrics.targetDistance then
        local mapStr = metrics.mapName or "Unknown"
        local distStr = metrics.targetDistance and string.format("%d studs", math.floor(metrics.targetDistance)) or "—"
        self.SubInfoText.Text = string.format("Map: %s | Dist: %s", mapStr, distStr)
    end
end

function MobileUI:Destroy()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end
end

return MobileUI
