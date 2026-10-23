--!strict
-- AntiAFK.luau: Safe Anti-AFK Disabler
-- Prevents Roblox 20-minute idle disconnection on both mobile and desktop

local Players = game:GetService("Players")
local VirtualUser = nil

pcall(function()
    VirtualUser = game:GetService("VirtualUser")
end)

local AntiAFK = {
    _enabled = false,
    _connection = nil :: RBXScriptConnection?,
}

function AntiAFK.Enable()
    if AntiAFK._enabled then return end
    AntiAFK._enabled = true

    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end

    -- Strategy 1: Executor getconnections / get_signal_cons
    local success = false
    local getCons = (getgenv and (getgenv().getconnections or getgenv().get_signal_cons)) or (_G and (_G.getconnections or _G.get_signal_cons))
    if type(getCons) == "function" then
        pcall(function()
            local cons = getCons(localPlayer.Idled)
            if cons and type(cons) == "table" then
                for _, con in pairs(cons) do
                    if type(con) == "table" and type(con.Disable) == "function" then
                        con:Disable()
                        success = true
                    elseif type(con) == "table" and type(con.Disconnect) == "function" then
                        con:Disconnect()
                        success = true
                    end
                end
            end
        end)
    end

    -- Strategy 2: Fallback to VirtualUser simulated input on Idled event
    if not success and VirtualUser then
        pcall(function()
            AntiAFK._connection = localPlayer.Idled:Connect(function()
                if not AntiAFK._enabled then return end
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end)
        end)
    end
end

function AntiAFK.Disable()
    AntiAFK._enabled = false
    if AntiAFK._connection then
        AntiAFK._connection:Disconnect()
        AntiAFK._connection = nil
    end
end

function AntiAFK.IsEnabled(): boolean
    return AntiAFK._enabled
end

return AntiAFK
