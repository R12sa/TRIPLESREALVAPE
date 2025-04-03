-- Crash Prevention Pro - Zero Crash Edition
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local httpService = game:GetService("HttpService")
local teleportService = game:GetService("TeleportService")
local lighting = game:GetService("Lighting")
local localPlayer = players.LocalPlayer
local lastHeartbeat = tick()
local crashLog = {}
local fpsDropTime = 0
local memOverloadTime = 0
local freezeCount = 0
local criticalMemoryThreshold = 450 -- Lower threshold for earlier cleanup
local freezeThreshold = 4 -- Detect freezes faster
local fpsThreshold = 20
local emergencyMode = false

local function log(txt)
    local logMsg = os.date("[%X] ") .. txt
    table.insert(crashLog, logMsg)
    print("[Crash Helper] " .. txt)
    pcall(function()
        writefile("CrashLog.txt", httpService:JSONEncode(crashLog))
    end)
end

local function safeCollectGarbage(aggressive)
    local mem = collectgarbage("count") / 1024
    if mem > criticalMemoryThreshold or aggressive then
        log("Yo, memory's at " .. math.floor(mem) .. "MB. Time to clean up.")
        task.wait(0.1)
        collectgarbage("collect") -- More aggressive collection
        
        if aggressive then
            -- Super aggressive cleanup
            for i = 1, 3 do
                collectgarbage("collect")
                task.wait(0.1)
            end
            
            -- Disable effects to save memory
            pcall(function()
                for _, obj in pairs(workspace:GetDescendants()) do
                    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") then
                        obj.Enabled = false
                    end
                end
                lighting.GlobalShadows = false
            end)
        end
        
        task.wait(0.5)
        log("Memory cleaned. Now at: " .. math.floor(collectgarbage("count") / 1024) .. "MB")
    end
end

local function enterEmergencyMode()
    if emergencyMode then return end
    emergencyMode = true
    log("EMERGENCY MODE ACTIVATED - Taking extreme measures to prevent crash")
    
    -- Aggressive memory cleanup
    safeCollectGarbage(true)
    
    -- Reduce graphics to minimum
    pcall(function()
        settings().Rendering.QualityLevel = 1
        lighting.GlobalShadows = false
        
        -- Disable all sounds
        for _, sound in pairs(workspace:GetDescendants()) do
            if sound:IsA("Sound") and sound.Playing then
                sound.Playing = false
            end
        end
    end)
    
    -- Create emergency notification
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "Crash Prevention",
            Text = "Emergency mode activated to prevent crash",
            Duration = 5
        })
    end)
end

local function monitorMemory()
    while task.wait(5) do -- Check more frequently
        safeCollectGarbage(emergencyMode)
        
        -- Check for memory spikes
        local mem = collectgarbage("count") / 1024
        if mem > criticalMemoryThreshold * 1.2 then
            memOverloadTime = memOverloadTime + 1
            if memOverloadTime >= 2 then
                log("Memory overload detected! " .. math.floor(mem) .. "MB")
                enterEmergencyMode()
                memOverloadTime = 0
            end
        else
            memOverloadTime = 0
        end
    end
end

local function monitorFPS()
    local frameCount = 0
    local lastCheck = tick()
    
    runService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = tick()
        
        if now - lastCheck >= 2 then
            local fps = frameCount / (now - lastCheck)
            frameCount = 0
            lastCheck = now
            
            if fps < fpsThreshold then
                fpsDropTime = fpsDropTime + 1
                if fpsDropTime >= 2 then
                    log("FPS is tanking: " .. math.floor(fps) .. " FPS. Taking action.")
                    
                    -- Auto-reduce graphics if FPS is really bad
                    if fps < fpsThreshold * 0.5 then
                        pcall(function()
                            local currentQuality = settings().Rendering.QualityLevel
                            if currentQuality > 1 then
                                settings().Rendering.QualityLevel = currentQuality - 1
                                log("Auto-reduced graphics to level " .. (currentQuality - 1))
                            end
                        end)
                    end
                    
                    safeCollectGarbage(fpsDropTime >= 4)
                    fpsDropTime = 0
                end
            else
                fpsDropTime = 0
            end
        end
    end)
end

local function monitorFreeze()
    while task.wait(2) do -- Check more frequently
        if tick() - lastHeartbeat > freezeThreshold then
            freezeCount = freezeCount + 1
            log("Yo, game froze. That's " .. freezeCount .. " times now.")
            
            -- Force cleanup on freeze
            safeCollectGarbage(true)
            
            if freezeCount >= 2 then -- React faster to freezes
                log("Multiple freezes detected - Taking emergency action")
                enterEmergencyMode()
                freezeCount = 0
            end
        else
            -- Gradually reduce freeze count if no freezes
            if freezeCount > 0 and tick() - lastHeartbeat > 30 then
                freezeCount = freezeCount - 1
            end
        end
    end
end

local function monitorPlayer()
    while task.wait(5) do -- Check more frequently
        if not players.LocalPlayer then
            log("Local player is missing, might crash")
            task.wait(1)
            if not players.LocalPlayer then
                log("Yup, that's a bad one. Trying to recover...")
                safeCollectGarbage(true)
            end
        end
        
        -- Also check if character exists when it should
        if localPlayer and not localPlayer.Character and tick() - (lastRespawn or 0) > 10 then
            log("Character missing when it should exist - Possible issue")
        end
        
        -- Track respawns
        if localPlayer and localPlayer.Character then
            lastRespawn = tick()
        end
    end
end

local function autoReconnect()
    -- Monitor for disconnection
    pcall(function()
        game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then
                log("Game crashed with error prompt - Attempting to reconnect")
                task.wait(5)
                teleportService:Teleport(game.PlaceId)
            end
        end)
    end)
    
    -- Regular check
    while task.wait(10) do
        if not localPlayer or not localPlayer.Parent then
            log("Game crashed or disconnected - Trying to reconnect in 5 seconds...")
            task.wait(5)
            teleportService:Teleport(game.PlaceId)
        end
    end
end

-- Optimize on startup
pcall(function()
    if settings().Rendering.QualityLevel > 7 then
        settings().Rendering.QualityLevel = 7
        log("Reduced initial graphics quality for stability")
    end
end)

-- Heartbeat tracker
runService.Heartbeat:Connect(function()
    lastHeartbeat = tick()
end)

-- Start monitoring
task.spawn(monitorMemory)
task.spawn(monitorFreeze)
task.spawn(monitorPlayer)
task.spawn(autoReconnect)
monitorFPS() -- This one uses RenderStepped directly

log("Zero-Crash Prevention System Loaded. You ain't crashing on my watch!")
