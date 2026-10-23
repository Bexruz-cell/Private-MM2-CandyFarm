--!strict
-- Movement.luau: Continuous Frame-Rate-Independent Movement & Reliable Candy Pickup
-- Mimics natural player traversal with RunService.Heartbeat interpolation, zero velocity spikes,
-- pre-physics noclip on Stepped, and observable tri-signal collection confirmation.

local RunService = game:GetService("RunService")
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

local function RefreshColliders(char: Model)
    table.clear(Movement._cachedColliders)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(Movement._cachedColliders, part)
        end
    end
end

-- Pre-physics collision override on Stepped (before PGS physics solver evaluates penetration)
local function ApplyNoclip()
    if not Movement.NoclipEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end

    for _, part in ipairs(Movement._cachedColliders) do
        if part and part.Parent and part.CanCollide then
            part.CanCollide = false
        end
    end

    local humanoid = char:FindFirstChildWhichIsA("Humanoid")
    if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end

    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

function Movement.SetNoclip(enabled: boolean)
    Movement.NoclipEnabled = enabled
    if enabled then
        if not Movement._noclipConnection then
            local char = LocalPlayer.Character
            if char then RefreshColliders(char) end
            Movement._noclipConnection = RunService.Stepped:Connect(ApplyNoclip)
        end
    else
        if Movement._noclipConnection then
            Movement._noclipConnection:Disconnect()
            Movement._noclipConnection = nil
        end
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and (part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "Head") then
                    part.CanCollide = true
                end
            end
            local humanoid = char:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end
end

-- Fire touch interest if executor supports it across multiple character limbs
function Movement.TouchTarget(char: Model, hrp: BasePart, targetPart: BasePart)
    local fireTouch = (getgenv and getgenv().firetouchinterest) or (_G and _G.firetouchinterest)
    if type(fireTouch) == "function" then
        pcall(function()
            fireTouch(hrp, targetPart, 0)
            fireTouch(hrp, targetPart, 1)

            local innerVisual = targetPart:FindFirstChild("CoinVisual")
            if innerVisual and innerVisual:IsA("BasePart") then
                fireTouch(hrp, innerVisual, 0)
                fireTouch(hrp, innerVisual, 1)
            end

            local leftLeg = char:FindFirstChild("LeftLeg") or char:FindFirstChild("LeftLowerLeg")
            if leftLeg and leftLeg:IsA("BasePart") then
                fireTouch(leftLeg, targetPart, 0)
                fireTouch(leftLeg, targetPart, 1)
            end

            local rightLeg = char:FindFirstChild("RightLeg") or char:FindFirstChild("RightLowerLeg")
            if rightLeg and rightLeg:IsA("BasePart") then
                fireTouch(rightLeg, targetPart, 0)
                fireTouch(rightLeg, targetPart, 1)
            end
        end)
    end
end

-- Check if candy was observably collected by MM2 game engine
function Movement.IsCoinCollected(targetPart: Instance): boolean
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

-- Cancel any active movement immediately, zero velocities, and restore physics
function Movement.Cancel()
    Movement.IsMoving = false

    if Movement._heartbeatConnection then
        Movement._heartbeatConnection:Disconnect()
        Movement._heartbeatConnection = nil
    end

    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        local humanoid = char:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
    end
end

-- Micro-nudge perturbation to force touch overlap if coin event didn't trigger
function Movement.MicroNudge(amplitude: number?)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end

    local amp = amplitude or 0.35
    local originalCFrame = hrp.CFrame
    hrp.CFrame = originalCFrame + Vector3.new(0, amp, 0)
    task.wait(0.04)
    if hrp and hrp.Parent then
        hrp.CFrame = originalCFrame
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end

-- Continuous frame-rate-independent movement toward target and verify observable collection
function Movement.MoveToAndCollect(
    targetPart: BasePart,
    speed: number,
    method: string?,
    isRoundActiveFn: (() -> boolean)?
): (boolean, string)
    Movement.Cancel()

    -- Fail-closed check: abort if round not active
    if isRoundActiveFn and not isRoundActiveFn() then
        return false, "Ожидание раунда"
    end

    local char = LocalPlayer.Character
    if not char then return false, "Ошибка" end

    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = char:FindFirstChildWhichIsA("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then return false, "Ошибка" end

    if not targetPart or not targetPart.Parent then
        return false, "Цель недоступна"
    end

    local targetPos = targetPart.Position
    local startPos = hrp.Position
    local distance = (targetPos - startPos).Magnitude

    local effectiveSpeed = math.clamp(speed or 28, 12, 45)
    local duration = distance / effectiveSpeed
    local maxAllowedTime = duration + 1.5

    Movement.IsMoving = true
    RefreshColliders(char)

    -- Continuous frame-rate-independent navigation loop (Heartbeat)
    local startTime = os.clock()
    local lastPos = hrp.Position
    local lastMoveCheck = startTime
    local arrived = false

    local movePromise = coroutine.running()

    Movement._heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
        if not Movement.IsMoving then
            if Movement._heartbeatConnection then
                Movement._heartbeatConnection:Disconnect()
                Movement._heartbeatConnection = nil
            end
            return
        end

        -- Check round state continuously
        if isRoundActiveFn and not isRoundActiveFn() then
            Movement.Cancel()
            coroutine.resume(movePromise, false, "Ожидание раунда")
            return
        end

        -- Check target validity mid-flight
        if not targetPart or not targetPart.Parent then
            Movement.Cancel()
            coroutine.resume(movePromise, false, "Цель недоступна")
            return
        end

        local curHrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not curHrp then
            Movement.Cancel()
            coroutine.resume(movePromise, false, "Ошибка")
            return
        end

        local curPos = curHrp.Position
        local delta = targetPart.Position - curPos
        local dist = delta.Magnitude

        -- Arrival condition (< 0.8 studs)
        if dist <= 0.8 then
            arrived = true
            curHrp.CFrame = targetPart.CFrame
            curHrp.AssemblyLinearVelocity = Vector3.zero
            curHrp.AssemblyAngularVelocity = Vector3.zero
            Movement.Cancel()
            coroutine.resume(movePromise, true, "Достигнуто")
            return
        end

        -- Timeout check
        local now = os.clock()
        if (now - startTime) > maxAllowedTime then
            Movement.Cancel()
            coroutine.resume(movePromise, false, "Таймаут движения")
            return
        end

        -- Anti-stuck progress check
        if (now - lastMoveCheck) > 0.8 then
            local moved = (curPos - lastPos).Magnitude
            if moved < 0.8 and dist > 2.5 then
                Movement.Cancel()
                coroutine.resume(movePromise, false, "Застревание")
                return
            end
            lastPos = curPos
            lastMoveCheck = now
        end

        -- Frame-rate independent step integration: step = Speed * dt
        local stepDist = math.min(effectiveSpeed * dt, dist)
        local moveDir = delta.Unit
        local nextPos = curPos + (moveDir * stepDist)

        -- Face naturally in movement direction on horizontal plane
        local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z)
        local nextCFrame: CFrame
        if flatDir.Magnitude > 0.001 then
            nextCFrame = CFrame.lookAlong(nextPos, flatDir.Unit, Vector3.yAxis)
        else
            nextCFrame = CFrame.new(nextPos)
        end

        curHrp.CFrame = nextCFrame
        curHrp.AssemblyLinearVelocity = Vector3.zero
        curHrp.AssemblyAngularVelocity = Vector3.zero
    end)

    local navSuccess, navReason = coroutine.yield()
    if not navSuccess then
        return false, navReason or "Ошибка навигации"
    end

    -- 2. Execute verified pickup interaction
    -- Position character directly overlapping the coin CFrame
    hrp.CFrame = targetPart.CFrame
    Movement.TouchTarget(char, hrp, targetPart)

    -- Ultra-fast observable collection check (check every 0.02s up to 0.12s)
    local waitStart = os.clock()
    while (os.clock() - waitStart) < 0.12 do
        if Movement.IsCoinCollected(targetPart) then
            return true, "Собираю конфеты"
        end
        task.wait(0.02)
    end

    -- 3. Retry with micro-nudge if not yet collected (quick 0.08s jolt)
    if not Movement.IsCoinCollected(targetPart) then
        Movement.MicroNudge(0.35)
        Movement.TouchTarget(char, hrp, targetPart)
        local retryStart = os.clock()
        while (os.clock() - retryStart) < 0.08 do
            if Movement.IsCoinCollected(targetPart) then
                return true, "Собираю конфеты"
            end
            task.wait(0.02)
        end
    end

    if Movement.IsCoinCollected(targetPart) then
        return true, "Собираю конфеты"
    else
        return false, "Конфета не подобрана"
    end
end

-- Backwards-compatible MoveTo alias
function Movement.MoveTo(
    target: BasePart | Vector3,
    speed: number,
    method: string?,
    isRoundActiveFn: (() -> boolean)?
): (boolean, string)
    if typeof(target) == "Vector3" then
        local char = LocalPlayer.Character
        if not char then return false, "Ошибка" end
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not hrp then return false, "Ошибка" end
        hrp.CFrame = CFrame.new(target)
        return true, "Перемещено"
    else
        return Movement.MoveToAndCollect(target, speed, method, isRoundActiveFn)
    end
end

-- Respawn handling
LocalPlayer.CharacterAdded:Connect(function(char)
    Movement.Cancel()
    RefreshColliders(char)
    char.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            table.insert(Movement._cachedColliders, descendant)
        end
    end)
end)

if LocalPlayer.Character then
    RefreshColliders(LocalPlayer.Character)
end

return Movement
