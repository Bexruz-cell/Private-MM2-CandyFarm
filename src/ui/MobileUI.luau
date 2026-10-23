--!strict
-- MobileUI.luau: Premium Russian Mobile Interface (NEBULA PRO + MIDNIGHT Architecture)
-- Ultra-compact pocket overlay (336 x 260 px), 3 primary tabs (ФАРМ, ЗОМБИ, НАСТРОЙКИ),
-- 100% native vector icon primitives (zero emojis), boundary clamping, and fail-safe diagnostics.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local IconPrimitives = require(script.Parent.IconPrimitives)

local UI_NAME = "MM2_Private_CandyFarm_RU_UI"

local PALETTE = {
    BG_MAIN        = Color3.fromRGB(13, 10, 22),     -- Глубокий ночной фон
    BG_CARD        = Color3.fromRGB(22, 17, 36),     -- Темно-фиолетовая карточка
    BG_CONTAINER   = Color3.fromRGB(32, 25, 52),     -- Колодец контейнера
    BORDER_STROKE  = Color3.fromRGB(88, 54, 138),    -- Фиолетовая обводка
    ACCENT_PURPLE  = Color3.fromRGB(147, 51, 234),   -- Яркий фиолетовый акцент
    ACCENT_MAGENTA = Color3.fromRGB(168, 85, 247),   -- Маджента
    TAB_INACTIVE   = Color3.fromRGB(24, 19, 40),
    STATUS_GREEN   = Color3.fromRGB(16, 185, 129),   -- Изумрудный (Активен)
    STATUS_RED     = Color3.fromRGB(239, 68, 68),    -- Рубиновый (Остановлен / Лимит)
    STATUS_AMBER   = Color3.fromRGB(245, 158, 11),   -- Янтарный (Ожидание)
    TEXT_WHITE     = Color3.fromRGB(255, 255, 255),
    TEXT_MUTED     = Color3.fromRGB(196, 181, 253),
    TEXT_DIM       = Color3.fromRGB(139, 128, 175),
    PROGRESS_BG    = Color3.fromRGB(28, 22, 44),
}

local FONTS = {
    REGULAR = Enum.Font.GothamMedium,
    BOLD    = Enum.Font.GothamBold,
    BLACK   = Enum.Font.GothamBlack,
}

-- 3-tier safe parent resolver (gethui -> CoreGui in pcall -> PlayerGui)
local function ResolveGuiParent(screenGui: ScreenGui): (Instance, string)
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            local parentOk = pcall(function()
                screenGui.Parent = hui
            end)
            if parentOk and screenGui.Parent == hui then
                return hui, "gethui"
            end
        end
    end

    local coreOk = pcall(function()
        local core = game:GetService("CoreGui")
        screenGui.Parent = core
    end)
    if coreOk and screenGui.Parent == game:GetService("CoreGui") then
        return game:GetService("CoreGui"), "CoreGui"
    end

    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5) or LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        screenGui.Parent = playerGui
        return playerGui, "PlayerGui"
    end

    error("Critical: Could not resolve valid GUI parent.")
end

local function Create(className: string, properties: { [string]: any }, children: { Instance }?): Instance
    local inst = Instance.new(className)
    for k, v in pairs(properties or {}) do
        pcall(function()
            (inst :: any)[k] = v
        end)
    end
    if children then
        for _, child in ipairs(children) do
            pcall(function()
                child.Parent = inst
            end)
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

-- Clamp GUI within mobile screen bounds
local function ClampToViewport(targetFrame: GuiObject, goalOffset: Vector2): UDim2
    local camera = Workspace.CurrentCamera
    local viewport = (camera and camera.ViewportSize.X > 50) and camera.ViewportSize or Vector2.new(1280, 720)
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
            local viewport = (camera and camera.ViewportSize.X > 50) and camera.ViewportSize or Vector2.new(1280, 720)
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
    self.IsZombieMode = false
    self.CurrentStatus = "Ожидание раунда"
    self.ActiveTab = "FARM"
    self.Callbacks = userCallbacks

    self.Settings = {
        FarmSpeed = "Быстрая", -- "Обычная" (28), "Быстрая" (36), "Турбо" (44)
        BagCapacity = "Авто",
        SafePlatform = true,
        AutoResume = true,
        AntiAFK = true,
        PerfMode = false,
    }

    -- 1. Singleton guard
    pcall(function()
        local existing = CoreGui:FindFirstChild(UI_NAME) or (LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild(UI_NAME))
        if existing then existing:Destroy() end
    end)

    -- 2. ScreenGui
    local screenGui = Create("ScreenGui", {
        Name = UI_NAME,
        ResetOnSpawn = false,
        DisplayOrder = 999990,
    }) :: ScreenGui
    screenGui.Enabled = true

    local resolvedParent, parentType = ResolveGuiParent(screenGui)
    self.ScreenGui = screenGui

    -- 3. Floating Mini-HUD Capsule
    local floatingPill = Create("Frame", {
        Name = "FloatingLauncher",
        Size = UDim2.new(0, 118, 0, 32),
        Position = UDim2.new(0.5, -59, 0, 14),
        BackgroundColor3 = PALETTE.BG_MAIN,
        BorderSizePixel = 0,
        Active = true,
        Parent = screenGui,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 16) }),
        Create("UIStroke", {
            Color = PALETTE.ACCENT_PURPLE,
            Thickness = 1.4,
            Transparency = 0.15,
        }),
    })
    self.FloatingPill = floatingPill

    -- Mini-HUD Custom Vector Icon
    local pillIcon = IconPrimitives.CreateIcon("Candy", 14, PALETTE.TEXT_WHITE, PALETTE.ACCENT_MAGENTA)
    pillIcon.Position = UDim2.new(0, 8, 0.5, -7)
    pillIcon.Parent = floatingPill

    local pillDot = Create("Frame", {
        Name = "StatusDot",
        Size = UDim2.new(0, 6, 0, 6),
        Position = UDim2.new(0, 24, 0.5, -3),
        BackgroundColor3 = PALETTE.STATUS_AMBER,
        BorderSizePixel = 0,
        Parent = floatingPill,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })
    self.PillDot = pillDot

    local pillLabel = Create("TextLabel", {
        Name = "PillLabel",
        Size = UDim2.new(1, -34, 1, 0),
        Position = UDim2.new(0, 32, 0, 0),
        BackgroundTransparency = 1,
        Text = "0 / 40",
        Font = FONTS.BOLD,
        TextSize = 10,
        TextColor3 = PALETTE.TEXT_WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = floatingPill,
    })
    self.PillLabel = pillLabel

    MakeClampedDraggable(floatingPill, floatingPill)

    -- 4. Main Window (NEBULA PRO + MIDNIGHT Compactness: 336 x 260 px)
    local mainWindow = Create("Frame", {
        Name = "MainWindow",
        Size = UDim2.new(0, 336, 0, 260),
        Position = UDim2.new(0.5, -168, 0.5, -130),
        BackgroundColor3 = PALETTE.BG_MAIN,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Parent = screenGui,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
        Create("UIStroke", { Color = PALETTE.BORDER_STROKE, Thickness = 1.2 }),
    })
    self.MainWindow = mainWindow

    -- Header Bar (32 px)
    local header = Create("Frame", {
        Name = "HeaderBar",
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = mainWindow,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
    })

    -- Header Icon
    local headerIcon = IconPrimitives.CreateIcon("Candy", 16, PALETTE.TEXT_WHITE, PALETTE.ACCENT_MAGENTA)
    headerIcon.Position = UDim2.new(0, 10, 0.5, -8)
    headerIcon.Parent = header

    local title = Create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0, 180, 1, 0),
        Position = UDim2.new(0, 30, 0, 0),
        BackgroundTransparency = 1,
        Text = "MM2 Candy Farm",
        Font = FONTS.BLACK,
        TextSize = 12,
        TextColor3 = PALETTE.TEXT_WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    -- Minimize Button
    local minimizeBtn = Create("TextButton", {
        Name = "MinBtn",
        Size = UDim2.new(0, 24, 0, 20),
        Position = UDim2.new(1, -52, 0.5, -10),
        BackgroundColor3 = PALETTE.BG_CONTAINER,
        BorderSizePixel = 0,
        Text = "",
        Parent = header,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
    })
    local minIcon = IconPrimitives.CreateIcon("Minimize", 12, PALETTE.TEXT_MUTED)
    minIcon.Position = UDim2.new(0.5, -6, 0.5, -6)
    minIcon.Parent = minimizeBtn

    -- Close Button
    local closeBtn = Create("TextButton", {
        Name = "CloseBtn",
        Size = UDim2.new(0, 24, 0, 20),
        Position = UDim2.new(1, -26, 0.5, -10),
        BackgroundColor3 = Color3.fromRGB(60, 20, 30),
        BorderSizePixel = 0,
        Text = "",
        Parent = header,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
    })
    local closeIcon = IconPrimitives.CreateIcon("Close", 12, Color3.fromRGB(248, 113, 113))
    closeIcon.Position = UDim2.new(0.5, -6, 0.5, -6)
    closeIcon.Parent = closeBtn

    MakeClampedDraggable(header, mainWindow)

    -- Toggle Window visibility
    local function ToggleMainWindow()
        mainWindow.Visible = not mainWindow.Visible
    end
    minimizeBtn.MouseButton1Click:Connect(ToggleMainWindow)
    closeBtn.MouseButton1Click:Connect(ToggleMainWindow)

    floatingPill.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local startPos = input.Position
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    conn:Disconnect()
                    local dist = (input.Position - startPos).Magnitude
                    if dist < 5 then
                        ToggleMainWindow()
                    end
                end
            end)
        end
    end)

    -- 5. Three-Tab Selector Bar (26 px)
    local tabBar = Create("Frame", {
        Name = "TabBar",
        Size = UDim2.new(1, -16, 0, 26),
        Position = UDim2.new(0, 8, 0, 36),
        BackgroundColor3 = PALETTE.BG_CONTAINER,
        BorderSizePixel = 0,
        Parent = mainWindow,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
    })

    local tabButtons = {}
    local tabPages = {}

    local function CreateTabButton(name: string, label: string, iconType: string, xPosScale: number, widthScale: number)
        local btn = Create("TextButton", {
            Name = "Tab_" .. name,
            Size = UDim2.new(widthScale, -2, 1, -2),
            Position = UDim2.new(xPosScale, 1, 0, 1),
            BackgroundColor3 = (name == "FARM") and PALETTE.BG_CARD or Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = (name == "FARM") and 0 or 1,
            BorderSizePixel = 0,
            Text = "  " .. label,
            Font = FONTS.BOLD,
            TextSize = 10,
            TextColor3 = (name == "FARM") and PALETTE.TEXT_WHITE or PALETTE.TEXT_DIM,
            Parent = tabBar,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 5) }),
        })

        local tabIcon = IconPrimitives.CreateIcon(iconType, 12, (name == "FARM") and PALETTE.ACCENT_MAGENTA or PALETTE.TEXT_DIM)
        tabIcon.Position = UDim2.new(0, 6, 0.5, -6)
        tabIcon.Parent = btn

        tabButtons[name] = { btn = btn, icon = tabIcon }
        return btn
    end

    CreateTabButton("FARM", "ФАРМ", "Candy", 0, 0.333)
    CreateTabButton("ZOMBIE", "ЗОМБИ", "Zombie", 0.333, 0.333)
    CreateTabButton("SETTINGS", "НАСТРОЙКИ", "Settings", 0.666, 0.334)

    -- Container for Tab Pages
    local contentArea = Create("Frame", {
        Name = "ContentArea",
        Size = UDim2.new(1, -16, 1, -70),
        Position = UDim2.new(0, 8, 0, 66),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = mainWindow,
    })

    local function SwitchTab(tabName: string)
        self.ActiveTab = tabName
        for name, page in pairs(tabPages) do
            page.Visible = (name == tabName)
        end
        for name, entry in pairs(tabButtons) do
            local isActive = (name == tabName)
            entry.btn.BackgroundColor3 = isActive and PALETTE.BG_CARD or Color3.fromRGB(0, 0, 0)
            entry.btn.BackgroundTransparency = isActive and 0 or 1
            entry.btn.TextColor3 = isActive and PALETTE.TEXT_WHITE or PALETTE.TEXT_DIM
            local iconBody = entry.icon:FindFirstChildWhichIsA("Frame")
            if iconBody then
                iconBody.BackgroundColor3 = isActive and PALETTE.ACCENT_MAGENTA or PALETTE.TEXT_DIM
            end
        end
    end

    tabButtons["FARM"].btn.MouseButton1Click:Connect(function() SwitchTab("FARM") end)
    tabButtons["ZOMBIE"].btn.MouseButton1Click:Connect(function() SwitchTab("ZOMBIE") end)
    tabButtons["SETTINGS"].btn.MouseButton1Click:Connect(function() SwitchTab("SETTINGS") end)

    -- =========================================================================
    -- TAB 1: ФАРМ (Core Farm Dashboard)
    -- =========================================================================
    local pageFarm = Create("Frame", {
        Name = "Page_Farm",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = contentArea,
    })
    tabPages["FARM"] = pageFarm

    -- Status Bar Card (36 px)
    local statusCard = Create("Frame", {
        Name = "StatusCard",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = pageFarm,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("UIStroke", { Color = PALETTE.BORDER_STROKE, Thickness = 1 }),
    })

    local statusDot = Create("Frame", {
        Name = "Dot",
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(0, 10, 0, 8),
        BackgroundColor3 = PALETTE.STATUS_AMBER,
        BorderSizePixel = 0,
        Parent = statusCard,
    }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    self.StatusDot = statusDot

    local statusTitle = Create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -26, 0, 14),
        Position = UDim2.new(0, 24, 0, 5),
        BackgroundTransparency = 1,
        Text = "Статус: Ожидание раунда",
        Font = FONTS.BOLD,
        TextSize = 10,
        TextColor3 = PALETTE.STATUS_AMBER,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = statusCard,
    })
    self.StatusTitle = statusTitle

    local statusDiag = Create("TextLabel", {
        Name = "Diag",
        Size = UDim2.new(1, -26, 0, 12),
        Position = UDim2.new(0, 24, 0, 19),
        BackgroundTransparency = 1,
        Text = "В лобби, ожидание начала раунда...",
        Font = FONTS.REGULAR,
        TextSize = 8.5,
        TextColor3 = PALETTE.TEXT_DIM,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = statusCard,
    })
    self.StatusDiag = statusDiag

    -- Candy Bag Progress Card (48 px)
    local bagCard = Create("Frame", {
        Name = "BagCard",
        Size = UDim2.new(1, 0, 0, 48),
        Position = UDim2.new(0, 0, 0, 42),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = pageFarm,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("UIStroke", { Color = PALETTE.BORDER_STROKE, Thickness = 1 }),
    })

    local bagTitle = Create("TextLabel", {
        Size = UDim2.new(0, 120, 0, 14),
        Position = UDim2.new(0, 10, 0, 6),
        BackgroundTransparency = 1,
        Text = "КОНФЕТЫ В СУМКЕ",
        Font = FONTS.BOLD,
        TextSize = 9,
        TextColor3 = PALETTE.TEXT_MUTED,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = bagCard,
    })

    local valBag = Create("TextLabel", {
        Name = "ValBag",
        Size = UDim2.new(0, 120, 0, 18),
        Position = UDim2.new(1, -130, 0, 4),
        BackgroundTransparency = 1,
        Text = "0 / 40",
        Font = FONTS.BLACK,
        TextSize = 13,
        TextColor3 = PALETTE.TEXT_WHITE,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = bagCard,
    })
    self.ValBag = valBag

    local progressTrack = Create("Frame", {
        Name = "Track",
        Size = UDim2.new(1, -20, 0, 8),
        Position = UDim2.new(0, 10, 0, 28),
        BackgroundColor3 = PALETTE.PROGRESS_BG,
        BorderSizePixel = 0,
        Parent = bagCard,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })

    local progressFill = Create("Frame", {
        Name = "Fill",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = PALETTE.ACCENT_PURPLE,
        BorderSizePixel = 0,
        Parent = progressTrack,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })
    self.BagProgressFill = progressFill

    -- Metric Chips Row (30 px)
    local chipsRow = Create("Frame", {
        Name = "ChipsRow",
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0, 0, 0, 96),
        BackgroundTransparency = 1,
        Parent = pageFarm,
    })

    local chipCollected = Create("Frame", {
        Size = UDim2.new(0.5, -4, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = chipsRow,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
        Create("UIStroke", { Color = PALETTE.BORDER_STROKE, Thickness = 0.8 }),
    })

    local valCollected = Create("TextLabel", {
        Name = "ValCollected",
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1,
        Text = "Собрано: 0",
        Font = FONTS.BOLD,
        TextSize = 9.5,
        TextColor3 = PALETTE.TEXT_WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = chipCollected,
    })
    self.ValCollected = valCollected

    local chipRound = Create("Frame", {
        Size = UDim2.new(0.5, -4, 1, 0),
        Position = UDim2.new(0.5, 4, 0, 0),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = chipsRow,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
        Create("UIStroke", { Color = PALETTE.BORDER_STROKE, Thickness = 0.8 }),
    })

    local valRound = Create("TextLabel", {
        Name = "ValRound",
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1,
        Text = "Раунд: Не начался",
        Font = FONTS.BOLD,
        TextSize = 9.5,
        TextColor3 = PALETTE.TEXT_MUTED,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = chipRound,
    })
    self.ValRound = valRound

    -- Target & Speed Telemetry (18 px)
    local targetLabel = Create("TextLabel", {
        Name = "TargetTelemetry",
        Size = UDim2.new(1, 0, 0, 16),
        Position = UDim2.new(0, 0, 0, 130),
        BackgroundTransparency = 1,
        Text = "Скорость: 36 ст/с • Дистанция цели: 0 м",
        Font = FONTS.REGULAR,
        TextSize = 8.5,
        TextColor3 = PALETTE.TEXT_DIM,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = pageFarm,
    })
    self.TargetTelemetry = targetLabel

    -- Primary Farm Start/Stop Button (38 px)
    local primaryBtn = Create("TextButton", {
        Name = "PrimaryBtn",
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.new(0, 0, 1, -38),
        BackgroundColor3 = PALETTE.STATUS_GREEN,
        BorderSizePixel = 0,
        Text = "НАЧАТЬ ФАРМ",
        Font = FONTS.BLACK,
        TextSize = 12,
        TextColor3 = PALETTE.TEXT_WHITE,
        Parent = pageFarm,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("UIStroke", { Color = Color3.fromRGB(52, 211, 153), Thickness = 1.2 }),
    })
    self.PrimaryBtn = primaryBtn

    primaryBtn.MouseButton1Click:Connect(function()
        self:ToggleFarming()
    end)

    -- =========================================================================
    -- TAB 2: ЗОМБИ (Dedicated MM2 Zombie & Infection Mode)
    -- =========================================================================
    local pageZombie = Create("Frame", {
        Name = "Page_Zombie",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = contentArea,
    })
    tabPages["ZOMBIE"] = pageZombie

    local zombieStatusCard = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = pageZombie,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("UIStroke", { Color = PALETTE.BORDER_STROKE, Thickness = 1 }),
    })

    local zDot = Create("Frame", {
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = Color3.fromRGB(34, 197, 94),
        BorderSizePixel = 0,
        Parent = zombieStatusCard,
    }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

    local zombieTitle = Create("TextLabel", {
        Name = "ZombieTitle",
        Size = UDim2.new(1, -26, 0, 14),
        Position = UDim2.new(0, 24, 0, 7),
        BackgroundTransparency = 1,
        Text = "РЕЖИМ ЗОМБИ / INFECTION",
        Font = FONTS.BOLD,
        TextSize = 9.5,
        TextColor3 = Color3.fromRGB(74, 222, 128),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = zombieStatusCard,
    })

    local zombieDiag = Create("TextLabel", {
        Name = "ZombieDiag",
        Size = UDim2.new(1, -26, 0, 14),
        Position = UDim2.new(0, 24, 0, 23),
        BackgroundTransparency = 1,
        Text = "Ожидание раунда Infection / Хэллоуин",
        Font = FONTS.REGULAR,
        TextSize = 8.5,
        TextColor3 = PALETTE.TEXT_DIM,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = zombieStatusCard,
    })
    self.ZombieDiag = zombieDiag

    -- Zombie Counter Card
    local zombieCountCard = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        Position = UDim2.new(0, 0, 0, 50),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = pageZombie,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("UIStroke", { Color = PALETTE.BORDER_STROKE, Thickness = 1 }),
    })

    local zCountLabel = Create("TextLabel", {
        Size = UDim2.new(0.6, 0, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "Зомби обнаружено:",
        Font = FONTS.BOLD,
        TextSize = 10,
        TextColor3 = PALETTE.TEXT_MUTED,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = zombieCountCard,
    })

    local valZombieCount = Create("TextLabel", {
        Name = "ValZombieCount",
        Size = UDim2.new(0.35, 0, 1, 0),
        Position = UDim2.new(0.65, -10, 0, 0),
        BackgroundTransparency = 1,
        Text = "0",
        Font = FONTS.BLACK,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(74, 222, 128),
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = zombieCountCard,
    })
    self.ValZombieCount = valZombieCount

    -- Diagnostic Note
    local zombieNote = Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 34),
        Position = UDim2.new(0, 0, 0, 98),
        BackgroundTransparency = 1,
        Text = "Модуль изолирован от сбора конфет. Уклонение и авто-прицел активируются строго в раундах с зомби.",
        Font = FONTS.REGULAR,
        TextSize = 8,
        TextColor3 = PALETTE.TEXT_DIM,
        TextWrapped = true,
        Parent = pageZombie,
    })

    -- Toggle Zombie Action Button
    local zombieBtn = Create("TextButton", {
        Name = "ZombieBtn",
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.new(0, 0, 1, -38),
        BackgroundColor3 = PALETTE.BG_CONTAINER,
        BorderSizePixel = 0,
        Text = "ВКЛЮЧИТЬ МОДУЛЬ ЗОМБИ",
        Font = FONTS.BOLD,
        TextSize = 11,
        TextColor3 = PALETTE.TEXT_WHITE,
        Parent = pageZombie,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("UIStroke", { Color = Color3.fromRGB(34, 197, 94), Thickness = 1 }),
    })
    self.ZombieBtn = zombieBtn

    zombieBtn.MouseButton1Click:Connect(function()
        self.IsZombieMode = not self.IsZombieMode
        if self.IsZombieMode then
            zombieBtn.Text = "ОТКЛЮЧИТЬ МОДУЛЬ ЗОМБИ"
            zombieBtn.BackgroundColor3 = Color3.fromRGB(185, 28, 28)
        else
            zombieBtn.Text = "ВКЛЮЧИТЬ МОДУЛЬ ЗОМБИ"
            zombieBtn.BackgroundColor3 = PALETTE.BG_CONTAINER
        end
        if self.Callbacks.OnToggleZombie then
            self.Callbacks.OnToggleZombie(self.IsZombieMode)
        end
    end)

    -- =========================================================================
    -- TAB 3: НАСТРОЙКИ (Settings & High FPS Controller)
    -- =========================================================================
    local pageSettings = Create("ScrollingFrame", {
        Name = "Page_Settings",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = PALETTE.ACCENT_PURPLE,
        CanvasSize = UDim2.new(0, 0, 0, 240),
        Visible = false,
        Parent = contentArea,
    })
    tabPages["SETTINGS"] = pageSettings

    -- High FPS Mode Toggle Row
    local function CreateToggleItem(yPos: number, titleText: string, defaultVal: boolean, onToggle: (boolean) -> ()): Frame
        local row = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 30),
            Position = UDim2.new(0, 0, 0, yPos),
            BackgroundColor3 = PALETTE.BG_CARD,
            BorderSizePixel = 0,
            Parent = pageSettings,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
            Create("UIStroke", { Color = PALETTE.BORDER_STROKE, Thickness = 0.8 }),
        })

        local lbl = Create("TextLabel", {
            Size = UDim2.new(1, -50, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1,
            Text = titleText,
            Font = FONTS.BOLD,
            TextSize = 9.5,
            TextColor3 = PALETTE.TEXT_WHITE,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        local switch = Create("Frame", {
            Size = UDim2.new(0, 32, 0, 16),
            Position = UDim2.new(1, -40, 0.5, -8),
            BackgroundColor3 = defaultVal and PALETTE.STATUS_GREEN or PALETTE.BG_CONTAINER,
            BorderSizePixel = 0,
            Parent = row,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

        local knob = Create("Frame", {
            Size = UDim2.new(0, 12, 0, 12),
            Position = defaultVal and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
            BackgroundColor3 = PALETTE.TEXT_WHITE,
            BorderSizePixel = 0,
            Parent = switch,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

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
                Tween(switch, 0.15, { BackgroundColor3 = PALETTE.STATUS_GREEN })
                Tween(knob, 0.15, { Position = UDim2.new(1, -14, 0.5, -6) })
            else
                Tween(switch, 0.15, { BackgroundColor3 = PALETTE.BG_CONTAINER })
                Tween(knob, 0.15, { Position = UDim2.new(0, 2, 0.5, -6) })
            end
            onToggle(state)
        end)

        return row
    end

    CreateToggleItem(0, "ВЫСОКИЙ FPS (Бустер графики)", self.Settings.PerfMode, function(val)
        self.Settings.PerfMode = val
        if self.Callbacks.OnPerfModeChanged then self.Callbacks.OnPerfModeChanged(val) end
    end)

    -- Speed Mode Selector Row
    local speedRow = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        Position = UDim2.new(0, 0, 0, 34),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = pageSettings,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
        Create("UIStroke", { Color = PALETTE.BORDER_STROKE, Thickness = 0.8 }),
    })

    local speedLabel = Create("TextLabel", {
        Size = UDim2.new(1, -20, 0, 14),
        Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1,
        Text = "Скорость движения (непрерывно)",
        Font = FONTS.BOLD,
        TextSize = 9,
        TextColor3 = PALETTE.TEXT_MUTED,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = speedRow,
    })

    local speedButtons = {}
    local speedModes = { "Обычная", "Быстрая", "Турбо" }
    for i, modeName in ipairs(speedModes) do
        local btn = Create("TextButton", {
            Size = UDim2.new(0.31, 0, 0, 18),
            Position = UDim2.new((i - 1) * 0.34, 4, 0, 20),
            BackgroundColor3 = (self.Settings.FarmSpeed == modeName) and PALETTE.ACCENT_PURPLE or PALETTE.BG_CONTAINER,
            BorderSizePixel = 0,
            Text = modeName,
            Font = FONTS.BOLD,
            TextSize = 9,
            TextColor3 = PALETTE.TEXT_WHITE,
            Parent = speedRow,
        }, { Create("UICorner", { CornerRadius = UDim.new(0, 4) }) })

        speedButtons[modeName] = btn
        btn.MouseButton1Click:Connect(function()
            self.Settings.FarmSpeed = modeName
            for k, b in pairs(speedButtons) do
                b.BackgroundColor3 = (k == modeName) and PALETTE.ACCENT_PURPLE or PALETTE.BG_CONTAINER
            end
            if self.Callbacks.OnSpeedChanged then
                self.Callbacks.OnSpeedChanged(modeName)
            end
        end)
    end

    CreateToggleItem(80, "Безопасное укрытие", self.Settings.SafePlatform, function(val)
        self.Settings.SafePlatform = val
        if self.Callbacks.OnSafePlatformChanged then self.Callbacks.OnSafePlatformChanged(val) end
    end)

    CreateToggleItem(114, "Авто-возобновление", self.Settings.AutoResume, function(val)
        self.Settings.AutoResume = val
        if self.Callbacks.OnAutoResumeChanged then self.Callbacks.OnAutoResumeChanged(val) end
    end)

    CreateToggleItem(148, "Защита Anti-AFK", self.Settings.AntiAFK, function(val)
        self.Settings.AntiAFK = val
        if self.Callbacks.OnAntiAFKChanged then self.Callbacks.OnAntiAFKChanged(val) end
    end)

    -- Telemetry Row
    local fpsLabel = Create("TextLabel", {
        Name = "FpsTelemetry",
        Size = UDim2.new(1, 0, 0, 16),
        Position = UDim2.new(0, 0, 0, 182),
        BackgroundTransparency = 1,
        Text = "Частота: 60.0 FPS • Задержка: 16.6 мс",
        Font = FONTS.REGULAR,
        TextSize = 8.5,
        TextColor3 = PALETTE.TEXT_DIM,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = pageSettings,
    })
    self.FpsTelemetry = fpsLabel

    -- Unload & Reset Action Row
    local unloadBtn = Create("TextButton", {
        Name = "UnloadBtn",
        Size = UDim2.new(0.48, 0, 0, 26),
        Position = UDim2.new(0, 0, 0, 204),
        BackgroundColor3 = Color3.fromRGB(60, 20, 25),
        BorderSizePixel = 0,
        Text = "Выгрузить скрипт",
        Font = FONTS.BOLD,
        TextSize = 9.5,
        TextColor3 = Color3.fromRGB(255, 140, 140),
        Parent = pageSettings,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
        Create("UIStroke", { Color = Color3.fromRGB(150, 40, 50), Thickness = 1 }),
    })

    unloadBtn.MouseButton1Click:Connect(function()
        if self.Callbacks.OnUnload then
            self.Callbacks.OnUnload()
        end
    end)

    local resetBtn = Create("TextButton", {
        Name = "ResetBtn",
        Size = UDim2.new(0.48, 0, 0, 26),
        Position = UDim2.new(0.52, 0, 0, 204),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Text = "Сбросить опции",
        Font = FONTS.BOLD,
        TextSize = 9.5,
        TextColor3 = PALETTE.TEXT_MUTED,
        Parent = pageSettings,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
        Create("UIStroke", { Color = PALETTE.BORDER_STROKE, Thickness = 1 }),
    })

    resetBtn.MouseButton1Click:Connect(function()
        if self.Callbacks.OnResetSettings then
            self.Callbacks.OnResetSettings()
        end
    end)

    return self
end

function MobileUI:ToggleFarming()
    self.IsFarming = not self.IsFarming

    if self.IsFarming then
        self.PrimaryBtn.Text = "ОСТАНОВИТЬ ФАРМ"
        self.PrimaryBtn.BackgroundColor3 = PALETTE.STATUS_RED
        self:SetStatus("Сбор конфет", "Поиск и непрерывное движение к цели...")
    else
        self.PrimaryBtn.Text = "НАЧАТЬ ФАРМ"
        self.PrimaryBtn.BackgroundColor3 = PALETTE.STATUS_GREEN
        self:SetStatus("Ожидание раунда", "Фарм остановлен пользователем")
    end

    if self.Callbacks.OnToggleFarm then
        self.Callbacks.OnToggleFarm(self.IsFarming)
    end
end

-- Update Status & Diagnostic in Russian
function MobileUI:SetStatus(statusTitleText: string, diagnosticMessage: string?)
    self.CurrentStatus = statusTitleText

    local dotColor = PALETTE.STATUS_AMBER

    if statusTitleText == "Сбор конфет" or statusTitleText == "Собираю конфеты" or statusTitleText == "Поиск конфет" then
        dotColor = PALETTE.STATUS_GREEN
    elseif statusTitleText == "Сумка заполнена" or statusTitleText == "Ошибка" or statusTitleText == "Конфета не подобрана" then
        dotColor = PALETTE.STATUS_RED
    elseif statusTitleText == "Раунд завершён" or statusTitleText == "Ожидание следующего раунда" then
        dotColor = PALETTE.STATUS_AMBER
    end

    if self.StatusDot then self.StatusDot.BackgroundColor3 = dotColor end
    if self.PillDot then self.PillDot.BackgroundColor3 = dotColor end

    if self.StatusTitle then
        self.StatusTitle.Text = "Статус: " .. statusTitleText
        self.StatusTitle.TextColor3 = dotColor
    end

    if diagnosticMessage and self.StatusDiag then
        self.StatusDiag.Text = diagnosticMessage
    end
end

function MobileUI:UpdateMetrics(metrics: {
    bagCurrent: number?,
    bagMax: number?,
    totalCandies: number?,
    roundName: string?,
    targetDistance: number?,
    fps: number?,
})
    if not metrics then return end

    if metrics.bagCurrent ~= nil and metrics.bagMax ~= nil then
        self.ValBag.Text = string.format("%d / %d", metrics.bagCurrent, metrics.bagMax)
        if self.PillLabel then
            self.PillLabel.Text = string.format("%d / %d", metrics.bagCurrent, metrics.bagMax)
        end

        local progress = math.clamp(metrics.bagCurrent / math.max(metrics.bagMax, 1), 0, 1)
        Tween(self.BagProgressFill, 0.15, { Size = UDim2.new(progress, 0, 1, 0) })
        if progress >= 1 then
            self.BagProgressFill.BackgroundColor3 = PALETTE.STATUS_RED
        else
            self.BagProgressFill.BackgroundColor3 = PALETTE.ACCENT_PURPLE
        end
    end

    if metrics.totalCandies ~= nil then
        self.ValCollected.Text = string.format("Собрано: %d", metrics.totalCandies)
    end

    if metrics.roundName ~= nil then
        self.ValRound.Text = "Раунд: " .. metrics.roundName
    end

    if metrics.targetDistance ~= nil then
        local spd = self.Settings.FarmSpeed
        self.TargetTelemetry.Text = string.format("Скорость: %s • Дистанция: %d м", spd, math.floor(metrics.targetDistance))
    end

    if metrics.fps ~= nil and self.FpsTelemetry then
        local frameMs = (metrics.fps > 0) and (1000 / metrics.fps) or 16.6
        self.FpsTelemetry.Text = string.format("Частота: %.1f FPS • Задержка: %.1f мс", metrics.fps, frameMs)
    end
end

function MobileUI:UpdateZombieMetrics(zombieData: {
    isEnabled: boolean?,
    isActive: boolean?,
    zombieCount: number?,
    status: string?,
})
    if not zombieData then return end
    if zombieData.zombieCount ~= nil and self.ValZombieCount then
        self.ValZombieCount.Text = tostring(zombieData.zombieCount)
    end
    if zombieData.status ~= nil and self.ZombieDiag then
        self.ZombieDiag.Text = zombieData.status
    end
end

function MobileUI:Destroy()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end
end

return MobileUI
