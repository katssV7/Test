-- KatssinnnHub | Game 8 (Cut a Rock)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Auto Farm: scan semua rock di workspace.Rooms tiap 1 detik, teleport bertahap (hop) ke rock target, collect instan
-- (ProximityPrompt tanpa tahan), lalu hapus rock yang bukan target dari tas lewat remote CepTasSil.
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
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- ===== LOOP (bisa dibatalkan, tidak pernah tumpang tindih) =====
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

-- ===== DATA AWAL: isi tiap room (dari catatanmu) =====
-- Dipakai untuk menebak room mana yang paling sering memunculkan sebuah rarity; ditambah statistik yang dipelajari saat main.
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
local learned, taken = {}, {}          -- statistik saat main: rock yang pernah terlihat muncul / yang pernah diambil, per room

-- ===== PENGATURAN =====
local TARGET = "supreme"               -- "all" atau nama rarity tanpa "_vein"
local MAX_BAG, DEL_JUNK = 10, true     -- kapasitas tas (isi sesuai tasmu) & hapus rock bukan target dari tas
local HOP_DIST, COLLECT_GAP, USE_BEST_ROOM = 150, 0.12, true

local Stats = { collected = 0, deleted = 0, hops = 0, scans = 0, errors = 0, status = "idle", room = "-", bag = "-", rocks = 0 }
local held = {}                        -- item yang diambil script: { uuid, rarity }

-- ===== KARAKTER & TELEPORT MULUS =====
local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

local tpParams = RaycastParams.new()
tpParams.FilterType = Enum.RaycastFilterType.Exclude
tpParams.IgnoreWater = true
local rockFolders = {}                 -- folder "Rocks" tiap room: diabaikan raycast lantai (rock bukan lantai)

local function PreloadArea(pos)         -- StreamingEnabled: minta area tujuan dimuat dulu supaya tidak jatuh menembus lantai
    local hrp = Root()
    if hrp and (hrp.Position - pos).Magnitude < 120 then return end
    local done = false
    task.spawn(function()
        pcall(function() LP:RequestStreamingAroundAsync(pos, 1) end)
        done = true
    end)
    local t = 0
    while not done and t < 1.2 do t += task.wait(0.05) end
end

local function TP(pos)
    local c = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    PreloadArea(pos)
    c = LP.Character
    hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local hum = c:FindFirstChildOfClass("Humanoid")

    local ignore = { c }
    for _, f in ipairs(rockFolders) do if f.Parent then ignore[#ignore + 1] = f end end
    tpParams.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -50, 0), tpParams)
    local y = hit and (hit.Position.Y + (hum and hum.HipHeight or 2) + hrp.Size.Y / 2 + 0.1) or (pos.Y + 3)

    local rot = hrp.CFrame - hrp.CFrame.Position                       -- pertahankan arah hadap
    c:PivotTo(CFrame.new(pos.X, y, pos.Z) * rot)
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    if not hrp.Anchored then                                           -- tahan 2 frame agar fisika tenang
        hrp.Anchored = true
        RunService.Heartbeat:Wait()
        RunService.Heartbeat:Wait()
        if hrp.Parent then hrp.Anchored = false end
    end
    return true
end

-- ===== SCAN ROCK (tiap 1 detik) =====
-- Struktur: workspace.Rooms.Room_N.Rocks.<rarity>_vein
local ROCKS, roomPos, seen = {}, {}, setmetatable({}, { __mode = "k" })

local function RockPos(r)
    if r:IsA("BasePart") then return r.Position end
    local ok, cf = pcall(function() return r:GetPivot() end)
    return ok and cf.Position or nil
end
local function PromptOf(r) return r:FindFirstChildWhichIsA("ProximityPrompt", true) end

local function ScanRocks()
    local rooms = workspace:FindFirstChild("Rooms")
    if not rooms then Stats.status = "workspace.Rooms tidak ada"; return end
    local list, sums, folders = {}, {}, {}
    for _, room in ipairs(rooms:GetChildren()) do
        local rn = tonumber(room.Name:match("Room_(%d+)"))
        local rocks = rn and room:FindFirstChild("Rocks")
        if rocks then
            folders[#folders + 1] = rocks
            for _, r in ipairs(rocks:GetChildren()) do
                local rar = r.Name:match("^(%a+)_vein$")
                local pos = rar and RockPos(r)
                if pos then
                    local pr = PromptOf(r)
                    if pr then pcall(function() pr.HoldDuration = 0 end) end          -- collect instan (tanpa tahan)
                    list[#list + 1] = { inst = r, rarity = rar, room = rn, pos = pos, prompt = pr }
                    local s = sums[rn] or { Vector3.zero, 0 }
                    sums[rn] = { s[1] + pos, s[2] + 1 }
                    if not seen[r] then
                        seen[r] = true
                        learned[rar] = learned[rar] or {}
                        learned[rar][rn] = (learned[rar][rn] or 0) + 1                  -- statistik spawn
                    end
                end
            end
        end
    end
    for rn, s in pairs(sums) do roomPos[rn] = s[1] / s[2] end                            -- pusat room (tetap diingat walau belum termuat)
    ROCKS, rockFolders = list, folders
    Stats.rocks, Stats.scans = #list, Stats.scans + 1
end

local function RoomPosition(rn)
    if roomPos[rn] then return roomPos[rn] end
    local rooms = workspace:FindFirstChild("Rooms")
    local m = rooms and rooms:FindFirstChild("Room_" .. rn)
    if m then
        local ok, cf = pcall(function() return m:GetPivot() end)
        if ok then return cf.Position end
    end
end

-- room terbaik untuk sebuah rarity: data awal + rock yang pernah terlihat muncul + yang pernah diambil
local function BestRoom(rar)
    local best, bs = nil, -1
    for rn = 0, 39 do
        local sc = ((PRIOR[rar] and PRIOR[rar][rn]) or 0)
            + ((learned[rar] and learned[rar][rn]) or 0)
            + 2 * ((taken[rar] and taken[rar][rn]) or 0)
        if sc > bs then best, bs = rn, sc end
    end
    return best, bs
end

-- ===== TELEPORT BERTAHAP (hop) =====
-- Target yang terlalu jauh didekati lewat rock / room lain yang masih dalam jangkauan (HOP_DIST) dari posisi sekarang,
-- yang paling mendekati target; setelah target masuk jangkauan baru teleport ke target.
local function HopTo(target, id)
    for _ = 1, 40 do
        if runId.farm ~= id then return false end
        local hrp = Root()
        if not hrp then return false end
        local p = hrp.Position
        local d = (p - target).Magnitude
        if d <= HOP_DIST then break end
        local best, bd
        local function consider(c)
            local dp = (c - p).Magnitude
            if dp <= HOP_DIST and dp > 10 then
                local dt = (c - target).Magnitude
                if not bd or dt < bd then best, bd = c, dt end
            end
        end
        for _, r in ipairs(ROCKS) do consider(r.pos) end
        for _, c in pairs(roomPos) do consider(c) end
        if not best or bd >= d - 10 then break end            -- tidak ada waypoint yang lebih dekat -> teleport langsung
        Stats.hops += 1
        TP(best + Vector3.new(4, 0, 0))
        task.wait(0.1)
    end
    local hrp = Root()
    if not hrp then return false end
    local dir = hrp.Position - target
    dir = Vector3.new(dir.X, 0, dir.Z)
    dir = dir.Magnitude > 0.5 and dir.Unit or Vector3.new(0, 0, 1)
    return TP(target + dir * 4)                                -- berdiri 4 stud dari rock (rock punya collision)
end

-- ===== UUID ITEM (untuk CepTasSil) =====
local UUID_PAT = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
local function IsUuid(s) return type(s) == "string" and s:match(UUID_PAT) ~= nil end
local function UuidIn(o)
    if IsUuid(o.Name) then return o.Name end
    for _, v in pairs(o:GetAttributes()) do if IsUuid(v) then return v end end
    if o:IsA("StringValue") and IsUuid(o.Value) then return o.Value end
end
local function FindUuid(inst)                                   -- uuid yang menempel di rock (dibaca sebelum diambil)
    local u = UuidIn(inst)
    if u then return u end
    for _, d in ipairs(inst:GetDescendants()) do
        u = UuidIn(d)
        if u then return u end
    end
end
local function UuidSet()                                        -- semua uuid di sisi player (tas / GUI / data player)
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
local function BagCount()           -- baca "x/MAX" dari GUI (MAX = angka yang kamu isi); kalau tidak ketemu, pakai hitungan sendiri
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
    if not HopTo(rk.pos, id) then return false end
    if runId.farm ~= id or not inst.Parent then return false end
    pcall(function() p.HoldDuration = 0 end)

    local uuid = FindUuid(inst)                                        -- baca uuid sebelum rock hilang
    local before = (not uuid and DEL_JUNK) and UuidSet() or nil        -- cadangan: bandingkan uuid tas sebelum / sesudah

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
    end
    if got then
        Stats.collected += 1
        taken[rk.rarity] = taken[rk.rarity] or {}
        taken[rk.rarity][rk.room] = (taken[rk.rarity][rk.room] or 0) + 1
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
local function NearestRock(origin, onlyRarity, onlyRoom)
    local best, bd
    for _, r in ipairs(ROCKS) do
        if r.inst.Parent and (not onlyRarity or r.rarity == onlyRarity) and (not onlyRoom or r.room == onlyRoom) then
            local d = (r.pos - origin).Magnitude
            if not bd or d < bd then best, bd = r, d end
        end
    end
    return best
end

local function FarmStep(id)
    local hrp = Root()
    if not hrp then Stats.status = "menunggu karakter"; Sleep("farm", 1, id) return end
    local all = (TARGET == "all")

    -- tas penuh?
    local bag = BagCount()
    if bag >= MAX_BAG then
        if not all and DEL_JUNK then DeleteJunk(TARGET); bag = BagCount() end
        if bag >= MAX_BAG then Stats.status = "tas penuh"; Sleep("farm", 0.5, id) return end
    end

    local pick
    if all then
        pick = NearestRock(hrp.Position)
    else
        pick = NearestRock(hrp.Position, TARGET)                      -- rock target yang ada sekarang
        if not pick and USE_BEST_ROOM then
            -- target tidak ada di mana pun: ke room yang paling sering memunculkannya, collect semua rock di sana
            local rn = BestRoom(TARGET)
            pick = NearestRock(hrp.Position, nil, rn)
            if not pick then
                local rp = RoomPosition(rn)                            -- room belum termuat: ke tengah room dulu
                if rp then
                    Stats.status = "menuju room " .. rn .. " (target kosong)"
                    HopTo(rp, id)
                    Sleep("farm", 0.5, id)
                    return
                end
            end
        end
    end
    if not pick then Stats.status = "tidak ada rock"; Sleep("farm", 0.5, id) return end

    local got = Collect(pick, id)
    if got and not all and DEL_JUNK and pick.rarity ~= TARGET then DeleteJunk(TARGET) end
end

-- ===== REMOTE LOGGER (cek argumen asli CepTasSil / remote lain saat main manual) =====
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
    if t == "Vector3" or t == "vector" then return string.format("vec(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) end
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
        TARGET = (v == "Semua rock") and "all" or v:gsub("_vein$", "")
    end,
})
local tgFarm = cFarm:Toggle({
    Title = "Auto Farm", Desc = "Teleport bertahap, collect instan, hapus rock non-target", id = "cr_farm", Expand = true,
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
        Title = "Jarak hop (stud)", Min = 40, Max = 400, Value = 150, Rounding = 0, id = "cr_hop",
        Callback = function(v) HOP_DIST = v end,
    })
    c:Slider({
        Title = "Jeda collect (s)", Min = 0.03, Max = 0.6, Value = 0.12, Rounding = 2, Suffix = "s", id = "cr_gap",
        Callback = function(v) COLLECT_GAP = v end,
    })
    c:Toggle({
        Title = "Target kosong: ke room terbanyak", Desc = "Collect rock di room itu sampai target muncul", Value = true, id = "cr_bestroom",
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

local cDbg = Main:AddCard({ Title = "Debug / Kalibrasi", Icon = "scan", Column = 2, Collapsed = true })
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
        local n = 0
        for _, d in ipairs(rk.inst:GetDescendants()) do
            n += 1
            if n <= 40 then
                local at = {}
                for k, v in pairs(d:GetAttributes()) do at[#at + 1] = k .. "=" .. tostring(v) end
                print("  " .. d.ClassName .. " " .. d.Name, table.concat(at, ", "))
            end
        end
        print("  uuid terbaca dari rock:", tostring(FindUuid(rk.inst)))
        N("Info rock", rk.rarity .. "_vein di Room_" .. rk.room .. " (lihat console F9)", "#6495ED", 4)
    end,
})
cDbg:Button({
    Title = "Scan UUID tas (print)", Text = "Scan UUID tas (print ke console)",
    Callback = function()
        task.spawn(function()
            local set, n = UuidSet(), 0
            local list = {}
            for u in pairs(set) do n += 1; if n <= 25 then list[#list + 1] = u end end
            print("[UUID] " .. n .. " uuid terbaca di sisi player: " .. table.concat(list, ", "))
            N("Scan UUID", n .. " uuid terbaca (lihat console F9)", "#6495ED", 4)
        end)
    end,
})
cDbg:Button({
    Title = "Statistik room (print)", Text = "Room terbaik tiap rarity (print)",
    Callback = function()
        for _, rar in ipairs(ORDER) do
            local rn, sc = BestRoom(rar)
            print(string.format("[Room] %-10s -> Room_%d (skor %d)", rar, rn or -1, sc))
        end
        N("Statistik room", "Lihat console F9", "#6495ED", 3)
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
            if logOn and #logLines > 0 then txt ..= "\n— remote terakhir —\n" .. table.concat(logLines, "\n") end
            stLbl:SetText(txt)
        end)
    end
end)

-- hentikan semua saat Unload
W:OnUnload(function()
    logOn = false
    for k in pairs(runId) do runId[k] += 1 end
end)

-- Player (Movement / Fly / Client) dan Home (+ Settings) ada di ui.lua; tiap bagian aman dari error.
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
W:Ready()      -- jalankan nilai awal + autoload config setelah intro selesai
W:OnBooted(function() N("KatssinnnHub", "Cut a Rock dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4) end)
