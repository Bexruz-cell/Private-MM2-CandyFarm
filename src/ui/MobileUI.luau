--[[
    MM2 Delta Android Mobile GUI/UX Engine - NEBULA PRO + MIDNIGHT
    Architect: Subagent 2: UI Architecture Specialist (MM2 Candy Farm Council)
    Platform: Delta Executor on Android (Roblox Mobile CoreGui & Touch Engine)
    Standard: 100% Pure Luau (Instance.new), Zero Emojis, Zero External Dependencies
    Target Dimensions: 336x248 px (Window), 118x32 px (Floating Mini-HUD)
    Tabs: ФАРМ, ЗОМБИ, ИГРОК, НАСТРОЙКИ
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- Unique ScreenGui Identifier for single-instance control
local UI_NAME = "MM2_Delta_NebulaMidnight_UI"

-- Design Tokens: NEBULA PRO + MIDNIGHT Hybrid Palette
local PALETTE = {
    -- Background Layers
    BG_MAIN          = Color3.fromRGB(13, 11, 22),    -- #0d0b16 Main window background
    BG_CARD          = Color3.fromRGB(20, 17, 34),    -- #141122 Elevated cards & panels
    BG_CONTAINER     = Color3.fromRGB(30, 25, 50),    -- #1e1932 Control wells & recessed slots
    BG_INPUT         = Color3.fromRGB(24, 20, 40),    -- #181428 Inactive pill / switch background
    
    -- Borders & Separators
    BORDER_SUBTLE    = Color3.fromRGB(48, 38, 80),    -- #302650 1px subtle divider
    BORDER_ACCENT    = Color3.fromRGB(90, 52, 160),   -- #5a34a0 Focused card border
    BORDER_GLOW      = Color3.fromRGB(140, 80, 255),  -- #8c50ff Active glow stroke
    
    -- Accents (Nebula Pro Cosmic Violet + Midnight Indigo & Sky)
    ACCENT_PURPLE    = Color3.fromRGB(168, 85, 247),  -- #a855f7 Nebula bright violet
    ACCENT_INDIGO    = Color3.fromRGB(99, 102, 241),  -- #6366f1 Midnight electric indigo
    ACCENT_CYAN      = Color3.fromRGB(56, 189, 248),  -- #38bdf8 Telemetry cyan
    ACCENT_MAGENTA   = Color3.fromRGB(217, 70, 239),  -- #d946ef Laser magenta
    
    -- Functional Status Colors
    STATUS_ACTIVE    = Color3.fromRGB(34, 197, 94),   -- #22c55e Active farm / safe green
    STATUS_ALERT     = Color3.fromRGB(239, 68, 68),   -- #ef4444 Stop / bag full red
    STATUS_WARN      = Color3.fromRGB(245, 158, 11),  -- #f59e0b Intermission / round wait amber
    STATUS_IDLE      = Color3.fromRGB(100, 116, 139), -- #64748b Standby / idle slate
    STATUS_ZOMBIE    = Color3.fromRGB(16, 185, 129),  -- #10b981 Toxic zombie defense green
    
    -- Typography Hierarchy
    TEXT_WHITE       = Color3.fromRGB(255, 255, 255),
    TEXT_PRIMARY     = Color3.fromRGB(241, 245, 249),
    TEXT_MUTED       = Color3.fromRGB(148, 163, 184),
    TEXT_DIM         = Color3.fromRGB(100, 116, 139),
    TEXT_VIOLET      = Color3.fromRGB(192, 132, 252),
    
    -- Progress Bar
    PROGRESS_BG      = Color3.fromRGB(24, 20, 42),
}

local FONTS = {
    REGULAR = Enum.Font.GothamMedium,
    BOLD    = Enum.Font.GothamBold,
    BLACK   = Enum.Font.GothamBlack,
}

-- Safe Parent Resolver for Delta Executor on Android
local function GetSafeGuiParent(): Instance
    if typeof(gethui) == "function" then
        local success, hui = pcall(gethui)
        if success and hui then
            return hui
        end
    end
    local success, core = pcall(function()
        return CoreGui
    end)
    if success and core then
        return core
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- Clean Instance Builder
local function Create(className: string, properties: { [string]: any }, children: { Instance }?): Instance
    local inst = Instance.new(className)
    for k, v in pairs(properties or {}) do
        inst[k] = v
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    return inst
end

-- Quick Tween
local function Tween(inst: Instance, duration: number, properties: { [string]: any }, easingStyle: Enum.EasingStyle?, easingDirection: Enum.EasingDirection?)
    local info = TweenInfo.new(
        duration,
        easingStyle or Enum.EasingStyle.Quad,
        easingDirection or Enum.EasingDirection.Out
    )
    local tw = TweenService:Create(inst, info, properties)
    tw:Play()
    return tw
end

-- Viewport Clamping & Mobile Touch-Safe Margins
local function ClampFrameToSafeBounds(frame: GuiObject, rawPos: UDim2, marginOptional: number?): UDim2
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
    local vw, vh = viewport.X, viewport.Y
    local fw = frame.AbsoluteSize.X > 0 and frame.AbsoluteSize.X or frame.Size.X.Offset
    local fh = frame.AbsoluteSize.Y > 0 and frame.AbsoluteSize.Y or frame.Size.Y.Offset

    local margin = marginOptional or 10
    local minX = margin
    local maxX = math.max(minX, vw - fw - margin)
    local minY = 38 -- Clear Roblox top-bar and camera notch
    local maxY = math.max(minY, vh - fh - margin)

    local targetX = math.clamp(rawPos.X.Offset, minX, maxX)
    local targetY = math.clamp(rawPos.Y.Offset, minY, maxY)

    -- Left Virtual Joystick Exclusion Zone: [0..155, vh - 155..vh]
    local inJoystickX = targetX < 155
    local inJoystickY = (targetY + fh) > (vh - 155)
    if inJoystickX and inJoystickY then
        if (vh - 155 - fh - 6) >= minY then
            targetY = vh - 155 - fh - 6
        else
            targetX = 160
        end
    end

    -- Right Jump Button Exclusion Zone: [vw - 85..vw, vh - 85..vh]
    local inJumpX = (targetX + fw) > (vw - 85)
    local inJumpY = (targetY + fh) > (vh - 85)
    if inJumpX and inJumpY then
        if (vh - 85 - fh - 6) >= minY then
            targetY = vh - 85 - fh - 6
        else
            targetX = math.max(minX, vw - 85 - fw - 6)
        end
    end

    return UDim2.new(0, targetX, 0, targetY)
end

-- Mobile Touch & Mouse Draggable Handler with Safe Bounds Clamping
local function MakeDraggable(dragHandle: GuiObject, targetFrame: GuiObject, onDragEnded: (() -> ())?)
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
                    if onDragEnded then
                        onDragEnded()
                    end
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
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            local rawPos = UDim2.new(0, startPos.X.Offset + delta.X, 0, startPos.Y.Offset + delta.Y)
            targetFrame.Position = ClampFrameToSafeBounds(targetFrame, rawPos)
        end
    end)
end

-- Fallback Icon Primitive Engine (Self-contained vector builder)
local PrimitiveIcons = {}
do
    local DEFAULT_COLOR = Color3.fromRGB(240, 240, 255)

    function PrimitiveIcons.CreateCandy(size: UDim2?, color: Color3?, accentColor: Color3?): Frame
        local c = color or DEFAULT_COLOR
        local acc = accentColor or PALETTE.ACCENT_PURPLE
        local cont = Create("Frame", { Size = size or UDim2.fromOffset(18, 18), BackgroundTransparency = 1 })
        local body = Create("Frame", {
            Size = UDim2.new(0.52, 0, 0.52, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            Rotation = 45,
            Parent = cont,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0.4, 0) }),
            Create("UIStroke", { Color = acc, Thickness = 1, Transparency = 0.2 })
        })
        Create("Frame", {
            Size = UDim2.new(0.24, 0, 0.8, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = acc,
            Parent = body,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.24, 0, 0.38, 0),
            Position = UDim2.new(0.18, 0, 0.18, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = acc,
            Rotation = 15,
            Parent = cont,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.24, 0, 0.38, 0),
            Position = UDim2.new(0.82, 0, 0.82, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = acc,
            Rotation = 15,
            Parent = cont,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
        return cont
    end

    function PrimitiveIcons.CreateZombie(size: UDim2?, color: Color3?, eyeColor: Color3?): Frame
        local c = color or PALETTE.STATUS_ZOMBIE
        local bg = eyeColor or PALETTE.BG_MAIN
        local cont = Create("Frame", { Size = size or UDim2.fromOffset(18, 18), BackgroundTransparency = 1 })
        local cranium = Create("Frame", {
            Size = UDim2.new(0.68, 0, 0.52, 0),
            Position = UDim2.new(0.5, 0, 0.32, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            Parent = cont,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.24, 0, 0.34, 0),
            Position = UDim2.new(0.32, 0, 0.52, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = bg,
            Parent = cranium,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.24, 0, 0.34, 0),
            Position = UDim2.new(0.68, 0, 0.52, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = bg,
            Parent = cranium,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        local jaw = Create("Frame", {
            Size = UDim2.new(0.44, 0, 0.28, 0),
            Position = UDim2.new(0.5, 0, 0.68, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            Parent = cont,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.25, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.12, 0, 0.55, 0),
            Position = UDim2.new(0.36, 0, 0.72, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = bg,
            Parent = jaw,
        })
        Create("Frame", {
            Size = UDim2.new(0.12, 0, 0.55, 0),
            Position = UDim2.new(0.64, 0, 0.72, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = bg,
            Parent = jaw,
        })
        return cont
    end

    function PrimitiveIcons.CreatePlayer(size: UDim2?, color: Color3?): Frame
        local c = color or PALETTE.ACCENT_INDIGO
        local cont = Create("Frame", { Size = size or UDim2.fromOffset(18, 18), BackgroundTransparency = 1 })
        Create("Frame", {
            Size = UDim2.new(0.38, 0, 0.38, 0),
            Position = UDim2.new(0.5, 0, 0.25, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            Parent = cont,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.70, 0, 0.40, 0),
            Position = UDim2.new(0.5, 0, 0.68, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            Parent = cont,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.45, 0) }) })
        return cont
    end

    function PrimitiveIcons.CreateSettings(size: UDim2?, color: Color3?, holeColor: Color3?): Frame
        local c = color or DEFAULT_COLOR
        local bg = holeColor or PALETTE.BG_MAIN
        local cont = Create("Frame", { Size = size or UDim2.fromOffset(18, 18), BackgroundTransparency = 1 })
        for _, ang in ipairs({ 0, 45, 90, 135 }) do
            Create("Frame", {
                Size = UDim2.new(0.78, 0, 0.22, 0),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = c,
                Rotation = ang,
                Parent = cont,
            }, { Create("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
        end
        local hub = Create("Frame", {
            Size = UDim2.new(0.6, 0, 0.6, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            Parent = cont,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.28, 0, 0.28, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = bg,
            Parent = hub,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        return cont
    end

    function PrimitiveIcons.CreateQuickToggle(size: UDim2?, isPlaying: boolean?, color: Color3?): Frame
        local c = color or PALETTE.TEXT_WHITE
        local cont = Create("Frame", { Size = size or UDim2.fromOffset(14, 14), BackgroundTransparency = 1 })
        if isPlaying then
            Create("Frame", {
                Size = UDim2.new(0.24, 0, 0.68, 0),
                Position = UDim2.new(0.32, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = c,
                Parent = cont,
            }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
            Create("Frame", {
                Size = UDim2.new(0.24, 0, 0.68, 0),
                Position = UDim2.new(0.68, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = c,
                Parent = cont,
            }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        else
            Create("Frame", {
                Size = UDim2.new(0.54, 0, 0.18, 0),
                Position = UDim2.new(0.32, 0, 0.35, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = c,
                Rotation = 30,
                Parent = cont,
            }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
            Create("Frame", {
                Size = UDim2.new(0.54, 0, 0.18, 0),
                Position = UDim2.new(0.32, 0, 0.65, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = c,
                Rotation = -30,
                Parent = cont,
            }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
            Create("Frame", {
                Size = UDim2.new(0.18, 0, 0.62, 0),
                Position = UDim2.new(0.32, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = c,
                Parent = cont,
            }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        end
        return cont
    end
end

-- Module Table
local MM2_MobileUI = {}
MM2_MobileUI.__index = MM2_MobileUI

function MM2_MobileUI.Init(userCallbacks)
    userCallbacks = userCallbacks or {}
    local self = setmetatable({}, MM2_MobileUI)

    -- Runtime State
    self.IsFarming = false
    self.CurrentStatus = "IDLE"
    self.ActiveTabIndex = 1
    self.Settings = {
        FarmSpeed = "Fast",             -- Normal (28), Fast (36), Turbo (44)
        BagCapacity = "Auto",            -- Auto, 40, 50
        SafePlatform = true,
        AutoResume = true,
        AntiAFK = true,
        HighFPS = false,
        ZombieAutoDefend = true,
        ZombieThreatRadius = "20m",      -- 15m, 20m, 28m
        ZombiePriority = "Closest",      -- Closest, Hunter, Boss
        Noclip = false,
        JumpMode = "Normal",            -- Normal, High, Infinite
        AntiFling = true,
        AutoReconnect = true,
        SafeDock = true,
    }
    self.Callbacks = userCallbacks

    -- 1. Remove previous instance
    local safeParent = GetSafeGuiParent()
    local existing = safeParent:FindFirstChild(UI_NAME)
    if existing then
        existing:Destroy()
    end

    -- 2. Root ScreenGui
    local screenGui = Create("ScreenGui", {
        Name = UI_NAME,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
        Parent = safeParent,
    })
    self.ScreenGui = screenGui

    -- 3. Compact Floating Mini-HUD (118x32 px)
    local miniHud = Create("Frame", {
        Name = "FloatingMiniHUD",
        Size = UDim2.new(0, 118, 0, 32),
        Position = UDim2.new(0.5, -59, 0, 20), -- Default top-center below notch
        BackgroundColor3 = PALETTE.BG_MAIN,
        BorderSizePixel = 0,
        Active = true,
        Parent = screenGui,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 16) }),
        Create("UIStroke", {
            Color = PALETTE.ACCENT_PURPLE,
            Thickness = 1.2,
            Transparency = 0.25,
        }),
        Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, PALETTE.BG_CARD),
                ColorSequenceKeypoint.new(1, PALETTE.BG_MAIN),
            }),
            Rotation = 90,
        }),
    })
    self.MiniHUD = miniHud

    -- Mini-HUD Status Beacon Dot with Halo
    local miniHalo = Create("Frame", {
        Name = "StatusHalo",
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, 7, 0.5, -6),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = miniHud,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
        Create("UIStroke", {
            Color = PALETTE.STATUS_IDLE,
            Thickness = 1,
            Transparency = 0.4,
        })
    })
    self.MiniHalo = miniHalo

    local miniStatusDot = Create("Frame", {
        Name = "StatusDot",
        Size = UDim2.new(0, 6, 0, 6),
        Position = UDim2.new(0.5, -3, 0.5, -3),
        BackgroundColor3 = PALETTE.STATUS_IDLE,
        BorderSizePixel = 0,
        Parent = miniHalo,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })
    self.MiniStatusDot = miniStatusDot

    -- Mini-HUD Live Telemetry Label
    local miniTelemetry = Create("TextLabel", {
        Name = "MiniTelemetry",
        Size = UDim2.new(0, 64, 1, 0),
        Position = UDim2.new(0, 22, 0, 0),
        BackgroundTransparency = 1,
        Text = "[ГОТОВ]",
        Font = FONTS.BOLD,
        TextSize = 10,
        TextColor3 = PALETTE.TEXT_WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = miniHud,
    })
    self.MiniTelemetry = miniTelemetry

    -- Mini-HUD Quick-Toggle Action Button (22x22 px)
    local miniQuickToggle = Create("TextButton", {
        Name = "QuickToggle",
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(1, -26, 0.5, -11),
        BackgroundColor3 = PALETTE.BG_CONTAINER,
        Text = "",
        BorderSizePixel = 0,
        Parent = miniHud,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 11) }),
        Create("UIStroke", {
            Color = PALETTE.BORDER_ACCENT,
            Thickness = 1,
        }),
    })
    self.MiniQuickToggle = miniQuickToggle

    local miniToggleIconContainer = Create("Frame", {
        Name = "IconContainer",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Parent = miniQuickToggle,
    })
    self.MiniToggleIconContainer = miniToggleIconContainer

    local function RefreshMiniToggleIcon()
        miniToggleIconContainer:ClearAllChildren()
        local icon = PrimitiveIcons.CreateQuickToggle(UDim2.new(0, 12, 0, 12), self.IsFarming, PALETTE.TEXT_WHITE)
        icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Parent = miniToggleIconContainer
        if self.IsFarming then
            miniQuickToggle.BackgroundColor3 = PALETTE.STATUS_ALERT
        else
            miniQuickToggle.BackgroundColor3 = PALETTE.STATUS_ACTIVE
        end
    end
    RefreshMiniToggleIcon()

    MakeDraggable(miniHud, miniHud)

    -- 4. Main Window (336x248 px - Nebula Pro + Midnight)
    local mainWindow = Create("Frame", {
        Name = "MainWindow",
        Size = UDim2.new(0, 336, 0, 248),
        Position = UDim2.new(0.5, -168, 0.5, -124),
        BackgroundColor3 = PALETTE.BG_MAIN,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Parent = screenGui,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
        Create("UIStroke", {
            Color = PALETTE.BORDER_SUBTLE,
            Thickness = 1.2,
        }),
    })
    self.MainWindow = mainWindow

    -- Viewport Clamping initial safeguard
    mainWindow.Position = ClampFrameToSafeBounds(mainWindow, mainWindow.Position)
    miniHud.Position = ClampFrameToSafeBounds(miniHud, miniHud.Position)

    local cam = workspace.CurrentCamera
    if cam then
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if mainWindow and mainWindow.Visible then
                mainWindow.Position = ClampFrameToSafeBounds(mainWindow, mainWindow.Position)
            end
            if miniHud then
                miniHud.Position = ClampFrameToSafeBounds(miniHud, miniHud.Position)
            end
        end)
    end

    -- 4.1 Header Bar (30px)
    local header = Create("Frame", {
        Name = "HeaderBar",
        Size = UDim2.new(1, 0, 0, 30),
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

    local headerIconContainer = Create("Frame", {
        Name = "HeaderIcon",
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(0, 10, 0.5, -8),
        BackgroundTransparency = 1,
        Parent = header,
    })
    local hIcon = PrimitiveIcons.CreateCandy(UDim2.new(1, 0, 1, 0), PALETTE.TEXT_WHITE, PALETTE.ACCENT_PURPLE)
    hIcon.Parent = headerIconContainer

    local title = Create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0, 140, 1, 0),
        Position = UDim2.new(0, 30, 0, 0),
        BackgroundTransparency = 1,
        Text = "NEBULA MIDNIGHT",
        Font = FONTS.BLACK,
        TextSize = 11,
        TextColor3 = PALETTE.TEXT_WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    local versionBadge = Create("TextLabel", {
        Name = "VersionBadge",
        Size = UDim2.new(0, 62, 0, 15),
        Position = UDim2.new(0, 172, 0.5, -7),
        BackgroundColor3 = PALETTE.BG_CONTAINER,
        Text = "DELTA MOB",
        Font = FONTS.BOLD,
        TextSize = 8.5,
        TextColor3 = PALETTE.ACCENT_PURPLE,
        Parent = header,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
    })

    local minimizeBtn = Create("TextButton", {
        Name = "MinBtn",
        Size = UDim2.new(0, 24, 0, 20),
        Position = UDim2.new(1, -54, 0.5, -10),
        BackgroundColor3 = PALETTE.BG_CONTAINER,
        Text = "[-]",
        Font = FONTS.BOLD,
        TextSize = 10,
        TextColor3 = PALETTE.TEXT_MUTED,
        Parent = header,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 5) }),
    })

    local closeBtn = Create("TextButton", {
        Name = "CloseBtn",
        Size = UDim2.new(0, 24, 0, 20),
        Position = UDim2.new(1, -27, 0.5, -10),
        BackgroundColor3 = Color3.fromRGB(44, 20, 28),
        Text = "[X]",
        Font = FONTS.BOLD,
        TextSize = 10,
        TextColor3 = PALETTE.STATUS_ALERT,
        Parent = header,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 5) }),
    })

    MakeDraggable(header, mainWindow)

    -- Window Minimize / Toggle Logic
    local function ToggleMainWindow()
        local isVisible = mainWindow.Visible
        if isVisible then
            Tween(mainWindow, 0.16, { Size = UDim2.new(0, 310, 0, 220), BackgroundTransparency = 0.6 })
            task.delay(0.16, function()
                mainWindow.Visible = false
                mainWindow.Size = UDim2.new(0, 336, 0, 248)
                mainWindow.BackgroundTransparency = 0
            end)
        else
            mainWindow.Visible = true
            mainWindow.Size = UDim2.new(0, 310, 0, 220)
            mainWindow.BackgroundTransparency = 0.4
            Tween(mainWindow, 0.16, { Size = UDim2.new(0, 336, 0, 248), BackgroundTransparency = 0 })
        end
    end

    minimizeBtn.MouseButton1Click:Connect(ToggleMainWindow)
    closeBtn.MouseButton1Click:Connect(ToggleMainWindow)

    -- Quick-toggle button direct action
    miniQuickToggle.MouseButton1Click:Connect(function()
        self:ToggleFarming()
        RefreshMiniToggleIcon()
    end)

    -- Mini-HUD Body Tap expands Window
    miniHud.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local startTime = tick()
            local endedConn
            endedConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    endedConn:Disconnect()
                    if (tick() - startTime) < 0.25 then
                        ToggleMainWindow()
                    end
                end
            end)
        end
    end)

    -- 4.2 Navigation Tab Bar (4 TABS: ФАРМ, ЗОМБИ, ИГРОК, НАСТРОЙКИ)
    local tabBar = Create("Frame", {
        Name = "TabBar",
        Size = UDim2.new(1, -16, 0, 26),
        Position = UDim2.new(0, 8, 0, 34),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = mainWindow,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
    })

    local tabButtons = {}
    local tabPages = {}
    local tabDefs = {
        { name = "TabFarm", label = "ФАРМ", iconType = "candy", accent = PALETTE.ACCENT_PURPLE },
        { name = "TabZombie", label = "ЗОМБИ", iconType = "zombie", accent = PALETTE.STATUS_ZOMBIE },
        { name = "TabPlayer", label = "ИГРОК", iconType = "player", accent = PALETTE.ACCENT_INDIGO },
        { name = "TabSettings", label = "НАСТРОЙКИ", iconType = "settings", accent = PALETTE.ACCENT_CYAN },
    }

    local tabCount = #tabDefs
    local tabWidth = 1 / tabCount

    -- Container for Tab Pages
    local pagesContainer = Create("Frame", {
        Name = "Pages",
        Size = UDim2.new(1, -16, 0, 180),
        Position = UDim2.new(0, 8, 0, 64),
        BackgroundTransparency = 1,
        Parent = mainWindow,
    })

    ----------------------------------------------------------------------
    -- Helper: Segmented Option Control for Pages
    ----------------------------------------------------------------------
    local function CreateSegmentedRow(parentPage: GuiObject, yPos: number, titleText: string, options: { string }, currentOpt: string, onSelect)
        local row = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 27),
            Position = UDim2.new(0, 0, 0, yPos),
            BackgroundColor3 = PALETTE.BG_CARD,
            BorderSizePixel = 0,
            Parent = parentPage,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
            Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
        })

        Create("TextLabel", {
            Size = UDim2.new(0, 95, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = titleText,
            Font = FONTS.BOLD,
            TextSize = 9.5,
            TextColor3 = PALETTE.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        local btnContainer = Create("Frame", {
            Size = UDim2.new(1, -104, 1, -6),
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
                TextSize = 9,
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

    ----------------------------------------------------------------------
    -- Helper: Animated Toggle Row for Pages
    ----------------------------------------------------------------------
    local function CreateToggleRow(parentPage: GuiObject, yPos: number, labelText: string, defaultVal: boolean, onToggle)
        local row = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 27),
            Position = UDim2.new(0, 0, 0, yPos),
            BackgroundColor3 = PALETTE.BG_CARD,
            BorderSizePixel = 0,
            Parent = parentPage,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
            Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
        })

        Create("TextLabel", {
            Size = UDim2.new(1, -55, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = labelText,
            Font = FONTS.BOLD,
            TextSize = 9.5,
            TextColor3 = PALETTE.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        local switch = Create("Frame", {
            Name = "Switch",
            Size = UDim2.new(0, 34, 0, 17),
            Position = UDim2.new(1, -42, 0.5, -8.5),
            BackgroundColor3 = defaultVal and PALETTE.STATUS_ACTIVE or PALETTE.BG_CONTAINER,
            BorderSizePixel = 0,
            Parent = row,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
        })

        local knob = Create("Frame", {
            Name = "Knob",
            Size = UDim2.new(0, 13, 0, 13),
            Position = defaultVal and UDim2.new(1, -15, 0.5, -6.5) or UDim2.new(0, 2, 0.5, -6.5),
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
                Tween(switch, 0.15, { BackgroundColor3 = PALETTE.STATUS_ACTIVE })
                Tween(knob, 0.15, { Position = UDim2.new(1, -15, 0.5, -6.5) })
            else
                Tween(switch, 0.15, { BackgroundColor3 = PALETTE.BG_CONTAINER })
                Tween(knob, 0.15, { Position = UDim2.new(0, 2, 0.5, -6.5) })
            end
            onToggle(state)
        end)

        return row
    end

    ----------------------------------------------------------------------
    -- TAB 1: ФАРМ (Farm / Candy harvest telemetry & primary controls)
    ----------------------------------------------------------------------
    local farmPage = Create("Frame", {
        Name = "FarmPage",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = true,
        Parent = pagesContainer,
    })
    tabPages[1] = farmPage

    -- Status Card
    local statusCard = Create("Frame", {
        Name = "StatusCard",
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = farmPage,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
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
        Size = UDim2.new(0, 120, 1, 0),
        Position = UDim2.new(0, 24, 0, 0),
        BackgroundTransparency = 1,
        Text = "ГОТОВ (IDLE)",
        Font = FONTS.BOLD,
        TextSize = 10,
        TextColor3 = PALETTE.STATUS_IDLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = statusCard,
    })
    self.StatusText = statusText

    local subInfoText = Create("TextLabel", {
        Name = "SubInfo",
        Size = UDim2.new(1, -150, 1, 0),
        Position = UDim2.new(0, 145, 0, 0),
        BackgroundTransparency = 1,
        Text = "Карта: Лобби | Дист: —",
        Font = FONTS.REGULAR,
        TextSize = 9,
        TextColor3 = PALETTE.TEXT_MUTED,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = statusCard,
    })
    self.SubInfoText = subInfoText

    -- Telemetry Metrics Grid (2x2 Cards: 82px)
    local metricGrid = Create("Frame", {
        Name = "MetricGrid",
        Size = UDim2.new(1, 0, 0, 84),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundTransparency = 1,
        Parent = farmPage,
    })

    local function CreateMetricCard(name: string, label: string, initialVal: string, posX: number, posY: number)
        local card = Create("Frame", {
            Name = name,
            Size = UDim2.new(0.5, -4, 0, 39),
            Position = UDim2.new(posX, 0, posY, 0),
            BackgroundColor3 = PALETTE.BG_CARD,
            BorderSizePixel = 0,
            Parent = metricGrid,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
            Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
        })

        Create("TextLabel", {
            Name = "Caption",
            Size = UDim2.new(1, -10, 0, 13),
            Position = UDim2.new(0, 8, 0, 3),
            BackgroundTransparency = 1,
            Text = label,
            Font = FONTS.REGULAR,
            TextSize = 8.5,
            TextColor3 = PALETTE.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
        })

        local val = Create("TextLabel", {
            Name = "Val",
            Size = UDim2.new(1, -10, 0, 18),
            Position = UDim2.new(0, 8, 0, 16),
            BackgroundTransparency = 1,
            Text = initialVal,
            Font = FONTS.BOLD,
            TextSize = 12,
            TextColor3 = PALETTE.TEXT_WHITE,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
        })

        return card, val
    end

    local cardBag, valBag = CreateMetricCard("CardBag", "В СУМКЕ", "0 / 40", 0, 0)
    local cardTotal, valTotal = CreateMetricCard("CardTotal", "УРОЖАЙ СЕССИИ", "0", 0.5, 0)
    local cardRounds, valRounds = CreateMetricCard("CardRounds", "РАУНДЫ", "0", 0, 0.53)
    local cardTime, valTime = CreateMetricCard("CardTime", "ВРЕМЯ СЕССИИ", "00:00:00", 0.5, 0.53)

    self.ValBag = valBag
    self.ValTotal = valTotal
    self.ValRounds = valRounds
    self.ValTime = valTime

    -- Mini Bag Progress Bar
    local bagProgressBg = Create("Frame", {
        Name = "ProgressBg",
        Size = UDim2.new(1, -16, 0, 2.5),
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

    -- Primary Action CTA Button (Large Touch Target: 36px)
    local primaryBtn = Create("TextButton", {
        Name = "PrimaryActionButton",
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.new(0, 0, 1, -36),
        BackgroundColor3 = PALETTE.STATUS_ACTIVE,
        Text = "[ПУСК СБОРА]",
        Font = FONTS.BLACK,
        TextSize = 12,
        TextColor3 = PALETTE.TEXT_WHITE,
        Parent = farmPage,
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
        RefreshMiniToggleIcon()
    end)

    ----------------------------------------------------------------------
    -- TAB 2: ЗОМБИ (Zombie Defense, Event Modes & Safety Platform)
    ----------------------------------------------------------------------
    local zombiePage = Create("Frame", {
        Name = "ZombiePage",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = pagesContainer,
    })
    tabPages[2] = zombiePage

    CreateToggleRow(zombiePage, 0, "Авто-Защита от Зомби (Оружие)", self.Settings.ZombieAutoDefend, function(val)
        self.Settings.ZombieAutoDefend = val
        if self.Callbacks.OnZombieAutoDefendChanged then
            self.Callbacks.OnZombieAutoDefendChanged(val)
        end
    end)

    CreateSegmentedRow(zombiePage, 31, "Радиус Угрозы", { "15м", "20м", "28м" }, self.Settings.ZombieThreatRadius, function(val)
        self.Settings.ZombieThreatRadius = val
        if self.Callbacks.OnZombieThreatRadiusChanged then
            self.Callbacks.OnZombieThreatRadiusChanged(val)
        end
    end)

    CreateSegmentedRow(zombiePage, 62, "Приоритет Цели", { "Ближний", "Охотник", "Босс" }, self.Settings.ZombiePriority, function(val)
        self.Settings.ZombiePriority = val
        if self.Callbacks.OnZombiePriorityChanged then
            self.Callbacks.OnZombiePriorityChanged(val)
        end
    end)

    CreateToggleRow(zombiePage, 93, "Небесная Платформа (При Угрозе)", self.Settings.SafePlatform, function(val)
        self.Settings.SafePlatform = val
        if self.Callbacks.OnSafePlatformChanged then
            self.Callbacks.OnSafePlatformChanged(val)
        end
    end)

    -- Zombie Threat Status Card
    local zombieStatusBanner = Create("Frame", {
        Name = "ZombieStatusBanner",
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.new(0, 0, 1, -30),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = zombiePage,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
        Create("UIStroke", { Color = PALETTE.STATUS_ZOMBIE, Thickness = 1, Transparency = 0.4 }),
    })

    local zombieStatusLabel = Create("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "[СТАТУС ЗОМБИ: АВТО-ОБОРОНА ГОТОВА]",
        Font = FONTS.BOLD,
        TextSize = 9.5,
        TextColor3 = PALETTE.STATUS_ZOMBIE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = zombieStatusBanner,
    })
    self.ZombieStatusLabel = zombieStatusLabel

    ----------------------------------------------------------------------
    -- TAB 3: ИГРОК (Player / Character Mods & Movement)
    ----------------------------------------------------------------------
    local playerPage = Create("Frame", {
        Name = "PlayerPage",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = pagesContainer,
    })
    tabPages[3] = playerPage

    CreateSegmentedRow(playerPage, 0, "Скорость Ходьбы", { "28", "36", "44" }, self.Settings.FarmSpeed == "Normal" and "28" or (self.Settings.FarmSpeed == "Fast" and "36" or "44"), function(val)
        local mode = val == "28" and "Normal" or (val == "36" and "Fast" or "Turbo")
        self.Settings.FarmSpeed = mode
        if self.Callbacks.OnSpeedChanged then
            self.Callbacks.OnSpeedChanged(mode)
        end
    end)

    CreateToggleRow(playerPage, 31, "Проход Сквозь Стены (Noclip)", self.Settings.Noclip, function(val)
        self.Settings.Noclip = val
        if self.Callbacks.OnNoclipChanged then
            self.Callbacks.OnNoclipChanged(val)
        end
    end)

    CreateSegmentedRow(playerPage, 62, "Режим Прыжка", { "Норма", "Высокий", "Инфинити" }, self.Settings.JumpMode == "Normal" and "Норма" or (self.Settings.JumpMode == "High" and "Высокий" or "Инфинити"), function(val)
        local mode = val == "Норма" and "Normal" or (val == "Высокий" and "High" or "Infinite")
        self.Settings.JumpMode = mode
        if self.Callbacks.OnJumpModeChanged then
            self.Callbacks.OnJumpModeChanged(mode)
        end
    end)

    CreateToggleRow(playerPage, 93, "Защита от Толчков (Anti-Fling)", self.Settings.AntiFling, function(val)
        self.Settings.AntiFling = val
        if self.Callbacks.OnAntiFlingChanged then
            self.Callbacks.OnAntiFlingChanged(val)
        end
    end)

    CreateToggleRow(playerPage, 124, "Авто-Воскрешение (Auto-Resume)", self.Settings.AutoResume, function(val)
        self.Settings.AutoResume = val
        if self.Callbacks.OnAutoResumeChanged then
            self.Callbacks.OnAutoResumeChanged(val)
        end
    end)

    ----------------------------------------------------------------------
    -- TAB 4: НАСТРОЙКИ (System, High-FPS, Anti-AFK & Docking)
    ----------------------------------------------------------------------
    local settingsPage = Create("Frame", {
        Name = "SettingsPage",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = pagesContainer,
    })
    tabPages[4] = settingsPage

    CreateToggleRow(settingsPage, 0, "Режим High-FPS (Низкая Графика)", self.Settings.HighFPS, function(val)
        self.Settings.HighFPS = val
        if self.Callbacks.OnHighFPSChanged then
            self.Callbacks.OnHighFPSChanged(val)
        end
    end)

    CreateToggleRow(settingsPage, 31, "Анти-АФК Защита (20м Кик)", self.Settings.AntiAFK, function(val)
        self.Settings.AntiAFK = val
        if self.Callbacks.OnAntiAFKChanged then
            self.Callbacks.OnAntiAFKChanged(val)
        end
    end)

    CreateSegmentedRow(settingsPage, 62, "Емкость Сумки", { "Авто", "40", "50" }, self.Settings.BagCapacity, function(val)
        self.Settings.BagCapacity = val
        if self.Callbacks.OnBagCapacityChanged then
            self.Callbacks.OnBagCapacityChanged(val)
        end
    end)

    CreateToggleRow(settingsPage, 93, "Touch Safe-Dock (Обход Джойстика)", self.Settings.SafeDock, function(val)
        self.Settings.SafeDock = val
        if val then
            mainWindow.Position = ClampFrameToSafeBounds(mainWindow, mainWindow.Position)
            miniHud.Position = ClampFrameToSafeBounds(miniHud, miniHud.Position)
        end
    end)

    CreateToggleRow(settingsPage, 124, "Авто-Реконнект к Серверу", self.Settings.AutoReconnect, function(val)
        self.Settings.AutoReconnect = val
        if self.Callbacks.OnAutoReconnectChanged then
            self.Callbacks.OnAutoReconnectChanged(val)
        end
    end)

    ----------------------------------------------------------------------
    -- Build Navigation Tab Buttons
    ----------------------------------------------------------------------
    local function SwitchTab(targetIndex: number)
        self.ActiveTabIndex = targetIndex
        for i, btn in ipairs(tabButtons) do
            local page = tabPages[i]
            local def = tabDefs[i]
            if i == targetIndex then
                btn.BackgroundColor3 = def.accent
                btn.BackgroundTransparency = 0
                local lbl = btn:FindFirstChild("TabLabel")
                if lbl then lbl.TextColor3 = PALETTE.TEXT_WHITE end
                page.Visible = true
            else
                btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                btn.BackgroundTransparency = 1
                local lbl = btn:FindFirstChild("TabLabel")
                if lbl then lbl.TextColor3 = PALETTE.TEXT_MUTED end
                page.Visible = false
            end
        end
    end

    for i, def in ipairs(tabDefs) do
        local btn = Create("TextButton", {
            Name = def.name,
            Size = UDim2.new(tabWidth, -2, 1, -4),
            Position = UDim2.new((i - 1) * tabWidth, 1, 0, 2),
            BackgroundColor3 = (i == 1) and def.accent or Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = (i == 1) and 0 or 1,
            Text = "",
            Parent = tabBar,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
        })

        -- Vector Icon Primitive for Tab
        local iconSize = UDim2.fromOffset(13, 13)
        local iconInst = nil
        if def.iconType == "candy" then
            iconInst = PrimitiveIcons.CreateCandy(iconSize, PALETTE.TEXT_WHITE, def.accent)
        elseif def.iconType == "zombie" then
            iconInst = PrimitiveIcons.CreateZombie(iconSize, PALETTE.TEXT_WHITE, PALETTE.BG_MAIN)
        elseif def.iconType == "player" then
            iconInst = PrimitiveIcons.CreatePlayer(iconSize, PALETTE.TEXT_WHITE)
        elseif def.iconType == "settings" then
            iconInst = PrimitiveIcons.CreateSettings(iconSize, PALETTE.TEXT_WHITE, PALETTE.BG_MAIN)
        end

        if iconInst then
            iconInst.Position = UDim2.new(0, 4, 0.5, -6.5)
            iconInst.Parent = btn
        end

        Create("TextLabel", {
            Name = "TabLabel",
            Size = UDim2.new(1, -20, 1, 0),
            Position = UDim2.new(0, 19, 0, 0),
            BackgroundTransparency = 1,
            Text = def.label,
            Font = FONTS.BOLD,
            TextSize = 9.5,
            TextColor3 = (i == 1) and PALETTE.TEXT_WHITE or PALETTE.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = btn,
        })

        btn.MouseButton1Click:Connect(function()
            SwitchTab(i)
        end)
        tabButtons[i] = btn
    end

    return self
end

-- Start / Stop Farming Toggle
function MM2_MobileUI:ToggleFarming()
    self.IsFarming = not self.IsFarming

    if self.IsFarming then
        self.PrimaryBtn.Text = "[СТОП СБОРА]"
        self.PrimaryBtn.BackgroundColor3 = PALETTE.STATUS_ALERT
        local grad = self.PrimaryBtn:FindFirstChildOfClass("UIGradient")
        if grad then
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(239, 68, 68)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 28, 28)),
            })
        end
        self:SetStatus("FARMING", "Сбор конфет...")
    else
        self.PrimaryBtn.Text = "[ПУСК СБОРА]"
        self.PrimaryBtn.BackgroundColor3 = PALETTE.STATUS_ACTIVE
        local grad = self.PrimaryBtn:FindFirstChildOfClass("UIGradient")
        if grad then
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 197, 94)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 145, 68)),
            })
        end
        self:SetStatus("IDLE", "Остановлен пользователем")
    end

    if self.Callbacks and self.Callbacks.OnToggleFarm then
        self.Callbacks.OnToggleFarm(self.IsFarming)
    end
end

-- Set Farming Active explicitly from backend
function MM2_MobileUI:SetFarmingActive(active: boolean)
    if self.IsFarming ~= active then
        self:ToggleFarming()
    end
end

-- Set Live Status
function MM2_MobileUI:SetStatus(statusKey: string, subInfo: string?)
    self.CurrentStatus = statusKey

    local color = PALETTE.STATUS_IDLE
    local title = "ГОТОВ (IDLE)"
    local miniText = "[ГОТОВ]"

    if statusKey == "FARMING" then
        color = PALETTE.STATUS_ACTIVE
        title = "СБОР КОНФЕТ"
        miniText = "[СБОР]"
    elseif statusKey == "BAG_FULL" then
        color = PALETTE.STATUS_ALERT
        title = "СУМКА ПОЛНА (40/40)"
        miniText = "[ПОЛНА]"
    elseif statusKey == "ROUND_OVER" then
        color = PALETTE.STATUS_WARN
        title = "РАУНД ОКОНЧЕН"
        miniText = "[РАУНД]"
    elseif statusKey == "WAITING_MAP" then
        color = PALETTE.ACCENT_PURPLE
        title = "ОЖИДАНИЕ КАРТЫ"
        miniText = "[ОЖИДАНИЕ]"
    elseif statusKey == "ZOMBIE_DEFENSE" then
        color = PALETTE.STATUS_ZOMBIE
        title = "ОБОРОНА ОТ ЗОМБИ"
        miniText = "[ЗОМБИ]"
    end

    if self.StatusDot then
        self.StatusDot.BackgroundColor3 = color
    end
    if self.MiniStatusDot then
        self.MiniStatusDot.BackgroundColor3 = color
    end
    if self.MiniHalo then
        local stroke = self.MiniHalo:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Color = color end
    end
    if self.StatusText then
        self.StatusText.Text = title
        self.StatusText.TextColor3 = color
    end
    if self.MiniTelemetry then
        self.MiniTelemetry.Text = miniText
        self.MiniTelemetry.TextColor3 = color
    end
    if subInfo and self.SubInfoText then
        self.SubInfoText.Text = subInfo
    end
end

-- Update Realtime Metrics
function MM2_MobileUI:UpdateMetrics(metrics: {
    bagCurrent: number?,
    bagMax: number?,
    totalCandies: number?,
    roundsFarmed: number?,
    elapsedSeconds: number?,
    mapName: string?,
    targetDistance: number?
})
    if not metrics then return end

    if metrics.bagCurrent ~= nil and metrics.bagMax ~= nil then
        self.ValBag.Text = string.format("%d / %d", metrics.bagCurrent, metrics.bagMax)
        local progress = math.clamp(metrics.bagCurrent / math.max(metrics.bagMax, 1), 0, 1)
        Tween(self.BagProgressFill, 0.2, { Size = UDim2.new(progress, 0, 1, 0) })
        if progress >= 1 then
            self.BagProgressFill.BackgroundColor3 = PALETTE.STATUS_ALERT
        else
            self.BagProgressFill.BackgroundColor3 = PALETTE.ACCENT_PURPLE
        end
        if self.MiniTelemetry and self.IsFarming then
            self.MiniTelemetry.Text = string.format("[%d/%d]", metrics.bagCurrent, metrics.bagMax)
        end
    end

    if metrics.totalCandies ~= nil then
        self.ValTotal.Text = tostring(metrics.totalCandies)
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
        local mapStr = metrics.mapName or "Неизвестно"
        local distStr = metrics.targetDistance and string.format("%d м", math.floor(metrics.targetDistance)) or "—"
        self.SubInfoText.Text = string.format("Карта: %s | Дист: %s", mapStr, distStr)
    end
end

-- Get Current Settings Table
function MM2_MobileUI:GetSettings()
    return self.Settings
end

-- Destroy UI Cleanly
function MM2_MobileUI:Destroy()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
        self.ScreenGui = nil
    end
end

return MM2_MobileUI
