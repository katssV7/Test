-- Sevoice | Game 16 - Auto Fishing
-- Sidebar: Home / Main / Player / Settings (library: ui.lua, same as game14, Teleport page removed)
--
-- Game flow (read from the dumped scripts):
--   equip Rod tool (CollectionService tag "Rod") -> cast (CastReplication) -> hook lands on water
--   -> wait 3-6s -> AuthorizeCatch:InvokeServer -> minigame -> FishGiver:FireServer{token} -> CleanupCast
-- The game already has its own Auto mode (Auto button: casts with power 90-100 and plays the minigame
-- with extra auto-taps). This script keeps a rod equipped, presses that Auto button for you and
-- recovers when it stalls, so every remote call is still made by the game's own code.

local RS = game:GetService("ReplicatedStorage")
local FS = RS:FindFirstChild("FishingSystem") or RS:WaitForChild("FishingSystem", 10)
if not FS then
    warn("[Sevoice] ReplicatedStorage.FishingSystem not found - this is not the right game")
    return
end

local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "Sevoice",
    Version   = "v1.0",
    Game      = "Mount Floresia",
    Folder    = "Sevoice/Mount Floresia",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local Players = game:GetService("Players")
local CS = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local function try(f) local ok, r = pcall(f); return ok and r or nil end

-- ===== SETTINGS =====
local CFG = {
    stuckAfter = 90,   -- seconds without any progress before the cast is reset
    pressGap   = 2.5,  -- minimum seconds between two presses of the Auto button
    equipWait  = 1.8,  -- seconds to wait after equipping a rod
    spawnWait  = 4,    -- seconds to wait after (re)spawn before touching anything
}
local BEST = "Best (highest luck)"

-- speed presets: overwrite the game's own waitTime (bite delay, rolled once at load) and cooldownTime (gap between casts)
-- AuthorizeCatch is checked by the server: if Casts rise but Fish does not, lower the level
-- taps = taps needed in the minigame (FishingConfig.MinigameSettings.rodTapCount, auto bonus taps removed)
-- the game's auto mode taps once every 0.1-0.18s, so 1 tap ~ 0.15s instead of ~2.5s
local SPEED = {
    Normal = {},
    Fast   = { wait = 1.5, cd = 0.05, taps = 4 },
    Max    = { wait = 0.3, cd = 0,    taps = 1 },
}
local speedSel, origWait, origCd, origTaps = "Normal", nil, nil, nil
local skipWait = false   -- skip the wait for the server's CatchPresentationReady before the next cast

-- ===== game modules (client side) =====
local Mods = FS:WaitForChild("FishingModules")
local GUI  = try(function() return require(Mods:WaitForChild("GUIManager")) end)
local MG   = try(function() return require(Mods:WaitForChild("MinigameSystem")) end)
local Cfg  = try(function() return require(FS:WaitForChild("FishingConfig")) end)
local CatchReady = FS:FindFirstChild("CatchPresentationReady")

local stats = { status = "idle", casts = 0, fish = 0, fail = 0, resets = 0, land = 0, last = "-" }
local run, running = 0, false
local lastProgress = os.clock()
local fullT = -999
local charT = os.clock()
LP.CharacterAdded:Connect(function() charT = os.clock() end)

-- ===== hooks (installed once; re-running the script only swaps the handler) =====
local G = (getgenv and getgenv()) or _G
G.__sev16 = G.__sev16 or {}
local H = G.__sev16
local trackedAuto = false

local function wrapMethod(tbl, key, hname)
    if type(tbl) ~= "table" then return false end
    if H["h_" .. key] == tbl then return true end
    local orig = tbl[key]
    if type(orig) ~= "function" then return false end
    local function wrapper(...)
        local f = H[hname]
        if f then pcall(f, ...) end
        return orig(...)
    end
    local ok = pcall(function() tbl[key] = wrapper end)
    local hooked = ok and tbl[key] == wrapper
    if not hooked and hookfunction then
        local old
        hooked = pcall(function()
            old = hookfunction(orig, function(...)
                local f = H[hname]
                if f then pcall(f, ...) end
                return old(...)
            end)
        end)
    end
    if hooked then H["h_" .. key] = tbl end
    return hooked
end

-- GUIManager:ShowNotification(text, duration, color, rarity, name, rollChance)
-- a catch is the call that carries rarity + name; used for stats and warnings
H.onNotify = function(_, text, _, _, rarity, name)
    if type(text) ~= "string" then return end
    if text == "Cast into water!" then     -- the game shows this when the hook did NOT land in water
        stats.land += 1
        return
    end
    lastProgress = os.clock()
    if rarity and name then
        stats.fish += 1
        stats.land = 0
        stats.last = text .. " [" .. tostring(rarity) .. "]"
    elseif text == "Fish got away!" then
        stats.fail += 1
        stats.land = 0
    elseif text:lower():find("inventory is full") then
        if os.clock() - fullT > 30 then
            fullT = os.clock()
            N("Inventory full", "Sell some fish first, Auto Fishing keeps failing until then", "#DC3232", 6)
        end
    end
end
-- GUIManager:UpdateAutoButton(state) is called by the game every time Auto changes -> free state tracking
H.onAuto = function(_, on) trackedAuto = on and true or false end

if GUI then
    wrapMethod(GUI, "ShowNotification", "onNotify")
    wrapMethod(GUI, "UpdateAutoButton", "onAuto")
end
if CatchReady then
    CatchReady.OnClientEvent:Connect(function() lastProgress = os.clock() end)
end

-- ===== read the game's own state tables through the Auto button's click handler =====
-- S = fishing state (isAutoFishing, casted, fishingInProgress ...), R = rod manager (isEquipped, currentRod ...)
local getUp = (debug and debug.getupvalues) or getupvalues
local getConns = getconnections or get_signal_cons
local S, R

local function autoButton()
    local b = GUI and try(function() return GUI:GetElement("autoButton") end)
    if typeof(b) == "Instance" then
        if b:IsA("GuiButton") then return b end
        local inner = b:FindFirstChildWhichIsA("GuiButton", true)
        if inner then return inner end
    end
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        for _, o in ipairs(pg:GetDescendants()) do
            if o:IsA("GuiButton") and o.Name:lower():find("autobutton") then return o end
        end
    end
end

local function scanUpvalues(fn)
    if type(fn) ~= "function" or not getUp then return end
    local ok, ups = pcall(getUp, fn)
    if not ok or type(ups) ~= "table" then return end
    for _, v in pairs(ups) do
        if type(v) == "table" then
            if rawget(v, "isAutoFishing") ~= nil then S = v end
            if type(rawget(v, "IsValidRod")) == "function" then R = v end
        end
    end
end

local lastScan = 0
local function findState()
    if (S and R) or not getUp or not getConns then return end
    if os.clock() - lastScan < 5 then return end
    lastScan = os.clock()
    local b = autoButton()
    if not b then return end
    local ok, conns = pcall(getConns, b.MouseButton1Click)
    if not ok or type(conns) ~= "table" then return end
    for _, c in ipairs(conns) do
        scanUpvalues(try(function() return c.Function end))
    end
end

local function canTrack() return S ~= nil or (GUI ~= nil and H.h_UpdateAutoButton == GUI) end
local function autoOn()
    if S then return S.isAutoFishing == true end
    return trackedAuto
end
local function mgActive() return MG and try(function() return MG:IsActive() end) or false end

local function restoreTouch()
    if not UIS.TouchEnabled then return end
    pcall(function() VIM:SendTouchEvent(9, 0, 2, 2); VIM:SendTouchEvent(9, 2, 2, 2) end)
end

-- press the Auto button exactly once
local function press(btn)
    if not btn then return false end
    if getConns then
        local ok, conns = pcall(getConns, btn.MouseButton1Click)
        if ok and type(conns) == "table" and #conns > 0 then
            -- only the newest connection, so a duplicated handler cannot toggle twice
            if pcall(function() conns[#conns]:Fire() end) then return true end
        end
    end
    if firesignal and pcall(firesignal, btn.MouseButton1Click) then return true end
    local p, s, inset = btn.AbsolutePosition, btn.AbsoluteSize, GuiService:GetGuiInset()
    local x, y = p.X + s.X / 2, p.Y + s.Y / 2 + inset.Y
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    restoreTouch()
    return true
end

-- ===== rods =====
local selRod = BEST
local function isRod(t) return t:IsA("Tool") and CS:HasTag(t, "Rod") end
local function listRods()
    local out = {}
    for _, root in ipairs({ LP.Character, LP:FindFirstChildOfClass("Backpack") }) do
        if root then
            for _, t in ipairs(root:GetChildren()) do
                if isRod(t) then out[#out + 1] = t end
            end
        end
    end
    return out
end
local function rodLuck(name)
    local c = Cfg and try(function() return Cfg.GetRodConfig(name) end)
    return type(c) == "table" and tonumber(c.baseLuck) or 0
end
local function pickRod()
    local rods = listRods()
    if selRod ~= BEST then
        for _, t in ipairs(rods) do if t.Name == selRod then return t end end
    end
    local best, bs
    for _, t in ipairs(rods) do
        local s = rodLuck(t.Name)
        if not best or s > bs then best, bs = t, s end
    end
    return best
end
local function equippedRod()
    local c = LP.Character
    if c then
        for _, t in ipairs(c:GetChildren()) do if isRod(t) then return t end end
    end
end
local function rodNames()
    local seen, names = {}, {}
    for _, t in ipairs(listRods()) do
        if not seen[t.Name] then seen[t.Name] = true; names[#names + 1] = t.Name end
    end
    table.sort(names, function(a, b)
        local la, lb = rodLuck(a), rodLuck(b)
        if la ~= lb then return la > lb end
        return a < b
    end)
    table.insert(names, 1, BEST)
    return names
end

-- ===== speed =====
local function applySpeed(name)
    local sp = SPEED[name] or SPEED.Normal
    if S then
        origWait = origWait or S.waitTime
        origCd   = origCd or S.cooldownTime
        S.waitTime     = sp.wait or origWait
        S.cooldownTime = sp.cd or origCd
    end
    pcall(function()
        local ms = Cfg.MinigameSettings
        if not origTaps then
            origTaps = { extra = ms.autoModeExtraTaps, rod = {} }
            for k, v in pairs(ms.rodTapCount) do origTaps.rod[k] = v end
        end
        ms.autoModeExtraTaps = sp.taps and 0 or origTaps.extra
        for k, v in pairs(origTaps.rod) do ms.rodTapCount[k] = sp.taps or v end
    end)
end

-- ===== main loop =====
local function step(st)
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then stats.status = "waiting for character"; return end
    if os.clock() - charT < CFG.spawnWait then stats.status = "character loading"; return end

    findState()

    applySpeed(speedSel)

    -- 1. rod
    local want = pickRod()
    if not want then stats.status = "no rod found in Backpack"; return end
    local cur = equippedRod()
    if cur ~= want then
        stats.status = "equipping " .. want.Name
        hum:EquipTool(want)
        st.equipT = os.clock()
        return
    end
    if os.clock() - st.equipT < CFG.equipWait then stats.status = "rod equipped, waiting"; return end
    if R and not (R.isEquipped and R.currentRod == cur) then
        stats.status = "waiting for the game to register the rod"
        return
    end

    -- 2. Auto mode of the game
    if not autoOn() then
        if not canTrack() then
            -- cannot read the Auto state: press only once per rod / respawn instead of toggling forever
            if st.pRod == cur and st.pChar == charT then stats.status = "Auto pressed (state unknown)"; return end
            st.pRod, st.pChar = cur, charT
        elseif os.clock() - st.pressT < CFG.pressGap then
            return
        end
        st.pressT = os.clock()
        local b = autoButton()
        if not b then stats.status = "Auto button not found"; return end
        press(b)
        stats.status = "pressing Auto button"
        return
    end

    -- 3. status + watchdog
    local phase = "casting"
    if mgActive() then phase = "minigame"
    elseif S and S.fishingInProgress then phase = "waiting for bite"
    elseif S and S.casted then phase = "line in the air" end
    if S then
        if S.casted and not st.wasCast then stats.casts += 1 end
        st.wasCast = S.casted and true or false
    end
    stats.status = "auto fishing - " .. phase

    -- after a catch the game blocks the next cast until the server sends CatchPresentationReady (up to 12s)
    -- fishingCaught is set by the game on a finished minigame, so it marks exactly that wait
    if skipWait and speedSel ~= "Normal" and S and S.fishingCaught and phase == "casting" then
        S.fishingCaught = false
        S.castingCooldown = false
        S.canCast = true
    end

    local sig = phase .. stats.fish .. stats.fail .. stats.casts
    if sig ~= st.sig then st.sig = sig; lastProgress = os.clock() end
    if os.clock() - lastProgress > CFG.stuckAfter then
        lastProgress = os.clock()
        stats.resets += 1
        stats.status = "stuck - resetting"
        if R and type(R.CleanupFishing) == "function" then pcall(R.CleanupFishing, R) end
        local b = autoButton()
        if b then press(b) end   -- Auto goes off, the next step turns it back on
    end
end

local function start()
    run += 1
    local id = run
    running = true
    lastProgress = os.clock()
    stats.status = "starting"
    local st = { pressT = 0, equipT = 0 }
    task.spawn(function()
        while running and run == id and W.Alive do
            local ok, err = pcall(step, st)
            if not ok then stats.status = "error: " .. tostring(err) end
            task.wait(0.4)
        end
    end)
end

local function stop()
    run += 1
    running = false
    stats.status = "idle"
    applySpeed("Normal")
    task.spawn(function()   -- switch the game's Auto mode off again
        if autoOn() then
            local b = autoButton()
            if b then press(b) end
        end
    end)
end

-- ===== UI =====
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "fish" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

local cFish = Main:AddCard({ Title = "Auto Fishing", Icon = "fish", Column = 1 })
cFish:Toggle({
    Title = "Auto Fishing", Desc = "Equips the rod and runs the game's own Auto mode (cast + minigame)",
    id = "g16_auto",
    Callback = function(v)
        if v then start() else stop() end
        N("Auto Fishing", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
local rodDD = cFish:Dropdown({
    Title = "Rod", List = rodNames(), Placeholder = BEST,
    Callback = function(v)
        if type(v) == "table" then v = v[1] end
        if type(v) == "string" and v ~= "" then selRod = v end
    end,
})
cFish:Dropdown({
    Title = "Speed", List = { "Normal", "Fast", "Max" }, Placeholder = "Normal",
    Callback = function(v)
        if type(v) == "table" then v = v[1] end
        if SPEED[v] then
            speedSel = v
            if v ~= "Normal" and not S then
                N("Speed", "Game state not readable: only the tap count changes, wait/cooldown do not (limited mode)", "#DC3232", 5)
            end
        end
    end,
})
cFish:Toggle({
    Title = "Skip catch wait", Desc = "RISKY: cast again without waiting for the server's catch animation signal",
    id = "g16_skipwait",
    Callback = function(v) skipWait = v and true or false end,
})
cFish:Button({
    Title = "Refresh rods", Text = "Refresh rod list",
    Callback = function()
        local names = rodNames()
        pcall(function() rodDD:SetList(names) end)
        N("Rods", (#names - 1) .. " rod(s) found", "#6495ED")
    end,
})
cFish:Label({ Text = "Stand facing the water: the Auto mode always casts straight ahead.", Size = 11, Color = "Text" })

local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })

task.spawn(function()
    local sig
    while W.Alive do
        task.wait(0.5)
        pcall(function()
            local rod = equippedRod()
            local warnTxt = ""
            if stats.land >= 3 then warnTxt = "\nWARNING: the hook keeps landing outside the water, face the water" end
            if os.clock() - fullT < 45 then warnTxt = warnTxt .. "\nWARNING: inventory full, sell your fish" end
            stLbl:SetText("Status: " .. stats.status ..
                "\nCasts: " .. stats.casts .. "   Fish: " .. stats.fish .. "   Got away: " .. stats.fail ..
                "\nLast: " .. stats.last ..
                "\nRod: " .. (rod and (rod.Name .. "  (luck " .. rodLuck(rod.Name) .. ")") or "-") ..
                "\nResets: " .. stats.resets ..
                "\nGame state: " .. (S and "read OK" or "limited mode") .. warnTxt)
        end)
        pcall(function()   -- keep the rod dropdown in sync with the backpack
            local names = rodNames()
            local s = table.concat(names, ",")
            if s ~= sig then
                if sig ~= nil then rodDD:SetList(names) end
                sig = s
            end
        end)
    end
end)

W:OnUnload(function() stop() end)

-- Player and Home (+ Settings) live in ui.lua; each part is wrapped against errors.
for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildHome({ Game = "Mount Floresia", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[Sevoice] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()
W:OnBooted(function() N("Sevoice", "Mount Floresia loaded  ·  RCtrl to open/close", "#50C864", 4) end)
print("[Mount Floresia] Auto Fishing ready.")
