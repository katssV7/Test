-- Rod And Reef | Auto Fishing v1 (memakai module paket game sendiri, bukan buffer manual)
-- Alur game (dari dump script): equip rod -> CastLine{power,castId} -> bobber mendarat di air ->
-- tunggu bite (delay dari client) -> RequestFishData{castQuality} -> server balas FishDataResponse ->
-- minigame -> CatchFish -> ReelIn.
local Players, RS, UIS = game:GetService("Players"), game:GetService("ReplicatedStorage"), game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local PS = LP:WaitForChild("PlayerScripts")

local Fishing = require(RS.Networking.Packets.Fishing)
local function try(f) local ok, r = pcall(f); return ok and r or nil end
local Hotbar = try(function() return require(PS.Controllers.GUI.Hotbar) end)
local PData  = try(function() return require(PS.Controllers.PlayerDataClient) end)
local Tuning = try(function() return require(RS.Modules.FishingTuning) end)

-- ===== PENGATURAN (bisa diubah di panel) =====
local CFG = {
    power = 100,            -- 0-100 (>=90 Perfect, >=50 Good)
    biteFallback = 3,       -- dipakai kalau RollBiteDelay game tidak bisa dipanggil
    minigameDelay = 1.5,    -- jeda setelah FishDataResponse sebelum CatchFish (game minimal 0.75s)
    castGap = 0.5,
    hitTol = 0.6,           -- toleransi klik minigame (0.1-1, fraksi dari setengah lebar zona)
    mode = "skip",          -- "skip" atau "mini"          -- jeda sebelum lempar lagi
}
local stats = { casts = 0, fish = 0, fail = 0, status = "idle" }
local run = 0

-- ===== listener paket dari server =====
local lastData, lastDataT = nil, 0
Fishing.FishDataResponse.listen(function(d) lastData, lastDataT = d, os.clock() end)
local blocked, blockedT = "", 0
Fishing.FishingBlocked.listen(function(d) blocked, blockedT = d.reason or "", os.clock() end)

local function quality(p) return p >= 90 and "Perfect" or (p >= 50 and "Good" or "Normal") end
local function alive(id) return run == id end
local function wait(id, t)   -- sleep yang bisa dibatalkan
    local t0 = os.clock()
    while os.clock() - t0 < t do task.wait(0.05); if not alive(id) then return false end end
    return true
end
local function streak()
    local ls = LP:FindFirstChild("leaderstats")
    local s = ls and ls:FindFirstChild("Streak")
    return s and s.Value or 0
end
local castCounter = math.random(1000000, 800000000)

local function findBobber(cid, timeout, id)
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        for _, p in ipairs(workspace:GetChildren()) do
            if p.Name == "bobber" and p:IsA("BasePart") and p:GetAttribute("Owner") == LP.UserId and p:GetAttribute("CastId") == cid then return p end
        end
        task.wait(0.05)
        if not alive(id) then return nil end
    end
end


-- ===== solver minigame lingkaran (CircularMinigame) =====
-- Jarum (Needle) & zona (Circle/CircleHard/CircleEasy) sama2 muter; klik saat selisih sudut <= setengah lebar zona.
local ARC = { Circle = 30, CircleHard = 7.75, CircleEasy = 47.5 }
local function click()
    local v = workspace.CurrentCamera.ViewportSize
    local x, yy = v.X * 0.5, v.Y * 0.85
    VIM:SendMouseButtonEvent(x, yy, 0, true, game, 0)
    VIM:SendMouseButtonEvent(x, yy, 0, false, game, 0)
end
local function sdiff(a, b) return (a - b + 180) % 360 - 180 end
local function getDial()
    local pg = LP:FindFirstChild("PlayerGui")
    local m = pg and pg:FindFirstChild("Minigames")
    local cm = m and m:FindFirstChild("Canvas") and m.Canvas:FindFirstChild("CircularMinigame")
    local h = cm and cm:FindFirstChild("Canvas") and cm.Canvas:FindFirstChild("CircleHolder")
    return cm, h
end
local function playMinigame(id)
    local t0, seen, prev, lastClick = os.clock(), false, nil, 0
    local before = streak()
    while os.clock() - t0 < 45 do
        if not alive(id) then return false end
        if streak() ~= before then return true end   -- game kirim CatchFish sendiri setelah menang
        local cm, h = getDial()
        local needle = h and h:FindFirstChild("Needle")
        local arc, half
        if h then for n, deg in pairs(ARC) do local a = h:FindFirstChild(n); if a and a.Visible then arc, half = a, deg / 2 end end end
        if cm and cm.Visible and needle and arc then
            seen = true
            local d = sdiff(needle.Rotation, arc.Rotation)
            local crossed = prev and (math.sign(prev) ~= math.sign(d)) and math.abs(prev) < 40
            if (math.abs(d) <= half * CFG.hitTol or crossed) and os.clock() - lastClick > 0.3 then
                lastClick = os.clock(); click()
            end
            prev = d
        elseif seen and os.clock() - lastClick > 2 then
            task.wait(0.3)   -- minigame sudah ditutup
            return streak() ~= before
        end
        RunService.Heartbeat:Wait()
    end
    return false
end

local function cycle(id)
    -- 1. equip rod
    if Hotbar and Hotbar.IsRodEquipped and not Hotbar.IsRodEquipped() then
        stats.status = "equip rod"
        pcall(Hotbar.ForceEquipRod)
        local t0 = os.clock()
        while not Hotbar.IsRodEquipped() and os.clock() - t0 < 3 do task.wait(0.1) end
    end
    if not alive(id) then return end

    -- 2. lempar
    stats.status = "lempar (power " .. CFG.power .. ")"
    castCounter += 1
    local cid, t = castCounter, os.clock()
    Fishing.CastLine.send({ power = CFG.power, castId = cid })
    stats.casts += 1
    local bobber = findBobber(cid, 3, id)
    if not alive(id) then return end
    if not bobber then
        stats.status = "bobber tidak muncul (" .. (blocked ~= "" and blocked or "?") .. ")"; stats.fail += 1
        pcall(Fishing.ReelIn.send); wait(id, 1.5); return
    end

    -- 3. tunggu mendarat di air
    stats.status = "menunggu bobber mendarat"
    local t0 = os.clock()
    while bobber.Parent and bobber:GetAttribute("WaterLandedAt") == nil and os.clock() - t0 < 6 do task.wait(0.05) if not alive(id) then return end end
    if not bobber.Parent or bobber:GetAttribute("WaterLandedAt") == nil then
        stats.status = "bobber gagal mendarat di air"; stats.fail += 1
        pcall(Fishing.ReelIn.send); wait(id, 1); return
    end

    -- 4. tunggu bite (delay dihitung sama seperti game)
    local delay = CFG.biteFallback
    if Tuning and Tuning.RollBiteDelay and PData and PData.GetCachedData then
        local d = PData.GetCachedData()
        local eq = d and d.CurrentlyEquipped
        local ok, v = pcall(Tuning.RollBiteDelay, eq and eq.Bait, eq and eq.SecondaryBait)
        if ok and type(v) == "number" then delay = v end
    end
    stats.status = ("menunggu gigitan %.1fs"):format(delay)
    if not wait(id, delay) then return end

    -- 5. minta data ikan
    stats.status = "RequestFishData"
    local sent = os.clock()
    Fishing.RequestFishData.send({ castQuality = quality(CFG.power) })
    while lastDataT < sent and os.clock() - sent < 5 do task.wait(0.05) if not alive(id) then return end end
    if lastDataT < sent then
        stats.status = "tidak ada FishDataResponse"; stats.fail += 1
        pcall(Fishing.ReelIn.send); wait(id, 1); return
    end
    local d = lastData
    stats.status = ("minigame %s (%s)"):format(d and d.name or "?", d and d.rarity or "?")

    -- 6. selesaikan minigame
    local before = streak()
    if CFG.mode == "mini" then
        stats.status = "main minigame..."
        local ok = playMinigame(id)
        if not alive(id) then return end
        if ok then stats.fish += 1; stats.status = "dapat " .. (d and d.name or "ikan")
        else stats.fail += 1; stats.status = "minigame gagal/timeout" end
        pcall(Fishing.ReelIn.send)
        wait(id, CFG.castGap)
        return
    end
    if not wait(id, CFG.minigameDelay) then return end
    Fishing.CatchFish.send()
    local t1 = os.clock()
    while streak() == before and os.clock() - t1 < 2.5 do task.wait(0.05) if not alive(id) then return end end
    if streak() ~= before then stats.fish += 1; stats.status = "dapat " .. (d and d.name or "ikan")
    else stats.fail += 1; stats.status = "CatchFish tidak dihitung server" end
    pcall(Fishing.ReelIn.send)
    wait(id, CFG.castGap)
end

local function start()
    run += 1
    local id = run
    task.spawn(function()
        while alive(id) do
            local ok, err = pcall(cycle, id)
            if not ok then stats.status = "error: " .. tostring(err):sub(1, 60); task.wait(1) end
            task.wait()
        end
    end)
end
local function stop() run += 1; stats.status = "idle" end

-- ===== GUI =====
local host = (gethui and gethui()) or game:GetService("CoreGui")
if not pcall(function() local t = Instance.new("ScreenGui"); t.Parent = host; t:Destroy() end) then host = LP:WaitForChild("PlayerGui") end
local old = host:FindFirstChild("RodReefAuto"); if old then old:Destroy() end
local gui = Instance.new("ScreenGui"); gui.Name = "RodReefAuto"; gui.ResetOnSpawn = false; gui.Parent = host
local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(230, 300); frame.Position = UDim2.new(0, 10, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30); frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 26); title.BackgroundColor3 = Color3.fromRGB(45, 45, 55); title.BorderSizePixel = 0
title.Text = "Rod & Reef Auto (geser)"; title.TextColor3 = Color3.new(1, 1, 1); title.TextSize = 13; title.Font = Enum.Font.GothamBold
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)
do
    local drag, st, sp
    title.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag, st, sp = true, i.Position, frame.Position end end)
    UIS.InputChanged:Connect(function(i) if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local d = i.Position - st; frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end end)
end
local y = 32
local function mk(class, props)
    local o = Instance.new(class, frame)
    for k, v in pairs(props) do o[k] = v end
    return o
end
local function mkToggle(label, mode, color)
    local b = mk("TextButton", { Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0, 6, 0, y), BackgroundColor3 = color,
        Text = "▶ " .. label .. ": OFF", TextColor3 = Color3.new(1, 1, 1), TextSize = 13, Font = Enum.Font.GothamBold, BorderSizePixel = 0 })
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    y += 34
    return b
end
local togSkip = mkToggle("Fishing SKIP", "skip", Color3.fromRGB(40, 150, 80))
local togMini = mkToggle("Fishing MINIGAME", "mini", Color3.fromRGB(50, 110, 190))
local active = nil
local function setActive(which)
    stop()
    active = (active ~= which) and which or nil
    for _, t in ipairs({ { togSkip, "Fishing SKIP", Color3.fromRGB(40, 150, 80), "skip" }, { togMini, "Fishing MINIGAME", Color3.fromRGB(50, 110, 190), "mini" } }) do
        local on = active == t[4]
        t[1].Text = (on and "⏹ " or "▶ ") .. t[2] .. (on and ": ON" or ": OFF")
        t[1].BackgroundColor3 = on and Color3.fromRGB(190, 60, 60) or t[3]
    end
    if active then CFG.mode = active; start() end
end
togSkip.MouseButton1Click:Connect(function() setActive("skip") end)
togMini.MouseButton1Click:Connect(function() setActive("mini") end)
local function stepper(label, key, step, min, max, fmt)
    mk("TextLabel", { Size = UDim2.new(0, 110, 0, 28), Position = UDim2.new(0, 8, 0, y), BackgroundTransparency = 1, Text = label,
        TextColor3 = Color3.fromRGB(210, 210, 210), TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left })
    local val = mk("TextLabel", { Size = UDim2.new(0, 44, 0, 28), Position = UDim2.new(0, 124, 0, y), BackgroundTransparency = 1,
        Text = fmt:format(CFG[key]), TextColor3 = Color3.new(1, 1, 1), TextSize = 13, Font = Enum.Font.GothamBold })
    local function btn(txt, x, d)
        local b = mk("TextButton", { Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0, x, 0, y + 2), BackgroundColor3 = Color3.fromRGB(70, 70, 85),
            Text = txt, TextColor3 = Color3.new(1, 1, 1), TextSize = 14, Font = Enum.Font.GothamBold, BorderSizePixel = 0 })
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        b.MouseButton1Click:Connect(function()
            CFG[key] = math.clamp(math.floor((CFG[key] + d * step) / step * 1 + 0.5) * 1 * step / 1, min, max)
            CFG[key] = math.floor(CFG[key] * 100 + 0.5) / 100
            val.Text = fmt:format(CFG[key])
        end)
    end
    btn("-", 168, -1); btn("+", 196, 1)
    y += 30
end
stepper("Power lempar", "power", 5, 0, 100, "%d")
stepper("Tunggu minigame", "minigameDelay", 0.25, 0.25, 8, "%.2f")
stepper("Jeda lempar ulang", "castGap", 0.1, 0.1, 5, "%.1f")
stepper("Toleransi klik", "hitTol", 0.1, 0.1, 1, "%.1f")
stepper("Bite cadangan", "biteFallback", 0.5, 0.5, 15, "%.1f")
local statusLbl = mk("TextLabel", { Size = UDim2.new(1, -12, 0, 70), Position = UDim2.new(0, 6, 0, y + 4), BackgroundTransparency = 1, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 12, Font = Enum.Font.Gotham, Text = "" })
frame.Size = UDim2.fromOffset(230, y + 82)
task.spawn(function()
    while gui.Parent do
        statusLbl.Text = ("Status: %s\nLempar: %d | Ikan: %d | Gagal: %d"):format(stats.status, stats.casts, stats.fish, stats.fail)
        task.wait(0.2)
    end
end)
print("[RodReef] Auto Fishing siap.")
