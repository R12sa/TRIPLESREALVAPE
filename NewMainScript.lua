-- Shop Fix for MacSploit/Nexus42
-- This script ensures the shop works even after clicking "Play Again"

-- Store original require function
local original_require = require

-- Create our hook function that will persist
getgenv().require = function(path)
    setthreadidentity(2)
    local result = original_require(path)
    setthreadidentity(8)
    return result
end

-- Create a flag to track if shop is loaded in current session
getgenv().shopLoaded = false

-- Basic file functions
local function isfile_safe(file)
    local success, result = pcall(function() return readfile(file) end)
    return success and result ~= nil and result ~= ''
end

local function delfile_safe(file)
    pcall(function() writefile(file, '') end)
end

-- Download file from repository
local function downloadFile(path)
    if not isfile_safe(path) then
        local success, result = pcall(function()
            local commit = isfile_safe('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or 'main'
            return game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/' .. commit .. '/' .. path:gsub('newvape/', ''), true)
        end)
        
        if not success or result == '404: Not Found' then
            warn("Failed to download: " .. path)
            return nil
        end
        
        if path:find('.lua') then
            result = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. result
        end
        
        pcall(function() writefile(path, result) end)
    end
    
    return readfile(path)
end

-- Create folders if they don't exist
for _, folder in pairs({'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'}) do
    if not isfolder(folder) then
        pcall(function() makefolder(folder) end)
    end
end

-- Get latest commit
local function getLatestCommit()
    local success, response = pcall(function()
        return game:HttpGet('https://github.com/R12sa/TRIPLESREALVAPE')
    end)
    
    if success and response then
        local commit = response:find('currentOid')
        commit = commit and response:sub(commit + 13, commit + 52) or nil
        return commit and #commit == 40 and commit or 'main'
    end
    
    return 'main'
end

-- Wipe cached files
local function wipeCache()
    for _, folder in pairs({'newvape', 'newvape/games', 'newvape/guis', 'newvape/libraries'}) do
        if isfolder(folder) then
            for _, file in pairs(listfiles(folder)) do
                if file:find('loader') then continue end
                if isfile_safe(file) and readfile(file):find('--This watermark is used to delete the file if its cached') then
                    delfile_safe(file)
                end
            end
        end
    end
end

-- Load shop script
local function loadShop()
    -- Prevent multiple loads
    if getgenv().shopLoaded then return true end
    
    -- Check for commit changes
    local commit = getLatestCommit()
    local oldCommit = isfile_safe('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or nil
    
    -- If commit changed, wipe cache
    if commit ~= oldCommit then
        wipeCache()
        pcall(function() writefile('newvape/profiles/commit.txt', commit) end)
    end
    
    -- Load main script
    local success, err = pcall(function()
        local mainScript = downloadFile('newvape/main.lua')
        if mainScript then
            loadstring(mainScript, 'main')()
        else
            error("Failed to download main script")
        end
    end)
    
    if success then
        getgenv().shopLoaded = true
        game.StarterGui:SetCore("SendNotification", {
            Title = "Shop Loaded",
            Text = "Shop is now available!",
            Duration = 2
        })
        return true
    else
        warn("Failed to load shop: " .. tostring(err))
        game.StarterGui:SetCore("SendNotification", {
            Title = "Shop Error",
            Text = "Failed to load shop. Try again.",
            Duration = 5
        })
        return false
    end
end

-- Function to detect game state changes
local function setupGameStateDetection()
    -- Track current game/place
    local currentGame = game.PlaceId
    
    -- Check for teleports
    game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
        if state == Enum.TeleportState.Started then
            -- Queue our script to run after teleport
            if syn and syn.queue_on_teleport then
                syn.queue_on_teleport([[
                    repeat wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer
                    loadstring(game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/main/loader.lua'))()
                ]])
            end
        end
    end)
    
    -- Reset shop loaded state when character spawns
    game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1) -- Wait for game to stabilize
        getgenv().shopLoaded = false
        loadShop()
    end)
    
    -- Monitor for "Play Again" button clicks (detect by checking UI)
    local function checkForPlayAgainClick()
        local playAgainDetected = false
        
        -- Check common UI elements that might indicate "Play Again" was clicked
        for _, ui in pairs(game:GetService("Players").LocalPlayer:GetDescendants()) do
            if ui:IsA("TextButton") and (ui.Text:find("Play Again") or ui.Text:find("Lobby")) then
                if ui.Visible and not playAgainDetected then
                    ui.MouseButton1Click:Connect(function()
                        task.wait(2) -- Wait for transition
                        getgenv().shopLoaded = false
                        loadShop()
                    end)
                    playAgainDetected = true
                end
            end
        end
        
        -- Also check CoreGui
        for _, ui in pairs(game:GetService("CoreGui"):GetDescendants()) do
            if ui:IsA("TextButton") and (ui.Text:find("Play Again") or ui.Text:find("Lobby")) then
                if ui.Visible and not playAgainDetected then
                    ui.MouseButton1Click:Connect(function()
                        task.wait(2) -- Wait for transition
                        getgenv().shopLoaded = false
                        loadShop()
                    end)
                    playAgainDetected = true
                end
            end
        end
    end
    
    -- Check UI periodically
    spawn(function()
        while wait(5) do
            pcall(checkForPlayAgainClick)
        end
    end)
    
    -- Monitor for game state changes
    spawn(function()
        while wait(2) do
            -- Check if game changed
            if game.PlaceId ~= currentGame then
                currentGame = game.PlaceId
                getgenv().shopLoaded = false
                task.wait(5) -- Wait for game to load
                loadShop()
            end
            
            -- Check for common game state indicators
            local gameState = game:GetService("ReplicatedStorage"):FindFirstChild("GameState")
            if gameState and gameState.Value == "Lobby" then
                if not getgenv().shopLoaded then
                    loadShop()
                end
            end
            
            -- Force reload shop if require hook was overwritten
            if require ~= getgenv().require then
                require = getgenv().require
                getgenv().shopLoaded = false
                loadShop()
            end
        end
    end)
end

-- Direct fix for MacSploit/Nexus42 issues
local function applyMacSploitFix()
    -- Create a global function that can be called from anywhere
    getgenv().reloadShop = function()
        getgenv().shopLoaded = false
        return loadShop()
    end
    
    -- Create a UI button to manually reload shop if needed
    pcall(function()
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "ShopReloader"
        screenGui.ResetOnSpawn = false
        
        -- Try to parent to CoreGui for persistence
        pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
        if not screenGui.Parent then screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end
        
        -- Create reload button
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 100, 0, 30)
        button.Position = UDim2.new(0, 10, 0, 10)
        button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Text = "Reload Shop"
        button.BorderSizePixel = 0
        button.Parent = screenGui
        
        -- Add rounded corners
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = button
        
        -- Add click handler
        button.MouseButton1Click:Connect(function()
            getgenv().reloadShop()
        end)
    end)
    
    -- Hook into key game events that might indicate a round restart
    
    -- 1. Monitor workspace changes
    workspace.ChildAdded:Connect(function(child)
        if child.Name == "Lobby" or child.Name == "Intermission" then
            task.wait(1)
            getgenv().shopLoaded = false
            loadShop()
        end
    end)
    
    -- 2. Monitor player state changes
    game:GetService("Players").LocalPlayer.PlayerGui.ChildAdded:Connect(function(child)
        if child.Name:find("Lobby") or child.Name:find("Menu") then
            task.wait(1)
            getgenv().shopLoaded = false
            loadShop()
        end
    end)
    
    -- 3. Create a periodic force check
    spawn(function()
        while wait(15) do
            if not getgenv().shopLoaded then
                loadShop()
            end
        end
    end)
end

-- Run everything
loadShop()
setupGameStateDetection()
applyMacSploitFix()

-- Notify user
game.StarterGui:SetCore("SendNotification", {
    Title = "Shop Fix",
    Text = "Shop fix is active! Press the Reload Shop button if needed.",
    Duration = 5
})
