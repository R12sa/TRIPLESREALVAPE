local old_require = require
getgenv().require = function(path)
    setthreadidentity(2)
    local _ = old_require(path)
    setthreadidentity(8)
    return _
end

-- Initialize global data
if not shared.GlobalData then
    shared.GlobalData = {}
end

-- Define global data functions
getgenv().SetGlobalData = function(key, value)
    if not shared.GlobalData then shared.GlobalData = {} end
    shared.GlobalData[key] = value
end

getgenv().GetGlobalData = function(key)
    if not shared.GlobalData then return nil end
    return shared.GlobalData[key]
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
            local commit = isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or 'main'
            return game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/' .. commit .. '/' .. select(1, path:gsub('newvape/', '')), true)
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

for _, folder in pairs({'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'}) do
    if not isfolder(folder) then
        pcall(function() makefolder(folder) end)
    end
end

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
local mainContent = downloadFile('newvape/main.lua')
if not mainContent then
    warn("Failed to download main.lua")
    game.StarterGui:SetCore("SendNotification", {
        Title = "Error",
        Text = "Failed to download main script",
        Duration = 5
    })
    return
end

local success, err = pcall(function()
    loadstring(mainContent, 'main')()
end)

if not success then
    warn("Failed to load script: " .. tostring(err))
    game.StarterGui:SetCore("SendNotification", {
        Title = "Error",
        Text = "Failed to load script: " .. tostring(err),
        Duration = 5
    })
else
    game.StarterGui:SetCore("SendNotification", {
        Title = "Success",
        Text = "Script loaded successfully!",
        Duration = 2
    })
end
