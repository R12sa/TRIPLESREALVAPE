-- Vape Shop Hook - Ensures the require hook is in place before Vape loads
-- This script should be executed once and will persist across game changes

-- Create a flag to track if we've already set up the hook
if not getgenv().VapeShopHookInitialized then
    getgenv().VapeShopHookInitialized = true
    
    -- Store the original require function
    local original_require = require
    
    -- Create our hook function
    getgenv().require = function(path)
        setthreadidentity(2)
        local result = original_require(path)
        setthreadidentity(8)
        return result
    end
    
    -- Function to check if file exists
    local isfile = isfile or function(file)
        local success, result = pcall(function() return readfile(file) end)
        return success and result ~= nil and result ~= ''
    end
    
    -- Function to delete file
    local delfile = delfile or function(file)
        pcall(function() writefile(file, '') end)
    end
    
    -- Function to download file
    local function downloadFile(path, func)
        if not isfile(path) then
            local success, result = pcall(function()
                return game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/' .. readfile('newvape/profiles/commit.txt') .. '/' .. select(1, path:gsub('newvape/', '')), true)
            end)
            if not success or result == '404: Not Found' then
                warn("Failed to download file: " .. tostring(result))
                return nil
            end
            if path:find('.lua') then
                result = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. result
            end
            pcall(function() writefile(path, result) end)
        end
        return (func or readfile)(path)
    end
    
    -- Function to wipe folder
    local function wipeFolder(path)
        if not isfolder(path) then return end
        for _, file in pairs(listfiles(path)) do
            if file:find('loader') then continue end
            if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
                delfile(file)
            end
        end
    end
    
    -- Create necessary folders
    for _, folder in pairs({'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'}) do
        if not isfolder(folder) then
            pcall(function() makefolder(folder) end)
        end
    end
    
    -- Function to load the main script
    local function loadShopScript()
        if not shared.VapeDeveloper then
            local retries = 3
            local subbed
            
            while retries > 0 do
                local success, response = pcall(function()
                    return game:HttpGet('https://github.com/R12sa/TRIPLESREALVAPE')
                end)
                
                if success and response then
                    subbed = response
                    break
                end
                
                retries = retries - 1
                wait(1)
            end
            
            if subbed then
                local commit = subbed:find('currentOid')
                commit = commit and subbed:sub(commit + 13, commit + 52) or nil
                commit = commit and #commit == 40 and commit or 'main'
                
                if commit == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit then
                    wipeFolder('newvape')
                    wipeFolder('newvape/games')
                    wipeFolder('newvape/guis')
                    wipeFolder('newvape/libraries')
                end
                
                pcall(function() writefile('newvape/profiles/commit.txt', commit) end)
            end
        end
        
        -- Load script safely
        local success, err = pcall(function()
            loadstring(downloadFile('newvape/main.lua'), 'main')()
        end)
        
        if not success then
            warn("Failed to load shop script: " .. tostring(err))
            game.StarterGui:SetCore("SendNotification", {
                Title = "Error",
                Text = "Failed to load shop script",
                Duration = 5
            })
            return false
        else
            game.StarterGui:SetCore("SendNotification", {
                Title = "Success",
                Text = "Shop loaded successfully!",
                Duration = 2
            })
            return true
        end
    end
    
    -- Set up auto-injection for game changes
    
    -- 1. Handle teleports
    local function setupTeleportHook()
        game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
            if state == Enum.TeleportState.Started then
                -- Queue our hook to run immediately after teleport
                local queueScript = [[
                    repeat wait() until game:IsLoaded()
                    
                    -- Set up the require hook first
                    local original_require = require
                    getgenv().require = function(path)
                        setthreadidentity(2)
                        local result = original_require(path)
                        setthreadidentity(8)
                        return result
                    end
                    
                    -- Then load the full script
                    loadstring(game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/main/loader.lua'))()
                ]]
                
                -- Use the appropriate queue function based on executor
                if syn and syn.queue_on_teleport then
                    syn.queue_on_teleport(queueScript)
                elseif queue_on_teleport then
                    queue_on_teleport(queueScript)
                end
            end
        end)
    end
    
    -- 2. Handle game loaded events
    local function onGameLoaded()
        -- Wait for game to fully load
        if not game:IsLoaded() then
            game.Loaded:Wait()
        end
        
        -- Wait for local player
        if not game:GetService("Players").LocalPlayer then
            game:GetService("Players"):GetPropertyChangedSignal("LocalPlayer"):Wait()
        end
        
        -- Set up teleport hook
        setupTeleportHook()
        
        -- Load shop script
        loadShopScript()
    end
    
    -- Run initial setup
    onGameLoaded()
    
    -- Set up a hook for when the character is added (for respawns/round changes)
    game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
        -- Small delay to ensure Vape has a chance to load first
        task.wait(1)
        
        -- Make sure our hook is still in place
        if require ~= getgenv().require then
            -- If our hook was overwritten, restore it
            require = getgenv().require
            
            -- And reload the shop
            loadShopScript()
        end
    end)
    
    -- Monitor for game state changes
    local gameStateChanged = false
    game:GetService("RunService").Heartbeat:Connect(function()
        -- Check for game state changes that might indicate returning to lobby
        local gameState = game:GetService("ReplicatedStorage"):FindFirstChild("GameState")
        if gameState and gameState.Value == "Lobby" and not gameStateChanged then
            gameStateChanged = true
            
            -- Make sure our hook is still in place
            if require ~= getgenv().require then
                require = getgenv().require
                loadShopScript()
            end
        elseif gameState and gameState.Value ~= "Lobby" then
            gameStateChanged = false
        end
    end)
    
    -- Print confirmation
    print("Vape Shop Hook initialized - require function is now hooked")
end
