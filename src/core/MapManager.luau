--!strict
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
