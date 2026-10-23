--[[
    ==============================================================================
    PRIVATE MM2 CANDY FARM — DELTA EXECUTOR ANDROID / WINDOWS
    ==============================================================================
    Version: 2.1.0 PRO (NEBULA PRO + MIDNIGHT + ZOMBIE ARCHITECTURE)
    Platform: Delta Executor (Android Mobile & Windows)
    Target: Roblox Murder Mystery 2 (Halloween Candy / Seasonal Coins / Infection)
    Author: Autonomous Engineering Team (Tech Lead & Council)

    SECURITY NOTICE:
    - 100% Standalone & Self-Contained. Zero external loaders or remote fetches.
    - Zero Webhooks, zero analytics, zero credential/token access.
    - Zero obfuscated code. Clean, inspectable, high-performance Luau.

    FEATURES:
    - Fast Continuous Movement (Heartbeat, zero velocity spikes) [IMPLEMENTED]
    - Observable Tri-Signal Collection (no phantom pickups)       [IMPLEMENTED]
    - Strict Fail-Closed Round State Machine (Lobby Safe)        [IMPLEMENTED]
    - Dedicated Zombie & Infection Mode Controller               [IMPLEMENTED]
    - High FPS Mode & Accurate Realtime FPS Counter              [IMPLEMENTED]
    - 3-Tab Mobile Interface (ФАРМ, ЗОМБИ, НАСТРОЙКИ)            [IMPLEMENTED]
    - Pure Vector Geometric Icon Primitives (Zero Emojis)        [IMPLEMENTED]
    - Draggable Floating Mini-HUD Capsule (336 x 260 px)         [IMPLEMENTED]
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

        -- MODULE 3: State Store
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

        -- MODULE 4: Performance Controller
        local Performance = (function()
-- Performance.luau: Low-End Android & Delta Executor High FPS Optimization
-- Accurately measures real FPS and disables heavy graphics effects with full state restoration.

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Performance = {
    _3dRendering = true,
    _perfMode = false,
    _savedShadows = true,
    _savedFog = 1000,
    _savedLightingProps = {} :: { [string]: any },
    _disabledEffects = {} :: { [Instance]: boolean },
    _fps = 60.0,
    _frameCount = 0,
    _fpsTimer = 0.0,
}

-- Real FPS calculation using frame timing (independent of display limits)
pcall(function()
    RunService.RenderStepped:Connect(function(dt: number)
        Performance._frameCount += 1
        Performance._fpsTimer += dt
        if Performance._fpsTimer >= 0.5 then
            Performance._fps = math.floor((Performance._frameCount / Performance._fpsTimer) * 10) / 10
            Performance._frameCount = 0
            Performance._fpsTimer = 0.0
        end
    end)
end)

function Performance.GetRealFPS(): number
    return Performance._fps
end

function Performance.Set3DRendering(enabled: boolean)
    Performance._3dRendering = enabled
    pcall(function()
        RunService:Set3dRenderingEnabled(enabled)
    end)
end

-- High FPS Mode: strips particle emitters, shadows, and post-processing while saving originals
function Performance.SetPerformanceMode(enabled: boolean)
    Performance._perfMode = enabled

    pcall(function()
        if enabled then
            -- Save lighting configuration
            Performance._savedShadows = Lighting.GlobalShadows
            Performance._savedFog = Lighting.FogEnd
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9

            -- Save and disable heavy post-processing effects in Lighting
            for _, child in ipairs(Lighting:GetChildren()) do
                if child:IsA("BloomEffect") or child:IsA("SunRaysEffect") or child:IsA("ColorCorrectionEffect") or child:IsA("DepthOfFieldEffect") or child:IsA("BlurEffect") then
                    if child.Enabled then
                        Performance._disabledEffects[child] = true
                        child.Enabled = false
                    end
                end
            end

            -- Disable heavy particle emitters and decals in workspace, excluding MM2 coin containers
            for _, obj in ipairs(Workspace:GetDescendants()) do
                -- NEVER touch coin containers or active candy models
                if obj.Name ~= "CoinContainer" and not obj:FindFirstChild("TouchInterest") and not obj:FindFirstChildWhichIsA("TouchTransmitter") then
                    if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                        if obj.Enabled then
                            Performance._disabledEffects[obj] = true
                            obj.Enabled = false
                        end
                    end
                end
            end
        else
            -- Restore original lighting
            Lighting.GlobalShadows = Performance._savedShadows
            Lighting.FogEnd = Performance._savedFog

            -- Restore all modified particle and post-processing effects
            for effect, wasEnabled in pairs(Performance._disabledEffects) do
                if effect and effect.Parent and wasEnabled then
                    pcall(function()
                        (effect :: any).Enabled = true
                    end)
                end
            end
            table.clear(Performance._disabledEffects)
        end
    end)
end

function Performance.IsPerformanceMode(): boolean
    return Performance._perfMode
end

return Performance

        end)()

        -- MODULE 5: Persistence Manager (Delta readfile/writefile)
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

        -- MODULE 6: Map & Round Lifecycle Manager
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
    local char = character or LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end

    local safePos = MapManager.GetSafeMapPosition()
    if safePos then
        hrp.CFrame = CFrame.new(safePos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        return true
    elseif MapManager.LobbyWaypoint then
        hrp.CFrame = MapManager.LobbyWaypoint
        hrp.AssemblyLinearVelocity = Vector3.zero
        return true
    end
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
    return MapManager.ParkInSafeSpot()
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

        -- MODULE 7: Candy & Coin Detector
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

        -- MODULE 8: Movement Engine
        local Movement = (function()
-- Movement.luau: Continuous Frame-Rate-Independent Movement & Reliable Candy Pickup
-- Mimics natural player traversal with RunService.Heartbeat interpolation, zero velocity spikes,
-- pre-physics noclip on Stepped, and observable tri-signal collection confirmation.

local RunService = game:GetService("RunService")
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

local function RefreshColliders(char: Model)
    table.clear(Movement._cachedColliders)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(Movement._cachedColliders, part)
        end
    end
end

-- Pre-physics collision override on Stepped (before PGS physics solver evaluates penetration)
local function ApplyNoclip()
    if not Movement.NoclipEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end

    for _, part in ipairs(Movement._cachedColliders) do
        if part and part.Parent and part.CanCollide then
            part.CanCollide = false
        end
    end

    local humanoid = char:FindFirstChildWhichIsA("Humanoid")
    if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end

    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

function Movement.SetNoclip(enabled: boolean)
    Movement.NoclipEnabled = enabled
    if enabled then
        if not Movement._noclipConnection then
            local char = LocalPlayer.Character
            if char then RefreshColliders(char) end
            Movement._noclipConnection = RunService.Stepped:Connect(ApplyNoclip)
        end
    else
        if Movement._noclipConnection then
            Movement._noclipConnection:Disconnect()
            Movement._noclipConnection = nil
        end
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and (part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "Head") then
                    part.CanCollide = true
                end
            end
            local humanoid = char:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end
end

-- Fire touch interest if executor supports it across multiple character limbs
function Movement.TouchTarget(char: Model, hrp: BasePart, targetPart: BasePart)
    local fireTouch = (getgenv and getgenv().firetouchinterest) or (_G and _G.firetouchinterest)
    if type(fireTouch) == "function" then
        pcall(function()
            fireTouch(hrp, targetPart, 0)
            fireTouch(hrp, targetPart, 1)

            local innerVisual = targetPart:FindFirstChild("CoinVisual")
            if innerVisual and innerVisual:IsA("BasePart") then
                fireTouch(hrp, innerVisual, 0)
                fireTouch(hrp, innerVisual, 1)
            end

            local leftLeg = char:FindFirstChild("LeftLeg") or char:FindFirstChild("LeftLowerLeg")
            if leftLeg and leftLeg:IsA("BasePart") then
                fireTouch(leftLeg, targetPart, 0)
                fireTouch(leftLeg, targetPart, 1)
            end

            local rightLeg = char:FindFirstChild("RightLeg") or char:FindFirstChild("RightLowerLeg")
            if rightLeg and rightLeg:IsA("BasePart") then
                fireTouch(rightLeg, targetPart, 0)
                fireTouch(rightLeg, targetPart, 1)
            end
        end)
    end
end

-- Check if candy was observably collected by MM2 game engine
function Movement.IsCoinCollected(targetPart: Instance): boolean
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

-- Cancel any active movement immediately, zero velocities, and restore physics
function Movement.Cancel()
    Movement.IsMoving = false

    if Movement._heartbeatConnection then
        Movement._heartbeatConnection:Disconnect()
        Movement._heartbeatConnection = nil
    end

    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        local humanoid = char:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
    end
end

-- Micro-nudge perturbation to force touch overlap if coin event didn't trigger
function Movement.MicroNudge(amplitude: number?)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end

    local amp = amplitude or 0.35
    local originalCFrame = hrp.CFrame
    hrp.CFrame = originalCFrame + Vector3.new(0, amp, 0)
    task.wait(0.04)
    if hrp and hrp.Parent then
        hrp.CFrame = originalCFrame
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end

-- Continuous frame-rate-independent movement toward target and verify observable collection
function Movement.MoveToAndCollect(
    targetPart: BasePart,
    speed: number,
    method: string?,
    isRoundActiveFn: (() -> boolean)?
): (boolean, string)
    Movement.Cancel()

    -- Fail-closed check: abort if round not active
    if isRoundActiveFn and not isRoundActiveFn() then
        return false, "Ожидание раунда"
    end

    local char = LocalPlayer.Character
    if not char then return false, "Ошибка" end

    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = char:FindFirstChildWhichIsA("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then return false, "Ошибка" end

    if not targetPart or not targetPart.Parent then
        return false, "Цель недоступна"
    end

    local targetPos = targetPart.Position
    local startPos = hrp.Position
    local distance = (targetPos - startPos).Magnitude

    local effectiveSpeed = math.clamp(speed or 28, 12, 45)
    local duration = distance / effectiveSpeed
    local maxAllowedTime = duration + 1.5

    Movement.IsMoving = true
    RefreshColliders(char)

    -- Continuous frame-rate-independent navigation loop (Heartbeat)
    local startTime = os.clock()
    local lastPos = hrp.Position
    local lastMoveCheck = startTime
    local arrived = false

    local movePromise = coroutine.running()

    Movement._heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
        if not Movement.IsMoving then
            if Movement._heartbeatConnection then
                Movement._heartbeatConnection:Disconnect()
                Movement._heartbeatConnection = nil
            end
            return
        end

        -- Check round state continuously
        if isRoundActiveFn and not isRoundActiveFn() then
            Movement.Cancel()
            coroutine.resume(movePromise, false, "Ожидание раунда")
            return
        end

        -- Check target validity mid-flight
        if not targetPart or not targetPart.Parent then
            Movement.Cancel()
            coroutine.resume(movePromise, false, "Цель недоступна")
            return
        end

        local curHrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not curHrp then
            Movement.Cancel()
            coroutine.resume(movePromise, false, "Ошибка")
            return
        end

        local curPos = curHrp.Position
        local delta = targetPart.Position - curPos
        local dist = delta.Magnitude

        -- Arrival condition (< 0.8 studs)
        if dist <= 0.8 then
            arrived = true
            curHrp.CFrame = targetPart.CFrame
            curHrp.AssemblyLinearVelocity = Vector3.zero
            curHrp.AssemblyAngularVelocity = Vector3.zero
            Movement.Cancel()
            coroutine.resume(movePromise, true, "Достигнуто")
            return
        end

        -- Timeout check
        local now = os.clock()
        if (now - startTime) > maxAllowedTime then
            Movement.Cancel()
            coroutine.resume(movePromise, false, "Таймаут движения")
            return
        end

        -- Anti-stuck progress check
        if (now - lastMoveCheck) > 0.8 then
            local moved = (curPos - lastPos).Magnitude
            if moved < 0.8 and dist > 2.5 then
                Movement.Cancel()
                coroutine.resume(movePromise, false, "Застревание")
                return
            end
            lastPos = curPos
            lastMoveCheck = now
        end

        -- Frame-rate independent step integration: step = Speed * dt
        local stepDist = math.min(effectiveSpeed * dt, dist)
        local moveDir = delta.Unit
        local nextPos = curPos + (moveDir * stepDist)

        -- Face naturally in movement direction on horizontal plane
        local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z)
        local nextCFrame: CFrame
        if flatDir.Magnitude > 0.001 then
            nextCFrame = CFrame.lookAlong(nextPos, flatDir.Unit, Vector3.yAxis)
        else
            nextCFrame = CFrame.new(nextPos)
        end

        curHrp.CFrame = nextCFrame
        curHrp.AssemblyLinearVelocity = Vector3.zero
        curHrp.AssemblyAngularVelocity = Vector3.zero
    end)

    local navSuccess, navReason = coroutine.yield()
    if not navSuccess then
        return false, navReason or "Ошибка навигации"
    end

    -- 2. Execute verified pickup interaction
    -- Position character directly overlapping the coin CFrame
    hrp.CFrame = targetPart.CFrame
    Movement.TouchTarget(char, hrp, targetPart)

    -- Ultra-fast observable collection check (check every 0.02s up to 0.12s)
    local waitStart = os.clock()
    while (os.clock() - waitStart) < 0.12 do
        if Movement.IsCoinCollected(targetPart) then
            return true, "Собираю конфеты"
        end
        task.wait(0.02)
    end

    -- 3. Retry with micro-nudge if not yet collected (quick 0.08s jolt)
    if not Movement.IsCoinCollected(targetPart) then
        Movement.MicroNudge(0.35)
        Movement.TouchTarget(char, hrp, targetPart)
        local retryStart = os.clock()
        while (os.clock() - retryStart) < 0.08 do
            if Movement.IsCoinCollected(targetPart) then
                return true, "Собираю конфеты"
            end
            task.wait(0.02)
        end
    end

    if Movement.IsCoinCollected(targetPart) then
        return true, "Собираю конфеты"
    else
        return false, "Конфета не подобрана"
    end
end

-- Backwards-compatible MoveTo alias
function Movement.MoveTo(
    target: BasePart | Vector3,
    speed: number,
    method: string?,
    isRoundActiveFn: (() -> boolean)?
): (boolean, string)
    if typeof(target) == "Vector3" then
        local char = LocalPlayer.Character
        if not char then return false, "Ошибка" end
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not hrp then return false, "Ошибка" end
        hrp.CFrame = CFrame.new(target)
        return true, "Перемещено"
    else
        return Movement.MoveToAndCollect(target, speed, method, isRoundActiveFn)
    end
end

-- Respawn handling
LocalPlayer.CharacterAdded:Connect(function(char)
    Movement.Cancel()
    RefreshColliders(char)
    char.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            table.insert(Movement._cachedColliders, descendant)
        end
    end)
end)

if LocalPlayer.Character then
    RefreshColliders(LocalPlayer.Character)
end

return Movement

        end)()

        -- MODULE 9: Farm Engine Orchestrator
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
                    if State.Config.Noclip then
                        Movement.SetNoclip(true)
                    end
                    State.SetStatus("SCANNING", "Раунд начался! Поиск конфет...")
                    FarmEngine.WakeLoop()
                else
                    Movement.Cancel()
                    Movement.SetNoclip(false)
                    State.SetStatus("WAITING_MAP", "Ожидание начала раунда...")
                end
            end
        end,
        OnRoundEnd = function()
            FarmEngine._roundsFarmed += 1
            State.IncrementRounds()

            -- Immediately halt all movement and restore normal collisions
            Movement.Cancel()
            Movement.SetNoclip(false)
            FarmEngine._activeTarget = nil
            State.SetDistance(0)

            if FarmEngine.IsRunning then
                State.SetStatus("ROUND_OVER", "Раунд завершён, пауза...")
                if State.Config.SafeSpotOnFull then
                    MapManager.TeleportToSafePlatform()
                end
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
                    Movement.Cancel()
                    Movement.SetNoclip(false)
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
            Movement.Cancel()
            if MapManager.IsRoundActive() then
                if State.Config.Noclip then
                    Movement.SetNoclip(true)
                end
                State.SetStatus("SCANNING", "Персонаж возрождён! Возобновление сбора...")
                FarmEngine.WakeLoop()
            else
                Movement.SetNoclip(false)
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
    Movement.Cancel()
    Movement.SetNoclip(false)
    FarmEngine._activeTarget = nil
    State.SetDistance(0)
    State.SetStatus("BAG_FULL", "Сумка заполнена! Ожидание конца раунда")

    if State.Config.SafeSpotOnFull then
        MapManager.TeleportToSafePlatform()
    end
end

-- Wake up the collection loop
function FarmEngine.WakeLoop()
    FarmEngine._loopToken += 1
    local currentToken = FarmEngine._loopToken

    task.spawn(function()
        FarmEngine.RunCollectionLoop(currentToken)
    end)
end

-- Start Farming
function FarmEngine.Start()
    if FarmEngine.IsRunning then return end
    FarmEngine.IsRunning = true
    State.Config.AutoFarm = true

    if State.Config.AntiAFK then
        AntiAFK.Enable()
    end

    -- Initial safety: Do NOT move or noclip until round is confirmed active
    Movement.Cancel()
    Movement.SetNoclip(false)
    MapManager.RecordLobbyWaypoint()

    if MapManager.IsRoundActive() then
        if State.Config.Noclip then
            Movement.SetNoclip(true)
        end
        State.SetStatus("SCANNING", "Round confirmed! Locating candies...")
    else
        State.SetStatus("WAITING_MAP", "Waiting for round to start (in lobby/intermission)...")
    end

    FarmEngine.WakeLoop()
end

-- Stop Farming
function FarmEngine.Stop()
    FarmEngine.IsRunning = false
    State.Config.AutoFarm = false
    FarmEngine._loopToken += 1

    Movement.Cancel()
    Movement.SetNoclip(false)

    State.SetStatus("IDLE", "Farm stopped by user")
    FarmEngine._activeTarget = nil
    State.SetDistance(0)
end

-- The core candy collection loop (Strictly gated by MapManager.IsRoundActive)
function FarmEngine.RunCollectionLoop(token: number)
    while FarmEngine.IsRunning and token == FarmEngine._loopToken do
        -- GATE 1: Fail-Closed Round Verification
        if not MapManager.IsRoundActive() then
            Movement.Cancel()
            Movement.SetNoclip(false)
            FarmEngine._activeTarget = nil
            State.SetDistance(0)

            local roundState = MapManager.GetRoundState()
            if roundState == "ENDING" then
                State.SetStatus("ROUND_OVER", "Round ended! Waiting for intermission...")
                if State.Config.SafeSpotOnFull then
                    MapManager.TeleportToSafePlatform()
                end
            else
                State.SetStatus("WAITING_MAP", "Waiting for round to start (in lobby/intermission)...")
            end

            task.wait(0.5)
            continue
        end

        -- GATE 2: Character and RootPart validity
        local char = LocalPlayer.Character
        if not char then
            State.SetStatus("DEAD", "Waiting for character respawn...")
            task.wait(0.5)
            continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local humanoid = char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not humanoid or humanoid.Health <= 0 then
            State.SetStatus("DEAD", "Player dead, awaiting respawn...")
            task.wait(0.5)
            continue
        end

        -- GATE 3: Check Bag Full condition
        local effectiveLimit = (State.Config.BagLimit > 0) and State.Config.BagLimit or State.BagCapacity
        if State.CandiesInBag >= effectiveLimit then
            FarmEngine.HandleBagFull()
            task.wait(1.5)
            continue
        end

        -- GATE 4: Active Map & CoinContainer existence
        local map, coinContainer = MapManager.FindActiveMap()
        if not map or not coinContainer then
            State.SetStatus("WAITING_MAP", "Map not ready...")
            task.wait(0.5)
            continue
        end

        State.SetMap(map.Name)

        -- Enable noclip now that round is 100% active
        if State.Config.Noclip and not Movement.NoclipEnabled then
            Movement.SetNoclip(true)
        end

        -- Find closest valid candy, strictly checking map bounds!
        local targetPart, distance = CandyDetector.GetClosestCandy(coinContainer, hrp.Position, "Candy", MapManager.IsPositionInsideMap)
        if not targetPart then
            targetPart, distance = CandyDetector.GetClosestCandy(coinContainer, hrp.Position, "All", MapManager.IsPositionInsideMap)
        end

        if not targetPart then
            State.SetStatus("SCANNING", "Конфеты не найдены, сканирую...")
            task.wait(0.5)
            continue
        end

        FarmEngine._activeTarget = targetPart
        State.SetDistance(distance)
        State.SetStatus("MOVING", string.format("Движение к конфете (%d м)", math.floor(distance)))

        -- Execute continuous movement with live round active check
        local speed = State.Config.MoveSpeed or 28
        local method = State.Config.MoveMethod or "Continuous"
        local success, reason = Movement.MoveToAndCollect(
            targetPart,
            speed,
            method,
            MapManager.IsRoundActive
        )

        if not FarmEngine.IsRunning or token ~= FarmEngine._loopToken then
            break
        end

        if success then
            State.SetStatus("COLLECTING", "Конфета успешно собрана")
            FarmEngine.BroadcastMetrics()
        else
            State.SetStatus("SCANNING", "Конфета недоступна (" .. tostring(reason) .. "), переключаю цель...")
            CandyDetector.RecordFailedPickup(targetPart, 2)
            CandyDetector.BlacklistCoin(targetPart, 10)
            FarmEngine.BroadcastMetrics()
        end

        CandyDetector.PruneBlacklist()
        task.wait(0.05)
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

        -- MODULE 10: Native Vector Icon Primitives
        local IconPrimitives = (function()
-- IconPrimitives.luau: Native Vector-Style UI Primitives for Roblox
-- Renders clean geometric icons using Frames, UICorner, UIStroke and Rotation.
-- Zero external image asset requests. Zero emojis. 100% self-contained.

local IconPrimitives = {}

local function Create(className: string, properties: { [string]: any }, children: { any }?): any
    local instance = Instance.new(className)
    for k, v in pairs(properties) do
        (instance :: any)[k] = v
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = instance
        end
    end
    return instance
end

-- Renders a scalable vector icon into a container Frame
function IconPrimitives.CreateIcon(iconName: string, size: number, color: Color3?, accentColor: Color3?): Frame
    local c = color or Color3.fromRGB(220, 220, 230)
    local ac = accentColor or Color3.fromRGB(168, 85, 247)
    local s = size or 16

    local container = Create("Frame", {
        Name = "Icon_" .. iconName,
        Size = UDim2.new(0, s, 0, s),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    })

    if iconName == "Candy" then
        -- Central candy diamond body
        Create("Frame", {
            Name = "Body",
            Size = UDim2.new(0.65, 0, 0.65, 0),
            Position = UDim2.new(0.175, 0, 0.175, 0),
            BackgroundColor3 = ac,
            Rotation = 45,
            BorderSizePixel = 0,
            Parent = container,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0.35, 0) }),
            Create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.5, Thickness = 1 }),
        })
        -- Left twist
        Create("Frame", {
            Name = "TwistL",
            Size = UDim2.new(0.22, 0, 0.22, 0),
            Position = UDim2.new(0.02, 0, 0.39, 0),
            BackgroundColor3 = c,
            Rotation = 25,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        -- Right twist
        Create("Frame", {
            Name = "TwistR",
            Size = UDim2.new(0.22, 0, 0.22, 0),
            Position = UDim2.new(0.76, 0, 0.39, 0),
            BackgroundColor3 = c,
            Rotation = -25,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

    elseif iconName == "Start" then
        -- Clean play triangle made of angled bars
        local bar1 = Create("Frame", {
            Size = UDim2.new(0.55, 0, 0.18, 0),
            Position = UDim2.new(0.25, 0, 0.32, 0),
            BackgroundColor3 = c,
            Rotation = 30,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        local bar2 = Create("Frame", {
            Size = UDim2.new(0.55, 0, 0.18, 0),
            Position = UDim2.new(0.25, 0, 0.52, 0),
            BackgroundColor3 = c,
            Rotation = -30,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        local spine = Create("Frame", {
            Size = UDim2.new(0.18, 0, 0.65, 0),
            Position = UDim2.new(0.2, 0, 0.18, 0),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

    elseif iconName == "Stop" then
        -- Rounded stop square
        Create("Frame", {
            Size = UDim2.new(0.68, 0, 0.68, 0),
            Position = UDim2.new(0.16, 0, 0.16, 0),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Parent = container,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0.22, 0) }),
        })

    elseif iconName == "Settings" then
        -- Gear icon
        for i = 0, 3 do
            Create("Frame", {
                Size = UDim2.new(0.85, 0, 0.22, 0),
                Position = UDim2.new(0.075, 0, 0.39, 0),
                BackgroundColor3 = c,
                Rotation = i * 45,
                BorderSizePixel = 0,
                Parent = container,
            }, { Create("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
        end
        Create("Frame", {
            Size = UDim2.new(0.52, 0, 0.52, 0),
            Position = UDim2.new(0.24, 0, 0.24, 0),
            BackgroundColor3 = ac,
            BorderSizePixel = 0,
            Parent = container,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
        })

    elseif iconName == "Performance" then
        -- Lightning bolt
        Create("Frame", {
            Size = UDim2.new(0.48, 0, 0.18, 0),
            Position = UDim2.new(0.28, 0, 0.18, 0),
            BackgroundColor3 = c,
            Rotation = -35,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.48, 0, 0.18, 0),
            Position = UDim2.new(0.24, 0, 0.62, 0),
            BackgroundColor3 = c,
            Rotation = -35,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.35, 0, 0.18, 0),
            Position = UDim2.new(0.32, 0, 0.41, 0),
            BackgroundColor3 = ac,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

    elseif iconName == "Zombie" then
        -- Geometric zombie skull
        Create("Frame", {
            Size = UDim2.new(0.72, 0, 0.72, 0),
            Position = UDim2.new(0.14, 0, 0.14, 0),
            BackgroundColor3 = Color3.fromRGB(34, 197, 94),
            BorderSizePixel = 0,
            Parent = container,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
        })
        -- Eyes
        Create("Frame", {
            Size = UDim2.new(0.18, 0, 0.18, 0),
            Position = UDim2.new(0.26, 0, 0.32, 0),
            BackgroundColor3 = Color3.fromRGB(234, 179, 8),
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.18, 0, 0.18, 0),
            Position = UDim2.new(0.56, 0, 0.32, 0),
            BackgroundColor3 = Color3.fromRGB(239, 68, 68),
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        -- Mouth stitch
        Create("Frame", {
            Size = UDim2.new(0.38, 0, 0.08, 0),
            Position = UDim2.new(0.31, 0, 0.65, 0),
            BackgroundColor3 = Color3.fromRGB(15, 23, 42),
            BorderSizePixel = 0,
            Parent = container,
        })

    elseif iconName == "Minimize" then
        -- Horizontal bar
        Create("Frame", {
            Size = UDim2.new(0.65, 0, 0.14, 0),
            Position = UDim2.new(0.175, 0, 0.43, 0),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

    elseif iconName == "Close" then
        -- Diagonal X
        Create("Frame", {
            Size = UDim2.new(0.7, 0, 0.14, 0),
            Position = UDim2.new(0.15, 0, 0.43, 0),
            BackgroundColor3 = c,
            Rotation = 45,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.7, 0, 0.14, 0),
            Position = UDim2.new(0.15, 0, 0.43, 0),
            BackgroundColor3 = c,
            Rotation = -45,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

    elseif iconName == "Status" then
        -- Radar pulse ring + core dot
        Create("Frame", {
            Size = UDim2.new(0.76, 0, 0.76, 0),
            Position = UDim2.new(0.12, 0, 0.12, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = container,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
            Create("UIStroke", { Color = c, Thickness = 1.5 }),
        })
        Create("Frame", {
            Size = UDim2.new(0.28, 0, 0.28, 0),
            Position = UDim2.new(0.36, 0, 0.36, 0),
            BackgroundColor3 = ac,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

    elseif iconName == "Movement" then
        -- Directional chevron
        Create("Frame", {
            Size = UDim2.new(0.48, 0, 0.16, 0),
            Position = UDim2.new(0.12, 0, 0.42, 0),
            BackgroundColor3 = c,
            Rotation = 45,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.48, 0, 0.16, 0),
            Position = UDim2.new(0.40, 0, 0.42, 0),
            BackgroundColor3 = c,
            Rotation = -45,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

    elseif iconName == "Statistics" then
        -- 3 vertical activity bars
        Create("Frame", {
            Size = UDim2.new(0.16, 0, 0.38, 0),
            Position = UDim2.new(0.18, 0, 0.48, 0),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.4, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.16, 0, 0.68, 0),
            Position = UDim2.new(0.42, 0, 0.18, 0),
            BackgroundColor3 = ac,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.4, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.16, 0, 0.50, 0),
            Position = UDim2.new(0.66, 0, 0.36, 0),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.4, 0) }) })

    elseif iconName == "Refresh" then
        -- Ring with notch
        Create("Frame", {
            Size = UDim2.new(0.72, 0, 0.72, 0),
            Position = UDim2.new(0.14, 0, 0.14, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = container,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
            Create("UIStroke", { Color = c, Thickness = 1.5 }),
        })
        Create("Frame", {
            Size = UDim2.new(0.24, 0, 0.24, 0),
            Position = UDim2.new(0.62, 0, 0.10, 0),
            BackgroundColor3 = ac,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
    end

    return container
end

return IconPrimitives

        end)()

        -- MODULE 11: Zombie & Infection Mode Controller
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

        -- 2. Physical Character & Camera Orientation
        local lookDir = (threat.RootPart.Position - localHrp.Position)
        local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
        localHrp.CFrame = CFrame.lookAlong(localHrp.Position, flatLook, Vector3.yAxis)

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
        -- Unarmed Defense: Relocate away from threat
        if threat.Distance <= ZombieMode.EvasionBuffer then
            local fleeDir = (localHrp.Position - threat.RootPart.Position).Unit
            local targetEvade = localHrp.Position + (fleeDir * 16.0)
            if MapManager.IsPositionInsideMap(targetEvade) then
                localHrp.CFrame = CFrame.new(targetEvade)
                localHrp.AssemblyLinearVelocity = Vector3.zero
            else
                MapManager.ParkInSafeSpot(char)
            end
            ZombieMode.StatusMessage = "Уклонение от зомби! Переход в укрытие"
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

        -- MODULE 12: Mobile UI (NEBULA PRO + MIDNIGHT Interface)
        local MobileUI = (function()
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

        end)()

        -- ==============================================================================
        -- RUNTIME INTEGRATION & ENTRY POINT
        -- ==============================================================================
        local UI = nil

        local function HandleUnload()
            FarmEngine.Destroy()
            ZombieMode.Stop()
            if UI then
                UI:Destroy()
                UI = nil
            end
            _G.PrivateMM2CandyFarmCleanup = nil
            print("[Private MM2 Candy Farm] Unloaded cleanly.")
        end

        _G.PrivateMM2CandyFarmCleanup = HandleUnload

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

            OnToggleZombie = function(enabled)
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

            OnPerfModeChanged = function(enabled)
                Performance.SetPerformanceMode(enabled)
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

        ZombieMode.Init(function(data)
            if UI then
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
