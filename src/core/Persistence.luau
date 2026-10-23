--!strict
-- Persistence.luau: Local Settings & Position Persistence for Delta Executor
-- Safely saves and loads JSON config using readfile/writefile when available

local HttpService = game:GetService("HttpService")

local CONFIG_FILE = "PrivateMM2_CandyFarm_Config.json"

local Persistence = {}

function Persistence.IsSupported(): boolean
    local hasWrite = (getgenv and getgenv().writefile) or (_G and _G.writefile)
    local hasRead = (getgenv and getgenv().readfile) or (_G and _G.readfile)
    return (type(hasWrite) == "function" and type(hasRead) == "function")
end

function Persistence.Save(settingsTable: { [string]: any }): boolean
    if not Persistence.IsSupported() then return false end
    local write = (getgenv and getgenv().writefile) or (_G and _G.writefile)
    return pcall(function()
        local json = HttpService:JSONEncode(settingsTable)
        write(CONFIG_FILE, json)
    end)
end

function Persistence.Load(): { [string]: any }?
    if not Persistence.IsSupported() then return nil end
    local read = (getgenv and getgenv().readfile) or (_G and _G.readfile)
    local isFile = (getgenv and getgenv().isfile) or (_G and _G.isfile)

    if type(isFile) == "function" and not isFile(CONFIG_FILE) then
        return nil
    end

    local success, content = pcall(function()
        return read(CONFIG_FILE)
    end)

    if success and content and #content > 0 then
        local decodeOk, data = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if decodeOk and type(data) == "table" then
            return data
        end
    end

    return nil
end

return Persistence
