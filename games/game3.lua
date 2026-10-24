-- KatssinnnHub | Game 3 (My Anime Mine)
-- UI / library / tema sama dengan game 1 dan 2.
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/source.lua"
))()

local Cfg  = Library.Cfg
local Exec = Library.Exec

local function N(title, desc, color, dur)
    Library:Notification({ Title=title, Desc=desc or "", Color=color or "#6495ED", Duration=dur or 3 })
end

local Window = Library:Window({
    Title            = "KatssinnnHub",
    SubTitle         = "OnTop",
    ToggleKey        = Enum.KeyCode.RightControl,
    Icon             = "rbxassetid://104055321996495",
    ToggleIcon       = "rbxassetid://104055321996495",
    ToggleBtnCorner  = UDim.new(1, 0),
    FolderName       = "KatssinnnHub",
    AutoLoad         = function(name, data)
        N("Restored", name, "#50C864", 3)
    end,
    AutoScale = true,
    Scale     = 1.45,
    Theme = {
        Accent       = "#FF007F",
        Background   = "#0B0B0B",
        Row          = "#121212",
        RowAlt       = "#0D0D0D",
        Stroke       = "#202020",
        Text         = "#EBEBEB",
        SubText      = "#949494",
        TabBg        = "#0D0D0D",
        TabStroke    = "#4B0026",
        TabImage     = "#FF007F",
        DropBg       = "#101010",
        ToggleBg     = "#0B0B0B",
        Font         = Enum.Font.Gotham,
        FontBold     = Enum.Font.GothamBold,
        FontMedium   = Enum.Font.GothamMedium,
        CornerRadius = UDim.new(0, 5),
    },
})

Library:SetExtraTitle("R4")
Library:SetExtraSubTitle("is tuff")

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
local P_Main = Window:NewPage({
    Title         = "Main",
    Desc          = "Mine, upgrade, chest, sell & unlock",
    Icon          = "toggle-left",
    TabImageColor = "#FF007F",
})

-- baris "xxx settings [v]" untuk buka/tutup pengaturan milik satu toggle
local function Group(title, build)
    local items, open = {}, false
    local header
    header = P_Main:Button({
        Title    = title,
        Desc     = "Buka / tutup pengaturan",
        Text     = "v",
        Callback = function()
            open = not open
            header:SetText(open and "^" or "v")
            for _, e in ipairs(items) do e:SetVisible(open) end
        end,
    })
    build(function(e)
        e:SetVisible(false)
        items[#items + 1] = e
        return e
    end)
end

local function OnOff(name, v)
    N(name, v and "ON" or "OFF", v and "#50C864" or "#DC3232")
end

-- ===== AUTO MINE =====
P_Main:Section("Mine")

local tog_mine = P_Main:Toggle({
    Title        = "Auto Mine",
    Desc         = "Klik semua ore di folder Nodes secara berurutan",
    Value        = false,
    id           = "auto_mine",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
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

Group("Mine settings", function(add)
    add(P_Main:Slider({
        Title    = "Click speed",
        Desc     = "Jeda antar klik ore (detik). Makin kecil makin cepat",
        Min      = 0.01, Max = 1, Value = 0.1,
        Rounding = 2, Suffix = "s",
        id       = "mine_delay",
        Callback = function(v) MINE_DELAY = v end,
    }))
    add(P_Main:Dropdown({
        Title    = "Plot",
        Desc     = "Auto = plot terdekat dari karaktermu",
        List     = PLOT_LIST,
        Value    = "Auto (terdekat)",
        id       = "mine_plot",
        Callback = function(v) PlotMode = tostring(v) end,
    }))
    add(P_Main:Toggle({
        Title        = "Teleport ke ore",
        Desc         = "Pindah ke dekat ore sebelum klik (kalau jarak jadi masalah)",
        Value        = false,
        id           = "mine_tp",
        CornerRadius = UDim.new(1, 0),
        Callback     = function(v) CLICK_TP = v end,
    }))
    add(P_Main:Button({
        Title    = "Cek ore",
        Desc     = "Hitung ore dan metode klik yang tersedia",
        Text     = "Cek",
        Callback = function()
            local ores = GetOres()
            local cd, pp, none = 0, 0, 0
            for _, o in ipairs(ores) do
                local m = Methods(o)
                if m.cd then cd += 1 elseif m.pp then pp += 1 else none += 1 end
            end
            N("Cek ore", #ores .. " ore | ClickDetector " .. cd .. " | Prompt " .. pp .. " | Layar " .. none, "#6495ED", 6)
        end,
    }))
end)

-- ===== EQUIP =====
P_Main:Divider()
P_Main:Section("Equip")

local tog_equip = P_Main:Toggle({
    Title        = "Auto Equip Best",
    Desc         = "Pasang anime terbaik terus-menerus",
    Value        = false,
    id           = "auto_equip",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        Loop("equip", v, function() return EQUIP_DELAY end, EquipBest)
        OnOff("Auto Equip Best", v)
    end,
})

Group("Equip settings", function(add)
    add(P_Main:Slider({
        Title    = "Equip delay",
        Min      = 1, Max = 60, Value = 5,
        Rounding = 0, Suffix = "s",
        id       = "equip_delay",
        Callback = function(v) EQUIP_DELAY = v end,
    }))
end)

-- ===== UPGRADE =====
P_Main:Divider()
P_Main:Section("Upgrade")

ddSlots = P_Main:Dropdown({
    Title     = "Slot anime",
    Desc      = "Pilih slot yang mau di-upgrade (M1 = anime urutan 1)",
    List      = SLOTS,
    Value     = { "M1" },
    KeepOrder = true,
    id        = "up_slots",
})

ddStats = P_Main:Dropdown({
    Title     = "Stat",
    Desc      = "Stat yang di-upgrade (kosong = semua)",
    List      = STATS,
    Value     = { "Damage", "Speed", "MineSpeed" },
    KeepOrder = true,
    id        = "up_stats",
})

local tog_upsel = P_Main:Toggle({
    Title        = "Auto Upgrade Selected",
    Desc         = "Upgrade slot yang dipilih. Coin kurang di M1? slot lain yang murah tetap naik",
    Value        = false,
    id           = "auto_up_sel",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        if v and #Ordered(SLOTS, ddSlots:GetValue()) == 0 then
            N("Auto Upgrade", "Belum ada slot yang dipilih", "#FFA500")
        end
        Loop("upsel", v, function() return UP_DELAY end, UpgradeSelected)
        OnOff("Auto Upgrade Selected", v)
    end,
})

local tog_upall = P_Main:Toggle({
    Title        = "Auto Upgrade All Slots",
    Desc         = "Upgrade semua slot M1 sampai M" .. MAX_SLOT,
    Value        = false,
    id           = "auto_up_all",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        Loop("upall", v, function() return UP_DELAY end, UpgradeAll)
        OnOff("Auto Upgrade All", v)
    end,
})

Group("Upgrade settings", function(add)
    add(P_Main:Slider({
        Title    = "Upgrade delay",
        Min      = 0.1, Max = 5, Value = 0.5,
        Rounding = 1, Suffix = "s",
        id       = "up_delay",
        Callback = function(v) UP_DELAY = v end,
    }))
end)

-- ===== CHEST =====
P_Main:Divider()
P_Main:Section("Chest")

local tog_chest = P_Main:Toggle({
    Title        = "Auto Take Chest",
    Desc         = "Ambil semua hasil mine terus-menerus",
    Value        = false,
    id           = "auto_chest",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        Loop("chest", v, function() return CHEST_DELAY end, TakeChest)
        OnOff("Auto Take Chest", v)
    end,
})

P_Main:Button({
    Title    = "Take Chest",
    Desc     = "Klik sekali: ambil semua hasil mine",
    Text     = "Take",
    Callback = function() TakeChest(); N("Take Chest", "Dikirim", "#50C864") end,
})

Group("Chest settings", function(add)
    add(P_Main:Slider({
        Title    = "Chest delay",
        Min      = 0.2, Max = 10, Value = 1,
        Rounding = 1, Suffix = "s",
        id       = "chest_delay",
        Callback = function(v) CHEST_DELAY = v end,
    }))
end)

-- ===== SELL =====
P_Main:Divider()
P_Main:Section("Sell")

ddSell = P_Main:Dropdown({
    Title     = "Ore (satuan)",
    Desc      = "Pilih ore yang dijual satu per satu",
    List      = ORES,
    Value     = {},
    KeepOrder = true,
    id        = "sell_select",
})

local tog_sellsel = P_Main:Toggle({
    Title        = "Auto Sell Selected",
    Desc         = "Jual ore yang dipilih di atas terus-menerus",
    Value        = false,
    id           = "auto_sell_sel",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        if v and #Ordered(ORES, ddSell:GetValue()) == 0 then
            N("Auto Sell Selected", "Belum ada ore yang dipilih", "#FFA500")
        end
        Loop("sellsel", v, function() return SELL_DELAY end, SellSelected)
        OnOff("Auto Sell Selected", v)
    end,
})

local tog_sellall = P_Main:Toggle({
    Title        = "Auto Sell All",
    Desc         = "Jual " .. table.concat(SELL_ALL, ", ") .. " sekaligus",
    Value        = false,
    id           = "auto_sell_all",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        Loop("sellall", v, function() return SELL_DELAY end, SellAllOres)
        OnOff("Auto Sell All", v)
    end,
})

Group("Sell settings", function(add)
    add(P_Main:Slider({
        Title    = "Sell delay",
        Min      = 0.5, Max = 30, Value = 2,
        Rounding = 1, Suffix = "s",
        id       = "sell_delay",
        Callback = function(v) SELL_DELAY = v end,
    }))
end)

-- ===== UNLOCK SLOT =====
P_Main:Divider()
P_Main:Section("Unlock Slot")

local tog_unlock = P_Main:Toggle({
    Title        = "Auto Unlock Slot",
    Desc         = "Tekan prompt \"Locked miner slot\" (pindah ke slot, tekan, lalu balik)",
    Value        = false,
    id           = "auto_unlock",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        Loop("unlock", v, function() return UNLOCK_DELAY end, function() UnlockSlots() end)
        OnOff("Auto Unlock Slot", v)
    end,
})

P_Main:Button({
    Title    = "Unlock Slot",
    Desc     = "Klik sekali: tekan semua slot yang masih terkunci",
    Text     = "Unlock",
    Callback = function()
        task.spawn(function()
            local n = UnlockSlots()
            if n < 0 then
                N("Unlock Slot", "Executor tidak mendukung fireproximityprompt", "#DC3232", 5)
            elseif n == 0 then
                N("Unlock Slot", "Tidak ada slot terkunci yang ditemukan", "#FFA500")
            else
                N("Unlock Slot", n .. " slot ditekan", "#50C864")
            end
        end)
    end,
})

Group("Unlock settings", function(add)
    add(P_Main:Slider({
        Title    = "Unlock delay",
        Min      = 1, Max = 30, Value = 2,
        Rounding = 0, Suffix = "s",
        id       = "unlock_delay",
        Callback = function(v) UNLOCK_DELAY = v end,
    }))
end)

-- ===== REDEEM =====
P_Main:Divider()
P_Main:Section("Redeem")

P_Main:Button({
    Title    = "Redeem Code",
    Desc     = "Sekali klik: semua kode di-redeem (" .. table.concat(CODES, ", ") .. ")",
    Text     = "Redeem",
    Callback = function()
        task.spawn(function()
            local n = RedeemAll()
            N("Redeem Code", n .. " kode dikirim", "#50C864")
        end)
    end,
})

-- ===== MANUAL =====
P_Main:Divider()
P_Main:Section("Manual")

P_Main:MultiButton({
    Buttons = {
        { Text="Equip Best", Callback=function() EquipBest() end },
        { Text="Upgrade", Color="#0088FF", Callback=function() UpgradeSelected() end },
        { Text="Sell All", Color="#50C864", Callback=function() SellAllOres() end },
    },
})

local allToggles = { tog_mine, tog_equip, tog_upsel, tog_upall, tog_chest, tog_sellsel, tog_sellall, tog_unlock }

P_Main:MultiButton({
    Buttons = {
        { Text="All ON",  Color="#50C864", Callback=function()
            for _, t in ipairs(allToggles) do t:SetValue(true) end
        end },
        { Text="All OFF", Color="#DC3232", Callback=function()
            for _, t in ipairs(allToggles) do t:SetValue(false) end
        end },
    },
})

-- ===== STATS =====
local P_Stat = Window:NewPage({
    Title         = "Leaderstats",
    Desc          = "Profil & stats pemain",
    Icon          = "layout",
    TabImageColor = "#0088FF",
})

P_Stat:Section("Profil")

P_Stat:Paragraph({
    Title         = LP.DisplayName,
    Desc          = "@" .. LP.Name,
    Thumbnail     = "rbxthumb://type=AvatarHeadShot&id=" .. LP.UserId .. "&w=150&h=150",
    ThumbnailSize = 56,
})

P_Stat:Divider()
P_Stat:Section("Leaderstats")

-- label dibuat otomatis dari isi leaderstats game ini
local statLabels = {}
do
    local ls = LP:FindFirstChild("leaderstats") or LP:WaitForChild("leaderstats", 5)
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            if v:IsA("ValueBase") then
                statLabels[#statLabels + 1] = {
                    obj   = v,
                    label = P_Stat:RightLabel({ Title = v.Name, Right = tostring(v.Value) }),
                }
            end
        end
    end
    if #statLabels == 0 then
        P_Stat:Label({ Title = "Leaderstats tidak ditemukan", Desc = "Game ini tidak punya leaderstats" })
    end
end

P_Stat:Divider()
P_Stat:Section("Status")

local lblOre    = P_Stat:RightLabel({ Title = "Ore terdeteksi", Right = "-" })
local lblMethod = P_Stat:RightLabel({ Title = "Metode klik",    Right = "-" })
local lblPlot   = P_Stat:RightLabel({ Title = "Plot",           Right = "-" })

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            for _, s in ipairs(statLabels) do
                s.label:SetRight(tostring(s.obj.Value))
            end
            lblOre:SetRight(tostring(#GetOres()))
            lblMethod:SetRight(LastMethod)
            lblPlot:SetRight(PlotMode)
        end)
    end
end)

-- ===== INPUTS =====
local P_Inp = Window:NewPage({
    Title         = "Inputs",
    Desc          = "Input & keybind tests",
    Icon          = "type",
    TabImageColor = "#00CC66",
})

P_Inp:Section("Input fields")

local inp1 = P_Inp:Input({
    Title       = "With clipboard copy button",
    Placeholder = "Type something...",
    ShowButton  = Exec.clipboard,
    id          = "inp1",
    Callback    = function(v) N("Input 1", v) end,
})

local inp2 = P_Inp:Input({
    Title         = "Clear on submit",
    Placeholder   = "Clears after Enter...",
    ClearOnSubmit = true,
    id            = "inp2",
    Callback      = function(v) N("Submitted", v) end,
})

local inp3 = P_Inp:Input({
    Title       = "No copy button",
    Placeholder = "Plain input...",
    ShowButton  = false,
    id          = "inp3",
    Callback    = function(v) end,
})

P_Inp:MultiButton({
    Buttons = {
        { Text="Read all", Callback=function() N("Inputs", inp1:GetValue().." | "..inp2:GetValue().." | "..inp3:GetValue()) end },
        { Text="Set inp1", Callback=function() inp1:SetValue("Hello") end },
        { Text="Clear",    Callback=function() inp1:SetValue(""); inp2:SetValue(""); inp3:SetValue("") end },
    },
})

P_Inp:Divider()
P_Inp:Section("Keybinds")

local key1 = P_Inp:Keybind({
    Title    = "Keybind A",
    Desc     = "Click to rebind, then press any key",
    Value    = Enum.KeyCode.H,
    id       = "key1",
    Callback = function(k) N("Key A fired", k.Name) end,
})

local key2 = P_Inp:Keybind({
    Title    = "Keybind B",
    Desc     = "Flips Auto Mine when pressed",
    Value    = Enum.KeyCode.J,
    id       = "key2",
    Callback = function() tog_mine:SetValue(not tog_mine:GetValue()) end,
})

P_Inp:Button({
    Title    = "Read keybinds",
    Text     = "Read",
    Callback = function() N("Keys", key1:GetValue().Name.." | "..key2:GetValue().Name) end,
})

-- ===== DROPDOWNS =====
local P_Drop = Window:NewPage({
    Title         = "Dropdowns",
    Desc          = "Dropdown element tests",
    Icon          = "chevron-down",
    TabImageColor = "#9955FF",
})

P_Drop:Section("Single select")

local drop1 = P_Drop:Dropdown({
    Title    = "Pick a color",
    List     = { "Red", "Orange", "Yellow", "Green", "Blue", "Indigo", "Violet" },
    Value    = "Red",
    id       = "drop1",
    Callback = function(v) N("Color", v) end,
})

local drop2 = P_Drop:Dropdown({
    Title    = "Pick a number",
    List     = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten" },
    Value    = "One",
    id       = "drop2",
    Callback = function(v) N("Number", v) end,
})

P_Drop:MultiButton({
    Buttons = {
        { Text="Read drop1", Callback=function() N("Drop1", tostring(drop1:GetValue())) end },
        { Text="Reset drop1", Callback=function() drop1:SetValue("Red") end },
        { Text="Add item", Callback=function() drop1:AddList("Extra") N("Added","Extra to drop1") end },
    },
})

P_Drop:Divider()
P_Drop:Section("Multi select")

local drop3 = P_Drop:Dropdown({
    Title    = "Pick multiple fruits",
    List     = { "Apple", "Banana", "Cherry", "Durian", "Elderberry", "Fig", "Grape" },
    Value    = { "Apple", "Banana" },
    id       = "drop3",
    Callback = function(v) N("Fruits", table.concat(v, ", ")) end,
})

P_Drop:MultiButton({
    Buttons = {
        { Text="Read multi",  Callback=function()
            local v = drop3:GetValue()
            N("Multi", type(v)=="table" and table.concat(v,", ") or tostring(v))
        end },
        { Text="Clear multi", Color="#DC3232", Callback=function() drop3:Clear() end },
    },
})

-- ===== DISPLAY =====
local P_Disp = Window:NewPage({
    Title         = "Display",
    Desc          = "All display elements",
    Icon          = "layout",
    TabImageColor = "#CC9900",
})

P_Disp:Section("Labels")

P_Disp:Label({ Title="Static label", Desc="Read-only text, no interaction" })
P_Disp:Label({ Title="<b>Rich text</b> in label", Desc="<i>Italic desc</i> with <font color=\"rgb(100,200,255)\">colored text</font>" })

local rl1 = P_Disp:RightLabel({ Title="Executor",  Right=Exec.name })
local rl2 = P_Disp:RightLabel({ Title="Clipboard", Right=tostring(Exec.clipboard) })
local rl3 = P_Disp:RightLabel({ Title="Live count", Right="0" })

do
    local count = 0
    task.spawn(function()
        while task.wait(1) do
            count = count + 1
            rl3:SetRight(tostring(count))
        end
    end)
end

P_Disp:Divider()
P_Disp:Section("Paragraphs")

P_Disp:Paragraph({
    Title = "Basic paragraph",
    Desc  = "A styled block of text. Supports <b>bold</b>, <i>italic</i>, and color.",
})

P_Disp:Paragraph({
    Title   = "Paragraph with buttons",
    Desc    = "An optional row of action buttons at the bottom of the paragraph.",
    Buttons = {
        { Text="Accept", Color="#50C864", Callback=function() N("Accepted","","#50C864") end },
        { Text="Decline", Color="#DC3232", Callback=function() N("Declined","","#DC3232") end },
        { Text="Ignore", Callback=function() N("Ignored") end },
    },
})

P_Disp:Divider()
P_Disp:Section("Banner")

P_Disp:Banner({ Image="rbxassetid://104055321996495", Height=100 })

P_Disp:Divider()
P_Disp:Section("Popups & Dialogs")

P_Disp:MultiButton({
    Buttons = {
        { Text="Popup",  Callback=function()
            Window:Popup({
                Title   = "Popup",
                Desc    = "A modal dialog with custom buttons.",
                Buttons = {
                    { Text="Confirm", Style="main", Callback=function() N("Confirmed","","#50C864") end },
                    { Text="Cancel",  Style="alt",  Callback=function() N("Cancelled") end },
                },
            })
        end },
        { Text="Dialog", Callback=function()
            Window:Dialog({
                Title="Dialog", Desc="Quick confirm or cancel.",
                ConfirmText="Yes", CancelText="No",
                OnConfirm=function() N("Yes","","#50C864") end,
                OnCancel=function() N("No") end,
            })
        end },
    },
})

-- ===== CONFIG =====
local P_Cfg = Window:NewPage({
    Title         = "Config",
    Desc          = "Config system",
    Icon          = "save",
    TabImageColor = "#888888",
})

P_Cfg:Section("Config manager")

local cfgDrop = P_Cfg:Dropdown({
    Title="Saved configs", List=Cfg:listcfg(), Placeholder="Select config...",
    Callback=function(v) end,
})

local function RefreshDrop()
    cfgDrop:SetList(Cfg:listcfg())
    if Cfg:ActiveCfg() then cfgDrop:SetValue(Cfg:ActiveCfg()) end
end

local cfgName = P_Cfg:Input({
    Title="Config name", Placeholder="Enter name...", ShowButton=false,
})

P_Cfg:MultiButton({
    Buttons = {
        { Text="Create", Color="#50C864", Callback=function()
            local n=cfgName:GetValue(); if n=="" then N("Config","Enter a name","#FFA500"); return end
            if not Cfg:addcfg(n) then N("Config","Exists","#FFA500"); return end
            RefreshDrop(); N("Created",'"'..n..'"',"#50C864")
        end },
        { Text="Save", Callback=function()
            local n=cfgDrop:GetValue() or cfgName:GetValue()
            if not n or n=="" then N("Config","Select or name first","#FFA500"); return end
            Cfg:updcfg(n); RefreshDrop(); N("Saved",'"'..n..'"',"#50C864")
        end },
        { Text="Load", Color="#0088FF", Callback=function()
            local n=cfgDrop:GetValue() or cfgName:GetValue()
            if not n or n=="" then N("Config","Select first","#FFA500"); return end
            if Cfg:loadcfg(n) then N("Loaded",'"'..n..'"',"#50C864")
            else N("Error","Not found","#DC3232") end
        end },
        { Text="Del", Color="#DC3232", Callback=function()
            local n=cfgDrop:GetValue() or cfgName:GetValue(); if not n or n=="" then return end
            Window:Dialog({ Title="Delete", Desc='Delete "'..n..'"?', ConfirmText="Delete", CancelText="Cancel",
                OnConfirm=function() Cfg:delcfg(n); RefreshDrop(); N("Deleted",'"'..n..'"') end })
        end },
    },
})

P_Cfg:Divider()
P_Cfg:Section("Import / Export")

local cfgExportIn = P_Cfg:Input({ Title="Export JSON", Placeholder="Click Export...", ShowButton=Exec.clipboard })

P_Cfg:MultiButton({
    Buttons = {
        { Text="Export", Color="#50C864", Callback=function()
            local j = Cfg:exportcfg()
            if j then cfgExportIn:SetValue(j); N("Exported","JSON ready","#50C864")
            else N("Error","No active config","#DC3232") end
        end },
        { Text="Import", Color="#0088FF", Callback=function()
            local name = cfgName:GetValue(); local j = cfgExportIn:GetValue()
            if name=="" or j=="" then N("Import","Enter name and JSON","#FFA500"); return end
            if Cfg:importcfg(name, j) then RefreshDrop(); N("Imported",'"'..name..'"',"#50C864")
            else N("Error","Invalid JSON","#DC3232") end
        end },
    },
})

P_Cfg:Divider()
P_Cfg:Section("Auto load")

P_Cfg:MultiButton({
    Buttons = {
        { Text="Pin auto-load", Color="#50C864", Callback=function()
            local n=cfgDrop:GetValue(); if not n or n=="" then N("Config","Select first","#FFA500"); return end
            Cfg:setautoload(n); N("Auto-load",'"'..n..'" loads next run',"#50C864")
        end },
        { Text="Clear pin", Color="#FF6600", Callback=function() Cfg:clearautoload(); N("Auto-load","Cleared") end },
    },
})

P_Cfg:Divider()
P_Cfg:RightLabel({ Title="Active",  Right=Cfg:ActiveCfg() or "none" })
P_Cfg:RightLabel({ Title="Folder",  Right=Cfg:GetFolder() })
P_Cfg:RightLabel({ Title="Configs", Right=tostring(#Cfg:listcfg()) })

-- ===== SETTINGS =====
local P_Set = Window:NewPage({
    Title         = "Settings",
    Desc          = "UI, theme & notifications",
    Icon          = "settings",
    TabImageColor = "#444444",
})

P_Set:Section("Interface")

Library:AddSizeSlider(P_Set)

P_Set:Divider()
P_Set:Section("Toggle key")

P_Set:Dropdown({
    Title    = "Toggle key",
    Desc     = "Key to show/hide the UI",
    List     = { "RightControl", "F1", "F2", "F3", "F4", "RightAlt", "RightShift", "Delete", "End" },
    Value    = "RightControl",
    Callback = function(v)
        local ok, kc = pcall(function() return Enum.KeyCode[v] end)
        if ok and kc then
            N("Toggle key", v)
        end
    end,
})

P_Set:Divider()
P_Set:Section("Toggle button shape")

P_Set:MultiButton({
    Title   = "Toggle button UICorner",
    Buttons = {
        { Text="Circle",  Callback=function() Library:SetToggleBtnCorner(UDim.new(1,0))  N("Shape","Circle")  end },
        { Text="Rounded", Callback=function() Library:SetToggleBtnCorner(UDim.new(0,8))  N("Shape","Rounded") end },
        { Text="Square",  Callback=function() Library:SetToggleBtnCorner(UDim.new(0,0))  N("Shape","Square")  end },
    },
})

P_Set:Button({
    Title    = "Change toggle button icon",
    Desc     = "Updates the floating UI toggle button",
    Text     = "Change",
    Callback = function() Library:SetToggleIcon("rbxassetid://104055321996495"); N("Icon","Updated") end,
})

P_Set:Divider()
P_Set:Section("Font")

P_Set:Dropdown({
    Title    = "UI Font",
    List     = { "Gotham", "GothamBold", "GothamMedium", "Montserrat", "Arial", "AvenirHeavy", "Highway" },
    Value    = "Gotham",
    Callback = function(v)
        local ok, f = pcall(function() return Enum.Font[v] end)
        if ok and f then
            Library:SetTheme({ Font=f, FontBold=f, FontMedium=f })
            N("Font", v)
        end
    end,
})

P_Set:Divider()
P_Set:Section("Header text")

P_Set:MultiButton({
    Buttons = {
        { Text="Set right title",  Callback=function() Library:SetExtraTitle("gooner"); Library:SetExtraSubTitle("detected") end },
        { Text="Clear right text", Callback=function() Library:SetExtraTitle(""); Library:SetExtraSubTitle("") end },
    },
})

P_Set:Divider()
P_Set:Section("Lock / Unlock")

P_Set:Paragraph({
    Title = "Lock covers the entire UI",
    Desc  = "Library:Lock() overlays every page. Nothing can be clicked. Library:Unlock() removes it.",
})

P_Set:MultiButton({
    Buttons = {
        { Text="Lock UI",   Color="#DC3232", Callback=function() Library:Lock() end },
        { Text="Unlock UI", Color="#50C864", Callback=function() Library:Unlock() end },
    },
})

P_Set:Divider()
P_Set:Section("Custom theme")

local themeAccent = P_Set:Input({ Title="Accent color (hex)", Placeholder="#FF007F", id="theme_accent" })
local themeTabStroke = P_Set:Input({ Title="Tab stroke (hex)", Placeholder="#4B0026", id="theme_tab_stroke" })
local themeCorner = P_Set:Slider({ Title="Corner radius", Min=0, Max=16, Value=5, Rounding=0, id="theme_corner" })

P_Set:MultiButton({
    Buttons = {
        { Text="Apply theme", Color="#50C864", Callback=function()
            local accent = themeAccent:GetValue()
            local tabstroke = themeTabStroke:GetValue()
            local corner = themeCorner:GetValue()
            local newTheme = {}
            if accent~="" then
                newTheme.Accent   = accent
                newTheme.TabImage = accent
            end
            if tabstroke~="" then newTheme.TabStroke = tabstroke end
            if corner then newTheme.CornerRadius = UDim.new(0, corner) end
            Library:SetTheme(newTheme)
            N("Theme applied", "Custom theme set", "#50C864")
        end },
        { Text="Save as config", Callback=function()
            local n = "theme_"..tostring(os.time())
            Cfg:addcfg(n)
            Cfg:updcfg(n)
            RefreshDrop()
            N("Saved", '"'..n..'"', "#50C864")
        end },
    },
})

P_Set:Divider()
P_Set:Section("Theme presets")

P_Set:MultiButton({
    Buttons = {
        { Text="Pink",   Callback=function() Library:SetTheme({Accent="#FF007F",TabImage="#FF007F",TabStroke="#4B0026"}) end },
        { Text="Blue",   Color="#0088FF", Callback=function() Library:SetTheme({Accent="#0088FF",TabImage="#0088FF",TabStroke="#003366"}) end },
        { Text="Green",  Color="#00CC66", Callback=function() Library:SetTheme({Accent="#00CC66",TabImage="#00CC66",TabStroke="#004D26"}) end },
        { Text="Purple", Color="#9955FF", Callback=function() Library:SetTheme({Accent="#9955FF",TabImage="#9955FF",TabStroke="#330066"}) end },
    },
})

P_Set:Divider()
P_Set:Section("Notification tests")

P_Set:MultiButton({
    Buttons = {
        { Text="Info",    Color="#6495ED", Callback=function() N("Info",    "Something to note",     "#6495ED",4) end },
        { Text="Success", Color="#50C864", Callback=function() N("Success", "<b>Done</b>",            "#50C864",4) end },
        { Text="Warning", Color="#FFA500", Callback=function() N("Warning", "Check <i>this</i>",      "#FFA500",4) end },
        { Text="Error",   Color="#DC3232", Callback=function() N("Error",   "Something broke",        "#DC3232",4) end },
    },
})

P_Set:MultiButton({
    Buttons = {
        { Text="With icon", Callback=function()
            Library:Notification({ Title="Notification", Desc="Has an icon", Color="#FF007F", Duration=3, Icon="rbxassetid://104055321996495" })
        end },
        { Text="Long one", Callback=function()
            Library:Notification({ Title="Long notification", Desc="This one has a longer description that wraps to multiple lines to test the layout", Color="#9955FF", Duration=5 })
        end },
    },
})

N("<b>KatssinnnHub</b>", Exec.name.."  ·  RCtrl to toggle", "#FF007F", 5)
