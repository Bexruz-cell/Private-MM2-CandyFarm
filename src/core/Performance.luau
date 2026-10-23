--!strict
-- Performance.luau: Low-End Android & Delta Executor High FPS Optimization
-- Accurately measures real FPS and disables heavy graphics effects with full state restoration.

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Performance = {
    _3dRendering = true,
    _perfMode = false,
    _savedShadows = true,
    _savedFog = 1000,
    _savedLightingProps = {} :: { [string]: any },
    _disabledEffects = {} :: { [Instance]: boolean },
    _fps = 60.0,
    _frameCount = 0,
    _fpsTimer = 0.0,
}

-- Real FPS calculation using frame timing (independent of display limits)
pcall(function()
    RunService.RenderStepped:Connect(function(dt: number)
        Performance._frameCount += 1
        Performance._fpsTimer += dt
        if Performance._fpsTimer >= 0.5 then
            Performance._fps = math.floor((Performance._frameCount / Performance._fpsTimer) * 10) / 10
            Performance._frameCount = 0
            Performance._fpsTimer = 0.0
        end
    end)
end)

function Performance.GetRealFPS(): number
    return Performance._fps
end

function Performance.Set3DRendering(enabled: boolean)
    Performance._3dRendering = enabled
    pcall(function()
        RunService:Set3dRenderingEnabled(enabled)
    end)
end

-- High FPS Mode: strips particle emitters, shadows, and post-processing while saving originals
function Performance.SetPerformanceMode(enabled: boolean)
    Performance._perfMode = enabled

    pcall(function()
        if enabled then
            -- Save lighting configuration
            Performance._savedShadows = Lighting.GlobalShadows
            Performance._savedFog = Lighting.FogEnd
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9

            -- Save and disable heavy post-processing effects in Lighting
            for _, child in ipairs(Lighting:GetChildren()) do
                if child:IsA("BloomEffect") or child:IsA("SunRaysEffect") or child:IsA("ColorCorrectionEffect") or child:IsA("DepthOfFieldEffect") or child:IsA("BlurEffect") then
                    if child.Enabled then
                        Performance._disabledEffects[child] = true
                        child.Enabled = false
                    end
                end
            end

            -- Disable heavy particle emitters and decals in workspace, excluding MM2 coin containers
            for _, obj in ipairs(Workspace:GetDescendants()) do
                -- NEVER touch coin containers or active candy models
                if obj.Name ~= "CoinContainer" and not obj:FindFirstChild("TouchInterest") and not obj:FindFirstChildWhichIsA("TouchTransmitter") then
                    if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                        if obj.Enabled then
                            Performance._disabledEffects[obj] = true
                            obj.Enabled = false
                        end
                    end
                end
            end
        else
            -- Restore original lighting
            Lighting.GlobalShadows = Performance._savedShadows
            Lighting.FogEnd = Performance._savedFog

            -- Restore all modified particle and post-processing effects
            for effect, wasEnabled in pairs(Performance._disabledEffects) do
                if effect and effect.Parent and wasEnabled then
                    pcall(function()
                        (effect :: any).Enabled = true
                    end)
                end
            end
            table.clear(Performance._disabledEffects)
        end
    end)
end

function Performance.IsPerformanceMode(): boolean
    return Performance._perfMode
end

return Performance
