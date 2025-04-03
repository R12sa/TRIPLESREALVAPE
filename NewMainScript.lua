local old_require = require
getgenv().require = function(path)
    setthreadidentity(2)
    local _ = old_require(path)
    setthreadidentity(8)
    return _
end

-- File system utilities
local isfile = isfile or function(file)
    local suc, res = pcall(function() return readfile(file) end)
    return suc and res ~= nil and res ~= ''
end

local delfile = delfile or function(file)
    pcall(function() writefile(file, '') end)
end

-- Download file with improved error handling
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

-- Wipe folder
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

-- Check for updates
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

-- Bedwars shop fix function
local function fixBedwarsShop()
    if game.PlaceId ~= 6872274481 then return end
    
    -- Wait for the player to be fully loaded
    repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer and game.Players.LocalPlayer.Character
    
    -- Find the Bedwars shop controller
    local function getShopController()
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "table" and rawget(obj, "OpenShop") and rawget(obj, "CloseShop") then
                return obj
            end
        end
        return nil
    end
    
    -- Try to get the shop controller
    local shopController = getShopController()
    if not shopController then
        warn("Could not find Bedwars shop controller")
        return
    end
    
    -- Create a custom shop opener function
    local function openShop()
        local success, err = pcall(function()
            -- Try to call the original function
            shopController.OpenShop(shopController)
        end)
        
        if not success then
            warn("Failed to open shop:", err)
            
            -- Try direct GUI manipulation as fallback
            local player = game.Players.LocalPlayer
            if player and player.PlayerGui then
                local shopGui = player.PlayerGui:FindFirstChild("BedwarsShop")
                if shopGui then
                    shopGui.Enabled = true
                end
            end
        end
    end
    
    -- Add a keybind to open the shop (B key)
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.B then
            openShop()
        end
    end)
    
    -- Add a command to open the shop
    if shared.vape and shared.vape.Commands then
        shared.vape.Commands.register({
            ["Name"] = "shop",
            ["Function"] = function()
                openShop()
                return "Opened shop"
            end
        })
    end
    
    print("Bedwars shop fix applied - Press B to open shop or use /shop command")
end

-- Load main script
local success, err = pcall(function()
    loadstring(downloadFile('newvape/main.lua'), 'main')()
end)

if not success then
    warn("Failed to load script: " .. tostring(err))
else
    -- Apply the shop fix after everything is loaded
    if game.PlaceId == 6872274481 then
        task.delay(5, fixBedwarsShop)
    end
end
