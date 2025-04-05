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

-- Create a custom version of the main script with XFunctions fix
local function createCustomMainScript()
    -- First download XFunctions.lua
    local xfunctionsContent = game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/main/libraries/XFunctions.lua', true)
    
    if not xfunctionsContent then
        handleError("Failed to download XFunctions.lua", "download")
        return nil
    end
    
    -- Write XFunctions.lua to file
    pcall(function() 
        writefile('newvape/libraries/XFunctions.lua', '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. xfunctionsContent) 
    end)
    
    -- Download main.lua
    local mainContent = game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/main/main.lua', true)
    
    if not mainContent then
        handleError("Failed to download main.lua", "download")
        return nil
    end
    
    -- Write main.lua to file
    pcall(function() 
        writefile('newvape/main.lua', '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. mainContent) 
    end)
    
    -- Create a custom script that loads XFunctions first
    local customScript = [[
        --This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
        repeat task.wait() until game:IsLoaded()
        
        -- Load XFunctions first
        local XFunctions = loadstring(readfile('newvape/libraries/XFunctions.lua'), 'XFunctions')()
        shared.XFunctions = XFunctions
        
        -- Now load the main script
        loadstring(readfile('newvape/main.lua'), 'main')()
    ]]
    
    return customScript
end

-- Create and execute the custom script
local customScript = createCustomMainScript()

if not customScript then
    handleError("Failed to create custom script", "preparation")
    return
end

-- Execute the custom script
local success, result = pcall(function()
    return loadstring(customScript, 'custom_main')()
end)

if not success then
    handleError(result, "execution")
else
    game.StarterGui:SetCore("SendNotification", {
        Title = "Success",
        Text = "Script loaded successfully!",
        Duration = 2
    })
end
