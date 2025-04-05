-- Ultra Simple Shop Fix for MacSploit/Nexus42
-- This script focuses only on the core functionality

-- Hook the require function (this is the critical part)
local original_require = require
getgenv().require = function(path)
    setthreadidentity(2)
    local result = original_require(path)
    setthreadidentity(8)
    return result
end

-- Create folders
for _, folder in pairs({'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'}) do
    if not isfolder(folder) then
        pcall(function() makefolder(folder) end)
    end
end

-- Get commit ID
local function getCommit()
    local success, response = pcall(function()
        return game:HttpGet('https://github.com/R12sa/TRIPLESREALVAPE')
    end)
    
    if success and response then
        local commit = response:find('currentOid')
        if commit then
            commit = response:sub(commit + 13, commit + 52)
            if #commit == 40 then
                return commit
            end
        end
    end
    
    return 'main'
end

-- Download file
local function downloadFile(path)
    local commit = 'main'
    pcall(function()
        if isfile('newvape/profiles/commit.txt') then
            commit = readfile('newvape/profiles/commit.txt')
        else
            commit = getCommit()
            writefile('newvape/profiles/commit.txt', commit)
        end
    end)
    
    local success, result = pcall(function()
        return game:HttpGet('https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/' .. commit .. '/' .. path:gsub('newvape/', ''), true)
    end)
    
    if success and result and result ~= '404: Not Found' then
        if path:find('.lua') then
            result = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. result
        end
        writefile(path, result)
        return result
    end
    
    return nil
end

-- Load shop
local function loadShop()
    -- Download and load main.lua
    local mainScript = nil
    
    -- Try to read existing file first
    if isfile('newvape/main.lua') then
        mainScript = readfile('newvape/main.lua')
    else
        -- Download if not exists
        mainScript = downloadFile('newvape/main.lua')
    end
    
    if mainScript then
        local success, err = pcall(function()
            loadstring(mainScript, 'main')()
        end)
        
        if success then
            game.StarterGui:SetCore("SendNotification", {
                Title = "Shop Loaded",
                Text = "Shop is now available!",
                Duration = 2
            })
            return true
        else
            warn("Shop error: " .. tostring(err))
            game.StarterGui:SetCore("SendNotification", {
                Title = "Shop Error",
                Text = tostring(err),
                Duration = 5
            })
        end
    else
        warn("Failed to get main script")
        game.StarterGui:SetCore("SendNotification", {
            Title = "Shop Error",
            Text = "Failed to download main script",
            Duration = 5
        })
    end
    
    return false
end

-- Load shop immediately
loadShop()

-- Create a button to reload shop
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopReloader"
screenGui.ResetOnSpawn = false

-- Try to parent to CoreGui for persistence
pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not screenGui.Parent then 
    screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") 
end

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
    loadShop()
end)

-- Create global function to reload shop
getgenv().reloadShop = loadShop

-- Set up auto-reload on character spawn
game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    loadShop()
end)

-- Print instructions
print("Shop loaded! If shop stops working, click the 'Reload Shop' button in the top-left corner")
print("You can also type 'reloadShop()' in the console to reload the shop")
