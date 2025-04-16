-- Triple's Anti-Crash v2
-- Updated on 4/6/25
-- Lightweight crash prevention

local AntiCrash = {}
local IsEnabled = false
local ProtectedRemotes = {}
local RemoteCallCounts = {}
local LastCleanup = tick()
local LastMemoryCheck = tick()
local ErrorCount = 0
local LastErrorTime = 0

-- Configuration
local MAX_REMOTE_CALLS_PER_SECOND = 50
local MEMORY_CHECK_INTERVAL = 10
local MEMORY_THRESHOLD = 1500000 -- in KB
local MAX_ERRORS_PER_MINUTE = 30

-- Safely execute a function
local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    return success and result or nil
end

-- Monitor and limit remote calls
local function SetupRemoteProtection()
    local oldNamecall
    
    -- Only set up if we haven't already
    if not getgenv().AntiCrashNamecallHooked then
        getgenv().AntiCrashNamecallHooked = true
        
        -- Hook namecall method
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            -- Only monitor FireServer and InvokeServer
            if (method == "FireServer" or method == "InvokeServer") and IsEnabled then
                local remotePath = tostring(self)
                local currentTime = tick()
                
                -- Initialize tracking for this remote if needed
                if not RemoteCallCounts[remotePath] then
                    RemoteCallCounts[remotePath] = {
                        count = 0,
                        lastReset = currentTime
                    }
                end
                
                local remoteData = RemoteCallCounts[remotePath]
                
                -- Reset counter if it's been more than a second
                if currentTime - remoteData.lastReset >= 1 then
                    remoteData.count = 0
                    remoteData.lastReset = currentTime
                end
                
                -- Increment call count
                remoteData.count = remoteData.count + 1
                
                -- Block if too many calls
                if remoteData.count > MAX_REMOTE_CALLS_PER_SECOND then
                    return nil
                end
            end
            
            -- Call original method
            return oldNamecall(self, ...)
        end)
    end
end

-- Monitor memory usage and clean up if needed
local function MonitorMemory()
    local currentTime = tick()
    
    -- Only check periodically
    if currentTime - LastMemoryCheck < MEMORY_CHECK_INTERVAL then
        return
    end
    
    LastMemoryCheck = currentTime
    local memoryUsage = gcinfo() -- in KB
    
    -- Force garbage collection if memory usage is too high
    if memoryUsage > MEMORY_THRESHOLD then
        collectgarbage("collect")
    end
end

-- Protect critical instances from being destroyed
local function ProtectCriticalInstances()
    local criticalInstances = {
        game:GetService("Players"),
        game:GetService("Workspace"),
        game:GetService("CoreGui"),
        game:GetService("ReplicatedStorage")
    }
    
    for _, instance in pairs(criticalInstances) do
        -- Use property changed signal to detect and prevent destruction
        instance.Changed:Connect(function(property)
            if property == "Parent" and instance.Parent == nil and IsEnabled then
                -- Try to restore the instance
                SafeCall(function()
                    instance.Parent = game
                end)
            end
        end)
    end
end

-- Override error function to prevent script termination from excessive errors
local function SetupErrorHandling()
    -- Store original functions
    local originalError = error
    local originalAssert = assert
    
    -- Override error
    error = function(message, level)
        if IsEnabled then
            ErrorCount = ErrorCount + 1
            local currentTime = tick()
            
            -- Reset error count if it's been more than a minute
            if currentTime - LastErrorTime > 60 then
                ErrorCount = 1
                LastErrorTime = currentTime
            end
            
            -- If too many errors, suppress them
            if ErrorCount > MAX_ERRORS_PER_MINUTE then
                return
            end
        end
        
        -- Call original error function
        return originalError(message, level)
    end
    
    -- Override assert
    assert = function(condition, message, ...)
        if not condition and IsEnabled then
            ErrorCount = ErrorCount + 1
            local currentTime = tick()
            
            -- Reset error count if it's been more than a minute
            if currentTime - LastErrorTime > 60 then
                ErrorCount = 1
                LastErrorTime = currentTime
            end
            
            -- If too many errors, make assert pass
            if ErrorCount > MAX_ERRORS_PER_MINUTE then
                return true
            end
        end
        
        -- Call original assert function
        return originalAssert(condition, message, ...)
    end
end

-- Main enable function
function AntiCrash:Enable()
    -- Don't re-enable if already enabled
    if IsEnabled then return end
    
    IsEnabled = true
    
    -- Set up protections
    SafeCall(SetupRemoteProtection)
    SafeCall(ProtectCriticalInstances)
    SafeCall(SetupErrorHandling)
    
    -- Set up periodic memory monitoring
    SafeCall(function()
        game:GetService("RunService").Heartbeat:Connect(function()
            if IsEnabled then
                MonitorMemory()
            end
        end)
    end)
    
    -- Notify user
    SafeCall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Triple's Anti-Crash",
            Text = "Protection enabled",
            Duration = 3
        })
    end)
    
    return true
end

-- Main disable function
function AntiCrash:Disable()
    IsEnabled = false
    
    -- Clear tracking data
    RemoteCallCounts = {}
    ErrorCount = 0
    
    -- Force garbage collection
    collectgarbage("collect")
    
    -- Notify user
    SafeCall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Triple's Anti-Crash",
            Text = "Protection disabled",
            Duration = 3
        })
    end)
    
    return true
end

-- Initialize
AntiCrash:Enable()

return AntiCrash
