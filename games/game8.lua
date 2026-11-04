-- KatssinnnHub | Game 8 (Cut a Rock)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Fitur: Auto Collect Rock (pilih target) — logic farm dari V2 (sudah work):
--        scan semua Rooms, teleport berurutan antar room, collect lewat ProximityPrompt (instan),
--        fallback farm room penghasil target terbanyak. Max Backpack = counter internal.
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "Cut a Rock",
    Folder    = "KatssinnnHub/CutARock",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- ===== LOOP =====
local runId = { collect = 0 }
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

-- ===== DATA AWAL room (dipakai hanya kalau target belum pernah diambil, untuk tebak room terbaik) =====
local ROOM_TEXT = [[
Room_0: common_vein, common_vein, common_vein, common_vein, uncommon_vein, common_vein, common_vein, common_vein
Room_1: uncommon_vein, common_vein, uncommon_vein, common_vein, common_vein, uncommon_vein, uncommon_vein, common_vein
Room_2: uncommon_vein, uncommon_vein, common_vein, uncommon_vein, common_vein, uncommon_vein, uncommon_vein, common_vein
Room_3: uncommon_vein, rare_vein, common_vein, uncommon_vein, uncommon_vein, rare_vein, uncommon_vein, uncommon_vein
Room_4: rare_vein, uncommon_vein, elite_vein, rare_vein, uncommon_vein, uncommon_vein, rare_vein, elite_vein
Room_5: rare_vein, elite_vein, uncommon_vein, rare_vein, elite_vein, elite_vein, rare_vein, rare_vein
Room_6: elite_vein, elite_vein, rare_vein, elite_vein, elite_vein, elite_vein, rare_vein, rare_vein
Room_7: elite_vein, elite_vein, elite_vein, epic_vein, elite_vein, elite_vein, elite_vein, elite_vein
Room_8: epic_vein, elite_vein, epic_vein, elite_vein, epic_vein, epic_vein, epic_vein, elite_vein
Room_9: elite_vein, epic_vein, epic_vein, epic_vein, epic_vein, epic_vein, legendary_vein, legendary_vein
Room_10: legendary_vein, legendary_vein, legendary_vein, epic_vein, legendary_vein, epic_vein, legendary_vein, mythic_vein
Room_11: legendary_vein, epic_vein, legendary_vein, legendary_vein, epic_vein, epic_vein, legendary_vein, mythic_vein
Room_12: mythic_vein, divine_vein, legendary_vein, mythic_vein, legendary_vein, mythic_vein, mythic_vein, legendary_vein
Room_13: divine_vein, mythic_vein, mythic_vein, legendary_vein, mythic_vein, legendary_vein, divine_vein, mythic_vein
Room_14: mythic_vein, mythic_vein, divine_vein, ancient_vein, divine_vein, mythic_vein, divine_vein, mythic_vein
Room_15: divine_vein, divine_vein, mythic_vein, ancient_vein, ancient_vein, mythic_vein, mythic_vein, divine_vein
Room_16: ancient_vein, divine_vein, ancient_vein, divine_vein, ancient_vein, immortal_vein, divine_vein, divine_vein
Room_17: immortal_vein, ancient_vein, immortal_vein, ancient_vein, immortal_vein, ancient_vein, ancient_vein, ancient_vein
Room_18: eternal_vein, immortal_vein, ancient_vein, ancient_vein, immortal_vein, immortal_vein, eternal_vein, immortal_vein
Room_19: eternal_vein, eternal_vein, eternal_vein, immortal_vein, eternal_vein, immortal_vein, immortal_vein, ancient_vein
Room_20: eternal_vein, eternal_vein, eternal_vein, eternal_vein, immortal_vein, immortal_vein, immortal_vein, immortal_vein
Room_21: secret_vein, secret_vein, secret_vein, eternal_vein, immortal_vein, immortal_vein, eternal_vein, immortal_vein
Room_22: eternal_vein, secret_vein, eternal_vein, secret_vein, secret_vein, hidden_vein, eternal_vein, secret_vein
Room_23: secret_vein, eternal_vein, hidden_vein, secret_vein, hidden_vein, eternal_vein, secret_vein, hidden_vein
Room_24: secret_vein, hidden_vein, hidden_vein, hidden_vein, secret_vein, hidden_vein, hidden_vein, hidden_vein
Room_25: hidden_vein, forbidden_vein, forbidden_vein, hidden_vein, hidden_vein, hidden_vein, hidden_vein, hidden_vein
Room_26: forbidden_vein, forbidden_vein, unknown_vein, forbidden_vein, hidden_vein, unknown_vein, hidden_vein, unknown_vein
Room_27: forbidden_vein, hidden_vein, forbidden_vein, hidden_vein, forbidden_vein, forbidden_vein, forbidden_vein, forbidden_vein
Room_28: forbidden_vein, forbidden_vein, unknown_vein, forbidden_vein, unknown_vein, unknown_vein, ascended_vein, unknown_vein
Room_29: unknown_vein, unknown_vein, unknown_vein, unknown_vein, unknown_vein, unknown_vein, forbidden_vein, unknown_vein
Room_30: unknown_vein, cosmic_vein, ascended_vein, ascended_vein, ascended_vein, ascended_vein, ascended_vein, unknown_vein
Room_31: ascended_vein, ascended_vein, ascended_vein, ascended_vein, unknown_vein, ascended_vein, unknown_vein, unknown_vein
Room_32: cosmic_vein, ascended_vein, cosmic_vein, cosmic_vein, cosmic_vein, ascended_vein, ethereal_vein, cosmic_vein
Room_33: ascended_vein, ascended_vein, ethereal_vein, cosmic_vein, ethereal_vein, cosmic_vein, cosmic_vein, cosmic_vein
Room_34: cosmic_vein, ethereal_vein, ethereal_vein, ethereal_vein, ethereal_vein, primal_vein, ethereal_vein, cosmic_vein
Room_35: primal_vein, primal_vein, ethereal_vein, ethereal_vein, cosmic_vein, ethereal_vein, ethereal_vein, ethereal_vein
Room_36: ethereal_vein, primal_vein, ethereal_vein, ethereal_vein, ethereal_vein, primal_vein, ethereal_vein, ethereal_vein
Room_37: supreme_vein, supreme_vein, primal_vein, ethereal_vein, primal_vein, supreme_vein, ethereal_vein, ethereal_vein
Room_38: supreme_vein, supreme_vein, primal_vein, supreme_vein, primal_vein, primal_vein, supreme_vein, supreme_vein
Room_39: supreme_vein, supreme_vein, supreme_vein, supreme_vein, supreme_vein, supreme_vein, supreme_vein, supreme_vein, supreme_vein, supreme_vein, supreme_vein
]]
local ORDER = { "common", "uncommon", "rare", "elite", "epic", "legendary", "mythic", "divine", "ancient", "immortal",
    "eternal", "secret", "hidden", "forbidden", "unknown", "ascended", "cosmic", "ethereal", "primal", "supreme" }

local PRIOR = {}                       -- PRIOR[rarity][room] = jumlah di data awal
for line in ROOM_TEXT:gmatch("[^\n]+") do
    local rn = tonumber(line:match("Room_(%d+)"))
    if rn then
        for rar in line:gmatch("(%a+)_vein") do
            PRIOR[rar] = PRIOR[rar] or {}
            PRIOR[rar][rn] = (PRIOR[rar][rn] or 0) + 1
        end
    end
end

-- ============================================================
--  AUTO COLLECT ROCK (logic V2)
--  Struktur: workspace.Rooms.Room_0 .. Room_39 > Rocks > (model rock, nama = jenis vein)
-- ============================================================
local SCAN_INTERVAL = 1        -- detik, scan ulang semua Rooms
local ROOM_FIRST, ROOM_LAST = 0, 39
local TARGET_VEIN = "supreme_vein"   -- diganti lewat dropdown
local HOP_WAIT = 0.15          -- jeda tiap teleport 1 room (beri waktu room ter-load)
local COLLECT_WAIT = 0.2       -- jeda setelah teleport ke rock sebelum collect
local FARM_HOP_WAIT = 0.12     -- jeda antar rock saat farm room terbaik

local maxBackpack = 10
local collected = 0
local Stats = { status = "-" }
local historyByTarget = {}         -- [targetName][roomIndex] = jumlah target yang sudah diambil dari room itu
local roomCentroid = {}            -- [roomIndex] = Vector3 rata-rata posisi rock di room itu
local rocksByRoom = {}             -- [roomIndex] = { rockInstance, ... }
local supremeList = {}             -- daftar rock TARGET hasil scan terakhir (nama lama dipertahankan dari V2)

local roomsFolder = workspace:FindFirstChild("Rooms") or workspace:WaitForChild("Rooms", 10)
local warnedNoPrompt = false

local function Hist()
    historyByTarget[TARGET_VEIN] = historyByTarget[TARGET_VEIN] or {}
    return historyByTarget[TARGET_VEIN]
end

local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function TP(pos)
    local hrp = Root()
    if not (hrp and pos) then return false end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
    pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    return true
end

local function RockPos(inst)
    if inst:IsA("Model") then
        local ok, cf = pcall(function() return inst:GetPivot() end)
        if ok and cf then return cf.Position end
        if inst.PrimaryPart then return inst.PrimaryPart.Position end
    elseif inst:IsA("BasePart") then
        return inst.Position
    end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("BasePart") then return d.Position end
    end
    return nil
end
local function FindPrompt(inst)
    if inst:IsA("ProximityPrompt") then return inst end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("ProximityPrompt") then return d end
    end
    return nil
end

local function Scan()
    table.clear(supremeList)
    table.clear(roomCentroid)
    table.clear(rocksByRoom)
    if not roomsFolder then return end
    for i = ROOM_FIRST, ROOM_LAST do
        local room = roomsFolder:FindFirstChild("Room_" .. i)
        if room then
            local rocksFolder = room:FindFirstChild("Rocks")
            if rocksFolder then
                local sum, n = Vector3.zero, 0
                local list = {}
                for _, rk in ipairs(rocksFolder:GetChildren()) do
                    local pos = RockPos(rk)
                    if pos then
                        sum += pos
                        n += 1
                        list[#list + 1] = rk
                        if rk.Name == TARGET_VEIN then
                            local prompt = FindPrompt(rk)
                            if prompt then
                                supremeList[#supremeList + 1] = { inst = rk, pos = pos, prompt = prompt, room = i }
                            end
                        end
                    end
                end
                rocksByRoom[i] = list
                if n > 0 then roomCentroid[i] = sum / n end
            end
        end
    end
end
task.spawn(function()
    while W.Alive do
        pcall(Scan)
        task.wait(SCAN_INTERVAL)
    end
end)

local function Collect(prompt)
    if typeof(fireproximityprompt) ~= "function" then
        if not warnedNoPrompt then
            warnedNoPrompt = true
            N("Auto Collect", "Executor tidak punya fireproximityprompt: tidak bisa auto-collect", "#DC3232", 6)
        end
        return false
    end
    pcall(function() prompt.HoldDuration = 0 end)
    return pcall(fireproximityprompt, prompt, 0)
end

local function NearestRoomIndex(pos)
    local best, bd
    for i, c in pairs(roomCentroid) do
        local d = (c - pos).Magnitude
        if not bd or d < bd then best, bd = i, d end
    end
    return best
end
local function HopToRoom(id, targetRoom)
    local hrp = Root()
    if not hrp then return end
    local cur = NearestRoomIndex(hrp.Position) or targetRoom
    local step = targetRoom >= cur and 1 or -1
    for i = cur, targetRoom, step do
        if runId.collect ~= id then return end
        local c = roomCentroid[i]
        if c then
            TP(c)
            task.wait(HOP_WAIT)
        end
    end
end

-- room penghasil target terbanyak: dari riwayat ambil; kalau belum ada riwayat, tebak dari data awal; terakhir room terakhir
local function BestHistoryRoom()
    local bestRoom, bestN
    for i, n in pairs(Hist()) do
        if not bestN or n > bestN then bestRoom, bestN = i, n end
    end
    if bestRoom then return bestRoom end
    local rar = TARGET_VEIN:match("^(%a+)_vein$")
    local pr = rar and PRIOR[rar]
    if pr then
        for i, n in pairs(pr) do
            if not bestN or n > bestN then bestRoom, bestN = i, n end
        end
    end
    return bestRoom or ROOM_LAST
end

local function CollectStep(id)
    if collected >= maxBackpack then
        Stats.status = string.format("tas penuh (%d/%d) — tekan Reset Counter setelah jual/kosongkan di game", collected, maxBackpack)
        task.wait(1)
        return
    end

    if #supremeList > 0 then
        local target = supremeList[1]
        Stats.status = "menuju " .. TARGET_VEIN .. " di Room_" .. target.room
        HopToRoom(id, target.room)
        if runId.collect ~= id then return end
        TP(target.pos)
        task.wait(COLLECT_WAIT)
        if Collect(target.prompt) then
            collected += 1
            local h = Hist()
            h[target.room] = (h[target.room] or 0) + 1
            Stats.status = string.format("ambil %s (%d/%d) · Room_%d", TARGET_VEIN, collected, maxBackpack, target.room)
        else
            Stats.status = "gagal collect, coba lagi..."
        end
        return
    end

    local bestRoom = BestHistoryRoom()
    Stats.status = TARGET_VEIN .. " habis, menuju Room_" .. bestRoom .. " (penghasil terbanyak)"
    HopToRoom(id, bestRoom)
    if runId.collect ~= id then return end

    local list = rocksByRoom[bestRoom] or {}
    for _, rk in ipairs(list) do
        if runId.collect ~= id or collected >= maxBackpack then return end
        if rk.Parent then          -- rock bisa hilang selagi loop (sudah di-collect / respawn)
            local pos = RockPos(rk)
            local prompt = FindPrompt(rk)
            if pos and prompt then
                TP(pos)
                task.wait(FARM_HOP_WAIT)
                if Collect(prompt) then
                    collected += 1
                    if rk.Name == TARGET_VEIN then
                        local h = Hist()
                        h[bestRoom] = (h[bestRoom] or 0) + 1
                        Stats.status = string.format("ambil %s (%d/%d) · Room_%d", TARGET_VEIN, collected, maxBackpack, bestRoom)
                    else
                        Stats.status = string.format("farm Room_%d: ambil %s (%d/%d)", bestRoom, rk.Name, collected, maxBackpack)
                    end
                end
            end
        end
    end
end

-- ===== UI =====
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "gem" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

local cConfig = Main:AddCard({ Title = "Konfigurasi", Icon = "settings", Column = 1 })
local targetList = {}
for _, r in ipairs(ORDER) do targetList[#targetList + 1] = r .. "_vein" end
cConfig:Dropdown({
    Title = "Target rock", List = targetList, Value = "supreme_vein", id = "cr_target",
    Callback = function(v)
        if not v then return end
        TARGET_VEIN = tostring(v)
        pcall(Scan)
    end,
})
cConfig:Input({
    Title = "Max Backpack", Value = tostring(maxBackpack), Placeholder = "mis. 10",
    ButtonText = "Set", id = "cr_maxbag",
    Callback = function(v)
        local n = tonumber(v)
        if n and n > 0 then maxBackpack = math.floor(n) end
    end,
    OnButton = function(v)
        local n = tonumber(v)
        if n and n > 0 then
            maxBackpack = math.floor(n)
            N("Max Backpack", "Diset ke " .. maxBackpack, "#50C864")
        end
    end,
})
cConfig:Button({
    Title = "Reset Counter", Text = "Reset Counter (setelah jual/kosongkan tas)",
    Callback = function()
        collected = 0
        N("Reset Counter", "Counter dikembalikan ke 0", "#50C864")
    end,
})

local cAuto = Main:AddCard({ Title = "Auto Collect Rock", Icon = "pickaxe", Column = 1 })
local tgCollect = cAuto:Toggle({
    Title = "Auto Collect Rock", Desc = "Scan semua Rooms, kejar rock target, fallback ke room penghasil terbanyak", id = "cr_auto",
    Expand = true,
    Callback = function(v)
        Loop("collect", v, function() return 0.1 end, CollectStep)
        if not v then Stats.status = "-" end
        N("Auto Collect Rock", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgCollect:Sub(function(c)
    c:Slider({
        Title = "Jeda tiap teleport antar room (s)", Min = 0.05, Max = 1, Value = HOP_WAIT, Rounding = 2, Suffix = "s", id = "cr_hopwait",
        Callback = function(v) HOP_WAIT = v end,
    })
    c:Slider({
        Title = "Scan ulang Rooms tiap (s)", Min = 0.5, Max = 5, Value = SCAN_INTERVAL, Rounding = 1, Suffix = "s", id = "cr_scanint",
        Callback = function(v) SCAN_INTERVAL = v end,
    })
end)

local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })

task.spawn(function()
    while W.Alive do
        task.wait(0.5)
        pcall(function()
            local parts = {}
            for i, n in pairs(Hist()) do parts[#parts + 1] = string.format("Room_%d=%d", i, n) end
            table.sort(parts)
            local txt = "Status: " .. Stats.status ..
                "\nTarget: " .. TARGET_VEIN ..
                "\nCollected: " .. collected .. " / " .. maxBackpack ..
                "\nRiwayat target: " .. (#parts > 0 and table.concat(parts, ", ") or "-")
            stLbl:SetText(txt)
        end)
    end
end)

-- hentikan semua saat Unload
W:OnUnload(function()
    runId.collect += 1
end)

-- Player dan Home (+ Settings) ada di ui.lua; tiap bagian aman dari error.
for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildHome({ Game = "Cut a Rock", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[KatssinnnHub] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()
W:OnBooted(function() N("KatssinnnHub", "Cut a Rock dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4) end)
