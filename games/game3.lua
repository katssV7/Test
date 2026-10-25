-- KatssinnnHub | Game 3 (My Anime Mine)
-- UI baru: sidebar Home / Main / Player / Settings, kartu dua kolom (library: ui.lua).
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "My Anime Mine",
    Folder    = "KatssinnnHub/MyAnimeMine",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local RS  = game:GetService("ReplicatedStorage")
local LP  = game:GetService("Players").LocalPlayer
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- ===== REMOTE =====
-- Semua aksi (equip, upgrade, chest, sell, code) lewat satu remote: Remotes.GamestateEvent
local GameEvent
local function Fire(...)
    if not (GameEvent and GameEvent.Parent) then
        local ok, r = pcall(function()
            return RS:WaitForChild("Remotes", 8):WaitForChild("GamestateEvent", 5)
        end)
        GameEvent = ok and r or nil
    end
    if GameEvent then GameEvent:FireServer(...) end
end

-- ===== DATA =====
local MAX_SLOT = 10                         -- jumlah slot anime (M1..M10). Naikkan kalau slot lebih banyak.
local STATS    = { "Damage", "Speed", "MineSpeed" }
local SLOTS    = {}
for i = 1, MAX_SLOT do SLOTS[i] = "M" .. i end

-- urutan = urutan tampil di dropdown
local ORES      = { "Amberite", "Silverdrop", "Tinvein", "Copperine", "Ochrite", "Coalite", "Bullionite", "Ironshard" }
local SELL_ALL  = { "Amberite", "Silverdrop", "Tinvein", "Copperine", "Ochrite", "Coalite" }
local CODES     = { "ONANDON", "FEASTS", "MOONRISE", "HALLOWKEEP" }

local PLOT_LIST = { "Auto (terdekat)", "Semua plot", "MinePlot1", "MinePlot2", "MinePlot3", "MinePlot4", "MinePlot5", "MinePlot6" }

-- ambil item terpilih sesuai urutan katalog (bukan urutan klik)
local function Ordered(catalog, v)
    local set = {}
    if type(v) == "table" then
        for _, x in ipairs(v) do set[x] = true end
    elseif v then
        set[v] = true
    end
    local out = {}
    for _, name in ipairs(catalog) do
        if set[name] then out[#out + 1] = name end
    end
    return out
end

-- ===== STATE =====
local MINE_DELAY    = 0.1
local CLICK_TP      = false
local PlotMode      = "Auto (terdekat)"
local CHEST_DELAY   = 1
local EQUIP_DELAY   = 5
local UP_DELAY      = 0.5
local SELL_DELAY    = 2
local UNLOCK_DELAY  = 2

local ddSlots, ddStats, ddSell
local LastMethod = "-"
local LastOreCount = 0

local runId = { mine = 0, chest = 0, equip = 0, upsel = 0, upall = 0, sellsel = 0, sellall = 0, unlock = 0 }

local function Loop(key, enabled, getDelay, fn)
    runId[key] += 1
    if not enabled then return end
    local id = runId[key]
    task.spawn(function()
        while runId[key] == id do
            local ok, err = pcall(fn)
            if not ok then warn("[" .. key .. "] " .. tostring(err)) end
            task.wait(getDelay())
        end
    end)
end

local function HRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- ===== AKSI: remote =====
local function EquipBest() Fire("MineEquipBest") end
local function TakeChest() Fire("MineTakeChest") end

local function UpgradeSlots(slots, stats)
    for _, slot in ipairs(slots) do
        for _, stat in ipairs(stats) do
            Fire("MineUpgradeCharacter", slot, stat)
        end
    end
end

-- Server menolak upgrade yang coin-nya kurang, jadi slot yang masih murah (mis. M2)
-- tetap naik walau M1 belum mampu: semua slot terpilih dicoba tiap putaran.
local function UpgradeSelected()
    local slots = Ordered(SLOTS, ddSlots and ddSlots:GetValue())
    local stats = Ordered(STATS, ddStats and ddStats:GetValue())
    if #stats == 0 then stats = STATS end
    UpgradeSlots(slots, stats)
    return #slots
end

local function UpgradeAll()
    local stats = Ordered(STATS, ddStats and ddStats:GetValue())
    if #stats == 0 then stats = STATS end
    UpgradeSlots(SLOTS, stats)
end

local function SellSelected()
    local picked = Ordered(ORES, ddSell and ddSell:GetValue())
    for _, ore in ipairs(picked) do
        Fire("MineSellItems", { ore })      -- satuan: 1 item per panggilan
    end
    return #picked
end

local function SellAllOres()
    Fire("MineSellItems", SELL_ALL)         -- semua sekaligus
end

local function RedeemAll()
    for _, code in ipairs(CODES) do
        Fire("UseCode", code)
        task.wait(0.3)
    end
    return #CODES
end

-- ===== AKSI: klik (tanpa remote) =====
local function PosOf(inst)
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        local ok, cf = pcall(inst.GetPivot, inst)
        if ok then return cf.Position end
    end
    local bp = inst:FindFirstChildWhichIsA("BasePart", true)
    return bp and bp.Position
end

-- folder Nodes di semua MinePlot (workspace.MineWorld.Plots.MinePlotN.Nodes)
local function PlotFolders()
    local list = {}
    local mw = workspace:FindFirstChild("MineWorld")
    local plots = mw and mw:FindFirstChild("Plots")
    if not plots then return list end
    for _, plot in ipairs(plots:GetChildren()) do
        local nodes = plot:FindFirstChild("Nodes")
        if nodes then list[#list + 1] = { plot = plot, nodes = nodes } end
    end
    return list
end

local function GetOres()
    local folders = PlotFolders()
    local chosen = {}
    if PlotMode == "Semua plot" then
        chosen = folders
    elseif PlotMode == "Auto (terdekat)" then
        local hrp = HRP()
        local best, bestD
        for _, f in ipairs(folders) do
            local p = PosOf(f.plot)
            if p and hrp then
                local d = (hrp.Position - p).Magnitude
                if not bestD or d < bestD then best, bestD = f, d end
            end
        end
        if best then chosen = { best } end
    else
        for _, f in ipairs(folders) do
            if f.plot.Name == PlotMode then chosen = { f } break end
        end
    end
    local ores = {}
    for _, f in ipairs(chosen) do
        for _, o in ipairs(f.nodes:GetChildren()) do ores[#ores + 1] = o end
    end
    return ores
end

local OreCache = setmetatable({}, { __mode = "k" })
local function Methods(ore)
    local info = OreCache[ore]
    if info and (info.cd or info.pp) then return info end
    info = {
        cd = ore:FindFirstChildWhichIsA("ClickDetector", true),
        pp = ore:FindFirstChildWhichIsA("ProximityPrompt", true),
    }
    OreCache[ore] = info
    return info
end

local function ScreenClick(pos)
    if not (VIM and pos) then return false end
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local v, on = cam:WorldToViewportPoint(pos)
    if not on then return false end
    VIM:SendMouseButtonEvent(v.X, v.Y, 0, true, game, 0)
    VIM:SendMouseButtonEvent(v.X, v.Y, 0, false, game, 0)
    return true
end

-- urutan metode: ClickDetector > ProximityPrompt > klik layar
local function ClickOre(ore)
    local info = Methods(ore)
    local pos = PosOf(ore)
    if CLICK_TP and pos then
        local h = HRP()
        if h then h.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) end
    end
    if info.cd and fireclickdetector then
        fireclickdetector(info.cd)
        LastMethod = "ClickDetector"
    elseif info.pp and fireproximityprompt then
        fireproximityprompt(info.pp)
        LastMethod = "ProximityPrompt"
    elseif ScreenClick(pos) then
        LastMethod = "Klik layar"
    else
        LastMethod = "Gagal (ore di luar layar / tidak ada metode)"
    end
end

-- klik semua ore berurutan; kecepatan diatur MINE_DELAY
local function MineRound(id)
    local ores = GetOres()
    LastOreCount = #ores
    for _, ore in ipairs(ores) do
        if runId.mine ~= id then return end
        if ore.Parent then
            pcall(ClickOre, ore)
            task.wait(MINE_DELAY)
        end
    end
    if #ores == 0 then task.wait(0.3) end
end

-- ===== AKSI: unlock slot (prompt yang ditekan, bukan remote) =====
local function FindLockedPrompts()
    local list = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local obj = string.lower(d.ObjectText or "")
            local act = string.lower(d.ActionText or "")
            if obj:find("locked") or act == "unlock" then list[#list + 1] = d end
        end
    end
    return list
end

local function PromptPos(pp)
    local p = pp.Parent
    if p and p:IsA("Attachment") then return p.WorldPosition end
    return p and PosOf(p)
end

local function UnlockSlots()
    if not fireproximityprompt then return -1 end
    local prompts = FindLockedPrompts()
    if #prompts == 0 then return 0 end
    local hrp = HRP()
    local back = hrp and hrp.CFrame
    for _, pp in ipairs(prompts) do
        local pos = PromptPos(pp)
        local h = HRP()
        if pos and h and (h.Position - pos).Magnitude > math.max(pp.MaxActivationDistance - 2, 4) then
            h.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
            task.wait(0.25)
        end
        pcall(function()
            local hd = pp.HoldDuration
            pp.HoldDuration = 0
            fireproximityprompt(pp)
            pp.HoldDuration = hd
        end)
        task.wait(0.25)
    end
    local h = HRP()
    if h and back then h.CFrame = back end
    return #prompts
end


-- ===== UI =====
-- urutan sidebar: Home lalu Main. Isi Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage = W:AddPage({ Name = "Home", Icon = "house" })
local Main = W:AddPage({ Name = "Main", Icon = "gamepad-2" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

local function OnOff(name, v)
    N(name, v and "ON" or "OFF", v and "#50C864" or "#DC3232")
end

-- ---------- kolom 1 ----------
local cMine = Main:AddCard({ Title = "Mine", Icon = "pickaxe", Column = 1 })

local tog_mine = cMine:Toggle({
    Title = "Auto Mine", id = "auto_mine",
    Callback = function(v)
        runId.mine += 1
        if v then
            local id = runId.mine
            task.spawn(function()
                while runId.mine == id do
                    local ok, err = pcall(MineRound, id)
                    if not ok then warn("[mine] " .. tostring(err)); task.wait(0.5) end
                    task.wait()
                end
            end)
        end
        OnOff("Auto Mine", v)
    end,
})
cMine:Slider({
    Title = "Click speed (jeda detik)", Min = 0.01, Max = 1, Value = 0.1, Rounding = 2, Suffix = "s", id = "mine_delay",
    Callback = function(v) MINE_DELAY = v end,
})
cMine:Dropdown({
    Title = "Plot", List = PLOT_LIST, Value = "Auto (terdekat)", id = "mine_plot",
    Callback = function(v) if v then PlotMode = tostring(v) end end,
})
cMine:Toggle({
    Title = "Teleport ke ore", id = "mine_tp",
    Callback = function(v) CLICK_TP = v end,
})
cMine:Button({
    Text = "Cek ore",
    Callback = function()
        local ores = GetOres()
        local cd, pp, none = 0, 0, 0
        for _, o in ipairs(ores) do
            local m = Methods(o)
            if m.cd then cd += 1 elseif m.pp then pp += 1 else none += 1 end
        end
        N("Cek ore", #ores .. " ore | ClickDetector " .. cd .. " | Prompt " .. pp .. " | Layar " .. none, "#6495ED", 6)
    end,
})

local cUp = Main:AddCard({ Title = "Upgrade", Icon = "arrow-up", Column = 1 })
ddSlots = cUp:Dropdown({ Title = "Slot anime (M1 = urutan 1)", List = SLOTS, Value = { "M1" }, id = "up_slots" })
ddStats = cUp:Dropdown({ Title = "Stat (kosong = semua)", List = STATS, Value = { "Damage", "Speed", "MineSpeed" }, id = "up_stats" })
local tog_upsel = cUp:Toggle({
    Title = "Auto Upgrade Selected", id = "auto_up_sel",
    Callback = function(v)
        if v and #Ordered(SLOTS, ddSlots:Get()) == 0 then N("Auto Upgrade", "Belum ada slot yang dipilih", "#FFA500") end
        Loop("upsel", v, function() return UP_DELAY end, UpgradeSelected)
        OnOff("Auto Upgrade Selected", v)
    end,
})
local tog_upall = cUp:Toggle({
    Title = "Auto Upgrade All (M1-M" .. MAX_SLOT .. ")", id = "auto_up_all",
    Callback = function(v)
        Loop("upall", v, function() return UP_DELAY end, UpgradeAll)
        OnOff("Auto Upgrade All", v)
    end,
})
cUp:Slider({
    Title = "Upgrade delay", Min = 0.1, Max = 5, Value = 0.5, Rounding = 1, Suffix = "s", id = "up_delay",
    Callback = function(v) UP_DELAY = v end,
})

local cEq = Main:AddCard({ Title = "Equip", Icon = "star", Column = 1 })
local tog_equip = cEq:Toggle({
    Title = "Auto Equip Best", id = "auto_equip",
    Callback = function(v)
        Loop("equip", v, function() return EQUIP_DELAY end, EquipBest)
        OnOff("Auto Equip Best", v)
    end,
})
cEq:Slider({
    Title = "Equip delay", Min = 1, Max = 60, Value = 5, Rounding = 0, Suffix = "s", id = "equip_delay",
    Callback = function(v) EQUIP_DELAY = v end,
})

-- ---------- kolom 2 ----------
local cChest = Main:AddCard({ Title = "Chest", Icon = "package", Column = 2 })
local tog_chest = cChest:Toggle({
    Title = "Auto Take Chest", id = "auto_chest",
    Callback = function(v)
        Loop("chest", v, function() return CHEST_DELAY end, TakeChest)
        OnOff("Auto Take Chest", v)
    end,
})
cChest:Slider({
    Title = "Chest delay", Min = 0.2, Max = 10, Value = 1, Rounding = 1, Suffix = "s", id = "chest_delay",
    Callback = function(v) CHEST_DELAY = v end,
})
cChest:Button({ Text = "Take Chest (1x klik)", Callback = function() TakeChest(); N("Take Chest", "Dikirim", "#50C864") end })

local cSell = Main:AddCard({ Title = "Sell", Icon = "coins", Column = 2 })
ddSell = cSell:Dropdown({ Title = "Ore (satuan)", List = ORES, Value = {}, id = "sell_select" })
local tog_sellsel = cSell:Toggle({
    Title = "Auto Sell Selected", id = "auto_sell_sel",
    Callback = function(v)
        if v and #Ordered(ORES, ddSell:Get()) == 0 then N("Auto Sell Selected", "Belum ada ore yang dipilih", "#FFA500") end
        Loop("sellsel", v, function() return SELL_DELAY end, SellSelected)
        OnOff("Auto Sell Selected", v)
    end,
})
local tog_sellall = cSell:Toggle({
    Title = "Auto Sell All (6 ore umum)", id = "auto_sell_all",
    Callback = function(v)
        Loop("sellall", v, function() return SELL_DELAY end, SellAllOres)
        OnOff("Auto Sell All", v)
    end,
})
cSell:Slider({
    Title = "Sell delay", Min = 0.5, Max = 30, Value = 2, Rounding = 1, Suffix = "s", id = "sell_delay",
    Callback = function(v) SELL_DELAY = v end,
})
cSell:Button({ Text = "Sell All (1x klik)", Callback = function() SellAllOres(); N("Sell All", "Dikirim", "#50C864") end })

local cUnlock = Main:AddCard({ Title = "Unlock Slot", Icon = "lock-open", Column = 2 })
local tog_unlock = cUnlock:Toggle({
    Title = "Auto Unlock Slot", id = "auto_unlock",
    Callback = function(v)
        Loop("unlock", v, function() return UNLOCK_DELAY end, function() UnlockSlots() end)
        OnOff("Auto Unlock Slot", v)
    end,
})
cUnlock:Slider({
    Title = "Unlock delay", Min = 1, Max = 30, Value = 2, Rounding = 0, Suffix = "s", id = "unlock_delay",
    Callback = function(v) UNLOCK_DELAY = v end,
})
cUnlock:Button({
    Text = "Unlock Slot (1x klik)",
    Callback = function()
        task.spawn(function()
            local n = UnlockSlots()
            if n < 0 then N("Unlock Slot", "Executor tidak mendukung fireproximityprompt", "#DC3232", 5)
            elseif n == 0 then N("Unlock Slot", "Tidak ada slot terkunci yang ditemukan", "#FFA500")
            else N("Unlock Slot", n .. " slot ditekan", "#50C864") end
        end)
    end,
})

local cRedeem = Main:AddCard({ Title = "Redeem", Icon = "gift", Column = 2 })
cRedeem:Label({ Text = table.concat(CODES, ", ") })
cRedeem:Button({
    Text = "Redeem Code",
    Callback = function()
        task.spawn(function()
            local n = RedeemAll()
            N("Redeem Code", n .. " kode dikirim", "#50C864")
        end)
    end,
})

local allToggles = { tog_mine, tog_equip, tog_upsel, tog_upall, tog_chest, tog_sellsel, tog_sellall, tog_unlock }
local cCtl = Main:AddCard({ Title = "Controls", Icon = "sliders-horizontal", Column = 2 })
cCtl:Buttons({ Buttons = {
    { Text = "All ON",  Callback = function() for _, t in ipairs(allToggles) do t:Set(true) end end },
    { Text = "All OFF", Callback = function() for _, t in ipairs(allToggles) do t:Set(false) end end },
} })
cCtl:Buttons({ Buttons = {
    { Text = "Equip Best", Callback = function() EquipBest() end },
    { Text = "Upgrade",    Callback = function() UpgradeSelected() end },
} })

-- status ore
local cStat = Main:AddCard({ Title = "Status", Icon = "gauge", Column = 1 })
local stLbl = cStat:Label({ Text = "-" })
task.spawn(function()
    while W.Alive do
        task.wait(1)
        pcall(function()
            stLbl:SetText("Ore: " .. #GetOres() .. "   Metode: " .. LastMethod .. "   Plot: " .. PlotMode)
        end)
    end
end)

-- hentikan semua loop saat Unload
W:OnUnload(function()
    for k in pairs(runId) do runId[k] += 1 end
end)

-- isi menu Player (Movement / Fly / Client) ada di ui.lua -> W:BuildPlayer
local okPl, errPl = pcall(function() W:BuildPlayer(PlayerPage) end)
if not okPl then
    warn("[KatssinnnHub] Player error: " .. tostring(errPl))
    N("Player error", tostring(errPl), "#DC3232", 10)
end

local okHome, errHome = pcall(function()
    W:BuildHome({ Game = "My Anime Mine", Version = "v1.0" }, HomePage)
end)
if not okHome then
    warn("[KatssinnnHub] Home error: " .. tostring(errHome))
    N("Home error", tostring(errHome), "#DC3232", 10)
end

W:SelectPage("Main")
W:Ready()      -- jalankan nilai awal + autoload config (Callback ikut jalan)
W:OnBooted(function() N("KatssinnnHub", "My Anime Mine dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4) end)   -- notifikasi muncul setelah intro selesai
