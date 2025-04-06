local whitelist_url = "https://raw.githubusercontent.com/R12sa/triplecrobowl/main/whitelist.json"
local player = game.Players.LocalPlayer
local userId = tostring(player.UserId)

local function getWhitelist()
    local success, response = pcall(function()
        return game:HttpGet(whitelist_url)
    end)
    if success and response then
        local successDecode, whitelist = pcall(function()
            return game:GetService("HttpService"):JSONDecode(response)
        end)
        if successDecode then
            return whitelist
        end
    end
    return nil
end

local whitelist = getWhitelist()
if whitelist and whitelist[userId] then
    -- User is whitelisted, continue with the script
    local old_require = require
    getgenv().require = function(path)
        setthreadidentity(2)
        local _ = old_require(path)
        setthreadidentity(8)
        return _
    end

    -- Check if file-related functions exist and wrap them safely
    local isfile = isfile or function(file)
        local suc, res = pcall(function() return readfile(file) end)
        return suc and res ~= nil and res ~= ''
    end

    local delfile = delfile or function(file)
        pcall(function() writefile(file, '') end)
    end

    local function downloadFile(path, func)
        if not isfile(path) then
            local suc, res = pcall(function()
                return game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/' .. readfile('newvape/profiles/commit.txt') .. '/' .. select(1, path:gsub('newvape/', '')), true)
            end)
            if not suc or res == '404: Not Found' then
                warn("Failed to download file: " .. tostring(res))
                return nil
            end
            if path:find('.lua') then
                res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
            end
            pcall(function() writefile(path, res) end)
        end
        return (func or readfile)(path)
    end

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
    local function loadMainScript()
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
            warn("Failed to load script: " .. tostring(err))
            game.StarterGui:SetCore("SendNotification", {
                Title = "Error",
                Text = "Failed to load script: " .. tostring(err),
                Duration = 5
            })
            return false
        else
            game.StarterGui:SetCore("SendNotification", {
                Title = "Success",
                Text = "Script loaded successfully!",
                Duration = 2
            })
            return true
        end
    end

    -- Track current place ID to detect game changes
    local currentPlaceId = game.PlaceId
    local shopLoaded = false

    -- Initial load
    shopLoaded = loadMainScript()

    -- Auto-reinjection when player teleports or game changes
    game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
        if state == Enum.TeleportState.Started then
            -- Queue script to run after teleport
            syn = syn or {}
            if syn.queue_on_teleport then
                syn.queue_on_teleport([[
                    repeat wait() until game:IsLoaded()
                    loadstring(game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/main/loader.lua'))()
                ]])
            end
        end
    end)

    -- Check for game changes (for games that change PlaceId without full teleport)
    game:GetService("RunService").Heartbeat:Connect(function()
        if game.PlaceId ~= currentPlaceId then
            currentPlaceId = game.PlaceId
            -- Game changed, reload the script
            task.wait(5) -- Wait for game to fully load
            shopLoaded = loadMainScript()
        end
        
        -- If we're in a lobby and shop isn't loaded, try to load it
        if not shopLoaded and game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer.Character then
            -- Check if we're in a lobby (you may need to adjust this logic based on the specific game)
            local inLobby = false
            
            -- Example lobby detection (customize for your specific game)
            if game.PlaceId == 6872265039 or -- Example lobby PlaceId
               game.PlaceId == 6872274481 or -- Another example lobby PlaceId
               game:GetService("Players").LocalPlayer:FindFirstChild("InLobby") then
                inLobby = true
            end
            
            if inLobby then
                shopLoaded = loadMainScript()
            end
        end
    end)

    -- Reset shop loaded state when character dies/respawns (common in round-based games)
    game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
        task.wait(2) -- Wait for character to fully load
        if not shopLoaded then
            shopLoaded = loadMainScript()
        end
    end)

    -- Handle game state changes (for games with round systems)
    local gameStateChanged = false
    game:GetService("RunService").Heartbeat:Connect(function()
        -- Example: Check for round state changes (customize for your specific game)
        local gameState = game:GetService("ReplicatedStorage"):FindFirstChild("GameState")
        if gameState then
            local currentState = gameState.Value
            if currentState == "Lobby" and not gameStateChanged then
                gameStateChanged = true
                shopLoaded = loadMainScript()
            elseif currentState ~= "Lobby" then
                gameStateChanged = false
            end
        end
    end)
else
    -- User is not whitelisted
    game.StarterGui:SetCore("SendNotification", {
        Title = "Access Denied",
        Text = "You are not whitelisted to use this script.",
        Duration = 5
    })
end
