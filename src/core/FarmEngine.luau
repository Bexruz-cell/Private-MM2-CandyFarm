--!strict
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
                    State.SetStatus("SCANNING", "Раунд начался! Мониторинг конфет...")
                    FarmEngine.WakeLoop()
                else
                    State.SetStatus("WAITING_MAP", "Ожидание начала раунда...")
                end
            end
        end,
        OnRoundEnd = function()
            FarmEngine._roundsFarmed += 1
            State.IncrementRounds()

            FarmEngine._activeTarget = nil
            State.SetDistance(0)

            if FarmEngine.IsRunning then
                State.SetStatus("ROUND_OVER", "Раунд завершён, пауза...")
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
            if MapManager.IsRoundActive() then
                State.SetStatus("SCANNING", "Персонаж возрождён! Наблюдение за сбором...")
                FarmEngine.WakeLoop()
            else
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
    FarmEngine._activeTarget = nil
    State.SetDistance(0)
    State.SetStatus("BAG_FULL", "Сумка заполнена! Ожидание конца раунда")
end

-- Wake up the collection loop
function FarmEngine.WakeLoop()
    FarmEngine._loopToken += 1
    local currentToken = FarmEngine._loopToken

    task.spawn(function()
        FarmEngine.RunCollectionLoop(currentToken)
    end)
end

-- Start Farming Telemetry Observer
function FarmEngine.Start()
    if FarmEngine.IsRunning then return end
    FarmEngine.IsRunning = true
    State.Config.AutoFarm = true

    if State.Config.AntiAFK then
        AntiAFK.Enable()
    end

    MapManager.RecordLobbyWaypoint()

    if MapManager.IsRoundActive() then
        State.SetStatus("SCANNING", "Раунд активен — наблюдение за сбором RockHub...")
    else
        State.SetStatus("WAITING_MAP", "Ожидание раунда (в лобби/интермиссии)...")
    end

    FarmEngine.WakeLoop()
end

-- Stop Farming Telemetry Observer
function FarmEngine.Stop()
    FarmEngine.IsRunning = false
    State.Config.AutoFarm = false
    FarmEngine._loopToken += 1

    State.SetStatus("IDLE", "Наблюдение остановлено пользователем")
    FarmEngine._activeTarget = nil
    State.SetDistance(0)
end

-- The passive companion collection loop (Zero movement, zero physics interference with RockHub)
-- Note: Movement.MoveToAndCollect is decommissioned. RockHub performs active movement.
-- FarmEngine operates strictly as a telemetry, metric broadcast, and HUD updater.
function FarmEngine.RunCollectionLoop(token: number)
    while FarmEngine.IsRunning and token == FarmEngine._loopToken do
        if MapManager.IsRoundActive() then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local map, coinContainer = MapManager.FindActiveMap()
            if hrp and coinContainer then
                local targetPart, distance = CandyDetector.GetClosestCandy(coinContainer, hrp.Position, "Candy", MapManager.IsPositionInsideMap)
                if not targetPart then
                    targetPart, distance = CandyDetector.GetClosestCandy(coinContainer, hrp.Position, "All", MapManager.IsPositionInsideMap)
                end
                if targetPart then
                    FarmEngine._activeTarget = targetPart
                    State.SetDistance(distance)
                    State.SetStatus("FARMING", string.format("Сбор RockHub | Ближайшая: %d м", math.floor(distance)))
                else
                    FarmEngine._activeTarget = nil
                    State.SetDistance(0)
                    State.SetStatus("SCANNING", "Ожидание спавна конфет...")
                end
            end
        else
            FarmEngine._activeTarget = nil
            State.SetDistance(0)
            State.SetStatus("WAITING_MAP", "Ожидание раунда...")
        end

        FarmEngine.BroadcastMetrics()
        CandyDetector.PruneBlacklist()
        task.wait(0.5)
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
