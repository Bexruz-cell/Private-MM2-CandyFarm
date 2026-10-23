--!strict
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

local State = require(script.Parent.Parent.core.State)
local MapManager = require(script.Parent.Parent.core.MapManager)

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
