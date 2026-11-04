-- ============================================================
--  CUT A ROCK — Auto Collect Supreme Vein
--  Struktur: workspace.Rooms.Room_0 .. Room_39 > Rocks > (model rock, nama = jenis vein)
--
--  CARA KERJA:
--   1. Scan ulang SEMUA Rooms tiap SCAN_INTERVAL detik (rock bisa hilang/muncul lagi
--      dengan jenis berbeda di posisi yang sama, jadi tidak boleh pakai daftar tetap).
--   2. Kalau ada Supreme Vein: teleport "melompat" lewat centroid tiap room secara berurutan
--      dari room terdekat pemain sampai room tujuan (bukan loncat jauh sekali), baru
--      teleport pas ke Supreme Vein itu, lalu langsung collect lewat ProximityPrompt
--      (fireproximityprompt, tidak perlu tekan/tahan manual).
--   3. Kalau Supreme Vein TIDAK ADA di semua room: pergi ke room yang riwayatnya paling
--      banyak menghasilkan Supreme Vein (dihitung sendiri selama script jalan), lalu
--      collect rock apa pun yang ada di room itu (supaya slot kosong & room "menghasilkan"
--      rock baru, siapa tahu Supreme).
--   4. "Tas penuh": dihitung dari internal counter dibandingkan Max Backpack yang kamu
--      isi sendiri di menu, BUKAN dibaca dari UI game (lihat catatan #2 di bawah).
--
--  CATATAN / ASUMSI YANG PERLU KAMU VERIFIKASI:
--   1. Collect pakai fireproximityprompt ke ProximityPrompt asli di tiap rock (seperti kamu
--      minta: "ga usah ditekan dulu"). Ini TIDAK memanggil remote CepTasSil secara manual -
--      begitu prompt di-fire, script GAME itu sendiri yang mengirim remote dengan GUID yang
--      benar. Kalau executor kamu tidak punya fireproximityprompt, fitur ini tidak jalan
--      (akan muncul peringatan sekali di konsol).
--   2. MAX BACKPACK: saya TIDAK tahu cara baca sisa slot tas dari game (butuh SimpleSpy/UI
--      scan lebih lanjut). Jadi script menghitung sendiri (internal counter) tiap berhasil
--      collect SESUATU, dan berhenti kalau sudah mencapai angka yang kamu isi di menu.
--      Kalau kamu jual/kosongkan tas secara manual di game, tekan tombol RESET di menu.
--   3. BUANG ITEM SELAIN SUPREME: belum saya buat, karena saya belum tahu remote untuk
--      membuang 1 item dari tas (CepTasSil kemungkinan cuma untuk collect, bukan buang).
--      Kalau kamu kirim hasil SimpleSpy/attack_probe waktu kamu buang 1 item manual di game,
--      saya tambahkan fungsi buangnya. Untuk sekarang, mode "farm room terbaik" HANYA
--      collect (tidak membuang), jadi tas bisa penuh berisi campuran sebelum sempat dapat
--      Supreme lagi — pantau manual dulu.
--   4. Lompat per-room (bukan loncat 1x jauh) itu tebakan saya dari permintaan kamu soal
--      "dijangkau studnya dulu" — kemungkinan supaya tidak kena anti-cheat jarak teleport,
--      atau supaya room ter-load. Kalau masih bermasalah (kena kick / room tidak sempat
--      muncul), beri tahu saya gejalanya biar saya perhalus jedanya.
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

if getgenv and getgenv().__CUTROCK then pcall(getgenv().__CUTROCK) end  -- matikan instance lama

-- ===== KONFIGURASI =====
local SCAN_INTERVAL = 1        -- detik, scan ulang semua Rooms
local ROOM_FIRST, ROOM_LAST = 0, 39
local TARGET_VEIN = "supreme_vein"
local HOP_WAIT = 0.15          -- jeda tiap lompat 1 room (beri waktu room ter-load)
local COLLECT_WAIT = 0.2       -- jeda setelah fireproximityprompt sebelum lanjut
local FARM_HOP_WAIT = 0.12     -- jeda antar rock saat farm room terbaik

-- ===== STATE =====
local maxBackpack = 10
local collected = 0
local running = false
local status = "-"
local supremeCountByRoom = {}      -- [roomIndex] = jumlah Supreme yang sudah diambil dari room itu
local roomCentroid = {}            -- [roomIndex] = Vector3 rata-rata posisi rock di room itu
local rocksByRoom = {}             -- [roomIndex] = { rockInstance, ... }
local supremeList = {}             -- { {inst, pos, prompt, room}, ... } — hasil scan terakhir

local roomsFolder = workspace:FindFirstChild("Rooms") or workspace:WaitForChild("Rooms", 10)
local warnedNoPrompt = false

-- ===== KARAKTER / TELEPORT =====
local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function TP(pos)
    local hrp = Root()
    if not (hrp and pos) then return false end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
    pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    return true
end

-- ===== BACA ROCK =====
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

-- ===== SCAN SEMUA ROOMS =====
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

-- ===== COLLECT (fireproximityprompt, instan tanpa tahan tombol) =====
local function Collect(prompt)
    if typeof(fireproximityprompt) ~= "function" then
        if not warnedNoPrompt then
            warnedNoPrompt = true
            warn("[CutRock] Executor tidak punya fireproximityprompt: tidak bisa auto-collect")
        end
        return false
    end
    return pcall(fireproximityprompt, prompt, 0)
end

-- ===== LOMPAT PER-ROOM (bukan loncat jauh sekali) =====
local function NearestRoomIndex(pos)
    local best, bd
    for i, c in pairs(roomCentroid) do
        local d = (c - pos).Magnitude
        if not bd or d < bd then best, bd = i, d end
    end
    return best
end
local function HopToRoom(targetRoom)
    local hrp = Root()
    if not hrp then return end
    local cur = NearestRoomIndex(hrp.Position) or targetRoom
    local step = targetRoom >= cur and 1 or -1
    for i = cur, targetRoom, step do
        if not running then return end
        local c = roomCentroid[i]
        if c then
            TP(c)
            task.wait(HOP_WAIT)
        end
    end
end

-- ===== LANGKAH UTAMA =====
local function BestHistoryRoom()
    local bestRoom, bestN
    for i, n in pairs(supremeCountByRoom) do
        if not bestN or n > bestN then bestRoom, bestN = i, n end
    end
    return bestRoom or ROOM_LAST   -- belum ada riwayat -> anggap room terakhir (paling sering Supreme dari data awal)
end

local function Step()
    if collected >= maxBackpack then
        status = string.format("tas penuh (%d/%d) — tekan RESET setelah kamu jual/kosongkan di game", collected, maxBackpack)
        return
    end

    if #supremeList > 0 then
        local target = supremeList[1]
        status = "menuju Supreme Vein di Room_" .. target.room
        HopToRoom(target.room)
        if not running then return end
        TP(target.pos)
        task.wait(COLLECT_WAIT)
        if Collect(target.prompt) then
            collected += 1
            supremeCountByRoom[target.room] = (supremeCountByRoom[target.room] or 0) + 1
            status = string.format("ambil Supreme Vein (%d/%d) · Room_%d", collected, maxBackpack, target.room)
        else
            status = "gagal collect, coba lagi..."
        end
        return
    end

    -- tidak ada Supreme Vein di mana pun -> ke room penghasil Supreme terbanyak (riwayat)
    local bestRoom = BestHistoryRoom()
    status = "Supreme Vein habis, menuju Room_" .. bestRoom .. " (penghasil terbanyak)"
    HopToRoom(bestRoom)
    if not running then return end

    local list = rocksByRoom[bestRoom] or {}
    for _, rk in ipairs(list) do
        if not running or collected >= maxBackpack then return end
        if rk.Parent then          -- rock bisa hilang selagi loop (sudah di-collect orang lain / respawn)
            local pos = RockPos(rk)
            local prompt = FindPrompt(rk)
            if pos and prompt then
                TP(pos)
                task.wait(FARM_HOP_WAIT)
                if Collect(prompt) then
                    collected += 1
                    if rk.Name == TARGET_VEIN then
                        supremeCountByRoom[bestRoom] = (supremeCountByRoom[bestRoom] or 0) + 1
                        status = string.format("ambil Supreme Vein (%d/%d) · Room_%d", collected, maxBackpack, bestRoom)
                    else
                        -- CATATAN #3: belum tahu remote buang item, jadi item non-Supreme TETAP di tas
                        status = string.format("farm Room_%d: ambil %s (%d/%d)", bestRoom, rk.Name, collected, maxBackpack)
                    end
                end
            end
        end
    end
end

-- ===== LOOP (scan + jalan) =====
task.spawn(function()
    while true do
        pcall(Scan)
        task.wait(SCAN_INTERVAL)
    end
end)
task.spawn(function()
    while true do
        if running then
            local ok, err = pcall(Step)
            if not ok then warn("[CutRock] " .. tostring(err)) end
        end
        task.wait(0.1)
    end
end)

-- ===== GUI =====
local parent = (gethui and gethui()) or game:GetService("CoreGui")
local ok0 = pcall(function() local _ = parent.Name end)
if not ok0 then parent = LP:WaitForChild("PlayerGui") end
local sg = Instance.new("ScreenGui")
sg.Name = "CutRockHub"; sg.ResetOnSpawn = false; sg.DisplayOrder = 999
if syn and syn.protect_gui then pcall(syn.protect_gui, sg) end
sg.Parent = parent

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 190)
frame.Position = UDim2.new(1, -310, 0, 60)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -10, 0, 22); title.Position = UDim2.new(0, 8, 0, 2)
title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBold; title.TextSize = 13
title.TextColor3 = Color3.fromRGB(255, 200, 80); title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "CUT A ROCK  •  Auto Supreme Vein"; title.Parent = frame

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -16, 0, 50); statusLbl.Position = UDim2.new(0, 8, 0, 26)
statusLbl.BackgroundColor3 = Color3.fromRGB(10, 10, 14); statusLbl.BorderSizePixel = 0
statusLbl.Font = Enum.Font.Code; statusLbl.TextSize = 11; statusLbl.TextWrapped = true
statusLbl.TextColor3 = Color3.fromRGB(210, 210, 220)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left; statusLbl.TextYAlignment = Enum.TextYAlignment.Top
statusLbl.Text = "-"; statusLbl.Parent = frame
Instance.new("UICorner", statusLbl).CornerRadius = UDim.new(0, 6)
Instance.new("UIPadding", statusLbl).PaddingLeft = UDim.new(0, 6)

local mbLbl = Instance.new("TextLabel")
mbLbl.Size = UDim2.new(0, 90, 0, 24); mbLbl.Position = UDim2.new(0, 8, 0, 82)
mbLbl.BackgroundTransparency = 1; mbLbl.Font = Enum.Font.Gotham; mbLbl.TextSize = 12
mbLbl.TextColor3 = Color3.new(1, 1, 1); mbLbl.TextXAlignment = Enum.TextXAlignment.Left
mbLbl.Text = "Max Backpack:"; mbLbl.Parent = frame

local mbBox = Instance.new("TextBox")
mbBox.Size = UDim2.new(0, 70, 0, 24); mbBox.Position = UDim2.new(0, 110, 0, 82)
mbBox.BackgroundColor3 = Color3.fromRGB(35, 38, 55); mbBox.BorderSizePixel = 0
mbBox.Font = Enum.Font.GothamBold; mbBox.TextSize = 13; mbBox.TextColor3 = Color3.new(1, 1, 1)
mbBox.Text = tostring(maxBackpack); mbBox.ClearTextOnFocus = false; mbBox.Parent = frame
Instance.new("UICorner", mbBox).CornerRadius = UDim.new(0, 6)

local function Btn(text, x, y, w, h, fn)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, h); b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(45, 48, 70); b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.TextColor3 = Color3.new(1, 1, 1)
    b.Text = text; b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function() fn(b) end)
    return b
end

Btn("Set", 190, 82, 50, 24, function()
    local n = tonumber(mbBox.Text)
    if n and n > 0 then
        maxBackpack = math.floor(n)
        status = "Max Backpack diset ke " .. maxBackpack
    end
end)

local toggleBtn
toggleBtn = Btn("MULAI", 8, 114, 130, 28, function(b)
    running = not running
    b.Text = running and "STOP" or "MULAI"
    status = running and "memulai..." or "berhenti"
end)
Btn("RESET", 146, 114, 70, 28, function()
    collected = 0
    status = "counter direset ke 0"
end)
Btn("TUTUP", 222, 114, 70, 28, function()
    if getgenv and getgenv().__CUTROCK then getgenv().__CUTROCK() end
end)

local histLbl = Instance.new("TextLabel")
histLbl.Size = UDim2.new(1, -16, 0, 34); histLbl.Position = UDim2.new(0, 8, 0, 150)
histLbl.BackgroundTransparency = 1; histLbl.Font = Enum.Font.Gotham; histLbl.TextSize = 10
histLbl.TextColor3 = Color3.fromRGB(160, 160, 170); histLbl.TextWrapped = true
histLbl.TextXAlignment = Enum.TextXAlignment.Left; histLbl.TextYAlignment = Enum.TextYAlignment.Top
histLbl.Text = ""; histLbl.Parent = frame

-- refresh tampilan
local conns = {}
conns[#conns + 1] = RunService.Heartbeat:Connect(function()
    statusLbl.Text = string.format("Status: %s\nCollected: %d / %d", status, collected, maxBackpack)
    local parts = {}
    for i, n in pairs(supremeCountByRoom) do parts[#parts + 1] = string.format("Room_%d=%d", i, n) end
    table.sort(parts)
    histLbl.Text = "Riwayat Supreme: " .. (next(supremeCountByRoom) and table.concat(parts, ", ") or "-")
end)

local function Shutdown()
    running = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if sg then sg:Destroy() end
    if getgenv then getgenv().__CUTROCK = nil end
end
if getgenv then getgenv().__CUTROCK = Shutdown end
