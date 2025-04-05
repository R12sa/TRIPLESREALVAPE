-- Set up error handling
local function handleError(err, stage)
    warn("Error at " .. stage .. ": " .. tostring(err))
    game.StarterGui:SetCore("SendNotification", {
        Title = "Error at " .. stage,
        Text = tostring(err),
        Duration = 5
    })
end

-- Try to set up require hook
local success, err = pcall(function()
    local old_require = require
    getgenv().require = function(path)
        local success, result = pcall(function()
            setthreadidentity(2)
            local _ = old_require(path)
            setthreadidentity(8)
            return _
        end)
        
        if not success then
            warn("Require error: " .. tostring(result))
            return nil
        end
        
        return result
    end
end)

if not success then
    handleError(err, "require setup")
end

-- Set up GlobalData and XFunctions to prevent errors
if not shared.GlobalData then
    shared.GlobalData = {}
end

-- Create a dummy XFunctions object with SetGlobalData method
if not shared.XFunctions then
    shared.XFunctions = {
        SetGlobalData = function(self, key, value)
            if not shared.GlobalData then shared.GlobalData = {} end
            shared.GlobalData[key] = value
            return value
        end,
        GetGlobalData = function(self, key)
            if not shared.GlobalData then return nil end
            return shared.GlobalData[key]
        end
    }
end

-- Add global functions to handle XFunctions calls
getgenv().SetGlobalData = function(key, value)
    if not shared.GlobalData then shared.GlobalData = {} end
    shared.GlobalData[key] = value
    return value
end

getgenv().GetGlobalData = function(key)
    if not shared.GlobalData then return nil end
    return shared.GlobalData[key]
end

-- Define file functions with error handling
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
            return game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/main/' .. select(1, path:gsub('newvape/', '')), true)
        end)
        
        if not suc or res == '404: Not Found' then
            warn("Failed to download file: " .. path .. " - " .. tostring(res))
            return nil
        end
        
        if path:find('.lua') then
            res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
        end
        
        pcall(function() writefile(path, res) end)
    end
    
    local content
    pcall(function() content = (func or readfile)(path) end)
    return content
end

-- Create folders
pcall(function()
    for _, folder in pairs({'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'}) do
        if not isfolder(folder) then
            pcall(function() makefolder(folder) end)
        end
    end
end)

-- Write commit file if it doesn't exist
if not isfile('newvape/profiles/commit.txt') then
    pcall(function() writefile('newvape/profiles/commit.txt', 'main') end)
end

-- Modify the environment to include XFunctions
local env = getfenv(0)
env.XFunctions = shared.XFunctions

-- Download and execute main script
local mainContent = downloadFile('newvape/main.lua')

if not mainContent then
    handleError("Failed to download main.lua", "download")
    return
end

-- Execute main script with error handling and custom environment
local mainFunc, loadErr = loadstring(mainContent, 'main')
if not mainFunc then
    handleError(loadErr, "loading")
    return
end

-- Set the environment for the main function
setfenv(mainFunc, env)

-- Execute the main function
local success, result = pcall(mainFunc)

if not success then
    handleError(result, "execution")
else
    game.StarterGui:SetCore("SendNotification", {
        Title = "Success",
        Text = "Script loaded successfully!",
        Duration = 2
    })
end
