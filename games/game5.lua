-- KatssinnnHub | Game 5 (Deagle Arena)
-- Aimbot (kekuatan bisa diatur), Triggerbot, ESP, Hitbox, FOV changer.
-- UI / library sama dengan game 3 (ui.lua).
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "Deagle Arena",
    Folder    = "KatssinnnHub/DeagleArena",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local LP         = Players.LocalPlayer
local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- ===== PENGATURAN =====
local S = {
    aim = false, strength = 40, fov = 150, showFov = true,
    part = "Head", mode = "Always", prio = "Closest to crosshair",
    predict = 0, sticky = false, team = true, wall = true, maxDist = 1500,
    trig = false, trigDelay = 0.08,
    esp = false, espName = true, espHealth = true, espDist = true, espTeam = false,
    hitbox = false, hitSize = 6,
    fovChange = false, fovValue = 90,
}
local PARTS = { "Head", "Body", "Closest part" }
local MODES = { "Always", "Hold Right Mouse", "Hold Left Mouse" }
local PRIOS = { "Closest to crosshair", "Closest distance", "Lowest health" }

-- ===== HELPER =====
local function Cam() return workspace.CurrentCamera end

local function Alive(p)
    local c = p.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if c and h and h.Health > 0 then return c, h end
end

local function Enemy(p)
    if p == LP then return false end
    if S.team and p.Team ~= nil and LP.Team ~= nil and p.Team == LP.Team then return false end
    return true
end

local function RayParams()
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { LP.Character }
    rp.IgnoreWater = true
    return rp
end

local function Visible(part, char)
    local cam = Cam()
    if not cam then return false end
    local origin = cam.CFrame.Position
    local hit = workspace:Raycast(origin, part.Position - origin, RayParams())
    return hit == nil or hit.Instance:IsDescendantOf(char)
end

local BODY = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }
local function PartFor(char, cam, center)
    if S.part == "Head" then return char:FindFirstChild("Head") end
    if S.part == "Body" then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    end
    local best, bd
    for _, n in ipairs(BODY) do
        local p = char:FindFirstChild(n)
        if p then
            local sp, on = cam:WorldToViewportPoint(p.Position)
            if on then
                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if not bd or d < bd then best, bd = p, d end
            end
        end
    end
    return best
end

-- ===== PILIH TARGET =====
local Current   -- { plr, part } target terkunci (untuk Sticky)
local function Evaluate(p, cam, center, myPos)
    if not Enemy(p) then return end
    local c, h = Alive(p)
    if not c then return end
    local part = PartFor(c, cam, center)
    if not part then return end
    local sp, on = cam:WorldToViewportPoint(part.Position)
    if not on then return end
    local sd = (Vector2.new(sp.X, sp.Y) - center).Magnitude
    local wd = (part.Position - myPos).Magnitude
    if wd > S.maxDist then return end
    if S.wall and not Visible(part, c) then return end
    return part, sd, wd, h.Health
end

local function Pick()
    local cam = Cam()
    if not cam then return end
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position or cam.CFrame.Position

    if S.sticky and Current and Current.plr.Parent then
        local part, sd = Evaluate(Current.plr, cam, center, myPos)
        if part and sd <= S.fov * 1.5 then Current.part = part return Current.plr, part end
    end

    local bestP, bestPart, bestScore
    for _, p in ipairs(Players:GetPlayers()) do
        local part, sd, wd, hp = Evaluate(p, cam, center, myPos)
        if part and sd <= S.fov then
            local score = (S.prio == "Closest distance" and wd) or (S.prio == "Lowest health" and hp) or sd
            if not bestScore or score < bestScore then bestP, bestPart, bestScore = p, part, score end
        end
    end
    if bestP then Current = { plr = bestP, part = bestPart } else Current = nil end
    return bestP, bestPart
end

-- ===== AIMBOT =====
local fovFrame = Instance.new("Frame")
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.Position = UDim2.fromScale(0.5, 0.5)
fovFrame.BackgroundTransparency = 1
fovFrame.Size = UDim2.fromOffset(300, 300)
fovFrame.Visible = false
local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = fovFrame
local fs = Instance.new("UIStroke"); fs.Thickness = 1.5; fs.Color = W.Accent; fs.Parent = fovFrame
fovFrame.Parent = W.Gui
W:_hook(function() fs.Color = W.Accent end)

local function Held()
    if S.mode == "Hold Right Mouse" then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
    if S.mode == "Hold Left Mouse" then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
    return true
end

local targetName = "-"
local lastT = os.clock()
local function AimStep()
    local now = os.clock()
    local dt = math.clamp(now - lastT, 0.001, 0.1)
    lastT = now
    fovFrame.Visible = S.aim and S.showFov
    fovFrame.Size = UDim2.fromOffset(S.fov * 2, S.fov * 2)
    if not S.aim or not Held() then targetName = "-"; Current = nil return end
    local cam = Cam()
    local p, part = Pick()
    if not (p and part and cam) then targetName = "-" return end
    targetName = p.DisplayName
    local pos = part.Position
    if S.predict > 0 then pos = pos + part.AssemblyLinearVelocity * S.predict end
    local goal = CFrame.lookAt(cam.CFrame.Position, pos)
    local s = S.strength / 100
    local alpha = (s >= 1) and 1 or (1 - math.exp(-dt * s * s * 45))      -- 100 = langsung kunci
    cam.CFrame = cam.CFrame:Lerp(goal, math.clamp(alpha, 0, 1))
end

local bound = false
pcall(function()
    RunService:BindToRenderStep("KatssinnnAim", Enum.RenderPriority.Camera.Value + 1, AimStep)   -- setelah kamera game
    bound = true
end)
if not bound then W.Conns[#W.Conns + 1] = RunService.RenderStepped:Connect(AimStep) end

-- ===== TRIGGERBOT =====
local lastShot = 0
local function Click()
    local cam = Cam()
    local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
    if typeof(mouse1click) == "function" then pcall(mouse1click) return end
    if VIM then
        pcall(function()
            VIM:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 0)
            VIM:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 0)
        end)
    end
end
W.Conns[#W.Conns + 1] = RunService.Heartbeat:Connect(function()
    if not S.trig or not W.Alive then return end
    if os.clock() - lastShot < S.trigDelay then return end
    local cam = Cam()
    if not cam then return end
    local vp = cam.ViewportSize
    local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
    local res = workspace:Raycast(ray.Origin, ray.Direction * S.maxDist, RayParams())
    if not res then return end
    local model = res.Instance:FindFirstAncestorOfClass("Model")
    local p = model and Players:GetPlayerFromCharacter(model)
    if p and Enemy(p) and Alive(p) then
        lastShot = os.clock()
        Click()
    end
end)

-- ===== ESP =====
local esp = {}   -- [Player] = { hl, bb, lbl, char }
local function EspRemove(p)
    local e = esp[p]
    if not e then return end
    pcall(function() e.hl:Destroy() end)
    pcall(function() e.bb:Destroy() end)
    esp[p] = nil
end

local function EspUpdate()
    local cam = Cam()
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local c, h = Alive(p)
            local show = S.esp and c ~= nil and (Enemy(p) or S.espTeam)
            local e = esp[p]
            if e and (not show or e.char ~= c) then EspRemove(p); e = nil end
            if show then
                if not e then
                    local hl = Instance.new("Highlight")
                    hl.Adornee = c
                    hl.FillTransparency = 0.6
                    hl.OutlineTransparency = 0
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = W.Gui
                    local bb = Instance.new("BillboardGui")
                    bb.Adornee = c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
                    bb.Size = UDim2.fromOffset(160, 34)
                    bb.StudsOffset = Vector3.new(0, 2.6, 0)
                    bb.AlwaysOnTop = true
                    bb.Parent = W.Gui
                    local lbl = Instance.new("TextLabel")
                    lbl.BackgroundTransparency = 1
                    lbl.Size = UDim2.fromScale(1, 1)
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 12
                    lbl.TextStrokeTransparency = 0.4
                    lbl.TextColor3 = Color3.new(1, 1, 1)
                    lbl.Text = ""
                    lbl.Parent = bb
                    e = { hl = hl, bb = bb, lbl = lbl, char = c }
                    esp[p] = e
                end
                local enemy = Enemy(p)
                local col = enemy and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(80, 220, 120)
                e.hl.FillColor = col
                e.hl.OutlineColor = col
                local parts = {}
                if S.espName then parts[#parts + 1] = p.DisplayName end
                if S.espHealth then parts[#parts + 1] = math.floor(h.Health) .. " HP" end
                if S.espDist and myRoot then
                    local hrp = c:FindFirstChild("HumanoidRootPart")
                    if hrp then parts[#parts + 1] = math.floor((hrp.Position - myRoot.Position).Magnitude) .. "m" end
                end
                e.lbl.Text = table.concat(parts, "  ·  ")
                e.lbl.TextColor3 = col
                e.bb.Enabled = #parts > 0
            end
        end
    end
    for p in pairs(esp) do
        if not p.Parent then EspRemove(p) end
    end
end

-- ===== HITBOX =====
local hitOrig = {}   -- [part] = { Size, Transparency, CanCollide }
local function HitboxRestore()
    for part, o in pairs(hitOrig) do
        pcall(function()
            part.Size = o.Size; part.Transparency = o.Transparency; part.CanCollide = o.CanCollide
        end)
    end
    hitOrig = {}
end
local function HitboxUpdate()
    if not S.hitbox then
        if next(hitOrig) then HitboxRestore() end
        return
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if Enemy(p) then
            local c = Alive(p)
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                if not hitOrig[hrp] then hitOrig[hrp] = { Size = hrp.Size, Transparency = hrp.Transparency, CanCollide = hrp.CanCollide } end
                pcall(function()
                    hrp.Size = Vector3.new(S.hitSize, S.hitSize, S.hitSize)
                    hrp.Transparency = 0.75
                    hrp.CanCollide = false
                end)
            end
        end
    end
end

-- ===== FOV CAMERA =====
local origFov
local function FovUpdate()
    local cam = Cam()
    if not cam then return end
    if S.fovChange then
        origFov = origFov or cam.FieldOfView
        cam.FieldOfView = S.fovValue
    elseif origFov then
        cam.FieldOfView = origFov
        origFov = nil
    end
end

task.spawn(function()
    while W.Alive do
        pcall(EspUpdate)
        pcall(HitboxUpdate)
        pcall(FovUpdate)
        task.wait(0.2)
    end
end)
W.Conns[#W.Conns + 1] = RunService.RenderStepped:Connect(function() if S.fovChange then pcall(FovUpdate) end end)

-- ===== UI =====
local HomePage = W:AddPage({ Name = "Home", Icon = "⌂" })
local Main = W:AddPage({ Name = "Main", Icon = "▣" })
local function OnOff(name, v) N(name, v and "ON" or "OFF", v and "#50C864" or "#DC3232") end

-- ---------- kolom 1 ----------
local cAim = Main:AddCard({ Title = "Aimbot", Icon = "◎", Column = 1 })
local tog_aim = cAim:Toggle({ Title = "Aimbot", id = "aim", Callback = function(v) S.aim = v; if not v then Current = nil end OnOff("Aimbot", v) end })
cAim:Slider({ Title = "Aim Strength", Min = 1, Max = 100, Value = 40, Suffix = "%", id = "aim_strength", Callback = function(v) S.strength = v end })
cAim:Slider({ Title = "FOV Radius", Min = 20, Max = 600, Value = 150, id = "aim_fov", Callback = function(v) S.fov = v end })
cAim:Toggle({ Title = "Show FOV Circle", Value = true, id = "aim_showfov", Callback = function(v) S.showFov = v end })
cAim:Dropdown({ Title = "Aim Part", List = PARTS, Value = "Head", id = "aim_part", Callback = function(v) S.part = v or "Head" end })
cAim:Dropdown({ Title = "Aim Mode", List = MODES, Value = "Always", id = "aim_mode", Callback = function(v) S.mode = v or "Always" end })
cAim:Dropdown({ Title = "Target Priority", List = PRIOS, Value = "Closest to crosshair", id = "aim_prio", Callback = function(v) S.prio = v or PRIOS[1] end })
cAim:Slider({ Title = "Prediction", Min = 0, Max = 0.3, Value = 0, Rounding = 2, id = "aim_predict", Callback = function(v) S.predict = v end })
cAim:Toggle({ Title = "Sticky Target", id = "aim_sticky", Callback = function(v) S.sticky = v; Current = nil end })
cAim:Keybind({ Title = "Aimbot Key", Value = Enum.KeyCode.Unknown, id = "aim_key", Callback = function() tog_aim:Set(not tog_aim:Get()) end })

local cChk = Main:AddCard({ Title = "Checks", Icon = "✓", Column = 1 })
cChk:Toggle({ Title = "Team Check", Value = true, id = "chk_team", Callback = function(v) S.team = v end })
cChk:Toggle({ Title = "Wall Check (Visible only)", Value = true, id = "chk_wall", Callback = function(v) S.wall = v end })
cChk:Slider({ Title = "Max Distance", Min = 50, Max = 3000, Value = 1500, id = "chk_dist", Callback = function(v) S.maxDist = v end })

-- ---------- kolom 2 ----------
local cTrig = Main:AddCard({ Title = "Triggerbot", Icon = "✦", Column = 2 })
cTrig:Toggle({ Title = "Triggerbot", id = "trig", Callback = function(v) S.trig = v; OnOff("Triggerbot", v) end })
cTrig:Slider({ Title = "Shoot Delay (s)", Min = 0, Max = 0.5, Value = 0.08, Rounding = 2, id = "trig_delay", Callback = function(v) S.trigDelay = v end })

local cEsp = Main:AddCard({ Title = "ESP", Icon = "◉", Column = 2 })
cEsp:Toggle({ Title = "ESP (Highlight)", id = "esp", Callback = function(v) S.esp = v; OnOff("ESP", v) end })
cEsp:Toggle({ Title = "Names", Value = true, id = "esp_name", Callback = function(v) S.espName = v end })
cEsp:Toggle({ Title = "Health", Value = true, id = "esp_health", Callback = function(v) S.espHealth = v end })
cEsp:Toggle({ Title = "Distance", Value = true, id = "esp_dist", Callback = function(v) S.espDist = v end })
cEsp:Toggle({ Title = "Show Teammates", id = "esp_team", Callback = function(v) S.espTeam = v end })

local cHit = Main:AddCard({ Title = "Hitbox", Icon = "▣", Column = 2 })
cHit:Toggle({ Title = "Hitbox Expander", id = "hitbox", Callback = function(v) S.hitbox = v; OnOff("Hitbox Expander", v) end })
cHit:Slider({ Title = "Hitbox Size", Min = 2, Max = 25, Value = 6, id = "hitbox_size", Callback = function(v) S.hitSize = v end })

local cCam = Main:AddCard({ Title = "Camera", Icon = "◔", Column = 2 })
cCam:Toggle({ Title = "FOV Changer", id = "fovchg", Callback = function(v) S.fovChange = v end })
cCam:Slider({ Title = "Field of View", Min = 40, Max = 120, Value = 90, id = "fovval", Callback = function(v) S.fovValue = v end })

local cStat = Main:AddCard({ Title = "Status", Icon = "◔", Column = 2 })
local stLbl = cStat:Label({ Text = "-" })
task.spawn(function()
    while W.Alive do
        task.wait(0.5)
        pcall(function() stLbl:SetText("Target: " .. targetName .. "\nAimbot: " .. (S.aim and "ON" or "OFF") .. "   Strength: " .. S.strength .. "%") end)
    end
end)

-- bersihkan semua saat Unload
W:OnUnload(function()
    pcall(function() RunService:UnbindFromRenderStep("KatssinnnAim") end)
    for p in pairs(esp) do EspRemove(p) end
    HitboxRestore()
    S.fovChange = false; pcall(FovUpdate)
    pcall(function() fovFrame:Destroy() end)
end)

-- Home / Player / Settings (library): tiap bagian aman dari error
for _, step in ipairs({
    function() W:BuildHome({ Game = "Deagle Arena", Version = "v1.0" }, HomePage) end,
    function() W:BuildPlayer() end,
    function() W:BuildSettings() end,
}) do
    local ok, err = pcall(step)
    if not ok then
        warn("[KatssinnnHub] UI error: " .. tostring(err))
        N("UI error", tostring(err), "#DC3232", 10)
    end
end

W:SelectPage("Main")
W:Ready()
N("KatssinnnHub", "Deagle Arena dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4)
