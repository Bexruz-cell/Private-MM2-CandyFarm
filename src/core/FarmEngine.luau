--!strict
-- FarmEngine.luau: Central MM2 Candy Farm Orchestrator & State Machine
-- Handles task execution, candy collection, map transitions, respawns, and metrics

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local State = require(script.Parent.State)
local Maid = require(script.Parent.Parent.utils.Maid)
local AntiAFK = require(script.Parent.Parent.utils.AntiAFK)
local MapManager = require(script.Parent.MapManager)
local CandyDetector = require(script.Parent.CandyDetector)
local Movement = require(script.Parent.Movement)
local Performance = require(script.Parent.Performance)
local Persistence = require(script.Parent.Persistence)

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
