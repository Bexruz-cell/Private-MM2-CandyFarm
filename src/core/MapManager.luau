--!strict
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
