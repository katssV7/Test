-- KatssinnnHub | Game 9 (Fishing Slayer)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Auto Fishing (input simulasi, bukan remote):
--   1. Tahan layar ~1 detik  -> melempar pancingan
--   2. Tunggu PlayerGui.CatchScreen muncul (ikan menggigit)
--   3. Tap layar berulang sampai CatchScreen hilang  -> ikan tertangkap
--   4. Ulangi
-- Tap dikirim lewat VirtualInputManager (sinyal input virtual): jari/layarmu tidak dipakai.
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

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

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
local HOLD         = 1.0      -- detik menahan layar untuk melempar
local BITE_TIMEOUT = 30       -- detik maks menunggu CatchScreen muncul sebelum lempar ulang
local PULL_TIMEOUT = 40       -- detik maks menarik sebelum menyerah
local TAP_GAP      = 0.12     -- jeda antar tap saat menarik
local CAST_GAP     = 1.0      -- jeda setelah ikan tertangkap sebelum lempar lagi
local TAP_X, TAP_Y = 0.5, 0.5 -- posisi tap (fraksi layar, 0..1)
local INPUT_MODE   = "Mouse"  -- "Mouse" atau "Touch"
local DETECT_MODE  = "Elemen terlihat"   -- atau "Enabled saja"

local Stats = { status = "idle", casts = 0, taps = 0, caught = 0, timeouts = 0, errors = 0 }

-- ===== INPUT VIRTUAL =====
local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local function TapPos()
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize or Vector2.new(1000, 500)
    return vs.X * TAP_X, vs.Y * TAP_Y
end

local function InputDown(x, y)
    if not VIM then Stats.errors += 1; return false end
    local ok
    if INPUT_MODE == "Touch" then
        ok = pcall(function() VIM:SendTouchEvent(1, 0, x, y) end)           -- 0 = Begin
    else
        ok = pcall(function() VIM:SendMouseButtonEvent(x, y, 0, true, game, 0) end)
    end
    if not ok then Stats.errors += 1 end
    return ok
end
local function InputUp(x, y)
    if not VIM then return false end
    local ok
    if INPUT_MODE == "Touch" then
        ok = pcall(function() VIM:SendTouchEvent(1, 2, x, y) end)           -- 2 = End
    else
        ok = pcall(function() VIM:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
    end
    if not ok then Stats.errors += 1 end
    return ok
end

-- ===== DETEKSI CatchScreen (PlayerGui.CatchScreen) =====
local function AncestorsVisible(d, root)
    local p = d.Parent
    while p and p ~= root do
        if p:IsA("GuiObject") and not p.Visible then return false end
        p = p.Parent
    end
    return true
end
local function CatchShown()
    local g = PG:FindFirstChild("CatchScreen")
    if not g then return false end
    if g:IsA("ScreenGui") and not g.Enabled then return false end
    if DETECT_MODE == "Enabled saja" then return true end
    for _, d in ipairs(g:GetDescendants()) do
        if d:IsA("GuiObject") and d.Visible and d.AbsoluteSize.X > 0 and d.AbsoluteSize.Y > 0 and AncestorsVisible(d, g) then
            return true
        end
    end
    return false
end

-- ===== AKSI =====
local function HoldCast(id)                    -- tahan layar HOLD detik
    local x, y = TapPos()
    if not InputDown(x, y) then return false end
    local alive = (id == nil) and (task.wait(HOLD) and true) or Sleep("fish", id, HOLD)
    InputUp(x, y)
    Stats.casts += 1
    return alive
end
local function Tap()
    local x, y = TapPos()
    InputDown(x, y)
    task.wait(0.03)
    InputUp(x, y)
    Stats.taps += 1
end

-- satu siklus: lempar -> tunggu CatchScreen muncul -> tap sampai hilang -> jeda
local function FishCycle(id)
    if not VIM then Stats.status = "VirtualInputManager tidak tersedia"; Sleep("fish", id, 1); return end

    -- kalau CatchScreen sudah tampil (misal baru dihidupkan saat ikan menggigit), langsung tarik
    if not CatchShown() then
        Stats.status = string.format("melempar (tahan %.1fs)", HOLD)
        if not HoldCast(id) then return end

        Stats.status = "menunggu CatchScreen..."
        local t = 0
        while not CatchShown() do
            if not Sleep("fish", id, 0.1) then return end
            t += 0.1
            if t >= BITE_TIMEOUT then
                Stats.timeouts += 1
                Stats.status = "tidak ada gigitan, lempar ulang"
                return
            end
        end
    end

    Stats.status = "menarik ikan (tap sampai CatchScreen hilang)"
    local tt, done = 0, false
    while true do
        if runId.fish ~= id then return end
        if not CatchShown() then done = true; break end
        Tap()
        if not Sleep("fish", id, TAP_GAP) then return end
        tt += TAP_GAP + 0.03
        if tt >= PULL_TIMEOUT then break end
    end

    if done then
        Stats.caught += 1
        Stats.status = "ikan tertangkap, jeda"
    else
        Stats.status = "timeout menarik, ulangi"
    end
    Sleep("fish", id, CAST_GAP)
end

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "fish" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

-- ---------- Auto Fishing ----------
local cFish = Main:AddCard({ Title = "Auto Fishing", Icon = "fish", Column = 1 })
local tgFish = cFish:Toggle({
    Title = "Auto Fishing", Desc = "Tahan untuk lempar -> tunggu CatchScreen -> tap sampai hilang", id = "fs_auto", Expand = true,
    Callback = function(v)
        Loop("fish", v, function() return 0.05 end, FishCycle)
        if not v then Stats.status = "idle" end
        N("Auto Fishing", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgFish:Sub(function(c)
    c:Slider({
        Title = "Tahan layar untuk lempar (s)", Min = 0.3, Max = 3, Value = HOLD, Rounding = 1, Suffix = "s", id = "fs_hold",
        Callback = function(v) HOLD = v end,
    })
    c:Slider({
        Title = "Jeda antar tap saat menarik (s)", Min = 0.03, Max = 0.6, Value = TAP_GAP, Rounding = 2, Suffix = "s", id = "fs_tapgap",
        Callback = function(v) TAP_GAP = v end,
    })
    c:Slider({
        Title = "Jeda sebelum lempar lagi (s)", Min = 0.2, Max = 5, Value = CAST_GAP, Rounding = 1, Suffix = "s", id = "fs_castgap",
        Callback = function(v) CAST_GAP = v end,
    })
    c:Slider({
        Title = "Batas tunggu gigitan (s)", Min = 5, Max = 90, Value = BITE_TIMEOUT, Rounding = 0, Suffix = "s", id = "fs_bite",
        Callback = function(v) BITE_TIMEOUT = v end,
    })
    c:Slider({
        Title = "Batas waktu menarik (s)", Min = 10, Max = 120, Value = PULL_TIMEOUT, Rounding = 0, Suffix = "s", id = "fs_pull",
        Callback = function(v) PULL_TIMEOUT = v end,
    })
end)

-- ---------- Input & Deteksi ----------
local cIn = Main:AddCard({ Title = "Input & Deteksi", Icon = "pointer", Column = 1 })
cIn:Dropdown({
    Title = "Mode input", List = { "Mouse", "Touch" }, Value = INPUT_MODE, id = "fs_inmode",
    Callback = function(v) if v then INPUT_MODE = tostring(v) end end,
})
cIn:Dropdown({
    Title = "Deteksi CatchScreen", List = { "Elemen terlihat", "Enabled saja" }, Value = DETECT_MODE, id = "fs_detect",
    Callback = function(v) if v then DETECT_MODE = tostring(v) end end,
})
cIn:Slider({
    Title = "Posisi tap X (%)", Min = 5, Max = 95, Value = TAP_X * 100, Rounding = 0, Suffix = "%", id = "fs_tapx",
    Callback = function(v) TAP_X = v / 100 end,
})
cIn:Slider({
    Title = "Posisi tap Y (%)", Min = 5, Max = 95, Value = TAP_Y * 100, Rounding = 0, Suffix = "%", id = "fs_tapy",
    Callback = function(v) TAP_Y = v / 100 end,
})

-- ---------- Tes manual ----------
local cTest = Main:AddCard({ Title = "Tes", Icon = "scan", Column = 2 })
cTest:Button({
    Title = "Tes lempar (tahan)", Text = "Tes lempar (tahan layar)",
    Callback = function()
        task.spawn(function()
            local ok = VIM and HoldCast(nil)
            N("Tes lempar", ok and "Terkirim" or "Gagal (VirtualInputManager?)", ok and "#6495ED" or "#DC3232")
        end)
    end,
})
cTest:Button({
    Title = "Tes tap", Text = "Tes tap sekali",
    Callback = function()
        if not VIM then N("Tes tap", "VirtualInputManager tidak tersedia", "#DC3232"); return end
        Tap()
        N("Tes tap", "Terkirim", "#6495ED")
    end,
})
cTest:Button({
    Title = "Cek CatchScreen (print)", Text = "Cek CatchScreen (print ke console)",
    Callback = function()
        local g = PG:FindFirstChild("CatchScreen")
        if not g then
            print("[CatchScreen] tidak ada di PlayerGui")
            N("CatchScreen", "Tidak ada di PlayerGui", "#DC3232")
            return
        end
        print("[CatchScreen] " .. g.ClassName .. " | Enabled=" .. tostring(g:IsA("ScreenGui") and g.Enabled) .. " | terdeteksi tampil=" .. tostring(CatchShown()))
        for _, c in ipairs(g:GetChildren()) do
            if c:IsA("GuiObject") then
                print(string.format("    %s [%s] Visible=%s AbsSize=%dx%d", c.Name, c.ClassName, tostring(c.Visible), c.AbsoluteSize.X, c.AbsoluteSize.Y))
            else
                print("    " .. c.Name .. " [" .. c.ClassName .. "]")
            end
        end
        N("CatchScreen", "Tampil=" .. tostring(CatchShown()) .. " (detail di console F9)", "#6495ED", 4)
    end,
})

local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })

task.spawn(function()
    while W.Alive do
        task.wait(0.4)
        pcall(function()
            stLbl:SetText("Status: " .. Stats.status ..
                "\nCatchScreen: " .. (CatchShown() and "TAMPIL" or "tidak tampil") ..
                "\nLempar: " .. Stats.casts .. "   Tap: " .. Stats.taps .. "   Tertangkap: " .. Stats.caught ..
                "\nTimeout gigitan: " .. Stats.timeouts .. "   Error input: " .. Stats.errors ..
                "\nInput: " .. INPUT_MODE .. (VIM and "" or " (VIM TIDAK ADA)"))
        end)
    end
end)

W:OnUnload(function()
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
