-- Crash Prevention Pro - Ultimate Edition
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local httpService = game:GetService("HttpService")
local teleportService = game:GetService("TeleportService")
local lighting = game:GetService("Lighting")
local replicatedStorage = game:GetService("ReplicatedStorage")
local starterGui = game:GetService("StarterGui")
local localPlayer = players.LocalPlayer
local lastHeartbeat = tick()
local lastRenderStep = tick()
local crashLog = {}
local config = {
    criticalMemoryThreshold = 400, -- MB - Lower threshold for earlier cleanup
    warningMemoryThreshold = 350, -- MB - Start passive cleanup
    freezeThreshold = 3, -- seconds - Detect freezes faster
    fpsThreshold = 20,
    minAcceptableFps = 10,
    checkFrequency = {
        memory = 3,    -- seconds
        freeze = 1,    -- seconds
        player = 4,    -- seconds
        connection = 8 -- seconds
    },
    logFile = "CrashPreventionLog.txt"
}
local stats = {
    fpsDrops = 0,
    memorySpikes = 0,
    freezeCount = 0,
    recoveryAttempts = 0,
    lastRespawn = 0,
    lastMemoryCleanup = 0,
    emergencyMode = false,
    performanceMode = 0, -- 0=normal, 1=reduced, 2=minimum, 3=emergency
    frameTimes = {},
    memoryHistory = {}
}

-- Initialize frame times and memory history
for i = 1, 10 do
    stats.frameTimes[i] = 0
    stats.memoryHistory[i] = 0
end

local function getTimeString()
    return os.date("%X")
end

local function log(message, level)
    level = level or "INFO"
    local logMsg = string.format("[%s] [%s] %s", getTimeString(), level, message)
    table.insert(crashLog, logMsg)
    print("[Crash Prevention] " .. message)
    
    if #crashLog > 100 then
        table.remove(crashLog, 1) -- Remove oldest log to prevent memory bloat
    end
    
    -- Save logs periodically (not on every message)
    if tick() - (stats.lastLogSave or 0) > 30 then
        pcall(function()
            writefile(config.logFile, httpService:JSONEncode(crashLog))
        end)
        stats.lastLogSave = tick()
    end
end

local function notifyUser(title, message, duration)
    pcall(function()
        starterGui:SetCore("SendNotification", {
            Title = title or "Crash Prevention",
            Text = message,
            Duration = duration or 5
        })
    end)
end

local function getCurrentMemory()
    return collectgarbage("count") / 1024
end

local function safeCollectGarbage(aggressiveness)
    -- aggressiveness: 0=normal, 1=enhanced, 2=aggressive, 3=emergency
    if tick() - (stats.lastMemoryCleanup or 0) < 1 then
        return -- Prevent too frequent garbage collection
    end
    
    local memBefore = getCurrentMemory()
    stats.lastMemoryCleanup = tick()
    
    if aggressiveness >= 1 then
        log(string.format("Memory cleanup (level %d) - Before: %.1fMB", aggressiveness, memBefore), 
            aggressiveness >= 2 and "WARNING" or "INFO")
    end
    
    -- Use different cleanup strategies based on aggressiveness
    if aggressiveness == 0 then
        -- Passive collection
        collectgarbage("step", 100)
    elseif aggressiveness == 1 then
        -- Enhanced collection
        collectgarbage("collect")
        task.wait(0.1)
    elseif aggressiveness >= 2 then
        -- Aggressive collection
        for i = 1, 1 + aggressiveness do
            collectgarbage("collect")
            task.wait(0.1)
        end
    end
    
    if aggressiveness >= 1 then
        local memAfter = getCurrentMemory()
        log(string.format("Memory after cleanup: %.1fMB (Freed: %.1fMB)", 
            memAfter, memBefore - memAfter), aggressiveness >= 2 and "WARNING" or "INFO")
    end
end

local function setPerformanceMode(level)
    if stats.performanceMode == level then return end
    stats.performanceMode = level
    
    local modeNames = {"Normal", "Reduced", "Minimum", "Emergency"}
    log("Setting performance mode to: " .. modeNames[level + 1], level >= 2 and "WARNING" or "INFO")
    
    -- Apply graphics settings based on level
    pcall(function()
        -- Graphics quality
        local qualityLevels = {7, 4, 2, 1}
        settings().Rendering.QualityLevel = qualityLevels[level + 1]
        
        -- Shadows
        lighting.GlobalShadows = (level < 2)
        
        -- Graphical effects (particles, trails, etc.)
        if level >= 2 then
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
                    obj.Enabled = false
                end
            end
        end
        
        -- Sound management
        if level >= 3 then
            for _, sound in pairs(workspace:GetDescendants()) do
                if sound:IsA("Sound") and sound.Playing then
                    sound.Playing = false
                end
            end
        end
    end)
    
    if level >= 2 then
        notifyUser("Performance Mode", 
            "Switched to " .. modeNames[level + 1] .. " mode to prevent crashing", 4)
    end
end

local function enterEmergencyMode()
    if stats.emergencyMode then return end
    stats.emergencyMode = true
    stats.recoveryAttempts = stats.recoveryAttempts + 1
    
    log("EMERGENCY MODE ACTIVATED - Taking extreme measures to prevent crash", "CRITICAL")
    setPerformanceMode(3)
    safeCollectGarbage(3)
    
    -- Create a system message
    notifyUser("CRASH PREVENTION", "Emergency mode activated - Taking action to stabilize", 8)
    
    -- Additional emergency measures
    pcall(function()
        -- Unload distant parts
        workspace.StreamingEnabled = true
        
        -- Clear GUIs that might be causing issues
        for _, gui in pairs(localPlayer.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name ~= "CoreGui" and gui.Name ~= "RobloxGui" then
                pcall(function() gui.Enabled = false end)
                task.delay(5, function() 
                    pcall(function() gui.Enabled = true end)
                end)
            end
        end
    end)
    
    -- Schedule recovery from emergency mode
    task.delay(15, function()
        if stats.emergencyMode then
            local currentMem = getCurrentMemory()
            local currentFps = getCurrentFPS()
            
            if currentMem < config.warningMemoryThreshold and currentFps > config.fpsThreshold then
                stats.emergencyMode = false
                setPerformanceMode(1) -- Go to reduced mode rather than normal
                log("Recovered from emergency mode - Memory: " .. currentMem .. "MB, FPS: " .. currentFps)
                notifyUser("Performance Restored", "System has stabilized", 4)
            end
        end
    end)
end

local function updateFrameTimeHistory(deltaTime)
    table.remove(stats.frameTimes, 1)
    table.insert(stats.frameTimes, deltaTime)
end

local function updateMemoryHistory()
    local currentMem = getCurrentMemory()
    table.remove(stats.memoryHistory, 1)
    table.insert(stats.memoryHistory, currentMem)
    return currentMem
end

local function getCurrentFPS()
    local totalTime = 0
    local validFrames = 0
    
    for _, frameTime in ipairs(stats.frameTimes) do
        if frameTime > 0 then
            totalTime = totalTime + frameTime
            validFrames = validFrames + 1
        end
    end
    
    if validFrames == 0 or totalTime == 0 then
        return 60 -- Default if no data
    end
    
    return validFrames / totalTime
end

local function detectMemoryLeak()
    local increases = 0
    for i = 2, #stats.memoryHistory do
        if stats.memoryHistory[i] > stats.memoryHistory[i-1] * 1.05 then
            increases = increases + 1
        end
    end
    return increases >= 7 -- If memory consistently increased in 7+ measurements
end

local function monitorMemory()
    while true do
        task.wait(config.checkFrequency.memory)
        
        local mem = updateMemoryHistory()
        
        -- Check for memory leaks
        if detectMemoryLeak() then
            log("Possible memory leak detected! Memory steadily increasing", "WARNING")
            safeCollectGarbage(2)
        end
        
        -- Normal memory management
        if mem > config.criticalMemoryThreshold then
            stats.memorySpikes = stats.memorySpikes + 1
            log(string.format("High memory usage: %.1fMB", mem), "WARNING")
            
            if stats.memorySpikes >= 2 then
                log("Persistent high memory - Taking action", "WARNING")
                setPerformanceMode(math.min(stats.performanceMode + 1, 3))
                safeCollectGarbage(2)
                
                if mem > config.criticalMemoryThreshold * 1.3 then
                    enterEmergencyMode()
                end
                
                stats.memorySpikes = 0
            end
        elseif mem > config.warningMemoryThreshold then
            safeCollectGarbage(1)
        else
            -- Occasionally do light cleanup even when memory is fine
            if math.random() < 0.3 then
                safeCollectGarbage(0)
            end
            
            -- Gradually reduce memory spike counter
            if stats.memorySpikes > 0 and tick() % 30 < 1 then
                stats.memorySpikes = stats.memorySpikes - 1
            end
        end
    end
end

local function monitorFPS()
    local lastFrame = tick()
    
    runService.RenderStepped:Connect(function()
        local now = tick()
        local deltaTime = now - lastFrame
        lastFrame = now
        lastRenderStep = now
        
        -- Update frame time history
        updateFrameTimeHistory(deltaTime)
        
        -- Check FPS periodically (not every frame)
        if now % 2 < deltaTime then
            local fps = getCurrentFPS()
            
            if fps < config.minAcceptableFps then
                stats.fpsDrops = stats.fpsDrops + 1
                log(string.format("Critical FPS drop: %.1f FPS", fps), "WARNING")
                
                if stats.fpsDrops >= 2 then
                    log("Persistent low FPS - Taking action", "WARNING")
                    
                    -- More aggressive performance mode when FPS is very low
                    local newMode = math.min(stats.performanceMode + 1, 3)
                    setPerformanceMode(newMode)
                    
                    if fps < config.minAcceptableFps * 0.5 then
                        safeCollectGarbage(2)
                    else
                        safeCollectGarbage(1)
                    end
                    
                    stats.fpsDrops = 0
                end
            elseif fps < config.fpsThreshold then
                -- Light action for moderate FPS drops
                if stats.performanceMode == 0 then
                    setPerformanceMode(1)
                end
            else
                -- Good FPS, gradually reduce the counter
                if stats.fpsDrops > 0 and tick() % 20 < 0.1 then
                    stats.fpsDrops = stats.fpsDrops - 1
                end
                
                -- If FPS is good for a while, consider improving graphics
                if stats.performanceMode > 0 and not stats.emergencyMode and tick() % 60 < 0.1 then
                    setPerformanceMode(stats.performanceMode - 1)
                end
            end
        end
    end)
end

local function monitorFreeze()
    while true do
        task.wait(config.checkFrequency.freeze)
        
        local timeSinceHeartbeat = tick() - lastHeartbeat
        local timeSinceRender = tick() - lastRenderStep
        
        -- Check for freezes
        if timeSinceHeartbeat > config.freezeThreshold or timeSinceRender > config.freezeThreshold then
            stats.freezeCount = stats.freezeCount + 1
            log(string.format("Game freeze detected - No updates for %.1f seconds (count: %d)", 
                math.max(timeSinceHeartbeat, timeSinceRender), stats.freezeCount), "WARNING")
            
            -- Force cleanup on any freeze
            safeCollectGarbage(1)
            
            if stats.freezeCount >= 2 then
                log("Multiple freezes detected - Taking emergency action", "CRITICAL")
                enterEmergencyMode()
                stats.freezeCount = 0
            end
        else
            -- Gradually reduce freeze count if no freezes
            if stats.freezeCount > 0 and tick() % 30 < 0.1 then
                stats.freezeCount = stats.freezeCount - 1
            end
        end
    end
end

local function monitorPlayer()
    while true do
        task.wait(config.checkFrequency.player)
        
        -- Check if local player exists
        if not players.LocalPlayer then
            log("Local player is missing, possible issue", "WARNING")
            task.wait(1)
            if not players.LocalPlayer then
                log("Local player still missing, attempting recovery", "CRITICAL")
                safeCollectGarbage(2)
            end
        else
            -- Update local player reference in case it changed
            localPlayer = players.LocalPlayer
        end
        
        -- Check character state
        if localPlayer then
            if localPlayer.Character then
                stats.lastRespawn = tick()
            elseif tick() - stats.lastRespawn > 15 then
                log("Character missing when it should exist - Possible respawn issue", "WARNING")
                
                -- Try to force respawn if character is missing for too long
                if tick() - stats.lastRespawn > 30 then
                    log("Attempting to force respawn", "WARNING")
                    pcall(function()
                        localPlayer:LoadCharacter()
                    end)
                    stats.lastRespawn = tick()
                end
            end
        end
    end
end

local function setupConnectionWatcher()
    -- Monitor for disconnection via prompt
    pcall(function()
        -- Watch for error prompts that appear when the game crashes
        local success, errorPromptConnection = pcall(function()
            local coreGui = game:GetService("CoreGui")
            if coreGui and coreGui:FindFirstChild("RobloxPromptGui") then
                local promptOverlay = coreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
                if promptOverlay then
                    return promptOverlay.ChildAdded:Connect(function(child)
                        if child.Name == "ErrorPrompt" then
                            log("Game crashed with error prompt - Attempting to reconnect", "CRITICAL")
                            
                            -- Try to save logs before reconnecting
                            pcall(function()
                                writefile(config.logFile, httpService:JSONEncode(crashLog))
                            end)
                            
                            -- Wait a moment before attempting to teleport
                            task.wait(5)
                            pcall(function()
                                teleportService:Teleport(game.PlaceId)
                            end)
                        end
                    end)
                end
            end
            return nil
        end)
        
        -- Regular connection check in a separate thread
        task.spawn(function()
            while true do
                task.wait(config.checkFrequency.connection)
                
                -- Check if we're still connected properly
                local connectionOK = pcall(function()
                    return game:IsLoaded() and 
                           players.LocalPlayer and 
                           players.LocalPlayer.Parent ~= nil and
                           game:GetService("RunService"):IsRunning()
                end)
                
                if not connectionOK then
                    log("Connection issues detected - Preparing to reconnect", "CRITICAL")
                    
                    -- Try to save logs before reconnecting
                    pcall(function()
                        writefile(config.logFile, httpService:JSONEncode(crashLog))
                    end)
                    
                    -- Wait a moment before attempting to teleport
                    task.wait(5)
                    pcall(function()
                        teleportService:Teleport(game.PlaceId)
                    end)
                end
            end
        end)
        
        -- Monitor ping for network stability
        task.spawn(function()
            local Stats = game:GetService("Stats")
            local lastPingCheck = tick()
            local highPingCount = 0
            
            while true do
                task.wait(2)
                
                pcall(function()
                    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
                    
                    if ping > 2000 then -- Very high ping (2 seconds)
                        highPingCount = highPingCount + 1
                        
                        if highPingCount >= 3 then
                            log("Network instability detected - High ping for extended period", "WARNING")
                            highPingCount = 0
                            
                            -- Force a lighter cleanup to help with network issues
                            safeCollectGarbage(1)
                        end
                    else
                        highPingCount = math.max(0, highPingCount - 1)
                    end
                    
                    -- Log extreme ping spikes
                    if ping > 5000 then
                        log("Extreme ping spike detected: " .. tostring(math.floor(ping)) .. "ms", "WARNING")
                    end
                end)
            end
        end)
    end)
end
