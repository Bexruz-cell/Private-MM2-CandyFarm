--!strict
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
