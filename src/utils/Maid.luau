--!strict
-- Maid.luau: Connection and Task Lifecycle Manager
-- Ensures zero connection leaks, clean cancellation of tweens and loops

local Maid = {}
Maid.__index = Maid

export type MaidTask = RBXScriptConnection | Instance | (() -> ()) | { Destroy: (any) -> () } | { disconnect: (any) -> () }

function Maid.new()
    local self = setmetatable({
        _tasks = {} :: { [any]: MaidTask },
    }, Maid)
    return self
end

function Maid:GiveTask(taskItem: MaidTask): any
    if not taskItem then return nil end
    local key = #self._tasks + 1
    self._tasks[key] = taskItem
    return key
end

function Maid:GiveNamed(name: string, taskItem: MaidTask)
    if self._tasks[name] then
        self:CleanKey(name)
    end
    self._tasks[name] = taskItem
end

function Maid:CleanKey(key: any)
    local taskItem = self._tasks[key]
    if not taskItem then return end
    self._tasks[key] = nil

    local t = typeof(taskItem)
    if t == "RBXScriptConnection" then
        (taskItem :: RBXScriptConnection):Disconnect()
    elseif t == "Instance" then
        pcall(function()
            (taskItem :: Instance):Destroy()
        end)
    elseif t == "function" then
        pcall(taskItem :: () -> ())
    elseif t == "table" then
        if typeof((taskItem :: any).Destroy) == "function" then
            pcall(function() (taskItem :: any):Destroy() end)
        elseif typeof((taskItem :: any).Disconnect) == "function" then
            pcall(function() (taskItem :: any):Disconnect() end)
        elseif typeof((taskItem :: any).Cancel) == "function" then
            pcall(function() (taskItem :: any):Cancel() end)
        end
    end
end

function Maid:DoCleaning()
    local tasks = self._tasks
    self._tasks = {}

    for key, taskItem in pairs(tasks) do
        local t = typeof(taskItem)
        if t == "RBXScriptConnection" then
            taskItem:Disconnect()
        elseif t == "Instance" then
            pcall(function()
                taskItem:Destroy()
            end)
        elseif t == "function" then
            pcall(taskItem)
        elseif t == "table" then
            if typeof(taskItem.Destroy) == "function" then
                pcall(function() taskItem:Destroy() end)
            elseif typeof(taskItem.Disconnect) == "function" then
                pcall(function() taskItem:Disconnect() end)
            elseif typeof(taskItem.Cancel) == "function" then
                pcall(function() taskItem:Cancel() end)
            end
        end
    end
end

function Maid:Destroy()
    self:DoCleaning()
end

return Maid
