--!strict
-- Movement.luau: Robust MM2 Character Movement & Anti-Stuck Controller
-- Provides TweenService, Step-Lerp, and BodyVelocity flight with safe cancellation

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Movement = {
    ActiveTween = nil :: Tween?,
    ActiveBodyVelocity = nil :: BodyVelocity?,
    ActiveBodyGyro = nil :: BodyGyro?,
    IsMoving = false,
    NoclipEnabled = false,
    _noclipConnection = nil :: RBXScriptConnection?,
    _stuckTimer = 0,
    _lastPosition = Vector3.zero,
}

-- Enable or disable Noclip on the local character
function Movement.SetNoclip(enabled: boolean)
    Movement.NoclipEnabled = enabled
    if enabled then
        if not Movement._noclipConnection then
            Movement._noclipConnection = RunService.Stepped:Connect(function()
                if not Movement.NoclipEnabled then return end
                local char = LocalPlayer.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end
    else
        if Movement._noclipConnection then
            Movement._noclipConnection:Disconnect()
            Movement._noclipConnection = nil
        end
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- Fire touch interest if executor supports it
function Movement.TouchTarget(hrp: BasePart, targetPart: BasePart)
    local fireTouch = (getgenv and getgenv().firetouchinterest) or (_G and _G.firetouchinterest)
    if type(fireTouch) == "function" then
        pcall(function()
            fireTouch(hrp, targetPart, 0)
            task.wait(0.02)
            fireTouch(hrp, targetPart, 1)
        end)
    end
end

-- Cancel any active movement immediately and restore physics
function Movement.Cancel()
    Movement.IsMoving = false

    if Movement.ActiveTween then
        pcall(function()
            Movement.ActiveTween:Cancel()
        end)
        Movement.ActiveTween = nil
    end

    if Movement.ActiveBodyVelocity then
        pcall(function()
            Movement.ActiveBodyVelocity:Destroy()
        end)
        Movement.ActiveBodyVelocity = nil
    end

    if Movement.ActiveBodyGyro then
        pcall(function()
            Movement.ActiveBodyGyro:Destroy()
        end)
        Movement.ActiveBodyGyro = nil
    end

    local char = LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

-- Move to target position using configured method with timeout guard
function Movement.MoveTo(targetPosition: Vector3, speed: number, method: string?, timeoutGuard: number?): boolean
    Movement.Cancel()

    local char = LocalPlayer.Character
    if not char then return false end

    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = char:FindFirstChildWhichIsA("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then return false end

    local startPos = hrp.Position
    local distance = (targetPosition - startPos).Magnitude
    if distance < 1.5 then
        return true
    end

    local effectiveSpeed = math.clamp(speed or 32, 10, 80)
    local duration = distance / effectiveSpeed
    local maxAllowedTime = timeoutGuard or (duration + 1.2)

    Movement.IsMoving = true
    local chosenMethod = method or "Tween"

    if chosenMethod == "Instant" then
        hrp.CFrame = CFrame.new(targetPosition + Vector3.new(0, 1.5, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
        Movement.IsMoving = false
        return true
    end

    -- Method: TweenService
    if chosenMethod == "Tween" then
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        local targetCFrame = CFrame.new(targetPosition + Vector3.new(0, 1.5, 0))
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
        local tw = TweenService:Create(hrp, tweenInfo, { CFrame = targetCFrame })
        Movement.ActiveTween = tw
        tw:Play()

        local startTime = os.clock()
        local lastPos = hrp.Position
        local lastMoveCheck = startTime

        while Movement.IsMoving and tw.PlaybackState == Enum.PlaybackState.Playing do
            task.wait(0.05)
            local now = os.clock()

            -- Timeout guard
            if (now - startTime) > maxAllowedTime then
                Movement.Cancel()
                return false
            end

            -- Anti-stuck watchdog: check if distance moved in last 1.5s is < 1.0 stud
            if (now - lastMoveCheck) > 1.5 then
                local moved = (hrp.Position - lastPos).Magnitude
                if moved < 1.0 and distance > 5.0 then
                    Movement.Cancel()
                    return false
                end
                lastPos = hrp.Position
                lastMoveCheck = now
            end
        end

        Movement.IsMoving = false
        return (tw.PlaybackState == Enum.PlaybackState.Completed)
    end

    -- Method: Step-Lerp (Heartbeat)
    local startTime = os.clock()
    local targetCFrame = CFrame.new(targetPosition + Vector3.new(0, 1.5, 0))
    local completed = false

    while Movement.IsMoving do
        local dt = RunService.Heartbeat:Wait()
        local elapsed = os.clock() - startTime
        local alpha = math.clamp(elapsed / duration, 0, 1)

        char:PivotTo(CFrame.new(startPos:Lerp(targetPosition, alpha)))

        if alpha >= 1 then
            completed = true
            break
        end

        if elapsed > maxAllowedTime then
            Movement.Cancel()
            return false
        end
    end

    Movement.IsMoving = false
    hrp.AssemblyLinearVelocity = Vector3.zero
    return completed
end

return Movement
