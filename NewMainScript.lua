local old_require = require
getgenv().require = function(path)
    setthreadidentity(2)
    local _ = old_require(path)
    setthreadidentity(8)
    return _
end

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

-- Create folders
for _, folder in pairs({'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'}) do
    if not isfolder(folder) then
        pcall(function() makefolder(folder) end)
    end
end

-- Write commit file
pcall(function() writefile('newvape/profiles/commit.txt', 'main') end)

-- Pre-download essential files to ensure they exist
local essentialFiles = {
    'newvape/libraries/XFunctions.lua',
    'newvape/libraries/utils.lua',
    'newvape/libraries/performance.lua',
    'newvape/guis/new.lua'
}

-- Make sure gui.txt exists
if not isfile('newvape/profiles/gui.txt') then
    pcall(function() writefile('newvape/profiles/gui.txt', 'new') end)
end

-- Pre-download essential files
for _, file in pairs(essentialFiles) do
    local content = downloadFile(file)
    if not content then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Error",
            Text = "Failed to download: " .. file,
            Duration = 5
        })
    end
end

-- Create a custom main script that handles the utils_functions issue
local customMainScript = [[
--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

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
            return game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/main/'..select(1, path:gsub('newvape/', '')), true)
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
            local teleportScript = [[
                shared.vapereload = true
                if shared.VapeDeveloper then
                    loadstring(readfile('newvape/loader.lua'), 'loader')()
                else
                    loadstring(game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/main/loader.lua', true), 'loader')()
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
if XFunctions then
    XFunctions:SetGlobalData('XFunctions', XFunctions)
    XFunctions:SetGlobalData('vape', vape)
else
    warn("Failed to load XFunctions")
    return
end

local PerformanceModule = loadstring(downloadFile('newvape/libraries/performance.lua'), 'Performance')()
if PerformanceModule and XFunctions then
    XFunctions:SetGlobalData('Performance', PerformanceModule)
end

-- Handle utils_functions safely
local utils_functions
local success, result = pcall(function()
    utils_functions = loadstring(downloadFile('newvape/libraries/utils.lua'), 'Utils')()
end)

if success and utils_functions then
    for i, v in pairs(utils_functions) do
        if type(v) == "function" then
            getfenv()[i] = v
        end
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
                return game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/main/games/'..game.PlaceId..'.lua', true)
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

-- Write the custom main script
pcall(function() writefile('newvape/custom_main.lua', customMainScript) end)

-- Execute the custom main script
local success, err = pcall(function()
    loadstring(readfile('newvape/custom_main.lua'), 'custom_main')()
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
