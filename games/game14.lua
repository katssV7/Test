-- Sevoice | Rod And Reef - Auto Fishing
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Game flow: equip rod -> CastLine{power,castId} -> bobber lands on water ->
-- wait for bite -> RequestFishData{castQuality} -> server replies FishDataResponse ->
-- minigame -> CatchFish -> ReelIn.
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "Sevoice",
    Version   = "v1.0",
    Game      = "Rod And Reef",
    Folder    = "Sevoice/RodAndReef",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local PS = LP:WaitForChild("PlayerScripts")

local Fishing = require(RS.Networking.Packets.Fishing)
local function try(f) local ok, r = pcall(f); return ok and r or nil end
local Hotbar = try(function() return require(PS.Controllers.GUI.Hotbar) end)
local ShopP = try(function() return require(RS.Networking.Packets.Shop) end)
local DialogueP = try(function() return require(RS.Networking.Packets.Dialogue) end)
local PData = try(function() return require(PS.Controllers.PlayerDataClient) end)

-- ===== SETTINGS (fixed / defaults) =====
local CFG = {
    releaseAt = 0.80,       -- release the rod button when the bar >= this
    holdTime = 1.0,         -- fallback: hold time (seconds) if the bar cannot be read
    biteFallback = 3.0,
    minigameDelay = 1.00,   -- delay after FishDataResponse before CatchFish
    castGap = 1.5,          -- delay before casting again
    hitTol = 0.5,           -- minigame click tolerance
    pursuitAccel = 450,     -- Pursuit needle acceleration (deg/s^2), from scan
    pursuitVmax = 132,      -- max Pursuit needle speed (deg/s)
    pursuitBand = 0.15,     -- tolerance (x half zone width) before reversing; smaller = tighter but more clicks
    pursuitLead = 0.06,     -- click latency compensation (seconds)
    pursuitCool = 0.33,     -- minimum gap between Pursuit clicks. The game ignores clicks < ~0.3 s after the previous one (from log), and ignored clicks also delay the next click
    debugPursuit = true,    -- true = record Pursuit log, auto-copied to clipboard when a stage ends
    memLead = 0.05,         -- Memory: click this many seconds early (latency compensation)
    memGap = 2.5,           -- Memory: no new spot for this long = watch phase finished
    debugMemory = true,    -- true = Memory log copied to clipboard when a stage ends
    pursuitMirror = false,  -- true if there turn out to be 2 opposite zones
    mode = "skip",          -- "skip" or "mini"
}
local lastPower = nil
local stats = { casts = 0, fish = 0, fail = 0, sold = 0, status = "idle" }
local run = 0
local running = false

-- ===== server packet listeners =====
local lastData, lastDataT = nil, 0
Fishing.FishDataResponse.listen(function(d) lastData, lastDataT = d, os.clock() end)
local blocked, blockedT = "", 0
Fishing.FishingBlocked.listen(function(d) blocked, blockedT = d.reason or "", os.clock() end)

do
    local orig = Fishing.CastLine.send
    Fishing.CastLine.send = function(d, ...)
        if type(d) == "table" and d.power then lastPower = d.power end
        return orig(d, ...)
    end
end
local function Root() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function alive(id) return id == nil or run == id end   -- id nil = manual action (cannot be cancelled)
local function wait(id, t)   -- cancellable sleep
    local t0 = os.clock()
    while os.clock() - t0 < t do task.wait(0.05); if not alive(id) then return false end end
    return true
end
local function streak()
    local ls = LP:FindFirstChild("leaderstats")
    local s = ls and ls:FindFirstChild("Streak")
    return s and s.Value or 0
end

-- ===== circle minigame solver (CircularMinigame) =====
local ARC = { Circle = 30, CircleHard = 7.75, CircleEasy = 47.5 }
-- Mouse events make Roblox think the player is on PC, so the mobile thumbstick disappears.
-- After each mouse click, send a small touch tap in the screen corner so the last input
-- is "Touch" again and the thumbstick comes back.
local function restoreTouch()
    if not UIS.TouchEnabled then return end
    pcall(function()
        VIM:SendTouchEvent(9, 0, 2, 2)
        VIM:SendTouchEvent(9, 2, 2, 2)
    end)
end
local function click()
    local v = workspace.CurrentCamera.ViewportSize
    local x, yy = v.X * 0.5, v.Y * 0.85
    VIM:SendMouseButtonEvent(x, yy, 0, true, game, 0)
    VIM:SendMouseButtonEvent(x, yy, 0, false, game, 0)
    restoreTouch()
end
local function sdiff(a, b) return (a - b + 180) % 360 - 180 end
local function getDial(name)
    local pg = LP:FindFirstChild("PlayerGui")
    local m = pg and pg:FindFirstChild("Minigames")
    local cv = m and m:FindFirstChild("Canvas")
    local cm = cv and (cv:FindFirstChild(name or "CircularMinigame") or cv:FindFirstChild("CircularMinigame"))
    local h = cm and cm:FindFirstChild("Canvas") and cm.Canvas:FindFirstChild("CircleHolder")
    if cm and not (h and h:FindFirstChild("Needle")) then   -- Pursuit: different structure, look for Needle directly
        for _, o in ipairs(cm:GetDescendants()) do
            if o.Name == "Needle" and o:IsA("GuiObject") then h = o.Parent; break end
        end
    end
    return cm, h
end
-- Secret fish: the server sends 3-4 different minigame stages. We wrap each module's start()
-- to know which stage is running (Circular/Blind = click, Tension = hold/release, Pursuit = click to reverse).
local activeMG, startSerial = nil, 0
do
    local G = PS:FindFirstChild("Gameplay")
    local MG = G and G:FindFirstChild("Minigames")
    for _, n in ipairs({ "CircularMinigame", "BlindNeedleMinigame", "TensionMinigame", "PursuitMinigame", "MemoryMinigame" }) do
        local inst = MG and MG:FindFirstChild(n)
        local m = inst and try(function() return require(inst) end)
        if type(m) == "table" and type(m.start) == "function" then
            local o = m.start
            m.start = function(...) activeMG = n; startSerial += 1; return o(...) end
        end
    end
end
local function findZone(h, needle)
    for n, deg in pairs(ARC) do local a = h:FindFirstChild(n); if a and a.Visible then return a, deg / 2 end end
    for _, a in ipairs(h:GetChildren()) do
        local nm = a.Name:lower()
        if a ~= needle and a:IsA("GuiObject") and a.Visible and (nm:find("zone") or nm:find("arc") or nm:find("target") or nm:find("circle")) then
            return a, 25
        end
    end
end
local MSKIP = { Needle = true, Background = true, Ring = true, _Axis = true, saww = true, Label = true, Progress = true }
local function spotVis(c)
    if not c.Visible then return false end
    if c:IsA("ImageLabel") or c:IsA("ImageButton") then return c.ImageTransparency < 0.9 end
    return c.BackgroundTransparency < 0.9
end
local wrap90 = function(x) return (x + 90) % 180 - 90 end
-- timestamped unwrapped angle history -> stable velocity/acceleration, no per-frame jitter
local function newTrack() return { t = {}, a = {}, i = 1 } end
local function tpush(tr, t, a)
    local n = #tr.t + 1
    tr.t[n] = t; tr.a[n] = a
    while tr.t[tr.i] < t - 0.5 do tr.i += 1 end
end
local function tfind(tr, tt)
    for j = #tr.t, tr.i, -1 do if tr.t[j] <= tt then return j end end
end
local function velAt(tr, tEnd, span)
    local j2 = tfind(tr, tEnd)
    local j1 = j2 and tfind(tr, tEnd - span)
    if not (j1 and j2) or j2 <= j1 then return nil end
    local dt = tr.t[j2] - tr.t[j1]
    if dt <= 0 then return nil end
    return (tr.a[j2] - tr.a[j1]) / dt
end
local function mouse(down)
    local v = workspace.CurrentCamera.ViewportSize
    VIM:SendMouseButtonEvent(v.X * 0.5, v.Y * 0.85, 0, down, game, 0)
end
-- Pursuit-only click: WITHOUT the restoreTouch tap (that tap counts as a second click and cancels the brake).
-- restoreTouch is called once when the Pursuit stage ends (via flush).
-- currently visible minigame frame (fallback if start() was not called through the wrapper above)
local function visibleMGs()
    local out = {}
    local pg = LP:FindFirstChild("PlayerGui")
    local m = pg and pg:FindFirstChild("Minigames")
    local cv = m and m:FindFirstChild("Canvas")
    if not cv then return out end
    for _, c in ipairs(cv:GetChildren()) do
        if c:IsA("GuiObject") and c.Visible and c.Name:find("Minigame") then out[#out + 1] = c.Name end
    end
    return out
end
local function clickP()
    local v = workspace.CurrentCamera.ViewportSize
    local x, yy = v.X * 0.5, v.Y * 0.85
    VIM:SendMouseButtonEvent(x, yy, 0, true, game, 0)
    task.delay(0.03, function() VIM:SendMouseButtonEvent(x, yy, 0, false, game, 0) end)
end
local function playMinigame(id)
    local usedP = false   -- true = Pursuit uses clickP, needs restoreTouch at the end
    local pCnt = 0        -- clicks already sent in this Pursuit stage
    local t0, seen, prev, lastClick = os.clock(), false, nil, 0
    local before = streak()
    local holding, pn, pz, pt, nv, zv = false, nil, nil, nil, 0, 0
    local ps, lastMG, uN, uZ, az = 1, nil, nil, nil, 0
    local trN, trZ = newTrack(), newTrack()
    local dbg, mlog, mem = {}, {}, nil
    local function mlogf(fmt, ...)
        if CFG.debugMemory and #mlog < 600 then mlog[#mlog + 1] = string.format("%.2f ", os.clock() - t0) .. string.format(fmt, ...) end
    end
    local function flush()
        if usedP then usedP = false; restoreTouch() end
        if CFG.debugPursuit and #dbg > 0 then
            local txt = "t,needle,zone,e,ps,click,vNeedle,vZone\n" .. table.concat(dbg, "\n")
            local f = setclipboard or toclipboard
            if f then pcall(f, txt) end
            if writefile then pcall(writefile, "pursuit_log.txt", txt) end
            print("[Rod And Reef] Pursuit log copied (" .. #dbg .. " lines)")
            dbg = {}
        end
        if CFG.debugMemory and #mlog > 0 then
            local txt = table.concat(mlog, "\n")
            local f = setclipboard or toclipboard
            if f then pcall(f, txt) end
            if writefile then pcall(writefile, "memory_solver_log.txt", txt) end
            print("[Rod And Reef] Memory log copied (" .. #mlog .. " lines)")
            mlog = {}
        end
    end
    -- Back to the watch phase: drop the old sequence, re-record the spots shown by the game.
    local function memRescan(reason)
        mem.phase, mem.spots, mem.pend, mem.k, mem.pd, mem.lastSpot = "watch", {}, {}, 1, nil, nil
        mem.lastHit, mem.needLabBack = nil, true
        mlogf("RESCAN: %s", reason)
    end
    local function memEvent(c, now)
        if not mem then return end
        -- Spot reappears during the click phase = game shows the sequence again (1 miss / new round) -> rescan.
        -- 0.25 s gap from the click / start of the click phase. From the log: after a missed click, the first spot reappears ~0.38 s later
        -- (the previous 0.6 s gap dropped that first spot, so the rescanned sequence lost spot #1).
        if mem.phase == "act" then
            local ref = math.max(mem.lastHit or 0, mem.actT or 0)
            if now - ref > 0.25 or (mem.k > #mem.spots and mem.lastHit and now - mem.lastHit > 0.4) then
                memRescan(string.format("spot reappeared (%s, click %d/%d)", c.Name, mem.k - 1, #mem.spots))
            end
        end
        if mem.phase == "watch" then mem.pend[#mem.pend + 1] = { c = c, t = now }
        else mlogf("ignore spot shown during click phase: %s rot=%.1f", c.Name, c.Rotation) end
    end
    local function setHold(h) if h ~= holding then holding = h; mouse(h); if not h then restoreTouch() end end end
    activeMG = nil
    while os.clock() - t0 < 60 do
        if not alive(id) then setHold(false); flush(); return false end
        if streak() ~= before then setHold(false); flush(); return true end
        -- Detect the minigame from the visible frame (Pursuit / Memory / Tension / Circular / Blind), then use the matching solver.
        -- The wrapped start() stays the main source and is NEVER overridden (Secret/Pursuit depend on it).
        -- The visible frame is only used when activeMG is still empty (start() was not called, e.g. Legend).
        if activeMG == nil then
            local vs = visibleMGs()
            if #vs >= 1 then
                activeMG = vs[1]
                stats.status = "minigame: " .. (vs[1]:gsub("Minigame", ""))
                mlogf("minigame detected from visible frame: %s", vs[1])
            end
        end
        local cm, h = getDial(activeMG)
        local needle = h and h:FindFirstChild("Needle")
        local arc, half
        if h and needle then arc, half = findZone(h, needle) end
        if activeMG ~= "MemoryMinigame" and mem then flush(); mem = nil end
        local memMode = activeMG == "MemoryMinigame" and cm and cm.Visible and needle and h
        if memMode then
            -- MEMORY: blue spots appear one by one (order = click order), then click as the needle passes each spot.
            seen = true
            local now = os.clock()
            local n = needle.Rotation
            if not mem or mem.serial ~= startSerial then
                mem = { serial = startSerial, spots = {}, pend = {}, obj = {}, phase = "watch", k = 1, init = false,
                        trN = newTrack(), un = n, pn = n, label = nil, text0 = nil, lastLab = 0, lastSpot = nil, t0 = now }
                mlogf("MEMORY mulai (serial %d)", startSerial)
                for _, c in ipairs(h:GetChildren()) do
                    local g = c:IsA("GuiObject")
                    mlogf("  anak %s [%s] vis=%s rot=%.1f", c.Name, c.ClassName, tostring(g and c.Visible), g and c.Rotation or 0)
                end
            end
            mem.un += sdiff(n, mem.pn); mem.pn = n
            tpush(mem.trN, now, mem.un)
            -- watch every CircleHolder child that could be a "blue spot"
            for _, c in ipairs(h:GetChildren()) do
                if c:IsA("GuiObject") and not MSKIP[c.Name] and not c:IsA("TextLabel") then
                    local vis, rot = spotVis(c), c.Rotation
                    local st = mem.obj[c]
                    if not st then
                        mem.obj[c] = { vis = vis, rot = rot }
                        if mem.init and vis then memEvent(c, now)
                        elseif vis then mlogf("already visible at start: %s rot=%.1f", c.Name, rot) end
                    else
                        if vis and ((not st.vis) or math.abs(sdiff(rot, st.rot)) > 10) then memEvent(c, now) end
                        st.vis, st.rot = vis, rot
                    end
                end
            end
            mem.init = true
            if mem.phase == "watch" then
                -- finalize the spot once its rotation settles (60 ms)
                local keep = {}
                for _, pe in ipairs(mem.pend) do
                    if now - pe.t >= 0.06 then
                        local ang = pe.c.Rotation
                        -- duplicate: a spot at the same angle appearing within 0.4 s, even if the object differs
                        -- (e.g. spot + rotating glow/outline) -> if counted twice the click order shifts
                        local dup = false
                        for _, sp in ipairs(mem.spots) do
                            if math.abs(sdiff(ang, sp.angle)) < 5 and now - sp.t < 0.4 then dup = true; break end
                        end
                        if dup then
                            mlogf("duplikat dibuang: %s angle=%.1f", pe.c.Name, ang)
                        else
                            mem.spots[#mem.spots + 1] = { angle = ang, t = now, c = pe.c }
                            mem.lastSpot = now
                            mlogf("SPOT #%d %s angle=%.1f needle=%.1f", #mem.spots, pe.c.Name, ang, n)
                        end
                    else keep[#keep + 1] = pe end
                end
                mem.pend = keep
                -- find the instruction label ("Watch the spots...") to detect the phase change
                if not mem.label and now - mem.lastLab > 0.5 and now - mem.t0 < 6 then
                    mem.lastLab = now
                    local pgui = LP:FindFirstChild("PlayerGui")
                    if pgui then
                        for _, o in ipairs(pgui:GetDescendants()) do
                            if o:IsA("TextLabel") and o.Visible then
                                local tx = o.Text:lower()
                                if tx:find("spots") or tx:find("watch") then mem.label, mem.text0 = o, o.Text; mlogf("label instruksi: %q", o.Text); break end
                            end
                        end
                    end
                end
                -- after a rescan, ignore the "text changed" signal until the text returns to the watch text
                if mem.needLabBack and mem.label and mem.label.Parent and mem.label.Text == mem.text0 then mem.needLabBack = false end
                local why
                if #mem.spots > 0 and #mem.pend == 0 then
                    if mem.label and not mem.needLabBack and (not mem.label.Parent or not mem.label.Visible or mem.label.Text ~= mem.text0) then why = "teks berubah"
                    elseif mem.lastSpot and now - mem.lastSpot > CFG.memGap then why = "no new spot" end
                end
                if why then
                    mem.phase, mem.k, mem.pd = "act", 1, nil
                    mem.actT, mem.labChanged, mem.lastHit = now, false, nil
                    local lst = {}
                    for i, sp in ipairs(mem.spots) do lst[i] = string.format("%.1f", sp.angle) end
                    mlogf("CLICK PHASE (%s). angle order: %s", why, table.concat(lst, ", "))
                end
            else
                -- instruction text returns to "Watch the spots..." after changing = new round
                if mem.label and mem.label.Parent then
                    if mem.label.Text ~= mem.text0 then mem.labChanged = true
                    elseif mem.labChanged and mem.label.Visible then
                        memRescan("teks instruksi kembali")
                    end
                end
                local v = velAt(mem.trN, now, 0.1)
                local tgt = mem.spots[mem.k]
                if tgt and v and math.abs(v) > 5 and now - lastClick > 0.2 and not (mem.sched and now < mem.sched) then
                    -- Scheduled click: compute when the needle reaches the target, send the click exactly then (arrival time - memLead).
                    -- The old way clicked only AFTER passing the spot (0.02-0.09 s late in the Legend log, needle ~190 deg/s).
                    local dir = v > 0 and 1 or -1
                    local ahead = (sdiff(tgt.angle, n) * dir) % 360     -- derajat tersisa searah gerak
                    local wait = ahead / math.abs(v) - CFG.memLead
                    if wait <= 0.07 and wait >= -0.03 then
                        wait = math.max(0, wait)
                        local m, k = mem, mem.k
                        mem.sched = now + wait + 0.1
                        task.delay(wait, function()
                            if mem ~= m or m.k ~= k or m.spots[k] ~= tgt or m.phase ~= "act" then return end
                            local nn = needle.Rotation
                            lastClick = os.clock(); click()
                            mlogf("CLICK #%d target=%.1f needle=%.1f diff=%+.1f v=%.0f", k, tgt.angle, nn, sdiff(nn, tgt.angle), v)
                            m.k = k + 1; m.pd = nil; m.lastHit = os.clock(); m.sched = nil
                        end)
                    end
                end
            end
        elseif cm and cm.Visible and needle and arc then
            seen = true
            local now = os.clock()
            local n, z = needle.Rotation, arc.Rotation
            if activeMG ~= lastMG or not uN then
                -- stage changed: reset everything
                if lastMG == "PursuitMinigame" then flush() end
                lastMG = activeMG; ps = 1; az = 0; pCnt = 0
                trN, trZ = newTrack(), newTrack(); uN, uZ = n, z
            elseif pn then
                local dn, dz, dtt = sdiff(n, pn), sdiff(z, pz), now - pt
                if dtt > 0 and (math.abs(dn) / dtt > 600 or math.abs(dz) / dtt > 600) then
                    -- jump (new round): reset
                    ps = 1; az = 0; pCnt = 0; trN, trZ = newTrack(), newTrack(); uN, uZ = n, z
                else
                    uN += dn; uZ += dz
                end
            end
            tpush(trN, now, uN); tpush(trZ, now, uZ)
            local dtc = 0
            if pt and now > pt then
                local dt = now - pt
                dtc = dt
                nv = sdiff(n, pn) / dt; zv = sdiff(z, pz) / dt
            end
            pn, pz, pt = n, z, now
            if activeMG == "TensionMinigame" then
                -- hold = needle rises (+), release = falls (-); follow the blue zone with a simple PD controller
                setHold(sdiff(z, n) + 0.3 * (zv - nv) > 0)
            elseif activeMG == "PursuitMinigame" then
                -- A click reverses the needle ACCELERATION (+-A); speed is capped at Vmax (from scan).
                local A, V = CFG.pursuitAccel, CFG.pursuitVmax
                local vN = velAt(trN, now, 0.08)
                local vO = velAt(trN, now - 0.1, 0.08)
                local vZ = velAt(trZ, now, 0.15)
                if vN and vO and vZ then
                    local acc = (vN - vO) / 0.1
                    -- sync the acceleration direction from observation (not just a guess)
                    if pCnt == 0 and math.abs(vN) > 8 then
                        ps = vN > 0 and 1 or -1          -- no click yet: the needle starts at rest, so the push is in the direction of motion
                    elseif now - lastClick > 0.2 then
                        if math.abs(acc) > 0.55 * A and math.abs(vN) < 0.9 * V then
                            ps = acc > 0 and 1 or -1
                        elseif math.abs(vN) >= 0.92 * V and math.abs(acc) < 0.3 * A then
                            ps = vN > 0 and 1 or -1      -- mentok Vmax berarti dorongan searah gerak
                        end
                    end
                    local e = CFG.pursuitMirror and wrap90(n - z) or sdiff(n, z)
                    local w = vN - vZ
                    local tau = CFG.pursuitLead
                    -- zone acceleration (the zone reverses every 1-2 s): added to the relative model
                    local vZo = velAt(trZ, now - 0.15, 0.15)
                    if vZo then az = az * 0.6 + math.max(-150, math.min(150, (vZ - vZo) / 0.15)) * 0.4 end
                    local ep = e + w * tau
                    local wp = w + (ps * A - az) * (tau + 0.04)
                    local sg = wp >= 0 and 1 or -1
                    local Aeff = math.max(0.3 * A, A + sg * az)   -- effective braking power relative to the zone
                    local sigma = ep + wp * math.abs(wp) / (2 * Aeff)
                    local clicked = false
                    -- Clicks are ONLY sent when the gap since the last click is >= pursuitCool.
                    -- Clicks sent too close together are ignored by the game and restart its gap timer.
                    if ps * sigma > half * CFG.pursuitBand and now - lastClick >= CFG.pursuitCool then
                        lastClick = now; ps = -ps; pCnt += 1; clickP(); usedP = true; clicked = true
                    else
                        -- safety: needle running away from the zone & not braking -> force reverse
                        local away = e * vN > 0 and math.abs(e) > half * 1.2 and math.abs(vN) > 20
                        local braking = vN * acc < -0.3 * A
                        if away and not braking and now - lastClick >= math.max(0.4, CFG.pursuitCool) then
                            lastClick = now; ps = vN > 0 and -1 or 1; pCnt += 1; clickP(); usedP = true; clicked = true
                        end
                    end
                    if CFG.debugPursuit and #dbg < 2500 then
                        dbg[#dbg + 1] = string.format("%.2f,%.1f,%.1f,%.1f,%d,%s,%.0f,%.0f", now - t0, n, z, e, ps, clicked and "C" or "", vN, vZ)
                    end
                end
            else
                -- Circular / BlindNeedle: click when the needle is in the zone
                local d = sdiff(n, z)
                local crossed = prev and (math.sign(prev) ~= math.sign(d)) and math.abs(prev) < 40
                if (math.abs(d) <= half * CFG.hitTol or crossed) and now - lastClick > 0.3 then
                    lastClick = now; click()
                end
                prev = d
            end
        elseif seen and os.clock() - lastClick > 2 then
            setHold(false); flush()
            task.wait(0.3)
            return streak() ~= before
        end
        RunService.Heartbeat:Wait()
    end
    setHold(false); flush()
    return false
end

-- ===== cast via the rod button (hold, release when the bar is full) =====
local barCache
local function findBar()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, o in ipairs(pg:GetDescendants()) do
        if o:IsA("GuiObject") and o.Visible and o.AbsoluteSize.X > 0 and o.Name:lower():find("power") then
            for _, f in ipairs(o:GetDescendants()) do
                local n = f.Name:lower()
                if f:IsA("GuiObject") and (n:find("fill") or n == "bar") then return o, f end
            end
        end
    end
end
local function readPower()
    if not (barCache and barCache[1].Parent and barCache[2].Parent) then
        local c, f = findBar(); barCache = c and { c, f } or nil
    end
    if not barCache then return nil end
    local c, f = barCache[1], barCache[2]
    if c.AbsoluteSize.X >= c.AbsoluteSize.Y then return f.AbsoluteSize.X / math.max(c.AbsoluteSize.X, 1) end
    return f.AbsoluteSize.Y / math.max(c.AbsoluteSize.Y, 1)
end
local function holdCast(id)
    local pg = LP:FindFirstChild("PlayerGui")
    local g = pg and pg:FindFirstChild("ExtendedTouchGui")
    local b = g and g:FindFirstChild("Fishing_Cast")
    if not (b and b.Visible) then return false end
    local p, sz = b.AbsolutePosition, b.AbsoluteSize
    -- left mouse click shifted right inside the rod button so the UI library does not cover it
    local x, y = p.X + sz.X * 0.75, p.Y + sz.Y / 2 + GuiService:GetGuiInset().Y
    barCache = nil
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    local t0, found = os.clock(), false
    while os.clock() - t0 < 5 do
        if not alive(id) then break end
        local v = readPower()
        if v then
            found = true
            if v >= CFG.releaseAt then break end
        elseif os.clock() - t0 >= CFG.holdTime then break end
        RunService.Heartbeat:Wait()
    end
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    restoreTouch()
    if not found then print("[Rod And Reef] power bar not readable, using holdTime") end
    return true
end

-- ===== AUTO SELL (from scan) =====
-- Fish enter the bag: CatchFish -> server adds "Inventory.Fish.<name>" to player data,
-- sent to the client via RemoteEvent Packages.Net["RE/PlayerDataChanged"] (path, value).
-- Sell all: packet Shop.SellAllFish (no arguments). In the real game via the island's fish buyer NPC
-- (Workspace.DialogueNPCs.<npc>) -> sell menu -> OpenSellPrompt -> confirm Yes.
local SELL = { enabled = false, every = 20 }
local fishTbl, sellMode, nextSellTry = nil, nil, 0   -- sellMode: nil (unknown yet) / "direct" / "npc"

local function sumFish(t)
    local n = 0
    if type(t) == "table" then
        for _, list in pairs(t) do
            if type(list) == "table" then
                for _, e in pairs(list) do
                    if type(e) == "table" then n += (tonumber(e.Count) or 1) end
                end
            end
        end
    end
    return n
end
local function cachedFish()
    if not PData then return nil end
    for _, nm in ipairs({ "GetCachedData", "GetData" }) do
        if type(PData[nm]) == "function" then
            local ok, d = pcall(PData[nm])
            if not (ok and type(d) == "table") then ok, d = pcall(PData[nm], PData) end
            if ok and type(d) == "table" and type(d.Inventory) == "table" and type(d.Inventory.Fish) == "table" then
                return d.Inventory.Fish
            end
        end
    end
end
local function invCount()
    local c = cachedFish()
    if c then return sumFish(c) end
    return sumFish(fishTbl)   -- fallback: count from the PlayerDataChanged event
end
task.spawn(function()
    local pk = RS:WaitForChild("Packages", 10)
    local net = pk and pk:WaitForChild("Net", 10)
    local re = net and net:WaitForChild("RE/PlayerDataChanged", 10)
    if not re then return end
    re.OnClientEvent:Connect(function(path, value)
        if type(path) ~= "string" then return end
        if path == "Inventory.Fish" then fishTbl = value
        else
            local name = path:match("^Inventory%.Fish%.([^%.]+)$")
            if name then fishTbl = fishTbl or {}; fishTbl[name] = value end
        end
    end)
end)

local function coins()
    local ls = LP:FindFirstChild("leaderstats")
    local c = ls and ls:FindFirstChild("Coins")
    return c and c.Value or 0
end
local function sellDone(c0, id)   -- wait for server: coins rise or the bag becomes empty
    local t0 = os.clock()
    while os.clock() - t0 < 3 do
        if coins() > c0 or invCount() == 0 then return true end
        task.wait(0.1)
        if not alive(id) then return false end
    end
    return false
end
local ISLANDS = {   -- id = value of the Zone attribute / folder Workspace.MAP; lv = "SHOPS LV n+" from the world map (log)
    { id = "Island1", name = "Verdantis",   lv = 1 },
    { id = "Island2", name = "Corvane",     lv = 22 },
    { id = "Island3", name = "Hollowscar",  lv = 52 },
    { id = "Island4", name = "Winterspire", lv = 77 },
}
local ISL = {}
for i, x in ipairs(ISLANDS) do x.idx = i; ISL[x.id] = x end
-- Shop NPCs per island (names given by the script owner)
local SHOPNPC = {
    Bait = { Island1 = "Ilyas",  Island2 = "Kenneth", Island3 = "Ash",   Island4 = "Neil" },
    Rod  = { Island1 = "Tobias", Island2 = "Blake",   Island3 = "Malik", Island4 = "Noah" },
}
local SELLNPC = { Island1 = "Oliver", Island2 = "Amir", Island3 = "Miguel", Island4 = "Enzo" }
local function curIsland()
    local z = LP:GetAttribute("Zone")
    return (type(z) == "string" and ISL[z]) and z or nil
end
local function islandLevel(id) return ISL[id] and ISL[id].lv or 0 end

local function sellViaNpc(id)
    local npc = SELLNPC[curIsland() or "Island1"] or "Oliver"   -- every island has its own fish buyer
    local f = workspace:FindFirstChild("DialogueNPCs")
    local m, r = f and f:FindFirstChild(npc), Root()
    local p = m and (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true))
    if not (m and p and r and DialogueP and ShopP) then return false end
    local back = r.CFrame
    r.CFrame = CFrame.new(p.Position + p.CFrame.LookVector * 4 + Vector3.new(0, 3, 0))
    r.AssemblyLinearVelocity = Vector3.zero
    local ok = false
    if wait(id, 0.6) then
        local c0 = coins()
        local function step(pk, data) if pk then pcall(pk.send, data) end; return wait(id, 0.35) end
        step(DialogueP.RequestNPCInteraction, { npcId = npc, npcModel = m })
        step(DialogueP.DialogueSelectBranch, { npcId = npc, branchId = npc .. "_Greet_r1" })
        step(DialogueP.DialogueSelectBranch, { npcId = npc, branchId = npc .. "_SellMenu_r1" })
        step(DialogueP.DialogueAction, { npcId = npc, actionId = "OpenSellPrompt", payload = "All" })
        step(DialogueP.DialogueAdvance, { npcId = npc, nodeId = npc .. "_SellAll" })
        step(DialogueP.NPCInteractionEnd, { npcId = npc, reason = "endOfDialogue" })
        if wait(id, 1.0) then
            pcall(ShopP.SellAllFish.send)
            ok = sellDone(c0, id)
        end
    end
    local r2 = Root()
    if r2 then r2.CFrame = back; r2.AssemblyLinearVelocity = Vector3.zero end
    return ok
end
-- the "FISH SOLD!" popup must be closed with the CONTINUE button (QuestRewards.Canvas.BG.Container.ContinueFrame.TextButton)
local function findContinue()
    local node = LP:FindFirstChild("PlayerGui")
    for _, n in ipairs({ "QuestRewards", "Canvas", "BG", "Container", "ContinueFrame", "TextButton" }) do
        node = node and node:FindFirstChild(n)
    end
    return node
end
local function shown(b)
    local o = b
    while o and o ~= game do
        if o:IsA("GuiObject") and not o.Visible then return false end
        if o:IsA("ScreenGui") and not o.Enabled then return false end
        o = o.Parent
    end
    return b.AbsoluteSize.X > 0
end
local function fireSig(sig, ...)
    local args = { ... }
    local n = select("#", ...)
    if getconnections then
        local ok, cons = pcall(getconnections, sig)
        if ok and type(cons) == "table" and #cons > 0 then
            for _, c in ipairs(cons) do pcall(function() c:Fire(table.unpack(args, 1, n)) end) end
            return true
        end
    end
    if firesignal then return (pcall(firesignal, sig, table.unpack(args, 1, n))) end
    return false
end
local function pressContinue(b)
    local fired = fireSig(b.Activated, nil, 1)
    fired = fireSig(b.MouseButton1Click) or fired
    if not fired then   -- fallback: touch tap in the middle of the button (touch, not mouse, so the mobile thumbstick stays)
        local p, sz = b.AbsolutePosition, b.AbsoluteSize
        local x, y = p.X + sz.X / 2, p.Y + sz.Y / 2 + GuiService:GetGuiInset().Y
        pcall(function()
            VIM:SendTouchEvent(8, 0, x, y)
            VIM:SendTouchEvent(8, 2, x, y)
        end)
    end
end
local function dismissSold(id)
    local t0, b = os.clock(), nil
    while os.clock() - t0 < 3 do   -- wait for the popup to appear
        b = findContinue()
        if b and shown(b) then break end
        b = nil
        task.wait(0.1)
        if not alive(id) then return end
    end
    if not b then return end
    stats.status = "clicking CONTINUE"
    for _ = 1, 3 do
        pressContinue(b)
        if not wait(id, 0.5) then return end
        b = findContinue()
        if not (b and shown(b)) then return end
    end
end

-- try SellAllFish directly first; if the server refuses, go through the island's seller NPC (mode remembered)
local function sellAll(id)
    if not (ShopP and ShopP.SellAllFish) then return false end
    stats.status = "selling all fish..."
    local c0 = coins()
    if sellMode ~= "npc" then
        pcall(ShopP.SellAllFish.send)
        if sellDone(c0, id) then sellMode = "direct"; dismissSold(id); return true end
        if not alive(id) then return false end
    end
    local ok = sellViaNpc(id)
    if ok then sellMode = "npc"; dismissSold(id) end
    return ok
end

-- ===== AUTO BUY BAIT / ROD =====
-- CONFIRMED from scan_log.txt (not guesses):
--   buy packet  : Shop.RequestBuyItem { amount, itemName, itemType = "Bait" | "Rod" }, reply Shop.BuyItemResponse { itemName, itemType, success }
--   NPC flow    : bait NPC (payload "Baits") and rod NPC (payload "Rods"); same dialogue steps as selling
--   data        : leaderstats.Level, leaderstats.Coins, Inventory.Baits { name = count }, Inventory.Rods { name, ... }
--   modul       : RS.Modules.BaitDatabase / RodDatabase / ShopRules (functions only; the data shape is NOT visible in the log)
-- PER ISLAND (from log): ShopRules has IsStockedOn / GetIslandShopLevel / ANY_ISLAND="All"; the world map shows 4 islands
--   (Verdantis Lv1+, Corvane Lv22+, Hollowscar Lv52+, Winterspire Lv77+), each with its own Bait Shop & Rod Shop.
--   Bait item names start with the island (I1CommonBait, I1UncommonBait, ...). So shop stock differs per island and so do the NPCs.
--   Shop NPC names per island are hardcoded in SHOPNPC / SELLNPC below.
-- UNKNOWN (resolved at runtime, see the "Copy diagnostics" button):
--   price & level requirement of each item. Price is read from fields named price/cost in the item data; level requirement from
--   ShopRules.GetLevelRequirement (argument form auto-calibrated) or a field named level. A price that cannot
--   be read is shown as "price ?" and learned (~ mark) after the first purchase (coin difference).
local ShopRules = try(function() return require(RS.Modules.ShopRules) end)
local SHOP = {
    Bait = { itemType = "Bait", db = try(function() return require(RS.Modules.BaitDatabase) end),
        getAll = "GetAllBaits", getOne = "GetBaitByName", npc = "Ilyas", payload = "Baits" },
    Rod = { itemType = "Rod", db = try(function() return require(RS.Modules.RodDatabase) end),
        getAll = "GetAllRods", getOne = "GetRodByName", npc = "Tobias", payload = "Rods" },
}
local MAXBUY = (ShopRules and tonumber(ShopRules.MaxBuyAmount)) or 100   -- 100 read from the log
local BUY = {
    Bait = { enabled = false, sel = nil, min = 20, per = 10, items = {}, byName = {}, byLabel = {}, labels = {},
        force = false, modeBy = {}, learned = {}, fails = 0, nextTry = 0, status = "-" },
    Rod = { enabled = false, sel = nil, items = {}, byName = {}, byLabel = {}, labels = {},
        force = false, modeBy = {}, learned = {}, fails = 0, nextTry = 0, status = "-" },
}
local nextBuyCheck = 0
local buyResp, dlgStartT = nil, 0

if ShopP and ShopP.BuyItemResponse then
    ShopP.BuyItemResponse.listen(function(d)
        if type(d) == "table" then buyResp = { name = d.itemName, type = d.itemType, ok = d.success == true, t = os.clock() } end
    end)
end
if DialogueP and DialogueP.NPCInteractionStart then
    DialogueP.NPCInteractionStart.listen(function() dlgStartT = os.clock() end)
end
-- ---------- player data ----------
local baitTbl, rodTbl = nil, nil   -- fallback from the PlayerDataChanged event
task.spawn(function()
    local pk = RS:WaitForChild("Packages", 10)
    local net = pk and pk:WaitForChild("Net", 10)
    local re = net and net:WaitForChild("RE/PlayerDataChanged", 10)
    if not re then return end
    re.OnClientEvent:Connect(function(path, value)
        if type(path) ~= "string" then return end
        if path == "Inventory.Baits" then baitTbl = value
        elseif path == "Inventory.Rods" then rodTbl = value
        else
            local b = path:match("^Inventory%.Baits%.([^%.]+)$")
            if b then baitTbl = baitTbl or {}; baitTbl[b] = value end
        end
    end)
end)
local function cachedData()
    if not PData then return nil end
    for _, nm in ipairs({ "GetCachedData", "GetData" }) do
        if type(PData[nm]) == "function" then
            local ok, d = pcall(PData[nm])
            if not (ok and type(d) == "table") then ok, d = pcall(PData[nm], PData) end
            if ok and type(d) == "table" then return d end
        end
    end
end
local function ownedBait(name)
    local d = cachedData()
    local inv = d and d.Inventory
    local t = type(inv) == "table" and inv.Baits or nil
    if type(t) ~= "table" then t = baitTbl end
    return type(t) == "table" and (tonumber(t[name]) or 0) or 0
end
local function ownsRod(name)
    local d = cachedData()
    local inv = d and d.Inventory
    local t = type(inv) == "table" and inv.Rods or nil
    if type(t) ~= "table" then t = rodTbl end
    if type(t) ~= "table" then return false end
    for k, v in pairs(t) do if v == name or k == name then return true end end
    return false
end
local function myLevel()
    local ls = LP:FindFirstChild("leaderstats")
    local l = ls and ls:FindFirstChild("Level")
    return (l and tonumber(l.Value)) or tonumber(LP:GetAttribute("Level")) or 0
end
local function fmtNum(n)
    local s, k = tostring(math.floor(n + 0.5)), nil
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end
local function clampInt(n, lo, hi) return math.max(lo, math.min(hi, math.floor(tonumber(n) or lo))) end

-- ---------- islands, per-island shop stock, shop NPCs ----------
-- "stock" value -> "all" | { [Island] = true } | nil
local function parseIsland(v)
    local tv = type(v)
    if tv == "string" then
        if v:lower() == "all" then return "all" end
        if ISL[v] then return { [v] = true } end
    elseif tv == "number" then
        local x = ISLANDS[math.floor(v)]
        if x then return { [x.id] = true } end
    elseif tv == "table" then
        local set, n = {}, 0
        for k, x in pairs(v) do
            local id
            if type(x) == "string" then
                if x:lower() == "all" then return "all" end
                if ISL[x] then id = x end
            elseif type(x) == "number" and type(k) == "number" and ISLANDS[x] then id = ISLANDS[x].id
            elseif x == true and type(k) == "string" then
                if k:lower() == "all" then return "all" end
                if ISL[k] then id = k end
            elseif x == true and type(k) == "number" and ISLANDS[k] then id = ISLANDS[k].id end
            if id then set[id] = true; n = n + 1 end
        end
        if n > 0 then return set end
    end
end
local function islandFromName(name)   -- I1CommonBait -> Island1 (confirmed for baits in the log)
    local n = tonumber(name:match("^I(%d)%u")) or tonumber(name:match("^Island(%d)"))
    local x = n and ISLANDS[n]
    return x and { [x.id] = true } or nil
end
local function stockFromData(data)
    if type(data) ~= "table" then return nil end
    for k, v in pairs(data) do
        if type(k) == "string" then
            local lk = k:lower()
            if (lk:find("island", 1, true) or lk:find("stock", 1, true)) and not lk:find("element", 1, true) then
                local r = parseIsland(v)
                if r then return r, k end
            end
        end
    end
end
-- argument form of ShopRules.IsStockedOn is not visible in the log -> auto-calibrated
local STOCK_FORMS = {
    { "(type,name,island)", function(f, t, n, d, i) return f(t, n, i) end },
    { "(name,island)", function(f, t, n, d, i) return f(n, i) end },
    { "(name,type,island)", function(f, t, n, d, i) return f(n, t, i) end },
    { "(data,island)", function(f, t, n, d, i) return f(d, i) end },
    { "(island,name)", function(f, t, n, d, i) return f(i, n) end },
    { "(island,type,name)", function(f, t, n, d, i) return f(i, t, n) end },
}
local STOCKFN = nil   -- { label, f(itemType, name, data, islandEntry) }
local function stockCalls()
    local fn = ShopRules and ShopRules.IsStockedOn
    local out = {}
    if type(fn) ~= "function" then return out end
    for _, w in ipairs({ { "", fn }, { "self,", function(...) return fn(ShopRules, ...) end } }) do
        for _, form in ipairs(STOCK_FORMS) do
            for _, km in ipairs({ "id", "idx" }) do
                out[#out + 1] = { label = w[1] .. form[1] .. "/" .. km, f = function(t, n, d, x)
                    return form[2](w[2], t, n, d, km == "id" and x.id or x.idx)
                end }
            end
        end
    end
    return out
end
local function calibrateStock(kind, list)
    if STOCKFN then return end
    local S = SHOP[kind]
    local best, bestScore
    for _, c in ipairs(stockCalls()) do
        local bad, cover, partial, agree, checked = 0, 0, 0, 0, 0
        for _, e in ipairs(list) do
            local t, f = 0, 0
            local res = {}
            for _, x in ipairs(ISLANDS) do
                local ok, r = pcall(c.f, S.itemType, e.name, e.data, x)
                if ok and type(r) == "boolean" then
                    res[x.id] = r
                    if r then t = t + 1 else f = f + 1 end
                else bad = bad + 1 end
            end
            if bad > 0 then break end
            if t >= 1 then cover = cover + 1 end
            if t >= 1 and f >= 1 then partial = partial + 1 end
            local pre = islandFromName(e.name)
            if pre then
                checked = checked + 1
                for id in pairs(pre) do if res[id] then agree = agree + 1 end end
            end
        end
        if bad == 0 and partial >= 1 and cover >= #list * 0.5 and (checked == 0 or agree / checked >= 0.8) then
            local score = partial * 1000 + cover * 10 + agree
            if not bestScore or score > bestScore then best, bestScore = c, score end
        end
    end
    STOCKFN = best
end
local function resolveStock(kind, list)
    local B, S = BUY[kind], SHOP[kind]
    calibrateStock(kind, list)
    local srcCount = {}
    for _, e in ipairs(list) do
        local set, src
        if STOCKFN then
            local s2, n = {}, 0
            for _, x in ipairs(ISLANDS) do
                local ok, r = pcall(STOCKFN.f, S.itemType, e.name, e.data, x)
                if ok and r == true then s2[x.id] = true; n = n + 1 end
            end
            if n == #ISLANDS then set = "all" elseif n > 0 then set = s2 end
            if set then src = "ShopRules.IsStockedOn" .. STOCKFN.label end
        end
        if not set then
            local s3, key = stockFromData(e.data)
            if s3 then set, src = s3, "field data: " .. key end
        end
        if not set then
            local s4 = islandFromName(e.name)
            if s4 then set, src = s4, "item name prefix" end
        end
        e.stock = set
        local k = src or "UNREADABLE"
        srcCount[k] = (srcCount[k] or 0) + 1
        -- effective level requirement = max(item level, lowest shop level of an island that sells this item)
        local req = e.level or 0
        if type(set) == "table" then
            local m
            for id in pairs(set) do local l = islandLevel(id); if not m or l < m then m = l end end
            if m and m > req then req = m end
        end
        e.reqLevel = (e.level ~= nil or type(set) == "table") and req or nil
    end
    local parts = {}
    for k, n in pairs(srcCount) do parts[#parts + 1] = k .. " x" .. n end
    table.sort(parts)
    B.stockSrc = table.concat(parts, "; ")
end
local function stockText(e)
    if e.stock == "all" then return "All islands" end
    if type(e.stock) == "table" then
        local t = {}
        for _, x in ipairs(ISLANDS) do if e.stock[x.id] then t[#t + 1] = x.name end end
        return table.concat(t, "/")
    end
    return "island ?"
end
local function stockRank(e)
    if type(e.stock) == "table" then
        for i, x in ipairs(ISLANDS) do if e.stock[x.id] then return i end end
    end
    return e.stock == "all" and 0 or 9
end
local function reqLevel(e) return e.reqLevel or e.level end
-- pick the island + shop NPC to buy this item from. Returns (island, npc) or (nil, island whose NPC is unknown)
local function pickShop(kind, e, force)
    local npcs = SHOPNPC[kind]
    local cands = {}
    for _, x in ipairs(ISLANDS) do
        if e.stock == "all" or e.stock == nil or (type(e.stock) == "table" and e.stock[x.id]) then cands[#cands + 1] = x.id end
    end
    local cur = curIsland()
    for _, id in ipairs(cands) do   -- already on the right island: no need to move
        if id == cur and npcs[id] then return id, npcs[id] end
    end
    for _, id in ipairs(cands) do
        if npcs[id] and (force or islandLevel(id) <= myLevel()) then return id, npcs[id] end
    end
    for _, id in ipairs(cands) do
        if npcs[id] then return id, npcs[id] end
    end
    return nil, cands[1]
end

-- ---------- catalog: scan items, prices, level requirements ----------
local function callDB(db, fname, ...)
    local f = db and db[fname]
    if type(f) ~= "function" then return nil end
    local ok, r = pcall(f, ...)
    if ok and r ~= nil then return r end
    ok, r = pcall(f, db, ...)
    if ok then return r end
    return nil
end
-- GetAll may return an array of names, an array of tables, or a name -> data map
local function listify(all)
    local out = {}
    if type(all) ~= "table" then return out end
    if #all > 0 then
        for _, v in ipairs(all) do
            if type(v) == "string" then out[#out + 1] = { name = v }
            elseif type(v) == "table" then
                local nm = v.Name or v.ItemName or v.Id or v.ID or v.name
                if type(nm) == "string" then out[#out + 1] = { name = nm, data = v } end
            end
        end
    else
        for k, v in pairs(all) do
            if type(k) == "string" then out[#out + 1] = { name = k, data = type(v) == "table" and v or nil } end
        end
    end
    return out
end
-- find a number in the item data by field name (heuristic; the source field is recorded for diagnostics)
local function findNum(t, pats, skipPats)
    if type(t) ~= "table" then return nil end
    local cands = {}
    local function walk(x, depth, path)
        if depth > 2 then return end
        for k, v in pairs(x) do
            if type(k) == "string" then
                local lk = k:lower()
                local hit = false
                for _, p in ipairs(pats) do if lk:find(p, 1, true) then hit = true break end end
                if hit and skipPats then
                    for _, p in ipairs(skipPats) do if lk:find(p, 1, true) then hit = false break end end
                end
                if hit and type(v) == "number" and v == v and v >= 0 then
                    cands[#cands + 1] = { v = v, key = path .. k, depth = depth, exact = (lk == pats[1]) }
                end
                if type(v) == "table" then walk(v, depth + 1, path .. k .. ".") end
            end
        end
    end
    walk(t, 0, "")
    if #cands == 0 then return nil end
    table.sort(cands, function(a, b)
        if a.exact ~= b.exact then return a.exact end
        if a.depth ~= b.depth then return a.depth < b.depth end
        if #a.key ~= #b.key then return #a.key < #b.key end
        return a.key < b.key
    end)
    return cands[1].v, cands[1].key
end
local function findDisplay(t)
    if type(t) ~= "table" then return nil end
    for k, v in pairs(t) do
        if type(k) == "string" and type(v) == "string" and v ~= "" then
            local lk = k:lower()
            if lk == "displayname" or lk == "display" then return v end
        end
    end
end
local LEVEL_FORMS = {
    { "(name)", function(f, t, n, d) return f(n) end },
    { "(type, name)", function(f, t, n, d) return f(t, n) end },
    { "(name, type)", function(f, t, n, d) return f(n, t) end },
    { "(data)", function(f, t, n, d) return f(d) end },
}
local function sourceStats(res)
    local num, distinct, seen = 0, 0, {}
    for _, v in pairs(res) do
        num = num + 1
        if not seen[v] then seen[v] = true; distinct = distinct + 1 end
    end
    return num, distinct
end
local function resolveLevels(kind, list)
    local B, S = BUY[kind], SHOP[kind]
    local best
    local fn = ShopRules and ShopRules.GetLevelRequirement
    if type(fn) == "function" then
        for fi, form in ipairs(LEVEL_FORMS) do
            local res = {}
            for _, e in ipairs(list) do
                local ok, r = pcall(form[2], fn, S.itemType, e.name, e.data)
                if ok and type(r) == "number" and r == r and r >= 0 and r <= 1000 then res[e.name] = r end
            end
            local num, distinct = sourceStats(res)
            if num > 0 and (not best or distinct > best.distinct or (distinct == best.distinct and num > best.num)) then
                best = { res = res, num = num, distinct = distinct, src = "ShopRules.GetLevelRequirement" .. form[1] }
            end
        end
    end
    local fres, fkey = {}, nil
    for _, e in ipairs(list) do
        local v, key = findNum(e.data, { "level" }, { "xp" })
        if v then fres[e.name] = v; fkey = fkey or key end
    end
    local fnum, fdistinct = sourceStats(fres)
    local pick
    if best and (fnum == 0 or best.distinct >= fdistinct) then pick = best
    elseif fnum > 0 then pick = { res = fres, src = "field data item: " .. tostring(fkey) } end
    if pick then
        for _, e in ipairs(list) do e.level = pick.res[e.name] end
        B.levelSrc = pick.src
    else
        B.levelSrc = "UNREADABLE (level requirement unknown, no lock)"
    end
end
local function isLocked(e) local r = reqLevel(e); return r ~= nil and r > myLevel() end
local function priceOf(kind, e) return e.price or BUY[kind].learned[e.name] end
local function fmtPrice(kind, e)
    if e.price then return "$" .. fmtNum(e.price) end
    local l = BUY[kind].learned[e.name]
    if l then return "~$" .. fmtNum(l) end
    return "price ?"
end
local function rebuildLabels(kind)
    local B = BUY[kind]
    B.labels, B.byLabel = {}, {}
    local lv = myLevel()
    for _, e in ipairs(B.items) do
        local nm = e.display or e.name
        local rq = reqLevel(e)
        local lbl
        if kind == "Rod" and ownsRod(e.name) then
            lbl = "[OWNED] " .. nm .. " · " .. fmtPrice(kind, e) .. ((e.level and e.level > 0) and (" · Lv " .. e.level) or "") .. " · " .. stockText(e)
        elseif rq and rq > lv then
            lbl = "[LOCKED] " .. nm .. " · needs Lv " .. rq .. " · " .. fmtPrice(kind, e) .. " · " .. stockText(e)
        else
            lbl = nm .. " · " .. fmtPrice(kind, e) .. ((e.level and e.level > 0) and (" · Lv " .. e.level) or "") .. " · " .. stockText(e)
        end
        if B.byLabel[lbl] then lbl = lbl .. " (" .. e.name .. ")" end
        B.byLabel[lbl] = e
        B.labels[#B.labels + 1] = lbl
    end
    if B.dd then pcall(function() B.dd:SetList(B.labels) end) end
end
local function scanKind(kind)
    local S, B = SHOP[kind], BUY[kind]
    B.err = nil
    if not (S.db and type(S.db[S.getAll]) == "function") then
        B.err = "database module / " .. S.getAll .. " missing"; B.items = {}; rebuildLabels(kind); return false
    end
    B.raw = callDB(S.db, S.getAll)
    local list = listify(B.raw)
    if #list == 0 then
        B.err = S.getAll .. " is empty or its result shape is unknown"; B.items = {}; rebuildLabels(kind); return false
    end
    for _, e in ipairs(list) do
        local one = callDB(S.db, S.getOne, e.name)
        if type(one) == "table" then e.data = one end
        e.display = findDisplay(e.data)
        e.price, e.priceKey = findNum(e.data, { "price", "cost" })
    end
    resolveLevels(kind, list)
    resolveStock(kind, list)
    table.sort(list, function(a, b)
        local ra, rb = stockRank(a), stockRank(b)
        if ra ~= rb then return ra < rb end
        local la, lb = a.level or 0, b.level or 0
        if la ~= lb then return la < lb end
        local pa, pb = a.price or math.huge, b.price or math.huge
        if pa ~= pb then return pa < pb end
        return a.name < b.name
    end)
    B.items, B.byName = list, {}
    for _, e in ipairs(list) do B.byName[e.name] = e end
    if B.sel and not B.byName[B.sel] then B.sel = nil end
    rebuildLabels(kind)
    return true
end
local function pickItem(kind, v)
    if type(v) == "table" then v = v[1] end
    local B = BUY[kind]
    local e = type(v) == "string" and B.byLabel[v] or nil
    if not e then return end
    if isLocked(e) and not B.force then
        N("Auto Buy " .. kind, "Requires level " .. reqLevel(e) .. " (your level " .. myLevel() .. ")", "#DC3232")
        return
    end
    B.sel = e.name
end
task.spawn(function()   -- relabel automatically when the level goes up
    local ls = LP:WaitForChild("leaderstats", 15)
    local lv = ls and ls:WaitForChild("Level", 15)
    if lv then
        lv:GetPropertyChangedSignal("Value"):Connect(function()
            for _, k in ipairs({ "Bait", "Rod" }) do pcall(rebuildLabels, k) end
        end)
    end
end)

-- ---------- pembelian ----------
local function waitResp(name, itemType, t0, id, timeout)
    local tt = os.clock()
    while os.clock() - tt < timeout do
        local r = buyResp
        if r and r.t >= t0 and r.name == name and r.type == itemType then return r end
        task.wait(0.05)
        if not alive(id) then return nil end
    end
end
local function sendBuy(S, name, amount, id)
    local t0 = os.clock()
    if not pcall(ShopP.RequestBuyItem.send, { amount = amount, itemName = name, itemType = S.itemType }) then return nil end
    return waitResp(name, S.itemType, t0, id, 3)
end
local function npcRoot(m)
    return m and (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true))
end
-- open the shop via NPC dialogue (packet order exactly as in the log), then buy. npcName = shop NPC on the island that sells the item
local function buyViaNpc(S, npcName, name, amount, id, crossIsland)
    local folder = workspace:FindFirstChild("DialogueNPCs")
    local m = folder and folder:FindFirstChild(npcName)
    local p = npcRoot(m)
    local r = Root()
    if not (m and p and r and DialogueP and ShopP) then return nil end
    local back = r.CFrame
    r.CFrame = CFrame.new(p.Position + p.CFrame.LookVector * 4 + Vector3.new(0, 3, 0))
    r.AssemblyLinearVelocity = Vector3.zero
    local resp
    if wait(id, crossIsland and 1.5 or 0.6) then   -- changing island: give the zone/map time to load
        local function step(pk, data) if pk then pcall(pk.send, data) end; return wait(id, 0.4) end
        local t = os.clock()
        step(DialogueP.RequestNPCInteraction, { npcId = npcName, npcModel = m })
        while dlgStartT < t and os.clock() - t < 3 do task.wait(0.05) end
        step(DialogueP.DialogueSelectBranch, { npcId = npcName, branchId = npcName .. "_Greet_r1" })
        step(DialogueP.DialogueAction, { npcId = npcName, actionId = "OpenShop", payload = S.payload })
        step(DialogueP.DialogueAdvance, { npcId = npcName, nodeId = npcName .. "_OpenShop" })
        step(DialogueP.NPCInteractionEnd, { npcId = npcName, reason = "endOfDialogue" })
        if wait(id, 0.6) then resp = sendBuy(S, name, amount, id) end
    end
    local r2 = Root()
    if r2 then r2.CFrame = back; r2.AssemblyLinearVelocity = Vector3.zero end
    return resp
end
-- Items are sold in a specific island's shop: if already on that island try a direct send first; if that fails
-- (or on another island) -> teleport to that island's shop NPC, buy, then come back. Mode is remembered per item type + island.
local function purchase(kind, name, amount, id, e)
    local S, B = SHOP[kind], BUY[kind]
    if not (ShopP and ShopP.RequestBuyItem) then return false, "packet Shop.RequestBuyItem missing" end
    local isl, npc = pickShop(kind, e or {}, B.force)
    if not isl then
        local nm = ISL[npc] and ISL[npc].name or "?"
        return false, "no shop NPC set for " .. nm
    end
    B.lastIsland = isl
    local c0 = coins()
    local resp
    local here = curIsland() == isl
    if here and B.modeBy[isl] ~= "npc" then
        resp = sendBuy(S, name, amount, id)
        if not alive(id) then return false, "dibatalkan" end
        if resp and resp.ok then B.modeBy[isl] = "direct" end
    end
    if not (resp and resp.ok) then
        resp = buyViaNpc(S, npc, name, amount, id, not here)
        if not alive(id) then return false, "dibatalkan" end
        if resp and resp.ok then B.modeBy[isl] = "npc" end
    end
    if not (resp and resp.ok) then
        return false, resp and "server refused (success=false)" or "no reply from server"
    end
    local t0 = os.clock()   -- read the coin difference right after it drops, before other rewards arrive
    while coins() >= c0 and os.clock() - t0 < 1.5 do task.wait(0.05) end
    local spent = c0 - coins()
    if spent > 0 and amount > 0 then B.learned[name] = spent / amount end
    return true
end

-- ---------- auto buy steps ----------
local function failed(B, why)
    B.fails = B.fails + 1
    B.status = "failed: " .. why
    if B.fails >= 3 then
        B.fails = 0
        B.nextTry = os.clock() + 60
        B.status = "failed 3x (" .. why .. "), retrying in 60 s"
    end
end
local STEP = {}
STEP.Bait = function(id, now)
    local B = BUY.Bait
    local e = B.sel and B.byName[B.sel]
    if not e then B.status = "select a bait first"; return end
    if isLocked(e) and not B.force then B.status = "locked, needs level " .. reqLevel(e); return end
    local have = ownedBait(e.name)
    if not now and have >= B.min then B.status = "enough stock (" .. have .. ")"; return end
    local amount = clampInt(B.per, 1, MAXBUY)
    local price = priceOf("Bait", e)
    if price and price > 0 then
        local afford = math.floor(coins() / price)
        if afford < 1 then B.status = "not enough coins (need $" .. fmtNum(price) .. ")"; return end
        amount = math.min(amount, afford)
    else
        amount = 1   -- price unknown: buy 1 first to read the price from the coin difference
    end
    B.status = "buying " .. amount .. "x " .. (e.display or e.name)
    local ok, why = purchase("Bait", e.name, amount, id, e)
    if not alive(id) then return end
    if ok then
        B.fails = 0
        B.status = "bought " .. amount .. "x " .. (e.display or e.name)
        rebuildLabels("Bait")
        N("Auto Buy Bait", "Bought " .. amount .. "x " .. (e.display or e.name), "#50C864")
    else
        failed(B, why)
    end
end
STEP.Rod = function(id, now)
    local B = BUY.Rod
    local e = B.sel and B.byName[B.sel]
    if not e then B.status = "select a rod first"; return end
    if ownsRod(e.name) then B.status = "already owned"; return end
    if isLocked(e) and not B.force then B.status = "locked, needs level " .. reqLevel(e); return end
    local price = priceOf("Rod", e)
    if price and coins() < price then B.status = "not enough coins (need $" .. fmtNum(price) .. ")"; return end
    B.status = "buying " .. (e.display or e.name)
    local ok, why = purchase("Rod", e.name, 1, id, e)
    if not alive(id) then return end
    if ok then
        B.fails = 0
        B.status = "bought " .. (e.display or e.name)
        rebuildLabels("Rod")
        N("Auto Buy Rod", "Bought " .. (e.display or e.name), "#50C864")
    else
        failed(B, why)
    end
end
local function autoBuyStep(id)
    if os.clock() < nextBuyCheck then return end
    nextBuyCheck = os.clock() + 6
    for _, kind in ipairs({ "Bait", "Rod" }) do
        local B = BUY[kind]
        if B.enabled and os.clock() >= B.nextTry then
            local ok, err = pcall(STEP[kind], id, false)
            if not ok then B.status = "error: " .. tostring(err):sub(1, 60) end
            if not alive(id) then return end
        end
    end
end
local function buyNow(kind)
    if running then N("Buy", "Turn off fishing first", "#DC3232"); return end
    task.spawn(function()
        local ok, err = pcall(STEP[kind], nil, true)
        if not ok then BUY[kind].status = "error: " .. tostring(err):sub(1, 60) end
        N("Buy " .. kind, BUY[kind].status, "#6495ED")
    end)
end

-- ---------- info + diagnosa ----------
local function infoText(kind)
    local B = BUY[kind]
    if B.err then return "Scan failed: " .. B.err .. "\nPress Copy diagnostics and send it to the script author" end
    local e = B.sel and B.byName[B.sel]
    if not e then return "Selected: -\nCatalog: " .. #B.items .. " items   Your level: " .. myLevel() end
    local rq = reqLevel(e)
    local req = rq == nil and "?" or (rq > 0 and ("Lv " .. rq) or "no requirement")
    local l3
    if kind == "Bait" then l3 = "Stock: " .. ownedBait(e.name)
    else l3 = ownsRod(e.name) and "Owned" or "Not owned" end
    local isl, npc = pickShop(kind, e, B.force)
    local shop = isl and (ISL[isl].name .. " · NPC " .. npc) or ("no NPC set for " .. (ISL[npc] and ISL[npc].name or "?"))
    return "Selected: " .. (e.display or e.name) ..
        "\nPrice: " .. fmtPrice(kind, e) .. "   Requires: " .. req .. "   Your level: " .. myLevel() ..
        "\nSold on: " .. stockText(e) .. "\nBuy from: " .. shop ..
        "\n" .. l3 .. "   Status: " .. B.status
end
local function dser(v, d)
    d = d or 0
    local tv = typeof(v)
    if tv == "string" then return string.format("%q", v:sub(1, 80)) end
    if tv == "table" then
        if d >= 3 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 25 then parts[#parts + 1] = "..."; break end
            parts[#parts + 1] = tostring(k) .. "=" .. dser(x, d + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    if tv == "function" then return "<fn>" end
    return tostring(v)
end
local function diagText(kind)
    local B, S = BUY[kind], SHOP[kind]
    local out = { "== auto buy diagnostics " .. kind .. " ==",
        "your level: " .. myLevel() .. "   coins: " .. coins() .. "   buy mode per island: " .. dser(B.modeBy) .. "   current island: " .. tostring(curIsland()),
        "db present: " .. tostring(S.db ~= nil) .. "   ShopRules present: " .. tostring(ShopRules ~= nil),
        "GetAll shape: " .. typeof(B.raw) .. "   items read: " .. #B.items,
        "level source: " .. tostring(B.levelSrc), "scan error: " .. tostring(B.err),
        "island stock source: " .. tostring(B.stockSrc), "shop NPCs: " .. dser(SHOPNPC) }
    for i, e in ipairs(B.items) do
        if i > 6 then break end
        out[#out + 1] = string.format("[%d] %s display=%s price=%s(%s) level=%s stock=%s", i, e.name, tostring(e.display),
            tostring(e.price), tostring(e.priceKey), tostring(e.level), stockText(e))
        out[#out + 1] = "    data: " .. dser(e.data)
    end
    if type(B.raw) == "table" and #B.items == 0 then out[#out + 1] = "raw GetAll: " .. dser(B.raw) end
    local okC, SC = pcall(function() return require(PS.Controllers.GUI.ShopController) end)
    if okC and type(SC) == "table" then
        local names = {}
        for k, v in pairs(SC) do names[#names + 1] = tostring(k) .. ":" .. type(v) end
        table.sort(names)
        out[#out + 1] = "ShopController: " .. table.concat(names, ", "):sub(1, 600)
    else
        out[#out + 1] = "ShopController cannot be required"
    end
    return table.concat(out, "\n")
end
local function copyDiag(kind)
    local txt = diagText(kind)
    if setclipboard then
        pcall(setclipboard, txt)
        N("Diagnostics " .. kind, "Copied to clipboard", "#50C864")
    else
        print(txt)
        N("Diagnostics " .. kind, "setclipboard unavailable, output in console (F9)", "#DC3232")
    end
end
task.spawn(function()
    for _, k in ipairs({ "Bait", "Rod" }) do
        local ok, err = pcall(scanKind, k)
        if not ok then BUY[k].err = tostring(err):sub(1, 80) end
    end
end)

local function cycle(id)
    -- 0. auto sell every N fish in the bag
    if SELL.enabled and SELL.every > 0 and os.clock() >= nextSellTry and invCount() >= SELL.every then
        local ok = sellAll(id)
        if not alive(id) then return end
        if ok then stats.sold += 1; stats.status = "sell done"
        else stats.fail += 1; stats.status = "sell failed, retrying in 15 s"; nextSellTry = os.clock() + 15 end
        wait(id, 0.5)
    end
    if not alive(id) then return end

    -- 0b. auto buy bait / rod (separate cards on Main)
    autoBuyStep(id)
    if not alive(id) then return end

    -- 1. equip rod
    if Hotbar and Hotbar.IsRodEquipped and not Hotbar.IsRodEquipped() then
        stats.status = "equip rod"
        pcall(Hotbar.ForceEquipRod)
        local t0 = os.clock()
        while not Hotbar.IsRodEquipped() and os.clock() - t0 < 3 do task.wait(0.1) end
    end
    if not alive(id) then return end

    -- 2. cast
    stats.status = "holding rod button"
    local seen = {}
    for _, p in ipairs(workspace:GetChildren()) do if p.Name == "bobber" then seen[p] = true end end
    lastPower = nil
    local castT = os.clock()
    if not holdCast(id) then
        stats.status = "rod button not found"; stats.fail += 1; wait(id, 1.5); return
    end
    stats.casts += 1
    local bobber
    local t0c = os.clock()
    while os.clock() - t0c < 4 and not bobber do
        for _, p in ipairs(workspace:GetChildren()) do
            if p.Name == "bobber" and p:IsA("BasePart") and not seen[p] and (p:GetAttribute("Owner") == LP.UserId or p:GetAttribute("FishingRigOwner") == LP.UserId) then bobber = p break end
        end
        task.wait(0.05)
        if not alive(id) then return end
    end
    if not bobber then
        stats.status = "bobber did not appear"; stats.fail += 1; wait(id, 1.5); return
    end

    -- 3. wait to land on water
    stats.status = "menunggu bobber mendarat"
    local t0 = os.clock()
    while bobber.Parent and bobber:GetAttribute("WaterLandedAt") == nil and os.clock() - t0 < 6 do task.wait(0.05) if not alive(id) then return end end
    if not bobber.Parent or bobber:GetAttribute("WaterLandedAt") == nil then
        stats.status = "bobber failed to land on water"; stats.fail += 1
        pcall(Fishing.ReelIn.send); wait(id, 1); return
    end

    -- 4-5. wait for FishDataResponse
    stats.status = ("menunggu gigitan (power %s)"):format(lastPower and math.floor(lastPower) or "?")
    while lastDataT < castT and os.clock() - castT < 40 do task.wait(0.05) if not alive(id) then return end end
    if lastDataT < castT then
        stats.status = "no bite"; stats.fail += 1
        pcall(Fishing.ReelIn.send); wait(id, 1); return
    end
    local d = lastData
    stats.status = ("minigame %s (%s)"):format(d and d.name or "?", d and d.rarity or "?")

    -- 6. selesaikan minigame
    local before = streak()
    if CFG.mode == "mini" or (d and d.rarity == "Secret") then
        stats.status = "main minigame..."
        local ok = playMinigame(id)
        if not alive(id) then return end
        if ok then stats.fish += 1; stats.status = "caught " .. (d and d.name or "fish")
        else stats.fail += 1; stats.status = "minigame failed/timeout" end
        pcall(Fishing.ReelIn.send)
        wait(id, CFG.castGap)
        return
    end
    if not wait(id, CFG.minigameDelay) then return end
    local MC = try(function() return require(PS.Gameplay.MinigameController) end)
    if MC and MC.stop then pcall(MC.stop, true) end
    local t1 = os.clock()
    while streak() == before and os.clock() - t1 < 1.5 do task.wait(0.05) if not alive(id) then return end end
    if streak() == before then Fishing.CatchFish.send() end
    t1 = os.clock()
    while streak() == before and os.clock() - t1 < 2.5 do task.wait(0.05) if not alive(id) then return end end
    if streak() ~= before then stats.fish += 1; stats.status = "caught " .. (d and d.name or "fish")
    else stats.fail += 1; stats.status = "CatchFish not counted by server" end
    pcall(Fishing.ReelIn.send)
    wait(id, CFG.castGap)
end

local function start()
    run += 1
    running = true
    local id = run
    task.spawn(function()
        while alive(id) do
            local ok, err = pcall(cycle, id)
            if not ok then stats.status = "error: " .. tostring(err):sub(1, 60); task.wait(1) end
            task.wait()
        end
    end)
end
local function stop()
    run += 1; running = false; stats.status = "idle"
    task.delay(0.3, restoreTouch)   -- mobile thumbstick comes back after fishing is turned off
end

-- ===== UI =====
-- Home is built LAST so an error in Home does not stop the Main features.
local HomePage   = W:AddPage({ Name = "Home", Icon = "house" })
local Main       = W:AddPage({ Name = "Main", Icon = "fish" })
local TeleportPage = W:AddPage({ Name = "Teleport", Icon = "map-pin" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

local cFish = Main:AddCard({ Title = "Auto Fishing", Icon = "fish", Column = 1 })
cFish:Toggle({
    Title = "Instant Fishing", id = "g14_skip",
    Callback = function(v)
        if v then CFG.mode = "skip"; start() else stop() end
        N("Instant Fishing", v and "ON (turn off Auto Fishing first if it is active)" or "OFF", v and "#50C864" or "#DC3232")
    end,
})
cFish:Toggle({
    Title = "Auto Fishing", id = "g14_mini",
    Callback = function(v)
        if v then CFG.mode = "mini"; start() else stop() end
        N("Auto Fishing", v and "ON (turn off Instant Fishing first if it is active)" or "OFF", v and "#50C864" or "#DC3232")
    end,
})


-- ---------- Auto Sell ----------
local cSell = Main:AddCard({ Title = "Auto Sell", Icon = "coins", Column = 2 })
cSell:Toggle({
    Title = "Auto Sell Fish", Desc = "Sell all fish whenever the bag reaches the amount below", id = "g14_sell",
    Callback = function(v)
        SELL.enabled = v
        nextSellTry = 0
        N("Auto Sell", v and ("ON, sells every " .. SELL.every .. " fish") or "OFF", v and "#50C864" or "#DC3232")
    end,
})
do
    local function setEvery(v)
        local n = math.floor(tonumber(v) or 0)
        if n >= 1 then SELL.every = n; N("Auto Sell", "Sells every " .. n .. " fish", "#50C864")
        else N("Auto Sell", "Enter a number of 1 or more", "#DC3232") end
    end
    cSell:Input({
        Title = "Sell every how many fish", Value = tostring(SELL.every), Placeholder = "20", ButtonText = "Set", id = "g14_sellN",
        Callback = function(v) local n = math.floor(tonumber(v) or 0); if n >= 1 then SELL.every = n end end,
        OnButton = setEvery,
    })
end
cSell:Button({
    Title = "Sell everything now", Text = "Sell All now",
    Callback = function()
        if running then N("Sell All", "Turn off fishing first", "#DC3232"); return end
        task.spawn(function()
            local before = invCount()
            if before <= 0 then N("Sell All", "No fish in the bag", "#DC3232"); return end
            local ok = sellAll(nil)
            stats.status = ok and "sell done" or "sell failed"
            N("Sell All", ok and ("Sold (" .. before .. " fish)") or "Sell failed", ok and "#50C864" or "#DC3232")
        end)
    end,
})

-- ---------- Auto Buy Bait & Auto Buy Rod (two separate cards) ----------
local function buildBuyCard(kind, col, icon, id)
    local B = BUY[kind]
    local c = Main:AddCard({ Title = "Auto Buy " .. kind, Icon = icon, Column = col })
    B.dd = c:Dropdown({
        Title = "Select " .. kind, List = B.labels, Placeholder = "Select " .. kind:lower(),
        Callback = function(v) pickItem(kind, v) end,
    })
    B.lbl = c:Label({ Text = "-", Size = 11, Color = "Text" })
    c:Toggle({
        Title = "Auto Buy " .. kind,
        Desc = kind == "Bait" and "Buys automatically when stock is below the limit (teleports to the island shop that sells it, then returns)" or "Buys the selected rod if you have enough coins and do not own it (teleports to the island shop that sells it)",
        id = "g14_buy" .. id,
        Callback = function(v)
            B.enabled = v
            B.nextTry = 0
            nextBuyCheck = 0
            N("Auto Buy " .. kind, v and "ON (runs together with fishing)" or "OFF", v and "#50C864" or "#DC3232")
        end,
    })
    if kind == "Bait" then
        c:Input({
            Title = "Buy when stock is below", Value = tostring(B.min), Placeholder = "20", ButtonText = "Set", id = "g14_baitMin",
            Callback = function(v) local n = math.floor(tonumber(v) or 0); if n >= 1 then B.min = n end end,
            OnButton = function(v)
                local n = math.floor(tonumber(v) or 0)
                if n >= 1 then B.min = n; N("Auto Buy Bait", "Buys when stock is below " .. n, "#50C864")
                else N("Auto Buy Bait", "Enter a number of 1 or more", "#DC3232") end
            end,
        })
        c:Input({
            Title = "Amount per purchase (max " .. MAXBUY .. ")", Value = tostring(B.per), Placeholder = "10", ButtonText = "Set", id = "g14_baitPer",
            Callback = function(v) local n = math.floor(tonumber(v) or 0); if n >= 1 then B.per = math.min(n, MAXBUY) end end,
            OnButton = function(v)
                local n = math.floor(tonumber(v) or 0)
                if n >= 1 then B.per = math.min(n, MAXBUY); N("Auto Buy Bait", "Buys " .. B.per .. " per purchase", "#50C864")
                else N("Auto Buy Bait", "Enter a number of 1 or more", "#DC3232") end
            end,
        })
    end
    c:Toggle({
        Title = "Allow selecting locked items", Desc = "Disables the level lock (the server still refuses if it is really not allowed)",
        id = "g14_force" .. id,
        Callback = function(v) B.force = v end,
    })
    c:Button({ Title = "Buy now", Text = kind == "Bait" and "Buy selected bait" or "Buy selected rod", Callback = function() buyNow(kind) end })
    c:Button({
        Title = "Rescan", Text = "Scan " .. kind:lower() .. " + price",
        Callback = function()
            task.spawn(function()
                local ok, err = pcall(scanKind, kind)
                if not ok then B.err = tostring(err):sub(1, 80) end
                N("Scan " .. kind, B.err and ("Failed: " .. B.err) or (#B.items .. " items found"), B.err and "#DC3232" or "#6495ED")
            end)
        end,
    })
    c:Button({ Title = "Copy diagnostics", Text = "Copy " .. kind:lower() .. " diagnostics", Callback = function() copyDiag(kind) end })
end
buildBuyCard("Bait", 1, "coins", "bait")
buildBuyCard("Rod", 2, "fish", "rod")

-- Status / debug card sits at the bottom of the Main page, under Auto Buy Rod
local cStat = Main:AddCard({ Title = "Status", Icon = "activity", Column = 2 })
local stLbl = cStat:Label({ Text = "-", Size = 11, Color = "Text" })
task.spawn(function()
    local ownSig
    while W.Alive do
        task.wait(1)
        for _, k in ipairs({ "Bait", "Rod" }) do
            local B = BUY[k]
            if B.lbl then pcall(function() B.lbl:SetText(infoText(k)) end) end
        end
        -- refresh the "[OWNED]" tag in the rod list when a rod is bought / obtained
        pcall(function()
            local B, sig = BUY.Rod, {}
            for _, e in ipairs(B.items) do if ownsRod(e.name) then sig[#sig + 1] = e.name end end
            sig = table.concat(sig, ",")
            if ownSig ~= nil and sig ~= ownSig then rebuildLabels("Rod") end
            ownSig = sig
        end)
    end
end)

-- ---------- Teleport NPC ----------
local npcMap, npcNames, selNpc = {}, {}, nil
local function npcPart(m)
    return m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true)
end
local function scanNpc()
    local map, names, cnt, done = {}, {}, {}, {}
    local function add(m)
        if not m or done[m] or not m:IsA("Model") or Players:GetPlayerFromCharacter(m) or not npcPart(m) then return end
        done[m] = true
        local n = m.Name
        cnt[n] = (cnt[n] or 0) + 1
        if cnt[n] > 1 then n = n .. " (" .. cnt[n] .. ")" end
        map[n] = m; names[#names + 1] = n
    end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Humanoid") then
            add(d.Parent)
        elseif d:IsA("Model") and d.Parent and d.Parent.Name:lower():find("npc") then
            add(d)
        end
    end
    table.sort(names)
    return map, names
end
pcall(function() npcMap, npcNames = scanNpc() end)

local cTp = TeleportPage:AddCard({ Title = "Teleport NPC", Icon = "map-pin", Column = 1 })
local tpLbl
local function UpdateTpLabel()
    if tpLbl then
        pcall(function() tpLbl:SetText("NPC ditemukan: " .. #npcNames .. "\nTerpilih: " .. (selNpc or "-")) end)
    end
end
local function PickNpc(v)
    if type(v) == "table" then v = v[1] end
    if type(v) == "string" and npcMap[v] then selNpc = v end
    UpdateTpLabel()
end

-- Built-in ui.lua dropdown: the list scrolls and has a Search box
local dd = cTp:Dropdown({
    Title = "Select NPC", List = npcNames, Placeholder = "Select NPC",
    Callback = PickNpc,
})
local function SetDropdownList()
    pcall(function() dd:SetList(npcNames) end)
end

cTp:Button({
    Title = "Refresh NPC", Text = "Find all NPCs",
    Callback = function()
        local ok, m, names = pcall(scanNpc)
        if ok then
            npcMap, npcNames = m, names
            if selNpc and not npcMap[selNpc] then selNpc = nil end
            SetDropdownList()
            UpdateTpLabel()
            N("Refresh NPC", #npcNames .. " NPC ditemukan", "#6495ED")
        else
            N("Refresh NPC", "Failed: " .. tostring(m), "#DC3232")
        end
    end,
})
cTp:Button({
    Title = "Teleport To Npc", Text = "Teleport to the selected NPC",
    Callback = function()
        local m = selNpc and npcMap[selNpc]
        local p = m and m.Parent and npcPart(m)
        local r = Root()
        if not p then N("Teleport", "Select an NPC first / NPC missing, press Refresh NPC", "#DC3232"); return end
        if not r then N("Teleport", "Character not loaded", "#DC3232"); return end
        local pos = p.Position + p.CFrame.LookVector * 4 + Vector3.new(0, 3, 0)
        r.CFrame = CFrame.new(pos, Vector3.new(p.Position.X, pos.Y, p.Position.Z))
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        N("Teleport", selNpc, "#50C864")
    end,
})
tpLbl = cTp:Label({ Text = "-", Size = 11, Color = "Text" })
UpdateTpLabel()

-- ---------- Teleport Island ----------
local ISLANDS = {
    { Name = "VERDANTIS",        Pos = Vector3.new(-249.81, 6.93, -53.22) },
    { Name = "CORVANE",          Pos = Vector3.new(3764.71, 17.36, 72.81) },
    { Name = "HOLLOWSCAR ISLE",  Pos = Vector3.new(-4665.43, 27.13, -98.15) },
    { Name = "WINTERSPIRE",      Pos = Vector3.new(287.56, 5.54, -4885.57) },
}
local islandPos, islandNames, selIsland = {}, {}, nil
for _, i in ipairs(ISLANDS) do
    islandPos[i.Name] = i.Pos
    islandNames[#islandNames + 1] = i.Name
end

local cIsland = TeleportPage:AddCard({ Title = "Teleport Island", Icon = "map-pin", Column = 2 })
cIsland:Dropdown({
    Title = "Select Island", List = islandNames, Placeholder = "Select Island",
    Callback = function(v)
        if type(v) == "table" then v = v[1] end
        if type(v) == "string" and islandPos[v] then selIsland = v end
    end,
})
cIsland:Button({
    Title = "Teleport To Island", Text = "Teleport to the selected island",
    Callback = function()
        local pos = selIsland and islandPos[selIsland]
        local r = Root()
        if not pos then N("Teleport Island", "Select an island first", "#DC3232"); return end
        if not r then N("Teleport Island", "Character not loaded", "#DC3232"); return end
        r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        N("Teleport Island", selIsland, "#50C864")
    end,
})

task.spawn(function()
    while W.Alive do
        task.wait(0.3)
        pcall(function()
            stLbl:SetText("Status: " .. stats.status ..
                "\nCasts: " .. stats.casts .. "   Fish: " .. stats.fish .. "   Failed: " .. stats.fail ..
                "\nFish in bag: " .. invCount() .. "   Sold: " .. stats.sold .. "x" ..
                "\nSell mode: " .. (sellMode or "unknown") ..
                "\nBait: " .. BUY.Bait.status .. "\nRod: " .. BUY.Rod.status)
        end)
    end
end)

W:OnUnload(function() run += 1 end)

-- Player and Home (+ Settings) live in ui.lua; each part is wrapped against errors.
for _, step in ipairs({
    function() W:BuildPlayer(PlayerPage) end,
    function() W:BuildHome({ Game = "Rod And Reef", Version = "v1.0" }, HomePage) end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[Sevoice] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()
W:OnBooted(function() N("Sevoice", "Rod And Reef loaded  ·  RCtrl to open/close", "#50C864", 4) end)
print("[Rod And Reef] Auto Fishing ready.")
