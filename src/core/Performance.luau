--[[
    MM2 Delta Android Mobile - High FPS Engine & Hardware Optimizer
    Architect: Subagent 5: Performance Engineer (MM2 Candy Farm Council)
    Platform: Delta Executor on Android (Roblox Mobile Graphics & Render Engine)
    Description:
      - Precision FPS tracking via RunService.RenderStepped frame deltas
        using a rolling average ring buffer over 10-20 frames (default 16 frames).
      - Frame time in milliseconds (dt * 1000).
      - Network ping detection via Stats.Network.ServerStatsItem["Data Ping"]:GetValue().
      - Non-destructive, 100% reversible High FPS optimization:
        * Lighting: GlobalShadows, FogEnd
        * Post-Processing: Atmosphere, Bloom, DepthOfField, SunRays, ColorCorrection, Blur
        * Terrain: Decoration (3D grass physics), WaterReflectance, WaterWaveSize, WaterWaveSpeed
        * Particles & Trails: ParticleEmitter, Trail, Beam, Fire, Smoke, Sparkles
        * Dynamic Lights: PointLight, SpotLight, SurfaceLight shadow suppression
      - Strict Exemption / Protection: ZERO impact on coin/candy models and drop instances.
      - Zero Memory Leaks: Weak-keyed instance caches (__mode = "k") and atomic unload contract.
]]

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local HighFPSEngine = {}
HighFPSEngine.__index = HighFPSEngine

-- Singleton Instance
local _instance = nil

-- Configuration Constants
local ROLLING_WINDOW_SIZE = 16 -- Frame window for rolling average (bounded in [10, 20])
local METRICS_UPDATE_INTERVAL = 0.25 -- Dispatch UI update every 250ms (4 Hz) for mobile CPU efficiency
local MIN_CLAMPED_DT = 0.0005 -- 2000 FPS ceiling guard
local MAX_CLAMPED_DT = 0.2    -- 5 FPS floor guard against pause / hitch spikes

-- Weak table constructor to prevent instance reference retention (Memory Leak Prevention)
local function CreateWeakInstanceTable()
    return setmetatable({}, { __mode = "k" })
end

-- Create or retrieve singleton engine instance
function HighFPSEngine.GetInstance()
    if not _instance then
        _instance = HighFPSEngine.new()
    end
    return _instance
end

function HighFPSEngine.new()
    local self = setmetatable({}, HighFPSEngine)

    self.IsEnabled = false

    -- State Snapshots (Lossless and Weak-keyed where Instances are keys)
    self.SavedState = {
        Lighting = {},
        PostEffects = CreateWeakInstanceTable(),
        Atmospheres = CreateWeakInstanceTable(),
        Particles = CreateWeakInstanceTable(),
        Lights = CreateWeakInstanceTable(),
        Terrain = {},
    }

    -- Active Connections
    self.DescendantAddedConn = nil
    self.FpsConnection = nil

    -- Performance Telemetry Metrics
    self.CurrentFPS = 60.0
    self.FrameTimeMs = 16.6
    self.AvgFrameTimeMs = 16.6
    self.CurrentPing = 0

    -- Rolling Average Ring Buffer
    self.DeltaBuffer = table.create(ROLLING_WINDOW_SIZE, 1 / 60)
    self.BufferIndex = 1
    self.BufferCount = 0
    self.DeltaSum = 0

    -- Event Callbacks
    self.OnFpsUpdated = nil       -- callback(fps: number, frameTimeMs: number)
    self.OnPingUpdated = nil      -- callback(pingMs: number)
    self.OnMetricsUpdated = nil   -- callback(fps: number, frameTimeMs: number, pingMs: number)

    -- Start background FPS & Telemetry tracker immediately
    self:StartFPSTracker()

    return self
end

--------------------------------------------------------------------------------
-- 1. REAL FPS, FRAME TIME & NETWORK PING ENGINE
--------------------------------------------------------------------------------

-- Network Ping Detection via Stats.Network.ServerStatsItem["Data Ping"]
function HighFPSEngine:GetPing(): number
    local success, ping = pcall(function()
        local item = Stats.Network.ServerStatsItem["Data Ping"]
        return item:GetValue()
    end)
    if success and typeof(ping) == "number" then
        self.CurrentPing = math.floor(ping + 0.5)
        return self.CurrentPing
    end

    -- Fallback: PerformanceStats.Ping
    local success2, ping2 = pcall(function()
        return Stats.PerformanceStats.Ping:GetValue()
    end)
    if success2 and typeof(ping2) == "number" then
        self.CurrentPing = math.floor(ping2 + 0.5)
        return self.CurrentPing
    end

    return self.CurrentPing or 0
end

-- Starts the RenderStepped precision frame delta sampling loop
function HighFPSEngine:StartFPSTracker()
    if self.FpsConnection then
        self.FpsConnection:Disconnect()
        self.FpsConnection = nil
    end

    -- Reset rolling ring buffer
    self.BufferIndex = 1
    self.BufferCount = 0
    self.DeltaSum = 0
    for i = 1, ROLLING_WINDOW_SIZE do
        self.DeltaBuffer[i] = 1 / 60
    end

    local elapsedSinceDispatch = 0

    self.FpsConnection = RunService.RenderStepped:Connect(function(dt: number)
        -- Guard against extreme lag spikes and pause deltas
        local clampedDt = math.clamp(dt, MIN_CLAMPED_DT, MAX_CLAMPED_DT)

        -- Rolling Average over 10-20 frames (ROLLING_WINDOW_SIZE = 16)
        if self.BufferCount < ROLLING_WINDOW_SIZE then
            self.BufferCount = self.BufferCount + 1
            self.DeltaSum = self.DeltaSum + clampedDt
            self.DeltaBuffer[self.BufferIndex] = clampedDt
        else
            self.DeltaSum = self.DeltaSum - self.DeltaBuffer[self.BufferIndex] + clampedDt
            self.DeltaBuffer[self.BufferIndex] = clampedDt
        end
        self.BufferIndex = (self.BufferIndex % ROLLING_WINDOW_SIZE) + 1

        local avgDt = self.DeltaSum / self.BufferCount
        local rollingFPS = 1 / avgDt

        -- Sub-millisecond Frame Time (dt * 1000)
        self.FrameTimeMs = math.floor((clampedDt * 1000) * 10) / 10
        self.AvgFrameTimeMs = math.floor((avgDt * 1000) * 10) / 10
        self.CurrentFPS = math.clamp(math.floor(rollingFPS + 0.5), 1, 360)

        elapsedSinceDispatch = elapsedSinceDispatch + clampedDt

        -- Dispatch UI callbacks on throttled window (0.25s) to conserve mobile CPU
        if elapsedSinceDispatch >= METRICS_UPDATE_INTERVAL then
            elapsedSinceDispatch = 0

            -- Query live network ping
            self:GetPing()

            if self.OnFpsUpdated then
                self.OnFpsUpdated(self.CurrentFPS, self.FrameTimeMs)
            end

            if self.OnPingUpdated then
                self.OnPingUpdated(self.CurrentPing)
            end

            if self.OnMetricsUpdated then
                self.OnMetricsUpdated(self.CurrentFPS, self.FrameTimeMs, self.CurrentPing)
            end
        end
    end)
end

function HighFPSEngine:GetFPS(): (number, number)
    return self.CurrentFPS, self.FrameTimeMs
end

function HighFPSEngine:GetMetrics(): (number, number, number)
    return self.CurrentFPS, self.FrameTimeMs, self.CurrentPing
end

--------------------------------------------------------------------------------
-- 2. CANDY & COIN MODEL PROTECTION FILTER (ZERO IMPACT GUARANTEE)
--------------------------------------------------------------------------------

-- Identifies if an instance belongs to a collectible candy, coin, gun drop, or player rig
local function IsProtectedInstance(inst: Instance?): boolean
    if not inst then return true end

    -- Check instance direct name
    local name = inst.Name:lower()
    if string.find(name, "coin") or string.find(name, "candy") or string.find(name, "gun") then
        return true
    end

    -- Check for TouchTransmitter (used by collectible MM2 items)
    if inst:FindFirstChildOfClass("TouchTransmitter") then
        return true
    end

    -- Walk ancestry up to Workspace to protect items inside map containers
    local current = inst.Parent
    while current and current ~= Workspace and current ~= game do
        local parentName = current.Name:lower()
        if string.find(parentName, "coin") or string.find(parentName, "candy") or string.find(parentName, "gun") then
            return true
        end
        if current.Name == "CoinContainer" or current.Name == "Coin_Server" or current.Name == "Coins" then
            return true
        end
        -- Protect player characters from rig / tool suppression
        if current:FindFirstChildOfClass("Humanoid") then
            return true
        end
        current = current.Parent
    end

    return false
end

--------------------------------------------------------------------------------
-- 3. HIGH FPS MODE: STATE CAPTURE & OPTIMIZATION
--------------------------------------------------------------------------------

function HighFPSEngine:SetEnabled(enable: boolean)
    if self.IsEnabled == enable then
        return
    end

    self.IsEnabled = enable

    if enable then
        self:ApplyOptimizations()
    else
        self:RestoreOriginalState()
    end
end

function HighFPSEngine:Toggle(): boolean
    self:SetEnabled(not self.IsEnabled)
    return self.IsEnabled
end

-- Optimizes a single descendant in Workspace with strict coin/candy exemption
function HighFPSEngine:OptimizeWorkspaceDescendant(inst: Instance)
    -- Guard: Strict Zero Impact on Coin/Candy models
    if IsProtectedInstance(inst) then
        return
    end

    -- Particle Emitters, Trails, Beams, Fire, Smoke, Sparkles
    local particleClasses = {
        "ParticleEmitter",
        "Trail",
        "Beam",
        "Fire",
        "Smoke",
        "Sparkles",
    }
    for _, pClass in ipairs(particleClasses) do
        if inst:IsA(pClass) then
            pcall(function()
                if self.SavedState.Particles[inst] == nil then
                    self.SavedState.Particles[inst] = inst.Enabled
                end
                inst.Enabled = false
            end)
            return
        end
    end

    -- Dynamic Lights: PointLight, SpotLight, SurfaceLight (Suppress expensive shadow maps)
    if inst:IsA("Light") then
        pcall(function()
            if self.SavedState.Lights[inst] == nil then
                self.SavedState.Lights[inst] = inst.Shadows
            end
            inst.Shadows = false
        end)
    end
end

-- Apply full optimization suite with lossless original property capture
function HighFPSEngine:ApplyOptimizations()
    -- 1. LIGHTING SERVICE OPTIMIZATIONS
    pcall(function()
        self.SavedState.Lighting = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
        }
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
    end)

    -- 2. POST-PROCESSING EFFECTS IN LIGHTING (Bloom, DepthOfField, SunRays, Atmosphere, etc.)
    pcall(function()
        for _, child in ipairs(Lighting:GetChildren()) do
            -- Atmosphere special handling (Atmosphere does not have .Enabled in Roblox)
            if child:IsA("Atmosphere") then
                pcall(function()
                    if self.SavedState.Atmospheres[child] == nil then
                        self.SavedState.Atmospheres[child] = {
                            Density = child.Density,
                            Haze = child.Haze,
                            Glare = child.Glare,
                        }
                    end
                    child.Density = 0
                    child.Haze = 0
                    child.Glare = 0
                end)
            elseif child:IsA("PostEffect") then
                pcall(function()
                    if self.SavedState.PostEffects[child] == nil then
                        self.SavedState.PostEffects[child] = child.Enabled
                    end
                    child.Enabled = false
                end)
            end
        end
    end)

    -- 3. WORKSPACE PARTICLES, TRAILS, BEAMS & DYNAMIC LIGHTS
    pcall(function()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            self:OptimizeWorkspaceDescendant(desc)
        end
    end)

    -- Dynamic DescendantAdded Guard (handles newly spawned map particles / bullet impacts)
    if self.DescendantAddedConn then
        self.DescendantAddedConn:Disconnect()
        self.DescendantAddedConn = nil
    end

    self.DescendantAddedConn = Workspace.DescendantAdded:Connect(function(inst: Instance)
        if self.IsEnabled then
            task.defer(function()
                if inst and inst.Parent then
                    self:OptimizeWorkspaceDescendant(inst)
                end
            end)
        end
    end)

    -- 4. TERRAIN 3D GRASS & WATER PHYSICS OPTIMIZATION
    pcall(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            self.SavedState.Terrain = {
                Decoration = terrain.Decoration,
                WaterReflectance = terrain.WaterReflectance,
                WaterWaveSize = terrain.WaterWaveSize,
                WaterWaveSpeed = terrain.WaterWaveSpeed,
            }
            terrain.Decoration = false
            terrain.WaterReflectance = 0
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
        end
    end)
end

--------------------------------------------------------------------------------
-- 4. 100% REVERSIBLE STATE RESTORATION
--------------------------------------------------------------------------------

-- Restores every visual and lighting property to exact pre-optimization snapshot
function HighFPSEngine:RestoreOriginalState()
    -- Disconnect dynamic descendant listener immediately
    if self.DescendantAddedConn then
        self.DescendantAddedConn:Disconnect()
        self.DescendantAddedConn = nil
    end

    -- 1. RESTORE LIGHTING
    pcall(function()
        if self.SavedState.Lighting.GlobalShadows ~= nil then
            Lighting.GlobalShadows = self.SavedState.Lighting.GlobalShadows
        end
        if self.SavedState.Lighting.FogEnd ~= nil then
            Lighting.FogEnd = self.SavedState.Lighting.FogEnd
        end
    end)
    self.SavedState.Lighting = {}

    -- 2. RESTORE POST-PROCESSING EFFECTS
    pcall(function()
        for effect, prevEnabled in pairs(self.SavedState.PostEffects) do
            if effect and effect.Parent then
                pcall(function()
                    effect.Enabled = prevEnabled
                end)
            end
        end
    end)
    table.clear(self.SavedState.PostEffects)

    -- 3. RESTORE ATMOSPHERES
    pcall(function()
        for atmosphere, props in pairs(self.SavedState.Atmospheres) do
            if atmosphere and atmosphere.Parent then
                pcall(function()
                    if props.Density ~= nil then atmosphere.Density = props.Density end
                    if props.Haze ~= nil then atmosphere.Haze = props.Haze end
                    if props.Glare ~= nil then atmosphere.Glare = props.Glare end
                end)
            end
        end
    end)
    table.clear(self.SavedState.Atmospheres)

    -- 4. RESTORE PARTICLES & TRAILS
    pcall(function()
        for inst, prevEnabled in pairs(self.SavedState.Particles) do
            if inst and inst.Parent then
                pcall(function()
                    inst.Enabled = prevEnabled
                end)
            end
        end
    end)
    table.clear(self.SavedState.Particles)

    -- 5. RESTORE DYNAMIC LIGHT SHADOWS
    pcall(function()
        for light, prevShadows in pairs(self.SavedState.Lights) do
            if light and light.Parent then
                pcall(function()
                    light.Shadows = prevShadows
                end)
            end
        end
    end)
    table.clear(self.SavedState.Lights)

    -- 6. RESTORE TERRAIN
    pcall(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain and self.SavedState.Terrain then
            if self.SavedState.Terrain.Decoration ~= nil then
                terrain.Decoration = self.SavedState.Terrain.Decoration
            end
            if self.SavedState.Terrain.WaterReflectance ~= nil then
                terrain.WaterReflectance = self.SavedState.Terrain.WaterReflectance
            end
            if self.SavedState.Terrain.WaterWaveSize ~= nil then
                terrain.WaterWaveSize = self.SavedState.Terrain.WaterWaveSize
            end
            if self.SavedState.Terrain.WaterWaveSpeed ~= nil then
                terrain.WaterWaveSpeed = self.SavedState.Terrain.WaterWaveSpeed
            end
        end
    end)
    self.SavedState.Terrain = {}
end

--------------------------------------------------------------------------------
-- 5. ATOMIC UNLOAD & CLEANUP (ZERO MEMORY LEAKS)
--------------------------------------------------------------------------------

function HighFPSEngine:Destroy()
    -- 1. Restore graphics to original non-destructive state
    self:SetEnabled(false)

    -- 2. Disconnect and nil all event listeners
    if self.FpsConnection then
        self.FpsConnection:Disconnect()
        self.FpsConnection = nil
    end

    if self.DescendantAddedConn then
        self.DescendantAddedConn:Disconnect()
        self.DescendantAddedConn = nil
    end

    -- 3. Clear all callback functions
    self.OnFpsUpdated = nil
    self.OnPingUpdated = nil
    self.OnMetricsUpdated = nil

    -- 4. Release all tables and ring buffers
    table.clear(self.DeltaBuffer)
    self.BufferCount = 0
    self.DeltaSum = 0

    -- 5. Clear singleton reference
    _instance = nil
end

-- Unload alias for atomic script lifecycle compliance
HighFPSEngine.Unload = HighFPSEngine.Destroy

return HighFPSEngine
