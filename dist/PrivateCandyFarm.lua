--[[
    ==============================================================================
    PRIVATE MM2 CANDY FARM — DELTA EXECUTOR ANDROID / WINDOWS
    ==============================================================================
    Version: 2.0.0 PRO (Autonomous Clean-Room Implementation)
    Platform: Delta Executor (Android Mobile & Windows)
    Target: Roblox Murder Mystery 2 (Halloween Candy / Seasonal Coins)
    Author: Autonomous Engineering Team (Tech Lead & Council)

    SECURITY NOTICE:
    - 100% Standalone & Self-Contained. Zero external loaders or remote fetches.
    - Zero Webhooks, zero analytics, zero credential/token access.
    - Zero obfuscated code. Clean, inspectable, high-performance Luau.

    ROCKHUB FEATURE PARITY:
    - Coin & Candy Autofarm (Start / Stop)          [VERIFIED & IMPLEMENTED]
    - Farm Speed Slider / Segmented Controls        [VERIFIED & IMPLEMENTED]
    - Performance Mode (FPS Booster for Android)    [VERIFIED & IMPLEMENTED]
    - Anti-AFK Idle Protection                      [VERIFIED & IMPLEMENTED]
    - Safe Platform Parking (Void / Sky on Full)    [VERIFIED & IMPLEMENTED]
    - Auto-Resume on Respawn & Intermission         [VERIFIED & IMPLEMENTED]
    - Screen Boundary Clamping & Mini HUD Pill      [VERIFIED & IMPLEMENTED]
    - Local Settings Persistence (readfile/writefile)[VERIFIED & IMPLEMENTED]
    - Clean Unload & Exit Script                    [VERIFIED & IMPLEMENTED]
    ==============================================================================
]]

do
    -- Prevent multiple running instances in the executor session
    if _G.PrivateMM2CandyFarmCleanup then
        pcall(_G.PrivateMM2CandyFarmCleanup)
        _G.PrivateMM2CandyFarmCleanup = nil
    end

    local Workspace = game:GetService("Workspace")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")
    local HttpService = game:GetService("HttpService")
    local Lighting = game:GetService("Lighting")

    local LocalPlayer = Players.LocalPlayer

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
    StatusMessage = "Ready to start",
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

function State.SetStatus(status: FarmStatus, message: string?)
    State.Status = status
    if message then
        State.StatusMessage = message
    end
    State._Emit("Status", status)
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
-- Performance.luau: Low-End Android & Delta Executor Optimization
-- Controls 3D rendering toggles, particle stripping, and FPS booster

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Performance = {
    _3dRendering = true,
    _perfMode = false,
    _originalShadows = true,
    _originalFog = 1000,
}

function Performance.Set3DRendering(enabled: boolean)
    Performance._3dRendering = enabled
    pcall(function()
        RunService:Set3dRenderingEnabled(enabled)
    end)
end

function Performance.SetPerformanceMode(enabled: boolean)
    Performance._perfMode = enabled

    pcall(function()
        if enabled then
            Performance._originalShadows = Lighting.GlobalShadows
            Performance._originalFog = Lighting.FogEnd

            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9

            -- Disable heavy decals and particles in workspace
            for _, obj in ipairs(game:GetService("Workspace"):GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                end
            end
        else
            Lighting.GlobalShadows = Performance._originalShadows
            Lighting.FogEnd = Performance._originalFog

            for _, obj in ipairs(game:GetService("Workspace"):GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = true
                end
            end
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
-- MapManager.luau: MM2 Active Map & Round Lifecycle Manager
-- Discovers active map, manages round states, and provides safe parking staging

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

export type RoundState = "WAITING" | "ROUND_ACTIVE" | "ROUND_ENDED"

local MapManager = {
    CurrentMap = nil :: Model?,
    CurrentCoinContainer = nil :: Instance?,
    RoundState = "WAITING" :: RoundState,
    SafePlatform = nil :: BasePart?,
    SafePosition = Vector3.new(0, -120, 0),
    LobbyWaypoint = nil :: CFrame?,
    _maid = nil :: any,
    _onRoundStart = nil :: (() -> ())?,
    _onRoundEnd = nil :: (() -> ())?,
    _onMapChanged = nil :: ((map: Model?) -> ())?,
}

-- Create an anchored invisible safe staging platform out of bounds
function MapManager.EnsureSafePlatform(): BasePart
    if MapManager.SafePlatform and MapManager.SafePlatform.Parent == Workspace then
        return MapManager.SafePlatform
    end

    local part = Instance.new("Part")
    part.Name = "MM2_SafeStagingPlatform"
    part.Size = Vector3.new(128, 4, 128)
    part.Position = MapManager.SafePosition
    part.Anchored = true
    part.CanCollide = true
    part.Transparency = 1 -- Invisible to avoid visual obstruction
    part.CastShadow = false
    part.Parent = Workspace

    MapManager.SafePlatform = part
    return part
end

function MapManager.RemoveSafePlatform()
    if MapManager.SafePlatform then
        pcall(function()
            MapManager.SafePlatform:Destroy()
        end)
        MapManager.SafePlatform = nil
    end
end

-- Find the active MM2 map
function MapManager.FindActiveMap(): (Model?, Instance?)
    -- Heuristic 1: Model with CoinContainer directly in Workspace
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child.Name ~= "Lobby" then
            local coinContainer = child:FindFirstChild("CoinContainer")
            if coinContainer then
                return child, coinContainer
            end
        end
    end

    -- Heuristic 2: Model with Spawns folder and CoinContainer descendant
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

-- Save the player's lobby position to return to after farming
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

function MapManager.TeleportToSafePlatform(character: Model?): boolean
    local char = character or LocalPlayer.Character
    if not char then return false end

    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end

    MapManager.EnsureSafePlatform()
    hrp.CFrame = CFrame.new(MapManager.SafePosition + Vector3.new(0, 5, 0))
    hrp.AssemblyLinearVelocity = Vector3.zero
    return true
end

function MapManager.TeleportToLobbyWaypoint(character: Model?): boolean
    if not MapManager.LobbyWaypoint then return false end
    local char = character or LocalPlayer.Character
    if not char then return false end

    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end

    hrp.CFrame = MapManager.LobbyWaypoint
    hrp.AssemblyLinearVelocity = Vector3.zero
    return true
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

    -- Listen to MM2 Gameplay remotes if present
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local gameplay = remotes:FindFirstChild("Gameplay")
            if gameplay then
                local roundStart = gameplay:FindFirstChild("RoundStart") :: RemoteEvent?
                if roundStart and roundStart:IsA("RemoteEvent") then
                    maid:GiveTask(roundStart.OnClientEvent:Connect(function()
                        MapManager.RoundState = "ROUND_ACTIVE"
                        if MapManager._onRoundStart then
                            MapManager._onRoundStart()
                        end
                    end))
                end

                local roundEnd = gameplay:FindFirstChild("RoundEndFade") :: RemoteEvent?
                if roundEnd and roundEnd:IsA("RemoteEvent") then
                    maid:GiveTask(roundEnd.OnClientEvent:Connect(function()
                        MapManager.RoundState = "ROUND_ENDED"
                        if MapManager._onRoundEnd then
                            MapManager._onRoundEnd()
                        end
                    end))
                end
            end
        end
    end)

    -- Monitor Workspace child additions/removals for map transitions
    maid:GiveTask(Workspace.ChildAdded:Connect(function(child)
        if child:IsA("Model") and child.Name ~= "Lobby" then
            task.delay(0.5, function()
                local map, coinContainer = MapManager.FindActiveMap()
                if map ~= MapManager.CurrentMap then
                    MapManager.CurrentMap = map
                    MapManager.CurrentCoinContainer = coinContainer
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
            MapManager.RoundState = "ROUND_ENDED"
            if MapManager._onMapChanged then
                MapManager._onMapChanged(nil)
            end
            if MapManager._onRoundEnd then
                MapManager._onRoundEnd()
            end
        end
    end))

    -- Initial discovery
    local map, coinContainer = MapManager.FindActiveMap()
    MapManager.CurrentMap = map
    MapManager.CurrentCoinContainer = coinContainer
    if map then
        MapManager.RoundState = "ROUND_ACTIVE"
    end
end

return MapManager

    end)()

    -- MODULE 7: Candy & Coin Detector
    local CandyDetector = (function()
-- CandyDetector.luau: High-Performance MM2 Candy & Coin Detection
-- Finds collectible seasonal candies, sorts by distance, and maintains blacklists

local CandyDetector = {
    Blacklist = {} :: { [Instance]: number }, -- [coinInstance] = expiryTimestamp
    CoinTypeFilter = "Candy",                  -- Target event currency ("Candy", "Coin", or "All")
}

-- Check if an instance is a valid, active collectible candy
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
        -- In some versions TouchInterest is inside a child part
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

-- Resolve the BasePart position of a candy target
function CandyDetector.GetTargetPart(candy: Instance): BasePart?
    if candy:IsA("BasePart") then
        return candy
    elseif candy:IsA("Model") then
        return (candy.PrimaryPart or candy:FindFirstChildWhichIsA("BasePart"))
    end
    return nil
end

-- Find all currently valid candies in the active container
function CandyDetector.GetCandies(coinContainer: Instance?, coinTypeFilter: string?): { BasePart }
    local result = {}
    if not coinContainer then return result end

    local filter = coinTypeFilter or CandyDetector.CoinTypeFilter
    for _, item in ipairs(coinContainer:GetChildren()) do
        if CandyDetector.IsValidCandy(item, filter) then
            local part = CandyDetector.GetTargetPart(item)
            if part then
                table.insert(result, part)
            end
        end
    end

    return result
end

-- Find the closest valid candy using squared distance (O(1) sqrt-free)
function CandyDetector.GetClosestCandy(coinContainer: Instance?, playerPos: Vector3, coinTypeFilter: string?): (BasePart?, number)
    local candidates = CandyDetector.GetCandies(coinContainer, coinTypeFilter)
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

-- Temporarily blacklist a coin that caused a timeout or stall
function CandyDetector.BlacklistCoin(coin: Instance, durationSeconds: number?)
    local duration = durationSeconds or 12
    CandyDetector.Blacklist[coin] = os.clock() + duration
end

-- Clear expired blacklists to free memory
function CandyDetector.PruneBlacklist()
    local now = os.clock()
    for coin, expiry in pairs(CandyDetector.Blacklist) do
        if now >= expiry or not coin.Parent then
            CandyDetector.Blacklist[coin] = nil
        end
    end
end

function CandyDetector.ClearBlacklist()
    table.clear(CandyDetector.Blacklist)
end

return CandyDetector

    end)()

    -- MODULE 8: Movement Engine
    local Movement = (function()
-- Movement.luau: Robust MM2 Character Movement & Anti-Stuck Controller
-- Provides TweenService, Step-Lerp, and BodyVelocity flight with safe cancellation

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Movement = {
    ActiveTween = nil :: Tween?,
    ActiveBodyVelocity = nil :: BodyVelocity?,
    ActiveBodyGyro = nil :: BodyGyro?,
    IsMoving = false,
    NoclipEnabled = false,
    _noclipConnection = nil :: RBXScriptConnection?,
    _stuckTimer = 0,
    _lastPosition = Vector3.zero,
}

-- Enable or disable Noclip on the local character
function Movement.SetNoclip(enabled: boolean)
    Movement.NoclipEnabled = enabled
    if enabled then
        if not Movement._noclipConnection then
            Movement._noclipConnection = RunService.Stepped:Connect(function()
                if not Movement.NoclipEnabled then return end
                local char = LocalPlayer.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end
    else
        if Movement._noclipConnection then
            Movement._noclipConnection:Disconnect()
            Movement._noclipConnection = nil
        end
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- Fire touch interest if executor supports it
function Movement.TouchTarget(hrp: BasePart, targetPart: BasePart)
    local fireTouch = (getgenv and getgenv().firetouchinterest) or (_G and _G.firetouchinterest)
    if type(fireTouch) == "function" then
        pcall(function()
            fireTouch(hrp, targetPart, 0)
            task.wait(0.02)
            fireTouch(hrp, targetPart, 1)
        end)
    end
end

-- Cancel any active movement immediately and restore physics
function Movement.Cancel()
    Movement.IsMoving = false

    if Movement.ActiveTween then
        pcall(function()
            Movement.ActiveTween:Cancel()
        end)
        Movement.ActiveTween = nil
    end

    if Movement.ActiveBodyVelocity then
        pcall(function()
            Movement.ActiveBodyVelocity:Destroy()
        end)
        Movement.ActiveBodyVelocity = nil
    end

    if Movement.ActiveBodyGyro then
        pcall(function()
            Movement.ActiveBodyGyro:Destroy()
        end)
        Movement.ActiveBodyGyro = nil
    end

    local char = LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

-- Move to target position using configured method with timeout guard
function Movement.MoveTo(targetPosition: Vector3, speed: number, method: string?, timeoutGuard: number?): boolean
    Movement.Cancel()

    local char = LocalPlayer.Character
    if not char then return false end

    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = char:FindFirstChildWhichIsA("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then return false end

    local startPos = hrp.Position
    local distance = (targetPosition - startPos).Magnitude
    if distance < 1.5 then
        return true
    end

    local effectiveSpeed = math.clamp(speed or 32, 10, 80)
    local duration = distance / effectiveSpeed
    local maxAllowedTime = timeoutGuard or (duration + 1.2)

    Movement.IsMoving = true
    local chosenMethod = method or "Tween"

    if chosenMethod == "Instant" then
        hrp.CFrame = CFrame.new(targetPosition + Vector3.new(0, 1.5, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
        Movement.IsMoving = false
        return true
    end

    -- Method: TweenService
    if chosenMethod == "Tween" then
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        local targetCFrame = CFrame.new(targetPosition + Vector3.new(0, 1.5, 0))
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
        local tw = TweenService:Create(hrp, tweenInfo, { CFrame = targetCFrame })
        Movement.ActiveTween = tw
        tw:Play()

        local startTime = os.clock()
        local lastPos = hrp.Position
        local lastMoveCheck = startTime

        while Movement.IsMoving and tw.PlaybackState == Enum.PlaybackState.Playing do
            task.wait(0.05)
            local now = os.clock()

            -- Timeout guard
            if (now - startTime) > maxAllowedTime then
                Movement.Cancel()
                return false
            end

            -- Anti-stuck watchdog: check if distance moved in last 1.5s is < 1.0 stud
            if (now - lastMoveCheck) > 1.5 then
                local moved = (hrp.Position - lastPos).Magnitude
                if moved < 1.0 and distance > 5.0 then
                    Movement.Cancel()
                    return false
                end
                lastPos = hrp.Position
                lastMoveCheck = now
            end
        end

        Movement.IsMoving = false
        return (tw.PlaybackState == Enum.PlaybackState.Completed)
    end

    -- Method: Step-Lerp (Heartbeat)
    local startTime = os.clock()
    local targetCFrame = CFrame.new(targetPosition + Vector3.new(0, 1.5, 0))
    local completed = false

    while Movement.IsMoving do
        local dt = RunService.Heartbeat:Wait()
        local elapsed = os.clock() - startTime
        local alpha = math.clamp(elapsed / duration, 0, 1)

        char:PivotTo(CFrame.new(startPos:Lerp(targetPosition, alpha)))

        if alpha >= 1 then
            completed = true
            break
        end

        if elapsed > maxAllowedTime then
            Movement.Cancel()
            return false
        end
    end

    Movement.IsMoving = false
    hrp.AssemblyLinearVelocity = Vector3.zero
    return completed
end

return Movement

    end)()

    -- MODULE 9: Farm Engine Orchestrator
    local FarmEngine = (function()
-- FarmEngine.luau: Central MM2 Candy Farm Orchestrator & State Machine
-- Handles task execution, candy collection, map transitions, respawns, and metrics

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

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

        -- Look for Candy or SnowToken or Coin
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

    -- Setup MapManager lifecycle
    MapManager.Init(FarmEngine._maid, {
        OnRoundStart = function()
            if FarmEngine.IsRunning then
                State.SetStatus("SCANNING", "Round started! Scanning map...")
                FarmEngine.WakeLoop()
            end
        end,
        OnRoundEnd = function()
            FarmEngine._roundsFarmed += 1
            State.IncrementRounds()
            if FarmEngine.IsRunning then
                Movement.Cancel()
                Movement.SetNoclip(false)
                State.SetStatus("ROUND_OVER", "Round ended! Waiting for intermission...")
                if State.Config.SafeSpotOnFull then
                    MapManager.TeleportToSafePlatform()
                end
            end
        end,
        OnMapChanged = function(map)
            if map then
                State.SetMap(map.Name)
                if FarmEngine.IsRunning then
                    State.SetStatus("SCANNING", "Map loaded: " .. map.Name)
                    FarmEngine.WakeLoop()
                end
            else
                State.SetMap("None")
                if FarmEngine.IsRunning then
                    State.SetStatus("WAITING_MAP", "Waiting for active map...")
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
        task.wait(1.0) -- Allow character parts to replicate
        if FarmEngine.IsRunning and State.Config.AutoResumeOnRespawn then
            Movement.Cancel()
            if State.Config.Noclip then
                Movement.SetNoclip(true)
            end
            State.SetStatus("SCANNING", "Respawned! Resuming candy farm...")
            FarmEngine.WakeLoop()
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

    -- Fallback bag reading from GUI if 0
    if currentBag == 0 then
        local guiCur, _ = ReadBagFromGui()
        if guiCur and guiCur > 0 then
            currentBag = guiCur
            State.UpdateBag(guiCur, maxBag)
        end
    end

    FarmEngine._uiCallback({
        bagCurrent = currentBag,
        bagMax = maxBag,
        totalCandies = FarmEngine._sessionCandies,
        roundsFarmed = FarmEngine._roundsFarmed,
        elapsedSeconds = elapsed,
        mapName = State.ActiveMapName,
        targetDistance = State.CurrentTargetDistance,
        cpm = cpm,
    })
end

-- Handle Bag Full state
function FarmEngine.HandleBagFull()
    Movement.Cancel()
    Movement.SetNoclip(false)
    State.SetStatus("BAG_FULL", "Bag capacity reached! Awaiting round end.")

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

    if State.Config.Noclip then
        Movement.SetNoclip(true)
    end

    MapManager.RecordLobbyWaypoint()
    State.SetStatus("SCANNING", "Farm started! Locating targets...")
    FarmEngine.WakeLoop()
end

-- Stop Farming
function FarmEngine.Stop()
    FarmEngine.IsRunning = false
    State.Config.AutoFarm = false
    FarmEngine._loopToken += 1 -- Invalidate any running loop token

    Movement.Cancel()
    Movement.SetNoclip(false)

    State.SetStatus("IDLE", "Farm stopped by user")
    FarmEngine._activeTarget = nil
    State.SetDistance(0)
end

-- The core candy collection loop
function FarmEngine.RunCollectionLoop(token: number)
    while FarmEngine.IsRunning and token == FarmEngine._loopToken do
        local char = LocalPlayer.Character
        if not char then
            State.SetStatus("DEAD", "Waiting for character respawn...")
            task.wait(1.0)
            continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local humanoid = char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not humanoid or humanoid.Health <= 0 then
            State.SetStatus("DEAD", "Player dead, awaiting respawn...")
            task.wait(1.0)
            continue
        end

        -- Check Bag Full condition
        local effectiveLimit = (State.Config.BagLimit > 0) and State.Config.BagLimit or State.BagCapacity
        if State.CandiesInBag >= effectiveLimit then
            FarmEngine.HandleBagFull()
            task.wait(2.0)
            continue
        end

        -- Find active map & coin container
        local map, coinContainer = MapManager.FindActiveMap()
        if not map or not coinContainer then
            State.SetStatus("WAITING_MAP", "Waiting for round map to load...")
            task.wait(1.0)
            continue
        end

        State.SetMap(map.Name)

        -- Find closest valid candy
        local targetPart, distance = CandyDetector.GetClosestCandy(coinContainer, hrp.Position, "Candy")
        if not targetPart then
            -- If no specific "Candy" found, try general coins
            targetPart, distance = CandyDetector.GetClosestCandy(coinContainer, hrp.Position, "All")
        end

        if not targetPart then
            State.SetStatus("SCANNING", "No candies currently available; scanning...")
            task.wait(0.6)
            continue
        end

        FarmEngine._activeTarget = targetPart
        State.SetDistance(distance)
        State.SetStatus("MOVING", string.format("Moving to candy (%d studs)", math.floor(distance)))

        -- Execute movement towards the target
        local speed = State.Config.MoveSpeed or 32
        local method = State.Config.MoveMethod or "Tween"
        local success = Movement.MoveTo(targetPart.Position, speed, method)

        if not FarmEngine.IsRunning or token ~= FarmEngine._loopToken then
            break
        end

        if success then
            State.SetStatus("COLLECTING", "Collecting candy...")
            Movement.TouchTarget(hrp, targetPart)

            -- Short yield for collection replication
            local waitStart = os.clock()
            while targetPart.Parent and (os.clock() - waitStart) < 0.3 do
                task.wait(0.05)
            end

            -- If coin wasn't destroyed/collected after 0.5s, blacklist it temporarily
            if targetPart.Parent and (os.clock() - waitStart) >= 0.3 then
                CandyDetector.BlacklistCoin(targetPart, 10)
            end
        else
            -- Movement failed or stalled: blacklist coin so bot tries another
            CandyDetector.BlacklistCoin(targetPart, 12)
        end

        -- Clean up expired blacklists
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

    -- MODULE 10: Mobile UI (Delta Touch Interface)
    local MobileUI = (function()
-- MobileUI.luau: Premium Delta Android Mobile Interface
-- 100% self-contained Luau GUI with touch drag, screen boundary clamping,
-- mini HUD launcher, live metrics, performance toggle, and clean unload.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local UI_NAME = "MM2_Private_CandyFarm_UI"

local PALETTE = {
    BG_MAIN        = Color3.fromRGB(18, 18, 24),     -- #121218
    BG_CARD        = Color3.fromRGB(26, 26, 36),     -- #1a1a24
    BG_CONTAINER   = Color3.fromRGB(36, 36, 50),     -- #242432
    BORDER_SUBTLE  = Color3.fromRGB(50, 50, 68),     -- #323244
    ACCENT_PURPLE  = Color3.fromRGB(138, 75, 255),   -- #8a4bff
    ACCENT_MAGENTA = Color3.fromRGB(168, 85, 247),   -- #a855f7
    STATUS_MINT    = Color3.fromRGB(34, 197, 94),    -- #22c55e (Active / Farming)
    STATUS_RED     = Color3.fromRGB(239, 68, 68),    -- #ef4444 (Stopped / Bag Full)
    STATUS_AMBER   = Color3.fromRGB(245, 158, 11),   -- #f59e0b (Waiting / Intermission)
    STATUS_IDLE    = Color3.fromRGB(148, 163, 184),  -- #94a3b8 (Idle)
    TEXT_WHITE     = Color3.fromRGB(255, 255, 255),
    TEXT_MUTED     = Color3.fromRGB(148, 163, 184),
    TEXT_DIM       = Color3.fromRGB(100, 116, 139),
    PROGRESS_BG    = Color3.fromRGB(30, 30, 42),
}

local FONTS = {
    REGULAR = Enum.Font.GothamMedium,
    BOLD    = Enum.Font.GothamBold,
    BLACK   = Enum.Font.GothamBlack,
}

local function GetSafeGuiParent(): Instance
    if typeof(gethui) == "function" then
        local success, hui = pcall(gethui)
        if success and hui then return hui end
    end
    local success, core = pcall(function() return CoreGui end)
    if success and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function Create(className: string, properties: { [string]: any }, children: { Instance }?): Instance
    local inst = Instance.new(className)
    for k, v in pairs(properties or {}) do
        (inst :: any)[k] = v
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
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

-- Clamp GUI position within screen viewport so it cannot be dragged off-screen on Android
local function ClampToViewport(targetFrame: GuiObject, goalOffset: Vector2): UDim2
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
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
            local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
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
    self.CurrentStatus = "IDLE"
    self.Callbacks = userCallbacks
    self.Settings = {
        FarmSpeed = "Fast",
        BagCapacity = "Auto",
        SafePlatform = true,
        AutoResume = true,
        AntiAFK = true,
        PerfMode = false,
    }

    local safeParent = GetSafeGuiParent()
    local existing = safeParent:FindFirstChild(UI_NAME)
    if existing then
        pcall(function() existing:Destroy() end)
    end

    local screenGui = Create("ScreenGui", {
        Name = UI_NAME,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
        Parent = safeParent,
    })
    self.ScreenGui = screenGui

    -- Floating Launcher Pill (Mini HUD when main window is hidden)
    local floatingPill = Create("Frame", {
        Name = "FloatingLauncher",
        Size = UDim2.new(0, 126, 0, 36),
        Position = UDim2.new(0.5, -63, 0, 18),
        BackgroundColor3 = PALETTE.BG_MAIN,
        BorderSizePixel = 0,
        Active = true,
        Parent = screenGui,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 18) }),
        Create("UIStroke", {
            Color = PALETTE.ACCENT_PURPLE,
            Thickness = 1.4,
            Transparency = 0.2,
        }),
    })
    self.FloatingPill = floatingPill

    local pillStatusDot = Create("Frame", {
        Name = "StatusDot",
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(0, 10, 0.5, -4),
        BackgroundColor3 = PALETTE.STATUS_IDLE,
        BorderSizePixel = 0,
        Parent = floatingPill,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })
    self.PillStatusDot = pillStatusDot

    local pillLabel = Create("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, -26, 1, 0),
        Position = UDim2.new(0, 24, 0, 0),
        BackgroundTransparency = 1,
        Text = "🍬 0 / 40",
        Font = FONTS.BOLD,
        TextSize = 11,
        TextColor3 = PALETTE.TEXT_WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = floatingPill,
    })
    self.PillLabel = pillLabel

    MakeClampedDraggable(floatingPill, floatingPill)

    -- Main Window (Compact: 340x260 px)
    local mainWindow = Create("Frame", {
        Name = "MainWindow",
        Size = UDim2.new(0, 340, 0, 260),
        Position = UDim2.new(0.5, -170, 0.5, -130),
        BackgroundColor3 = PALETTE.BG_MAIN,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Parent = screenGui,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
        Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1.2 }),
    })
    self.MainWindow = mainWindow

    -- Header Bar
    local header = Create("Frame", {
        Name = "HeaderBar",
        Size = UDim2.new(1, 0, 0, 34),
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

    local title = Create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0, 180, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "🍬 DELTA CANDY FARM",
        Font = FONTS.BLACK,
        TextSize = 12,
        TextColor3 = PALETTE.TEXT_WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    local versionBadge = Create("TextLabel", {
        Name = "Badge",
        Size = UDim2.new(0, 52, 0, 16),
        Position = UDim2.new(0, 164, 0.5, -8),
        BackgroundColor3 = PALETTE.BG_CONTAINER,
        Text = "PRO v2.0",
        Font = FONTS.BOLD,
        TextSize = 9,
        TextColor3 = PALETTE.ACCENT_MAGENTA,
        Parent = header,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 4) }),
    })

    local minimizeBtn = Create("TextButton", {
        Name = "MinBtn",
        Size = UDim2.new(0, 26, 0, 22),
        Position = UDim2.new(1, -58, 0.5, -11),
        BackgroundColor3 = PALETTE.BG_CONTAINER,
        Text = "—",
        Font = FONTS.BOLD,
        TextSize = 11,
        TextColor3 = PALETTE.TEXT_MUTED,
        Parent = header,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
    })

    local closeBtn = Create("TextButton", {
        Name = "CloseBtn",
        Size = UDim2.new(0, 26, 0, 22),
        Position = UDim2.new(1, -28, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(44, 24, 28),
        Text = "✕",
        Font = FONTS.BOLD,
        TextSize = 11,
        TextColor3 = PALETTE.STATUS_RED,
        Parent = header,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
    })

    MakeClampedDraggable(header, mainWindow)

    -- Toggle Main Window visibility
    local function ToggleMainWindow()
        if mainWindow.Visible then
            Tween(mainWindow, 0.16, { Size = UDim2.new(0, 310, 0, 235), BackgroundTransparency = 0.5 })
            task.delay(0.16, function()
                mainWindow.Visible = false
                mainWindow.Size = UDim2.new(0, 340, 0, 260)
                mainWindow.BackgroundTransparency = 0
            end)
        else
            mainWindow.Visible = true
            mainWindow.Size = UDim2.new(0, 310, 0, 235)
            mainWindow.BackgroundTransparency = 0.4
            Tween(mainWindow, 0.16, { Size = UDim2.new(0, 340, 0, 260), BackgroundTransparency = 0 })
        end
    end

    minimizeBtn.MouseButton1Click:Connect(ToggleMainWindow)
    closeBtn.MouseButton1Click:Connect(ToggleMainWindow)

    floatingPill.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local startTime = tick()
            local endedConn
            endedConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    endedConn:Disconnect()
                    if (tick() - startTime) < 0.22 then
                        ToggleMainWindow()
                    end
                end
            end)
        end
    end)

    -- Navigation Bar (Dashboard & Settings)
    local tabBar = Create("Frame", {
        Name = "TabBar",
        Size = UDim2.new(1, -16, 0, 26),
        Position = UDim2.new(0, 8, 0, 38),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = mainWindow,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
    })

    local tabDashBtn = Create("TextButton", {
        Name = "TabDash",
        Size = UDim2.new(0.5, -2, 1, -4),
        Position = UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = PALETTE.ACCENT_PURPLE,
        Text = "📊 Dashboard",
        Font = FONTS.BOLD,
        TextSize = 11,
        TextColor3 = PALETTE.TEXT_WHITE,
        Parent = tabBar,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
    })

    local tabSettingsBtn = Create("TextButton", {
        Name = "TabSettings",
        Size = UDim2.new(0.5, -2, 1, -4),
        Position = UDim2.new(0.5, 0, 0, 2),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        Text = "⚙ Settings",
        Font = FONTS.BOLD,
        TextSize = 11,
        TextColor3 = PALETTE.TEXT_MUTED,
        Parent = tabBar,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
    })

    local pagesContainer = Create("Frame", {
        Name = "Pages",
        Size = UDim2.new(1, -16, 1, -74),
        Position = UDim2.new(0, 8, 0, 68),
        BackgroundTransparency = 1,
        Parent = mainWindow,
    })

    -- PAGE 1: DASHBOARD
    local dashPage = Create("Frame", {
        Name = "DashboardPage",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = true,
        Parent = pagesContainer,
    })

    -- Status Card
    local statusCard = Create("Frame", {
        Name = "StatusCard",
        Size = UDim2.new(1, 0, 0, 32),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = PALETTE.BG_CARD,
        BorderSizePixel = 0,
        Parent = dashPage,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
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
        Size = UDim2.new(0, 130, 1, 0),
        Position = UDim2.new(0, 24, 0, 0),
        BackgroundTransparency = 1,
        Text = "IDLE (READY)",
        Font = FONTS.BOLD,
        TextSize = 10,
        TextColor3 = PALETTE.STATUS_IDLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = statusCard,
    })
    self.StatusText = statusText

    local subInfoText = Create("TextLabel", {
        Name = "SubInfo",
        Size = UDim2.new(1, -165, 1, 0),
        Position = UDim2.new(0, 155, 0, 0),
        BackgroundTransparency = 1,
        Text = "Map: Lobby | Target: —",
        Font = FONTS.REGULAR,
        TextSize = 9.5,
        TextColor3 = PALETTE.TEXT_MUTED,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = statusCard,
    })
    self.SubInfoText = subInfoText

    -- Metric Grid (2x2)
    local metricGrid = Create("Frame", {
        Name = "MetricGrid",
        Size = UDim2.new(1, 0, 0, 96),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundTransparency = 1,
        Parent = dashPage,
    })

    local function CreateMetricCard(name: string, label: string, initialVal: string, posX: number, posY: number)
        local card = Create("Frame", {
            Name = name,
            Size = UDim2.new(0.5, -4, 0, 45),
            Position = UDim2.new(posX, 0, posY, 0),
            BackgroundColor3 = PALETTE.BG_CARD,
            BorderSizePixel = 0,
            Parent = metricGrid,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
            Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
        })

        local caption = Create("TextLabel", {
            Name = "Caption",
            Size = UDim2.new(1, -12, 0, 14),
            Position = UDim2.new(0, 8, 0, 4),
            BackgroundTransparency = 1,
            Text = label,
            Font = FONTS.REGULAR,
            TextSize = 9,
            TextColor3 = PALETTE.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
        })

        local val = Create("TextLabel", {
            Name = "Val",
            Size = UDim2.new(1, -12, 0, 20),
            Position = UDim2.new(0, 8, 0, 18),
            BackgroundTransparency = 1,
            Text = initialVal,
            Font = FONTS.BOLD,
            TextSize = 13,
            TextColor3 = PALETTE.TEXT_WHITE,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
        })

        return card, val
    end

    local cardBag, valBag = CreateMetricCard("CardBag", "BAG CAPACITY", "0 / 40", 0, 0)
    local cardTotal, valTotal = CreateMetricCard("CardTotal", "SESSION HARVEST", "0 🍬", 0.5, 0)
    local cardRounds, valRounds = CreateMetricCard("CardRounds", "ROUNDS FARMED", "0", 0, 0.52)
    local cardTime, valTime = CreateMetricCard("CardTime", "SESSION DURATION", "00:00:00", 0.5, 0.52)

    self.ValBag = valBag
    self.ValTotal = valTotal
    self.ValRounds = valRounds
    self.ValTime = valTime

    local bagProgressBg = Create("Frame", {
        Name = "ProgressBg",
        Size = UDim2.new(1, -16, 0, 3),
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

    -- Primary CTA Button
    local primaryBtn = Create("TextButton", {
        Name = "PrimaryActionButton",
        Size = UDim2.new(1, 0, 0, 38),
        Position = UDim2.new(0, 0, 1, -40),
        BackgroundColor3 = PALETTE.STATUS_MINT,
        Text = "▶  START FARMING",
        Font = FONTS.BLACK,
        TextSize = 13,
        TextColor3 = PALETTE.TEXT_WHITE,
        Parent = dashPage,
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
    end)

    -- PAGE 2: SETTINGS
    local settingsPage = Create("ScrollingFrame", {
        Name = "SettingsPage",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = PALETTE.ACCENT_PURPLE,
        CanvasSize = UDim2.new(0, 0, 0, 230),
        Visible = false,
        Parent = pagesContainer,
    })

    local function CreateSegmentedRow(yPos: number, titleText: string, options: { string }, currentOpt: string, onSelect)
        local row = Create("Frame", {
            Size = UDim2.new(1, -4, 0, 28),
            Position = UDim2.new(0, 0, 0, yPos),
            BackgroundColor3 = PALETTE.BG_CARD,
            BorderSizePixel = 0,
            Parent = settingsPage,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
            Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
        })

        local label = Create("TextLabel", {
            Size = UDim2.new(0, 95, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = titleText,
            Font = FONTS.BOLD,
            TextSize = 10,
            TextColor3 = PALETTE.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        local btnContainer = Create("Frame", {
            Size = UDim2.new(1, -105, 1, -6),
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
                TextSize = 9.5,
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

    local function CreateToggleRow(yPos: number, labelText: string, defaultVal: boolean, onToggle)
        local row = Create("Frame", {
            Size = UDim2.new(1, -4, 0, 28),
            Position = UDim2.new(0, 0, 0, yPos),
            BackgroundColor3 = PALETTE.BG_CARD,
            BorderSizePixel = 0,
            Parent = settingsPage,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
            Create("UIStroke", { Color = PALETTE.BORDER_SUBTLE, Thickness = 1 }),
        })

        local label = Create("TextLabel", {
            Size = UDim2.new(1, -55, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = labelText,
            Font = FONTS.BOLD,
            TextSize = 10,
            TextColor3 = PALETTE.TEXT_MUTED,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        local switch = Create("Frame", {
            Name = "Switch",
            Size = UDim2.new(0, 36, 0, 18),
            Position = UDim2.new(1, -44, 0.5, -9),
            BackgroundColor3 = defaultVal and PALETTE.STATUS_MINT or PALETTE.BG_CONTAINER,
            BorderSizePixel = 0,
            Parent = row,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
        })

        local knob = Create("Frame", {
            Name = "Knob",
            Size = UDim2.new(0, 14, 0, 14),
            Position = defaultVal and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
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
                Tween(switch, 0.15, { BackgroundColor3 = PALETTE.STATUS_MINT })
                Tween(knob, 0.15, { Position = UDim2.new(1, -16, 0.5, -7) })
            else
                Tween(switch, 0.15, { BackgroundColor3 = PALETTE.BG_CONTAINER })
                Tween(knob, 0.15, { Position = UDim2.new(0, 2, 0.5, -7) })
            end
            onToggle(state)
        end)

        return row
    end

    CreateSegmentedRow(0, "Farm Speed", { "Normal", "Fast", "Instant" }, self.Settings.FarmSpeed, function(val)
        self.Settings.FarmSpeed = val
        if self.Callbacks.OnSpeedChanged then self.Callbacks.OnSpeedChanged(val) end
    end)

    CreateSegmentedRow(32, "Bag Target", { "Auto", "40", "50" }, self.Settings.BagCapacity, function(val)
        self.Settings.BagCapacity = val
        if self.Callbacks.OnBagCapacityChanged then self.Callbacks.OnBagCapacityChanged(val) end
    end)

    CreateToggleRow(64, "Safe Spot (Void Platform on Full)", self.Settings.SafePlatform, function(val)
        self.Settings.SafePlatform = val
        if self.Callbacks.OnSafePlatformChanged then self.Callbacks.OnSafePlatformChanged(val) end
    end)

    CreateToggleRow(96, "Auto-Resume on Respawn", self.Settings.AutoResume, function(val)
        self.Settings.AutoResume = val
        if self.Callbacks.OnAutoResumeChanged then self.Callbacks.OnAutoResumeChanged(val) end
    end)

    CreateToggleRow(128, "Anti-AFK Protection", self.Settings.AntiAFK, function(val)
        self.Settings.AntiAFK = val
        if self.Callbacks.OnAntiAFKChanged then self.Callbacks.OnAntiAFKChanged(val) end
    end)

    CreateToggleRow(160, "Performance Mode (Low-End FPS)", self.Settings.PerfMode, function(val)
        self.Settings.PerfMode = val
        if self.Callbacks.OnPerfModeChanged then self.Callbacks.OnPerfModeChanged(val) end
    end)

    -- Clean Unload Button in Settings
    local unloadBtn = Create("TextButton", {
        Name = "UnloadBtn",
        Size = UDim2.new(1, -4, 0, 28),
        Position = UDim2.new(0, 0, 0, 194),
        BackgroundColor3 = Color3.fromRGB(50, 24, 28),
        Text = "🛑 Clean Unload & Exit Script",
        Font = FONTS.BOLD,
        TextSize = 10,
        TextColor3 = PALETTE.STATUS_RED,
        Parent = settingsPage,
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
        Create("UIStroke", { Color = Color3.fromRGB(100, 30, 35), Thickness = 1 }),
    })

    unloadBtn.MouseButton1Click:Connect(function()
        if self.Callbacks.OnUnload then
            self.Callbacks.OnUnload()
        else
            self:Destroy()
        end
    end)

    -- Tab Switching
    tabDashBtn.MouseButton1Click:Connect(function()
        tabDashBtn.BackgroundColor3 = PALETTE.ACCENT_PURPLE
        tabDashBtn.BackgroundTransparency = 0
        tabDashBtn.TextColor3 = PALETTE.TEXT_WHITE

        tabSettingsBtn.BackgroundTransparency = 1
        tabSettingsBtn.TextColor3 = PALETTE.TEXT_MUTED

        dashPage.Visible = true
        settingsPage.Visible = false
    end)

    tabSettingsBtn.MouseButton1Click:Connect(function()
        tabSettingsBtn.BackgroundColor3 = PALETTE.ACCENT_PURPLE
        tabSettingsBtn.BackgroundTransparency = 0
        tabSettingsBtn.TextColor3 = PALETTE.TEXT_WHITE

        tabDashBtn.BackgroundTransparency = 1
        tabDashBtn.TextColor3 = PALETTE.TEXT_MUTED

        settingsPage.Visible = true
        dashPage.Visible = false
    end)

    return self
end

function MobileUI:ToggleFarming()
    self.IsFarming = not self.IsFarming

    if self.IsFarming then
        self.PrimaryBtn.Text = "⏹  STOP FARMING"
        self.PrimaryBtn.BackgroundColor3 = PALETTE.STATUS_RED
        local grad = self.PrimaryBtn:FindFirstChildOfClass("UIGradient")
        if grad then
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(239, 68, 68)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 28, 28)),
            })
        end
        self:SetStatus("FARMING", "Traversing candies...")
    else
        self.PrimaryBtn.Text = "▶  START FARMING"
        self.PrimaryBtn.BackgroundColor3 = PALETTE.STATUS_MINT
        local grad = self.PrimaryBtn:FindFirstChildOfClass("UIGradient")
        if grad then
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 197, 94)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 145, 68)),
            })
        end
        self:SetStatus("IDLE", "Farm stopped by user")
    end

    if self.Callbacks.OnToggleFarm then
        self.Callbacks.OnToggleFarm(self.IsFarming)
    end
end

function MobileUI:SetStatus(statusKey: string, subInfo: string?)
    self.CurrentStatus = statusKey

    local color = PALETTE.STATUS_IDLE
    local title = "IDLE (READY)"

    if statusKey == "FARMING" or statusKey == "MOVING" or statusKey == "COLLECTING" then
        color = PALETTE.STATUS_MINT
        title = "FARMING CANDIES"
    elseif statusKey == "BAG_FULL" then
        color = PALETTE.STATUS_RED
        title = "BAG FULL (40/40)"
    elseif statusKey == "ROUND_OVER" then
        color = PALETTE.STATUS_AMBER
        title = "ROUND OVER"
    elseif statusKey == "WAITING_MAP" then
        color = PALETTE.ACCENT_MAGENTA
        title = "WAITING FOR MAP"
    end

    if self.StatusDot then self.StatusDot.BackgroundColor3 = color end
    if self.PillStatusDot then self.PillStatusDot.BackgroundColor3 = color end
    if self.StatusText then
        self.StatusText.Text = title
        self.StatusText.TextColor3 = color
    end
    if subInfo and self.SubInfoText then
        self.SubInfoText.Text = subInfo
    end
end

function MobileUI:UpdateMetrics(metrics: {
    bagCurrent: number?,
    bagMax: number?,
    totalCandies: number?,
    roundsFarmed: number?,
    elapsedSeconds: number?,
    mapName: string?,
    targetDistance: number?,
    cpm: number?,
})
    if not metrics then return end

    if metrics.bagCurrent ~= nil and metrics.bagMax ~= nil then
        self.ValBag.Text = string.format("%d / %d", metrics.bagCurrent, metrics.bagMax)
        if self.PillLabel then
            self.PillLabel.Text = string.format("🍬 %d / %d", metrics.bagCurrent, metrics.bagMax)
        end

        local progress = math.clamp(metrics.bagCurrent / math.max(metrics.bagMax, 1), 0, 1)
        Tween(self.BagProgressFill, 0.2, { Size = UDim2.new(progress, 0, 1, 0) })
        if progress >= 1 then
            self.BagProgressFill.BackgroundColor3 = PALETTE.STATUS_RED
        else
            self.BagProgressFill.BackgroundColor3 = PALETTE.ACCENT_PURPLE
        end
    end

    if metrics.totalCandies ~= nil then
        self.ValTotal.Text = string.format("%d 🍬", metrics.totalCandies)
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
        local mapStr = metrics.mapName or "Unknown"
        local distStr = metrics.targetDistance and string.format("%d studs", math.floor(metrics.targetDistance)) or "—"
        self.SubInfoText.Text = string.format("Map: %s | Dist: %s", mapStr, distStr)
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
        if UI then
            UI:Destroy()
            UI = nil
        end
        _G.PrivateMM2CandyFarmCleanup = nil
        print("[Private MM2 Candy Farm] Unloaded cleanly.")
    end

    _G.PrivateMM2CandyFarmCleanup = HandleUnload

    local function ResolveSpeed(mode)
        if mode == "Normal" then return 28
        elseif mode == "Fast" then return 38
        elseif mode == "Instant" then return 80
        end
        return 32
    end

    UI = MobileUI.Init({
        OnToggleFarm = function(enabled)
            if enabled then
                FarmEngine.Start()
            else
                FarmEngine.Stop()
            end
        end,

        OnSpeedChanged = function(mode)
            local speed = ResolveSpeed(mode)
            State.SetConfig("MoveSpeed", speed)
            State.SetConfig("MoveMethod", (mode == "Instant") and "Instant" or "Tween")
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

        OnUnload = function()
            HandleUnload()
        end,
    })

    FarmEngine.Init(function(metrics)
        if UI then
            UI:UpdateMetrics(metrics)
            UI:SetStatus(State.Status, State.StatusMessage)
        end
    end)

    print("[Private MM2 Candy Farm] Running! Touch the floating candy pill or dashboard to control.")
end
