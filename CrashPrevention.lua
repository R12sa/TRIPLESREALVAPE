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
