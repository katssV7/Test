-- KatssinnnHub | Game 7 (Anime Eyes)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Fitur: Auto Click, Auto Train (teleport sesuai rebirth), Auto Stage (serang musuh di MyEnemies per stage -> claim trophy),
--        Redeem Codes, Auto Rebirth, Auto Equip Best Pet, Remote Logger.
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "Anime Eyes",
    Folder    = "KatssinnnHub/AnimeEyes",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

-- ===== LOOP LAMBAT (rebirth, equip pet) =====
local runId = { rebirth = 0, equip = 0, train = 0, stage = 0, pop = 0 }
local function Loop(key, enabled, getDelay, fn)
    runId[key] += 1
    if not enabled then return end
    local id = runId[key]
    task.spawn(function()
        while runId[key] == id do
            local ok, err = pcall(fn, id)
            if not ok then warn("[" .. key .. "] " .. tostring(err)) end
            task.wait(getDelay())
        end
    end)
end

-- ===== PULSE CEPAT (auto click / attack) =====
-- task.wait(0.01) tidak bisa lebih cepat dari 1 frame, jadi kecepatan dihitung per frame:
-- tiap frame dikirim sebanyak (waktu berlalu / interval) kali, dibatasi MAX_PER_FRAME agar tidak menumpuk.
local MAX_PER_FRAME = 8
local pulses = {}
local function NewPulse(fn, interval)
    local p = { on = false, acc = 0, int = interval, fn = fn }
    pulses[#pulses + 1] = p
    return p
end
local hbConn = RunService.Heartbeat:Connect(function(dt)
    for _, p in ipairs(pulses) do
        if p.on then
            p.acc += dt
            local n = 0
            while p.acc >= p.int and n < MAX_PER_FRAME do
                p.acc -= p.int
                n += 1
                pcall(p.fn)
            end
            if p.acc > p.int * MAX_PER_FRAME then p.acc = 0 end
        end
    end
end)
W.Conns[#W.Conns + 1] = hbConn

-- ===== REMOTE =====
local function V3(x, y, z)
    local ok, v = pcall(function() return vector.create(x, y, z) end)   -- tipe vector seperti remote asli
    if ok and v then return v end
    return Vector3.new(x, y, z)
end

local RemotesF
local function Remote(name)
    if not (RemotesF and RemotesF.Parent) then
        RemotesF = RS:FindFirstChild("Remotes") or RS:WaitForChild("Remotes", 5)
    end
    return RemotesF and (RemotesF:FindFirstChild(name) or RemotesF:WaitForChild(name, 5))
end

local Stats = { clicks = 0, attacks = 0, rebirths = 0, equips = 0, errors = 0, stage = "-", zone = "-", pop = "-", popOk = 0, popTry = 0 }

-- panggil remote sesuai jenisnya (RemoteEvent = FireServer, RemoteFunction = InvokeServer)
local function Call(name, ...)
    local r = Remote(name)
    if not r then Stats.errors += 1; return false end
    local ok, res
    if r:IsA("RemoteFunction") then
        ok, res = pcall(r.InvokeServer, r, ...)
    else
        ok, res = pcall(r.FireServer, r, ...)
    end
    if not ok then Stats.errors += 1 end
    return ok, res
end

-- ===== KARAKTER =====
local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

local function TP(pos)
    local hrp = Root()
    if not hrp then return false end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    return true
end

-- ===== DATA WORLD / STAGE =====
-- attack = titik teleport untuk menyerang musuh stage itu; claim = titik teleport claim trophy stage itu.
-- World 2 belum diisi: tinggal isi tabel attack / claim-nya (nomor stage = kunci tabel) dan sesuaikan first / last.
local V = Vector3.new
local WORLDS = {
    ["World 1"] = {
        first = 1, last = 15,
        attack = {
            [1] = V(1, 4, -54),    [2] = V(3, 7, -166),   [3] = V(-7, 4, -248),  [4] = V(-2, 8, -332),  [5] = V(-1, 4, -434),
            [6] = V(0, 4, -515),   [7] = V(2, 4, -593),   [8] = V(1, 4, -702),   [9] = V(1, 4, -786),   [10] = V(-2, 4, -872),
            [11] = V(0, 4, -964),  [12] = V(1, 4, -1056), [13] = V(-3, 4, -1163), [14] = V(-4, 4, -1245),
            [15] = V(0, 4, -1334),  -- di catatan tertulis "0, 4, 1334"; saya anggap -1334 (pola z terus turun)
        },
        claim = {
            [1] = V(20, 4, -110),  [2] = V(20, 6, -203),  [3] = V(18, 5, -292),  [4] = V(19, 7, -380),  [5] = V(20, 7, -470),
            [6] = V(18, 5, -560),  [7] = V(19, 7, -651),  [8] = V(16, 6, -740),  [9] = V(19, 5, -831),  [10] = V(17, 6, -922),
            [11] = V(20, 7, -1008), [12] = V(17, 5, -1100), [13] = V(16, 6, -1190), [14] = V(17, 5, -1280), [15] = V(17, 6, -1372),
        },
    },
    ["World 2"] = { first = 10, last = 25, attack = {}, claim = {} },   -- BELUM DIISI
}
local WORLD_ORDER = { "World 1", "World 2" }
local function StageList(w)
    local wd = WORLDS[w]
    local t = {}
    if wd then for st = wd.first, wd.last do t[#t + 1] = "Stage " .. st end end
    return t
end

-- ===== MUSUH: folder workspace.MyEnemies =====
local function EnemyPos(e)
    if e:IsA("BasePart") then return e.Position end
    if e:IsA("Model") then
        local r = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart or e:FindFirstChildWhichIsA("BasePart", true)
        return r and r.Position
    end
end
local function EnemyAlive(e)
    if not e or not e.Parent then return false end
    local h = e:FindFirstChildOfClass("Humanoid")
    if h and h.Health <= 0 then return false end
    return EnemyPos(e) ~= nil
end
local function EnemyList()
    local folder = workspace:FindFirstChild("MyEnemies")
    if not folder then return {} end
    local out = {}
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("Folder") then
            for _, cc in ipairs(c:GetChildren()) do out[#out + 1] = cc end
        else
            out[#out + 1] = c
        end
    end
    return out
end
local RADIUS = 100
local function NearestEnemy(point)
    local best, bd
    for _, e in ipairs(EnemyList()) do
        if EnemyAlive(e) then
            local d = (EnemyPos(e) - point).Magnitude
            if d <= RADIUS and (not bd or d < bd) then best, bd = e, d end
        end
    end
    return best
end

-- ===== FITUR =====
local clickPulse = NewPulse(function()
    local r = Remote("Train")
    if r then pcall(r.FireServer, r); Stats.clicks += 1 end
end, 0.1)

local function Rebirth(id)
    task.spawn(function()
        local ok = Call("Rebirth")
        if ok then Stats.rebirths += 1 end
    end)
end
local function EquipBest(id)
    task.spawn(function()
        local ok = Call("PetAction", "equipBest")
        if ok then Stats.equips += 1 end
    end)
end

-- ===== AUTO TRAIN (teleport ke zona train sesuai rebirth) =====
-- { syarat rebirth minimal, posisi }. Zona yang dipakai = syarat terbesar yang MASIH <= rebirth pemain.
-- Contoh: rebirth 3/4/5 tetap di zona "2 REBIRTH"; baru pindah ke zona 6 saat rebirth sudah 6.
-- Kalau ada zona lain (di bawah 56 REBIRTH) tinggal tambah baris baru di tabel ini.
local TRAIN_ZONES = {
    { 0,  Vector3.new(-59, 4, 37) },
    { 2,  Vector3.new(-86, 5, 37) },
    { 6,  Vector3.new(-144, 4, 38) },
    { 12, Vector3.new(-61, 4, 66) },
    { 20, Vector3.new(-115, 4, 63) },
    { 28, Vector3.new(-144, 4, 63) },
    { 36, Vector3.new(-88, 4, 91) },
    { 44, Vector3.new(-116, 4, 91) },
    { 56, Vector3.new(-60, 4, 121) },
}
local TRAIN_STAY = 12     -- kalau lebih jauh dari ini (stud) dari titik train, teleport lagi
local TRAIN_INT = 1       -- jeda cek (detik)

local function GetRebirth()
    local ls = LP:FindFirstChild("leaderstats")
    if not ls then return nil end
    for _, v in ipairs(ls:GetChildren()) do
        if v:IsA("ValueBase") and string.find(string.lower(v.Name), "rebirth", 1, true) then
            local n = tonumber((tostring(v.Value):gsub(",", "")))
            if n then return n end
        end
    end
    return nil
end

local function ZoneFor(rb)
    local z = TRAIN_ZONES[1]
    for _, e in ipairs(TRAIN_ZONES) do
        if rb >= e[1] then z = e end
    end
    return z
end

local function TrainStep()
    local hrp, rb = Root(), GetRebirth()
    if not hrp then return end
    if not rb then Stats.zone = "leaderstats Rebirth tidak ketemu"; return end
    local z = ZoneFor(rb)
    Stats.zone = z[1] .. " REBIRTH  (rebirth kamu: " .. rb .. ")"
    local d = hrp.Position - z[2]
    if Vector3.new(d.X, 0, d.Z).Magnitude > TRAIN_STAY then      -- hanya jarak mendatar, supaya tinggi melayang tidak memicu teleport ulang
        TP(z[2])
    end
end

-- ===== AUTO STAGE =====
-- Pilih World + Stage tujuan (N). Siklus (otomatis berulang dari stage awal):
--   tiap stage: teleport ke titik serang -> 1 detik spam (attack + skill R + skill E, jeda 0.01) -> stage berikutnya.
--   Setelah stage N: teleport ke claim trophy stage N (hanya stage tujuan), tunggu 1 detik, lalu mulai lagi dari stage awal.
-- Arah attack & skill = posisi musuh terdekat di workspace.MyEnemies (vector dibuat otomatis dari posisi musuh);
-- kalau belum ada musuh, dipakai titik serang stage itu.
local WORLD, STAGE_END = "World 1", 1
local STAGE_TIME = 1           -- lama di tiap stage (detik)
local CLAIM_WAIT = 1           -- lama di trophy sebelum mulai lagi (detik)
local tgStage, tgTrain         -- toggle (diisi di bagian UI)

local AimPos                   -- posisi bidikan (posisi musuh / titik serang), diperbarui tiap frame
local stagePulse = NewPulse(function()
    local p = AimPos
    if not p then return end
    local rc = Remote("Cast")
    if not rc then return end
    local v = V3(p.X, p.Y, p.Z)
    pcall(rc.FireServer, rc, "attack", v)
    pcall(rc.FireServer, rc, "R", v)         -- skill 1
    pcall(rc.FireServer, rc, "E", v)         -- skill 2
    Stats.attacks += 1
end, 0.01)

local function FirePromptsNear(pos)       -- kalau claim memakai ProximityPrompt, ikut ditekan
    if not fireproximityprompt then return end
    pcall(function()
        local done = {}
        for _, p in ipairs(workspace:GetPartBoundsInRadius(pos, 18)) do
            local pr = p:FindFirstChildWhichIsA("ProximityPrompt")
            if pr and not done[pr] then done[pr] = true; fireproximityprompt(pr) end
        end
    end)
end

local function StageOff()
    task.defer(function() if tgStage then tgStage:Set(false) end end)
end

local function RunStages(id)
    local wd = WORLDS[WORLD]
    if not wd then StageOff() return end
    local last = math.clamp(STAGE_END, wd.first, wd.last)
    for st = wd.first, last do
        if runId.stage ~= id then return end
        local ap = wd.attack[st]
        if not ap then
            N("Auto Stage", "Waypoint " .. WORLD .. " Stage " .. st .. " belum diisi", "#DC3232", 5)
            StageOff()
            return
        end
        Stats.stage = string.format("%s · Stage %d (serang)", WORLD, st)
        if not TP(ap) then task.wait(0.5) return end
        AimPos = ap
        stagePulse.on = true
        local t = 0
        while t < STAGE_TIME and runId.stage == id do
            local e = NearestEnemy(ap)
            AimPos = e and EnemyPos(e) or ap
            t += task.wait()
        end
    end
    if runId.stage ~= id then return end

    -- stage tujuan selesai -> claim trophy stage tujuan, tunggu 1 detik, lalu siklus mulai lagi dari stage awal
    stagePulse.on = false
    AimPos = nil
    local cp = wd.claim[last]
    if cp then
        Stats.stage = string.format("%s · Stage %d (claim trophy)", WORLD, last)
        TP(cp)
        FirePromptsNear(cp)
        local t = 0
        while t < CLAIM_WAIT and runId.stage == id do t += task.wait(0.1) end
    else
        N("Auto Stage", "Waypoint claim " .. WORLD .. " Stage " .. last .. " belum diisi", "#FFA500", 4)
    end
end

-- ===== REDEEM ALL CODES =====
-- Tambah kode baru cukup dengan menambah namanya di daftar ini.
local CODES = { "AWAKEN", "SHARINGAN", "UPDATE1", "NEWWORLDS", "1MILLIONVISITS", "UPDATE2", "KURUMA" }
local redeeming = false
local codeLines = {}
local codeLbl
local function ShowCodes()
    if codeLbl then codeLbl:SetText(#codeLines > 0 and table.concat(codeLines, "\n") or "-") end
end
local function RedeemAll()
    if redeeming then N("Redeem Codes", "Masih berjalan...", "#FFA500") return end
    redeeming = true
    codeLines = {}
    ShowCodes()
    task.spawn(function()
        local good = 0
        for _, code in ipairs(CODES) do
            if not W.Alive then break end
            local ok, res = Call("RedeemCode", code)       -- RemoteFunction -> InvokeServer
            if ok then good += 1 end
            local info = (res ~= nil) and tostring(res) or ""
            if #info > 40 then info = info:sub(1, 40) .. "…" end
            codeLines[#codeLines + 1] = code .. ": " .. (ok and ("terkirim" .. (info ~= "" and (" · " .. info) or "")) or "gagal")
            ShowCodes()
            task.wait(0.5)
        end
        redeeming = false
        N("Redeem Codes", good .. "/" .. #CODES .. " kode terkirim", good == #CODES and "#50C864" or "#FFA500", 4)
    end)
end

-- ===== AUTO CLAIM POP (bubble "x2!") =====
-- Remote: Pops:FireServer("claim", id). Server tidak membalas, jadi "diterima" dideteksi dari GUI pop yang hilang:
--   pop terlihat -> kirim claim dengan ID kandidat -> kalau pop langsung hilang = ID itu diterima, kandidat berikutnya = ID + 1
--   kalau pop masih ada = ditolak, coba ID + 1 (jadi mulai dari angka awal, naik satu per satu sampai ketemu yang diterima).
-- ID juga dipelajari dari klik manual: kalau kamu / game memanggil Pops("claim", N), kandidat berikutnya = N + 1.
local POP_START   = 25
local POP_CHECK   = 0.1             -- tunggu sekian detik setelah kirim, lalu cek pop hilang atau belum
local POP_PATTERN = "^x%d+!$"       -- pola teks label pop (huruf kecil, spasi dibuang), contoh "x2!"
local POP_MAXSCAN = 3000            -- kalau sudah sekian angka ditolak berturut-turut, ulangi dari POP_START
local popCand, popFails = POP_START, 0
local popLearn = true
local popLabel, popScanT = nil, 0
local popEvt = "-"                  -- argumen terakhir yang dikirim server lewat Pops.OnClientEvent (untuk diagnosa)

local function Shown(d)
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    local p = d
    while p and p ~= pg do
        if p:IsA("GuiObject") and not p.Visible then return false end
        if p:IsA("ScreenGui") and not p.Enabled then return false end
        p = p.Parent
    end
    return p == pg
end

local function PopVisible()
    if popLabel and popLabel.Parent and Shown(popLabel) then return true end
    if os.clock() - popScanT < 0.4 then return false end
    popScanT = os.clock()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return false end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = d.Text:gsub("<[^>]+>", ""):gsub("%s", ""):lower()
            local okm, m = pcall(string.match, t, POP_PATTERN)
            if okm and m and Shown(d) then popLabel = d; return true end
        end
    end
    return false
end

local function PopStep()
    if not PopVisible() then
        Stats.pop = "menunggu pop  (ID berikut: " .. popCand .. ")"
        return
    end
    local cand = popCand
    local r = Remote("Pops")
    if not r then Stats.errors += 1; Stats.pop = "remote Pops tidak ada"; return end
    pcall(r.FireServer, r, "claim", cand)
    Stats.popTry += 1
    task.wait(POP_CHECK)
    popCand = cand + 1
    if not PopVisible() then
        Stats.popOk += 1
        popFails = 0
        Stats.pop = "diterima ID " .. cand .. "  (berikut: " .. popCand .. ")"
    else
        popFails += 1
        Stats.pop = "mencoba ID " .. cand .. " ..."
        if popFails >= POP_MAXSCAN then popCand, popFails = POP_START, 0 end
    end
end

task.spawn(function()
    local r = Remote("Pops")
    if r and r:IsA("RemoteEvent") then
        W.Conns[#W.Conns + 1] = r.OnClientEvent:Connect(function(...)
            local t = table.pack(...)
            for i = 1, t.n do t[i] = tostring(t[i]) end
            popEvt = table.concat(t, ", ")
        end)
    end
end)

-- ===== REMOTE LOGGER (untuk melihat argumen skill lain: Clairvoyant Judgement, Arrow Storm, dll.) =====
local logOn, logLines, oldNc = false, {}, nil
local function Fmt(v)
    local t = typeof(v)
    if t == "number" then return string.format("%.3f", v) end
    if t == "string" then return '"' .. v .. '"' end
    if t == "Vector3" or t == "vector" then return string.format("vec(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) end
    return tostring(v)
end
local function InstallHook()
    if oldNc then return true end
    if not (hookmetamethod and getnamecallmethod) then return false end
    local wrap = newcclosure or function(f) return f end
    oldNc = hookmetamethod(game, "__namecall", wrap(function(self, ...)
        if logOn or popLearn then
            local m = getnamecallmethod()
            if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance"
                and RemotesF and self.Parent == RemotesF and not (checkcaller and checkcaller()) then
                local args = table.pack(...)
                local nm = self.Name
                -- belajar ID pop: klaim manual (dari game) Pops("claim", N) -> kandidat berikutnya N + 1
                if popLearn and nm == "Pops" and args[1] == "claim" and type(args[2]) == "number" then
                    popCand = args[2] + 1
                    popFails = 0
                end
                if logOn then
                    task.spawn(function()
                        local parts = {}
                        for i = 1, args.n do parts[i] = Fmt(args[i]) end
                        local line = nm .. "(" .. table.concat(parts, ", ") .. ")"
                        print("[RemoteLog] " .. line)
                        logLines[#logLines + 1] = line
                        if #logLines > 6 then table.remove(logLines, 1) end
                    end)
                end
            end
        end
        return oldNc(self, ...)
    end))
    return true
end

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "swords" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

-- ---------- kolom 1 ----------
local cClick = Main:AddCard({ Title = "Auto Click (Train)", Icon = "zap", Column = 1 })
-- Tanda v di sebelah switch = buka/tutup pengaturan (slider dkk.) lewat Toggle{ Expand = true } + tg:Sub(fn)
local tgClick = cClick:Toggle({
    Title = "Auto Click", id = "ae_click", Expand = true,
    Callback = function(v)
        clickPulse.on = v
        clickPulse.acc = 0
        N("Auto Click", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgClick:Sub(function(c)
    c:Slider({
        Title = "Kecepatan click (jeda detik, terkecil 0.01)", Min = 0.01, Max = 1, Value = 0.1, Rounding = 2, Suffix = "s", id = "ae_click_speed",
        Callback = function(v) clickPulse.int = math.max(v, 0.01) end,
    })
end)

-- Auto Train: tepat di bawah Auto Click
tgTrain = cClick:Toggle({
    Title = "Auto Train (teleport sesuai rebirth)", id = "ae_train", Expand = true,
    Callback = function(v)
        if v and tgStage and tgStage.Value then tgStage:Set(false) end     -- Auto Stage & Auto Train sama-sama teleport
        Loop("train", v, function() return TRAIN_INT end, TrainStep)
        if not v then Stats.zone = "-" end
        N("Auto Train", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgTrain:Sub(function(c)
    c:Slider({
        Title = "Jeda cek rebirth (s)", Min = 0.5, Max = 10, Value = 1, Rounding = 1, Suffix = "s", id = "ae_train_int",
        Callback = function(v) TRAIN_INT = v end,
    })
    c:Slider({
        Title = "Jarak sebelum teleport ulang", Min = 3, Max = 60, Value = 12, Rounding = 0, id = "ae_train_stay",
        Callback = function(v) TRAIN_STAY = v end,
    })
end)

-- Auto Claim Pop: tepat di bawah Auto Train
local tgPop = cClick:Toggle({
    Title = "Auto Claim Pop (x2!)", id = "ae_pop", Expand = true,
    Callback = function(v)
        Loop("pop", v, function() return 0.02 end, PopStep)
        if not v then Stats.pop = "-" end
        N("Auto Claim Pop", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgPop:Sub(function(c)
    c:Input({
        Title = "Mulai dari ID", Value = "25", id = "ae_pop_start",
        Callback = function(t)
            local n = tonumber(t)
            if n then POP_START = math.floor(n); popCand = POP_START; popFails = 0 end
        end,
    })
    c:Slider({
        Title = "Jeda cek tiap angka (s)", Min = 0.05, Max = 0.5, Value = 0.1, Rounding = 2, Suffix = "s", id = "ae_pop_check",
        Callback = function(v) POP_CHECK = v end,
    })
    c:Input({
        Title = "Pola teks pop (Lua pattern)", Value = "^x%d+!$", id = "ae_pop_pattern",
        Callback = function(t)
            t = tostring(t or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if t ~= "" then POP_PATTERN = t; popLabel = nil; popScanT = 0 end
        end,
    })
    c:Toggle({
        Title = "Pelajari ID dari klaim manual", Value = true, id = "ae_pop_learn",
        Callback = function(v)
            if v and not InstallHook() then
                popLearn = false
                N("Auto Claim Pop", "Executor tanpa hookmetamethod: ID tidak bisa dipelajari dari klaim manual", "#FFA500", 5)
                return
            end
            popLearn = v
        end,
    })
    c:Button({
        Title = "Reset ke ID awal", Text = "Reset ke ID awal",
        Callback = function() popCand, popFails = POP_START, 0; N("Auto Claim Pop", "ID kembali ke " .. POP_START, "#6495ED") end,
    })
end)

local cStage = Main:AddCard({ Title = "Auto Stage", Icon = "swords", Column = 1 })
local ddStage
cStage:Dropdown({
    Title = "World", List = WORLD_ORDER, Value = "World 1", id = "ae_world",
    Callback = function(v)
        if not v then return end
        WORLD = tostring(v)
        local wd = WORLDS[WORLD]
        if ddStage and wd then
            ddStage:SetList(StageList(WORLD))
            if STAGE_END < wd.first or STAGE_END > wd.last then STAGE_END = wd.first end
            ddStage:Set("Stage " .. STAGE_END, true)
        end
    end,
})
ddStage = cStage:Dropdown({
    Title = "Stage tujuan (titik akhir)", List = StageList("World 1"), Value = "Stage 1", id = "ae_stage",
    Callback = function(v)
        local n = v and tonumber(tostring(v):match("%d+"))
        if n then STAGE_END = n end
    end,
})
tgStage = cStage:Toggle({
    Title = "Auto Stage", Desc = "Attack + skill R/E per stage, claim trophy, ulang otomatis", id = "ae_stage_on",
    Callback = function(v)
        if v and tgTrain and tgTrain.Value then tgTrain:Set(false) end       -- Auto Train & Auto Stage sama-sama teleport
        stagePulse.on = false
        stagePulse.acc = 0
        AimPos = nil
        Loop("stage", v, function() return 0.1 end, RunStages)
        if not v then Stats.stage = "-" end
        N("Auto Stage", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

-- Redeem Codes
local cCodes = Main:AddCard({ Title = "Redeem Codes", Icon = "gift", Column = 1 })
cCodes:Button({
    Title = "Redeem semua kode", Text = "Redeem semua kode (" .. #CODES .. ")",
    Callback = RedeemAll,
})
codeLbl = cCodes:Label({ Text = "-", Size = 11, Color = "Text" })

-- ---------- kolom 2 ----------
local cReb = Main:AddCard({ Title = "Rebirth", Icon = "rotate-ccw", Column = 2 })
local REB_INT = 2
cReb:Toggle({
    Title = "Auto Rebirth", id = "ae_rebirth",
    Callback = function(v)
        Loop("rebirth", v, function() return REB_INT end, Rebirth)
        N("Auto Rebirth", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cReb:Slider({
    Title = "Jeda rebirth (s)", Min = 0.5, Max = 60, Value = 2, Rounding = 1, id = "ae_rebirth_int",
    Callback = function(v) REB_INT = v end,
})
cReb:Button({
    Title = "Rebirth sekarang", Text = "Rebirth sekarang",
    Callback = function() Rebirth(); N("Rebirth", "Dikirim", "#6495ED") end,
})

local cPet = Main:AddCard({ Title = "Pets", Icon = "package", Column = 2 })
local EQ_INT = 30
cPet:Toggle({
    Title = "Auto Equip Best Pet", id = "ae_equip",
    Callback = function(v)
        Loop("equip", v, function() return EQ_INT end, EquipBest)
        N("Auto Equip Best", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cPet:Slider({
    Title = "Jeda equip best (s)", Min = 2, Max = 600, Value = 30, Rounding = 0, id = "ae_equip_int",
    Callback = function(v) EQ_INT = v end,
})
cPet:Button({
    Title = "Equip Best sekarang", Text = "Equip Best sekarang",
    Callback = function() EquipBest(); N("Equip Best", "Dikirim", "#6495ED") end,
})

local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })

local cDbg = Main:AddCard({ Title = "Debug", Icon = "scan", Column = 2, Collapsed = true })
cDbg:Toggle({
    Title = "Remote Logger (lihat argumen remote saat main manual)", id = "ae_log",
    Callback = function(v)
        if v and not InstallHook() then
            N("Remote Logger", "Executor tidak mendukung hookmetamethod", "#DC3232", 5)
            return
        end
        logOn = v
        if v then Remote("Cast") end       -- pastikan RemotesF terisi
    end,
})

task.spawn(function()
    while W.Alive do
        task.wait(0.5)
        pcall(function()
            local txt = "Click: " .. Stats.clicks .. "   Attack: " .. Stats.attacks ..
                "\nRebirth: " .. Stats.rebirths .. "   Equip best: " .. Stats.equips ..
                "\nStage: " .. Stats.stage .. "   Error: " .. Stats.errors ..
                "\nZona train: " .. Stats.zone ..
                "\nPop: " .. Stats.pop .. "   diterima: " .. Stats.popOk .. "/" .. Stats.popTry ..
                "\nPops dari server: " .. popEvt
            if logOn and #logLines > 0 then txt ..= "\n— remote terakhir —\n" .. table.concat(logLines, "\n") end
            stLbl:SetText(txt)
        end)
    end
end)

-- hentikan semua saat Unload
W:OnUnload(function()
    logOn = false
    for _, p in ipairs(pulses) do p.on = false end
    for k in pairs(runId) do runId[k] += 1 end
end)

-- Player (Movement / Fly / Client) dan Home (+ Settings) ada di ui.lua; tiap bagian aman dari error.
for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildHome({ Game = "Anime Eyes", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[KatssinnnHub] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()      -- jalankan nilai awal + autoload config setelah intro selesai
W:OnBooted(function() N("KatssinnnHub", "Anime Eyes dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4) end)
