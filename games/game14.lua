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
    pursuitBand = 0.15,     -- toleransi (x setengah lebar zona) sebelum membalik; makin kecil = makin rapat tapi makin sering klik
    pursuitLead = 0.06,     -- kompensasi latensi klik (detik)
    pursuitCool = 0.33,     -- jeda minimum antar klik Pursuit. Game mengabaikan klik < ~0.3 dtk dari klik sebelumnya (hasil log), dan klik yang diabaikan ikut menunda klik berikutnya
    debugPursuit = true,    -- true = rekam log Pursuit, otomatis disalin ke clipboard tiap tahap selesai
    memLead = 0.05,         -- Memory: klik lebih awal sekian detik (kompensasi latensi)
    memGap = 2.5,           -- Memory: tidak ada titik baru selama ini = fase tonton selesai
    debugMemory = true,    -- true = log Memory disalin ke clipboard saat tahap selesai
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
local activeMG, startSerial = nil, 0
do
    local G = PS:FindFirstChild("Gameplay")
    local MG = G and G:FindFirstChild("Minigames")
    for _, n in ipairs({ "CircularMinigame", "BlindNeedleMinigame", "TensionMinigame", "PursuitMinigame", "MemoryMinigame" }) do
        local inst = MG and MG:FindFirstChild(n)
        local m = inst and try(function() return require(inst) end)
        if type(m) == "table" and type(m.start) == "function" then
            local o = m.start
            m.start = function(...) activeMG = n; startSerial += 1; return o(...) end
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
local MSKIP = { Needle = true, Background = true, Ring = true, _Axis = true, saww = true, Label = true, Progress = true }
local function spotVis(c)
    if not c.Visible then return false end
    if c:IsA("ImageLabel") or c:IsA("ImageButton") then return c.ImageTransparency < 0.9 end
    return c.BackgroundTransparency < 0.9
end
local wrap90 = function(x) return (x + 90) % 180 - 90 end
-- riwayat sudut (tak terlipat) bertimestamp -> kecepatan/percepatan stabil, tidak jitter per frame
local function newTrack() return { t = {}, a = {}, i = 1 } end
local function tpush(tr, t, a)
    local n = #tr.t + 1
    tr.t[n] = t; tr.a[n] = a
    while tr.t[tr.i] < t - 0.5 do tr.i += 1 end
end
local function tfind(tr, tt)
    for j = #tr.t, tr.i, -1 do if tr.t[j] <= tt then return j end end
end
local function velAt(tr, tEnd, span)
    local j2 = tfind(tr, tEnd)
    local j1 = j2 and tfind(tr, tEnd - span)
    if not (j1 and j2) or j2 <= j1 then return nil end
    local dt = tr.t[j2] - tr.t[j1]
    if dt <= 0 then return nil end
    return (tr.a[j2] - tr.a[j1]) / dt
end
local function mouse(down)
    local v = workspace.CurrentCamera.ViewportSize
    VIM:SendMouseButtonEvent(v.X * 0.5, v.Y * 0.85, 0, down, game, 0)
end
-- Klik khusus Pursuit: TANPA tap sentuh restoreTouch (tap itu terhitung klik kedua dan membatalkan rem).
-- restoreTouch dipanggil sekali saat tahap Pursuit selesai (lewat flush).
-- frame minigame yang sedang tampil (cadangan kalau start() tidak terpanggil lewat pembungkus di atas)
local function visibleMGs()
    local out = {}
    local pg = LP:FindFirstChild("PlayerGui")
    local m = pg and pg:FindFirstChild("Minigames")
    local cv = m and m:FindFirstChild("Canvas")
    if not cv then return out end
    for _, c in ipairs(cv:GetChildren()) do
        if c:IsA("GuiObject") and c.Visible and c.Name:find("Minigame") then out[#out + 1] = c.Name end
    end
    return out
end
local function clickP()
    local v = workspace.CurrentCamera.ViewportSize
    local x, yy = v.X * 0.5, v.Y * 0.85
    VIM:SendMouseButtonEvent(x, yy, 0, true, game, 0)
    task.delay(0.03, function() VIM:SendMouseButtonEvent(x, yy, 0, false, game, 0) end)
end
local function playMinigame(id)
    local usedP = false   -- true = Pursuit pakai clickP, perlu restoreTouch di akhir
    local pCnt = 0        -- jumlah klik yang sudah dikirim di tahap Pursuit ini
    local t0, seen, prev, lastClick = os.clock(), false, nil, 0
    local before = streak()
    local holding, pn, pz, pt, nv, zv = false, nil, nil, nil, 0, 0
    local ps, lastMG, uN, uZ, az = 1, nil, nil, nil, 0
    local trN, trZ = newTrack(), newTrack()
    local dbg, mlog, mem = {}, {}, nil
    local function mlogf(fmt, ...)
        if CFG.debugMemory and #mlog < 600 then mlog[#mlog + 1] = string.format("%.2f ", os.clock() - t0) .. string.format(fmt, ...) end
    end
    local function flush()
        if usedP then usedP = false; restoreTouch() end
        if CFG.debugPursuit and #dbg > 0 then
            local txt = "t,needle,zone,e,ps,click,vNeedle,vZone\n" .. table.concat(dbg, "\n")
            local f = setclipboard or toclipboard
            if f then pcall(f, txt) end
            if writefile then pcall(writefile, "pursuit_log.txt", txt) end
            print("[Rod And Reef] log Pursuit disalin (" .. #dbg .. " baris)")
            dbg = {}
        end
        if CFG.debugMemory and #mlog > 0 then
            local txt = table.concat(mlog, "\n")
            local f = setclipboard or toclipboard
            if f then pcall(f, txt) end
            if writefile then pcall(writefile, "memory_solver_log.txt", txt) end
            print("[Rod And Reef] log Memory disalin (" .. #mlog .. " baris)")
            mlog = {}
        end
    end
    -- Kembali ke fase tonton: buang urutan lama, rekam ulang titik-titik yang ditampilkan game.
    local function memRescan(reason)
        mem.phase, mem.spots, mem.pend, mem.k, mem.pd, mem.lastSpot = "watch", {}, {}, 1, nil, nil
        mem.lastHit, mem.needLabBack = nil, true
        mlogf("SCAN ULANG: %s", reason)
    end
    local function memEvent(c, now)
        if not mem then return end
        -- Titik muncul lagi saat fase klik = game menampilkan urutan lagi (gagal 1x / ronde baru) -> scan ulang.
        -- Jeda 0,25 dtk dari klik/awal fase klik. Dari log: setelah klik gagal, titik pertama muncul lagi ~0,38 dtk kemudian
        -- (jeda 0,6 sebelumnya membuang titik pertama itu, jadi urutan hasil scan ulang kehilangan titik #1).
        if mem.phase == "act" then
            local ref = math.max(mem.lastHit or 0, mem.actT or 0)
            if now - ref > 0.25 or (mem.k > #mem.spots and mem.lastHit and now - mem.lastHit > 0.4) then
                memRescan(string.format("titik muncul lagi (%s, klik %d/%d)", c.Name, mem.k - 1, #mem.spots))
            end
        end
        if mem.phase == "watch" then mem.pend[#mem.pend + 1] = { c = c, t = now }
        else mlogf("abaikan titik muncul saat fase klik: %s rot=%.1f", c.Name, c.Rotation) end
    end
    local function setHold(h) if h ~= holding then holding = h; mouse(h); if not h then restoreTouch() end end end
    activeMG = nil
    while os.clock() - t0 < 60 do
        if not alive(id) then setHold(false); flush(); return false end
        if streak() ~= before then setHold(false); flush(); return true end
        -- Deteksi minigame dari frame yang tampil (Pursuit / Memory / Tension / Circular / Blind), lalu pakai solver yang cocok.
        -- start() yang dibungkus tetap sumber utama dan TIDAK pernah ditimpa (Secret/Pursuit bergantung padanya).
        -- Frame tampil hanya dipakai kalau activeMG masih kosong (start() tidak terpanggil, mis. Legend).
        if activeMG == nil then
            local vs = visibleMGs()
            if #vs >= 1 then
                activeMG = vs[1]
                stats.status = "minigame: " .. (vs[1]:gsub("Minigame", ""))
                mlogf("minigame terdeteksi dari frame tampil: %s", vs[1])
            end
        end
        local cm, h = getDial(activeMG)
        local needle = h and h:FindFirstChild("Needle")
        local arc, half
        if h and needle then arc, half = findZone(h, needle) end
        if activeMG ~= "MemoryMinigame" and mem then flush(); mem = nil end
        local memMode = activeMG == "MemoryMinigame" and cm and cm.Visible and needle and h
        if memMode then
            -- MEMORY: titik biru muncul satu-satu (urutan = urutan klik), lalu klik saat jarum melewati tiap titik.
            seen = true
            local now = os.clock()
            local n = needle.Rotation
            if not mem or mem.serial ~= startSerial then
                mem = { serial = startSerial, spots = {}, pend = {}, obj = {}, phase = "watch", k = 1, init = false,
                        trN = newTrack(), un = n, pn = n, label = nil, text0 = nil, lastLab = 0, lastSpot = nil, t0 = now }
                mlogf("MEMORY mulai (serial %d)", startSerial)
                for _, c in ipairs(h:GetChildren()) do
                    local g = c:IsA("GuiObject")
                    mlogf("  anak %s [%s] vis=%s rot=%.1f", c.Name, c.ClassName, tostring(g and c.Visible), g and c.Rotation or 0)
                end
            end
            mem.un += sdiff(n, mem.pn); mem.pn = n
            tpush(mem.trN, now, mem.un)
            -- pantau semua anak CircleHolder yang bisa jadi "titik biru"
            for _, c in ipairs(h:GetChildren()) do
                if c:IsA("GuiObject") and not MSKIP[c.Name] and not c:IsA("TextLabel") then
                    local vis, rot = spotVis(c), c.Rotation
                    local st = mem.obj[c]
                    if not st then
                        mem.obj[c] = { vis = vis, rot = rot }
                        if mem.init and vis then memEvent(c, now)
                        elseif vis then mlogf("sudah terlihat saat mulai: %s rot=%.1f", c.Name, rot) end
                    else
                        if vis and ((not st.vis) or math.abs(sdiff(rot, st.rot)) > 10) then memEvent(c, now) end
                        st.vis, st.rot = vis, rot
                    end
                end
            end
            mem.init = true
            if mem.phase == "watch" then
                -- finalkan titik setelah rotasinya settle (60 ms)
                local keep = {}
                for _, pe in ipairs(mem.pend) do
                    if now - pe.t >= 0.06 then
                        local ang = pe.c.Rotation
                        -- duplikat: titik di sudut yang sama muncul dalam 0,4 dtk, walau objeknya beda
                        -- (mis. titik + glow/outline yang ikut berputar) -> kalau dihitung dua kali, urutan klik bergeser
                        local dup = false
                        for _, sp in ipairs(mem.spots) do
                            if math.abs(sdiff(ang, sp.angle)) < 5 and now - sp.t < 0.4 then dup = true; break end
                        end
                        if dup then
                            mlogf("duplikat dibuang: %s angle=%.1f", pe.c.Name, ang)
                        else
                            mem.spots[#mem.spots + 1] = { angle = ang, t = now, c = pe.c }
                            mem.lastSpot = now
                            mlogf("TITIK #%d %s angle=%.1f needle=%.1f", #mem.spots, pe.c.Name, ang, n)
                        end
                    else keep[#keep + 1] = pe end
                end
                mem.pend = keep
                -- cari label instruksi ("Watch the spots...") untuk tanda fase berganti
                if not mem.label and now - mem.lastLab > 0.5 and now - mem.t0 < 6 then
                    mem.lastLab = now
                    local pgui = LP:FindFirstChild("PlayerGui")
                    if pgui then
                        for _, o in ipairs(pgui:GetDescendants()) do
                            if o:IsA("TextLabel") and o.Visible then
                                local tx = o.Text:lower()
                                if tx:find("spots") or tx:find("watch") then mem.label, mem.text0 = o, o.Text; mlogf("label instruksi: %q", o.Text); break end
                            end
                        end
                    end
                end
                -- setelah scan ulang, abaikan sinyal "teks berubah" sampai teks sempat kembali ke teks tonton
                if mem.needLabBack and mem.label and mem.label.Parent and mem.label.Text == mem.text0 then mem.needLabBack = false end
                local why
                if #mem.spots > 0 and #mem.pend == 0 then
                    if mem.label and not mem.needLabBack and (not mem.label.Parent or not mem.label.Visible or mem.label.Text ~= mem.text0) then why = "teks berubah"
                    elseif mem.lastSpot and now - mem.lastSpot > CFG.memGap then why = "tidak ada titik baru" end
                end
                if why then
                    mem.phase, mem.k, mem.pd = "act", 1, nil
                    mem.actT, mem.labChanged, mem.lastHit = now, false, nil
                    local lst = {}
                    for i, sp in ipairs(mem.spots) do lst[i] = string.format("%.1f", sp.angle) end
                    mlogf("FASE KLIK (%s). urutan sudut: %s", why, table.concat(lst, ", "))
                end
            else
                -- teks instruksi kembali ke "Watch the spots..." setelah sempat berubah = ronde baru
                if mem.label and mem.label.Parent then
                    if mem.label.Text ~= mem.text0 then mem.labChanged = true
                    elseif mem.labChanged and mem.label.Visible then
                        memRescan("teks instruksi kembali")
                    end
                end
                local v = velAt(mem.trN, now, 0.1)
                local tgt = mem.spots[mem.k]
                if tgt and v and math.abs(v) > 5 and now - lastClick > 0.2 and not (mem.sched and now < mem.sched) then
                    -- Klik dijadwalkan: hitung kapan jarum tiba di target, kirim klik tepat (waktu tiba - memLead).
                    -- Cara lama baru mengklik SETELAH melewati titik (terlambat 0,02-0,09 dtk di log Legend, jarum ~190 deg/s).
                    local dir = v > 0 and 1 or -1
                    local ahead = (sdiff(tgt.angle, n) * dir) % 360     -- derajat tersisa searah gerak
                    local wait = ahead / math.abs(v) - CFG.memLead
                    if wait <= 0.07 and wait >= -0.03 then
                        wait = math.max(0, wait)
                        local m, k = mem, mem.k
                        mem.sched = now + wait + 0.1
                        task.delay(wait, function()
                            if mem ~= m or m.k ~= k or m.spots[k] ~= tgt or m.phase ~= "act" then return end
                            local nn = needle.Rotation
                            lastClick = os.clock(); click()
                            mlogf("KLIK #%d target=%.1f needle=%.1f selisih=%+.1f v=%.0f", k, tgt.angle, nn, sdiff(nn, tgt.angle), v)
                            m.k = k + 1; m.pd = nil; m.lastHit = os.clock(); m.sched = nil
                        end)
                    end
                end
            end
        elseif cm and cm.Visible and needle and arc then
            seen = true
            local now = os.clock()
            local n, z = needle.Rotation, arc.Rotation
            if activeMG ~= lastMG or not uN then
                -- ganti tahap: reset semua
                if lastMG == "PursuitMinigame" then flush() end
                lastMG = activeMG; ps = 1; az = 0; pCnt = 0
                trN, trZ = newTrack(), newTrack(); uN, uZ = n, z
            elseif pn then
                local dn, dz, dtt = sdiff(n, pn), sdiff(z, pz), now - pt
                if dtt > 0 and (math.abs(dn) / dtt > 600 or math.abs(dz) / dtt > 600) then
                    -- lompatan (ronde baru): reset
                    ps = 1; az = 0; pCnt = 0; trN, trZ = newTrack(), newTrack(); uN, uZ = n, z
                else
                    uN += dn; uZ += dz
                end
            end
            tpush(trN, now, uN); tpush(trZ, now, uZ)
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
                -- Klik membalik PERCEPATAN jarum (+-A); kecepatan dibatasi Vmax (hasil scan).
                local A, V = CFG.pursuitAccel, CFG.pursuitVmax
                local vN = velAt(trN, now, 0.08)
                local vO = velAt(trN, now - 0.1, 0.08)
                local vZ = velAt(trZ, now, 0.15)
                if vN and vO and vZ then
                    local acc = (vN - vO) / 0.1
                    -- sinkronkan arah percepatan dari pengamatan (bukan cuma tebakan)
                    if pCnt == 0 and math.abs(vN) > 8 then
                        ps = vN > 0 and 1 or -1          -- belum ada klik: jarum mulai dari diam, jadi dorongan searah gerak
                    elseif now - lastClick > 0.2 then
                        if math.abs(acc) > 0.55 * A and math.abs(vN) < 0.9 * V then
                            ps = acc > 0 and 1 or -1
                        elseif math.abs(vN) >= 0.92 * V and math.abs(acc) < 0.3 * A then
                            ps = vN > 0 and 1 or -1      -- mentok Vmax berarti dorongan searah gerak
                        end
                    end
                    local e = CFG.pursuitMirror and wrap90(n - z) or sdiff(n, z)
                    local w = vN - vZ
                    local tau = CFG.pursuitLead
                    -- percepatan zona (zona berbalik arah tiap 1-2 dtk): dimasukkan ke model relatif
                    local vZo = velAt(trZ, now - 0.15, 0.15)
                    if vZo then az = az * 0.6 + math.max(-150, math.min(150, (vZ - vZo) / 0.15)) * 0.4 end
                    local ep = e + w * tau
                    local wp = w + (ps * A - az) * (tau + 0.04)
                    local sg = wp >= 0 and 1 or -1
                    local Aeff = math.max(0.3 * A, A + sg * az)   -- daya pengereman efektif terhadap zona
                    local sigma = ep + wp * math.abs(wp) / (2 * Aeff)
                    local clicked = false
                    -- Klik HANYA dikirim kalau jeda sejak klik terakhir sudah >= pursuitCool.
                    -- Klik yang dikirim terlalu rapat diabaikan game dan malah mengulang hitungan jeda-nya.
                    if ps * sigma > half * CFG.pursuitBand and now - lastClick >= CFG.pursuitCool then
                        lastClick = now; ps = -ps; pCnt += 1; clickP(); usedP = true; clicked = true
                    else
                        -- pengaman: jarum lari menjauhi zona & tidak sedang mengerem -> paksa balik
                        local away = e * vN > 0 and math.abs(e) > half * 1.2 and math.abs(vN) > 20
                        local braking = vN * acc < -0.3 * A
                        if away and not braking and now - lastClick >= math.max(0.4, CFG.pursuitCool) then
                            lastClick = now; ps = vN > 0 and -1 or 1; pCnt += 1; clickP(); usedP = true; clicked = true
                        end
                    end
                    if CFG.debugPursuit and #dbg < 2500 then
                        dbg[#dbg + 1] = string.format("%.2f,%.1f,%.1f,%.1f,%d,%s,%.0f,%.0f", now - t0, n, z, e, ps, clicked and "C" or "", vN, vZ)
                    end
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
            setHold(false); flush()
            task.wait(0.3)
            return streak() ~= before
        end
        RunService.Heartbeat:Wait()
    end
    setHold(false); flush()
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

-- ===== AUTO BUY BAIT / ROD =====
-- TERKONFIRMASI dari scan_log.txt (bukan tebakan):
--   packet beli : Shop.RequestBuyItem { amount, itemName, itemType = "Bait" | "Rod" }, balasan Shop.BuyItemResponse { itemName, itemType, success }
--   alur NPC    : Ilyas (Bait, payload "Baits") dan Tobias (Rod, payload "Rods"); langkah dialog sama dengan sell via Oliver
--   data        : leaderstats.Level, leaderstats.Coins, Inventory.Baits { nama = jumlah }, Inventory.Rods { nama, ... }
--   modul       : RS.Modules.BaitDatabase / RodDatabase / ShopRules (hanya berisi fungsi; bentuk datanya TIDAK terlihat di log)
-- PER PULAU (dari log): ShopRules punya IsStockedOn / GetIslandShopLevel / ANY_ISLAND="All"; peta dunia menampilkan 4 pulau
--   (Verdantis Lv1+, Corvane Lv22+, Hollowscar Lv52+, Winterspire Lv77+) masing-masing dengan Bait Shop & Rod Shop sendiri.
--   Nama item bait berawalan pulau (I1CommonBait, I1UncommonBait, ...). Jadi isi toko BEDA tiap pulau dan NPC-nya juga beda.
--   Yang terkonfirmasi log hanya Island1: Ilyas (Bait) & Tobias (Rod). NPC pulau lain dicari otomatis lewat tombol "Scan toko NPC".
-- TIDAK DIKETAHUI (dicari saat runtime, lihat tombol "Salin diagnosa"):
--   field harga & syarat level tiap item. Harga dicari dari field bernama price/cost di data item; syarat level dari
--   ShopRules.GetLevelRequirement (bentuk argumen dikalibrasi otomatis) atau field bernama level. Harga yang tidak
--   terbaca ditampilkan "harga ?" dan baru diketahui (tanda ~) setelah pembelian pertama (selisih koin).
local ShopRules = try(function() return require(RS.Modules.ShopRules) end)
local SHOP = {
    Bait = { itemType = "Bait", db = try(function() return require(RS.Modules.BaitDatabase) end),
        getAll = "GetAllBaits", getOne = "GetBaitByName", npc = "Ilyas", payload = "Baits" },
    Rod = { itemType = "Rod", db = try(function() return require(RS.Modules.RodDatabase) end),
        getAll = "GetAllRods", getOne = "GetRodByName", npc = "Tobias", payload = "Rods" },
}
local MAXBUY = (ShopRules and tonumber(ShopRules.MaxBuyAmount)) or 100   -- 100 terbaca dari log
local BUY = {
    Bait = { enabled = false, sel = nil, min = 20, per = 10, items = {}, byName = {}, byLabel = {}, labels = {},
        force = false, modeBy = {}, learned = {}, fails = 0, nextTry = 0, status = "-" },
    Rod = { enabled = false, sel = nil, items = {}, byName = {}, byLabel = {}, labels = {},
        force = false, modeBy = {}, learned = {}, fails = 0, nextTry = 0, status = "-" },
}
local nextBuyCheck = 0
local buyResp, dlgStartT = nil, 0

if ShopP and ShopP.BuyItemResponse then
    ShopP.BuyItemResponse.listen(function(d)
        if type(d) == "table" then buyResp = { name = d.itemName, type = d.itemType, ok = d.success == true, t = os.clock() } end
    end)
end
if DialogueP and DialogueP.NPCInteractionStart then
    DialogueP.NPCInteractionStart.listen(function() dlgStartT = os.clock() end)
end
local OPENSHOP = nil   -- paket Shop.OpenShop terakhir (dipakai untuk mendeteksi NPC toko)
if ShopP and ShopP.OpenShop and ShopP.OpenShop.listen then
    ShopP.OpenShop.listen(function(p) OPENSHOP = { payload = p, t = os.clock() } end)
end

-- ---------- data pemain ----------
local baitTbl, rodTbl = nil, nil   -- cadangan dari event PlayerDataChanged
task.spawn(function()
    local pk = RS:WaitForChild("Packages", 10)
    local net = pk and pk:WaitForChild("Net", 10)
    local re = net and net:WaitForChild("RE/PlayerDataChanged", 10)
    if not re then return end
    re.OnClientEvent:Connect(function(path, value)
        if type(path) ~= "string" then return end
        if path == "Inventory.Baits" then baitTbl = value
        elseif path == "Inventory.Rods" then rodTbl = value
        else
            local b = path:match("^Inventory%.Baits%.([^%.]+)$")
            if b then baitTbl = baitTbl or {}; baitTbl[b] = value end
        end
    end)
end)
local function cachedData()
    if not PData then return nil end
    for _, nm in ipairs({ "GetCachedData", "GetData" }) do
        if type(PData[nm]) == "function" then
            local ok, d = pcall(PData[nm])
            if not (ok and type(d) == "table") then ok, d = pcall(PData[nm], PData) end
            if ok and type(d) == "table" then return d end
        end
    end
end
local function ownedBait(name)
    local d = cachedData()
    local inv = d and d.Inventory
    local t = type(inv) == "table" and inv.Baits or nil
    if type(t) ~= "table" then t = baitTbl end
    return type(t) == "table" and (tonumber(t[name]) or 0) or 0
end
local function ownsRod(name)
    local d = cachedData()
    local inv = d and d.Inventory
    local t = type(inv) == "table" and inv.Rods or nil
    if type(t) ~= "table" then t = rodTbl end
    if type(t) ~= "table" then return false end
    for k, v in pairs(t) do if v == name or k == name then return true end end
    return false
end
local function myLevel()
    local ls = LP:FindFirstChild("leaderstats")
    local l = ls and ls:FindFirstChild("Level")
    return (l and tonumber(l.Value)) or tonumber(LP:GetAttribute("Level")) or 0
end
local function fmtNum(n)
    local s, k = tostring(math.floor(n + 0.5)), nil
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end
local function clampInt(n, lo, hi) return math.max(lo, math.min(hi, math.floor(tonumber(n) or lo))) end

-- ---------- pulau, stok toko per pulau, NPC toko ----------
local ISLANDS = {   -- id = nilai attribute Zone / folder Workspace.MAP; lv = "SHOPS LV n+" dari peta dunia (log)
    { id = "Island1", name = "Verdantis",  lv = 1 },
    { id = "Island2", name = "Corvane",    lv = 22 },
    { id = "Island3", name = "Hollowscar", lv = 52 },
    { id = "Island4", name = "Winterspire", lv = 77 },
}
local ISL = {}
for i, x in ipairs(ISLANDS) do x.idx = i; ISL[x.id] = x end
local SHOPFILE = "KatssinnnHub/RodAndReef/shopnpc.json"
local SHOPNPC = { Bait = { Island1 = "Ilyas" }, Rod = { Island1 = "Tobias" } }   -- hanya Island1 yang terkonfirmasi log
do  -- muat hasil scan sebelumnya
    pcall(function()
        if isfile and readfile and isfile(SHOPFILE) then
            local d = game:GetService("HttpService"):JSONDecode(readfile(SHOPFILE))
            for _, k in ipairs({ "Bait", "Rod" }) do
                if type(d[k]) == "table" then
                    for isl, n in pairs(d[k]) do if ISL[isl] and type(n) == "string" then SHOPNPC[k][isl] = n end end
                end
            end
        end
    end)
end
local function saveShopNpc()
    pcall(function()
        if not writefile then return end
        if makefolder and isfolder then
            for _, f in ipairs({ "KatssinnnHub", "KatssinnnHub/RodAndReef" }) do
                if not isfolder(f) then pcall(makefolder, f) end
            end
        end
        writefile(SHOPFILE, game:GetService("HttpService"):JSONEncode(SHOPNPC))
    end)
end
local function curIsland()
    local z = LP:GetAttribute("Zone")
    return (type(z) == "string" and ISL[z]) and z or nil
end
local function islandLevel(id) return ISL[id] and ISL[id].lv or 0 end

-- nilai "stok" -> "all" | { [Island] = true } | nil
local function parseIsland(v)
    local tv = type(v)
    if tv == "string" then
        if v:lower() == "all" then return "all" end
        if ISL[v] then return { [v] = true } end
    elseif tv == "number" then
        local x = ISLANDS[math.floor(v)]
        if x then return { [x.id] = true } end
    elseif tv == "table" then
        local set, n = {}, 0
        for k, x in pairs(v) do
            local id
            if type(x) == "string" then
                if x:lower() == "all" then return "all" end
                if ISL[x] then id = x end
            elseif type(x) == "number" and type(k) == "number" and ISLANDS[x] then id = ISLANDS[x].id
            elseif x == true and type(k) == "string" then
                if k:lower() == "all" then return "all" end
                if ISL[k] then id = k end
            elseif x == true and type(k) == "number" and ISLANDS[k] then id = ISLANDS[k].id end
            if id then set[id] = true; n = n + 1 end
        end
        if n > 0 then return set end
    end
end
local function islandFromName(name)   -- I1CommonBait -> Island1 (terkonfirmasi untuk bait di log)
    local n = tonumber(name:match("^I(%d)%u")) or tonumber(name:match("^Island(%d)"))
    local x = n and ISLANDS[n]
    return x and { [x.id] = true } or nil
end
local function stockFromData(data)
    if type(data) ~= "table" then return nil end
    for k, v in pairs(data) do
        if type(k) == "string" then
            local lk = k:lower()
            if (lk:find("island", 1, true) or lk:find("stock", 1, true)) and not lk:find("element", 1, true) then
                local r = parseIsland(v)
                if r then return r, k end
            end
        end
    end
end
-- bentuk argumen ShopRules.IsStockedOn tidak terlihat di log -> dikalibrasi otomatis
local STOCK_FORMS = {
    { "(type,name,island)", function(f, t, n, d, i) return f(t, n, i) end },
    { "(name,island)", function(f, t, n, d, i) return f(n, i) end },
    { "(name,type,island)", function(f, t, n, d, i) return f(n, t, i) end },
    { "(data,island)", function(f, t, n, d, i) return f(d, i) end },
    { "(island,name)", function(f, t, n, d, i) return f(i, n) end },
    { "(island,type,name)", function(f, t, n, d, i) return f(i, t, n) end },
}
local STOCKFN = nil   -- { label, f(itemType, name, data, islandEntry) }
local function stockCalls()
    local fn = ShopRules and ShopRules.IsStockedOn
    local out = {}
    if type(fn) ~= "function" then return out end
    for _, w in ipairs({ { "", fn }, { "self,", function(...) return fn(ShopRules, ...) end } }) do
        for _, form in ipairs(STOCK_FORMS) do
            for _, km in ipairs({ "id", "idx" }) do
                out[#out + 1] = { label = w[1] .. form[1] .. "/" .. km, f = function(t, n, d, x)
                    return form[2](w[2], t, n, d, km == "id" and x.id or x.idx)
                end }
            end
        end
    end
    return out
end
local function calibrateStock(kind, list)
    if STOCKFN then return end
    local S = SHOP[kind]
    local best, bestScore
    for _, c in ipairs(stockCalls()) do
        local bad, cover, partial, agree, checked = 0, 0, 0, 0, 0
        for _, e in ipairs(list) do
            local t, f = 0, 0
            local res = {}
            for _, x in ipairs(ISLANDS) do
                local ok, r = pcall(c.f, S.itemType, e.name, e.data, x)
                if ok and type(r) == "boolean" then
                    res[x.id] = r
                    if r then t = t + 1 else f = f + 1 end
                else bad = bad + 1 end
            end
            if bad > 0 then break end
            if t >= 1 then cover = cover + 1 end
            if t >= 1 and f >= 1 then partial = partial + 1 end
            local pre = islandFromName(e.name)
            if pre then
                checked = checked + 1
                for id in pairs(pre) do if res[id] then agree = agree + 1 end end
            end
        end
        if bad == 0 and partial >= 1 and cover >= #list * 0.5 and (checked == 0 or agree / checked >= 0.8) then
            local score = partial * 1000 + cover * 10 + agree
            if not bestScore or score > bestScore then best, bestScore = c, score end
        end
    end
    STOCKFN = best
end
local function resolveStock(kind, list)
    local B, S = BUY[kind], SHOP[kind]
    calibrateStock(kind, list)
    local srcCount = {}
    for _, e in ipairs(list) do
        local set, src
        if STOCKFN then
            local s2, n = {}, 0
            for _, x in ipairs(ISLANDS) do
                local ok, r = pcall(STOCKFN.f, S.itemType, e.name, e.data, x)
                if ok and r == true then s2[x.id] = true; n = n + 1 end
            end
            if n == #ISLANDS then set = "all" elseif n > 0 then set = s2 end
            if set then src = "ShopRules.IsStockedOn" .. STOCKFN.label end
        end
        if not set then
            local s3, key = stockFromData(e.data)
            if s3 then set, src = s3, "field data: " .. key end
        end
        if not set then
            local s4 = islandFromName(e.name)
            if s4 then set, src = s4, "prefix nama item" end
        end
        e.stock = set
        local k = src or "TIDAK TERBACA"
        srcCount[k] = (srcCount[k] or 0) + 1
        -- syarat level efektif = max(level item, level toko pulau terendah yang menjual item ini)
        local req = e.level or 0
        if type(set) == "table" then
            local m
            for id in pairs(set) do local l = islandLevel(id); if not m or l < m then m = l end end
            if m and m > req then req = m end
        end
        e.reqLevel = (e.level ~= nil or type(set) == "table") and req or nil
    end
    local parts = {}
    for k, n in pairs(srcCount) do parts[#parts + 1] = k .. " x" .. n end
    table.sort(parts)
    B.stockSrc = table.concat(parts, "; ")
end
local function stockText(e)
    if e.stock == "all" then return "Semua pulau" end
    if type(e.stock) == "table" then
        local t = {}
        for _, x in ipairs(ISLANDS) do if e.stock[x.id] then t[#t + 1] = x.name end end
        return table.concat(t, "/")
    end
    return "pulau ?"
end
local function stockRank(e)
    if type(e.stock) == "table" then
        for i, x in ipairs(ISLANDS) do if e.stock[x.id] then return i end end
    end
    return e.stock == "all" and 0 or 9
end
local function reqLevel(e) return e.reqLevel or e.level end
-- pilih pulau + NPC toko untuk membeli item ini. Return (pulau, npc) atau (nil, pulauYangNPCnyaBelumDiketahui)
local function pickShop(kind, e, force)
    local npcs = SHOPNPC[kind]
    local cands = {}
    for _, x in ipairs(ISLANDS) do
        if e.stock == "all" or e.stock == nil or (type(e.stock) == "table" and e.stock[x.id]) then cands[#cands + 1] = x.id end
    end
    local cur = curIsland()
    for _, id in ipairs(cands) do   -- sudah di pulau yang tepat: tidak perlu pindah
        if id == cur and npcs[id] then return id, npcs[id] end
    end
    for _, id in ipairs(cands) do
        if npcs[id] and (force or islandLevel(id) <= myLevel()) then return id, npcs[id] end
    end
    for _, id in ipairs(cands) do
        if npcs[id] then return id, npcs[id] end
    end
    return nil, cands[1]
end

-- ---------- katalog: scan item, harga, syarat level ----------
local function callDB(db, fname, ...)
    local f = db and db[fname]
    if type(f) ~= "function" then return nil end
    local ok, r = pcall(f, ...)
    if ok and r ~= nil then return r end
    ok, r = pcall(f, db, ...)
    if ok then return r end
    return nil
end
-- GetAll bisa mengembalikan array nama, array tabel, atau map nama -> data
local function listify(all)
    local out = {}
    if type(all) ~= "table" then return out end
    if #all > 0 then
        for _, v in ipairs(all) do
            if type(v) == "string" then out[#out + 1] = { name = v }
            elseif type(v) == "table" then
                local nm = v.Name or v.ItemName or v.Id or v.ID or v.name
                if type(nm) == "string" then out[#out + 1] = { name = nm, data = v } end
            end
        end
    else
        for k, v in pairs(all) do
            if type(k) == "string" then out[#out + 1] = { name = k, data = type(v) == "table" and v or nil } end
        end
    end
    return out
end
-- cari angka di data item lewat nama field (heuristik; sumber field dicatat untuk diagnosa)
local function findNum(t, pats, skipPats)
    if type(t) ~= "table" then return nil end
    local cands = {}
    local function walk(x, depth, path)
        if depth > 2 then return end
        for k, v in pairs(x) do
            if type(k) == "string" then
                local lk = k:lower()
                local hit = false
                for _, p in ipairs(pats) do if lk:find(p, 1, true) then hit = true break end end
                if hit and skipPats then
                    for _, p in ipairs(skipPats) do if lk:find(p, 1, true) then hit = false break end end
                end
                if hit and type(v) == "number" and v == v and v >= 0 then
                    cands[#cands + 1] = { v = v, key = path .. k, depth = depth, exact = (lk == pats[1]) }
                end
                if type(v) == "table" then walk(v, depth + 1, path .. k .. ".") end
            end
        end
    end
    walk(t, 0, "")
    if #cands == 0 then return nil end
    table.sort(cands, function(a, b)
        if a.exact ~= b.exact then return a.exact end
        if a.depth ~= b.depth then return a.depth < b.depth end
        if #a.key ~= #b.key then return #a.key < #b.key end
        return a.key < b.key
    end)
    return cands[1].v, cands[1].key
end
local function findDisplay(t)
    if type(t) ~= "table" then return nil end
    for k, v in pairs(t) do
        if type(k) == "string" and type(v) == "string" and v ~= "" then
            local lk = k:lower()
            if lk == "displayname" or lk == "display" then return v end
        end
    end
end
local LEVEL_FORMS = {
    { "(name)", function(f, t, n, d) return f(n) end },
    { "(type, name)", function(f, t, n, d) return f(t, n) end },
    { "(name, type)", function(f, t, n, d) return f(n, t) end },
    { "(data)", function(f, t, n, d) return f(d) end },
}
local function sourceStats(res)
    local num, distinct, seen = 0, 0, {}
    for _, v in pairs(res) do
        num = num + 1
        if not seen[v] then seen[v] = true; distinct = distinct + 1 end
    end
    return num, distinct
end
local function resolveLevels(kind, list)
    local B, S = BUY[kind], SHOP[kind]
    local best
    local fn = ShopRules and ShopRules.GetLevelRequirement
    if type(fn) == "function" then
        for fi, form in ipairs(LEVEL_FORMS) do
            local res = {}
            for _, e in ipairs(list) do
                local ok, r = pcall(form[2], fn, S.itemType, e.name, e.data)
                if ok and type(r) == "number" and r == r and r >= 0 and r <= 1000 then res[e.name] = r end
            end
            local num, distinct = sourceStats(res)
            if num > 0 and (not best or distinct > best.distinct or (distinct == best.distinct and num > best.num)) then
                best = { res = res, num = num, distinct = distinct, src = "ShopRules.GetLevelRequirement" .. form[1] }
            end
        end
    end
    local fres, fkey = {}, nil
    for _, e in ipairs(list) do
        local v, key = findNum(e.data, { "level" }, { "xp" })
        if v then fres[e.name] = v; fkey = fkey or key end
    end
    local fnum, fdistinct = sourceStats(fres)
    local pick
    if best and (fnum == 0 or best.distinct >= fdistinct) then pick = best
    elseif fnum > 0 then pick = { res = fres, src = "field data item: " .. tostring(fkey) } end
    if pick then
        for _, e in ipairs(list) do e.level = pick.res[e.name] end
        B.levelSrc = pick.src
    else
        B.levelSrc = "TIDAK TERBACA (syarat level tidak diketahui, tidak ada kunci)"
    end
end
local function isLocked(e) local r = reqLevel(e); return r ~= nil and r > myLevel() end
local function priceOf(kind, e) return e.price or BUY[kind].learned[e.name] end
local function fmtPrice(kind, e)
    if e.price then return "$" .. fmtNum(e.price) end
    local l = BUY[kind].learned[e.name]
    if l then return "~$" .. fmtNum(l) end
    return "harga ?"
end
local function rebuildLabels(kind)
    local B = BUY[kind]
    B.labels, B.byLabel = {}, {}
    local lv = myLevel()
    for _, e in ipairs(B.items) do
        local nm = e.display or e.name
        local rq = reqLevel(e)
        local lbl
        if rq and rq > lv then
            lbl = "[KUNCI] " .. nm .. " · butuh Lv " .. rq .. " · " .. fmtPrice(kind, e) .. " · " .. stockText(e)
        else
            lbl = nm .. " · " .. fmtPrice(kind, e) .. ((e.level and e.level > 0) and (" · Lv " .. e.level) or "") .. " · " .. stockText(e)
        end
        if B.byLabel[lbl] then lbl = lbl .. " (" .. e.name .. ")" end
        B.byLabel[lbl] = e
        B.labels[#B.labels + 1] = lbl
    end
    if B.dd then pcall(function() B.dd:SetList(B.labels) end) end
end
local function scanKind(kind)
    local S, B = SHOP[kind], BUY[kind]
    B.err = nil
    if not (S.db and type(S.db[S.getAll]) == "function") then
        B.err = "modul database / " .. S.getAll .. " tidak ada"; B.items = {}; rebuildLabels(kind); return false
    end
    B.raw = callDB(S.db, S.getAll)
    local list = listify(B.raw)
    if #list == 0 then
        B.err = S.getAll .. " kosong atau bentuk hasilnya tidak dikenal"; B.items = {}; rebuildLabels(kind); return false
    end
    for _, e in ipairs(list) do
        local one = callDB(S.db, S.getOne, e.name)
        if type(one) == "table" then e.data = one end
        e.display = findDisplay(e.data)
        e.price, e.priceKey = findNum(e.data, { "price", "cost" })
    end
    resolveLevels(kind, list)
    resolveStock(kind, list)
    table.sort(list, function(a, b)
        local ra, rb = stockRank(a), stockRank(b)
        if ra ~= rb then return ra < rb end
        local la, lb = a.level or 0, b.level or 0
        if la ~= lb then return la < lb end
        local pa, pb = a.price or math.huge, b.price or math.huge
        if pa ~= pb then return pa < pb end
        return a.name < b.name
    end)
    B.items, B.byName = list, {}
    for _, e in ipairs(list) do B.byName[e.name] = e end
    if B.sel and not B.byName[B.sel] then B.sel = nil end
    rebuildLabels(kind)
    return true
end
local function pickItem(kind, v)
    if type(v) == "table" then v = v[1] end
    local B = BUY[kind]
    local e = type(v) == "string" and B.byLabel[v] or nil
    if not e then return end
    if isLocked(e) and not B.force then
        N("Auto Buy " .. kind, "Membutuhkan level " .. reqLevel(e) .. " (level kamu " .. myLevel() .. ")", "#DC3232")
        return
    end
    B.sel = e.name
end
task.spawn(function()   -- relabel otomatis saat level naik
    local ls = LP:WaitForChild("leaderstats", 15)
    local lv = ls and ls:WaitForChild("Level", 15)
    if lv then
        lv:GetPropertyChangedSignal("Value"):Connect(function()
            for _, k in ipairs({ "Bait", "Rod" }) do pcall(rebuildLabels, k) end
        end)
    end
end)

-- ---------- pembelian ----------
local function waitResp(name, itemType, t0, id, timeout)
    local tt = os.clock()
    while os.clock() - tt < timeout do
        local r = buyResp
        if r and r.t >= t0 and r.name == name and r.type == itemType then return r end
        task.wait(0.05)
        if not alive(id) then return nil end
    end
end
local function sendBuy(S, name, amount, id)
    local t0 = os.clock()
    if not pcall(ShopP.RequestBuyItem.send, { amount = amount, itemName = name, itemType = S.itemType }) then return nil end
    return waitResp(name, S.itemType, t0, id, 3)
end
local function npcRoot(m)
    return m and (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true))
end
-- buka shop lewat dialog NPC (urutan paket persis seperti di log), lalu beli. npcName = NPC toko di pulau yang menjual item
local function buyViaNpc(S, npcName, name, amount, id, crossIsland)
    local folder = workspace:FindFirstChild("DialogueNPCs")
    local m = folder and folder:FindFirstChild(npcName)
    local p = npcRoot(m)
    local r = Root()
    if not (m and p and r and DialogueP and ShopP) then return nil end
    local back = r.CFrame
    r.CFrame = CFrame.new(p.Position + p.CFrame.LookVector * 4 + Vector3.new(0, 3, 0))
    r.AssemblyLinearVelocity = Vector3.zero
    local resp
    if wait(id, crossIsland and 1.5 or 0.6) then   -- pindah pulau: beri waktu zona/map dimuat
        local function step(pk, data) if pk then pcall(pk.send, data) end; return wait(id, 0.4) end
        local t = os.clock()
        step(DialogueP.RequestNPCInteraction, { npcId = npcName, npcModel = m })
        while dlgStartT < t and os.clock() - t < 3 do task.wait(0.05) end
        step(DialogueP.DialogueSelectBranch, { npcId = npcName, branchId = npcName .. "_Greet_r1" })
        step(DialogueP.DialogueAction, { npcId = npcName, actionId = "OpenShop", payload = S.payload })
        step(DialogueP.DialogueAdvance, { npcId = npcName, nodeId = npcName .. "_OpenShop" })
        step(DialogueP.NPCInteractionEnd, { npcId = npcName, reason = "endOfDialogue" })
        if wait(id, 0.6) then resp = sendBuy(S, name, amount, id) end
    end
    local r2 = Root()
    if r2 then r2.CFrame = back; r2.AssemblyLinearVelocity = Vector3.zero end
    return resp
end
-- Item dijual di toko pulau tertentu: kalau sudah di pulau itu coba kirim langsung dulu; kalau tidak sukses
-- (atau beda pulau) -> teleport ke NPC toko pulau itu, beli, lalu kembali. Mode diingat per jenis item + pulau.
local function purchase(kind, name, amount, id, e)
    local S, B = SHOP[kind], BUY[kind]
    if not (ShopP and ShopP.RequestBuyItem) then return false, "packet Shop.RequestBuyItem tidak ada" end
    local isl, npc = pickShop(kind, e or {}, B.force)
    if not isl then
        local nm = ISL[npc] and ISL[npc].name or "?"
        return false, "NPC toko " .. nm .. " belum diketahui, tekan Scan toko NPC"
    end
    B.lastIsland = isl
    local c0 = coins()
    local resp
    local here = curIsland() == isl
    if here and B.modeBy[isl] ~= "npc" then
        resp = sendBuy(S, name, amount, id)
        if not alive(id) then return false, "dibatalkan" end
        if resp and resp.ok then B.modeBy[isl] = "direct" end
    end
    if not (resp and resp.ok) then
        resp = buyViaNpc(S, npc, name, amount, id, not here)
        if not alive(id) then return false, "dibatalkan" end
        if resp and resp.ok then B.modeBy[isl] = "npc" end
    end
    if not (resp and resp.ok) then
        return false, resp and "server menolak (success=false)" or "tidak ada balasan server"
    end
    local t0 = os.clock()   -- baca selisih koin segera setelah turun, sebelum reward lain masuk
    while coins() >= c0 and os.clock() - t0 < 1.5 do task.wait(0.05) end
    local spent = c0 - coins()
    if spent > 0 and amount > 0 then B.learned[name] = spent / amount end
    return true
end

-- ---------- scan NPC toko semua pulau ----------
-- Toko tiap pulau dijalankan NPC berbeda (log hanya menunjukkan Island1: Ilyas/Tobias). Scan ini mengelompokkan NPC di
-- Workspace.DialogueNPCs per pulau (titik tengah dari Workspace.MAP.IslandN), lalu mencoba urutan dialog toko ke tiap NPC;
-- NPC yang membalas paket Shop.OpenShop "Baits"/"Rods" dicatat (disimpan ke file, tidak perlu scan ulang).
local disc = { running = false, cancel = false, status = "belum pernah scan" }
local SKIPNPC = { Oliver = true, CombatMaster = true, IlyasDock = true, BoatManager = true }
local ISLCENTER
local function islandCenters()
    if ISLCENTER then return ISLCENTER end
    local out = {}
    local map = workspace:FindFirstChild("MAP")
    for _, x in ipairs(ISLANDS) do
        local f = map and map:FindFirstChild(x.id)
        if f then
            local xs, zs, n = {}, {}, 0
            for _, d in ipairs(f:GetDescendants()) do
                n = n + 1
                if n % 4000 == 0 then task.wait() end
                if d:IsA("BasePart") and math.abs(d.Position.Y) < 500 and #xs < 60000 then
                    xs[#xs + 1] = d.Position.X; zs[#zs + 1] = d.Position.Z
                end
            end
            if #xs > 0 then
                table.sort(xs); table.sort(zs)
                out[x.id] = Vector3.new(xs[math.ceil(#xs / 2)], 0, zs[math.ceil(#zs / 2)])   -- median: tahan outlier (mis. Dock1 di koordinat aneh)
            end
        end
    end
    ISLCENTER = out
    return out
end
local function probeNpc(m, p)
    local r = Root()
    if not r then return nil end
    r.CFrame = CFrame.new(p.Position + p.CFrame.LookVector * 4 + Vector3.new(0, 3, 0))
    r.AssemblyLinearVelocity = Vector3.zero
    task.wait(0.7)
    local name, found = m.Name, nil
    local function send(pk, data) if pk then pcall(pk.send, data) end; task.wait(0.35) end
    local t = os.clock()
    send(DialogueP.RequestNPCInteraction, { npcId = name, npcModel = m })
    while dlgStartT < t and os.clock() - t < 1.5 do task.wait(0.05) end
    if dlgStartT < t then   -- NPC ini tidak membuka dialog
        pcall(DialogueP.NPCInteractionEnd.send, { npcId = name, reason = "endOfDialogue" })
        return nil
    end
    send(DialogueP.DialogueSelectBranch, { npcId = name, branchId = name .. "_Greet_r1" })
    for _, payload in ipairs({ "Baits", "Rods" }) do
        local t2 = os.clock()
        send(DialogueP.DialogueAction, { npcId = name, actionId = "OpenShop", payload = payload })
        local w = os.clock()
        while os.clock() - w < 0.6 do
            if OPENSHOP and OPENSHOP.t >= t2 then found = OPENSHOP.payload; break end
            task.wait(0.05)
        end
        if found then break end
    end
    send(DialogueP.DialogueAdvance, { npcId = name, nodeId = name .. "_OpenShop" })
    send(DialogueP.NPCInteractionEnd, { npcId = name, reason = "endOfDialogue" })
    local s = found and tostring(found):lower() or ""
    if s:find("bait", 1, true) then return "Bait" elseif s:find("rod", 1, true) then return "Rod" end
    return nil
end
local function discoverShops()
    if disc.running then N("Scan toko", "Scan sedang berjalan", "#DC3232"); return end
    if running then N("Scan toko", "Matikan fishing dulu", "#DC3232"); return end
    if not (DialogueP and ShopP and DialogueP.RequestNPCInteraction) then N("Scan toko", "Packet Dialogue/Shop tidak ada", "#DC3232"); return end
    disc.running, disc.cancel = true, false
    task.spawn(function()
        local r0 = Root()
        local back = r0 and r0.CFrame
        local ok, err = pcall(function()
            local folder = workspace:FindFirstChild("DialogueNPCs")
            if not folder then disc.status = "Workspace.DialogueNPCs tidak ada"; return end
            disc.status = "menghitung posisi pulau..."
            local centers = islandCenters()
            local ily = npcRoot(folder:FindFirstChild("Ilyas"))
            if ily then centers.Island1 = Vector3.new(ily.Position.X, 0, ily.Position.Z) end
            local groups = {}
            for _, m in ipairs(folder:GetChildren()) do
                local p = m:IsA("Model") and not SKIPNPC[m.Name] and npcRoot(m)
                if p then
                    local bid, bd
                    for id, c in pairs(centers) do
                        local d = ((p.Position.X - c.X) ^ 2 + (p.Position.Z - c.Z) ^ 2) ^ 0.5
                        if not bd or d < bd then bid, bd = id, d end
                    end
                    if bid and bd < 2500 then
                        groups[bid] = groups[bid] or {}
                        table.insert(groups[bid], { m = m, p = p, d = bd })
                    end
                end
            end
            local found = 0
            for _, x in ipairs(ISLANDS) do
                local list = groups[x.id]
                if list and not (SHOPNPC.Bait[x.id] and SHOPNPC.Rod[x.id]) then
                    table.sort(list, function(a, b) return a.d < b.d end)
                    for i, c in ipairs(list) do
                        if disc.cancel or (SHOPNPC.Bait[x.id] and SHOPNPC.Rod[x.id]) then break end
                        disc.status = x.name .. ": cek " .. c.m.Name .. " (" .. i .. "/" .. #list .. ")"
                        local kind = probeNpc(c.m, c.p)
                        if kind and not SHOPNPC[kind][x.id] then
                            SHOPNPC[kind][x.id] = c.m.Name
                            found = found + 1
                            saveShopNpc()
                        end
                    end
                end
                if disc.cancel then break end
            end
            local parts = {}
            for _, x in ipairs(ISLANDS) do
                parts[#parts + 1] = x.name .. " Bait=" .. tostring(SHOPNPC.Bait[x.id]) .. " Rod=" .. tostring(SHOPNPC.Rod[x.id])
            end
            disc.status = (disc.cancel and "dibatalkan. " or "selesai. ") .. table.concat(parts, " | ")
            N("Scan toko", (disc.cancel and "Dibatalkan" or "Selesai") .. ", " .. found .. " NPC baru", "#50C864")
        end)
        if not ok then disc.status = "error: " .. tostring(err):sub(1, 80); N("Scan toko", disc.status, "#DC3232") end
        local r1 = Root()
        if r1 and back then r1.CFrame = back; r1.AssemblyLinearVelocity = Vector3.zero end
        disc.running = false
    end)
end

-- ---------- langkah auto buy ----------
local function failed(B, why)
    B.fails = B.fails + 1
    B.status = "gagal: " .. why
    if B.fails >= 3 then
        B.fails = 0
        B.nextTry = os.clock() + 60
        B.status = "gagal 3x (" .. why .. "), coba lagi 60 detik"
    end
end
local STEP = {}
STEP.Bait = function(id, now)
    local B = BUY.Bait
    local e = B.sel and B.byName[B.sel]
    if not e then B.status = "pilih bait dulu"; return end
    if isLocked(e) and not B.force then B.status = "terkunci, butuh level " .. reqLevel(e); return end
    local have = ownedBait(e.name)
    if not now and have >= B.min then B.status = "stok cukup (" .. have .. ")"; return end
    local amount = clampInt(B.per, 1, MAXBUY)
    local price = priceOf("Bait", e)
    if price and price > 0 then
        local afford = math.floor(coins() / price)
        if afford < 1 then B.status = "koin kurang (butuh $" .. fmtNum(price) .. ")"; return end
        amount = math.min(amount, afford)
    else
        amount = 1   -- harga belum diketahui: beli 1 dulu untuk membaca harga dari selisih koin
    end
    B.status = "beli " .. amount .. "x " .. (e.display or e.name)
    local ok, why = purchase("Bait", e.name, amount, id, e)
    if not alive(id) then return end
    if ok then
        B.fails = 0
        B.status = "dibeli " .. amount .. "x " .. (e.display or e.name)
        rebuildLabels("Bait")
        N("Auto Buy Bait", "Dibeli " .. amount .. "x " .. (e.display or e.name), "#50C864")
    else
        failed(B, why)
    end
end
STEP.Rod = function(id, now)
    local B = BUY.Rod
    local e = B.sel and B.byName[B.sel]
    if not e then B.status = "pilih rod dulu"; return end
    if ownsRod(e.name) then B.status = "sudah dimiliki"; return end
    if isLocked(e) and not B.force then B.status = "terkunci, butuh level " .. reqLevel(e); return end
    local price = priceOf("Rod", e)
    if price and coins() < price then B.status = "koin kurang (butuh $" .. fmtNum(price) .. ")"; return end
    B.status = "beli " .. (e.display or e.name)
    local ok, why = purchase("Rod", e.name, 1, id, e)
    if not alive(id) then return end
    if ok then
        B.fails = 0
        B.status = "dibeli " .. (e.display or e.name)
        rebuildLabels("Rod")
        N("Auto Buy Rod", "Dibeli " .. (e.display or e.name), "#50C864")
    else
        failed(B, why)
    end
end
local function autoBuyStep(id)
    if os.clock() < nextBuyCheck then return end
    nextBuyCheck = os.clock() + 6
    for _, kind in ipairs({ "Bait", "Rod" }) do
        local B = BUY[kind]
        if B.enabled and os.clock() >= B.nextTry then
            local ok, err = pcall(STEP[kind], id, false)
            if not ok then B.status = "error: " .. tostring(err):sub(1, 60) end
            if not alive(id) then return end
        end
    end
end
local function buyNow(kind)
    if running then N("Beli", "Matikan fishing dulu", "#DC3232"); return end
    task.spawn(function()
        local ok, err = pcall(STEP[kind], nil, true)
        if not ok then BUY[kind].status = "error: " .. tostring(err):sub(1, 60) end
        N("Beli " .. kind, BUY[kind].status, "#6495ED")
    end)
end

-- ---------- info + diagnosa ----------
local function infoText(kind)
    local B = BUY[kind]
    if B.err then return "Scan gagal: " .. B.err .. "\nTekan Salin diagnosa dan kirim ke pembuat script" end
    local e = B.sel and B.byName[B.sel]
    if not e then return "Terpilih: -\nKatalog: " .. #B.items .. " item   Level kamu: " .. myLevel() .. "\nScan toko: " .. disc.status end
    local rq = reqLevel(e)
    local req = rq == nil and "?" or (rq > 0 and ("Lv " .. rq) or "tanpa syarat")
    local l3
    if kind == "Bait" then l3 = "Stok: " .. ownedBait(e.name)
    else l3 = ownsRod(e.name) and "Sudah dimiliki" or "Belum dimiliki" end
    local isl, npc = pickShop(kind, e, B.force)
    local shop = isl and (ISL[isl].name .. " · NPC " .. npc) or ("NPC " .. (ISL[npc] and ISL[npc].name or "?") .. " belum ketemu, tekan Scan toko NPC")
    return "Terpilih: " .. (e.display or e.name) ..
        "\nHarga: " .. fmtPrice(kind, e) .. "   Syarat: " .. req .. "   Level kamu: " .. myLevel() ..
        "\nDijual di: " .. stockText(e) .. "\nBeli di: " .. shop ..
        "\n" .. l3 .. "   Status: " .. B.status ..
        (disc.running and ("\nScan toko: " .. disc.status) or "")
end
local function dser(v, d)
    d = d or 0
    local tv = typeof(v)
    if tv == "string" then return string.format("%q", v:sub(1, 80)) end
    if tv == "table" then
        if d >= 3 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 25 then parts[#parts + 1] = "..."; break end
            parts[#parts + 1] = tostring(k) .. "=" .. dser(x, d + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    if tv == "function" then return "<fn>" end
    return tostring(v)
end
local function diagText(kind)
    local B, S = BUY[kind], SHOP[kind]
    local out = { "== diagnosa auto buy " .. kind .. " ==",
        "level kamu: " .. myLevel() .. "   koin: " .. coins() .. "   mode beli per pulau: " .. dser(B.modeBy) .. "   pulau sekarang: " .. tostring(curIsland()),
        "db ada: " .. tostring(S.db ~= nil) .. "   ShopRules ada: " .. tostring(ShopRules ~= nil),
        "GetAll bentuk: " .. typeof(B.raw) .. "   item terbaca: " .. #B.items,
        "sumber level: " .. tostring(B.levelSrc), "error scan: " .. tostring(B.err),
        "sumber stok pulau: " .. tostring(B.stockSrc), "NPC toko: " .. dser(SHOPNPC), "scan toko: " .. disc.status }
    for i, e in ipairs(B.items) do
        if i > 6 then break end
        out[#out + 1] = string.format("[%d] %s display=%s price=%s(%s) level=%s stok=%s", i, e.name, tostring(e.display),
            tostring(e.price), tostring(e.priceKey), tostring(e.level), stockText(e))
        out[#out + 1] = "    data: " .. dser(e.data)
    end
    if type(B.raw) == "table" and #B.items == 0 then out[#out + 1] = "raw GetAll: " .. dser(B.raw) end
    local okC, SC = pcall(function() return require(PS.Controllers.GUI.ShopController) end)
    if okC and type(SC) == "table" then
        local names = {}
        for k, v in pairs(SC) do names[#names + 1] = tostring(k) .. ":" .. type(v) end
        table.sort(names)
        out[#out + 1] = "ShopController: " .. table.concat(names, ", "):sub(1, 600)
    else
        out[#out + 1] = "ShopController tidak bisa di-require"
    end
    return table.concat(out, "\n")
end
local function copyDiag(kind)
    local txt = diagText(kind)
    if setclipboard then
        pcall(setclipboard, txt)
        N("Diagnosa " .. kind, "Disalin ke clipboard", "#50C864")
    else
        print(txt)
        N("Diagnosa " .. kind, "setclipboard tidak ada, hasil di console (F9)", "#DC3232")
    end
end
task.spawn(function()
    for _, k in ipairs({ "Bait", "Rod" }) do
        local ok, err = pcall(scanKind, k)
        if not ok then BUY[k].err = tostring(err):sub(1, 80) end
    end
end)

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

    -- 0b. auto buy bait / rod (kartu terpisah di Main)
    autoBuyStep(id)
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

-- ---------- Auto Buy Bait & Auto Buy Rod (dua kartu terpisah) ----------
local function buildBuyCard(kind, col, icon, id)
    local B = BUY[kind]
    local c = Main:AddCard({ Title = "Auto Buy " .. kind, Icon = icon, Column = col })
    B.dd = c:Dropdown({
        Title = "Pilih " .. kind, List = B.labels, Placeholder = "Pilih " .. kind:lower(),
        Callback = function(v) pickItem(kind, v) end,
    })
    B.lbl = c:Label({ Text = "-", Size = 11, Color = "Text" })
    c:Toggle({
        Title = "Auto Buy " .. kind,
        Desc = kind == "Bait" and "Beli otomatis saat stok di bawah batas (teleport ke toko pulau yang menjual, lalu kembali)" or "Beli rod terpilih kalau koin cukup dan belum dimiliki (teleport ke toko pulau yang menjual)",
        id = "g14_buy" .. id,
        Callback = function(v)
            B.enabled = v
            B.nextTry = 0
            nextBuyCheck = 0
            N("Auto Buy " .. kind, v and "ON (jalan bersama fishing)" or "OFF", v and "#50C864" or "#DC3232")
        end,
    })
    if kind == "Bait" then
        c:Input({
            Title = "Beli jika stok di bawah", Value = tostring(B.min), Placeholder = "20", ButtonText = "Set", id = "g14_baitMin",
            Callback = function(v) local n = math.floor(tonumber(v) or 0); if n >= 1 then B.min = n end end,
            OnButton = function(v)
                local n = math.floor(tonumber(v) or 0)
                if n >= 1 then B.min = n; N("Auto Buy Bait", "Beli jika stok di bawah " .. n, "#50C864")
                else N("Auto Buy Bait", "Isi angka 1 atau lebih", "#DC3232") end
            end,
        })
        c:Input({
            Title = "Jumlah per pembelian (maks " .. MAXBUY .. ")", Value = tostring(B.per), Placeholder = "10", ButtonText = "Set", id = "g14_baitPer",
            Callback = function(v) local n = math.floor(tonumber(v) or 0); if n >= 1 then B.per = math.min(n, MAXBUY) end end,
            OnButton = function(v)
                local n = math.floor(tonumber(v) or 0)
                if n >= 1 then B.per = math.min(n, MAXBUY); N("Auto Buy Bait", "Beli " .. B.per .. " per pembelian", "#50C864")
                else N("Auto Buy Bait", "Isi angka 1 atau lebih", "#DC3232") end
            end,
        })
    end
    c:Toggle({
        Title = "Izinkan pilih item terkunci", Desc = "Matikan kunci level (server tetap menolak kalau memang belum boleh)",
        id = "g14_force" .. id,
        Callback = function(v) B.force = v end,
    })
    c:Button({ Title = "Beli sekarang", Text = kind == "Bait" and "Beli bait terpilih" or "Beli rod terpilih", Callback = function() buyNow(kind) end })
    c:Button({
        Title = "Scan ulang", Text = "Scan " .. kind:lower() .. " + harga",
        Callback = function()
            task.spawn(function()
                local ok, err = pcall(scanKind, kind)
                if not ok then B.err = tostring(err):sub(1, 80) end
                N("Scan " .. kind, B.err and ("Gagal: " .. B.err) or (#B.items .. " item ditemukan"), B.err and "#DC3232" or "#6495ED")
            end)
        end,
    })
    c:Button({ Title = "Scan toko NPC", Text = "Cari NPC Bait/Rod tiap pulau", Callback = discoverShops })
    c:Button({ Title = "Batal scan", Text = "Hentikan scan toko", Callback = function() disc.cancel = true end })
    c:Button({ Title = "Salin diagnosa", Text = "Salin diagnosa " .. kind:lower(), Callback = function() copyDiag(kind) end })
end
buildBuyCard("Bait", 1, "coins", "bait")
buildBuyCard("Rod", 2, "fish", "rod")
task.spawn(function()
    while W.Alive do
        task.wait(1)
        for _, k in ipairs({ "Bait", "Rod" }) do
            local B = BUY[k]
            if B.lbl then pcall(function() B.lbl:SetText(infoText(k)) end) end
        end
    end
end)

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
                "\nMode jual: " .. (sellMode or "belum diketahui") ..
                "\nBait: " .. BUY.Bait.status .. "\nRod: " .. BUY.Rod.status .. (disc.running and ("\nScan toko: " .. disc.status) or ""))
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
