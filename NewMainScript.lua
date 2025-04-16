-- Loader script for Triple C Bowl
-- This script loads both the crash prevention and main script

-- First, check if the game is loaded
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Wait for player to be available
local Players = game:GetService("Players")
while not Players.LocalPlayer do
    Players.PlayerAdded:Wait()
end

-- Load the crash prevention first
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/R12sa/triplecrobowl/main/CrashPrevention.lua"))()
end)

-- Then load the main script
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/R12sa/triplecrobowl/main/MainScript.lua"))()
end)

-- Notify user
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Triple C Bowl",
    Text = "Script loaded successfully!",
    Duration = 3
})
