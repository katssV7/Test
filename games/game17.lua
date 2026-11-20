-- Sevoice | Rod And Reef - Auto Fishing (FishingSystem remotes)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Loop: CastReplication -> RollFishFunction -> FishGiver -> CleanupCast
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "Sevoice",
    Version   = "v1.0",
    Game      = "Rod And Reef",
    Folder    = "Sevoice/RodAndReef",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

-- ===== SETTINGS =====
local CFG = {
    delay   = 0.5,              -- seconds between each step (0.01 - 5)
    rod     = "Eternal Flower", -- rod name sent to the server
    power   = 100,              -- cast power
}
local stats = { casts = 0, fish = 0, fail = 0, status = "idle" }
local run, running = 0, false

local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function wait(id, t)   -- cancellable sleep
    local t0 = os.clock()
    while os.clock() - t0 < t do
        task.wait(math.min(0.05, math.max(t - (os.clock() - t0), 0.005)))
        if run ~= id then return false end
    end
    return run == id
end

-- ===== remotes =====
local FS = RS:WaitForChild("FishingSystem", 10)
local function remote(name) return FS and FS:WaitForChild(name, 10) end

-- ===== auto fishing =====
local function castArgs()
    local r = Root()
    local look = r and r.CFrame.LookVector or Vector3.new(0, 0, -1)
    local start = r and (r.Position + look * 2) or Vector3.zero
    local dir = Vector3.new(look.X * 16, 5, look.Z * 16)
    local hook = start + Vector3.new(dir.X * 0.45, -18, dir.Z * 0.45)
    return start, dir, hook
end

local function cycle(id)
    local Cast, Roll, Giver, Cleanup =
        remote("CastReplication"), remote("RollFishFunction"), remote("FishGiver"), remote("CleanupCast")
    if not (Cast and Roll and Giver and Cleanup) then
        stats.status = "remote tidak ketemu"; return false
    end

    -- 1) cast
    stats.status = "casting"
    local start, dir, hook = castArgs()
    local ok = pcall(function() Cast:FireServer(start, dir, CFG.rod, CFG.power, false) end)
    if not ok then stats.fail += 1; return true end
    stats.casts += 1
    if not wait(id, CFG.delay) then return false end

    -- 2) minigame
    stats.status = "minigame"
    local ok2, res = pcall(function() return Roll:InvokeServer(CFG.rod, 0) end)
    if not wait(id, CFG.delay) then return false end

    -- 3) fish giver (uses the fish returned by the server when available)
    stats.status = "fish giver"
    if ok2 then
        local info = {
            hookPosition = hook,
            name = "Unknown", rarity = "Common", weight = 1,
        }
        if type(res) == "table" then
            info.hookPosition = res.hookPosition or hook
            info.name   = res.name   or res.Name   or info.name
            info.rarity = res.rarity or res.Rarity or info.rarity
            info.weight = res.weight or res.Weight or info.weight
        end
        local ok3 = pcall(function() Giver:FireServer(info) end)
        if ok3 then stats.fish += 1 else stats.fail += 1 end
    else
        stats.fail += 1
    end
    if not wait(id, CFG.delay) then return false end

    -- 4) cleanup
    stats.status = "cleanup"
    pcall(function() Cleanup:FireServer() end)
    return wait(id, CFG.delay)
end

local function start()
    if running then return end
    running = true
    run += 1
    local id = run
    task.spawn(function()
        while running and run == id and W.Alive do
            local ok, cont = pcall(cycle, id)
            if not ok then stats.fail += 1; task.wait(0.5) end
            if ok and cont == false and run ~= id then break end
        end
    end)
end
local function stop()
    run += 1; running = false; stats.status = "idle"
end

-- ===== UI =====
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "fish" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

local cFish = Main:AddCard({ Title = "Auto Fishing", Icon = "fish", Column = 1 })
cFish:Toggle({
    Title = "Auto Fishing", Desc = "Cast, minigame, fish giver, cleanup, repeat", id = "g14_autofish",
    Callback = function(v)
        if v then start() else stop() end
        N("Auto Fishing", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cFish:Input({
    Title = "Rod Name", Value = CFG.rod, Placeholder = "Eternal Flower", ButtonText = "Set", id = "g14_rodname",
    Callback = function(v)
        if type(v) == "string" and #v > 0 then CFG.rod = v end
    end,
    OnButton = function(v)
        if type(v) == "string" and #v > 0 then CFG.rod = v end
        N("Rod", CFG.rod, "#50C864")
    end,
})

-- Delay: slider (drag, unit 0.01 s) + number box (type seconds) stay in sync.
-- "syncing" guard stops the two controls from calling each other forever.
local sliderObj, inputObj
local syncing = false
local function fmt(n) return string.format("%.2f", n) end
local function push(obj, val)
    if not obj then return end
    syncing = true
    for _, m in ipairs({ "SetValue", "Set", "SetText" }) do
        if type(obj[m]) == "function" then
            if pcall(obj[m], obj, val) then break end
        end
    end
    syncing = false
end
local function setDelay(v, from)
    if syncing then return end
    if type(v) == "table" then v = v[1] end
    local n = tonumber(v)
    if not n then return end
    if from == "slider" then n = n / 100 end          -- slider is in 0.01 s units
    n = math.clamp(math.floor(n * 100 + 0.5) / 100, 0.01, 5)
    CFG.delay = n
    if from == "slider" then push(inputObj, fmt(n))
    elseif from == "input" then push(sliderObj, math.floor(n * 100 + 0.5)) end
end

local okS, s = pcall(function()
    return cFish:Slider({
        Title = "Delay slider (1 = 0.01 detik, 500 = 5 detik)", id = "g14_delay",
        Min = 1, Max = 500, Default = 50, Value = 50,
        Step = 1, Increment = 1, Suffix = "",
        Callback = function(v) setDelay(v, "slider") end,
    })
end)
if okS then sliderObj = s end
inputObj = cFish:Input({
    Title = "Delay manual detik (0.01 - 5)", Value = fmt(CFG.delay), Placeholder = "0.50", ButtonText = "Set",
    id = "g14_delayInput",
    Callback = function(v) setDelay(v, "input") end,
    OnButton = function(v)
        setDelay(v, "input")
        N("Delay", fmt(CFG.delay) .. " detik", "#50C864")
    end,
})

local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })
task.spawn(function()
    while W.Alive do
        task.wait(0.3)
        pcall(function()
            stLbl:SetText("Status: " .. stats.status ..
                "\nCasts: " .. stats.casts .. "   Fish: " .. stats.fish .. "   Failed: " .. stats.fail ..
                "\nDelay: " .. fmt(CFG.delay) .. "s   Rod: " .. CFG.rod)
        end)
    end
end)

W:OnUnload(function() run += 1; running = false end)

-- Player and Home (+ Settings) live in ui.lua; each part is wrapped against errors.
for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildHome({ Game = "Rod And Reef", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[Sevoice] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()
W:OnBooted(function() N("Sevoice", "Rod And Reef loaded  ·  RCtrl to open/close", "#50C864", 4) end)
print("[Rod And Reef] Auto Fishing ready.")
