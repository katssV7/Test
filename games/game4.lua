-- KatssinnnHub | Game 4 (Auto Fishing - Instant)
-- UI / library sama dengan game 3 (ui.lua).
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

-- ===== LOOP (bisa dibatalkan) =====
local runId = { fish = 0, collect = 0 }
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

-- ===== PENGATURAN (diisi slider) =====
local POWER      = 99      -- kekuatan lemparan
local HOLD_TIME  = 0.35    -- lama menahan (ancang-ancang) sebelum dilepas
local BITE_WAIT  = 1.0     -- tunggu sampai ikan nyangkut (tanda di atas kepala)
local CATCH_WAIT = 0.15    -- jeda setelah tanda muncul sebelum catch
local CYCLE_WAIT = 0.5     -- jeda antar siklus
local COLLECT_EVERY = 3    -- detik, auto ambil ke tas
local SHOW_MARK  = true    -- kirim tanda "!" di atas kepala
local COLLECT_AFTER = true -- ambil ke tas setiap selesai catch
local DIRECTION  = "Menghadap karakter"

local Stats = { casts = 0, catches = 0, bag = 0, status = "idle" }

-- ===== ROD / REMOTE =====
-- Nama rod bisa beda ("Starter Rod", dll). Cari tool yang punya Mechanics.Remotes.
local function RodFrom(container)
    if not container then return nil end
    for _, t in ipairs(container:GetChildren()) do
        if t:IsA("Tool") then
            local m = t:FindFirstChild("Mechanics")
            local r = m and m:FindFirstChild("Remotes")
            if r then return t, r end
        end
    end
end

local function GetRod()
    local t, r = RodFrom(LP.Character)
    if t then return t, r end
    -- belum dipegang: ambil dari backpack lalu equip
    local bt = RodFrom(LP:FindFirstChildOfClass("Backpack"))
    if bt then
        pcall(function()
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(bt) end
        end)
        task.wait(0.3)
        return RodFrom(LP.Character)
    end
end

local function Remote(rodRemotes, name)
    local r = rodRemotes and rodRemotes:FindFirstChild(name)
    if r then return r end
    return rodRemotes and rodRemotes:WaitForChild(name, 3)
end

local function Dir()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local look = Vector3.new(0, 0, 1)
    if DIRECTION == "Arah kamera" then
        local cam = workspace.CurrentCamera
        if cam then look = cam.CFrame.LookVector end
    elseif hrp then
        look = hrp.CFrame.LookVector
    end
    local x, z = look.X, look.Z
    local m = math.sqrt(x * x + z * z)
    if m < 1e-4 then x, z, m = 0, 1, 1 end
    x, z = x / m, z / m
    local ok, v = pcall(function() return vector.create(x, 0, z) end)   -- tipe vector seperti remote asli
    if ok and v then return v end
    return Vector3.new(x, 0, z)
end

local function BiteMark()
    local r = RS:FindFirstChild("TandaSeruBersama")
    if not r then return end
    local blue = Color3.new(0.3333333432674408, 0.6352941393852234, 1)
    local dark = Color3.new(0.0784313753247261, 0.0784313753247261, 0.0784313753247261)
    r:FireServer(blue, dark, ColorSequence.new({ ColorSequenceKeypoint.new(0, blue), ColorSequenceKeypoint.new(1, blue) }), 1.5)
end

local function CollectAll()
    local ok, res = pcall(function()
        local rem = RS:WaitForChild("Remote", 3):WaitForChild("Inventaris", 3):WaitForChild("AmbilSemua", 3)
        return rem:InvokeServer()
    end)
    if ok then Stats.bag += 1 end
    return ok
end

-- satu siklus instant fishing
local function Sleep(t, id)           -- tidur yang bisa dibatalkan
    local el = 0
    while el < t do
        if id and runId.fish ~= id then return false end
        el += task.wait(0.05)
    end
    return not (id and runId.fish ~= id)
end

local function FishOnce(id)
    local rod, remotes = GetRod()
    if not rod then Stats.status = "rod tidak ditemukan"; task.wait(2) return false end
    local cast, mini = Remote(remotes, "CastEvent"), Remote(remotes, "MiniGame")
    if not cast or not mini then Stats.status = "remote rod tidak ada"; task.wait(2) return false end

    Stats.status = "hold"
    cast:FireServer(true)                                   -- ancang-ancang / hold
    if id and not Sleep(HOLD_TIME, id) then return false end
    Stats.status = "lempar"
    cast:FireServer(false, POWER, Dir())                    -- lepas -> lempar
    Stats.casts += 1
    if id and not Sleep(BITE_WAIT, id) then return false end
    Stats.status = "ikan nyangkut"
    if SHOW_MARK then BiteMark() end                        -- tanda di atas kepala
    if id and not Sleep(CATCH_WAIT, id) then return false end
    mini:FireServer(true)                                   -- catch langsung
    Stats.catches += 1
    Stats.status = "catch"
    if COLLECT_AFTER then CollectAll() end                  -- masuk tas & bersihkan
    return true
end

-- ===== UI =====
local HomePage = W:AddPage({ Name = "Home", Icon = "⌂" })
local Main = W:AddPage({ Name = "Main", Icon = "▣" })

local function OnOff(name, v)
    N(name, v and "ON" or "OFF", v and "#50C864" or "#DC3232")
end

-- ---------- kolom 1 ----------
local cFish = Main:AddCard({ Title = "Instant Fishing", Icon = "◆", Column = 1 })
local tog_fish = cFish:Toggle({
    Title = "Auto Instant Fishing", id = "auto_fish",
    Callback = function(v)
        Loop("fish", v, function() return CYCLE_WAIT end, FishOnce)
        if not v then Stats.status = "idle" end
        OnOff("Auto Instant Fishing", v)
    end,
})
cFish:Slider({ Title = "Cast Power", Min = 1, Max = 100, Value = 99, id = "fish_power", Callback = function(v) POWER = v end })
cFish:Slider({ Title = "Hold Time (s)", Min = 0, Max = 2, Value = 0.35, Rounding = 2, id = "fish_hold", Callback = function(v) HOLD_TIME = v end })
cFish:Slider({ Title = "Bite Wait (s)", Min = 0, Max = 5, Value = 1.0, Rounding = 2, id = "fish_bite", Callback = function(v) BITE_WAIT = v end })
cFish:Slider({ Title = "Catch Delay (s)", Min = 0, Max = 2, Value = 0.15, Rounding = 2, id = "fish_catch", Callback = function(v) CATCH_WAIT = v end })
cFish:Slider({ Title = "Cycle Delay (s)", Min = 0, Max = 5, Value = 0.5, Rounding = 2, id = "fish_cycle", Callback = function(v) CYCLE_WAIT = v end })

local cOpt = Main:AddCard({ Title = "Options", Icon = "★", Column = 1 })
cOpt:Dropdown({ Title = "Cast Direction", List = { "Menghadap karakter", "Arah kamera" }, Value = "Menghadap karakter", id = "fish_dir",
    Callback = function(v) DIRECTION = v or "Menghadap karakter" end })
cOpt:Toggle({ Title = "Send Bite Mark (!)", Value = true, id = "fish_mark", Callback = function(v) SHOW_MARK = v end })
cOpt:Toggle({ Title = "Collect After Each Catch", Value = true, id = "fish_collect_after", Callback = function(v) COLLECT_AFTER = v end })

-- ---------- kolom 2 ----------
local cBag = Main:AddCard({ Title = "Bag", Icon = "▣", Column = 2 })
local tog_collect = cBag:Toggle({
    Title = "Auto Collect to Bag", id = "auto_collect",
    Callback = function(v)
        Loop("collect", v, function() return COLLECT_EVERY end, CollectAll)
        OnOff("Auto Collect to Bag", v)
    end,
})
cBag:Slider({ Title = "Collect Interval (s)", Min = 1, Max = 60, Value = 3, id = "collect_delay", Callback = function(v) COLLECT_EVERY = v end })
cBag:Button({ Text = "Collect Now", Callback = function()
    local ok = CollectAll()
    N("Bag", ok and "Semua masuk tas" or "Gagal (remote tidak ditemukan)", ok and "#50C864" or "#DC3232")
end })

local cCtl = Main:AddCard({ Title = "Controls", Icon = "◉", Column = 2 })
cCtl:Buttons({ Buttons = {
    { Text = "All ON",  Callback = function() tog_fish:Set(true); tog_collect:Set(true) end },
    { Text = "All OFF", Callback = function() tog_fish:Set(false); tog_collect:Set(false) end },
} })
cCtl:Button({ Text = "Cast Once", Callback = function()
    task.spawn(function()
        local ok = pcall(FishOnce, nil)
        N("Cast", ok and "Satu siklus dikirim" or "Gagal", ok and "#50C864" or "#DC3232")
    end)
end })

local cStat = Main:AddCard({ Title = "Status", Icon = "◔", Column = 2 })
local stLbl = cStat:Label({ Text = "-" })
task.spawn(function()
    while W.Alive do
        task.wait(1)
        pcall(function()
            local rod = RodFrom(LP.Character)
            stLbl:SetText("Rod: " .. (rod and rod.Name or "-") .. "\nStatus: " .. Stats.status ..
                "\nCast: " .. Stats.casts .. "   Catch: " .. Stats.catches .. "   Tas: " .. Stats.bag)
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
