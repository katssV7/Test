-- KatssinnnHub | Game 7 (Anime Eyes)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Fitur: Auto Click, Auto Train (teleport sesuai rebirth), Auto Stage (teleport + bunuh MyEnemies + claim trophy), God Mode, Auto Rebirth, Auto Equip Best Pet, Remote Logger.
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
local runId = { rebirth = 0, equip = 0, train = 0, stage = 0 }
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

local Stats = { clicks = 0, attacks = 0, rebirths = 0, equips = 0, errors = 0, target = "-", zone = "-", stage = "-", kills = 0 }

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

-- ===== KARAKTER / TARGET =====
local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

-- ===== DATA AUTO STAGE =====
-- attack = titik teleport untuk menyerang tiap stage, claim = titik teleport claim trophy tiap stage (index = nomor stage).
-- Untuk menambah world baru: tambah entri di WORLDS + nama di WORLD_ORDER, dropdown World/Stage ikut otomatis.
local WORLD_ORDER = { "World 1" }
local WORLDS = {
    ["World 1"] = {
        first = 1, last = 15,
        attack = {
            [1]  = Vector3.new(-2, 4, 71),
            [2]  = Vector3.new(3, 7, -166),
            [3]  = Vector3.new(-7, 4, -248),
            [4]  = Vector3.new(-2, 8, -332),
            [5]  = Vector3.new(-1, 4, -434),
            [6]  = Vector3.new(0, 4, -515),
            [7]  = Vector3.new(2, 4, -593),
            [8]  = Vector3.new(1, 4, -702),
            [9]  = Vector3.new(1, 4, -786),
            [10] = Vector3.new(-2, 4, -872),
            [11] = Vector3.new(0, 4, -964),
            [12] = Vector3.new(1, 4, -1056),
            [13] = Vector3.new(-3, 4, -1163),
            [14] = Vector3.new(-4, 4, -1245),
            [15] = Vector3.new(0, 4, -1334),   -- di catatan tertulis "1334" (tanpa minus); disesuaikan pola stage sebelumnya
        },
        claim = {
            [1]  = Vector3.new(18, 5, -111),
            [2]  = Vector3.new(20, 6, -203),
            [3]  = Vector3.new(18, 5, -292),
            [4]  = Vector3.new(19, 7, -380),
            [5]  = Vector3.new(20, 7, -470),
            [6]  = Vector3.new(18, 5, -560),
            [7]  = Vector3.new(19, 7, -651),
            [8]  = Vector3.new(16, 6, -740),
            [9]  = Vector3.new(19, 5, -831),
            [10] = Vector3.new(17, 6, -922),
            [11] = Vector3.new(20, 7, -1008),
            [12] = Vector3.new(17, 5, -1100),
            [13] = Vector3.new(16, 6, -1190),
            [14] = Vector3.new(17, 5, -1280),
            [15] = Vector3.new(17, 6, -1372),
        },
    },
    -- ["World 2"] = { first = 10, last = 25, attack = { [10] = Vector3.new(...), ... }, claim = { ... } },
}

local WORLD, END_STAGE = "World 1", 15
local ATK_RADIUS    = 70     -- musuh di MyEnemies dianggap milik stage ini kalau jaraknya <= ini dari titik serang
local MIN_WAIT      = 1.5    -- tunggu minimal (detik) setelah teleport supaya musuh sempat muncul
local EMPTY_GRACE   = 1.0    -- stage dianggap selesai kalau tidak ada musuh hidup selama ini
local STAGE_TIMEOUT = 90     -- batas waktu per stage; lewat ini lanjut ke stage berikutnya
local CLAIM_WAIT    = 1.5    -- diam di titik claim selama ini
local STAGE_REPEAT  = true   -- ulangi dari stage awal setelah claim
local stageOn = false
local curTarget            -- posisi musuh yang sedang diserang (Vector3) atau nil

local function StageNames(worldName)
    local w, out = WORLDS[worldName], {}
    if w then for s = w.first, w.last do out[#out + 1] = "Stage " .. s end end
    return out
end

local function TP(pos)
    local hrp = Root()
    if not hrp then return false end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    return true
end

-- musuh hidup terdekat di workspace.MyEnemies dalam radius dari titik serang.
-- return: posisi musuh (atau nil), folderAda (false kalau MyEnemies tidak ketemu)
local function NearestEnemy(center)
    local folder = workspace:FindFirstChild("MyEnemies")
    if not folder then return nil, false end
    local best, bd
    for _, m in ipairs(folder:GetChildren()) do
        local hum = m:FindFirstChildOfClass("Humanoid")
        if not (hum and hum.Health <= 0) then
            local part = m:IsA("BasePart") and m
                or (m:IsA("Model") and (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true)))
            if part then
                local d = (part.Position - center).Magnitude
                if d <= ATK_RADIUS and (not bd or d < bd) then best, bd = part.Position, d end
            end
        end
    end
    return best, true
end

-- ===== FITUR =====
local clickPulse = NewPulse(function()
    local r = Remote("Train")
    if r then pcall(r.FireServer, r); Stats.clicks += 1 end
end, 0.1)

local attackPulse = NewPulse(function()
    local p = curTarget
    if not p then return end
    local r = Remote("Cast")
    if r then pcall(r.FireServer, r, "attack", V3(p.X, p.Y, p.Z)); Stats.attacks += 1 end
end, 0.2)

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

-- ===== AUTO STAGE (teleport ke titik serang -> bunuh MyEnemies -> stage berikutnya -> claim trophy di stage akhir) =====
local tgStage    -- diisi di bagian UI

local function ClaimAt(pos)
    TP(pos)
    task.wait(CLAIM_WAIT)
    -- kalau executor punya fireproximityprompt: tekan prompt (kalau ada) di sekitar titik claim
    if typeof(fireproximityprompt) == "function" then
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            n += 1
            if n % 3000 == 0 then task.wait() end
            if d:IsA("ProximityPrompt") then
                local p = d.Parent
                local bp = p and (p:IsA("BasePart") and p or p:FindFirstChildWhichIsA("BasePart"))
                if bp and (bp.Position - pos).Magnitude <= 25 then pcall(fireproximityprompt, d) end
            end
        end
    end
end

local function StageLoop(id)
    while runId.stage == id do
        local w = WORLDS[WORLD]
        if not w then Stats.stage = "world tidak ada"; return end
        local last = math.min(END_STAGE, w.last)
        for s = w.first, last do
            if runId.stage ~= id then return end
            local ap = w.attack[s]
            if ap then
                Stats.stage = WORLD .. " · stage " .. s .. "/" .. last .. " (menuju)"
                while runId.stage == id and not TP(ap) do task.wait(0.5) end
                attackPulse.on = true
                local t0, emptySince = os.clock(), nil
                while runId.stage == id do
                    task.wait(0.2)
                    local hrp = Root()
                    if hrp and (hrp.Position - ap).Magnitude > 30 then TP(ap) end
                    local e, hasFolder = NearestEnemy(ap)
                    if not hasFolder then
                        Stats.stage = "folder MyEnemies tidak ditemukan"
                        curTarget = nil; t0 = os.clock(); emptySince = nil
                    elseif e then
                        Stats.stage = WORLD .. " · stage " .. s .. "/" .. last .. " (bunuh musuh)"
                        curTarget = e; emptySince = nil
                    else
                        curTarget = nil
                        emptySince = emptySince or os.clock()
                        Stats.stage = WORLD .. " · stage " .. s .. "/" .. last .. " (menunggu musuh)"
                        if os.clock() - t0 >= MIN_WAIT and os.clock() - emptySince >= EMPTY_GRACE then
                            Stats.kills += 1
                            break
                        end
                    end
                    if hasFolder and os.clock() - t0 > STAGE_TIMEOUT then break end
                end
                curTarget = nil
            end
        end
        if runId.stage ~= id then return end
        attackPulse.on = false
        local cp = w.claim[last]
        if cp then
            Stats.stage = WORLD .. " · claim trophy stage " .. last
            ClaimAt(cp)
        end
        if not STAGE_REPEAT then
            Stats.stage = "selesai (claim stage " .. last .. ")"
            if tgStage then tgStage:Set(false) end
            return
        end
        task.wait(0.5)
    end
end

local function StopStage()
    runId.stage += 1
    stageOn = false
    curTarget = nil
    attackPulse.on = false
end
local function StartStage()
    StopStage()
    local id = runId.stage
    stageOn = true
    attackPulse.acc = 0
    task.spawn(function()
        local ok, err = pcall(StageLoop, id)
        if not ok then Stats.stage = "error: " .. tostring(err); warn("[stage] " .. tostring(err)) end
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
    if stageOn then return end      -- Auto Stage yang pegang teleport, Auto Train menunggu
    local hrp, rb = Root(), GetRebirth()
    if not hrp then return end
    if not rb then Stats.zone = "leaderstats Rebirth tidak ketemu"; return end
    local z = ZoneFor(rb)
    Stats.zone = z[1] .. " REBIRTH  (rebirth kamu: " .. rb .. ")"
    if (hrp.Position - z[2]).Magnitude > TRAIN_STAY then
        hrp.CFrame = CFrame.new(z[2] + Vector3.new(0, 3, 0))
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    end
end

-- ===== GOD MODE (jaga darah tetap penuh) =====
local godOn = false
local function GetHum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
W.Conns[#W.Conns + 1] = RunService.Heartbeat:Connect(function()
    if not godOn then return end
    local h = GetHum()
    if h and h.Health > 0 and h.Health < h.MaxHealth then h.Health = h.MaxHealth end
end)
local function GodState(v)
    local h = GetHum()
    if h then pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead, not v) end) end
end
W.Conns[#W.Conns + 1] = LP.CharacterAdded:Connect(function()
    if godOn then task.wait(0.5); GodState(true) end
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
        if logOn then
            local m = getnamecallmethod()
            if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance"
                and RemotesF and self.Parent == RemotesF and not (checkcaller and checkcaller()) then
                local args = table.pack(...)
                local nm = self.Name
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
        return oldNc(self, ...)
    end))
    return true
end

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "swords" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })
local NotePage   = W:AddPage({ Name = "Notepad", Icon = "pencil-line" })

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
local tgTrain = cClick:Toggle({
    Title = "Auto Train (teleport sesuai rebirth)", id = "ae_train", Expand = true,
    Callback = function(v)
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

-- Auto Stage (pengganti Auto Attack): pilih World, pilih Stage akhir. Stage dari awal world sampai stage akhir
-- dikerjakan berurutan, lalu claim trophy di stage akhir.
local cStage = Main:AddCard({ Title = "Auto Stage", Icon = "swords", Column = 1 })
tgStage = cStage:Toggle({
    Title = "Auto Stage", id = "ae_stage", Expand = true,
    Callback = function(v)
        if v then StartStage() else StopStage(); Stats.stage = "-" end
        N("Auto Stage", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgStage:Sub(function(c)
    c:Slider({
        Title = "Kecepatan attack (jeda detik, terkecil 0.01)", Min = 0.01, Max = 2, Value = 0.2, Rounding = 2, Suffix = "s", id = "ae_attack_speed",
        Callback = function(v) attackPulse.int = math.max(v, 0.01) end,
    })
    c:Slider({
        Title = "Radius musuh dari titik serang", Min = 20, Max = 300, Value = 70, Rounding = 0, id = "ae_stage_radius",
        Callback = function(v) ATK_RADIUS = v end,
    })
    c:Slider({
        Title = "Tunggu musuh muncul (min, s)", Min = 0, Max = 10, Value = 1.5, Rounding = 1, Suffix = "s", id = "ae_stage_minwait",
        Callback = function(v) MIN_WAIT = v end,
    })
    c:Slider({
        Title = "Batas waktu per stage (s)", Min = 10, Max = 300, Value = 90, Rounding = 0, Suffix = "s", id = "ae_stage_timeout",
        Callback = function(v) STAGE_TIMEOUT = v end,
    })
    c:Slider({
        Title = "Diam di titik claim (s)", Min = 0.5, Max = 10, Value = 1.5, Rounding = 1, Suffix = "s", id = "ae_stage_claimwait",
        Callback = function(v) CLAIM_WAIT = v end,
    })
    c:Toggle({
        Title = "Ulangi dari stage awal setelah claim", Value = true, id = "ae_stage_repeat",
        Callback = function(v) STAGE_REPEAT = v end,
    })
end)

local ddStage
local function ApplyWorld(name)
    local w = WORLDS[name]
    if not w or not ddStage then return end
    WORLD = name
    ddStage:SetList(StageNames(name))
    local cur = tonumber(tostring(ddStage:Get() or ""):match("%d+"))
    if not cur or cur < w.first or cur > w.last then
        ddStage:Set("Stage " .. w.last, true)
        END_STAGE = w.last
    end
end
cStage:Dropdown({
    Title = "World", List = WORLD_ORDER, Value = "World 1", id = "ae_world",
    Callback = function(v) if v then ApplyWorld(tostring(v)) end end,
})
ddStage = cStage:Dropdown({
    Title = "Stage akhir (mulai dari stage awal world)", List = StageNames("World 1"), Value = "Stage 15", id = "ae_stage_end",
    Callback = function(v)
        local n = v and tonumber(tostring(v):match("%d+"))
        if n then END_STAGE = n end
    end,
})

local cGod = Main:AddCard({ Title = "Survival", Icon = "shield", Column = 1 })
cGod:Toggle({
    Title = "God Mode", Desc = "Darah dijaga tetap penuh saat diserang", id = "ae_god",
    Callback = function(v)
        godOn = v
        GodState(v)
        N("God Mode", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

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
                "\nStage selesai: " .. Stats.kills .. "   Error: " .. Stats.errors ..
                "\nAuto Stage: " .. Stats.stage ..
                "\nZona train: " .. Stats.zone
            if logOn and #logLines > 0 then txt ..= "\n— remote terakhir —\n" .. table.concat(logLines, "\n") end
            stLbl:SetText(txt)
        end)
    end
end)

-- hentikan semua saat Unload
W:OnUnload(function()
    logOn = false
    StopStage()
    godOn = false
    GodState(false)
    for _, p in ipairs(pulses) do p.on = false end
    for k in pairs(runId) do runId[k] += 1 end
end)

-- Player (Movement / Fly / Client) dan Home (+ Settings) ada di ui.lua; tiap bagian aman dari error.
for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildNotepad(NotePage) end,
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
