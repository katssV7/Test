-- KatssinnnHub | Rod And Reef - Auto Fishing
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Alur game: equip rod -> CastLine{power,castId} -> bobber mendarat di air ->
-- tunggu bite -> RequestFishData{castQuality} -> server balas FishDataResponse ->
-- minigame -> CatchFish -> ReelIn.
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "Rod And Reef",
    Folder    = "KatssinnnHub/RodAndReef",
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
local ShopP = try(function() return require(RS.Networking.Packets.Shop) end)
local DialogueP = try(function() return require(RS.Networking.Packets.Dialogue) end)
local PData = try(function() return require(PS.Controllers.PlayerDataClient) end)

-- ===== PENGATURAN (tetap / default) =====
local CFG = {
    releaseAt = 0.80,       -- lepas tombol kail saat bar >= ini
    holdTime = 1.0,         -- cadangan: lama tahan (detik) kalau bar tidak terbaca
    biteFallback = 3.0,
    minigameDelay = 1.00,   -- jeda setelah FishDataResponse sebelum CatchFish
    castGap = 1.5,          -- jeda sebelum lempar lagi
    hitTol = 0.5,           -- toleransi klik minigame
    pursuitAccel = 450,     -- percepatan jarum Pursuit (deg/s^2), hasil scan
    pursuitVmax = 132,      -- kecepatan maks jarum Pursuit (deg/s)
    pursuitBand = 0.35,     -- toleransi (x setengah lebar zona) sebelum membalik
    pursuitLead = 0.05,     -- kompensasi latensi klik (detik)
    pursuitMirror = false,  -- true kalau ternyata ada 2 zona berseberangan
    mode = "skip",          -- "skip" atau "mini"
}
local lastPower = nil
local stats = { casts = 0, fish = 0, fail = 0, sold = 0, status = "idle" }
local run = 0
local running = false

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
local function alive(id) return id == nil or run == id end   -- id nil = aksi manual (tidak bisa dibatalkan)
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
local function getDial(name)
    local pg = LP:FindFirstChild("PlayerGui")
    local m = pg and pg:FindFirstChild("Minigames")
    local cv = m and m:FindFirstChild("Canvas")
    local cm = cv and (cv:FindFirstChild(name or "CircularMinigame") or cv:FindFirstChild("CircularMinigame"))
    local h = cm and cm:FindFirstChild("Canvas") and cm.Canvas:FindFirstChild("CircleHolder")
    if cm and not (h and h:FindFirstChild("Needle")) then   -- Pursuit: struktur beda, cari Needle langsung
        for _, o in ipairs(cm:GetDescendants()) do
            if o.Name == "Needle" and o:IsA("GuiObject") then h = o.Parent; break end
        end
    end
    return cm, h
end
-- Ikan Secret: server kirim 3-4 tahap minigame berbeda. Kita bungkus start() tiap modul
-- supaya tahu tahap mana yang sedang jalan (Circular/Blind = klik, Tension = hold/lepas, Pursuit = klik balik arah).
local activeMG = nil
do
    local G = PS:FindFirstChild("Gameplay")
    local MG = G and G:FindFirstChild("Minigames")
    for _, n in ipairs({ "CircularMinigame", "BlindNeedleMinigame", "TensionMinigame", "PursuitMinigame", "MemoryMinigame" }) do
        local inst = MG and MG:FindFirstChild(n)
        local m = inst and try(function() return require(inst) end)
        if type(m) == "table" and type(m.start) == "function" then
            local o = m.start
            m.start = function(...) activeMG = n; return o(...) end
        end
    end
end
local function findZone(h, needle)
    for n, deg in pairs(ARC) do local a = h:FindFirstChild(n); if a and a.Visible then return a, deg / 2 end end
    for _, a in ipairs(h:GetChildren()) do
        local nm = a.Name:lower()
        if a ~= needle and a:IsA("GuiObject") and a.Visible and (nm:find("zone") or nm:find("arc") or nm:find("target") or nm:find("circle")) then
            return a, 25
        end
    end
end
local wrap90 = function(x) return (x + 90) % 180 - 90 end
local function mouse(down)
    local v = workspace.CurrentCamera.ViewportSize
    VIM:SendMouseButtonEvent(v.X * 0.5, v.Y * 0.85, 0, down, game, 0)
end
local function playMinigame(id)
    local t0, seen, prev, lastClick = os.clock(), false, nil, 0
    local before = streak()
    local holding, pn, pz, pt, nv, zv = false, nil, nil, nil, 0, 0
    local sn, sz, sa, psn, ps, lastMG = 0, 0, 0, 0, 1, nil
    local function setHold(h) if h ~= holding then holding = h; mouse(h); if not h then restoreTouch() end end end
    activeMG = nil
    while os.clock() - t0 < 60 do
        if not alive(id) then setHold(false); return false end
        if streak() ~= before then setHold(false); return true end
        local cm, h = getDial(activeMG)
        local needle = h and h:FindFirstChild("Needle")
        local arc, half
        if h and needle then arc, half = findZone(h, needle) end
        if cm and cm.Visible and needle and arc then
            seen = true
            local now = os.clock()
            local n, z = needle.Rotation, arc.Rotation
            local dtc = 0
            if pt and now > pt then
                local dt = now - pt
                dtc = dt
                nv = sdiff(n, pn) / dt; zv = sdiff(z, pz) / dt
            end
            pn, pz, pt = n, z, now
            if activeMG == "TensionMinigame" then
                -- tahan = jarum naik (+), lepas = turun (-); ikuti zona biru pakai PD sederhana
                setHold(sdiff(z, n) + 0.3 * (zv - nv) > 0)
            elseif activeMG == "PursuitMinigame" then
                -- Model hasil scan: klik membalik PERCEPATAN jarum (+-A), kecepatan dibatasi Vmax.
                -- Kontrol bang-bang: balik percepatan kalau posisi berhenti (jika direm sekarang)
                -- akan melewati pusat zona lebih dari toleransi.
                local A, V = CFG.pursuitAccel, CFG.pursuitVmax
                if lastMG ~= activeMG then lastMG = activeMG; ps, sa, psn, sn, sz = 1, 0, 0, 0, 0 end
                sn = sn * 0.5 + nv * 0.5; sz = sz * 0.5 + zv * 0.5
                if dtc > 0 then sa = sa * 0.6 + ((sn - psn) / dtc) * 0.4 end
                psn = sn
                -- sinkronkan tebakan arah percepatan dari pengamatan (hanya saat belum mentok Vmax)
                if math.abs(sn) < V * 0.7 and math.abs(sa) > A * 0.5 and now - lastClick > 0.25 then
                    ps = sa > 0 and 1 or -1
                end
                local e = CFG.pursuitMirror and wrap90(n - z) or sdiff(n, z)
                local w = sn - sz
                local tau = CFG.pursuitLead
                local ep = e + w * tau
                local wp = w + ps * A * tau
                local sigma = ep + wp * math.abs(wp) / (2 * A)
                if ps * sigma > half * CFG.pursuitBand and now - lastClick > 0.08 then
                    lastClick = now; ps = -ps; click()
                end
            else
                -- Circular / BlindNeedle: klik saat jarum di zona
                local d = sdiff(n, z)
                local crossed = prev and (math.sign(prev) ~= math.sign(d)) and math.abs(prev) < 40
                if (math.abs(d) <= half * CFG.hitTol or crossed) and now - lastClick > 0.3 then
                    lastClick = now; click()
                end
                prev = d
            end
        elseif seen and os.clock() - lastClick > 2 then
            setHold(false)
            task.wait(0.3)
            return streak() ~= before
        end
        RunService.Heartbeat:Wait()
    end
    setHold(false)
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
    if not found then print("[Rod And Reef] bar power tidak terbaca, pakai holdTime") end
    return true
end

-- ===== AUTO SELL (dari hasil scan) =====
-- Ikan masuk tas: CatchFish -> server menambah "Inventory.Fish.<nama>" di data pemain,
-- dikirim ke client lewat RemoteEvent Packages.Net["RE/PlayerDataChanged"] (path, nilai).
-- Jual semua: packet Shop.SellAllFish (tanpa argumen). Di game asli lewat NPC Oliver
-- (Workspace.DialogueNPCs.Oliver) -> menu jual -> OpenSellPrompt -> konfirmasi Yes.
local SELL = { enabled = false, every = 20 }
local fishTbl, sellMode, nextSellTry = nil, nil, 0   -- sellMode: nil (belum tahu) / "direct" / "npc"

local function sumFish(t)
    local n = 0
    if type(t) == "table" then
        for _, list in pairs(t) do
            if type(list) == "table" then
                for _, e in pairs(list) do
                    if type(e) == "table" then n += (tonumber(e.Count) or 1) end
                end
            end
        end
    end
    return n
end
local function cachedFish()
    if not PData then return nil end
    for _, nm in ipairs({ "GetCachedData", "GetData" }) do
        if type(PData[nm]) == "function" then
            local ok, d = pcall(PData[nm])
            if not (ok and type(d) == "table") then ok, d = pcall(PData[nm], PData) end
            if ok and type(d) == "table" and type(d.Inventory) == "table" and type(d.Inventory.Fish) == "table" then
                return d.Inventory.Fish
            end
        end
    end
end
local function invCount()
    local c = cachedFish()
    if c then return sumFish(c) end
    return sumFish(fishTbl)   -- cadangan: hitungan dari event PlayerDataChanged
end
task.spawn(function()
    local pk = RS:WaitForChild("Packages", 10)
    local net = pk and pk:WaitForChild("Net", 10)
    local re = net and net:WaitForChild("RE/PlayerDataChanged", 10)
    if not re then return end
    re.OnClientEvent:Connect(function(path, value)
        if type(path) ~= "string" then return end
        if path == "Inventory.Fish" then fishTbl = value
        else
            local name = path:match("^Inventory%.Fish%.([^%.]+)$")
            if name then fishTbl = fishTbl or {}; fishTbl[name] = value end
        end
    end)
end)

local function coins()
    local ls = LP:FindFirstChild("leaderstats")
    local c = ls and ls:FindFirstChild("Coins")
    return c and c.Value or 0
end
local function sellDone(c0, id)   -- tunggu server: koin naik atau tas jadi kosong
    local t0 = os.clock()
    while os.clock() - t0 < 3 do
        if coins() > c0 or invCount() == 0 then return true end
        task.wait(0.1)
        if not alive(id) then return false end
    end
    return false
end
local function oliver()
    local f = workspace:FindFirstChild("DialogueNPCs")
    return f and f:FindFirstChild("Oliver")
end
local function sellViaNpc(id)
    local m, r = oliver(), Root()
    local p = m and (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true))
    if not (m and p and r and DialogueP and ShopP) then return false end
    local back = r.CFrame
    r.CFrame = CFrame.new(p.Position + p.CFrame.LookVector * 4 + Vector3.new(0, 3, 0))
    r.AssemblyLinearVelocity = Vector3.zero
    local ok = false
    if wait(id, 0.6) then
        local c0 = coins()
        local function step(pk, data) if pk then pcall(pk.send, data) end; return wait(id, 0.35) end
        step(DialogueP.RequestNPCInteraction, { npcId = "Oliver", npcModel = m })
        step(DialogueP.DialogueSelectBranch, { npcId = "Oliver", branchId = "Oliver_Greet_r1" })
        step(DialogueP.DialogueSelectBranch, { npcId = "Oliver", branchId = "Oliver_SellMenu_r1" })
        step(DialogueP.DialogueAction, { npcId = "Oliver", actionId = "OpenSellPrompt", payload = "All" })
        step(DialogueP.DialogueAdvance, { npcId = "Oliver", nodeId = "Oliver_SellAll" })
        step(DialogueP.NPCInteractionEnd, { npcId = "Oliver", reason = "endOfDialogue" })
        if wait(id, 1.0) then
            pcall(ShopP.SellAllFish.send)
            ok = sellDone(c0, id)
        end
    end
    local r2 = Root()
    if r2 then r2.CFrame = back; r2.AssemblyLinearVelocity = Vector3.zero end
    return ok
end
-- popup "FISH SOLD!" harus ditutup dengan tombol CONTINUE (QuestRewards.Canvas.BG.Container.ContinueFrame.TextButton)
local function findContinue()
    local node = LP:FindFirstChild("PlayerGui")
    for _, n in ipairs({ "QuestRewards", "Canvas", "BG", "Container", "ContinueFrame", "TextButton" }) do
        node = node and node:FindFirstChild(n)
    end
    return node
end
local function shown(b)
    local o = b
    while o and o ~= game do
        if o:IsA("GuiObject") and not o.Visible then return false end
        if o:IsA("ScreenGui") and not o.Enabled then return false end
        o = o.Parent
    end
    return b.AbsoluteSize.X > 0
end
local function fireSig(sig, ...)
    local args = { ... }
    local n = select("#", ...)
    if getconnections then
        local ok, cons = pcall(getconnections, sig)
        if ok and type(cons) == "table" and #cons > 0 then
            for _, c in ipairs(cons) do pcall(function() c:Fire(table.unpack(args, 1, n)) end) end
            return true
        end
    end
    if firesignal then return (pcall(firesignal, sig, table.unpack(args, 1, n))) end
    return false
end
local function pressContinue(b)
    local fired = fireSig(b.Activated, nil, 1)
    fired = fireSig(b.MouseButton1Click) or fired
    if not fired then   -- cadangan: tap sentuh di tengah tombol (sentuh, bukan mouse, jadi analog HP aman)
        local p, sz = b.AbsolutePosition, b.AbsoluteSize
        local x, y = p.X + sz.X / 2, p.Y + sz.Y / 2 + GuiService:GetGuiInset().Y
        pcall(function()
            VIM:SendTouchEvent(8, 0, x, y)
            VIM:SendTouchEvent(8, 2, x, y)
        end)
    end
end
local function dismissSold(id)
    local t0, b = os.clock(), nil
    while os.clock() - t0 < 3 do   -- tunggu popup muncul
        b = findContinue()
        if b and shown(b) then break end
        b = nil
        task.wait(0.1)
        if not alive(id) then return end
    end
    if not b then return end
    stats.status = "klik CONTINUE"
    for _ = 1, 3 do
        pressContinue(b)
        if not wait(id, 0.5) then return end
        b = findContinue()
        if not (b and shown(b)) then return end
    end
end

-- coba kirim SellAllFish langsung dulu; kalau server menolak, lewat NPC Oliver (mode diingat)
local function sellAll(id)
    if not (ShopP and ShopP.SellAllFish) then return false end
    stats.status = "jual semua ikan..."
    local c0 = coins()
    if sellMode ~= "npc" then
        pcall(ShopP.SellAllFish.send)
        if sellDone(c0, id) then sellMode = "direct"; dismissSold(id); return true end
        if not alive(id) then return false end
    end
    local ok = sellViaNpc(id)
    if ok then sellMode = "npc"; dismissSold(id) end
    return ok
end

local function cycle(id)
    -- 0. auto sell tiap N ikan di tas
    if SELL.enabled and SELL.every > 0 and os.clock() >= nextSellTry and invCount() >= SELL.every then
        local ok = sellAll(id)
        if not alive(id) then return end
        if ok then stats.sold += 1; stats.status = "jual selesai"
        else stats.fail += 1; stats.status = "jual gagal, coba lagi 15 detik"; nextSellTry = os.clock() + 15 end
        wait(id, 0.5)
    end
    if not alive(id) then return end

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
    if CFG.mode == "mini" or (d and d.rarity == "Secret") then
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
    running = true
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
    run += 1; running = false; stats.status = "idle"
    task.delay(0.3, restoreTouch)   -- analog HP muncul lagi setelah fishing dimatikan
end

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "fish" })
local TeleportPage = W:AddPage({ Name = "Teleport", Icon = "map-pin" })
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

-- ---------- Auto Sell ----------
local cSell = Main:AddCard({ Title = "Auto Sell", Icon = "coins", Column = 2 })
cSell:Toggle({
    Title = "Auto Sell Fish", Desc = "Jual semua ikan tiap mencapai jumlah di bawah", id = "g14_sell",
    Callback = function(v)
        SELL.enabled = v
        nextSellTry = 0
        N("Auto Sell", v and ("ON, jual tiap " .. SELL.every .. " ikan") or "OFF", v and "#50C864" or "#DC3232")
    end,
})
do
    local function setEvery(v)
        local n = math.floor(tonumber(v) or 0)
        if n >= 1 then SELL.every = n; N("Auto Sell", "Jual tiap " .. n .. " ikan", "#50C864")
        else N("Auto Sell", "Isi angka 1 atau lebih", "#DC3232") end
    end
    cSell:Input({
        Title = "Jual tiap berapa ikan", Value = tostring(SELL.every), Placeholder = "20", ButtonText = "Set", id = "g14_sellN",
        Callback = function(v) local n = math.floor(tonumber(v) or 0); if n >= 1 then SELL.every = n end end,
        OnButton = setEvery,
    })
end
cSell:Button({
    Title = "Jual semua sekarang", Text = "Sell All sekarang",
    Callback = function()
        if running then N("Sell All", "Matikan fishing dulu", "#DC3232"); return end
        task.spawn(function()
            local before = invCount()
            if before <= 0 then N("Sell All", "Tidak ada ikan di tas", "#DC3232"); return end
            local ok = sellAll(nil)
            stats.status = ok and "jual selesai" or "jual gagal"
            N("Sell All", ok and ("Terjual (" .. before .. " ikan)") or "Gagal menjual", ok and "#50C864" or "#DC3232")
        end)
    end,
})

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

local cTp = TeleportPage:AddCard({ Title = "Teleport", Icon = "map-pin", Column = 1 })
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
                "\nLempar: " .. stats.casts .. "   Ikan: " .. stats.fish .. "   Gagal: " .. stats.fail ..
                "\nIkan di tas: " .. invCount() .. "   Terjual: " .. stats.sold .. "x" ..
                "\nMode jual: " .. (sellMode or "belum diketahui"))
        end)
    end
end)

W:OnUnload(function() run += 1 end)

-- Player dan Home (+ Settings) ada di ui.lua; tiap bagian aman dari error.
for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildHome({ Game = "Rod And Reef", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[KatssinnnHub] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()
W:OnBooted(function() N("KatssinnnHub", "Rod And Reef dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4) end)
print("[Rod And Reef] Auto Fishing siap.")
