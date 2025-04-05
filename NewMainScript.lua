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

-- Set default GUI to new if not set
if not isfile('newvape/profiles/gui.txt') then
    pcall(function() writefile('newvape/profiles/gui.txt', 'new') end)
end

-- Function to load the main script
local function loadMainScript()
    -- First, check for updates and set commit
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
        else
            -- If we can't get the commit, just use main
            pcall(function() writefile('newvape/profiles/commit.txt', 'main') end)
        end
    end

    -- Download and write a fixed main.lua that handles the utils_functions issue
    local fixedMainLua = [[--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

-- Loading the crash prevention script
pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/main/CrashPrevention.lua"))() end)

-- why do exploits fail to implement anything correctly? Is it really that hard?
if identifyexecutor then
    if table.find({'Argon', 'Wave'}, ({identifyexecutor()})[1]) then
        getgenv().setthreadidentity = nil
    end
end

local vape
local loadstring = function(...)
    local res, err = loadstring(...)
    if err and vape then
        vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
    end
    return res
end

local queue_on_teleport = queue_on_teleport or function() end

local isfile = isfile or function(file)
    local suc, res = pcall(function()
        return readfile(file)
    end)
    return suc and res ~= nil and res ~= ''
end

local cloneref = cloneref or function(obj)
    return obj
end

local playersService = cloneref(game:GetService('Players'))

local function downloadFile(path, func)
    if not isfile(path) then
        local suc, res = pcall(function()
            return game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
        end)
        if not suc or res == '404: Not Found' then
            error(res)
        end
        if path:find('.lua') then
            res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
        end
        writefile(path, res)
    end
    return (func or readfile)(path)
end

local function finishLoading()
    vape.Init = nil
    vape:Load()
    task.spawn(function()
        repeat
            vape:Save()
            task.wait(10)
        until not vape.Loaded
    end)
    local teleportedServers
    vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
        if (not teleportedServers) and (not shared.VapeIndependent) then
            teleportedServers = true
            local teleportScript = "script_key = '"..(getgenv().script_key or "")..[[';
            getgenv().script_key = script_key
            
            shared.vapereload = true
            
            if shared.VapeDeveloper then
                loadstring(readfile('newvape/loader.lua'), 'loader')()
            else
                loadstring(game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
            end
            ]]
            if shared.VapeDeveloper then
                teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
            end
            if shared.VapeCustomProfile then
                teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
            end
            vape:Save()
            queue_on_teleport(teleportScript)
        end
    end))
    if not shared.vapereload then
        if not vape.Categories then return end
        if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
            vape:CreateNotification('Finished Loading', vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI', 5)
        end
    end
end

if not isfile('newvape/profiles/gui.txt') then
    writefile('newvape/profiles/gui.txt', 'new')
end

local gui = readfile('newvape/profiles/gui.txt')
if not isfolder('newvape/assets/'..gui) then
    makefolder('newvape/assets/'..gui)
end

vape = loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
shared.vape = vape

local XFunctions = loadstring(downloadFile('newvape/libraries/XFunctions.lua'), 'XFunctions')()
XFunctions:SetGlobalData('XFunctions', XFunctions)
XFunctions:SetGlobalData('vape', vape)

local PerformanceModule = loadstring(downloadFile('newvape/libraries/performance.lua'), 'Performance')()
XFunctions:SetGlobalData('Performance', PerformanceModule)

-- Fixed utils_functions loading with error handling
local utils_functions
local success, result = pcall(function()
    return loadstring(downloadFile('newvape/libraries/utils.lua'), 'Utils')()
end)

if success and result then
    utils_functions = result
    for i, v in pairs(utils_functions or {}) do
        getfenv()[i] = v
    end
else
    warn("Failed to load utils_functions: " .. tostring(result))
end

getgenv().InfoNotification = function(title, msg, dur)
    warn('info', tostring(title), tostring(msg), tostring(dur))
    vape:CreateNotification(title, msg, dur)
end

getgenv().warningNotification = function(title, msg, dur)
    warn('warn', tostring(title), tostring(msg), tostring(dur))
    vape:CreateNotification(title, msg, dur, 'warning')
end

getgenv().errorNotification = function(title, msg, dur)
    warn("error", tostring(title), tostring(msg), tostring(dur))
    vape:CreateNotification(title, msg, dur, 'alert')
end

if not shared.VapeIndependent then
    loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
    loadstring(downloadFile('newvape/games/modules.lua'), 'modules')()
    if isfile('newvape/games/'..game.PlaceId..'.lua') then
        loadstring(readfile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
    else
        if not shared.VapeDeveloper then
            local suc, res = pcall(function()
                return game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/'..readfile('newvape/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
            end)
            if suc and res ~= '404: Not Found' then
                loadstring(downloadFile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
            end
        end
    end
    finishLoading()
else
    vape.Init = finishLoading
    return vape
end

shared.VapeFullyLoaded = true
]]

    -- Write the fixed main.lua
    pcall(function() writefile('newvape/fixed_main.lua', fixedMainLua) end)

    -- Load script safely
    local success, err = pcall(function()
        loadstring(readfile('newvape/fixed_main.lua'), 'fixed_main')()
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
