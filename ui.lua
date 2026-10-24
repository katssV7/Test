-- KatssinnnUI | library UI baru: sidebar (Home / Main), kartu dua kolom, toggle & slider gaya baru.
-- Dipakai lewat: local UI = loadstring(game:HttpGet(".../ui.lua"))()
--
-- Perbaikan penting: saat config / nilai tersimpan dipulihkan, SEMUA elemen memanggil Callback-nya lagi
-- (bukan cuma mengubah tampilan), jadi toggle yang terlihat ON benar-benar menjalankan fiturnya.

local Players       = game:GetService("Players")
local UIS           = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local HttpService   = game:GetService("HttpService")
local LP            = Players.LocalPlayer

local Lib = {}
local Window = {}
Window.__index = Window

local function C(h) return Color3.fromHex(h) end

local T = {
    BG     = C("#151515"),
    Side   = C("#101010"),
    Card   = C("#1B1B1B"),
    Row    = C("#242424"),
    RowHi  = C("#2E2E2E"),
    Field  = C("#161616"),
    Stroke = C("#2A2A2A"),
    Text   = C("#F3F3EE"),
    Muted  = C("#8B8B85"),
    Off    = C("#3A3A3A"),
    Knob   = C("#B4B4B4"),
}

local PRESETS = {
    Pink = "#FF007F", Lime = "#B7F34A", Blue = "#0088FF",
    Purple = "#9955FF", Red = "#E5484D", Cyan = "#22D3EE",
}
local PRESET_LIST = { "Pink", "Lime", "Blue", "Purple", "Red", "Cyan" }

local F, FB, FM = Enum.Font.Gotham, Enum.Font.GothamBold, Enum.Font.GothamMedium

-- ===== helpers =====
local function mk(class, props)
    local o = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else o[k] = v end
    end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, r) return mk("UICorner", { CornerRadius = UDim.new(0, r), Parent = o }) end
local function stroke(o, col, th) return mk("UIStroke", { Color = col or T.Stroke, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o }) end
local function pad(o, l, t, r, b)
    return mk("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l), PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l), Parent = o })
end
local function list(o, gap, dir)
    return mk("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = dir or Enum.FillDirection.Vertical, Parent = o })
end
local function col3(c, default)
    if c == nil then return default end
    if type(c) == "string" then
        local ok, r = pcall(Color3.fromHex, c)
        return ok and r or default
    end
    return c
end

local function label(parent, text, size, col, font, xa)
    return mk("TextLabel", {
        BackgroundTransparency = 1, Text = tostring(text), TextSize = size or 12, TextColor3 = col3(col, T.Text),
        Font = font or FM, TextXAlignment = xa or Enum.TextXAlignment.Left, Parent = parent,
    })
end
local function tw(o, t, props)
    local ok = pcall(function()
        TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
    end)
    if not ok then for k, v in pairs(props) do pcall(function() o[k] = v end) end end
end
local function has(f) return typeof(f) == "function" end

local function drag(handle, target, onMoved)
    local dragging, startPos, startIn = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startIn, startPos = true, i.Position, target.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startIn
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            if onMoved then onMoved(d.Magnitude) end
        end
    end)
end

-- ===== Window =====
function Lib:CreateWindow(opts)
    opts = opts or {}
    local W = setmetatable({}, Window)
    W.Opts       = opts
    W.Accent     = C(opts.Accent or PRESETS.Pink)
    W.Elements   = {}
    W.Pages      = {}
    W.PageList   = {}
    W.OnUnloads  = {}
    W.Pending    = {}
    W.hooks      = {}
    W.accents    = {}
    W.ToggleKey  = opts.ToggleKey or Enum.KeyCode.RightControl
    W.UIScaleMul = 1
    W.Folder     = opts.Folder or "KatssinnnHub"
    W.Mem        = {}            -- penyimpanan config sementara kalau executor tidak punya writefile
    W.Alive      = true

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

    local frame = mk("Frame", {
        Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(640, 360), BackgroundColor3 = T.BG, BorderSizePixel = 0, Parent = gui,
    })
    corner(frame, 10); stroke(frame, T.Stroke, 1)
    W.Frame = frame
    local uiscale = mk("UIScale", { Parent = frame })
    W.UIScale = uiscale

    function W:ApplyScale()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local auto = math.min(vp.X / 720, vp.Y / 420, 1.25)
        uiscale.Scale = math.max(0.5, auto) * self.UIScaleMul
    end
    W:ApplyScale()
    pcall(function()
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() W:ApplyScale() end)
    end)

    -- accent: daftar objek yang ikut berubah warna
    function W:_acc(inst, prop)
        self.accents[#self.accents + 1] = { inst, prop }
        inst[prop] = self.Accent
    end
    function W:_hook(fn) self.hooks[#self.hooks + 1] = fn end
    function W:SetAccent(col)
        if typeof(col) == "string" then col = C(PRESETS[col] or col) end
        self.Accent = col
        for _, a in ipairs(self.accents) do pcall(function() a[1][a[2]] = col end) end
        for _, h in ipairs(self.hooks) do pcall(h) end
    end

    -- ===== sidebar =====
    local side = mk("Frame", { Name = "Side", Size = UDim2.new(0, 150, 1, 0), BackgroundColor3 = T.Side, BorderSizePixel = 0, Parent = frame })
    corner(side, 10)
    mk("Frame", { Size = UDim2.new(0, 12, 1, 0), Position = UDim2.new(1, -12, 0, 0), BackgroundColor3 = T.Side, BorderSizePixel = 0, Parent = side })

    local brand = mk("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, Parent = side })
    if opts.Icon then
        mk("ImageLabel", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(12, 14), BackgroundTransparency = 1, Image = opts.Icon, Parent = brand })
    end
    local bt = label(brand, opts.Title or "KatssinnnHub", 13, T.Text, FB)
    bt.Position = UDim2.fromOffset(opts.Icon and 50 or 14, 14); bt.Size = UDim2.new(1, -56, 0, 16); bt.TextTruncate = Enum.TextTruncate.AtEnd
    local bv = label(brand, opts.Version or "v1.0", 10, T.Muted, F)
    bv.Position = UDim2.fromOffset(opts.Icon and 50 or 14, 31); bv.Size = UDim2.new(1, -56, 0, 12)

    local nav = mk("Frame", { Name = "Nav", Position = UDim2.fromOffset(8, 62), Size = UDim2.new(1, -16, 1, -132), BackgroundTransparency = 1, Parent = side })
    list(nav, 4)

    local foot = mk("Frame", { Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 1, -58), BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = side })
    corner(foot, 8); stroke(foot, T.Stroke, 1)
    local av = mk("ImageLabel", {
        Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(8, 10), BackgroundColor3 = T.Row, BorderSizePixel = 0,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. LP.UserId .. "&w=150&h=150", Parent = foot,
    })
    corner(av, 15)
    local fn = label(foot, LP.DisplayName, 11, T.Text, FB)
    fn.Position = UDim2.fromOffset(44, 9); fn.Size = UDim2.new(1, -50, 0, 14); fn.TextTruncate = Enum.TextTruncate.AtEnd
    local fg = label(foot, opts.Game or "", 9, T.Muted, F)
    fg.Position = UDim2.fromOffset(44, 25); fg.Size = UDim2.new(1, -50, 0, 12); fg.TextTruncate = Enum.TextTruncate.AtEnd
    W.FooterGame = fg

    -- ===== konten =====
    local content = mk("Frame", { Name = "Content", Position = UDim2.fromOffset(150, 0), Size = UDim2.new(1, -150, 1, 0), BackgroundTransparency = 1, Parent = frame })
    local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = content })
    W.HeaderIcon = label(header, "", 16, nil, FB); W.HeaderIcon.Position = UDim2.fromOffset(14, 0); W.HeaderIcon.Size = UDim2.new(0, 22, 1, 0)
    W:_acc(W.HeaderIcon, "TextColor3")
    W.HeaderTitle = label(header, "", 15, T.Text, FB); W.HeaderTitle.Position = UDim2.fromOffset(40, 0); W.HeaderTitle.Size = UDim2.new(0.4, 0, 1, 0)

    local minBtn = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 1, Text = "—", TextColor3 = T.Muted, Font = FB, TextSize = 14, Parent = header,
    })
    local searchF = mk("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -44, 0.5, 0), Size = UDim2.fromOffset(160, 28),
        BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = header,
    })
    corner(searchF, 7); stroke(searchF, T.Stroke, 1)
    local searchBox = mk("TextBox", {
        Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = "",
        PlaceholderText = "Search", PlaceholderColor3 = T.Muted, TextColor3 = T.Text, Font = FM, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = searchF,
    })

    local holder = mk("Frame", { Name = "Pages", Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48), BackgroundTransparency = 1, ClipsDescendants = true, Parent = content })
    W.Holder = holder

    drag(header, frame)
    drag(brand, frame)

    -- tombol melayang (buka/tutup)
    local fbtn = mk("TextButton", {
        Name = "Toggle", Position = UDim2.new(0, 14, 0.5, -22), Size = UDim2.fromOffset(44, 44),
        BackgroundColor3 = C("#101010"), Text = "▦", TextSize = 22, Font = FB, AutoButtonColor = false, Parent = gui,
    })
    corner(fbtn, 12); stroke(fbtn, T.Stroke, 1)
    W:_acc(fbtn, "TextColor3")
    local moved = 0
    drag(fbtn, fbtn, function(d) moved = math.max(moved, d) end)
    fbtn.InputBegan:Connect(function() moved = 0 end)
    fbtn.MouseButton1Click:Connect(function()
        if moved > 6 then return end
        W:SetVisible(not frame.Visible)
    end)
    minBtn.MouseButton1Click:Connect(function() W:SetVisible(false) end)

    function W:SetVisible(v)
        frame.Visible = v
        if not v then self:ClosePopup() end
    end

    W.Conns = {}
    W.Conns[#W.Conns + 1] = UIS.InputBegan:Connect(function(i, gp)
        if gp or not W.Alive then return end
        if i.KeyCode == W.ToggleKey then W:SetVisible(not frame.Visible) end
    end)

    -- ===== navigasi / halaman =====
    local function selectPage(page)
        for _, p in ipairs(W.PageList) do
            p.Scroll.Visible = (p == page)
            p.NavBtn.BackgroundTransparency = (p == page) and 0 or 1
            p.NavText.TextColor3 = (p == page) and T.Text or T.Muted
        end
        W.Current = page
        W.HeaderIcon.Text = page.Icon
        W.HeaderTitle.Text = page.Name
        searchBox.Text = ""
        W:ClosePopup()
    end
    W.SelectPage = function(self, name)
        local p = self.Pages[name]
        if p then selectPage(p) end
    end

    local function applyFilter()
        local p = W.Current
        if not p then return end
        local q = string.lower(searchBox.Text or "")
        for _, card in ipairs(p.Cards) do
            local titleHit = (q == "") or (card.TitleLower:find(q, 1, true) ~= nil)
            local anyItem = false
            for _, it in ipairs(card.Items) do
                local vis = titleHit or (it.Text:find(q, 1, true) ~= nil)
                it.Frame.Visible = vis
                if vis then anyItem = true end
            end
            card.Frame.Visible = titleHit or anyItem
        end
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)

    function W:AddPage(o)
        local page = { Name = o.Name, Icon = o.Icon or "•", Cards = {}, Win = W, NextCol = 1 }

        local btn = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = T.Row, BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, Parent = nav,
        })
        corner(btn, 7)
        local ic = label(btn, page.Icon, 14, T.Muted, FM, Enum.TextXAlignment.Center)
        ic.Position = UDim2.fromOffset(6, 0); ic.Size = UDim2.new(0, 24, 1, 0)
        local tx = label(btn, o.Name, 12, T.Muted, FM)
        tx.Position = UDim2.fromOffset(36, 0); tx.Size = UDim2.new(1, -40, 1, 0)
        page.NavBtn, page.NavText = btn, tx
        btn.MouseButton1Click:Connect(function() selectPage(page) end)

        local scroll = mk("ScrollingFrame", {
            Name = o.Name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = T.Stroke, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = holder,
        })
        pad(scroll, 12, 4, 14, 12)
        local cols = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroll })
        list(cols, 10, Enum.FillDirection.Horizontal)
        page.Cols = {}
        for i = 1, 2 do
            local c = mk("Frame", {
                Size = UDim2.new(0.5, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                LayoutOrder = i, Parent = cols,
            })
            list(c, 10)
            page.Cols[i] = c
        end
        page.Scroll = scroll

        -- ===== kartu =====
        function page:AddCard(co)
            local colIdx = co.Column or self.NextCol
            self.NextCol = (colIdx == 1) and 2 or 1
            local card = { Win = W, Page = self, Items = {}, TitleLower = string.lower(co.Title or "") }
            local cf = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = self.Cols[colIdx] })
            corner(cf, 9); stroke(cf, T.Stroke, 1)
            list(cf, 0)
            card.Frame = cf

            local hd = mk("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1, Parent = cf })
            local hi = label(hd, co.Icon or "•", 14, nil, FB, Enum.TextXAlignment.Center)
            hi.Position = UDim2.fromOffset(8, 0); hi.Size = UDim2.new(0, 22, 1, 0)
            W:_acc(hi, "TextColor3")
            local ht = label(hd, co.Title or "", 12, T.Text, FB)
            ht.Position = UDim2.fromOffset(34, 0); ht.Size = UDim2.new(1, -70, 1, 0)
            local chev = label(hd, "v", 11, T.Muted, FB, Enum.TextXAlignment.Center)
            chev.Position = UDim2.new(1, -30, 0, 0); chev.Size = UDim2.new(0, 22, 1, 0)

            local body = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = cf })
            pad(body, 12, 4, 12, 12)
            list(body, 8)
            card.Body = body
            local open = true
            local function setOpen(v)
                open = v
                body.Visible = v
                chev.Text = v and "v" or ">"
            end
            hd.MouseButton1Click:Connect(function() setOpen(not open) end)
            if co.Collapsed then setOpen(false) end

            local function reg(f, title)
                card.Items[#card.Items + 1] = { Frame = f, Text = string.lower(title or "") }
            end
            local function row(h, title)
                local f = mk("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = #card.Items + 1, Parent = body })
                reg(f, title)
                return f
            end
            local function register(o2, obj)
                if o2.id then W.Elements[o2.id] = obj end
            end

            -- ----- Toggle -----
            function card:Toggle(o2)
                local f = row(30, o2.Title)
                local t = label(f, o2.Title or "", 12, T.Text, FM)
                t.Size = UDim2.new(1, -56, 1, 0); t.TextTruncate = Enum.TextTruncate.AtEnd
                local sw = mk("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(42, 22), BackgroundColor3 = T.Off, BorderSizePixel = 0, Parent = f })
                corner(sw, 11)
                local knob = mk("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = T.Knob, BorderSizePixel = 0, Parent = sw })
                corner(knob, 8)
                local click = mk("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f })
                local cb = o2.Callback or function() end
                local obj = { Frame = f, Value = false, Id = o2.id }
                local function visual(v)
                    tw(sw, 0.15, { BackgroundColor3 = v and W.Accent or T.Off })
                    tw(knob, 0.15, { Position = v and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = v and T.BG or T.Knob })
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
                W:_hook(function() if obj.Value then sw.BackgroundColor3 = W.Accent end end)
                click.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
                if o2.Value then
                    obj:Set(true, true)
                    W.Pending[#W.Pending + 1] = function() pcall(cb, true) end   -- nilai awal ON ikut dijalankan
                end
                register(o2, obj)
                return obj
            end

            -- ----- Slider -----
            function card:Slider(o2)
                local f = row(44, o2.Title)
                local t = label(f, o2.Title or "", 12, T.Text, FM)
                t.Size = UDim2.new(1, -70, 0, 20); t.TextTruncate = Enum.TextTruncate.AtEnd
                local box = mk("TextBox", {
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(56, 20),
                    BackgroundColor3 = T.Field, Text = "", TextColor3 = T.Text, Font = FM, TextSize = 11,
                    ClearTextOnFocus = false, Parent = f,
                })
                corner(box, 5)
                local bs = stroke(box, T.Stroke, 1)
                local track = mk("Frame", { Position = UDim2.new(0, 0, 0, 32), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = T.Off, BorderSizePixel = 0, Parent = f })
                corner(track, 2)
                local fill = mk("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = track })
                corner(fill, 2); W:_acc(fill, "BackgroundColor3")
                local thumb = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0, Parent = track })
                corner(thumb, 6); W:_acc(thumb, "BackgroundColor3")
                local hit = mk("TextButton", { Position = UDim2.new(0, -4, 0, 24), Size = UDim2.new(1, 8, 0, 20), BackgroundTransparency = 1, Text = "", Parent = f })

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
                W:_hook(function() bs.Color = T.Stroke end)

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
                UIS.InputChanged:Connect(function(i)
                    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                        fromX(i.Position.X)
                    end
                end)
                UIS.InputEnded:Connect(function(i)
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
                W.Pending[#W.Pending + 1] = function() pcall(cb, obj.Value) end   -- nilai awal ikut dipakai
                register(o2, obj)
                return obj
            end

            -- ----- Button -----
            local function styleButton(b, col)
                b.BackgroundColor3 = T.Row
                b.TextColor3 = col3(col, T.Text)
                b.MouseEnter:Connect(function() tw(b, 0.12, { BackgroundColor3 = T.RowHi }) end)
                b.MouseLeave:Connect(function() tw(b, 0.12, { BackgroundColor3 = T.Row }) end)
            end

            function card:Button(o2)
                local f = row(30, o2.Title or o2.Text)
                local b = mk("TextButton", {
                    Size = UDim2.fromScale(1, 1), Text = o2.Text or o2.Title or "", Font = FM, TextSize = 12,
                    AutoButtonColor = false, BorderSizePixel = 0, Parent = f,
                })
                corner(b, 6); stroke(b, T.Stroke, 1)
                styleButton(b, o2.Color)
                local cb = o2.Callback or function() end
                b.MouseButton1Click:Connect(function() pcall(cb) end)
                local obj = { Frame = f }
                function obj:SetText(s) b.Text = s end
                function obj:SetVisible(v) f.Visible = v end
                return obj
            end

            function card:Buttons(o2)   -- beberapa tombol sebaris
                local f = row(30, "")
                list(f, 6, Enum.FillDirection.Horizontal)
                local n = #o2.Buttons
                for i, bd in ipairs(o2.Buttons) do
                    local b = mk("TextButton", {
                        Size = UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0), Text = bd.Text or "", Font = FM, TextSize = 11,
                        AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i, Parent = f,
                    })
                    corner(b, 6); stroke(b, T.Stroke, 1)
                    styleButton(b, bd.Color)
                    b.MouseButton1Click:Connect(function() pcall(bd.Callback or function() end) end)
                end
                return { Frame = f }
            end

            function card:Label(o2)
                local f = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = #card.Items + 1, Parent = body })
                reg(f, o2.Title or o2.Text)
                local t = label(f, o2.Text or o2.Title or "", o2.Size or 11, o2.Color or T.Muted, F)
                t.Size = UDim2.new(1, 0, 0, 0); t.AutomaticSize = Enum.AutomaticSize.Y; t.TextWrapped = true
                local obj = { Frame = f }
                function obj:SetText(s) t.Text = s end
                function obj:SetVisible(v) f.Visible = v end
                return obj
            end

            function card:Custom(h)       -- bingkai kosong untuk isi bebas (dipakai halaman Home)
                return row(h, "")
            end

            -- ----- Input -----
            function card:Input(o2)
                local f = row(54, o2.Title)
                local t = label(f, o2.Title or "", 12, T.Text, FM)
                t.Size = UDim2.new(1, 0, 0, 18)
                local bx = mk("TextBox", {
                    Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.Field, BorderSizePixel = 0,
                    Text = o2.Value or "", PlaceholderText = o2.Placeholder or "", PlaceholderColor3 = T.Muted, TextColor3 = T.Text,
                    Font = FM, TextSize = 12, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = f,
                })
                corner(bx, 6); stroke(bx, T.Stroke, 1); pad(bx, 10, 0)
                local cb = o2.Callback or function() end
                local obj = { Frame = f, Id = o2.id }
                function obj:Set(v, silent) bx.Text = tostring(v or ""); if not silent then pcall(cb, bx.Text) end end
                obj.SetValue = obj.Set
                function obj:Get() return bx.Text end
                obj.GetValue = obj.Get
                function obj:SetVisible(v) f.Visible = v end
                bx.FocusLost:Connect(function() pcall(cb, bx.Text) end)
                register(o2, obj)
                return obj
            end

            -- ----- Keybind -----
            function card:Keybind(o2)
                local f = row(30, o2.Title)
                local t = label(f, o2.Title or "", 12, T.Text, FM)
                t.Size = UDim2.new(1, -80, 1, 0)
                local kb = mk("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(70, 24),
                    BackgroundColor3 = T.Field, Text = "", TextColor3 = T.Text, Font = FM, TextSize = 11, AutoButtonColor = false, Parent = f,
                })
                corner(kb, 6); stroke(kb, T.Stroke, 1)
                local key = o2.Value or Enum.KeyCode.Unknown
                local cb, onChanged = o2.Callback or function() end, o2.OnChanged or function() end
                local obj = { Frame = f, Id = o2.id }
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
                function obj:Get() return key.Name end      -- disimpan sebagai nama
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

            -- ----- Dropdown (multi / single) -----
            function card:Dropdown(o2)
                local f = row(56, o2.Title)
                local t = label(f, o2.Title or "", 12, T.Text, FM)
                t.Size = UDim2.new(1, 0, 0, 18)
                local btn = mk("TextButton", {
                    Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.Field, BorderSizePixel = 0,
                    Text = "", AutoButtonColor = false, Parent = f,
                })
                corner(btn, 6); local bstroke = stroke(btn, T.Stroke, 1)
                local vt = label(btn, "", 12, T.Text, FM)
                vt.Position = UDim2.fromOffset(10, 0); vt.Size = UDim2.new(1, -34, 1, 0); vt.TextTruncate = Enum.TextTruncate.AtEnd
                local arrow = label(btn, "v", 11, T.Muted, FB, Enum.TextXAlignment.Center)
                arrow.Position = UDim2.new(1, -24, 0, 0); arrow.Size = UDim2.new(0, 18, 1, 0)

                local items = o2.List or {}
                local multi = o2.Multi == true or type(o2.Value) == "table"
                local sel = {}
                local cb = o2.Callback or function() end
                local obj = { Frame = f, Id = o2.id, Multi = multi }

                local function indexOf(v) for i, x in ipairs(items) do if x == v then return i end end end
                local function ordered()
                    local out = {}
                    for _, x in ipairs(items) do if sel[x] then out[#out + 1] = x end end
                    return out
                end
                local function refreshText()
                    if multi then
                        local o3 = ordered()
                        vt.Text = (#o3 > 0) and table.concat(o3, ", ") or "None"
                    else
                        local o3 = ordered()
                        vt.Text = o3[1] or (o2.Placeholder or "Select")
                    end
                    vt.TextColor3 = (vt.Text == "None" or vt.Text == (o2.Placeholder or "Select")) and T.Muted or T.Text
                end
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
                    local height = math.min(#items * 28 + 52, 210)
                    local y = rel.Y + btn.AbsoluteSize.Y / sc + 4
                    if y + height > frame.AbsoluteSize.Y / sc - 6 then y = math.max(6, rel.Y - height - 4) end
                    local pop = mk("Frame", {
                        Position = UDim2.fromOffset(rel.X, y), Size = UDim2.fromOffset(width, height),
                        BackgroundColor3 = T.Card, BorderSizePixel = 0, ZIndex = 51, Parent = frame,
                    })
                    corner(pop, 8); stroke(pop, T.Stroke, 1)
                    local sf = mk("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 28), BackgroundColor3 = T.Field, BorderSizePixel = 0, Parent = pop })
                    corner(sf, 6); stroke(sf, T.Stroke, 1)
                    local sb = mk("TextBox", {
                        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -16, 1, 0), BackgroundTransparency = 1, Text = "",
                        PlaceholderText = "Search", PlaceholderColor3 = T.Muted, TextColor3 = T.Text, Font = FM, TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = sf,
                    })
                    local lst = mk("ScrollingFrame", {
                        Position = UDim2.fromOffset(6, 42), Size = UDim2.new(1, -12, 1, -48), BackgroundTransparency = 1, BorderSizePixel = 0,
                        ScrollBarThickness = 2, ScrollBarImageColor3 = T.Stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = pop,
                    })
                    list(lst, 2)
                    local rows = {}
                    local function paint(r, name)
                        local on = sel[name] == true
                        r.txt.TextColor3 = on and W.Accent or T.Text
                        r.bar.Visible = on
                        r.btn.BackgroundTransparency = on and 0.6 or 1
                    end
                    for i, name in ipairs(items) do
                        local b = mk("TextButton", { Size = UDim2.new(1, -4, 0, 26), BackgroundColor3 = T.Row, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = lst })
                        corner(b, 5)
                        local bar = mk("Frame", { Size = UDim2.new(0, 2, 1, -10), Position = UDim2.fromOffset(2, 5), BorderSizePixel = 0, Parent = b })
                        bar.BackgroundColor3 = W.Accent
                        local tx = label(b, tostring(name), 12, T.Text, FM)
                        tx.Position = UDim2.fromOffset(12, 0); tx.Size = UDim2.new(1, -16, 1, 0); tx.TextTruncate = Enum.TextTruncate.AtEnd
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
                    arrow.Text = "^"
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
            return card
        end

        self.Pages[o.Name] = page
        self.PageList[#self.PageList + 1] = page
        if #self.PageList == 1 then selectPage(page) end
        return page
    end

    function W:ClosePopup()
        if self.Popup then
            for _, o in ipairs(self.Popup) do pcall(function() o:Destroy() end) end
            self.Popup = nil
            self.PopupOwner = nil
        end
        if self.PopupArrow then pcall(function() self.PopupArrow.Text = "v" end); self.PopupArrow = nil end
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
        local col = o.Color and (typeof(o.Color) == "string" and C(o.Color) or o.Color) or W.Accent
        local tf = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = toasts })
        corner(tf, 8); stroke(tf, T.Stroke, 1)
        pad(tf, 12, 10, 12, 0)
        list(tf, 3)
        local tt = label(tf, o.Title or "", 13, col, FB)
        tt.Size = UDim2.new(1, 0, 0, 16); tt.LayoutOrder = 1; tt.RichText = true
        if o.Desc and o.Desc ~= "" then
            local td = label(tf, o.Desc, 11, T.Muted, F)
            td.Size = UDim2.new(1, 0, 0, 0); td.AutomaticSize = Enum.AutomaticSize.Y; td.TextWrapped = true; td.LayoutOrder = 2; td.RichText = true
        end
        local pb = mk("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = col, BorderSizePixel = 0, LayoutOrder = 3, Parent = tf })
        mk("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, LayoutOrder = 4, Parent = tf })
        pcall(function()
            TweenService:Create(pb, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) }):Play()
        end)
        task.delay(dur, function() pcall(function() tf:Destroy() end) end)
    end

    -- ===== config =====
    local function cfgPath(name) return W.Folder .. "/" .. name .. ".json" end
    local canFS = has(writefile) and has(readfile) and has(isfile) and has(makefolder) and has(isfolder)
    if canFS then
        pcall(function()
            local cur = ""
            for p in string.gmatch(W.Folder, "[^/]+") do
                cur = (cur == "") and p or (cur .. "/" .. p)
                if not isfolder(cur) then makefolder(cur) end
            end
        end)
    end
    W.CanFS = canFS

    function W:Collect()
        local data = {}
        for id, el in pairs(self.Elements) do
            local ok, v = pcall(el.Get, el)
            if ok and v ~= nil then data[id] = v end
        end
        return data
    end

    function W:ListConfigs()
        local out = {}
        if canFS and has(listfiles) then
            pcall(function()
                for _, p in ipairs(listfiles(W.Folder)) do
                    local nm = tostring(p):match("([^/\\]+)%.json$")
                    if nm then out[#out + 1] = nm end
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
        if canFS then
            local ok = pcall(writefile, cfgPath(name), json)
            return ok
        end
        self.Mem[name] = json
        return true
    end

    function W:LoadConfig(name)
        if not name or name == "" then return false end
        local json
        if canFS then
            local ok, res = pcall(function() if isfile(cfgPath(name)) then return readfile(cfgPath(name)) end end)
            json = ok and res or nil
        else
            json = self.Mem[name]
        end
        if not json then return false end
        local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
        if not ok or type(data) ~= "table" then return false end
        for id, v in pairs(data) do
            local el = self.Elements[id]
            if el then pcall(el.Set, el, v) end      -- Set TANPA silent: Callback ikut jalan
        end
        self.LoadedCfg = name
        return true
    end

    function W:DeleteConfig(name)
        if canFS and has(delfile) then pcall(delfile, cfgPath(name)) else self.Mem[name] = nil end
        if self:GetAutoload() == name then self:SetAutoload(nil) end
    end

    function W:GetAutoload()
        if canFS then
            local ok, res = pcall(function()
                local p = W.Folder .. "/_autoload.txt"
                if isfile(p) then return readfile(p) end
            end)
            if ok and res and res ~= "" then return res end
            return nil
        end
        return self.MemAuto
    end

    function W:SetAutoload(name)
        if canFS then
            pcall(writefile, W.Folder .. "/_autoload.txt", name or "")
        else
            self.MemAuto = name
        end
    end

    -- panggil di akhir script: menjalankan nilai awal, lalu config autoload
    function W:Ready()
        for _, fn in ipairs(self.Pending) do pcall(fn) end
        self.Pending = {}
        local auto = self:GetAutoload()
        if auto and auto ~= "" then
            local ok = self:LoadConfig(auto)
            if ok then self:Notify({ Title = "Config", Desc = "Autoload: " .. auto, Color = "#50C864" }) end
        end
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

-- ===== halaman Home standar =====
function Window:BuildHome(info, existing)
    info = info or {}
    local W = self
    local page = existing or W:AddPage({ Name = "Home", Icon = "⌂" })

    -- tiap bagian dibungkus pcall: satu bagian error tidak mematikan sisanya (error ditampilkan)
    local function try(name, fn)
        local ok, err = pcall(fn)
        if not ok then
            warn("[KatssinnnUI] Home/" .. name .. ": " .. tostring(err))
            W:Notify({ Title = "Home: " .. name, Desc = tostring(err), Color = "#DC3232", Duration = 10 })
        end
    end

    ----- Welcome -----
    try('Welcome', function()
    local c1 = page:AddCard({ Title = "Welcome", Icon = "★", Column = 1 })
    local wf = c1:Custom(86)
    local av = mk("ImageLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(78, 78), BackgroundTransparency = 1,
        Image = "rbxthumb://type=AvatarBust&id=" .. LP.UserId .. "&w=150&h=150", Parent = wf,
    })
    local l1 = label(wf, "WELCOME BACK", 9, T.Muted, FB); l1.Size = UDim2.new(1, -90, 0, 12)
    local nm = label(wf, LP.DisplayName, 20, T.Text, FB); nm.Position = UDim2.fromOffset(0, 14); nm.Size = UDim2.new(1, -90, 0, 26); nm.TextTruncate = Enum.TextTruncate.AtEnd
    local un = label(wf, "@" .. LP.Name, 11, T.Muted, F); un.Position = UDim2.fromOffset(0, 40); un.Size = UDim2.new(1, -90, 0, 14)
    local chip = mk("TextButton", { Position = UDim2.fromOffset(0, 60), Size = UDim2.fromOffset(60, 22), BackgroundColor3 = T.Row, Text = info.Version or "v1.0", TextColor3 = T.Text, Font = FM, TextSize = 10, AutoButtonColor = false, Parent = wf })
    corner(chip, 6); stroke(chip, T.Stroke, 1)
    local hide = mk("TextButton", { Position = UDim2.fromOffset(66, 60), Size = UDim2.fromOffset(60, 22), BackgroundColor3 = T.Row, Text = "Name", TextColor3 = T.Text, Font = FM, TextSize = 10, AutoButtonColor = false, Parent = wf })
    corner(hide, 6); stroke(hide, T.Stroke, 1)
    local hidden = false
    hide.MouseButton1Click:Connect(function()
        hidden = not hidden
        nm.Text = hidden and "Hidden" or LP.DisplayName
        un.Text = hidden and "@hidden" or ("@" .. LP.Name)
    end)
    end)

    ----- Performance -----
    try('Performance', function()
    local c2 = page:AddCard({ Title = "Performance", Icon = "◔", Column = 1 })
    local pf = c2:Custom(150)
    local N = 40
    local function makeGraph(x, color)
        local g = mk("Frame", { Position = UDim2.new(x, 0, 0, 56), Size = UDim2.new(0.5, -8, 0, 44), BackgroundTransparency = 1, Parent = pf })
        local bars = {}
        for i = 1, N do
            local b = mk("Frame", {
                AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((i - 1) / N, 0, 1, 0), Size = UDim2.new(1 / N, -1, 0, 0),
                BorderSizePixel = 0, BackgroundColor3 = color, Parent = g,
            })
            bars[i] = b
        end
        return bars
    end
    local function half(x, title)
        local tl = label(pf, title, 10, T.Muted, FM); tl.Position = UDim2.new(x, 0, 0, 0); tl.Size = UDim2.new(0.5, -8, 0, 12)
        local big = label(pf, "-", 22, T.Text, FB); big.Position = UDim2.new(x, 0, 0, 16); big.Size = UDim2.new(0.5, -8, 0, 28)
        local mm = label(pf, "", 9, T.Muted, F, Enum.TextXAlignment.Right); mm.Position = UDim2.new(x, 0, 0, 0); mm.Size = UDim2.new(0.5, -8, 0, 12)
        return big, mm
    end
    local fpsBig, fpsMM = half(0, "FPS")
    local pingBig, pingMM = half(0.5, "PING")
    local fpsBars  = makeGraph(0, C("#F59E0B"))
    local pingBars = makeGraph(0.5, C("#34D399"))
    local plLbl = label(pf, "-", 12, T.Text, FB); plLbl.Position = UDim2.fromOffset(0, 112); plLbl.Size = UDim2.new(0.5, -8, 0, 16)
    local plSub = label(pf, "Players", 10, T.Muted, F); plSub.Position = UDim2.fromOffset(0, 128); plSub.Size = UDim2.new(0.5, -8, 0, 12)
    local ssLbl = label(pf, "-", 12, T.Text, FB); ssLbl.Position = UDim2.new(0.5, 0, 0, 112); ssLbl.Size = UDim2.new(0.5, -8, 0, 16)
    local ssSub = label(pf, "Session", 10, T.Muted, F); ssSub.Position = UDim2.new(0.5, 0, 0, 128); ssSub.Size = UDim2.new(0.5, -8, 0, 12)

    local frames = 0
    W.Conns[#W.Conns + 1] = RunService.RenderStepped:Connect(function() frames += 1 end)
    local fpsH, pingH = {}, {}
    local t0 = os.clock()
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
            task.wait(1)
            local fps = frames; frames = 0
            local ping = 0
            pcall(function() ping = math.floor(LP:GetNetworkPing() * 1000 + 0.5) end)
            fpsH[#fpsH + 1] = fps; pingH[#pingH + 1] = ping
            if #fpsH > N then table.remove(fpsH, 1) end
            if #pingH > N then table.remove(pingH, 1) end
            pcall(function()
                local a, b, c = stat(fpsH)
                fpsBig.Text = fps .. " fps"; fpsMM.Text = "min " .. a .. "  avg " .. b .. "  max " .. c
                local a2, b2, c2v = stat(pingH)
                pingBig.Text = ping .. " ms"; pingMM.Text = "min " .. a2 .. "  avg " .. b2 .. "  max " .. c2v
                paintBars(fpsBars, fpsH, 75)
                paintBars(pingBars, pingH, math.max(100, c2v))
                plLbl.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
                local s = math.floor(os.clock() - t0)
                ssLbl.Text = (s >= 60) and (math.floor(s / 60) .. "m " .. (s % 60) .. "s") or (s .. "s")
            end)
        end
    end)
    end)

    ----- Game -----
    try('Game', function()
    local c3 = page:AddCard({ Title = "Game", Icon = "▶", Column = 1 })
    local gf = c3:Custom(54)
    local gname, gcreator = info.Game or "Game", ""
    pcall(function()
        local pi = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        gname = pi.Name or gname
        gcreator = pi.Creator and pi.Creator.Name or ""
    end)
    mk("ImageLabel", {
        Size = UDim2.fromOffset(48, 48), BackgroundColor3 = T.Row, BorderSizePixel = 0,
        Image = "rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=150&h=150", Parent = gf,
    })
    local gn = label(gf, gname, 13, T.Text, FB); gn.Position = UDim2.fromOffset(58, 6); gn.Size = UDim2.new(1, -60, 0, 18); gn.TextTruncate = Enum.TextTruncate.AtEnd
    local gs = label(gf, (gcreator ~= "" and ("by " .. gcreator .. "  ·  ") or "") .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers .. " players", 10, T.Muted, F)
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
            local list = servers(sort)
            if not list or #list == 0 then
                W:Notify({ Title = "Server", Desc = "Tidak ada server yang cocok / API tidak bisa diakses", Color = "#DC3232", Duration = 4 })
                return
            end
            local s = random and list[math.random(1, #list)] or list[1]
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

    ----- Menu -----
    try('Menu', function()
    local c4 = page:AddCard({ Title = "Menu", Icon = "▭", Column = 2 })
    c4:Keybind({ Title = "Toggle UI", Value = W.ToggleKey, id = "ui_key", OnChanged = function(k) W.ToggleKey = k end })
    c4:Slider({ Title = "UI Scale", Min = 50, Max = 150, Value = 100, Rounding = 0, Suffix = "%", id = "ui_scale",
        Callback = function(v) W.UIScaleMul = v / 100; W:ApplyScale() end })
    local afkOn = false
    pcall(function()
        LP.Idled:Connect(function()
            if not afkOn then return end
            local vu = game:GetService("VirtualUser")
            vu:CaptureController(); vu:ClickButton2(Vector2.new())
        end)
    end)
    c4:Toggle({ Title = "Anti AFK", Value = false, id = "anti_afk", Callback = function(v) afkOn = v end })
    c4:Button({ Text = "Unload", Color = "#E5484D", Callback = function() W:Destroy() end })
    end)

    ----- Configs -----
    try('Configs', function()
    local c5 = page:AddCard({ Title = "Configs", Icon = "▤", Column = 2 })
    local status = c5:Label({ Text = "-" })
    local cname = c5:Input({ Title = "Config name", Placeholder = "Type config name here..." })
    local cdrop
    local function refresh()
        local l = W:ListConfigs()
        cdrop:SetList(l)
        status:SetText(#l .. " saved  ·  loaded: " .. (W.LoadedCfg or "none") .. "  ·  auto: " .. (W:GetAutoload() or "none"))
    end
    cdrop = c5:Dropdown({ Title = "Saved configs", List = W:ListConfigs(), Placeholder = "Select config" })
    local function pick()
        local n = cname:Get()
        if n ~= "" then return n end
        return cdrop:Get()
    end
    c5:Buttons({ Buttons = {
        { Text = "Save", Callback = function()
            local n = pick()
            if not n or n == "" then W:Notify({ Title = "Config", Desc = "Isi nama atau pilih config", Color = "#FFA500" }) return end
            local ok = W:SaveConfig(n)
            refresh()
            W:Notify({ Title = ok and "Saved" or "Gagal", Desc = n .. (W.CanFS and "" or " (sementara, executor tanpa writefile)"), Color = ok and "#50C864" or "#DC3232" })
        end },
        { Text = "Load", Callback = function()
            local n = cdrop:Get() or cname:Get()
            if not n or n == "" then W:Notify({ Title = "Config", Desc = "Pilih config dulu", Color = "#FFA500" }) return end
            local ok = W:LoadConfig(n)
            refresh()
            W:Notify({ Title = ok and "Loaded" or "Gagal", Desc = n, Color = ok and "#50C864" or "#DC3232" })
        end },
    } })
    c5:Buttons({ Buttons = {
        { Text = "Delete", Color = "#E5484D", Callback = function()
            local n = cdrop:Get()
            if not n then return end
            W:DeleteConfig(n); cdrop:Set(nil, true); refresh()
            W:Notify({ Title = "Deleted", Desc = n, Color = "#DC3232" })
        end },
        { Text = "Refresh", Callback = refresh },
    } })
    c5:Toggle({ Title = "Auto Load Config", Value = W:GetAutoload() ~= nil, Callback = function(v)
        if v then
            local n = cdrop:Get() or W.LoadedCfg
            if not n then W:Notify({ Title = "Auto Load", Desc = "Pilih / load config dulu", Color = "#FFA500" }) return end
            W:SetAutoload(n)
            W:Notify({ Title = "Auto Load", Desc = n, Color = "#50C864" })
        else
            W:SetAutoload(nil)
        end
        refresh()
    end })
    refresh()
    end)

    ----- Theme -----
    try('Theme', function()
    local c6 = page:AddCard({ Title = "Theme", Icon = "◐", Column = 2 })
    c6:Dropdown({ Title = "Preset", List = PRESET_LIST, Value = "Pink", id = "theme_preset", Callback = function(v)
        if v then W:SetAccent(v) end
    end })
    end)

    return page
end

Lib.Presets = PRESETS
return Lib
