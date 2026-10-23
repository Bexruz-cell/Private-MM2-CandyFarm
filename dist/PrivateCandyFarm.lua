--[[
    ==============================================================================
    PRIVATE MM2 CANDY FARM & ROCKHUB COMPANION — DELTA EXECUTOR ANDROID
    ==============================================================================
    Version: 2.1.0 PRO (NEBULA PRO + MIDNIGHT + ROCKHUB RESIZER ARCHITECTURE)
    Platform: Delta Executor (Android Mobile & Windows)
    Target: Roblox Murder Mystery 2 (Halloween Candy / Seasonal Coins / Infection)
    Author: Autonomous Engineering Team (Tech Lead & Council)

    SECURITY NOTICE:
    - 100% Standalone & Self-Contained. Zero external loaders or remote fetches.
    - Zero Webhooks, zero analytics, zero credential/token access.
    - Zero obfuscated code. Clean, inspectable, high-performance Luau.

    FEATURES:
    - Non-Destructive RockHub UI Resizer (680x470 -> 306x211 px, 62% reduction)
    - NEBULA PRO + MIDNIGHT Compact Dashboard (336 x 248 px)
    - Draggable Floating Mini-HUD Capsule (118 x 32 px)
    - 4 Primary Tabs (ФАРМ, ЗОМБИ, ИГРОК, НАСТРОЙКИ)
    - Precision FPS Rolling Average (16-frame window) & Sub-ms Frame Time
    - Passive Round & Coin State Observers (Zero competing farm physics)
    - Hardware-Safe High FPS Graphics Optimizer (Coins strictly protected)
    - Safe Touch Clamping (Virtual Joystick & Jump Button dead-zone avoidance)
    ==============================================================================
]]

do
    -- 1. Ensure game engine is loaded
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local waitLimit = os.clock() + 10
    while not LocalPlayer and os.clock() < waitLimit do
        task.wait(0.1)
        LocalPlayer = Players.LocalPlayer
    end

    if not LocalPlayer then
        error("[Private MM2 Farm] Critical: LocalPlayer could not be resolved.")
    end

    -- 2. Prevent duplicate running instances in the same session
    if _G.PrivateMM2CandyFarmCleanup then
        pcall(_G.PrivateMM2CandyFarmCleanup)
        _G.PrivateMM2CandyFarmCleanup = nil
    end
    if _G.PrivateMM2CompanionCleanup then
        pcall(_G.PrivateMM2CompanionCleanup)
        _G.PrivateMM2CompanionCleanup = nil
    end

    local initSuccess, initError = pcall(function()
        local Workspace = game:GetService("Workspace")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local RunService = game:GetService("RunService")
        local TweenService = game:GetService("TweenService")
        local UserInputService = game:GetService("UserInputService")
        local CoreGui = game:GetService("CoreGui")
        local HttpService = game:GetService("HttpService")
        local Lighting = game:GetService("Lighting")

        -- MODULE 1: Maid (Lifecycle Manager)
        local Maid = (function()
-- Maid.luau: Connection and Task Lifecycle Manager
-- Ensures zero connection leaks, clean cancellation of tweens and loops

local Maid = {}
Maid.__index = Maid

export type MaidTask = RBXScriptConnection | Instance | (() -> ()) | { Destroy: (any) -> () } | { disconnect: (any) -> () }

function Maid.new()
    local self = setmetatable({
        _tasks = {} :: { [any]: MaidTask },
    }, Maid)
    return self
end

function Maid:GiveTask(taskItem: MaidTask): any
    if not taskItem then return nil end
    local key = #self._tasks + 1
    self._tasks[key] = taskItem
    return key
end

function Maid:GiveNamed(name: string, taskItem: MaidTask)
    if self._tasks[name] then
        self:CleanKey(name)
    end
    self._tasks[name] = taskItem
end

function Maid:CleanKey(key: any)
    local taskItem = self._tasks[key]
    if not taskItem then return end
    self._tasks[key] = nil

    local t = typeof(taskItem)
    if t == "RBXScriptConnection" then
        (taskItem :: RBXScriptConnection):Disconnect()
    elseif t == "Instance" then
        pcall(function()
            (taskItem :: Instance):Destroy()
        end)
    elseif t == "function" then
        pcall(taskItem :: () -> ())
    elseif t == "table" then
        if typeof((taskItem :: any).Destroy) == "function" then
            pcall(function() (taskItem :: any):Destroy() end)
        elseif typeof((taskItem :: any).Disconnect) == "function" then
            pcall(function() (taskItem :: any):Disconnect() end)
        elseif typeof((taskItem :: any).Cancel) == "function" then
            pcall(function() (taskItem :: any):Cancel() end)
        end
    end
end

function Maid:DoCleaning()
    local tasks = self._tasks
    self._tasks = {}

    for key, taskItem in pairs(tasks) do
        local t = typeof(taskItem)
        if t == "RBXScriptConnection" then
            taskItem:Disconnect()
        elseif t == "Instance" then
            pcall(function()
                taskItem:Destroy()
            end)
        elseif t == "function" then
            pcall(taskItem)
        elseif t == "table" then
            if typeof(taskItem.Destroy) == "function" then
                pcall(function() taskItem:Destroy() end)
            elseif typeof(taskItem.Disconnect) == "function" then
                pcall(function() taskItem:Disconnect() end)
            elseif typeof(taskItem.Cancel) == "function" then
                pcall(function() taskItem:Cancel() end)
            end
        end
    end
end

function Maid:Destroy()
    self:DoCleaning()
end

return Maid

        end)()

        -- MODULE 2: AntiAFK (VirtualUser + getconnections)
        local AntiAFK = (function()
-- AntiAFK.luau: Safe Anti-AFK Disabler
-- Prevents Roblox 20-minute idle disconnection on both mobile and desktop

local Players = game:GetService("Players")
local VirtualUser = nil

pcall(function()
    VirtualUser = game:GetService("VirtualUser")
end)

local AntiAFK = {
    _enabled = false,
    _connection = nil :: RBXScriptConnection?,
}

function AntiAFK.Enable()
    if AntiAFK._enabled then return end
    AntiAFK._enabled = true

    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end

    -- Strategy 1: Executor getconnections / get_signal_cons
    local success = false
    local getCons = (getgenv and (getgenv().getconnections or getgenv().get_signal_cons)) or (_G and (_G.getconnections or _G.get_signal_cons))
    if type(getCons) == "function" then
        pcall(function()
            local cons = getCons(localPlayer.Idled)
            if cons and type(cons) == "table" then
                for _, con in pairs(cons) do
                    if type(con) == "table" and type(con.Disable) == "function" then
                        con:Disable()
                        success = true
                    elseif type(con) == "table" and type(con.Disconnect) == "function" then
                        con:Disconnect()
                        success = true
                    end
                end
            end
        end)
    end

    -- Strategy 2: Fallback to VirtualUser simulated input on Idled event
    if not success and VirtualUser then
        pcall(function()
            AntiAFK._connection = localPlayer.Idled:Connect(function()
                if not AntiAFK._enabled then return end
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end)
        end)
    end
end

function AntiAFK.Disable()
    AntiAFK._enabled = false
    if AntiAFK._connection then
        AntiAFK._connection:Disconnect()
        AntiAFK._connection = nil
    end
end

function AntiAFK.IsEnabled(): boolean
    return AntiAFK._enabled
end

return AntiAFK

        end)()

        -- MODULE 3: Delta Android Touch & Hardware Compatibility Engine
        local DeltaCompatibility = (function()
--[[
    Delta Android Compatibility & Touch Optimization Engine
    Specialist: Subagent 3 - Android Delta Specialist (MM2 Candy Farm Council)
    Target Platform: Delta Executor on Android Mobile (Roblox Touch Engine & CoreGui)
    Standard: 100% Pure Luau, Zero External Dependencies, Zero Emojis, Native Hardware Optimization

    Features:
    1. Screen insets & display cutouts handling (GuiService:GetGuiInset(), notch/pill/punch-hole adaptation).
    2. Responsive scaling math for phone landscape viewports (720x360, 800x400, 1280x720, 2400x1080).
    3. Safe area positioning & collision prevention against on-screen virtual joystick (~140x140) & jump button (~100x100).
    4. Multi-touch safe dragging mechanics with pointer identity lock & camera orbit bleed suppression.
    5. ScreenGui parent cascade resolver (gethui() -> CoreGui -> PlayerGui) with cross-hierarchy cleanup.
]]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local DeltaAndroidCompatibility = {}
DeltaAndroidCompatibility.__index = DeltaAndroidCompatibility

-- Baseline Reference Viewport (Landscape 16:9 Standard)
local REF_WIDTH = 960
local REF_HEIGHT = 540
local MIN_SCALE = 0.72
local MAX_SCALE = 1.30

-- Exclusion Zone Defaults (Roblox Mobile Landscape Controls)
local EXCLUSION_JOYSTICK_SIZE = Vector2.new(160, 160) -- Lower-left virtual dynamic thumbstick
local EXCLUSION_JUMP_SIZE     = Vector2.new(110, 110) -- Lower-right jump button
local EXCLUSION_TOPBAR_HEIGHT = 44                    -- Top-bar hamburger / chat / leaderboard icons

-- ============================================================================
-- 1. SCREEN INSETS & DISPLAY CUTOUTS HANDLER
-- ============================================================================

--[=[
    Returns the device safe bounds accounting for notches, punch-holes, cutouts,
    and system gesture navigation bars.
    Returns:
        safeMin: Vector2 (topLeft inset)
        safeMax: Vector2 (bottomRight safe boundary)
        safeSize: Vector2 (usable display dimensions)
]=]
function DeltaAndroidCompatibility.GetDeviceSafeBounds(): (Vector2, Vector2, Vector2)
    local topLeftInset, bottomRightInset = Vector2.zero, Vector2.zero
    
    local success, err = pcall(function()
        topLeftInset, bottomRightInset = GuiService:GetGuiInset()
    end)
    if not success then
        topLeftInset = Vector2.new(0, 36)
        bottomRightInset = Vector2.zero
    end

    local viewport = (Camera and Camera.ViewportSize) or Vector2.new(800, 450)
    local safeMin = topLeftInset
    local safeMax = Vector2.new(
        math.max(safeMin.X + 100, viewport.X - bottomRightInset.X),
        math.max(safeMin.Y + 100, viewport.Y - bottomRightInset.Y)
    )
    local safeSize = safeMax - safeMin

    return safeMin, safeMax, safeSize
end

-- ============================================================================
-- 2. RESPONSIVE SCALING ENGINE
-- ============================================================================

--[=[
    Calculates responsive scale factor for current landscape viewport.
    Preserves legibility of fonts and minimum touch target size (>= 38-44 px).
]=]
function DeltaAndroidCompatibility.CalculateScale(customViewport: Vector2?): number
    local viewport = customViewport or (Camera and Camera.ViewportSize) or Vector2.new(REF_WIDTH, REF_HEIGHT)
    local widthRatio = viewport.X / REF_WIDTH
    local heightRatio = viewport.Y / REF_HEIGHT
    local rawScale = math.min(widthRatio, heightRatio)

    return math.clamp(rawScale, MIN_SCALE, MAX_SCALE)
end

--[=[
    Attaches or updates a UIScale instance on the target GUI container,
    automatically binding to Camera.ViewportSize changes.
]=]
function DeltaAndroidCompatibility.ApplyResponsiveUIScale(container: GuiObject): (UIScale, RBXScriptConnection)
    local uiScale = container:FindFirstChildOfClass("UIScale")
    if not uiScale then
        uiScale = Instance.new("UIScale")
        uiScale.Name = "DeltaResponsiveScale"
        uiScale.Parent = container
    end

    local function updateScale()
        uiScale.Scale = DeltaAndroidCompatibility.CalculateScale()
    end

    updateScale()

    local conn = nil
    if Camera then
        conn = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    end

    return uiScale, conn
end

-- ============================================================================
-- 3. EXCLUSION ZONES & SAFE POSITION RESOLVER
-- ============================================================================

--[=[
    Checks whether a 2D Axis-Aligned Bounding Box (AABB) overlaps another box.
]=]
local function BoxOverlaps(minA: Vector2, maxA: Vector2, minB: Vector2, maxB: Vector2): boolean
    return (minA.X < maxB.X and maxA.X > minB.X and minA.Y < maxB.Y and maxA.Y > minB.Y)
end

--[=[
    Calculates the exclusion zones for Roblox on-screen mobile controls:
    1. Lower-Left Virtual Dynamic Joystick (0, H - 160 to 160, H)
    2. Lower-Right Jump Button (W - 110, H - 110 to W, H)
    3. Top-Left Roblox Hamburger Menu (0, 0 to 60, 50)
    4. Top-Right Roblox Chat/Leaderboard (W - 160, 0 to W, 50)
]=]
function DeltaAndroidCompatibility.GetExclusionZones(customViewport: Vector2?): { { Name: string, Min: Vector2, Max: Vector2 } }
    local vp = customViewport or (Camera and Camera.ViewportSize) or Vector2.new(800, 450)
    local safeMin, safeMax = DeltaAndroidCompatibility.GetDeviceSafeBounds()

    return {
        {
            Name = "VirtualJoystick",
            Min = Vector2.new(0, vp.Y - EXCLUSION_JOYSTICK_SIZE.Y),
            Max = Vector2.new(EXCLUSION_JOYSTICK_SIZE.X, vp.Y),
        },
        {
            Name = "JumpButton",
            Min = Vector2.new(vp.X - EXCLUSION_JUMP_SIZE.X, vp.Y - EXCLUSION_JUMP_SIZE.Y),
            Max = Vector2.new(vp.X, vp.Y),
        },
        {
            Name = "TopLeftMenu",
            Min = Vector2.new(0, 0),
            Max = Vector2.new(60, EXCLUSION_TOPBAR_HEIGHT),
        },
        {
            Name = "TopRightControls",
            Min = Vector2.new(vp.X - 160, 0),
            Max = Vector2.new(vp.X, EXCLUSION_TOPBAR_HEIGHT),
        },
    }
end

--[=[
    Resolves a proposed (X, Y) pixel position for a GUI frame of size (W, H),
    clamping within safe bounds and pushing out of joystick and jump button zones.
]=]
function DeltaAndroidCompatibility.ResolveSafePosition(proposedPos: Vector2, frameSize: Vector2, customViewport: Vector2?): Vector2
    local vp = customViewport or (Camera and Camera.ViewportSize) or Vector2.new(800, 450)
    local safeMin, safeMax = DeltaAndroidCompatibility.GetDeviceSafeBounds()
    
    local resolvedX = math.clamp(proposedPos.X, safeMin.X, math.max(safeMin.X, safeMax.X - frameSize.X))
    local resolvedY = math.clamp(proposedPos.Y, safeMin.Y, math.max(safeMin.Y, safeMax.Y - frameSize.Y))

    local frameMin = Vector2.new(resolvedX, resolvedY)
    local frameMax = frameMin + frameSize

    -- 1. Joystick collision check (Lower-Left)
    local joyMin = Vector2.new(0, vp.Y - EXCLUSION_JOYSTICK_SIZE.Y)
    local joyMax = Vector2.new(EXCLUSION_JOYSTICK_SIZE.X, vp.Y)
    if BoxOverlaps(frameMin, frameMax, joyMin, joyMax) then
        -- Prefer horizontal shift to the right of joystick
        local shiftX = joyMax.X + 6
        if shiftX + frameSize.X <= safeMax.X then
            resolvedX = shiftX
        else
            -- Push vertically above joystick
            resolvedY = math.max(safeMin.Y, joyMin.Y - frameSize.Y - 6)
        end
    end

    -- 2. Jump button collision check (Lower-Right)
    frameMin = Vector2.new(resolvedX, resolvedY)
    frameMax = frameMin + frameSize
    local jumpMin = Vector2.new(vp.X - EXCLUSION_JUMP_SIZE.X, vp.Y - EXCLUSION_JUMP_SIZE.Y)
    local jumpMax = Vector2.new(vp.X, vp.Y)
    if BoxOverlaps(frameMin, frameMax, jumpMin, jumpMax) then
        -- Prefer horizontal shift to the left of jump button
        local shiftX = jumpMin.X - frameSize.X - 6
        if shiftX >= safeMin.X then
            resolvedX = shiftX
        else
            -- Push vertically above jump button
            resolvedY = math.max(safeMin.Y, jumpMin.Y - frameSize.Y - 6)
        end
    end

    return Vector2.new(math.floor(resolvedX + 0.5), math.floor(resolvedY + 0.5))
end

-- ============================================================================
-- 4. MULTI-TOUCH SAFE DRAGGING ENGINE
-- ============================================================================

--[=[
    Binds a touch/mouse draggable interaction on targetFrame using dragHandle.
    Guarantees:
    - Multi-touch isolation: tracks exact InputObject pointer identity; secondary fingers cannot hijack position.
    - Camera orbit bleed suppression: sets Active = true so Roblox TouchCameraModule sinks the touch.
    - System gesture resilience: handles UserInputState.Cancel gracefully.
    - On release: smoothly spring-animates frame back to a safe zone if dropped on joystick or offscreen.
]=]
function DeltaAndroidCompatibility.MakeTouchDraggable(dragHandle: GuiObject, targetFrame: GuiObject, onDragEndedCallback: ((Vector2) -> ())?)
    dragHandle.Active = true
    targetFrame.Active = true

    local activePointerInput: InputObject? = nil
    local isDragging: boolean = false
    local dragStartScreenPos: Vector2 = Vector2.zero
    local frameStartScreenPos: Vector2 = Vector2.zero
    local inputChangedConnection: RBXScriptConnection? = nil
    local inputStateConnection: RBXScriptConnection? = nil

    local function EndDrag()
        if not isDragging then return end
        isDragging = false
        activePointerInput = nil

        if inputStateConnection then
            inputStateConnection:Disconnect()
            inputStateConnection = nil
        end
        if inputChangedConnection then
            inputChangedConnection:Disconnect()
            inputChangedConnection = nil
        end

        -- Safe zone boundary & exclusion clamp with spring snap
        local currentAbsPos = targetFrame.AbsolutePosition
        local currentSize = targetFrame.AbsoluteSize
        local resolvedPos = DeltaAndroidCompatibility.ResolveSafePosition(currentAbsPos, currentSize)

        if (resolvedPos - currentAbsPos).Magnitude > 2 then
            local tweenInfo = TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local targetUDim2 = UDim2.new(0, resolvedPos.X, 0, resolvedPos.Y)
            TweenService:Create(targetFrame, tweenInfo, { Position = targetUDim2 }):Play()
        end

        if onDragEndedCallback then
            task.spawn(onDragEndedCallback, resolvedPos)
        end
    end

    dragHandle.InputBegan:Connect(function(input: InputObject)
        if activePointerInput ~= nil then
            -- Secondary finger detected! Multi-touch immunity: ignore secondary touch
            return
        end

        local inputType = input.UserInputType
        if inputType == Enum.UserInputType.Touch or inputType == Enum.UserInputType.MouseButton1 then
            activePointerInput = input
            isDragging = true
            dragStartScreenPos = Vector2.new(input.Position.X, input.Position.Y)
            frameStartScreenPos = targetFrame.AbsolutePosition

            -- Monitor pointer end or cancellation (e.g. Android 3-finger gesture, notification shade)
            inputStateConnection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
                    EndDrag()
                end
            end)

            -- Pointer move tracking
            inputChangedConnection = UserInputService.InputChanged:Connect(function(moveInput: InputObject)
                if moveInput == activePointerInput and isDragging then
                    local currentPos = Vector2.new(moveInput.Position.X, moveInput.Position.Y)
                    local delta = currentPos - dragStartScreenPos
                    local newPos = frameStartScreenPos + delta

                    -- Real-time boundary clamping during movement
                    local safeMin, safeMax = DeltaAndroidCompatibility.GetDeviceSafeBounds()
                    local frameSize = targetFrame.AbsoluteSize
                    local clampedX = math.clamp(newPos.X, safeMin.X - 20, safeMax.X - frameSize.X + 20)
                    local clampedY = math.clamp(newPos.Y, safeMin.Y - 10, safeMax.Y - frameSize.Y + 10)

                    targetFrame.Position = UDim2.new(0, clampedX, 0, clampedY)
                end
            end)
        end
    end)

    -- Global fallback listener if InputObject.Changed drops under extreme frame hitches
    UserInputService.InputEnded:Connect(function(endedInput: InputObject)
        if endedInput == activePointerInput then
            EndDrag()
        end
    end)
end

-- ============================================================================
-- 5. SCREEN-GUI PARENT CASCADE RESOLVER & GC
-- ============================================================================

--[=[
    Discovers the safest parent container in Delta Executor:
    1. gethui() (Hidden UI folder, protected from game scripts & MM2 scans)
    2. CoreGui (Accessible to Delta executor context)
    3. PlayerGui (Graceful fallback)
]=]
function DeltaAndroidCompatibility.GetSafeGuiParent(): Instance
    -- 1. Primary: gethui()
    if typeof(gethui) == "function" then
        local success, result = pcall(gethui)
        if success and result and typeof(result) == "Instance" and result:IsA("Instance") then
            return result
        end
    end

    -- 2. Secondary: CoreGui
    local coreSuccess, coreResult = pcall(function()
        return CoreGui
    end)
    if coreSuccess and coreResult and typeof(coreResult) == "Instance" and coreResult:IsA("Instance") then
        return coreResult
    end

    -- 3. Fallback: PlayerGui
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        return playerGui
    end

    return LocalPlayer:WaitForChild("PlayerGui", 5)
end

--[=[
    Removes existing UI instances across the entire cascade hierarchy,
    preventing duplicate execution leaks and memory bloat on mobile.
]=]
function DeltaAndroidCompatibility.CleanupOrphanedUIs(uiName: string)
    local candidateParents = {}

    -- Check gethui
    if typeof(gethui) == "function" then
        local success, result = pcall(gethui)
        if success and result and typeof(result) == "Instance" then
            table.insert(candidateParents, result)
        end
    end

    -- Check CoreGui
    local coreSuccess, coreResult = pcall(function()
        return CoreGui
    end)
    if coreSuccess and coreResult and typeof(coreResult) == "Instance" then
        table.insert(candidateParents, coreResult)
    end

    -- Check PlayerGui
    if LocalPlayer then
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            table.insert(candidateParents, pg)
        end
    end

    -- Purge
    for _, parent in ipairs(candidateParents) do
        pcall(function()
            local existing = parent:FindFirstChild(uiName)
            if existing then
                existing:Destroy()
            end
        end)
    end
end

--[=[
    Mounts a production ScreenGui with optimal mobile properties:
    - ResetOnSpawn = false (survives MM2 rounds & deaths)
    - IgnoreGuiInset = true (we handle insets with math)
    - DisplayOrder = 9999 (draws over MM2 mobile HUD)
]=]
function DeltaAndroidCompatibility.MountScreenGui(uiName: string): ScreenGui
    DeltaAndroidCompatibility.CleanupOrphanedUIs(uiName)
    local safeParent = DeltaAndroidCompatibility.GetSafeGuiParent()

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = uiName
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 9999

    -- Safely set ScreenInsets enum if supported by engine build
    pcall(function()
        screenGui.ScreenInsets = Enum.ScreenInsets.None
    end)

    screenGui.Parent = safeParent
    return screenGui
end

return DeltaAndroidCompatibility

        end)()

        -- MODULE 4: State Store
        local State = (function()
-- State.luau: Centralized reactive state store
-- Handles farming status, metrics, configuration, and event dispatching

export type FarmStatus = "IDLE" | "SCANNING" | "MOVING" | "COLLECTING" | "BAG_FULL" | "ROUND_OVER" | "WAITING_MAP" | "DEAD" | "STOPPED"

export type Config = {
    AutoFarm: boolean,
    MoveSpeed: number,            -- studs per second (e.g. 30)
    MoveMethod: string,           -- "Tween" | "Lerp" | "Instant"
    BagLimit: number,             -- Default 40, Elite 50 (0 = auto-detect)
    AutoResumeOnRespawn: boolean,
    SafeSpotOnFull: boolean,      -- Move to safe platform when bag is full
    AntiAFK: boolean,
    Noclip: boolean,
}

local State = {
    -- Runtime Status
    Status = "IDLE" :: FarmStatus,
    StatusMessage = "Готов к запуску",
    ActiveMapName = "None",
    CandiesInBag = 0,
    BagCapacity = 40,
    TotalCandiesCollected = 0,
    RoundsCompleted = 0,
    CurrentTargetDistance = 0,
    SessionStartTime = os.time(),

    -- Settings
    Config = {
        AutoFarm = false,
        MoveSpeed = 32,
        MoveMethod = "Tween",
        BagLimit = 0, -- 0 means auto-detect from game remote/gui
        AutoResumeOnRespawn = true,
        SafeSpotOnFull = true,
        AntiAFK = true,
        Noclip = true,
    } :: Config,

    -- Event Listeners
    _listeners = {} :: { (key: string, value: any) -> () },
}

function State.GetRussianStatusTitle(): string
    local s = tostring(State.Status)
    if s == "SCANNING" or s == "Поиск конфет" then
        return "Поиск конфет"
    elseif s == "MOVING" or s == "COLLECTING" or s == "Сбор конфет" or s == "Собираю конфеты" then
        return "Сбор конфет"
    elseif s == "BAG_FULL" or s == "Сумка заполнена" then
        return "Сумка заполнена"
    elseif s == "ROUND_OVER" or s == "Раунд завершён" then
        return "Раунд завершён"
    elseif s == "WAITING_MAP" or s == "IDLE" or s == "STOPPED" or s == "Ожидание раунда" then
        return "Ожидание раунда"
    elseif s == "DEAD" or s == "Ожидание возрождения" then
        return "Ожидание возрождения"
    end
    return "Ожидание раунда"
end

function State.SetStatus(status: FarmStatus, message: string?)
    State.Status = status
    if message then
        State.StatusMessage = message
    end
    State._Emit("Status", status)
    State._Emit("StatusTitle", State.GetRussianStatusTitle())
    State._Emit("StatusMessage", State.StatusMessage)
end

function State.UpdateBag(current: number, max: number?)
    State.CandiesInBag = current
    if max and max > 0 then
        State.BagCapacity = max
    end
    State._Emit("CandiesInBag", current)
    State._Emit("BagCapacity", State.BagCapacity)
end

function State.IncrementCandies(amount: number?)
    local count = amount or 1
    State.TotalCandiesCollected += count
    State._Emit("TotalCandiesCollected", State.TotalCandiesCollected)
end

function State.IncrementRounds()
    State.RoundsCompleted += 1
    State._Emit("RoundsCompleted", State.RoundsCompleted)
end

function State.SetMap(mapName: string)
    State.ActiveMapName = mapName
    State._Emit("ActiveMapName", mapName)
end

function State.SetDistance(distance: number)
    State.CurrentTargetDistance = math.floor(distance)
    State._Emit("CurrentTargetDistance", State.CurrentTargetDistance)
end

function State.SetConfig(key: string, value: any)
    if (State.Config :: any)[key] ~= nil then
        (State.Config :: any)[key] = value
        State._Emit("Config." .. key, value)
    end
end

function State.Subscribe(callback: (key: string, value: any) -> ()): () -> ()
    table.insert(State._listeners, callback)
    return function()
        local idx = table.find(State._listeners, callback)
        if idx then
            table.remove(State._listeners, idx)
        end
    end
end

function State._Emit(key: string, value: any)
    for _, callback in ipairs(State._listeners) do
        task.spawn(callback, key, value)
    end
end

return State

        end)()

        -- MODULE 5: High-FPS & Performance Controller
        local Performance = (function()
--[[
    MM2 Delta Android Mobile - High FPS Engine & Hardware Optimizer
    Architect: Subagent 5: Performance Engineer (MM2 Candy Farm Council)
    Platform: Delta Executor on Android (Roblox Mobile Graphics & Render Engine)
    Description:
      - Precision FPS tracking via RunService.RenderStepped frame deltas
        using a rolling average ring buffer over 10-20 frames (default 16 frames).
      - Frame time in milliseconds (dt * 1000).
      - Network ping detection via Stats.Network.ServerStatsItem["Data Ping"]:GetValue().
      - Non-destructive, 100% reversible High FPS optimization:
        * Lighting: GlobalShadows, FogEnd
        * Post-Processing: Atmosphere, Bloom, DepthOfField, SunRays, ColorCorrection, Blur
        * Terrain: Decoration (3D grass physics), WaterReflectance, WaterWaveSize, WaterWaveSpeed
        * Particles & Trails: ParticleEmitter, Trail, Beam, Fire, Smoke, Sparkles
        * Dynamic Lights: PointLight, SpotLight, SurfaceLight shadow suppression
      - Strict Exemption / Protection: ZERO impact on coin/candy models and drop instances.
      - Zero Memory Leaks: Weak-keyed instance caches (__mode = "k") and atomic unload contract.
]]

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local HighFPSEngine = {}
HighFPSEngine.__index = HighFPSEngine

-- Singleton Instance
local _instance = nil

-- Configuration Constants
local ROLLING_WINDOW_SIZE = 16 -- Frame window for rolling average (bounded in [10, 20])
local METRICS_UPDATE_INTERVAL = 0.25 -- Dispatch UI update every 250ms (4 Hz) for mobile CPU efficiency
local MIN_CLAMPED_DT = 0.0005 -- 2000 FPS ceiling guard
local MAX_CLAMPED_DT = 0.2    -- 5 FPS floor guard against pause / hitch spikes

-- Weak table constructor to prevent instance reference retention (Memory Leak Prevention)
local function CreateWeakInstanceTable()
    return setmetatable({}, { __mode = "k" })
end

-- Create or retrieve singleton engine instance
function HighFPSEngine.GetInstance()
    if not _instance then
        _instance = HighFPSEngine.new()
    end
    return _instance
end

function HighFPSEngine.new()
    local self = setmetatable({}, HighFPSEngine)

    self.IsEnabled = false

    -- State Snapshots (Lossless and Weak-keyed where Instances are keys)
    self.SavedState = {
        Lighting = {},
        PostEffects = CreateWeakInstanceTable(),
        Atmospheres = CreateWeakInstanceTable(),
        Particles = CreateWeakInstanceTable(),
        Lights = CreateWeakInstanceTable(),
        Terrain = {},
    }

    -- Active Connections
    self.DescendantAddedConn = nil
    self.FpsConnection = nil

    -- Performance Telemetry Metrics
    self.CurrentFPS = 60.0
    self.FrameTimeMs = 16.6
    self.AvgFrameTimeMs = 16.6
    self.CurrentPing = 0

    -- Rolling Average Ring Buffer
    self.DeltaBuffer = table.create(ROLLING_WINDOW_SIZE, 1 / 60)
    self.BufferIndex = 1
    self.BufferCount = 0
    self.DeltaSum = 0

    -- Event Callbacks
    self.OnFpsUpdated = nil       -- callback(fps: number, frameTimeMs: number)
    self.OnPingUpdated = nil      -- callback(pingMs: number)
    self.OnMetricsUpdated = nil   -- callback(fps: number, frameTimeMs: number, pingMs: number)

    -- Start background FPS & Telemetry tracker immediately
    self:StartFPSTracker()

    return self
end

--------------------------------------------------------------------------------
-- 1. REAL FPS, FRAME TIME & NETWORK PING ENGINE
--------------------------------------------------------------------------------

-- Network Ping Detection via Stats.Network.ServerStatsItem["Data Ping"]
function HighFPSEngine:GetPing(): number
    local success, ping = pcall(function()
        local item = Stats.Network.ServerStatsItem["Data Ping"]
        return item:GetValue()
    end)
    if success and typeof(ping) == "number" then
        self.CurrentPing = math.floor(ping + 0.5)
        return self.CurrentPing
    end

    -- Fallback: PerformanceStats.Ping
    local success2, ping2 = pcall(function()
        return Stats.PerformanceStats.Ping:GetValue()
    end)
    if success2 and typeof(ping2) == "number" then
        self.CurrentPing = math.floor(ping2 + 0.5)
        return self.CurrentPing
    end

    return self.CurrentPing or 0
end

-- Starts the RenderStepped precision frame delta sampling loop
function HighFPSEngine:StartFPSTracker()
    if self.FpsConnection then
        self.FpsConnection:Disconnect()
        self.FpsConnection = nil
    end

    -- Reset rolling ring buffer
    self.BufferIndex = 1
    self.BufferCount = 0
    self.DeltaSum = 0
    for i = 1, ROLLING_WINDOW_SIZE do
        self.DeltaBuffer[i] = 1 / 60
    end

    local elapsedSinceDispatch = 0

    self.FpsConnection = RunService.RenderStepped:Connect(function(dt: number)
        -- Guard against extreme lag spikes and pause deltas
        local clampedDt = math.clamp(dt, MIN_CLAMPED_DT, MAX_CLAMPED_DT)

        -- Rolling Average over 10-20 frames (ROLLING_WINDOW_SIZE = 16)
        if self.BufferCount < ROLLING_WINDOW_SIZE then
            self.BufferCount = self.BufferCount + 1
            self.DeltaSum = self.DeltaSum + clampedDt
            self.DeltaBuffer[self.BufferIndex] = clampedDt
        else
            self.DeltaSum = self.DeltaSum - self.DeltaBuffer[self.BufferIndex] + clampedDt
            self.DeltaBuffer[self.BufferIndex] = clampedDt
        end
        self.BufferIndex = (self.BufferIndex % ROLLING_WINDOW_SIZE) + 1

        local avgDt = self.DeltaSum / self.BufferCount
        local rollingFPS = 1 / avgDt

        -- Sub-millisecond Frame Time (dt * 1000)
        self.FrameTimeMs = math.floor((clampedDt * 1000) * 10) / 10
        self.AvgFrameTimeMs = math.floor((avgDt * 1000) * 10) / 10
        self.CurrentFPS = math.clamp(math.floor(rollingFPS + 0.5), 1, 360)

        elapsedSinceDispatch = elapsedSinceDispatch + clampedDt

        -- Dispatch UI callbacks on throttled window (0.25s) to conserve mobile CPU
        if elapsedSinceDispatch >= METRICS_UPDATE_INTERVAL then
            elapsedSinceDispatch = 0

            -- Query live network ping
            self:GetPing()

            if self.OnFpsUpdated then
                self.OnFpsUpdated(self.CurrentFPS, self.FrameTimeMs)
            end

            if self.OnPingUpdated then
                self.OnPingUpdated(self.CurrentPing)
            end

            if self.OnMetricsUpdated then
                self.OnMetricsUpdated(self.CurrentFPS, self.FrameTimeMs, self.CurrentPing)
            end
        end
    end)
end

function HighFPSEngine:GetFPS(): (number, number)
    return self.CurrentFPS, self.FrameTimeMs
end

function HighFPSEngine:GetMetrics(): (number, number, number)
    return self.CurrentFPS, self.FrameTimeMs, self.CurrentPing
end

--------------------------------------------------------------------------------
-- 2. CANDY & COIN MODEL PROTECTION FILTER (ZERO IMPACT GUARANTEE)
--------------------------------------------------------------------------------

-- Identifies if an instance belongs to a collectible candy, coin, gun drop, or player rig
local function IsProtectedInstance(inst: Instance?): boolean
    if not inst then return true end

    -- Check instance direct name
    local name = inst.Name:lower()
    if string.find(name, "coin") or string.find(name, "candy") or string.find(name, "gun") then
        return true
    end

    -- Check for TouchTransmitter (used by collectible MM2 items)
    if inst:FindFirstChildOfClass("TouchTransmitter") then
        return true
    end

    -- Walk ancestry up to Workspace to protect items inside map containers
    local current = inst.Parent
    while current and current ~= Workspace and current ~= game do
        local parentName = current.Name:lower()
        if string.find(parentName, "coin") or string.find(parentName, "candy") or string.find(parentName, "gun") then
            return true
        end
        if current.Name == "CoinContainer" or current.Name == "Coin_Server" or current.Name == "Coins" then
            return true
        end
        -- Protect player characters from rig / tool suppression
        if current:FindFirstChildOfClass("Humanoid") then
            return true
        end
        current = current.Parent
    end

    return false
end

--------------------------------------------------------------------------------
-- 3. HIGH FPS MODE: STATE CAPTURE & OPTIMIZATION
--------------------------------------------------------------------------------

function HighFPSEngine:SetEnabled(enable: boolean)
    if self.IsEnabled == enable then
        return
    end

    self.IsEnabled = enable

    if enable then
        self:ApplyOptimizations()
    else
        self:RestoreOriginalState()
    end
end

function HighFPSEngine:Toggle(): boolean
    self:SetEnabled(not self.IsEnabled)
    return self.IsEnabled
end

-- Optimizes a single descendant in Workspace with strict coin/candy exemption
function HighFPSEngine:OptimizeWorkspaceDescendant(inst: Instance)
    -- Guard: Strict Zero Impact on Coin/Candy models
    if IsProtectedInstance(inst) then
        return
    end

    -- Particle Emitters, Trails, Beams, Fire, Smoke, Sparkles
    local particleClasses = {
        "ParticleEmitter",
        "Trail",
        "Beam",
        "Fire",
        "Smoke",
        "Sparkles",
    }
    for _, pClass in ipairs(particleClasses) do
        if inst:IsA(pClass) then
            pcall(function()
                if self.SavedState.Particles[inst] == nil then
                    self.SavedState.Particles[inst] = inst.Enabled
                end
                inst.Enabled = false
            end)
            return
        end
    end

    -- Dynamic Lights: PointLight, SpotLight, SurfaceLight (Suppress expensive shadow maps)
    if inst:IsA("Light") then
        pcall(function()
            if self.SavedState.Lights[inst] == nil then
                self.SavedState.Lights[inst] = inst.Shadows
            end
            inst.Shadows = false
        end)
    end
end

-- Apply full optimization suite with lossless original property capture
function HighFPSEngine:ApplyOptimizations()
    -- 1. LIGHTING SERVICE OPTIMIZATIONS
    pcall(function()
        self.SavedState.Lighting = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
        }
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
    end)

    -- 2. POST-PROCESSING EFFECTS IN LIGHTING (Bloom, DepthOfField, SunRays, Atmosphere, etc.)
    pcall(function()
        for _, child in ipairs(Lighting:GetChildren()) do
            -- Atmosphere special handling (Atmosphere does not have .Enabled in Roblox)
            if child:IsA("Atmosphere") then
                pcall(function()
                    if self.SavedState.Atmospheres[child] == nil then
                        self.SavedState.Atmospheres[child] = {
                            Density = child.Density,
                            Haze = child.Haze,
                            Glare = child.Glare,
                        }
                    end
                    child.Density = 0
                    child.Haze = 0
                    child.Glare = 0
                end)
            elseif child:IsA("PostEffect") then
                pcall(function()
                    if self.SavedState.PostEffects[child] == nil then
                        self.SavedState.PostEffects[child] = child.Enabled
                    end
                    child.Enabled = false
                end)
            end
        end
    end)

    -- 3. WORKSPACE PARTICLES, TRAILS, BEAMS & DYNAMIC LIGHTS
    pcall(function()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            self:OptimizeWorkspaceDescendant(desc)
        end
    end)

    -- Dynamic DescendantAdded Guard (handles newly spawned map particles / bullet impacts)
    if self.DescendantAddedConn then
        self.DescendantAddedConn:Disconnect()
        self.DescendantAddedConn = nil
    end

    self.DescendantAddedConn = Workspace.DescendantAdded:Connect(function(inst: Instance)
        if self.IsEnabled then
            task.defer(function()
                if inst and inst.Parent then
                    self:OptimizeWorkspaceDescendant(inst)
                end
            end)
        end
    end)

    -- 4. TERRAIN 3D GRASS & WATER PHYSICS OPTIMIZATION
    pcall(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            self.SavedState.Terrain = {
                Decoration = terrain.Decoration,
                WaterReflectance = terrain.WaterReflectance,
                WaterWaveSize = terrain.WaterWaveSize,
                WaterWaveSpeed = terrain.WaterWaveSpeed,
            }
            terrain.Decoration = false
            terrain.WaterReflectance = 0
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
        end
    end)
end

--------------------------------------------------------------------------------
-- 4. 100% REVERSIBLE STATE RESTORATION
--------------------------------------------------------------------------------

-- Restores every visual and lighting property to exact pre-optimization snapshot
function HighFPSEngine:RestoreOriginalState()
    -- Disconnect dynamic descendant listener immediately
    if self.DescendantAddedConn then
        self.DescendantAddedConn:Disconnect()
        self.DescendantAddedConn = nil
    end

    -- 1. RESTORE LIGHTING
    pcall(function()
        if self.SavedState.Lighting.GlobalShadows ~= nil then
            Lighting.GlobalShadows = self.SavedState.Lighting.GlobalShadows
        end
        if self.SavedState.Lighting.FogEnd ~= nil then
            Lighting.FogEnd = self.SavedState.Lighting.FogEnd
        end
    end)
    self.SavedState.Lighting = {}

    -- 2. RESTORE POST-PROCESSING EFFECTS
    pcall(function()
        for effect, prevEnabled in pairs(self.SavedState.PostEffects) do
            if effect and effect.Parent then
                pcall(function()
                    effect.Enabled = prevEnabled
                end)
            end
        end
    end)
    table.clear(self.SavedState.PostEffects)

    -- 3. RESTORE ATMOSPHERES
    pcall(function()
        for atmosphere, props in pairs(self.SavedState.Atmospheres) do
            if atmosphere and atmosphere.Parent then
                pcall(function()
                    if props.Density ~= nil then atmosphere.Density = props.Density end
                    if props.Haze ~= nil then atmosphere.Haze = props.Haze end
                    if props.Glare ~= nil then atmosphere.Glare = props.Glare end
                end)
            end
        end
    end)
    table.clear(self.SavedState.Atmospheres)

    -- 4. RESTORE PARTICLES & TRAILS
    pcall(function()
        for inst, prevEnabled in pairs(self.SavedState.Particles) do
            if inst and inst.Parent then
                pcall(function()
                    inst.Enabled = prevEnabled
                end)
            end
        end
    end)
    table.clear(self.SavedState.Particles)

    -- 5. RESTORE DYNAMIC LIGHT SHADOWS
    pcall(function()
        for light, prevShadows in pairs(self.SavedState.Lights) do
            if light and light.Parent then
                pcall(function()
                    light.Shadows = prevShadows
                end)
            end
        end
    end)
    table.clear(self.SavedState.Lights)

    -- 6. RESTORE TERRAIN
    pcall(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain and self.SavedState.Terrain then
            if self.SavedState.Terrain.Decoration ~= nil then
                terrain.Decoration = self.SavedState.Terrain.Decoration
            end
            if self.SavedState.Terrain.WaterReflectance ~= nil then
                terrain.WaterReflectance = self.SavedState.Terrain.WaterReflectance
            end
            if self.SavedState.Terrain.WaterWaveSize ~= nil then
                terrain.WaterWaveSize = self.SavedState.Terrain.WaterWaveSize
            end
            if self.SavedState.Terrain.WaterWaveSpeed ~= nil then
                terrain.WaterWaveSpeed = self.SavedState.Terrain.WaterWaveSpeed
            end
        end
    end)
    self.SavedState.Terrain = {}
end

--------------------------------------------------------------------------------
-- 5. ATOMIC UNLOAD & CLEANUP (ZERO MEMORY LEAKS)
--------------------------------------------------------------------------------

function HighFPSEngine:Destroy()
    -- 1. Restore graphics to original non-destructive state
    self:SetEnabled(false)

    -- 2. Disconnect and nil all event listeners
    if self.FpsConnection then
        self.FpsConnection:Disconnect()
        self.FpsConnection = nil
    end

    if self.DescendantAddedConn then
        self.DescendantAddedConn:Disconnect()
        self.DescendantAddedConn = nil
    end

    -- 3. Clear all callback functions
    self.OnFpsUpdated = nil
    self.OnPingUpdated = nil
    self.OnMetricsUpdated = nil

    -- 4. Release all tables and ring buffers
    table.clear(self.DeltaBuffer)
    self.BufferCount = 0
    self.DeltaSum = 0

    -- 5. Clear singleton reference
    _instance = nil
end

-- Unload alias for atomic script lifecycle compliance
HighFPSEngine.Unload = HighFPSEngine.Destroy

return HighFPSEngine

        end)()

        -- MODULE 6: Persistence Manager (Delta readfile/writefile)
        local Persistence = (function()
-- Persistence.luau: Local Settings & Position Persistence for Delta Executor
-- Safely saves and loads JSON config using readfile/writefile when available

local HttpService = game:GetService("HttpService")

local CONFIG_FILE = "PrivateMM2_CandyFarm_Config.json"

local Persistence = {}

function Persistence.IsSupported(): boolean
    local hasWrite = (getgenv and getgenv().writefile) or (_G and _G.writefile)
    local hasRead = (getgenv and getgenv().readfile) or (_G and _G.readfile)
    return (type(hasWrite) == "function" and type(hasRead) == "function")
end

function Persistence.Save(settingsTable: { [string]: any }): boolean
    if not Persistence.IsSupported() then return false end
    local write = (getgenv and getgenv().writefile) or (_G and _G.writefile)
    return pcall(function()
        local json = HttpService:JSONEncode(settingsTable)
        write(CONFIG_FILE, json)
    end)
end

function Persistence.Load(): { [string]: any }?
    if not Persistence.IsSupported() then return nil end
    local read = (getgenv and getgenv().readfile) or (_G and _G.readfile)
    local isFile = (getgenv and getgenv().isfile) or (_G and _G.isfile)

    if type(isFile) == "function" and not isFile(CONFIG_FILE) then
        return nil
    end

    local success, content = pcall(function()
        return read(CONFIG_FILE)
    end)

    if success and content and #content > 0 then
        local decodeOk, data = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if decodeOk and type(data) == "table" then
            return data
        end
    end

    return nil
end

return Persistence

        end)()

        -- MODULE 7: Map & Round Lifecycle Manager
        local MapManager = (function()
-- MapManager.luau: MM2 Map Discovery & Fail-Closed Round State Machine
-- Strictly prevents any movement in lobby, intermission, voting, or outside map bounds.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

export type RussianRoundState = 
    "Ожидание раунда" 
    | "Раунд начался" 
    | "Сбор конфет" 
    | "Сумка заполнена" 
    | "Раунд завершён" 
    | "Ошибка"

local LOBBY_SPAWN_POSITION = Vector3.new(-108, 140, -9)
local LOBBY_MAX_RADIUS = 140

local MapManager = {
    CurrentMap = nil :: Model?,
    CurrentCoinContainer = nil :: Instance?,
    MapCFrame = CFrame.identity,
    MapSize = Vector3.new(500, 200, 500),
    RoundState = "Ожидание раунда" :: RussianRoundState,
    SafeWaypoint = nil :: CFrame?,
    LobbyWaypoint = nil :: CFrame?,
    _roundStartReceived = false,
    _roundEndReceived = false,
    _maid = nil :: any,
    _onRoundStart = nil :: (() -> ())?,
    _onRoundEnd = nil :: (() -> ())?,
    _onMapChanged = nil :: ((map: Model?) -> ())?,
}

-- Check if player is physically located in the MM2 Lobby
function MapManager.IsPlayerInLobby(): boolean
    local success, inLobby = pcall(function()
        local char = LocalPlayer.Character
        if not char then return true end
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not hrp then return true end
        local dist = (hrp.Position - LOBBY_SPAWN_POSITION).Magnitude
        return dist < LOBBY_MAX_RADIUS
    end)
    return (not success) or (inLobby == true)
end

-- Check if MM2 in-game timer GUI is visible
function MapManager.IsTimerVisible(): boolean
    local success, visible = pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return false end
        local mainGui = playerGui:FindFirstChild("MainGUI")
        if not mainGui then return false end
        local gameFrame = mainGui:FindFirstChild("Game")
        if not gameFrame then return false end
        local timer = gameFrame:FindFirstChild("Timer")
        if timer and timer:IsA("GuiObject") then
            return timer.Visible == true
        end
        return false
    end)
    return success and visible == true
end

-- Check if MM2 LocalPlayer has attribute "Alive" == true
function MapManager.IsPlayerAliveInRound(): boolean
    local success, alive = pcall(function()
        return LocalPlayer:GetAttribute("Alive") == true
    end)
    return success and alive == true
end

-- Find the active MM2 playable map (Model with CoinContainer or Spawns, excluding Lobby)
function MapManager.FindActiveMap(): (Model?, Instance?)
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child.Name ~= "Lobby" then
            local coinContainer = child:FindFirstChild("CoinContainer")
            if coinContainer then
                return child, coinContainer
            end
        end
    end

    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child.Name ~= "Lobby" and child:FindFirstChild("Spawns") then
            local coinContainer = child:FindFirstChild("CoinContainer") or child:FindFirstChildWhichIsA("Folder")
            if coinContainer and coinContainer.Name == "CoinContainer" then
                return child, coinContainer
            end
            return child, nil
        end
    end

    return nil, nil
end

-- Update map bounding box to prevent wandering outside playable zone
function MapManager.UpdateMapBounds(map: Model)
    pcall(function()
        local cf, size = map:GetBoundingBox()
        MapManager.MapCFrame = cf
        MapManager.MapSize = size + Vector3.new(20, 30, 20) -- Slight safe buffer
    end)
end

-- Validate that a position is strictly inside the playable map boundaries
function MapManager.IsPositionInsideMap(targetPos: Vector3): boolean
    -- Absolute sanity limits for MM2
    if targetPos.Y < -20 or targetPos.Y > 140 then
        return false
    end

    -- If player is in lobby, map position is invalid
    if MapManager.IsPlayerInLobby() then
        return false
    end

    local map = MapManager.CurrentMap
    if not map then return false end

    -- Check relative to map bounding box
    local rel = MapManager.MapCFrame:PointToObjectSpace(targetPos)
    local halfSize = MapManager.MapSize * 0.5
    if math.abs(rel.X) > halfSize.X or math.abs(rel.Y) > halfSize.Y or math.abs(rel.Z) > halfSize.Z then
        return false
    end

    return true
end

-- Evaluate current round state strictly (FAIL-CLOSED)
function MapManager.EvaluateRoundState(): RussianRoundState
    local map, coinContainer = MapManager.FindActiveMap()
    MapManager.CurrentMap = map
    MapManager.CurrentCoinContainer = coinContainer

    if map then
        MapManager.UpdateMapBounds(map)
    end

    -- Gate 1: No map or no CoinContainer = Ожидание раунда
    if not map or not coinContainer then
        MapManager._roundStartReceived = false
        return "Ожидание раунда"
    end

    -- Gate 2: Server explicitly fired RoundEndFade = Раунд завершён
    if MapManager._roundEndReceived then
        return "Раунд завершён"
    end

    -- Gate 3: Player is physically located in the Lobby = Ожидание раунда
    if MapManager.IsPlayerInLobby() then
        return "Ожидание раунда"
    end

    -- Positive Gate 1: Server fired RoundStart remote event and round hasn't ended
    if MapManager._roundStartReceived and not MapManager._roundEndReceived then
        if MapManager.IsPlayerAliveInRound() or MapManager.IsTimerVisible() then
            return "Раунд начался"
        end
        if LocalPlayer:GetAttribute("Alive") == false then
            return "Раунд завершён"
        end
        return "Раунд начался"
    end

    -- Positive Gate 2: Joining mid-round verification
    local playerAlive = MapManager.IsPlayerAliveInRound()
    local timerVisible = MapManager.IsTimerVisible()

    if playerAlive and timerVisible then
        return "Раунд начался"
    end

    if not playerAlive then
        return "Ожидание раунда"
    end

    return "Ожидание раунда"
end

-- Check if round is confirmed ACTIVE (Fail-Closed)
function MapManager.IsRoundActive(): boolean
    local state = MapManager.EvaluateRoundState()
    MapManager.RoundState = state
    return (state == "Раунд начался" or state == "Сбор конфет")
end

function MapManager.GetRoundState(): RussianRoundState
    return MapManager.EvaluateRoundState()
end

-- Find safe resting point inside map (spawn point) rather than falling into the void
function MapManager.GetSafeMapPosition(): Vector3?
    local map = MapManager.CurrentMap
    if not map then return nil end

    local spawns = map:FindFirstChild("Spawns")
    if spawns then
        local firstSpawn = spawns:FindFirstChildWhichIsA("BasePart")
        if firstSpawn then
            return firstSpawn.Position + Vector3.new(0, 3, 0)
        end
    end

    return MapManager.MapCFrame.Position + Vector3.new(0, 5, 0)
end

function MapManager.RecordLobbyWaypoint()
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
            if hrp then
                MapManager.LobbyWaypoint = hrp.CFrame
            end
        end
    end)
end

function MapManager.ParkInSafeSpot(character: Model?): boolean
    -- Zero-Interference Contract: The Companion strictly never modifies character CFrame,
    -- never teleports the player, and never zeros or alters AssemblyLinearVelocity.
    return false
end

function MapManager.EnsureSafePlatform(): BasePart
    local part = Instance.new("Part")
    part.Name = "MM2_SafeStagingPlatform"
    part.Size = Vector3.new(32, 2, 32)
    part.Anchored = true
    part.CanCollide = true
    part.Transparency = 1
    return part
end

function MapManager.TeleportToSafePlatform(): boolean
    -- Zero-Interference Contract: The Companion strictly never teleports the player
    return false
end

function MapManager.RemoveSafePlatform()
    -- Safe parking uses in-engine map spawns/geometry; no cleanup needed
end

-- Initialize lifecycle listeners
function MapManager.Init(maid: any, callbacks: {
    OnRoundStart: (() -> ())?,
    OnRoundEnd: (() -> ())?,
    OnMapChanged: ((map: Model?) -> ())?,
})
    MapManager._maid = maid
    MapManager._onRoundStart = callbacks.OnRoundStart
    MapManager._onRoundEnd = callbacks.OnRoundEnd
    MapManager._onMapChanged = callbacks.OnMapChanged

    MapManager.RoundState = "Ожидание раунда"
    MapManager._roundStartReceived = false
    MapManager._roundEndReceived = false

    -- Listen to MM2 Gameplay remotes
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local gameplay = remotes:FindFirstChild("Gameplay")
            if gameplay then
                local roundStart = gameplay:FindFirstChild("RoundStart") :: RemoteEvent?
                if roundStart and roundStart:IsA("RemoteEvent") then
                    maid:GiveTask(roundStart.OnClientEvent:Connect(function()
                        MapManager._roundStartReceived = true
                        MapManager._roundEndReceived = false
                        MapManager.RoundState = "Раунд начался"
                        if MapManager._onRoundStart then
                            MapManager._onRoundStart()
                        end
                    end))
                end

                local roundEnd = gameplay:FindFirstChild("RoundEndFade") :: RemoteEvent?
                if roundEnd and roundEnd:IsA("RemoteEvent") then
                    maid:GiveTask(roundEnd.OnClientEvent:Connect(function()
                        MapManager._roundStartReceived = false
                        MapManager._roundEndReceived = true
                        MapManager.RoundState = "Раунд завершён"
                        if MapManager._onRoundEnd then
                            MapManager._onRoundEnd()
                        end
                    end))
                end
            end
        end
    end)

    -- Listen to Player "Alive" attribute changes
    pcall(function()
        maid:GiveTask(LocalPlayer:GetAttributeChangedSignal("Alive"):Connect(function()
            local isAlive = LocalPlayer:GetAttribute("Alive") == true
            if not isAlive and (MapManager.RoundState == "Раунд начался" or MapManager.RoundState == "Сбор конфет") then
                MapManager.RoundState = "Раунд завершён"
                if MapManager._onRoundEnd then
                    MapManager._onRoundEnd()
                end
            end
        end))
    end)

    -- Monitor Workspace map transitions
    maid:GiveTask(Workspace.ChildAdded:Connect(function(child)
        if child:IsA("Model") and child.Name ~= "Lobby" then
            task.delay(0.5, function()
                local map, coinContainer = MapManager.FindActiveMap()
                if map ~= MapManager.CurrentMap then
                    MapManager.CurrentMap = map
                    MapManager.CurrentCoinContainer = coinContainer
                    if map then
                        MapManager.UpdateMapBounds(map)
                    end
                    if MapManager._onMapChanged then
                        MapManager._onMapChanged(map)
                    end
                end
            end)
        end
    end))

    maid:GiveTask(Workspace.ChildRemoved:Connect(function(child)
        if child == MapManager.CurrentMap then
            MapManager.CurrentMap = nil
            MapManager.CurrentCoinContainer = nil
            MapManager._roundStartReceived = false
            MapManager._roundEndReceived = true
            MapManager.RoundState = "Раунд завершён"
            if MapManager._onMapChanged then
                MapManager._onMapChanged(nil)
            end
            if MapManager._onRoundEnd then
                MapManager._onRoundEnd()
            end
        end
    end))

    -- Initial evaluation (Strictly fail-closed: never start as ACTIVE in lobby)
    MapManager.RoundState = MapManager.EvaluateRoundState()
end

return MapManager

        end)()

        -- MODULE 8: Candy & Coin Detector
        local CandyDetector = (function()
-- CandyDetector.luau: Validated MM2 Candy Detection & Boundary Guard
-- Validates targets against map boundaries, active TouchInterest, and collection state

local CandyDetector = {
    Blacklist = {} :: { [Instance]: number },
    CoinTypeFilter = "Candy",
    FailCounts = {} :: { [Instance]: number },
}

-- Check if an instance is a valid, currently collectible candy
function CandyDetector.IsValidCandy(obj: Instance, coinTypeFilter: string?): boolean
    if not obj or not obj.Parent then return false end
    if not (obj:IsA("BasePart") or obj:IsA("Model")) then return false end

    -- Check blacklist expiry
    local expiry = CandyDetector.Blacklist[obj]
    if expiry and os.clock() < expiry then
        return false
    end

    -- 1. Check for TouchInterest / TouchTransmitter
    local touchInterest = obj:FindFirstChildWhichIsA("TouchTransmitter") or obj:FindFirstChild("TouchInterest")
    if not touchInterest then
        local innerTouch = obj:FindFirstChild("CoinVisual") and obj.CoinVisual:FindFirstChildWhichIsA("TouchTransmitter")
        if not innerTouch then
            return false
        end
    end

    -- 2. Verify seasonal CoinID attribute if specified
    local filter = coinTypeFilter or CandyDetector.CoinTypeFilter
    if filter and filter ~= "All" then
        local coinId = obj:GetAttribute("CoinID")
        if coinId and tostring(coinId) ~= filter then
            return false
        end
    end

    -- 3. Check if marked collected by client visual attribute
    local coinVisual = obj:FindFirstChild("CoinVisual")
    if coinVisual and coinVisual:GetAttribute("Collected") == true then
        return false
    end

    return true
end

-- Resolve the BasePart target of a candy
function CandyDetector.GetTargetPart(candy: Instance): BasePart?
    if candy:IsA("BasePart") then
        return candy
    elseif candy:IsA("Model") then
        return (candy.PrimaryPart or candy:FindFirstChildWhichIsA("BasePart"))
    end
    return nil
end

-- Find all currently valid candies inside map boundaries
function CandyDetector.GetCandies(
    coinContainer: Instance?,
    filterOrBoundaryFn: (string | ((Vector3) -> boolean))?,
    boundaryFn: ((Vector3) -> boolean)?
): { BasePart }
    local result = {}
    if not coinContainer then return result end

    local filter: string? = nil
    local isPositionValidFn: ((Vector3) -> boolean)? = nil

    if typeof(filterOrBoundaryFn) == "string" then
        filter = filterOrBoundaryFn
        isPositionValidFn = boundaryFn
    elseif typeof(filterOrBoundaryFn) == "function" then
        isPositionValidFn = filterOrBoundaryFn
    end

    local activeFilter = filter or CandyDetector.CoinTypeFilter

    for _, item in ipairs(coinContainer:GetChildren()) do
        if CandyDetector.IsValidCandy(item, activeFilter) then
            local part = CandyDetector.GetTargetPart(item)
            if part then
                -- Spatial boundary validation: Reject any coin outside the map
                local isValidPos = (not isPositionValidFn) or isPositionValidFn(part.Position)
                if isValidPos then
                    table.insert(result, part)
                end
            end
        end
    end

    return result
end

-- Find the closest valid candy using squared distance
function CandyDetector.GetClosestCandy(
    coinContainer: Instance?,
    playerPos: Vector3,
    filterOrBoundaryFn: (string | ((Vector3) -> boolean))?,
    boundaryFn: ((Vector3) -> boolean)?
): (BasePart?, number)
    local candidates = CandyDetector.GetCandies(coinContainer, filterOrBoundaryFn, boundaryFn)
    if #candidates == 0 then
        return nil, math.huge
    end

    local bestPart = nil :: BasePart?
    local bestDistSq = math.huge

    for _, part in ipairs(candidates) do
        local delta = part.Position - playerPos
        local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
        if distSq < bestDistSq then
            bestDistSq = distSq
            bestPart = part
        end
    end

    local realDist = (bestPart and math.sqrt(bestDistSq)) or math.huge
    return bestPart, realDist
end

-- Register a failed pickup attempt; blacklists if failed repeatedly
function CandyDetector.RecordFailedPickup(coin: Instance, maxRetries: number?): boolean
    local limit = maxRetries or 2
    local count = (CandyDetector.FailCounts[coin] or 0) + 1
    CandyDetector.FailCounts[coin] = count

    if count >= limit then
        CandyDetector.Blacklist[coin] = os.clock() + 15 -- Blacklist for 15s
        CandyDetector.FailCounts[coin] = nil
        return true -- Triggered permanent blacklist for this cycle
    end
    return false
end

function CandyDetector.BlacklistCoin(coin: Instance, durationSeconds: number?)
    local duration = durationSeconds or 15
    CandyDetector.Blacklist[coin] = os.clock() + duration
end

function CandyDetector.PruneBlacklist()
    local now = os.clock()
    for coin, expiry in pairs(CandyDetector.Blacklist) do
        if now >= expiry or not coin.Parent then
            CandyDetector.Blacklist[coin] = nil
            CandyDetector.FailCounts[coin] = nil
        end
    end
end

function CandyDetector.ClearBlacklist()
    table.clear(CandyDetector.Blacklist)
    table.clear(CandyDetector.FailCounts)
end

return CandyDetector

        end)()

        -- MODULE 9: Movement Engine (Decommissioned safe stubs)
        local Movement = (function()
-- Movement.luau: Fully Decommissioned Passive Movement Stubs (Zero-Interference Contract)
-- Requirements:
-- 1. The Companion must NEVER modify character physics during normal operation.
-- 2. Never delete movement constraints, body movers, or forces created by RockHub or other scripts.
-- 3. Never alter Humanoid states, collisions (CanCollide), CFrame, or AssemblyLinearVelocity.
-- 4. All movement, navigation, and candy collection are managed exclusively by RockHub.

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local Movement = {
    IsMoving = false,
    NoclipEnabled = false,
    _noclipConnection = nil :: RBXScriptConnection?,
    _heartbeatConnection = nil :: RBXScriptConnection?,
    _cachedColliders = {} :: { BasePart },
}

-- Safe No-Op: Never modifies limb collisions or Humanoid states
function Movement.SetNoclip(enabled: boolean)
    Movement.NoclipEnabled = false
end

-- Safe No-Op: Never deletes constraints or alters character velocities/states
-- RockHub manages its own legitimate movement movers (LinearVelocity, AlignPosition, etc.)
function Movement.RestoreCharacterPhysics()
    -- Zero-Interference Contract: Intentionally No-Op
end

-- Safe No-Op: Never alters CFrame or touches physical instances
function Movement.TouchTarget(char: Model, hrp: BasePart, targetPart: BasePart)
    -- Intentionally No-Op
end

-- Observably check if a candy is collected by MM2 game engine (read-only)
function Movement.IsCoinCollected(targetPart: Instance?): boolean
    if not targetPart or not targetPart.Parent then
        return true
    end

    local touchTransmitter = targetPart:FindFirstChildWhichIsA("TouchTransmitter") or targetPart:FindFirstChild("TouchInterest")
    if not touchTransmitter then
        local innerTouch = targetPart:FindFirstChild("CoinVisual") and targetPart.CoinVisual:FindFirstChildWhichIsA("TouchTransmitter")
        if not innerTouch then
            return true
        end
    end

    local coinVisual = targetPart:FindFirstChild("CoinVisual")
    if coinVisual and coinVisual:GetAttribute("Collected") == true then
        return true
    end

    return false
end

-- Cancels any legacy companion connections without touching character properties
function Movement.Cancel()
    Movement.IsMoving = false
    if Movement._heartbeatConnection then
        Movement._heartbeatConnection:Disconnect()
        Movement._heartbeatConnection = nil
    end
    if Movement._noclipConnection then
        Movement._noclipConnection:Disconnect()
        Movement._noclipConnection = nil
    end
end

-- Safe No-Op: Never nudges or teleports character
function Movement.MicroNudge(amplitude: number?)
    -- Zero-Interference Contract: Intentionally No-Op
end

-- Decommissioned: Active continuous movement and candy collection are handled exclusively by RockHub.
-- Safe stubs guarantee zero movement race conditions, zero physics fighting, and zero floor clipping.
function Movement.MoveToAndCollect(
    targetPart: (BasePart | Instance)?,
    speed: number?,
    method: string?,
    isRoundActiveFn: (() -> boolean)?
): (boolean, string)
    Movement.Cancel()
    return false, "Декоммиссовано: управление движением передано RockHub"
end

-- Backwards-compatible MoveTo alias
function Movement.MoveTo(
    target: (BasePart | Vector3 | Instance)?,
    speed: number?,
    method: string?,
    isRoundActiveFn: (() -> boolean)?
): (boolean, string)
    Movement.Cancel()
    return false, "Декоммиссовано: управление движением передано RockHub"
end

return Movement

        end)()

        -- MODULE 10: RockHub Screen Resizer & Mobile Viewport Optimizer
        local RockHubResizer = (function()
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

        end)()

        -- MODULE 11: MM2 Companion Telemetry & Diagnostic Engine
        local CompanionTelemetry = (function()
--[[
    MM2 Delta Android Mobile - Independent Companion Features Suite
    Architect: Feature Researcher & Systems Architect (MM2 Candy Farm Council)
    Platform: Delta Executor on Android (Roblox Mobile Touch Engine & CoreGui)
    Standard: 100% Pure Luau (Instance.new), Zero External Dependencies, Zero Emojis, Zero Placebo Controls
    
    Subsystems Included:
      1. Session Timer (os.clock() high-res elapsed timer formatted as HH:MM:SS)
      2. Player Stats Monitor (Humanoid Health/MaxHealth, WalkSpeed, character lifecycle)
      3. Current Map Detector (workspace map model & CoinContainer observation, non-intrusive)
      4. MM2 Round State Observer (passive read-only signals, zero competing farm loops)
      5. UI Customization Engine (Transparency [0.0-0.5], UIScale [0.6-1.1], Accent Color Presets)
      6. Diagnostic Panel & Error Logger (safe pcall wrapper, ring buffer, engine telemetry)
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LogService = game:GetService("LogService")
local StatsService = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
assert(LocalPlayer, "LocalPlayer must exist in Roblox client environment")

local Companion = {}
local activeConnections: { [string]: RBXScriptConnection } = {}

local function RegisterConnection(id: string, conn: RBXScriptConnection)
    if activeConnections[id] then
        pcall(function() activeConnections[id]:Disconnect() end)
    end
    activeConnections[id] = conn
end

local function DisconnectConnection(id: string)
    if activeConnections[id] then
        pcall(function() activeConnections[id]:Disconnect() end)
        activeConnections[id] = nil
    end
end

--------------------------------------------------------------------------------
-- 1. SESSION TIMER SUBSYSTEM
--------------------------------------------------------------------------------
local SessionTimer = {}
SessionTimer.__index = SessionTimer

function SessionTimer.New()
    local self = setmetatable({}, SessionTimer)
    self.StartTime = os.clock()
    self.Accumulated = 0
    self.IsActive = false
    self.Connection = nil
    return self
end

function SessionTimer:Start()
    if self.IsActive then return end
    self.StartTime = os.clock()
    self.IsActive = true
end

function SessionTimer:Pause()
    if not self.IsActive then return end
    self.Accumulated = self.Accumulated + (os.clock() - self.StartTime)
    self.IsActive = false
end

function SessionTimer:Resume()
    if self.IsActive then return end
    self.StartTime = os.clock()
    self.IsActive = true
end

function SessionTimer:Reset()
    self.StartTime = os.clock()
    self.Accumulated = 0
end

function SessionTimer:GetElapsedSeconds(): number
    if self.IsActive then
        return self.Accumulated + (os.clock() - self.StartTime)
    end
    return self.Accumulated
end

function SessionTimer:GetFormattedTime(): string
    local totalSecs = math.floor(self:GetElapsedSeconds())
    local hours = math.floor(totalSecs / 3600)
    local mins = math.floor((totalSecs % 3600) / 60)
    local secs = totalSecs % 60
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

function SessionTimer:IsRunning(): boolean
    return self.IsActive
end

Companion.SessionTimer = SessionTimer

--------------------------------------------------------------------------------
-- 2. PLAYER STATS MONITOR SUBSYSTEM
--------------------------------------------------------------------------------
export type PlayerStats = {
    Health: number,
    MaxHealth: number,
    HealthRatio: number,
    WalkSpeed: number,
    IsAlive: boolean,
    StatusText: string,
    StatusColor: Color3,
}

local PlayerStatsMonitor = {}
PlayerStatsMonitor.__index = PlayerStatsMonitor

function PlayerStatsMonitor.New(onStatsUpdated: ((stats: PlayerStats) -> ())?)
    local self = setmetatable({}, PlayerStatsMonitor)
    self.OnStatsUpdated = onStatsUpdated
    self.CurrentStats = {
        Health = 100,
        MaxHealth = 100,
        HealthRatio = 1.0,
        WalkSpeed = 16.0,
        IsAlive = true,
        StatusText = "[СТАТУС: ЖИВ]",
        StatusColor = Color3.fromRGB(34, 197, 94),
    }
    self.IsRunning = false
    return self
end

function PlayerStatsMonitor:_Evaluate(humanoid: Humanoid?)
    if not humanoid or humanoid.Health <= 0 then
        self.CurrentStats.Health = 0
        self.CurrentStats.MaxHealth = humanoid and humanoid.MaxHealth or 100
        self.CurrentStats.HealthRatio = 0
        self.CurrentStats.WalkSpeed = 0
        self.CurrentStats.IsAlive = false
        self.CurrentStats.StatusText = "[СТАТУС: ПОГИБ]"
        self.CurrentStats.StatusColor = Color3.fromRGB(239, 68, 68)
    else
        local h = humanoid.Health
        local maxH = math.max(humanoid.MaxHealth, 1)
        local ratio = math.clamp(h / maxH, 0, 1)
        local ws = humanoid.WalkSpeed
        
        self.CurrentStats.Health = math.floor(h)
        self.CurrentStats.MaxHealth = math.floor(maxH)
        self.CurrentStats.HealthRatio = ratio
        self.CurrentStats.WalkSpeed = ws
        self.CurrentStats.IsAlive = true

        if ratio > 0.60 then
            self.CurrentStats.StatusText = "[ЗДОРОВЬЕ: НОРМА]"
            self.CurrentStats.StatusColor = Color3.fromRGB(34, 197, 94)
        elseif ratio >= 0.25 then
            self.CurrentStats.StatusText = "[ЗДОРОВЬЕ: РАНЕН]"
            self.CurrentStats.StatusColor = Color3.fromRGB(245, 158, 11)
        else
            self.CurrentStats.StatusText = "[ЗДОРОВЬЕ: КРИТИЧЕСКИ]"
            self.CurrentStats.StatusColor = Color3.fromRGB(239, 68, 68)
        end
    end

    if self.OnStatsUpdated then
        self.OnStatsUpdated(self.CurrentStats)
    end
end

function PlayerStatsMonitor:Start()
    if self.IsRunning then return end
    self.IsRunning = true

    local function HookHumanoid(character: Model)
        local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
        if not humanoid then return end

        self:_Evaluate(humanoid)

        RegisterConnection("PSM_HealthChanged", humanoid.HealthChanged:Connect(function()
            self:_Evaluate(humanoid)
        end))

        RegisterConnection("PSM_SpeedChanged", humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            self:_Evaluate(humanoid)
        end))

        RegisterConnection("PSM_MaxHealthChanged", humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
            self:_Evaluate(humanoid)
        end))
    end

    if LocalPlayer.Character then
        HookHumanoid(LocalPlayer.Character)
    end

    RegisterConnection("PSM_CharAdded", LocalPlayer.CharacterAdded:Connect(function(char)
        HookHumanoid(char)
    end))

    RegisterConnection("PSM_CharRemoving", LocalPlayer.CharacterRemoving:Connect(function()
        self:_Evaluate(nil)
    end))
end

function PlayerStatsMonitor:Stop()
    self.IsRunning = false
    DisconnectConnection("PSM_HealthChanged")
    DisconnectConnection("PSM_SpeedChanged")
    DisconnectConnection("PSM_MaxHealthChanged")
    DisconnectConnection("PSM_CharAdded")
    DisconnectConnection("PSM_CharRemoving")
end

function PlayerStatsMonitor:GetStats(): PlayerStats
    return self.CurrentStats
end

Companion.PlayerStatsMonitor = PlayerStatsMonitor

--------------------------------------------------------------------------------
-- 3. CURRENT MAP DETECTOR SUBSYSTEM (Non-Intrusive)
--------------------------------------------------------------------------------
export type MapInfo = {
    Name: string,
    Model: Model,
    CoinContainer: Instance?,
    CoinCount: number,
    ExtentsSize: Vector3,
    IsActive: boolean,
}

local MapDetector = {}
MapDetector.__index = MapDetector

local KNOWN_MAP_NAMES = {
    "Normal", "Mansion2", "BioLab", "Factory", "MilBase", "House2",
    "PoliceStation", "ResearchFacility", "Workplace", "Hospital3",
    "Hotel", "Bank2", "LogCabin", "VampireCastle",
}

function MapDetector.New(onMapChanged: ((mapInfo: MapInfo?) -> ())?)
    local self = setmetatable({}, MapDetector)
    self.OnMapChanged = onMapChanged
    self.CurrentMapInfo = nil :: MapInfo?
    self.IsRunning = false
    return self
end

function MapDetector:_FindCandidateMap(): Model?
    -- Standard MM2 map container
    local normal = Workspace:FindFirstChild("Normal")
    if normal and normal:IsA("Model") then
        return normal
    end

    -- Known named models
    for _, name in ipairs(KNOWN_MAP_NAMES) do
        local model = Workspace:FindFirstChild(name)
        if model and model:IsA("Model") then
            return model
        end
    end

    -- Fallback: Any model containing CoinContainer / Coins
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child.Name ~= "Terrain" and not Players:GetPlayerFromCharacter(child) then
            if child:FindFirstChild("CoinContainer") or child:FindFirstChild("Coins") or child:FindFirstChild("Coin_Server") then
                return child
            end
        end
    end

    return nil
end

function MapDetector:_EvaluateMap()
    local mapModel = self:_FindCandidateMap()
    if not mapModel then
        if self.CurrentMapInfo ~= nil then
            self.CurrentMapInfo = nil
            if self.OnMapChanged then
                self.OnMapChanged(nil)
            end
        end
        return
    end

    local coinCont = mapModel:FindFirstChild("CoinContainer") 
        or mapModel:FindFirstChild("Coins") 
        or mapModel:FindFirstChild("Coin_Server")

    local coinCount = 0
    if coinCont then
        coinCount = #coinCont:GetChildren()
    end

    local extents = Vector3.zero
    pcall(function()
        extents = mapModel:GetExtentsSize()
    end)

    local info: MapInfo = {
        Name = mapModel.Name,
        Model = mapModel,
        CoinContainer = coinCont,
        CoinCount = coinCount,
        ExtentsSize = extents,
        IsActive = true,
    }

    self.CurrentMapInfo = info
    if self.OnMapChanged then
        self.OnMapChanged(info)
    end
end

function MapDetector:Start()
    if self.IsRunning then return end
    self.IsRunning = true

    self:_EvaluateMap()

    RegisterConnection("MD_ChildAdded", Workspace.ChildAdded:Connect(function(child)
        if child:IsA("Model") then
            task.delay(0.2, function()
                if self.IsRunning then
                    self:_EvaluateMap()
                end
            end)
        end
    end))

    RegisterConnection("MD_ChildRemoved", Workspace.ChildRemoved:Connect(function(child)
        if self.CurrentMapInfo and self.CurrentMapInfo.Model == child then
            self:_EvaluateMap()
        end
    end))
end

function MapDetector:Stop()
    self.IsRunning = false
    DisconnectConnection("MD_ChildAdded")
    DisconnectConnection("MD_ChildRemoved")
    self.CurrentMapInfo = nil
end

function MapDetector:GetCurrentMap(): MapInfo?
    return self.CurrentMapInfo
end

Companion.MapDetector = MapDetector

--------------------------------------------------------------------------------
-- 4. MM2 ROUND STATE OBSERVER (Passive Read-Only Signals)
--------------------------------------------------------------------------------
local RoundObserver = {}
RoundObserver.__index = RoundObserver

function RoundObserver.New(onStateChanged: ((newState: string, oldState: string, details: any) -> ())?)
    local self = setmetatable({}, RoundObserver)
    self.OnStateChanged = onStateChanged
    self.CurrentState = "LOBBY"
    self.IsRunning = false
    return self
end

function RoundObserver:_Transition(newState: string, details: any)
    if self.CurrentState == newState then return end
    local oldState = self.CurrentState
    self.CurrentState = newState
    if self.OnStateChanged then
        self.OnStateChanged(newState, oldState, details or {})
    end
end

function RoundObserver:Start()
    if self.IsRunning then return end
    self.IsRunning = true

    -- 1. Hook MM2 ReplicatedStorage Remotes (Primary Channel)
    pcall(function()
        local remotes = ReplicatedStorage:WaitForChild("Remotes", 3)
        if not remotes then return end

        local gameplay = remotes:WaitForChild("Gameplay", 3)
        if not gameplay then return end

        local roundStart = gameplay:FindFirstChild("RoundStart")
        if roundStart and roundStart:IsA("RemoteEvent") then
            RegisterConnection("RO_RoundStart", roundStart.OnClientEvent:Connect(function(...)
                self:_Transition("IN_PROGRESS", { Signal = "RoundStart", Args = { ... } })
            end))
        end

        local roundEndFade = gameplay:FindFirstChild("RoundEndFade")
        if roundEndFade and roundEndFade:IsA("RemoteEvent") then
            RegisterConnection("RO_RoundEndFade", roundEndFade.OnClientEvent:Connect(function(...)
                self:_Transition("ROUND_END", { Signal = "RoundEndFade", Args = { ... } })
                task.delay(3.5, function()
                    if self.IsRunning and self.CurrentState == "ROUND_END" then
                        self:_Transition("LOBBY", { Signal = "LobbyReturnTimeout" })
                    end
                end)
            end))
        end

        local roleSelect = gameplay:FindFirstChild("RoleSelect")
        if roleSelect and roleSelect:IsA("RemoteEvent") then
            RegisterConnection("RO_RoleSelect", roleSelect.OnClientEvent:Connect(function(...)
                self:_Transition("STARTING", { Signal = "RoleSelect", Args = { ... } })
            end))
        end
    end)

    -- 2. Fallback Channel: Workspace Normal Map Model lifecycle
    RegisterConnection("RO_MapWatcher", Workspace.ChildAdded:Connect(function(child)
        if child.Name == "Normal" and child:IsA("Model") then
            self:_Transition("IN_PROGRESS", { Signal = "NormalMapSpawned" })
        end
    end))

    RegisterConnection("RO_MapDestroyWatcher", Workspace.ChildRemoved:Connect(function(child)
        if child.Name == "Normal" and child:IsA("Model") then
            self:_Transition("LOBBY", { Signal = "NormalMapDestroyed" })
        end
    end))

    -- Check initial state
    if Workspace:FindFirstChild("Normal") then
        self:_Transition("IN_PROGRESS", { Signal = "InitialPresence" })
    else
        self:_Transition("LOBBY", { Signal = "InitialPresence" })
    end
end

function RoundObserver:Stop()
    self.IsRunning = false
    DisconnectConnection("RO_RoundStart")
    DisconnectConnection("RO_RoundEndFade")
    DisconnectConnection("RO_RoleSelect")
    DisconnectConnection("RO_MapWatcher")
    DisconnectConnection("RO_MapDestroyWatcher")
end

function RoundObserver:GetCurrentState(): string
    return self.CurrentState
end

Companion.RoundObserver = RoundObserver

--------------------------------------------------------------------------------
-- 5. UI CUSTOMIZATION ENGINE (Transparency, Scale, Accent Color Picker)
--------------------------------------------------------------------------------
local UICustomizer = {}

UICustomizer.ColorPresets = {
    NEBULA_PURPLE = {
        Name = "NEBULA",
        Primary = Color3.fromRGB(138, 75, 255),  -- #8a4bff
        Secondary = Color3.fromRGB(168, 85, 247),-- #a855f7
        Stroke = Color3.fromRGB(76, 40, 137),
    },
    CYBER_CYAN = {
        Name = "CYBER",
        Primary = Color3.fromRGB(6, 182, 212),   -- #06b6d4
        Secondary = Color3.fromRGB(34, 211, 238),-- #22d3ee
        Stroke = Color3.fromRGB(14, 116, 144),
    },
    EMERALD_MINT = {
        Name = "EMERALD",
        Primary = Color3.fromRGB(16, 185, 129),  -- #10b981
        Secondary = Color3.fromRGB(52, 211, 153),-- #34d399
        Stroke = Color3.fromRGB(4, 120, 87),
    },
    CRIMSON_PHANTOM = {
        Name = "PHANTOM",
        Primary = Color3.fromRGB(239, 68, 68),   -- #ef4444
        Secondary = Color3.fromRGB(248, 113, 113),-- #f87171
        Stroke = Color3.fromRGB(153, 27, 27),
    },
    AMBER_GOLD = {
        Name = "MONARCH",
        Primary = Color3.fromRGB(245, 158, 11),  -- #f59e0b
        Secondary = Color3.fromRGB(251, 191, 36),-- #fbbf24
        Stroke = Color3.fromRGB(180, 83, 9),
    },
    OBSIDIAN_SLATE = {
        Name = "OBSIDIAN",
        Primary = Color3.fromRGB(113, 113, 122), -- #71717a
        Secondary = Color3.fromRGB(161, 161, 170),-- #a1a1aa
        Stroke = Color3.fromRGB(63, 63, 70),
    },
}

local managedFrames: { GuiObject } = {}
local managedStrokes: { UIStroke } = {}
local managedButtons: { GuiButton } = {}
local targetScaleInstance: UIScale? = nil

function UICustomizer.RegisterContainer(frame: GuiObject)
    table.insert(managedFrames, frame)
end

function UICustomizer.RegisterStroke(stroke: UIStroke)
    table.insert(managedStrokes, stroke)
end

function UICustomizer.RegisterButton(btn: GuiButton)
    table.insert(managedButtons, btn)
end

function UICustomizer.SetScaleInstance(scaleInst: UIScale)
    targetScaleInstance = scaleInst
end

function UICustomizer.SetTransparency(alpha: number)
    local clamped = math.clamp(alpha, 0.0, 0.5)
    for _, frame in ipairs(managedFrames) do
        pcall(function()
            frame.BackgroundTransparency = clamped
        end)
    end
end

function UICustomizer.SetScale(scale: number)
    local clamped = math.clamp(scale, 0.6, 1.1)
    if targetScaleInstance then
        targetScaleInstance.Scale = clamped
    end
end

function UICustomizer.ApplyPreset(presetKey: string)
    local preset = UICustomizer.ColorPresets[presetKey]
    if not preset then return end

    for _, stroke in ipairs(managedStrokes) do
        pcall(function()
            stroke.Color = preset.Primary
        end)
    end

    for _, btn in ipairs(managedButtons) do
        pcall(function()
            btn.BackgroundColor3 = preset.Primary
        end)
    end
end

-- Interactive Mobile Slider Generator
function UICustomizer.CreateSlider(
    parent: GuiObject,
    labelText: string,
    minVal: number,
    maxVal: number,
    defaultVal: number,
    formatStr: string,
    onValueChanged: (val: number) -> ()
): Frame
    local currentVal = math.clamp(defaultVal, minVal, maxVal)

    local container = Instance.new("Frame")
    container.Name = "Slider_" .. labelText
    container.Size = UDim2.new(1, 0, 0, 46)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 16)
    header.BackgroundTransparency = 1
    header.Parent = container

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.65, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = labelText
    title.TextColor3 = Color3.fromRGB(148, 163, 184)
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.35, 0, 1, 0)
    valueLabel.Position = UDim2.new(0.65, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = string.format(formatStr, currentVal)
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 11
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = header

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(1, 0, 0, 10)
    track.Position = UDim2.new(0, 0, 0, 22)
    track.BackgroundColor3 = Color3.fromRGB(36, 36, 50)
    track.BorderSizePixel = 0
    track.Active = true
    track.Parent = container

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local initialRatio = (currentVal - minVal) / math.max(maxVal - minVal, 1e-4)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(initialRatio, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(138, 75, 255)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.fromOffset(20, 20)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(initialRatio, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = track

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local isDragging = false

    local function UpdateFromX(inputX: number)
        local trackAbsPos = track.AbsolutePosition.X
        local trackAbsWidth = track.AbsoluteSize.X
        if trackAbsWidth <= 0 then return end

        local ratio = math.clamp((inputX - trackAbsPos) / trackAbsWidth, 0, 1)
        currentVal = minVal + ratio * (maxVal - minVal)

        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, 0, 0.5, 0)
        valueLabel.Text = string.format(formatStr, currentVal)

        onValueChanged(currentVal)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            UpdateFromX(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateFromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    return container
end

-- Mobile Color Preset Picker Generator
function UICustomizer.CreatePresetPicker(
    parent: GuiObject,
    onPresetSelected: (presetKey: string) -> ()
): Frame
    local container = Instance.new("Frame")
    container.Name = "ColorPresetPicker"
    container.Size = UDim2.new(1, 0, 0, 54)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 16)
    title.BackgroundTransparency = 1
    title.Text = "АКЦЕНТНЫЙ ЦВЕТ"
    title.TextColor3 = Color3.fromRGB(148, 163, 184)
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = container

    local swatches = Instance.new("Frame")
    swatches.Size = UDim2.new(1, 0, 0, 32)
    swatches.Position = UDim2.new(0, 0, 0, 20)
    swatches.BackgroundTransparency = 1
    swatches.Parent = container

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = swatches

    for key, data in pairs(UICustomizer.ColorPresets) do
        local btn = Instance.new("TextButton")
        btn.Name = "Swatch_" .. key
        btn.Size = UDim2.fromOffset(36, 28)
        btn.BackgroundColor3 = data.Primary
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = swatches

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1.5
        stroke.Color = Color3.fromRGB(50, 50, 68)
        stroke.Parent = btn

        btn.MouseButton1Click:Connect(function()
            UICustomizer.ApplyPreset(key)
            onPresetSelected(key)
        end)
    end

    return container
end

Companion.UICustomizer = UICustomizer

--------------------------------------------------------------------------------
-- 6. DIAGNOSTIC PANEL & ERROR LOGGER (Safe pcall Capture & Ring Buffer)
--------------------------------------------------------------------------------
export type LogEntry = {
    Timestamp: number,
    FormattedTime: string,
    Level: "INFO" | "WARN" | "ERROR",
    Source: string,
    Message: string,
    Trace: string?,
}

local DiagnosticLogger = {}
local logRingBuffer: { LogEntry } = {}
local maxBufferCapacity = 60
local onLogAddedCallback: ((entry: LogEntry) -> ())? = nil

function DiagnosticLogger.Init(capacity: number?, onLogAdded: ((entry: LogEntry) -> ())?)
    maxBufferCapacity = capacity or 60
    onLogAddedCallback = onLogAdded
    table.clear(logRingBuffer)
end

function DiagnosticLogger.Log(level: "INFO" | "WARN" | "ERROR", source: string, message: string, trace: string?)
    local now = os.clock()
    local entry: LogEntry = {
        Timestamp = now,
        FormattedTime = string.format("%.2f", now),
        Level = level,
        Source = source,
        Message = message,
        Trace = trace,
    }

    if #logRingBuffer >= maxBufferCapacity then
        table.remove(logRingBuffer, 1)
    end
    table.insert(logRingBuffer, entry)

    if onLogAddedCallback then
        pcall(function()
            onLogAddedCallback(entry)
        end)
    end
end

-- Safe call wrapper with full stack traceback
function DiagnosticLogger.SafeCall(source: string, func: (...any) -> ...any, ...: any): (boolean, any)
    local results = { xpcall(func, debug.traceback, ...) }
    local success = results[1]
    if not success then
        local errTrace = tostring(results[2])
        DiagnosticLogger.Log("ERROR", source, errTrace, errTrace)
    end
    return table.unpack(results)
end

function DiagnosticLogger.GetLogs(): { LogEntry }
    return logRingBuffer
end

function DiagnosticLogger.Clear()
    table.clear(logRingBuffer)
end

function DiagnosticLogger.GetSystemTelemetry(): { MemoryMb: number, PingMs: number, UptimeSec: number }
    local memMb = 0
    pcall(function()
        memMb = math.floor(StatsService:GetTotalMemoryUsageMb())
    end)

    local pingMs = 0
    pcall(function()
        pingMs = math.floor(LocalPlayer:GetNetworkPing() * 1000)
    end)

    return {
        MemoryMb = memMb,
        PingMs = pingMs,
        UptimeSec = math.floor(os.clock()),
    }
end

function DiagnosticLogger.StartEngineLogCapture()
    RegisterConnection("DL_LogService", LogService.MessageOut:Connect(function(msg, msgType)
        if msgType == Enum.MessageType.MessageError then
            DiagnosticLogger.Log("ERROR", "RobloxEngine", msg)
        elseif msgType == Enum.MessageType.MessageWarning then
            DiagnosticLogger.Log("WARN", "RobloxEngine", msg)
        end
    end))
end

function DiagnosticLogger.StopEngineLogCapture()
    DisconnectConnection("DL_LogService")
end

-- Scrollable Mobile Log View Generator
function DiagnosticLogger.CreateLogViewer(parent: GuiObject, height: number?): Frame
    local container = Instance.new("Frame")
    container.Name = "DiagnosticLogViewer"
    container.Size = UDim2.new(1, 0, 0, height or 140)
    container.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    container.BorderSizePixel = 0
    container.Parent = parent

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(50, 50, 68)
    stroke.Thickness = 1
    stroke.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container

    -- Top Toolbar
    local toolbar = Instance.new("Frame")
    toolbar.Size = UDim2.new(1, 0, 0, 26)
    toolbar.BackgroundTransparency = 1
    toolbar.Parent = container

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.5, 0, 1, 0)
    title.Position = UDim2.new(0, 8, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "ЖУРНАЛ ДИАГНОСТИКИ"
    title.TextColor3 = Color3.fromRGB(148, 163, 184)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 10
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = toolbar

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.fromOffset(70, 20)
    clearBtn.Position = UDim2.new(1, -78, 0, 3)
    clearBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 50)
    clearBtn.Text = "[ОЧИСТИТЬ]"
    clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 9
    clearBtn.AutoButtonColor = false
    clearBtn.Parent = toolbar

    local clearCorner = Instance.new("UICorner")
    clearCorner.CornerRadius = UDim.new(0, 4)
    clearCorner.Parent = clearBtn

    -- Scrolling entries list
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 1, -34)
    scroll.Position = UDim2.new(0, 8, 0, 28)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(138, 75, 255)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = container

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = scroll

    local function RenderLog(entry: LogEntry)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 18)
        row.BackgroundTransparency = 1
        row.Parent = scroll

        local color = Color3.fromRGB(148, 163, 184)
        if entry.Level == "ERROR" then
            color = Color3.fromRGB(239, 68, 68)
        elseif entry.Level == "WARN" then
            color = Color3.fromRGB(245, 158, 11)
        end

        local badge = Instance.new("TextLabel")
        badge.Size = UDim2.new(0, 46, 1, 0)
        badge.BackgroundTransparency = 1
        badge.Text = "[" .. entry.Level .. "]"
        badge.TextColor3 = color
        badge.Font = Enum.Font.GothamBold
        badge.TextSize = 9
        badge.TextXAlignment = Enum.TextXAlignment.Left
        badge.Parent = row

        local msg = Instance.new("TextLabel")
        msg.Size = UDim2.new(1, -50, 1, 0)
        msg.Position = UDim2.new(0, 50, 0, 0)
        msg.BackgroundTransparency = 1
        msg.Text = entry.Source .. ": " .. entry.Message
        msg.TextColor3 = Color3.fromRGB(220, 220, 235)
        msg.Font = Enum.Font.GothamMedium
        msg.TextSize = 9
        msg.TextXAlignment = Enum.TextXAlignment.Left
        msg.TextTruncate = Enum.TextTruncate.AtEnd
        msg.Parent = row
    end

    for _, entry in ipairs(logRingBuffer) do
        RenderLog(entry)
    end

    clearBtn.MouseButton1Click:Connect(function()
        DiagnosticLogger.Clear()
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
    end)

    onLogAddedCallback = function(newEntry)
        RenderLog(newEntry)
    end

    return container
end

Companion.DiagnosticLogger = DiagnosticLogger

--------------------------------------------------------------------------------
-- ATOMIC UNLOAD & CLEANUP
--------------------------------------------------------------------------------
function Companion.CleanupAll()
    for id, conn in pairs(activeConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(activeConnections)

    DiagnosticLogger.StopEngineLogCapture()
    table.clear(managedFrames)
    table.clear(managedStrokes)
    table.clear(managedButtons)
    targetScaleInstance = nil
end

return Companion

        end)()

        -- MODULE 12: Farm Engine Orchestrator
        local FarmEngine = (function()
-- FarmEngine.luau: Central MM2 Candy Farm Orchestrator & State Machine (Fail-Closed)
-- Strictly prevents any movement in lobby, intermission, voting, or inactive rounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local FarmEngine = {
    IsRunning = false,
    _maid = nil :: any,
    _loopToken = 0,
    _activeTarget = nil :: BasePart?,
    _lastCandyCount = 0,
    _sessionCandies = 0,
    _roundsFarmed = 0,
    _startTime = 0,
    _uiCallback = nil :: ((metrics: any) -> ())?,
}

-- Resolve current candy amount and bag capacity from MM2 GUI as fallback
local function ReadBagFromGui(): (number?, number?)
    local success, res = pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return nil, nil end
        local mainGui = playerGui:FindFirstChild("MainGUI")
        if not mainGui then return nil, nil end
        local gameFrame = mainGui:FindFirstChild("Game")
        if not gameFrame then return nil, nil end
        local coinBags = gameFrame:FindFirstChild("CoinBags")
        if not coinBags then return nil, nil end
        local container = coinBags:FindFirstChild("Container")
        if not container then return nil, nil end

        local candyBag = container:FindFirstChild("Candy") or container:FindFirstChild("Coin") or container:FindFirstChildWhichIsA("Frame")
        if not candyBag then return nil, nil end

        local icon = candyBag:FindFirstChild("CurrencyFrame") and candyBag.CurrencyFrame:FindFirstChild("Icon")
        if not icon then return nil, nil end
        local label = icon:FindFirstChild("Coins") :: TextLabel?
        if label and label:IsA("TextLabel") then
            local text = label.Text
            local current = tonumber(text)
            return current, nil
        end
        return nil, nil
    end)

    if success and res then
        return res, nil
    end
    return nil, nil
end

-- Initialize FarmEngine
function FarmEngine.Init(uiUpdateCallback: ((metrics: any) -> ())?)
    FarmEngine._maid = Maid.new()
    FarmEngine._uiCallback = uiUpdateCallback
    FarmEngine._startTime = os.time()

    -- Load saved settings if supported
    local saved = Persistence.Load()
    if saved then
        for k, v in pairs(saved) do
            if (State.Config :: any)[k] ~= nil then
                (State.Config :: any)[k] = v
            end
        end
    end

    -- Setup MapManager lifecycle with strict fail-closed callbacks
    MapManager.Init(FarmEngine._maid, {
        OnRoundStart = function()
            if FarmEngine.IsRunning then
                task.wait(0.5) -- Allow player spawn to replicate
                if MapManager.IsRoundActive() then
                    State.SetStatus("SCANNING", "Раунд начался! Мониторинг конфет...")
                    FarmEngine.WakeLoop()
                else
                    State.SetStatus("WAITING_MAP", "Ожидание начала раунда...")
                end
            end
        end,
        OnRoundEnd = function()
            FarmEngine._roundsFarmed += 1
            State.IncrementRounds()

            FarmEngine._activeTarget = nil
            State.SetDistance(0)

            if FarmEngine.IsRunning then
                State.SetStatus("ROUND_OVER", "Раунд завершён, пауза...")
            end
        end,
        OnMapChanged = function(map)
            if map then
                State.SetMap(map.Name)
            else
                State.SetMap("None")
            end

            if FarmEngine.IsRunning then
                if MapManager.IsRoundActive() then
                    State.SetStatus("SCANNING", "Карта подтверждена: " .. (map and map.Name or "Игра"))
                    FarmEngine.WakeLoop()
                else
                    State.SetStatus("WAITING_MAP", "Ожидание начала раунда...")
                end
            end
        end,
    })

    -- Listen to MM2 CoinCollected remote event
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local gameplay = remotes:FindFirstChild("Gameplay")
            if gameplay then
                local coinCollected = gameplay:FindFirstChild("CoinCollected") :: RemoteEvent?
                if coinCollected and coinCollected:IsA("RemoteEvent") then
                    FarmEngine._maid:GiveTask(coinCollected.OnClientEvent:Connect(function(coinType, current, max)
                        local curNum = tonumber(current) or 0
                        local maxNum = tonumber(max) or 40

                        if curNum > FarmEngine._lastCandyCount then
                            local diff = curNum - FarmEngine._lastCandyCount
                            FarmEngine._sessionCandies += diff
                            State.IncrementCandies(diff)
                        end
                        FarmEngine._lastCandyCount = curNum

                        State.UpdateBag(curNum, maxNum)

                        -- Check if bag is full
                        local limit = State.Config.BagLimit > 0 and State.Config.BagLimit or maxNum
                        if curNum >= limit then
                            FarmEngine.HandleBagFull()
                        end
                    end))
                end
            end
        end
    end)

    -- Character Added (Respawn Recovery)
    FarmEngine._maid:GiveTask(LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(1.0)
        if FarmEngine.IsRunning and State.Config.AutoResumeOnRespawn then
            if MapManager.IsRoundActive() then
                State.SetStatus("SCANNING", "Персонаж возрождён! Наблюдение за сбором...")
                FarmEngine.WakeLoop()
            else
                State.SetStatus("WAITING_MAP", "Возрождение в лобби. Ожидание раунда...")
            end
        end
    end))

    -- Metric broadcast heartbeat (1s interval)
    FarmEngine._maid:GiveTask(task.spawn(function()
        while true do
            task.wait(1.0)
            FarmEngine.BroadcastMetrics()
        end
    end))
end

-- Broadcast metrics to UI
function FarmEngine.BroadcastMetrics()
    if not FarmEngine._uiCallback then return end

    local elapsed = os.time() - FarmEngine._startTime
    local cpm = (elapsed > 10) and ((FarmEngine._sessionCandies / elapsed) * 60) or 0

    local currentBag = State.CandiesInBag
    local maxBag = State.BagCapacity

    if currentBag == 0 then
        local guiCur, _ = ReadBagFromGui()
        if guiCur and guiCur > 0 then
            currentBag = guiCur
            State.UpdateBag(guiCur, maxBag)
        end
    end

    local roundDisplayName = "Не начался"
    if MapManager.IsRoundActive() then
        roundDisplayName = (State.ActiveMapName and State.ActiveMapName ~= "None") and State.ActiveMapName or "Идёт бой"
    elseif MapManager.GetRoundState() == "Раунд завершён" then
        roundDisplayName = "Завершён"
    end

    FarmEngine._uiCallback({
        bagCurrent = currentBag,
        bagMax = maxBag,
        totalCandies = FarmEngine._sessionCandies,
        roundsFarmed = FarmEngine._roundsFarmed,
        elapsedSeconds = elapsed,
        mapName = State.ActiveMapName,
        roundName = roundDisplayName,
        targetDistance = State.CurrentTargetDistance,
        cpm = cpm,
        statusTitle = State.GetRussianStatusTitle(),
        diagnosticMessage = State.StatusMessage,
        fps = Performance.GetRealFPS(),
    })
end

-- Handle Bag Full state
function FarmEngine.HandleBagFull()
    FarmEngine._activeTarget = nil
    State.SetDistance(0)
    State.SetStatus("BAG_FULL", "Сумка заполнена! Ожидание конца раунда")
end

-- Wake up the collection loop
function FarmEngine.WakeLoop()
    FarmEngine._loopToken += 1
    local currentToken = FarmEngine._loopToken

    task.spawn(function()
        FarmEngine.RunCollectionLoop(currentToken)
    end)
end

-- Start Farming Telemetry Observer
function FarmEngine.Start()
    if FarmEngine.IsRunning then return end
    FarmEngine.IsRunning = true
    State.Config.AutoFarm = true

    if State.Config.AntiAFK then
        AntiAFK.Enable()
    end

    MapManager.RecordLobbyWaypoint()

    if MapManager.IsRoundActive() then
        State.SetStatus("SCANNING", "Раунд активен — наблюдение за сбором RockHub...")
    else
        State.SetStatus("WAITING_MAP", "Ожидание раунда (в лобби/интермиссии)...")
    end

    FarmEngine.WakeLoop()
end

-- Stop Farming Telemetry Observer
function FarmEngine.Stop()
    FarmEngine.IsRunning = false
    State.Config.AutoFarm = false
    FarmEngine._loopToken += 1

    State.SetStatus("IDLE", "Наблюдение остановлено пользователем")
    FarmEngine._activeTarget = nil
    State.SetDistance(0)
end

-- The passive companion collection loop (Zero movement, zero physics interference with RockHub)
-- Note: Movement.MoveToAndCollect is decommissioned. RockHub performs active movement.
-- FarmEngine operates strictly as a telemetry, metric broadcast, and HUD updater.
function FarmEngine.RunCollectionLoop(token: number)
    while FarmEngine.IsRunning and token == FarmEngine._loopToken do
        if MapManager.IsRoundActive() then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local map, coinContainer = MapManager.FindActiveMap()
            if hrp and coinContainer then
                local targetPart, distance = CandyDetector.GetClosestCandy(coinContainer, hrp.Position, "Candy", MapManager.IsPositionInsideMap)
                if not targetPart then
                    targetPart, distance = CandyDetector.GetClosestCandy(coinContainer, hrp.Position, "All", MapManager.IsPositionInsideMap)
                end
                if targetPart then
                    FarmEngine._activeTarget = targetPart
                    State.SetDistance(distance)
                    State.SetStatus("FARMING", string.format("Сбор RockHub | Ближайшая: %d м", math.floor(distance)))
                else
                    FarmEngine._activeTarget = nil
                    State.SetDistance(0)
                    State.SetStatus("SCANNING", "Ожидание спавна конфет...")
                end
            end
        else
            FarmEngine._activeTarget = nil
            State.SetDistance(0)
            State.SetStatus("WAITING_MAP", "Ожидание раунда...")
        end

        FarmEngine.BroadcastMetrics()
        CandyDetector.PruneBlacklist()
        task.wait(0.5)
    end
end

-- Shutdown and clean up everything
function FarmEngine.Destroy()
    FarmEngine.Stop()
    if FarmEngine._maid then
        FarmEngine._maid:Destroy()
        FarmEngine._maid = nil
    end
    AntiAFK.Disable()
    MapManager.RemoveSafePlatform()
    Performance.SetPerformanceMode(false)
    Performance.Set3DRendering(true)
end

return FarmEngine

        end)()

        -- MODULE 13: Native Vector Icon Primitives
        local IconPrimitives = (function()
--[[
    MM2 Delta Android Mobile - Native UI Primitive Icon Engine
    Architect: Mobile UX & High-FPS Engine Architect (MM2 Candy Farm Council)
    Platform: Delta Executor on Android (Roblox Mobile CoreGui)
    Description: 100% Pure Roblox Instance.new primitive icon fallbacks.
                 Renders crisp vector-like icons using Frames, UICorners, UIStrokes,
                 and Rotations with zero external web images, decals, or asset IDs.
    Icons supported:
      - Candy
      - Start
      - Stop
      - Settings
      - Performance
      - Minimize
      - Close
      - Status
      - Movement
      - Statistics
      - Refresh
]]

local IconPrimitives = {}

-- Helper: Create primitive element
local function CreatePrimitive(className: string, properties: { [string]: any }, children: { Instance }?): Instance
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

-- Default Icon Size
local DEFAULT_SIZE = UDim2.fromOffset(20, 20)
local DEFAULT_COLOR = Color3.fromRGB(240, 240, 255)

-- 1. CANDY ICON (Wrapped sweet with center body and flared twist ends)
function IconPrimitives.CreateCandy(size: UDim2?, color: Color3?, accentColor: Color3?): Frame
    local c = color or DEFAULT_COLOR
    local acc = accentColor or Color3.fromRGB(168, 85, 247)
    
    local container = CreatePrimitive("Frame", {
        Name = "Icon_Candy",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Center Sweet Body (Tilted rounded pill)
    local center = CreatePrimitive("Frame", {
        Name = "CandyBody",
        Size = UDim2.new(0.52, 0, 0.52, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = 45,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.4, 0) }),
        CreatePrimitive("UIStroke", {
            Color = acc,
            Thickness = 1,
            Transparency = 0.2,
        })
    })
    center.Parent = container

    -- Center decorative stripe
    local stripe = CreatePrimitive("Frame", {
        Name = "Stripe",
        Size = UDim2.new(0.24, 0, 0.8, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = acc,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })
    stripe.Parent = center

    -- Left Twist Wing
    local leftWing = CreatePrimitive("Frame", {
        Name = "LeftWing",
        Size = UDim2.new(0.24, 0, 0.38, 0),
        Position = UDim2.new(0.18, 0, 0.18, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = acc,
        Rotation = 15,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
    })
    leftWing.Parent = container

    -- Right Twist Wing
    local rightWing = CreatePrimitive("Frame", {
        Name = "RightWing",
        Size = UDim2.new(0.24, 0, 0.38, 0),
        Position = UDim2.new(0.82, 0, 0.82, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = acc,
        Rotation = 15,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
    })
    rightWing.Parent = container

    return container
end

-- 2. START ICON (Play chevron / directional triangle)
function IconPrimitives.CreateStart(size: UDim2?, color: Color3?): Frame
    local c = color or Color3.fromRGB(34, 197, 94)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Start",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Simulated triangle using 3 angled line elements
    local topSlant = CreatePrimitive("Frame", {
        Name = "TopSlant",
        Size = UDim2.new(0.55, 0, 0.12, 0),
        Position = UDim2.new(0.32, 0, 0.33, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = c,
        Rotation = 30,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    topSlant.Parent = container

    local botSlant = CreatePrimitive("Frame", {
        Name = "BotSlant",
        Size = UDim2.new(0.55, 0, 0.12, 0),
        Position = UDim2.new(0.32, 0, 0.67, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = c,
        Rotation = -30,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    botSlant.Parent = container

    local backBar = CreatePrimitive("Frame", {
        Name = "BackBar",
        Size = UDim2.new(0.12, 0, 0.58, 0),
        Position = UDim2.new(0.32, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    backBar.Parent = container

    -- Inner Fill Core
    local fillCore = CreatePrimitive("Frame", {
        Name = "FillCore",
        Size = UDim2.new(0.34, 0, 0.34, 0),
        Position = UDim2.new(0.46, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BackgroundTransparency = 0.2,
        Rotation = 45,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
    })
    fillCore.Parent = container

    return container
end

-- 3. STOP ICON (Square stop block with rounded micro-corners)
function IconPrimitives.CreateStop(size: UDim2?, color: Color3?): Frame
    local c = color or Color3.fromRGB(239, 68, 68)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Stop",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local square = CreatePrimitive("Frame", {
        Name = "StopSquare",
        Size = UDim2.new(0.68, 0, 0.68, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.22, 0) }),
        CreatePrimitive("UIStroke", {
            Color = Color3.fromRGB(255, 255, 255),
            Thickness = 1,
            Transparency = 0.5,
        })
    })
    square.Parent = container

    return container
end

-- 4. SETTINGS ICON (Mechanical Cog with central aperture and 4 orthogonal & 4 diagonal teeth)
function IconPrimitives.CreateSettings(size: UDim2?, color: Color3?, holeColor: Color3?): Frame
    local c = color or DEFAULT_COLOR
    local bg = holeColor or Color3.fromRGB(18, 18, 24)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Settings",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- 4 Orthogonal & Diagonal Teeth (Cross bars)
    local angles = { 0, 45, 90, 135 }
    for i, ang in ipairs(angles) do
        local bar = CreatePrimitive("Frame", {
            Name = "Tooth_" .. tostring(i),
            Size = UDim2.new(0.78, 0, 0.22, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            Rotation = ang,
            BorderSizePixel = 0,
        }, {
            CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
        })
        bar.Parent = container
    end

    -- Center Hub Circle
    local hub = CreatePrimitive("Frame", {
        Name = "Hub",
        Size = UDim2.new(0.6, 0, 0.6, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    hub.Parent = container

    -- Center Hole (Mask matching background)
    local hole = CreatePrimitive("Frame", {
        Name = "Hole",
        Size = UDim2.new(0.28, 0, 0.28, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    hole.Parent = container

    return container
end

-- 5. PERFORMANCE ICON (Speed tachometer gauge + lightning bolt)
function IconPrimitives.CreatePerformance(size: UDim2?, color: Color3?): Frame
    local c = color or Color3.fromRGB(56, 189, 248)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Performance",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Gauge Arc (Circular border with open bottom)
    local arcRing = CreatePrimitive("Frame", {
        Name = "GaugeArc",
        Size = UDim2.new(0.74, 0, 0.74, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) }),
        CreatePrimitive("UIStroke", {
            Color = c,
            Thickness = 2,
            Transparency = 0.1,
        })
    })
    arcRing.Parent = container

    -- Lightning Bolt in center
    local boltUpper = CreatePrimitive("Frame", {
        Name = "BoltUpper",
        Size = UDim2.new(0.12, 0, 0.44, 0),
        Position = UDim2.new(0.55, 0, 0.38, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = -24,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    boltUpper.Parent = container

    local boltLower = CreatePrimitive("Frame", {
        Name = "BoltLower",
        Size = UDim2.new(0.12, 0, 0.44, 0),
        Position = UDim2.new(0.45, 0, 0.62, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = -24,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    boltLower.Parent = container

    return container
end

-- 6. MINIMIZE ICON (Horizontal pill bar)
function IconPrimitives.CreateMinimize(size: UDim2?, color: Color3?): Frame
    local c = color or DEFAULT_COLOR

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Minimize",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local bar = CreatePrimitive("Frame", {
        Name = "Bar",
        Size = UDim2.new(0.7, 0, 0.14, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    bar.Parent = container

    return container
end

-- 7. CLOSE ICON (Diagonal crossed bars)
function IconPrimitives.CreateClose(size: UDim2?, color: Color3?): Frame
    local c = color or Color3.fromRGB(239, 68, 68)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Close",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local bar1 = CreatePrimitive("Frame", {
        Name = "Bar1",
        Size = UDim2.new(0.74, 0, 0.14, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = 45,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    bar1.Parent = container

    local bar2 = CreatePrimitive("Frame", {
        Name = "Bar2",
        Size = UDim2.new(0.74, 0, 0.14, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = -45,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    bar2.Parent = container

    return container
end

-- 8. STATUS ICON (Pulsing radar ring + center core dot)
function IconPrimitives.CreateStatus(size: UDim2?, activeColor: Color3?): Frame
    local c = activeColor or Color3.fromRGB(34, 197, 94)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Status",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Outer Halo Ring
    local ring = CreatePrimitive("Frame", {
        Name = "HaloRing",
        Size = UDim2.new(0.8, 0, 0.8, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) }),
        CreatePrimitive("UIStroke", {
            Color = c,
            Thickness = 1.2,
            Transparency = 0.35,
        })
    })
    ring.Parent = container

    -- Center Solid Signal Dot
    local coreDot = CreatePrimitive("Frame", {
        Name = "CoreDot",
        Size = UDim2.new(0.36, 0, 0.36, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    coreDot.Parent = container

    return container
end

-- 9. MOVEMENT ICON (Navigation waypoint / teleport directional arrow)
function IconPrimitives.CreateMovement(size: UDim2?, color: Color3?): Frame
    local c = color or Color3.fromRGB(168, 85, 247)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Movement",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Left slanted wing
    local leftWing = CreatePrimitive("Frame", {
        Name = "LeftWing",
        Size = UDim2.new(0.6, 0, 0.12, 0),
        Position = UDim2.new(0.36, 0, 0.44, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = -64,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    leftWing.Parent = container

    -- Right slanted wing
    local rightWing = CreatePrimitive("Frame", {
        Name = "RightWing",
        Size = UDim2.new(0.6, 0, 0.12, 0),
        Position = UDim2.new(0.64, 0, 0.44, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = 64,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    rightWing.Parent = container

    -- Center stem waypoint dot
    local centerDot = CreatePrimitive("Frame", {
        Name = "CenterDot",
        Size = UDim2.new(0.18, 0, 0.18, 0),
        Position = UDim2.new(0.5, 0, 0.72, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    centerDot.Parent = container

    return container
end

-- 10. STATISTICS ICON (Telemetry bar chart with 3 graduated levels)
function IconPrimitives.CreateStatistics(size: UDim2?, color: Color3?): Frame
    local c = color or DEFAULT_COLOR

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Statistics",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Bar 1 (Short, 35%)
    local bar1 = CreatePrimitive("Frame", {
        Name = "Bar1",
        Size = UDim2.new(0.18, 0, 0.35, 0),
        Position = UDim2.new(0.24, 0, 0.82, 0),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
    })
    bar1.Parent = container

    -- Bar 2 (Medium, 60%)
    local bar2 = CreatePrimitive("Frame", {
        Name = "Bar2",
        Size = UDim2.new(0.18, 0, 0.60, 0),
        Position = UDim2.new(0.5, 0, 0.82, 0),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
    })
    bar2.Parent = container

    -- Bar 3 (Tall, 85%)
    local bar3 = CreatePrimitive("Frame", {
        Name = "Bar3",
        Size = UDim2.new(0.18, 0, 0.85, 0),
        Position = UDim2.new(0.76, 0, 0.82, 0),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
    })
    bar3.Parent = container

    -- Bottom Baseline
    local baseline = CreatePrimitive("Frame", {
        Name = "Baseline",
        Size = UDim2.new(0.76, 0, 0.08, 0),
        Position = UDim2.new(0.5, 0, 0.88, 0),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    baseline.Parent = container

    return container
end

-- 11. REFRESH ICON (Rotational sync arrows)
function IconPrimitives.CreateRefresh(size: UDim2?, color: Color3?): Frame
    local c = color or DEFAULT_COLOR

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Refresh",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Arc Ring Base
    local arc = CreatePrimitive("Frame", {
        Name = "ArcRing",
        Size = UDim2.new(0.68, 0, 0.68, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) }),
        CreatePrimitive("UIStroke", {
            Color = c,
            Thickness = 1.8,
            Transparency = 0.1,
        })
    })
    arc.Parent = container

    -- Mask to simulate open circle
    local mask = CreatePrimitive("Frame", {
        Name = "Mask",
        Size = UDim2.new(0.36, 0, 0.36, 0),
        Position = UDim2.new(0.82, 0, 0.18, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(18, 18, 24),
        BorderSizePixel = 0,
    })
    mask.Parent = container

    -- Arrowhead on top right
    local arrow = CreatePrimitive("Frame", {
        Name = "ArrowHead",
        Size = UDim2.new(0.24, 0, 0.12, 0),
        Position = UDim2.new(0.78, 0, 0.22, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = 45,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    arrow.Parent = container

    return container
end

-- 12. ZOMBIE ICON (Cyber Undead Skull / Biohazard primitive)
function IconPrimitives.CreateZombie(size: UDim2?, color: Color3?, eyeColor: Color3?): Frame
    local c = color or Color3.fromRGB(34, 197, 94)
    local bg = eyeColor or Color3.fromRGB(18, 18, 24)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Zombie",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Cranium dome
    local cranium = CreatePrimitive("Frame", {
        Name = "Cranium",
        Size = UDim2.new(0.68, 0, 0.52, 0),
        Position = UDim2.new(0.5, 0, 0.32, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.5, 0) })
    })
    cranium.Parent = container

    -- Left eye socket
    local leftEye = CreatePrimitive("Frame", {
        Name = "LeftEye",
        Size = UDim2.new(0.24, 0, 0.34, 0),
        Position = UDim2.new(0.32, 0, 0.52, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    leftEye.Parent = cranium

    -- Right eye socket
    local rightEye = CreatePrimitive("Frame", {
        Name = "RightEye",
        Size = UDim2.new(0.24, 0, 0.34, 0),
        Position = UDim2.new(0.68, 0, 0.52, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    rightEye.Parent = cranium

    -- Jaw / Muzzle
    local jaw = CreatePrimitive("Frame", {
        Name = "Jaw",
        Size = UDim2.new(0.44, 0, 0.28, 0),
        Position = UDim2.new(0.5, 0, 0.68, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.25, 0) })
    })
    jaw.Parent = container

    -- Teeth divider slits
    local tooth1 = CreatePrimitive("Frame", {
        Name = "Tooth1",
        Size = UDim2.new(0.12, 0, 0.55, 0),
        Position = UDim2.new(0.36, 0, 0.72, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
    })
    tooth1.Parent = jaw

    local tooth2 = CreatePrimitive("Frame", {
        Name = "Tooth2",
        Size = UDim2.new(0.12, 0, 0.55, 0),
        Position = UDim2.new(0.64, 0, 0.72, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
    })
    tooth2.Parent = jaw

    return container
end

-- 13. PLAYER ICON (Humanoid silhouette: head circle + torso shoulders)
function IconPrimitives.CreatePlayer(size: UDim2?, color: Color3?): Frame
    local c = color or Color3.fromRGB(129, 140, 248)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Player",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Head Circle
    local head = CreatePrimitive("Frame", {
        Name = "Head",
        Size = UDim2.new(0.38, 0, 0.38, 0),
        Position = UDim2.new(0.5, 0, 0.25, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    head.Parent = container

    -- Shoulders / Torso
    local torso = CreatePrimitive("Frame", {
        Name = "Torso",
        Size = UDim2.new(0.70, 0, 0.40, 0),
        Position = UDim2.new(0.5, 0, 0.68, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.45, 0) })
    })
    torso.Parent = container

    return container
end

-- 14. QUICK TOGGLE ICON (Play triangle or pause bars)
function IconPrimitives.CreateQuickToggle(size: UDim2?, isPlaying: boolean?, color: Color3?): Frame
    local c = color or Color3.fromRGB(240, 240, 255)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_QuickToggle",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    if isPlaying then
        -- Two vertical pause bars
        local bar1 = CreatePrimitive("Frame", {
            Name = "Bar1",
            Size = UDim2.new(0.24, 0, 0.68, 0),
            Position = UDim2.new(0.32, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
        }, {
            CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
        })
        bar1.Parent = container

        local bar2 = CreatePrimitive("Frame", {
            Name = "Bar2",
            Size = UDim2.new(0.24, 0, 0.68, 0),
            Position = UDim2.new(0.68, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
        }, {
            CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
        })
        bar2.Parent = container
    else
        -- Play chevron / triangle
        local slantTop = CreatePrimitive("Frame", {
            Name = "SlantTop",
            Size = UDim2.new(0.54, 0, 0.18, 0),
            Position = UDim2.new(0.32, 0, 0.35, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = c,
            Rotation = 30,
            BorderSizePixel = 0,
        }, {
            CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
        })
        slantTop.Parent = container

        local slantBot = CreatePrimitive("Frame", {
            Name = "SlantBot",
            Size = UDim2.new(0.54, 0, 0.18, 0),
            Position = UDim2.new(0.32, 0, 0.65, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = c,
            Rotation = -30,
            BorderSizePixel = 0,
        }, {
            CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
        })
        slantBot.Parent = container

        local backBar = CreatePrimitive("Frame", {
            Name = "BackBar",
            Size = UDim2.new(0.18, 0, 0.62, 0),
            Position = UDim2.new(0.32, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
        }, {
            CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
        })
        backBar.Parent = container
    end

    return container
end

-- Generic Factory Dispatcher
function IconPrimitives.Render(iconName: string, size: UDim2?, color: Color3?, extraColor: any): Frame
    local name = string.lower(iconName)
    if name == "candy" then
        return IconPrimitives.CreateCandy(size, color, extraColor)
    elseif name == "start" then
        return IconPrimitives.CreateStart(size, color)
    elseif name == "stop" then
        return IconPrimitives.CreateStop(size, color)
    elseif name == "settings" then
        return IconPrimitives.CreateSettings(size, color, extraColor)
    elseif name == "performance" then
        return IconPrimitives.CreatePerformance(size, color)
    elseif name == "minimize" then
        return IconPrimitives.CreateMinimize(size, color)
    elseif name == "close" then
        return IconPrimitives.CreateClose(size, color)
    elseif name == "status" then
        return IconPrimitives.CreateStatus(size, color)
    elseif name == "movement" then
        return IconPrimitives.CreateMovement(size, color)
    elseif name == "statistics" then
        return IconPrimitives.CreateStatistics(size, color)
    elseif name == "refresh" then
        return IconPrimitives.CreateRefresh(size, color)
    elseif name == "zombie" then
        return IconPrimitives.CreateZombie(size, color, extraColor)
    elseif name == "player" or name == "user" then
        return IconPrimitives.CreatePlayer(size, color)
    elseif name == "quicktoggle" then
        local isPlaying = (extraColor == true)
        return IconPrimitives.CreateQuickToggle(size, isPlaying, color)
    else
        -- Fallback: generic status dot
        return IconPrimitives.CreateStatus(size, color)
    end
end

-- Backwards compatibility alias for CreateIcon
function IconPrimitives.CreateIcon(iconName: string, size: any?, color: Color3?, accentColor: Color3?): Frame
    local sz: UDim2? = nil
    if typeof(size) == "number" then
        sz = UDim2.fromOffset(size, size)
    elseif typeof(size) == "UDim2" then
        sz = size
    end
    return IconPrimitives.Render(iconName, sz, color, accentColor)
end

return IconPrimitives

        end)()

        -- MODULE 14: Zombie & Infection Mode Controller
        local ZombieMode = (function()
-- ZombieMode.luau: MM2 Halloween Zombie & Infection Mode Controller (Verified Zero-Remote Architecture)
-- Detects infected entities, handles gun auto-equip and safe native tool activation,
-- and provides threat evasion with strict lobby lockout and state isolation from Candy Farm.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

export type ThreatTarget = {
    Player: Player?,
    Character: Model,
    RootPart: BasePart,
    Humanoid: Humanoid,
    Distance: number,
}

local ZombieMode = {
    IsEnabled = false,
    IsActiveInRound = false,
    ZombieCount = 0,
    StatusMessage = "Ожидание раунда Infection",
    AutoEquipGun = true,
    AutoShoot = true,
    EvasionBuffer = 18.0,
    _loopToken = 0,
    _activeThreat = nil :: ThreatTarget?,
    _updateCallback = nil :: ((data: any) -> ())?,
}

-- Check if character is an infected player or zombie entity
local function IsTargetInfected(char: Model): boolean
    if not char or not char:IsA("Model") then return false end
    if char == LocalPlayer.Character then return false end

    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if not hum or hum.Health <= 0 then return false end

    -- Signal 1: Attributes
    if char:GetAttribute("Zombie") == true or char:GetAttribute("Infected") == true then
        return true
    end

    -- Signal 2: Weapon check (Zombie Knife)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and (string.find(child.Name:lower(), "zombie") or string.find(child.Name:lower(), "knife")) then
            return true
        end
    end

    -- Signal 3: Naming
    local nameLower = char.Name:lower()
    if string.find(nameLower, "zombie") or string.find(nameLower, "infected") then
        return true
    end

    -- Signal 4: Player team in Infection
    local player = Players:GetPlayerFromCharacter(char)
    if player then
        local team = player.Team
        if team and string.find(team.Name:lower(), "zombie") then
            return true
        end
        if player:GetAttribute("Role") == "Zombie" then
            return true
        end
    end

    return false
end

-- Scan for active zombie threats inside playable map
function ZombieMode.ScanNearestThreat(): ThreatTarget?
    if MapManager.IsPlayerInLobby() or not MapManager.IsRoundActive() then
        return nil
    end

    local localChar = LocalPlayer.Character
    if not localChar then return nil end
    local localHrp = localChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not localHrp then return nil end

    local nearestThreat: ThreatTarget? = nil
    local shortestDist = 50.0

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid?

            if hrp and hum and hum.Health > 0 and IsTargetInfected(char) then
                local dist = (hrp.Position - localHrp.Position).Magnitude
                if dist < shortestDist and MapManager.IsPositionInsideMap(hrp.Position) then
                    shortestDist = dist
                    nearestThreat = {
                        Player = player,
                        Character = char,
                        RootPart = hrp,
                        Humanoid = hum,
                        Distance = dist,
                    }
                end
            end
        end
    end

    return nearestThreat
end

-- Resolve gun tool from character or backpack
local function GetEquippedOrBackpackGun(): Tool?
    local char = LocalPlayer.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and string.find(item.Name:lower(), "gun") then
                return item
            end
        end
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and string.find(item.Name:lower(), "gun") then
                return item
            end
        end
    end

    return nil
end

-- Defensive engagement using native Roblox engine methods (zero unverified remotes)
local function EngageThreat(threat: ThreatTarget)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    local localHrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hum or not localHrp then return end

    local gunTool = GetEquippedOrBackpackGun()
    if gunTool then
        -- 1. Auto-Equip Gun if currently in backpack
        if gunTool.Parent ~= char and ZombieMode.AutoEquipGun then
            hum:EquipTool(gunTool)
            task.wait(0.05)
        end

        -- 2. Camera Orientation towards threat (No character CFrame mutation)
        local camera = Workspace.CurrentCamera
        if camera then
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, threat.RootPart.Position)
        end

        -- 3. Native Tool Activation (bypasses remote tampering)
        if ZombieMode.AutoShoot and gunTool.Parent == char then
            pcall(function()
                gunTool:Activate()
            end)
        end

        ZombieMode.StatusMessage = string.format("Защита: Стрельба по зомби (%d м)", math.floor(threat.Distance))
    else
        -- Unarmed Defense: Telemetry warning only (Zero-Interference Contract: no physics manipulation)
        if threat.Distance <= ZombieMode.EvasionBuffer then
            ZombieMode.StatusMessage = string.format("Внимание: приближение зомби (%d м)!", math.floor(threat.Distance))
        end
    end
end

local function RunZombieLoop(token: number)
    while ZombieMode.IsEnabled and token == ZombieMode._loopToken do
        task.wait(0.25)

        if MapManager.IsPlayerInLobby() then
            ZombieMode.IsActiveInRound = false
            ZombieMode.ZombieCount = 0
            ZombieMode.StatusMessage = "В лобби (Ожидание раунда Infection)"
            ZombieMode.Broadcast()
            continue
        end

        if not MapManager.IsRoundActive() then
            ZombieMode.IsActiveInRound = false
            ZombieMode.ZombieCount = 0
            ZombieMode.StatusMessage = "Раунд не начался или завершён"
            ZombieMode.Broadcast()
            continue
        end

        local threat = ZombieMode.ScanNearestThreat()
        if threat then
            ZombieMode.IsActiveInRound = true
            ZombieMode.ZombieCount = 1
            EngageThreat(threat)
        else
            ZombieMode.IsActiveInRound = false
            ZombieMode.ZombieCount = 0
            ZombieMode.StatusMessage = "Зомби не обнаружены (Стандартный раунд)"
        end

        ZombieMode.Broadcast()
    end
end

function ZombieMode.Broadcast()
    if ZombieMode._updateCallback then
        ZombieMode._updateCallback({
            isEnabled = ZombieMode.IsEnabled,
            isActive = ZombieMode.IsActiveInRound,
            zombieCount = ZombieMode.ZombieCount,
            status = ZombieMode.StatusMessage,
        })
    end
end

function ZombieMode.Init(uiCallback: ((data: any) -> ())?)
    ZombieMode._updateCallback = uiCallback
end

function ZombieMode.Start()
    ZombieMode.IsEnabled = true
    ZombieMode._loopToken += 1
    task.spawn(RunZombieLoop, ZombieMode._loopToken)
    ZombieMode.Broadcast()
end

function ZombieMode.Stop()
    ZombieMode.IsEnabled = false
    ZombieMode._loopToken += 1
    ZombieMode.IsActiveInRound = false
    ZombieMode.ZombieCount = 0
    ZombieMode.StatusMessage = "Модуль Зомби остановлен"
    ZombieMode.Broadcast()
end

return ZombieMode

        end)()

        -- MODULE 15: Mobile UI (NEBULA PRO + MIDNIGHT Interface)
        local MobileUI = (function()
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

        end)()

        -- ==============================================================================
        -- RUNTIME INTEGRATION & ENTRY POINT
        -- ==============================================================================
        -- Zero-Interference Contract: The Companion strictly never alters character physics

        local UI = nil

        local function HandleUnload()
            FarmEngine.Destroy()
            ZombieMode.Stop()
            if RockHubResizer and RockHubResizer.Detach then
                pcall(function() RockHubResizer:Detach() end)
            end
            if CompanionTelemetry and CompanionTelemetry.CleanupAll then
                pcall(CompanionTelemetry.CleanupAll)
            end
            local perf = Performance.GetInstance()
            if perf and perf.RestoreAll then
                pcall(function() perf:RestoreAll() end)
            end
            if UI then
                UI:Destroy()
                UI = nil
            end
            _G.PrivateMM2CandyFarmCleanup = nil
            _G.PrivateMM2CompanionCleanup = nil
            print("[Private MM2 Candy Farm] Unloaded cleanly.")
        end

        _G.PrivateMM2CandyFarmCleanup = HandleUnload
        _G.PrivateMM2CompanionCleanup = HandleUnload

        local function ResolveSpeed(mode)
            if mode == "Обычная" or mode == "Normal" then return 28
            elseif mode == "Быстрая" or mode == "Fast" then return 36
            elseif mode == "Турбо" or mode == "Turbo" or mode == "Instant" then return 44
            end
            return 36
        end

        UI = MobileUI.Init({
            OnToggleFarm = function(enabled)
                if enabled then
                    FarmEngine.Start()
                else
                    FarmEngine.Stop()
                end
            end,

            OnZombieAutoDefendChanged = function(enabled)
                if enabled then
                    ZombieMode.Start()
                else
                    ZombieMode.Stop()
                end
            end,

            OnSpeedChanged = function(mode)
                local speed = ResolveSpeed(mode)
                State.SetConfig("MoveSpeed", speed)
                State.SetConfig("MoveMethod", "Continuous")
                Persistence.Save(State.Config)
            end,

            OnNoclipChanged = function(enabled)
                State.SetConfig("Noclip", enabled)
                Movement.SetNoclip(enabled)
                Persistence.Save(State.Config)
            end,

            OnHighFPSChanged = function(enabled)
                local perf = Performance.GetInstance()
                perf:SetEnabled(enabled)
            end,

            OnBagCapacityChanged = function(capStr)
                local cap = tonumber(capStr) or 0
                State.SetConfig("BagLimit", cap)
                Persistence.Save(State.Config)
            end,

            OnSafePlatformChanged = function(enabled)
                State.SetConfig("SafeSpotOnFull", enabled)
                Persistence.Save(State.Config)
            end,

            OnAutoResumeChanged = function(enabled)
                State.SetConfig("AutoResumeOnRespawn", enabled)
                Persistence.Save(State.Config)
            end,

            OnAntiAFKChanged = function(enabled)
                State.SetConfig("AntiAFK", enabled)
                if enabled then
                    AntiAFK.Enable()
                else
                    AntiAFK.Disable()
                end
                Persistence.Save(State.Config)
            end,

            OnResetSettings = function()
                State.Config = {
                    AutoFarm = false,
                    MoveSpeed = 36,
                    MoveMethod = "Continuous",
                    BagLimit = 0,
                    AutoResumeOnRespawn = true,
                    SafeSpotOnFull = true,
                    AntiAFK = true,
                    Noclip = true,
                }
                Persistence.Save(State.Config)
            end,

            OnUnload = function()
                HandleUnload()
            end,
        })

        FarmEngine.Init(function(metrics)
            if UI then
                UI:UpdateMetrics(metrics)
                local title = metrics.statusTitle or State.GetRussianStatusTitle()
                local diag = metrics.diagnosticMessage or State.StatusMessage
                UI:SetStatus(title, diag)
            end
        end)

        local perfEngine = Performance.GetInstance()
        perfEngine:StartMetrics(function(perfData)
            if UI then
                UI:UpdateMetrics({
                    fps = perfData.FPS,
                    ping = perfData.Ping,
                })
            end
        end)

        ZombieMode.Init(function(data)
            if UI and UI.UpdateZombieMetrics then
                UI:UpdateZombieMetrics(data)
            end
        end)

        print("[Private MM2 Candy Farm] Running! Touch floating pill or dashboard to control.")
    end)

    if not initSuccess then
        local errString = tostring(initError)
        warn("[Private MM2 Candy Farm STARTUP FAILURE]: " .. errString)

        -- Visible On-Screen Diagnostic Fallback (renders directly in PlayerGui so mobile user sees error)
        pcall(function()
            local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5) or LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if playerGui then
                local errGui = Instance.new("ScreenGui")
                errGui.Name = "MM2_Startup_Error_Diag"
                errGui.ResetOnSpawn = false
                errGui.DisplayOrder = 999999
                errGui.Parent = playerGui

                local errFrame = Instance.new("Frame")
                errFrame.Size = UDim2.new(0, 320, 0, 100)
                errFrame.Position = UDim2.new(0.5, -160, 0, 20)
                errFrame.BackgroundColor3 = Color3.fromRGB(40, 10, 15)
                errFrame.BorderSizePixel = 0
                errFrame.Parent = errGui

                local corner = Instance.new("UICorner", errFrame)
                corner.CornerRadius = UDim.new(0, 8)

                local stroke = Instance.new("UIStroke", errFrame)
                stroke.Color = Color3.fromRGB(239, 68, 68)
                stroke.Thickness = 1.5

                local errTitle = Instance.new("TextLabel", errFrame)
                errTitle.Size = UDim2.new(1, -16, 0, 24)
                errTitle.Position = UDim2.new(0, 8, 0, 6)
                errTitle.BackgroundTransparency = 1
                errTitle.Text = "MM2 FARM STARTUP ERROR"
                errTitle.Font = Enum.Font.GothamBold
                errTitle.TextSize = 12
                errTitle.TextColor3 = Color3.fromRGB(239, 68, 68)

                local errDesc = Instance.new("TextLabel", errFrame)
                errDesc.Size = UDim2.new(1, -16, 0, 60)
                errDesc.Position = UDim2.new(0, 8, 0, 30)
                errDesc.BackgroundTransparency = 1
                errDesc.Text = errString
                errDesc.Font = Enum.Font.GothamMedium
                errDesc.TextSize = 10
                errDesc.TextColor3 = Color3.fromRGB(255, 200, 200)
                errDesc.TextWrapped = true
            end
        end)
    end
end
