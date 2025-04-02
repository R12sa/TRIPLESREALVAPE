-- Advanced Crash Prevention System v2.0
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local httpService = game:GetService("HttpService")
local teleportService = game:GetService("TeleportService")
local lighting = game:GetService("Lighting")
local physicsService = game:GetService("PhysicsService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = players.LocalPlayer

-- Configuration
local config = {
    memoryThresholds = {
        warning = 400,      -- MB - Show warning
        critical = 600,     -- MB - Force cleanup
        extreme = 800       -- MB - Emergency measures
    },
    fps = {
        lowThreshold = 20,  -- FPS below this triggers warnings
        criticalThreshold = 10, -- FPS below this triggers emergency measures
        sampleSize = 10     -- Number of samples to average
    },
    freezeThresholds = {
        warning = 2,        -- Seconds without heartbeat
        critical = 4,       -- Seconds - More aggressive measures
        emergency = 6       -- Seconds - Emergency measures
    },
    autoReconnect = true,   -- Attempt to reconnect on crash
    logToFile = true,       -- Save logs to file
    optimizeRendering = true, -- Apply rendering optimizations
    cleanupInterval = 30,   -- Seconds between routine cleanups
    emergencyMode = false   -- Starts in normal mode
}

-- State tracking
local state = {
    lastHeartbeat = tick(),
    lastRender = tick(),
    fpsHistory = {},
    freezeCount = 0,
    memorySpikes = 0,
    crashLog = {},
    startTime = tick(),
    emergencyModeActivated = false,
    originalGraphicsQuality = UserSettings():GetService("UserGameSettings").SavedQualityLevel,
    originalRenderDistance = workspace.StreamingMinRadius
}

-- Performance monitoring
local performance = {
    currentFPS = 60,
    averageFPS = 60,
    currentMemory = 0,
    peakMemory = 0,
    freezeTime = 0,
    lastCleanup = 0
}

-- Utility functions
local function formatMemory(mem)
    return string.format("%.2f MB", mem)
end

local function getTimestamp()
    return os.date("%H:%M:%S")
end

local function getUptime()
    return string.format("%.2f minutes", (tick() - state.startTime) / 60)
end

local function log(level, message)
    local levels = {
        INFO = "INFO",
        WARN = "WARNING",
        ERROR = "ERROR",
        CRITICAL = "CRITICAL"
    }
    
    local prefix = "[" .. getTimestamp() .. "][" .. (levels[level] or "INFO") .. "]"
    local fullMessage = prefix .. " " .. message
    
    table.insert(state.crashLog, fullMessage)
    print("[CrashGuard] " .. fullMessage)
    
    -- Show in-game notification for warnings and above
    if level ~= "INFO" then
        game.StarterGui:SetCore("SendNotification", {
            Title = "CrashGuard " .. level,
            Text = message,
            Duration = level == "CRITICAL" and 10 or 5
        })
    end
    
    -- Save logs to file
    if config.logToFile then
        pcall(function()
            writefile("CrashGuard_Log.txt", table.concat(state.crashLog, "\n"))
        end)
    end
end

-- Memory management functions
local function getMemoryUsage()
    return collectgarbage("count") / 1024
end

local function cleanMemory(aggressive)
    local before = getMemoryUsage()
    
    -- Basic cleanup
    collectgarbage()
    
    if aggressive then
        -- More aggressive cleanup
        for i = 1, 3 do
            collectgarbage()
            task.wait(0.1)
        end
        
        -- Clear caches
        game:GetService("ContentProvider"):PreloadAsync({}) -- Reset content cache
        
        -- Clear unused assets
        for _, obj in pairs(lighting:GetChildren()) do
            if obj:IsA("PostEffect") then
                obj.Enabled = false
            end
        end
    end
    
    local after = getMemoryUsage()
    log("INFO", string.format("Memory cleaned: %s → %s (Saved: %s)", 
        formatMemory(before), formatMemory(after), formatMemory(before - after)))
    
    performance.lastCleanup = tick()
    return before - after
end

-- Rendering optimization
local function optimizeRendering(emergency)
    if emergency and not state.emergencyModeActivated then
        -- Save current settings
        state.originalGraphicsQuality = UserSettings():GetService("UserGameSettings").SavedQualityLevel
        state.originalRenderDistance = workspace.StreamingMinRadius
        
        -- Apply emergency settings
        UserSettings():GetService("UserGameSettings").SavedQualityLevel = 1
        settings().Rendering.QualityLevel = 1
        
        -- Reduce render distance
        workspace.StreamingMinRadius = 64
        
        -- Disable effects
        lighting.GlobalShadows = false
        lighting.ShadowSoftness = 0
        lighting.Brightness = 2
        
        -- Disable physics where possible
        physicsService.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Aggressive
        
        -- Disable unnecessary rendering
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
        settings().Rendering.EagerBulkExecution = false
        
        state.emergencyModeActivated = true
        log("WARN", "Emergency rendering mode activated to prevent crash")
    elseif not emergency and state.emergencyModeActivated then
        -- Restore settings
        UserSettings():GetService("UserGameSettings").SavedQualityLevel = state.originalGraphicsQuality
        settings().Rendering.QualityLevel = state.originalGraphicsQuality
        workspace.StreamingMinRadius = state.originalRenderDistance
        lighting.GlobalShadows = true
        lighting.ShadowSoftness = 0.2
        lighting.Brightness = 1
        
        state.emergencyModeActivated = false
        log("INFO", "Restored normal rendering settings")
    end
end

-- Monitoring functions
local function monitorMemory()
    while task.wait(5) do
        performance.currentMemory = getMemoryUsage()
        performance.peakMemory = math.max(performance.peakMemory, performance.currentMemory)
        
        -- Check memory thresholds
        if performance.currentMemory > config.memoryThresholds.extreme then
            log("CRITICAL", "Extreme memory usage: " .. formatMemory(performance.currentMemory))
            cleanMemory(true)
            optimizeRendering(true)
            config.emergencyMode = true
            state.memorySpikes = state.memorySpikes + 1
            
            if state.memorySpikes > 3 then
                log("CRITICAL", "Multiple extreme memory spikes detected. Attempting to recover...")
                for i = 1, 5 do
                    cleanMemory(true)
                    task.wait(1)
                end
            end
        elseif performance.currentMemory > config.memoryThresholds.critical then
            log("WARN", "Critical memory usage: " .. formatMemory(performance.currentMemory))
            cleanMemory(true)
            state.memorySpikes = state.memorySpikes + 1
        elseif performance.currentMemory > config.memoryThresholds.warning then
            log("INFO", "High memory usage: " .. formatMemory(performance.currentMemory))
            if tick() - performance.lastCleanup > 60 then
                cleanMemory(false)
            end
        else
            state.memorySpikes = math.max(0, state.memorySpikes - 1)
        end
        
        -- Routine cleanup
        if tick() - performance.lastCleanup > config.cleanupInterval then
            cleanMemory(false)
        end
    end
end

local function monitorFPS()
    while true do
        local lastTick = tick()
        runService.RenderStepped:Wait()
        local delta = tick() - lastTick
        
        -- Calculate current FPS
        performance.currentFPS = delta > 0 and (1 / delta) or 60
        
        -- Add to history and maintain sample size
        table.insert(state.fpsHistory, performance.currentFPS)
        if #state.fpsHistory > config.fps.sampleSize then
            table.remove(state.fpsHistory, 1)
        end
        
        -- Calculate average FPS
        local sum = 0
        for _, fps in ipairs(state.fpsHistory) do
            sum = sum + fps
        end
        performance.averageFPS = sum / #state.fpsHistory
        
        -- Check FPS thresholds
        if performance.averageFPS < config.fps.criticalThreshold then
            if not config.emergencyMode then
                log("CRITICAL", string.format("Critically low FPS: %.1f - Activating emergency mode", performance.averageFPS))
                config.emergencyMode = true
                optimizeRendering(true)
                cleanMemory(true)
            end
        elseif performance.averageFPS < config.fps.lowThreshold then
            log("WARN", string.format("Low FPS: %.1f - Performance may be degraded", performance.averageFPS))
            if tick() - performance.lastCleanup > 30 then
                cleanMemory(false)
            end
        elseif config.emergencyMode and performance.averageFPS > config.fps.lowThreshold + 10 then
            -- If FPS has recovered, exit emergency mode
            log("INFO", string.format("FPS recovered: %.1f - Deactivating emergency mode", performance.averageFPS))
            config.emergencyMode = false
            optimizeRendering(false)
        end
        
        task.wait(1) -- Check FPS every second
    end
end

local function monitorFreeze()
    while task.wait(1) do
        local timeSinceHeartbeat = tick() - state.lastHeartbeat
        performance.freezeTime = timeSinceHeartbeat
        
        if timeSinceHeartbeat > config.freezeThresholds.emergency then
            state.freezeCount = state.freezeCount + 1
            log("CRITICAL", string.format("Game freeze detected: %.1fs - Emergency recovery attempt #%d", 
                timeSinceHeartbeat, state.freezeCount))
            
            -- Emergency recovery
            cleanMemory(true)
            optimizeRendering(true)
            config.emergencyMode = true
            
            -- Try to force GC more aggressively
            for i = 1, 5 do
                collectgarbage()
                task.wait(0.1)
            end
            
            if state.freezeCount >= 3 and config.autoReconnect then
                log("CRITICAL", "Multiple severe freezes detected. Attempting to reconnect...")
                task.delay(5, function()
                    teleportService:Teleport(game.PlaceId)
                end)
            end
        elseif timeSinceHeartbeat > config.freezeThresholds.critical then
            log("ERROR", string.format("Game stutter detected: %.1fs", timeSinceHeartbeat))
            cleanMemory(true)
        elseif timeSinceHeartbeat > config.freezeThresholds.warning then
            log("WARN", string.format("Game lag detected: %.1fs", timeSinceHeartbeat))
            if not config.emergencyMode then
                cleanMemory(false)
            end
        else
            -- Gradually reduce freeze count if no freezes
            if state.freezeCount > 0 and tick() % 30 == 0 then
                state.freezeCount = state.freezeCount - 1
            end
        end
    end
end

-- Player monitoring
local function monitorPlayer()
    while task.wait(5) do
        if not localPlayer or not localPlayer.Parent then
            log("ERROR", "Local player reference lost - Potential crash imminent")
            
            task.wait(2)
            
            if not players.LocalPlayer then
                log("CRITICAL", "Player completely disconnected - Attempting recovery")
                
                if config.autoReconnect then
                    task.delay(5, function()
                        teleportService:Teleport(game.PlaceId)
                    end)
                end
            end
        end
    end
end

-- Network monitoring
local function monitorNetwork()
    local lastPing = 0
    
    while task.wait(10) do
        local ping = localPlayer:GetNetworkPing() * 1000 -- Convert to ms
        
        if ping > 500 then
            log("WARN", string.format("High network latency: %dms - Game may become unresponsive", ping))
        elseif ping > 1000 then
            log("ERROR", string.format("Extreme network latency: %dms - Disconnection likely", ping))
        end
        
        -- Detect sudden ping spikes
        if lastPing > 0 and ping > lastPing * 5 and ping > 300 then
            log("WARN", string.format("Sudden ping spike: %dms → %dms", lastPing, ping))
        end
        
        lastPing = ping
    end
end

-- Asset preloading to prevent stutters
local function preloadCriticalAssets()
    log("INFO", "Preloading critical assets to prevent stutters")
    
    local assetsToPreload = {}
    
    -- Add character models
    for _, player in pairs(players:GetPlayers()) do
        if player.Character then
            table.insert(assetsToPreload, player.Character)
        end
    end
    
    -- Add workspace children that are visible
    for _, child in pairs(workspace:GetChildren()) do
        if child:IsA("Model") or child:IsA("Part") then
            table.insert(assetsToPreload, child)
        end
    end
    
    -- Preload in batches to prevent freezing
    local batchSize = 10
    for i = 1, #assetsToPreload, batchSize do
        local batch = {}
        for j = i, math.min(i + batchSize - 1, #assetsToPreload) do
            table.insert(batch, assetsToPreload[j])
        end
        
        pcall(function()
            game:GetService("ContentProvider"):PreloadAsync(batch)
        end)
        
        task.wait(0.5) -- Wait between batches
    end
    
    log("INFO", "Asset preloading complete")
end

-- Status reporting
local function reportStatus()
    while task.wait(60) do -- Report status every minute
        log("INFO", string.format(
            "Status Report - Uptime: %s | FPS: %.1f | Memory: %s | Peak: %s | Freezes: %d",
            getUptime(),
            performance.averageFPS,
            formatMemory(performance.currentMemory),
            formatMemory(performance.peakMemory),
            state.freezeCount
        ))
    end
end

-- Crash recovery (continued)
local function setupCrashRecovery()
    -- Set up auto-reconnect on crash
    if config.autoReconnect then
        game:BindToClose(function()
            if config.emergencyMode then
                log("CRITICAL", "Game closing in emergency mode - Attempting to reconnect")
                teleportService:Teleport(game.PlaceId)
                task.wait(5) -- Give time for teleport to process
                return true -- Attempt to delay closing
            end
        end)
    end
    
    -- Set up error handling
    local oldErrorHandler = settings().Diagnostics.ErrorReporting
    settings().Diagnostics.ErrorReporting = Enum.ErrorReporting.Prompt
    
    -- Monitor script errors
    local scriptErrors = 0
    game:GetService("ScriptContext").Error:Connect(function(message, stack, script)
        scriptErrors = scriptErrors + 1
        
        if scriptErrors > 10 in 60 seconds then
            log("ERROR", "Multiple script errors detected - Game may be unstable")
            cleanMemory(true)
            
            if scriptErrors > 20 then
                log("CRITICAL", "Excessive script errors - Activating emergency mode")
                config.emergencyMode = true
                optimizeRendering(true)
            end
        end
        
        log("WARN", "Script Error: " .. message:sub(1, 100) .. (message:len() > 100 and "..." or ""))
    end)
    
    -- Reset error count periodically
    task.spawn(function()
        while task.wait(60) do
            scriptErrors = 0
        end
    end)
end

-- Texture quality management
local function manageTextureQuality()
    local textureQuality = settings().Rendering.QualityLevel
    
    -- Lower texture quality in emergency mode
    if config.emergencyMode and textureQuality > 1 then
        local oldQuality = textureQuality
        settings().Rendering.QualityLevel = 1
        log("WARN", "Lowered texture quality from " .. oldQuality .. " to 1 to improve performance")
    end
    
    -- Monitor texture memory usage
    task.spawn(function()
        while task.wait(15) do
            local stats = stats()
            if stats and stats.GetTotalMemoryUsageMb then
                local textureMem = stats:GetTextureMem()
                if textureMem > 200 then -- 200MB of texture memory
                    log("WARN", "High texture memory usage: " .. textureMem .. "MB")
                    if not config.emergencyMode then
                        local currentQuality = settings().Rendering.QualityLevel
                        if currentQuality > 2 then
                            settings().Rendering.QualityLevel = currentQuality - 1
                            log("WARN", "Reduced texture quality to level " .. (currentQuality - 1))
                        end
                    end
                end
            end
        end
    end)
end

-- Instance cleanup
local function setupInstanceCleaner()
    -- Track instance count
    local lastInstanceCount = 0
    
    task.spawn(function()
        while task.wait(30) do
            local currentCount = 0
            for _, v in pairs(game:GetDescendants()) do
                currentCount = currentCount + 1
            end
            
            -- Check for instance explosion (sudden large increase)
            if lastInstanceCount > 0 and currentCount > lastInstanceCount * 1.5 and currentCount - lastInstanceCount > 1000 then
                log("ERROR", "Instance explosion detected: " .. lastInstanceCount .. " → " .. currentCount)
                
                -- Try to identify the source
                local counts = {}
                for _, v in pairs(game:GetDescendants()) do
                    local className = v.ClassName
                    counts[className] = (counts[className] or 0) + 1
                end
                
                -- Find classes with unusually high counts
                for class, count in pairs(counts) do
                    if count > 1000 then
                        log("WARN", "Excessive " .. class .. " instances: " .. count)
                    end
                end
                
                -- Force cleanup
                cleanMemory(true)
            end
            
            lastInstanceCount = currentCount
        end
    end)
    
    -- Clean up particle effects that might cause lag
    task.spawn(function()
        while task.wait(10) do
            if config.emergencyMode then
                local particleCount = 0
                for _, v in pairs(game:GetDescendants()) do
                    if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                        if v.Enabled then
                            v.Enabled = false
                            particleCount = particleCount + 1
                        end
                    end
                end
                
                if particleCount > 0 then
                    log("INFO", "Disabled " .. particleCount .. " particle effects to improve performance")
                end
            end
        end
    end)
end

-- Sound management
local function manageSounds()
    task.spawn(function()
        while task.wait(5) do
            if config.emergencyMode then
                -- Reduce sound quality and disable non-essential sounds
                settings().Physics.AllowSleep = true
                settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.DefaultAuto
                
                -- Limit concurrent sounds
                local soundCount = 0
                for _, v in pairs(game:GetDescendants()) do
                    if v:IsA("Sound") and v.Playing and not v:FindFirstChild("CrashGuardEssential") then
                        soundCount = soundCount + 1
                        if soundCount > 5 then
                            v.Volume = v.Volume * 0.5
                            if soundCount > 10 then
                                v:Stop()
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- Smart rendering distance management
local function manageRenderDistance()
    task.spawn(function()
        local baseRenderDistance = workspace.StreamingMinRadius
        
        while task.wait(5) do
            -- Adjust based on performance
            if performance.averageFPS < 15 then
                workspace.StreamingMinRadius = math.max(64, baseRenderDistance * 0.5)
            elseif performance.averageFPS < 30 then
                workspace.StreamingMinRadius = math.max(128, baseRenderDistance * 0.7)
            elseif not config.emergencyMode and performance.averageFPS > 45 then
                workspace.StreamingMinRadius = baseRenderDistance
            end
        end
    end)
end

-- Automatic graphics quality adjustment
local function setupAdaptiveGraphics()
    local userSettings = UserSettings():GetService("UserGameSettings")
    local initialQuality = userSettings.SavedQualityLevel
    
    task.spawn(function()
        while task.wait(10) do
            -- Don't override emergency mode
            if not config.emergencyMode then
                if performance.averageFPS < 20 and userSettings.SavedQualityLevel > 1 then
                    userSettings.SavedQualityLevel = userSettings.SavedQualityLevel - 1
                    log("WARN", "Reduced graphics quality to level " .. userSettings.SavedQualityLevel .. " due to low FPS")
                elseif performance.averageFPS > 55 and userSettings.SavedQualityLevel < initialQuality then
                    userSettings.SavedQualityLevel = math.min(initialQuality, userSettings.SavedQualityLevel + 1)
                    log("INFO", "Increased graphics quality to level " .. userSettings.SavedQualityLevel)
                end
            end
        end
    end)
end

-- Command interface
local function setupCommands()
    -- Add chat commands for manual control
    local chatted = localPlayer.Chatted:Connect(function(message)
        if message:lower() == "/crashguard status" then
            log("INFO", string.format(
                "CrashGuard Status - FPS: %.1f | Memory: %s | Emergency Mode: %s",
                performance.averageFPS,
                formatMemory(performance.currentMemory),
                config.emergencyMode and "ON" or "OFF"
            ))
        elseif message:lower() == "/crashguard clean" then
            log("INFO", "Manual memory cleanup requested")
            cleanMemory(true)
        elseif message:lower() == "/crashguard emergency" then
            config.emergencyMode = not config.emergencyMode
            log(config.emergencyMode and "WARN" or "INFO", 
                "Emergency mode " .. (config.emergencyMode and "activated" or "deactivated"))
            optimizeRendering(config.emergencyMode)
        end
    end)
    
    -- Clean up connection when script ends
    game:BindToClose(function()
        chatted:Disconnect()
    end)
end

-- Initialize the system
local function initialize()
    log("INFO", "CrashGuard v2.0 initializing...")
    
    -- Create status GUI
    if config.showStatusGUI then
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "CrashGuardStatus"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = game.CoreGui
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 150, 0, 60)
        frame.Position = UDim2.new(1, -160, 0, 10)
        frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel = 0
        frame.Parent = screenGui
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 20)
        title.Text = "CrashGuard Status"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.BackgroundTransparency = 1
        title.Parent = frame
        
        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, 0, 0, 40)
        status.Position = UDim2.new(0, 0, 0, 20)
        status.Text = "FPS: -- | MEM: --"
        status.TextColor3 = Color3.fromRGB(255, 255, 255)
        status.BackgroundTransparency = 1
        status.Parent = frame
        
        -- Update status
        task.spawn(function()
            while task.wait(1) do
                status.Text = string.format("FPS: %.1f | MEM: %s\nMode: %s", 
                    performance.averageFPS,
                    formatMemory(performance.currentMemory),
                    config.emergencyMode and "EMERGENCY" or "NORMAL"
                )
                
                -- Color code based on status
                if config.emergencyMode then
                    status.TextColor3 = Color3.fromRGB(255, 100, 100)
                elseif performance.averageFPS < 30 then
                    status.TextColor3 = Color3.fromRGB(255, 255, 100)
                else
                    status.TextColor3 = Color3.fromRGB(100, 255, 100)
                end
            end
        end)
    end
    
    -- Initial cleanup
    cleanMemory(false)
    
    -- Start all monitoring systems
    task.spawn(monitorMemory)
    task.spawn(monitorFPS)
    task.spawn(monitorFreeze)
    task.spawn(monitorPlayer)
    task.spawn(monitorNetwork)
    task.spawn(reportStatus)
    
    -- Set up advanced systems
    setupCrashRecovery()
    setupInstanceCleaner()
    manageSounds()
    manageRenderDistance()
    setupAdaptiveGraphics()
    setupCommands()
    
    -- Preload assets after a short delay
    task.delay(5, preloadCriticalAssets)
    
    -- Set up heartbeat tracking
    runService.Heartbeat:Connect(function()
        state.lastHeartbeat = tick()
    end)
    
    log("INFO", "CrashGuard v2.0 initialized successfully - Your game is now protected from crashes")
end

-- Start the system
initialize()
