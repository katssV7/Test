-- KatssinnnHub | Game 8 (Cut a Rock)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Auto Farm: scan semua rock di workspace.Rooms tiap 1 detik.
--   * Teleport antar room BERURUTAN (Room_a -> Room_a+1 -> ... -> room tujuan) lewat titik tengah tiap room, lalu TP pas ke atas rock.
--   * Collect instan lewat ProximityPrompt (HoldDuration 0 + fireproximityprompt).
--   * Target kosong -> ke room penghasil target terbanyak, collect rock di sana, lalu hapus yang bukan target dari tas (CepTasSil).
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

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- ===== LOOP (bisa dibatalkan, tidak tumpang tindih) =====
local runId = { farm = 0, scan = 0 }
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
local function Sleep(key, t, id)
    local el = 0
    while el < t do
        if runId[key] ~= id then return false end
        el += task.wait(math.min(0.05, t - el + 0.001))
    end
    return runId[key] == id
end

-- ===== DATA AWAL room (dipakai kalau belum pernah ambil target) =====
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
local taken = {}                       -- taken[rarity][room] = berapa kali target diambil di room itu

-- ===== PENGATURAN =====
local TARGET = "supreme"               -- "all" atau nama rarity tanpa "_vein"
local MAX_BAG, DEL_JUNK = 10, true
local HOP_WAIT, COLLECT_GAP, USE_BEST_ROOM = 0.15, 0.12, true

local Stats = { collected = 0, deleted = 0, hops = 0, scans = 0, errors = 0, status = "idle", room = "-", bag = "-", rocks = 0 }
local held = {}                        -- item hasil collect script: { uuid, rarity }

-- ===== KARAKTER & TELEPORT (sama seperti V2: langsung set CFrame) =====
local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

local function TP(pos)
    local hrp = Root()
    if not (hrp and pos) then return false end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    return true
end

-- ===== SCAN ROCK (tiap 1 detik): workspace.Rooms.Room_N.Rocks.<rarity>_vein =====
local ROCKS, roomPos = {}, {}          -- roomPos[n] = titik tengah room (diingat terus walau room kosong sesaat)

local function RockPos(r)
    if r:IsA("BasePart") then return r.Position end
    local ok, cf = pcall(function() return r:GetPivot() end)
    if ok and cf then return cf.Position end
    for _, d in ipairs(r:GetDescendants()) do
        if d:IsA("BasePart") then return d.Position end
    end
end
local function PromptOf(r) return r:FindFirstChildWhichIsA("ProximityPrompt", true) end

local function ScanRocks()
    local rooms = workspace:FindFirstChild("Rooms")
    if not rooms then Stats.status = "workspace.Rooms tidak ada"; return end
    local list, sums = {}, {}
    for _, room in ipairs(rooms:GetChildren()) do
        local rn = tonumber(room.Name:match("Room_(%d+)"))
        local rocks = rn and room:FindFirstChild("Rocks")
        if rocks then
            for _, r in ipairs(rocks:GetChildren()) do
                local rar = r.Name:match("^(%a+)_vein$")
                local pos = rar and RockPos(r)
                if pos then
                    local pr = PromptOf(r)
                    if pr then
                        pcall(function()
                            pr.HoldDuration = 0                     -- collect instan (tanpa tahan)
                            pr.RequiresLineOfSight = false
                        end)
                    end
                    list[#list + 1] = { inst = r, rarity = rar, room = rn, pos = pos, prompt = pr }
                    local s = sums[rn] or { Vector3.zero, 0 }
                    sums[rn] = { s[1] + pos, s[2] + 1 }
                end
            end
        end
    end
    for rn, s in pairs(sums) do roomPos[rn] = s[1] / s[2] end
    ROCKS = list
    Stats.rocks, Stats.scans = #list, Stats.scans + 1
end

local function NearestRoom(pos)
    local best, bd
    for rn, c in pairs(roomPos) do
        local d = (c - pos).Magnitude
        if not bd or d < bd then best, bd = rn, d end
    end
    return best
end

-- Teleport berurutan antar room: dari room terdekat pemain ke room tujuan, satu room per langkah.
local function HopToRoom(id, targetRoom)
    local hrp = Root()
    if not hrp then return false end
    local cur = NearestRoom(hrp.Position) or targetRoom
    if cur == targetRoom and roomPos[cur] and (hrp.Position - roomPos[cur]).Magnitude < 80 then return true end
    local step = targetRoom >= cur and 1 or -1
    for i = cur, targetRoom, step do
        if runId.farm ~= id then return false end
        local c = roomPos[i]
        if c then
            Stats.hops += 1
            TP(c)
            task.wait(HOP_WAIT)
        end
    end
    return true
end

-- room terbaik untuk sebuah rarity: paling banyak diambil di room itu; kalau belum ada riwayat, pakai data awal
local function BestRoom(rar)
    local best, bs = nil, -1
    for rn = 0, 39 do
        local sc = 100 * ((taken[rar] and taken[rar][rn]) or 0) + ((PRIOR[rar] and PRIOR[rar][rn]) or 0)
        if sc > bs then best, bs = rn, sc end
    end
    return best, bs
end

-- ===== UUID ITEM (untuk CepTasSil) =====
local UUID_PAT = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
local function IsUuid(s) return type(s) == "string" and s:match(UUID_PAT) ~= nil end
local function UuidIn(o)
    if IsUuid(o.Name) then return o.Name end
    for _, v in pairs(o:GetAttributes()) do if IsUuid(v) then return v end end
    if o:IsA("StringValue") and IsUuid(o.Value) then return o.Value end
end
local function FindUuid(inst)                                -- uuid yang menempel di rock (dibaca sebelum diambil)
    local u = UuidIn(inst)
    if u then return u end
    for _, d in ipairs(inst:GetDescendants()) do
        u = UuidIn(d)
        if u then return u end
    end
end
local function UuidSet()                                     -- cadangan: semua uuid di sisi player (bandingkan sebelum/sesudah collect)
    local set = {}
    local function scan(root)
        if not root then return end
        local n = 0
        for _, d in ipairs(root:GetDescendants()) do
            n += 1
            if n % 3000 == 0 then task.wait() end
            local u = UuidIn(d)
            if u then set[u] = true end
        end
    end
    scan(LP:FindFirstChildOfClass("Backpack"))
    scan(PG)
    for _, c in ipairs(RS:GetChildren()) do
        if c.Name == LP.Name or c.Name == tostring(LP.UserId) then scan(c) end
    end
    return set
end

-- ===== TAS =====
local guiCache = {}
local function Shown(g)
    local o = g
    while o and o ~= PG do
        if o:IsA("GuiObject") and not o.Visible then return false end
        if o:IsA("ScreenGui") and not o.Enabled then return false end
        o = o.Parent
    end
    return o == PG
end
local function BagCount()           -- baca "x/MAX" dari GUI; kalau tidak ketemu, pakai hitungan sendiri
    local key = "bag" .. MAX_BAG
    local lbl = guiCache[key]
    if not (lbl and lbl.Parent and lbl:IsDescendantOf(PG)) then
        lbl = nil
        if os.clock() - (guiCache[key .. "_t"] or 0) >= 1.5 then
            guiCache[key .. "_t"] = os.clock()
            for _, d in ipairs(PG:GetDescendants()) do
                if d:IsA("TextLabel") then
                    local a, b = d.Text:match("^%s*(%d+)%s*/%s*(%d+)%s*$")
                    if a and tonumber(b) == MAX_BAG and Shown(d) then lbl = d; guiCache[key] = d; break end
                end
            end
        end
    end
    if lbl then
        local a = lbl.Text:match("^%s*(%d+)")
        if a then Stats.bag = a .. "/" .. MAX_BAG; return tonumber(a) end
    end
    Stats.bag = #held .. "/" .. MAX_BAG .. " (hitungan sendiri)"
    return #held
end

local warnedUuid = false
local function DeleteJunk(keep)       -- buang item yang rarity-nya bukan "keep" lewat CepTasSil({uuid})
    local rem = RS:FindFirstChild("CepTasSil")
    if not rem then Stats.errors += 1; return 0 end
    local n = 0
    for i = #held, 1, -1 do
        local h = held[i]
        if keep == nil or h.rarity ~= keep then
            if h.uuid then
                if pcall(rem.FireServer, rem, { h.uuid }) then n += 1 else Stats.errors += 1 end
                table.remove(held, i)
                task.wait(0.05)
            elseif not warnedUuid then
                warnedUuid = true
                N("Hapus tas", "UUID item tidak ketemu, item tidak bisa dihapus. Pakai Info rock / Remote Logger di kartu Debug.", "#FFA500", 6)
            end
        end
    end
    Stats.deleted += n
    return n
end

-- ===== COLLECT =====
local function Collect(rk, id)
    local inst = rk.inst
    local p = rk.prompt or PromptOf(inst)
    if not p or not inst.Parent then return false end
    Stats.status = string.format("room %d · %s_vein", rk.room, rk.rarity)
    Stats.room = tostring(rk.room)

    if not HopToRoom(id, rk.room) then return false end          -- berurutan antar room dulu
    if runId.farm ~= id or not inst.Parent then return false end
    local pos = RockPos(inst) or rk.pos
    TP(pos)                                                      -- lalu TP pas ke rock
    task.wait(0.1)
    pcall(function() p.HoldDuration = 0 end)

    local uuid = FindUuid(inst)                                  -- baca uuid sebelum rock hilang
    local before = (not uuid and DEL_JUNK) and UuidSet() or nil

    local got = false
    for _ = 1, 4 do
        if fireproximityprompt then
            pcall(fireproximityprompt, p)
        else
            pcall(function() p:InputHoldBegin(); task.wait(0.05); p:InputHoldEnd() end)
        end
        local t = 0
        while t < COLLECT_GAP + 0.15 and inst.Parent and p.Parent and p.Enabled do t += task.wait(0.03) end
        if not inst.Parent or not p.Parent or not p.Enabled then got = true; break end
        TP(pos)                                                  -- belum kena? posisikan ulang lalu coba lagi
    end
    if got then
        Stats.collected += 1
        if rk.rarity == TARGET then
            taken[rk.rarity] = taken[rk.rarity] or {}
            taken[rk.rarity][rk.room] = (taken[rk.rarity][rk.room] or 0) + 1
        end
        if not uuid and before then
            task.wait(0.1)
            local fresh = {}
            for u in pairs(UuidSet()) do if not before[u] then fresh[#fresh + 1] = u end end
            if #fresh == 1 then uuid = fresh[1] end
        end
        held[#held + 1] = { uuid = uuid, rarity = rk.rarity }
    end
    return got
end

-- ===== AUTO FARM =====
-- pilih rock: room paling dekat dulu (supaya hop sedikit), lalu jarak terdekat
local function NearestRock(origin, onlyRarity, onlyRoom)
    local cur = NearestRoom(origin)
    local best, bs
    for _, r in ipairs(ROCKS) do
        if r.inst.Parent and (not onlyRarity or r.rarity == onlyRarity) and (not onlyRoom or r.room == onlyRoom) then
            local s = math.abs(r.room - (cur or r.room)) * 100000 + (r.pos - origin).Magnitude
            if not bs or s < bs then best, bs = r, s end
        end
    end
    return best
end

local function FarmStep(id)
    local hrp = Root()
    if not hrp then Stats.status = "menunggu karakter"; Sleep("farm", 1, id) return end
    local all = (TARGET == "all")

    -- 1) tas penuh? buang yang bukan target dulu
    local bag = BagCount()
    if bag >= MAX_BAG then
        if not all and DEL_JUNK then DeleteJunk(TARGET); bag = BagCount() end
        if bag >= MAX_BAG then Stats.status = "tas penuh"; Sleep("farm", 0.5, id) return end
    end

    -- 2) pilih rock
    local pick
    if all then
        pick = NearestRock(hrp.Position)
    else
        pick = NearestRock(hrp.Position, TARGET)                   -- target ada -> kejar
        if not pick and USE_BEST_ROOM then
            local rn = BestRoom(TARGET)                            -- target kosong -> room penghasil terbanyak
            pick = NearestRock(hrp.Position, nil, rn)
            if not pick then
                Stats.status = "menuju room " .. rn .. " (target kosong)"
                HopToRoom(id, rn)
                Sleep("farm", 0.5, id)
                return
            end
        end
    end
    if not pick then Stats.status = "tidak ada rock"; Sleep("farm", 0.5, id) return end

    -- 3) collect, lalu langsung buang kalau bukan target
    local got = Collect(pick, id)
    if got and not all and DEL_JUNK and pick.rarity ~= TARGET then DeleteJunk(TARGET) end
end

-- ===== REMOTE LOGGER (lihat argumen asli CepTasSil saat hapus item manual) =====
local logOn, logLines, oldNc = false, {}, nil
local function Fmt(v)
    local t = typeof(v)
    if t == "number" then return string.format("%.3f", v) end
    if t == "string" then return '"' .. v .. '"' end
    if t == "table" then
        local parts = {}
        for i, x in ipairs(v) do parts[i] = Fmt(x) end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end
local function InstallHook()
    if oldNc then return true end
    if not (hookmetamethod and getnamecallmethod) then return false end
    local wrap = newcclosure or function(f) return f end
    oldNc = hookmetamethod(game, "__namecall", wrap(function(self, ...)
        if logOn then
            local m = getnamecallmethod()
            if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance"
                and (self.Parent == RS or (self.Parent and self.Parent.Parent == RS)) and not (checkcaller and checkcaller()) then
                local args = table.pack(...)
                local nm = self.Name
                task.spawn(function()
                    local parts = {}
                    for i = 1, args.n do parts[i] = Fmt(args[i]) end
                    local line = nm .. "(" .. table.concat(parts, ", ") .. ")"
                    print("[RemoteLog] " .. line)
                    logLines[#logLines + 1] = line
                    if #logLines > 6 then table.remove(logLines, 1) end
                end)
            end
        end
        return oldNc(self, ...)
    end))
    return true
end

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "pickaxe" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

-- ---------- Auto Farm ----------
local cFarm = Main:AddCard({ Title = "Auto Farm", Icon = "pickaxe", Column = 1 })
local targetList = { "Semua rock" }
for _, r in ipairs(ORDER) do targetList[#targetList + 1] = r .. "_vein" end
cFarm:Dropdown({
    Title = "Target rock", List = targetList, Value = "supreme_vein", id = "cr_target",
    Callback = function(v)
        if not v then return end
        v = tostring(v)
        if v == "Semua rock" then TARGET = "all" else TARGET = (v:gsub("_vein$", "")) end
    end,
})
local tgFarm = cFarm:Toggle({
    Title = "Auto Farm", Desc = "Teleport antar room, collect instan, hapus rock non-target", id = "cr_farm", Expand = true,
    Callback = function(v)
        if v then held = {}; warnedUuid = false end
        Loop("scan", v, function() return 1 end, function() ScanRocks() end)      -- scan tiap 1 detik
        if v then pcall(ScanRocks) end
        Loop("farm", v, function() return 0.05 end, FarmStep)
        if not v then Stats.status = "idle" end
        N("Auto Farm", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
tgFarm:Sub(function(c)
    c:Slider({
        Title = "Jeda teleport antar room (s)", Min = 0.05, Max = 1, Value = 0.15, Rounding = 2, Suffix = "s", id = "cr_hopwait",
        Callback = function(v) HOP_WAIT = v end,
    })
    c:Slider({
        Title = "Jeda collect (s)", Min = 0.03, Max = 0.6, Value = 0.12, Rounding = 2, Suffix = "s", id = "cr_gap",
        Callback = function(v) COLLECT_GAP = v end,
    })
    c:Toggle({
        Title = "Target kosong: ke room terbanyak", Desc = "Collect rock di room itu, lalu buang yang bukan target", Value = true, id = "cr_bestroom",
        Callback = function(v) USE_BEST_ROOM = v end,
    })
end)

-- ---------- Backpack ----------
local cBag = Main:AddCard({ Title = "Backpack", Icon = "backpack", Column = 1 })
cBag:Input({
    Title = "Max backpack (kapasitas tas)", Placeholder = "10", Value = "10", id = "cr_maxbag",
    Callback = function(v)
        local n = tonumber(v)
        if n and n >= 1 then MAX_BAG = math.floor(n) end
    end,
})
cBag:Toggle({
    Title = "Hapus rock bukan target dari tas", Value = true, id = "cr_deljunk",
    Callback = function(v) DEL_JUNK = v end,
})
cBag:Button({
    Title = "Hapus non-target sekarang", Text = "Hapus non-target dari tas sekarang",
    Callback = function()
        task.spawn(function()
            local keep = (TARGET ~= "all") and TARGET or nil
            local n = DeleteJunk(keep)
            N("Backpack", n .. " item dihapus", "#6495ED")
        end)
    end,
})

-- ---------- Status & Debug ----------
local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })

local cDbg = Main:AddCard({ Title = "Debug", Icon = "scan", Column = 2, Collapsed = true })
cDbg:Toggle({
    Title = "Remote Logger (lihat argumen remote asli)", id = "cr_log",
    Callback = function(v)
        if v and not InstallHook() then
            N("Remote Logger", "Executor tidak mendukung hookmetamethod", "#DC3232", 5)
            return
        end
        logOn = v
    end,
})
cDbg:Button({
    Title = "Info rock terdekat (print)", Text = "Info rock terdekat (print ke console)",
    Callback = function()
        pcall(ScanRocks)
        local hrp = Root()
        local rk = hrp and NearestRock(hrp.Position)
        if not rk then N("Info rock", "Tidak ada rock terdeteksi", "#DC3232"); return end
        print("===== Rock: " .. rk.inst:GetFullName() .. " [" .. rk.inst.ClassName .. "] =====")
        for k, v in pairs(rk.inst:GetAttributes()) do print("  attr", k, v) end
        print("  uuid terbaca dari rock:", tostring(FindUuid(rk.inst)))
        N("Info rock", rk.rarity .. "_vein di Room_" .. rk.room .. " (lihat console F9)", "#6495ED", 4)
    end,
})
cDbg:Button({
    Title = "Room terbaik target (print)", Text = "Room terbaik untuk target (print)",
    Callback = function()
        local rn, sc = BestRoom(TARGET == "all" and "supreme" or TARGET)
        print(string.format("[Room] %s -> Room_%d (skor %d)", TARGET, rn or -1, sc))
        N("Room terbaik", "Room_" .. tostring(rn), "#6495ED", 3)
    end,
})

task.spawn(function()
    while W.Alive do
        task.wait(0.5)
        pcall(function()
            local txt = "Status: " .. Stats.status ..
                "\nTarget: " .. (TARGET == "all" and "semua rock" or TARGET .. "_vein") .. "   Room: " .. Stats.room ..
                "\nTas: " .. Stats.bag .. "   Rock terlihat: " .. Stats.rocks ..
                "\nDiambil: " .. Stats.collected .. "   Dihapus: " .. Stats.deleted .. "   Hop: " .. Stats.hops ..
                "\nError: " .. Stats.errors
            if logOn and #logLines > 0 then
                txt = txt .. "\n— remote terakhir —\n" .. table.concat(logLines, "\n")
            end
            stLbl:SetText(txt)
        end)
    end
end)

W:OnUnload(function()
    logOn = false
    for k in pairs(runId) do runId[k] += 1 end
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
