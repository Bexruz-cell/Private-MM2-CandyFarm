--!strict
-- main.luau: Private MM2 Candy Farm Entry Point (Hardened & Diagnostic-Enabled)
-- Integrates all sub-modules with top-level error handling and visible screen diagnostics

-- 1. Wait for game engine and client player to fully load
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
    error("Critical: LocalPlayer could not be resolved within 10 seconds.")
end

local success, initError = pcall(function()
    local State = require(script.core.State)
    local Maid = require(script.utils.Maid)
    local AntiAFK = require(script.utils.AntiAFK)
    local MapManager = require(script.core.MapManager)
    local CandyDetector = require(script.core.CandyDetector)
    local Movement = require(script.core.Movement)
    local Performance = require(script.core.Performance)
    local Persistence = require(script.core.Persistence)
    local FarmEngine = require(script.core.FarmEngine)
    local MobileUI = require(script.ui.MobileUI)

    -- Singleton cleanup if already running in executor
    if _G.PrivateMM2CandyFarmCleanup then
        pcall(_G.PrivateMM2CandyFarmCleanup)
        _G.PrivateMM2CandyFarmCleanup = nil
    end

    local UI = nil

    local function HandleUnload()
        FarmEngine.Destroy()
        if UI then
            UI:Destroy()
            UI = nil
        end
        _G.PrivateMM2CandyFarmCleanup = nil
    end

    _G.PrivateMM2CandyFarmCleanup = HandleUnload

    local function ResolveSpeed(mode: string): number
        if mode == "Normal" then
            return 28
        elseif mode == "Fast" then
            return 38
        elseif mode == "Instant" then
            return 80
        end
        return 32
    end

    -- Initialize UI with backend event callbacks
    UI = MobileUI.Init({
        OnToggleFarm = function(enabled: boolean)
            if enabled then
                FarmEngine.Start()
            else
                FarmEngine.Stop()
            end
        end,

        OnSpeedChanged = function(mode: string)
            local speed = ResolveSpeed(mode)
            State.SetConfig("MoveSpeed", speed)
            State.SetConfig("MoveMethod", (mode == "Instant") and "Instant" or "Tween")
            Persistence.Save(State.Config)
        end,

        OnBagCapacityChanged = function(capStr: string)
            local cap = tonumber(capStr) or 0
            State.SetConfig("BagLimit", cap)
            Persistence.Save(State.Config)
        end,

        OnSafePlatformChanged = function(enabled: boolean)
            State.SetConfig("SafeSpotOnFull", enabled)
            Persistence.Save(State.Config)
        end,

        OnAutoResumeChanged = function(enabled: boolean)
            State.SetConfig("AutoResumeOnRespawn", enabled)
            Persistence.Save(State.Config)
        end,

        OnAntiAFKChanged = function(enabled: boolean)
            State.SetConfig("AntiAFK", enabled)
            if enabled then
                AntiAFK.Enable()
            else
                AntiAFK.Disable()
            end
            Persistence.Save(State.Config)
        end,

        OnPerfModeChanged = function(enabled: boolean)
            Performance.SetPerformanceMode(enabled)
        end,

        OnUnload = function()
            HandleUnload()
        end,
    })

    -- Initialize Farm Engine with UI metric dispatcher
    FarmEngine.Init(function(metrics)
        if UI then
            UI:UpdateMetrics(metrics)
            UI:SetStatus(State.Status, State.StatusMessage)
        end
    end)

    print("[Private MM2 Candy Farm] Successfully initialized and rendered!")
end)

if not success then
    local errString = tostring(initError)
    warn("[Private MM2 Candy Farm STARTUP FAILURE]: " .. errString)

    -- Visible On-Screen Diagnostic Fallback (renders directly in PlayerGui so mobile user sees the error)
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
            errTitle.Text = "❌ MM2 FARM STARTUP ERROR"
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
