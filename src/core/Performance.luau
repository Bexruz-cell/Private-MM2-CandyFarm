--!strict
-- Performance.luau: Low-End Android & Delta Executor Optimization
-- Controls 3D rendering toggles, particle stripping, and FPS booster

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Performance = {
    _3dRendering = true,
    _perfMode = false,
    _originalShadows = true,
    _originalFog = 1000,
}

function Performance.Set3DRendering(enabled: boolean)
    Performance._3dRendering = enabled
    pcall(function()
        RunService:Set3dRenderingEnabled(enabled)
    end)
end

function Performance.SetPerformanceMode(enabled: boolean)
    Performance._perfMode = enabled

    pcall(function()
        if enabled then
            Performance._originalShadows = Lighting.GlobalShadows
            Performance._originalFog = Lighting.FogEnd

            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9

            -- Disable heavy decals and particles in workspace
            for _, obj in ipairs(game:GetService("Workspace"):GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                end
            end
        else
            Lighting.GlobalShadows = Performance._originalShadows
            Lighting.FogEnd = Performance._originalFog

            for _, obj in ipairs(game:GetService("Workspace"):GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = true
                end
            end
        end
    end)
end

function Performance.IsPerformanceMode(): boolean
    return Performance._perfMode
end

return Performance
