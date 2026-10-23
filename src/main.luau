--!strict
-- main.luau: Private MM2 Candy Farm & RockHub Mobile Companion Entry Point
-- NEBULA PRO + MIDNIGHT Interface, Android Delta Optimization, Non-Intrusive RockHub Resizer

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
    local RockHubResizer = require(script.core.RockHubResizer)
    local CompanionTelemetry = require(script.core.CompanionTelemetry)
    local ZombieMode = require(script.features.ZombieMode)
    local MobileUI = require(script.ui.MobileUI)

    -- Singleton cleanup if already running in executor
    if _G.PrivateMM2CandyFarmCleanup then
        pcall(_G.PrivateMM2CandyFarmCleanup)
        _G.PrivateMM2CandyFarmCleanup = nil
    end
    if _G.PrivateMM2CompanionCleanup then
        pcall(_G.PrivateMM2CompanionCleanup)
        _G.PrivateMM2CompanionCleanup = nil
    end

    -- Zero-Interference Contract: The Companion strictly never alters character physics,
    -- never deletes body movers or constraints, and never changes Humanoid states or velocities.

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
        print("[Private MM2 Candy Farm] Companion unloaded cleanly.")
    end

    _G.PrivateMM2CandyFarmCleanup = HandleUnload
    _G.PrivateMM2CompanionCleanup = HandleUnload

    local function ResolveSpeed(mode: string): number
        if mode == "Обычная" or mode == "Normal" then
            return 28
        elseif mode == "Быстрая" or mode == "Fast" then
            return 36
        elseif mode == "Турбо" or mode == "Turbo" or mode == "Instant" then
            return 44
        end
        return 36
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

        OnZombieAutoDefendChanged = function(enabled: boolean)
            if enabled then
                ZombieMode.Start()
            else
                ZombieMode.Stop()
            end
        end,

        OnSpeedChanged = function(mode: string)
            local speed = ResolveSpeed(mode)
            State.SetConfig("MoveSpeed", speed)
            State.SetConfig("MoveMethod", "Continuous")
            Persistence.Save(State.Config)
        end,

        OnNoclipChanged = function(enabled: boolean)
            State.SetConfig("Noclip", enabled)
            Movement.SetNoclip(enabled)
            Persistence.Save(State.Config)
        end,

        OnHighFPSChanged = function(enabled: boolean)
            local perf = Performance.GetInstance()
            perf:SetEnabled(enabled)
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

    -- Initialize Farm Engine with UI metric dispatcher
    FarmEngine.Init(function(metrics)
        if UI then
            UI:UpdateMetrics(metrics)
            local title = metrics.statusTitle or State.GetRussianStatusTitle()
            local diag = metrics.diagnosticMessage or State.StatusMessage
            UI:SetStatus(title, diag)
        end
    end)

    -- Connect High-FPS performance metrics to UI
    local perfEngine = Performance.GetInstance()
    perfEngine:StartMetrics(function(perfData)
        if UI then
            UI:UpdateMetrics({
                fps = perfData.FPS,
                ping = perfData.Ping,
            })
        end
    end)

    -- Initialize Zombie Mode with UI metric dispatcher
    ZombieMode.Init(function(data)
        if UI and UI.UpdateZombieMetrics then
            UI:UpdateZombieMetrics(data)
        end
    end)

    print("[Private MM2 Candy Farm] Successfully initialized RockHub Companion!")
end)

if not success then
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
