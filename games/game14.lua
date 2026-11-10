-- KatssinnnHub | Game 14 (Rod And Reef - Auto Fishing)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Alur game: equip rod -> CastLine{power,castId} -> bobber mendarat di air ->
-- tunggu bite -> RequestFishData{castQuality} -> server balas FishDataResponse ->
-- minigame -> CatchFish -> ReelIn.
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "Game 14",
    Folder    = "KatssinnnHub/Game14",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local PS = LP:WaitForChild("PlayerScripts")

local Fishing = require(RS.Networking.Packets.Fishing)
local function try(f) local ok, r = pcall(f); return ok and r or nil end
local Hotbar = try(function() return require(PS.Controllers.GUI.Hotbar) end)

-- ===== PENGATURAN (tetap / default) =====
local CFG = {
    releaseAt = 0.80,       -- lepas tombol kail saat bar >= ini
    holdTime = 1.0,         -- cadangan: lama tahan (detik) kalau bar tidak terbaca
    biteFallback = 3.0,
    minigameDelay = 1.00,   -- jeda setelah FishDataResponse sebelum CatchFish
    castGap = 1.5,          -- jeda sebelum lempar lagi
    hitTol = 0.5,           -- toleransi klik minigame
    mode = "skip",          -- "skip" atau "mini"
}
local lastPower = nil
local stats = { casts = 0, fish = 0, fail = 0, status = "idle" }
local run = 0

-- ===== listener paket dari server =====
local lastData, lastDataT = nil, 0
Fishing.FishDataResponse.listen(function(d) lastData, lastDataT = d, os.clock() end)
local blocked, blockedT = "", 0
Fishing.FishingBlocked.listen(function(d) blocked, blockedT = d.reason or "", os.clock() end)

do
    local orig = Fishing.CastLine.send
    Fishing.CastLine.send = function(d, ...)
        if type(d) == "table" and d.power then lastPower = d.power end
        return orig(d, ...)
    end
end
local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function alive(id) return run == id end
local function wait(id, t)   -- sleep yang bisa dibatalkan
    local t0 = os.clock()
    while os.clock() - t0 < t do task.wait(0.05); if not alive(id) then return false end end
    return true
end
local function streak()
    local ls = LP:FindFirstChild("leaderstats")
    local s = ls and ls:FindFirstChild("Streak")
    return s and s.Value or 0
end

-- ===== solver minigame lingkaran (CircularMinigame) =====
local ARC = { Circle = 30, CircleHard = 7.75, CircleEasy = 47.5 }
-- Event mouse bikin Roblox mengira pemain pakai PC, sehingga analog HP hilang.
-- Setelah tiap klik mouse, kirim tap sentuh kecil di pojok layar supaya input terakhir
-- kembali "Touch" dan analog muncul lagi.
local function restoreTouch()
    if not UIS.TouchEnabled then return end
    pcall(function()
        VIM:SendTouchEvent(9, 0, 2, 2)
        VIM:SendTouchEvent(9, 2, 2, 2)
    end)
end
local function click()
    local v = workspace.CurrentCamera.ViewportSize
    local x, yy = v.X * 0.5, v.Y * 0.85
    VIM:SendMouseButtonEvent(x, yy, 0, true, game, 0)
    VIM:SendMouseButtonEvent(x, yy, 0, false, game, 0)
    restoreTouch()
end
local function sdiff(a, b) return (a - b + 180) % 360 - 180 end
local function getDial()
    local pg = LP:FindFirstChild("PlayerGui")
    local m = pg and pg:FindFirstChild("Minigames")
    local cm = m and m:FindFirstChild("Canvas") and m.Canvas:FindFirstChild("CircularMinigame")
    local h = cm and cm:FindFirstChild("Canvas") and cm.Canvas:FindFirstChild("CircleHolder")
    return cm, h
end
local function playMinigame(id)
    local t0, seen, prev, lastClick = os.clock(), false, nil, 0
    local before = streak()
    while os.clock() - t0 < 45 do
        if not alive(id) then return false end
        if streak() ~= before then return true end
        local cm, h = getDial()
        local needle = h and h:FindFirstChild("Needle")
        local arc, half
        if h then for n, deg in pairs(ARC) do local a = h:FindFirstChild(n); if a and a.Visible then arc, half = a, deg / 2 end end end
        if cm and cm.Visible and needle and arc then
            seen = true
            local d = sdiff(needle.Rotation, arc.Rotation)
            local crossed = prev and (math.sign(prev) ~= math.sign(d)) and math.abs(prev) < 40
            if (math.abs(d) <= half * CFG.hitTol or crossed) and os.clock() - lastClick > 0.3 then
                lastClick = os.clock(); click()
            end
            prev = d
        elseif seen and os.clock() - lastClick > 2 then
            task.wait(0.3)
            return streak() ~= before
        end
        RunService.Heartbeat:Wait()
    end
    return false
end

-- ===== lempar lewat tombol kail (tahan, lepas saat bar penuh) =====
local barCache
local function findBar()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, o in ipairs(pg:GetDescendants()) do
        if o:IsA("GuiObject") and o.Visible and o.AbsoluteSize.X > 0 and o.Name:lower():find("power") then
            for _, f in ipairs(o:GetDescendants()) do
                local n = f.Name:lower()
                if f:IsA("GuiObject") and (n:find("fill") or n == "bar") then return o, f end
            end
        end
    end
end
local function readPower()
    if not (barCache and barCache[1].Parent and barCache[2].Parent) then
        local c, f = findBar(); barCache = c and { c, f } or nil
    end
    if not barCache then return nil end
    local c, f = barCache[1], barCache[2]
    if c.AbsoluteSize.X >= c.AbsoluteSize.Y then return f.AbsoluteSize.X / math.max(c.AbsoluteSize.X, 1) end
    return f.AbsoluteSize.Y / math.max(c.AbsoluteSize.Y, 1)
end
local function holdCast(id)
    local pg = LP:FindFirstChild("PlayerGui")
    local g = pg and pg:FindFirstChild("ExtendedTouchGui")
    local b = g and g:FindFirstChild("Fishing_Cast")
    if not (b and b.Visible) then return false end
    local p, sz = b.AbsolutePosition, b.AbsoluteSize
    -- klik kiri mouse digeser ke kanan di dalam tombol kail supaya tidak tertutup UI library
    local x, y = p.X + sz.X * 0.75, p.Y + sz.Y / 2 + GuiService:GetGuiInset().Y
    barCache = nil
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    local t0, found = os.clock(), false
    while os.clock() - t0 < 5 do
        if not alive(id) then break end
        local v = readPower()
        if v then
            found = true
            if v >= CFG.releaseAt then break end
        elseif os.clock() - t0 >= CFG.holdTime then break end
        RunService.Heartbeat:Wait()
    end
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    restoreTouch()
    if not found then print("[RodReef] bar power tidak terbaca, pakai holdTime") end
    return true
end

local function cycle(id)
    -- 1. equip rod
    if Hotbar and Hotbar.IsRodEquipped and not Hotbar.IsRodEquipped() then
        stats.status = "equip rod"
        pcall(Hotbar.ForceEquipRod)
        local t0 = os.clock()
        while not Hotbar.IsRodEquipped() and os.clock() - t0 < 3 do task.wait(0.1) end
    end
    if not alive(id) then return end

    -- 2. lempar
    stats.status = "tahan tombol kail"
    local seen = {}
    for _, p in ipairs(workspace:GetChildren()) do if p.Name == "bobber" then seen[p] = true end end
    lastPower = nil
    local castT = os.clock()
    if not holdCast(id) then
        stats.status = "tombol kail tidak ketemu"; stats.fail += 1; wait(id, 1.5); return
    end
    stats.casts += 1
    local bobber
    local t0c = os.clock()
    while os.clock() - t0c < 4 and not bobber do
        for _, p in ipairs(workspace:GetChildren()) do
            if p.Name == "bobber" and p:IsA("BasePart") and not seen[p] and (p:GetAttribute("Owner") == LP.UserId or p:GetAttribute("FishingRigOwner") == LP.UserId) then bobber = p break end
        end
        task.wait(0.05)
        if not alive(id) then return end
    end
    if not bobber then
        stats.status = "bobber tidak muncul"; stats.fail += 1; wait(id, 1.5); return
    end

    -- 3. tunggu mendarat di air
    stats.status = "menunggu bobber mendarat"
    local t0 = os.clock()
    while bobber.Parent and bobber:GetAttribute("WaterLandedAt") == nil and os.clock() - t0 < 6 do task.wait(0.05) if not alive(id) then return end end
    if not bobber.Parent or bobber:GetAttribute("WaterLandedAt") == nil then
        stats.status = "bobber gagal mendarat di air"; stats.fail += 1
        pcall(Fishing.ReelIn.send); wait(id, 1); return
    end

    -- 4-5. tunggu FishDataResponse
    stats.status = ("menunggu gigitan (power %s)"):format(lastPower and math.floor(lastPower) or "?")
    while lastDataT < castT and os.clock() - castT < 40 do task.wait(0.05) if not alive(id) then return end end
    if lastDataT < castT then
        stats.status = "tidak ada gigitan"; stats.fail += 1
        pcall(Fishing.ReelIn.send); wait(id, 1); return
    end
    local d = lastData
    stats.status = ("minigame %s (%s)"):format(d and d.name or "?", d and d.rarity or "?")

    -- 6. selesaikan minigame
    local before = streak()
    if CFG.mode == "mini" then
        stats.status = "main minigame..."
        local ok = playMinigame(id)
        if not alive(id) then return end
        if ok then stats.fish += 1; stats.status = "dapat " .. (d and d.name or "ikan")
        else stats.fail += 1; stats.status = "minigame gagal/timeout" end
        pcall(Fishing.ReelIn.send)
        wait(id, CFG.castGap)
        return
    end
    if not wait(id, CFG.minigameDelay) then return end
    local MC = try(function() return require(PS.Gameplay.MinigameController) end)
    if MC and MC.stop then pcall(MC.stop, true) end
    local t1 = os.clock()
    while streak() == before and os.clock() - t1 < 1.5 do task.wait(0.05) if not alive(id) then return end end
    if streak() == before then Fishing.CatchFish.send() end
    t1 = os.clock()
    while streak() == before and os.clock() - t1 < 2.5 do task.wait(0.05) if not alive(id) then return end end
    if streak() ~= before then stats.fish += 1; stats.status = "dapat " .. (d and d.name or "ikan")
    else stats.fail += 1; stats.status = "CatchFish tidak dihitung server" end
    pcall(Fishing.ReelIn.send)
    wait(id, CFG.castGap)
end

local function start()
    run += 1
    local id = run
    task.spawn(function()
        while alive(id) do
            local ok, err = pcall(cycle, id)
            if not ok then stats.status = "error: " .. tostring(err):sub(1, 60); task.wait(1) end
            task.wait()
        end
    end)
end
local function stop()
    run += 1; stats.status = "idle"
    task.delay(0.3, restoreTouch)   -- analog HP muncul lagi setelah fishing dimatikan
end

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "fish" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

local cFish = Main:AddCard({ Title = "Auto Fishing", Icon = "fish", Column = 1 })
cFish:Toggle({
    Title = "Instant Fishing", id = "g14_skip",
    Callback = function(v)
        if v then CFG.mode = "skip"; start() else stop() end
        N("Instant Fishing", v and "ON (matikan Auto Fishing dulu kalau aktif)" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cFish:Toggle({
    Title = "Auto Fishing", id = "g14_mini",
    Callback = function(v)
        if v then CFG.mode = "mini"; start() else stop() end
        N("Auto Fishing", v and "ON (matikan Instant Fishing dulu kalau aktif)" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })

-- ---------- Teleport NPC ----------
local npcMap, npcNames, selNpc = {}, {}, nil
local function npcPart(m)
    return m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true)
end
local function scanNpc()
    local map, names, cnt, done = {}, {}, {}, {}
    local function add(m)
        if not m or done[m] or not m:IsA("Model") or Players:GetPlayerFromCharacter(m) or not npcPart(m) then return end
        done[m] = true
        local n = m.Name
        cnt[n] = (cnt[n] or 0) + 1
        if cnt[n] > 1 then n = n .. " (" .. cnt[n] .. ")" end
        map[n] = m; names[#names + 1] = n
    end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Humanoid") then
            add(d.Parent)
        elseif d:IsA("Model") and d.Parent and d.Parent.Name:lower():find("npc") then
            add(d)
        end
    end
    table.sort(names)
    return map, names
end
pcall(function() npcMap, npcNames = scanNpc() end)

local cTp = Main:AddCard({ Title = "Teleport", Icon = "map-pin", Column = 1 })
local tpLbl
local function UpdateTpLabel()
    if tpLbl then
        pcall(function() tpLbl:SetText("NPC ditemukan: " .. #npcNames .. "\nTerpilih: " .. (selNpc or "-")) end)
    end
end
local function PickNpc(v)
    if type(v) == "table" then v = v[1] end
    if type(v) == "string" and npcMap[v] then selNpc = v end
    UpdateTpLabel()
end

-- Dropdown bawaan ui.lua: daftar bisa di-scroll dan punya kolom Search
local dd = cTp:Dropdown({
    Title = "Pilih NPC", List = npcNames, Placeholder = "Pilih NPC",
    Callback = PickNpc,
})
local function SetDropdownList()
    pcall(function() dd:SetList(npcNames) end)
end

cTp:Button({
    Title = "Refresh NPC", Text = "Cari semua NPC",
    Callback = function()
        local ok, m, names = pcall(scanNpc)
        if ok then
            npcMap, npcNames = m, names
            if selNpc and not npcMap[selNpc] then selNpc = nil end
            SetDropdownList()
            UpdateTpLabel()
            N("Refresh NPC", #npcNames .. " NPC ditemukan", "#6495ED")
        else
            N("Refresh NPC", "Gagal: " .. tostring(m), "#DC3232")
        end
    end,
})
cTp:Button({
    Title = "Teleport To Npc", Text = "Teleport ke NPC terpilih",
    Callback = function()
        local m = selNpc and npcMap[selNpc]
        local p = m and m.Parent and npcPart(m)
        local r = Root()
        if not p then N("Teleport", "Pilih NPC dulu / NPC tidak ada, tekan Refresh NPC", "#DC3232"); return end
        if not r then N("Teleport", "Karakter belum ada", "#DC3232"); return end
        local pos = p.Position + p.CFrame.LookVector * 4 + Vector3.new(0, 3, 0)
        r.CFrame = CFrame.new(pos, Vector3.new(p.Position.X, pos.Y, p.Position.Z))
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        N("Teleport", selNpc, "#50C864")
    end,
})
tpLbl = cTp:Label({ Text = "-", Size = 11, Color = "Text" })
UpdateTpLabel()

task.spawn(function()
    while W.Alive do
        task.wait(0.3)
        pcall(function()
            stLbl:SetText("Status: " .. stats.status ..
                "\nLempar: " .. stats.casts .. "   Ikan: " .. stats.fish .. "   Gagal: " .. stats.fail)
        end)
    end
end)

W:OnUnload(function() run += 1 end)

-- Player dan Home (+ Settings) ada di ui.lua; tiap bagian aman dari error.
for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildHome({ Game = "Game 14", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[KatssinnnHub] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()
W:OnBooted(function() N("KatssinnnHub", "Game 14 dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4) end)
print("[RodReef] Auto Fishing siap.")
