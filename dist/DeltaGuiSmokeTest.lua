--[[
    ==============================================================================
    DELTA EXECUTOR — MINIMAL GUI SMOKE TEST (ANDROID / WINDOWS)
    ==============================================================================
    Purpose: 
    Minimal, 100% standalone GUI test to verify ScreenGui rendering, touch input,
    and safe parenting across Delta, Codex, Fluxus, and native Roblox environments.
    Zero external dependencies. No farming logic. Pure Instance.new.
    ==============================================================================
]]

local success, runtimeError = pcall(function()
    -- 1. Ensure game engine is fully loaded
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    local Players = game:GetService("Players")
    local CoreGui = game:GetService("CoreGui")
    local Workspace = game:GetService("Workspace")

    -- 2. Resolve LocalPlayer safely
    local localPlayer = Players.LocalPlayer
    local timeout = os.clock() + 10
    while not localPlayer and os.clock() < timeout do
        task.wait(0.1)
        localPlayer = Players.LocalPlayer
    end

    if not localPlayer then
        error("LocalPlayer could not be resolved within 10 seconds.")
    end

    -- 3. Resolve Executor Name if available
    local executorName = "Unknown Executor"
    pcall(function()
        if type(identifyexecutor) == "function" then
            executorName = tostring(identifyexecutor())
        elseif type(getexecutorname) == "function" then
            executorName = tostring(getexecutorname())
        end
    end)

    -- 4. Safe GUI Parent Resolution with fallback cascade
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Delta_SmokeTest_ScreenGui"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 999999
    screenGui.IgnoreGuiInset = true
    screenGui.Enabled = true

    local resolvedParentName = "Unknown"
    local parented = false

    -- Strategy A: gethui()
    if not parented and type(gethui) == "function" then
        parented = pcall(function()
            local hui = gethui()
            if hui then
                screenGui.Parent = hui
                resolvedParentName = "gethui() (" .. tostring(hui.ClassName) .. ")"
            end
        end)
    end

    -- Strategy B: CoreGui (wrapped in pcall)
    if not parented or not screenGui.Parent then
        parented = pcall(function()
            screenGui.Parent = CoreGui
            resolvedParentName = "CoreGui"
        end)
    end

    -- Strategy C: PlayerGui (Guaranteed to work and render on all Android mobile devices!)
    if not parented or not screenGui.Parent then
        local playerGui = localPlayer:WaitForChild("PlayerGui", 5) or localPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            screenGui.Parent = playerGui
            resolvedParentName = "PlayerGui"
            parented = true
        end
    end

    if not screenGui.Parent then
        error("Failed to parent ScreenGui to gethui, CoreGui, or PlayerGui.")
    end

    -- Remove any previous smoke test instance
    for _, sibling in ipairs(screenGui.Parent:GetChildren()) do
        if sibling ~= screenGui and sibling.Name == "Delta_SmokeTest_ScreenGui" then
            pcall(function() sibling:Destroy() end)
        end
    end

    -- 5. Build Visible Test Frame
    local camera = Workspace.CurrentCamera
    local viewport = (camera and camera.ViewportSize.X > 50) and camera.ViewportSize or Vector2.new(800, 600)

    -- Floating Test Card (Compact: 300x170 px)
    local testFrame = Instance.new("Frame")
    testFrame.Name = "SmokeTestCard"
    testFrame.Size = UDim2.new(0, 300, 0, 170)
    testFrame.Position = UDim2.new(0.5, -150, 0, 45) -- Centered top
    testFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    testFrame.BorderSizePixel = 0
    testFrame.Active = true
    testFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = testFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(34, 197, 94) -- Neon Mint
    stroke.Thickness = 2
    stroke.Parent = testFrame

    -- Header Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -40, 0, 28)
    title.Position = UDim2.new(0, 12, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "✅ DELTA SMOKE TEST: PASSED"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 13
    title.TextColor3 = Color3.fromRGB(34, 197, 94)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = testFrame

    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.Position = UDim2.new(1, -30, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(45, 20, 25)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Color3.fromRGB(239, 68, 68)
    closeBtn.Parent = testFrame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Diagnostic Info Text
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "Info"
    infoLabel.Size = UDim2.new(1, -24, 0, 64)
    infoLabel.Position = UDim2.new(0, 12, 0, 38)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font = Enum.Font.GothamMedium
    infoLabel.TextSize = 11
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.Text = string.format(
        "• Parent: %s\n• Executor: %s\n• Player: %s\n• Viewport: %dx%d px",
        resolvedParentName,
        executorName,
        localPlayer.Name,
        math.floor(viewport.X),
        math.floor(viewport.Y)
    )
    infoLabel.Parent = testFrame

    -- Interactive Tap Button (to verify touch responsiveness)
    local testBtn = Instance.new("TextButton")
    testBtn.Name = "TapTestButton"
    testBtn.Size = UDim2.new(1, -24, 0, 36)
    testBtn.Position = UDim2.new(0, 12, 1, -46)
    testBtn.BackgroundColor3 = Color3.fromRGB(138, 75, 255) -- Purple
    testBtn.Text = "📱 TAP HERE TO TEST TOUCH INPUT"
    testBtn.Font = Enum.Font.GothamBold
    testBtn.TextSize = 11
    testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    testBtn.Parent = testFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = testBtn

    local tapCount = 0
    testBtn.MouseButton1Click:Connect(function()
        tapCount += 1
        testBtn.Text = string.format("🎉 TOUCH CONFIRMED! (TAPS: %d)", tapCount)
        testBtn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    end)

    print("[Delta Smoke Test] Smoke test GUI successfully created and parented to: " .. resolvedParentName)
end)

if not success then
    -- Fallback diagnostic print and alert
    local errMsg = tostring(runtimeError)
    warn("[Delta Smoke Test FAILED]: " .. errMsg)
    pcall(function()
        local Players = game:GetService("Players")
        local lp = Players.LocalPlayer
        if lp and lp:FindFirstChild("PlayerGui") then
            local fallbackGui = Instance.new("ScreenGui", lp.PlayerGui)
            local alert = Instance.new("TextLabel", fallbackGui)
            alert.Size = UDim2.new(1, 0, 0, 50)
            alert.Position = UDim2.new(0, 0, 0, 20)
            alert.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
            alert.TextColor3 = Color3.fromRGB(255, 255, 255)
            alert.TextSize = 14
            alert.Text = "SMOKE TEST ERROR: " .. errMsg
        end
    end)
end
