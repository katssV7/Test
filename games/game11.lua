-- KatssinnnHub | Game 11 (Summit + Fishing Instant/Fast)
-- Sidebar: Home / Main / Summit / Player / Settings (library: ui.lua)
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "Game 11",
    Folder    = "KatssinnnHub/Game11",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- ===== LOOP (bisa dibatalkan, tidak tumpang tindih) =====
local runId = { fish = 0, summit = 0 }
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
local function Sleep(key, id, t)               -- tidur yang bisa dibatalkan; false kalau loop dibatalkan
    local el = 0
    while el < t do
        if runId[key] ~= id then return false end
        el += task.wait(math.min(0.05, t - el + 0.001))
    end
    return runId[key] == id
end

-- ===== PENGATURAN =====
local CAST_POWER  = 100      -- power lempar (contohmu 89)
local CHARGE_WAIT = 0.1      -- jeda antara CastEvent(true) dan CastEvent(false,...)
local CAST_GAP    = 0.1      -- jeda sebelum lempar lagi
local CLICK_GAP   = 0        -- jeda antar batch klik (0 = tiap frame)
local CLICK_INTERVAL = 0.005  -- 5 ms per klik (aman)
local MAX_CLICKS_FRAME = 3    -- batas klik per frame (aman)
local BITE_TIMEOUT, CLICK_TIMEOUT = 10, 12
local MINIGAME_DELAY = 1.25   -- jeda setelah TandaSeruBersama sebelum minigame
local TP_DELAY    = 0.1      -- jeda teleport antar CP
local STAY_CP1    = true     -- avatar terlihat diam di CP 1 (klon lokal)

local Stats = { status = "idle", casts = 0, fish = 0, errors = 0, cp = "-", rounds = 0 }

-- ===== HELPER =====
local function Vec(x, y, z)
    if typeof(vector) == "table" and vector.create then return vector.create(x, y, z) end
    return Vector3.new(x, y, z)
end
local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

-- ===== ROD =====
local function RodTool()
    local c = LP.Character
    if not c then return end
    for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") and t:FindFirstChild("Mechanics") then return t end
    end
    local bp = LP:FindFirstChild("Backpack")
    local h = c:FindFirstChildOfClass("Humanoid")
    if bp and h then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t:FindFirstChild("Mechanics") then
                h:EquipTool(t); task.wait(0.2)
                return t
            end
        end
    end
end
local function RodRemote(name)
    local t = RodTool()
    local m = t and t:FindFirstChild("Mechanics")
    local r = m and m:FindFirstChild("Remotes")
    return r and r:FindFirstChild(name), t
end

-- ===== SINYAL DARI GAME (hook FireServer milik game sendiri) =====
-- TandaSeruBersama = tanda seru (ikan gigit); MiniGame(true) = minigame selesai
local biteN, mgN, hookOk = 0, 0, false
local oldNc
local function InstallHook()
    if oldNc then return true end
    if not (hookmetamethod and getnamecallmethod) then return false end
    local wrap = newcclosure or function(f) return f end
    oldNc = hookmetamethod(game, "__namecall", wrap(function(self, ...)
        if typeof(self) == "Instance" and not (checkcaller and checkcaller()) and getnamecallmethod() == "FireServer" then
            local n = self.Name
            if n == "TandaSeruBersama" then
                biteN += 1
            elseif n == "MiniGame" and (...) == true then
                mgN += 1
            end
        end
        return oldNc(self, ...)
    end))
    hookOk = true
    return true
end
pcall(InstallHook)

local tandaR = RS:FindFirstChild("TandaSeruBersama") or RS:WaitForChild("TandaSeruBersama", 5)
if tandaR and tandaR:IsA("RemoteEvent") then
    pcall(function() tandaR.OnClientEvent:Connect(function() biteN += 1 end) end)
end
local function FireTanda()
    if not tandaR then return false end
    local blue = Color3.new(0.3333333432674408, 0.6352941393852234, 1)
    local dark = Color3.new(0.0784313753247261, 0.0784313753247261, 0.0784313753247261)
    return pcall(function()
        tandaR:FireServer(blue, dark,
            ColorSequence.new({ ColorSequenceKeypoint.new(0, blue), ColorSequenceKeypoint.new(1, blue) }), 1.5)
    end)
end

-- ===== AKSI MEMANCING =====
local function CastRod()
    local ce = RodRemote("CastEvent")
    local hrp = Root()
    if not (ce and hrp) then Stats.errors += 1; return false end
    local look = hrp.CFrame.LookVector
    local h = Vector3.new(look.X, 0, look.Z)
    h = h.Magnitude > 0.01 and h.Unit or Vector3.new(0, 0, -1)
    local ok = pcall(function()
        Stats.status = "cast 1: charge"
        ce:FireServer(true)
        task.wait(CHARGE_WAIT)
        Stats.status = "cast 2: lempar"
        ce:FireServer(false, CAST_POWER, Vec(h.X, 0, h.Z))
    end)
    if ok then Stats.casts += 1 else Stats.errors += 1 end
    return ok
end

local function MiniGameDone()
    local mr = RodRemote("MiniGame")
    if not mr then Stats.errors += 1; return false end
    local ok = pcall(function() mr:FireServer(true) end)
    if ok then Stats.fish += 1 else Stats.errors += 1 end
    return ok
end

-- tap layar (touch, bukan mouse): kiri, di atas tombol jump
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local function TapPos()
    local cam = workspace.CurrentCamera
    local sz = cam and cam.ViewportSize or Vector2.new(800, 600)
    local x, y = 40, sz.Y * 0.5
    pcall(function()
        local jb = LP.PlayerGui.TouchGui.TouchControlFrame.JumpButton
        x = jb.AbsolutePosition.X - 40
        y = jb.AbsolutePosition.Y + GuiService:GetGuiInset().Y - 40
    end)
    return math.max(10, x), math.max(10, y)
end
local function Click()
    local x, y = TapPos()
    return pcall(function()
        VIM:SendTouchEvent(1, 0, x, y)
        VIM:SendTouchEvent(1, 2, x, y)
    end)
end

-- tunggu TandaSeruBersama (setelah cast); false kalau loop dibatalkan
local function WaitBite(id, prefix, b0)
    Stats.status = prefix .. ": menunggu TandaSeruBersama"
    local t0 = os.clock()
    while biteN == b0 do
        if os.clock() - t0 > (hookOk and BITE_TIMEOUT or 5) then Stats.status = prefix .. ": tanda seru timeout"; return true, false end
        if not Sleep("fish", id, 0.05) then return false end
    end
    Stats.status = prefix .. ": TandaSeruBersama muncul"
    return true, true
end

-- Auto Fishing: cast(true) -> cast(false) -> tunggu TandaSeruBersama -> tarik ikan (MiniGame)
local function InstantCycle(id)
    local b0 = biteN
    if not CastRod() then Sleep("fish", id, 1); return end
    local alive, got = WaitBite(id, "auto", b0)
    if not alive then return end
    if got then
        Stats.status = "auto: tunggu " .. MINIGAME_DELAY .. "s"
        if not Sleep("fish", id, MINIGAME_DELAY) then return end
        Stats.status = "auto: tarik ikan (minigame)"
        MiniGameDone()
    end
    Sleep("fish", id, CAST_GAP)
end

-- Fishing Fast: lempar -> tunggu TandaSeruBersama -> klik tiap 0.1s sampai MiniGame(true)
local function FastCycle(id)
    local b0, m0 = biteN, mgN
    Stats.status = "fast: lempar"
    if not CastRod() then Sleep("fish", id, 1); return end

    local alive, got = WaitBite(id, "fast", b0)
    if not alive then return end
    if not got then Sleep("fish", id, CAST_GAP); return end

    Stats.status = "fast: klik"
    t0 = os.clock()
    local lastClick = t0
    while mgN == m0 do
        if os.clock() - t0 > (hookOk and CLICK_TIMEOUT or 3) then break end
        local now = os.clock()
        local n = math.min(MAX_CLICKS_FRAME, math.max(1, math.floor((now - (lastClick or now)) / CLICK_INTERVAL)))
        lastClick = now
        for _ = 1, n do Click() end
        if runId.fish ~= id then return end
        task.wait()
    end
    if mgN > m0 then Stats.fish += 1 end
    Stats.status = "fast: selesai"
    Sleep("fish", id, CAST_GAP)
end

-- ===== SUMMIT =====
local WPS = {
    { "1",       Vector3.new(463.76, 444.65, -8945.72) },
    { "2",       Vector3.new(449.50, 489.00, -9568.00) },
    { "3",       Vector3.new(398.28, 629.00, -10113.53) },
    { "4",       Vector3.new(486.50, 637.00, -10681.00) },
    { "5",       Vector3.new(1088.50, 725.00, -11156.50) },
    { "6",       Vector3.new(973.69, 733.00, -11808.90) },
    { "7",       Vector3.new(391.50, 885.00, -11839.00) },
    { "8",       Vector3.new(-325.87, 849.00, -11738.49) },
    { "9",       Vector3.new(-869.70, 853.00, -11737.40) },
    { "10",      Vector3.new(-1281.53, 857.00, -12093.62) },
    { "11",      Vector3.new(-1310.60, 889.00, -12834.42) },
    { "12",      Vector3.new(-2326.69, 913.00, -12672.86) },
    { "13",      Vector3.new(-2309.10, 917.00, -11856.90) },
    { "14",      Vector3.new(-2444.76, 961.00, -11057.50) },
    { "15",      Vector3.new(-3480.15, 980.84, -11014.89) },
    { "16",      Vector3.new(-4225.70, 1001.00, -11018.01) },
    { "17",      Vector3.new(-4650.55, 1081.00, -11665.26) },
    { "18",      Vector3.new(-5543.91, 1101.00, -11651.75) },
    { "19",      Vector3.new(-6766.57, 1097.00, -11507.14) },
    { "20",      Vector3.new(-6761.15, 1102.39, -10800.56) },
    { "SUMMIT",  Vector3.new(-6765.21, 1310.40, -10082.37) },
    { "BACK BC", Vector3.new(-6830.20, 1312.67, -9844.31) },
}

local function TP(p)
    local r = Root()
    if not r then return false end
    r.CFrame = CFrame.new(p)
    r.AssemblyLinearVelocity = Vector3.zero
    r.AssemblyAngularVelocity = Vector3.zero
    return true
end

-- klon lokal: avatar terlihat diam di CP 1, karakter asli yang teleport
local decoy
local function SetRealHidden(hide)
    local c = LP.Character
    if not c then return end
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") then pcall(function() d.LocalTransparencyModifier = hide and 1 or 0 end) end
    end
end
local function MakeDecoy()
    pcall(function()
        local c = LP.Character
        if not c or decoy then return end
        c.Archivable = true
        local cl = c:Clone()
        if not cl then return end
        for _, d in ipairs(cl:GetDescendants()) do
            if d:IsA("BaseScript") then d:Destroy()
            elseif d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanTouch = false end
        end
        local h = cl:FindFirstChildOfClass("Humanoid")
        if h then h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
        cl.Name = "_decoy"
        cl:PivotTo(CFrame.new(WPS[1][2]))
        cl.Parent = workspace
        decoy = cl
        SetRealHidden(true)
        if h then workspace.CurrentCamera.CameraSubject = h end
    end)
end
local function DropDecoy()
    pcall(function()
        if decoy then decoy:Destroy(); decoy = nil end
        SetRealHidden(false)
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then workspace.CurrentCamera.CameraSubject = h end
    end)
end

local startPos
-- baca CP dari leaderboard (leaderstats)
local function ReadCP()
    local ls = LP:FindFirstChild("leaderstats")
    if not ls then return nil end
    local pick
    for _, v in ipairs(ls:GetChildren()) do
        if v:IsA("ValueBase") and type(v.Value) == "number" then
            local n = v.Name:lower()
            if n:find("checkpoint") then pick = v; break end
            if not pick and (n:find("cp") or n:find("summit") or n:find("stage")) then pick = v end
        end
    end
    return pick and pick.Value
end
local MAX_RETRY = 6
local function SummitRound(id)
    if not Root() then Stats.status = "menunggu karakter"; Sleep("summit", id, 1); return end
    local i, retry = 1, 0
    while i <= #WPS do
        if runId.summit ~= id then return end
        local wp = WPS[i]
        Stats.cp = wp[1] .. " (" .. i .. "/" .. #WPS .. ")"
        Stats.status = "teleport checkpoint " .. wp[1]
        if STAY_CP1 and decoy then SetRealHidden(true) end
        TP(wp[2])
        if not Sleep("summit", id, TP_DELAY) then return end
        -- cek leaderboard: CP harus sudah tercatat, kalau ada yang kelewat ulang dari situ
        local cur = ReadCP()
        if cur and i <= 21 and cur < i and retry < MAX_RETRY then
            retry += 1
            i = math.max(1, math.floor(cur) + 1)
            Stats.status = "checkpoint kelewat, ulang dari CP " .. WPS[i][1]
            if not Sleep("summit", id, 0.2) then return end
        else
            retry = 0
            i += 1
        end
    end
    Stats.rounds += 1
end

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "fish" })
local SummitPage = W:AddPage({ Name = "Summit", Icon = "mountain" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

-- ---------- Fishing ----------
local cFish = Main:AddCard({ Title = "Auto Fishing", Icon = "fish", Column = 1 })
cFish:Toggle({
    Title = "Auto Fishing", Desc = "Cast (2 remote), tunggu TandaSeruBersama, lalu tarik ikan pakai minigame", id = "g11_instant",
    Callback = function(v)
        Loop("fish", v, function() return 0.05 end, InstantCycle)
        if not v then Stats.status = "idle" end
        N("Auto Fishing", v and "ON (matikan Fast dulu kalau aktif)" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cFish:Toggle({
    Title = "Fishing Fast", Desc = "Cast (2 remote), tunggu TandaSeruBersama, lalu klik cepat (tanpa minigame)", id = "g11_fast",
    Callback = function(v)
        Loop("fish", v, function() return 0.05 end, FastCycle)
        if not v then Stats.status = "idle" end
        N("Fishing Fast", v and "ON (matikan Auto Fishing dulu kalau aktif)" or "OFF", v and "#50C864" or "#DC3232")
    end,
})

local cSet = Main:AddCard({ Title = "Pengaturan Lempar", Icon = "pickaxe", Column = 1 })
local okSl = pcall(function()
cSet:Slider({
    Title = "Batas tunggu TandaSeruBersama (detik)", Min = 3, Max = 60, Default = BITE_TIMEOUT, Value = BITE_TIMEOUT,
    Increment = 1, Step = 1, Suffix = "s", id = "g11_bitetimeout",
    Callback = function(v) local n = tonumber(v); if n then BITE_TIMEOUT = n end end,
})
end)
if not okSl then
    cSet:Input({
        Title = "Batas tunggu tanda seru (detik)", Value = tostring(BITE_TIMEOUT), Placeholder = "10", ButtonText = "Set", id = "g11_bitetimeout",
        Callback = function(v) local n = tonumber(v); if n then BITE_TIMEOUT = n end end,
        OnButton = function(v) local n = tonumber(v); if n then BITE_TIMEOUT = n end end,
    })
end
cSet:Input({
    Title = "Power lempar", Value = tostring(CAST_POWER), Placeholder = "100", ButtonText = "Set", id = "g11_power",
    Callback = function(v) local n = tonumber(v); if n then CAST_POWER = n end end,
    OnButton = function(v) local n = tonumber(v); if n then CAST_POWER = n; N("Power", "Diset: " .. n, "#50C864") end end,
})

local cMan = Main:AddCard({ Title = "Manual", Icon = "pointer", Column = 2 })
cMan:Button({
    Title = "Lempar sekali", Text = "CastEvent sekali",
    Callback = function()
        local ok = CastRod()
        N("Lempar", ok and "Terkirim" or "Gagal (rod / karakter?)", ok and "#6495ED" or "#DC3232")
    end,
})
cMan:Button({
    Title = "Selesai sekali", Text = "TandaSeru + MiniGame(true) sekali",
    Callback = function()
        FireTanda()
        local ok = MiniGameDone()
        N("Selesai", ok and "Terkirim" or "Gagal", ok and "#6495ED" or "#DC3232")
    end,
})

local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })

-- ---------- Summit ----------
local cSum = SummitPage:AddCard({ Title = "Auto Summit", Icon = "mountain", Column = 1 })
cSum:Toggle({
    Title = "Auto Summit (CP 1 -> SUMMIT -> BACK BC)", Desc = "Teleport berurutan lalu ulang dari CP 1 terus", id = "g11_summit",
    Callback = function(v)
        if v then
            local r = Root()
            startPos = r and r.Position
            if STAY_CP1 then MakeDecoy() end
        end
        Loop("summit", v, function() return 0.02 end, SummitRound)
        if not v then
            Stats.status = "idle"
            DropDecoy()
            if startPos then task.delay(0.15, function() TP(startPos) end) end
        end
        N("Auto Summit", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cSum:Toggle({
    Title = "Avatar diam di CP 1 (klon lokal)", Desc = "Hanya tampilan di layarmu; karakter asli tetap teleport. Pasang sebelum ON", Value = true, id = "g11_stay",
    Callback = function(v) STAY_CP1 = v end,
})
cSum:Input({
    Title = "Delay teleport (detik)", Value = tostring(TP_DELAY), Placeholder = "0.1", ButtonText = "Set", id = "g11_tpdelay",
    Callback = function(v) local n = tonumber(v); if n then TP_DELAY = math.max(0.03, n) end end,
    OnButton = function(v) local n = tonumber(v); if n then TP_DELAY = math.max(0.03, n); N("Delay", "Diset: " .. TP_DELAY, "#50C864") end end,
})

local cTp = SummitPage:AddCard({ Title = "Teleport Manual", Icon = "map-pin", Column = 2 })
cTp:Input({
    Title = "Nomor CP (1-22)", Value = "1", Placeholder = "1-22", ButtonText = "TP", id = "g11_cp",
    OnButton = function(v)
        local n = math.floor(tonumber(v) or 0)
        local wp = WPS[n]
        if wp and TP(wp[2]) then N("Teleport", "CP " .. wp[1], "#6495ED")
        else N("Teleport", "Nomor tidak valid / karakter belum ada", "#DC3232") end
    end,
})
local cSumSt = SummitPage:AddCard({ Title = "Status Summit", Icon = "activity", Column = 2 })
local sumLbl = cSumSt:Label({ Text = "-", Size = 11, Color = "Text" })

task.spawn(function()
    while W.Alive do
        task.wait(0.5)
        pcall(function()
            stLbl:SetText("Status: " .. Stats.status ..
                "\nLempar: " .. Stats.casts .. "   Ikan: " .. Stats.fish .. "   Error: " .. Stats.errors ..
                "\nHook sinyal game: " .. (hookOk and "aktif" or "TIDAK (pakai timer)"))
            sumLbl:SetText("CP: " .. Stats.cp .. "\nPutaran: " .. Stats.rounds .. "\nDelay: " .. TP_DELAY .. "s")
        end)
    end
end)

W:OnUnload(function()
    for k in pairs(runId) do runId[k] += 1 end
    DropDecoy()
end)

-- Player dan Home (+ Settings) ada di ui.lua; tiap bagian aman dari error.
for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildHome({ Game = "Game 11", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[KatssinnnHub] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()
W:OnBooted(function() N("KatssinnnHub", "Game 11 dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4) end)
