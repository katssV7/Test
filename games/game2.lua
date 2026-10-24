-- KatssinnnHub | Game 2 (Fishing)
-- UI / library / tema sama dengan game 1, hanya fitur farm yang diganti.
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
    FolderName       = "SkidPlayground",
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

local RS = game:GetService("ReplicatedStorage")
local LP = game:GetService("Players").LocalPlayer

-- ===== REMOTES =====
local Container
local function GetContainer()
    if Container and Container.Parent then return Container end
    local ok, res = pcall(function()
        return RS:WaitForChild("rbxts_include", 8)
            :WaitForChild("node_modules", 5)
            :WaitForChild("@rbxts", 5)
            :WaitForChild("remo", 5)
            :WaitForChild("src", 5)
            :WaitForChild("container", 5)
    end)
    Container = ok and res or nil
    return Container
end

local RemoteCache = {}
local function GetRemote(name)
    local r = RemoteCache[name]
    if r and r.Parent then return r end
    local c = GetContainer()
    r = c and c:WaitForChild(name, 5)
    RemoteCache[name] = r
    return r
end

-- ===== KATALOG =====
-- Urutan di bawah = urutan tampil di dropdown (Common paling atas, Godly paling bawah).
-- Format item: { "Nama", "Harga", "ID remote (opsional)" }
-- Kalau ID kosong: bait pakai nama apa adanya, gear pakai nama tanpa spasi.
local BAIT_TIERS = {
    { "Common",    { {"Starter", "50"}, {"Novice", "500"} } },
    { "Uncommon",  { {"Reef", "2.5K"}, {"Deep Sea", "5K"} } },
    { "Epic",      { {"Koi", "20K"}, {"River", "50K"}, {"Puffer", "200K"} } },
    { "Legendary", { {"Glo", "400K"}, {"Seal", "700K"}, {"Ray", "1.2M"}, {"Octopus", "30M"} } },
    { "Mythic",    { {"Axolotl", "5M"}, {"Jelly", "60M"}, {"Whale", "250M"}, {"Squid", "500M"}, {"Shark", "500M"} } },
    { "Ancient",   { {"Megalodon", "3 Token"}, {"Kraken", "15 Token"}, {"Maw", "75 Token"} } },
    { "Godly",     { {"Bloop", "250 Token"}, {"Ocean Eater", "1K Token"}, {"Serpent", "25K Token"}, {"Doom Rex", "100K Token"}, {"Grand Turtle", "400 Token"} } },
}

local EGG_TIERS = {
    { "Common",    { {"Starter Egg", "5K", "Starter"} } },
    { "Uncommon",  { {"Novice Egg", "200K", "Novice"} } },
    { "Epic",      { {"Forest Egg", "3M", "Forest"} } },
    { "Legendary", { {"Polar Egg", "15M", "Polar"} } },
    { "Mythic",    { {"Tropical Egg", "70M", "Tropical"} } },
    { "Ancient",   { {"Exotic Egg", "800M", "Exotic"} } },
}

local GEAR_TIERS = {
    { "Common",    { {"Basic Auto Feeder", "20K"}, {"Food Scoop", "30K"}, {"Basic Food Tray", "50K"}, {"Move Tool", "60K"} } },
    { "Uncommon",  { {"Magnifying Glass", "120K"} } },
    { "Epic",      { {"Advance Food Tray", "500K"}, {"Advance Auto Feeder", "500K"}, {"XP Cookie", "750K"}, {"Teleport Wand", "1M"}, {"Star Lock", "1.2M"} } },
    { "Legendary", { {"Supreme Auto Feeder", "5M"}, {"Pet Toy", "10M"}, {"Trading Ticket", "10M"}, {"Egg Hatcher", "12.5M"}, {"Supreme Food Tray", "20M"} } },
    { "Mythic",    { {"Pet Whistle", "10M"}, {"Golden Cookie", "20M"}, {"Mutation Beacon", "50M"}, {"Egg Incubator", "150M"} } },
    { "Ancient",   { {"Storm Horn", "100M"}, {"Extreme Auto Feeder", "100M"} } },
    { "Godly",     { {"Godly Auto Feeder", "1 Token"} } },
}

-- bikin daftar { label, id } sesuai urutan di atas
local function Catalog(tiers, stripSpaces)
    local list = {}
    for _, tier in ipairs(tiers) do
        local rarity = tier[1]
        for _, it in ipairs(tier[2]) do
            local name, price, id = it[1], it[2], it[3]
            if not id then
                id = name
                if stripSpaces then id = (name:gsub("%s+", "")) end
            end
            list[#list + 1] = {
                label = name .. " - " .. price .. " (" .. rarity .. ")",
                id    = id,
            }
        end
    end
    return list
end

local function Labels(cat)
    local t = {}
    for i, e in ipairs(cat) do t[i] = e.label end
    return t
end

local BAIT_CAT = Catalog(BAIT_TIERS, false)
local EGG_CAT  = Catalog(EGG_TIERS, false)
local GEAR_CAT = Catalog(GEAR_TIERS, true)

-- ambil id item yang dipilih, selalu berurutan sesuai katalog
local function SelectedIds(cat, v)
    local set = {}
    if type(v) == "table" then
        for _, l in ipairs(v) do set[l] = true end
    elseif v then
        set[v] = true
    end
    local ids = {}
    for _, e in ipairs(cat) do
        if set[e.label] then ids[#ids + 1] = e.id end
    end
    return ids
end

-- ===== STATE =====
local CLAIM_DELAY = 0.1
local SELL_DELAY  = 1
local CYCLE_DELAY = 1     -- jeda antar putaran saat Auto Feed ON
local STEP_GAP    = 0.5   -- jeda Claim -> Feed -> Sell saat Auto Feed ON
local BUY_DELAY   = 1
local EGG_DELAY   = 1
local GEAR_DELAY  = 1
local LastClaimCount = 0

local On = { claim = false, feed = false, sell = false }
local runId = { buy = 0, egg = 0, gear = 0 }

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

-- ===== AKSI =====
-- ID jaring (workspace.Ponds.<pond>.Buildings.<uuid>)
local function GetNetIDs()
    local ids = {}
    local ponds = workspace:FindFirstChild("Ponds")
    if not ponds then return ids end
    for _, pond in ipairs(ponds:GetChildren()) do
        local buildings = pond:FindFirstChild("Buildings")
        if buildings then
            for _, net in ipairs(buildings:GetChildren()) do
                local name = net.Name
                if #name >= 32 and name:find("%-") then
                    table.insert(ids, name)
                end
            end
        end
    end
    return ids
end

-- claim semua jaring sekaligus (paralel)
local function ClaimAll()
    local r = GetRemote("bait.collectAllFish")
    if not r then return 0 end
    local ids = GetNetIDs()
    for _, id in ipairs(ids) do
        task.spawn(function() pcall(r.FireServer, r, id) end)
    end
    LastClaimCount = #ids
    return #ids
end

local function FeedAll()
    local r = GetRemote("halloween.feedTreeAll")
    if r then r:FireServer() end
end

local function SellAll()
    local r = GetRemote("sellFish.sellAllFish")
    if r then r:FireServer() end
end

-- ===== DROP FEED (teleport) =====
-- Klik sekali: teleport ke titik 1 -> 2 -> 3, lalu balik ke posisi awal.
local DROP_POINTS = {
    Vector3.new(-10, 12, -1),
    Vector3.new(0, 13, -8),
    Vector3.new(2, 10, 6),
}
local DROP_WAIT = 1
local DropBusy = false

local function GetHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function CollectDrops()
    if DropBusy then return false end
    local hrp = GetHRP()
    if not hrp then return false end
    DropBusy = true
    local back = hrp.CFrame
    pcall(function()
        for _, pos in ipairs(DROP_POINTS) do
            local h = GetHRP()
            if not h then return end
            h.CFrame = CFrame.new(pos)
            h.AssemblyLinearVelocity = Vector3.zero
            task.wait(DROP_WAIT)
        end
    end)
    local h = GetHRP()
    if h then
        h.CFrame = back
        h.AssemblyLinearVelocity = Vector3.zero
    end
    DropBusy = false
    return true
end

-- ===== REDEEM =====
local CODES = { "WILCO", "KIRA", "67", "50K" }

local function RedeemAll()
    local r = GetRemote("store.redeemCode")
    if not r then return 0 end
    for _, code in ipairs(CODES) do
        pcall(r.FireServer, r, code)
        task.wait(0.3)
    end
    return #CODES
end

-- dropdown dibuat di bawah; dibaca langsung saat beli supaya selalu sinkron
local ddBait, ddEgg, ddGear

local function BuyFrom(remoteName, cat, dd)
    local r = GetRemote(remoteName)
    if not r or not dd then return 0 end
    local ids = SelectedIds(cat, dd:GetValue())
    for _, id in ipairs(ids) do
        pcall(r.FireServer, r, id)
    end
    return #ids
end

local function BuyBaits() return BuyFrom("shop.purchaseBait", BAIT_CAT, ddBait) end
local function BuyEggs()  return BuyFrom("shop.purchaseEgg",  EGG_CAT,  ddEgg)  end
local function BuyGears() return BuyFrom("shop.purchaseGear", GEAR_CAT, ddGear) end

-- ===== SCHEDULER: Claim / Feed / Sell =====
-- Toggle tetap terpisah. Kalau Auto Feed ON, ketiganya jalan berurutan dalam satu putaran:
--   Claim (kalau ON) -> Feed -> Sell (kalau ON), jadi ikan tidak terjual sebelum di-feed.
-- Kalau Auto Feed OFF, Claim dan Sell jalan sendiri-sendiri dengan delay masing-masing.
local schedId = 0
local function Sched()
    schedId += 1
    if not (On.claim or On.feed or On.sell) then return end
    local id = schedId
    local function alive() return schedId == id end

    task.spawn(function()
        local lastClaim, lastSell, lastCycle = -math.huge, -math.huge, -math.huge
        while alive() do
            local now = os.clock()
            local ok, err = pcall(function()
                if On.feed then
                    if now - lastCycle >= CYCLE_DELAY then
                        lastCycle = now
                        if On.claim then
                            ClaimAll()
                            task.wait(STEP_GAP)
                            if not alive() then return end
                        end
                        FeedAll()
                        if On.sell then
                            task.wait(STEP_GAP)
                            if not alive() or not On.sell then return end
                            SellAll()
                        end
                        lastCycle = os.clock()   -- Cycle delay dihitung dari selesainya putaran
                    end
                else
                    if On.claim and now - lastClaim >= CLAIM_DELAY then
                        lastClaim = now
                        ClaimAll()
                    end
                    if On.sell and now - lastSell >= SELL_DELAY then
                        lastSell = now
                        SellAll()
                    end
                end
            end)
            if not ok then warn("[sched] " .. tostring(err)) end
            task.wait(0.05)
        end
    end)
end

local P_Main = Window:NewPage({
    Title         = "Main",
    Desc          = "Claim, feed, sell, buy bait / egg / gear",
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

-- ===== CLAIM FISH =====
P_Main:Section("Farm")

local tog_claim = P_Main:Toggle({
    Title        = "Auto Claim Fish",
    Desc         = "Claim semua jaring sekaligus",
    Value        = false,
    id           = "auto_claim",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        On.claim = v
        Sched()
        N("Auto Claim Fish", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

Group("Claim settings", function(add)
    add(P_Main:Slider({
        Title    = "Claim delay",
        Desc     = "Jeda antar claim (dipakai saat Auto Feed OFF)",
        Min      = 0.05, Max = 5, Value = 0.1,
        Rounding = 2, Suffix = "s",
        id       = "claim_delay",
        Callback = function(v) CLAIM_DELAY = v end,
    }))
end)

-- ===== FEED =====
P_Main:Divider()
P_Main:Section("Feed")

local tog_feed = P_Main:Toggle({
    Title        = "Auto Feed Tree",
    Desc         = "Feed semua pohon. Bareng Auto Sell: Claim > Feed > Sell",
    Value        = false,
    id           = "auto_feed",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        On.feed = v
        Sched()
        if v and On.sell then
            N("Auto Feed", "ON - Sell ditunda sampai Feed selesai", "#50C864")
        else
            N("Auto Feed", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
        end
    end,
})

Group("Feed settings", function(add)
    add(P_Main:Slider({
        Title    = "Cycle delay",
        Desc     = "Jeda antar putaran Claim > Feed > Sell",
        Min      = 0.1, Max = 10, Value = 1,
        Rounding = 1, Suffix = "s",
        id       = "cycle_delay",
        Callback = function(v) CYCLE_DELAY = v end,
    }))
    add(P_Main:Slider({
        Title    = "Step gap",
        Desc     = "Jeda antar langkah (Claim ke Feed, Feed ke Sell)",
        Min      = 0.1, Max = 3, Value = 0.5,
        Rounding = 1, Suffix = "s",
        id       = "step_gap",
        Callback = function(v) STEP_GAP = v end,
    }))
end)

P_Main:Button({
    Title    = "Collect Drop Feed",
    Desc     = "Klik: teleport ke titik 1, 2, 3 lalu kembali ke posisi awal",
    Text     = "Collect",
    Callback = function()
        task.spawn(function()
            if DropBusy then N("Drop Feed", "Masih berjalan...", "#FFA500"); return end
            N("Drop Feed", "Teleport 1 > 2 > 3...", "#6495ED")
            local ok = CollectDrops()
            N("Drop Feed", ok and "Selesai, kembali ke posisi awal" or "Karakter tidak ditemukan", ok and "#50C864" or "#DC3232")
        end)
    end,
})

Group("Drop settings", function(add)
    add(P_Main:Slider({
        Title    = "Jeda tiap titik",
        Desc     = "Lama berhenti di setiap titik teleport (detik)",
        Min      = 0.2, Max = 5, Value = 1,
        Rounding = 1, Suffix = "s",
        id       = "drop_wait",
        Callback = function(v) DROP_WAIT = v end,
    }))
end)

-- ===== SELL =====
P_Main:Divider()
P_Main:Section("Sell")

local tog_sell = P_Main:Toggle({
    Title        = "Auto Sell Fish",
    Desc         = "Jual semua ikan (ditunda sampai Feed selesai kalau Auto Feed ON)",
    Value        = false,
    id           = "auto_sell",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        On.sell = v
        Sched()
        N("Auto Sell Fish", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

Group("Sell settings", function(add)
    add(P_Main:Slider({
        Title    = "Sell delay",
        Desc     = "Jeda antar jual (dipakai saat Auto Feed OFF)",
        Min      = 0.5, Max = 10, Value = 1,
        Rounding = 1, Suffix = "s",
        id       = "sell_delay",
        Callback = function(v) SELL_DELAY = v end,
    }))
end)

-- ===== BAIT =====
P_Main:Divider()
P_Main:Section("Bait")

ddBait = P_Main:Dropdown({
    Title     = "Bait",
    List      = Labels(BAIT_CAT),
    Value     = { BAIT_CAT[1].label },
    KeepOrder = true,
    id        = "bait_select",
})

local tog_buy = P_Main:Toggle({
    Title        = "Auto Buy Bait",
    Desc         = "Beli bait yang dipilih terus-menerus",
    Value        = false,
    id           = "auto_buy_bait",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        if v and #SelectedIds(BAIT_CAT, ddBait:GetValue()) == 0 then
            N("Auto Buy Bait", "Belum ada bait yang dipilih", "#FFA500")
        end
        Loop("buy", v, function() return BUY_DELAY end, function()
            BuyBaits()
        end)
        N("Auto Buy Bait", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

Group("Bait settings", function(add)
    add(P_Main:Slider({
        Title    = "Buy delay",
        Min      = 0.1, Max = 10, Value = 1,
        Rounding = 1, Suffix = "s",
        id       = "buy_delay",
        Callback = function(v) BUY_DELAY = v end,
    }))
end)

-- ===== EGG =====
P_Main:Divider()
P_Main:Section("Egg")

ddEgg = P_Main:Dropdown({
    Title     = "Egg",
    List      = Labels(EGG_CAT),
    Value     = {},
    KeepOrder = true,
    id        = "egg_select",
})

local tog_egg = P_Main:Toggle({
    Title        = "Auto Buy Egg",
    Desc         = "Beli egg yang dipilih terus-menerus",
    Value        = false,
    id           = "auto_buy_egg",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        if v and #SelectedIds(EGG_CAT, ddEgg:GetValue()) == 0 then
            N("Auto Buy Egg", "Belum ada egg yang dipilih", "#FFA500")
        end
        Loop("egg", v, function() return EGG_DELAY end, function()
            BuyEggs()
        end)
        N("Auto Buy Egg", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

Group("Egg settings", function(add)
    add(P_Main:Slider({
        Title    = "Egg delay",
        Min      = 0.1, Max = 10, Value = 1,
        Rounding = 1, Suffix = "s",
        id       = "egg_delay",
        Callback = function(v) EGG_DELAY = v end,
    }))
end)

-- ===== GEAR =====
P_Main:Divider()
P_Main:Section("Gear")

ddGear = P_Main:Dropdown({
    Title     = "Gear",
    List      = Labels(GEAR_CAT),
    Value     = {},
    KeepOrder = true,
    id        = "gear_select",
})

local tog_gear = P_Main:Toggle({
    Title        = "Auto Buy Gear",
    Desc         = "Beli gear yang dipilih terus-menerus",
    Value        = false,
    id           = "auto_buy_gear",
    CornerRadius = UDim.new(1, 0),
    Callback     = function(v)
        if v and #SelectedIds(GEAR_CAT, ddGear:GetValue()) == 0 then
            N("Auto Buy Gear", "Belum ada gear yang dipilih", "#FFA500")
        end
        Loop("gear", v, function() return GEAR_DELAY end, function()
            BuyGears()
        end)
        N("Auto Buy Gear", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

Group("Gear settings", function(add)
    add(P_Main:Slider({
        Title    = "Gear delay",
        Min      = 0.1, Max = 10, Value = 1,
        Rounding = 1, Suffix = "s",
        id       = "gear_delay",
        Callback = function(v) GEAR_DELAY = v end,
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
        { Text="Claim", Color="#0088FF", Callback=function()
            N("Claim", ClaimAll() .. " jaring", "#50C864")
        end },
        { Text="Feed", Callback=function() pcall(FeedAll) end },
        { Text="Drop", Callback=function() task.spawn(CollectDrops) end },
        { Text="Sell", Color="#50C864", Callback=function() pcall(SellAll) end },
    },
})

P_Main:MultiButton({
    Buttons = {
        { Text="Buy Bait", Callback=function() BuyBaits() end },
        { Text="Buy Egg",  Callback=function() BuyEggs() end },
        { Text="Buy Gear", Callback=function() BuyGears() end },
    },
})

P_Main:MultiButton({
    Buttons = {
        { Text="All ON",  Color="#50C864", Callback=function()
            tog_claim:SetValue(true); tog_feed:SetValue(true); tog_sell:SetValue(true)
            tog_buy:SetValue(true); tog_egg:SetValue(true); tog_gear:SetValue(true)
        end },
        { Text="All OFF", Color="#DC3232", Callback=function()
            tog_claim:SetValue(false); tog_feed:SetValue(false); tog_sell:SetValue(false)
            tog_buy:SetValue(false); tog_egg:SetValue(false); tog_gear:SetValue(false)
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

local lblNets  = P_Stat:RightLabel({ Title = "Jaring",        Right = "-" })
local lblClaim = P_Stat:RightLabel({ Title = "Claim terakhir", Right = "-" })
local lblMode  = P_Stat:RightLabel({ Title = "Mode",           Right = "-" })

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            for _, s in ipairs(statLabels) do
                s.label:SetRight(tostring(s.obj.Value))
            end
            lblNets:SetRight(tostring(#GetNetIDs()))
            lblClaim:SetRight(LastClaimCount .. " jaring")
            lblMode:SetRight(On.feed and "Cycle: Claim > Feed > Sell" or "Terpisah")
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
    Desc     = "Flips Auto Claim when pressed",
    Value    = Enum.KeyCode.J,
    id       = "key2",
    Callback = function() tog_claim:SetValue(not tog_claim:GetValue()) end,
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

N("<b>Skid Playground</b>", Exec.name.."  ·  RCtrl to toggle", "#FF007F", 5)
