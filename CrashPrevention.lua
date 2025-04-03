-- Advanced Crash Prevention System v2.0
-- Lightweight but powerful crash prevention

local runService = game:GetService("RunService")
local players = game:GetService("Players")
local teleportService = game:GetService("TeleportService")
local lighting = game:GetService("Lighting")
local stats = game:GetService("Stats")
local localPlayer = players.LocalPlayer

-- Configuration
local config = {
    memoryThreshold = 500,  -- MB - Triggers cleanup
    freezeThreshold = 5,    -- Seconds without heartbeat to detect freeze
    fpsThreshold = 20,      -- FPS below this triggers warnings
    cleanupInterval = 60,   -- Seconds between routine cleanups
    autoReconnect = true    -- Auto reconnect on crash
}

-- State tracking
local state = {
    lastHeartbeat = tick(),
    lastCleanup = tick(),
    freezeCount = 0,
    fpsDropCount = 0,
    crashLog = {},
    emergencyMode = false
}

-- Log function with file saving
local function log(message)
    local logMsg = os.date("[%X] ") .. message
    table.insert(state.crashLog, logMsg)
    print("[CrashGuard] " .. message)
    
    -- Keep log size reasonable
    if #state.crashLog > 100 then
        table.remove(state.crashLog, 1)
    end
    
    -- Save log to file
    pcall(function()
        writefile("CrashLog.txt", game:GetService("HttpService"):JSONEncode(state.crashLog))
    end)
    
    -- Show critical messages as notifications
    if message:find("CRITICAL") then
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "CrashGuard Alert",
                Text = message:gsub("CRITICAL: ", ""),
                Duration = 5
            })
        end)
    end
end

-- Smart memory cleanup
local function cleanMemory(aggressive)
    local startMem = collectgarbage("count") / 1024
    
    -- Basic cleanup
    collectgarbage()
    
    -- More aggressive cleanup if needed
    if aggressive then
        -- Force full collection
        for i = 1, 3 do
            collectgarbage("collect")
            task.wait(0.1)
        end
        
        -- Clear textures that aren't visible
        for _, obj in pairs(workspace:GetDescendants()) do
            if (obj:IsA("Texture") or obj:IsA("Decal")) and 
               not obj:IsDescendantOf(localPlayer.Character) then
                pcall(function() obj.Transparency = 1 end)
            end
        end
        
        -- Disable effects
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
                pcall(function() obj.Enabled = false end)
            end
        end
        
        -- Disable post-processing effects
        for _, effect in pairs(lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                pcall(function() effect.Enabled = false end)
            end
        end
        
        -- Enter emergency mode
        if not state.emergencyMode then
            state.emergencyMode = true
            lighting.GlobalShadows = false
            settings().Rendering.QualityLevel = 1
            log("CRITICAL: Entered emergency mode to prevent crash")
        end
    end
    
    -- Final collection
    collectgarbage("collect")
    
    -- Calculate memory saved
    local endMem = collectgarbage("count") / 1024
    local saved = startMem - endMem
    
    if saved > 5 then
        log("Memory cleaned: " .. math.floor(startMem) .. "MB → " .. math.floor(endMem) .. "MB (Saved: " .. math.floor(saved) .. "MB)")
    end
    
    state.lastCleanup = tick()
    return saved
end

-- Memory monitoring
local function monitorMemory()
    while task.wait(10) do
        local mem = collectgarbage("count") / 1024
        
        -- Regular cleanup interval
        if tick() - state.lastCleanup > config.cleanupInterval then
            cleanMemory(false)
        end
        
        -- Emergency cleanup if memory is too high
        if mem > config.memoryThreshold then
            log("CRITICAL: High memory usage detected: " .. math.floor(mem) .. "MB")
            cleanMemory(true)
        end
    end
end

-- FPS monitoring
local function monitorFPS()
    while task.wait(3) do
        local fps = math.floor(1 / runService.RenderStepped:Wait())
        
        if fps < config.fpsThreshold then
            state.fpsDropCount = state.fpsDropCount + 1
            
            if state.fpsDropCount >= 2 then
                log("Low FPS detected: " .. fps .. " FPS")
                
                -- Try to improve performance
                if state.fpsDropCount >= 4 and not state.emergencyMode then
                    cleanMemory(true)
                else
                    cleanMemory(false)
                end
                
                state.fpsDropCount = 0
            end
        else
            state.fpsDropCount = math.max(0, state.fpsDropCount - 1)
            
            -- Exit emergency mode if FPS is good again
            if state.emergencyMode and fps > config.fpsThreshold * 1.5 and tick() - state.lastCleanup > 30 then
                state.emergencyMode = false
                lighting.GlobalShadows = true
                settings().Rendering.QualityLevel = 3
                log("Performance improved - Exiting emergency mode")
            end
        end
    end
end

-- Freeze detection
local function monitorFreeze()
    while task.wait(1) do
        local timeSinceHeartbeat = tick() - state.lastHeartbeat
        
        if timeSinceHeartbeat > config.freezeThreshold then
            state.freezeCount = state.freezeCount + 1
            log("CRITICAL: Game freeze detected: " .. math.floor(timeSinceHeartbeat) .. "s")
            
            -- Force cleanup
            cleanMemory(true)
            
            if state.freezeCount >= 3 then
                log("CRITICAL: Multiple freezes detected - Taking emergency actions")
                
                -- Extreme measures to prevent crash
                settings().Rendering.QualityLevel = 1
                workspace:FindFirstChildOfClass("Terrain").Decoration = false
                
                -- Disable all sounds
                for _, sound in pairs(workspace:GetDescendants()) do
                    if sound:IsA("Sound") then
                        pcall(function() sound.Playing = false end)
                    end
                end
                
                state.freezeCount = 0
            end
        else
            -- Gradually reduce freeze count if no freezes
            if tick() - state.lastHeartbeat > 30 and state.freezeCount > 0 then
                state.freezeCount = state.freezeCount - 1
            end
        end
    end
end

-- Auto-reconnect on crash
local function setupAutoReconnect()
    if not config.autoReconnect then return end
    
    -- Monitor for disconnection
    game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
        if child.Name == "ErrorPrompt" then
            log("CRITICAL: Game crashed - Attempting to reconnect")
            task.wait(5)
            teleportService:Teleport(game.PlaceId)
        end
    end)
    
    -- Check for player removal
    while task.wait(15) do
        if not localPlayer or not localPlayer.Parent then
            log("CRITICAL: Player disconnected - Attempting to reconnect")
            task.wait(5)
            pcall(function()
                teleportService:Teleport(game.PlaceId)
            end)
        end
    end
end

-- Optimize game on startup
local function optimizeOnStartup()
    -- Preemptive cleanup
    cleanMemory(false)
    
    -- Optimize rendering settings
    local currentQuality = settings().Rendering.QualityLevel
    if currentQuality > 7 then
        settings().Rendering.QualityLevel = 7
    end
    
    -- Limit distance
    settings().Rendering.MaximumQualityLevel = 7
    
    -- Optimize physics
    settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.DefaultAuto
    
    -- Disable unnecessary effects
    lighting.GlobalShadows = lighting.GlobalShadows -- Keep current setting
    
    log("Game optimized for stability")
end

-- Heartbeat tracker
runService.Heartbeat:Connect(function()
    state.lastHeartbeat = tick()
end)

-- Initialize
optimizeOnStartup()
task.spawn(monitorMemory)
task.spawn(monitorFPS)
task.spawn(monitorFreeze)
task.spawn(setupAutoReconnect)

-- Create simple status indicator
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CrashGuardStatus"
pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not screenGui.Parent then screenGui.Parent = localPlayer:WaitForChild("PlayerGui") end

local statusFrame = Instance.new("Frame")
statusFrame.Size = UDim2.new(0, 120, 0, 25)
statusFrame.Position = UDim2.new(1, -130, 0, 10)
statusFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
statusFrame.BackgroundTransparency = 0.5
statusFrame.BorderSizePixel = 0
statusFrame.Parent = screenGui

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 8)
statusCorner.Parent = statusFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 1, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "CrashGuard: Active"
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
statusLabel.TextSize = 14
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Parent = statusFrame

-- Update status indicator
task.spawn(function()
    while task.wait(1) do
        if state.emergencyMode then
            statusLabel.Text = "CrashGuard: EMERGENCY"
            statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        elseif state.freezeCount > 0 or state.fpsDropCount > 0 then
            statusLabel.Text = "CrashGuard: Warning"
            statusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        else
            statusLabel.Text = "CrashGuard: Active"
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        end
    end
end)

log("CrashGuard loaded successfully - Your game is now protected")
