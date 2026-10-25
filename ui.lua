-- KatssinnnUI v2 | sidebar + header search + Settings + Dynamic Island, responsif semua perangkat.
-- Pemakaian: local UI = loadstring(game:HttpGet(".../ui.lua"))()
-- API tetap sama: CreateWindow / AddPage / AddCard / Toggle / Slider / Dropdown / Button(s) / Label / Input / Keybind / BuildHome / Ready

local Players       = game:GetService("Players")
local UIS           = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local HttpService   = game:GetService("HttpService")
local Stats         = game:GetService("Stats")
local LP            = Players.LocalPlayer

local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"
local LOGO = "rbxassetid://88144642735093"

local Lib, Window = {}, {}
Window.__index = Window

local F, FB, FM = Enum.Font.Gotham, Enum.Font.GothamBold, Enum.Font.GothamMedium

local function C(h)
    local ok, r = pcall(Color3.fromHex, h)
    return ok and r or Color3.new(1, 1, 1)
end
local function has(f) return typeof(f) == "function" end

-- ===== tema =====
local THEMES = {
    Lime     = { Accent = "#B7F34A", Background = "#131313", Surface = "#1B1B1B", Text = "#F3F3EE", Muted = "#8B8B85" },
    Midnight = { Accent = "#80A0F6", Background = "#0F121A", Surface = "#161A25", Text = "#E4E8F2", Muted = "#7F899D" },
    Pink     = { Accent = "#FF007F", Background = "#0B0B0B", Surface = "#141414", Text = "#EBEBEB", Muted = "#949494" },
    Purple   = { Accent = "#9955FF", Background = "#110E18", Surface = "#181423", Text = "#EDE8F7", Muted = "#8E86A3" },
    Red      = { Accent = "#E5484D", Background = "#120D0D", Surface = "#1B1414", Text = "#F3EDED", Muted = "#9A8888" },
    Cyan     = { Accent = "#22D3EE", Background = "#0B1114", Surface = "#121A1F", Text = "#E8F3F6", Muted = "#7F969E" },
}
local THEME_LIST = { "Lime", "Midnight", "Pink", "Purple", "Red", "Cyan" }
local PRESETS = {}
for k, v in pairs(THEMES) do PRESETS[k] = v.Accent end

local Th, Cur = {}, {}
local function setPalette(p)
    for k, v in pairs(p) do Cur[k] = (typeof(v) == "string") and C(v) or v end
    local W3, B3 = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
    local bg, sf = Cur.Background, Cur.Surface
    Th.Accent = Cur.Accent; Th.BG = bg; Th.Side = bg:Lerp(B3, 0.3)
    Th.Card = sf; Th.CardHd = sf:Lerp(W3, 0.05); Th.Row = sf:Lerp(W3, 0.08); Th.RowHi = sf:Lerp(W3, 0.15)
    Th.Field = bg:Lerp(B3, 0.3); Th.Stroke = sf:Lerp(W3, 0.1); Th.Off = sf:Lerp(W3, 0.2)
    Th.Knob = Cur.Muted; Th.Text = Cur.Text; Th.Muted = Cur.Muted; Th.OnKnob = bg
    Th.Danger = C("#E5484D"); Th.Good = C("#50C864")
end
setPalette(THEMES.Lime)

local Bind, Corners, DensLists = {}, {}, {}
local cornerMul = 1

-- ===== glass (transparan menyeluruh) =====
-- Transparansi efektif = hasil kali transparansi semua layer yang bertumpuk,
-- jadi layer di atas window dibuat lebih "tipis" supaya semuanya ikut tembus pandang.
local Surf, GlassOn, GlassT = {}, false, 0.22
local GLASSKEY = { BG = true, Side = true, Card = true, CardHd = true, Row = true, RowHi = true, Field = true, Pop = true, Toast = true }
local function glassTr(key)
    if key == "BG" then return GlassT end
    if key == "Side" or key == "Card" then return 0.62 end
    if key == "CardHd" then return 0.8 end
    if key == "Row" or key == "RowHi" then return 0.5 end
    if key == "Field" then return 0.6 end
    if key == "Pop" then return 0.5 end
    if key == "Toast" then return 0.55 end
    return 0
end
local function applyGlassTo(e)
    local base = e[2]
    e[1].BackgroundTransparency = GlassOn and (base + (1 - base) * glassTr(e[3])) or base
end
local function reglass()
    for i = #Surf, 1, -1 do
        local e = Surf[i]
        if e[1].Parent == nil then table.remove(Surf, i) else applyGlassTo(e) end
    end
end
local function regGlass(o, key)
    local e = { o, o.BackgroundTransparency, key }
    Surf[#Surf + 1] = e
    if GlassOn then applyGlassTo(e) end
end

local function bind(o, prop, key)
    Bind[#Bind + 1] = { o, prop, key }
    o[prop] = Th[key]
end
local function reapply()
    for i = #Bind, 1, -1 do
        local b = Bind[i]
        if b[1].Parent == nil then table.remove(Bind, i) else pcall(function() b[1][b[2]] = Th[b[3]] end) end
    end
end

local function mk(class, props)
    local o = Instance.new(class)
    local parent, gkey
    props = props or {}
    for k, v in pairs(props) do
        if k == "Parent" then parent = v
        elseif k == "Glass" then gkey = v
        elseif type(v) == "string" and Th[v] and (k == "Color" or k:sub(-6) == "Color3") then bind(o, k, v)
        else o[k] = v end
    end
    if gkey ~= false and o:IsA("GuiObject") and o.BackgroundTransparency < 1 then
        local key = (type(gkey) == "string") and gkey or props.BackgroundColor3
        if type(key) == "string" and GLASSKEY[key] then regGlass(o, key) end
    end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, r, fixed)
    local c = mk("UICorner", { Parent = o })
    if fixed then c.CornerRadius = UDim.new(0, r)
    else
        c.CornerRadius = UDim.new(0, math.floor(r * cornerMul + 0.5))
        Corners[#Corners + 1] = { c, r }
    end
    return c
end
local function round(o) return mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = o }) end
local function setCornerMul(m)
    cornerMul = m
    for i = #Corners, 1, -1 do
        local c = Corners[i]
        if c[1].Parent then c[1].CornerRadius = UDim.new(0, math.floor(c[2] * m + 0.5)) else table.remove(Corners, i) end
    end
end
local function stroke(o, col, th)
    return mk("UIStroke", { Color = col or "Stroke", Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o })
end
local function pad(o, l, t, r, b)
    return mk("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l), PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l), Parent = o })
end
local function list(o, gap, dir)
    return mk("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = dir or Enum.FillDirection.Vertical, Parent = o })
end
local function dlist(o, gap)
    local l = list(o, gap)
    DensLists[#DensLists + 1] = { l, gap }
    return l
end

local function colArg(c, default)
    if c == nil then return default end
    if type(c) == "string" then
        if Th[c] then return c end
        return C(c)
    end
    return c
end
local function label(parent, text, size, col, font, xa)
    return mk("TextLabel", {
        BackgroundTransparency = 1, Text = tostring(text), TextSize = size or 12, TextColor3 = colArg(col, "Text"),
        Font = font or FM, TextXAlignment = xa or Enum.TextXAlignment.Left, Parent = parent,
    })
end
local function tw(o, t, props)
    local ok = pcall(function()
        TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
    end)
    if not ok then for k, v in pairs(props) do pcall(function() o[k] = v end) end end
end

-- ===== icon (lucide, fallback teks) =====
local Lucide = {}
pcall(function()
    local r = loadstring(game:HttpGet(BASE .. "lucide.lua"))()
    if type(r) == "table" then Lucide = r end
end)
if next(Lucide) == nil then
    pcall(function()
        local r = loadstring(game:HttpGet("https://raw.githubusercontent.com/ArchIsDead/vita-ui-modified/refs/heads/main/lucide.lua"))()
        if type(r) == "table" then Lucide = r end
    end)
end
local LEGACY = {
    ["⌂"] = "house", ["▣"] = "gamepad-2", ["★"] = "star", ["◔"] = "gauge", ["▶"] = "play", ["▭"] = "monitor",
    ["▤"] = "folder", ["◐"] = "palette", ["◆"] = "pickaxe", ["▲"] = "arrow-up", ["$"] = "coins", ["●"] = "lock-open",
    ["◇"] = "gift", ["◉"] = "sliders-horizontal", ["•"] = "circle", ["home"] = "house",
}
local function resolveIcon(name)
    if type(name) ~= "string" then return nil end
    name = LEGACY[name] or name
    if name:find("^rbxassetid://") then return name end
    return Lucide[name]
end
local function icon(parent, name, size, col)
    local id = resolveIcon(name)
    if id then
        return mk("ImageLabel", { BackgroundTransparency = 1, Image = id, Size = UDim2.fromOffset(size, size), ImageColor3 = colArg(col, "Muted"), Parent = parent })
    end
    return mk("TextLabel", {
        BackgroundTransparency = 1, Text = (type(name) == "string" and #name <= 3) and name or "•", TextSize = size, Font = FB,
        TextColor3 = colArg(col, "Muted"), Size = UDim2.fromOffset(size, size), Parent = parent,
    })
end
local function setIc(o, c) pcall(function() o[o:IsA("ImageLabel") and "ImageColor3" or "TextColor3"] = c end) end

-- ===== base64 (share code) =====
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64e(data)
    return ((data:gsub(".", function(x)
        local r, b = "", x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
        return r
    end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
        if #x < 6 then return "" end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
        return B64:sub(c + 1, c + 1)
    end) .. ({ "", "==", "=" })[#data % 3 + 1])
end
local function b64d(data)
    data = data:gsub("[^" .. B64 .. "=]", "")
    return (data:gsub(".", function(x)
        if x == "=" then return "" end
        local r, f = "", (B64:find(x, 1, true) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
        return r
    end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
        if #x ~= 8 then return "" end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
end

local function keyShort(n)
    n = tostring(n)
    return (n:gsub("RightControl", "RCtrl"):gsub("LeftControl", "LCtrl"):gsub("RightShift", "RShift"):gsub("LeftShift", "LShift"):gsub("RightAlt", "RAlt"):gsub("LeftAlt", "LAlt"))
end

local function viewport()
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1280, 720)
end
local function isTouch() return UIS.TouchEnabled end
local function isPointer(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function isMove(i)
    return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

-- ===== Window =====
function Lib:CreateWindow(opts)
    opts = opts or {}
    Bind, Corners, DensLists = {}, {}, {}
    Surf, GlassOn, GlassT = {}, false, 0.22
    cornerMul = 1
    setPalette(THEMES[opts.Theme] or THEMES.Lime)
    if opts.Accent then setPalette({ Accent = opts.Accent }) end

    local W = setmetatable({}, Window)
    W.Opts = opts
    W.Elements, W.Pages, W.PageList, W.OnUnloads, W.Pending, W.hooks, W.Conns = {}, {}, {}, {}, {}, {}, {}
    W.ToggleKey  = opts.ToggleKey or Enum.KeyCode.RightControl
    W.UIScaleMul = 1
    W.Folder     = opts.Folder or "KatssinnnHub"
    W.Mem        = {}
    W.Alive      = true
    W.Adaptive   = true
    W.DragOutline = false
    W.ToggleMode = "Always"
    W.IslandMode = "Always"
    W.Notifs     = 0
    W.Accent     = Th.Accent
    W.Single     = false
    W.W, W.H     = 680, 380
    W.Themes     = {}
    W.DefaultTheme = nil

    local parent
    pcall(function() if gethui then parent = gethui() end end)
    if not parent then
        pcall(function()
            local t = Instance.new("Folder")
            t.Parent = game:GetService("CoreGui")
            t:Destroy()
            parent = game:GetService("CoreGui")
        end)
    end
    parent = parent or LP:WaitForChild("PlayerGui")
    local old = parent:FindFirstChild("KatssinnnUI")
    if old then old:Destroy() end

    local gui = mk("ScreenGui", {
        Name = "KatssinnnUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parent,
    })
    W.Gui = gui

    function W:_hook(fn) self.hooks[#self.hooks + 1] = fn end
    function W:ApplyTheme()
        reapply()
        self.Accent = Th.Accent
        for _, h in ipairs(self.hooks) do pcall(h) end
    end
    function W:SetPalette(p) setPalette(p); self:ApplyTheme() end
    function W:SetAccent(col)
        if typeof(col) == "string" then col = C(PRESETS[col] or col) end
        setPalette({ Accent = col }); self:ApplyTheme()
    end
    function W:GetPalette()
        local o = {}
        for _, k in ipairs({ "Accent", "Background", "Surface", "Text", "Muted" }) do o[k] = "#" .. Cur[k]:ToHex() end
        return o
    end

    -- dim (gelapkan game di belakang window)
    local dim = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, Visible = false, ZIndex = 0, Parent = gui })
    W.DimOn = false

    -- window
    local frame = mk("Frame", {
        Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(680, 380), BackgroundColor3 = "BG", BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2, Parent = gui,
    })
    corner(frame, 12); stroke(frame, "Stroke", 1)
    W.Frame = frame
    local uiscale = mk("UIScale", { Parent = frame })
    W.UIScale = uiscale

    local bgImg = mk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ImageTransparency = 1, ScaleType = Enum.ScaleType.Crop, Visible = false, ZIndex = 0, Parent = frame })

    -- ghost (drag style: outline)
    local ghost = mk("Frame", { BackgroundTransparency = 1, Visible = false, ZIndex = 80, Parent = gui })
    corner(ghost, 12, true); stroke(ghost, "Accent", 2)

    -- ===== sidebar =====
    local side = mk("Frame", { Name = "Side", Size = UDim2.new(0, 168, 1, 0), BackgroundColor3 = "Side", BorderSizePixel = 0, Parent = frame })
    corner(side, 12)
    -- penutup sudut kanan sidebar (hanya sudut, supaya tidak menumpuk saat mode transparan)
    local covTop = mk("Frame", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -26, 0, 0), BackgroundColor3 = "Side", BorderSizePixel = 0, Glass = false, Parent = side })
    local covBot = mk("Frame", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -26, 1, -26), BackgroundColor3 = "Side", BorderSizePixel = 0, Glass = false, Parent = side })

    local brand = mk("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, Parent = side })
    local logo = mk("ImageLabel", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(13, 16), BackgroundTransparency = 1, Image = LOGO, ScaleType = Enum.ScaleType.Fit, Parent = brand })
    local bt = label(brand, opts.Title or "KatssinnnHub", 13, "Text", FB)
    bt.Position = UDim2.fromOffset(52, 15); bt.Size = UDim2.new(1, -58, 0, 16); bt.TextTruncate = Enum.TextTruncate.AtEnd
    local bv = label(brand, opts.Version or "v1.0", 10, "Muted", F)
    bv.Position = UDim2.fromOffset(52, 32); bv.Size = UDim2.new(1, -58, 0, 12)

    local nav = mk("Frame", { Name = "Nav", Position = UDim2.fromOffset(8, 66), Size = UDim2.new(1, -16, 1, -140), BackgroundTransparency = 1, Parent = side })
    list(nav, 4)

    local foot = mk("TextButton", { Size = UDim2.new(1, -16, 0, 52), Position = UDim2.new(0, 8, 1, -60), BackgroundColor3 = "Card", BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = side })
    corner(foot, 9); stroke(foot, "Stroke", 1)
    local av = mk("ImageLabel", {
        Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(6, 10), BackgroundColor3 = "Row", BorderSizePixel = 0,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. LP.UserId .. "&w=150&h=150", Parent = foot,
    })
    round(av)
    local avHide = label(foot, "?", 14, "Muted", FB, Enum.TextXAlignment.Center)
    avHide.Position = av.Position; avHide.Size = av.Size; avHide.BackgroundColor3 = Th.Row; avHide.BackgroundTransparency = 0; avHide.Visible = false
    round(avHide)
    local fn = label(foot, LP.DisplayName, 11, "Text", FB)
    fn.Position = UDim2.fromOffset(46, 10); fn.Size = UDim2.new(1, -72, 0, 14); fn.TextTruncate = Enum.TextTruncate.AtEnd
    local fg = label(foot, opts.Game or "", 10, "Muted", F)
    fg.Position = UDim2.fromOffset(46, 26); fg.Size = UDim2.new(1, -72, 0, 12); fg.TextTruncate = Enum.TextTruncate.AtEnd
    local fchev = icon(foot, "chevron-right", 14, "Muted")
    fchev.AnchorPoint = Vector2.new(1, 0.5); fchev.Position = UDim2.new(1, -8, 0.5, 0)
    W.FooterGame, W.FooterName, W.FooterAvatar, W.FooterAvatarHide = fg, fn, av, avHide

    -- ===== konten =====
    local content = mk("Frame", { Name = "Content", Position = UDim2.fromOffset(168, 0), Size = UDim2.new(1, -168, 1, 0), BackgroundTransparency = 1, Parent = frame })
    local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = content })
    W.HeaderIconHolder = mk("Frame", { Position = UDim2.fromOffset(16, 15), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Parent = header })
    W.HeaderTitle = label(header, "", 17, "Text", FM)
    W.HeaderTitle.Position = UDim2.fromOffset(46, 0); W.HeaderTitle.Size = UDim2.new(0.4, 0, 1, 0); W.HeaderTitle.TextTruncate = Enum.TextTruncate.AtEnd

    local minBtn = mk("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Text = "", Parent = header })
    local minIc = icon(minBtn, "minimize-2", 18, "Muted")
    minIc.AnchorPoint = Vector2.new(0.5, 0.5); minIc.Position = UDim2.fromScale(0.5, 0.5)
    local searchF = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, 0), Size = UDim2.fromOffset(160, 30),
        BackgroundColor3 = "Card", BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = header,
    })
    corner(searchF, 8); stroke(searchF, "Stroke", 1)
    local sIc = icon(searchF, "search", 15, "Muted")
    sIc.AnchorPoint = Vector2.new(0, 0.5); sIc.Position = UDim2.new(0, 10, 0.5, 0)
    local sLbl = label(searchF, "Search", 12, "Muted", FM)
    sLbl.Position = UDim2.fromOffset(32, 0); sLbl.Size = UDim2.new(1, -36, 1, 0)

    local holder = mk("Frame", { Name = "Pages", Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1, ClipsDescendants = true, Parent = content })
    W.Holder = holder

    -- ===== drag window =====
    local function dragWin(handle)
        local dragging, startIn, startC, fs
        handle.InputBegan:Connect(function(i)
            if not isPointer(i) then return end
            dragging = true
            startIn = Vector2.new(i.Position.X, i.Position.Y)
            fs = frame.AbsoluteSize
            startC = frame.AbsolutePosition + fs / 2
            if W.DragOutline then
                ghost.Position = UDim2.fromOffset(frame.AbsolutePosition.X, frame.AbsolutePosition.Y)
                ghost.Size = UDim2.fromOffset(fs.X, fs.Y); ghost.Visible = true
            end
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if ghost.Visible then
                        ghost.Visible = false
                        local vp = gui.AbsoluteSize
                        local c = Vector2.new(ghost.AbsolutePosition.X + fs.X / 2, ghost.AbsolutePosition.Y + fs.Y / 2)
                        frame.Position = UDim2.fromScale(c.X / vp.X, c.Y / vp.Y)
                    end
                end
            end)
        end)
        UIS.InputChanged:Connect(function(i)
            if not dragging or not isMove(i) then return end
            W.Moved = true
            local vp = gui.AbsoluteSize
            local c = startC + (Vector2.new(i.Position.X, i.Position.Y) - startIn)
            c = Vector2.new(math.clamp(c.X, fs.X / 2 - fs.X * 0.6, vp.X - fs.X / 2 + fs.X * 0.6), math.clamp(c.Y, fs.Y / 2, vp.Y - 30))
            if ghost.Visible then
                ghost.Position = UDim2.fromOffset(c.X - fs.X / 2, c.Y - fs.Y / 2)
            else
                frame.Position = UDim2.fromScale(c.X / vp.X, c.Y / vp.Y)
            end
        end)
    end
    dragWin(header); dragWin(brand)

    -- ===== tombol melayang =====
    local fbtn = mk("TextButton", {
        Name = "Toggle", Position = UDim2.new(0, 14, 0.5, -22), Size = UDim2.fromOffset(46, 46),
        BackgroundColor3 = "Side", Text = "", AutoButtonColor = false, ZIndex = 60, Parent = gui,
    })
    corner(fbtn, 11, true); stroke(fbtn, "Stroke", 1)
    local fImg = mk("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Parent = fbtn })
    local moved = 0
    do
        local dragging, startIn, startPos
        fbtn.InputBegan:Connect(function(i)
            if not isPointer(i) then return end
            moved = 0; dragging = true; startIn = Vector2.new(i.Position.X, i.Position.Y); startPos = fbtn.AbsolutePosition
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end)
        UIS.InputChanged:Connect(function(i)
            if dragging and isMove(i) then
                local d = Vector2.new(i.Position.X, i.Position.Y) - startIn
                moved = math.max(moved, d.Magnitude)
                if moved > 6 then
                    local vp = gui.AbsoluteSize
                    local p = startPos + d
                    fbtn.Position = UDim2.fromOffset(math.clamp(p.X, 0, vp.X - 46), math.clamp(p.Y, 0, vp.Y - 46))
                end
            end
        end)
    end

    -- ===== dynamic island =====
    local island = mk("TextButton", {
        Name = "Island", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(160, 34),
        BackgroundColor3 = Color3.fromRGB(8, 8, 8), Text = "", AutoButtonColor = false, ClipsDescendants = true, ZIndex = 60, Parent = gui,
    })
    round(island); stroke(island, "Stroke", 1)
    local iLogo = mk("ImageLabel", { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(5, 5), BackgroundTransparency = 1, Image = LOGO, ScaleType = Enum.ScaleType.Fit, Parent = island })
    local iTitle = label(island, opts.Title or "KatssinnnHub", 12, "Text", FB)
    iTitle.Position = UDim2.fromOffset(36, 0); iTitle.Size = UDim2.new(1, -78, 1, 0); iTitle.TextTruncate = Enum.TextTruncate.AtEnd; iTitle.RichText = false
    local iCount = label(island, "0", 12, "Muted", FB, Enum.TextXAlignment.Right)
    iCount.AnchorPoint = Vector2.new(1, 0); iCount.Position = UDim2.new(1, -12, 0, 0); iCount.Size = UDim2.new(0, 30, 1, 0)
    local iDot = mk("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, 0), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = "Accent", BorderSizePixel = 0, Parent = island })
    round(iDot)
    local hover, notifToken, notifOn = false, 0, false
    local musicOn, musicSnd = false, nil

    -- gelombang musik (ala dynamic island iPhone)
    local wave = mk("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(27, 20), BackgroundTransparency = 1, Visible = false, Parent = island })
    local bars = {}
    for i = 1, 5 do
        bars[i] = mk("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, (i - 1) * 6, 0.5, 0), Size = UDim2.fromOffset(3, 4), BackgroundColor3 = "Accent", BorderSizePixel = 0, Parent = wave })
        round(bars[i])
    end

    function W:_island()
        local vp = gui.AbsoluteSize
        island.Visible = (self.IslandMode ~= "Hidden")
        local size
        if notifOn then size = UDim2.fromOffset(math.min(300, vp.X * 0.8), 34)
        elseif musicOn then size = UDim2.fromOffset(math.min(200, vp.X * 0.8), 34)
        elseif self.IslandMode == "Always" or hover then size = UDim2.fromOffset(160, 34)
        else size = UDim2.fromOffset(38, 34) end
        tw(island, 0.22, { Size = size })
        iCount.Text = tostring(self.Notifs)
        iCount.Visible = not musicOn
        iDot.Visible = not musicOn
        wave.Visible = musicOn
        iTitle.Size = UDim2.new(1, musicOn and -90 or -78, 1, 0)
    end
    island.MouseEnter:Connect(function() hover = true; W:_island() end)
    island.MouseLeave:Connect(function() hover = false; W:_island() end)

    -- drag island
    local imoved = 0
    do
        local dragging, startIn, startC
        island.InputBegan:Connect(function(i)
            if not isPointer(i) then return end
            imoved = 0; dragging = true
            startIn = Vector2.new(i.Position.X, i.Position.Y)
            startC = Vector2.new(island.AbsolutePosition.X + island.AbsoluteSize.X / 2, island.AbsolutePosition.Y)
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end)
        W.Conns[#W.Conns + 1] = UIS.InputChanged:Connect(function(i)
            if not dragging or not isMove(i) then return end
            local d = Vector2.new(i.Position.X, i.Position.Y) - startIn
            imoved = math.max(imoved, d.Magnitude)
            if imoved > 6 then
                local vp = gui.AbsoluteSize
                local half = math.min(island.AbsoluteSize.X / 2, vp.X / 2)
                local p = startC + d
                island.Position = UDim2.new(math.clamp(p.X, half, vp.X - half) / vp.X, 0, 0, math.clamp(p.Y, 0, vp.Y - 40))
            end
        end)
    end

    -- deteksi musik: Sound panjang/looping yang sedang diputar di game
    do
        local SoundService = game:GetService("SoundService")
        local sounds = setmetatable({}, { __mode = "k" })
        local function consider(d) if d:IsA("Sound") then sounds[d] = true end end
        local function scan(root)
            if not root then return end
            task.spawn(function()
                local n = 0
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA("Sound") then sounds[d] = true end
                    n += 1
                    if n % 1500 == 0 then task.wait() end
                end
            end)
        end
        pcall(function()
            scan(SoundService); scan(workspace); scan(LP:FindFirstChildOfClass("PlayerGui"))
            W.Conns[#W.Conns + 1] = SoundService.DescendantAdded:Connect(consider)
            W.Conns[#W.Conns + 1] = workspace.DescendantAdded:Connect(consider)
        end)
        task.spawn(function()
            while W.Alive do
                task.wait(0.5)
                local best, bl = nil, -1
                for snd in pairs(sounds) do
                    if snd.Parent == nil then sounds[snd] = nil
                    else
                        local ok, playing = pcall(function()
                            return snd.IsPlaying and snd.Volume > 0.02 and (snd.Looped or snd.TimeLength > 20)
                        end)
                        if ok and playing then
                            local l = 0
                            pcall(function() l = snd.PlaybackLoudness end)
                            if l > bl then best, bl = snd, l end
                        end
                    end
                end
                musicSnd = best
            end
        end)
        local wt2, lvl = 0, 0
        W.Conns[#W.Conns + 1] = RunService.Heartbeat:Connect(function(dt)
            local active = (musicSnd ~= nil and musicSnd.Parent ~= nil) or (W.NowPlaying ~= nil)
            if active ~= musicOn then musicOn = active; W:_island() end
            if not musicOn or not island.Visible then return end
            wt2 += dt
            local raw = 0
            if musicSnd then pcall(function() raw = musicSnd.PlaybackLoudness end) end
            local target = (raw >= 1) and math.clamp(raw / 350, 0, 1) ^ 0.6 or 0.4
            lvl += (target - lvl) * math.min(1, dt * 12)
            for i, b in ipairs(bars) do
                local ph = math.abs(math.sin(wt2 * (4 + i * 1.9) + i * 1.3))
                b.Size = UDim2.fromOffset(3, 4 + 14 * math.clamp(lvl * (0.3 + 0.7 * ph), 0, 1))
            end
        end)
    end
    -- teks manual "now playing" (opsional): W:SetNowPlaying("Judul lagu") / W:SetNowPlaying(nil)
    function W:SetNowPlaying(text)
        self.NowPlaying = text
        iTitle.Text = text or (opts.Title or "KatssinnnHub")
    end
    function W:_islandNotify(title, col)
        notifToken += 1
        local tok = notifToken
        notifOn = true
        iTitle.Text = (tostring(title):gsub("<[^>]+>", ""))
        tw(iDot, 0.15, { BackgroundColor3 = col or Th.Accent })
        self:_island()
        task.delay(2.6, function()
            if tok ~= notifToken then return end
            notifOn = false
            iTitle.Text = W.NowPlaying or opts.Title or "KatssinnnHub"
            tw(iDot, 0.15, { BackgroundColor3 = Th.Accent })
            if W.Alive then W:_island() end
        end)
    end

    -- ikon logo: window tampil = ikon kotak, window disembunyikan = logo
    function W:_brand()
        -- logo tetap sama saat window dibuka maupun disembunyikan
        fImg.Image = LOGO; fImg.ImageColor3 = Color3.new(1, 1, 1); fImg.Size = UDim2.fromOffset(34, 34)
        iLogo.Image = LOGO
    end
    function W:SetToggleMode(m)
        self.ToggleMode = m
        fbtn.Visible = (m == "Always") or (m == "Mobile only" and isTouch())
    end
    function W:SetIslandMode(m) self.IslandMode = m; self:_island() end
    function W:SetDim(v) self.DimOn = v and true or false; dim.Visible = self.DimOn and frame.Visible end
    function W:SetTransparent(v)
        GlassOn = v and true or false
        reglass()
        local t = GlassOn and 1 or 0
        covTop.BackgroundTransparency = t; covBot.BackgroundTransparency = t
    end
    function W:SetTransparentAmount(a)
        GlassT = math.clamp(tonumber(a) or 0.22, 0.03, 0.7)
        if GlassOn then reglass() end
    end
    function W:SetDragStyle(s) self.DragOutline = (s == "Outline") end

    function W:SetVisible(v)
        frame.Visible = v
        dim.Visible = v and self.DimOn
        if not v then self:ClosePopup(); self:CloseFeatures() else self.Notifs = 0; self:_island() end
        self:_brand()
    end
    function W:IsVisible() return frame.Visible end

    fbtn.MouseButton1Click:Connect(function()
        if moved > 6 then return end
        W:SetVisible(not frame.Visible)
    end)
    island.MouseButton1Click:Connect(function()
        if imoved > 6 then return end
        W:SetVisible(not frame.Visible)
    end)
    minBtn.MouseButton1Click:Connect(function() W:SetVisible(false) end)

    W.Conns[#W.Conns + 1] = UIS.InputBegan:Connect(function(i, gp)
        if gp or not W.Alive then return end
        if i.KeyCode == W.ToggleKey then W:SetVisible(not frame.Visible) end
    end)

    -- ===== background image =====
    function W:SetBackground(src, opacity)
        if opacity then bgImg.ImageTransparency = 1 - math.clamp(opacity / 100, 0, 1) end
        if src == nil then bgImg.Visible = false; return end
        bgImg.Image = src; bgImg.Visible = true
        if opacity == nil then bgImg.ImageTransparency = 1 - math.clamp((self.BgOpacity or 40) / 100, 0, 1) end
    end
    function W:SetBackgroundOpacity(o)
        self.BgOpacity = o
        bgImg.ImageTransparency = 1 - math.clamp(o / 100, 0, 1)
    end

    -- ===== weather =====
    local wx = mk("Frame", { Name = "Weather", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40, ClipsDescendants = true, Parent = frame })
    local parts, weather, wt = {}, "None", 0
    local function clearParts() for _, p in ipairs(parts) do p.f:Destroy() end parts = {} end
    function W:SetWeather(kind)
        weather = kind or "None"
        clearParts()
        if weather == "None" then return end
        local n = (weather == "Rain") and 60 or 42
        for i = 1, n do
            local f = mk("Frame", { BorderSizePixel = 0, Parent = wx })
            local p = { f = f, x = math.random(), y = math.random(), s = 0.5 + math.random() * 0.8, ph = math.random() * 6 }
            if weather == "Snow" then
                f.BackgroundColor3 = Color3.new(1, 1, 1); f.BackgroundTransparency = 0.25
                local d = math.random(3, 6); f.Size = UDim2.fromOffset(d, d); round(f)
            elseif weather == "Rain" then
                f.BackgroundColor3 = Color3.fromRGB(150, 190, 255); f.BackgroundTransparency = 0.5
                f.Size = UDim2.fromOffset(1, math.random(9, 15))
            else
                f.BackgroundColor3 = Color3.fromRGB(255, 160, 200); f.BackgroundTransparency = 0.2
                f.Size = UDim2.fromOffset(6, 4); round(f)
            end
            parts[i] = p
        end
    end
    function W:SetWeatherMode(m)
        wx.Parent = (m == "Screen") and gui or frame
        wx.ZIndex = (m == "Screen") and 40 or 40
    end
    W.Conns[#W.Conns + 1] = RunService.Heartbeat:Connect(function(dt)
        if weather == "None" or not frame.Visible and wx.Parent == frame then return end
        wt += dt
        for _, p in ipairs(parts) do
            if weather == "Snow" then
                p.y += (0.08 + p.s * 0.1) * dt; p.x += math.sin(wt * p.s + p.ph) * 0.02 * dt
            elseif weather == "Rain" then
                p.y += (0.9 + p.s * 0.5) * dt; p.x -= 0.05 * dt
            else
                p.y += (0.06 + p.s * 0.08) * dt; p.x += (0.03 + math.sin(wt + p.ph) * 0.04) * dt
            end
            if p.y > 1.02 then p.y = -0.03; p.x = math.random() end
            if p.x > 1.02 then p.x = -0.02 elseif p.x < -0.03 then p.x = 1.01 end
            p.f.Position = UDim2.fromScale(p.x, p.y)
        end
    end)

    -- ===== density =====
    function W:SetDensity(mode)
        local m = (mode == "Compact") and 0.6 or (mode == "Comfortable") and 1.5 or 1
        for i = #DensLists, 1, -1 do
            local d = DensLists[i]
            if d[1].Parent then d[1].Padding = UDim.new(0, math.floor(d[2] * m + 0.5)) else table.remove(DensLists, i) end
        end
    end
    function W:SetCorner(px) setCornerMul(px / 8) end

    -- ===== responsif =====
    local brandTexts = { bt, bv }
    function W:ApplyScale()
        local vp = gui.AbsoluteSize
        if vp.X < 10 or vp.Y < 10 then vp = viewport() end
        local s = math.clamp(math.min(vp.Y / 470, vp.X / 600), 0.55, 1.3) * self.UIScaleMul
        uiscale.Scale = s
        local top = island.Visible and 50 or 6          -- sisakan ruang untuk dynamic island
        local availH = math.max(120, vp.Y - top - 6)
        local aw, ah = vp.X / s, availH / s
        local w, h
        if self.Adaptive then
            w = math.clamp(aw * 0.92, 380, 780); h = math.clamp(ah * 0.96, 270, 480)
        else
            w, h = 680, 380
        end
        w = math.min(w, aw - 6); h = math.min(h, ah - 2)
        frame.Size = UDim2.fromOffset(w, h)
        self.W, self.H = w, h
        if not self.Moved then
            frame.Position = UDim2.fromScale(0.5, (top + availH / 2) / vp.Y)
        end

        local compact = w < 560
        self.Compact = compact
        local sw = compact and 58 or 168
        side.Size = UDim2.new(0, sw, 1, 0)
        content.Position = UDim2.fromOffset(sw, 0); content.Size = UDim2.new(1, -sw, 1, 0)
        for _, o in ipairs(brandTexts) do o.Visible = not compact end
        logo.Position = UDim2.fromOffset(compact and 14 or 13, 16)
        fn.Visible = not compact; fg.Visible = not compact; fchev.Visible = not compact
        av.Position = UDim2.fromOffset(compact and 5 or 6, 10); avHide.Position = av.Position
        for _, p in ipairs(self.PageList) do p.NavText.Visible = not compact end

        local cw = w - sw
        local small = cw < 340
        searchF.Size = small and UDim2.fromOffset(34, 30) or UDim2.fromOffset(math.clamp(cw * 0.34, 110, 200), 30)
        sLbl.Visible = not small
        sIc.Position = small and UDim2.new(0.5, -7, 0.5, 0) or UDim2.new(0, 10, 0.5, 0)
        W.HeaderTitle.Size = UDim2.new(1, -(searchF.Size.X.Offset + 100), 1, 0)

        local single = cw < 470
        self.Single = single
        for _, p in ipairs(self.PageList) do p:Layout(single) end
        if self.Feat then self:CloseFeatures() end
    end
    W:ApplyScale()
    pcall(function()
        W.Conns[#W.Conns + 1] = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() W:ApplyScale(); W:_island() end)
    end)
    W.Conns[#W.Conns + 1] = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() W:ApplyScale() end)
    W:SetToggleMode("Always")
    W:_island()
    W:_brand()
    W:_hook(function() W:_brand() end)

    -- ===== navigasi =====
    local function refreshNav()
        for _, p in ipairs(W.PageList) do
            local on = (p == W.Current)
            p.NavBtn.BackgroundTransparency = on and 0 or 1
            p.NavText.TextColor3 = on and Th.Text or Th.Muted
            setIc(p.NavIcon, on and Th.Text or Th.Muted)
        end
    end
    W:_hook(refreshNav)

    local function selectPage(page)
        for _, p in ipairs(W.PageList) do p.Scroll.Visible = (p == page) end
        W.Current = page
        for _, c in ipairs(W.HeaderIconHolder:GetChildren()) do c:Destroy() end
        local hi = icon(W.HeaderIconHolder, page.Icon, 22, "Accent")
        hi.Size = UDim2.fromScale(1, 1)
        W.HeaderTitle.Text = page.Name
        refreshNav()
        W:ClosePopup()
    end
    W.SelectPage = function(self, name)
        local p = self.Pages[name]
        if p then selectPage(p) end
    end
    foot.MouseButton1Click:Connect(function() if W.Pages["Settings"] then selectPage(W.Pages["Settings"]) end end)

    function W:_flash(f)
        local h = mk("Frame", { Size = UDim2.new(1, 8, 1, 4), Position = UDim2.fromOffset(-4, -2), BackgroundColor3 = "Accent", BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 5, Parent = f })
        corner(h, 7)
        tw(h, 1.1, { BackgroundTransparency = 1 })
        task.delay(1.2, function() pcall(function() h:Destroy() end) end)
    end

    -- ===== overlay Features (search) =====
    local TYPE_ICON = { Toggle = "eye", Slider = "sliders-horizontal", Dropdown = "list", Button = "mouse-pointer-click", Input = "pencil-line", Keybind = "keyboard", Color = "palette" }
    function W:CloseFeatures()
        if self.Feat then pcall(function() self.Feat.blocker:Destroy() end); pcall(function() self.Feat.panel:Destroy() end); self.Feat = nil end
    end
    function W:OpenFeatures()
        self:ClosePopup()
        if self.Feat then return end
        local blocker = mk("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false, ZIndex = 60, Parent = frame })
        local pw, ph = math.min(self.W - 24, 540), self.H - 24
        local panel = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(pw, ph), BackgroundColor3 = "Side", Glass = "Pop", BorderSizePixel = 0, ZIndex = 61, Parent = frame })
        corner(panel, 12); stroke(panel, "Stroke", 1)
        self.Feat = { blocker = blocker, panel = panel }

        local entries, total = {}, 0
        for _, p in ipairs(self.PageList) do
            local its = {}
            for _, card in ipairs(p.Cards) do
                for _, it in ipairs(card.Items) do
                    if it.Title and it.Title ~= "" and it.Type then its[#its + 1] = { it = it, card = card } end
                end
            end
            if #its > 0 then entries[#entries + 1] = { page = p, items = its }; total += #its end
        end

        local hic = icon(panel, "list-checks", 22, "Accent"); hic.Position = UDim2.fromOffset(16, 14)
        local ht = label(panel, "Features", 15, "Text", FB); ht.Position = UDim2.fromOffset(48, 12); ht.Size = UDim2.new(1, -100, 0, 18)
        local hs = label(panel, total .. " features across " .. #entries .. " tabs", 11, "Muted", F); hs.Position = UDim2.fromOffset(48, 30); hs.Size = UDim2.new(1, -100, 0, 14)
        local cl = mk("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 12), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Text = "", Parent = panel })
        local cli = icon(cl, "x", 18, "Text"); cli.AnchorPoint = Vector2.new(0.5, 0.5); cli.Position = UDim2.fromScale(0.5, 0.5)
        cl.MouseButton1Click:Connect(function() W:CloseFeatures() end)
        blocker.MouseButton1Click:Connect(function() W:CloseFeatures() end)

        local sf = mk("Frame", { Position = UDim2.fromOffset(14, 56), Size = UDim2.new(1, -28, 0, 36), BackgroundColor3 = "Card", BorderSizePixel = 0, Parent = panel })
        corner(sf, 9); stroke(sf, "Stroke", 1)
        local si = icon(sf, "search", 16, "Muted"); si.AnchorPoint = Vector2.new(0, 0.5); si.Position = UDim2.new(0, 12, 0.5, 0)
        local sb = mk("TextBox", {
            Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, Text = "",
            PlaceholderText = "Search features", PlaceholderColor3 = "Muted", TextColor3 = "Text", Font = FM, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = sf,
        })
        local lst = mk("ScrollingFrame", {
            Position = UDim2.fromOffset(10, 100), Size = UDim2.new(1, -20, 1, -108), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = "Stroke", CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel,
        })
        list(lst, 3)

        local groups = {}
        for gi, e in ipairs(entries) do
            local hdr = mk("Frame", { Size = UDim2.new(1, -4, 0, 28), BackgroundTransparency = 1, LayoutOrder = gi * 1000, Parent = lst })
            local gic = icon(hdr, e.page.Icon, 15, "Accent"); gic.Position = UDim2.fromOffset(8, 7)
            local gl = label(hdr, string.upper(e.page.Name), 11, "Muted", FM); gl.Position = UDim2.fromOffset(32, 0); gl.Size = UDim2.new(1, -70, 1, 0)
            local gn = label(hdr, tostring(#e.items), 11, "Muted", FM, Enum.TextXAlignment.Right); gn.Position = UDim2.new(1, -40, 0, 0); gn.Size = UDim2.fromOffset(34, 28)
            local g = { hdr = hdr, rows = {} }
            groups[#groups + 1] = g
            for ri, en in ipairs(e.items) do
                local b = mk("TextButton", { Size = UDim2.new(1, -4, 0, 46), BackgroundColor3 = "Row", BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = gi * 1000 + ri, Parent = lst })
                corner(b, 8)
                local ib = icon(b, TYPE_ICON[en.it.Type] or "circle", 17, "Muted"); ib.Position = UDim2.fromOffset(12, 14)
                local tl = label(b, en.it.Title, 13, "Text", FM); tl.Position = UDim2.fromOffset(44, 6); tl.Size = UDim2.new(1, -86, 0, 18); tl.TextTruncate = Enum.TextTruncate.AtEnd
                local cl2 = label(b, en.card.TitleRaw or "", 11, "Muted", F); cl2.Position = UDim2.fromOffset(44, 24); cl2.Size = UDim2.new(1, -86, 0, 14); cl2.TextTruncate = Enum.TextTruncate.AtEnd
                local ar = icon(b, "arrow-up-right", 16, "Muted"); ar.AnchorPoint = Vector2.new(1, 0.5); ar.Position = UDim2.new(1, -12, 0.5, 0)
                b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.4 end)
                b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
                b.MouseButton1Click:Connect(function()
                    W:CloseFeatures()
                    selectPage(e.page)
                    if en.card.SetOpen then en.card.SetOpen(true) end
                    task.spawn(function()
                        task.wait(0.08)
                        local sc = e.page.Scroll
                        local y = (en.it.Frame.AbsolutePosition.Y - sc.AbsolutePosition.Y) / uiscale.Scale + sc.CanvasPosition.Y - 10
                        sc.CanvasPosition = Vector2.new(0, math.max(0, y))
                        W:_flash(en.it.Frame)
                    end)
                end)
                g.rows[#g.rows + 1] = { b = b, t = string.lower(en.it.Title), c = string.lower(en.card.TitleRaw or "") }
            end
        end
        sb:GetPropertyChangedSignal("Text"):Connect(function()
            local q = string.lower(sb.Text)
            for _, g in ipairs(groups) do
                local any = false
                for _, r in ipairs(g.rows) do
                    local vis = (q == "") or r.t:find(q, 1, true) ~= nil or r.c:find(q, 1, true) ~= nil
                    r.b.Visible = vis
                    if vis then any = true end
                end
                g.hdr.Visible = any
            end
        end)
        task.defer(function() pcall(function() sb:CaptureFocus() end) end)
    end
    searchF.MouseButton1Click:Connect(function() W:OpenFeatures() end)

    -- ===== halaman =====
    function W:AddPage(o)
        local page = { Name = o.Name, Icon = o.Icon or "circle", Cards = {}, Win = W, NextCol = 1 }

        local btn = mk("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = "Row", BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = nav })
        corner(btn, 8)
        local ic = icon(btn, page.Icon, 18, "Muted"); ic.Position = UDim2.fromOffset(12, 9)
        local tx = label(btn, o.Name, 13, Th.Muted, FM)
        tx.Position = UDim2.fromOffset(40, 0); tx.Size = UDim2.new(1, -44, 1, 0); tx.Visible = not W.Compact
        page.NavBtn, page.NavText, page.NavIcon = btn, tx, ic
        btn.MouseButton1Click:Connect(function() selectPage(page) end)

        local scroll = mk("ScrollingFrame", {
            Name = o.Name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = "Stroke", CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = holder,
        })
        -- padding dipasang di frame biasa (bukan di ScrollingFrame) karena UIPadding di ScrollingFrame
        -- tidak mengurangi lebar scale anak -> kolom kanan melebihi kotak window.
        local root = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroll })
        pad(root, 14, 4, 16, 14)
        local cols = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = root })
        list(cols, 10, Enum.FillDirection.Horizontal)
        page.Cols = {}
        for i = 1, 2 do
            local c = mk("Frame", { Size = UDim2.new(0.5, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = i, Parent = cols })
            list(c, 10)
            page.Cols[i] = c
        end
        page.Scroll = scroll

        function page:Layout(single)
            if single then
                self.Cols[2].Visible = false
                self.Cols[1].Size = UDim2.new(1, 0, 0, 0)
                for idx, card in ipairs(self.Cards) do card.Frame.Parent = self.Cols[1]; card.Frame.LayoutOrder = idx end
            else
                self.Cols[2].Visible = true
                self.Cols[1].Size = UDim2.new(0.5, -5, 0, 0)
                local n = { 0, 0 }
                for _, card in ipairs(self.Cards) do
                    n[card.Col] += 1
                    card.Frame.Parent = self.Cols[card.Col]; card.Frame.LayoutOrder = n[card.Col]
                end
            end
        end

        -- ===== kartu =====
        function page:AddCard(co)
            local colIdx = co.Column or self.NextCol
            self.NextCol = (colIdx == 1) and 2 or 1
            local card = { Win = W, Page = self, Items = {}, Col = colIdx, TitleRaw = co.Title or "", TitleLower = string.lower(co.Title or "") }
            local cf = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = "Card", BorderSizePixel = 0, ClipsDescendants = true, Parent = self.Cols[colIdx] })
            corner(cf, 10); stroke(cf, "Stroke", 1)
            list(cf, 0)
            card.Frame = cf

            local hd = mk("TextButton", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = "CardHd", BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = 1, Parent = cf })
            local hi = icon(hd, co.Icon or "circle", 17, "Accent"); hi.Position = UDim2.fromOffset(12, 11)
            local ht = label(hd, co.Title or "", 13, "Text", FB)
            ht.Position = UDim2.fromOffset(38, 0); ht.Size = UDim2.new(1, -72, 1, 0); ht.TextTruncate = Enum.TextTruncate.AtEnd
            local chev = icon(hd, "chevron-down", 16, "Muted"); chev.AnchorPoint = Vector2.new(1, 0.5); chev.Position = UDim2.new(1, -12, 0.5, 0)

            local body = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = cf })
            pad(body, 14, 10, 14, 14)
            dlist(body, 9)
            card.Body = body
            local open = true
            local function setOpen(v)
                open = v
                body.Visible = v
                local id = resolveIcon(v and "chevron-down" or "chevron-right")
                if id and chev:IsA("ImageLabel") then chev.Image = id end
            end
            card.SetOpen = setOpen
            hd.MouseButton1Click:Connect(function() setOpen(not open) end)
            if co.Collapsed then setOpen(false) end

            local function reg(f, title, typ)
                card.Items[#card.Items + 1] = { Frame = f, Text = string.lower(title or ""), Title = title, Type = typ }
            end
            local function row(h, title, typ)
                local f = mk("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = #card.Items + 1, Parent = body })
                reg(f, title, typ)
                return f
            end
            local function register(o2, obj)
                pcall(function() obj.Default = obj:Get() end)
                if o2.id then W.Elements[o2.id] = obj end
            end

            -- ----- Toggle -----
            function card:Toggle(o2)
                local hasDesc = o2.Desc and o2.Desc ~= ""
                local f = row(hasDesc and 40 or 30, o2.Title, "Toggle")
                local t = label(f, o2.Title or "", 13, "Text", FM)
                t.Size = UDim2.new(1, -56, 0, hasDesc and 20 or 30); t.TextTruncate = Enum.TextTruncate.AtEnd
                if hasDesc then
                    local d = label(f, o2.Desc, 11, "Muted", F)
                    d.Position = UDim2.fromOffset(0, 21); d.Size = UDim2.new(1, -56, 0, 14); d.TextTruncate = Enum.TextTruncate.AtEnd
                end
                local sw = mk("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(42, 24), BackgroundColor3 = Th.Off, BorderSizePixel = 0, Parent = f })
                round(sw)
                local knob = mk("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Th.Knob, BorderSizePixel = 0, Parent = sw })
                round(knob)
                local click = mk("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f })
                local cb = o2.Callback or function() end
                local obj = { Frame = f, Value = false, Id = o2.id }
                local function visual(v, instant)
                    local p1 = { BackgroundColor3 = v and Th.Accent or Th.Off }
                    local p2 = { Position = v and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = v and Th.OnKnob or Th.Knob }
                    if instant then for k, x in pairs(p1) do sw[k] = x end; for k, x in pairs(p2) do knob[k] = x end
                    else tw(sw, 0.15, p1); tw(knob, 0.15, p2) end
                end
                function obj:Set(v, silent)
                    v = v and true or false
                    self.Value = v
                    visual(v)
                    if not silent then pcall(cb, v) end
                end
                obj.SetValue = obj.Set
                function obj:Get() return self.Value end
                obj.GetValue = obj.Get
                function obj:SetVisible(v) f.Visible = v end
                W:_hook(function() visual(obj.Value, true) end)
                click.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
                if o2.Value then
                    obj:Set(true, true)
                    W.Pending[#W.Pending + 1] = function() pcall(cb, true) end
                end
                register(o2, obj)
                return obj
            end

            -- ----- Slider -----
            function card:Slider(o2)
                local f = row(46, o2.Title, "Slider")
                local t = label(f, o2.Title or "", 13, "Text", FM)
                t.Size = UDim2.new(1, -74, 0, 24); t.TextTruncate = Enum.TextTruncate.AtEnd
                local box = mk("TextBox", {
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(60, 24),
                    BackgroundColor3 = "Field", Text = "", TextColor3 = "Text", Font = FM, TextSize = 12, ClearTextOnFocus = false, Parent = f,
                })
                corner(box, 6); stroke(box, "Stroke", 1)
                local track = mk("Frame", { Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = "Off", BorderSizePixel = 0, Parent = f })
                round(track)
                local fill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = "Accent", BorderSizePixel = 0, Parent = track })
                round(fill)
                local thumb = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = "Accent", BorderSizePixel = 0, Parent = track })
                round(thumb)
                local hit = mk("TextButton", { Position = UDim2.new(0, -6, 0, 26), Size = UDim2.new(1, 12, 0, 22), BackgroundTransparency = 1, Text = "", Parent = f })

                local min, max = o2.Min or 0, o2.Max or 100
                local dec = o2.Rounding or 0
                local suffix = o2.Suffix or ""
                local cb = o2.Callback or function() end
                local obj = { Frame = f, Value = min, Id = o2.id }
                local function fmt(v)
                    if dec <= 0 then return tostring(math.floor(v + 0.5)) .. suffix end
                    return string.format("%." .. dec .. "f", v) .. suffix
                end
                function obj:Set(v, silent)
                    v = tonumber(v) or min
                    v = math.clamp(v, min, max)
                    local m = 10 ^ dec
                    v = math.floor(v * m + 0.5) / m
                    self.Value = v
                    local r = (max > min) and ((v - min) / (max - min)) or 0
                    fill.Size = UDim2.fromScale(r, 1)
                    thumb.Position = UDim2.new(r, 0, 0.5, 0)
                    box.Text = fmt(v)
                    if not silent then pcall(cb, v) end
                end
                obj.SetValue = obj.Set
                function obj:Get() return self.Value end
                obj.GetValue = obj.Get
                function obj:SetVisible(v) f.Visible = v end

                local dragging = false
                local function fromX(x)
                    local w = track.AbsoluteSize.X
                    if w <= 0 then return end
                    obj:Set(min + (max - min) * math.clamp((x - track.AbsolutePosition.X) / w, 0, 1))
                end
                hit.InputBegan:Connect(function(i)
                    if isPointer(i) then
                        dragging = true
                        page.Scroll.ScrollingEnabled = false
                        fromX(i.Position.X)
                    end
                end)
                W.Conns[#W.Conns + 1] = UIS.InputChanged:Connect(function(i)
                    if dragging and isMove(i) then fromX(i.Position.X) end
                end)
                W.Conns[#W.Conns + 1] = UIS.InputEnded:Connect(function(i)
                    if dragging and isPointer(i) then dragging = false; page.Scroll.ScrollingEnabled = true end
                end)
                box.FocusLost:Connect(function()
                    local n = tonumber((box.Text:gsub("[^%d%.%-]", "")))
                    obj:Set(n or obj.Value)
                end)

                obj:Set(o2.Value or min, true)
                W.Pending[#W.Pending + 1] = function() pcall(cb, obj.Value) end
                register(o2, obj)
                return obj
            end

            -- ----- Button -----
            local function styleButton(b, colr)
                regGlass(b, "Field")
                b.BackgroundColor3 = Th.Field
                b.TextColor3 = (colr and colArg(colr, Th.Text)) or Th.Text
                if typeof(b.TextColor3) ~= "Color3" then b.TextColor3 = Th.Text end
                b.MouseEnter:Connect(function() tw(b, 0.12, { BackgroundColor3 = Th.RowHi }) end)
                b.MouseLeave:Connect(function() tw(b, 0.12, { BackgroundColor3 = Th.Field }) end)
                W:_hook(function() b.BackgroundColor3 = Th.Field end)
            end

            function card:Button(o2)
                local f = row(34, o2.Title or o2.Text, "Button")
                local b = mk("TextButton", {
                    Size = UDim2.fromScale(1, 1), Text = o2.Text or o2.Title or "", Font = FM, TextSize = 13,
                    AutoButtonColor = false, BorderSizePixel = 0, Parent = f,
                })
                corner(b, 7); stroke(b, "Stroke", 1)
                local colr = o2.Color and (type(o2.Color) == "string" and C(o2.Color) or o2.Color) or nil
                styleButton(b, colr)
                if o2.Icon then
                    local ic2 = icon(b, o2.Icon, 16, "Muted"); ic2.AnchorPoint = Vector2.new(0, 0.5); ic2.Position = UDim2.new(0, 14, 0.5, 0)
                    if colr then setIc(ic2, colr) end
                end
                local cb = o2.Callback or function() end
                b.MouseButton1Click:Connect(function() pcall(cb) end)
                local obj = { Frame = f }
                function obj:SetText(s) b.Text = s end
                function obj:SetVisible(v) f.Visible = v end
                return obj
            end

            function card:Buttons(o2)
                local f = row(34, "", nil)
                list(f, 8, Enum.FillDirection.Horizontal)
                local n = #o2.Buttons
                for i, bd in ipairs(o2.Buttons) do
                    local b = mk("TextButton", {
                        Size = UDim2.new(1 / n, -8 * (n - 1) / n, 1, 0), Text = bd.Text or "", Font = FM, TextSize = 12,
                        AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i, Parent = f,
                    })
                    corner(b, 7); stroke(b, "Stroke", 1)
                    styleButton(b, bd.Color and (type(bd.Color) == "string" and C(bd.Color) or bd.Color) or nil)
                    b.MouseButton1Click:Connect(function() pcall(bd.Callback or function() end) end)
                    card.Items[#card.Items + 1] = { Frame = b, Text = string.lower(bd.Text or ""), Title = bd.Text, Type = "Button" }
                end
                return { Frame = f }
            end

            function card:Label(o2)
                local f = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = #card.Items + 1, Parent = body })
                reg(f, o2.Title or o2.Text, nil)
                local t = label(f, o2.Text or o2.Title or "", o2.Size or 11, o2.Color or "Muted", F)
                t.Size = UDim2.new(1, 0, 0, 0); t.AutomaticSize = Enum.AutomaticSize.Y; t.TextWrapped = true; t.RichText = true
                local obj = { Frame = f }
                function obj:SetText(s) t.Text = s end
                function obj:SetVisible(v) f.Visible = v end
                return obj
            end

            function card:Custom(h) return row(h, "", nil) end

            function card:Divider(text)
                local f = row(16, "", nil)
                mk("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = "Stroke", BorderSizePixel = 0, Parent = f })
                if text and text ~= "" then
                    f:ClearAllChildren()
                    local l = mk("TextLabel", {
                        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16),
                        BackgroundTransparency = 1, BorderSizePixel = 0, Text = text, TextColor3 = "Muted", Font = FM, TextSize = 11, Parent = f,
                    })
                    pad(l, 8, 0, 8, 0)
                    local l1 = mk("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0.5, -20, 0, 1), BackgroundColor3 = "Stroke", BorderSizePixel = 0, Parent = f })
                    local l2 = mk("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.5, -20, 0, 1), BackgroundColor3 = "Stroke", BorderSizePixel = 0, Parent = f })
                    local function fit()
                        local fw = f.AbsoluteSize.X
                        if fw <= 0 then return end
                        local r = l.AbsoluteSize.X / fw
                        local sz = UDim2.new((1 - r) / 2, -4, 0, 1)
                        l1.Size = sz; l2.Size = sz
                    end
                    l:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
                    f:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
                    task.defer(fit)
                end
                return { Frame = f }
            end

            -- ----- Input -----
            function card:Input(o2)
                local hasTitle = o2.Title and o2.Title ~= ""
                local f = row(hasTitle and 58 or 34, o2.Title, "Input")
                local y0 = 0
                if hasTitle then
                    local t = label(f, o2.Title, 13, "Text", FM); t.Size = UDim2.new(1, 0, 0, 20); y0 = 24
                end
                local btnW = o2.ButtonText and 64 or 0
                local bx = mk("TextBox", {
                    Position = UDim2.fromOffset(0, y0), Size = UDim2.new(1, -(btnW > 0 and btnW + 8 or 0), 0, 34), BackgroundColor3 = "Field", BorderSizePixel = 0,
                    Text = o2.Value or "", PlaceholderText = o2.Placeholder or "", PlaceholderColor3 = "Muted", TextColor3 = "Text",
                    Font = FM, TextSize = 13, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = f,
                })
                corner(bx, 7); stroke(bx, "Stroke", 1); pad(bx, 12, 0)
                local cb = o2.Callback or function() end
                local obj = { Frame = f, Id = o2.id }
                function obj:Set(v, silent) bx.Text = tostring(v or ""); if not silent then pcall(cb, bx.Text) end end
                obj.SetValue = obj.Set
                function obj:Get() return bx.Text end
                obj.GetValue = obj.Get
                function obj:SetVisible(v) f.Visible = v end
                bx.FocusLost:Connect(function() pcall(cb, bx.Text) end)
                if btnW > 0 then
                    local b = mk("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, y0), Size = UDim2.fromOffset(btnW, 34), Text = o2.ButtonText, Font = FM, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0, Parent = f })
                    corner(b, 7); stroke(b, "Stroke", 1); styleButton(b)
                    b.MouseButton1Click:Connect(function() pcall(o2.OnButton or function() end, bx.Text) end)
                end
                register(o2, obj)
                return obj
            end

            -- ----- Keybind -----
            function card:Keybind(o2)
                local f = row(34, o2.Title, "Keybind")
                local t = label(f, o2.Title or "", 13, "Text", FM)
                t.Size = UDim2.new(1, -90, 1, 0)
                local kb = mk("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(84, 28),
                    BackgroundColor3 = "Field", Text = "", TextColor3 = "Text", Font = FM, TextSize = 12, AutoButtonColor = false, Parent = f,
                })
                corner(kb, 7); stroke(kb, "Stroke", 1)
                local key = o2.Value or Enum.KeyCode.Unknown
                local cb, onChanged = o2.Callback or function() end, o2.OnChanged or function() end
                local obj = { Frame = f, Id = o2.id }
                local function show() kb.Text = keyShort(key.Name) end
                function obj:Set(v, silent)
                    if type(v) == "string" then
                        local ok, k = pcall(function() return Enum.KeyCode[v] end)
                        if ok and k then v = k else return end
                    end
                    key = v; show()
                    if not silent then pcall(onChanged, key) end
                end
                obj.SetValue = obj.Set
                function obj:Get() return key.Name end
                obj.GetValue = obj.Get
                function obj:Key() return key end
                function obj:SetVisible(v) f.Visible = v end
                local listening = false
                kb.MouseButton1Click:Connect(function()
                    if listening then return end
                    listening = true; kb.Text = "..."
                    local c
                    c = UIS.InputBegan:Connect(function(i)
                        if i.UserInputType == Enum.UserInputType.Keyboard then
                            listening = false; c:Disconnect()
                            obj:Set(i.KeyCode)
                        end
                    end)
                end)
                W.Conns[#W.Conns + 1] = UIS.InputBegan:Connect(function(i, gp)
                    if gp or listening or not W.Alive then return end
                    if i.KeyCode == key and key ~= Enum.KeyCode.Unknown then pcall(cb, key) end
                end)
                show()
                register(o2, obj)
                return obj
            end

            -- ----- Color (picker HSV) -----
            function card:Color(o2)
                local f = row(34, o2.Title, "Color")
                local t = label(f, o2.Title or "", 13, "Text", FM); t.Size = UDim2.new(1, -150, 0, 34)
                local hexL = label(f, "", 11, "Muted", F, Enum.TextXAlignment.Right)
                hexL.AnchorPoint = Vector2.new(1, 0); hexL.Position = UDim2.new(1, -92, 0, 0); hexL.Size = UDim2.fromOffset(70, 34)
                local sw = mk("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -30, 0, 5), Size = UDim2.fromOffset(52, 24), BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = f })
                corner(sw, 6); stroke(sw, "Stroke", 1)
                local ch = icon(f, "chevron-down", 16, "Muted"); ch.AnchorPoint = Vector2.new(1, 0); ch.Position = UDim2.new(1, -4, 0, 9)

                local pk = mk("Frame", { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1, Visible = false, Parent = f })
                local svBox = mk("Frame", { Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = Color3.new(1, 0, 0), BorderSizePixel = 0, Parent = pk })
                corner(svBox, 6)
                local wh = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = svBox })
                corner(wh, 6)
                mk("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = wh })
                local bl = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = svBox })
                corner(bl, 6)
                mk("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = bl })
                local svCur = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = svBox })
                round(svCur); stroke(svCur, Color3.new(1, 1, 1), 2)
                local hueBar = mk("Frame", { Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = pk })
                round(hueBar)
                local seq = {}
                for i = 0, 6 do seq[#seq + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)) end
                mk("UIGradient", { Color = ColorSequence.new(seq), Parent = hueBar })
                local hueCur = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(6, 18), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = hueBar })
                corner(hueCur, 3, true)

                local h, s, v = 0, 1, 1
                local cb = o2.Callback or function() end
                local obj = { Frame = f, Id = o2.id }
                local function paint()
                    local col = Color3.fromHSV(h, s, v)
                    sw.BackgroundColor3 = col
                    hexL.Text = "#" .. col:ToHex():upper()
                    svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                    svCur.Position = UDim2.fromScale(s, 1 - v)
                    hueCur.Position = UDim2.fromScale(h, 0.5)
                    return col
                end
                function obj:Set(val, silent)
                    local col = (typeof(val) == "Color3") and val or C(tostring(val))
                    h, s, v = col:ToHSV()
                    local c = paint()
                    if not silent then pcall(cb, c) end
                end
                obj.SetValue = obj.Set
                function obj:Get() return "#" .. Color3.fromHSV(h, s, v):ToHex() end
                obj.GetValue = obj.Get
                function obj:SetVisible(x) f.Visible = x end

                local openPk = false
                local function toggle()
                    openPk = not openPk
                    pk.Visible = openPk
                    f.Size = UDim2.new(1, 0, 0, openPk and 144 or 34)
                    local id = resolveIcon(openPk and "chevron-up" or "chevron-down")
                    if id and ch:IsA("ImageLabel") then ch.Image = id end
                end
                sw.MouseButton1Click:Connect(toggle)
                local hdBtn = mk("TextButton", { Size = UDim2.new(1, -100, 0, 34), BackgroundTransparency = 1, Text = "", Parent = f })
                hdBtn.MouseButton1Click:Connect(toggle)

                local mode
                local function upd(pos)
                    if mode == "sv" then
                        s = math.clamp((pos.X - svBox.AbsolutePosition.X) / math.max(1, svBox.AbsoluteSize.X), 0, 1)
                        v = 1 - math.clamp((pos.Y - svBox.AbsolutePosition.Y) / math.max(1, svBox.AbsoluteSize.Y), 0, 1)
                    elseif mode == "hue" then
                        h = math.clamp((pos.X - hueBar.AbsolutePosition.X) / math.max(1, hueBar.AbsoluteSize.X), 0, 0.999)
                    end
                    pcall(cb, paint())
                end
                local function startDrag(m, i)
                    mode = m; page.Scroll.ScrollingEnabled = false; upd(i.Position)
                end
                svBox.InputBegan:Connect(function(i) if isPointer(i) then startDrag("sv", i) end end)
                hueBar.InputBegan:Connect(function(i) if isPointer(i) then startDrag("hue", i) end end)
                W.Conns[#W.Conns + 1] = UIS.InputChanged:Connect(function(i) if mode and isMove(i) then upd(i.Position) end end)
                W.Conns[#W.Conns + 1] = UIS.InputEnded:Connect(function(i) if mode and isPointer(i) then mode = nil; page.Scroll.ScrollingEnabled = true end end)

                obj:Set(o2.Value or "#FFFFFF", true)
                register(o2, obj)
                return obj
            end

            -- ----- Dropdown (single / multi) -----
            function card:Dropdown(o2)
                local f = row(62, o2.Title, "Dropdown")
                local t = label(f, o2.Title or "", 13, "Text", FM)
                t.Size = UDim2.new(1, 0, 0, 20)
                local btn = mk("TextButton", {
                    Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = "Field", BorderSizePixel = 0,
                    Text = "", AutoButtonColor = false, Parent = f,
                })
                corner(btn, 7); stroke(btn, "Stroke", 1)
                local vt = label(btn, "", 13, "Text", FM)
                vt.Position = UDim2.fromOffset(12, 0); vt.Size = UDim2.new(1, -40, 1, 0); vt.TextTruncate = Enum.TextTruncate.AtEnd
                local arrow = icon(btn, "chevron-down", 16, "Muted"); arrow.AnchorPoint = Vector2.new(1, 0.5); arrow.Position = UDim2.new(1, -10, 0.5, 0)

                local items = o2.List or {}
                local multi = o2.Multi == true or type(o2.Value) == "table"
                local sel = {}
                local cb = o2.Callback or function() end
                local obj = { Frame = f, Id = o2.id, Multi = multi }

                local function indexOf(x) for i, y in ipairs(items) do if y == x then return i end end end
                local function ordered()
                    local out = {}
                    for _, x in ipairs(items) do if sel[x] then out[#out + 1] = x end end
                    return out
                end
                local function refreshText()
                    local o3 = ordered()
                    if multi then vt.Text = (#o3 > 0) and table.concat(o3, ", ") or "None"
                    else vt.Text = o3[1] and tostring(o3[1]) or (o2.Placeholder or "Select") end
                    local empty = (vt.Text == "None" or vt.Text == (o2.Placeholder or "Select"))
                    vt.TextColor3 = empty and Th.Muted or Th.Text
                end
                W:_hook(refreshText)
                function obj:Get()
                    local o3 = ordered()
                    if multi then return o3 end
                    return o3[1]
                end
                obj.GetValue = obj.Get
                function obj:Set(x, silent)
                    sel = {}
                    if type(x) == "table" then
                        for _, y in ipairs(x) do if indexOf(y) then sel[y] = true end end
                    elseif x ~= nil and indexOf(x) then sel[x] = true end
                    refreshText()
                    if not silent then pcall(cb, self:Get()) end
                end
                obj.SetValue = obj.Set
                function obj:SetList(l)
                    items = l or {}
                    local keep = {}
                    for _, x in ipairs(items) do if sel[x] then keep[x] = true end end
                    sel = keep
                    refreshText()
                end
                function obj:SetVisible(x) f.Visible = x end

                local function openPopup()
                    if W.Popup and W.PopupOwner == obj then W:ClosePopup() return end
                    W:ClosePopup(); W:CloseFeatures()
                    W.PopupOwner = obj
                    local blocker = mk("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 50, Parent = frame })
                    local sc = uiscale.Scale
                    local rel = (btn.AbsolutePosition - frame.AbsolutePosition) / sc
                    local width = btn.AbsoluteSize.X / sc
                    local height = math.min(#items * 30 + 58, 230)
                    local y = rel.Y + btn.AbsoluteSize.Y / sc + 4
                    if y + height > W.H - 6 then y = math.max(6, rel.Y - height - 4) end
                    local pop = mk("Frame", {
                        Position = UDim2.fromOffset(rel.X, y), Size = UDim2.fromOffset(width, height),
                        BackgroundColor3 = "Side", Glass = "Pop", BorderSizePixel = 0, ZIndex = 51, Parent = frame,
                    })
                    corner(pop, 9); stroke(pop, "Stroke", 1)
                    local sf = mk("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 30), BackgroundColor3 = "Field", BorderSizePixel = 0, Parent = pop })
                    corner(sf, 7); stroke(sf, "Stroke", 1)
                    local sb = mk("TextBox", {
                        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -16, 1, 0), BackgroundTransparency = 1, Text = "",
                        PlaceholderText = "Search", PlaceholderColor3 = "Muted", TextColor3 = "Text", Font = FM, TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = sf,
                    })
                    local lst = mk("ScrollingFrame", {
                        Position = UDim2.fromOffset(6, 44), Size = UDim2.new(1, -12, 1, -50), BackgroundTransparency = 1, BorderSizePixel = 0,
                        ScrollBarThickness = 2, ScrollBarImageColor3 = "Stroke", CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = pop,
                    })
                    list(lst, 2)
                    local rows = {}
                    local function paint(r, name)
                        local on = sel[name] == true
                        r.txt.TextColor3 = on and Th.Accent or Th.Text
                        r.bar.Visible = on
                        r.btn.BackgroundTransparency = on and 0.5 or 1
                    end
                    for i, name in ipairs(items) do
                        local b = mk("TextButton", { Size = UDim2.new(1, -4, 0, 28), BackgroundColor3 = "Row", BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = lst })
                        corner(b, 6)
                        local bar = mk("Frame", { Size = UDim2.new(0, 3, 1, -12), Position = UDim2.fromOffset(3, 6), BackgroundColor3 = "Accent", BorderSizePixel = 0, Parent = b })
                        round(bar)
                        local tx = label(b, tostring(name), 13, Th.Text, FM)
                        tx.Position = UDim2.fromOffset(14, 0); tx.Size = UDim2.new(1, -18, 1, 0); tx.TextTruncate = Enum.TextTruncate.AtEnd
                        local r = { btn = b, bar = bar, txt = tx, name = name }
                        rows[#rows + 1] = r
                        paint(r, name)
                        b.MouseButton1Click:Connect(function()
                            if multi then
                                sel[name] = (not sel[name]) or nil
                                refreshText(); paint(r, name)
                                pcall(cb, obj:Get())
                            else
                                sel = { [name] = true }
                                refreshText()
                                pcall(cb, obj:Get())
                                W:ClosePopup()
                            end
                        end)
                    end
                    sb:GetPropertyChangedSignal("Text"):Connect(function()
                        local q = string.lower(sb.Text)
                        for _, r in ipairs(rows) do r.btn.Visible = (q == "") or (string.lower(tostring(r.name)):find(q, 1, true) ~= nil) end
                    end)
                    blocker.MouseButton1Click:Connect(function() W:ClosePopup() end)
                    W.Popup = { blocker, pop }
                    local up = resolveIcon("chevron-up")
                    if up and arrow:IsA("ImageLabel") then arrow.Image = up end
                    W.PopupArrow = arrow
                end
                btn.MouseButton1Click:Connect(openPopup)

                obj:Set(o2.Value, true)
                if multi or o2.Value ~= nil then
                    W.Pending[#W.Pending + 1] = function() pcall(cb, obj:Get()) end
                end
                register(o2, obj)
                return obj
            end

            self.Cards[#self.Cards + 1] = card
            self:Layout(W.Single)
            return card
        end

        self.Pages[o.Name] = page
        self.PageList[#self.PageList + 1] = page
        page:Layout(self.Single)
        if self.Compact then tx.Visible = false end
        if #self.PageList == 1 then selectPage(page) end
        return page
    end

    function W:ClosePopup()
        if self.Popup then
            for _, o in ipairs(self.Popup) do pcall(function() o:Destroy() end) end
            self.Popup = nil
            self.PopupOwner = nil
        end
        if self.PopupArrow then
            pcall(function()
                local dn = resolveIcon("chevron-down")
                if dn and self.PopupArrow:IsA("ImageLabel") then self.PopupArrow.Image = dn end
            end)
            self.PopupArrow = nil
        end
    end

    -- ===== notifikasi =====
    local toasts = mk("Frame", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(260, 400),
        BackgroundTransparency = 1, ZIndex = 70, Parent = gui,
    })
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = toasts })

    function W:Notify(o)
        o = o or {}
        local dur = o.Duration or 3
        local col = o.Color and (typeof(o.Color) == "string" and C(o.Color) or o.Color) or Th.Accent
        local tf = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = "Card", Glass = "Toast", BorderSizePixel = 0, Parent = toasts })
        corner(tf, 9); stroke(tf, "Stroke", 1)
        pad(tf, 12, 10, 12, 0)
        list(tf, 3)
        local tt = label(tf, o.Title or "", 13, col, FB)
        tt.Size = UDim2.new(1, 0, 0, 16); tt.LayoutOrder = 1; tt.RichText = true
        if o.Desc and o.Desc ~= "" then
            local td = label(tf, o.Desc, 11, "Muted", F)
            td.Size = UDim2.new(1, 0, 0, 0); td.AutomaticSize = Enum.AutomaticSize.Y; td.TextWrapped = true; td.LayoutOrder = 2; td.RichText = true
        end
        local pb = mk("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = col, BorderSizePixel = 0, LayoutOrder = 3, Parent = tf })
        mk("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, LayoutOrder = 4, Parent = tf })
        pcall(function() TweenService:Create(pb, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) }):Play() end)
        task.delay(dur, function() pcall(function() tf:Destroy() end) end)
        self.Notifs += 1
        self:_islandNotify(o.Title or "", col)
    end

    -- ===== config =====
    local canFS = has(writefile) and has(readfile) and has(isfile) and has(makefolder) and has(isfolder)
    W.CanFS = canFS
    if canFS then
        pcall(function()
            local cur = ""
            for p in string.gmatch(W.Folder, "[^/]+") do
                cur = (cur == "") and p or (cur .. "/" .. p)
                if not isfolder(cur) then makefolder(cur) end
            end
        end)
    end
    local function cfgPath(name) return W.Folder .. "/" .. name .. ".json" end
    local function rf(p)
        if not canFS then return nil end
        local ok, r = pcall(function() if isfile(p) then return readfile(p) end end)
        return ok and r or nil
    end
    local function wf(p, s) if canFS then return pcall(writefile, p, s) end return false end

    function W:Collect()
        local data = {}
        for id, el in pairs(self.Elements) do
            if not id:find("^ui_") then
                local ok, v = pcall(el.Get, el)
                if ok and v ~= nil then data[id] = v end
            end
        end
        return data
    end

    function W:ListConfigs()
        local out = {}
        if canFS and has(listfiles) then
            pcall(function()
                for _, p in ipairs(listfiles(W.Folder)) do
                    local nm = tostring(p):match("([^/\\]+)%.json$")
                    if nm and nm ~= "themes" and nm ~= "_ui" then out[#out + 1] = nm end
                end
            end)
        else
            for nm in pairs(self.Mem) do out[#out + 1] = nm end
        end
        table.sort(out)
        return out
    end

    function W:SaveConfig(name)
        if not name or name == "" then return false end
        local json = HttpService:JSONEncode(self:Collect())
        if canFS then return (pcall(writefile, cfgPath(name), json)) end
        self.Mem[name] = json
        return true
    end

    function W:_readCfg(name)
        if canFS then return rf(cfgPath(name)) end
        return self.Mem[name]
    end

    function W:_applyData(data)
        for id, v in pairs(data) do
            local el = self.Elements[id]
            if el then pcall(el.Set, el, v) end
        end
    end

    function W:LoadConfig(name)
        if not name or name == "" then return false end
        local json = self:_readCfg(name)
        if not json then return false end
        local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
        if not ok or type(data) ~= "table" then return false end
        self:_applyData(data)
        self.LoadedCfg = name
        return true
    end

    function W:DeleteConfig(name)
        if canFS and has(delfile) then pcall(delfile, cfgPath(name)) else self.Mem[name] = nil end
        if self:GetAutoload() == name then self:SetAutoload(nil) end
        if self.LoadedCfg == name then self.LoadedCfg = nil end
    end

    function W:RenameConfig(old, new)
        if not old or not new or new == "" or old == new then return false end
        local json = self:_readCfg(old)
        if not json then return false end
        if canFS then wf(cfgPath(new), json) else self.Mem[new] = json end
        self:DeleteConfig(old)
        if self.LoadedCfg == nil then self.LoadedCfg = new end
        return true
    end

    function W:ResetAll()
        for id, el in pairs(self.Elements) do
            if not id:find("^ui_") and el.Default ~= nil then pcall(el.Set, el, el.Default) end
        end
    end

    function W:ExportCode() return "KH1:" .. b64e(HttpService:JSONEncode(self:Collect())) end
    function W:ImportCode(code)
        code = tostring(code or ""):gsub("%s", ""):gsub("^KH1:", "")
        if code == "" then return false end
        local ok, data = pcall(function() return HttpService:JSONDecode(b64d(code)) end)
        if not ok or type(data) ~= "table" then return false end
        self:_applyData(data)
        return true
    end

    function W:GetAutoMode()
        return (canFS and rf(W.Folder .. "/_automode.txt")) or self.MemAutoMode or "All accounts"
    end
    function W:SetAutoMode(m)
        if canFS then wf(W.Folder .. "/_automode.txt", m) else self.MemAutoMode = m end
    end
    function W:GetAutoload()
        if canFS then
            local a = rf(W.Folder .. "/_autoload_" .. LP.UserId .. ".txt")
            if a and a ~= "" then return a end
            local g = rf(W.Folder .. "/_autoload.txt")
            if g and g ~= "" then return g end
            return nil
        end
        return self.MemAuto
    end
    function W:SetAutoload(name)
        local acct = (self:GetAutoMode() == "This account")
        if canFS then
            wf(W.Folder .. "/_autoload.txt", (not acct and name) or "")
            wf(W.Folder .. "/_autoload_" .. LP.UserId .. ".txt", (acct and name) or "")
        else
            self.MemAuto = name
        end
    end

    -- ----- simpan pengaturan UI (id berawalan ui_) -----
    function W:SaveUI()
        if self.LoadingUI then return end
        local d = {}
        for id, el in pairs(self.Elements) do
            if id:find("^ui_") then
                local ok, v = pcall(el.Get, el)
                if ok and v ~= nil then d[id] = v end
            end
        end
        wf(W.Folder .. "/_ui.json", HttpService:JSONEncode(d))
    end
    function W:LoadUI()
        local json = rf(W.Folder .. "/_ui.json")
        if not json then return end
        local ok, d = pcall(function() return HttpService:JSONDecode(json) end)
        if not ok or type(d) ~= "table" then return end
        self.LoadingUI = true
        self:_applyData(d)
        self.LoadingUI = false
    end

    -- ----- tema kustom -----
    function W:LoadThemes()
        local json = rf(W.Folder .. "/themes.json")
        if not json then return end
        local ok, d = pcall(function() return HttpService:JSONDecode(json) end)
        if ok and type(d) == "table" then
            self.Themes = d.list or {}
            self.DefaultTheme = d.default
        end
    end
    function W:SaveThemes()
        wf(W.Folder .. "/themes.json", HttpService:JSONEncode({ list = self.Themes, default = self.DefaultTheme }))
    end
    function W:ThemeNames()
        local o = {}
        for k in pairs(self.Themes) do o[#o + 1] = k end
        table.sort(o)
        return o
    end
    W:LoadThemes()

    function W:Ready()
        for _, fn in ipairs(self.Pending) do pcall(fn) end
        self.Pending = {}
        if self.DefaultTheme and self.Themes[self.DefaultTheme] then self:SetPalette(self.Themes[self.DefaultTheme]) end
        local auto = self:GetAutoload()
        if auto and auto ~= "" then
            if self:LoadConfig(auto) then self:Notify({ Title = "Config", Desc = "Autoload: " .. auto, Color = "#50C864" }) end
        end
        if self.MinimizeOnStart then self:SetVisible(false) end
        self:_brand(); self:_island()
    end

    function W:OnUnload(fn) self.OnUnloads[#self.OnUnloads + 1] = fn end

    function W:Destroy()
        self.Alive = false
        for _, fn in ipairs(self.OnUnloads) do pcall(fn) end
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
        pcall(function() gui:Destroy() end)
    end

    return W
end

-- ===== Home =====
function Window:BuildHome(info, existing)
    info = info or {}
    local W = self
    local page = existing or W:AddPage({ Name = "Home", Icon = "house" })

    local function try(name, fn)
        local ok, err = pcall(fn)
        if not ok then
            warn("[KatssinnnUI] Home/" .. name .. ": " .. tostring(err))
            W:Notify({ Title = "Home: " .. name, Desc = tostring(err), Color = "#DC3232", Duration = 10 })
        end
    end

    ----- Welcome -----
    try("Welcome", function()
        local c1 = page:AddCard({ Title = "Welcome", Icon = "star", Column = 1 })
        local wf = c1:Custom(104)
        local avWrap = mk("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(92, 92), BackgroundTransparency = 1, Parent = wf })
        local av = mk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "rbxthumb://type=AvatarBust&id=" .. LP.UserId .. "&w=150&h=150", Parent = avWrap })
        local avP = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = "Row", BorderSizePixel = 0, Visible = false, Parent = avWrap })
        corner(avP, 12)
        local avPi = icon(avP, "user", 34, "Muted"); avPi.AnchorPoint = Vector2.new(0.5, 0.5); avPi.Position = UDim2.fromScale(0.5, 0.5)

        local l1 = label(wf, "WELCOME BACK", 10, "Muted", FB); l1.Size = UDim2.new(1, -100, 0, 12)
        local nm = label(wf, LP.DisplayName, 22, "Text", FB); nm.Position = UDim2.fromOffset(0, 16); nm.Size = UDim2.new(1, -100, 0, 28); nm.TextTruncate = Enum.TextTruncate.AtEnd
        local un = label(wf, "@" .. LP.Name, 12, "Muted", F); un.Position = UDim2.fromOffset(0, 46); un.Size = UDim2.new(1, -100, 0, 14); un.TextTruncate = Enum.TextTruncate.AtEnd

        local hiddenName, hiddenAvatar = false, false
        local chips = mk("Frame", { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, -100, 0, 28), BackgroundTransparency = 1, Parent = wf })
        list(chips, 6, Enum.FillDirection.Horizontal)
        local function chip(text, order)
            local b = mk("TextButton", { Size = UDim2.fromOffset(text == info.Version and 54 or 64, 28), BackgroundColor3 = "Field", BorderSizePixel = 0, Text = text, TextColor3 = "Text", Font = FM, TextSize = 11, AutoButtonColor = false, LayoutOrder = order, Parent = chips })
            corner(b, 7); local st = stroke(b, "Stroke", 1)
            return b, st
        end
        local vChip = chip(info.Version or "v1.0", 1)
        local nChip, nSt = chip("Name", 2)
        local aChip, aSt = chip("Avatar", 3)
        local function applyHide()
            nm.Text = hiddenName and "Hidden" or LP.DisplayName
            un.Text = hiddenName and "@hidden" or ("@" .. LP.Name)
            W.FooterName.Text = hiddenName and "Hidden" or LP.DisplayName
            av.Visible = not hiddenAvatar; avP.Visible = hiddenAvatar
            W.FooterAvatar.Visible = not hiddenAvatar; W.FooterAvatarHide.Visible = hiddenAvatar
            nChip.TextColor3 = hiddenName and Th.Accent or Th.Text; nSt.Color = hiddenName and Th.Accent or Th.Stroke
            aChip.TextColor3 = hiddenAvatar and Th.Accent or Th.Text; aSt.Color = hiddenAvatar and Th.Accent or Th.Stroke
        end
        nChip.MouseButton1Click:Connect(function() hiddenName = not hiddenName; applyHide() end)
        aChip.MouseButton1Click:Connect(function() hiddenAvatar = not hiddenAvatar; applyHide() end)
        W:_hook(applyHide)
        W.Elements["hide_name"] = { Default = false, Get = function() return hiddenName end, Set = function(_, v) hiddenName = v and true or false; applyHide() end }
        W.Elements["hide_avatar"] = { Default = false, Get = function() return hiddenAvatar end, Set = function(_, v) hiddenAvatar = v and true or false; applyHide() end }
        applyHide()
    end)

    ----- Performance (real-time) -----
    try("Performance", function()
        local c2 = page:AddCard({ Title = "Performance", Icon = "gauge", Column = 1 })
        local pf = c2:Custom(156)
        local N = 36
        local function half(x, title, color)
            local h = mk("Frame", { Position = UDim2.new(x, x == 0 and 0 or 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1, Parent = pf })
            local tl = label(h, title, 11, "Muted", FB); tl.Size = UDim2.new(1, 0, 0, 14)
            local big = label(h, "-", 24, "Text", FB); big.Position = UDim2.fromOffset(0, 14); big.Size = UDim2.new(1, 0, 0, 30); big.TextTruncate = Enum.TextTruncate.AtEnd
            local mm = label(h, "", 10, "Muted", F); mm.Position = UDim2.fromOffset(0, 44); mm.Size = UDim2.new(1, 0, 0, 12); mm.TextTruncate = Enum.TextTruncate.AtEnd
            local g = mk("Frame", { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, ClipsDescendants = true, Parent = h })
            local bars = {}
            for i = 1, N do
                bars[i] = mk("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((i - 1) / N, 0, 1, 0), Size = UDim2.new(1 / N, -1, 0, 0), BorderSizePixel = 0, BackgroundColor3 = color, Parent = g })
            end
            return big, mm, bars, h
        end
        local fpsBig, fpsMM, fpsBars, fh = half(0, "FPS", C("#F59E0B"))
        local pingBig, pingMM, pingBars, ph = half(0.5, "PING", C("#34D399"))
        local function foot(h, y)
            local a = label(h, "-", 13, "Text", FB); a.Position = UDim2.fromOffset(0, y); a.Size = UDim2.new(1, 0, 0, 16)
            return a
        end
        local plLbl = foot(fh, 118); local ssLbl = foot(ph, 118)
        local plSub = label(fh, "Players", 10, "Muted", F); plSub.Position = UDim2.fromOffset(0, 134); plSub.Size = UDim2.new(1, 0, 0, 12)
        local ssSub = label(ph, "Session", 10, "Muted", F); ssSub.Position = UDim2.fromOffset(0, 134); ssSub.Size = UDim2.new(1, 0, 0, 12)

        -- FPS: dihitung dari selisih waktu antar frame (bukan stat Roblox)
        local acc, frames = 0, 0
        W.Conns[#W.Conns + 1] = RunService.RenderStepped:Connect(function(dt) acc += dt; frames += 1 end)

        -- Ping: sampel langsung 4x/detik, nilai mentah (bukan angka tetap dari menu Roblox)
        local lastPing
        local function samplePing()
            local v
            pcall(function() v = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
            if type(v) ~= "number" or v <= 0 then pcall(function() v = LP:GetNetworkPing() * 1000 end) end
            if type(v) == "number" and v > 0 then
                lastPing = lastPing and (lastPing * 0.4 + v * 0.6) or v
            end
            return lastPing
        end

        local fpsH, pingH = {}, {}
        local t0 = os.clock()
        local function stat(h)
            if #h == 0 then return 0, 0, 0 end
            local mn, mx, sum = math.huge, 0, 0
            for _, v in ipairs(h) do mn = math.min(mn, v); mx = math.max(mx, v); sum += v end
            return mn, math.floor(sum / #h + 0.5), mx
        end
        local function paintBars(bars, h, cap)
            local off = N - #h
            for i, b in ipairs(bars) do
                local v = h[i - off]
                b.Size = UDim2.new(1 / N, -1, v and math.clamp(v / cap, 0.05, 1) or 0, 0)
            end
        end
        task.spawn(function()
            while W.Alive do
                task.wait(0.25)
                local fps = (acc > 0) and math.floor(frames / acc + 0.5) or 0
                acc, frames = 0, 0
                local ping = samplePing()
                ping = ping and math.floor(ping + 0.5) or 0
                fpsH[#fpsH + 1] = fps; pingH[#pingH + 1] = ping
                if #fpsH > N then table.remove(fpsH, 1) end
                if #pingH > N then table.remove(pingH, 1) end
                if W.Frame.Visible then
                    pcall(function()
                        local a, b, c = stat(fpsH)
                        fpsBig.Text = fps .. " fps"; fpsMM.Text = "min " .. a .. "  avg " .. b .. "  max " .. c
                        local a2, b2, c2 = stat(pingH)
                        pingBig.Text = ping .. " ms"; pingMM.Text = "min " .. a2 .. "  avg " .. b2 .. "  max " .. c2
                        paintBars(fpsBars, fpsH, math.max(60, c))
                        paintBars(pingBars, pingH, math.max(100, c2))
                        plLbl.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
                        local s = math.floor(os.clock() - t0)
                        ssLbl.Text = (s >= 3600) and (math.floor(s / 3600) .. "h " .. math.floor(s % 3600 / 60) .. "m") or (s >= 60) and (math.floor(s / 60) .. "m " .. (s % 60) .. "s") or (s .. "s")
                    end)
                end
            end
        end)
    end)

    ----- Game -----
    try("Game", function()
        local c3 = page:AddCard({ Title = "Game", Icon = "play", Column = 2 })
        local gf = c3:Custom(56)
        local gname, gcreator = info.Game or "Game", ""
        pcall(function()
            local pi = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
            gname = pi.Name or gname
            gcreator = pi.Creator and pi.Creator.Name or ""
        end)
        local gi = mk("ImageLabel", { Size = UDim2.fromOffset(52, 52), BackgroundColor3 = "Row", BorderSizePixel = 0, Image = "rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=150&h=150", Parent = gf })
        corner(gi, 9)
        local gn = label(gf, gname, 14, "Text", FB); gn.Position = UDim2.fromOffset(62, 8); gn.Size = UDim2.new(1, -64, 0, 18); gn.TextTruncate = Enum.TextTruncate.AtEnd
        local gs = label(gf, (gcreator ~= "" and ("by " .. gcreator) or "Roblox"), 11, "Muted", F)
        gs.Position = UDim2.fromOffset(62, 28); gs.Size = UDim2.new(1, -64, 0, 14); gs.TextTruncate = Enum.TextTruncate.AtEnd
        W.FooterGame.Text = gname

        local TS = game:GetService("TeleportService")
        local function servers(sort)
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=" .. sort .. "&limit=100"
            local ok, res = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
            if not ok or type(res) ~= "table" or not res.data then return nil end
            local out = {}
            for _, s in ipairs(res.data) do
                if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then out[#out + 1] = s end
            end
            return out
        end
        local function hop(sort, random)
            W:Notify({ Title = "Server", Desc = "Mencari server...", Color = "#6495ED" })
            task.spawn(function()
                local l = servers(sort)
                if not l or #l == 0 then
                    W:Notify({ Title = "Server", Desc = "Tidak ada server yang cocok / API tidak bisa diakses", Color = "#DC3232", Duration = 4 })
                    return
                end
                local s = random and l[math.random(1, #l)] or l[1]
                pcall(function() TS:TeleportToPlaceInstance(game.PlaceId, s.id, LP) end)
            end)
        end
        c3:Buttons({ Buttons = {
            { Text = "Rejoin", Callback = function()
                pcall(function()
                    if #Players:GetPlayers() <= 1 then TS:Teleport(game.PlaceId, LP) else TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end
                end)
            end },
            { Text = "Server Hop", Callback = function() hop("Desc", true) end },
        } })
        c3:Buttons({ Buttons = {
            { Text = "Lowest Server", Callback = function() hop("Asc", false) end },
            { Text = "Copy Job ID", Callback = function()
                if has(setclipboard) then setclipboard(game.JobId); W:Notify({ Title = "Job ID", Desc = "Disalin ke clipboard", Color = "#50C864" })
                else W:Notify({ Title = "Job ID", Desc = game.JobId, Color = "#6495ED", Duration = 6 }) end
            end },
        } })
    end)

    ----- Info -----
    try("Info", function()
        local c4 = page:AddCard({ Title = "Info", Icon = "activity", Column = 2 })
        local function kv(k, v)
            local f = c4:Custom(18)
            local a = label(f, k, 12, "Muted", F); a.Size = UDim2.new(0.4, 0, 1, 0)
            local b = label(f, v, 12, "Text", FM, Enum.TextXAlignment.Right); b.Position = UDim2.fromScale(0.4, 0); b.Size = UDim2.fromScale(0.6, 1); b.TextTruncate = Enum.TextTruncate.AtEnd
            return b
        end
        kv("Executor", (W.ExecName or (identifyexecutor and select(1, identifyexecutor())) or "Unknown"))
        kv("Place ID", tostring(game.PlaceId))
        kv("Job ID", string.sub(game.JobId, 1, 13) .. (#game.JobId > 13 and "…" or ""))
        kv("Device", isTouch() and "Mobile" or "PC")
        local scr = kv("Screen", "")
        local function upd() local vp = viewport(); scr.Text = math.floor(vp.X) .. "×" .. math.floor(vp.Y) end
        upd()
        pcall(function() W.Conns[#W.Conns + 1] = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(upd) end)
    end)

    try("Settings", function() W:BuildSettings() end)
    return page
end

-- ===== Settings =====
function Window:BuildSettings()
    local W = self
    if W.Pages["Settings"] then return W.Pages["Settings"] end
    local page = W:AddPage({ Name = "Settings", Icon = "settings" })
    local function ui(cb) return function(v) pcall(cb, v); W:SaveUI() end end
    local function N(t, d, c, dur) W:Notify({ Title = t, Desc = d or "", Color = c or "#6495ED", Duration = dur or 3 }) end

    ----- Menu -----
    local cm = page:AddCard({ Title = "Menu", Icon = "monitor", Column = 1 })
    cm:Keybind({ Title = "Toggle UI", Value = W.ToggleKey, id = "ui_key", OnChanged = ui(function(k) W.ToggleKey = k end) })
    cm:Dropdown({ Title = "Toggle button", List = { "Always", "Mobile only", "Hidden" }, Value = "Always", id = "ui_togglebtn",
        Callback = ui(function(v) if v then W:SetToggleMode(v) end end) })
    local afkOn = false
    pcall(function()
        LP.Idled:Connect(function()
            if not afkOn then return end
            local vu = game:GetService("VirtualUser")
            vu:CaptureController(); vu:ClickButton2(Vector2.new())
        end)
    end)
    cm:Toggle({ Title = "Anti AFK", Value = false, id = "anti_afk", Callback = function(v) afkOn = v end })
    cm:Toggle({ Title = "Minimize UI on Start", Value = false, id = "ui_minstart", Callback = ui(function(v) W.MinimizeOnStart = v end) })
    cm:Button({ Text = "Unload", Icon = "power", Color = "#E5484D", Callback = function() W:Destroy() end })

    ----- Configs -----
    local cc = page:AddCard({ Title = "Configs", Icon = "folder", Column = 1 })
    local lf = cc:Custom(112)
    local box = mk("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = "Field", BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = "Stroke",
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = lf,
    })
    corner(box, 8); stroke(box, "Stroke", 1); pad(box, 4); list(box, 2)
    local status = cc:Label({ Text = "-" })
    local cname = cc:Input({ Title = "Config Name:", Placeholder = "Type config name here..." })
    local selCfg
    local tgAuto
    local function refresh()
        for _, c in ipairs(box:GetChildren()) do if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end end
        local l = W:ListConfigs()
        if #l == 0 then
            local e = label(box, "no configs yet", 12, "Muted", FM, Enum.TextXAlignment.Center)
            e.Size = UDim2.new(1, 0, 0, 40)
        end
        for i, nm in ipairs(l) do
            local on = (nm == selCfg)
            local b = mk("TextButton", { Size = UDim2.new(1, -4, 0, 26), BackgroundColor3 = "Row", BackgroundTransparency = on and 0 or 1, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = box })
            corner(b, 6)
            local t = label(b, nm, 12, on and Th.Accent or Th.Text, FM); t.Position = UDim2.fromOffset(10, 0); t.Size = UDim2.new(1, -14, 1, 0)
            b.MouseButton1Click:Connect(function() selCfg = nm; cname:Set(nm, true); refresh() end)
        end
        status:SetText(#l .. " saved  ·  loaded: " .. (W.LoadedCfg or "none") .. "  ·  auto: " .. (W:GetAutoload() or "none"))
        if tgAuto then tgAuto:Set(W:GetAutoload() ~= nil, true) end
    end
    local function pick()
        local n = cname:Get()
        if n ~= "" then return n end
        return selCfg
    end
    cc:Buttons({ Buttons = {
        { Text = "Save", Callback = function()
            local n = pick()
            if not n or n == "" then N("Config", "Isi nama atau pilih config", "#FFA500") return end
            local ok = W:SaveConfig(n); selCfg = n; refresh()
            N(ok and "Saved" or "Gagal", n .. (W.CanFS and "" or " (sementara, executor tanpa writefile)"), ok and "#50C864" or "#DC3232")
        end },
        { Text = "Load", Callback = function()
            local n = selCfg or cname:Get()
            if not n or n == "" then N("Config", "Pilih config dulu", "#FFA500") return end
            local ok = W:LoadConfig(n); refresh()
            N(ok and "Loaded" or "Gagal", n, ok and "#50C864" or "#DC3232")
        end },
    } })
    cc:Buttons({ Buttons = {
        { Text = "Delete", Color = "#E5484D", Callback = function()
            if not selCfg then return end
            local n = selCfg; W:DeleteConfig(n); selCfg = nil; refresh()
            N("Deleted", n, "#DC3232")
        end },
        { Text = "Refresh", Callback = refresh },
    } })
    tgAuto = cc:Toggle({ Title = "Auto Load Config", Desc = "Loads the selected config on launch", Callback = function(v)
        if v then
            local n = selCfg or W.LoadedCfg
            if not n then N("Auto Load", "Pilih / load config dulu", "#FFA500"); tgAuto:Set(false, true) return end
            W:SetAutoload(n); N("Auto Load", n, "#50C864")
        else
            W:SetAutoload(nil)
        end
        refresh()
    end })
    cc:Divider("more")
    cc:Buttons({ Buttons = {
        { Text = "Rename", Callback = function()
            local n = cname:Get()
            if not selCfg or n == "" or n == selCfg then N("Rename", "Pilih config lalu ketik nama baru", "#FFA500") return end
            local ok = W:RenameConfig(selCfg, n)
            if ok then selCfg = n end
            refresh(); N(ok and "Renamed" or "Gagal", n, ok and "#50C864" or "#DC3232")
        end },
        { Text = "Reset", Color = "#E5484D", Callback = function() W:ResetAll(); N("Reset", "Semua fitur dikembalikan ke default", "#FFA500") end },
    } })
    cc:Dropdown({ Title = "Autoload mode", List = { "All accounts", "This account" }, Value = W:GetAutoMode(), id = "ui_automode",
        Callback = ui(function(v)
            if not v then return end
            local cur = W:GetAutoload()
            W:SetAutoMode(v)
            if cur then W:SetAutoload(cur) end
        end) })
    cc:Divider("share")
    cc:Button({ Text = "Copy code", Icon = "copy", Callback = function()
        local code = W:ExportCode()
        if has(setclipboard) then setclipboard(code); N("Config code", "Disalin ke clipboard", "#50C864")
        else N("Config code", code, "#6495ED", 8) end
    end })
    local pasted = cc:Input({ Placeholder = "paste a config code..." })
    cc:Button({ Text = "Import code", Icon = "download", Callback = function()
        local ok = W:ImportCode(pasted:Get())
        N(ok and "Imported" or "Gagal", ok and "Config code diterapkan" or "Kode tidak valid", ok and "#50C864" or "#DC3232")
    end })
    refresh()

    ----- Themes -----
    local ct = page:AddCard({ Title = "Themes", Icon = "palette", Column = 2 })
    local colorEls = {}
    local function syncColors()
        local p = W:GetPalette()
        for k, el in pairs(colorEls) do el:Set(p[k], true) end
    end
    ct:Dropdown({ Title = "Preset", List = THEME_LIST, Placeholder = "Select preset", Callback = ui(function(v)
        if v and THEMES[v] then W:SetPalette(THEMES[v]); syncColors() end
    end) })
    local ddTheme
    local defLbl
    local function refreshThemes()
        ddTheme:SetList(W:ThemeNames())
        defLbl:SetText("Default theme: " .. (W.DefaultTheme or "none"))
    end
    ct:Input({ Placeholder = "theme name", ButtonText = "Create", id = nil, OnButton = function(name)
        name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then N("Theme", "Isi nama theme", "#FFA500") return end
        W.Themes[name] = W:GetPalette(); W:SaveThemes(); refreshThemes(); ddTheme:Set(name, true)
        N("Theme", "Dibuat: " .. name, "#50C864")
    end })
    ddTheme = ct:Dropdown({ Title = "Theme", List = W:ThemeNames(), Placeholder = "no themes" })
    ct:Buttons({ Buttons = {
        { Text = "Save", Callback = function()
            local n = ddTheme:Get()
            if not n then N("Theme", "Pilih theme dulu", "#FFA500") return end
            W.Themes[n] = W:GetPalette(); W:SaveThemes(); N("Theme", "Disimpan: " .. n, "#50C864")
        end },
        { Text = "Load", Callback = function()
            local n = ddTheme:Get()
            if not n or not W.Themes[n] then N("Theme", "Pilih theme dulu", "#FFA500") return end
            W:SetPalette(W.Themes[n]); syncColors(); W:SaveUI()
        end },
    } })
    ct:Buttons({ Buttons = {
        { Text = "Delete", Color = "#E5484D", Callback = function()
            local n = ddTheme:Get()
            if not n then return end
            W.Themes[n] = nil
            if W.DefaultTheme == n then W.DefaultTheme = nil end
            W:SaveThemes(); ddTheme:Set(nil, true); refreshThemes()
        end },
        { Text = "Set Default", Callback = function()
            local n = ddTheme:Get()
            if not n then N("Theme", "Pilih theme dulu", "#FFA500") return end
            W.DefaultTheme = n; W:SaveThemes(); refreshThemes(); N("Theme", "Default: " .. n, "#50C864")
        end },
    } })
    defLbl = ct:Label({ Text = "Default theme: " .. (W.DefaultTheme or "none"), Size = 12 })
    local P = W:GetPalette()
    for _, k in ipairs({ "Accent", "Background", "Surface", "Text", "Muted" }) do
        colorEls[k] = ct:Color({ Title = k == "Muted" and "Muted text" or k, Value = P[k], Callback = ui(function(c) W:SetPalette({ [k] = c }) end) })
    end
    W.Elements["ui_palette"] = {
        Get = function() return W:GetPalette() end,
        Set = function(_, v) if type(v) == "table" then W:SetPalette(v); syncColors() end end,
    }

    ----- Display -----
    local cd = page:AddCard({ Title = "Display", Icon = "layout-dashboard", Column = 2 })
    cd:Dropdown({ Title = "Weather", List = { "None", "Snow", "Rain", "Sakura" }, Value = "None", id = "ui_weather", Callback = ui(function(v) W:SetWeather(v) end) })
    cd:Dropdown({ Title = "Weather Mode", List = { "Window", "Screen" }, Value = "Window", id = "ui_weathermode", Callback = ui(function(v) if v then W:SetWeatherMode(v) end end) })
    cd:Toggle({ Title = "Dim", Value = false, id = "ui_dim", Callback = ui(function(v) W:SetDim(v) end) })
    cd:Toggle({ Title = "Transparent", Desc = "Menu tembus pandang, gameplay tetap terlihat", Value = false, id = "ui_transparent", Callback = ui(function(v) W:SetTransparent(v) end) })
    cd:Slider({ Title = "Transparency", Min = 5, Max = 50, Value = 22, Rounding = 0, Suffix = "%", id = "ui_transamt", Callback = ui(function(v) W:SetTransparentAmount(v / 100) end) })
    cd:Dropdown({ Title = "Drag Style", List = { "Normal", "Outline" }, Value = "Normal", id = "ui_drag", Callback = ui(function(v) if v then W:SetDragStyle(v) end end) })
    cd:Dropdown({ Title = "Dynamic Island", List = { "Always", "Show on Hover", "Hidden" }, Value = "Always", id = "ui_island", Callback = ui(function(v) if v then W:SetIslandMode(v) end end) })
    cd:Toggle({ Title = "Adaptive Size", Value = true, id = "ui_adaptive", Callback = ui(function(v) W.Adaptive = v; W:ApplyScale() end) })
    cd:Slider({ Title = "UI Scale", Min = 50, Max = 150, Value = 100, Rounding = 0, Suffix = "%", id = "ui_scale", Callback = ui(function(v) W.UIScaleMul = v / 100; W:ApplyScale() end) })
    cd:Dropdown({ Title = "Density", List = { "Compact", "Default", "Comfortable" }, Value = "Default", id = "ui_density", Callback = ui(function(v) if v then W:SetDensity(v) end end) })
    cd:Slider({ Title = "Corner Radius", Min = 0, Max = 16, Value = 8, Rounding = 0, Suffix = "px", id = "ui_corner", Callback = ui(function(v) W:SetCorner(v) end) })

    local ddBg, inBg
    local function applyBg()
        local mode, text = ddBg:Get(), (inBg:Get() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if mode ~= "Image" or text == "" then W:SetBackground(nil) return end
        local src
        if text:match("^%d+$") then src = "rbxassetid://" .. text
        elseif text:match("^rbxassetid://") or text:match("^rbxasset://") then src = text
        elseif text:match("^https?://") and has(writefile) and has(getcustomasset) then
            local ok, res = pcall(function()
                local data = game:HttpGet(text)
                local p = W.Folder .. "/bg.png"
                writefile(p, data)
                return getcustomasset(p)
            end)
            if ok then src = res else N("Background", "Gagal download gambar", "#DC3232") return end
        else
            N("Background", "Pakai asset id (angka) atau URL (butuh writefile)", "#FFA500") return
        end
        W:SetBackground(src)
    end
    ddBg = cd:Dropdown({ Title = "Background", List = { "None", "Image" }, Value = "None", id = "ui_bg", Callback = ui(function() applyBg() end) })
    inBg = cd:Input({ Placeholder = "image id or url", ButtonText = "Set", id = "ui_bgsrc", Callback = ui(function() applyBg() end), OnButton = function() applyBg(); W:SaveUI() end })
    cd:Slider({ Title = "Background Opacity", Min = 0, Max = 100, Value = 40, Rounding = 0, Suffix = "%", id = "ui_bgop", Callback = ui(function(v) W:SetBackgroundOpacity(v) end) })

    W:LoadUI()
    return page
end

Lib.Presets = PRESETS
Lib.Themes = THEMES
Lib.Logo = LOGO
return Lib
