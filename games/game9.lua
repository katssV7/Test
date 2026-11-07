-- KatssinnnHub | Game 9 (Fishing Slayer)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Fitur: Auto Fishing = lempar pancingan -> tunggu gigitan -> tarik ikan (kirim "Slash" berurutan) -> ulangi.
--   Lempar : ReliableRedEvent:FireServer({ ["\015"] = { { <posisi>, <power 0..1>, n = 2 } } }, {})
--   Tarik  : ReliableRedEvent:FireServer({ ["\017"] = { { <id>, <idx>, <waktu server>, "Slash", <idx>, -1, n = 6 } } }, {})
-- Nilai <id> (contohmu 8815) dan posisi lempar bisa DIPELAJARI otomatis dari aksi manualmu (Remote Recorder di kartu Rekam).
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "Fishing Slayer",
    Folder    = "KatssinnnHub/FishingSlayer",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- ===== LOOP (bisa dibatalkan, tidak tumpang tindih) =====
local runId = { fish = 0 }
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
-- tidur yang bisa dibatalkan; return false kalau loop dibatalkan
local function Sleep(key, id, t)
    local el = 0
    while el < t do
        if runId[key] ~= id then return false end
        el += task.wait(math.min(0.05, t - el + 0.001))
    end
    return runId[key] == id
end

-- ===== PENGATURAN =====
local WAIT_BITE   = 3        -- detik menunggu ikan menggigit setelah lempar
local HITS        = 8        -- jumlah "Slash" per tarikan
local HIT_GAP     = 0.22     -- jeda antar Slash (contohmu 0.21 - 0.39 detik)
local CAST_GAP    = 1.0      -- jeda setelah tarik sebelum lempar lagi
local POWER_MIN, POWER_MAX = 0.5, 0.9
local PULL_ID     = 8815     -- angka pertama di paket tarik (dipelajari otomatis kalau Remote Recorder aktif)
local AUTO_LEARN  = true
local RELATIVE    = false    -- lempar relatif ke posisi karakter (pakai offset dari lemparan terakhir yang direkam)

local Stats = { status = "idle", casts = 0, pulls = 0, hits = 0, errors = 0 }

-- ===== REMOTE =====
local remote = RS:FindFirstChild("ReliableRedEvent") or RS:WaitForChild("ReliableRedEvent", 10)

-- ===== HELPER =====
local function Vec(x, y, z)
    if typeof(vector) == "table" and vector.create then return vector.create(x, y, z) end
    return Vector3.new(x, y, z)
end
local function Comp(v)                         -- ambil x,y,z dari vector / Vector3
    local ok, x, y, z = pcall(function()
        local t = typeof(v)
        if t == "Vector3" then return v.X, v.Y, v.Z end
        return v.x, v.y, v.z
    end)
    if ok then return x, y, z end
end
local function Now()                           -- waktu server (contoh: 1794051009.47)
    local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
    return ok and t or (os.time() + (os.clock() % 1))
end
local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function Rand(a, b) return a + math.random() * (b - a) end

-- posisi lempar contoh dari data yang kamu kirim (dipakai kalau belum ada lemparan yang direkam)
local SAMPLE = {
    { -13.387155532836914, -0.2815028131008148, -155.10609436035156 },
    { -9.24265193939209, -1.6271926164627075, -129.4575653076172 },
    { -15.568771362304688, 1.3304721117019653, -135.24957275390625 },
}
local learnedCast                              -- { x, y, z, power }  (lemparan manual terakhir)
local learnedOff                               -- { dx, dy, dz } relatif ke karakter saat direkam

local function CastTarget()
    local x, y, z
    if learnedCast then
        x = learnedCast[1] + Rand(-2, 2)
        y = learnedCast[2]
        z = learnedCast[3] + Rand(-2, 2)
        local hrp = Root()
        if RELATIVE and learnedOff and hrp then
            local p = hrp.Position
            x, y, z = p.X + learnedOff[1] + Rand(-2, 2), p.Y + learnedOff[2], p.Z + learnedOff[3] + Rand(-2, 2)
        end
    else
        local a = SAMPLE[math.random(#SAMPLE)]
        x, y, z = a[1] + Rand(-2, 2), a[2], a[3] + Rand(-2, 2)
    end
    return Vec(x, y, z)
end

-- ===== AKSI =====
local function Cast()
    if not remote then return false end
    local power = Rand(POWER_MIN, POWER_MAX)
    local payload = { ["\015"] = { { CastTarget(), power, n = 2 } } }
    local ok = pcall(remote.FireServer, remote, payload, {})
    if ok then Stats.casts += 1 else Stats.errors += 1 end
    return ok
end

local function Slash(idx)
    if not remote then return false end
    local payload = { ["\017"] = { { PULL_ID, idx, Now(), "Slash", idx, -1, n = 6 } } }
    local ok = pcall(remote.FireServer, remote, payload, {})
    if ok then Stats.hits += 1 else Stats.errors += 1 end
    return ok
end

-- satu siklus penuh: lempar -> tunggu gigitan -> tarik (HITS kali Slash) -> jeda
local function FishCycle(id)
    if not remote then Stats.status = "ReliableRedEvent tidak ketemu"; Sleep("fish", id, 1); return end

    Stats.status = "melempar pancingan"
    if not Cast() then Sleep("fish", id, 1); return end

    Stats.status = string.format("menunggu gigitan (%.1fs)", WAIT_BITE)
    if not Sleep("fish", id, WAIT_BITE) then return end

    for i = 1, HITS do
        if runId.fish ~= id then return end
        Stats.status = string.format("menarik ikan %d/%d", i, HITS)
        Slash(i)
        if not Sleep("fish", id, HIT_GAP + Rand(-0.03, 0.05)) then return end
    end
    Stats.pulls += 1

    Stats.status = "jeda sebelum lempar lagi"
    Sleep("fish", id, CAST_GAP)
end

-- ===== REMOTE RECORDER (pelajari id tarikan & posisi lempar dari aksi manualmu) =====
local recOn, oldNc, recLines = false, nil, {}
local function Fmt(v, d)
    d = d or 0
    local t = typeof(v)
    if t == "number" then return string.format("%.3f", v) end
    if t == "string" then return '"' .. v .. '"' end
    if t == "vector" or t == "Vector3" then
        local x, y, z = Comp(v)
        return string.format("vec(%.2f, %.2f, %.2f)", x or 0, y or 0, z or 0)
    end
    if t == "table" and d < 3 then
        local parts = {}
        for k, x in pairs(v) do
            if k ~= "n" then parts[#parts + 1] = (type(k) == "string" and ("[" .. #k .. "ch#" .. string.byte(k, 1) .. "]=") or "") .. Fmt(x, d + 1) end
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function Learn(payload)
    if type(payload) ~= "table" then return end
    local cast = payload["\015"]
    if type(cast) == "table" and type(cast[1]) == "table" then
        local x, y, z = Comp(cast[1][1])
        if x then
            learnedCast = { x, y, z, cast[1][2] }
            local hrp = Root()
            if hrp then learnedOff = { x - hrp.Position.X, y - hrp.Position.Y, z - hrp.Position.Z } end
        end
    end
    local pull = payload["\017"]
    if AUTO_LEARN and type(pull) == "table" and type(pull[1]) == "table" and type(pull[1][1]) == "number" then
        PULL_ID = pull[1][1]
    end
end

local function InstallHook()
    if oldNc then return true end
    if not (hookmetamethod and getnamecallmethod) then return false end
    local wrap = newcclosure or function(f) return f end
    oldNc = hookmetamethod(game, "__namecall", wrap(function(self, ...)
        if recOn and self == remote and not (checkcaller and checkcaller()) and getnamecallmethod() == "FireServer" then
            local a1 = ...
            task.spawn(function()
                pcall(Learn, a1)
                local line = Fmt(a1)
                print("[Rec] " .. line)
                recLines[#recLines + 1] = line
                if #recLines > 4 then table.remove(recLines, 1) end
            end)
        end
        return oldNc(self, ...)
    end))
    return true
end

-- log paket masuk dari server (untuk mencari sinyal "ikan menggigit")
local inOn, inCount = false, 0
if remote then
    pcall(function()
        remote.OnClientEvent:Connect(function(...)
            if not inOn then return end
            inCount += 1
            if inCount > 60 then return end
            print("[Masuk] " .. Fmt({ ... }))
        end)
    end)
end

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "fish" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

-- ---------- Auto Fishing ----------
local cFish = Main:AddCard({ Title = "Auto Fishing", Icon = "fish", Column = 1 })
local tgFish = cFish:Toggle({
    Title = "Auto Fishing", Desc = "Lempar -> tunggu gigitan -> tarik (Slash) -> ulangi", id = "fs_auto", Expand = true,
    Callback = function(v)
        Loop("fish", v, function() return 0.05 end, FishCycle)
        if not v then Stats.status = "idle" end
        N("Auto Fishing", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgFish:Sub(function(c)
    c:Slider({
        Title = "Tunggu gigitan (s)", Min = 0.5, Max = 15, Value = WAIT_BITE, Rounding = 1, Suffix = "s", id = "fs_bite",
        Callback = function(v) WAIT_BITE = v end,
    })
    c:Slider({
        Title = "Jumlah Slash per tarikan", Min = 1, Max = 40, Value = HITS, Rounding = 0, id = "fs_hits",
        Callback = function(v) HITS = math.floor(v) end,
    })
    c:Slider({
        Title = "Jeda antar Slash (s)", Min = 0.05, Max = 0.8, Value = HIT_GAP, Rounding = 2, Suffix = "s", id = "fs_gap",
        Callback = function(v) HIT_GAP = v end,
    })
    c:Slider({
        Title = "Jeda sebelum lempar lagi (s)", Min = 0.2, Max = 5, Value = CAST_GAP, Rounding = 1, Suffix = "s", id = "fs_castgap",
        Callback = function(v) CAST_GAP = v end,
    })
    c:Slider({
        Title = "Power lempar minimum", Min = 0.1, Max = 1, Value = POWER_MIN, Rounding = 2, id = "fs_pmin",
        Callback = function(v) POWER_MIN = v; if POWER_MAX < v then POWER_MAX = v end end,
    })
    c:Slider({
        Title = "Power lempar maksimum", Min = 0.1, Max = 1, Value = POWER_MAX, Rounding = 2, id = "fs_pmax",
        Callback = function(v) POWER_MAX = v; if POWER_MIN > v then POWER_MIN = v end end,
    })
    c:Toggle({
        Title = "Lempar relatif ke karakter", Desc = "Pakai offset dari lemparan manual terakhir yang direkam", Value = false, id = "fs_rel",
        Callback = function(v) RELATIVE = v end,
    })
end)

-- ---------- Manual ----------
local cMan = Main:AddCard({ Title = "Manual", Icon = "pointer", Column = 1 })
cMan:Button({
    Title = "Lempar sekali", Text = "Lempar pancingan sekali",
    Callback = function()
        local ok = Cast()
        N("Lempar", ok and "Terkirim" or "ReliableRedEvent tidak ketemu", ok and "#6495ED" or "#DC3232")
    end,
})
cMan:Button({
    Title = "Tarik sekali", Text = "Tarik ikan sekali (sejumlah Slash)",
    Callback = function()
        task.spawn(function()
            for i = 1, HITS do
                Slash(i)
                task.wait(HIT_GAP)
            end
            N("Tarik", HITS .. " Slash terkirim", "#6495ED")
        end)
    end,
})

-- ---------- Rekam / Debug ----------
local cRec = Main:AddCard({ Title = "Rekam (belajar dari aksi manual)", Icon = "scan", Column = 2 })
cRec:Toggle({
    Title = "Remote Recorder", Desc = "Aktifkan, lalu lempar & tarik ikan MANUAL sekali", id = "fs_rec",
    Callback = function(v)
        if v and not InstallHook() then
            N("Remote Recorder", "Executor tidak mendukung hookmetamethod", "#DC3232", 5)
            return
        end
        recOn = v
        if v then N("Remote Recorder", "ON — lempar & tarik ikan manual sekali", "#50C864", 4) end
    end,
})
cRec:Toggle({
    Title = "Pelajari ID tarikan otomatis", Value = true, id = "fs_learn",
    Callback = function(v) AUTO_LEARN = v end,
})
cRec:Input({
    Title = "ID tarikan (angka pertama paket tarik)", Value = tostring(PULL_ID), Placeholder = "8815",
    ButtonText = "Set", id = "fs_pullid",
    Callback = function(v)
        local n = tonumber(v)
        if n then PULL_ID = n end
    end,
    OnButton = function(v)
        local n = tonumber(v)
        if n then PULL_ID = n; N("ID tarikan", "Diset ke " .. n, "#50C864") end
    end,
})
cRec:Toggle({
    Title = "Log paket masuk dari server (console)", Desc = "Untuk mencari sinyal gigitan; maks 60 baris", id = "fs_in",
    Callback = function(v) inOn = v; if v then inCount = 0 end end,
})

local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })

task.spawn(function()
    while W.Alive do
        task.wait(0.5)
        pcall(function()
            local txt = "Status: " .. Stats.status ..
                "\nLempar: " .. Stats.casts .. "   Tarik: " .. Stats.pulls .. "   Slash: " .. Stats.hits ..
                "\nID tarikan: " .. tostring(PULL_ID) ..
                "\nLemparan direkam: " .. (learnedCast and string.format("%.1f, %.1f, %.1f", learnedCast[1], learnedCast[2], learnedCast[3]) or "belum (pakai contoh)") ..
                "\nRemote: " .. (remote and "ReliableRedEvent OK" or "TIDAK KETEMU") .. "   Error: " .. Stats.errors
            if recOn and #recLines > 0 then
                txt = txt .. "\n— rekaman terakhir —\n" .. table.concat(recLines, "\n")
            end
            stLbl:SetText(txt)
        end)
    end
end)

W:OnUnload(function()
    recOn, inOn = false, false
    for k in pairs(runId) do runId[k] += 1 end
end)

-- Player dan Home (+ Settings) ada di ui.lua; tiap bagian aman dari error.
for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildHome({ Game = "Fishing Slayer", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[KatssinnnHub] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()
W:OnBooted(function() N("KatssinnnHub", "Fishing Slayer dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4) end)
