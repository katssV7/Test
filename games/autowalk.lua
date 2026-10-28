-- KatssinnnHub | Auto Walk (rekam & putar ulang, untuk push summit / obby)
-- Cara kerja:
--  * REKAM: jalur yang kamu lewati (posisi + titik lompat) disimpan per checkpoint (CP 1, CP 2, ...).
--  * PUTAR: karakter berjalan sendiri mengikuti jalur rekaman lewat Humanoid:Move() + lompat di titik yang sama.
--    Tidak ada CFrame/teleport, tidak ada velocity paksa -> gerakannya natural (tidak slide / glitch).
--  * Kalau melenceng, jalur dikoreksi terus-menerus; kalau nyangkut, otomatis coba lompat / sinkron ulang.
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "Auto Walk",
    Folder    = "KatssinnnHub/AutoWalk",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local LP = Players.LocalPlayer

-- ===== PENGATURAN (bisa diubah di kartu Tuning) =====
local LOOK        = 2.2    -- jarak "mata" ke depan di darat (studs)
local LOOK_AIR    = 3.2    -- jarak ke depan saat di udara
local SPACING     = 0.2    -- jarak minimum antar titik rekaman (studs)
local TOL         = 3.0    -- toleransi langsung mulai di titik awal CP
local RETRY       = true   -- ulangi CP otomatis saat mati
local ALLOW_TP    = false  -- teleport hanya kalau titik awal benar-benar tak terjangkau
local SEL, FROM, TO = 1, 1, 0

-- ===== PENYIMPANAN =====
local FS_OK = (writefile and readfile and isfile and isfolder and makefolder) and true or false
local DIR = "KatssinnnHub/AutoWalk/" .. tostring(game.PlaceId)
local CPS = {}   -- [nomor] = { pts = {Vector3}, jumps = {idx}, cum = {}, n, len, dur }

local function EnsureDir()
    if not FS_OK then return end
    pcall(function()
        for _, d in ipairs({ "KatssinnnHub", "KatssinnnHub/AutoWalk", DIR }) do
            if not isfolder(d) then makefolder(d) end
        end
    end)
end
local function CpPath(n) return DIR .. "/cp" .. n .. ".json" end

local function MakeCP(pts, jumps, dur)
    local cum = table.create(#pts)
    cum[1] = 0
    for i = 2, #pts do cum[i] = cum[i - 1] + (pts[i] - pts[i - 1]).Magnitude end
    return { pts = pts, jumps = jumps, cum = cum, n = #pts, len = cum[#pts], dur = dur or 0 }
end

local function R2(x) return math.floor(x * 100 + 0.5) / 100 end

local function SaveCP(n, cp)
    if not FS_OK then return false end
    EnsureDir()
    local flat = table.create(#cp.pts * 3)
    for i, p in ipairs(cp.pts) do
        flat[#flat + 1] = R2(p.X); flat[#flat + 1] = R2(p.Y); flat[#flat + 1] = R2(p.Z)
    end
    local ok = pcall(function()
        writefile(CpPath(n), HttpService:JSONEncode({ v = 1, pts = flat, jumps = cp.jumps, dur = cp.dur }))
    end)
    return ok
end

local function LoadAll()
    if not (FS_OK and listfiles) then return end
    EnsureDir()
    pcall(function()
        for _, f in ipairs(listfiles(DIR)) do
            local n = tonumber(tostring(f):match("cp(%d+)%.json$"))
            if n then
                local ok, data = pcall(function() return HttpService:JSONDecode(readfile(f)) end)
                if ok and type(data) == "table" and type(data.pts) == "table" then
                    local pts = {}
                    for i = 1, #data.pts - 2, 3 do pts[#pts + 1] = Vector3.new(data.pts[i], data.pts[i + 1], data.pts[i + 2]) end
                    if #pts >= 2 then CPS[n] = MakeCP(pts, data.jumps or {}, data.dur) end
                end
            end
        end
    end)
end
LoadAll()

local function Sorted()
    local t = {}
    for n in pairs(CPS) do t[#t + 1] = n end
    table.sort(t)
    return t
end

-- ===== UTIL =====
local function Hum()
    local c = LP.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h and h.Health > 0 then return h end
end
local function Root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function dist2(a, b)
    local dx, dz = a.X - b.X, a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end
local function metric(a, b) return dist2(a, b) + 0.6 * math.abs(a.Y - b.Y) end

local controls
local function CtrlSet(enable)
    if controls == nil then
        controls = false
        pcall(function()
            local pm = LP:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
            if pm then controls = require(pm):GetControls() end
        end)
    end
    if controls then pcall(function() if enable then controls:Enable() else controls:Disable() end end) end
end

local function Clear(a, b)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { LP.Character }
    rp.IgnoreWater = true
    return workspace:Raycast(a, b - a, rp) == nil
end

-- ===== REKAM =====
local rec
local RefreshInfo   -- diisi di bagian UI

local function RecStop(save)
    if not rec then return end
    local r = rec
    rec = nil
    for _, c in ipairs(r.conns) do pcall(function() c:Disconnect() end) end
    if not save then N("Rekam", "Rekaman dibatalkan", "#FFA500"); RefreshInfo(); return end
    if #r.pts < 5 then N("Rekam", "Terlalu pendek, tidak disimpan", "#DC3232"); RefreshInfo(); return end
    local cp = MakeCP(r.pts, r.jumps, os.clock() - r.t0)
    CPS[r.cp] = cp
    local saved = SaveCP(r.cp, cp)
    N("CP " .. r.cp .. " tersimpan", string.format("%d titik · %.0f studs · %.1fs%s", cp.n, cp.len, cp.dur,
        saved and "" or " (hanya di memori, executor tanpa writefile)"), "#50C864", 5)
    RefreshInfo()
end

local P   -- playback (didefinisikan di bawah)

local function RecStart(n)
    if rec then N("Rekam", "Sedang merekam. Tekan Stop & simpan dulu.", "#FFA500"); return end
    if P.on then N("Rekam", "Hentikan playback dulu.", "#FFA500"); return end
    local hrp, hum = Root(), Hum()
    if not hrp or not hum then N("Rekam", "Karakter belum siap", "#DC3232"); return end
    rec = { cp = n, pts = { hrp.Position }, jumps = {}, t0 = os.clock(), conns = {} }
    rec.conns[1] = RunService.Heartbeat:Connect(function()
        local h, hu = Root(), Hum()
        if not rec then return end
        if not h or not hu then
            N("Rekam", "Karakter mati, rekaman dibatalkan", "#DC3232")
            RecStop(false)
            return
        end
        if (h.Position - rec.pts[#rec.pts]).Magnitude >= SPACING then rec.pts[#rec.pts + 1] = h.Position end
    end)
    rec.conns[2] = hum.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Jumping and rec then
            local h = Root()
            if not h then return end
            if (h.Position - rec.pts[#rec.pts]).Magnitude > 0.02 then rec.pts[#rec.pts + 1] = h.Position end
            rec.jumps[#rec.jumps + 1] = #rec.pts
        end
    end)
    N("Rekam CP " .. n, "Mulai berjalan. Tekan Stop & simpan di akhir CP.", "#50C864", 4)
    RefreshInfo()
end

-- ===== PLAYBACK =====
P = {
    on = false, id = 0, state = "idle", status = "idle", deaths = 0,
    seq = {}, si = 0, cp = nil, cpn = 0, idx = 1, jp = 1,
    dirSm = Vector3.zero, prog = 0, progT = 0, resyncs = 0,
}

local function Stop(msg, color)
    if not P.on then return end
    P.on = false
    P.id += 1
    P.state = "idle"
    P.status = msg or "berhenti"
    local h = Hum()
    if h then pcall(function() h:Move(Vector3.zero, false) end) end
    CtrlSet(true)
    if msg then N("Auto Walk", msg, color or "#6495ED", 4) end
end

local function SyncJumpPtr()
    local cp = P.cp
    P.jp = 1
    while P.jp <= #cp.jumps and cp.jumps[P.jp] < P.idx do P.jp += 1 end
end

local function Approach(target)
    P.state = "planning"
    local id = P.id
    task.spawn(function()
        local hrp = Root()
        if not hrp then return end
        local pos = hrp.Position
        local wps
        if dist2(pos, target) <= 10 and math.abs(pos.Y - target.Y) <= 3 and Clear(pos, target) then
            wps = { { Position = target, Jump = false } }
        else
            local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = false })
            local ok = pcall(function() path:ComputeAsync(pos, target) end)
            if ok and path.Status == Enum.PathStatus.Success then
                wps = {}
                for _, w in ipairs(path:GetWaypoints()) do
                    wps[#wps + 1] = { Position = w.Position, Jump = (w.Action == Enum.PathWaypointAction.Jump) }
                end
            end
        end
        if P.id ~= id or not P.on then return end
        if wps and #wps > 0 then
            P.wps, P.wpi, P.state, P.approachT = wps, 1, "approach", os.clock()
        elseif ALLOW_TP then
            local h = Root()
            if h then h.CFrame = CFrame.new(target + Vector3.new(0, 3, 0)) end
            P.state = "follow"; P.prog = P.cp.cum[P.idx]; P.progT = os.clock()
        else
            Stop("Titik awal CP " .. P.cpn .. " tidak terjangkau (jauh / terhalang)", "#DC3232")
        end
    end)
end

local function BeginSeg(si, startIdx)
    local n = P.seq[si]
    local cp = CPS[n]
    if not cp then Stop("CP " .. tostring(n) .. " belum direkam", "#DC3232"); return end
    P.si, P.cp, P.cpn = si, cp, n
    P.idx = startIdx or 1
    P.resyncs = 0
    P.prog, P.progT = cp.cum[P.idx], os.clock()
    SyncJumpPtr()
    local hrp = Root()
    if hrp and metric(hrp.Position, cp.pts[P.idx]) <= TOL then P.state = "follow" else Approach(cp.pts[P.idx]) end
end

local function Steer(hum, dir, dt)
    if dir.Magnitude < 1e-4 then return end
    dir = dir.Unit
    if P.dirSm.Magnitude < 1e-4 then
        P.dirSm = dir
    else
        local m = P.dirSm:Lerp(dir, math.min(1, dt * 20))
        P.dirSm = (m.Magnitude > 1e-3) and m.Unit or dir
    end
    hum:Move(P.dirSm, false)
end

local function Play(seq)
    if rec then N("Auto Walk", "Selesaikan rekaman dulu.", "#FFA500"); return end
    if #seq == 0 then N("Auto Walk", "Belum ada CP yang direkam", "#DC3232"); return end
    if P.on then Stop() end
    P.on = true
    P.id += 1
    P.seq, P.deaths, P.dirSm = seq, 0, Vector3.zero
    P.status = "mulai"
    CtrlSet(false)
    BeginSeg(1, 1)
end

local function Step(dt)
    if not P.on then return end
    local hum, hrp = Hum(), Root()

    -- mati / respawn
    if not hum or not hrp then
        if P.state ~= "respawn" then
            P.deaths += 1
            if not RETRY or P.deaths > 100 then Stop("Karakter mati, berhenti", "#DC3232"); return end
            P.state, P.respawnAt = "respawn", nil
            P.status = "menunggu respawn"
        end
        return
    end
    if P.state == "respawn" then
        if not P.respawnAt then P.respawnAt = os.clock() + 1.2 end
        if os.clock() >= P.respawnAt then CtrlSet(false); P.dirSm = Vector3.zero; BeginSeg(P.si, 1) end
        return
    end

    local pos, now = hrp.Position, os.clock()
    local st = P.state

    if st == "planning" then
        pcall(function() hum:Move(Vector3.zero, false) end)
        P.status = "merencanakan jalan ke titik awal"
        return
    end

    if st == "approach" then
        P.status = "menuju titik awal CP " .. P.cpn
        local wp = P.wps[P.wpi]
        if not wp then
            P.state, P.prog, P.progT = "follow", P.cp.cum[P.idx], now
            return
        end
        if dist2(pos, wp.Position) < 2.2 then
            P.wpi += 1
            local nw = P.wps[P.wpi]
            if not nw then
                P.state, P.prog, P.progT = "follow", P.cp.cum[P.idx], now
            elseif nw.Jump then
                hum.Jump = true
            end
        else
            Steer(hum, Vector3.new(wp.Position.X - pos.X, 0, wp.Position.Z - pos.Z), dt)
        end
        if now - P.approachT > 25 then Stop("Gagal sampai titik awal CP " .. P.cpn, "#DC3232") end
        return
    end

    -- ===== follow =====
    local cp = P.cp
    local pts, cum = cp.pts, cp.cum

    -- majukan indeks ke titik terdekat di depan (tidak mundur; sedikit bias ke depan jalur)
    local best, bs = P.idx, metric(pos, pts[P.idx])
    local j = P.idx + 1
    while j <= cp.n and cum[j] - cum[P.idx] <= 8 do
        local s = metric(pos, pts[j]) + 0.1 * (cum[j] - cum[P.idx])
        if s < bs then bs, best = s, j end
        j += 1
    end
    P.idx = best

    -- lompat di titik yang direkam
    local jumpNow = false
    while true do
        local ji = cp.jumps[P.jp]
        if ji and cum[ji] - cum[P.idx] <= 0.25 then P.jp += 1; jumpNow = true else break end
    end
    if jumpNow then hum.Jump = true end

    -- selesai segmen?
    local last = pts[cp.n]
    if cum[cp.n] - cum[P.idx] <= 0.9 and dist2(pos, last) <= 2.2 then
        if P.si >= #P.seq then
            Stop("Selesai! Semua CP dalam urutan sudah dijalankan", "#50C864")
        else
            BeginSeg(P.si + 1, 1)    -- langsung lanjut, arah gerak tidak di-reset (mulus)
        end
        return
    end

    -- target di depan (pure pursuit)
    local look = (hum.FloorMaterial == Enum.Material.Air) and LOOK_AIR or LOOK
    local k = P.idx
    while k < cp.n and cum[k] - cum[P.idx] < look do k += 1 end
    local tgt = pts[k]
    local dir = Vector3.new(tgt.X - pos.X, 0, tgt.Z - pos.Z)
    if dir.Magnitude < 0.05 and k < cp.n then
        local nxt = pts[math.min(k + 1, cp.n)]
        dir = Vector3.new(nxt.X - pos.X, 0, nxt.Z - pos.Z)
    end
    Steer(hum, dir, dt)

    P.status = string.format("jalan CP %d (%d/%d) %.0f%%", P.cpn, P.si, #P.seq, 100 * cum[P.idx] / math.max(cp.len, 0.01))

    -- nyangkut?
    if cum[P.idx] > P.prog + 0.35 then
        P.prog, P.progT = cum[P.idx], now
    else
        local stuck = now - P.progT
        if stuck > 1.6 and now - (P.lastUnstick or 0) > 1.0 then
            P.lastUnstick = now
            hum.Jump = true
        end
        if stuck > 5 then
            P.resyncs += 1
            if P.resyncs > 3 then Stop("Nyangkut di CP " .. P.cpn .. " (coba rekam ulang bagian ini)", "#DC3232"); return end
            local bi, bd = 1, math.huge
            for i = 1, cp.n do
                local d = metric(pos, pts[i])
                if d < bd then bd, bi = d, i end
            end
            P.idx = bi
            SyncJumpPtr()
            P.prog, P.progT = cum[bi], now
            if bd > 6 then Approach(pts[bi]) end
        end
    end
end

RunService:BindToRenderStep("KatsAutoWalk", Enum.RenderPriority.Input.Value + 1, function(dt)
    local ok, err = pcall(Step, math.min(dt, 0.1))
    if not ok then warn("[AutoWalk] " .. tostring(err)) end
end)

W:OnUnload(function()
    pcall(function() RunService:UnbindFromRenderStep("KatsAutoWalk") end)
    RecStop(false)
    Stop()
    CtrlSet(true)
end)

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage = W:AddPage({ Name = "Home", Icon = "house" })
local Main = W:AddPage({ Name = "Main", Icon = "footprints" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

local cRec = Main:AddCard({ Title = "Rekam", Icon = "crosshair", Column = 1 })
local infoLbl
cRec:Slider({
    Title = "Checkpoint #", Min = 1, Max = 100, Value = 1, Rounding = 0, id = "aw_sel",
    Callback = function(v) SEL = v; if RefreshInfo then RefreshInfo() end end,
})
infoLbl = cRec:Label({ Text = "-", Size = 11, Color = "Text" })
cRec:Button({ Title = "Mulai rekam", Text = "Mulai rekam CP ini", Callback = function() RecStart(SEL) end })
cRec:Button({ Title = "Stop & simpan", Text = "Stop & simpan", Callback = function() RecStop(true) end })
cRec:Button({ Title = "Batalkan rekaman", Text = "Batalkan rekaman", Callback = function() RecStop(false) end })
cRec:Button({
    Title = "Hapus CP ini", Text = "Hapus CP ini",
    Callback = function()
        if CPS[SEL] then
            CPS[SEL] = nil
            if FS_OK and delfile then pcall(function() delfile(CpPath(SEL)) end) end
            N("CP " .. SEL, "Dihapus", "#DC3232")
            RefreshInfo()
        else
            N("CP " .. SEL, "Belum ada rekaman", "#FFA500")
        end
    end,
})
cRec:Label({ Text = "Rekam dari titik checkpoint sampai checkpoint berikutnya (jalan normal, lompat seperti biasa). Satu CP = satu rekaman.", Size = 10 })

local cPlay = Main:AddCard({ Title = "Jalankan", Icon = "footprints", Column = 2 })
cPlay:Button({
    Title = "Play CP terpilih", Text = "Play CP terpilih",
    Callback = function() Play({ SEL }) end,
})
cPlay:Slider({
    Title = "Mulai dari CP", Min = 1, Max = 100, Value = 1, Rounding = 0, id = "aw_from",
    Callback = function(v) FROM = v end,
})
cPlay:Slider({
    Title = "Sampai CP (0 = semua)", Min = 0, Max = 100, Value = 0, Rounding = 0, id = "aw_to",
    Callback = function(v) TO = v end,
})
cPlay:Button({
    Title = "Play berurutan", Text = "Play berurutan (CP 1, 2, 3, ...)",
    Callback = function()
        local seq = {}
        for _, n in ipairs(Sorted()) do
            if n >= FROM and (TO == 0 or n <= TO) then seq[#seq + 1] = n end
        end
        Play(seq)
    end,
})
cPlay:Button({ Title = "Stop", Text = "Stop", Callback = function() Stop("Dihentikan", "#FFA500") end })
cPlay:Toggle({
    Title = "Auto ulang CP saat mati", Value = true, id = "aw_retry",
    Callback = function(v) RETRY = v end,
})
cPlay:Toggle({
    Title = "Boleh teleport kalau titik awal tak terjangkau", Value = false, id = "aw_tp",
    Callback = function(v) ALLOW_TP = v end,
})

local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })

local cTune = Main:AddCard({ Title = "Tuning", Icon = "wrench", Column = 1, Collapsed = true })
cTune:Slider({ Title = "Look-ahead darat (studs)", Min = 1, Max = 5, Value = 2.2, Rounding = 1, id = "aw_look", Callback = function(v) LOOK = v end })
cTune:Slider({ Title = "Look-ahead udara (studs)", Min = 1.5, Max = 6, Value = 3.2, Rounding = 1, id = "aw_lookair", Callback = function(v) LOOK_AIR = v end })
cTune:Slider({ Title = "Jarak antar titik rekam (studs)", Min = 0.1, Max = 0.6, Value = 0.2, Rounding = 2, id = "aw_spacing", Callback = function(v) SPACING = v end })
cTune:Slider({ Title = "Toleransi titik awal (studs)", Min = 1, Max = 8, Value = 3, Rounding = 1, id = "aw_tol", Callback = function(v) TOL = v end })

RefreshInfo = function()
    pcall(function()
        local t = {}
        for _, n in ipairs(Sorted()) do t[#t + 1] = tostring(n) end
        local cp = CPS[SEL]
        local line = cp and string.format("CP %d: %d titik · %.0f studs · %d lompatan", SEL, cp.n, cp.len, #cp.jumps)
            or ("CP " .. SEL .. ": belum direkam")
        local recLine = rec and ("\n<font color=\"rgb(255,80,80)\">● MEREKAM CP " .. rec.cp .. " (" .. #rec.pts .. " titik)</font>") or ""
        infoLbl:SetText(line .. recLine .. "\nTersimpan: " .. (#t > 0 and table.concat(t, ", ") or "-") ..
            (FS_OK and "" or "\n(Executor tanpa writefile: rekaman hilang saat keluar game)"))
    end)
end
RefreshInfo()

task.spawn(function()
    while W.Alive do
        task.wait(0.5)
        pcall(function()
            stLbl:SetText("Status: " .. (rec and "merekam" or P.status) .. "\nMati/ulang: " .. P.deaths ..
                "\nFolder: " .. (FS_OK and DIR or "(memori)"))
            if rec then RefreshInfo() end
        end)
    end
end)

-- Player (Movement / Fly / Client) dan Home (+ Settings) ada di ui.lua; tiap bagian aman dari error.
for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildHome({ Game = "Auto Walk", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[KatssinnnHub] UI error: " .. tostring(err))
        N("UI error", tostring(e
