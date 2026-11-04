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
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

-- ===== LOOP =====
local runId = { collect = 0, sell = 0, cut = 0, stone = 0, tp = 0 }
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
local HOP_UP = 12              -- tinggi pendaratan saat teleport antar room (stud di atas titik tengah room) supaya tidak tembus lantai
local COLLECT_WAIT = 0.35      -- jeda setelah teleport ke rock sebelum collect (diperlambat supaya rock pasti ke-collect)
local FARM_HOP_WAIT = 0.12     -- jeda setelah berhasil collect 1 rock
local COOLDOWN = 8             -- detik: posisi rock yang baru diambil dihindari (rock bisa respawn di tempat yang sama)
local COOL_RADIUS = 6          -- stud: rock dalam radius ini dari posisi yang baru diambil dianggap "tempat yang sama"
local cooled = {}              -- { {pos = Vector3, t = os.clock()} }

local function MarkCooled(pos)
    cooled[#cooled + 1] = { pos = pos, t = os.clock() }
end
local function IsCooled(pos)
    local now = os.clock()
    for i = #cooled, 1, -1 do
        local c = cooled[i]
        if now - c.t > COOLDOWN then
            table.remove(cooled, i)
        elseif (c.pos - pos).Magnitude <= COOL_RADIUS then
            return true
        end
    end
    return false
end

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
local function TP(pos, up)                     -- up = tinggi di atas titik tujuan (default 4)
    local hrp = Root()
    if not (hrp and pos) then return false end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, up or 4, 0))
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

local function Collect(prompt, alt)
    if typeof(fireproximityprompt) ~= "function" then
        if not warnedNoPrompt then
            warnedNoPrompt = true
            N("Auto Collect", "Executor tidak punya fireproximityprompt: tidak bisa auto-collect", "#DC3232", 6)
        end
        return false
    end
    pcall(function() prompt.HoldDuration = 0 end)
    if alt then pcall(fireproximityprompt, prompt) end      -- percobaan ke-3 dst: pakai pemanggilan default juga
    return pcall(fireproximityprompt, prompt, 0)
end

-- ===== TAS: dibaca dari PlayerGui.MainHUD.CepBar.Sayi (teks "0/10") =====
local PG = LP:WaitForChild("PlayerGui")
local sayiLbl
local function BagInfo()                -- return (isi, kapasitas); kalau Sayi tidak ketemu pakai counter internal
    if not (sayiLbl and sayiLbl.Parent) then
        sayiLbl = nil
        local hud = PG:FindFirstChild("MainHUD")
        local bar = hud and hud:FindFirstChild("CepBar", true)
        sayiLbl = bar and bar:FindFirstChild("Sayi", true)
    end
    if sayiLbl then
        local a, b = tostring(sayiLbl.Text):match("(%d+)%s*/%s*(%d+)")
        if a and b then
            Stats.bagSrc = "Sayi"
            return tonumber(a), tonumber(b)
        end
    end
    Stats.bagSrc = "counter"
    return collected, maxBackpack
end

-- Ambil 1 rock dengan verifikasi: TP -> tunggu -> fire prompt -> cek isi tas (Sayi) naik / rock hilang. Ulangi kalau belum kena.
local function TryCollect(id, inst, prompt, pos)
    local before = BagInfo()
    for attempt = 1, 5 do
        if runId.collect ~= id then return false end
        if not (inst.Parent and prompt.Parent) then break end
        TP(pos)
        task.wait(COLLECT_WAIT)
        if not Collect(prompt, attempt >= 3) then return false end
        local t = 0
        while t < 0.8 do
            task.wait(0.05)
            t += 0.05
            local now = BagInfo()
            if Stats.bagSrc == "Sayi" then
                if now > before then return true end
            elseif not inst.Parent or not prompt.Parent or not prompt.Enabled then
                collected += 1
                return true
            end
        end
    end
    return false
end

local function NearestRoomIndex(pos)
    local best, bd
    for i, c in pairs(roomCentroid) do
        local d = (c - pos).Magnitude
        if not bd or d < bd then best, bd = i, d end
    end
    return best
end
local function HopToRoom(id, targetRoom, key)     -- key = nama runId yang dicek untuk membatalkan (default: farm)
    key = key or "collect"
    local hrp = Root()
    if not hrp then return end
    local cur = NearestRoomIndex(hrp.Position) or targetRoom
    local step = targetRoom >= cur and 1 or -1
    for i = cur, targetRoom, step do
        if runId[key] ~= id then return end
        local c = roomCentroid[i]
        if c then
            TP(c, HOP_UP)
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
    local cur, mx = BagInfo()
    if cur >= mx then
        Stats.status = string.format("tas penuh (%d/%d)", cur, mx)
        task.wait(1)
        return
    end

    -- 1) rock target yang BUKAN di posisi yang baru diambil (room terdekat dulu, lalu jarak terdekat)
    local hrp = Root()
    local curRoom = hrp and NearestRoomIndex(hrp.Position)
    local target, bs
    for _, t in ipairs(supremeList) do
        if t.inst.Parent and not IsCooled(t.pos) then
            local s = math.abs(t.room - (curRoom or t.room)) * 100000 + (hrp and (t.pos - hrp.Position).Magnitude or 0)
            if not bs or s < bs then target, bs = t, s end
        end
    end

    if target then
        Stats.status = "menuju " .. TARGET_VEIN .. " di Room_" .. target.room
        HopToRoom(id, target.room)
        if runId.collect ~= id then return end
        local ok = TryCollect(id, target.inst, target.prompt, target.pos)
        MarkCooled(target.pos)                 -- berhasil / gagal: jangan kembali ke posisi ini dulu
        if ok then
            local h = Hist()
            h[target.room] = (h[target.room] or 0) + 1
            local c2, m2 = BagInfo()
            Stats.status = string.format("ambil %s (%d/%d) · Room_%d", TARGET_VEIN, c2, m2, target.room)
            task.wait(FARM_HOP_WAIT)
        else
            Stats.status = "gagal collect, cari rock lain..."
        end
        return
    end

    -- 2) target tidak ada (atau semuanya baru diambil): ambil 1 rock lain di room penghasil terbanyak
    local bestRoom = BestHistoryRoom()
    Stats.status = TARGET_VEIN .. " tidak ada, menuju Room_" .. bestRoom .. " (penghasil terbanyak)"
    HopToRoom(id, bestRoom)
    if runId.collect ~= id then return end

    local rp = Root()
    local pick, pd
    for _, rk in ipairs(rocksByRoom[bestRoom] or {}) do
        if rk.Parent then
            local pos = RockPos(rk)
            local prompt = FindPrompt(rk)
            if pos and prompt and not IsCooled(pos) then
                local d = rp and (pos - rp.Position).Magnitude or 0
                if not pd or d < pd then pick, pd = { inst = rk, pos = pos, prompt = prompt }, d end
            end
        end
    end
    if not pick then
        Stats.status = "semua rock di Room_" .. bestRoom .. " baru diambil, jeda..."
        task.wait(0.5)
        return
    end

    local name = pick.inst.Name
    local ok = TryCollect(id, pick.inst, pick.prompt, pick.pos)
    MarkCooled(pick.pos)
    if ok then
        local c2, m2 = BagInfo()
        if name == TARGET_VEIN then
            local h = Hist()
            h[bestRoom] = (h[bestRoom] or 0) + 1
        end
        Stats.status = string.format("farm Room_%d: ambil %s (%d/%d)", bestRoom, name, c2, m2)
        task.wait(FARM_HOP_WAIT)
    end
end

-- ============================================================
--  AUTO SELL ALL + AUTO CUT ROCKS
--   * Sell  : ReplicatedStorage.SellEvent:FireServer("SellAll")
--   * Cut   : ReplicatedStorage.PlaceStoneInMachineEvent:FireServer(<model mesin>, <uuid item>)
--             mesin = model bernama level<angka> di FinalBaseModel MILIKMU (Bases berisi banyak FinalBaseModel; pemilik dideteksi, cadangan: urutan ke-N)
--   * Collect Cut Stone (toggle terpisah): teleport hanya ke mesin yang prompt-nya "Collect" (ready); mesin "Cutting..." cukup ditunggu.
-- ============================================================
local machineBusy, farmInStep, farmOn = false, false, false   -- kunci supaya farm rock & urusan mesin tidak teleport bersamaan
local SELL_INTERVAL, CUT_INTERVAL, STONE_INTERVAL = 10, 4, 5
local STONE_RETRY = 1                      -- detik: mesin yang baru di-collect tidak di-collect lagi sebelum jeda ini (anti spam)
local BASE_INDEX = 1                       -- urutan FinalBaseModel milikmu (1 = paling atas) kalau pemilik tidak terdeteksi otomatis
local placedAt = {}                            -- [uuid] = waktu terakhir diletakkan ke mesin

local function SellAll()
    local ev = RS:FindFirstChild("SellEvent")
    if not ev then return false end
    if pcall(ev.FireServer, ev, "SellAll") then
        Stats.sold = (Stats.sold or 0) + 1
        return true
    end
    return false
end

local UUID_PAT = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
local function IsUuid(s) return type(s) == "string" and s:match(UUID_PAT) ~= nil end
local function UuidIn(o)
    if IsUuid(o.Name) then return o.Name end
    for _, v in pairs(o:GetAttributes()) do if IsUuid(v) then return v end end
    if o:IsA("StringValue") and IsUuid(o.Value) then return o.Value end
end
local seenUuids = {}                           -- [uuid] = waktu; uuid yang pernah lewat di RemoteEvent masuk (server -> client)
local function NoteUuids(v, depth)
    local t = typeof(v)
    if t == "string" then
        if IsUuid(v) then seenUuids[v] = os.clock() end
    elseif t == "table" and depth < 4 then
        for k, x in pairs(v) do NoteUuids(k, depth + 1); NoteUuids(x, depth + 1) end
    elseif t == "Instance" then
        if IsUuid(v.Name) then seenUuids[v.Name] = os.clock() end
        for _, a in pairs(v:GetAttributes()) do NoteUuids(a, depth + 1) end
    end
end
pcall(function()
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") then
            pcall(function() d.OnClientEvent:Connect(function(...) NoteUuids({ ... }, 0) end) end)
        end
    end
end)
local function PoolCount()
    local n = 0
    for _ in pairs(seenUuids) do n += 1 end
    return n
end

local function BagUuids()                      -- uuid item: GUI/data player + karakter, lalu yang tertangkap dari RemoteEvent (terbaru dulu)
    local set, list = {}, {}
    local function add(u) if not set[u] then set[u] = true; list[#list + 1] = u end end
    local function scan(root)
        if not root then return end
        local n = 0
        for _, d in ipairs(root:GetDescendants()) do
            n += 1
            if n % 2000 == 0 then task.wait() end
            local u = UuidIn(d)
            if u then add(u) end
        end
    end
    scan(LP)
    scan(LP.Character)
    for _, c in ipairs(RS:GetChildren()) do
        if c.Name == LP.Name or c.Name == tostring(LP.UserId) then scan(c) end
    end
    local pool = {}
    for u, t in pairs(seenUuids) do if not set[u] then pool[#pool + 1] = { u, t } end end
    table.sort(pool, function(a, b) return a[2] > b[2] end)
    for _, e in ipairs(pool) do add(e[1]) end
    return list
end

local function OwnerMatch(o)                 -- apakah attribute / value ini menandakan pemilik = kita
    for _, v in pairs(o:GetAttributes()) do
        if v == LP.UserId or v == LP.Name or v == LP.DisplayName or tostring(v) == tostring(LP.UserId) then return true end
    end
    if o:IsA("StringValue") and (o.Value == LP.Name or o.Value == LP.DisplayName or o.Value == tostring(LP.UserId)) then return true end
    if o:IsA("IntValue") and o.Value == LP.UserId then return true end
    if o:IsA("ObjectValue") and o.Value == LP then return true end
    return false
end

local busyUntil = setmetatable({}, { __mode = "k" })     -- [mesin] = waktu sampai kapan dianggap baru diisi (anti spam remote)
local collectedAt = setmetatable({}, { __mode = "k" })   -- [mesin] = waktu terakhir di-collect (anti spam teleport)

local function IsMine(bs)                      -- pemilik = kita? (attribute / value di base atau anak langsungnya)
    if OwnerMatch(bs) then return true end
    for _, c in ipairs(bs:GetChildren()) do
        if OwnerMatch(c) then return true end
    end
    return false
end

local function GetBase()                       -- workspace.Models.Bases.FinalBaseModel (ada banyak: punya pemain lain juga)
    local m = workspace:FindFirstChild("Models")
    local b = m and m:FindFirstChild("Bases")
    if not b then return nil end
    local bases = {}
    for _, c in ipairs(b:GetChildren()) do
        if c.Name == "FinalBaseModel" then bases[#bases + 1] = c end
    end
    for i, bs in ipairs(bases) do
        if IsMine(bs) then return bs, "auto (#" .. i .. ")" end
    end
    local idx = math.min(BASE_INDEX, #bases)
    return bases[idx], "urutan #" .. idx
end

local function GetMachines()                   -- model level<angka> di base milikmu
    local base, how = GetBase()
    local list = {}
    if base then
        for _, c in ipairs(base:GetChildren()) do
            if c.Name:lower():match("^level%d+$") then list[#list + 1] = c end
        end
    end
    Stats.baseInfo = (base and how or "base tidak ketemu")
    return list
end

-- status mesin dari ProximityPrompt-nya:
--   "ready"   = ada prompt aksi "Collect" yang aktif (Cut Stone siap diambil)
--   "cutting" = ada prompt "Cutting..." -> tinggal tunggu, jangan disentuh (prompt itu aksi Upgrade)
--   "idle"    = tidak sedang cutting, siap diisi batu
local function MachineState(m)
    local readyPr, cutting
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local a = tostring(d.ActionText or ""):lower()
            if a:find("collect") then
                if d.Enabled then readyPr = readyPr or d end
            elseif a:find("cutting") then
                cutting = true
            end
        end
    end
    if readyPr then return "ready", readyPr end
    if cutting then return "cutting" end
    return "idle"
end

local function PromptPos(pr)
    local p = pr.Parent
    if p and p:IsA("BasePart") then return p.Position end
    if p and p:IsA("Attachment") then return p.WorldPosition end
    local mdl = pr:FindFirstAncestorOfClass("Model")
    return mdl and RockPos(mdl)
end

-- UUID batu: PlayerGui.CuttingMenu.MainFrame.Tepsi.Izgara (anak-anaknya bernama uuid = semua batu, termasuk yang di tas).
-- Cadangan kalau menu itu tidak ada: scan umum.
local function CutUuids()
    local gui = PG:FindFirstChild("CuttingMenu")
    local mf = gui and gui:FindFirstChild("MainFrame")
    local tepsi = mf and mf:FindFirstChild("Tepsi")
    local izgara = tepsi and tepsi:FindFirstChild("Izgara")
    if izgara then
        local list = {}
        for _, c in ipairs(izgara:GetChildren()) do
            if IsUuid(c.Name) then list[#list + 1] = c.Name end
        end
        return list, "Izgara"
    end
    return BagUuids(), "scan umum"
end

-- AUTO CUT: isi mesin dari batu di tas terus-menerus sampai habis (remote, tanpa teleport).
-- Berhasil = uuid itu HILANG dari Izgara (tidak bergantung pada teks prompt mesin).
-- Mesin yang menolak (masih cutting / baru diisi game) di-backoff supaya tidak spam remote; mesin "ready" (ada stone
-- yang belum di-collect) dilewati. Uuid hanya dianggap bermasalah sementara (60 detik), bukan permanen.
local uuidFail, uuidFailAt, machineFail = {}, {}, {}
local function CutCycle(id)
    local machines = GetMachines()
    if #machines == 0 then Stats.cutStatus = "mesin (level*) tidak ketemu"; return end
    local rem = RS:FindFirstChild("PlaceStoneInMachineEvent")
    if not rem then Stats.cutStatus = "remote PlaceStoneInMachineEvent tidak ada"; return end

    local list, src = CutUuids()
    local now = os.clock()
    local pending = {}
    for _, u in ipairs(list) do
        if (uuidFail[u] or 0) >= 2 and now - (uuidFailAt[u] or 0) > 60 then uuidFail[u] = 0 end
        if (uuidFail[u] or 0) < 2 then pending[#pending + 1] = u end
    end
    if #pending == 0 then Stats.cutStatus = "tidak ada batu untuk di-cut (" .. src .. ": " .. #list .. " uuid)"; return end

    local step = (src == "Izgara") and 0.2 or 0.6
    local n, ui, skipped = 0, 1, 0
    for _, m in ipairs(machines) do
        if runId.cut ~= id or ui > #pending then break end
        local st = MachineState(m)
        if st == "ready" or (busyUntil[m] or 0) > os.clock() then
            skipped += 1
        else
            local u = pending[ui]
            ui += 1
            pcall(rem.FireServer, rem, m, u)
            local gone, t = false, 0
            while t < 2 do                                   -- tunggu uuid hilang dari daftar batu
                task.wait(step)
                t += step
                local cur = (src == "Izgara") and (CutUuids()) or BagUuids()
                local still = false
                for _, x in ipairs(cur) do if x == u then still = true; break end end
                if not still then gone = true; break end
            end
            if gone then
                n += 1
                machineFail[m] = 0
                busyUntil[m] = os.clock() + 2
            else
                if st == "idle" then                         -- mesin kelihatan kosong tapi uuid ditolak -> curigai uuid-nya
                    uuidFail[u] = (uuidFail[u] or 0) + 1
                    uuidFailAt[u] = os.clock()
                end
                machineFail[m] = (machineFail[m] or 0) + 1
                local base = (st == "idle") and 3 or 8
                busyUntil[m] = os.clock() + math.min(base * machineFail[m], 20)
                skipped += 1
            end
        end
    end
    Stats.cut = (Stats.cut or 0) + n
    Stats.cutStatus = "diletakkan " .. n .. " batu · dilewati " .. skipped .. " mesin · sisa di tas " .. math.max(#list - n, 0) .. " (" .. src .. ")"
end

-- AUTO COLLECT CUT STONE: hanya teleport kalau ada mesin yang benar-benar "ready"; kalau semua masih Cutting... cukup menunggu.
local function CollectStoneCycle(id)
    local machines = GetMachines()
    if #machines == 0 then Stats.stoneStatus = "mesin (level*) tidak ketemu"; return end

    local now = os.clock()
    local ready, cutting = {}, 0
    for _, m in ipairs(machines) do
        local st, pr = MachineState(m)
        if st == "ready" and (collectedAt[m] or 0) + STONE_RETRY <= now then
            ready[#ready + 1] = { m = m, pr = pr }
        elseif st == "cutting" then
            cutting += 1
        end
    end
    if #ready == 0 then
        Stats.stoneStatus = cutting > 0 and ("menunggu " .. cutting .. " mesin cutting...") or "tidak ada Cut Stone siap"
        return
    end

    machineBusy = true
    local t = 0
    while farmInStep and t < 5 do t += task.wait(0.05) end      -- tunggu langkah farm rock yang sedang jalan
    local ok, err = pcall(function()
        local got = 0
        for _, r in ipairs(ready) do
            if runId.stone ~= id then break end
            local pr = r.pr
            local pos = pr.Parent and PromptPos(pr)
            if pos then
                Stats.stoneStatus = "collect Cut Stone " .. (got + 1) .. "/" .. #ready
                TP(pos)                                         -- 1x teleport per mesin
                task.wait(0.3)
                Collect(pr, false)
                task.wait(0.4)
                if pr.Parent and pr.Enabled and tostring(pr.ActionText or ""):lower():find("collect") then
                    Collect(pr, true)                           -- masih belum kena: coba sekali lagi saja
                    task.wait(0.4)
                end
                collectedAt[r.m] = os.clock()
                got += 1
            end
        end
        Stats.stone = (Stats.stone or 0) + got
        Stats.stoneStatus = "collect " .. got .. " mesin"
    end)
    machineBusy = false
    if not ok then warn("[stone] " .. tostring(err)) end
end

-- farm rock dibungkus supaya tidak jalan saat mesin sedang diurus
local function FarmTick(id)
    if machineBusy then Stats.status = "mengurus mesin..."; task.wait(0.2); return end
    farmInStep = true
    local ok, err = pcall(CollectStep, id)
    farmInStep = false
    if not ok then warn("[collect] " .. tostring(err)) end
end

-- ===== UI =====
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "pickaxe" })
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
    Title = "Max Backpack (cadangan jika Sayi tak terbaca)", Value = tostring(maxBackpack), Placeholder = "mis. 10",
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
        farmOn = v
        Loop("collect", v, function() return 0.1 end, FarmTick)
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
        Title = "Jeda posisi rock yang baru diambil (s)", Min = 2, Max = 30, Value = COOLDOWN, Rounding = 0, Suffix = "s", id = "cr_cooldown",
        Callback = function(v) COOLDOWN = v end,
    })
    c:Slider({
        Title = "Tinggi pendaratan antar room (stud)", Min = 4, Max = 40, Value = HOP_UP, Rounding = 0, id = "cr_hopup",
        Callback = function(v) HOP_UP = v end,
    })
    c:Slider({
        Title = "Jeda sebelum collect (s)", Min = 0.1, Max = 1, Value = COLLECT_WAIT, Rounding = 2, Suffix = "s", id = "cr_collectwait",
        Callback = function(v) COLLECT_WAIT = v end,
    })
    c:Slider({
        Title = "Scan ulang Rooms tiap (s)", Min = 0.5, Max = 5, Value = SCAN_INTERVAL, Rounding = 1, Suffix = "s", id = "cr_scanint",
        Callback = function(v) SCAN_INTERVAL = v end,
    })
end)

-- ---------- Teleport Room (manual, buat ambil rock limited) ----------
-- Pakai logic teleport yang sama dengan Auto Farm: hop berurutan antar room lewat titik tengah tiap room.
local TP_ROOM = 39
local tpBusy = false
local roomList = {}
for i = ROOM_FIRST, ROOM_LAST do roomList[#roomList + 1] = "Room_" .. i end
local cTp = Main:AddCard({ Title = "Teleport Room", Icon = "scan", Column = 1 })
cTp:Dropdown({
    Title = "Room tujuan", List = roomList, Value = "Room_" .. TP_ROOM, id = "cr_tproom",
    Callback = function(v)
        local n = tonumber(tostring(v):match("(%d+)"))
        if n then TP_ROOM = n end
    end,
})
cTp:Button({
    Title = "Teleport ke room", Text = "Teleport ke room terpilih",
    Callback = function()
        if tpBusy then return end
        if farmOn then
            N("Teleport Room", "Matikan Auto Farm dulu supaya kamu tidak ditarik pergi", "#FFA500", 4)
            return
        end
        if not roomCentroid[TP_ROOM] then
            N("Teleport Room", "Room_" .. TP_ROOM .. " belum ter-scan (belum termuat)", "#DC3232", 4)
            return
        end
        tpBusy = true
        runId.tp += 1
        local id = runId.tp
        task.spawn(function()
            local t = 0
            while machineBusy and t < 8 do t += task.wait(0.1) end    -- tunggu urusan mesin selesai dulu
            Stats.status = "teleport ke Room_" .. TP_ROOM
            local ok, err = pcall(HopToRoom, id, TP_ROOM, "tp")
            tpBusy = false
            if ok then
                Stats.status = "di Room_" .. TP_ROOM
                N("Teleport Room", "Sampai di Room_" .. TP_ROOM, "#50C864")
            else
                warn("[tp] " .. tostring(err))
            end
        end)
    end,
})

-- ---------- Auto Sell & Auto Cut ----------
local cSell = Main:AddCard({ Title = "Auto Sell All", Icon = "coins", Column = 2 })
local tgSell = cSell:Toggle({
    Title = "Auto Sell All", Desc = "Kirim SellEvent 'SellAll' berkala", id = "cr_sell", Expand = true,
    Callback = function(v)
        Loop("sell", v, function() return SELL_INTERVAL end, function() SellAll() end)
        N("Auto Sell All", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgSell:Sub(function(c)
    c:Slider({
        Title = "Jual tiap (s)", Min = 2, Max = 60, Value = SELL_INTERVAL, Rounding = 0, Suffix = "s", id = "cr_sellint",
        Callback = function(v) SELL_INTERVAL = v end,
    })
end)
cSell:Button({
    Title = "Sell All sekarang", Text = "Sell All sekarang",
    Callback = function()
        local ok = SellAll()
        N("Sell All", ok and "Terkirim" or "SellEvent tidak ketemu", ok and "#6495ED" or "#DC3232")
    end,
})

local cCut = Main:AddCard({ Title = "Auto Cut Rocks", Icon = "pickaxe", Column = 2 })
local tgCut = cCut:Toggle({
    Title = "Auto Cut Rocks", Desc = "Letakkan batu dari tas ke semua mesin level*", id = "cr_cut", Expand = true,
    Callback = function(v)
        Loop("cut", v, function() return CUT_INTERVAL end, CutCycle)
        if not v then Stats.cutStatus = "-" end
        N("Auto Cut Rocks", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgCut:Sub(function(c)
    c:Slider({
        Title = "Base ke- (cadangan jika pemilik tak terdeteksi)", Min = 1, Max = 8, Value = BASE_INDEX, Rounding = 0, id = "cr_baseidx",
        Callback = function(v) BASE_INDEX = v end,
    })
    c:Slider({
        Title = "Siklus cut tiap (s)", Min = 0.1, Max = 30, Value = CUT_INTERVAL, Rounding = 0, Suffix = "s", id = "cr_cutint",
        Callback = function(v) CUT_INTERVAL = v end,
    })
end)
cCut:Button({
    Title = "Cek base, mesin & UUID (print)", Text = "Cek base, mesin & UUID (print ke console)",
    Callback = function()
        task.spawn(function()
            local u, src = CutUuids()
            local ms = GetMachines()
            local b = workspace:FindFirstChild("Models") and workspace.Models:FindFirstChild("Bases")
            if b then
                local i = 0
                for _, c in ipairs(b:GetChildren()) do
                    if c.Name == "FinalBaseModel" then
                        i += 1
                        local at = {}
                        for k, v in pairs(c:GetAttributes()) do at[#at + 1] = k .. "=" .. tostring(v) end
                        for _, ch in ipairs(c:GetChildren()) do
                            if ch:IsA("ValueBase") then at[#at + 1] = ch.Name .. "=" .. tostring(ch.Value) end
                        end
                        print("[Base #" .. i .. "] mine=" .. tostring(IsMine(c)) .. " | " .. table.concat(at, ", "))
                    end
                end
            end
            for _, m in ipairs(ms) do
                print("[Mesin] " .. m:GetFullName() .. " | status: " .. tostring((MachineState(m))))
                for _, d in ipairs(m:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then
                        print("    prompt: action='" .. tostring(d.ActionText) .. "' object='" .. tostring(d.ObjectText) .. "' enabled=" .. tostring(d.Enabled))
                    end
                end
            end
            print("[UUID] sumber=" .. tostring(src) .. " | " .. #u .. " uuid terbaca (dari remote masuk: " .. PoolCount() .. "): " .. table.concat(u, ", ", 1, math.min(#u, 12)))
            N("Cek mesin", "Base: " .. tostring(Stats.baseInfo) .. " · " .. #ms .. " mesin · " .. #u .. " uuid (console F9)", "#6495ED", 6)
        end)
    end,
})

local cStone = Main:AddCard({ Title = "Auto Collect Cut Stone", Icon = "backpack", Column = 2 })
local tgStone = cStone:Toggle({
    Title = "Auto Collect Cut Stone", Desc = "Scan mesin yang ada stone, teleport & collect", id = "cr_stone", Expand = true,
    Callback = function(v)
        Loop("stone", v, function() return STONE_INTERVAL end, CollectStoneCycle)
        if not v then Stats.stoneStatus = "-" end
        N("Auto Collect Cut Stone", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgStone:Sub(function(c)
    c:Slider({
        Title = "Scan mesin tiap (s)", Min = 0.1, Max = 30, Value = STONE_INTERVAL, Rounding = 0, Suffix = "s", id = "cr_stoneint",
        Callback = function(v) STONE_INTERVAL = v end,
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
            local bc, bm = BagInfo()
            local txt = "Status: " .. Stats.status ..
                "\nTarget: " .. TARGET_VEIN ..
                "\nTas: " .. bc .. " / " .. bm .. " (" .. tostring(Stats.bagSrc) .. ")" ..
                "\nRiwayat target: " .. (#parts > 0 and table.concat(parts, ", ") or "-") ..
                "\nJual: " .. (Stats.sold or 0) .. "   Cut: " .. (Stats.cut or 0) .. "   Collect: " .. (Stats.stone or 0) ..
                "\nBase: " .. tostring(Stats.baseInfo or "-") ..
                "\nCut: " .. tostring(Stats.cutStatus or "-") ..
                "\nStone: " .. tostring(Stats.stoneStatus or "-")
            stLbl:SetText(txt)
        end)
    end
end)

-- hentikan semua saat Unload
W:OnUnload(function()
    for k in pairs(runId) do runId[k] += 1 end
    machineBusy = false
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
