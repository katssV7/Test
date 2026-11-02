-- KatssinnnHub | Game 7 (Anime Eyes)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Fitur: World/Teleport, Auto Hatch (teleport ke egg), Auto Fuse, Auto Claim Reward, Auto Boss Kyubi (join + dodge), Auto Click, Auto Train (teleport sesuai rebirth), Auto Stage (serang musuh di MyEnemies per stage -> claim trophy),
--        Redeem Codes, Auto Rebirth, Auto Equip Best Pet.
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
local runId = { rebirth = 0, equip = 0, train = 0, stage = 0, pop = 0, hatch = 0, reward = 0, fuse = 0, boss = 0, stage2 = 0 }
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

local Stats = { clicks = 0, attacks = 0, rebirths = 0, equips = 0, errors = 0, stage = "-", zone = "-", pop = "-", popClicks = 0, hatch = "-", hatches = 0, rewards = 0, fuse = "-", fuses = 0, boss = "-", dodges = 0 }

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

-- Teleport mulus (anti glitch):
--  1. Area tujuan diminta dimuat dulu (StreamingEnabled) supaya karakter tidak jatuh menembus lantai yang belum termuat.
--  2. Tinggi dihitung dari lantai (raycast) -> kaki pas di lantai, tidak "jatuh" dari ketinggian tebakan.
--  3. Arah hadap karakter dipertahankan (dulu rotasi di-reset, karakter / kamera berputar mendadak tiap teleport).
--  4. Dipindah dengan PivotTo (seluruh model sekaligus) + kecepatan di-nol-kan + diam 2 frame supaya fisika tenang.
local tpParams = RaycastParams.new()
tpParams.FilterType = Enum.RaycastFilterType.Exclude
tpParams.IgnoreWater = true

local function PreloadArea(pos)
    local hrp = Root()
    if hrp and (hrp.Position - pos).Magnitude < 120 then return end          -- dekat: area sudah termuat
    local done = false
    task.spawn(function()
        pcall(function() LP:RequestStreamingAroundAsync(pos, 1) end)
        done = true
    end)
    local t = 0
    while not done and t < 1.2 do t += task.wait(0.05) end
end

local function TP(pos)
    local c = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    PreloadArea(pos)
    c = LP.Character
    hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local hum = c:FindFirstChildOfClass("Humanoid")

    local ignore = { c }
    local mine = workspace:FindFirstChild("MyEnemies")
    if mine then ignore[#ignore + 1] = mine end
    tpParams.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), tpParams)
    local y
    if hit then
        y = hit.Position.Y + (hum and hum.HipHeight or 2) + hrp.Size.Y / 2 + 0.1
    else
        y = pos.Y + 3                                                        -- lantai belum terbaca: pakai tinggi titik + 3
    end

    local rot = hrp.CFrame - hrp.CFrame.Position                             -- pertahankan arah hadap
    c:PivotTo(CFrame.new(pos.X, y, pos.Z) * rot)
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    if not hrp.Anchored then                                                 -- tahan 2 frame agar fisika tenang
        hrp.Anchored = true
        RunService.Heartbeat:Wait()
        RunService.Heartbeat:Wait()
        if hrp.Parent then hrp.Anchored = false end
    end
    return true
end

-- ===== DATA WORLD / STAGE =====
-- Per world: attack = titik serang tiap stage, claim = titik claim trophy tiap stage (kunci = nomor stage),
--            train = { rebirth minimal, posisi } untuk Auto Train.
-- Kalau ada stage yang belum diisi (mis. claim World 5 stage 11-15), Auto Stage berhenti dan memberi tahu saat sampai di situ.
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
        train = {
            { 0, V(-59, 4, 37) },  { 2, V(-86, 5, 37) },  { 6, V(-144, 4, 38) }, { 12, V(-61, 4, 66) }, { 20, V(-115, 4, 63) },
            { 28, V(-144, 4, 63) }, { 36, V(-88, 4, 91) }, { 44, V(-116, 4, 91) }, { 56, V(-60, 4, 121) },
        },
    },
    ["World 2"] = {
        first = 1, last = 15,
        attack = {
            [1] = V(2999, 4, -66),   [2] = V(3001, 4, -165),  [3] = V(2999, 4, -250),  [4] = V(2998, 4, -339),  [5] = V(2996, 4, -430),
            [6] = V(3001, 4, -522),  [7] = V(2998, 4, -610),  [8] = V(2997, 4, -699),  [9] = V(2999, 4, -791),  [10] = V(3000, 4, -879),
            [11] = V(3000, 4, -977), [12] = V(2999, 4, -1060), [13] = V(3000, 4, -1146), [14] = V(2997, 4, -1242), [15] = V(3000, 4, -1330),
        },
        claim = {
            [1] = V(3019, 6, -111),  [2] = V(3015, 7, -198),  [3] = V(3016, 8, -290),   -- stage 3: dikoreksi -200 -> -290 (pola semua world: stage 2 ~-200, stage 3 ~-290)
            [4] = V(3021, 6, -380),  [5] = V(3020, 5, -471),  [6] = V(3019, 7, -561),  [7] = V(3020, 7, -652),  [8] = V(3019, 5, -741),
            [9] = V(3018, 5, -829),  [10] = V(3020, 5, -922), [11] = V(3018, 7, -1009), [12] = V(3018, 7, -1102), [13] = V(3021, 7, -1192),
            [14] = V(3019, 7, -1280), [15] = V(3020, 6, -1370),
        },
        train = {
            { 64, V(2939, 4, 38) },  { 66, V(2909, 5, 38) },  { 69, V(2857, 4, 37) },  { 72, V(2939, 4, 64) },  { 77, V(2883, 4, 64) },
            { 85, V(2855, 4, 66) },  { 97, V(2911, 4, 92) },  { 109, V(2883, 4, 94) }, { 121, V(2939, 4, 122) },
        },
    },
    ["World 3"] = {
        first = 1, last = 15,
        attack = {
            [1] = V(5996, 4, -64),   [2] = V(6000, 4, -157),  [3] = V(5997, 4, -256),  [4] = V(5996, 4, -339),  [5] = V(5995, 4, -430),
            [6] = V(5999, 4, -523),  [7] = V(5995, 4, -617),  [8] = V(5997, 4, -699),  [9] = V(5998, 4, -788),  [10] = V(5997, 4, -887),
            [11] = V(5995, 4, -968), [12] = V(5996, 4, -1061), [13] = V(5999, 4, -1148), [14] = V(5999, 4, -1236), [15] = V(6001, 4, -1327),
        },
        claim = {
            [1] = V(6022, 5, -112),  [2] = V(6021, 6, -200),  [3] = V(6020, 6, -291),  [4] = V(6021, 5, -379),  [5] = V(6017, 6, -470),
            [6] = V(6020, 5, -562),  [7] = V(6019, 6, -650),  [8] = V(6019, 6, -741),  [9] = V(6019, 6, -831),  [10] = V(6019, 6, -920),
            [11] = V(6018, 7, -1012), [12] = V(6019, 6, -1099), [13] = V(6019, 6, -1191), [14] = V(6017, 6, -1279), [15] = V(6018, 9, -1370),
        },
        train = {
            { 150, V(5938, 4, 36) },  { 157, V(5911, 5, 37) },  { 164, V(5855, 4, 37) },  { 172, V(5939, 4, 65) },  { 179, V(5882, 4, 63) },
            { 186, V(5857, 4, 65) },  { 193, V(5913, 4, 92) },  { 200, V(5883, 4, 92) },  { 208, V(5940, 4, 121) },
        },
    },
    ["World 4"] = {
        first = 1, last = 15,
        attack = {
            [1] = V(9002.18, 4.17, -70.60),   [2] = V(8998.77, 4.17, -157.17),  [3] = V(8999.49, 4.17, -253.72),  [4] = V(8998.39, 4.15, -335.20),  [5] = V(8999.70, 4.17, -427.27),
            [6] = V(9002.47, 4.17, -508.97),  [7] = V(9003.89, 4.17, -620.38),  [8] = V(9001.13, 4.17, -706.02),  [9] = V(9003.07, 4.17, -785.26),  [10] = V(9001.03, 4.17, -884.05),
            [11] = V(8998.81, 4.17, -975.11), [12] = V(8998.19, 4.17, -1058.58), [13] = V(9000.11, 4.17, -1149.58), [14] = V(8999.65, 4.17, -1243.56), [15] = V(8998.60, 4.17, -1323.14),
        },
        claim = {
            [1] = V(9020.43, 5.45, -114.27),  [2] = V(9019.90, 5.57, -201.31),  [3] = V(9018.36, 5.57, -292.40),  [4] = V(9017.41, 5.57, -381.61),  [5] = V(9018.30, 6.57, -470.55),
            [6] = V(9017.73, 6.42, -560.87),  [7] = V(9020.52, 6.07, -650.36),  [8] = V(9021.50, 7.69, -741.48),  [9] = V(9022.50, 7.55, -830.34),  [10] = V(9020.63, 6.07, -919.44),
            [11] = V(9019.97, 6.57, -1009.18), [12] = V(9021.07, 5.57, -1102.00), [13] = V(9021.45, 7.91, -1189.58), [14] = V(9018.94, 7.09, -1279.16), [15] = V(9019.00, 5.98, -1371.32),
        },
        train = {
            { 240, V(8937.39, 4.42, 38.95) },  { 247, V(8910.39, 5.07, 37.46) },  { 254, V(8855.59, 4.42, 37.44) },  { 262, V(8940.53, 4.42, 65.92) },  { 269, V(8883.47, 4.42, 65.80) },
            { 276, V(8855.75, 4.42, 67.06) },  { 283, V(8911.41, 4.42, 94.96) },  { 290, V(8883.48, 4.42, 94.72) },  { 298, V(8939.30, 4.42, 122.55) },
        },
    },
    ["World 5"] = {
        first = 1, last = 15,
        attack = {
            [1] = V(11998.66, 4.17, -71.55),   [2] = V(11996.89, 4.17, -163.85),  [3] = V(11996.73, 4.17, -244.54),  [4] = V(11998.96, 4.15, -340.09),  [5] = V(11997.58, 4.17, -426.30),
            [6] = V(11999.24, 4.17, -516.96),  [7] = V(11996.86, 4.17, -607.56),  [8] = V(12001.36, 4.15, -699.28),  [9] = V(12001.24, 4.17, -782.82),  [10] = V(12000.04, 4.17, -878.97),
            [11] = V(11999.16, 4.17, -964.67), [12] = V(12000.71, 4.17, -1054.90), [13] = V(11997.61, 4.17, -1146.29), [14] = V(11999.52, 4.17, -1233.93), [15] = V(11999.87, 4.17, -1318.46),
        },
        claim = {   -- BARU stage 1-10, stage 11-15 belum ada
            [1] = V(12019.43, 5.57, -112.33),  [2] = V(12018.20, 6.40, -201.81),  [3] = V(12020.21, 5.57, -290.70),  [4] = V(12017.81, 6.48, -381.19),  [5] = V(12019.91, 7.38, -469.35),
            [6] = V(12018.44, 5.57, -563.75),  [7] = V(12020.47, 7.44, -652.64),  [8] = V(12018.86, 5.57, -740.46),  [9] = V(12019.01, 5.53, -831.01),  [10] = V(12020.83, 7.95, -921.48),
        },
        train = {
            { 300, V(11938.25, 4.42, 36.65) },  { 307, V(11909.67, 5.07, 38.86) },  { 314, V(11855.71, 4.42, 37.69) },  { 322, V(11939.89, 4.42, 65.32) },  { 329, V(11883.55, 4.42, 66.89) },
            { 336, V(11857.58, 4.42, 64.57) },  { 343, V(11909.59, 4.42, 94.54) },  { 350, V(11883.37, 4.42, 93.39) },  { 358, V(11939.74, 4.42, 120.96) },
        },
    },
}
local WORLD_ORDER = { "World 1", "World 2", "World 3", "World 4", "World 5" }    -- urutan = nomor world untuk remote Teleport
local WORLD_NAME  = { ["World 1"] = "Shinobi Land", ["World 2"] = "Celestial Realm", ["World 3"] = "Blood Moon" }
local WORLD, STAGE_END = "World 1", 1                      -- world terpilih dipakai bersama Auto Stage, Auto Train, Auto Hatch
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
    for _, a in ipairs({ "Health", "health", "HP", "hp" }) do      -- musuh tanpa Humanoid: darah bisa berupa atribut
        local v = e:GetAttribute(a)
        if type(v) == "number" and v <= 0 then return false end
    end
    if e:GetAttribute("Dead") == true or e:GetAttribute("dead") == true then return false end
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
end, 0.01)

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

-- ===== AUTO TRAIN (teleport ke zona train sesuai rebirth, mengikuti World terpilih) =====
-- Zona train tiap world ada di WORLDS[...].train. Zona yang dipakai = syarat terbesar yang MASIH <= rebirth pemain.
-- Contoh World 1: rebirth 3/4/5 tetap di zona "2 REBIRTH"; baru pindah ke zona 6 saat rebirth sudah 6.
local TRAIN_STAY = 10     -- kalau lebih jauh dari ini (stud) dari titik train, teleport lagi
local TRAIN_INT = 0.5     -- jeda cek (detik)

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

local function ZoneFor(w, rb)
    local zones = WORLDS[w] and WORLDS[w].train
    if not zones or #zones == 0 then return nil end
    local z = zones[1]
    for _, e in ipairs(zones) do
        if rb >= e[1] then z = e end
    end
    return z
end

local function TrainStep()
    local hrp, rb = Root(), GetRebirth()
    if not hrp then return end
    if not rb then Stats.zone = "leaderstats Rebirth tidak ketemu"; return end
    local z = ZoneFor(WORLD, rb)
    if not z then Stats.zone = WORLD .. ": zona train belum diisi"; return end
    Stats.zone = WORLD .. " · " .. z[1] .. " REBIRTH  (rebirth kamu: " .. rb .. ")"
    local d = hrp.Position - z[2]
    if Vector3.new(d.X, 0, d.Z).Magnitude > TRAIN_STAY then      -- hanya jarak mendatar, supaya tinggi melayang tidak memicu teleport ulang
        TP(z[2])
    end
end

-- ===== AUTO STAGE =====
-- Pilih World + Stage tujuan (N). Siklus (otomatis berulang dari stage awal):
--   tiap stage: teleport ke titik serang -> serang (attack + skill R + skill E) sampai SEMUA musuh di workspace.MyEnemies mati
--   -> teleport ke stage berikutnya.
--   Setelah musuh stage tujuan (N) habis: teleport ke claim trophy stage N (diulang sampai trophy bertambah), lalu mulai lagi dari stage awal.
-- Arah attack & skill = posisi musuh hidup terdekat di MyEnemies (vector dibuat otomatis dari posisi musuh).
local SPAWN_WAIT    = 4      -- tunggu musuh muncul sesudah teleport (detik); kalau tidak ada yang muncul, lanjut
local CLEAR_DELAY   = 0.15   -- musuh harus tetap habis (dan attack berhenti) selama ini sebelum stage dianggap selesai
local STAGE_TIMEOUT = 60     -- batas waktu per stage (pengaman kalau ada musuh yang tidak pernah mati)
local CLAIM_SETTLE  = 0.5    -- jeda setelah musuh terakhir mati sebelum pindah ke claim trophy
local CLAIM_WAIT    = 0.8    -- lama menunggu di titik claim tiap percobaan
local CLAIM_TRIES   = 3      -- maksimal percobaan claim kalau trophy belum bertambah
local tgStage, tgStage2, tgTrain, tgHatch, tgBoss   -- toggle (diisi di bagian UI)

-- ===== DETEKTOR "ATTACK MASIH KELUAR" =====
-- Selama masih ada musuh, attack karakter benar-benar keluar (animasi serangan jalan / server membalas Cast).
-- Kalau attack berhenti keluar -> tidak ada musuh lagi. Dicek tiap 0.05 detik, berhenti dianggap setelah ATTACK_IDLE tanpa sinyal.
-- Sinyal dipakai SEBAGAI TAMBAHAN daftar MyEnemies: stage baru selesai kalau MyEnemies kosong DAN attack sudah berhenti.
local ATTACK_IDLE = 0.1      -- tidak ada sinyal attack selama ini = attack berhenti keluar (detik)
local ATTACK_CAP  = 1.5      -- pengaman: MyEnemies kosong tapi sinyal attack terus terdeteksi sampai segini -> sinyal diabaikan
local lastAtk = 0
local atkSrc = { anim = 0, remote = 0 }
local function MarkAtk(src) lastAtk = os.clock(); atkSrc[src] += 1 end

local function IsAtkTrack(t)             -- animasi aksi (bukan idle/jalan yang looping)
    local ok, r = pcall(function() return (not t.Looped) and t.Priority.Value >= Enum.AnimationPriority.Action.Value end)
    return ok and r
end
local function PollAtk()                 -- ada animasi serangan yang sedang jalan?
    local c = LP.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local ok, tracks = pcall(hum.GetPlayingAnimationTracks, hum)
    if ok then
        for _, t in ipairs(tracks) do
            if IsAtkTrack(t) then MarkAtk("anim") return end
        end
    end
end
local animConn
local function HookAnimator(char)
    if animConn then animConn:Disconnect(); animConn = nil end
    if not char then return end
    task.spawn(function()
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        local an = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5))
        if an then animConn = an.AnimationPlayed:Connect(function(t) if IsAtkTrack(t) then MarkAtk("anim") end end) end
    end)
end
HookAnimator(LP.Character)
W.Conns[#W.Conns + 1] = LP.CharacterAdded:Connect(HookAnimator)

local function MentionsMe(v, d)          -- balasan server yang menyebut pemain ini (efek attack milik kita)
    if v == LP or v == LP.Character or v == LP.Name or v == LP.UserId then return true end
    if type(v) == "table" and (d or 0) < 2 then
        for _, x in pairs(v) do if MentionsMe(x, (d or 0) + 1) then return true end end
    end
    return false
end
local castConn
local function HookCastEvent()
    if castConn then return end
    local rc = Remote("Cast")
    if rc and rc:IsA("RemoteEvent") then
        castConn = rc.OnClientEvent:Connect(function(...) if MentionsMe({ ... }) then MarkAtk("remote") end end)
        W.Conns[#W.Conns + 1] = castConn
    end
end

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

local function AliveEnemies()
    local out = {}
    for _, e in ipairs(EnemyList()) do
        if EnemyAlive(e) then out[#out + 1] = e end
    end
    return out
end
local function NearestOf(list, from)
    local best, bd
    for _, e in ipairs(list) do
        local d = (EnemyPos(e) - from).Magnitude
        if not bd or d < bd then best, bd = e, d end
    end
    return best
end

local function GetTrophies()             -- nilai trophy dari leaderstats (kalau ada), untuk memastikan claim berhasil
    local ls = LP:FindFirstChild("leaderstats")
    if not ls then return nil end
    for _, v in ipairs(ls:GetChildren()) do
        if v:IsA("ValueBase") and string.find(string.lower(v.Name), "troph", 1, true) then
            local n = tonumber((tostring(v.Value):gsub(",", "")))
            if n then return n end
        end
    end
    return nil
end

local function TouchNear(pos, hrp)       -- sentuh part claim di sekitar titik (kalau trophy diambil lewat Touched)
    if typeof(firetouchinterest) ~= "function" then return end
    pcall(function()
        local op = OverlapParams.new()
        op.FilterType = Enum.RaycastFilterType.Exclude
        op.FilterDescendantsInstances = { LP.Character }
        local done = {}
        for _, part in ipairs(workspace:GetPartBoundsInRadius(pos, 20, op)) do
            if not done[part] and part:FindFirstChildWhichIsA("TouchTransmitter") then
                done[part] = true
                firetouchinterest(hrp, part, 0)
                firetouchinterest(hrp, part, 1)
            end
        end
    end)
end

-- claim trophy: berdiri tepat di titik claim, sentuh / tekan prompt, ulangi sampai trophy bertambah
local function ClaimTrophy(cp, id, st, key)
    key = key or "stage"
    local before = GetTrophies()
    for try = 1, CLAIM_TRIES do
        if runId[key] ~= id then return end
        Stats.stage = string.format("%s · claim trophy stage %d (coba %d)", WORLD, st, try)
        TP(cp)                                   -- TP sudah menaruh kaki tepat di lantai titik claim
        local hrp = Root()
        if hrp then
            TouchNear(cp, hrp)
            FirePromptsNear(cp)
        end
        local t = 0
        while t < CLAIM_WAIT and runId[key] == id do t += task.wait(0.1) end
        local now = GetTrophies()
        if before and now then
            if now > before then return true end
        elseif try >= 2 then
            return nil                           -- trophy tidak bisa dibaca: cukup 2 percobaan
        end
    end
end

local function RunStages(id)
    local wd = WORLDS[WORLD]
    if not wd then StageOff() return end
    local st = wd.first
    local last = math.clamp(STAGE_END, wd.first, wd.last)
    while st <= last do                 -- "last" dibaca ulang tiap stage: ganti stage tujuan saat jalan langsung berlaku
        if runId.stage ~= id then return end
        local ap = wd.attack[st]
        if not ap then
            N("Auto Stage", "Waypoint " .. WORLD .. " Stage " .. st .. " belum diisi", "#DC3232", 5)
            StageOff()
            return
        end
        local tag = string.format("%s · Stage %d/%d", WORLD, st, last)
        Stats.stage = tag .. " (menuju)"
        if not TP(ap) then task.wait(0.5) return end
        AimPos = ap
        stagePulse.on = true
        HookCastEvent()
        lastAtk = 0

        -- serang sampai semua musuh di MyEnemies mati DAN attack berhenti keluar
        local t0, emptySince, seen, noListSince = os.clock(), nil, false, nil
        while runId.stage == id do
            local now = os.clock()
            PollAtk()
            local alive = AliveEnemies()
            local atkOn = (now - lastAtk) < ATTACK_IDLE
            if #alive > 0 then
                seen, emptySince, noListSince = true, nil, nil
                local hrp = Root()
                local e = NearestOf(alive, hrp and hrp.Position or ap)
                AimPos = EnemyPos(e) or ap
                Stats.stage = string.format("%s (bunuh musuh, sisa %d)", tag, #alive)
                if hrp then                                  -- tetap di titik serang (kalau terdorong jauh)
                    local d = hrp.Position - ap
                    if Vector3.new(d.X, 0, d.Z).Magnitude > 40 then TP(ap) end
                end
            elseif atkOn and (not noListSince or now - noListSince < ATTACK_CAP) then
                -- daftar MyEnemies kosong tapi attack masih keluar -> masih ada musuh
                noListSince = noListSince or now
                seen, emptySince = true, nil
                AimPos = ap
                Stats.stage = tag .. " (attack masih keluar)"
            else
                AimPos = ap
                if seen then
                    emptySince = emptySince or now
                    Stats.stage = tag .. " (musuh habis)"
                    if now - emptySince >= CLEAR_DELAY then break end
                else
                    Stats.stage = workspace:FindFirstChild("MyEnemies") and (tag .. " (menunggu musuh muncul)") or (tag .. " (folder MyEnemies tidak ada)")
                    if now - t0 >= SPAWN_WAIT then break end
                end
            end
            if now - t0 > STAGE_TIMEOUT then Stats.stage = tag .. " (timeout, lanjut)"; break end
            task.wait(0.05)
        end
        st += 1
        last = math.clamp(STAGE_END, wd.first, wd.last)
    end
    if runId.stage ~= id then return end
    last = math.clamp(STAGE_END, wd.first, wd.last)       -- claim SELALU untuk stage tujuan yang terpilih sekarang

    -- semua musuh sampai stage tujuan sudah mati -> claim trophy stage tujuan
    stagePulse.on = false
    AimPos = nil
    local cp = wd.claim[last]
    if not cp then
        N("Auto Stage", "Waypoint claim " .. WORLD .. " Stage " .. last .. " belum diisi", "#FFA500", 5)
        StageOff()
        return
    end
    local t = 0
    while t < CLAIM_SETTLE and runId.stage == id do t += task.wait(0.1) end      -- beri waktu server mencatat kill terakhir
    ClaimTrophy(cp, id, last)
end

-- ===== AUTO STAGE V2 =====
-- Per stage: teleport ke titik serang -> tunggu 1 detik -> tembak otomatis 5x (attack + skill R + skill E ke musuh terdekat)
-- -> langsung lanjut ke stage berikutnya (tidak menunggu musuh mati). Setelah stage tujuan: claim trophy, lalu ulang dari stage awal.
local V2_WAIT, V2_SHOTS, V2_GAP = 1, 5, 0.1

local function StageOff2()
    task.defer(function() if tgStage2 then tgStage2:Set(false) end end)
end

local function ShootOnce(ap)
    local hrp = Root()
    local alive = AliveEnemies()
    local p = ap
    if #alive > 0 then
        local e = NearestOf(alive, hrp and hrp.Position or ap)
        p = e and EnemyPos(e) or ap
    end
    local rc = Remote("Cast")
    if not rc then return end
    local v = V3(p.X, p.Y, p.Z)
    pcall(rc.FireServer, rc, "attack", v)
    pcall(rc.FireServer, rc, "R", v)
    pcall(rc.FireServer, rc, "E", v)
    Stats.attacks += 1
end

local function RunStagesV2(id)
    local wd = WORLDS[WORLD]
    if not wd then StageOff2() return end
    local st = wd.first
    local last = math.clamp(STAGE_END, wd.first, wd.last)
    while st <= last do
        if runId.stage2 ~= id then return end
        local ap = wd.attack[st]
        if not ap then
            N("Auto Stage V2", "Waypoint " .. WORLD .. " Stage " .. st .. " belum diisi", "#DC3232", 5)
            StageOff2()
            return
        end
        local tag = string.format("V2 · %s · Stage %d/%d", WORLD, st, last)
        Stats.stage = tag .. " (menuju)"
        if not TP(ap) then task.wait(0.5) return end

        Stats.stage = tag .. " (tunggu " .. V2_WAIT .. " dtk)"
        local t = 0
        while t < V2_WAIT and runId.stage2 == id do t += task.wait(0.05) end

        for i = 1, V2_SHOTS do
            if runId.stage2 ~= id then return end
            Stats.stage = string.format("%s (tembak %d/%d)", tag, i, V2_SHOTS)
            ShootOnce(ap)
            task.wait(V2_GAP)
        end
        st += 1
        last = math.clamp(STAGE_END, wd.first, wd.last)
    end
    if runId.stage2 ~= id then return end
    last = math.clamp(STAGE_END, wd.first, wd.last)       -- claim SELALU untuk stage tujuan yang terpilih sekarang

    local cp = wd.claim[last]
    if not cp then
        N("Auto Stage V2", "Waypoint claim " .. WORLD .. " Stage " .. last .. " belum diisi", "#FFA500", 5)
        StageOff2()
        return
    end
    ClaimTrophy(cp, id, last, "stage2")
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

-- Kalau World / Stage tujuan diganti saat Auto Stage (V1 / V2) sedang menyala, siklus yang berjalan dibatalkan
-- dan dimulai lagi dari stage awal dengan tujuan yang baru (supaya tidak menyelesaikan siklus dengan tujuan lama).
local function RestartStage()
    if tgStage and tgStage.Value then
        stagePulse.on = false
        AimPos = nil
        Loop("stage", true, function() return 0.1 end, RunStages)
    end
    if tgStage2 and tgStage2.Value then
        Loop("stage2", true, function() return 0.1 end, RunStagesV2)
    end
end

-- Fitur yang berpindah-pindah posisi tidak boleh jalan bersamaan: menyalakan satu mematikan yang lain
local function OffOthers(keep)
    for _, tg in ipairs({ tgStage, tgStage2, tgTrain, tgHatch, tgBoss }) do
        if tg and tg ~= keep and tg.Value then tg:Set(false) end
    end
end

-- ===== AUTO CLAIM REWARD =====
local REWARD_INT = 15          -- detik antar putaran klaim reward 1,2,3
local function ClaimRewards()
    for i = 1, 3 do
        local ok = Call("ClaimReward", i)       -- RemoteFunction -> InvokeServer
        if ok then Stats.rewards += 1 end
        task.wait(0.2)
    end
end

-- ===== AUTO FUSE =====
-- Remote: Fuse:InvokeServer("fuse", { "id1", "id2", "id3", "id4" })  (ID pet berupa string, terus bertambah).
-- Script mencari 4 ID pet yang diterima server: mulai dari ID awal, coba 4 ID (boleh ada celah, mis. 432,434,435,436),
-- kalau diterima -> ID itu dianggap terpakai & lanjut ke ID berikutnya; kalau ditolak semua -> geser ke ID berikutnya.
-- Kalau kamu fuse manual sekali, ID terakhirnya dipelajari dan scan lanjut dari situ.
local FUSE_SPAN, FUSE_MAXMISS, FUSE_IDLE = 6, 20, 30
local fuseBase, fuseCursor = 428, nil
local fuseUsed, fuseDead = {}, {}
local fuseMiss, fuseLearn, fuseOldNc = 0, true, nil
local fuseCombos = {}
for a = 1, FUSE_SPAN - 1 do
    for b = a + 1, FUSE_SPAN - 1 do
        for c = b + 1, FUSE_SPAN - 1 do fuseCombos[#fuseCombos + 1] = { a, b, c } end   -- paling rapat dulu
    end
end

local FUSE_BAD = { "not", "invalid", "fail", "error", "cannot", "can't", "need", "insufficient", "missing", "don't" }
local function FuseOk(res)
    if res == nil or res == false then return false end
    if res == true then return true end
    if type(res) == "table" then
        return not (res.success == false or res.ok == false or res.error ~= nil or res.Error ~= nil)
    end
    if type(res) == "string" then
        local l = string.lower(res)
        for _, w in ipairs(FUSE_BAD) do
            if string.find(l, w, 1, true) then return false end
        end
    end
    return true
end
local function ResText(res)
    if res == nil then return "kosong" end
    local t = type(res) == "table" and "tabel" or tostring(res)
    return #t > 30 and (t:sub(1, 30) .. "…") or t
end

local function FuseReset()
    fuseCursor = nil; fuseMiss = 0
    table.clear(fuseDead)
end

local function FuseStep(id)
    if not fuseCursor then fuseCursor = fuseBase end
    local n = fuseCursor
    while fuseUsed[n] or fuseDead[n] do n += 1 end
    local avail, k = { n }, n
    while #avail < FUSE_SPAN do
        k += 1
        if not fuseUsed[k] then avail[#avail + 1] = k end
    end
    local lastRes
    for _, cb in ipairs(fuseCombos) do
        if runId.fuse ~= id then return end
        local ids = { avail[1], avail[1 + cb[1]], avail[1 + cb[2]], avail[1 + cb[3]] }
        local strs = {}
        for i, v in ipairs(ids) do strs[i] = tostring(v) end
        local ok, res = Call("Fuse", "fuse", strs)
        lastRes = res
        if ok and FuseOk(res) then
            for _, v in ipairs(ids) do fuseUsed[v] = true end
            Stats.fuses += 1
            fuseMiss = 0
            fuseCursor = n
            Stats.fuse = "ok " .. table.concat(ids, ",") .. "  (respon: " .. ResText(res) .. ")"
            return
        end
    end
    fuseDead[n] = true
    fuseCursor = n + 1
    fuseMiss += 1
    Stats.fuse = "scan ID " .. n .. "…  (respon: " .. ResText(lastRes) .. ")"
    if fuseMiss >= FUSE_MAXMISS then
        Stats.fuse = "tidak ada yang bisa di-fuse, cek lagi " .. FUSE_IDLE .. " dtk"
        local t = 0
        while t < FUSE_IDLE and runId.fuse == id do t += task.wait(0.5) end
        FuseReset()
    end
end

local function FuseLearnIds(ids)
    local mx = 0
    for _, v in ipairs(ids) do fuseUsed[v] = true; if v > mx then mx = v end end
    if mx > 0 then
        fuseBase, fuseCursor, fuseMiss = mx + 1, mx + 1, 0
        table.clear(fuseDead)
        Stats.fuse = "dipelajari dari fuse manual: lanjut dari ID " .. (mx + 1)
    end
end
local function InstallFuseHook()
    if fuseOldNc then return true end
    if not (hookmetamethod and getnamecallmethod) then return false end
    local wrap = newcclosure or function(f) return f end
    fuseOldNc = hookmetamethod(game, "__namecall", wrap(function(self, ...)
        if fuseLearn and typeof(self) == "Instance" and self.Name == "Fuse" and getnamecallmethod() == "InvokeServer"
            and not (checkcaller and checkcaller()) then
            local a, b = ...
            if a == "fuse" and type(b) == "table" then
                local ids = {}
                for _, v in ipairs(b) do
                    local num = tonumber(v)
                    if num then ids[#ids + 1] = num end
                end
                task.spawn(FuseLearnIds, ids)
            end
        end
        return fuseOldNc(self, ...)
    end))
    return true
end

-- ===== AUTO BOSS KYUBI =====
-- Berdasarkan script klien Boss milik game:
--   * Status boss ada di atribut workspace: BossPhase ("wait" / "coming" / "fight" / "over"), BossHp (0..1), BossX, BossZ.
--   * Join: Remotes.Boss:FireServer("join"). Boleh dikirim saat phase "coming" atau "fight".
--   * Serangan boss dikirim server ke semua klien lewat Remotes.Boss.OnClientEvent sebagai batch { {t="atk", ...} }:
--       k = nama serangan, hit = waktu kena (server time), sh = daftar zona bahaya
--       { kind = "circle" | "ring" | "cone", x, z, radius, inner?, yaw?, half? }.
--     Jadi dodge tidak perlu menebak dari animasi: cukup pastikan posisi kita di luar semua zona saat waktu `hit`.
--   * Pemain hanya bisa melukai boss saat phase "fight", berada di dalam arena (INSIDE_RADIUS dari CENTRE) dan tidak sedang KO ("down").
local BOSS_KEYS  = { "kurama", "kyubi", "kyuubi" }       -- hanya cadangan kalau modul Boss tidak bisa di-require
local DODGE_DIST, DODGE_HOLD, BOSS_MARGIN = 120, 0.4, 10 -- jarak cari tempat aman, tahan setelah serangan, margin zona (stud)
local bossModel, bossScanT, bossJoinT = nil, 0, 0
local bossTick, bossDown = 0, false
local dodgeCount = 0
local bossConn

local BossCfg, BOSS_CENTRE, BOSS_INSIDE, BOSS_CHEST = nil, nil, 200, 10
pcall(function()
    BossCfg = require(RS:WaitForChild("Shared", 5):WaitForChild("Logic", 5):WaitForChild("Boss", 5))
end)
if type(BossCfg) == "table" then
    if typeof(BossCfg.CENTRE) == "Vector3" then BOSS_CENTRE = BossCfg.CENTRE end
    if type(BossCfg.INSIDE_RADIUS) == "number" then BOSS_INSIDE = BossCfg.INSIDE_RADIUS end
    if type(BossCfg.CHEST) == "number" then BOSS_CHEST = BossCfg.CHEST end
end

local function BossPhase()
    local p = workspace:GetAttribute("BossPhase")
    return type(p) == "string" and p or "wait"
end

local function Flat(v) return math.sqrt(v.X * v.X + v.Z * v.Z) end

local function InAnyChar(d)
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character and d:IsDescendantOf(pl.Character) then return true end
    end
    return false
end
local function BossRoot(m)
    return m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true)
end

-- cadangan: cari model boss berdasarkan nama (dipakai hanya kalau CENTRE tidak terbaca)
local function FindBoss()
    if bossModel and bossModel.Parent and bossModel:IsDescendantOf(workspace) then return bossModel end
    bossModel = nil
    if os.clock() - bossScanT < 3 then return nil end
    bossScanT = os.clock()
    local best, bs, n = nil, 0, 0
    for _, d in ipairs(workspace:GetDescendants()) do
        n += 1
        if n % 2500 == 0 then task.wait() end
        if d:IsA("Model") and not InAnyChar(d) then
            local l = string.lower(d.Name)
            for _, key in ipairs(BOSS_KEYS) do
                if string.find(l, key, 1, true) then
                    local r = BossRoot(d)
                    if r then
                        local sz = r.Size.Magnitude
                        if sz > bs then best, bs = d, sz end
                    end
                    break
                end
            end
        end
    end
    bossModel = best
    return bossModel
end

-- posisi boss: XZ dari atribut server, Y dari CENTRE (+ tinggi dada); cadangan: model bernama Kurama
local function BossPos()
    local bx, bz = workspace:GetAttribute("BossX"), workspace:GetAttribute("BossZ")
    if type(bx) == "number" and type(bz) == "number" and BOSS_CENTRE then
        return Vector3.new(bx, BOSS_CENTRE.Y + BOSS_CHEST, bz)
    end
    local m = FindBoss()
    local r = m and BossRoot(m)
    if r then
        if type(bx) == "number" and type(bz) == "number" then return Vector3.new(bx, r.Position.Y, bz) end
        return r.Position
    end
end

-- sama seperti syarat target di script game: dalam radius arena dan beda tinggi < 80
local function InArena()
    local hrp = Root()
    if not hrp then return false end
    if not BOSS_CENTRE then return true end
    local d = hrp.Position - BOSS_CENTRE
    return Flat(d) <= BOSS_INSIDE and math.abs(d.Y) < 80
end

local function GroundAt(pos)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { LP.Character }
    local r = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), rp)
    return r and r.Position
end

-- ---------- zona bahaya ----------
local function ParseShapes(sh)
    local out = {}
    if type(sh) ~= "table" then return out end
    for _, s in ipairs(sh) do
        if type(s) == "table" and type(s.x) == "number" and type(s.z) == "number" and type(s.radius) == "number"
            and (s.kind == "circle" or s.kind == "ring" or s.kind == "cone") then
            out[#out + 1] = { kind = s.kind, x = s.x, z = s.z, radius = s.radius,
                inner = type(s.inner) == "number" and s.inner or nil,
                yaw = type(s.yaw) == "number" and s.yaw or 0,
                half = type(s.half) == "number" and s.half or nil }
        end
    end
    return out
end

local function InShape(s, p)
    local dx, dz = p.X - s.x, p.Z - s.z
    local d = math.sqrt(dx * dx + dz * dz)
    local m = BOSS_MARGIN
    if s.kind == "circle" then
        return d <= s.radius + m
    elseif s.kind == "ring" then
        return d <= s.radius + m and d >= (s.inner or 0) - m
    else -- cone
        if d > s.radius + m then return false end
        if d < 1 then return true end
        local half = s.half or (math.pi / 4)
        if half > 3.2 then half = math.rad(half) end            -- kalau ternyata derajat
        local sy, cy = math.sin(s.yaw), math.cos(s.yaw)
        -- arah yaw belum pasti (sin,cos) atau (-sin,-cos): cek keduanya, anggap kena kalau salah satu cocok
        for _, f in ipairs({ { sy, cy }, { -sy, -cy } }) do
            local ang = math.acos(math.clamp((dx * f[1] + dz * f[2]) / d, -1, 1))
            if ang <= half + 0.1 then return true end
        end
        return false
    end
end

local function Unsafe(p, shapes)
    for _, s in ipairs(shapes) do
        if InShape(s, p) then return true end
    end
    return false
end

-- Waypoint aman buatan sendiri (opsional): posisi di dalam arena yang jarang kena serangan, mis. V(x, y, z).
-- Kalau diisi, dipilih yang TIDAK kena zona serangan dan paling dekat dengan posisi kamu.
-- Kalau kosong, titik aman dihitung otomatis dari zona serangan.
local SAFE_SPOTS = {
    -- V(0, 4, 0),
}

local function FindSafe(from, shapes)
    local best, bd
    for _, sp in ipairs(SAFE_SPOTS) do
        if not Unsafe(sp, shapes) then
            local d = (sp - from).Magnitude
            if not bd or d < bd then best, bd = sp, d end
        end
    end
    if best then return best end
    for dist = 15, DODGE_DIST, 15 do
        for i = 0, 15 do
            local a = i * math.pi / 8
            local c = from + Vector3.new(math.cos(a) * dist, 0, math.sin(a) * dist)
            local inside = (not BOSS_CENTRE) or Flat(c - BOSS_CENTRE) <= BOSS_INSIDE * 0.9
            if inside and not Unsafe(c, shapes) then
                local g = GroundAt(c)
                if g then return g + Vector3.new(0, 4, 0) end
            end
        end
    end
end

-- Slide: karakter meluncur cepat ke titik aman (bukan teleport), jadi server melihat gerakan kontinu.
local SLIDE_SPEED = 150                 -- stud/detik
local slideGoal, slideRun = nil, false

local function SlideTo(dest)
    slideGoal = dest
    if slideRun then return end
    slideRun = true
    task.spawn(function()
        while slideGoal do
            local dt = RunService.Heartbeat:Wait()
            local hrp = Root()
            if not hrp then break end
            hrp.Anchored = false
            local delta = slideGoal - hrp.Position
            local dist = delta.Magnitude
            local step = SLIDE_SPEED * dt
            if dist <= step then
                hrp.CFrame = CFrame.new(slideGoal) * (hrp.CFrame - hrp.CFrame.Position)
                pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
                slideGoal = nil
            else
                local dir = delta.Unit
                hrp.CFrame = CFrame.new(hrp.Position + dir * step) * (hrp.CFrame - hrp.CFrame.Position)
                pcall(function() hrp.AssemblyLinearVelocity = dir * SLIDE_SPEED end)
            end
        end
        slideGoal = nil
        slideRun = false
    end)
end

-- Agresif: begitu event serangan diterima, cek posisi tiap frame sampai serangan lewat.
-- Kalau posisi / tujuan masuk zona -> slide cepat ke titik aman terdekat dan TETAP di sana.
local function Evade(hit, shapes, name)
    local moved = false
    while workspace:GetServerTimeNow() < hit + 0.15 do
        if os.clock() - bossTick > 1.5 then break end
        local hrp = Root()
        if hrp then
            local goalBad = slideGoal and Unsafe(slideGoal, shapes)
            if (not slideGoal and Unsafe(hrp.Position, shapes)) or goalBad then
                if not moved then moved = true; dodgeCount += 1; Stats.dodges += 1 end
                local dest = FindSafe(hrp.Position, shapes) or (hrp.Position + Vector3.new(0, 80, 0))
                SlideTo(dest)
                Stats.boss = "slide " .. tostring(name)
            end
        end
        task.wait(0.03)
    end
    if moved then
        while slideGoal do task.wait(0.03) end      -- tunggu sampai tiba
        local h1 = Root()
        if h1 then h1.Anchored = true end
        task.wait(DODGE_HOLD)
        dodgeCount = math.max(dodgeCount - 1, 0)
        if dodgeCount == 0 then
            local h2 = Root()
            if h2 then h2.Anchored = false end
        end
    end
end

local function OnBossEvent(ev)
    if os.clock() - bossTick > 1.5 then return end        -- hanya saat Auto Boss aktif
    local t = ev.t
    if t == "atk" then
        local shapes = ParseShapes(ev.sh)
        if type(ev.hit) == "number" and #shapes > 0 then
            task.spawn(Evade, ev.hit, shapes, ev.k)
        end
    elseif t == "down" then
        bossDown = true
    elseif t == "up" or t == "dend" or t == "end" then
        bossDown = false
    end
end

local function EnsureBossListener()
    if bossConn and bossConn.Connected then return end
    local r = Remote("Boss")
    if r and r:IsA("RemoteEvent") then
        bossConn = r.OnClientEvent:Connect(function(batch)
            if type(batch) ~= "table" then return end
            for _, ev in ipairs(batch) do
                if type(ev) == "table" then pcall(OnBossEvent, ev) end
            end
        end)
        W.Conns[#W.Conns + 1] = bossConn
    end
end

local function BossStep()
    bossTick = os.clock()
    EnsureBossListener()
    local phase = BossPhase()

    if phase == "wait" or phase == "over" then
        stagePulse.on = false; AimPos = nil
        Stats.boss = "menunggu boss muncul (" .. phase .. ")"
        return
    end

    if not InArena() then                                  -- belum di arena: kirim join berkala
        stagePulse.on = false; AimPos = nil
        if os.clock() - bossJoinT >= 3 then
            bossJoinT = os.clock()
            Call("Boss", "join")
        end
        Stats.boss = "join dikirim (" .. phase .. ")"
        return
    end

    if phase ~= "fight" then                               -- "coming": sudah di arena, tunggu mulai
        stagePulse.on = false; AimPos = nil
        Stats.boss = "di arena, menunggu fight mulai"
        return
    end

    if bossDown then                                       -- KO: tidak bisa menyerang
        stagePulse.on = false; AimPos = nil
        Stats.boss = "KO, menunggu revive / selesai"
        return
    end

    local pos = BossPos()
    if not pos then
        stagePulse.on = false; AimPos = nil
        Stats.boss = "posisi boss belum terbaca"
        return
    end
    AimPos = pos
    stagePulse.on = true
    if dodgeCount == 0 then
        local hp = workspace:GetAttribute("BossHp")
        Stats.boss = "fight" .. (type(hp) == "number" and string.format(" · HP %d%%", math.floor(hp * 100 + 0.5)) or "")
    end
end

-- ===== AUTO CLICK POP (bubble "x2!") =====
-- Pop muncul sebagai objek GUI di  PlayerGui > Main > HUD > Pops  dan HARUS di-klik (claim lewat remote saja tidak berpengaruh).
-- Script memantau folder itu; begitu ada pop yang tampil, sinyal klik tombolnya dipicu langsung (tanpa input mouse/touch,
-- jadi kontrol HP tidak terganggu).
local POP_RETRY = 0.6                 -- kalau pop masih ada, picu lagi setelah jeda ini
local popsCache, popsScanT = nil, 0
local popSeen = setmetatable({}, { __mode = "k" })

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

local function FindCI(parent, name)     -- cari anak berdasarkan nama tanpa peduli huruf besar/kecil
    if not parent then return nil end
    local l = string.lower(name)
    for _, c in ipairs(parent:GetChildren()) do
        if string.lower(c.Name) == l then return c end
    end
end

local function PopsFolder()
    if popsCache and popsCache.Parent then return popsCache end
    if os.clock() - popsScanT < 1 then return nil end
    popsScanT = os.clock()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    local f = FindCI(FindCI(FindCI(pg, "Main"), "HUD"), "Pops")
    if not f then       -- cadangan: cari folder bernama Pops yang induknya HUD
        for _, d in ipairs(pg:GetDescendants()) do
            if string.lower(d.Name) == "pops" and d.Parent and string.lower(d.Parent.Name) == "hud" then f = d; break end
        end
    end
    popsCache = f
    return f
end

local function PopObject(c)
    if c:IsA("GuiObject") then return c end
    return c:FindFirstChildWhichIsA("GuiObject", true)
end

local SIG_NAMES = { "MouseButton1Down", "MouseButton1Click", "MouseButton1Up", "Activated", "TouchTap" }
local function FireSignals(btn)      -- memicu event tombol langsung di script game, tanpa input apa pun
    local any = false
    for _, nm in ipairs(SIG_NAMES) do
        local okS, sig = pcall(function() return btn[nm] end)
        if okS and sig then
            local fired = false
            if typeof(firesignal) == "function" then fired = pcall(firesignal, sig) end
            if not fired and typeof(getconnections) == "function" then
                local okc, cons = pcall(getconnections, sig)
                if okc and type(cons) == "table" then
                    for _, cn in ipairs(cons) do
                        if pcall(function() cn:Fire() end) then fired = true end
                    end
                end
            end
            if fired then any = true end
        end
    end
    return any
end

local function ClickPop(pop)         -- return teks hasil untuk ditampilkan di Status
    local btn = pop:IsA("GuiButton") and pop or pop:FindFirstChildWhichIsA("GuiButton", true)
    if not btn then return "tidak ada tombol di pop" end
    return FireSignals(btn) and "sinyal klik" or "sinyal gagal (executor tanpa firesignal?)"
end

local function PopStep()
    local folder = PopsFolder()
    if not folder then Stats.pop = "folder Main > HUD > Pops tidak ketemu"; return end
    local now, active = os.clock(), 0
    for _, c in ipairs(folder:GetChildren()) do
        local pop = PopObject(c)
        if pop then
            local rec = popSeen[pop]
            if not rec then rec = { last = -10 }; popSeen[pop] = rec end
            if Shown(pop) and pop.AbsoluteSize.X > 2 and pop.AbsoluteSize.Y > 2 then
                active += 1
                if now - rec.last >= POP_RETRY then
                    rec.last = now
                    Stats.popClicks += 1
                    Stats.pop = pop.Name .. ": " .. ClickPop(pop)
                    return          -- satu klik per putaran
                end
            end
        end
    end
    if active == 0 then Stats.pop = "menunggu pop muncul di Pops" end
end

-- ===== AUTO HATCH (Auto Catch Pet) + TELEPORT WORLD =====
-- Telur mengikuti World terpilih. Remote: PetAction:InvokeServer("hatch", { egg = id, count = 1 atau 3 }).
-- price = harga satuan dalam Trophy. Buka x3 -> ditampilkan harga satuan × 3 = total.
local EGGS = {
    ["World 1"] = { { id = "normal", name = "Normal Egg", price = 10, pos = V(61, 5, 35) }, { id = "shinobi", name = "Shinobi Egg", price = 400, pos = V(85, 5, 34) } },
    ["World 2"] = { { id = "lotus", name = "Lotus Egg", price = 790e6, pos = V(3057, 5, 35) }, { id = "celestial", name = "Celestial Egg", price = 1.8e12, pos = V(3083, 5, 36) } },
    ["World 3"] = { { id = "bloodmoon", name = "Blood Moon Egg", price = 390e15, pos = V(6061, 5, 33) }, { id = "demon", name = "Demon Egg", price = 890e18, pos = V(6083, 5, 36) } },
    ["World 4"] = { { id = "frost", name = "Frost Egg", price = 195e24, pos = V(9057, 5, 34) }, { id = "abyss", name = "Abyss Egg", price = 440e27, pos = V(9083, 5, 36) } },
    ["World 5"] = { { id = "nebula", name = "Nebula Egg", price = 97.5e33, pos = V(12060.83, 5.53, 33.88) }, { id = "void", name = "Void Egg", price = 220e36, pos = V(12080.92, 6.37, 29.11) } },
}
local EGG_NAME, EGG_COUNT, HATCH_INT = "Normal Egg", 1, 0.3

local NUM_SUF = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud" }
local function FmtNum(n)
    local i = 1
    while n >= 1000 and i < #NUM_SUF do n = n / 1000; i += 1 end
    local t = string.format("%.2f", n):gsub("%.?0+$", "")
    return t .. NUM_SUF[i]
end

local function EggNames(w)
    local o = {}
    for _, e in ipairs(EGGS[w] or {}) do o[#o + 1] = e.name end
    return o
end
local function EggByName(w, name)
    for _, e in ipairs(EGGS[w] or {}) do
        if e.name == name then return e end
    end
end
local function EggPriceText()
    local e = EggByName(WORLD, EGG_NAME)
    if not e then return "Pilih egg dulu" end
    local one = FmtNum(e.price)
    if EGG_COUNT <= 1 then return e.name .. "  ·  Harga: " .. one .. " Trophy" end
    return e.name .. "  ·  Harga: " .. one .. " × " .. EGG_COUNT .. " = " .. FmtNum(e.price * EGG_COUNT) .. " Trophy"
end

local function HatchStep()
    local e = EggByName(WORLD, EGG_NAME)
    if not e then Stats.hatch = "pilih egg dulu"; return end
    if e.pos then                                  -- hatch tidak bisa dari jauh: teleport ke depan egg dulu
        local hrp = Root()
        if hrp then
            local d = hrp.Position - e.pos
            if Vector3.new(d.X, 0, d.Z).Magnitude > 8 then TP(e.pos); task.wait(0.3) end
        end
    end
    local ok, res = Call("PetAction", "hatch", { egg = e.id, count = EGG_COUNT })
    local info = "ok"
    if res ~= nil and res ~= true then
        info = type(res) == "table" and "ok (tabel)" or tostring(res)
        if #info > 36 then info = info:sub(1, 36) .. "…" end
    end
    if ok then Stats.hatches += EGG_COUNT end
    Stats.hatch = e.name .. " ×" .. EGG_COUNT .. " · " .. (ok and info or "gagal")
end

local function TeleportWorld(name)
    local idx = table.find(WORLD_ORDER, name)
    if not idx then return end
    Call("Teleport", idx)
    N("Teleport", name .. " · " .. (WORLD_NAME[name] or ""), "#6495ED")
end

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "swords" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

-- ---------- kolom 1 ----------
-- World terpilih dipakai bersama Auto Stage, Auto Train dan Auto Hatch
local ddStage, ddEgg, eggLbl
local worldTP, worldReady = true, false
-- worldReady baru true setelah UI selesai dimuat (lihat W:OnBooted di bawah), supaya nilai config yang dimuat tidak memicu teleport

local function ApplyWorld(name, allowTP)
    local wd = WORLDS[name]
    if not wd then return end
    local changed = name ~= WORLD
    local oldEnd = STAGE_END
    WORLD = name
    if ddStage then
        ddStage:SetList(StageList(name))
        if STAGE_END < wd.first or STAGE_END > wd.last then STAGE_END = wd.first end
        ddStage:Set("Stage " .. STAGE_END, true)
    end
    if ddEgg then
        local names = EggNames(name)
        ddEgg:SetList(names)
        if not EggByName(name, EGG_NAME) then EGG_NAME = names[1] or "" end
        ddEgg:Set(EGG_NAME, true)
    end
    if eggLbl then eggLbl:SetText(EggPriceText()) end
    if changed or STAGE_END ~= oldEnd then RestartStage() end
    if allowTP and changed and worldTP and worldReady then TeleportWorld(name) end
end

local cWorld = Main:AddCard({ Title = "World", Icon = "globe", Column = 1 })
cWorld:Dropdown({
    Title = "World (untuk Auto Stage / Train / Hatch)", List = WORLD_ORDER, Value = "World 1", id = "ae_world",
    Callback = function(v) if v then ApplyWorld(tostring(v), true) end end,
})
cWorld:Toggle({
    Title = "Teleport otomatis saat ganti World", Value = true, id = "ae_world_tp",
    Callback = function(v) worldTP = v end,
})
cWorld:Button({
    Title = "Teleport ke world terpilih", Text = "Teleport ke world terpilih",
    Callback = function() TeleportWorld(WORLD) end,
})

local cClick = Main:AddCard({ Title = "Auto Click (Train)", Icon = "zap", Column = 1 })
cClick:Toggle({
    Title = "Auto Click", id = "ae_click",
    Callback = function(v)
        clickPulse.on = v
        clickPulse.acc = 0
        N("Auto Click", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

tgTrain = cClick:Toggle({
    Title = "Auto Train", id = "ae_train",
    Callback = function(v)
        if v then OffOthers(tgTrain) end        -- fitur teleport tidak jalan bersamaan
        Loop("train", v, function() return TRAIN_INT end, TrainStep)
        if not v then Stats.zone = "-" end
        N("Auto Train", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

cClick:Toggle({
    Title = "Auto Click Pop (x2!)", id = "ae_pop",
    Callback = function(v)
        Loop("pop", v, function() return 0.1 end, PopStep)
        if not v then Stats.pop = "-" end
        N("Auto Click Pop", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

local cStage = Main:AddCard({ Title = "Auto Stage", Icon = "swords", Column = 1 })
ddStage = cStage:Dropdown({
    Title = "Stage tujuan (titik akhir)", List = StageList("World 1"), Value = "Stage 1", id = "ae_stage",
    Callback = function(v)
        local n = v and tonumber(tostring(v):match("%d+"))
        if n and n ~= STAGE_END then
            STAGE_END = n
            RestartStage()
        end
    end,
})
tgStage = cStage:Toggle({
    Title = "Auto Stage", Desc = "Attack + skill R/E per stage, claim trophy, ulang otomatis", id = "ae_stage_on",
    Callback = function(v)
        if v then OffOthers(tgStage) end        -- fitur teleport tidak jalan bersamaan
        stagePulse.on = false
        stagePulse.acc = 0
        AimPos = nil
        Loop("stage", v, function() return 0.1 end, RunStages)
        if not v then Stats.stage = "-" end
        N("Auto Stage", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgStage2 = cStage:Toggle({
    Title = "Auto Stage V2", Desc = "Per stage: tunggu 1 dtk, tembak 5x, lanjut stage berikutnya", id = "ae_stage2_on",
    Callback = function(v)
        if v then OffOthers(tgStage2) end        -- fitur teleport tidak jalan bersamaan
        stagePulse.on = false
        stagePulse.acc = 0
        AimPos = nil
        Loop("stage2", v, function() return 0.1 end, RunStagesV2)
        if not v then Stats.stage = "-" end
        N("Auto Stage V2", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

-- Redeem Codes
local cCodes = Main:AddCard({ Title = "Rewards & Codes", Icon = "gift", Column = 1 })
cCodes:Toggle({
    Title = "Auto Claim Reward", Desc = "Klaim reward 1, 2, 3 berkala", id = "ae_reward",
    Callback = function(v)
        Loop("reward", v, function() return REWARD_INT end, ClaimRewards)
        N("Auto Claim Reward", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cCodes:Button({
    Title = "Redeem semua kode", Text = "Redeem semua kode (" .. #CODES .. ")",
    Callback = RedeemAll,
})
codeLbl = cCodes:Label({ Text = "-", Size = 11, Color = "Text" })

-- Boss Kyubi
local cBoss = Main:AddCard({ Title = "Boss Kyubi", Icon = "flame", Column = 1 })
tgBoss = cBoss:Toggle({
    Title = "Auto Boss Kyubi", Desc = "Join, serang, dan keluar dari zona serangan Kyubi", id = "ae_boss", Expand = true,
    Callback = function(v)
        if v then OffOthers(tgBoss) end
        stagePulse.on = false; stagePulse.acc = 0; AimPos = nil
        Loop("boss", v, function() return 0.03 end, BossStep)
        if not v then
            Stats.boss = "-"
            slideGoal, dodgeCount = nil, 0
            local h = Root()
            if h then h.Anchored = false end             -- jangan sampai karakter tertinggal terkunci
        end
        N("Auto Boss Kyubi", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgBoss:Sub(function(c)
    c:Slider({
        Title = "Jarak maks cari tempat aman (stud)", Min = 30, Max = 250, Value = 120, Rounding = 0, id = "ae_boss_dist",
        Callback = function(v) DODGE_DIST = v end,
    })
    c:Slider({
        Title = "Tahan di tempat aman setelah serangan (s)", Min = 0.1, Max = 3, Value = 0.4, Rounding = 1, Suffix = "s", id = "ae_boss_hold",
        Callback = function(v) DODGE_HOLD = v end,
    })
    c:Slider({
        Title = "Kecepatan slide (stud/detik)", Min = 40, Max = 400, Value = 150, Rounding = 0, id = "ae_boss_speed",
        Callback = function(v) SLIDE_SPEED = v end,
    })
    c:Slider({
        Title = "Margin zona bahaya (stud)", Min = 0, Max = 30, Value = 10, Rounding = 0, id = "ae_boss_margin",
        Callback = function(v) BOSS_MARGIN = v end,
    })
end)

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

local fuseStartIn
local tgFuse = cPet:Toggle({
    Title = "Auto Fuse", Desc = "Fuse 4 pet, ID dicari otomatis", id = "ae_fuse", Expand = true,
    Callback = function(v)
        if v then
            fuseLearn = true
            if not InstallFuseHook() then N("Auto Fuse", "Executor tanpa hookmetamethod: tidak bisa belajar dari fuse manual", "#FFA500", 5) end
            local n = fuseStartIn and tonumber(fuseStartIn:Get())
            if n and math.floor(n) ~= fuseBase then fuseBase = math.floor(n); FuseReset() end
        end
        Loop("fuse", v, function() return 0.15 end, FuseStep)
        if not v then Stats.fuse = "-" end
        N("Auto Fuse", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgFuse:Sub(function(c)
    fuseStartIn = c:Input({
        Title = "Mulai dari ID pet", Value = "428", id = "ae_fuse_start",
        Callback = function(t)
            local n = tonumber(t)
            if n then fuseBase = math.floor(n); FuseReset() end
        end,
    })
    c:Button({
        Title = "Reset scan", Text = "Reset scan (lupakan ID yang sudah dicoba)",
        Callback = function()
            table.clear(fuseUsed); FuseReset()
            local n = fuseStartIn and tonumber(fuseStartIn:Get())
            if n then fuseBase = math.floor(n) end
            N("Auto Fuse", "Scan diulang dari ID " .. fuseBase, "#6495ED")
        end,
    })
end)

local cHatch = Main:AddCard({ Title = "Auto Hatch (Catch Pet)", Icon = "egg", Column = 2 })
ddEgg = cHatch:Dropdown({
    Title = "Egg (sesuai World terpilih)", List = EggNames("World 1"), Value = "Normal Egg", id = "ae_egg",
    Callback = function(v)
        if not v then return end
        EGG_NAME = tostring(v)
        if eggLbl then eggLbl:SetText(EggPriceText()) end
    end,
})
cHatch:Dropdown({
    Title = "Jumlah sekali buka", List = { "Buka 1 egg", "Buka 3 egg" }, Value = "Buka 1 egg", id = "ae_egg_count",
    Callback = function(v)
        local n = v and tonumber(tostring(v):match("%d+"))
        if n then EGG_COUNT = n end
        if eggLbl then eggLbl:SetText(EggPriceText()) end
    end,
})
eggLbl = cHatch:Label({ Text = EggPriceText(), Size = 12, Color = "Text" })
tgHatch = cHatch:Toggle({
    Title = "Auto Hatch", id = "ae_hatch", Expand = true,
    Callback = function(v)
        if v then OffOthers(tgHatch) end
        Loop("hatch", v, function() return HATCH_INT end, HatchStep)
        if not v then Stats.hatch = "-" end
        N("Auto Hatch", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgHatch:Sub(function(c)
    c:Slider({
        Title = "Jeda antar hatch (s)", Min = 0.05, Max = 5, Value = 0.3, Rounding = 2, Suffix = "s", id = "ae_hatch_int",
        Callback = function(v) HATCH_INT = v end,
    })
end)
cHatch:Button({
    Title = "Hatch sekali", Text = "Hatch sekali sekarang",
    Callback = function() task.spawn(HatchStep) end,
})

local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })

task.spawn(function()
    while W.Alive do
        task.wait(0.5)
        pcall(function()
            local txt = "Click: " .. Stats.clicks .. "   Attack: " .. Stats.attacks ..
                "\nRebirth: " .. Stats.rebirths .. "   Equip best: " .. Stats.equips ..
                "\nStage: " .. Stats.stage .. "   Error: " .. Stats.errors ..
                "\nZona train: " .. Stats.zone ..
                "\nPop: " .. Stats.pop .. "   klik: " .. Stats.popClicks ..
                "\nHatch: " .. Stats.hatch .. "   total egg: " .. Stats.hatches ..
                "\nFuse: " .. Stats.fuse .. "   berhasil: " .. Stats.fuses ..
                "\nBoss: " .. Stats.boss .. "   dodge: " .. Stats.dodges ..
                "\nReward diklaim: " .. Stats.rewards
            stLbl:SetText(txt)
        end)
    end
end)

-- hentikan semua saat Unload
W:OnUnload(function()
    slideGoal, dodgeCount = nil, 0
    local h = Root()
    if h then h.Anchored = false end
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
W:OnBooted(function() task.delay(2, function() worldReady = true end); N("KatssinnnHub", "Anime Eyes dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4) end)
