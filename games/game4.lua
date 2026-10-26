-- KatssinnnHub | Game 4 (Auto Fishing)
-- UI / library sama dengan game 3 (ui.lua).
-- Siklus: Cast -> Minigame -> Cleanup -> FishGiver (berurutan, tiap langkah dicek).
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "Auto Fishing",
    Folder    = "KatssinnnHub/AutoFishing",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP      = Players.LocalPlayer

-- ===== LOOP (bisa dibatalkan, tidak pernah tumpang tindih) =====
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

-- ===== KECEPATAN =====
-- Speed 2 terbukti aman, speed 3+ (jeda dipotong merata) ada langkah yang kepotong terlalu pendek.
-- Jadi: langkah yang menentukan ikan masuk (cast & minigame) dikunci minimal di nilai aman speed 2,
-- sedangkan jeda yang tidak menentukan (cleanup & antar siklus) terus dipercepat sampai hampir 0.
-- Kalau mau menembus batas aman, isi kartu "Fine Tune" (0 = otomatis).
local SPEED = 6
local SLOW = { cast = 1.4, minigame = 2.2, cleanup = 0.30, cycle = 0.60 }   -- speed 1
local SAFE = { cast = 1.26, minigame = 1.98 }                                 -- batas aman (= speed 2)
local FAST = { cleanup = 0.04, cycle = 0.05 }                                 -- speed 10
local OVERRIDE = { cast = 0, minigame = 0, cleanup = 0, cycle = 0 }
local function D(key)
    if OVERRIDE[key] and OVERRIDE[key] > 0 then return OVERRIDE[key] end
    local t = (SPEED - 1) / 9                      -- 0..1
    if SAFE[key] then
        local k = math.min((SPEED - 1) / 1, 1)     -- speed 1 -> 2 turun ke batas aman, setelah itu tetap
        return SLOW[key] + (SAFE[key] - SLOW[key]) * k
    end
    return SLOW[key] + (FAST[key] - SLOW[key]) * t
end

local CAST_DIST   = 25     -- besar vektor arah lemparan (dari contoh: 25)
local CAST_POWER  = 64.99  -- angka ke-4 CastReplication
local HOOK_AHEAD  = 8.5    -- jarak kail jatuh di depan karakter
local HOOK_DROP   = 9.9    -- kail turun dari titik lempar ke air (cadangan kalau raycast gagal)

local Stats = { cycles = 0, fish = 0, errors = 0, status = "idle", t0 = os.clock() }

-- ===== REMOTE =====
local function V3(x, y, z)
    local ok, v = pcall(function() return vector.create(x, y, z) end)   -- tipe vector seperti remote asli
    if ok and v then return v end
    return Vector3.new(x, y, z)
end

local FS
local function Remote(name)
    if not (FS and FS.Parent) then
        FS = RS:FindFirstChild("FishingSystem") or RS:WaitForChild("FishingSystem", 5)
    end
    local r = FS and (FS:FindFirstChild(name) or FS:WaitForChild(name, 5))
    return r
end

local function Sleep(t, id)            -- tidur yang bisa dibatalkan
    local el = 0
    while el < t do
        if runId.fish ~= id then return false end
        el += task.wait(math.min(0.05, t - el + 0.001))
    end
    return runId.fish == id
end

local function RodName()
    local c = LP.Character
    if c then for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") then return t.Name end end end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then return t.Name end end end
    return "Basic Rod"
end

local function Root()
    local c = LP.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if hum and hrp and hum.Health > 0 then return hrp end
end

-- titik lempar, arah, dan titik kail jatuh (dihitung dari posisi karakter sekarang)
local function CastInfo(hrp)
    local look = hrp.CFrame.LookVector
    local x, z = look.X, look.Z
    local m = math.sqrt(x * x + z * z)
    if m < 1e-4 then x, z, m = 0, 1, 1 end
    x, z = x / m, z / m
    local start = hrp.Position + Vector3.new(x * 1.5, 4, z * 1.5)
    local hx, hz = start.X + x * HOOK_AHEAD, start.Z + z * HOOK_AHEAD
    local hy = start.Y - HOOK_DROP
    pcall(function()          -- cari permukaan air / tanah di titik jatuh
        local rp = RaycastParams.new()
        rp.IgnoreWater = false
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = { LP.Character }
        local hit = workspace:Raycast(Vector3.new(hx, start.Y + 20, hz), Vector3.new(0, -80, 0), rp)
        if hit then hy = hit.Position.Y end
    end)
    return start, V3(x * CAST_DIST, 5, z * CAST_DIST), V3(hx, hy, hz), V3(start.X, start.Y, start.Z)
end

-- satu siklus penuh. Mengembalikan true kalau selesai, false kalau dibatalkan / gagal.
local function FishOnce(id)
    local hrp = Root()
    if not hrp then Stats.status = "menunggu karakter"; Sleep(1, id) return false end

    local rCast, rMini, rClean, rGive =
        Remote("CastReplication"), Remote("MinigameStarted"), Remote("CleanupCast"), Remote("FishGiver")
    if not (rCast and rMini and rClean and rGive) then
        Stats.status = "remote FishingSystem tidak lengkap"; Stats.errors += 1; Sleep(2, id) return false
    end

    local _, dir, hook, startV = CastInfo(hrp)
    local payload = { hookPosition = hook, power = 0 }

    Stats.status = "1/4 cast"
    rCast:FireServer(startV, dir, RodName(), CAST_POWER)
    if not Sleep(D("cast"), id) then return false end

    Stats.status = "2/4 minigame"
    rMini:FireServer(payload)
    if not Sleep(D("minigame"), id) then return false end

    Stats.status = "3/4 cleanup"
    rClean:FireServer()
    if not Sleep(D("cleanup"), id) then return false end

    Stats.status = "4/4 fish giver"
    rGive:FireServer(payload)
    Stats.cycles += 1
    Stats.fish += 1
    Stats.status = "selesai"
    return true
end

-- bersihkan sisa cast lama sebelum mulai (supaya siklus pertama tidak nyangkut)
local function ResetCast()
    local r = Remote("CleanupCast")
    if r then pcall(function() r:FireServer() end) end
end

-- ===== UI =====
local HomePage = W:AddPage({ Name = "Home", Icon = "⌂" })
local Main = W:AddPage({ Name = "Main", Icon = "▣" })

local cFish = Main:AddCard({ Title = "Auto Fishing", Icon = "◆", Column = 1 })
cFish:Toggle({
    Title = "Auto Fishing", id = "auto_fish",
    Callback = function(v)
        if v then ResetCast() end
        Loop("fish", v, function() return D("cycle") end, FishOnce)
        if not v then Stats.status = "idle" end
        N("Auto Fishing", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cFish:Slider({ Title = "Fishing Speed", Min = 1, Max = 10, Value = 6, id = "fish_speed", Callback = function(v) SPEED = v end })
cFish:Label({ Text = "Cast → Minigame → Cleanup → Fish Giver. Speed 2 = aman; di atasnya hanya jeda cleanup/antar siklus yang dipercepat.", Size = 10 })

local cTune = Main:AddCard({ Title = "Fine Tune (0 = otomatis)", Icon = "⚙", Column = 1, Collapsed = true })
for _, e in ipairs({ { "cast", "Cast wait (s)" }, { "minigame", "Minigame wait (s)" }, { "cleanup", "Cleanup wait (s)" }, { "cycle", "Cycle gap (s)" } }) do
    cTune:Slider({ Title = e[2], Min = 0, Max = 3, Value = 0, Rounding = 2, id = "tune_" .. e[1], Callback = function(v) OVERRIDE[e[1]] = v end })
end

local cStat = Main:AddCard({ Title = "Status", Icon = "◔", Column = 2 })
local stLbl = cStat:Label({ Text = "-" })
task.spawn(function()
    while W.Alive do
        task.wait(1)
        pcall(function()
            local mins = math.max((os.clock() - Stats.t0) / 60, 0.01)
            stLbl:SetText("Status: " .. Stats.status .. "\nSiklus: " .. Stats.cycles .. "   Ikan: " .. Stats.fish ..
                "   Error: " .. Stats.errors .. "\nRod: " .. RodName() .. "   ~" .. string.format("%.1f", Stats.cycles / mins) .. "/menit")
        end)
    end
end)

-- hentikan semua loop saat Unload
W:OnUnload(function()
    for k in pairs(runId) do runId[k] += 1 end
end)

-- Home / Player / Settings (library): tiap bagian aman dari error
for _, step in ipairs({
    function() W:BuildHome({ Game = "Auto Fishing", Version = "v1.0" }, HomePage) end,
    function() W:BuildPlayer() end,
    function() W:BuildSettings() end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[KatssinnnHub] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()
N("KatssinnnHub", "Auto Fishing dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4)
