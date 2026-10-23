--[[
    MM2 Delta Android Mobile - Independent Companion Features Suite
    Architect: Feature Researcher & Systems Architect (MM2 Candy Farm Council)
    Platform: Delta Executor on Android (Roblox Mobile Touch Engine & CoreGui)
    Standard: 100% Pure Luau (Instance.new), Zero External Dependencies, Zero Emojis, Zero Placebo Controls
    
    Subsystems Included:
      1. Session Timer (os.clock() high-res elapsed timer formatted as HH:MM:SS)
      2. Player Stats Monitor (Humanoid Health/MaxHealth, WalkSpeed, character lifecycle)
      3. Current Map Detector (workspace map model & CoinContainer observation, non-intrusive)
      4. MM2 Round State Observer (passive read-only signals, zero competing farm loops)
      5. UI Customization Engine (Transparency [0.0-0.5], UIScale [0.6-1.1], Accent Color Presets)
      6. Diagnostic Panel & Error Logger (safe pcall wrapper, ring buffer, engine telemetry)
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LogService = game:GetService("LogService")
local StatsService = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
assert(LocalPlayer, "LocalPlayer must exist in Roblox client environment")

local Companion = {}
local activeConnections: { [string]: RBXScriptConnection } = {}

local function RegisterConnection(id: string, conn: RBXScriptConnection)
    if activeConnections[id] then
        pcall(function() activeConnections[id]:Disconnect() end)
    end
    activeConnections[id] = conn
end

local function DisconnectConnection(id: string)
    if activeConnections[id] then
        pcall(function() activeConnections[id]:Disconnect() end)
        activeConnections[id] = nil
    end
end

--------------------------------------------------------------------------------
-- 1. SESSION TIMER SUBSYSTEM
--------------------------------------------------------------------------------
local SessionTimer = {}
SessionTimer.__index = SessionTimer

function SessionTimer.New()
    local self = setmetatable({}, SessionTimer)
    self.StartTime = os.clock()
    self.Accumulated = 0
    self.IsActive = false
    self.Connection = nil
    return self
end

function SessionTimer:Start()
    if self.IsActive then return end
    self.StartTime = os.clock()
    self.IsActive = true
end

function SessionTimer:Pause()
    if not self.IsActive then return end
    self.Accumulated = self.Accumulated + (os.clock() - self.StartTime)
    self.IsActive = false
end

function SessionTimer:Resume()
    if self.IsActive then return end
    self.StartTime = os.clock()
    self.IsActive = true
end

function SessionTimer:Reset()
    self.StartTime = os.clock()
    self.Accumulated = 0
end

function SessionTimer:GetElapsedSeconds(): number
    if self.IsActive then
        return self.Accumulated + (os.clock() - self.StartTime)
    end
    return self.Accumulated
end

function SessionTimer:GetFormattedTime(): string
    local totalSecs = math.floor(self:GetElapsedSeconds())
    local hours = math.floor(totalSecs / 3600)
    local mins = math.floor((totalSecs % 3600) / 60)
    local secs = totalSecs % 60
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

function SessionTimer:IsRunning(): boolean
    return self.IsActive
end

Companion.SessionTimer = SessionTimer

--------------------------------------------------------------------------------
-- 2. PLAYER STATS MONITOR SUBSYSTEM
--------------------------------------------------------------------------------
export type PlayerStats = {
    Health: number,
    MaxHealth: number,
    HealthRatio: number,
    WalkSpeed: number,
    IsAlive: boolean,
    StatusText: string,
    StatusColor: Color3,
}

local PlayerStatsMonitor = {}
PlayerStatsMonitor.__index = PlayerStatsMonitor

function PlayerStatsMonitor.New(onStatsUpdated: ((stats: PlayerStats) -> ())?)
    local self = setmetatable({}, PlayerStatsMonitor)
    self.OnStatsUpdated = onStatsUpdated
    self.CurrentStats = {
        Health = 100,
        MaxHealth = 100,
        HealthRatio = 1.0,
        WalkSpeed = 16.0,
        IsAlive = true,
        StatusText = "[СТАТУС: ЖИВ]",
        StatusColor = Color3.fromRGB(34, 197, 94),
    }
    self.IsRunning = false
    return self
end

function PlayerStatsMonitor:_Evaluate(humanoid: Humanoid?)
    if not humanoid or humanoid.Health <= 0 then
        self.CurrentStats.Health = 0
        self.CurrentStats.MaxHealth = humanoid and humanoid.MaxHealth or 100
        self.CurrentStats.HealthRatio = 0
        self.CurrentStats.WalkSpeed = 0
        self.CurrentStats.IsAlive = false
        self.CurrentStats.StatusText = "[СТАТУС: ПОГИБ]"
        self.CurrentStats.StatusColor = Color3.fromRGB(239, 68, 68)
    else
        local h = humanoid.Health
        local maxH = math.max(humanoid.MaxHealth, 1)
        local ratio = math.clamp(h / maxH, 0, 1)
        local ws = humanoid.WalkSpeed
        
        self.CurrentStats.Health = math.floor(h)
        self.CurrentStats.MaxHealth = math.floor(maxH)
        self.CurrentStats.HealthRatio = ratio
        self.CurrentStats.WalkSpeed = ws
        self.CurrentStats.IsAlive = true

        if ratio > 0.60 then
            self.CurrentStats.StatusText = "[ЗДОРОВЬЕ: НОРМА]"
            self.CurrentStats.StatusColor = Color3.fromRGB(34, 197, 94)
        elseif ratio >= 0.25 then
            self.CurrentStats.StatusText = "[ЗДОРОВЬЕ: РАНЕН]"
            self.CurrentStats.StatusColor = Color3.fromRGB(245, 158, 11)
        else
            self.CurrentStats.StatusText = "[ЗДОРОВЬЕ: КРИТИЧЕСКИ]"
            self.CurrentStats.StatusColor = Color3.fromRGB(239, 68, 68)
        end
    end

    if self.OnStatsUpdated then
        self.OnStatsUpdated(self.CurrentStats)
    end
end

function PlayerStatsMonitor:Start()
    if self.IsRunning then return end
    self.IsRunning = true

    local function HookHumanoid(character: Model)
        local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
        if not humanoid then return end

        self:_Evaluate(humanoid)

        RegisterConnection("PSM_HealthChanged", humanoid.HealthChanged:Connect(function()
            self:_Evaluate(humanoid)
        end))

        RegisterConnection("PSM_SpeedChanged", humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            self:_Evaluate(humanoid)
        end))

        RegisterConnection("PSM_MaxHealthChanged", humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
            self:_Evaluate(humanoid)
        end))
    end

    if LocalPlayer.Character then
        HookHumanoid(LocalPlayer.Character)
    end

    RegisterConnection("PSM_CharAdded", LocalPlayer.CharacterAdded:Connect(function(char)
        HookHumanoid(char)
    end))

    RegisterConnection("PSM_CharRemoving", LocalPlayer.CharacterRemoving:Connect(function()
        self:_Evaluate(nil)
    end))
end

function PlayerStatsMonitor:Stop()
    self.IsRunning = false
    DisconnectConnection("PSM_HealthChanged")
    DisconnectConnection("PSM_SpeedChanged")
    DisconnectConnection("PSM_MaxHealthChanged")
    DisconnectConnection("PSM_CharAdded")
    DisconnectConnection("PSM_CharRemoving")
end

function PlayerStatsMonitor:GetStats(): PlayerStats
    return self.CurrentStats
end

Companion.PlayerStatsMonitor = PlayerStatsMonitor

--------------------------------------------------------------------------------
-- 3. CURRENT MAP DETECTOR SUBSYSTEM (Non-Intrusive)
--------------------------------------------------------------------------------
export type MapInfo = {
    Name: string,
    Model: Model,
    CoinContainer: Instance?,
    CoinCount: number,
    ExtentsSize: Vector3,
    IsActive: boolean,
}

local MapDetector = {}
MapDetector.__index = MapDetector

local KNOWN_MAP_NAMES = {
    "Normal", "Mansion2", "BioLab", "Factory", "MilBase", "House2",
    "PoliceStation", "ResearchFacility", "Workplace", "Hospital3",
    "Hotel", "Bank2", "LogCabin", "VampireCastle",
}

function MapDetector.New(onMapChanged: ((mapInfo: MapInfo?) -> ())?)
    local self = setmetatable({}, MapDetector)
    self.OnMapChanged = onMapChanged
    self.CurrentMapInfo = nil :: MapInfo?
    self.IsRunning = false
    return self
end

function MapDetector:_FindCandidateMap(): Model?
    -- Standard MM2 map container
    local normal = Workspace:FindFirstChild("Normal")
    if normal and normal:IsA("Model") then
        return normal
    end

    -- Known named models
    for _, name in ipairs(KNOWN_MAP_NAMES) do
        local model = Workspace:FindFirstChild(name)
        if model and model:IsA("Model") then
            return model
        end
    end

    -- Fallback: Any model containing CoinContainer / Coins
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child.Name ~= "Terrain" and not Players:GetPlayerFromCharacter(child) then
            if child:FindFirstChild("CoinContainer") or child:FindFirstChild("Coins") or child:FindFirstChild("Coin_Server") then
                return child
            end
        end
    end

    return nil
end

function MapDetector:_EvaluateMap()
    local mapModel = self:_FindCandidateMap()
    if not mapModel then
        if self.CurrentMapInfo ~= nil then
            self.CurrentMapInfo = nil
            if self.OnMapChanged then
                self.OnMapChanged(nil)
            end
        end
        return
    end

    local coinCont = mapModel:FindFirstChild("CoinContainer") 
        or mapModel:FindFirstChild("Coins") 
        or mapModel:FindFirstChild("Coin_Server")

    local coinCount = 0
    if coinCont then
        coinCount = #coinCont:GetChildren()
    end

    local extents = Vector3.zero
    pcall(function()
        extents = mapModel:GetExtentsSize()
    end)

    local info: MapInfo = {
        Name = mapModel.Name,
        Model = mapModel,
        CoinContainer = coinCont,
        CoinCount = coinCount,
        ExtentsSize = extents,
        IsActive = true,
    }

    self.CurrentMapInfo = info
    if self.OnMapChanged then
        self.OnMapChanged(info)
    end
end

function MapDetector:Start()
    if self.IsRunning then return end
    self.IsRunning = true

    self:_EvaluateMap()

    RegisterConnection("MD_ChildAdded", Workspace.ChildAdded:Connect(function(child)
        if child:IsA("Model") then
            task.delay(0.2, function()
                if self.IsRunning then
                    self:_EvaluateMap()
                end
            end)
        end
    end))

    RegisterConnection("MD_ChildRemoved", Workspace.ChildRemoved:Connect(function(child)
        if self.CurrentMapInfo and self.CurrentMapInfo.Model == child then
            self:_EvaluateMap()
        end
    end))
end

function MapDetector:Stop()
    self.IsRunning = false
    DisconnectConnection("MD_ChildAdded")
    DisconnectConnection("MD_ChildRemoved")
    self.CurrentMapInfo = nil
end

function MapDetector:GetCurrentMap(): MapInfo?
    return self.CurrentMapInfo
end

Companion.MapDetector = MapDetector

--------------------------------------------------------------------------------
-- 4. MM2 ROUND STATE OBSERVER (Passive Read-Only Signals)
--------------------------------------------------------------------------------
local RoundObserver = {}
RoundObserver.__index = RoundObserver

function RoundObserver.New(onStateChanged: ((newState: string, oldState: string, details: any) -> ())?)
    local self = setmetatable({}, RoundObserver)
    self.OnStateChanged = onStateChanged
    self.CurrentState = "LOBBY"
    self.IsRunning = false
    return self
end

function RoundObserver:_Transition(newState: string, details: any)
    if self.CurrentState == newState then return end
    local oldState = self.CurrentState
    self.CurrentState = newState
    if self.OnStateChanged then
        self.OnStateChanged(newState, oldState, details or {})
    end
end

function RoundObserver:Start()
    if self.IsRunning then return end
    self.IsRunning = true

    -- 1. Hook MM2 ReplicatedStorage Remotes (Primary Channel)
    pcall(function()
        local remotes = ReplicatedStorage:WaitForChild("Remotes", 3)
        if not remotes then return end

        local gameplay = remotes:WaitForChild("Gameplay", 3)
        if not gameplay then return end

        local roundStart = gameplay:FindFirstChild("RoundStart")
        if roundStart and roundStart:IsA("RemoteEvent") then
            RegisterConnection("RO_RoundStart", roundStart.OnClientEvent:Connect(function(...)
                self:_Transition("IN_PROGRESS", { Signal = "RoundStart", Args = { ... } })
            end))
        end

        local roundEndFade = gameplay:FindFirstChild("RoundEndFade")
        if roundEndFade and roundEndFade:IsA("RemoteEvent") then
            RegisterConnection("RO_RoundEndFade", roundEndFade.OnClientEvent:Connect(function(...)
                self:_Transition("ROUND_END", { Signal = "RoundEndFade", Args = { ... } })
                task.delay(3.5, function()
                    if self.IsRunning and self.CurrentState == "ROUND_END" then
                        self:_Transition("LOBBY", { Signal = "LobbyReturnTimeout" })
                    end
                end)
            end))
        end

        local roleSelect = gameplay:FindFirstChild("RoleSelect")
        if roleSelect and roleSelect:IsA("RemoteEvent") then
            RegisterConnection("RO_RoleSelect", roleSelect.OnClientEvent:Connect(function(...)
                self:_Transition("STARTING", { Signal = "RoleSelect", Args = { ... } })
            end))
        end
    end)

    -- 2. Fallback Channel: Workspace Normal Map Model lifecycle
    RegisterConnection("RO_MapWatcher", Workspace.ChildAdded:Connect(function(child)
        if child.Name == "Normal" and child:IsA("Model") then
            self:_Transition("IN_PROGRESS", { Signal = "NormalMapSpawned" })
        end
    end))

    RegisterConnection("RO_MapDestroyWatcher", Workspace.ChildRemoved:Connect(function(child)
        if child.Name == "Normal" and child:IsA("Model") then
            self:_Transition("LOBBY", { Signal = "NormalMapDestroyed" })
        end
    end))

    -- Check initial state
    if Workspace:FindFirstChild("Normal") then
        self:_Transition("IN_PROGRESS", { Signal = "InitialPresence" })
    else
        self:_Transition("LOBBY", { Signal = "InitialPresence" })
    end
end

function RoundObserver:Stop()
    self.IsRunning = false
    DisconnectConnection("RO_RoundStart")
    DisconnectConnection("RO_RoundEndFade")
    DisconnectConnection("RO_RoleSelect")
    DisconnectConnection("RO_MapWatcher")
    DisconnectConnection("RO_MapDestroyWatcher")
end

function RoundObserver:GetCurrentState(): string
    return self.CurrentState
end

Companion.RoundObserver = RoundObserver

--------------------------------------------------------------------------------
-- 5. UI CUSTOMIZATION ENGINE (Transparency, Scale, Accent Color Picker)
--------------------------------------------------------------------------------
local UICustomizer = {}

UICustomizer.ColorPresets = {
    NEBULA_PURPLE = {
        Name = "NEBULA",
        Primary = Color3.fromRGB(138, 75, 255),  -- #8a4bff
        Secondary = Color3.fromRGB(168, 85, 247),-- #a855f7
        Stroke = Color3.fromRGB(76, 40, 137),
    },
    CYBER_CYAN = {
        Name = "CYBER",
        Primary = Color3.fromRGB(6, 182, 212),   -- #06b6d4
        Secondary = Color3.fromRGB(34, 211, 238),-- #22d3ee
        Stroke = Color3.fromRGB(14, 116, 144),
    },
    EMERALD_MINT = {
        Name = "EMERALD",
        Primary = Color3.fromRGB(16, 185, 129),  -- #10b981
        Secondary = Color3.fromRGB(52, 211, 153),-- #34d399
        Stroke = Color3.fromRGB(4, 120, 87),
    },
    CRIMSON_PHANTOM = {
        Name = "PHANTOM",
        Primary = Color3.fromRGB(239, 68, 68),   -- #ef4444
        Secondary = Color3.fromRGB(248, 113, 113),-- #f87171
        Stroke = Color3.fromRGB(153, 27, 27),
    },
    AMBER_GOLD = {
        Name = "MONARCH",
        Primary = Color3.fromRGB(245, 158, 11),  -- #f59e0b
        Secondary = Color3.fromRGB(251, 191, 36),-- #fbbf24
        Stroke = Color3.fromRGB(180, 83, 9),
    },
    OBSIDIAN_SLATE = {
        Name = "OBSIDIAN",
        Primary = Color3.fromRGB(113, 113, 122), -- #71717a
        Secondary = Color3.fromRGB(161, 161, 170),-- #a1a1aa
        Stroke = Color3.fromRGB(63, 63, 70),
    },
}

local managedFrames: { GuiObject } = {}
local managedStrokes: { UIStroke } = {}
local managedButtons: { GuiButton } = {}
local targetScaleInstance: UIScale? = nil

function UICustomizer.RegisterContainer(frame: GuiObject)
    table.insert(managedFrames, frame)
end

function UICustomizer.RegisterStroke(stroke: UIStroke)
    table.insert(managedStrokes, stroke)
end

function UICustomizer.RegisterButton(btn: GuiButton)
    table.insert(managedButtons, btn)
end

function UICustomizer.SetScaleInstance(scaleInst: UIScale)
    targetScaleInstance = scaleInst
end

function UICustomizer.SetTransparency(alpha: number)
    local clamped = math.clamp(alpha, 0.0, 0.5)
    for _, frame in ipairs(managedFrames) do
        pcall(function()
            frame.BackgroundTransparency = clamped
        end)
    end
end

function UICustomizer.SetScale(scale: number)
    local clamped = math.clamp(scale, 0.6, 1.1)
    if targetScaleInstance then
        targetScaleInstance.Scale = clamped
    end
end

function UICustomizer.ApplyPreset(presetKey: string)
    local preset = UICustomizer.ColorPresets[presetKey]
    if not preset then return end

    for _, stroke in ipairs(managedStrokes) do
        pcall(function()
            stroke.Color = preset.Primary
        end)
    end

    for _, btn in ipairs(managedButtons) do
        pcall(function()
            btn.BackgroundColor3 = preset.Primary
        end)
    end
end

-- Interactive Mobile Slider Generator
function UICustomizer.CreateSlider(
    parent: GuiObject,
    labelText: string,
    minVal: number,
    maxVal: number,
    defaultVal: number,
    formatStr: string,
    onValueChanged: (val: number) -> ()
): Frame
    local currentVal = math.clamp(defaultVal, minVal, maxVal)

    local container = Instance.new("Frame")
    container.Name = "Slider_" .. labelText
    container.Size = UDim2.new(1, 0, 0, 46)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 16)
    header.BackgroundTransparency = 1
    header.Parent = container

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.65, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = labelText
    title.TextColor3 = Color3.fromRGB(148, 163, 184)
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.35, 0, 1, 0)
    valueLabel.Position = UDim2.new(0.65, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = string.format(formatStr, currentVal)
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 11
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = header

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(1, 0, 0, 10)
    track.Position = UDim2.new(0, 0, 0, 22)
    track.BackgroundColor3 = Color3.fromRGB(36, 36, 50)
    track.BorderSizePixel = 0
    track.Active = true
    track.Parent = container

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local initialRatio = (currentVal - minVal) / math.max(maxVal - minVal, 1e-4)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(initialRatio, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(138, 75, 255)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.fromOffset(20, 20)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(initialRatio, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = track

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local isDragging = false

    local function UpdateFromX(inputX: number)
        local trackAbsPos = track.AbsolutePosition.X
        local trackAbsWidth = track.AbsoluteSize.X
        if trackAbsWidth <= 0 then return end

        local ratio = math.clamp((inputX - trackAbsPos) / trackAbsWidth, 0, 1)
        currentVal = minVal + ratio * (maxVal - minVal)

        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, 0, 0.5, 0)
        valueLabel.Text = string.format(formatStr, currentVal)

        onValueChanged(currentVal)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            UpdateFromX(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateFromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    return container
end

-- Mobile Color Preset Picker Generator
function UICustomizer.CreatePresetPicker(
    parent: GuiObject,
    onPresetSelected: (presetKey: string) -> ()
): Frame
    local container = Instance.new("Frame")
    container.Name = "ColorPresetPicker"
    container.Size = UDim2.new(1, 0, 0, 54)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 16)
    title.BackgroundTransparency = 1
    title.Text = "АКЦЕНТНЫЙ ЦВЕТ"
    title.TextColor3 = Color3.fromRGB(148, 163, 184)
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = container

    local swatches = Instance.new("Frame")
    swatches.Size = UDim2.new(1, 0, 0, 32)
    swatches.Position = UDim2.new(0, 0, 0, 20)
    swatches.BackgroundTransparency = 1
    swatches.Parent = container

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = swatches

    for key, data in pairs(UICustomizer.ColorPresets) do
        local btn = Instance.new("TextButton")
        btn.Name = "Swatch_" .. key
        btn.Size = UDim2.fromOffset(36, 28)
        btn.BackgroundColor3 = data.Primary
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = swatches

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1.5
        stroke.Color = Color3.fromRGB(50, 50, 68)
        stroke.Parent = btn

        btn.MouseButton1Click:Connect(function()
            UICustomizer.ApplyPreset(key)
            onPresetSelected(key)
        end)
    end

    return container
end

Companion.UICustomizer = UICustomizer

--------------------------------------------------------------------------------
-- 6. DIAGNOSTIC PANEL & ERROR LOGGER (Safe pcall Capture & Ring Buffer)
--------------------------------------------------------------------------------
export type LogEntry = {
    Timestamp: number,
    FormattedTime: string,
    Level: "INFO" | "WARN" | "ERROR",
    Source: string,
    Message: string,
    Trace: string?,
}

local DiagnosticLogger = {}
local logRingBuffer: { LogEntry } = {}
local maxBufferCapacity = 60
local onLogAddedCallback: ((entry: LogEntry) -> ())? = nil

function DiagnosticLogger.Init(capacity: number?, onLogAdded: ((entry: LogEntry) -> ())?)
    maxBufferCapacity = capacity or 60
    onLogAddedCallback = onLogAdded
    table.clear(logRingBuffer)
end

function DiagnosticLogger.Log(level: "INFO" | "WARN" | "ERROR", source: string, message: string, trace: string?)
    local now = os.clock()
    local entry: LogEntry = {
        Timestamp = now,
        FormattedTime = string.format("%.2f", now),
        Level = level,
        Source = source,
        Message = message,
        Trace = trace,
    }

    if #logRingBuffer >= maxBufferCapacity then
        table.remove(logRingBuffer, 1)
    end
    table.insert(logRingBuffer, entry)

    if onLogAddedCallback then
        pcall(function()
            onLogAddedCallback(entry)
        end)
    end
end

-- Safe call wrapper with full stack traceback
function DiagnosticLogger.SafeCall(source: string, func: (...any) -> ...any, ...: any): (boolean, any)
    local results = { xpcall(func, debug.traceback, ...) }
    local success = results[1]
    if not success then
        local errTrace = tostring(results[2])
        DiagnosticLogger.Log("ERROR", source, errTrace, errTrace)
    end
    return table.unpack(results)
end

function DiagnosticLogger.GetLogs(): { LogEntry }
    return logRingBuffer
end

function DiagnosticLogger.Clear()
    table.clear(logRingBuffer)
end

function DiagnosticLogger.GetSystemTelemetry(): { MemoryMb: number, PingMs: number, UptimeSec: number }
    local memMb = 0
    pcall(function()
        memMb = math.floor(StatsService:GetTotalMemoryUsageMb())
    end)

    local pingMs = 0
    pcall(function()
        pingMs = math.floor(LocalPlayer:GetNetworkPing() * 1000)
    end)

    return {
        MemoryMb = memMb,
        PingMs = pingMs,
        UptimeSec = math.floor(os.clock()),
    }
end

function DiagnosticLogger.StartEngineLogCapture()
    RegisterConnection("DL_LogService", LogService.MessageOut:Connect(function(msg, msgType)
        if msgType == Enum.MessageType.MessageError then
            DiagnosticLogger.Log("ERROR", "RobloxEngine", msg)
        elseif msgType == Enum.MessageType.MessageWarning then
            DiagnosticLogger.Log("WARN", "RobloxEngine", msg)
        end
    end))
end

function DiagnosticLogger.StopEngineLogCapture()
    DisconnectConnection("DL_LogService")
end

-- Scrollable Mobile Log View Generator
function DiagnosticLogger.CreateLogViewer(parent: GuiObject, height: number?): Frame
    local container = Instance.new("Frame")
    container.Name = "DiagnosticLogViewer"
    container.Size = UDim2.new(1, 0, 0, height or 140)
    container.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    container.BorderSizePixel = 0
    container.Parent = parent

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(50, 50, 68)
    stroke.Thickness = 1
    stroke.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container

    -- Top Toolbar
    local toolbar = Instance.new("Frame")
    toolbar.Size = UDim2.new(1, 0, 0, 26)
    toolbar.BackgroundTransparency = 1
    toolbar.Parent = container

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.5, 0, 1, 0)
    title.Position = UDim2.new(0, 8, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "ЖУРНАЛ ДИАГНОСТИКИ"
    title.TextColor3 = Color3.fromRGB(148, 163, 184)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 10
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = toolbar

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.fromOffset(70, 20)
    clearBtn.Position = UDim2.new(1, -78, 0, 3)
    clearBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 50)
    clearBtn.Text = "[ОЧИСТИТЬ]"
    clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 9
    clearBtn.AutoButtonColor = false
    clearBtn.Parent = toolbar

    local clearCorner = Instance.new("UICorner")
    clearCorner.CornerRadius = UDim.new(0, 4)
    clearCorner.Parent = clearBtn

    -- Scrolling entries list
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 1, -34)
    scroll.Position = UDim2.new(0, 8, 0, 28)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(138, 75, 255)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = container

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = scroll

    local function RenderLog(entry: LogEntry)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 18)
        row.BackgroundTransparency = 1
        row.Parent = scroll

        local color = Color3.fromRGB(148, 163, 184)
        if entry.Level == "ERROR" then
            color = Color3.fromRGB(239, 68, 68)
        elseif entry.Level == "WARN" then
            color = Color3.fromRGB(245, 158, 11)
        end

        local badge = Instance.new("TextLabel")
        badge.Size = UDim2.new(0, 46, 1, 0)
        badge.BackgroundTransparency = 1
        badge.Text = "[" .. entry.Level .. "]"
        badge.TextColor3 = color
        badge.Font = Enum.Font.GothamBold
        badge.TextSize = 9
        badge.TextXAlignment = Enum.TextXAlignment.Left
        badge.Parent = row

        local msg = Instance.new("TextLabel")
        msg.Size = UDim2.new(1, -50, 1, 0)
        msg.Position = UDim2.new(0, 50, 0, 0)
        msg.BackgroundTransparency = 1
        msg.Text = entry.Source .. ": " .. entry.Message
        msg.TextColor3 = Color3.fromRGB(220, 220, 235)
        msg.Font = Enum.Font.GothamMedium
        msg.TextSize = 9
        msg.TextXAlignment = Enum.TextXAlignment.Left
        msg.TextTruncate = Enum.TextTruncate.AtEnd
        msg.Parent = row
    end

    for _, entry in ipairs(logRingBuffer) do
        RenderLog(entry)
    end

    clearBtn.MouseButton1Click:Connect(function()
        DiagnosticLogger.Clear()
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
    end)

    onLogAddedCallback = function(newEntry)
        RenderLog(newEntry)
    end

    return container
end

Companion.DiagnosticLogger = DiagnosticLogger

--------------------------------------------------------------------------------
-- ATOMIC UNLOAD & CLEANUP
--------------------------------------------------------------------------------
function Companion.CleanupAll()
    for id, conn in pairs(activeConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(activeConnections)

    DiagnosticLogger.StopEngineLogCapture()
    table.clear(managedFrames)
    table.clear(managedStrokes)
    table.clear(managedButtons)
    targetScaleInstance = nil
end

return Companion
