                    stats.lastRespawn = tick()
                end
            end
        end
    end
end

local function setupConnectionWatcher()
    -- Monitor for disconnection via prompt
    pcall(function()
        game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then
                log("Game crashed with error prompt - Attempting to reconnect", "CRITICAL")
                
                -- Try to save logs before reconnecting
                pcall(function()
                    writefile(config.logFile, httpService:JSONEncode(crashLog))
                end)
                
                task.wait(5)
                pcall(function()
                    teleportService:Teleport(game.PlaceId)
                end)
            end
        end)
    end)
    
    -- Regular connection check
    task.spawn(function()
        while true do
            task.wait(config.checkFrequency.connection)
            
            -- Check if we're still connected properly
            if not game:IsLoaded() or not localPlayer or not localPlayer.Parent then
                log("Connection issues detected - Preparing to reconnect", "CRITICAL")
                
                -- Try to save logs before reconnecting
                pcall(function()
                    writefile(config.logFile, httpService:JSONEncode(crashLog))
                end)
                
                task.wait(5)
                pcall(function()
                    teleportService:Teleport(game.PlaceId)
                end)
            end
        end
    end)
end

-- Setup crash prevention and diagnostics commands
local function setupCommands()
    pcall(function()
        local function createCommand(cmdName, callback)
            if replicatedStorage:FindFirstChild("CrashPreventionCommands") then return end
            
            local cmdFolder = Instance.new("Folder")
            cmdFolder.Name = "CrashPreventionCommands"
            cmdFolder.Parent = replicatedStorage
            
            local cmd = Instance.new("RemoteEvent")
            cmd.Name = cmdName
            cmd.Parent = cmdFolder
            cmd.OnServerEvent:Connect(callback)
        end
        
        -- Status command
        createCommand("GetStatus", function()
            local status = {
                memory = getCurrentMemory(),
                fps = getCurrentFPS(),
                performanceMode = stats.performanceMode,
                emergencyMode = stats.emergencyMode,
                recoveryAttempts = stats.recoveryAttempts,
                freezeCount = stats.freezeCount
            }
            return status
        end)
        
        -- Force cleanup command
        createCommand("ForceCleanup", function(level)
            safeCollectGarbage(level or 2)
        end)
    end)
end

-- Setup optimization recommendations
local function optimizeOnStartup()
    pcall(function()
        -- Start with reasonable graphics settings
        if settings().Rendering.QualityLevel > 8 then
            settings().Rendering.QualityLevel = 8
            log("Reduced initial graphics quality for stability")
        end
        
        -- Get initial memory baseline
        local initialMem = getCurrentMemory()
        for i = 1, #stats.memoryHistory do
            stats.memoryHistory[i] = initialMem
        end
        
        log("Initial memory: " .. string.format("%.1fMB", initialMem))
        
        -- Initial garbage collection
        safeCollectGarbage(1)
    end)
end

-- Heartbeat tracker for freeze detection
runService.Heartbeat:Connect(function()
    lastHeartbeat = tick()
end)

-- Start all monitoring functions
log("Crash Prevention Ultimate loaded - Version 2.0")
optimizeOnStartup()
task.spawn(monitorMemory)
task.spawn(monitorFreeze)
task.spawn(monitorPlayer)
setupConnectionWatcher()
setupCommands()
monitorFPS() -- This one uses RenderStepped directly

-- Apply initial performance setting based on device capabilities
task.spawn(function()
    task.wait(5) -- Wait for game to stabilize
    local initialFPS = getCurrentFPS()
    local initialMemory = getCurrentMemory()
    
    log(string.format("Initial system check - FPS: %.1f, Memory: %.1fMB", initialFPS, initialMemory))
    
    -- Auto-adjust based on initial performance
    if initialFPS < config.fpsThreshold or initialMemory > config.warningMemoryThreshold then
        setPerformanceMode(1)
        log("Auto-adjusted to Reduced mode based on initial performance")
    end
end)

log("Crash Prevention Ultimate ready - You're protected!")

return {
    getCurrentMemory = getCurrentMemory,
    getCurrentFPS = getCurrentFPS,
    forceCleanup = safeCollectGarbage,
    setPerformanceMode = setPerformanceMode,
    enterEmergencyMode = enterEmergencyMode
}
