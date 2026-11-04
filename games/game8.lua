-- KatssinnnHub | Game 8 (Cut a Rock)
-- Sidebar: Home / Main / Settings (library: ui.lua)
-- Fitur: Auto Collect Supreme Vein — scan semua Rooms, teleport berurutan antar room (bukan sekali loncat jauh),
--        collect lewat ProximityPrompt (instan), fallback farm room penghasil Supreme terbanyak.
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
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

-- ===== LOOP (sama pola dengan game7) =====
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

-- ============================================================
--  AUTO COLLECT SUPREME VEIN
--  Struktur: workspace.Rooms.Room_0 .. Room_39 > Rocks > (model rock, nama = jenis vein)
--
--  CARA KERJA:
--   1. Scan ulang SEMUA Rooms tiap SCAN_INTERVAL detik (rock bisa hilang/muncul lagi dengan
--      jenis berbeda di posisi yang sama, jadi tidak boleh pakai daftar tetap).
--   2. Kalau ada Supreme Vein: teleport berurutan lewat titik tengah tiap room dari room
--      terdekat pemain sampai room tujuan (bukan sekali loncat jauh), baru teleport pas ke
--      Supreme Vein itu, lalu langsung collect lewat ProximityPrompt (fireproximityprompt,
--      tidak perlu tahan tombol manual).
--   3. Kalau Supreme Vein TIDAK ADA di semua room: pergi ke room yang riwayatnya paling
--      banyak menghasilkan Supreme Vein (dihitung sendiri selama script jalan), lalu collect
--      rock apa pun yang ada di room itu (supaya slot kosong & room "menghasilkan" rock baru).
--   4. "Tas penuh": dihitung dari internal counter dibandingkan Max Backpack yang kamu isi
--      sendiri di menu, BUKAN dibaca dari UI game (lihat CATATAN #2 di bawah).
--
--  CATATAN / ASUMSI YANG PERLU KAMU VERIFIKASI:
--   1. Collect pakai fireproximityprompt ke ProximityPrompt asli di tiap rock. Ini TIDAK
--      memanggil remote CepTasSil secara manual — begitu prompt di-fire, script GAME itu
--      sendiri yang mengirim remote dengan GUID yang benar. Kalau executor kamu tidak punya
--      fireproximityprompt, fitur ini tidak jalan (peringatan muncul sekali di konsol).
--   2. MAX BACKPACK: saya TIDAK tahu cara baca sisa slot tas dari game (butuh SimpleSpy/UI
--      scan lebih lanjut). Jadi script menghitung sendiri (internal counter) tiap berhasil
--      collect SESUATU, dan berhenti kalau sudah mencapai angka yang kamu isi di menu.
--      Kalau kamu jual/kosongkan tas secara manual di game, tekan tombol Reset Counter.
--   3. BUANG ITEM SELAIN SUPREME: belum dibuat, karena belum tahu remote untuk membuang 1
--      item dari tas. Mode "farm room terbaik" HANYA collect (tidak membuang), jadi tas bisa
--      penuh berisi campuran sebelum sempat dapat Supreme lagi — pantau manual dulu. Kirim
--      hasil SimpleSpy/attack_probe waktu kamu buang 1 item manual, nanti saya tambahkan.
--   4. Teleport per-room (bukan sekali loncat jauh) itu tebakan saya dari permintaan "dijangkau
--      studnya dulu" — kemungkinan supaya tidak kena anti-cheat jarak teleport, atau supaya
--      room ter-load. Kalau masih bermasalah, beri tahu gejalanya biar jedanya diperhalus.
-- ============================================================
local SCAN_INTERVAL = 1        -- detik, scan ulang semua Rooms
local ROOM_FIRST, ROOM_LAST = 0, 39
local TARGET_VEIN = "supreme_vein"
local HOP_WAIT = 0.15          -- jeda tiap teleport 1 room (beri waktu room ter-load)
local COLLECT_WAIT = 0.2       -- jeda setelah fireproximityprompt sebelum lanjut
local FARM_HOP_WAIT = 0.12     -- jeda antar rock saat farm room terbaik

local maxBackpack = 10
local collected = 0
local Stats = { status = "-" }
local supremeCountByRoom = {}      -- [roomIndex] = jumlah Supreme yang sudah diambil dari room itu
local roomCentroid = {}            -- [roomIndex] = Vector3 rata-rata posisi rock di room itu
local rocksByRoom = {}             -- [roomIndex] = { rockInstance, ... }
local supremeList = {}             -- { {inst, pos, prompt, room}, ... } — hasil scan terakhir

local roomsFolder = workspace:FindFirstChild("Rooms") or workspace:WaitForChild("Rooms", 10)
local warnedNoPrompt = false

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
    while true do
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

local function BestHistoryRoom()
    local bestRoom, bestN
    for i, n in pairs(supremeCountByRoom) do
        if not bestN or n > bestN then bestRoom, bestN = i, n end
    end
    return bestRoom or ROOM_LAST   -- belum ada riwayat -> anggap room terakhir
end

local function CollectStep(id)
    if collected >= maxBackpack then
        Stats.status = string.format("tas penuh (%d/%d) — tekan Reset Counter setelah jual/kosongkan di game", collected, maxBackpack)
        task.wait(1)
        return
    end

    if #supremeList > 0 then
        local target = supremeList[1]
        Stats.status = "menuju Supreme Vein di Room_" .. target.room
        HopToRoom(id, target.room)
        if runId.collect ~= id then return end
        TP(target.pos)
        task.wait(COLLECT_WAIT)
        if Collect(target.prompt) then
            collected += 1
            supremeCountByRoom[target.room] = (supremeCountByRoom[target.room] or 0) + 1
            Stats.status = string.format("ambil Supreme Vein (%d/%d) · Room_%d", collected, maxBackpack, target.room)
        else
            Stats.status = "gagal collect, coba lagi..."
        end
        return
    end

    local bestRoom = BestHistoryRoom()
    Stats.status = "Supreme Vein habis, menuju Room_" .. bestRoom .. " (penghasil terbanyak)"
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
                        supremeCountByRoom[bestRoom] = (supremeCountByRoom[bestRoom] or 0) + 1
                        Stats.status = string.format("ambil Supreme Vein (%d/%d) · Room_%d", collected, maxBackpack, bestRoom)
                    else
                        -- CATATAN #3: belum tahu remote buang item, jadi item non-Supreme TETAP di tas
                        Stats.status = string.format("farm Room_%d: ambil %s (%d/%d)", bestRoom, rk.Name, collected, maxBackpack)
                    end
                end
            end
        end
    end
end

-- ===== UI =====
local HomePage = W:AddPage({ Name = "Home", Icon = "house" })
local Main = W:AddPage({ Name = "Main", Icon = "gem" })

local cConfig = Main:AddCard({ Title = "Konfigurasi", Icon = "settings", Column = 1 })
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

local cAuto = Main:AddCard({ Title = "Auto Collect Supreme Vein", Icon = "pickaxe", Column = 1 })
local tgCollect = cAuto:Toggle({
    Title = "Auto Collect Supreme Vein", Desc = "Scan semua Rooms, kejar Supreme Vein, fallback ke room penghasil terbanyak", id = "cr_auto",
    Expand = true,
    Callback = function(v)
        Loop("collect", v, function() return 0.1 end, CollectStep)
        if not v then Stats.status = "-" end
        N("Auto Collect Supreme Vein", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
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
            for i, n in pairs(supremeCountByRoom) do parts[#parts + 1] = string.format("Room_%d=%d", i, n) end
            table.sort(parts)
            local txt = "Status: " .. Stats.status ..
                "\nCollected: " .. collected .. " / " .. maxBackpack ..
                "\nRiwayat Supreme: " .. (next(supremeCountByRoom) and table.concat(parts, ", ") or "-")
            stLbl:SetText(txt)
        end)
    end
end)

-- hentikan semua saat Unload
W:OnUnload(function()
    runId.collect += 1
end)
