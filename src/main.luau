--!strict
-- main.luau: Private MM2 Candy Farm Entry Point
-- Integrates all sub-modules for modular local development

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

-- Speed resolution helper
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

print("[Private MM2 Candy Farm] Successfully initialized!")
return {
    Engine = FarmEngine,
    UI = UI,
    State = State,
    Unload = HandleUnload,
}
