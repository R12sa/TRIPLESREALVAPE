local old_require = require
getgenv().require = function(path)
    setthreadidentity(2)
    local _ = old_require(path)
    setthreadidentity(8)
    return _
end

-- Your repository information
local repo_owner = "R12sa"
local repo_name = "TRIPLESREALVAPE"
local branch = "main"

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
            return game:HttpGet('https://raw.githubusercontent.com/' .. repo_owner .. '/' .. repo_name .. '/' .. branch .. '/' .. select(1, path:gsub('triplevape/', '')), true)
        end)
        if not suc or res == '404: Not Found' then
            warn("Failed to download file: " .. tostring(res))
            return nil
        end
        if path:find('.lua') then
            res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after updates.\n' .. res
        end
        pcall(function() writefile(path, res) end)
    end
    return (func or readfile)(path)
end

local function wipeFolder(path)
    if not isfolder(path) then return end
    for _, file in listfiles(path) do
        if file:find('loader') then continue end
        if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after updates.')) == 1 then
            delfile(file)
        end
    end
end

-- Create necessary folders
for _, folder in {'triplevape', 'triplevape/games', 'triplevape/profiles', 'triplevape/assets', 'triplevape/libraries', 'triplevape/guis'} do
    if not isfolder(folder) then
        pcall(function() makefolder(folder) end)
    end
end

-- Check for updates
if not shared.VapeDeveloper then
    local _, subbed = pcall(function()
        return game:HttpGet('https://github.com/' .. repo_owner .. '/' .. repo_name)
    end)
    if subbed then
        local commit = subbed:find('currentOid')
        commit = commit and subbed:sub(commit + 13, commit + 52) or nil
        commit = commit and #commit == 40 and commit or branch
        if commit == branch or (isfile('triplevape/profiles/commit.txt') and readfile('triplevape/profiles/commit.txt') or '') ~= commit then
            wipeFolder('triplevape')
            wipeFolder('triplevape/games')
            wipeFolder('triplevape/guis')
            wipeFolder('triplevape/libraries')
        end
        pcall(function() writefile('triplevape/profiles/commit.txt', commit) end)
    end
end

-- Load the main script
local success, err = pcall(function()
    loadstring(downloadFile('triplevape/main.lua'), 'main')()
end)
if not success then
    warn("Failed to load script: " .. tostring(err))
    game.StarterGui:SetCore("SendNotification", {
        Title = "Script Error",
        Text = "Failed to load. Check console for details.",
        Duration = 5
    })
end
