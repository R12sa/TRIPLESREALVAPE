-- Set up require hook
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

-- Create necessary folders first
for _, folder in pairs({'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'}) do
    if not isfolder(folder) then
        pcall(function() makefolder(folder) end)
    end
end

-- Set a default commit if needed
if not isfile('newvape/profiles/commit.txt') then
    pcall(function() writefile('newvape/profiles/commit.txt', 'main') end)
end

-- Download file function with better error handling
local function downloadFile(path, func)
    if not isfile(path) then
        local commit = 'main'
        pcall(function() 
            commit = readfile('newvape/profiles/commit.txt')
        end)
        
        local url = 'https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/' .. commit .. '/' .. path:gsub('newvape/', '')
        local suc, res = pcall(function()
            return game:HttpGet(url, true)
        end)
        
        if not suc then
            warn("Failed to download file: HTTP request failed")
            warn("URL: " .. url)
            warn("Error: " .. tostring(res))
            return nil
        end
        
        if res == '404: Not Found' then
            warn("Failed to download file: 404 Not Found")
            warn("URL: " .. url)
            return nil
        end
        
        if path:find('.lua') then
            res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
        end
        
        local writeSuc, writeErr = pcall(function() writefile(path, res) end)
        if not writeSuc then
            warn("Failed to write file: " .. tostring(writeErr))
            return res -- Still return the content even if we couldn't write it
        end
    end
    
    -- Read the file
    local readSuc, readRes = pcall(function() 
        return (func or readfile)(path) 
    end)
    
    if not readSuc then
        warn("Failed to read file: " .. tostring(readRes))
        return nil
    end
    
    return readRes
end

local function wipeFolder(path)
    if not isfolder(path) then return end
    
    local listSuc, files = pcall(function() return listfiles(path) end)
    if not listSuc or not files then
        warn("Failed to list files in folder: " .. path)
        return
    end
    
    for _, file in pairs(files) do
        if file:find('loader') then continue end
        
        local readSuc, content = pcall(function() return readfile(file) end)
        if readSuc and content and content:find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.') == 1 then
            delfile(file)
        end
    end
end

-- Get latest commit
local function getLatestCommit()
    local retries = 3
    
    while retries > 0 do
        local success, response = pcall(function()
            return game:HttpGet('https://github.com/R12sa/TRIPLESREALVAPE')
        end)
        
        if success and response then
            local commitPos = response:find('currentOid')
            if commitPos then
                local commit = response:sub(commitPos + 13, commitPos + 52)
                if commit and #commit == 40 then
                    return commit
                end
            end
            break
        end
        
        retries = retries - 1
        wait(1)
    end
    
    return 'main' -- Default to main if we can't get the commit
end

-- Update files if needed
if not shared.VapeDeveloper then
    local commit = getLatestCommit()
    local oldCommit = 'main'
    
    pcall(function() 
        if isfile('newvape/profiles/commit.txt') then
            oldCommit = readfile('newvape/profiles/commit.txt')
        end
    end)
    
    if commit == 'main' or oldCommit ~= commit then
        -- Wipe folders if commit changed
        wipeFolder('newvape')
        wipeFolder('newvape/games')
        wipeFolder('newvape/guis')
        wipeFolder('newvape/libraries')
        
        -- Update commit file
        pcall(function() writefile('newvape/profiles/commit.txt', commit) end)
    end
end

-- Load main script with detailed error handling
local mainContent = downloadFile('newvape/main.lua')

if not mainContent then
    warn("Failed to get main.lua content")
    game.StarterGui:SetCore("SendNotification", {
        Title = "Error",
        Text = "Failed to download main script",
        Duration = 5
    })
else
    local success, err = pcall(function()
        loadstring(mainContent, 'main')()
    end)
    
    if not success then
        warn("Failed to load script: " .. tostring(err))
        game.StarterGui:SetCore("SendNotification", {
            Title = "Error",
            Text = "Failed to execute script: " .. tostring(err),
            Duration = 5
        })
    else
        game.StarterGui:SetCore("SendNotification", {
            Title = "Success",
            Text = "Script loaded successfully!",
            Duration = 2
        })
    end
end
