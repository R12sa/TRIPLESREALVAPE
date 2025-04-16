-- Triple's Anti-Crash
-- Updated on 4/6/25
-- Prevents game crashes and memory leaks

local AntiCrash = {}
local OriginalFunctions = {}
local ProtectedInstances = {}
local ErrorCount = 0
local LastErrorTime = 0
local MaxErrorsPerMinute = 30
local IsEnabled = true
local MemoryThreshold = 1800000000
local LastMemoryCheck = 0
local MemoryCheckInterval = 5
local Executor = identifyexecutor and identifyexecutor() or "Unknown"

-- Helper functions
local function SafePcall(fn, ...)
    local s, r = pcall(fn, ...)
    return s and r or nil
end

local function HookMethod(instance, methodName, customFunction)
    if not instance or typeof(instance) ~= "Instance" then return end
    
    if not OriginalFunctions[instance] then 
        OriginalFunctions[instance] = {} 
    end
    
    local originalFunction = instance[methodName]
    OriginalFunctions[instance][methodName] = originalFunction
    
    instance[methodName] = function(...)
        local args = {...}
        local success, result = pcall(function() 
            return customFunction(originalFunction, unpack(args)) 
        end)
        
        if not success and IsEnabled then
            ErrorCount = ErrorCount + 1
            if tick() - LastErrorTime > 60 then
                ErrorCount = 1
                LastErrorTime = tick()
            elseif ErrorCount > MaxErrorsPerMinute then
                return nil
            end
        end
        
        return success and result or nil
    end
end

local function ProtectInstance(instance)
    if not instance or typeof(instance) ~= "Instance" or ProtectedInstances[instance] then return end
    
    ProtectedInstances[instance] = true
    
    -- Prevent destruction of critical instances
    HookMethod(instance, "Destroy", function(original, ...)
        if IsEnabled and (instance.ClassName == "Player" or instance.ClassName == "Workspace" or 
                         instance.ClassName == "CoreGui" or instance.ClassName == "Players") then
            return nil
        end
        return original(...)
    end)
    
    -- Prevent removal of critical instances
    HookMethod(instance, "Remove", function(original, ...)
        if IsEnabled and (instance.ClassName == "Player" or instance.ClassName == "Workspace" or 
                         instance.ClassName == "CoreGui" or instance.ClassName == "Players") then
            return nil
        end
        return original(...)
    end)
    
    -- Recursively protect children
    for _, child in pairs(instance:GetChildren()) do 
        ProtectInstance(child) 
    end
    
    -- Protect future children
    instance.ChildAdded:Connect(function(child) 
        ProtectInstance(child) 
    end)
end

local function MonitorMemory()
    if tick() - LastMemoryCheck < MemoryCheckInterval then return end
    
    LastMemoryCheck = tick()
    local memoryUsage = gcinfo() * 1024
    
    if memoryUsage > MemoryThreshold then
        collectgarbage("collect")
    end
end

local function SafeConnect(signal, callback)
    local success, result = pcall(function()
        return signal:Connect(function(...)
            task.spawn(function() 
                pcall(callback, ...) 
            end)
        end)
    end)
    
    return success and result or nil
end

local function SelfHealHooks()
    for instance, methods in pairs(OriginalFunctions) do
        if typeof(instance) == "Instance" and instance:IsDescendantOf(game) then
            for methodName, original in pairs(methods) do
                SafePcall(function()
                    if instance[methodName] ~= original then
                        instance[methodName] = original
                    end
                end)
            end
        end
    end
end

-- Main functionality
function AntiCrash:Enable()
    IsEnabled = true
    
    -- Protect critical services
    local services = {
        game:GetService("Workspace"),
        game:GetService("Players"),
        game:GetService("CoreGui"),
        game:GetService("ReplicatedStorage"),
        game:GetService("RunService"),
        game:GetService("UserInputService"),
        game:GetService("GuiService"),
        game:GetService("Lighting"),
        game:GetService("StarterGui")
    }
    
    for _, service in pairs(services) do 
        ProtectInstance(service) 
    end
    
    -- Hook namecall to prevent remote spam
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        
        if (method == "FireServer" or method == "InvokeServer") and IsEnabled then
            local callCount = self._antiCrashCallCount or 0
            local lastCallTime = self._antiCrashLastCall or 0
            
            if tick() - lastCallTime < 1 then
                callCount = callCount + 1
            else
                callCount = 1
            end
            
            self._antiCrashCallCount = callCount
            self._antiCrashLastCall = tick()
            
            if callCount > 60 then 
                return nil 
            end
        end
        
        return oldNamecall(self, ...)
    end)
    
    setreadonly(mt, true)
    
    -- Hook error function
    local oldError = error
    error = function(...)
        if IsEnabled then
            ErrorCount = ErrorCount + 1
            
            if tick() - LastErrorTime > 60 then
                ErrorCount = 1
                LastErrorTime = tick()
            elseif ErrorCount > MaxErrorsPerMinute then
                return
            end
        end
        
        return oldError(...)
    end
    
    -- Hook assert function
    local oldAssert = assert
    assert = function(cond, ...)
        if not cond and IsEnabled then
            ErrorCount = ErrorCount + 1
            
            if tick() - LastErrorTime > 60 then
                ErrorCount = 1
                LastErrorTime = tick()
            elseif ErrorCount > MaxErrorsPerMinute then
                return true
            end
        end
        
        return oldAssert(cond, ...)
    end
    
    -- Monitor memory usage
    SafeConnect(game:GetService("RunService").Heartbeat, MonitorMemory)
    
    -- Protect RunService connections
    task.spawn(function()
        while IsEnabled do
            pcall(function()
                for _, conn in pairs(getconnections(game:GetService("RunService").Heartbeat)) do
                    if conn.Function and not conn._antiCrashProtected then
                        local originalFunction = conn.Function
                        
                        conn.Function = function(...)
                            local success, result = pcall(function() 
                                return originalFunction(...) 
                            end)
                            
                            return success and result or nil
                        end
                        
                        conn._antiCrashProtected = true
                    end
                end
            end)
            
            SelfHealHooks()
            task.wait(5)
        end
    end)
    
    -- Monitor player scripts for errors
    task.spawn(function()
        while IsEnabled do
            task.wait(1)
            
            pcall(function()
                for _, plr in pairs(game:GetService("Players"):GetPlayers()) do
                    for _, obj in pairs(plr:GetDescendants()) do
                        if (obj:IsA("Script") or obj:IsA("LocalScript")) and not obj._antiCrashProtected then
                            obj._antiCrashProtected = true
                            
                            pcall(function()
                                obj.Error:Connect(function()
                                    if IsEnabled then
                                        ErrorCount = ErrorCount + 1
                                        
                                        if tick() - LastErrorTime > 60 then
                                            ErrorCount = 1
                                            LastErrorTime = tick()
                                        elseif ErrorCount > MaxErrorsPerMinute then
                                            return
                                        end
                                    end
                                end)
                            end)
                        end
                    end
                end
            end)
        end
    end)
    
    -- Notify user
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Triple's Anti-Crash",
            Text = "Protection enabled successfully!",
            Duration = 3
        })
    end)
    
    return true
end

function AntiCrash:Disable()
    IsEnabled = false
    
    -- Restore original functions
    for instance, methods in pairs(OriginalFunctions) do
        if typeof(instance) == "Instance" and instance:IsDescendantOf(game) then
            for methodName, original in pairs(methods) do
                pcall(function()
                    instance[methodName] = original
                end)
            end
        end
    end
    
    OriginalFunctions = {}
    ProtectedInstances = {}
    
    -- Notify user
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Triple's Anti-Crash",
            Text = "Protection disabled",
            Duration = 3
        })
    end)
    
    return true
end

-- Initialize protection
AntiCrash:Enable()

return AntiCrash
