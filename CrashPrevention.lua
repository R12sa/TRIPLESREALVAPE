-- Ultra-Reliable Crash Prevention v3.0
-- Designed for maximum stability with minimal overhead
-- Last updated: 4/2/25

local runService = game:GetService("RunService")
local players = game:GetService("Players")
local lighting = game:GetService("Lighting")
local stats = game:GetService("Stats")
local coreGui = game:GetService("CoreGui")
local localPlayer = players.LocalPlayer

-- Configuration (feel free to adjust)
local config = {
    memoryLimit = 450,        -- MB - Aggressive cleanup threshold
    freezeThreshold = 3,      -- Seconds to detect freeze
    fpsThreshold = 15,        -- Low FPS threshold
    checkInterval = 2,        -- Seconds between checks
    autoFixGraphics = true,   -- Auto-reduce graphics
    disableEffects = true,    -- Disable effects when needed
    showStatus = true         -- Show status indicator
}

-- State tracking
local state = {
    lastHeartbeat = tick(),
    lastCleanup = 0,
    freezeCount = 0,
    lowFpsCount = 0,
    memoryWarnings = 0,
    emergencyMode = false,
    logs = {}
}

-- Simple logging
local function log(message)
    local entry = os.date("[%H:%M:%S] ") .. message
    table.insert(state.logs, entry)
    
    -- Keep log size reasonable
    if #state.logs > 50 then table.remove(state.logs, 1) end
    
    -- Print to console
    print("[CrashGuard] " .. message)
    
    -- Save to file
    pcall(function()
        writefile("crash_log.txt", table.concat(state.logs, "\n"))
    end)
    
    -- Show notification for important messages
    if message:find("WARNING") or message:find("EMERGENCY") then
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "CrashGuard",
                Text = message:gsub("WARNING: ", ""):gsub("EMERGENCY: ", ""),
                Duration = 3
            })
        end)
    end
end

-- Create status indicator
local statusLabel
if config.showStatus then
    pcall(function()
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "CrashGuardStatus"
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        
        -- Try to parent to CoreGui for persistence
        pcall(function() screenGui.Parent = coreGui end)
        if not screenGui.Parent then screenGui.Parent = localPlayer:WaitForChild("PlayerGui") end
        
        -- Create status label
        statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(0, 120, 0, 25)
        statusLabel.Position = UDim2.new(1, -125, 0, 5)
        statusLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        statusLabel.BackgroundTransparency = 0.5
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        statusLabel.TextSize = 14
        statusLabel.Font = Enum.Font.GothamBold
        statusLabel.Text = "CrashGuard: OK"
        statusLabel.BorderSizePixel = 0
        
        -- Add rounded corners
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = statusLabel
        
        statusLabel.Parent = screenGui
    end)
end

-- Update status indicator
local function updateStatus(status, color)
    if statusLabel then
        pcall(function()
            statusLabel.Text = "CrashGuard: " .. status
            statusLabel.TextColor3 = color
        end)
    end
end

-- Memory cleanup with different intensity levels
local function cleanMemory(aggressive)
    local startMem = collectgarbage("count") / 1024
    
    -- Basic cleanup
    collectgarbage()
    task.wait(0.1)
    
    -- More aggressive cleanup if needed
    if aggressive then
        -- Force full collection
        for i = 1, 2 do
            collectgarbage("collect")
            task.wait(0.1)
        end
        
        -- Clear textures and effects
        if config.disableEffects then
            pcall(function()
                -- Disable particles
                for _, obj in pairs(workspace:GetDescendants()) do
                    if obj:IsA("ParticleEmitter") then
                        obj.Enabled = false
                    elseif obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                        obj.Enabled = false
                    end
                end
                
                -- Disable post-processing
                for _, effect in pairs(lighting:GetChildren()) do
                    if effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or 
                       effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") then
                        effect.Enabled = false
                    end
                end
            end)
        end
    end
    
    -- Final collection
    collectgarbage("collect")
    
    -- Calculate memory saved
    local endMem = collectgarbage("count") / 1024
    local saved = startMem - endMem
    
    state.lastCleanup = tick()
    return saved, endMem
end

-- Optimize graphics settings
local function optimizeGraphics(emergency)
    if not config.autoFixGraphics then return end
    
    pcall(function()
        local currentQuality = settings().Rendering.QualityLevel
        
        if emergency then
            -- Emergency settings
            settings().Rendering.QualityLevel = 1
            lighting.GlobalShadows = false
            lighting.ShadowSoftness = 0
            settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
            
            -- Disable terrain decorations
            if workspace:FindFirstChildOfClass("Terrain") then
                workspace.Terrain.Decoration = false
            end
            
            log("EMERGENCY: Applied minimum graphics settings to prevent crash")
        else
            -- Just reduce quality by 2 levels
            local newQuality = math.max(1, currentQuality - 2)
            if newQuality < currentQuality then
                settings().Rendering.QualityLevel = newQuality
                log("WARNING: Reduced graphics quality to level " .. newQuality)
            end
        end
    end)
end

-- Enter emergency mode
local function enterEmergencyMode()
    if state.emergencyMode then return end
    
    state.emergencyMode = true
    updateStatus("EMERGENCY", Color3.fromRGB(255, 0, 0))
    
    log("EMERGENCY: Entering emergency mode to prevent crash")
    
    -- Aggressive cleanup
    local saved, newMem = cleanMemory(true)
    log("EMERGENCY: Freed " .. math.floor(saved) .. "MB of memory")
    
    -- Minimum graphics
    optimizeGraphics(true)
    
    -- Disable sounds
    pcall(function()
        for _, sound in pairs(workspace:GetDescendants()) do
            if sound:IsA("Sound") and sound.Playing then
                sound.Playing = false
            end
        end
    end)
    
    -- Disable physics
    pcall(function()
        settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Aggressive
        settings().Physics.AllowSleep = true
        settings().Physics.DisableCSGv2 = true
    end)
    
    -- Limit render distance
    pcall(function()
        settings().Rendering.EagerBulkExecution = false
        settings().Rendering.ExportMergeByMaterial = true
        settings().Rendering.MeshCacheSize = 32
    end)
    
    -- Disable character animations if possible
    pcall(function()
        if localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid") then
            localPlayer.Character.Humanoid.AnimationPlayed:Connect(function(animTrack)
                if state.emergencyMode then
                    animTrack:Stop()
                end
            end)
        end
    end)
end

-- Exit emergency mode
local function exitEmergencyMode()
    if not state.emergencyMode then return end
    
    state.emergencyMode = false
    updateStatus("OK", Color3.fromRGB(0, 255, 0))
    
    log("System stabilized - Exiting emergency mode")
    
    -- Restore settings
    pcall(function()
        settings().Rendering.QualityLevel = 3
        lighting.GlobalShadows = true
        
        if workspace:FindFirstChildOfClass("Terrain") then
            workspace.Terrain.Decoration = true
        end
    end)
end

-- Main monitoring function
local function monitorSystem()
    -- Track FPS
    local lastFpsCheck = tick()
    local frameCount = 0
    
    runService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        state.lastHeartbeat = tick()
    end)
    
    -- Main monitoring loop
    while task.wait(config.checkInterval) do
        -- Check for freezes
        local timeSinceHeartbeat = tick() - state.lastHeartbeat
        if timeSinceHeartbeat > config.freezeThreshold then
            state.freezeCount = state.freezeCount + 1
            log("WARNING: Game freeze detected: " .. math.floor(timeSinceHeartbeat) .. "s")
            
            if state.freezeCount >= 2 then
                enterEmergencyMode()
            end
        else
            -- Gradually reduce freeze count
            state.freezeCount = math.max(0, state.freezeCount - 0.5)
        end
        
        -- Check FPS
        local currentTime = tick()
        local elapsed = currentTime - lastFpsCheck
        
        if elapsed >= 1 then
            local fps = frameCount / elapsed
            frameCount = 0
            lastFpsCheck = currentTime
            
            if fps < config.fpsThreshold then
                state.lowFpsCount = state.lowFpsCount + 1
                
                if state.lowFpsCount >= 3 then
                    log("WARNING: Persistent low FPS: " .. math.floor(fps) .. " FPS")
                    
                    if state.lowFpsCount >= 5 then
                        enterEmergencyMode()
                    else
                        optimizeGraphics(false)
                        cleanMemory(false)
                    end
                end
            else
                state.lowFpsCount = math.max(0, state.lowFpsCount - 0.5)
                
                -- Exit emergency mode if things are stable
                if state.emergencyMode and fps > config.fpsThreshold * 1.5 and 
                   state.freezeCount == 0 and state.memoryWarnings == 0 and
                   tick() - state.lastCleanup > 30 then
                    exitEmergencyMode()
                end
            end
        end
        
        -- Check memory
        local mem = collectgarbage("count") / 1024
        if mem > config.memoryLimit then
            state.memoryWarnings = state.memoryWarnings + 1
            log("WARNING: High memory usage: " .. math.floor(mem) .. "MB")
            
            local saved, newMem = cleanMemory(state.memoryWarnings >= 2)
            
            if newMem > config.memoryLimit * 0.9 then
                enterEmergencyMode()
            end
        else
            state.memoryWarnings = math.max(0, state.memoryWarnings - 0.5)
        end
        
        -- Update status indicator
        if not state.emergencyMode then
            if state.freezeCount > 0 or state.lowFpsCount > 0 or state.memoryWarnings > 0 then
                updateStatus("WARNING", Color3.fromRGB(255, 255, 0))
            else
                updateStatus("OK", Color3.fromRGB(0, 255, 0))
            end
        end
    end
end

-- Optimize on startup
local function optimizeOnStartup()
    -- Initial cleanup
    cleanMemory(false)
    
    -- Preemptively optimize some settings
    pcall(function()
        -- Set reasonable quality level
        if settings().Rendering.QualityLevel > 6 then
            settings().Rendering.QualityLevel = 6
        end
        
        -- Optimize physics
        settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Default
        settings().Physics.AllowSleep = true
        
        -- Optimize network
        settings().Network.IncomingReplicationLag = Enum.NetworkOwnership.Manual
        
        -- Optimize rendering
        settings().Rendering.EagerBulkExecution = true
    end)
    
    log("System optimized for stability")
end

-- Prevent idle kick
local function preventIdleKick()
    while task.wait(120) do
        pcall(function()
            local virtualUser = game:GetService("VirtualUser")
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new())
        end)
    end
end

-- Auto-reconnect on crash
local function setupAutoReconnect()
    pcall(function()
        coreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then
                log("EMERGENCY: Game crashed - Attempting to reconnect")
                task.wait(5)
                game:GetService("TeleportService"):Teleport(game.PlaceId)
            end
        end)
    end)
end

-- Initialize
log("CrashGuard initializing...")
optimizeOnStartup()
task.spawn(monitorSystem)
task.spawn(preventIdleKick)
task.spawn(setupAutoReconnect)
log("CrashGuard active - Your game is now protected")
updateStatus("OK", Color3.fromRGB(0, 255, 0))
