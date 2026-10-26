-- KatssinnnHub | Game 5 (Deagle Map)
-- Sidebar: Home / Main / Player / Settings (library: ui.lua)
-- Main: Aimbot + FOV, ESP (tim & musuh), Extras (Triggerbot, Hitbox)
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local UI = loadstring(game:HttpGet(BASE .. "ui.lua"))()

local W = UI:CreateWindow({
    Title     = "KatssinnnHub",
    Version   = "v1.0",
    Game      = "Deagle Map",
    Folder    = "KatssinnnHub/DeagleMap",
    ToggleKey = Enum.KeyCode.RightControl,
})

local function N(title, desc, color, dur)
    W:Notify({ Title = title, Desc = desc or "", Color = color or "#6495ED", Duration = dur or 3 })
end
local function OnOff(name, v)
    N(name, v and "ON" or "OFF", v and "#50C864" or "#DC3232")
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local function Cam() return workspace.CurrentCamera end

-- ===== HOST GUI (FOV circle + ESP) =====
local host
do
    local parent
    pcall(function() if gethui then parent = gethui() end end)
    if not parent then pcall(function() parent = game:GetService("CoreGui") end) end
    if not parent then parent = LP:WaitForChild("PlayerGui") end
    host = Instance.new("ScreenGui")
    host.Name = "KatsDeagleHost"
    host.ResetOnSpawn = false
    host.IgnoreGuiInset = true
    host.DisplayOrder = 5
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(host) end end)
    host.Parent = parent
end
local espFolder = Instance.new("Folder")
espFolder.Name = "ESP"
espFolder.Parent = host

-- ===== STATE =====
local AIM_ON, AIM_TEAMCHECK, AIM_WALL = false, true, true
local AIM_PART, AIM_PRIORITY, AIM_TRIGGER = "Head", "Closest to crosshair", "Always"
local AIM_SMOOTH, AIM_MAXDIST, AIM_PRED = 30, 1000, 0
local AimKey = Enum.KeyCode.Q

local FOV_SHOW, FOV_SIZE, FOV_CENTER = true, 150, "Screen center"
local FOV_COLOR = Color3.fromRGB(255, 255, 255)

local ESP_ON, ESP_ENEMY, ESP_TEAM = false, true, false
local ESP_CHAMS, ESP_NAME, ESP_HP, ESP_DIST, ESP_TRACER = true, true, true, true, false
local ESP_MAX = 1500
local COL_ENEMY, COL_TEAM = Color3.fromRGB(255, 50, 50), Color3.fromRGB(80, 200, 100)

local TRIG_ON, TRIG_DELAY = false, 0.1
local HB_ON, HB_SIZE = false, 6

-- ===== HELPERS =====
-- musuh = pemain lain; kalau kedua pihak punya Team, musuh = Team beda. (FFA: semua musuh)
local function IsEnemy(p)
    if p == LP then return false end
    if p.Team == nil or LP.Team == nil then return true end
    return p.Team ~= LP.Team
end

local function Alive(p)
    local c = p.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if h and r and h.Health > 0 then return c, h, r end
end

local function TorsoOf(c)
    return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
end

local function Center()
    local cam = Cam()
    local vp = cam and cam.ViewportSize or Vector2.new(800, 400)
    if FOV_CENTER == "Mouse" and UIS.MouseEnabled then
        local m = UIS:GetMouseLocation()
        return Vector2.new(m.X, m.Y)  -- GetMouseLocation sudah ikut inset; host IgnoreGuiInset=true
    end
    return vp / 2
end

local function Visible(from, part, ignore)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = ignore
    rp.IgnoreWater = true
    local res = workspace:Raycast(from, part.Position - from, rp)
    return res == nil
end

-- pilih bagian tubuh sesuai pengaturan
local function PickPart(c, cam, center)
    if AIM_PART == "Head" then return c:FindFirstChild("Head") or TorsoOf(c) end
    if AIM_PART == "Torso" then return TorsoOf(c) end
    -- Closest part: bagian yang paling dekat ke crosshair
    local best, bd
    for _, n in ipairs({ "Head", "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso" }) do
        local p = c:FindFirstChild(n)
        if p then
            local v, on = cam:WorldToViewportPoint(p.Position)
            if on then
                local d = (Vector2.new(v.X, v.Y) - center).Magnitude
                if not bd or d < bd then best, bd = p, d end
            end
        end
    end
    return best
end

-- ===== TARGET =====
local function GetTarget()
    local cam = Cam()
    if not cam then return end
    local center = Center()
    local myChar = LP.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local best, bestScore
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and (not AIM_TEAMCHECK or IsEnemy(p)) then
            local c, h, r = Alive(p)
            if c then
                local part = PickPart(c, cam, center)
                if part then
                    local v, on = cam:WorldToViewportPoint(part.Position)
                    if on then
                        local sd = (Vector2.new(v.X, v.Y) - center).Magnitude
                        local wd = (cam.CFrame.Position - part.Position).Magnitude
                        if sd <= FOV_SIZE and wd <= AIM_MAXDIST then
                            if not AIM_WALL or Visible(cam.CFrame.Position, part, { myChar, c }) then
                                local score
                                if AIM_PRIORITY == "Closest distance" then score = wd
                                elseif AIM_PRIORITY == "Lowest health" then score = h.Health
                                else score = sd end
                                if not bestScore or score < bestScore then
                                    best, bestScore = { part = part, root = r, char = c, player = p }, score
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- ===== FOV CIRCLE =====
local fovFrame = Instance.new("Frame")
fovFrame.Name = "FOV"
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.BackgroundTransparency = 1
fovFrame.BorderSizePixel = 0
fovFrame.Visible = false
fovFrame.Parent = host
Instance.new("UICorner", fovFrame).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke")
fovStroke.Thickness = 1.5
fovStroke.Color = FOV_COLOR
fovStroke.Parent = fovFrame

-- ===== TRIGGERBOT =====
local clicking = false
local function Click()
    if clicking then return end
    clicking = true
    task.spawn(function()
        if mouse1click then
            pcall(mouse1click)
        elseif VIM then
            local c = Center()
            pcall(function()
                VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0)
                task.wait(0.02)
                VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0)
            end)
        end
        task.wait(TRIG_DELAY)
        clicking = false
    end)
end

local function TriggerCheck()
    local cam = Cam()
    if not cam then return end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { LP.Character }
    rp.IgnoreWater = true
    local c = Center()
    local ray = cam:ViewportPointToRay(c.X, c.Y)
    local res = workspace:Raycast(ray.Origin, ray.Direction * 2000, rp)
    if not res then return end
    local model = res.Instance:FindFirstAncestorOfClass("Model")
    local p = model and Players:GetPlayerFromCharacter(model)
    if p and IsEnemy(p) and Alive(p) then Click() end
end

-- ===== ESP =====
local esp = {}
local hasDrawing = (typeof(Drawing) == "table" or typeof(Drawing) == "userdata") and Drawing.new ~= nil

local function DestroyESP(p)
    local e = esp[p]
    if not e then return end
    pcall(function() e.hl:Destroy() end)
    pcall(function() e.bb:Destroy() end)
    if e.line then pcall(function() e.line:Remove() end) end
    esp[p] = nil
end

local function BuildESP(p, c)
    DestroyESP(p)
    local e = { char = c }
    e.hl = Instance.new("Highlight")
    e.hl.Adornee = c
    e.hl.FillTransparency = 0.75
    e.hl.OutlineTransparency = 0
    e.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    e.hl.Parent = espFolder

    e.bb = Instance.new("BillboardGui")
    e.bb.Adornee = c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
    e.bb.AlwaysOnTop = true
    e.bb.Size = UDim2.fromOffset(200, 44)
    e.bb.StudsOffset = Vector3.new(0, 2.6, 0)
    e.bb.Parent = espFolder
    e.txt = Instance.new("TextLabel")
    e.txt.Size = UDim2.fromScale(1, 1)
    e.txt.BackgroundTransparency = 1
    e.txt.Font = Enum.Font.GothamBold
    e.txt.TextSize = 13
    e.txt.TextStrokeTransparency = 0.4
    e.txt.Text = ""
    e.txt.Parent = e.bb

    if hasDrawing then
        pcall(function()
            e.line = Drawing.new("Line")
            e.line.Thickness = 1.2
            e.line.Visible = false
        end)
    end
    esp[p] = e
    return e
end

local function HideESP(e)
    e.hl.Enabled = false
    e.bb.Enabled = false
    if e.line then e.line.Visible = false end
end

local function UpdateESP(p, myPos, cam)
    local e = esp[p]
    local c, h, r = Alive(p)
    local enemy = IsEnemy(p)
    local want = ESP_ON and c and ((enemy and ESP_ENEMY) or (not enemy and ESP_TEAM))
    if want and myPos then
        if (r.Position - myPos).Magnitude > ESP_MAX then want = false end
    end
    if not want then
        if e then HideESP(e) end
        return
    end
    if not e or e.char ~= c or not e.hl.Parent then e = BuildESP(p, c) end
    local col = enemy and COL_ENEMY or COL_TEAM
    e.hl.Enabled = ESP_CHAMS
    e.hl.FillColor, e.hl.OutlineColor = col, col
    local parts = {}
    if ESP_NAME then parts[#parts + 1] = p.DisplayName ~= p.Name and p.DisplayName or p.Name end
    local info = {}
    if ESP_HP then info[#info + 1] = math.floor(h.Health) .. " HP" end
    if ESP_DIST and myPos then info[#info + 1] = math.floor((r.Position - myPos).Magnitude) .. "m" end
    if #info > 0 then parts[#parts + 1] = table.concat(info, " | ") end
    e.bb.Enabled = #parts > 0
    e.txt.Text = table.concat(parts, "\n")
    e.txt.TextColor3 = col
    if e.line then
        if ESP_TRACER and cam then
            local v, on = cam:WorldToViewportPoint(r.Position)
            if on then
                local vp = cam.ViewportSize
                e.line.From = Vector2.new(vp.X / 2, vp.Y)
                e.line.To = Vector2.new(v.X, v.Y)
                e.line.Color = col
                e.line.Visible = true
            else
                e.line.Visible = false
            end
        else
            e.line.Visible = false
        end
    end
end

Players.PlayerRemoving:Connect(DestroyESP)

-- ===== HITBOX =====
local hbOrig = {}
local function HBRestore()
    for hrp, o in pairs(hbOrig) do
        pcall(function()
            hrp.Size = o.Size; hrp.Transparency = o.Transparency; hrp.CanCollide = o.CanCollide
        end)
    end
    hbOrig = {}
end
local function HBApply()
    local keep = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and IsEnemy(p) then
            local c, _, r = Alive(p)
            if c then
                keep[r] = true
                if not hbOrig[r] then hbOrig[r] = { Size = r.Size, Transparency = r.Transparency, CanCollide = r.CanCollide } end
                r.Size = Vector3.new(HB_SIZE, HB_SIZE, HB_SIZE)
                r.Transparency = 0.8
                r.CanCollide = false
            end
        end
    end
    for r, o in pairs(hbOrig) do
        if not keep[r] then
            pcall(function() r.Size = o.Size; r.Transparency = o.Transparency; r.CanCollide = o.CanCollide end)
            hbOrig[r] = nil
        end
    end
end

-- ===== MAIN LOOP =====
local alive = true
local espTimer, hbTimer = 0, 0
local STEP = "KatsDeagleAim"
RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not alive then return end
    local cam = Cam()
    if not cam then return end

    -- FOV circle
    local showFov = FOV_SHOW
    fovFrame.Visible = showFov
    if showFov then
        local c = Center()
        fovFrame.Position = UDim2.fromOffset(c.X, c.Y)
        fovFrame.Size = UDim2.fromOffset(FOV_SIZE * 2, FOV_SIZE * 2)
        fovStroke.Color = FOV_COLOR
    end

    -- Aimbot
    if AIM_ON then
        local active = true
        if AIM_TRIGGER == "Hold key" then
            active = UIS:IsKeyDown(AimKey) or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        end
        if active then
            local t = GetTarget()
            if t then
                local pos = t.part.Position
                if AIM_PRED > 0 then pos = pos + t.root.AssemblyLinearVelocity * AIM_PRED end
                local goal = CFrame.lookAt(cam.CFrame.Position, pos)
                local alpha = math.clamp(1 - AIM_SMOOTH / 100, 0.03, 1)
                alpha = 1 - (1 - alpha) ^ (math.clamp(dt, 0, 0.1) * 60)
                cam.CFrame = cam.CFrame:Lerp(goal, alpha)
            end
        end
    end

    -- ESP (tracer tiap frame, teks/warna ~7x per detik cukup, tapi disatukan agar simpel)
    espTimer += dt
    if ESP_ON or next(esp) then
        local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local myPos = myRoot and myRoot.Position or cam.CFrame.Position
        if ESP_TRACER or espTimer >= 0.12 then
            espTimer = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then pcall(UpdateESP, p, myPos, cam) end
            end
        end
    end

    -- Triggerbot
    if TRIG_ON and not clicking then pcall(TriggerCheck) end

    -- Hitbox
    if HB_ON then
        hbTimer += dt
        if hbTimer >= 0.3 then hbTimer = 0; pcall(HBApply) end
    end
end)

W:OnUnload(function()
    alive = false
    pcall(function() RunService:UnbindFromRenderStep(STEP) end)
    for p in pairs(esp) do DestroyESP(p) end
    HBRestore()
    pcall(function() host:Destroy() end)
end)

-- ===== UI =====
-- Home dibangun TERAKHIR supaya error di Home tidak menghentikan fitur Main.
local HomePage = W:AddPage({ Name = "Home", Icon = "house" })
local Main = W:AddPage({ Name = "Main", Icon = "crosshair" })
local PlayerPage = W:AddPage({ Name = "Player", Icon = "user" })

-- ---------- kolom 1: Aimbot ----------
local cAim = Main:AddCard({ Title = "Aimbot", Icon = "crosshair", Column = 1 })
cAim:Toggle({
    Title = "Aimbot", id = "aim_on",
    Callback = function(v) AIM_ON = v; OnOff("Aimbot", v) end,
})
cAim:Dropdown({
    Title = "Aim part", List = { "Head", "Torso", "Closest part" }, Value = "Head", id = "aim_part",
    Callback = function(v) if v then AIM_PART = tostring(v) end end,
})
cAim:Dropdown({
    Title = "Target priority", List = { "Closest to crosshair", "Closest distance", "Lowest health" },
    Value = "Closest to crosshair", id = "aim_priority",
    Callback = function(v) if v then AIM_PRIORITY = tostring(v) end end,
})
cAim:Dropdown({
    Title = "Aim trigger", List = { "Always", "Hold key" }, Value = "Always", id = "aim_trigger",
    Callback = function(v) if v then AIM_TRIGGER = tostring(v) end end,
})
cAim:Keybind({
    Title = "Aim key (mode Hold key / klik kanan)", Value = Enum.KeyCode.Q, id = "aim_key",
    Callback = function(k) if typeof(k) == "EnumItem" then AimKey = k end end,
})
cAim:Slider({
    Title = "Smoothness (0 = langsung kunci)", Min = 0, Max = 95, Value = 30, Rounding = 0, Suffix = "%", id = "aim_smooth",
    Callback = function(v) AIM_SMOOTH = v end,
})
cAim:Slider({
    Title = "Prediction (gerak target)", Min = 0, Max = 0.3, Value = 0, Rounding = 2, id = "aim_pred",
    Callback = function(v) AIM_PRED = v end,
})
cAim:Slider({
    Title = "Max distance", Min = 50, Max = 3000, Value = 1000, Rounding = 0, Suffix = " st", id = "aim_maxdist",
    Callback = function(v) AIM_MAXDIST = v end,
})
cAim:Toggle({
    Title = "Team check (abaikan teman)", Value = true, id = "aim_teamcheck",
    Callback = function(v) AIM_TEAMCHECK = v end,
})
cAim:Toggle({
    Title = "Wall check (hanya yang terlihat)", Value = true, id = "aim_wall",
    Callback = function(v) AIM_WALL = v end,
})

local cFov = Main:AddCard({ Title = "FOV", Icon = "scan", Column = 1 })
cFov:Toggle({
    Title = "Show FOV circle", Value = true, id = "fov_show",
    Callback = function(v) FOV_SHOW = v end,
})
cFov:Slider({
    Title = "FOV size", Min = 30, Max = 600, Value = 150, Rounding = 0, Suffix = " px", id = "fov_size",
    Callback = function(v) FOV_SIZE = v end,
})
cFov:Color({
    Title = "FOV color", Value = "#FFFFFF", id = "fov_color",
    Callback = function(c) if typeof(c) == "Color3" then FOV_COLOR = c end end,
})
cFov:Dropdown({
    Title = "FOV center", List = { "Screen center", "Mouse" }, Value = "Screen center", id = "fov_center",
    Callback = function(v) if v then FOV_CENTER = tostring(v) end end,
})

-- ---------- kolom 2: ESP + Extras ----------
local cEsp = Main:AddCard({ Title = "ESP", Icon = "eye", Column = 2 })
cEsp:Toggle({
    Title = "ESP", id = "esp_on",
    Callback = function(v)
        ESP_ON = v
        OnOff("ESP", v)
        if not v then for _, e in pairs(esp) do HideESP(e) end end
    end,
})
cEsp:Toggle({ Title = "Show enemy", Value = true, id = "esp_enemy", Callback = function(v) ESP_ENEMY = v end })
cEsp:Toggle({ Title = "Show team", id = "esp_team", Callback = function(v) ESP_TEAM = v end })
cEsp:Toggle({ Title = "Chams (highlight)", Value = true, id = "esp_chams", Callback = function(v) ESP_CHAMS = v end })
cEsp:Toggle({ Title = "Name", Value = true, id = "esp_name", Callback = function(v) ESP_NAME = v end })
cEsp:Toggle({ Title = "Health", Value = true, id = "esp_hp", Callback = function(v) ESP_HP = v end })
cEsp:Toggle({ Title = "Distance", Value = true, id = "esp_dist", Callback = function(v) ESP_DIST = v end })
local togTracer = cEsp:Toggle({
    Title = "Tracers", id = "esp_tracer",
    Callback = function(v)
        if v and not hasDrawing then N("Tracers", "Executor tidak mendukung Drawing API", "#FFA500") end
        ESP_TRACER = v
    end,
})
cEsp:Slider({
    Title = "ESP max distance", Min = 100, Max = 5000, Value = 1500, Rounding = 0, Suffix = " st", id = "esp_max",
    Callback = function(v) ESP_MAX = v end,
})
cEsp:Color({
    Title = "Enemy color", Value = "#FF3232", id = "esp_colenemy",
    Callback = function(c) if typeof(c) == "Color3" then COL_ENEMY = c end end,
})
cEsp:Color({
    Title = "Team color", Value = "#50C864", id = "esp_colteam",
    Callback = function(c) if typeof(c) == "Color3" then COL_TEAM = c end end,
})

local cExt = Main:AddCard({ Title = "Extras", Icon = "zap", Column = 2 })
cExt:Toggle({
    Title = "Triggerbot (tembak otomatis saat crosshair kena musuh)", id = "trig_on",
    Callback = function(v) TRIG_ON = v; OnOff("Triggerbot", v) end,
})
cExt:Slider({
    Title = "Trigger delay", Min = 0, Max = 0.5, Value = 0.1, Rounding = 2, Suffix = "s", id = "trig_delay",
    Callback = function(v) TRIG_DELAY = v end,
})
cExt:Toggle({
    Title = "Hitbox expander (musuh)", id = "hb_on",
    Callback = function(v)
        HB_ON = v
        if not v then HBRestore() end
        OnOff("Hitbox expander", v)
    end,
})
cExt:Slider({
    Title = "Hitbox size", Min = 2, Max = 25, Value = 6, Rounding = 0, id = "hb_size",
    Callback = function(v) HB_SIZE = v end,
})

-- isi menu Player (Movement / Fly / Client) ada di ui.lua -> W:BuildPlayer
local okPl, errPl = pcall(function() W:BuildPlayer(PlayerPage) end)
if not okPl then
    warn("[KatssinnnHub] Player error: " .. tostring(errPl))
    N("Player error", tostring(errPl), "#DC3232", 10)
end

local okHome, errHome = pcall(function()
    W:BuildHome({ Game = "Deagle Map", Version = "v1.0" }, HomePage)
end)
if not okHome then
    warn("[KatssinnnHub] Home error: " .. tostring(errHome))
    N("Home error", tostring(errHome), "#DC3232", 10)
end

W:SelectPage("Main")
W:Ready()      -- jalankan nilai awal + autoload config
W:OnBooted(function() N("KatssinnnHub", "Deagle Map dimuat  ·  RCtrl untuk buka/tutup", "#50C864", 4) end)
