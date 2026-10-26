-- KatssinnnUI v2 | sidebar (Home / Main / Player / Settings), kartu dua kolom, Dynamic Island, tema, config.
-- Dipakai lewat: local UI = loadstring(game:HttpGet(".../ui.lua"))()
--
-- * Responsif: ukuran window & jumlah kolom menyesuaikan layar (HP portrait / landscape / PC).
-- * Saat config / nilai tersimpan dipulihkan, SEMUA elemen memanggil Callback-nya lagi
--   (toggle yang terlihat ON benar-benar menjalankan fiturnya).

local Players       = game:GetService("Players")
local UIS           = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local HttpService   = game:GetService("HttpService")
local LP            = Players.LocalPlayer

local Lib = {}
local Window = {}
Window.__index = Window

local LOGO = "rbxassetid://88144642735093"

local function C(h)
    local ok, r = pcall(Color3.fromHex, h)
    return ok and r or Color3.new(1, 1, 1)
end

-- ===== tema =====
-- { Accent, Background, Surface, Text, Muted }
local PRESETS = {
    Pink     = { "#FF007F", "#151515", "#1B1B1B", "#F3F3EE", "#8B8B85" },
    Midnight = { "#80A0F6", "#0F121A", "#161A25", "#E4E8F2", "#7F899D" },
    Lime     = { "#B4F34A", "#101010", "#1A1A1A", "#F3F3EE", "#8B8B85" },
    Purple   = { "#9955FF", "#13111A", "#1B1824", "#EEEAF7", "#8A849A" },
    Red      = { "#E5484D", "#141010", "#1D1717", "#F5EDED", "#9A8888" },
    Cyan     = { "#22D3EE", "#0E1417", "#151D21", "#E8F4F7", "#7E959C" },
}
local PRESET_LIST = { "Pink", "Midnight", "Lime", "Purple", "Red", "Cyan" }
local THEME_KEYS = { "Accent", "Background", "Surface", "Text", "Muted" }

local TH: { [string]: any } = {}
local REG, CR, DENS = {}, {}, {}
local STATE = { Radius = 8, Density = 0 }

local function derive()
    local W, K = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
    TH.Side   = TH.Background:Lerp(K, 0.28)
    TH.Card   = TH.Surface
    TH.Head   = TH.Surface:Lerp(W, 0.035)
    TH.Row    = TH.Surface:Lerp(W, 0.07)
    TH.RowHi  = TH.Surface:Lerp(W, 0.12)
    TH.Field  = TH.Background:Lerp(K, 0.18)
    TH.Stroke = TH.Surface:Lerp(W, 0.10)
    TH.Off    = TH.Surface:Lerp(W, 0.20)
    TH.Knob   = TH.Muted:Lerp(W, 0.25)
    TH.OnKnob = TH.Background
end

local function setPreset(name)
    local p = PRESETS[name] or PRESETS.Pink
    for i, k in ipairs(THEME_KEYS) do TH[k] = C(p[i]) end
    derive()
end
setPreset("Pink")

local F, FB, FM = Enum.Font.Gotham, Enum.Font.GothamBold, Enum.Font.GothamMedium

-- ===== helpers =====
local function mk(class, props)
    local o = Instance.new(class)
    local parent, bm
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v
        elseif k == "B" then bm = v
        else o[k] = v end
    end
    if bm then
        for p, key in pairs(bm) do
            REG[#REG + 1] = { o, p, key }
            o[p] = TH[key]
        end
    end
    if parent then o.Parent = parent end
    return o
end

local function repaint()
    for _, r in ipairs(REG) do pcall(function() r[1][r[2]] = TH[r[3]] end) end
end

local function corner(o, r) return mk("UICorner", { CornerRadius = UDim.new(0, r), Parent = o }) end
local function cornerL(o)
    local c = mk("UICorner", { CornerRadius = UDim.new(0, STATE.Radius), Parent = o })
    CR[#CR + 1] = { c, 0 }
    return c
end
local function cornerS(o)
    local c = mk("UICorner", { CornerRadius = UDim.new(0, math.max(0, STATE.Radius - 3)), Parent = o })
    CR[#CR + 1] = { c, 3 }
    return c
end
local function applyRadius()
    for _, e in ipairs(CR) do pcall(function() e[1].CornerRadius = UDim.new(0, math.max(0, STATE.Radius - e[2])) end) end
end
local function stroke(o, key, th)
    return mk("UIStroke", { B = { Color = key or "Stroke" }, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o })
end
local function pad(o, l, t, r, b)
    return mk("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l), PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l), Parent = o })
end
local function list(o, gap, dir)
    return mk("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = dir or Enum.FillDirection.Vertical, Parent = o })
end
local function listD(o, gap)       -- list yang jaraknya ikut pengaturan Density
    local l = list(o, gap)
    DENS[#DENS + 1] = { l, gap }
    l.Padding = UDim.new(0, math.max(0, gap + STATE.Density))
    return l
end
local function applyDensity()
    for _, e in ipairs(DENS) do pcall(function() e[1].Padding = UDim.new(0, math.max(0, e[2] + STATE.Density)) end) end
end

local function col3(c, default)
    if c == nil then return default end
    if type(c) == "string" then
        local ok, r = pcall(Color3.fromHex, c)
        return ok and r or default
    end
    return c
end

-- key = nama warna tema ("Text", "Muted", "Accent"...) atau Color3 / hex
local function label(parent, text, size, key, font, xa)
    local props = {
        BackgroundTransparency = 1, Text = tostring(text), TextSize = size or 12,
        Font = font or FM, TextXAlignment = xa or Enum.TextXAlignment.Left, Parent = parent,
    }
    if type(key) == "string" and TH[key] then props.B = { TextColor3 = key }
    else props.TextColor3 = col3(key, TH.Text) end
    return mk("TextLabel", props)
end

local function tw(o, t, props)
    local ok = pcall(function()
        TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
    end)
    if not ok then for k, v in pairs(props) do pcall(function() o[k] = v end) end end
end
local function has(f) return typeof(f) == "function" end
local function isTouch() local ok, r = pcall(function() return UIS.TouchEnabled end) return ok and r end

local function hexOf(c)
    local function h(x) return string.format("%02X", math.clamp(math.floor(x * 255 + 0.5), 0, 255)) end
    return "#" .. h(c.R) .. h(c.G) .. h(c.B)
end
local function parseHex(s)
    s = tostring(s or ""):gsub("%s", ""):gsub("^#", "")
    if #s == 3 then s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2) end
    if #s ~= 6 or s:find("[^%x]") then return nil end
    return C("#" .. s)
end

-- base64 sederhana (untuk "config code")
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64enc(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2, c3, c4 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1) ..
            (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end
local function b64dec(s)
    s = s:gsub("[^%w%+/=]", "")
    local out = {}
    for i = 1, #s, 4 do
        local n, pads = 0, 0
        for j = 0, 3 do
            local ch = s:sub(i + j, i + j)
            if ch == "=" or ch == "" then pads += 1; n = n * 64
            else n = n * 64 + ((B64:find(ch, 1, true) or 1) - 1) end
        end
        local b1, b2, b3 = math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256
        out[#out + 1] = string.char(b1)
        if pads < 2 then out[#out + 1] = string.char(b2) end
        if pads < 1 then out[#out + 1] = string.char(b3) end
    end
    return table.concat(out)
end

-- ikon kecil yang digambar dari Frame (tidak butuh aset gambar)
local function magnifier(parent, x, y)
    local f = mk("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Parent = parent })
    local c = mk("Frame", { Size = UDim2.fromOffset(9, 9), BackgroundTransparency = 1, Parent = f })
    corner(c, 5); mk("UIStroke", { B = { Color = "Muted" }, Thickness = 1.5, Parent = c })
    local h = mk("Frame", { Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(5, 1.5), Rotation = 45, BorderSizePixel = 0, B = { BackgroundColor3 = "Muted" }, Parent = f })
    return f
end

local function gridIcon(parent, size, anchored)   -- 4 kotak (logo tombol)
    local f = mk("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Parent = parent })
    if anchored then f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.fromScale(0.5, 0.5) end
    local s = math.floor(size * 0.4)
    for i = 0, 3 do
        local q = mk("Frame", {
            Position = UDim2.fromOffset((i % 2) * (size - s), math.floor(i / 2) * (size - s)),
            Size = UDim2.fromOffset(s, s), BackgroundTransparency = 1, Parent = f,
        })
        corner(q, 3)
        mk("UIStroke", { B = { Color = "Accent" }, Thickness = 2, Parent = q })
    end
    return f
end

local function chevron(parent, key)    -- panah kecil; Rotation: 0 = kanan, 90 = bawah, -90 = atas
    local l = label(parent, "›", 18, key or "Muted", FB, Enum.TextXAlignment.Center)
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    return l
end

-- ===== Window =====
function Lib:CreateWindow(opts)
    opts = opts or {}
    REG, CR, DENS = {}, {}, {}
    STATE.Radius, STATE.Density = 8, 0
    setPreset(opts.Theme or "Pink")
    if opts.Accent then TH.Accent = col3(opts.Accent, TH.Accent) end

    local W = setmetatable({}, Window)
    W.Opts        = opts
    W.Accent      = TH.Accent
    W.Elements    = {}
    W.Order       = {}            -- id elemen sesuai urutan dibuat
    W.Pages       = {}
    W.PageList    = {}
    W.OnUnloads   = {}
    W.Pending     = {}
    W.Hooks       = {}
    W.Features    = {}
    W.ToggleList  = {}
    W.ToggleKey   = opts.ToggleKey or Enum.KeyCode.RightControl
    W.UIScaleMul  = 1
    W.Adaptive    = true
    W.Dim         = false
    W.Transparent = false
    W.DragStyle   = "Normal"
    W.BtnMode     = "Always"
    W.IslandMode  = "Always"
    W.Folder      = opts.Folder or "KatssinnnHub"
    W.Mem         = {}
    W.MemThemes   = {}
    W.Alive       = true
    W.Conns       = {}
    W.Title       = opts.Title or "KatssinnnHub"
    W.HideName, W.HideAvatar = false, false
    W.NameLabels, W.AvatarImgs = {}, {}

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

    -- lapisan di belakang window: cuaca (mode Screen) + redup
    local weatherScreen = mk("Frame", { Name = "WeatherScreen", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false, Parent = gui })
    local dim = mk("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, Visible = false, Active = false, Parent = gui })
    W.WeatherScreen, W.DimFrame = weatherScreen, dim

    local frame = mk("Frame", {
        Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(760, 430), BorderSizePixel = 0, B = { BackgroundColor3 = "Background" }, Parent = gui,
    })
    cornerL(frame); stroke(frame)
    W.Frame = frame
    local uiscale = mk("UIScale", { Parent = frame })
    W.UIScale = uiscale

    -- ===== sidebar =====
    local side = mk("Frame", { Name = "Side", Size = UDim2.new(0, 150, 1, 0), BorderSizePixel = 0, B = { BackgroundColor3 = "Side" }, Parent = frame })
    cornerL(side)
    mk("Frame", { Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -14, 0, 0), BorderSizePixel = 0, B = { BackgroundColor3 = "Side" }, Parent = side })
    W.Side = side

    local brand = mk("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, Active = true, Parent = side })
    local logo = mk("ImageLabel", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(12, 15), BackgroundTransparency = 1, Image = LOGO, ScaleType = Enum.ScaleType.Fit, Parent = brand })
    corner(logo, 8)
    local bt = label(brand, W.Title, 13, "Text", FB)
    bt.Position = UDim2.fromOffset(54, 17); bt.Size = UDim2.new(1, -58, 0, 16); bt.TextTruncate = Enum.TextTruncate.AtEnd
    local bv = label(brand, opts.Version or "v1.0", 10, "Muted", F)
    bv.Position = UDim2.fromOffset(54, 34); bv.Size = UDim2.new(1, -58, 0, 12)
    W.BrandLogo, W.BrandText, W.BrandVer = logo, bt, bv

    local nav = mk("Frame", { Name = "Nav", Position = UDim2.fromOffset(8, 70), Size = UDim2.new(1, -16, 1, -142), BackgroundTransparency = 1, Parent = side })
    list(nav, 4)

    local foot = mk("TextButton", { Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 1, -58), Text = "", AutoButtonColor = false, BorderSizePixel = 0, B = { BackgroundColor3 = "Card" }, Parent = side })
    cornerL(foot); stroke(foot)
    local av = mk("ImageLabel", {
        Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(8, 10), BorderSizePixel = 0, B = { BackgroundColor3 = "Row" },
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. LP.UserId .. "&w=150&h=150", Parent = foot,
    })
    corner(av, 15)
    local dot = mk("Frame", { Size = UDim2.fromOffset(9, 9), Position = UDim2.fromOffset(31, 31), BackgroundColor3 = Color3.fromRGB(80, 200, 100), BorderSizePixel = 0, Parent = foot })
    corner(dot, 5); mk("UIStroke", { B = { Color = "Card" }, Thickness = 2, Parent = dot })
    local fn = label(foot, LP.DisplayName, 11, "Text", FB)
    fn.Position = UDim2.fromOffset(46, 9); fn.Size = UDim2.new(1, -66, 0, 14); fn.TextTruncate = Enum.TextTruncate.AtEnd
    local fg = label(foot, opts.Game or "", 9, "Muted", F)
    fg.Position = UDim2.fromOffset(46, 25); fg.Size = UDim2.new(1, -66, 0, 12); fg.TextTruncate = Enum.TextTruncate.AtEnd
    local fch = chevron(foot); fch.Position = UDim2.new(1, -12, 0.5, 0); fch.Size = UDim2.fromOffset(14, 20)
    W.FooterGame, W.FooterName, W.FooterAvatar, W.FooterChev, W.Footer = fg, fn, av, fch, foot
    W.NameLabels[#W.NameLabels + 1] = { fn, LP.DisplayName }
    W.AvatarImgs[#W.AvatarImgs + 1] = av

    -- ===== konten =====
    local content = mk("Frame", { Name = "Content", Position = UDim2.fromOffset(150, 0), Size = UDim2.new(1, -150, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = frame })
    W.Content = content
    local bgImg = mk("ImageLabel", { Name = "BG", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ImageTransparency = 1, ScaleType = Enum.ScaleType.Crop, Image = "", Parent = content })
    W.BgImage = bgImg

    local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Active = true, Parent = content })
    W.HeaderIcon = label(header, "", 17, "Accent", FB, Enum.TextXAlignment.Center)
    W.HeaderIcon.Position = UDim2.fromOffset(14, 0); W.HeaderIcon.Size = UDim2.new(0, 24, 1, 0)
    W.HeaderTitle = label(header, "", 17, "Text", FM)
    W.HeaderTitle.Position = UDim2.fromOffset(44, 0); W.HeaderTitle.Size = UDim2.new(0.4, 0, 1, 0)

    local minBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 1, Text = "–", Font = FB, TextSize = 18, B = { TextColor3 = "Muted" }, Parent = header,
    })
    local searchBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, 0), Size = UDim2.fromOffset(180, 30),
        Text = "", AutoButtonColor = false, BorderSizePixel = 0, B = { BackgroundColor3 = "Field" }, Parent = header,
    })
    cornerS(searchBtn); stroke(searchBtn)
    magnifier(searchBtn, 10, 8)
    local searchTx = label(searchBtn, "Search", 12, "Muted", FM)
    searchTx.Position = UDim2.fromOffset(32, 0); searchTx.Size = UDim2.new(1, -36, 1, 0)
    W.SearchBtn, W.SearchTx = searchBtn, searchTx
    searchBtn.MouseButton1Click:Connect(function() W:OpenFeatures() end)

    local holder = mk("Frame", { Name = "Pages", Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56), BackgroundTransparency = 1, ClipsDescendants = true, Parent = content })
    W.Holder = holder

    -- ===== drag window =====
    local outline
    local function dragWin(handle)
        local dragging, startIn, startPos = false, nil, nil
        handle.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging, startIn, startPos = true, i.Position, frame.Position
                if W.DragStyle == "Outline" then
                    outline = mk("Frame", {
                        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0,
                        Size = UDim2.fromOffset(frame.AbsoluteSize.X, frame.AbsoluteSize.Y),
                        Position = UDim2.fromOffset(frame.AbsolutePosition.X + frame.AbsoluteSize.X / 2, frame.AbsolutePosition.Y + frame.AbsoluteSize.Y / 2),
                        Parent = gui,
                    })
                    corner(outline, STATE.Radius)
                    mk("UIStroke", { B = { Color = "Accent" }, Thickness = 2, Parent = outline })
                end
                i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then
                        if dragging and outline and W.LastDrag then
                            local d, sc = W.LastDrag, uiscale.Scale
                            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X / sc, startPos.Y.Scale, startPos.Y.Offset + d.Y / sc)
                        end
                        dragging = false
                        if outline then outline:Destroy(); outline = nil end
                    end
                end)
            end
        end)
        W.Conns[#W.Conns + 1] = UIS.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - startIn
                W.LastDrag = d
                if outline then
                    outline.Position = UDim2.fromOffset(frame.AbsolutePosition.X + frame.AbsoluteSize.X / 2 + d.X, frame.AbsolutePosition.Y + frame.AbsoluteSize.Y / 2 + d.Y)
                else
                    local sc = uiscale.Scale
                    frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X / sc, startPos.Y.Scale, startPos.Y.Offset + d.Y / sc)
                end
            end
        end)
    end
    dragWin(header); dragWin(brand)

    -- ===== tema / accent =====
    function W:Repaint()
        repaint()
        self.Accent = TH.Accent
        for _, h in ipairs(self.Hooks) do pcall(h) end
    end
    function W:_hook(fn) self.Hooks[#self.Hooks + 1] = fn end
    function W:GetTheme() local t = {}; for _, k in ipairs(THEME_KEYS) do t[k] = hexOf(TH[k]) end return t end
    function W:SetThemeColor(key, col)
        col = col3(col)
        if not col or not TH[key] then return end
        TH[key] = col; derive(); self:Repaint()
    end
    function W:ApplyTheme(t)
        if type(t) == "string" then
            if not PRESETS[t] then return end
            setPreset(t)
        elseif type(t) == "table" then
            for _, k in ipairs(THEME_KEYS) do
                local c = t[k] and col3(t[k])
                if c then TH[k] = c end
            end
            derive()
        end
        self:Repaint()
        if self.OnThemeChanged then pcall(self.OnThemeChanged) end
    end
    function W:SetAccent(col)   -- kompatibel dengan versi lama: nama preset / hex / Color3
        if type(col) == "string" and PRESETS[col] then self:ApplyTheme(col) return end
        self:SetThemeColor("Accent", col)
    end

    -- ===== skala & layout responsif =====
    local function vpSize()
        local cam = workspace.CurrentCamera
        return cam and cam.ViewportSize or Vector2.new(1280, 720)
    end
    function W:ApplyScale()
        local vp = vpSize()
        local s = 1
        if self.Adaptive then s = math.clamp(math.min(vp.X / 800, vp.Y / 450), 0.75, 1.25) end
        s = s * self.UIScaleMul
        uiscale.Scale = s
        local dw = math.clamp((vp.X - 16) / s, 300, 760)
        local dh = math.clamp((vp.Y - 16) / s, 240, 430)
        frame.Size = UDim2.fromOffset(dw, dh)
        self.DW, self.DH = dw, dh
        self:Relayout()
    end
    function W:Relayout()
        local dw = self.DW or 760
        local compact = dw < 620
        local sw = compact and 56 or 150
        self.Compact = compact
        side.Size = UDim2.new(0, sw, 1, 0)
        content.Position = UDim2.fromOffset(sw, 0)
        content.Size = UDim2.new(1, -sw, 1, 0)
        bt.Visible = not compact; bv.Visible = not compact
        logo.Position = compact and UDim2.new(0.5, -17, 0, 15) or UDim2.fromOffset(12, 15)
        fn.Visible = not compact; fg.Visible = not compact; fch.Visible = not compact
        av.Position = compact and UDim2.new(0.5, -15, 0.5, -15) or UDim2.fromOffset(8, 10)
        dot.Position = compact and UDim2.new(0.5, 6, 0.5, 6) or UDim2.fromOffset(31, 31)
        foot.Size = compact and UDim2.new(1, -12, 0, 46) or UDim2.new(1, -16, 0, 50)
        foot.Position = compact and UDim2.new(0, 6, 1, -54) or UDim2.new(0, 8, 1, -58)
        searchBtn.Size = UDim2.fromOffset(compact and 34 or 180, 30)
        searchTx.Visible = not compact
        for _, p in ipairs(self.PageList) do
            p.NavText.Visible = not compact
            p.NavIcon.Position = compact and UDim2.new(0.5, -12, 0, 0) or UDim2.fromOffset(8, 0)
        end
        local single = (dw - sw) < 470
        self.Single = single
        for _, p in ipairs(self.PageList) do p:Reflow(single) end
    end
    W:ApplyScale()
    pcall(function()
        W.Conns[#W.Conns + 1] = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() W:ApplyScale() end)
    end)

    -- ===== tombol kotak + Dynamic Island =====
    local fbtn = mk("TextButton", {
        Name = "Toggle", Position = UDim2.new(0, 14, 0.5, -24), Size = UDim2.fromOffset(48, 48),
        Text = "", AutoButtonColor = false, BorderSizePixel = 0, B = { BackgroundColor3 = "Side" }, Parent = gui,
    })
    cornerL(fbtn); stroke(fbtn)
    local fgrid = gridIcon(fbtn, 24, true)
    local fimg = mk("ImageLabel", { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1, Image = LOGO, ScaleType = Enum.ScaleType.Fit, Visible = false, Parent = fbtn })
    corner(fimg, 8)

    local island = mk("TextButton", {
        Name = "Island", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(200, 38),
        Text = "", AutoButtonColor = false, ClipsDescendants = true, BorderSizePixel = 0, B = { BackgroundColor3 = "Side" }, Parent = gui,
    })
    corner(island, 19); stroke(island)
    local isHold = mk("Frame", { Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Parent = island })
    local isGrid = gridIcon(isHold, 18, true)
    local isImg = mk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = LOGO, ScaleType = Enum.ScaleType.Fit, Visible = false, Parent = isHold })
    corner(isImg, 14)
    local isName = label(island, W.Title, 12, "Text", FM)
    isName.Position = UDim2.fromOffset(42, 0); isName.Size = UDim2.fromOffset(100, 38); isName.TextTruncate = Enum.TextTruncate.AtEnd
    local wave = {}
    for i = 1, 4 do
        wave[i] = mk("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(148 + (i - 1) * 6, 19), Size = UDim2.fromOffset(3, 4), BorderSizePixel = 0, B = { BackgroundColor3 = "Accent" }, Parent = island })
        corner(wave[i], 2)
    end
    local isCount = label(island, "0", 12, "Text", FB)
    isCount.Position = UDim2.fromOffset(174, 0); isCount.Size = UDim2.fromOffset(20, 38)
    W.Island, W.IslandCount = island, isCount

    local active = 0
    W.Conns[#W.Conns + 1] = RunService.Heartbeat:Connect(function()
        if not island.Visible then return end
        local t = os.clock()
        for i, b in ipairs(wave) do
            local h = (active > 0) and (5 + 12 * math.abs(math.sin(t * 5 + i * 1.3))) or 4
            b.Size = UDim2.fromOffset(3, h)
        end
    end)

    function W:UpdateIsland()
        local n = 0
        for _, t in ipairs(self.ToggleList) do if t.Value then n += 1 end end
        active = n
        isCount.Text = tostring(n)
    end

    function W:RefreshChrome()
        local shown = frame.Visible
        fbtn.Visible = (self.BtnMode == "Always") or (self.BtnMode == "Mobile only" and isTouch() == true)
        fgrid.Visible = shown; fimg.Visible = not shown
        isGrid.Visible = shown; isImg.Visible = not shown
        island.Visible = self.IslandMode ~= "Hidden"
        local expanded = (self.IslandMode == "Always") or (not shown) or self.IslandHover == true
        tw(island, 0.18, { Size = UDim2.fromOffset(expanded and 200 or 44, 38) })
        dim.Visible = self.Dim and shown or false
    end
    island.MouseEnter:Connect(function() W.IslandHover = true; W:RefreshChrome() end)
    island.MouseLeave:Connect(function() W.IslandHover = false; W:RefreshChrome() end)

    function W:SetVisible(v)
        frame.Visible = v
        if not v then self:ClosePopup(); self:CloseFeatures() end
        self:RefreshChrome()
    end
    function W:Toggle() self:SetVisible(not frame.Visible) end

    local function makeClickDrag(btn)
        local moved, dragging, s0, p0 = 0, false, nil, nil
        btn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging, s0, p0, moved = true, i.Position, btn.Position, 0
                i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
            end
        end)
        W.Conns[#W.Conns + 1] = UIS.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - s0
                moved = math.max(moved, d.Magnitude)
                if moved > 6 then btn.Position = UDim2.new(p0.X.Scale, p0.X.Offset + d.X, p0.Y.Scale, p0.Y.Offset + d.Y) end
            end
        end)
        btn.MouseButton1Click:Connect(function()
            if moved > 6 then moved = 0 return end
            W:Toggle()
        end)
    end
    makeClickDrag(fbtn); makeClickDrag(island)
    minBtn.MouseButton1Click:Connect(function() W:SetVisible(false) end)
    foot.MouseButton1Click:Connect(function() if W.PageList[1] then W:SelectPage(W.PageList[1].Name) end end)

    W.Conns[#W.Conns + 1] = UIS.InputBegan:Connect(function(i, gp)
        if gp or not W.Alive then return end
        if i.KeyCode == W.ToggleKey then W:Toggle() end
    end)

    -- ===== nama / avatar bisa disembunyikan =====
    function W:SetHideName(v)
        self.HideName = v
        for _, e in ipairs(self.NameLabels) do e[1].Text = v and (e[3] or "Hidden") or e[2] end
    end
    function W:SetHideAvatar(v)
        self.HideAvatar = v
        for _, im in ipairs(self.AvatarImgs) do im.ImageTransparency = v and 1 or 0 end
    end

    -- ===== navigasi / halaman =====
    local function selectPage(page)
        for _, p in ipairs(W.PageList) do
            local on = (p == page)
            p.Scroll.Visible = on
            p.NavBtn.BackgroundTransparency = on and 0 or 1
            p.NavText.TextColor3 = on and TH.Text or TH.Muted
            p.NavIcon.TextColor3 = on and TH.Accent or TH.Muted
        end
        W.Current = page
        W.HeaderIcon.Text = page.Icon
        W.HeaderTitle.Text = page.Name
        W:ClosePopup()
    end
    W:_hook(function() if W.Current then selectPage(W.Current) end end)
    W.SelectPage = function(self, name)
        local p = self.Pages[name]
        if p then selectPage(p) end
    end

    function W:AddPage(o)
        local page = { Name = o.Name, Icon = o.Icon or "•", Cards = {}, Win = W, Seq = { 0, 0 }, NextCol = 1 }
        -- urutan sidebar tetap: Home, Main, (halaman game lain), Player, Settings
        local FIXED = { Home = 1, Main = 2, Player = 900, Settings = 1000 }
        page.Order = FIXED[o.Name] or (10 + #W.PageList)

        local btn = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
            BorderSizePixel = 0, B = { BackgroundColor3 = "Row" }, LayoutOrder = page.Order, Parent = nav,
        })
        cornerS(btn)
        local ic = label(btn, page.Icon, 15, "Muted", FM, Enum.TextXAlignment.Center)
        ic.Position = UDim2.fromOffset(8, 0); ic.Size = UDim2.new(0, 24, 1, 0)
        local tx = label(btn, o.Name, 12, "Muted", FM)
        tx.Position = UDim2.fromOffset(42, 0); tx.Size = UDim2.new(1, -46, 1, 0)
        page.NavBtn, page.NavText, page.NavIcon = btn, tx, ic
        btn.MouseButton1Click:Connect(function() selectPage(page) end)

        local scroll = mk("ScrollingFrame", {
            Name = o.Name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, B = { ScrollBarImageColor3 = "Stroke" }, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = holder,
        })
        pad(scroll, 12, 2, 14, 14)
        local cols = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroll })
        list(cols, 10, Enum.FillDirection.Horizontal)
        page.Cols = {}
        for i = 1, 2 do
            local c = mk("Frame", {
                Size = UDim2.new(0.5, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                LayoutOrder = i, Parent = cols,
            })
            listD(c, 10)
            page.Cols[i] = c
        end
        page.Scroll = scroll

        function page:Reflow(single)
            self.Cols[2].Visible = not single
            self.Cols[1].Size = single and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -5, 0, 0)
            for _, c in ipairs(self.Cards) do
                c.Frame.Parent = single and self.Cols[1] or self.Cols[c.Col]
                c.Frame.LayoutOrder = single and (c.Col * 1000 + c.Seq) or c.Seq
            end
        end

        -- ===== kartu =====
        function page:AddCard(co)
            local colIdx = co.Column or self.NextCol
            if colIdx ~= 1 and colIdx ~= 2 then colIdx = 1 end
            self.NextCol = (colIdx == 1) and 2 or 1
            self.Seq[colIdx] += 1
            local card = { Win = W, Page = self, Col = colIdx, Seq = self.Seq[colIdx], Title = co.Title or "", N = 0 }
            local cf = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = card.Seq, B = { BackgroundColor3 = "Card" }, Parent = self.Cols[colIdx] })
            cornerL(cf); stroke(cf)
            list(cf, 0)
            card.Frame = cf

            local hd = mk("TextButton", { Size = UDim2.new(1, 0, 0, 38), Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = 1, B = { BackgroundColor3 = "Head" }, Parent = cf })
            cornerL(hd)
            local fill = mk("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 10), BorderSizePixel = 0, B = { BackgroundColor3 = "Head" }, Parent = hd })
            local hi = label(hd, co.Icon or "•", 15, "Accent", FB, Enum.TextXAlignment.Center)
            hi.Position = UDim2.fromOffset(8, 0); hi.Size = UDim2.new(0, 24, 1, 0)
            local ht = label(hd, card.Title, 12, "Text", FB)
            ht.Position = UDim2.fromOffset(38, 0); ht.Size = UDim2.new(1, -72, 1, 0); ht.TextTruncate = Enum.TextTruncate.AtEnd
            local chev = chevron(hd); chev.Position = UDim2.new(1, -18, 0.5, 0); chev.Size = UDim2.fromOffset(20, 24); chev.Rotation = 90

            local body = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = cf })
            pad(body, 14, 8, 14, 14)
            listD(body, 8)
            card.Body = body
            local open = true
            function card:SetOpen(v)
                open = v
                body.Visible = v
                fill.Visible = v
                chev.Rotation = v and 90 or 0
            end
            hd.MouseButton1Click:Connect(function() card:SetOpen(not open) end)
            if co.Collapsed then card:SetOpen(false) end

            local function row(h)
                card.N += 1
                return mk("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = card.N, Parent = body })
            end
            local function register(o2, obj, kind, f)
                obj.Kind, obj.Card, obj.Page = kind, card, page
                obj.Title = o2.Title or o2.Text or ""
                if o2.id then
                    W.Elements[o2.id] = obj
                    W.Order[#W.Order + 1] = o2.id
                    obj.Id = o2.id
                end
                if not o2.Hidden then
                    W.Features[#W.Features + 1] = { Title = obj.Title, Kind = kind, Page = page, Card = card, Frame = f, Id = o2.id }
                end
            end

            -- ----- Toggle -----
            function card:Toggle(o2)
                local f = row(32)
                local t = label(f, o2.Title or "", 12, "Text", FM)
                t.Size = UDim2.new(1, -56, 1, 0); t.TextTruncate = Enum.TextTruncate.AtEnd
                local sw = mk("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(46, 24), BorderSizePixel = 0, B = { BackgroundColor3 = "Off" }, Parent = f })
                corner(sw, 12)
                local knob = mk("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(18, 18), BorderSizePixel = 0, B = { BackgroundColor3 = "Knob" }, Parent = sw })
                corner(knob, 9)
                local click = mk("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f })
                local cb = o2.Callback or function() end
                local obj = { Frame = f, Value = false, Default = o2.Value == true }
                local function visual(v, instant)
                    local props = {
                        BackgroundColor3 = v and TH.Accent or TH.Off,
                    }
                    local kp = {
                        Position = v and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                        BackgroundColor3 = v and TH.OnKnob or TH.Knob,
                    }
                    if instant then
                        for k, x in pairs(props) do sw[k] = x end
                        for k, x in pairs(kp) do knob[k] = x end
                    else
                        tw(sw, 0.15, props); tw(knob, 0.15, kp)
                    end
                end
                function obj:Set(v, silent)
                    v = v and true or false
                    self.Value = v
                    visual(v)
                    W:UpdateIsland()
                    if not silent then pcall(cb, v) end
                end
                obj.SetValue = obj.Set
                function obj:Get() return self.Value end
                obj.GetValue = obj.Get
                function obj:SetVisible(v) f.Visible = v end
                W:_hook(function() visual(obj.Value, true) end)
                click.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
                W.ToggleList[#W.ToggleList + 1] = obj
                if o2.Value then
                    obj:Set(true, true)
                    W.Pending[#W.Pending + 1] = function() pcall(cb, true) end
                end
                register(o2, obj, "toggle", f)
                return obj
            end

            -- ----- Slider -----
            function card:Slider(o2)
                local f = row(48)
                local t = label(f, o2.Title or "", 12, "Text", FM)
                t.Size = UDim2.new(1, -70, 0, 22); t.TextTruncate = Enum.TextTruncate.AtEnd
                local box = mk("TextBox", {
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(58, 22),
                    BorderSizePixel = 0, Text = "", Font = FM, TextSize = 11, ClearTextOnFocus = false,
                    B = { BackgroundColor3 = "Field", TextColor3 = "Accent" }, Parent = f,
                })
                cornerS(box); stroke(box)
                local track = mk("Frame", { Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, 0, 0, 4), BorderSizePixel = 0, B = { BackgroundColor3 = "Off" }, Parent = f })
                corner(track, 2)
                local fillb = mk("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, B = { BackgroundColor3 = "Accent" }, Parent = track })
                corner(fillb, 2)
                local thumb = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0, B = { BackgroundColor3 = "Accent" }, Parent = track })
                corner(thumb, 7)
                local hit = mk("TextButton", { Position = UDim2.new(0, -6, 0, 26), Size = UDim2.new(1, 12, 0, 24), BackgroundTransparency = 1, Text = "", Parent = f })

                local min, max = o2.Min or 0, o2.Max or 100
                local dec = o2.Rounding or 0
                local suffix = o2.Suffix or ""
                local cb = o2.Callback or function() end
                local obj = { Frame = f, Value = min, Default = o2.Value or min }
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
                    fillb.Size = UDim2.fromScale(r, 1)
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
                    local r = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
                    obj:Set(min + (max - min) * r)
                end
                hit.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        page.Scroll.ScrollingEnabled = false
                        fromX(i.Position.X)
                    end
                end)
                W.Conns[#W.Conns + 1] = UIS.InputChanged:Connect(function(i)
                    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                        fromX(i.Position.X)
                    end
                end)
                W.Conns[#W.Conns + 1] = UIS.InputEnded:Connect(function(i)
                    if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
                        dragging = false
                        page.Scroll.ScrollingEnabled = true
                    end
                end)
                box.FocusLost:Connect(function()
                    local n = tonumber((box.Text:gsub("[^%d%.%-]", "")))
                    obj:Set(n or obj.Value)
                end)

                obj:Set(o2.Value or min, true)
                W.Pending[#W.Pending + 1] = function() pcall(cb, obj.Value) end
                register(o2, obj, "slider", f)
                return obj
            end

            -- ----- Button -----
            local function styleButton(b, colr)
                b.BorderSizePixel = 0
                REG[#REG + 1] = { b, "BackgroundColor3", "Row" }
                b.BackgroundColor3 = TH.Row
                if colr then b.TextColor3 = col3(colr, TH.Text)
                else REG[#REG + 1] = { b, "TextColor3", "Text" }; b.TextColor3 = TH.Text end
                b.MouseEnter:Connect(function() tw(b, 0.12, { BackgroundColor3 = TH.RowHi }) end)
                b.MouseLeave:Connect(function() tw(b, 0.12, { BackgroundColor3 = TH.Row }) end)
            end

            function card:Button(o2)
                local f = row(34)
                local b = mk("TextButton", {
                    Size = UDim2.fromScale(1, 1), Text = ((o2.Icon and (o2.Icon .. "  ")) or "") .. (o2.Text or o2.Title or ""),
                    Font = FM, TextSize = 12, AutoButtonColor = false, Parent = f,
                })
                cornerS(b); stroke(b)
                styleButton(b, o2.Color)
                local cb = o2.Callback or function() end
                b.MouseButton1Click:Connect(function() pcall(cb) end)
                local obj = { Frame = f }
                function obj:SetText(s) b.Text = s end
                function obj:SetVisible(v) f.Visible = v end
                register(o2, obj, "button", f)
                return obj
            end

            function card:Buttons(o2)   -- beberapa tombol sebaris
                local f = row(34)
                list(f, 8, Enum.FillDirection.Horizontal)
                local n = #o2.Buttons
                local out = {}
                for i, bd in ipairs(o2.Buttons) do
                    local b = mk("TextButton", {
                        Size = UDim2.new(1 / n, -8 * (n - 1) / n, 1, 0), Text = bd.Text or "", Font = FM, TextSize = 11,
                        AutoButtonColor = false, LayoutOrder = i, Parent = f,
                    })
                    cornerS(b); stroke(b)
                    styleButton(b, bd.Color)
                    b.MouseButton1Click:Connect(function() pcall(bd.Callback or function() end) end)
                    out[i] = b
                end
                return { Frame = f, Buttons = out }
            end

            function card:Label(o2)
                card.N += 1
                local f = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = card.N, Parent = body })
                local t = label(f, o2.Text or o2.Title or "", o2.Size or 11, o2.Color or "Muted", F)
                t.Size = UDim2.new(1, 0, 0, 0); t.AutomaticSize = Enum.AutomaticSize.Y; t.TextWrapped = true
                local obj = { Frame = f }
                function obj:SetText(s) t.Text = s end
                function obj:SetVisible(v) f.Visible = v end
                return obj
            end

            function card:Divider(text)
                local f = row(16)
                local ln = mk("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, B = { BackgroundColor3 = "Stroke" }, Parent = f })
                if text and text ~= "" then
                    local t = label(f, text, 10, "Muted", FM, Enum.TextXAlignment.Center)
                    t.AnchorPoint = Vector2.new(0.5, 0.5); t.Position = UDim2.fromScale(0.5, 0.5)
                    t.Size = UDim2.fromOffset(#text * 6 + 16, 14); t.BackgroundTransparency = 0
                    REG[#REG + 1] = { t, "BackgroundColor3", "Card" }; t.BackgroundColor3 = TH.Card
                end
                return { Frame = f }
            end

            function card:Custom(h)       -- bingkai kosong untuk isi bebas (dipakai halaman Home)
                return row(h)
            end

            -- ----- Input -----
            function card:Input(o2)
                local f = row(58)
                local t = label(f, o2.Title or "", 12, "Text", FM)
                t.Size = UDim2.new(1, 0, 0, 20)
                local bx = mk("TextBox", {
                    Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0,
                    Text = o2.Value or "", PlaceholderText = o2.Placeholder or "", Font = FM, TextSize = 12,
                    ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
                    B = { BackgroundColor3 = "Field", TextColor3 = "Text", PlaceholderColor3 = "Muted" }, Parent = f,
                })
                cornerS(bx); stroke(bx); pad(bx, 10, 0)
                local cb = o2.Callback or function() end
                local obj = { Frame = f, Default = o2.Value or "" }
                function obj:Set(v, silent) bx.Text = tostring(v or ""); if not silent then pcall(cb, bx.Text) end end
                obj.SetValue = obj.Set
                function obj:Get() return bx.Text end
                obj.GetValue = obj.Get
                function obj:SetVisible(v) f.Visible = v end
                bx.FocusLost:Connect(function() pcall(cb, bx.Text) end)
                if o2.NoTitle then t.Visible = false; bx.Position = UDim2.fromOffset(0, 0); f.Size = UDim2.new(1, 0, 0, 32) end
                if o2.id == nil then o2.Hidden = true end
                register(o2, obj, "input", f)
                return obj
            end

            -- ----- Keybind -----
            function card:Keybind(o2)
                local f = row(32)
                local t = label(f, o2.Title or "", 12, "Text", FM)
                t.Size = UDim2.new(1, -90, 1, 0)
                local kb = mk("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(80, 26),
                    Text = "", Font = FM, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0,
                    B = { BackgroundColor3 = "Field", TextColor3 = "Text" }, Parent = f,
                })
                cornerS(kb); stroke(kb)
                local key = o2.Value or Enum.KeyCode.Unknown
                local cb, onChanged = o2.Callback or function() end, o2.OnChanged or function() end
                local obj = { Frame = f, Default = key.Name }
                local function show() kb.Text = key.Name end
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
                register(o2, obj, "keybind", f)
                return obj
            end

            -- ----- ColorRow (hex + swatch) -----
            function card:ColorRow(o2)
                card.N += 1
                local f = mk("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = card.N, Parent = body })
                local t = label(f, o2.Title or "", 12, "Text", FM)
                t.Size = UDim2.new(0.4, 0, 0, 34)
                local hx = label(f, "", 10, "Muted", FM, Enum.TextXAlignment.Right)
                hx.AnchorPoint = Vector2.new(1, 0); hx.Position = UDim2.new(1, -62, 0, 0); hx.Size = UDim2.fromOffset(70, 34)
                local sw = mk("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -26, 0, 17), Size = UDim2.fromOffset(28, 22), BorderSizePixel = 0, Parent = f })
                cornerS(sw); stroke(sw)
                local ch = chevron(f); ch.Position = UDim2.new(1, -9, 0, 17); ch.Size = UDim2.fromOffset(18, 24); ch.Rotation = 90
                local hit = mk("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", Parent = f })
                local bx = mk("TextBox", {
                    Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0, Visible = false,
                    Text = "", PlaceholderText = "#RRGGBB", Font = FM, TextSize = 12, ClearTextOnFocus = false,
                    B = { BackgroundColor3 = "Field", TextColor3 = "Text", PlaceholderColor3 = "Muted" }, Parent = f,
                })
                cornerS(bx); stroke(bx); pad(bx, 10, 0)
                local open = false
                hit.MouseButton1Click:Connect(function()
                    open = not open
                    bx.Visible = open
                    f.Size = UDim2.new(1, 0, 0, open and 72 or 34)
                    ch.Rotation = open and -90 or 90
                end)
                local cb = o2.Callback or function() end
                local obj = { Frame = f }
                local function show()
                    local c = o2.Get and o2.Get() or Color3.new(1, 1, 1)
                    sw.BackgroundColor3 = c
                    hx.Text = hexOf(c)
                    bx.Text = hexOf(c)
                end
                function obj:Refresh() show() end
                bx.FocusLost:Connect(function()
                    local c = parseHex(bx.Text)
                    if c then pcall(cb, c) end
                    show()
                end)
                W:_hook(show)
                show()
                return obj
            end

            -- ----- Dropdown (single / multi) -----
            function card:Dropdown(o2)
                local f = row(60)
                local t = label(f, o2.Title or "", 12, "Text", FM)
                t.Size = UDim2.new(1, 0, 0, 20)
                local btn = mk("TextButton", {
                    Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 34), BorderSizePixel = 0,
                    Text = "", AutoButtonColor = false, B = { BackgroundColor3 = "Field" }, Parent = f,
                })
                cornerS(btn)
                local bstroke = stroke(btn)
                local vt = label(btn, "", 12, "Text", FM)
                vt.Position = UDim2.fromOffset(12, 0); vt.Size = UDim2.new(1, -38, 1, 0); vt.TextTruncate = Enum.TextTruncate.AtEnd
                local arrow = chevron(btn); arrow.Position = UDim2.new(1, -16, 0.5, 0); arrow.Size = UDim2.fromOffset(18, 24); arrow.Rotation = 90

                local items = o2.List or {}
                local multi = o2.Multi == true or type(o2.Value) == "table"
                local sel = {}
                local cb = o2.Callback or function() end
                local obj = { Frame = f, Multi = multi, Default = o2.Value }
                local placeholder = o2.Placeholder or (multi and "None" or "Select")

                local function indexOf(v) for i, x in ipairs(items) do if x == v then return i end end end
                local function ordered()
                    local out = {}
                    for _, x in ipairs(items) do if sel[x] then out[#out + 1] = x end end
                    return out
                end
                local function refreshText()
                    local o3 = ordered()
                    if multi then vt.Text = (#o3 > 0) and table.concat(o3, ", ") or placeholder
                    else vt.Text = tostring(o3[1] or placeholder) end
                    vt.TextColor3 = (#o3 == 0) and TH.Muted or TH.Text
                end
                W:_hook(refreshText)
                function obj:Get()
                    local o3 = ordered()
                    if multi then return o3 end
                    return o3[1]
                end
                obj.GetValue = obj.Get
                function obj:Set(v, silent)
                    sel = {}
                    if type(v) == "table" then
                        for _, x in ipairs(v) do if indexOf(x) then sel[x] = true end end
                    elseif v ~= nil and indexOf(v) then
                        sel[v] = true
                    end
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
                function obj:SetVisible(v) f.Visible = v end

                local function openPopup()
                    if W.Popup and W.PopupOwner == obj then W:ClosePopup() return end
                    W:ClosePopup()
                    W.PopupOwner = obj
                    local blocker = mk("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 50, Parent = frame })
                    local sc = uiscale.Scale
                    local rel = (btn.AbsolutePosition - frame.AbsolutePosition) / sc
                    local width = btn.AbsoluteSize.X / sc
                    local fh = frame.AbsoluteSize.Y / sc
                    local height = math.min(#items * 30 + 54, 230, fh - 12)
                    local y = rel.Y + btn.AbsoluteSize.Y / sc + 4
                    if y + height > fh - 6 then y = math.max(6, rel.Y - height - 4) end
                    local pop = mk("Frame", {
                        Position = UDim2.fromOffset(rel.X, y), Size = UDim2.fromOffset(width, height),
                        BorderSizePixel = 0, ZIndex = 51, B = { BackgroundColor3 = "Card" }, Parent = frame,
                    })
                    cornerL(pop); stroke(pop, "Accent")
                    local sf = mk("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 30), BorderSizePixel = 0, B = { BackgroundColor3 = "Field" }, Parent = pop })
                    cornerS(sf); stroke(sf)
                    local sb = mk("TextBox", {
                        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -16, 1, 0), BackgroundTransparency = 1, Text = "",
                        PlaceholderText = "Search", Font = FM, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
                        B = { TextColor3 = "Text", PlaceholderColor3 = "Muted" }, Parent = sf,
                    })
                    local lst = mk("ScrollingFrame", {
                        Position = UDim2.fromOffset(6, 44), Size = UDim2.new(1, -12, 1, -50), BackgroundTransparency = 1, BorderSizePixel = 0,
                        ScrollBarThickness = 2, B = { ScrollBarImageColor3 = "Stroke" }, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = pop,
                    })
                    list(lst, 2)
                    local rows = {}
                    local function paint(r, name)
                        local on = sel[name] == true
                        r.txt.TextColor3 = on and TH.Accent or TH.Text
                        r.bar.Visible = on
                        r.btn.BackgroundTransparency = on and 0.5 or 1
                    end
                    for i, name in ipairs(items) do
                        local b = mk("TextButton", { Size = UDim2.new(1, -4, 0, 28), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i, B = { BackgroundColor3 = "Row" }, Parent = lst })
                        cornerS(b)
                        local bar = mk("Frame", { Size = UDim2.new(0, 3, 1, -12), Position = UDim2.fromOffset(2, 6), BorderSizePixel = 0, B = { BackgroundColor3 = "Accent" }, Parent = b })
                        corner(bar, 2)
                        local tx = label(b, tostring(name), 12, "Text", FM)
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
                    bstroke.Color = TH.Accent
                    arrow.Rotation = -90
                    W.PopupReset = function() bstroke.Color = TH.Stroke; arrow.Rotation = 90 end
                end
                btn.MouseButton1Click:Connect(openPopup)

                obj:Set(o2.Value, true)
                if multi or o2.Value ~= nil then
                    W.Pending[#W.Pending + 1] = function() pcall(cb, obj:Get()) end
                end
                register(o2, obj, "dropdown", f)
                return obj
            end

            self.Cards[#self.Cards + 1] = card
            if W.Single then self:Reflow(true) end
            return card
        end

        self.Pages[o.Name] = page
        self.PageList[#self.PageList + 1] = page
        table.sort(self.PageList, function(a, b) return a.Order < b.Order end)
        page.NavText.Visible = not W.Compact
        if not self.Current then selectPage(page) end
        return page
    end

    function W:ClosePopup()
        if self.Popup then
            for _, o in ipairs(self.Popup) do pcall(function() o:Destroy() end) end
            self.Popup = nil
            self.PopupOwner = nil
        end
        if self.PopupReset then pcall(self.PopupReset); self.PopupReset = nil end
    end

    -- ===== Features (pencarian semua fitur) =====
    local KIND_ICON = { toggle = "◉", slider = "↔", dropdown = "☰", button = "✦", input = "✎", keybind = "⌘" }

    function W:CloseFeatures()
        if self.FeatUI then
            pcall(function() self.FeatUI:Destroy() end)
            self.FeatUI = nil
        end
    end

    local function flash(f)
        local s = mk("UIStroke", { B = { Color = "Accent" }, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
        local c = mk("UICorner", { CornerRadius = UDim.new(0, 6), Parent = f })
        tw(s, 1.6, { Transparency = 1 })
        task.delay(1.7, function() pcall(function() s:Destroy(); c:Destroy() end) end)
    end

    function W:GoTo(ft)
        self:CloseFeatures()
        self:SelectPage(ft.Page.Name)
        ft.Card:SetOpen(true)
        task.delay(0.1, function()
            pcall(function()
                local sc = uiscale.Scale
                local sf = ft.Page.Scroll
                local y = (ft.Frame.AbsolutePosition.Y - sf.AbsolutePosition.Y) / sc + sf.CanvasPosition.Y - 10
                sf.CanvasPosition = Vector2.new(0, math.max(0, y))
                flash(ft.Frame)
            end)
        end)
    end

    function W:OpenFeatures()
        if self.FeatUI then self:CloseFeatures() return end
        self:ClosePopup()
        local root = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 60, Parent = frame })
        self.FeatUI = root
        local blocker = mk("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 60, Parent = root })
        cornerL(blocker)
        blocker.MouseButton1Click:Connect(function() W:CloseFeatures() end)

        local pw = math.min(560, (self.DW or 760) - 24)
        local ph = math.min(400, (self.DH or 430) - 24)
        local panel = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(pw, ph), BorderSizePixel = 0, ZIndex = 61, B = { BackgroundColor3 = "Card" }, Parent = root })
        cornerL(panel); stroke(panel)

        local ic = label(panel, "☰", 17, "Accent", FB, Enum.TextXAlignment.Center); ic.Position = UDim2.fromOffset(14, 12); ic.Size = UDim2.fromOffset(26, 26)
        local ttl = label(panel, "Features", 15, "Text", FB); ttl.Position = UDim2.fromOffset(46, 10); ttl.Size = UDim2.new(1, -100, 0, 18)
        local cnt = #self.Features
        local sub = label(panel, cnt .. " features across " .. #self.PageList .. " tabs", 10, "Muted", F); sub.Position = UDim2.fromOffset(46, 29); sub.Size = UDim2.new(1, -100, 0, 14)
        local x = mk("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Text = "✕", Font = FB, TextSize = 14, B = { TextColor3 = "Muted" }, Parent = panel })
        x.MouseButton1Click:Connect(function() W:CloseFeatures() end)

        local sbox = mk("Frame", { Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 0, 34), BorderSizePixel = 0, B = { BackgroundColor3 = "Field" }, Parent = panel })
        cornerS(sbox); stroke(sbox)
        magnifier(sbox, 10, 10)
        local sb = mk("TextBox", {
            Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Search features",
            Font = FM, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
            B = { TextColor3 = "Text", PlaceholderColor3 = "Muted" }, Parent = sbox,
        })

        local lst = mk("ScrollingFrame", {
            Position = UDim2.fromOffset(8, 96), Size = UDim2.new(1, -16, 1, -104), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, B = { ScrollBarImageColor3 = "Stroke" }, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel,
        })
        list(lst, 2)
        local groups, order = {}, 0
        for _, p in ipairs(self.PageList) do
            local items = {}
            for _, ft in ipairs(self.Features) do if ft.Page == p then items[#items + 1] = ft end end
            if #items > 0 then
                order += 1
                local gh = mk("Frame", { Size = UDim2.new(1, -6, 0, 28), BackgroundTransparency = 1, LayoutOrder = order * 1000, Parent = lst })
                local gi = label(gh, p.Icon, 13, "Accent", FB, Enum.TextXAlignment.Center); gi.Position = UDim2.fromOffset(4, 0); gi.Size = UDim2.fromOffset(20, 28)
                local gt = label(gh, string.upper(p.Name), 10, "Muted", FM); gt.Position = UDim2.fromOffset(30, 0); gt.Size = UDim2.new(1, -70, 1, 0)
                local gc = label(gh, tostring(#items), 10, "Muted", FM, Enum.TextXAlignment.Right); gc.Position = UDim2.new(1, -40, 0, 0); gc.Size = UDim2.fromOffset(36, 28)
                local g = { header = gh, rows = {} }
                groups[#groups + 1] = g
                for k, ft in ipairs(items) do
                    local r = mk("TextButton", { Size = UDim2.new(1, -6, 0, 46), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = order * 1000 + k, B = { BackgroundColor3 = "Row" }, Parent = lst })
                    cornerS(r)
                    local ki = label(r, KIND_ICON[ft.Kind] or "•", 14, "Muted", FM, Enum.TextXAlignment.Center); ki.Position = UDim2.fromOffset(6, 0); ki.Size = UDim2.fromOffset(28, 46)
                    local rt = label(r, ft.Title, 12, "Text", FM); rt.Position = UDim2.fromOffset(42, 6); rt.Size = UDim2.new(1, -80, 0, 18); rt.TextTruncate = Enum.TextTruncate.AtEnd
                    local rs = label(r, ft.Card.Title, 10, "Muted", F); rs.Position = UDim2.fromOffset(42, 24); rs.Size = UDim2.new(1, -80, 0, 14); rs.TextTruncate = Enum.TextTruncate.AtEnd
                    local ar = chevron(r); ar.Position = UDim2.new(1, -16, 0.5, 0); ar.Size = UDim2.fromOffset(18, 24)
                    r.MouseEnter:Connect(function() r.BackgroundTransparency = 0.4 end)
                    r.MouseLeave:Connect(function() r.BackgroundTransparency = 1 end)
                    r.MouseButton1Click:Connect(function() W:GoTo(ft) end)
                    g.rows[#g.rows + 1] = { btn = r, key = string.lower(ft.Title .. " " .. ft.Card.Title .. " " .. p.Name) }
                end
            end
        end
        sb:GetPropertyChangedSignal("Text"):Connect(function()
            local q = string.lower(sb.Text)
            for _, g in ipairs(groups) do
                local any = false
                for _, r in ipairs(g.rows) do
                    local vis = (q == "") or (r.key:find(q, 1, true) ~= nil)
                    r.btn.Visible = vis
                    if vis then any = true end
                end
                g.header.Visible = any
            end
        end)
        pcall(function() sb:CaptureFocus() end)
    end

    -- ===== notifikasi =====
    local toasts = mk("Frame", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(250, 400),
        BackgroundTransparency = 1, Parent = gui,
    })
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = toasts })

    function W:Notify(o)
        o = o or {}
        local dur = o.Duration or 3
        local col = col3(o.Color, TH.Accent)
        local tf = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, B = { BackgroundColor3 = "Card" }, Parent = toasts })
        cornerL(tf); stroke(tf)
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
        pcall(function()
            TweenService:Create(pb, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) }):Play()
        end)
        task.delay(dur, function() pcall(function() tf:Destroy() end) end)
    end

    -- ===== cuaca / redup / transparan / background =====
    W.Parts = {}
    function W:SetWeather(kind, mode)
        self.WeatherKind = kind or self.WeatherKind or "None"
        self.WeatherMode = mode or self.WeatherMode or "Screen"
        if self.WeatherLayer then pcall(function() self.WeatherLayer:Destroy() end); self.WeatherLayer = nil end
        self.Parts = {}
        if self.WeatherKind == "None" then return end
        local inWin = (self.WeatherMode == "Window")
        local layer = mk("Frame", { Name = "Weather", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false, ClipsDescendants = true, ZIndex = inWin and 40 or 1, Parent = inWin and frame or weatherScreen })
        if inWin then cornerL(layer) end
        self.WeatherLayer = layer
        local n = (self.WeatherKind == "Rain") and 50 or 38
        for i = 1, n do
            local p = { x = math.random(), y = math.random(), ph = math.random() * 6.28 }
            local f
            if self.WeatherKind == "Snow" then
                local s = math.random(3, 6)
                f = mk("Frame", { Size = UDim2.fromOffset(s, s), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = layer })
                corner(f, 3); p.v = 0.05 + math.random() * 0.06; p.sway = 0.02
            elseif self.WeatherKind == "Rain" then
                f = mk("Frame", { Size = UDim2.fromOffset(1, math.random(9, 15)), BackgroundColor3 = Color3.fromRGB(170, 200, 255), BackgroundTransparency = 0.45, BorderSizePixel = 0, Rotation = 8, Parent = layer })
                p.v = 0.7 + math.random() * 0.4; p.sway = 0
            else
                local s = math.random(2, 4)
                f = mk("Frame", { Size = UDim2.fromOffset(s, s), BorderSizePixel = 0, B = { BackgroundColor3 = "Accent" }, Parent = layer })
                corner(f, 2); p.v = -(0.03 + math.random() * 0.05); p.sway = 0.03
            end
            p.f = f
            self.Parts[#self.Parts + 1] = p
        end
    end
    W.Conns[#W.Conns + 1] = RunService.Heartbeat:Connect(function(dt)
        local parts = W.Parts
        if #parts == 0 then return end
        local t = os.clock()
        local sparkle = (W.WeatherKind == "Sparkle")
        for _, p in ipairs(parts) do
            p.y += p.v * dt
            if p.y > 1.02 then p.y = -0.02; p.x = math.random() elseif p.y < -0.02 then p.y = 1.02; p.x = math.random() end
            local x = p.x + math.sin(t * 0.8 + p.ph) * p.sway
            p.f.Position = UDim2.fromScale(x, p.y)
            if sparkle then p.f.BackgroundTransparency = 0.2 + 0.7 * math.abs(math.sin(t * 2 + p.ph)) end
        end
    end)

    function W:SetDim(v) self.Dim = v and true or false; self:RefreshChrome() end
    function W:SetTransparent(v)
        self.Transparent = v and true or false
        frame.BackgroundTransparency = v and 0.18 or 0
        side.BackgroundTransparency = v and 0.18 or 0
    end

    function W:SetBackground(src)
        local img = ""
        src = tostring(src or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if src:match("^%d+$") then img = "rbxassetid://" .. src
        elseif src:match("^rbxassetid://") or src:match("^rbxthumb://") or src:match("^rbxasset://") then img = src
        elseif src:match("^https?://") and has(writefile) and has(getcustomasset) then
            pcall(function()
                local data = game:HttpGet(src)
                local name = W.Folder .. "/bg_" .. tostring(#src) .. "_" .. tostring(#data) .. ".png"
                writefile(name, data)
                img = getcustomasset(name)
            end)
        end
        self.BgSrc = img
        bgImg.Image = img
        self:SetBackgroundMode(self.BgMode or "None")
        return img ~= ""
    end
    function W:SetBackgroundMode(m)
        self.BgMode = m
        self.BgOpacity = self.BgOpacity or 0.65
        bgImg.ImageTransparency = (m ~= "None" and (self.BgSrc or "") ~= "") and (1 - self.BgOpacity) or 1
    end
    function W:SetBackgroundOpacity(o)
        self.BgOpacity = math.clamp(o, 0, 1)
        self:SetBackgroundMode(self.BgMode or "None")
    end

    -- ===== config =====
    local function cfgPath(name) return W.Folder .. "/" .. name .. ".json" end
    local canFS = has(writefile) and has(readfile) and has(isfile) and has(makefolder) and has(isfolder)
    local function mkdirs(path)
        if not canFS then return end
        pcall(function()
            local cur = ""
            for p in string.gmatch(path, "[^/]+") do
                cur = (cur == "") and p or (cur .. "/" .. p)
                if not isfolder(cur) then makefolder(cur) end
            end
        end)
    end
    mkdirs(W.Folder); mkdirs(W.Folder .. "/themes")
    W.CanFS = canFS

    local function readText(path)
        if not canFS then return nil end
        local ok, res = pcall(function() if isfile(path) then return readfile(path) end end)
        return ok and res or nil
    end

    function W:Collect()
        local data = {}
        for id, el in pairs(self.Elements) do
            local ok, v = pcall(el.Get, el)
            if ok and v ~= nil then data[id] = v end
        end
        return data
    end
    function W:Apply(data)
        if type(data) ~= "table" then return false end
        for id, v in pairs(data) do
            local el = self.Elements[id]
            if el then pcall(el.Set, el, v) end      -- Set TANPA silent: Callback ikut jalan
        end
        return true
    end

    local function listJson(dir, memTable)
        local out = {}
        if canFS and has(listfiles) then
            pcall(function()
                for _, p in ipairs(listfiles(dir)) do
                    local nm = tostring(p):match("([^/\\]+)%.json$")
                    if nm then out[#out + 1] = nm end
                end
            end)
        else
            for nm in pairs(memTable) do out[#out + 1] = nm end
        end
        table.sort(out)
        return out
    end

    function W:ListConfigs() return listJson(W.Folder, W.Mem) end

    function W:SaveConfig(name)
        if not name or name == "" then return false end
        local json = HttpService:JSONEncode(self:Collect())
        if canFS then return (pcall(writefile, cfgPath(name), json)) end
        self.Mem[name] = json
        return true
    end

    function W:LoadConfig(name)
        if not name or name == "" then return false end
        local json = canFS and readText(cfgPath(name)) or self.Mem[name]
        if not json then return false end
        local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
        if not ok then return false end
        if not self:Apply(data) then return false end
        self.LoadedCfg = name
        return true
    end

    function W:DeleteConfig(name)
        if canFS and has(delfile) then pcall(delfile, cfgPath(name)) else self.Mem[name] = nil end
        if self:GetAutoload() == name then self:SetAutoload(nil) end
    end

    function W:RenameConfig(old, new)
        if not old or not new or new == "" or old == new then return false end
        local json = canFS and readText(cfgPath(old)) or self.Mem[old]
        if not json then return false end
        if canFS then pcall(writefile, cfgPath(new), json); if has(delfile) then pcall(delfile, cfgPath(old)) end
        else self.Mem[new] = json; self.Mem[old] = nil end
        if self.LoadedCfg == old then self.LoadedCfg = new end
        if self:GetAutoload() == old then self:SetAutoload(new) end
        return true
    end

    function W:ResetAll()
        for id, el in pairs(self.Elements) do
            if el.Default ~= nil and id ~= "ui_key" then pcall(el.Set, el, el.Default) end
        end
    end

    function W:ExportCode() return "KH1:" .. b64enc(HttpService:JSONEncode(self:Collect())) end
    function W:ImportCode(code)
        code = tostring(code or ""):gsub("^%s+", ""):gsub("%s+$", "")
        code = code:gsub("^KH1:", "")
        local ok, data = pcall(function() return HttpService:JSONDecode(b64dec(code)) end)
        if not ok or type(data) ~= "table" then return false end
        return self:Apply(data)
    end

    function W:GetAutoMode() return readText(W.Folder .. "/_automode.txt") or self.MemAutoMode or "All accounts" end
    function W:SetAutoMode(m)
        self.MemAutoMode = m
        if canFS then pcall(writefile, W.Folder .. "/_automode.txt", m) end
    end
    local function autoFile()
        if W:GetAutoMode() == "This account" then return W.Folder .. "/_autoload_" .. LP.UserId .. ".txt" end
        return W.Folder .. "/_autoload.txt"
    end
    function W:GetAutoload()
        if canFS then
            local r = readText(autoFile())
            if r and r ~= "" then return r end
            return nil
        end
        return self.MemAuto
    end
    function W:SetAutoload(name)
        if canFS then pcall(writefile, autoFile(), name or "") else self.MemAuto = name end
    end

    -- ===== tema tersimpan =====
    local function themePath(n) return W.Folder .. "/themes/" .. n .. ".json" end
    function W:ListThemes() return listJson(W.Folder .. "/themes", W.MemThemes) end
    function W:SaveTheme(name)
        if not name or name == "" then return false end
        local json = HttpService:JSONEncode(self:GetTheme())
        if canFS then return (pcall(writefile, themePath(name), json)) end
        self.MemThemes[name] = json
        return true
    end
    function W:LoadTheme(name)
        local json = canFS and readText(themePath(name)) or self.MemThemes[name]
        if not json then return false end
        local ok, t = pcall(function() return HttpService:JSONDecode(json) end)
        if not ok or type(t) ~= "table" then return false end
        self:ApplyTheme(t)
        return true
    end
    function W:DeleteTheme(name)
        if canFS and has(delfile) then pcall(delfile, themePath(name)) else self.MemThemes[name] = nil end
        if self:GetDefaultTheme() == name then self:SetDefaultTheme(nil) end
    end
    function W:GetDefaultTheme()
        if canFS then
            local r = readText(W.Folder .. "/_theme.txt")
            return (r and r ~= "") and r or nil
        end
        return self.MemDefTheme
    end
    function W:SetDefaultTheme(name)
        if canFS then pcall(writefile, W.Folder .. "/_theme.txt", name or "") else self.MemDefTheme = name end
    end

    -- panggil di akhir script: menjalankan nilai awal, lalu config autoload
    function W:Ready()
        for _, fn in ipairs(self.Pending) do pcall(fn) end
        self.Pending = {}
        local dt = self:GetDefaultTheme()
        if dt then self:LoadTheme(dt) end
        local auto = self:GetAutoload()
        if auto and auto ~= "" then
            local ok = self:LoadConfig(auto)
            if ok then self:Notify({ Title = "Config", Desc = "Autoload: " .. auto, Color = "#50C864" }) end
        end
        self:UpdateIsland()
        local m, h = self.Elements.ui_minstart, self.Elements.cl_hide
        self:SetVisible(not ((m and m:Get()) or (h and h:Get())))
        self:RefreshChrome()
    end

    function W:OnUnload(fn) self.OnUnloads[#self.OnUnloads + 1] = fn end

    function W:Destroy()
        self.Alive = false
        for _, fn in ipairs(self.OnUnloads) do pcall(fn) end
        for _, c in ipairs(self.Conns) do pcall(function() c:Disconnect() end) end
        pcall(function() gui:Destroy() end)
    end

    W:RefreshChrome()
    return W
end

-- ===== helper: tiap bagian dibungkus pcall supaya satu error tidak mematikan sisanya =====
local function try(W, scope, name, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[KatssinnnUI] " .. scope .. "/" .. name .. ": " .. tostring(err))
        pcall(function() W:Notify({ Title = scope .. ": " .. name, Desc = tostring(err), Color = "#DC3232", Duration = 10 }) end)
    end
end

-- ===== halaman Home =====
function Window:BuildHome(info, existing)
    info = info or {}
    local W = self
    local page = existing or W:AddPage({ Name = "Home", Icon = "⌂" })

    ----- Welcome -----
    try(W, "Home", "Welcome", function()
        local c1 = page:AddCard({ Title = "Welcome", Icon = "★", Column = 1 })
        local wf = c1:Custom(92)
        local av = mk("ImageLabel", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1,
            Image = "rbxthumb://type=AvatarBust&id=" .. LP.UserId .. "&w=150&h=150", Parent = wf,
        })
        W.AvatarImgs[#W.AvatarImgs + 1] = av
        local l1 = label(wf, "WELCOME BACK", 9, "Muted", FB); l1.Size = UDim2.new(1, -92, 0, 12)
        local nm = label(wf, LP.DisplayName, 20, "Text", FB); nm.Position = UDim2.fromOffset(0, 14); nm.Size = UDim2.new(1, -92, 0, 26); nm.TextTruncate = Enum.TextTruncate.AtEnd
        local un = label(wf, "@" .. LP.Name, 11, "Muted", F); un.Position = UDim2.fromOffset(0, 42); un.Size = UDim2.new(1, -92, 0, 14); un.TextTruncate = Enum.TextTruncate.AtEnd
        W.NameLabels[#W.NameLabels + 1] = { nm, LP.DisplayName }
        W.NameLabels[#W.NameLabels + 1] = { un, "@" .. LP.Name, "@hidden" }

        local function chip(x, w, text)
            local b = mk("TextButton", {
                Position = UDim2.fromOffset(x, 64), Size = UDim2.fromOffset(w, 22), Text = text, Font = FM, TextSize = 10,
                AutoButtonColor = false, BorderSizePixel = 0, B = { BackgroundColor3 = "Row", TextColor3 = "Text" }, Parent = wf,
            })
            cornerS(b); stroke(b)
            return b
        end
        chip(0, 44, info.Version or "v1.0")
        local hn, ha = chip(50, 64, "Name"), chip(120, 64, "Avatar")
        local function paint(b, on)
            b.Text = (b.Name == "n" and "Name" or "Avatar") .. (on and " ✕" or "")
            b.BackgroundColor3 = on and TH.Accent or TH.Row
            b.TextColor3 = on and TH.OnKnob or TH.Text
        end
        hn.Name, ha.Name = "n", "a"
        local function reg(id, btn, setter, getter)
            local obj = { Default = false, Kind = "toggle" }
            function obj:Set(v) setter(v and true or false); paint(btn, getter()) end
            obj.SetValue = obj.Set
            function obj:Get() return getter() end
            obj.GetValue = obj.Get
            W.Elements[id] = obj
            btn.MouseButton1Click:Connect(function() obj:Set(not getter()) end)
            W:_hook(function() paint(btn, getter()) end)
            paint(btn, false)
        end
        reg("hide_name", hn, function(v) W:SetHideName(v) end, function() return W.HideName end)
        reg("hide_avatar", ha, function(v) W:SetHideAvatar(v) end, function() return W.HideAvatar end)
    end)

    ----- Performance (FPS & ping diukur langsung, bukan dari statistik bawaan Roblox) -----
    try(W, "Home", "Performance", function()
        local c2 = page:AddCard({ Title = "Performance", Icon = "◔", Column = 2 })
        local pf = c2:Custom(176)
        local N = 30
        local function half(x, title, color)
            local w = UDim2.new(0.5, -8, 0, 0)
            local tl = label(pf, title, 10, "Muted", FB); tl.Position = UDim2.new(x, 0, 0, 0); tl.Size = UDim2.new(0.5, -8, 0, 12)
            local big = label(pf, "-", 22, "Text", FB); big.Position = UDim2.new(x, 0, 0, 14); big.Size = UDim2.new(0.5, -8, 0, 28)
            local mm = label(pf, "", 9, "Muted", F); mm.Position = UDim2.new(x, 0, 0, 44); mm.Size = UDim2.new(0.5, -8, 0, 12); mm.TextTruncate = Enum.TextTruncate.AtEnd
            local g = mk("Frame", { Position = UDim2.new(x, 0, 0, 62), Size = UDim2.new(0.5, -8, 0, 50), BackgroundTransparency = 1, ClipsDescendants = true, Parent = pf })
            local bars = {}
            for i = 1, N do
                bars[i] = mk("Frame", {
                    AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((i - 1) / N, 0, 1, 0), Size = UDim2.new(1 / N, -1, 0, 0),
                    BorderSizePixel = 0, BackgroundColor3 = color, Parent = g,
                })
            end
            return big, mm, bars
        end
        local fpsBig, fpsMM, fpsBars = half(0, "FPS", C("#F59E0B"))
        local pingBig, pingMM, pingBars = half(0.5, "PING", C("#34D399"))
        local function stat2(x, y, text, sub)
            local a = label(pf, text, 12, "Text", FB); a.Position = UDim2.new(x, 0, 0, y); a.Size = UDim2.new(0.5, -8, 0, 16)
            local b = label(pf, sub, 10, "Muted", F); b.Position = UDim2.new(x, 0, 0, y + 16); b.Size = UDim2.new(0.5, -8, 0, 12)
            return a
        end
        local plLbl = stat2(0, 124, "-", "Players")
        local ssLbl = stat2(0.5, 124, "-", "Session")
        local liveLbl = label(pf, "live · diukur langsung", 9, "Muted", F); liveLbl.Position = UDim2.fromOffset(0, 160); liveLbl.Size = UDim2.new(1, 0, 0, 12)

        -- FPS: hitung frame nyata per selang waktu
        local frames = 0
        W.Conns[#W.Conns + 1] = RunService.RenderStepped:Connect(function() frames += 1 end)

        -- PING: waktu pulang-pergi nyata (request kecil) -> bukan angka statistik Roblox
        local reqf
        pcall(function() reqf = (syn and syn.request) or request or http_request or (http and http.request) end)
        local samples, livePing = {}, nil
        task.spawn(function()
            local first = true
            while W.Alive do
                local t0 = os.clock()
                local ok = pcall(function()
                    local url = "https://www.roblox.com/favicon.ico?_=" .. tostring(math.floor(t0 * 1000))
                    if reqf then reqf({ Url = url, Method = "GET" }) else game:HttpGet(url, true) end
                end)
                local ms = (os.clock() - t0) * 1000
                if ok then
                    if first then first = false
                    else
                        samples[#samples + 1] = ms
                        if #samples > 3 then table.remove(samples, 1) end
                        local s = table.clone(samples); table.sort(s)
                        livePing = s[math.ceil(#s / 2)]
                    end
                end
                task.wait(1.2)
            end
        end)
        local function currentPing()
            if livePing then return math.floor(livePing + 0.5) end
            local p = 0
            pcall(function() p = math.floor(LP:GetNetworkPing() * 2000 + 0.5) end)   -- cadangan sebelum sampel pertama
            return p
        end

        local fpsH, pingH = {}, {}
        local t0 = os.clock()
        local last = os.clock()
        local function stat(h)
            local mn, mx, sum = math.huge, 0, 0
            for _, v in ipairs(h) do mn = math.min(mn, v); mx = math.max(mx, v); sum += v end
            if #h == 0 then return 0, 0, 0 end
            return mn, math.floor(sum / #h + 0.5), mx
        end
        local function paintBars(bars, h, cap)
            local off = N - #h
            for i, b in ipairs(bars) do
                local v = h[i - off]
                b.Size = UDim2.new(1 / N, -1, v and math.clamp(v / cap, 0.04, 1) or 0, 0)
            end
        end
        task.spawn(function()
            while W.Alive do
                task.wait(0.5)
                local now = os.clock()
                local fps = math.floor(frames / math.max(now - last, 0.001) + 0.5)
                frames = 0; last = now
                local ping = currentPing()
                fpsH[#fpsH + 1] = fps; pingH[#pingH + 1] = ping
                if #fpsH > N then table.remove(fpsH, 1) end
                if #pingH > N then table.remove(pingH, 1) end
                pcall(function()
                    local a, b, c = stat(fpsH)
                    fpsBig.Text = fps .. " fps"; fpsMM.Text = a .. " / " .. b .. " / " .. c
                    local a2, b2, c2 = stat(pingH)
                    pingBig.Text = ping .. " ms"; pingMM.Text = a2 .. " / " .. b2 .. " / " .. c2
                    paintBars(fpsBars, fpsH, math.max(60, c))
                    paintBars(pingBars, pingH, math.max(100, c2))
                    plLbl.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
                    local s = math.floor(now - t0)
                    ssLbl.Text = (s >= 3600) and (math.floor(s / 3600) .. "h " .. math.floor(s % 3600 / 60) .. "m")
                        or (s >= 60) and (math.floor(s / 60) .. "m " .. (s % 60) .. "s") or (s .. "s")
                end)
            end
        end)
    end)

    ----- Game -----
    try(W, "Home", "Game", function()
        local c3 = page:AddCard({ Title = "Game", Icon = "▶", Column = 1 })
        local gf = c3:Custom(54)
        local gname, gcreator = info.Game or "Game", ""
        pcall(function()
            local pi = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
            gname = pi.Name or gname
            gcreator = pi.Creator and pi.Creator.Name or ""
        end)
        local gi = mk("ImageLabel", {
            Size = UDim2.fromOffset(48, 48), BorderSizePixel = 0, B = { BackgroundColor3 = "Row" },
            Image = "rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=150&h=150", Parent = gf,
        })
        cornerS(gi)
        local gn = label(gf, gname, 13, "Text", FB); gn.Position = UDim2.fromOffset(58, 6); gn.Size = UDim2.new(1, -60, 0, 18); gn.TextTruncate = Enum.TextTruncate.AtEnd
        local gs = label(gf, (gcreator ~= "" and ("by " .. gcreator .. "  ·  ") or "") .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers .. " players", 10, "Muted", F)
        gs.Position = UDim2.fromOffset(58, 26); gs.Size = UDim2.new(1, -60, 0, 14); gs.TextTruncate = Enum.TextTruncate.AtEnd
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
            { Text = "↻ Rejoin", Callback = function()
                pcall(function()
                    if #Players:GetPlayers() <= 1 then TS:Teleport(game.PlaceId, LP) else TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end
                end)
            end },
            { Text = "⇄ Hop", Callback = function() hop("Desc", true) end },
            { Text = "▼ Lowest", Callback = function() hop("Asc", false) end },
            { Text = "⧉ Job ID", Callback = function()
                if has(setclipboard) then setclipboard(game.JobId); W:Notify({ Title = "Job ID", Desc = "Disalin ke clipboard", Color = "#50C864" })
                else W:Notify({ Title = "Job ID", Desc = game.JobId, Color = "#6495ED", Duration = 6 }) end
            end },
        } })
        c3:Label({ Text = "Job " .. string.sub(game.JobId, 1, 8) .. "…  ·  Place " .. game.PlaceId, Size = 10 })
    end)

    return page
end

-- ===== halaman Player =====
function Window:BuildPlayer()
    local W = self
    local page = W:AddPage({ Name = "Player", Icon = "☺" })
    local TS = game:GetService("TeleportService")
    local function char() return LP.Character end
    local function hum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
    local function root() local c = LP.Character; return c and (c:FindFirstChild("HumanoidRootPart")) end
    local function conn(c) W.Conns[#W.Conns + 1] = c; return c end

    local st = { walk = false, speed = 32, ijump = false, noclip = false, prompt = false, fly = false, flyspeed = 60, nopause = false }
    local origWS

    try(W, "Player", "Movement", function()
        local c = page:AddCard({ Title = "Movement", Icon = "✥", Column = 1 })
        c:Toggle({ Title = "WalkSpeed", id = "ply_walk", Callback = function(v)
            st.walk = v
            local h = hum()
            if v and h then origWS = origWS or h.WalkSpeed end
            if not v and h and origWS then h.WalkSpeed = origWS; origWS = nil end
        end })
        c:Slider({ Title = "Speed", Min = 16, Max = 200, Value = 32, id = "ply_speed", Callback = function(v) st.speed = v end })
        c:Toggle({ Title = "Infinite Jump", id = "ply_ijump", Callback = function(v) st.ijump = v end })
        c:Toggle({ Title = "Noclip", id = "ply_noclip", Callback = function(v) st.noclip = v end })
        c:Toggle({ Title = "Instant ProximityPrompt", id = "ply_prompt", Callback = function(v)
            st.prompt = v
            if v then
                task.spawn(function()
                    for _, d in ipairs(workspace:GetDescendants()) do
                        if d:IsA("ProximityPrompt") then pcall(function() d.HoldDuration = 0 end) end
                    end
                end)
            end
        end })
    end)

    try(W, "Player", "Fly", function()
        local c = page:AddCard({ Title = "Fly", Icon = "✈", Column = 2 })
        c:Toggle({ Title = "Fly", id = "ply_fly", Callback = function(v) st.fly = v end })
        c:Slider({ Title = "Fly Speed", Min = 10, Max = 300, Value = 60, id = "ply_flyspeed", Callback = function(v) st.flyspeed = v end })
        c:Label({ Text = "Space / E naik, Q turun (HP: lompat = naik)", Size = 10 })
    end)

    -- ----- logika loop -----
    local bv, bg
    local function stopFly()
        if bv then pcall(function() bv:Destroy() end); bv = nil end
        if bg then pcall(function() bg:Destroy() end); bg = nil end
        local h = hum(); if h then pcall(function() h.PlatformStand = false end) end
    end
    conn(RunService.Heartbeat:Connect(function()
        if not W.Alive then return end
        local h = hum()
        if st.walk and h then h.WalkSpeed = st.speed end
        if st.fly and h and root() then
            local r = root()
            if not bv or bv.Parent ~= r then
                stopFly()
                bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(1e9, 1e9, 1e9); bv.Velocity = Vector3.zero; bv.Parent = r
                bg = Instance.new("BodyGyro"); bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9); bg.P = 9e4; bg.Parent = r
            end
            local cam = workspace.CurrentCamera
            local rel = cam.CFrame:VectorToObjectSpace(h.MoveDirection)
            local dir = cam.CFrame.LookVector * (-rel.Z) + cam.CFrame.RightVector * rel.X
            local up = 0
            if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then up += 1 end
            if UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then up -= 1 end
            bv.Velocity = dir * st.flyspeed + Vector3.new(0, up * st.flyspeed, 0)
            bg.CFrame = cam.CFrame
            h.PlatformStand = true
        elseif bv then
            stopFly()
        end
    end))
    conn(RunService.Stepped:Connect(function()
        if st.noclip and char() then
            for _, p in ipairs(char():GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end))
    conn(UIS.JumpRequest:Connect(function()
        if st.ijump and W.Alive then
            local h = hum()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end))
    pcall(function()
        local PPS = game:GetService("ProximityPromptService")
        conn(PPS.PromptShown:Connect(function(p) if st.prompt then pcall(function() p.HoldDuration = 0 end) end end))
        conn(PPS.PromptButtonHoldBegan:Connect(function(p)
            if st.prompt and has(fireproximityprompt) then pcall(fireproximityprompt, p) end
        end))
    end)

    -- ----- Client -----
    local origLight, boosted = nil, false
    local function setBoost(v)
        local L = game:GetService("Lighting")
        if v and not boosted then
            boosted = true
            origLight = { GlobalShadows = L.GlobalShadows, Technology = nil }
            pcall(function() L.GlobalShadows = false end)
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            task.spawn(function()
                for _, d in ipairs(workspace:GetDescendants()) do
                    if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                        pcall(function() d.Enabled = false end)
                    end
                end
            end)
            for _, e in ipairs(L:GetChildren()) do
                if e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("ColorCorrectionEffect") then
                    pcall(function() e.Enabled = false end)
                end
            end
        elseif not v and boosted then
            boosted = false
            pcall(function() L.GlobalShadows = origLight.GlobalShadows end)
            for _, e in ipairs(L:GetChildren()) do
                if e:IsA("PostEffect") then pcall(function() e.Enabled = true end) end
            end
        end
    end

    local reconn
    try(W, "Player", "Client", function()
        local c = page:AddCard({ Title = "Client", Icon = "▭", Column = 1 })
        c:Toggle({ Title = "No Gameplay Paused", id = "cl_nopause", Callback = function(v)
            st.nopause = v
            if v then
                task.spawn(function()
                    while st.nopause and W.Alive do
                        pcall(function() workspace.StreamingIntegrityMode = Enum.StreamingIntegrityMode.Disabled end)
                        task.wait(1)
                    end
                end)
            end
        end })
        c:Toggle({ Title = "Auto Reconnect on Kick", id = "cl_reconnect", Callback = function(v)
            if reconn then pcall(function() reconn:Disconnect() end); reconn = nil end
            if v then
                task.spawn(function()
                    pcall(function()
                        local ov = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 8):WaitForChild("promptOverlay", 8)
                        reconn = ov.ChildAdded:Connect(function(ch)
                            if ch.Name == "ErrorPrompt" then
                                task.wait(2)
                                pcall(function() TS:Teleport(game.PlaceId, LP) end)
                            end
                        end)
                    end)
                end)
            end
        end })
        c:Toggle({ Title = "Disable 3D Rendering", id = "cl_no3d", Callback = function(v)
            pcall(function() RunService:Set3dRenderingEnabled(not v) end)
        end })
        c:Toggle({ Title = "FPS Boost", id = "cl_fpsboost", Callback = setBoost })
        c:Toggle({ Title = "Hide UI On Start", id = "cl_hide" })
    end)

    W:OnUnload(function()
        stopFly()
        local h = hum(); if h and origWS then pcall(function() h.WalkSpeed = origWS end) end
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
        setBoost(false)
        if reconn then pcall(function() reconn:Disconnect() end) end
    end)
    return page
end

-- ===== halaman Settings =====
function Window:BuildSettings()
    local W = self
    local page = W:AddPage({ Name = "Settings", Icon = "⚙" })

    ----- Menu -----
    try(W, "Settings", "Menu", function()
        local c = page:AddCard({ Title = "Menu", Icon = "▭", Column = 1 })
        c:Keybind({ Title = "Toggle UI", Value = W.ToggleKey, id = "ui_key", OnChanged = function(k) W.ToggleKey = k end })
        c:Dropdown({ Title = "Toggle button", List = { "Always", "Mobile only", "Hidden" }, Value = "Always", id = "ui_btnmode",
            Callback = function(v) W.BtnMode = v or "Always"; W:RefreshChrome() end })
        local afkOn = false
        pcall(function()
            local idleConn = LP.Idled:Connect(function()
                if not afkOn then return end
                local vu = game:GetService("VirtualUser")
                vu:CaptureController(); vu:ClickButton2(Vector2.new())
            end)
            W.Conns[#W.Conns + 1] = idleConn
        end)
        c:Toggle({ Title = "Anti AFK", Value = true, id = "anti_afk", Callback = function(v) afkOn = v end })
        c:Toggle({ Title = "Minimize UI on Start", id = "ui_minstart" })
        c:Button({ Text = "Unload", Icon = "⏻", Callback = function() W:Destroy() end })
    end)

    ----- Configs -----
    try(W, "Settings", "Configs", function()
        local c = page:AddCard({ Title = "Configs", Icon = "▤", Column = 1 })
        local selected
        local box = c:Custom(104)
        local bf = mk("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, B = { BackgroundColor3 = "Field", ScrollBarImageColor3 = "Stroke" }, Parent = box,
        })
        cornerS(bf); stroke(bf); pad(bf, 4, 4, 4, 4); list(bf, 2)
        local status = c:Label({ Text = "-" })
        local cname = c:Input({ Title = "Config Name:", Placeholder = "Type config name here..." })
        local autoToggle
        local function refresh()
            local l = W:ListConfigs()
            for _, ch in ipairs(bf:GetChildren()) do if ch:IsA("TextButton") or ch:IsA("TextLabel") then ch:Destroy() end end
            if #l == 0 then
                local e = label(bf, "no configs yet", 12, "Muted", FM, Enum.TextXAlignment.Center); e.Size = UDim2.new(1, 0, 0, 30)
            end
            for i, nm in ipairs(l) do
                local b = mk("TextButton", { Size = UDim2.new(1, -4, 0, 26), Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i,
                    BackgroundTransparency = (nm == selected) and 0.3 or 1, B = { BackgroundColor3 = "Row" }, Parent = bf })
                cornerS(b)
                local tx = label(b, nm, 12, (nm == selected) and "Accent" or "Text", FM); tx.Position = UDim2.fromOffset(10, 0); tx.Size = UDim2.new(1, -14, 1, 0)
                b.MouseButton1Click:Connect(function() selected = nm; cname:Set(nm, true); refresh() end)
            end
            status:SetText(#l .. " saved  ·  loaded: " .. (W.LoadedCfg or "none") .. "  ·  auto: " .. (W:GetAutoload() or "none"))
        end
        local function pick()
            local n = cname:Get()
            if n ~= "" then return n end
            return selected
        end
        c:Buttons({ Buttons = {
            { Text = "Save", Callback = function()
                local n = pick()
                if not n or n == "" then W:Notify({ Title = "Config", Desc = "Isi nama atau pilih config", Color = "#FFA500" }) return end
                local ok = W:SaveConfig(n); selected = n; refresh()
                W:Notify({ Title = ok and "Saved" or "Gagal", Desc = n .. (W.CanFS and "" or " (sementara, executor tanpa writefile)"), Color = ok and "#50C864" or "#DC3232" })
            end },
            { Text = "Load", Callback = function()
                local n = selected or cname:Get()
                if not n or n == "" then W:Notify({ Title = "Config", Desc = "Pilih config dulu", Color = "#FFA500" }) return end
                local ok = W:LoadConfig(n); refresh()
                W:Notify({ Title = ok and "Loaded" or "Gagal", Desc = n, Color = ok and "#50C864" or "#DC3232" })
            end },
        } })
        c:Buttons({ Buttons = {
            { Text = "Delete", Color = "#E5484D", Callback = function()
                if not selected then return end
                W:DeleteConfig(selected); W:Notify({ Title = "Deleted", Desc = selected, Color = "#DC3232" }); selected = nil; refresh()
            end },
            { Text = "Refresh", Callback = refresh },
        } })
        autoToggle = c:Toggle({ Title = "Auto Load Config", Value = W:GetAutoload() ~= nil, Hidden = true, Callback = function(v)
            if v then
                local n = selected or W.LoadedCfg
                if not n then W:Notify({ Title = "Auto Load", Desc = "Pilih / load config dulu", Color = "#FFA500" }) autoToggle:Set(false, true) return end
                W:SetAutoload(n); W:Notify({ Title = "Auto Load", Desc = n, Color = "#50C864" })
            else
                W:SetAutoload(nil)
            end
            refresh()
        end })
        c:Label({ Text = "Loads the selected config on launch", Size = 10 })
        c:Divider("more")
        c:Buttons({ Buttons = {
            { Text = "Rename", Callback = function()
                local n = cname:Get()
                if selected and n ~= "" and n ~= selected and W:RenameConfig(selected, n) then selected = n; refresh()
                else W:Notify({ Title = "Rename", Desc = "Pilih config lalu isi nama baru", Color = "#FFA500" }) end
            end },
            { Text = "Reset", Color = "#E5484D", Callback = function() W:ResetAll(); W:Notify({ Title = "Reset", Desc = "Semua pengaturan dikembalikan", Color = "#FFA500" }) end },
        } })
        c:Dropdown({ Title = "Autoload mode", List = { "All accounts", "This account" }, Value = W:GetAutoMode(), Hidden = true, Callback = function(v)
            if v then
                local cur = W:GetAutoload()
                W:SetAutoMode(v)
                if cur then W:SetAutoload(cur) end
                refresh()
            end
        end })
        c:Divider("share")
        c:Button({ Text = "Copy code", Callback = function()
            local code = W:ExportCode()
            if has(setclipboard) then setclipboard(code); W:Notify({ Title = "Copied", Desc = "Config code disalin", Color = "#50C864" })
            else W:Notify({ Title = "Config code", Desc = string.sub(code, 1, 120), Color = "#6495ED", Duration = 8 }) end
        end })
        local paste = c:Input({ Title = "", Placeholder = "paste a config code...", NoTitle = true })
        c:Button({ Text = "Import code", Callback = function()
            local ok = W:ImportCode(paste:Get())
            W:Notify({ Title = ok and "Imported" or "Gagal", Desc = ok and "Config code diterapkan" or "Code tidak valid", Color = ok and "#50C864" or "#DC3232" })
        end })
        refresh()
    end)

    ----- Themes -----
    try(W, "Settings", "Themes", function()
        local c = page:AddCard({ Title = "Themes", Icon = "◐", Column = 2 })
        local presetDD = c:Dropdown({ Title = "Preset", List = PRESET_LIST, Placeholder = "Preset", Callback = function(v)
            if v then W:ApplyTheme(v) end
        end })
        presetDD:Set("Pink", true)       -- tanpa Callback awal supaya tema tersimpan tidak tertimpa

        local nrow = c:Custom(34)
        local nbox = mk("TextBox", {
            Size = UDim2.new(1, -68, 1, 0), BorderSizePixel = 0, Text = "", PlaceholderText = "theme name", Font = FM, TextSize = 12,
            ClearTextOnFocus = false, B = { BackgroundColor3 = "Field", TextColor3 = "Text", PlaceholderColor3 = "Muted" }, Parent = nrow,
        })
        cornerS(nbox); stroke(nbox); pad(nbox, 10, 0)
        local cbtn = mk("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(60, 34), Text = "Create", Font = FM, TextSize = 11, AutoButtonColor = false, Parent = nrow })
        cornerS(cbtn); stroke(cbtn)
        REG[#REG + 1] = { cbtn, "BackgroundColor3", "Row" }; cbtn.BackgroundColor3 = TH.Row
        REG[#REG + 1] = { cbtn, "TextColor3", "Text" }; cbtn.TextColor3 = TH.Text

        local themeDD = c:Dropdown({ Title = "Theme", List = W:ListThemes(), Placeholder = "no themes", Hidden = true })
        local defLbl
        local function refresh()
            themeDD:SetList(W:ListThemes())
            defLbl:SetText("Default theme: " .. (W:GetDefaultTheme() or "none"))
        end
        cbtn.MouseButton1Click:Connect(function()
            local n = nbox.Text
            if n == "" then W:Notify({ Title = "Theme", Desc = "Isi nama tema", Color = "#FFA500" }) return end
            W:SaveTheme(n); nbox.Text = ""; refresh(); themeDD:Set(n, true)
            W:Notify({ Title = "Theme", Desc = "Dibuat: " .. n, Color = "#50C864" })
        end)
        c:Buttons({ Buttons = {
            { Text = "Save", Callback = function()
                local n = themeDD:Get()
                if not n then W:Notify({ Title = "Theme", Desc = "Pilih tema dulu", Color = "#FFA500" }) return end
                W:SaveTheme(n); W:Notify({ Title = "Theme", Desc = "Disimpan: " .. n, Color = "#50C864" })
            end },
            { Text = "Load", Callback = function()
                local n = themeDD:Get()
                if n and W:LoadTheme(n) then W:Notify({ Title = "Theme", Desc = "Dimuat: " .. n, Color = "#50C864" }) end
            end },
        } })
        c:Buttons({ Buttons = {
            { Text = "Delete", Color = "#E5484D", Callback = function()
                local n = themeDD:Get()
                if n then W:DeleteTheme(n); themeDD:Set(nil, true); refresh() end
            end },
            { Text = "Set Default", Callback = function()
                local n = themeDD:Get()
                if n then W:SetDefaultTheme(n); refresh(); W:Notify({ Title = "Theme", Desc = "Default: " .. n, Color = "#50C864" }) end
            end },
        } })
        defLbl = c:Label({ Text = "Default theme: none", Size = 11 })
        c:Divider("")
        local rows = {}
        for _, e in ipairs({ { "Accent", "Accent" }, { "Background", "Background" }, { "Surface", "Surface" }, { "Text", "Text" }, { "Muted text", "Muted" } }) do
            rows[#rows + 1] = c:ColorRow({ Title = e[1], Get = function() return TH[e[2]] end, Callback = function(col) W:SetThemeColor(e[2], col) end })
        end
        refresh()
    end)

    ----- Interface -----
    try(W, "Settings", "Interface", function()
        local c = page:AddCard({ Title = "Interface", Icon = "▭", Column = 2 })
        c:Dropdown({ Title = "Weather", List = { "None", "Snow", "Rain", "Sparkle" }, Value = "None", id = "set_weather", Callback = function(v) W:SetWeather(v or "None") end })
        c:Dropdown({ Title = "Weather Mode", List = { "Screen", "Window" }, Value = "Screen", id = "set_wmode", Callback = function(v) W:SetWeather(nil, v or "Screen") end })
        c:Toggle({ Title = "Dim", id = "set_dim", Callback = function(v) W:SetDim(v) end })
        c:Toggle({ Title = "Transparent", id = "set_trans", Callback = function(v) W:SetTransparent(v) end })
        c:Dropdown({ Title = "Drag Style", List = { "Normal", "Outline" }, Value = "Normal", id = "set_drag", Callback = function(v) W.DragStyle = v or "Normal" end })
        c:Dropdown({ Title = "Dynamic Island", List = { "Always", "Show on Hover", "Hidden" }, Value = "Always", id = "set_island", Callback = function(v) W.IslandMode = v or "Always"; W:RefreshChrome() end })
        c:Toggle({ Title = "Adaptive Size", Value = true, id = "set_adaptive", Callback = function(v) W.Adaptive = v; W:ApplyScale() end })
        c:Slider({ Title = "UI Scale", Min = 50, Max = 150, Value = 100, Suffix = "%", id = "ui_scale", Callback = function(v) W.UIScaleMul = v / 100; W:ApplyScale() end })
        c:Dropdown({ Title = "Density", List = { "Compact", "Default", "Comfortable" }, Value = "Default", id = "set_density", Callback = function(v)
            STATE.Density = (v == "Compact" and -4) or (v == "Comfortable" and 4) or 0
            applyDensity()
        end })
        c:Slider({ Title = "Corner Radius", Min = 0, Max = 16, Value = 8, Suffix = "px", id = "set_radius", Callback = function(v) STATE.Radius = v; applyRadius() end })
        c:Dropdown({ Title = "Background", List = { "None", "Image" }, Value = "None", id = "set_bgmode", Callback = function(v) W:SetBackgroundMode(v or "None") end })
        local bgrow = c:Custom(34)
        local bbox = mk("TextBox", {
            Size = UDim2.new(1, -58, 1, 0), BorderSizePixel = 0, Text = "", PlaceholderText = "image id or url", Font = FM, TextSize = 12,
            ClearTextOnFocus = false, B = { BackgroundColor3 = "Field", TextColor3 = "Text", PlaceholderColor3 = "Muted" }, Parent = bgrow,
        })
        cornerS(bbox); stroke(bbox); pad(bbox, 10, 0)
        local sbtn = mk("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(52, 34), Text = "Set", Font = FM, TextSize = 11, AutoButtonColor = false, Parent = bgrow })
        cornerS(sbtn); stroke(sbtn)
        REG[#REG + 1] = { sbtn, "BackgroundColor3", "Row" }; sbtn.BackgroundColor3 = TH.Row
        REG[#REG + 1] = { sbtn, "TextColor3", "Text" }; sbtn.TextColor3 = TH.Text
        sbtn.MouseButton1Click:Connect(function()
            local ok = W:SetBackground(bbox.Text)
            local dd = W.Elements.set_bgmode
            if ok and dd then dd:Set("Image") end
            W:Notify({ Title = "Background", Desc = ok and "Gambar diterapkan" or "ID / URL tidak valid", Color = ok and "#50C864" or "#DC3232" })
        end)
        c:Slider({ Title = "Background Opacity", Min = 0, Max = 100, Value = 65, Suffix = "%", id = "set_bgopacity", Callback = function(v) W:SetBackgroundOpacity(v / 100) end })
    end)

    return page
end

Lib.Presets = PRESETS
return Lib
