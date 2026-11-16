-- Sevoice | Fish Game - Auto Fishing (FishGiver)
-- Auto Fishing: pilih rarity + ikan. Auto Full Index: kirim semua ikan Common -> Anomaly.
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "Sevoice",
    Version   = "v1.0",
    Game      = "Fish Game",
    Folder    = "Sevoice/FishGame",
    ToggleKey = Enum.KeyCode.RightControl,
})
local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local RS = game:GetService("ReplicatedStorage")

-- ===== data ikan (urut Common -> Anomaly) =====
local DATA = {
    { rarity = "Common", fish = { "Goldfish", "Guest Guppy", "Shedletsky Guppy", "Pastel Guppie", "Builderman Guppy", "Brighteyes Guppy", "Shrimp Goby", "Reef Chromis", "Goldmask Tetra", "Starfish", "Frog", "Hermit Crab", "Balloon Shrimp", "Beach Ball", "Seahorse Fish", "Worm Fish", "Sea Urchin", "Domino Damsel", "Floaty Damsel", "Classic Goldfish", "Sea Anemone", "Coconut Dotty", "Sunset Shrimp", "Fire Goby", "Hibiscus Chromis" } },
    { rarity = "Uncommon", fish = { "Jellyfish", "Axolotl", "Lobster", "Catfish", "Salmon", "Rockfish", "Pilot Fish", "Silver Tuna", "Yellowfin Tuna", "Red Snapper", "Parrot Fish", "Blue Lobster", "Horseshoe Crab", "Cabana Carp", "Dorhey Tang", "Banded Butterfly", "Panther Grouper", "Flying Fish", "Cantelope Puffer", "Wahoo" } },
    { rarity = "Rare", fish = { "Lion Fish", "Luminous Fish", "Zombie Shark", "Ghost Ray", "Ghost Fish", "Wraithfin Abyssal", "Fangtooth", "Magma Crab", "Flying Manta", "Loggerhead Turtle", "Panther Eel", "Steelfin Marlin", "Deepblue Lion Fish", "Runic Lobster", "Giant Squid", "Sharp One", "Crocodile", "Cosmic Jellyfish" } },
    { rarity = "Epic", fish = { "Loving Shark", "Monster Shark", "Queen Crab", "Pink Dolphin", "Pumpkin Jellyfish", "Witch Fish", "Heart Dolphin", "Cute Octopus", "Gladiator Shark", "Magma Shark", "Mosasaur Shark", "Hybodus Shark" } },
    { rarity = "Legendary", fish = { "Plasma Shark", "Crimsom Ray", "Blue Sea Dragon", "Walrus Bride", "Pirate Megalodon", "Megalodon", "Bone Whale", "Bloodmoon Whale", "Ancient Whale" } },
    { rarity = "Unknown", fish = { "Pumpkin Ray", "Festive Dolphin", "Wizard Stingray", "SPFin Shark", "Ancient Relic Crocodile", "Kraken", "Velastra", "Tralalero Tralala", "Plasma Serpent", "Great Christmas Whale", "Cursed Kraken", "Lochness Monster", "Cupid Octopus", "Fossilized Shark", "Thin Armor Shark", "Coral Reaper", "Cryoshade Glider", "Sacred Guardian Squid", "Disco Frogalloon", "Alligator Snapper", "Lake Sturgeon", "Frankenstein Longsnapper", "Sheriff Sawfish", "Pastel Easter Sawfish", "Crystal Crab", "Primal Lobster", "Pirate Blue Lobster", "King Jelly", "Sophisticated Angler", "Pumpkin Angler Fish", "Enchanted Turtle", "Classic UFO Turtle", "Gingerbread Turtle", "Abyss Seahorse", "Ancient Pufferfish", "Magma Piranha", "Disco Party Puffer", "Glowspore Toad", "King Frog", "Starbloom Jelly", "Lavafin Tuna", "Temple Spokes Tuna", "Runic Sea Crustacean" } },
    { rarity = "Mythic", fish = { "Orca", "Leviathan", "Naga", "King Crab", "Thunderzilla", "MACHODON", "Ragnarex", "Astrelle", "Crystalline Behemoth", "Trench Warden", "Caustic Maw", "Sea Eater", "1x1x1 Comet Shark", "Elshark Gran Maja", "ElRetro Gran Maja", "Emerald Winter Whale", "Starry Night Whale", "Ketupat Whale", "Blocky Lochness Monster", "Two-Headed Shark" } },
    { rarity = "Anomaly", fish = { "Starglass Guardian", "Viridis Lurker", "Void Leviathan", "Great Whale", "Dark Megalodon", "Cerulean Dragon", "Ancient Magma Whale" } },
}
local RARITIES, FISH_RARITY, ORDERED = {}, {}, {}
for _, g in ipairs(DATA) do
    RARITIES[#RARITIES + 1] = g.rarity
    for _, n in ipairs(g.fish) do FISH_RARITY[n] = g.rarity; ORDERED[#ORDERED + 1] = n end
end
local function fishOf(rarSet)   -- rarSet: { [rarity]=true }
    local out = {}
    for _, g in ipairs(DATA) do
        if rarSet[g.rarity] then for _, n in ipairs(g.fish) do out[#out + 1] = n end end
    end
    return out
end

-- ===== pengaturan =====
local CFG = { delay = 1, weight = 100000 }
local selRarity, selFish = {}, {}
local stats = { sent = 0, fail = 0, status = "idle" }
local run, running = 0, false
local hookPos = { -303.00714111328125, -39.849998474121094, 64.18134307861328 }

local remote
local function getRemote()
    if remote and remote.Parent then return remote end
    local fs = RS:FindFirstChild("FishingSystem") or RS:WaitForChild("FishingSystem", 5)
    remote = fs and (fs:FindFirstChild("FishGiver") or fs:WaitForChild("FishGiver", 5))
    return remote
end
local function vec(x, y, z)
    if vector and vector.create then return vector.create(x, y, z) end
    return Vector3.new(x, y, z)
end
local function give(name)
    local r = getRemote()
    if not r then stats.fail += 1; return false end
    local j = function() return (math.random() - 0.5) * 0.6 end
    local ok = pcall(function()
        r:FireServer({
            hookPosition = vec(hookPos[1] + j(), hookPos[2], hookPos[3] + j()),
            name = name,
            rarity = FISH_RARITY[name],
            weight = CFG.weight,
        })
    end)
    if ok then stats.sent += 1 else stats.fail += 1 end
    return ok
end

local function alive(id) return run == id end
local function wait(id, t)
    local t0 = os.clock()
    while os.clock() - t0 < t do task.wait(0.05); if not alive(id) then return false end end
    return true
end

local indexPos = 0
local function stopAll() run += 1; running = false; stats.status = "idle" end

-- Auto Fishing: acak dari ikan terpilih (kalau kosong: semua ikan di rarity terpilih)
local function startFishing()
    run += 1; running = true
    local id = run
    task.spawn(function()
        while alive(id) do
            local pool = {}
            for n in pairs(selFish) do pool[#pool + 1] = n end
            if #pool == 0 then pool = fishOf(selRarity) end
            if #pool == 0 then stats.status = "pilih rarity / ikan dulu"; task.wait(0.5)
            else
                local n = pool[math.random(#pool)]
                give(n)
                stats.status = "dapat " .. n .. " (" .. FISH_RARITY[n] .. ")"
                if not wait(id, CFG.delay) then break end
            end
        end
    end)
end

-- Auto Full Index: semua ikan, Common sampai Anomaly, sekali putaran
local function startIndex()
    run += 1; running = true
    local id = run
    task.spawn(function()
        for i, n in ipairs(ORDERED) do
            if not alive(id) then return end
            indexPos = i
            give(n)
            stats.status = ("index %d/%d: %s (%s)"):format(i, #ORDERED, n, FISH_RARITY[n])
            if not wait(id, CFG.delay) then return end
        end
        if alive(id) then
            running = false; stats.status = "index selesai (" .. #ORDERED .. " ikan)"
            N("Auto Full Index", "Selesai, semua " .. #ORDERED .. " ikan terkirim", "#50C864", 5)
        end
    end)
end

-- ===== UI =====
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "fish" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

local cFish = Main:AddCard({ Title = "Auto Fishing", Icon = "fish", Column = 1 })
local fishDD
cFish:Dropdown({
    Title = "Select Rarity", List = RARITIES, Multi = true, Value = {}, Placeholder = "Select rarity",
    Callback = function(v)
        selRarity = {}
        for _, r in ipairs(type(v) == "table" and v or { v }) do selRarity[r] = true end
        local list = fishOf(selRarity)
        if fishDD then pcall(function() fishDD:SetList(list) end) end
        -- buang ikan terpilih yang rarity-nya sudah tidak dipilih
        for n in pairs(selFish) do if not selRarity[FISH_RARITY[n]] then selFish[n] = nil end end
    end,
})
fishDD = cFish:Dropdown({
    Title = "Select Fish", List = {}, Multi = true, Value = {}, Placeholder = "Kosong = semua ikan di rarity",
    Callback = function(v)
        selFish = {}
        for _, n in ipairs(type(v) == "table" and v or { v }) do selFish[n] = true end
    end,
})
cFish:Toggle({
    Title = "Auto Fishing", Desc = "Kirim ikan dari rarity/ikan terpilih terus-menerus", id = "g15_fish",
    Callback = function(v)
        if v then startFishing() else stopAll() end
        N("Auto Fishing", v and "ON (matikan Auto Full Index dulu kalau aktif)" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cFish:Toggle({
    Title = "Auto Full Index", Desc = "Kirim semua ikan dari Common sampai Anomaly (1 putaran)", id = "g15_index",
    Callback = function(v)
        if v then startIndex() else stopAll() end
        N("Auto Full Index", v and "ON (matikan Auto Fishing dulu kalau aktif)" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

local cSet = Main:AddCard({ Title = "Settings", Icon = "sliders-horizontal", Column = 2 })
local function setDelay(v) local n = tonumber(v); if n and n >= 0.1 then CFG.delay = n end end
local sliderOk = pcall(function()
    cSet:Slider({
        Title = "Delay (detik)", id = "g15_delay",
        Min = 0.1, Max = 5, Default = 1, Value = 1, Step = 0.1, Increment = 0.1, Suffix = "s",
        Callback = setDelay,
    })
end)
if not sliderOk then
    cSet:Input({ Title = "Delay (detik)", Value = "1", Placeholder = "1", ButtonText = "Set", id = "g15_delay", Callback = setDelay, OnButton = setDelay })
end
cSet:Input({
    Title = "Weight", Value = tostring(CFG.weight), Placeholder = "100000", ButtonText = "Set", id = "g15_weight",
    Callback = function(v) local n = tonumber(v); if n and n > 0 then CFG.weight = n end end,
    OnButton = function(v) local n = tonumber(v); if n and n > 0 then CFG.weight = n; N("Weight", tostring(n), "#50C864") end end,
})

local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })
task.spawn(function()
    while true do
        pcall(function()
            stLbl:SetText("Status: " .. stats.status .. "\nTerkirim: " .. stats.sent .. "   Gagal: " .. stats.fail ..
                "\nTotal ikan index: " .. #ORDERED)
        end)
        task.wait(0.3)
    end
end)

W:OnUnload(function() run += 1 end)

for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildHome({ Game = "Fish Game", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then warn("[Sevoice] UI error: " .. tostring(err)); N("UI error", tostring(err), "#DC3232", 10) end
end

W:SelectPage("Main")
W:Ready()
W:OnBooted(function() N("Sevoice", "Fish Game loaded  ·  RCtrl buka/tutup", "#50C864", 4) end)
print("[Fish Game] Auto Fishing siap.")
