--!strict
-- Movement.luau: Fully Decommissioned Passive Movement Stubs (Zero-Interference Contract)
-- Requirements:
-- 1. The Companion must NEVER modify character physics during normal operation.
-- 2. Never delete movement constraints, body movers, or forces created by RockHub or other scripts.
-- 3. Never alter Humanoid states, collisions (CanCollide), CFrame, or AssemblyLinearVelocity.
-- 4. All movement, navigation, and candy collection are managed exclusively by RockHub.

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

-- Safe No-Op: Never modifies limb collisions or Humanoid states
function Movement.SetNoclip(enabled: boolean)
    Movement.NoclipEnabled = false
end

-- Safe No-Op: Never deletes constraints or alters character velocities/states
-- RockHub manages its own legitimate movement movers (LinearVelocity, AlignPosition, etc.)
function Movement.RestoreCharacterPhysics()
    -- Zero-Interference Contract: Intentionally No-Op
end

-- Safe No-Op: Never alters CFrame or touches physical instances
function Movement.TouchTarget(char: Model, hrp: BasePart, targetPart: BasePart)
    -- Intentionally No-Op
end

-- Observably check if a candy is collected by MM2 game engine (read-only)
function Movement.IsCoinCollected(targetPart: Instance?): boolean
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

-- Cancels any legacy companion connections without touching character properties
function Movement.Cancel()
    Movement.IsMoving = false
    if Movement._heartbeatConnection then
        Movement._heartbeatConnection:Disconnect()
        Movement._heartbeatConnection = nil
    end
    if Movement._noclipConnection then
        Movement._noclipConnection:Disconnect()
        Movement._noclipConnection = nil
    end
end

-- Safe No-Op: Never nudges or teleports character
function Movement.MicroNudge(amplitude: number?)
    -- Zero-Interference Contract: Intentionally No-Op
end

-- Decommissioned: Active continuous movement and candy collection are handled exclusively by RockHub.
-- Safe stubs guarantee zero movement race conditions, zero physics fighting, and zero floor clipping.
function Movement.MoveToAndCollect(
    targetPart: (BasePart | Instance)?,
    speed: number?,
    method: string?,
    isRoundActiveFn: (() -> boolean)?
): (boolean, string)
    Movement.Cancel()
    return false, "Декоммиссовано: управление движением передано RockHub"
end

-- Backwards-compatible MoveTo alias
function Movement.MoveTo(
    target: (BasePart | Vector3 | Instance)?,
    speed: number?,
    method: string?,
    isRoundActiveFn: (() -> boolean)?
): (boolean, string)
    Movement.Cancel()
    return false, "Декоммиссовано: управление движением передано RockHub"
end

return Movement
