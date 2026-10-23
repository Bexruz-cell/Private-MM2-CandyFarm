--[[
    ==============================================================================
    ROCKHUB COMPANION HOOK & MOBILE SCREEN RESIZER (ANDROID DELTA)
    ==============================================================================
    Subagent 4: RockHub Integration Engineer
    Target: RockHub MM2 / RockHubUI (Luraph v14.9 Runtime GUI Optimization)
    Platform: Delta Executor (Android Mobile & PC)

    CORE OBJECTIVE:
    Non-destructively intercept RockHub's native ScreenGui ("RockHubUI") at runtime,
    rescaling its 680x470 "Main" Frame from ~0.71-0.73 down to ~0.45 (306x211 px),
    repositioning it outside touch control zones (virtual joystick & jump button),
    while maintaining 100% integrity of the Luraph VM execution state & farm loop.
    ==============================================================================
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
assert(LocalPlayer, "RockHub Resizer requires a local client environment")

-- Configuration Parameters
local CONFIG = {
    TargetScale = 0.52,            -- 0.52 produces 353 x 244 px (ergonomic touch targets on mobile)
    MinScale = 0.35,               -- Extreme compact mode
    MaxScale = 0.70,               -- Full tablet mode
    SafeTopOffset = 14,            -- Pixels below top status bar / camera cutout
    GuiName = "RockHubUI",
    MainFrameName = "Main",
    WatermarkName = "WatermarkHolder",
}

-- Safe GUI container cascade resolver for Delta executor
local function resolveGuiContainer(): Instance
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local okCore, _ = pcall(function() return CoreGui:GetChildren() end)
    if okCore then return CoreGui end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local RockHubHook = {
    Active = false,
    CurrentScale = CONFIG.TargetScale,
    Connections = {} :: { [RBXScriptConnection]: boolean },
    AttachedGui = nil :: ScreenGui?,
}

local function trackConnection(conn: RBXScriptConnection)
    RockHubHook.Connections[conn] = true
    return conn
end

-- Non-destructive Scale & Geometry Optimizer
local function optimizeMainFrame(main: Frame)
    local uiScale = main:FindFirstChildOfClass("UIScale")
    if not uiScale then
        uiScale = Instance.new("UIScale")
        uiScale.Parent = main
    end

    -- 1. Reposition to Top-Center to completely clear Virtual Joystick (left) and Jump Button (right)
    main.AnchorPoint = Vector2.new(0.5, 0)
    main.Position = UDim2.new(0.5, 0, 0, CONFIG.SafeTopOffset)

    -- 2. State-Guard to prevent infinite signal recursion
    local isReenforcing = false
    local function enforceCustomScale()
        if isReenforcing or not RockHubHook.Active then return end
        -- RockHub window:SetOpen tweens scale to 0 when closed. Only clamp when opening/open (> 0.05)
        if uiScale.Scale > 0.05 and math.abs(uiScale.Scale - RockHubHook.CurrentScale) > 0.02 then
            isReenforcing = true
            uiScale.Scale = RockHubHook.CurrentScale
            isReenforcing = false
        end
    end

    -- Initial enforcement
    enforceCustomScale()

    -- Intercept RockHub's internal updateResponsiveScale and tween animations
    local scaleConn = trackConnection(uiScale:GetPropertyChangedSignal("Scale"):Connect(enforceCustomScale))
end

-- Watermark / Mini-toggle optimization
local function optimizeWatermark(wmHolder: Frame)
    -- Align watermark nicely near top-right so it doesn't overlap Roblox Mobile Chat/Menu
    wmHolder.Position = UDim2.new(1, -220, 0, 6)
    local wm = wmHolder:FindFirstChild("Watermark")
    if wm and wm:IsA("GuiObject") then
        local wmScale = wm:FindFirstChildOfClass("UIScale")
        if wmScale then
            wmScale.Scale = 0.65
        end
    end
end

-- Attach Hook to RockHub ScreenGui
function RockHubHook:Attach(gui: ScreenGui)
    if self.AttachedGui == gui then return end
    self.AttachedGui = gui
    self.Active = true

    local main = gui:FindFirstChild(CONFIG.MainFrameName)
    if main and main:IsA("Frame") then
        optimizeMainFrame(main)
    else
        trackConnection(gui.ChildAdded:Connect(function(child)
            if child.Name == CONFIG.MainFrameName and child:IsA("Frame") then
                optimizeMainFrame(child)
            end
        end))
    end

    local wm = gui:FindFirstChild(CONFIG.WatermarkName)
    if wm and wm:IsA("Frame") then
        optimizeWatermark(wm)
    else
        trackConnection(gui.ChildAdded:Connect(function(child)
            if child.Name == CONFIG.WatermarkName and child:IsA("Frame") then
                optimizeWatermark(child)
            end
        end))
    end
end

-- Set scale dynamically at runtime (callable by Mobile Companion HUD)
function RockHubHook:SetScale(newScale: number)
    self.CurrentScale = math.clamp(newScale, CONFIG.MinScale, CONFIG.MaxScale)
    if self.AttachedGui then
        local main = self.AttachedGui:FindFirstChild(CONFIG.MainFrameName)
        if main then
            local uiScale = main:FindFirstChildOfClass("UIScale")
            if uiScale and uiScale.Scale > 0.05 then
                uiScale.Scale = self.CurrentScale
            end
        end
    end
end

-- Detach and cleanly restore
function RockHubHook:Detach()
    self.Active = false
    for conn in pairs(self.Connections) do
        conn:Disconnect()
    end
    table.clear(self.Connections)
    self.AttachedGui = nil
end

-- Start Listener & Auto-Detection
local container = resolveGuiContainer()
local existing = container:FindFirstChild(CONFIG.GuiName)
if existing and existing:IsA("ScreenGui") then
    RockHubHook:Attach(existing)
end

-- Listen for late injection if RockHub loads after this hook
trackConnection(container.ChildAdded:Connect(function(child)
    if child.Name == CONFIG.GuiName and child:IsA("ScreenGui") then
        RockHubHook:Attach(child)
    end
end))

return RockHubHook
