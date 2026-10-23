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
