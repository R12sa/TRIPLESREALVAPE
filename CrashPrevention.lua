-- crashprevention script (in beta rn) gonna make it better as time goes on
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local httpService = game:GetService("HttpService")
local teleportService = game:GetService("TeleportService")
local localPlayer = players.LocalPlayer
local lastHeartbeat = tick()
local crashLog = {}
local fpsDropTime = 0
local memOverloadTime = 0
local freezeCount = 0
local criticalMemoryThreshold = 500 -- cleans memeory if it goes over 500
local freezeThreshold = 5 -- If no heartbeat in 5 secs (it infers roblox is freezing)
local fpsThreshold = 20 -- gets an alert if FPS is below this

local function log(txt)
    local logMsg = os.date("[%X] ") .. txt
    table.insert(crashLog, logMsg)
    print("[Crash Helper] " .. txt)
    pcall(function()
        writefile("CrashLog.txt", httpService:JSONEncode(crashLog))
    end)
end

local function safeCollectGarbage()
    local mem = collectgarbage("count") / 1024 -- Check if memory's too high
    if mem > criticalMemoryThreshold then
        log("Yo, memory's at " .. math.floor(mem) .. "MB. Time to clean up.")
        task.wait(0.5) 
        collectgarbage()
        task.wait(1)
        log("Memory cleaned. Now at: " .. math.floor(collectgarbage("count") / 1024) .. "MB")
    end
end

local function monitorMemory()
    while task.wait(10) do 
        safeCollectGarbage()
    end
end

local function monitorFPS()
    while task.wait(3) do 
        local fps = math.floor(1 / runService.RenderStepped:Wait())
        if fps < fpsThreshold then
            fpsDropTime = fpsDropTime + 1
            if fpsDropTime >= 2 then -- Less aggressive warnings
                log("FPS is tanking: " .. fps .. " FPS. Might wanna tweak your settings.")
                fpsDropTime = 0
            end
        else
            fpsDropTime = 0
        end
    end
end

local function monitorFreeze()
    while task.wait(3) do 
        if tick() - lastHeartbeat > freezeThreshold then
            freezeCount = freezeCount + 1
            log("Yo, game froze. That's " .. freezeCount .. " times now.")
            if freezeCount >= 3 then
                log("Game has been caught freezing try, lowering them graphics or restart.")
                freezeCount = 0
            end
        else
            freezeCount = 0
        end
    end
end

local function monitorPlayer()
    while task.wait(10) do 
        if not players.LocalPlayer then
            log("Local player is missing, might crash")
            task.wait(2)
            if not players.LocalPlayer then
                log("Yup, that's a bad one. Restart Roblox if you see this.")
            end
        end
    end
end

local function autoReconnect()
    while task.wait(15) do
        if not localPlayer or not localPlayer.Parent then
            log("Game crashed Trying to reconnect in 5 seconds...")
            task.wait(5)
            teleportService:Teleport(game.PlaceId)
        end
    end
end

runService.Heartbeat:Connect(function()
    lastHeartbeat = tick()
end)

task.spawn(monitorMemory)
task.spawn(monitorFPS)
task.spawn(monitorFreeze)
task.spawn(monitorPlayer)
task.spawn(autoReconnect)

log("Crash Prevention System Loaded. If you're still crashing, blame that Wi-Fi, fam.")
