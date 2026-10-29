-- KatssinnnHub | Game 6 (Harpoon a Fish)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Siklus Auto Farm: jalan ke StandPoint harpoon -> Dive -> tembak ikan -> mini game (ReelBeat) -> Exit saat tas penuh.
-- Tambahan: Auto Upgrade Table, Auto Grow ikan (scan ID), Auto Equip Best, Remote Logger (untuk kalibrasi).
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "Harpoon a Fish",
    Folder    = "KatssinnnHub/HarpoonAFish",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- ===== LOOP (bisa dibatalkan, tidak pernah tumpang tindih) =====
local runId = { farm = 0, upg = 0, grow = 0, equip = 0 }
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
local function Sleep(key, t, id)         -- tidur yang bisa dibatalkan
    local el = 0
    while el < t do
        if runId[key] ~= id then return false end
        el += task.wait(math.min(0.05, t - el + 0.001))
    end
    return runId[key] == id
end

-- ===== PENGATURAN =====
local OPT = { walk = true, fire = true, reel = true, exit = true, teleport = false }
local FIRE_CD, REEL_INT, MAX_DIVE, LEAD, MAX_RANGE = 0.8, 0.4, 90, 0, 600
local PLOT_CHOICE = "Auto"
local UPG_INT, EQUIP_INT, GROW_INT = 3, 60, 20
local BRUTE, BRUTE_MAX = false, 40

local Stats = { trips = 0, shots = 0, beats = 0, errors = 0, status = "idle", bag = "-", plot = "-", grow = 0 }

-- ===== REMOTE =====
local function V3(x, y, z)
    local ok, v = pcall(function() return vector.create(x, y, z) end)   -- tipe vector seperti remote asli
    if ok and v then return v end
    return Vector3.new(x, y, z)
end

local RemotesF
local function Remote(name)
    if not (RemotesF and RemotesF.Parent) then
        RemotesF = RS:FindFirstChild("Remotes") or RS:WaitForChild("Remotes", 5)
    end
    return RemotesF and (RemotesF:FindFirstChild(name) or RemotesF:WaitForChild(name, 5))
end
local function Fire(name, ...)
    local r = Remote(name)
    if not r then Stats.errors += 1; return false end
    local ok = pcall(r.FireServer, r, ...)
    if not ok then Stats.errors += 1 end
    return ok
end
local function Now() return workspace:GetServerTimeNow() end   -- cap waktu seperti contoh (±1.79e9)

-- ===== KARAKTER =====
local function Hum()
    local c = LP.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h and h.Health > 0 then return h end
end
local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function dist2(a, b) local dx, dz = a.X - b.X, a.Z - b.Z; return math.sqrt(dx * dx + dz * dz) end

-- ===== PLOT & HARPOON =====
local plotCache
local function OwnsPlot(plot)
    local function match(v)
        if v == LP then return true end
        if type(v) == "number" then return v == LP.UserId end
        if type(v) == "string" then return v == LP.Name or v == LP.DisplayName or v == tostring(LP.UserId) end
        return false
    end
    for k, v in pairs(plot:GetAttributes()) do
        local kl = tostring(k):lower()
        if (kl:find("owner") or kl:find("user") or kl:find("player")) and match(v) then return true end
    end
    for _, d in ipairs(plot:GetDescendants()) do
        local nl = d.Name:lower()
        if (nl:find("owner") or nl:find("player")) and (d:IsA("ObjectValue") or d:IsA("StringValue") or d:IsA("IntValue") or d:IsA("NumberValue")) then
            if match(d.Value) then return true end
        end
        if d:IsA("TextLabel") and d.Text ~= "" and (d.Text:find(LP.Name, 1, true) or d.Text:find(LP.DisplayName, 1, true)) then return true end
    end
    return false
end

local function GetPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    if PLOT_CHOICE ~= "Auto" then return plots:FindFirstChild(PLOT_CHOICE) end
    if plotCache and plotCache.Parent == plots then return plotCache end
    for _, p in ipairs(plots:GetChildren()) do
        if OwnsPlot(p) then plotCache = p; return p end
    end
    return plots:FindFirstChild("Plot1")      -- cadangan
end

local function HarpoonStand()
    local plot = GetPlot()
    local h = plot and plot:FindFirstChild("Harpoon")
    if not h then return nil end
    Stats.plot = plot.Name
    local sp = h:FindFirstChild("StandPoint", true)
    if sp and sp:IsA("BasePart") then return sp end
    return h:FindFirstChildWhichIsA("BasePart", true)
end

-- jalan (Pathfinding + MoveTo), tanpa teleport kecuali diizinkan
local function WalkTo(target, id)
    for attempt = 1, 3 do
        local hum, hrp = Hum(), Root()
        if not hum or not hrp then return false end
        if dist2(hrp.Position, target) <= 4 and math.abs(hrp.Position.Y - target.Y) < 8 then return true end
        local wps
        local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
        local ok = pcall(function() path:ComputeAsync(hrp.Position, target) end)
        if ok and path.Status == Enum.PathStatus.Success then wps = path:GetWaypoints() end
        if not wps then wps = { { Position = target, Action = Enum.PathWaypointAction.Walk } } end
        for _, wp in ipairs(wps) do
            if runId.farm ~= id then return false end
            local h2 = Hum()
            if not h2 then return false end
            if wp.Action == Enum.PathWaypointAction.Jump then h2.Jump = true end
            h2:MoveTo(wp.Position)
            local t0 = os.clock()
            while os.clock() - t0 < 4 do
                if runId.farm ~= id then return false end
                local r = Root()
                if not r then return false end
                if dist2(r.Position, wp.Position) < 3 then break end
                task.wait(0.1)
            end
        end
    end
    local hrp = Root()
    if hrp and dist2(hrp.Position, target) <= 6 then return true end
    if OPT.teleport and hrp then
        hrp.CFrame = CFrame.new(target + Vector3.new(0, 3, 0))
        task.wait(0.3)
        return true
    end
    return false
end

-- ===== DETEKSI GUI (tas, mini game) =====
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
local function FindLabel(key, pred)
    local c = guiCache[key]
    if c and c.Parent and c:IsDescendantOf(PG) then return c end
    local last = guiCache[key .. "_t"] or 0
    if os.clock() - last < 1.5 then return nil end
    guiCache[key .. "_t"] = os.clock()
    for _, d in ipairs(PG:GetDescendants()) do
        if d:IsA("TextLabel") and pred(d) then guiCache[key] = d; return d end
    end
end

local function NearKg(lbl)       -- label "3/5" dianggap tas kalau ada teks "kg" di dekatnya
    local o = lbl.Parent
    for _ = 1, 3 do
        if not o or o == PG then return false end
        for _, d in ipairs(o:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text:lower():find("kg") then return true end
        end
        o = o.Parent
    end
    return false
end

local function Bag()
    local lbl = FindLabel("bag", function(d)
        return d.Text:match("^%s*%d+%s*/%s*%d+%s*$") ~= nil and NearKg(d)
    end)
    if not lbl then return nil end
    local a, b = lbl.Text:match("(%d+)%s*/%s*(%d+)")
    a, b = tonumber(a), tonumber(b)
    if a and b then Stats.bag = a .. "/" .. b; return a, b end
end

local function ReelActive()
    local lbl = FindLabel("tap", function(d)
        local t = d.Text:upper():gsub("%s+", "")
        return t == "TAP"
    end)
    return lbl ~= nil and Shown(lbl)
end

-- ===== IKAN =====
local function FishPart(f)
    if f:IsA("BasePart") then return f end
    if f:IsA("Model") then return f.PrimaryPart or f:FindFirstChildWhichIsA("BasePart", true) end
end
local function NearestFish()
    local folder = workspace:FindFirstChild("Fish")
    if not folder then return nil end
    local cam = workspace.CurrentCamera
    local origin = cam and cam.CFrame.Position or (Root() and Root().Position) or Vector3.zero
    local best, bd
    for _, f in ipairs(folder:GetChildren()) do
        local p = FishPart(f)
        if p then
            local d = (p.Position - origin).Magnitude
            if d <= MAX_RANGE and (not bd or d < bd) then best, bd = p, d end
        end
    end
    return best
end

-- ===== AUTO FARM =====
local S = { state = "surface", t0 = 0, lastFire = 0, lastReel = 0 }

local function ExitDive(id)
    Stats.status = "exit harpoon"
    Fire("HarpoonExit")
    S.state = "surface"
    Stats.trips += 1
    Sleep("farm", 3, id)
end

local function FarmStep(id)
    if not Hum() then Stats.status = "menunggu karakter"; S.state = "surface"; Sleep("farm", 1, id) return end

    if S.state == "surface" then
        if OPT.walk then
            local sp = HarpoonStand()
            if not sp then Stats.status = "Harpoon tidak ketemu di Plots"; Sleep("farm", 2, id) return end
            Stats.status = "jalan ke harpoon"
            if not WalkTo(sp.Position, id) then Stats.status = "gagal sampai harpoon"; Sleep("farm", 1.5, id) return end
        end
        Stats.status = "dive"
        Fire("HarpoonDive")
        S.state, S.t0, S.lastFire, S.lastReel = "diving", os.clock(), 0, 0
        Sleep("farm", 3, id)           -- tunggu transisi turun
        return
    end

    -- ===== sedang dive =====
    local now = os.clock()

    -- dive gagal? (label DEPTH ada tapi tidak tampil setelah 6 detik)
    if now - S.t0 > 6 then
        local d = FindLabel("depth", function(l) return l.Text:upper():find("DEPTH") ~= nil end)
        if d and not Shown(d) and not ReelActive() then
            S.state = "surface"; Stats.status = "dive gagal, ulangi"; return
        end
    end

    if OPT.exit then
        local cur, max = Bag()
        if cur and max and cur >= max then ExitDive(id) return end
    end
    if now - S.t0 > MAX_DIVE then ExitDive(id) return end

    if OPT.reel and ReelActive() then
        Stats.status = "mini game"
        if now - S.lastReel >= REEL_INT then
            S.lastReel = now
            Fire("ReelBeat", Now())
            Stats.beats += 1
        end
        return
    end

    if OPT.fire then
        if now - S.lastFire >= FIRE_CD then
            local p = NearestFish()
            if p then
                local pos = p.Position + p.AssemblyLinearVelocity * LEAD
                Fire("HarpoonFire", V3(pos.X, pos.Y, pos.Z), Now())
                S.lastFire = now
                Stats.shots += 1
                Stats.status = "menembak ikan"
            else
                Stats.status = "mencari ikan"
            end
        end
    end
end

-- ===== AQUARIUM: scan ID ikan =====
local ID_ATTR = { "Id", "ID", "FishId", "FishID", "UID", "Uid", "Index" }
local idCache, idT = {}, 0
local function CollectIds()
    if os.clock() - idT < 10 then return idCache end
    idT = os.clock()
    local set = {}
    local function consider(i)
        local n = tonumber(i.Name)
        if n and n >= 0 and n < 1e6 and n == math.floor(n) then set[n] = true end
        for _, a in ipairs(ID_ATTR) do
            local v = i:GetAttribute(a)
            if type(v) == "number" and v >= 0 and v < 1e6 then set[v] = true end
        end
        if i:IsA("IntValue") or i:IsA("NumberValue") then
            local nl = i.Name:lower()
            if nl == "id" or nl == "fishid" or nl == "uid" then set[i.Value] = true end
        end
    end
    local function scan(root)
        if not root then return end
        for _, d in ipairs(root:GetDescendants()) do consider(d) end
    end
    scan(LP:FindFirstChildOfClass("Backpack"))
    for _, c in ipairs(LP:GetChildren()) do
        if c ~= LP.Character and c ~= PG and not c:IsA("Backpack") then scan(c) end
    end
    scan(PG)
    scan(GetPlot())
    for _, c in ipairs(RS:GetChildren()) do
        if c.Name == LP.Name or c.Name == tostring(LP.UserId) then scan(c) end
        for _, cc in ipairs(c:GetChildren()) do
            if cc.Name == LP.Name or cc.Name == tostring(LP.UserId) then scan(cc) end
        end
    end
    local list = {}
    for n in pairs(set) do list[#list + 1] = n end
    table.sort(list)
    if #list > 80 then for i = #list, 81, -1 do list[i] = nil end end
    idCache = list
    return list
end

local function GrowStep(id)
    local ids = {}
    for _, n in ipairs(CollectIds()) do ids[#ids + 1] = n end
    if BRUTE then
        local have = {}
        for _, n in ipairs(ids) do have[n] = true end
        for n = 1, BRUTE_MAX do if not have[n] then ids[#ids + 1] = n end end
    end
    if #ids == 0 then Stats.grow = 0; return end
    for _, n in ipairs(ids) do
        if runId.grow ~= id then return end
        Fire("AquariumAction", "Grow", n)
        if not Sleep("grow", 0.25, id) then return end
    end
end

-- ===== REMOTE LOGGER (untuk melihat nilai asli remote saat kamu main manual) =====
local logOn, logLines, oldNc = false, {}, nil
local function Fmt(v)
    local t = typeof(v)
    if t == "number" then return string.format("%.4f", v) end
    if t == "string" then return '"' .. v .. '"' end
    if t == "Vector3" or t == "vector" then return string.format("vec(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) end
    return tostring(v)
end
local function InstallHook()
    if oldNc then return true end
    if not (hookmetamethod and getnamecallmethod) then return false end
    local wrap = newcclosure or function(f) return f end
    oldNc = hookmetamethod(game, "__namecall", wrap(function(self, ...)
        if logOn and getnamecallmethod() == "FireServer" and typeof(self) == "Instance"
            and RemotesF and self.Parent == RemotesF and not (checkcaller and checkcaller()) then
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
        return oldNc(self, ...)
    end))
    return true
end

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "fish" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

-- ---------- kolom 1: Auto Farm ----------
local cFarm = Main:AddCard({ Title = "Auto Harpoon", Icon = "fish", Column = 1 })
cFarm:Toggle({
    Title = "Auto Farm (jalan > dive > tembak > mini game > exit)", id = "hf_farm",
    Callback = function(v)
        if v then S.state = "surface" end
        Loop("farm", v, function() return 0.05 end, FarmStep)
        if not v then Stats.status = "idle" end
        N("Auto Farm", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cFarm:Toggle({ Title = "Jalan ke harpoon + Dive", Value = true, id = "hf_opt_walk", Callback = function(v) OPT.walk = v end })
cFarm:Toggle({ Title = "Auto tembak harpoon", Value = true, id = "hf_opt_fire", Callback = function(v) OPT.fire = v end })
cFarm:Toggle({ Title = "Auto mini game (ReelBeat)", Value = true, id = "hf_opt_reel", Callback = function(v) OPT.reel = v end })
cFarm:Toggle({ Title = "Exit otomatis saat tas penuh", Value = true, id = "hf_opt_exit", Callback = function(v) OPT.exit = v end })
cFarm:Toggle({ Title = "Teleport kalau jalan gagal", Value = false, id = "hf_opt_tp", Callback = function(v) OPT.teleport = v end })

local plotList = { "Auto" }
pcall(function()
    local plots = workspace:FindFirstChild("Plots")
    if plots then for _, p in ipairs(plots:GetChildren()) do plotList[#plotList + 1] = p.Name end end
end)
cFarm:Dropdown({
    Title = "Plot", List = plotList, Value = "Auto", id = "hf_plot",
    Callback = function(v) if v then PLOT_CHOICE = tostring(v); plotCache = nil end end,
})

local cTune = Main:AddCard({ Title = "Tuning", Icon = "wrench", Column = 1, Collapsed = true })
cTune:Slider({ Title = "Jeda tembak (s)", Min = 0.2, Max = 3, Value = 0.8, Rounding = 2, id = "hf_fire_cd", Callback = function(v) FIRE_CD = v end })
cTune:Slider({ Title = "Interval ReelBeat (s)", Min = 0.1, Max = 1.5, Value = 0.4, Rounding = 2, id = "hf_reel_int", Callback = function(v) REEL_INT = v end })
cTune:Slider({ Title = "Maks. waktu per dive (s)", Min = 20, Max = 240, Value = 90, Rounding = 0, id = "hf_maxdive", Callback = function(v) MAX_DIVE = v end })
cTune:Slider({ Title = "Prediksi gerak ikan (lead)", Min = 0, Max = 1, Value = 0, Rounding = 2, id = "hf_lead", Callback = function(v) LEAD = v end })
cTune:Slider({ Title = "Jarak maks. target ikan", Min = 50, Max = 1500, Value = 600, Rounding = 0, id = "hf_range", Callback = function(v) MAX_RANGE = v end })

-- ---------- kolom 2: Table / Aquarium ----------
local cTbl = Main:AddCard({ Title = "Table & Aquarium", Icon = "package", Column = 2 })
cTbl:Toggle({
    Title = "Auto Upgrade Table", id = "hf_upg",
    Callback = function(v)
        Loop("upg", v, function() return UPG_INT end, function() Fire("TableUpgrade") end)
        N("Auto Upgrade Table", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cTbl:Slider({ Title = "Jeda upgrade (s)", Min = 0.5, Max = 30, Value = 3, Rounding = 1, id = "hf_upg_int", Callback = function(v) UPG_INT = v end })
cTbl:Toggle({
    Title = "Auto Grow ikan (scan ID)", id = "hf_grow",
    Callback = function(v)
        Loop("grow", v, function() return GROW_INT end, GrowStep)
        N("Auto Grow", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
        if v then
            task.defer(function()
                local n = #CollectIds()
                if n == 0 and not BRUTE then
                    N("Auto Grow", "ID ikan tidak ketemu. Nyalakan Brute-force ID atau pakai Remote Logger.", "#FFA500", 6)
                end
            end)
        end
    end,
})
cTbl:Slider({ Title = "Jeda antar putaran grow (s)", Min = 2, Max = 120, Value = 20, Rounding = 0, id = "hf_grow_int", Callback = function(v) GROW_INT = v end })
cTbl:Toggle({ Title = "Brute-force ID (cadangan)", id = "hf_brute", Callback = function(v) BRUTE = v end })
cTbl:Slider({ Title = "Brute-force sampai ID", Min = 5, Max = 200, Value = 40, Rounding = 0, id = "hf_brute_max", Callback = function(v) BRUTE_MAX = v end })
cTbl:Toggle({
    Title = "Auto Equip Best ikan", id = "hf_equip",
    Callback = function(v)
        Loop("equip", v, function() return EQUIP_INT end, function() Fire("AquariumAction", "EquipBest") end)
        N("Auto Equip Best", v and "ON" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cTbl:Slider({ Title = "Jeda equip best (s)", Min = 5, Max = 600, Value = 60, Rounding = 0, id = "hf_equip_int", Callback = function(v) EQUIP_INT = v end })
cTbl:Button({
    Title = "Equip Best sekarang", Text = "Equip Best sekarang",
    Callback = function() Fire("AquariumAction", "EquipBest"); N("Equip Best", "Dikirim", "#6495ED") end,
})

-- ---------- status & debug ----------
local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })

local cDbg = Main:AddCard({ Title = "Debug / Kalibrasi", Icon = "scan", Column = 2, Collapsed = true })
cDbg:Toggle({
    Title = "Remote Logger (lihat remote asli saat main manual)", id = "hf_log",
    Callback = function(v)
        if v and not InstallHook() then
            N("Remote Logger", "Executor tidak mendukung hookmetamethod", "#DC3232", 5)
            return
        end
        logOn = v
        if v then Remote("HarpoonDive") end      -- pastikan RemotesF terisi
    end,
})
cDbg:Button({
    Title = "Scan ikan (print)", Text = "Scan ikan (print ke console)",
    Callback = function()
        local folder = workspace:FindFirstChild("Fish")
        if not folder then N("Scan", "Workspace.Fish tidak ada", "#DC3232"); return end
        local n = 0
        for _, f in ipairs(folder:GetChildren()) do
            n += 1
            if n <= 15 then
                local attrs = {}
                for k, v in pairs(f:GetAttributes()) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
                print("[Fish]", f.Name, f.ClassName, table.concat(attrs, ", "))
            end
        end
        N("Scan ikan", n .. " objek di Workspace.Fish (15 pertama di console)", "#6495ED", 4)
    end,
})
cDbg:Button({
    Title = "Scan ID aquarium (print)", Text = "Scan ID aquarium (print ke console)",
    Callback = function()
        idT = 0
        local ids = CollectIds()
        print("[Aquarium] ID kandidat:", table.concat(ids, ", "))
        N("Scan ID", #ids .. " kandidat (lihat console)", "#6495ED", 4)
    end,
})

task.spawn(function()
    while W.Alive do
        task.wait(0.5)
        pcall(function()
            local txt = "Status: " .. Stats.status ..
                "\nDive: " .. Stats.trips .. "   Tembak: " .. Stats.shots .. "   Beat: " .. Stats.beats ..
                "\nTas: " .. Stats.bag .. "   Plot: " .. Stats.plot .. "   Error: " .. Stats.errors
            if logOn and #logLines > 0 then txt ..= "\n— remote terakhir —\n" .. table.concat(logLines, "\n") end
            stLbl:SetText(txt)
        end)
    end
end)

-- hentikan semua loop saat Unload
W:OnUnload(function()
    logOn = false
    for k in pairs(runId) do runId[k] += 1 end
end)

-- Player (Movement / Fly / Client) dan Home (+ Settings) ada di ui.lua; tiap bagian aman dari error.
for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildHome({ Game = "Harpoon a Fish", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[KatssinnnHub] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()      -- jalankan nilai awal + autoload config setelah intro selesai
W:OnBooted(function() N("KatssinnnHub", "Harpoon a Fish dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4) end)
