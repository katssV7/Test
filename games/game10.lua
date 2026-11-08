-- KatssinnnHub | Game 10 (Mountain Senandi)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Auto Fishing (remote FishingSystem):
--   1. CastReplication(origin, arah, namaRod, power)   -> lempar pancingan
--   2. tunggu ikan naik
--   3. CleanupCast()                                     -> tarik / bersihkan lemparan
--   4. FishGiver({ hookPosition, powerPercent })         -> ambil ikan
-- Posisi kail dihitung otomatis (raycast ke air di depan karakter); Remote Recorder bisa mempelajari nilai asli dari aksi manualmu.
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "Mountain Senandi",
    Folder    = "KatssinnnHub/MountainSenandi",
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
local function Sleep(key, id, t)               -- tidur yang bisa dibatalkan; false kalau loop dibatalkan
    local el = 0
    while el < t do
        if runId[key] ~= id then return false end
        el += task.wait(math.min(0.05, t - el + 0.001))
    end
    return runId[key] == id
end

-- ===== PENGATURAN =====
local ROD_NAME     = "Gold Rod"
local USE_HELD_ROD = true      -- pakai nama tool yang sedang dipegang kalau namanya mengandung "Rod"
local CAST_POWER   = 100
local FISH_POWER   = 0         -- powerPercent di FishGiver (contohmu 0)
local WAIT_FISH    = 0.1         -- detik menunggu ikan naik sebelum CleanupCast
local WAIT_JITTER  = 0         -- acak +/- detik
local CAST_GAP     = 0.1       -- jeda sebelum lempar lagi
local USE_BITE     = false      -- tunggu sinyal gigitan asli (FishingGui.Fishing muncul), bukan waktu tetap
local BITE_TIMEOUT = 25        -- batas tunggu gigitan sebelum dianggap gagal
local PULL_TIME    = 0.1       -- lama "tarik ikan" setelah gigit sebelum CleanupCast (log asli 2.1-3.6s)
local PULL_JITTER  = 0
local DIR_POWER    = 25        -- panjang vektor arah horizontal (contohmu ~25)
local DIR_Y        = 5         -- komponen Y arah (contohmu 5)
local HOOK_FRAC    = 0.375     -- kail jatuh sejauh DIR * HOOK_FRAC dari karakter (dari contohmu: ~9.4 stud)
local HOOK_DROP    = -11       -- cadangan kalau raycast ke air gagal: kail sekian stud di bawah titik lempar
local USE_LEARNED  = true      -- pakai nilai hasil rekaman (arah / offset kail / rod / power)

local Stats = { status = "idle", casts = 0, fish = 0, errors = 0 }

-- ===== REMOTE =====
local fsFolder = RS:FindFirstChild("FishingSystem") or RS:WaitForChild("FishingSystem", 10)
local function Rem(name) return fsFolder and (fsFolder:FindFirstChild(name) or fsFolder:WaitForChild(name, 5)) end
local rCast, rClean, rGive = Rem("CastReplication"), Rem("CleanupCast"), Rem("FishGiver")

-- ===== HELPER =====
local function Vec(x, y, z)
    if typeof(vector) == "table" and vector.create then return vector.create(x, y, z) end
    return Vector3.new(x, y, z)
end
local function Comp(v)
    local ok, x, y, z = pcall(function()
        if typeof(v) == "Vector3" then return v.X, v.Y, v.Z end
        return v.x, v.y, v.z
    end)
    if ok then return x, y, z end
end
local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function Rand(a, b) return a + math.random() * (b - a) end

local function RodName()
    if USE_HELD_ROD then
        local c = LP.Character
        local tool = c and c:FindFirstChildOfClass("Tool")
        if tool and tool.Name:lower():find("rod") then return tool.Name end
    end
    return ROD_NAME
end

-- hitung origin, arah, dan posisi kail dari posisi & arah hadap karakter
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false              -- permukaan air ikut terdeteksi

local function CastData()
    local hrp = Root()
    if not hrp then return nil end
    local p = hrp.Position
    local look = hrp.CFrame.LookVector
    local h = Vector3.new(look.X, 0, look.Z)
    h = h.Magnitude > 0.01 and h.Unit or Vector3.new(0, 0, -1)
    local dx, dz = h.X * DIR_POWER, h.Z * DIR_POWER

    local hx, hz = p.X + dx * HOOK_FRAC, p.Z + dz * HOOK_FRAC
    local hy = p.Y + HOOK_DROP
    rayParams.FilterDescendantsInstances = { LP.Character }
    local hit = workspace:Raycast(Vector3.new(hx, p.Y + 50, hz), Vector3.new(0, -400, 0), rayParams)
    if hit then hy = hit.Position.Y end

    return {
        origin = Vec(p.X, p.Y, p.Z),
        dir = Vec(dx, DIR_Y, dz),
        hook = Vec(hx, hy, hz),
    }
end

-- ===== AKSI =====
local USE_TAP = true
local function PressTap()
    local pg = LP:FindFirstChild("PlayerGui")
    local g = pg and pg:FindFirstChild("FishingGui")
    local b = g and g:FindFirstChild("TapMobile")
    if not (b and firesignal) then return false end
    local any = false
    for _, sig in ipairs({ "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "Activated" }) do
        local ok = pcall(function() firesignal(b[sig]) end)
        any = any or ok
    end
    return any
end
local lastData
local function Cast()
    if USE_TAP and PressTap() then
        lastData = CastData()
        Stats.casts += 1
        return true
    end
    if not rCast then Stats.errors += 1; return false end
    local d = CastData()
    if not d then return false end
    lastData = d
    local ok = pcall(rCast.FireServer, rCast, d.origin, d.dir, RodName(), CAST_POWER)
    if ok then Stats.casts += 1 else Stats.errors += 1 end
    return ok
end
local function Cleanup()
    if not rClean then Stats.errors += 1; return false end
    local ok = pcall(rClean.FireServer, rClean)          -- tanpa argumen, seperti contohmu
    if not ok then Stats.errors += 1 end
    return ok
end
local function GiveFish()
    if not rGive then Stats.errors += 1; return false end
    local d = lastData or CastData()
    if not d then return false end
    local ok = pcall(function()
        rGive:FireServer({ hookPosition = d.hook, powerPercent = FISH_POWER })
    end)
    if ok then Stats.fish += 1 else Stats.errors += 1 end
    return ok
end

local function BiteShown()
    local pg = LP:FindFirstChild("PlayerGui")
    local g = pg and pg:FindFirstChild("FishingGui")
    local f = g and g:FindFirstChild("Fishing")
    if not f then return false end
    local on = true
    pcall(function() on = (g.Enabled ~= false) and f.Visible end)
    return on
end

-- tutup paksa minigame tap (Fishing frame) supaya tidak perlu 12/12
local MG
local function CloseMinigame()
    pcall(function()
        if not MG then
            local m = RS:FindFirstChild("FishingSystem") and RS.FishingSystem:FindFirstChild("FishingModules")
            m = m and m:FindFirstChild("MinigameSystem")
            if m then MG = require(m) end
        end
        if MG then
            if MG.ForceStop then MG:ForceStop() end
        end
    end)
    pcall(function()
        local g = LP.PlayerGui:FindFirstChild("FishingGui")
        if not g then return end
        local f = g:FindFirstChild("Fishing")
        if f then f.Visible = false end
        local tm = g:FindFirstChild("TapMobile")
        if tm then tm.Visible = false end
    end)
end

-- kembalikan pose ke awal (stop animasi narik, equip ulang rod)
local AC
local function ResetPose()
    pcall(function()
        local c = LP.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local an = hum:FindFirstChildOfClass("Animator") or hum
        for _, t in ipairs(an:GetPlayingAnimationTracks()) do
            local n = t.Name
            if n == "PullingAnimation" or n == "WaitingAnimation" then t:Stop(0.1) end
        end
        if not AC then
            local m = RS:FindFirstChild("FishingSystem") and RS.FishingSystem:FindFirstChild("FishingModules")
            m = m and m:FindFirstChild("AnimationController")
            if m then AC = require(m) end
        end
        if AC and AC.Play then AC:Play("EquippedAnimation", 0.1) end
        local tool = c:FindFirstChildOfClass("Tool")
        if tool then
            hum:UnequipTools()
            task.wait(0.1)
            if tool.Parent then hum:EquipTool(tool) end
        end
    end)
end

-- satu siklus: lempar -> tunggu -> CleanupCast -> FishGiver -> jeda
local function FishCycle(id)
    if not (rCast and rClean and rGive) then
        Stats.status = "remote FishingSystem tidak lengkap"
        Sleep("fish", id, 1)
        return
    end
    if not Root() then Stats.status = "menunggu karakter"; Sleep("fish", id, 1); return end

    Stats.status = "melempar (" .. RodName() .. ")"
    if not Cast() then Sleep("fish", id, 1); return end

    local hasGui = USE_BITE and LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("FishingGui")
    if hasGui then
        Stats.status = "menunggu gigitan"
        local t0 = os.clock()
        while not BiteShown() do
            if os.clock() - t0 > BITE_TIMEOUT then
                Stats.status = "gigitan tidak muncul, ulang"
                Cleanup()
                CloseMinigame()
                ResetPose()
                Sleep("fish", id, CAST_GAP)
                return
            end
            if not Sleep("fish", id, 0.05) then return end
        end
        local w = math.max(0.1, PULL_TIME + Rand(-PULL_JITTER, PULL_JITTER))
        Stats.status = string.format("tarik ikan (%.1fs)", w)
        if not Sleep("fish", id, w) then return end
    else
        local w = math.max(0.1, WAIT_FISH + Rand(-WAIT_JITTER, WAIT_JITTER))
        Stats.status = string.format("menunggu ikan naik (%.1fs)", w)
        if not Sleep("fish", id, w) then return end
    end

    Stats.status = "CleanupCast"
    Cleanup()
    if not Sleep("fish", id, 0.1) then return end

    Stats.status = "FishGiver"
    GiveFish()
    CloseMinigame()
    task.delay(0.1, function() CloseMinigame(); ResetPose() end)
    Stats.status = "ikan diambil, jeda"
    Sleep("fish", id, CAST_GAP)
end

-- ===== REMOTE RECORDER (pelajari nilai asli dari aksi manualmu) =====
local recOn, oldNc, recLines = false, nil, {}
local learned = {}                             -- origin, dir, rod, power, hookFrac, hookDrop
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
        for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. Fmt(x, d + 1) end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function Learn(name, a1, a2, a3, a4)
    if name == "CastReplication" then
        local ox, oy, oz = Comp(a1)
        local dx, dy, dz = Comp(a2)
        if ox and dx then
            learned.origin, learned.dir = { ox, oy, oz }, { dx, dy, dz }
            if USE_LEARNED then
                DIR_POWER = math.sqrt(dx * dx + dz * dz)
                DIR_Y = dy
            end
        end
        if type(a3) == "string" and USE_LEARNED then ROD_NAME = a3 end
        if type(a4) == "number" and USE_LEARNED then CAST_POWER = a4 end
    elseif name == "FishGiver" and type(a1) == "table" then
        local hx, hy, hz = Comp(a1.hookPosition)
        local o, d = learned.origin, learned.dir
        if hx and o and d then
            local dist = math.sqrt((hx - o[1]) ^ 2 + (hz - o[3]) ^ 2)
            local dlen = math.sqrt(d[1] ^ 2 + d[3] ^ 2)
            if dlen > 0.01 and USE_LEARNED then
                HOOK_FRAC = dist / dlen
                HOOK_DROP = hy - o[2]
            end
        end
        if type(a1.powerPercent) == "number" and USE_LEARNED then FISH_POWER = a1.powerPercent end
    end
end

local function InstallHook()
    if oldNc then return true end
    if not (hookmetamethod and getnamecallmethod) then return false end
    local wrap = newcclosure or function(f) return f end
    oldNc = hookmetamethod(game, "__namecall", wrap(function(self, ...)
        if recOn and typeof(self) == "Instance" and self.Parent == fsFolder and not (checkcaller and checkcaller())
            and getnamecallmethod() == "FireServer" then
            local a1, a2, a3, a4 = ...
            local nm = self.Name
            task.spawn(function()
                pcall(Learn, nm, a1, a2, a3, a4)
                local line = nm .. "(" .. Fmt(a1) .. (a2 ~= nil and (", " .. Fmt(a2)) or "") ..
                    (a3 ~= nil and (", " .. Fmt(a3)) or "") .. (a4 ~= nil and (", " .. Fmt(a4)) or "") .. ")"
                print("[Rec] " .. line)
                recLines[#recLines + 1] = line
                if #recLines > 4 then table.remove(recLines, 1) end
            end)
        end
        return oldNc(self, ...)
    end))
    return true
end

-- log paket masuk dari server (cari sinyal "ikan menggigit")
local inOn, inCount = false, 0
if fsFolder then
    for _, r in ipairs(fsFolder:GetChildren()) do
        if r:IsA("RemoteEvent") then
            pcall(function()
                r.OnClientEvent:Connect(function(...)
                    if not inOn then return end
                    inCount += 1
                    if inCount > 60 then return end
                    print("[Masuk] " .. r.Name .. "(" .. Fmt({ ... }) .. ")")
                end)
            end)
        end
    end
end

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "fish" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

-- ---------- Auto Fishing ----------
local cFish = Main:AddCard({ Title = "Auto Fishing", Icon = "fish", Column = 1 })
local tgFish = cFish:Toggle({
    Title = "Auto Fishing", Desc = "CastReplication -> CleanupCast -> FishGiver, berulang", id = "ms_auto",
    Callback = function(v)
        Loop("fish", v, function() return 0.05 end, FishCycle)
        if not v then Stats.status = "idle" end
        N("Auto Fishing", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

-- ---------- Rod & Arah ----------
local cRod = Main:AddCard({ Title = "Rod & Arah Lempar", Icon = "pickaxe", Column = 1 })
cRod:Input({
    Title = "Nama rod", Value = ROD_NAME, Placeholder = "Gold Rod", ButtonText = "Set", id = "ms_rod",
    Callback = function(v)
        v = tostring(v or "")
        if v ~= "" then ROD_NAME = v end
    end,
    OnButton = function(v)
        v = tostring(v or "")
        if v ~= "" then ROD_NAME = v; N("Rod", "Diset: " .. v, "#50C864") end
    end,
})
cRod:Toggle({
    Title = "Pakai rod yang sedang dipegang", Desc = "Kalau tool-nya bernama '...Rod'", Value = true, id = "ms_held",
    Callback = function(v) USE_HELD_ROD = v end,
})

cRod:Toggle({
    Title = "Lempar via TapMobile (sinyal)", Desc = "Pencet FishingGui.TapMobile lewat sinyal; mati = pakai remote", Value = true, id = "ms_tap",
    Callback = function(v) USE_TAP = v end,
})

-- ---------- Manual ----------
local cMan = Main:AddCard({ Title = "Manual", Icon = "pointer", Column = 2 })
cMan:Button({
    Title = "Lempar sekali", Text = "Lempar sekali (CastReplication)",
    Callback = function()
        local ok = Cast()
        N("Lempar", ok and "Terkirim" or "Gagal (remote / karakter?)", ok and "#6495ED" or "#DC3232")
    end,
})
cMan:Button({
    Title = "Tarik sekali", Text = "CleanupCast + FishGiver sekali",
    Callback = function()
        Cleanup()
        task.wait(0.15)
        local ok = GiveFish()
        N("Tarik", ok and "Terkirim" or "Gagal", ok and "#6495ED" or "#DC3232")
    end,
})

-- ---------- Rekam / Debug ----------
local cRec = Main:AddCard({ Title = "Rekam (belajar dari aksi manual)", Icon = "scan", Column = 2 })
cRec:Toggle({
    Title = "Remote Recorder", Desc = "Aktifkan, lalu memancing MANUAL sekali", id = "ms_rec",
    Callback = function(v)
        if v and not InstallHook() then
            N("Remote Recorder", "Executor tidak mendukung hookmetamethod", "#DC3232", 5)
            return
        end
        recOn = v
        if v then N("Remote Recorder", "ON — memancing manual sekali", "#50C864", 4) end
    end,
})
cRec:Toggle({
    Title = "Pakai nilai hasil rekaman", Desc = "Rod, power, arah, dan posisi kail ikut rekaman", Value = true, id = "ms_learn",
    Callback = function(v) USE_LEARNED = v end,
})
cRec:Toggle({
    Title = "Log paket masuk dari server (console)", Desc = "Cari sinyal ikan menggigit; maks 60 baris", id = "ms_in",
    Callback = function(v) inOn = v; if v then inCount = 0 end end,
})

local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })

task.spawn(function()
    while W.Alive do
        task.wait(0.5)
        pcall(function()
            local txt = "Status: " .. Stats.status ..
                "\nLempar: " .. Stats.casts .. "   FishGiver: " .. Stats.fish .. "   Error: " .. Stats.errors ..
                "\nRod: " .. RodName() .. "   Power: " .. CAST_POWER ..
                "\nRemote: " .. (rCast and "Cast " or "Cast? ") .. (rClean and "Clean " or "Clean? ") .. (rGive and "Give" or "Give?")
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
    function() W:BuildHome({ Game = "Mountain Senandi", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[KatssinnnHub] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()
W:OnBooted(function() N("KatssinnnHub", "Mountain Senandi dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4) end)
