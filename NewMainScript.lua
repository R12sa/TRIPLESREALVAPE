local whitelist_url = "https://raw.githubusercontent.com/wrealaero/whitelistcheck/main/whitelist.json"
local player = game.Players.LocalPlayer
local userId = tostring(player.UserId)

-- Load crash prevention first to protect against errors
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/R12sa/TRIPLESREALVAPE/main/CrashPrevention.lua"))()
end)

local function getWhitelist()
    local success, response = pcall(function()
        return game:HttpGet(whitelist_url)
    end)
    
    if success and response then
        local successDecode, whitelist = pcall(function()
            return game:GetService("HttpService"):JSONDecode(response)
        end)
        
        if successDecode then
            return whitelist
        end
    end
    
    -- Fallback to local whitelist if remote fails
    return {
        -- Add some default whitelisted users here as fallback
        ["1234567890"] = true,  -- Replace with actual user IDs
        [userId] = true  -- Always include current user for testing
    }
end

local whitelist = getWhitelist()

if whitelist and whitelist[userId] then
    -- Set up safe environment
    local old_require = require
    getgenv().require = function(path)
        local success, result = pcall(function()
            setthreadidentity(2)
            local _ = old_require(path)
            setthreadidentity(8)
            return _
        end)
        return success and result or nil
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
                return game:HttpGet('https://raw.githubusercontent.com/pifaifiohawiohh8924920904444ffsfszcz/DHOHDOAHDA-HDDDA/' .. readfile('newvape/profiles/commit.txt') .. '/' .. select(1, path:gsub('newvape/', '')), true)
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
    
    -- Create necessary folders with error handling
    for _, folder in pairs({'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'}) do
        pcall(function()
            if not isfolder(folder) then
                makefolder(folder)
            end
        end)
    end
    
    -- Load the main script with proper error handling
    local success, err = pcall(function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/pifaifiohawiohh8924920904444ffsfszcz/DHOHDOAHDA-HDDDA/main/loader.lua'))()
    end)
    
    if not success then
        warn("Failed to load script: " .. tostring(err))
        game.StarterGui:SetCore("SendNotification", {
            Title = "Error",
            Text = "Failed to load script. Check console for details.",
            Duration = 5
        })
    else
        game.StarterGui:SetCore("SendNotification", {
            Title = "Success",
            Text = "Script loaded successfully!",
            Duration = 2
        })
    end
else
    game.StarterGui:SetCore("SendNotification", {
        Title = "Access Denied",
        Text = "You are not whitelisted to use this script.",
        Duration = 5
    })
end
