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

-- Create folders first
for _, folder in pairs({'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'}) do
    if not isfolder(folder) then
        pcall(function() makefolder(folder) end)
    end
end

-- Set default commit if needed
if not isfile('newvape/profiles/commit.txt') then
    pcall(function() writefile('newvape/profiles/commit.txt', 'main') end)
end

local function downloadFile(path, func)
    if not isfile(path) then
        local commit = 'main'
        pcall(function() commit = readfile('newvape/profiles/commit.txt') end)
        
        local suc, res = pcall(function()
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
    
    local readSuc, content = pcall(function() return (func or readfile)(path) end)
    if not readSuc then
        warn("Failed to read file: " .. path)
        return nil
    end
    
    return content
end

local function wipeFolder(path)
    if not isfolder(path) then return end
    
    local listSuc, files = pcall(function() return listfiles(path) end)
    if not listSuc then return end
    
    for _, file in pairs(files) do
        if file:find('loader') then continue end
        
        local readSuc, content = pcall(function() return readfile(file) end)
        if readSuc and content and content:find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.') == 1 then
            delfile(file)
        end
    end
end

-- Update files if needed
if not shared.VapeDeveloper then
    local commitSuc, subbed = pcall(function()
        return game:HttpGet('https://github.com/R12sa/TRIPLESREALVAPE')
    end)
    
    if commitSuc and subbed then
        local commit = subbed:find('currentOid')
        commit = commit and subbed:sub(commit + 13, commit + 52) or nil
        commit = commit and #commit == 40 and commit or 'main'
        
        local oldCommit = ''
        pcall(function() 
            if isfile('newvape/profiles/commit.txt') then
                oldCommit = readfile('newvape/profiles/commit.txt')
            end
        end)
        
        if commit == 'main' or oldCommit ~= commit then
            wipeFolder('newvape')
            wipeFolder('newvape/games')
            wipeFolder('newvape/guis')
            wipeFolder('newvape/libraries')
            
            pcall(function() writefile('newvape/profiles/commit.txt', commit) end)
        end
    end
end

-- Download main.lua
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

-- Fix for the SetGlobalData error
local fixedContent = mainContent:gsub("(%w+)%.SetGlobalData", function(varName)
    return "if " .. varName .. " and " .. varName .. ".SetGlobalData then " .. varName .. ".SetGlobalData"
end)

-- Add global data fallback
fixedContent = [[
-- Global data fallback
if not shared.GlobalData then
    shared.GlobalData = {}
end

getgenv().SetGlobalData = function(key, value)
    if not shared.GlobalData then shared.GlobalData = {} end
    shared.GlobalData[key] = value
end

getgenv().GetGlobalData = function(key)
    if not shared.GlobalData then return nil end
    return shared.GlobalData[key]
end

]] .. fixedContent

-- Load the fixed script
local success, err = pcall(function()
    loadstring(fixedContent, 'main')()
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
