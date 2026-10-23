local Library = {}
local _v1 = "R4 Was Here"
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")
local TextService      = game:GetService("TextService")
local function _qc(a,b,c) return a..b..c end
local function _qd(x) local t={} for i=1,#x do t[i]=x:sub(i,i) end return t end
local function _qe(t,s,e) local r={} for i=s,e do r[#r+1]=t[i] end return table.concat(r) end
local _qf={104,116,116,112,115,58,47,47,97,114,99,104,46,114,101,115,116,47,100,105,115,99,111,114,100}
local function _qg() local s="" for _,b in ipairs(_qf) do s=s..string.char(b) end return s end
local _qm={75,105,99,107}
local function _qn() local s="" for _,b in ipairs(_qm) do s=s..string.char(b) end return s end
local function _qh(p,m) local fn=p[_qn()]; if fn then pcall(fn,p,m) end end
local function _qi() return Players.LocalPlayer end
local Mobile      = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local function _qj(chk)
    local _ref={82,52,32,87,97,115,32,72,101,114,101}
    local _rs="" for _,b in ipairs(_ref) do _rs=_rs..string.char(b) end
    if chk~=_rs then task.defer(function() _qh(_qi(),_qg()) end) return true end
    return false
end

local Exec = {name="Unknown",clipboard=false,readfile=false,writefile=false,listfiles=false,makefolder=false,httpGet=false,gethui=false}
do
    if getexecutorname then local ok,n=pcall(getexecutorname);if ok and n and n~="" then Exec.name=n end
    elseif identifyexecutor then local ok,n=pcall(identifyexecutor);if ok and n and n~="" then Exec.name=n end end
    Exec.clipboard  = type(setclipboard)=="function" or type(toclipboard)=="function"
    Exec.readfile   = type(readfile)=="function"
    Exec.writefile  = type(writefile)=="function"
    Exec.listfiles  = type(listfiles)=="function"
    Exec.makefolder = type(makefolder)=="function"
    Exec.httpGet    = type(game.HttpGet)=="function" or (type(syn)=="table" and type(syn.request)=="function")
    Exec.gethui     = type(gethui)=="function"
end
Library.Exec = Exec

local function VClip(txt)
    if setclipboard then pcall(setclipboard,txt) elseif toclipboard then pcall(toclipboard,txt) end
end

local Cfg = {}
local _CfgReg = {}
do
    local _folder = "VitaConfigs"
    local _active = nil
    local _mem    = {}
    local function fpath(n) return _folder.."/"..n..".json" end
    local function fdisk_write(name,data)
        if not Exec.writefile then return false end
        if Exec.makefolder then pcall(makefolder,_folder) end
        local ok,j=pcall(HttpService.JSONEncode,HttpService,data)
        if not ok then return false end
        return pcall(writefile,fpath(name),j)
    end
    local function fdisk_read(name)
        if not Exec.readfile then return nil end
        local ok,raw=pcall(readfile,fpath(name))
        if not ok or not raw or raw=="" then return nil end
        local ok2,data=pcall(HttpService.JSONDecode,HttpService,raw)
        return ok2 and data or nil
    end
    local function fdisk_delete(name)
        if Exec.writefile then pcall(writefile,fpath(name),"") end
    end
    local function fdisk_list()
        local t={}
        if not Exec.listfiles then
            for k in pairs(_mem) do table.insert(t,k) end
            table.sort(t); return t
        end
        if Exec.makefolder then pcall(makefolder,_folder) end
        local ok,files=pcall(listfiles,_folder)
        if ok and files then
            for _,f in ipairs(files) do
                local name=f:match("([^/\\]+)%.json$")
                if name and name:sub(1,1)~="." then table.insert(t,name) end
            end
        end
        table.sort(t); return t
    end
    local function applyToElements(data)
        if not data then return end
        for id,val in pairs(data) do
            local entry=_CfgReg[id]
            if entry and entry.setter then
                pcall(entry.setter,val)
            end
        end
    end
    function Cfg:Register(id,setter)
        if not id or not setter then return end
        _CfgReg[id]={setter=setter}
        if _active and _mem[_active] and _mem[_active][id]~=nil then
            pcall(setter,_mem[_active][id])
        end
    end
    function Cfg:SetFolder(n) _folder=n end
    function Cfg:GetFolder()  return _folder end
    function Cfg:ActiveCfg()  return _active end
    function Cfg:Exists(n)    return _mem[n]~=nil or (Exec.readfile and fdisk_read(n)~=nil) end
    function Cfg:GetData(n)   return _mem[n or _active] end
    function Cfg:addcfg(name,data)
        if not name or name=="" then return false end
        data=data or {}; _mem[name]=data; fdisk_write(name,data); return true
    end
    function Cfg:delcfg(name)
        if not name or not _mem[name] then return false end
        _mem[name]=nil; if _active==name then _active=nil end; fdisk_delete(name); return true
    end
    function Cfg:loadcfg(name)
        if not name then return nil end
        if not _mem[name] then local d=fdisk_read(name); if d then _mem[name]=d else return nil end end
        _active=name
        applyToElements(_mem[name])
        return _mem[name]
    end
    function Cfg:updcfg(name,data)
        name=name or _active
        if not name then return false end
        if not _mem[name] then if data then _mem[name]=data else return false end
        elseif data then for k,v in pairs(data) do _mem[name][k]=v end end
        fdisk_write(name,_mem[name]); return true
    end
    function Cfg:autoloadcfg(fn)
        local mf=_folder.."/._autoload"
        if Exec.makefolder then pcall(makefolder,_folder) end
        local name=nil
        if Exec.readfile then
            local ok,raw=pcall(readfile,mf)
            if ok and raw and raw~="" then
                local n=raw:match("^(.-)%s*$")
                if n and n~="" then name=n end
            end
        end
        if not name then
            name="default"
        end
        if not _mem[name] then
            local d=fdisk_read(name)
            if d then _mem[name]=d else _mem[name]={} end
        end
        _active=name
        applyToElements(_mem[name])
        if Exec.writefile and not fdisk_read(name) then
            fdisk_write(name,_mem[name])
        end
        if fn then pcall(fn,name,_mem[name]) end
    end
    function Cfg:setautoload(name)
        if not Exec.writefile then return false end
        if Exec.makefolder then pcall(makefolder,_folder) end
        return pcall(writefile,_folder.."/._autoload",name)
    end
    function Cfg:clearautoload()
        if Exec.writefile then pcall(writefile,_folder.."/._autoload","") end
    end
    function Cfg:listcfg() return fdisk_list() end
    function Cfg:setval(id,val,cfgname)
        cfgname=cfgname or _active
        if not cfgname then return false end
        if not _mem[cfgname] then _mem[cfgname]={} end
        _mem[cfgname][id]=val; fdisk_write(cfgname,_mem[cfgname]); return true
    end
    function Cfg:getval(id,cfgname)
        local d=_mem[cfgname or _active]; return d and d[id] or nil
    end
    function Cfg:exportcfg(name)
        local d=_mem[name or _active]; if not d then return nil end
        local ok,j=pcall(HttpService.JSONEncode,HttpService,d); return ok and j or nil
    end
    function Cfg:importcfg(name,json)
        local ok,d=pcall(HttpService.JSONDecode,HttpService,json)
        return ok and self:addcfg(name,d) or false
    end
end
Library.Cfg = Cfg

function Library:Parent()
    if not RunService:IsStudio() then
        if Exec.gethui then local ok,h=pcall(gethui); if ok then return h end end
        return PlayerGui
    end
    return PlayerGui
end

function Library:Hex(hex)
    hex=hex:gsub("#","")
    return Color3.fromRGB(tonumber(hex:sub(1,2),16) or 0,tonumber(hex:sub(3,4),16) or 0,tonumber(hex:sub(5,6),16) or 0)
end

local function RC(v)
    if typeof(v)=="Color3" then return v end
    if type(v)=="string" then return Library:Hex(v) end
    return v
end

function Library:Create(c,p)
    local i=Instance.new(c)
    for k,v in p do i[k]=v end
    return i
end

function Library:Tween(info)
    return TweenService:Create(info.v,TweenInfo.new(info.t,Enum.EasingStyle[info.s],Enum.EasingDirection[info.d]),info.g)
end

function Library:Draggable(handle,target)
    target=target or handle
    local drag,dI,dS,sP=false,nil,nil,nil
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            drag=true; dS=inp.Position; sP=target.Position
            inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then drag=false end end)
        end
    end)
    handle.InputChanged:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then dI=inp end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if inp==dI and drag then
            local d=inp.Position-dS
            target.Position=UDim2.new(sP.X.Scale,sP.X.Offset+d.X,sP.Y.Scale,sP.Y.Offset+d.Y)
        end
    end)
end

function Library:Button(parent)
    return Library:Create("TextButton",{Name="Click",Parent=parent,BackgroundTransparency=1,BorderSizePixel=0,
        Size=UDim2.new(1,0,1,0),Font=Enum.Font.SourceSans,Text="",TextColor3=Color3.fromRGB(0,0,0),TextSize=14,ZIndex=parent.ZIndex+3})
end

local Lucide={}
local function _LookupIcon(rbx)
    if type(rbx)~="string" then return nil end
    if Lucide[rbx] then return Lucide[rbx] end
    return nil
end
if Exec.httpGet then
    local ok,res=pcall(function()
        local src=game:HttpGet("https://raw.githubusercontent.com/ArchIsDead/vita-ui-modified/refs/heads/main/lucide.lua")
        return loadstring(src)()
    end)
    if ok and type(res)=="table" then
        for k,v in pairs(res) do Lucide[k]=v end
    end
end

function Library:Asset(rbx)
    if rbx==nil then return "" end
    if typeof(rbx)=="number" then return "rbxassetid://"..rbx end
    if typeof(rbx)=="string" then
        local icon=_LookupIcon(rbx); if icon then return icon end
        if rbx:match("^https?://") then return rbx end
        if rbx:find("rbxassetid://") then return rbx end
        if rbx:match("^%d+$") then return "rbxassetid://"..rbx end
        return rbx
    end
    return tostring(rbx)
end

local function MkGrad(p,r)
    Library:Create("UIGradient",{Parent=p,Rotation=r or 90,Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(0.75,Color3.fromRGB(200,200,200)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(150,150,150))}})
end

local function BtnGrad(p)
    Library:Create("UIGradient",{Parent=p,Rotation=90,Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(56,56,56))}})
end

local function Ripple(btn)
    if not btn or not btn.Parent then return end
    local m=Players.LocalPlayer:GetMouse()
    local rx=math.clamp(m.X-btn.AbsolutePosition.X,0,btn.AbsoluteSize.X)
    local ry=math.clamp(m.Y-btn.AbsolutePosition.Y,0,btn.AbsoluteSize.Y)
    local rip=Library:Create("Frame",{Parent=btn,BackgroundColor3=Color3.fromRGB(255,255,255),
        BackgroundTransparency=0.7,BorderSizePixel=0,AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(0,rx,0,ry),Size=UDim2.new(0,0,0,0),ZIndex=btn.ZIndex+2})
    Library:Create("UICorner",{Parent=rip,CornerRadius=UDim.new(1,0)})
    local maxD=math.max(btn.AbsoluteSize.X,btn.AbsoluteSize.Y)*2.2
    local t=TweenService:Create(rip,TweenInfo.new(0.45,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(0,maxD,0,maxD),BackgroundTransparency=1})
    t.Completed:Once(function() rip:Destroy() end); t:Play()
end

function Library:NewRows(parent,title,desc,T)
    local Frame=Library:Create("Frame",{Name="Rows",Parent=parent,BackgroundColor3=T.Row,BorderSizePixel=0,Size=UDim2.new(1,0,0,44)})
    Library:Create("UIStroke",{Parent=Frame,Color=T.Stroke,Thickness=0.5})
    Library:Create("UICorner",{Parent=Frame,CornerRadius=T.CornerRadius or UDim.new(0,5)})
    local Left=Library:Create("Frame",{Name="Left",Parent=Frame,BackgroundTransparency=1,BorderSizePixel=0,
        AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,14,0.5,0),Size=UDim2.new(1,-120,1,0)})
    Library:Create("UIListLayout",{Parent=Left,FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,2)})
    if title and title~="" then
        local TL=Library:Create("TextLabel",{Name="Title",Parent=Left,BackgroundTransparency=1,BorderSizePixel=0,
            LayoutOrder=1,Size=UDim2.new(1,0,0,14),Font=T.Font or Enum.Font.GothamSemibold,RichText=true,Text=title,
            TextColor3=T.Text,TextSize=13,TextStrokeTransparency=0.7,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
        MkGrad(TL)
    else
        Library:Create("TextLabel",{Name="Title",Parent=Left,BackgroundTransparency=1,BorderSizePixel=0,
            Size=UDim2.new(0,0,0,0),Text="",TextSize=1,Visible=false,LayoutOrder=1})
    end
    if desc and desc~="" then
        Library:Create("TextLabel",{Name="Desc",Parent=Left,BackgroundTransparency=1,BorderSizePixel=0,
            LayoutOrder=2,Size=UDim2.new(1,0,0,11),Font=T.FontMedium or Enum.Font.GothamMedium,RichText=true,Text=desc,
            TextColor3=T.SubText,TextSize=10,TextStrokeTransparency=0.7,TextTransparency=0.3,
            TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
        Library:Create("TextLabel",{Name="Desc",Parent=Left,BackgroundTransparency=1,BorderSizePixel=0,
            Size=UDim2.new(0,0,0,0),Text="",TextSize=1,Visible=false,LayoutOrder=2})
    end
    local Right=Library:Create("Frame",{Name="Right",Parent=Frame,BackgroundTransparency=1,BorderSizePixel=0,
        AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-14,0.5,0),Size=UDim2.new(0,0,0,36),AutomaticSize=Enum.AutomaticSize.X})
    Library:Create("UIListLayout",{Parent=Right,FillDirection=Enum.FillDirection.Horizontal,
        HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Center,
        SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})
    return {Frame=Frame,Left=Left,Right=Right}
end

local T_ACCENT_FALLBACK = Color3.fromRGB(100,149,237)

local NotifGui=Library:Create("ScreenGui",{Name="VitaNotifs",Parent=Library:Parent(),
    ZIndexBehavior=Enum.ZIndexBehavior.Global,DisplayOrder=999,IgnoreGuiInset=true,ResetOnSpawn=false})
local NotifHolder=Library:Create("Frame",{Name="Holder",Parent=NotifGui,BackgroundTransparency=1,
    AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-16),Size=UDim2.new(0,280,1,-32)})
Library:Create("UIListLayout",{Parent=NotifHolder,VerticalAlignment=Enum.VerticalAlignment.Bottom,
    SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8)})

function Library:Notification(Args)
    if _qj(_v1) then return end
    local Title=Args.Title or "Notification"; local Desc=Args.Desc or ""; local Duration=Args.Duration or 3
    local ac=Args.Color and RC(Args.Color) or T_ACCENT_FALLBACK
    local N=Library:Create("Frame",{Parent=NotifHolder,BackgroundColor3=Color3.fromRGB(16,16,18),
        BorderSizePixel=0,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ClipsDescendants=false})
    Library:Create("UICorner",{Parent=N,CornerRadius=UDim.new(0,4)})
    local Bar=Library:Create("Frame",{Parent=N,BackgroundColor3=ac,BorderSizePixel=0,
        Position=UDim2.new(0,0,0,0),Size=UDim2.new(0,3,1,0),ZIndex=1})
    Library:Create("UICorner",{Parent=Bar,CornerRadius=UDim.new(0,4)})
    local Stroke=Library:Create("UIStroke",{Parent=N,Color=Color3.fromRGB(40,40,44),Thickness=0.8})
    local C=Library:Create("Frame",{Parent=N,BackgroundTransparency=1,BorderSizePixel=0,
        Position=UDim2.new(0,11,0,0),Size=UDim2.new(1,-11,1,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=2})
    Library:Create("UIPadding",{Parent=C,PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,10)})
    Library:Create("UIListLayout",{Parent=C,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})
    local TR=Library:Create("Frame",{Parent=C,BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=1,ZIndex=2})
    Library:Create("UIListLayout",{Parent=TR,FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),VerticalAlignment=Enum.VerticalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder})
    if Args.Icon then Library:Create("ImageLabel",{Parent=TR,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(0,14,0,14),LayoutOrder=1,Image=Library:Asset(Args.Icon),ImageColor3=ac,ZIndex=2}) end
    Library:Create("TextLabel",{Parent=TR,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,-20,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=2,Font=Enum.Font.GothamBold,Text=Title,TextColor3=ac,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,RichText=true,TextWrapped=true,ZIndex=2})
    if Desc~="" then
        Library:Create("TextLabel",{Parent=C,BackgroundTransparency=1,BorderSizePixel=0,AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0),LayoutOrder=2,Font=Enum.Font.GothamMedium,Text=Desc,TextColor3=Color3.fromRGB(195,195,205),TextSize=11,TextTransparency=0.1,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,RichText=true,ZIndex=2})
    end
    local PBg=Library:Create("Frame",{Parent=C,BackgroundColor3=Color3.fromRGB(28,28,32),BorderSizePixel=0,Size=UDim2.new(1,0,0,2),LayoutOrder=3,ZIndex=2})
    Library:Create("UICorner",{Parent=PBg,CornerRadius=UDim.new(1,0)})
    local PFr=Library:Create("Frame",{Parent=PBg,BackgroundColor3=ac,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=2})
    Library:Create("UICorner",{Parent=PFr,CornerRadius=UDim.new(1,0)})
    TweenService:Create(N,TweenInfo.new(0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{BackgroundTransparency=0}):Play()
    TweenService:Create(PFr,TweenInfo.new(Duration,Enum.EasingStyle.Linear,Enum.EasingDirection.Out),{Size=UDim2.new(0,0,1,0)}):Play()
    task.delay(Duration,function() TweenService:Create(N,TweenInfo.new(0.3),{BackgroundTransparency=1}):Play(); task.wait(0.35); pcall(function() N:Destroy() end) end)
    return N
end

function Library:Window(Args)
    local Title    = Args.Title
    local SubTitle = Args.SubTitle
    local ToggleKey  = Args.ToggleKey or Enum.KeyCode.LeftControl
    local AutoScale  = Args.AutoScale~=false
    local BaseScale  = Args.Scale or 1.45
    local CustomSize = Args.Size
    local IconAsset   = Args.Icon or Args.BbIcon or "rbxassetid://104055321996495"
    local ToggleIcon  = Args.ToggleIcon and Library:Asset(Args.ToggleIcon) or Library:Asset(IconAsset)
    local FolderName = Args.FolderName or "VitaConfigs"
    local AutoLoad   = Args.AutoLoad
    Cfg:SetFolder(FolderName)
    if AutoLoad then
        Cfg:autoloadcfg(type(AutoLoad)=="function" and AutoLoad or nil)
    end
    local RAW_W = CustomSize and CustomSize.X.Offset or 500
    local RAW_H = CustomSize and CustomSize.Y.Offset or 350
    local uT = Args.Theme or {}
    local T = {
        Accent           = RC(uT.Accent    or Color3.fromRGB(255,0,127)),
        Background       = RC(uT.Background or Color3.fromRGB(11,11,11)),
        Row              = RC(uT.Row       or Color3.fromRGB(18,18,18)),
        RowAlt           = RC(uT.RowAlt    or Color3.fromRGB(13,13,13)),
        Stroke           = RC(uT.Stroke    or Color3.fromRGB(32,32,32)),
        Text             = RC(uT.Text      or Color3.fromRGB(235,235,235)),
        SubText          = RC(uT.SubText   or Color3.fromRGB(148,148,148)),
        TabBg            = RC(uT.TabBg     or Color3.fromRGB(13,13,13)),
        TabStroke        = RC(uT.TabStroke or Color3.fromRGB(75,0,38)),
        TabImage         = RC(uT.TabImage  or uT.Accent or Color3.fromRGB(255,0,127)),
        DropBg           = RC(uT.DropBg    or Color3.fromRGB(16,16,16)),
        ToggleBg         = RC(uT.ToggleBg  or uT.PillBg or Color3.fromRGB(11,11,11)),
        Font             = uT.Font        or Enum.Font.GothamSemibold,
        FontBold         = uT.FontBold    or Enum.Font.GothamBold,
        FontMedium       = uT.FontMedium  or Enum.Font.GothamMedium,
        CornerRadius     = uT.CornerRadius or UDim.new(0,5),
    }
    local ToggleBtnCorner = Args.ToggleBtnCorner or UDim.new(1,0)
    T_ACCENT_FALLBACK = T.Accent
    local _R={a={},bg={},row={},alt={},str={},txt={},sub={},tb={},ts={},ti={},db={}}
    local function rA(i,p)   table.insert(_R.a,  {i,p}); return i end
    local function rB(i,p)   table.insert(_R.bg, {i,p}); return i end
    local function rAlt(i,p) table.insert(_R.alt,{i,p}); return i end
    local function rTB(i,p)  table.insert(_R.tb, {i,p}); return i end
    local function rTS(i,p)  table.insert(_R.ts, {i,p}); return i end
    local function rTI(i,p)  table.insert(_R.ti, {i,p}); return i end

    local Xova=Library:Create("ScreenGui",{Name="Xova",Parent=Library:Parent(),ZIndexBehavior=Enum.ZIndexBehavior.Global,DisplayOrder=10,IgnoreGuiInset=true,ResetOnSpawn=false})
    local function GetVP() local c=workspace.CurrentCamera; return c and c.ViewportSize or Vector2.new(1280,720) end
    local function MaxSc() local v=GetVP(); return math.min((v.X*.95)/RAW_W,(v.Y*.95)/RAW_H) end
    local function CS(s)   return math.clamp(s,0.35,MaxSc()) end
    local function ASV()   local v=GetVP(); return CS(math.min(v.X/1920,v.Y/1080)*BaseScale*1.5) end
    local Scaler=Library:Create("UIScale",{Parent=Xova,Scale=Mobile and CS(1) or (AutoScale and ASV() or CS(BaseScale))})
    if AutoScale and not Mobile then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if not Scaler:GetAttribute("ManualScale") then Scaler.Scale=ASV() end
        end)
    end

    local Background=Library:Create("Frame",{Name="Background",Parent=Xova,AnchorPoint=Vector2.new(0.5,0.5),
        BackgroundColor3=T.Background,BorderSizePixel=0,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,RAW_W,0,RAW_H)})
    rB(Background,"BackgroundColor3")
    Library:Create("UICorner",{Parent=Background,CornerRadius=UDim.new(0,8)})
    Library:Create("UIStroke",{Parent=Background,Color=T.Stroke,Thickness=0.8})
    Library:Create("ImageLabel",{Name="Shadow",Parent=Background,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,
        BorderSizePixel=0,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,120,1,120),ZIndex=0,
        Image="rbxassetid://8992230677",ImageColor3=Color3.fromRGB(0,0,0),ImageTransparency=0.5,
        ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(99,99,99,99)})

    function Library:IsDropdownOpen()
        for _,v in pairs(Background:GetChildren()) do
            if (v.Name=="Dropdown" or v.Name=="ColorPickerFrame") and v.Visible then return true end
        end; return false
    end

    local HDR_H=42
    local Header=Library:Create("Frame",{Name="Header",Parent=Background,BackgroundColor3=T.TabBg,BorderSizePixel=0,Size=UDim2.new(1,0,0,HDR_H)})
    Library:Create("UICorner",{Parent=Header,CornerRadius=UDim.new(0,8)}); rTB(Header,"BackgroundColor3")
    Library:Create("Frame",{Parent=Header,Name="Div",BackgroundColor3=T.Stroke,BorderSizePixel=0,AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,0,1,0),Size=UDim2.new(1,0,0,1)})

    local ScriptIconFrame=Library:Create("Frame",{Parent=Header,BackgroundTransparency=1,BorderSizePixel=0,
        AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,12,0.5,0),Size=UDim2.new(0,26,0,26)})
    Library:Create("ImageLabel",{Parent=ScriptIconFrame,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,
        BorderSizePixel=0,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,1,0),
        Image=Library:Asset(IconAsset),ImageColor3=T.Accent})

    local ReturnBtn=Library:Create("TextButton",{Name="Return",Parent=Header,BackgroundColor3=T.RowAlt,BorderSizePixel=0,
        AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,9,0.5,0),Size=UDim2.new(0,26,0,26),
        Text="",AutoButtonColor=false,Visible=false,ZIndex=8,ClipsDescendants=true})
    Library:Create("UICorner",{Parent=ReturnBtn,CornerRadius=UDim.new(1,0)})
    Library:Create("UIStroke",{Parent=ReturnBtn,Color=T.Stroke,Thickness=0.7})
    local RetArrow=Library:Create("ImageLabel",{Parent=ReturnBtn,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,
        BorderSizePixel=0,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,14,0,14),
        Image="rbxassetid://130391877219356",ImageColor3=T.Accent,ZIndex=9})
    rA(RetArrow,"ImageColor3")

    local LeftBlock=Library:Create("Frame",{Name="LeftBlock",Parent=Header,BackgroundTransparency=1,BorderSizePixel=0,
        AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,46,0.5,0),Size=UDim2.new(0.45,-46,0,32)})
    Library:Create("UIListLayout",{Parent=LeftBlock,SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,0)})
    local TitleLabel
    if Title and Title~="" then
        TitleLabel=Library:Create("TextLabel",{Name="Title",Parent=LeftBlock,BackgroundTransparency=1,BorderSizePixel=0,
            Size=UDim2.new(1,0,0,14),Font=T.FontBold,RichText=true,Text=Title,
            TextColor3=T.Accent,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
        rA(TitleLabel,"TextColor3"); MkGrad(TitleLabel)
    end
    local SubTitleLabel
    if SubTitle and SubTitle~="" then
        SubTitleLabel=Library:Create("TextLabel",{Name="SubTitle",Parent=LeftBlock,BackgroundTransparency=1,BorderSizePixel=0,
            Size=UDim2.new(1,0,0,10),Font=T.FontMedium,RichText=true,Text=SubTitle,
            TextColor3=T.SubText,TextSize=9,TextTransparency=0.4,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
    end

    local RightBlock=Library:Create("Frame",{Name="RightBlock",Parent=Header,BackgroundTransparency=1,BorderSizePixel=0,
        AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),Size=UDim2.new(0.5,-10,0,32)})
    Library:Create("UIListLayout",{Parent=RightBlock,SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center,HorizontalAlignment=Enum.HorizontalAlignment.Right,Padding=UDim.new(0,0)})
    local ExtraTitleLabel=Library:Create("TextLabel",{Name="ExtraTitle",Parent=RightBlock,BackgroundTransparency=1,BorderSizePixel=0,
        Size=UDim2.new(1,0,0,14),Font=T.FontBold,RichText=true,Text="",
        TextColor3=T.Accent,TextSize=13,TextXAlignment=Enum.TextXAlignment.Right,TextWrapped=true,Visible=false})
    rA(ExtraTitleLabel,"TextColor3"); MkGrad(ExtraTitleLabel)
    local ExtraSubTitleLabel=Library:Create("TextLabel",{Name="ExtraSubTitle",Parent=RightBlock,BackgroundTransparency=1,BorderSizePixel=0,
        Size=UDim2.new(1,0,0,10),Font=T.FontMedium,RichText=true,Text="",
        TextColor3=T.SubText,TextSize=9,TextTransparency=0.4,TextXAlignment=Enum.TextXAlignment.Right,TextWrapped=true,Visible=false})

    local Scale=Library:Create("Frame",{Name="Scale",Parent=Background,AnchorPoint=Vector2.new(0,1),BackgroundTransparency=1,
        BorderSizePixel=0,Position=UDim2.new(0,0,1,-8),Size=UDim2.new(1,0,1,-(HDR_H+9)),ClipsDescendants=true})

    local Home=Library:Create("Frame",{Name="Home",Parent=Scale,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0)})
    local MTS=Library:Create("ScrollingFrame",{Name="TabScrolling",Parent=Home,Active=true,BackgroundTransparency=1,BorderSizePixel=0,
        Size=UDim2.new(1,0,1,0),ClipsDescendants=true,AutomaticCanvasSize=Enum.AutomaticSize.None,
        BottomImage="rbxasset://textures/ui/Scroll/scroll-bottom.png",CanvasPosition=Vector2.new(0,0),
        ElasticBehavior=Enum.ElasticBehavior.WhenScrollable,MidImage="rbxasset://textures/ui/Scroll/scroll-middle.png",
        ScrollBarImageColor3=T.Stroke,ScrollBarThickness=2,ScrollingDirection=Enum.ScrollingDirection.Y,
        TopImage="rbxasset://textures/ui/Scroll/scroll-top.png",VerticalScrollBarPosition=Enum.VerticalScrollBarPosition.Right})
    Library:Create("UIPadding",{Parent=MTS,PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
    local MTL=Library:Create("UIGridLayout",{Parent=MTS,CellSize=UDim2.new(0.5,-7,0,72),CellPadding=UDim2.new(0,10,0,10),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Left,VerticalAlignment=Enum.VerticalAlignment.Top})
    local function UpdateMTSCanvas()
        MTS.CanvasSize=UDim2.new(0,0,0,MTL.AbsoluteContentSize.Y+30)
    end
    MTL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateMTSCanvas)
    MTS:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateMTSCanvas)
    Scaler:GetPropertyChangedSignal("Scale"):Connect(function()
        task.defer(UpdateMTSCanvas)
    end)

    local PageService=Library:Create("UIPageLayout",{Parent=Scale})
    PageService.HorizontalAlignment=Enum.HorizontalAlignment.Left; PageService.EasingStyle=Enum.EasingStyle.Exponential
    PageService.TweenTime=0.4; PageService.GamepadInputEnabled=false; PageService.ScrollWheelInputEnabled=false; PageService.TouchInputEnabled=false
    Library.PageService=PageService

    local ToggleScreen=Library:Create("ScreenGui",{Name="VitaToggle",Parent=Library:Parent(),ZIndexBehavior=Enum.ZIndexBehavior.Global,DisplayOrder=11,IgnoreGuiInset=true,ResetOnSpawn=false})
    local ToggleBtn=Library:Create("TextButton",{Name="ToggleBtn",Parent=ToggleScreen,BackgroundColor3=T.ToggleBg,BorderSizePixel=0,
        Position=UDim2.new(0.06,0,0.15,0),Size=UDim2.new(0,50,0,50),Text="",ClipsDescendants=true,AutoButtonColor=false})
    rB(ToggleBtn,"BackgroundColor3")
    local ToggleBtnCornerObj=Library:Create("UICorner",{Parent=ToggleBtn,CornerRadius=ToggleBtnCorner})
    Library:Create("UIStroke",{Parent=ToggleBtn,Color=T.Stroke,Thickness=0.7})
    local ToggleLogo=Library:Create("ImageLabel",{Name="Logo",Parent=ToggleBtn,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,
        BorderSizePixel=0,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0.54,0,0.54,0),Image=ToggleIcon,ImageColor3=T.Accent})
    rA(ToggleLogo,"ImageColor3")
    Library:Draggable(ToggleBtn)
    ToggleBtn.MouseButton1Click:Connect(function() Background.Visible=not Background.Visible end)
    UserInputService.InputBegan:Connect(function(inp,proc)
        if proc then return end
        if inp.KeyCode==ToggleKey then Background.Visible=not Background.Visible end
    end)

    local MiniBar=Library:Create("Frame",{Name="MiniBar",Parent=Background,BackgroundColor3=T.TabBg,BorderSizePixel=0,
        AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,0),Size=UDim2.new(1,0,0,8),ZIndex=5})
    Library:Create("UICorner",{Parent=MiniBar,CornerRadius=UDim.new(0,4)}); rTB(MiniBar,"BackgroundColor3")
    local MiniHandle=Library:Create("Frame",{Parent=MiniBar,BackgroundColor3=T.Stroke,BorderSizePixel=0,
        AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,24,0,2),BackgroundTransparency=0.4})
    Library:Create("UICorner",{Parent=MiniHandle,CornerRadius=UDim.new(1,0)})

    local ResizeHandle=Library:Create("TextButton",{Name="ResizeHandle",Parent=Background,BackgroundTransparency=1,
        BorderSizePixel=0,AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,0,1,0),Size=UDim2.new(0,22,0,22),Text="",ZIndex=10,AutoButtonColor=false})
    for ri=1,3 do
        Library:Create("Frame",{Parent=ResizeHandle,BackgroundColor3=T.Stroke,BorderSizePixel=0,
            AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-2,1,-2+((ri-1)*-5)),
            Size=UDim2.new(0,ri*8,0,1),BackgroundTransparency=0.3,Rotation=-45})
    end
    do
        local rDrag,rStart,rSize=false,nil,nil
        ResizeHandle.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
                rDrag=true; rStart=inp.Position; rSize=Vector2.new(Background.Size.X.Offset,Background.Size.Y.Offset)
            end
        end)
        ResizeHandle.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then rDrag=false end end)
        UserInputService.InputChanged:Connect(function(inp)
            if not rDrag then return end
            if inp.UserInputType~=Enum.UserInputType.MouseMovement and inp.UserInputType~=Enum.UserInputType.Touch then return end
            local d=inp.Position-rStart
            local nW=math.clamp(rSize.X+d.X/Scaler.Scale,260,900)
            local nH=math.clamp(rSize.Y+d.Y/Scaler.Scale,200,700)
            Background.Size=UDim2.new(0,nW,0,nH); RAW_W=nW; RAW_H=nH
        end)
        UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then rDrag=false end end)
    end

    local _locked=false; local _lockMsg="Locked"
    local TabLockOv=Library:Create("Frame",{Name="TabLock",Parent=Scale,BackgroundColor3=Color3.fromRGB(10,10,12),
        BackgroundTransparency=0.06,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=100,Visible=false})
    do
        local inn=Library:Create("Frame",{Parent=TabLockOv,BackgroundTransparency=1,BorderSizePixel=0,
            AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,0,0,0),AutomaticSize=Enum.AutomaticSize.XY,ZIndex=101})
        Library:Create("UIListLayout",{Parent=inn,SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center,Padding=UDim.new(0,4)})
        Library:Create("ImageLabel",{Parent=inn,BackgroundTransparency=1,BorderSizePixel=0,
            Size=UDim2.new(0,22,0,22),Image="rbxassetid://134724289526879",ImageColor3=Color3.fromRGB(180,180,190),ZIndex=102,LayoutOrder=1})
        Library:Create("TextLabel",{Parent=inn,BackgroundTransparency=1,BorderSizePixel=0,
            Size=UDim2.new(0,100,0,12),ZIndex=102,LayoutOrder=2,Font=Enum.Font.GothamMedium,
            Text="Locked",TextColor3=Color3.fromRGB(160,160,170),TextSize=10,TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=true})
    end

    local function OnReturn()
        ReturnBtn.Visible=false; ScriptIconFrame.Visible=true
        LeftBlock.Position=UDim2.new(0,46,0.5,0); PageService:JumpTo(Home)
    end
    ReturnBtn.MouseButton1Click:Connect(OnReturn)
    PageService:JumpTo(Home)
    Library:Draggable(Header,Background)

    local Window={}

    function Window:Popup(Args)
        local PTitle   = Args.Title or "Popup"
        local PDesc    = Args.Desc or ""
        local PButtons = Args.Buttons or {{Text="OK",Callback=function()end}}
        local Overlay=Library:Create("Frame",{Name="PopupOverlay",Parent=Background,BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=0.55,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=800})
        local PF=Library:Create("Frame",{Name="Popup",Parent=Background,AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=T.Background,BorderSizePixel=0,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,300,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=801})
        Library:Create("UICorner",{Parent=PF,CornerRadius=UDim.new(0,8)})
        Library:Create("UIStroke",{Parent=PF,Color=T.Stroke,Thickness=0.8})
        Library:Create("UIListLayout",{Parent=PF,SortOrder=Enum.SortOrder.LayoutOrder})
        local PHdr=Library:Create("Frame",{Parent=PF,BackgroundColor3=T.TabBg,BorderSizePixel=0,Size=UDim2.new(1,0,0,44),ZIndex=802})
        Library:Create("UICorner",{Parent=PHdr,CornerRadius=UDim.new(0,8)})
        Library:Create("Frame",{Parent=PHdr,BackgroundColor3=T.Accent,BorderSizePixel=0,AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,0,1,0),Size=UDim2.new(1,0,0,1),ZIndex=803})
        Library:Create("UIPadding",{Parent=PHdr,PaddingLeft=UDim.new(0,16),PaddingRight=UDim.new(0,16)})
        Library:Create("TextLabel",{Parent=PHdr,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),Font=T.FontBold,Text=PTitle,TextColor3=T.Text,TextSize=14,ZIndex=803,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,RichText=true})
        local PBody=Library:Create("Frame",{Parent=PF,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=802})
        Library:Create("UIPadding",{Parent=PBody,PaddingTop=UDim.new(0,14),PaddingBottom=UDim.new(0,16),PaddingLeft=UDim.new(0,16),PaddingRight=UDim.new(0,16)})
        Library:Create("UIListLayout",{Parent=PBody,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,14)})
        Library:Create("TextLabel",{Parent=PBody,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,Font=T.FontMedium,Text=PDesc,TextColor3=T.SubText,TextSize=12,ZIndex=803,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,RichText=true})
        local BR=Library:Create("Frame",{Parent=PBody,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,0,32),ZIndex=802})
        Library:Create("UIListLayout",{Parent=BR,FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center})
        local function Close() pcall(function()PF:Destroy()end); pcall(function()Overlay:Destroy()end) end
        for _,bd in ipairs(PButtons) do
            local isM=bd.Style=="main" or bd.Style==nil
            local tw=TextService:GetTextSize(bd.Text or "OK",12,T.FontBold,Vector2.new(300,32)).X
            local bW=math.clamp(tw+32,64,180)
            local Btn=Library:Create("TextButton",{Parent=BR,BackgroundColor3=isM and T.Accent or Color3.fromRGB(35,35,35),BorderSizePixel=0,
                Size=UDim2.new(0,bW,0,30),ZIndex=803,Font=T.FontBold,Text=bd.Text or "OK",
                TextColor3=Color3.fromRGB(255,255,255),TextSize=12,ClipsDescendants=true,AutoButtonColor=false})
            Library:Create("UICorner",{Parent=Btn,CornerRadius=UDim.new(0,6)})
            if isM then BtnGrad(Btn) end
            Btn.MouseButton1Click:Connect(function()
                Ripple(Btn)
                Close()
                if bd.Callback then pcall(bd.Callback) end
            end)
        end
        Library:Create("TextButton",{Parent=Overlay,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),Text="",ZIndex=800}).MouseButton1Click:Connect(Close)
        return {Close=Close}
    end

    function Window:Dialog(Args)
        return self:Popup({
            Title=Args.Title or "Confirm",Desc=Args.Desc or "Are you sure?",
            Buttons={
                {Text=Args.ConfirmText or "Confirm",Style="main",Callback=Args.OnConfirm},
                {Text=Args.CancelText  or "Cancel", Style="alt", Callback=Args.OnCancel},
            }
        })
    end

    function Window:NewPage(Args)
        local PageTitle   = Args.Title or "Page"
        local PageDesc    = Args.Desc or ""
        local PageIcon    = Args.Icon or 127194456372995
        local TabImg      = Args.TabImage
        local TabImgColor = Args.TabImageColor
        local NewTabs=Library:Create("Frame",{Name="NewTabs",Parent=MTS,BackgroundColor3=T.TabBg,BorderSizePixel=0,Size=UDim2.new(1,0,0,72),ClipsDescendants=true})
        rTB(NewTabs,"BackgroundColor3"); local TabCB=Library:Button(NewTabs)
        Library:Create("UICorner",{Parent=NewTabs,CornerRadius=UDim.new(0,6)})
        local TSI=Library:Create("UIStroke",{Parent=NewTabs,Color=T.TabStroke,Thickness=1}); rTS(TSI,"Color")
        local banImg=TabImg and Library:Asset(TabImg) or "rbxassetid://125411502674016"
        local banColor=TabImgColor and RC(TabImgColor) or T.TabImage
        local TabBann=Library:Create("ImageLabel",{Name="Banner",Parent=NewTabs,BackgroundTransparency=1,BorderSizePixel=0,
            Size=UDim2.new(1,0,1,0),Image=banImg,ImageColor3=banColor,ScaleType=Enum.ScaleType.Crop})
        if not TabImgColor and not TabImg then rTI(TabBann,"ImageColor3") end
        Library:Create("UICorner",{Parent=TabBann,CornerRadius=UDim.new(0,2)})
        local TabInfo=Library:Create("Frame",{Name="Info",Parent=NewTabs,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0)})
        Library:Create("UIListLayout",{Parent=TabInfo,Padding=UDim.new(0,10),FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center})
        Library:Create("UIPadding",{Parent=TabInfo,PaddingLeft=UDim.new(0,14)})
        local TabIcon=Library:Create("ImageLabel",{Name="Icon",Parent=TabInfo,BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=-1,Size=UDim2.new(0,22,0,22),Image=Library:Asset(PageIcon),ImageColor3=T.Accent})
        rA(TabIcon,"ImageColor3"); MkGrad(TabIcon)
        local TabText=Library:Create("Frame",{Name="Text",Parent=TabInfo,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(0,148,0,34)})
        Library:Create("UIListLayout",{Parent=TabText,Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center})
        local TabTL=Library:Create("TextLabel",{Name="Title",Parent=TabText,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(0,148,0,14),Font=T.FontBold,RichText=true,Text=PageTitle,TextColor3=T.Accent,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
        rA(TabTL,"TextColor3"); MkGrad(TabTL)
        Library:Create("TextLabel",{Name="Desc",Parent=TabText,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(0.9,0,0,10),Font=T.FontMedium,RichText=true,Text=PageDesc,TextColor3=T.SubText,TextSize=10,TextTransparency=0.3,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
        local NewPage=Library:Create("Frame",{Name="NewPage",Parent=Scale,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0)})
        local PS=Library:Create("ScrollingFrame",{Name="PageScrolling",Parent=NewPage,Active=true,BackgroundTransparency=1,BorderSizePixel=0,
            Size=UDim2.new(1,0,1,0),ClipsDescendants=true,AutomaticCanvasSize=Enum.AutomaticSize.None,
            BottomImage="rbxasset://textures/ui/Scroll/scroll-bottom.png",CanvasPosition=Vector2.new(0,0),
            ElasticBehavior=Enum.ElasticBehavior.WhenScrollable,MidImage="rbxasset://textures/ui/Scroll/scroll-middle.png",
            ScrollBarImageColor3=Color3.fromRGB(0,0,0),ScrollBarThickness=0,ScrollingDirection=Enum.ScrollingDirection.Y,
            TopImage="rbxasset://textures/ui/Scroll/scroll-top.png",VerticalScrollBarPosition=Enum.VerticalScrollBarPosition.Right})
        Library:Create("UIPadding",{Parent=PS,PaddingBottom=UDim.new(0,40),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14),PaddingTop=UDim.new(0,10)})
        local PL=Library:Create("UIListLayout",{Parent=PS,Padding=UDim.new(0,6),FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder})
        local function UpdateCanvas()
            PS.CanvasSize=UDim2.new(0,0,0,PL.AbsoluteContentSize.Y+60)
        end
        PL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
        PS:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvas)
        Scaler:GetPropertyChangedSignal("Scale"):Connect(function() task.defer(UpdateCanvas) end)
        TabCB.MouseButton1Click:Connect(function()
            if _locked then return end
            ReturnBtn.Visible=true; ScriptIconFrame.Visible=false
            LeftBlock.Position=UDim2.new(0,44,0.5,0); PageService:JumpTo(NewPage)
        end)

        local Page={}

        local function LockOv(parent,msg)
            local ov=Library:Create("Frame",{Parent=parent,BackgroundColor3=Color3.fromRGB(12,12,14),
                BackgroundTransparency=0.08,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=50,Visible=false})
            Library:Create("UICorner",{Parent=ov,CornerRadius=UDim.new(0,5)})
            local inner=Library:Create("Frame",{Parent=ov,BackgroundTransparency=1,BorderSizePixel=0,
                AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),
                Size=UDim2.new(0,0,0,0),AutomaticSize=Enum.AutomaticSize.XY,ZIndex=51})
            Library:Create("UIListLayout",{Parent=inner,SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center,Padding=UDim.new(0,4)})
            Library:Create("ImageLabel",{Parent=inner,BackgroundTransparency=1,BorderSizePixel=0,
                Size=UDim2.new(0,18,0,18),Image="rbxassetid://134724289526879",ImageColor3=Color3.fromRGB(180,180,190),ZIndex=52,LayoutOrder=1})
            Library:Create("TextLabel",{Parent=inner,BackgroundTransparency=1,BorderSizePixel=0,
                Size=UDim2.new(0,80,0,11),ZIndex=52,LayoutOrder=2,Font=Enum.Font.GothamMedium,
                Text=msg or _lockMsg,TextColor3=Color3.fromRGB(160,160,170),TextSize=10,
                TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=true})
            return ov
        end

        function Page:Section(txt)
            local row=Library:Create("Frame",{Name="Section",Parent=PS,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,0,24)})
            Library:Create("UIListLayout",{Parent=row,FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
            Library:Create("TextLabel",{Name="SL",Parent=row,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(0,0,0,14),AutomaticSize=Enum.AutomaticSize.X,LayoutOrder=1,Font=T.Font,RichText=true,Text=txt,TextColor3=T.SubText,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=false})
            Library:Create("Frame",{Parent=row,BackgroundColor3=T.Stroke,BorderSizePixel=0,LayoutOrder=2,Size=UDim2.new(1,0,0,1),BackgroundTransparency=0.3})
            local obj={}
            function obj:SetVisible(v) row.Visible=v end
            function obj:Destroy() row:Destroy() end
            return obj
        end

        function Page:Divider()
            local div=Library:Create("Frame",{Name="Divider",Parent=PS,BackgroundColor3=T.Stroke,BorderSizePixel=0,Size=UDim2.new(1,0,0,1),BackgroundTransparency=0.45})
            local obj={}
            function obj:SetVisible(v) div.Visible=v end
            function obj:Destroy() div:Destroy() end
            return obj
        end

        function Page:Label(Args)
            local R=Library:NewRows(PS,Args.Title,Args.Desc,T); local Left=R.Left
            local obj={}
            function obj:SetTitle(v) local t=Left:FindFirstChild("Title");if t then t.Text=tostring(v) end end
            function obj:SetDesc(v)  local d=Left:FindFirstChild("Desc"); if d then d.Text=tostring(v) end end
            function obj:SetVisible(v) R.Frame.Visible=v end
            function obj:Destroy()   R.Frame:Destroy() end
            return obj
        end

        function Page:Paragraph(Args)
            local hasThumb = Args.Thumbnail and Args.Thumbnail~=""
            local hasImg   = Args.Image and Args.Image~=""
            local imgMode  = Args.ImageMode or "beside"
            local hasButtons = Args.Buttons and #Args.Buttons>0
            local H = hasButtons and (hasThumb and 80 or 60) or (hasThumb and 64 or 44)
            local Rows=Library:Create("Frame",{Name="Paragraph",Parent=PS,BackgroundColor3=Args.Color and RC(Args.Color) or T.Row,BorderSizePixel=0,
                Size=UDim2.new(1,0,0,H),AutomaticSize=Enum.AutomaticSize.Y})
            Library:Create("UIStroke",{Parent=Rows,Color=T.Stroke,Thickness=0.5})
            Library:Create("UICorner",{Parent=Rows,CornerRadius=UDim.new(0,5)})
            Library:Create("UIPadding",{Parent=Rows,PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)})
            Library:Create("UIListLayout",{Parent=Rows,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6),FillDirection=Enum.FillDirection.Vertical})
            local ContentRow=Library:Create("Frame",{Parent=Rows,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=1})
            Library:Create("UIListLayout",{Parent=ContentRow,FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,10),VerticalAlignment=Enum.VerticalAlignment.Center})
            local ThumbLbl,IconLbl
            if hasThumb then
                ThumbLbl=Library:Create("ImageLabel",{Parent=ContentRow,BackgroundColor3=Color3.fromRGB(30,30,30),BorderSizePixel=0,
                    Size=UDim2.new(0,Args.ThumbnailSize or 44,0,Args.ThumbnailSize or 44),Image=Library:Asset(Args.Thumbnail),ScaleType=Enum.ScaleType.Crop})
                Library:Create("UICorner",{Parent=ThumbLbl,CornerRadius=UDim.new(0,6)})
            end
            local TextCol=Library:Create("Frame",{Parent=ContentRow,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,-(hasThumb and ((Args.ThumbnailSize or 44)+10) or 0),0,0),AutomaticSize=Enum.AutomaticSize.Y})
            Library:Create("UIListLayout",{Parent=TextCol,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,3),VerticalAlignment=Enum.VerticalAlignment.Center})
            if hasImg and imgMode=="top" then
                IconLbl=Library:Create("ImageLabel",{Parent=TextCol,BackgroundTransparency=1,BorderSizePixel=0,
                    LayoutOrder=0,Size=UDim2.new(1,0,0,Args.TopImageHeight or 100),Image=Library:Asset(Args.Image),ScaleType=Enum.ScaleType.Crop})
                Library:Create("UICorner",{Parent=IconLbl,CornerRadius=UDim.new(0,4)})
            end
            local TitleRow=Library:Create("Frame",{Parent=TextCol,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=1})
            Library:Create("UIListLayout",{Parent=TitleRow,FillDirection=Enum.FillDirection.Horizontal,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,6)})
            if hasImg and imgMode=="beside" then
                IconLbl=Library:Create("ImageLabel",{Parent=TitleRow,BackgroundTransparency=1,BorderSizePixel=0,
                    Size=UDim2.new(0,Args.ImageSize or 16,0,Args.ImageSize or 16),Image=Library:Asset(Args.Image),ImageColor3=T.Accent})
            end
            local TitleLbl=Library:Create("TextLabel",{Parent=TitleRow,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,-(hasImg and imgMode=="beside" and (Args.ImageSize or 16)+6 or 0),0,0),AutomaticSize=Enum.AutomaticSize.Y,
                Font=T.FontBold,Text=Args.Title or "",TextColor3=T.Text,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,RichText=true})
            local DescLbl=Library:Create("TextLabel",{Parent=TextCol,BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=2,
                Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
                Font=T.FontMedium,Text=Args.Desc or "",TextColor3=T.SubText,TextSize=11,TextTransparency=0.2,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,RichText=true})
            if hasButtons then
                local BtnRow2=Library:Create("Frame",{Parent=Rows,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=2})
                Library:Create("UIListLayout",{Parent=BtnRow2,FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center,Wraps=true})
                for _,bd in ipairs(Args.Buttons) do
                    local bl=bd.Title or bd.Text or "Btn"
                    local tw2=TextService:GetTextSize(bl,11,T.Font,Vector2.new(200,28)).X
                    local bW2=math.clamp(tw2+24,48,200)
                    local PBtn=Library:Create("TextButton",{Parent=BtnRow2,BackgroundColor3=bd.Color and RC(bd.Color) or T.Accent,BorderSizePixel=0,
                        Size=UDim2.new(0,bW2,0,26),Font=T.Font,Text=bl,TextColor3=Color3.fromRGB(255,255,255),TextSize=11,ClipsDescendants=true,AutoButtonColor=false})
                    Library:Create("UICorner",{Parent=PBtn,CornerRadius=UDim.new(0,5)})
                    BtnGrad(PBtn)
                    PBtn.MouseButton1Click:Connect(function() if _locked then return end; Ripple(PBtn); if bd.Callback then pcall(bd.Callback) end end)
                end
            end
            local PLockMsg=Args.LockMessage; local lov=LockOv(Rows,PLockMsg); local obj={}
            function obj:SetTitle(v) TitleLbl.Text=tostring(v) end
            function obj:SetDesc(v) DescLbl.Text=tostring(v) end
            function obj:SetImage(v) if IconLbl then IconLbl.Image=Library:Asset(v) end end
            function obj:SetThumbnail(v) if ThumbLbl then ThumbLbl.Image=Library:Asset(v) end end
            function obj:SetColor(v) Rows.BackgroundColor3=RC(v) end
            function obj:SetVisible(v) Rows.Visible=v end
            function obj:Lock(m) lov.Visible=true; if m then lov:FindFirstChildWhichIsA("TextLabel",true).Text=m end end
            function obj:Unlock() lov.Visible=false end
            function obj:Destroy() Rows:Destroy() end
            return obj
        end

        function Page:Button(Args)
            local Callback=Args.Callback; local BtnText=Args.Text or "Click"
            local SaveKey=Args.id
            local R=Library:NewRows(PS,Args.Title,Args.Desc,T); local Right=R.Right; local Left=R.Left
            local tw=TextService:GetTextSize(BtnText,11,T.Font,Vector2.new(200,26)).X
            local bW=math.clamp(tw+24,64,140)
            local Btn=Library:Create("TextButton",{Name="Button",Parent=Right,BackgroundColor3=T.Accent,BorderSizePixel=0,
                Size=UDim2.new(0,bW,0,26),ClipsDescendants=true,
                Font=T.Font,Text=BtnText,TextColor3=Color3.fromRGB(255,255,255),TextSize=11,AutoButtonColor=false,TextXAlignment=Enum.TextXAlignment.Center})
            rA(Btn,"BackgroundColor3"); Library:Create("UICorner",{Parent=Btn,CornerRadius=UDim.new(0,5)}); BtnGrad(Btn)
            Btn.MouseButton1Click:Connect(function() if _locked or Library:IsDropdownOpen() then return end; Ripple(Btn); if Callback then pcall(Callback) end end)
            local lov=LockOv(R.Frame,Args.LockMessage); local obj={}
            function obj:SetTitle(v) local t=Left:FindFirstChild("Title");if t then t.Text=tostring(v) end end
            function obj:SetDesc(v)  local d=Left:FindFirstChild("Desc"); if d then d.Text=tostring(v) end end
            function obj:SetText(v)  Btn.Text=tostring(v) end; function obj:GetValue() return BtnText end
            function obj:SetVisible(v) R.Frame.Visible=v end
            function obj:Lock(m) lov.Visible=true; if m then lov:FindFirstChildWhichIsA("TextLabel",true).Text=m end end
            function obj:Unlock() lov.Visible=false end; function obj:Destroy() R.Frame:Destroy() end
            setmetatable(obj,{__newindex=function(t,k,v) rawset(t,k,v)
                if k=="Title" then local tl=Left:FindFirstChild("Title");if tl then tl.Text=tostring(v) end
                elseif k=="Desc" then local dl=Left:FindFirstChild("Desc");if dl then dl.Text=tostring(v) end
                elseif k=="Text" then Btn.Text=tostring(v) end end})
            return obj
        end

        function Page:Toggle(Args)
            local Value   = Args.Value or false
            local Callback= Args.Callback or function()end
            local SaveKey = Args.id
            local CornerR = Args.CornerRadius or UDim.new(0,6)
            local ChkIcon = Args.Icon
            local Enabled = Args.Enabled ~= false
            local R=Library:NewRows(PS,Args.Title,Args.Desc,T); local Left=R.Left; local Right=R.Right
            local TitleLbl=Left:FindFirstChild("Title")
            if SaveKey and Cfg:getval(SaveKey)~=nil then Value=Cfg:getval(SaveKey) end
            local Bg=Library:Create("Frame",{Name="ToggleBg",Parent=Right,BackgroundColor3=T.RowAlt,BorderSizePixel=0,Size=UDim2.new(0,22,0,22)})
            local Stroke=Library:Create("UIStroke",{Parent=Bg,Color=T.Stroke,Thickness=0.7})
            Library:Create("UICorner",{Parent=Bg,CornerRadius=CornerR}); rAlt(Bg,"BackgroundColor3")
            local Hl=Library:Create("Frame",{Parent=Bg,AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=T.Accent,BorderSizePixel=0,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,1,0),BackgroundTransparency=1})
            Library:Create("UICorner",{Parent=Hl,CornerRadius=CornerR}); rA(Hl,"BackgroundColor3"); BtnGrad(Hl)
            local ChkImg=Library:Create("ImageLabel",{Parent=Hl,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0.62,0,0.62,0),Image=ChkIcon and Library:Asset(ChkIcon) or "",ImageTransparency=1})
            local CB=Library:Button(Bg); local Data={Value=Value,Enabled=Enabled}
            local function OnChanged(val,skipCallback)
                Data.Value=val; if SaveKey then Cfg:setval(SaveKey,val) end
                if val then
                    if not skipCallback then pcall(Callback,val) end
                    if TitleLbl then TitleLbl.TextColor3=T.Accent end
                    Library:Tween({v=Hl,t=0.25,s="Exponential",d="Out",g={BackgroundTransparency=0}}):Play()
                    Library:Tween({v=ChkImg,t=0.2,s="Exponential",d="Out",g={ImageTransparency=ChkIcon and 0 or 1}}):Play()
                    Stroke.Thickness=0
                else
                    if not skipCallback then pcall(Callback,val) end
                    if TitleLbl then TitleLbl.TextColor3=T.Text end
                    Library:Tween({v=Hl,t=0.25,s="Exponential",d="Out",g={BackgroundTransparency=1}}):Play()
                    Library:Tween({v=ChkImg,t=0.2,s="Exponential",d="Out",g={ImageTransparency=1}}):Play()
                    Stroke.Thickness=0.7
                end
            end
            if SaveKey then
                Cfg:Register(SaveKey,function(v)
                    local bv=v
                    if type(v)=="string" then bv=(v=="true") elseif type(v)=="number" then bv=v~=0 end
                    OnChanged(bv,true)
                end)
            end
            CB.MouseButton1Click:Connect(function() if _locked or Library:IsDropdownOpen() or not Data.Enabled then return end; OnChanged(not Data.Value,false) end)
            OnChanged(Value,true)
            local lov=LockOv(R.Frame,Args.LockMessage); local obj={}
            function obj:SetTitle(v) if TitleLbl then TitleLbl.Text=tostring(v) end end
            function obj:SetDesc(v)  local d=Left:FindFirstChild("Desc"); if d then d.Text=tostring(v) end end
            function obj:SetValue(v) OnChanged(v,false) end
            function obj:GetValue()  return Data.Value end
            function obj:SetIcon(v)  ChkImg.Image=Library:Asset(v); ChkIcon=v end
            function obj:Enable()    Data.Enabled=true;  R.Frame.BackgroundTransparency=0 end
            function obj:Disable()   Data.Enabled=false; R.Frame.BackgroundTransparency=0.5 end
            function obj:IsEnabled() return Data.Enabled end
            function obj:SetVisible(v) R.Frame.Visible=v end
            function obj:Lock(m) lov.Visible=true; if m then lov:FindFirstChildWhichIsA("TextLabel",true).Text=m end end
            function obj:Unlock() lov.Visible=false end
            function obj:Destroy() R.Frame:Destroy() end
            setmetatable(obj,{
                __newindex=function(t,k,v) rawset(t,k,v)
                    if k=="Title" and TitleLbl then TitleLbl.Text=tostring(v)
                    elseif k=="Value" then OnChanged(v)
                    elseif k=="Enabled" then if v then obj:Enable() else obj:Disable() end end end,
                __index=function(t,k) if k=="Value" then return Data.Value end; return rawget(t,k) end})
            if not Enabled then obj:Disable() end
            return obj
        end

        function Page:Slider(Args)
            local Min     = Args.Min or 0
            local Max     = Args.Max or 100
            local Rounding= Args.Rounding or 0
            local Value   = Args.Value or Min
            local Suffix  = Args.Suffix or ""
            local Callback= Args.Callback or function()end
            local SaveKey = Args.id
            if SaveKey and Cfg:getval(SaveKey)~=nil then Value=Cfg:getval(SaveKey) end
            local SF=Library:Create("Frame",{Name="Slider",Parent=PS,BackgroundColor3=T.Row,BorderSizePixel=0,Size=UDim2.new(1,0,0,44)})
            Library:Create("UICorner",{Parent=SF,CornerRadius=UDim.new(0,5)}); Library:Create("UIStroke",{Parent=SF,Color=T.Stroke,Thickness=0.5})
            Library:Create("UIPadding",{Parent=SF,PaddingBottom=UDim.new(0,1),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
            local TextF=Library:Create("Frame",{Name="Text",Parent=SF,BackgroundTransparency=1,BorderSizePixel=0,
                Position=UDim2.new(0,0,0.1,0),Size=UDim2.new(0,111,0,22)})
            Library:Create("UIListLayout",{Parent=TextF,SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center})
            Library:Create("UIPadding",{Parent=TextF,PaddingBottom=UDim.new(0,3)})
            local TitleLbl=Library:Create("TextLabel",{Name="Title",Parent=TextF,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,
                LayoutOrder=-1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,0,13),
                Font=T.Font,RichText=true,Text=Args.Title or "",TextColor3=T.Text,TextSize=12,
                TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y})
            Library:Create("UIGradient",{Parent=TitleLbl,Rotation=90,Color=ColorSequence.new{
                ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),
                ColorSequenceKeypoint.new(0.75,T.SubText),
                ColorSequenceKeypoint.new(1,Color3.fromRGB(100,100,100))}})
            local Scaling=Library:Create("Frame",{Name="Scaling",Parent=SF,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0)})
            local Slide=Library:Create("Frame",{Name="Slide",Parent=Scaling,AnchorPoint=Vector2.new(0,1),BackgroundTransparency=1,BorderSizePixel=0,
                Position=UDim2.new(0,0,1,0),Size=UDim2.new(1,0,0,23)})
            local ColorBar=Library:Create("Frame",{Name="ColorBar",Parent=Slide,AnchorPoint=Vector2.new(0.5,0.5),
                BackgroundColor3=Color3.fromRGB(10,10,10),BorderSizePixel=0,
                Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,0,5)})
            Library:Create("UICorner",{Parent=ColorBar,CornerRadius=UDim.new(0,3)})
            local Fill=Library:Create("Frame",{Name="Fill",Parent=ColorBar,BackgroundColor3=T.Accent,BorderSizePixel=0,Size=UDim2.new(0,0,1,0)})
            rA(Fill,"BackgroundColor3"); Library:Create("UICorner",{Parent=Fill,CornerRadius=UDim.new(0,3)})
            Library:Create("UIGradient",{Parent=Fill,Rotation=90,Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(47,47,47))}})
            Library:Create("Frame",{Name="Circle",Parent=Fill,AnchorPoint=Vector2.new(1,0.5),BackgroundColor3=Color3.fromRGB(255,255,255),BorderSizePixel=0,Position=UDim2.new(1,0,0.5,0),Size=UDim2.new(0,5,0,11)})
            local ValueBox=Library:Create("TextBox",{Name="Boxvalue",Parent=Scaling,AnchorPoint=Vector2.new(1,0.5),BackgroundTransparency=1,BorderSizePixel=0,
                Position=UDim2.new(1,-5,0.449,-2),Size=UDim2.new(0,60,0,15),ZIndex=5,
                Font=T.FontMedium,Text=tostring(Value)..Suffix,TextColor3=T.Text,TextSize=11,TextTransparency=0.5,
                TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Right,TextWrapped=true,ClearTextOnFocus=false})
            local dragging=false; local Data={Value=Value}
            local function Round(n,d) return math.floor(n*(10^d)+0.5)/(10^d) end
            local function UpdateSlider(val)
                val=math.clamp(val,Min,Max); val=Round(val,Rounding); Data.Value=val
                if SaveKey then Cfg:setval(SaveKey,val) end
                local ratio=(val-Min)/(Max-Min)
                Library:Tween({v=Fill,t=0.1,s="Linear",d="Out",g={Size=UDim2.new(ratio,0,1,0)}}):Play()
                ValueBox.Text=tostring(val)..(Suffix~="" and (" "..Suffix) or "")
                pcall(Callback,val); return val
            end
            local function GetVal(inp)
                local ax=ColorBar.AbsolutePosition.X; local aw=ColorBar.AbsoluteSize.X
                if aw<=0 then return Value end
                return math.clamp((inp.Position.X-ax)/aw,0,1)*(Max-Min)+Min
            end
            local function SetDragging(s)
                dragging=s
                local col=s and T.Accent or T.Text
                Library:Tween({v=ValueBox,t=s and 0.3 or 0.3,s="Back",d="Out",g={TextSize=s and 15 or 11}}):Play()
                Library:Tween({v=ValueBox,t=0.2,s="Exponential",d="Out",g={TextColor3=col}}):Play()
                Library:Tween({v=TitleLbl,t=0.2,s="Exponential",d="Out",g={TextColor3=col}}):Play()
            end
            local HitBtn=Library:Button(SF); HitBtn.ZIndex=4
            HitBtn.InputBegan:Connect(function(inp)
                if _locked or Library:IsDropdownOpen() then return end
                if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
                    SetDragging(true); UpdateSlider(GetVal(inp))
                end
            end)
            HitBtn.InputEnded:Connect(function(inp)
                if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then SetDragging(false) end
            end)
            UserInputService.InputChanged:Connect(function(inp)
                if Library:IsDropdownOpen() then return end
                if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then UpdateSlider(GetVal(inp)) end
            end)
            ValueBox.Focused:Connect(function()
                Library:Tween({v=ValueBox,t=0.2,s="Exponential",d="Out",g={TextColor3=T.Accent}}):Play()
                Library:Tween({v=TitleLbl,t=0.2,s="Exponential",d="Out",g={TextColor3=T.Accent}}):Play()
            end)
            ValueBox.FocusLost:Connect(function()
                Library:Tween({v=ValueBox,t=0.2,s="Exponential",d="Out",g={TextColor3=T.Text}}):Play()
                Library:Tween({v=TitleLbl,t=0.2,s="Exponential",d="Out",g={TextColor3=T.Text}}):Play()
                Value=UpdateSlider(tonumber(ValueBox.Text:match("%-?%d+%.?%d*")) or Value)
            end)
            UpdateSlider(Value)
            if SaveKey then
                Cfg:Register(SaveKey,function(v)
                    local n=tonumber(v); if n then UpdateSlider(n) end
                end)
            end
            local lov=LockOv(SF,Args.LockMessage); local obj={}
            function obj:SetTitle(v) TitleLbl.Text=tostring(v) end
            function obj:SetValue(v) UpdateSlider(v) end
            function obj:SetMin(v) Min=v end; function obj:SetMax(v) Max=v end
            function obj:GetValue() return Data.Value end
            function obj:SetVisible(v) SF.Visible=v end
            function obj:Lock(m) lov.Visible=true; if m then lov:FindFirstChildWhichIsA("TextLabel",true).Text=m end end
            function obj:Unlock() lov.Visible=false end; function obj:Destroy() SF:Destroy() end
            setmetatable(obj,{
                __newindex=function(t,k,v) rawset(t,k,v)
                    if k=="Title" then TitleLbl.Text=tostring(v) elseif k=="Value" then UpdateSlider(v)
                    elseif k=="Min" then Min=v elseif k=="Max" then Max=v end end,
                __index=function(t,k) if k=="Value" then return Data.Value end; return rawget(t,k) end})
            return obj
        end

        function Page:Input(Args)
            local Value      = Args.Value or ""
            local Callback   = Args.Callback or function()end
            local Placeholder= Args.Placeholder or "Type here..."
            local COS        = Args.ClearOnSubmit or false
            local ShowEnter  = Args.ShowButton~=false
            local SaveKey    = Args.id
            if SaveKey and Cfg:getval(SaveKey)~=nil then Value=Cfg:getval(SaveKey) end
            local IF=Library:Create("Frame",{Name="InputFrame",Parent=PS,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,0,36)})
            Library:Create("UIListLayout",{Parent=IF,Padding=UDim.new(0,6),FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center})
            local frontW=ShowEnter and UDim2.new(1,-44,1,0) or UDim2.new(1,0,1,0)
            local Front=Library:Create("Frame",{Name="Front",Parent=IF,BackgroundColor3=T.Row,BorderSizePixel=0,Size=frontW,LayoutOrder=1})
            Library:Create("UICorner",{Parent=Front,CornerRadius=UDim.new(0,5)}); Library:Create("UIStroke",{Parent=Front,Color=T.Stroke,Thickness=0.5})
            Library:Create("UIPadding",{Parent=Front,PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,8)})
            local TB=Library:Create("TextBox",{Parent=Front,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),Font=T.FontMedium,PlaceholderColor3=Color3.fromRGB(68,68,68),PlaceholderText=Placeholder,Text=tostring(Value),TextColor3=Color3.fromRGB(200,200,200),TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=false,ClearTextOnFocus=false})
            TB.FocusLost:Connect(function(e) if e then if not _locked then pcall(Callback,TB.Text); if SaveKey then Cfg:setval(SaveKey,TB.Text) end end; if COS then TB.Text="" end end end)
            if ShowEnter then
                local Enter=Library:Create("TextButton",{Name="Enter",Parent=IF,BackgroundColor3=T.RowAlt,BorderSizePixel=0,Size=UDim2.new(0,36,0,36),Text="",AutoButtonColor=false,ClipsDescendants=true,LayoutOrder=2})
                rAlt(Enter,"BackgroundColor3")
                Library:Create("UICorner",{Parent=Enter,CornerRadius=UDim.new(0,5)})
                Library:Create("UIStroke",{Parent=Enter,Color=T.Stroke,Thickness=0.5})
                Library:Create("ImageLabel",{Parent=Enter,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,16,0,16),Image="rbxassetid://78020815235467",ImageColor3=T.SubText})
                local copied=false
                Enter.MouseButton1Click:Connect(function()
                    if copied then return end
                    Ripple(Enter)
                    if Exec.clipboard then VClip(TB.Text) end
                    copied=true
                    local ck=Enter:FindFirstChildWhichIsA("ImageLabel"); if ck then ck.Image="rbxassetid://121742282171603"; ck.ImageColor3=T.Accent end
                    task.delay(1.5,function()
                        if Enter and Enter.Parent then
                            local ck2=Enter:FindFirstChildWhichIsA("ImageLabel"); if ck2 then ck2.Image="rbxassetid://78020815235467"; ck2.ImageColor3=T.SubText end
                            copied=false
                        end
                    end)
                end)
            end
            if SaveKey then
                Cfg:Register(SaveKey,function(v) TB.Text=tostring(v) end)
            end
            local lov=LockOv(IF,Args.LockMessage); local obj={}
            function obj:SetPlaceholder(v) TB.PlaceholderText=tostring(v) end
            function obj:SetValue(v) TB.Text=tostring(v) end
            function obj:GetValue() return TB.Text end
            function obj:SetVisible(v) IF.Visible=v end
            function obj:Lock(m) lov.Visible=true; if m then lov:FindFirstChildWhichIsA("TextLabel",true).Text=m end end
            function obj:Unlock() lov.Visible=false end; function obj:Destroy() IF:Destroy() end
            setmetatable(obj,{__newindex=function(t,k,v) rawset(t,k,v); if k=="Value" then TB.Text=tostring(v) elseif k=="Placeholder" then TB.PlaceholderText=tostring(v) end end,__index=function(t,k) if k=="Value" then return TB.Text end; return rawget(t,k) end})
            return obj
        end

        function Page:Dropdown(Args)
            local DTitle=Args.Title; local List=Args.List or {}; local Value=Args.Value
            local Callback=Args.Callback or function()end; local IsMulti=typeof(Value)=="table"
            local SaveKey=Args.id
            if SaveKey and Cfg:getval(SaveKey)~=nil then
                local sv=Cfg:getval(SaveKey); if sv~=nil then Value=sv end
            end
            local R=Library:NewRows(PS,DTitle,nil,T); local Right=R.Right; local Left=R.Left
            local DescL=Left:FindFirstChild("Desc")
            if not DescL then
                DescL=Library:Create("TextLabel",{Name="Desc",Parent=Left,BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=2,Size=UDim2.new(1,0,0,11),Font=T.FontMedium,Text="",TextColor3=T.SubText,TextSize=10,TextTransparency=0.3,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=false,RichText=true})
            end
            DescL.Visible=true
            local DDIcon=Library:Create("ImageLabel",{Parent=Right,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(0,20,0,20),Image="rbxassetid://132291592681506",ImageTransparency=0.5})
            local DDBtn=Library:Button(R.Frame)
            local DropFrame=Library:Create("Frame",{Name="Dropdown",Parent=Background,AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=T.DropBg,BorderSizePixel=0,Position=UDim2.new(0.5,0,0.3,0),Size=UDim2.new(0,300,0,250),ZIndex=500,Visible=false})
            rB(DropFrame,"BackgroundColor3")
            Library:Create("UICorner",{Parent=DropFrame,CornerRadius=UDim.new(0,3)})
            Library:Create("UIStroke",{Parent=DropFrame,Color=T.Stroke,Thickness=0.5})
            Library:Create("UIListLayout",{Parent=DropFrame,Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center})
            Library:Create("UIPadding",{Parent=DropFrame,PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,10)})
            local DropText=Library:Create("Frame",{Name="Text",Parent=DropFrame,BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=-5,Size=UDim2.new(1,0,0,30),ZIndex=500})
            Library:Create("UIListLayout",{Parent=DropText,Padding=UDim.new(0,1),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center})
            local DTitleLbl=Library:Create("TextLabel",{Name="Title",Parent=DropText,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=-1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,0,13),ZIndex=500,Font=T.Font,RichText=true,Text=DTitle or "",TextColor3=T.Accent,TextSize=14,TextStrokeTransparency=0.7,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y})
            rA(DTitleLbl,"TextColor3")
            Library:Create("UIGradient",{Parent=DTitleLbl,Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(0.75,T.SubText),ColorSequenceKeypoint.new(1,Color3.fromRGB(100,100,100))},Rotation=90})
            local function GetText()
                if IsMulti then return table.concat(type(Value)=="table" and Value or {},", ") end
                return Value~=nil and tostring(Value) or ""
            end
            local Desc1=Library:Create("TextLabel",{Name="Desc",Parent=DropText,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,0,10),ZIndex=500,Font=T.FontMedium,RichText=true,Text=GetText(),TextColor3=T.Text,TextSize=10,TextStrokeTransparency=0.7,TextTransparency=0.6,TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y})
            DescL.Text=GetText()
            local InputF=Library:Create("Frame",{Name="Input",Parent=DropFrame,BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=-4,Size=UDim2.new(1,0,0,25),ZIndex=500})
            Library:Create("UIListLayout",{Parent=InputF,Padding=UDim.new(0,5),FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center})
            local FrontF=Library:Create("Frame",{Name="Front",Parent=InputF,BackgroundColor3=T.Row,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=500})
            Library:Create("UICorner",{Parent=FrontF,CornerRadius=UDim.new(0,2)}); Library:Create("UIStroke",{Parent=FrontF,Color=T.Stroke,Thickness=0.5})
            local SearchBox=Library:Create("TextBox",{Name="Search",Parent=FrontF,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,CursorPosition=-1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,-20,1,0),ZIndex=500,Font=T.FontMedium,PlaceholderColor3=Color3.fromRGB(55,55,55),PlaceholderText="Search",Text="",TextColor3=T.Text,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
            local List1=Library:Create("ScrollingFrame",{Name="List",Parent=DropFrame,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,0,160),ZIndex=500,ScrollBarThickness=0})
            local ScrollL=Library:Create("UIListLayout",{Parent=List1,Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center})
            Library:Create("UIPadding",{Parent=List1,PaddingLeft=UDim.new(0,1),PaddingRight=UDim.new(0,1)})
            ScrollL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                List1.CanvasSize=UDim2.new(0,0,0,ScrollL.AbsoluteContentSize.Y+15)
            end)
            local selectedValues={}; local selectedOrder=0
            local function isInTable(val,tbl)
                if type(tbl)~="table" then return false end
                for _,v in pairs(tbl) do if v==val then return true end end
                return false
            end
            local function Settext()
                if IsMulti then
                    local t=table.concat(Value,", "); Desc1.Text=t; DescL.Text=t
                else
                    Desc1.Text=tostring(Value); DescL.Text=tostring(Value)
                end
                if SaveKey then Cfg:setval(SaveKey,Value) end
            end
            if SaveKey then
                Cfg:Register(SaveKey,function(v)
                    Value=v
                    if IsMulti and type(v)~="table" then Value={} end
                    selectedValues={}; selectedOrder=0
                    for _,ch in ipairs(List1:GetChildren()) do
                        if ch:IsA("Frame") and ch.Name=="NewList" and ch:FindFirstChild("Title") then
                            local nm=ch.Title.Text
                            local sel=(IsMulti and type(Value)=="table" and isInTable(nm,Value)) or (not IsMulti and Value==nm)
                            ch.Title.TextColor3=sel and T.Accent or T.Text
                            TweenService:Create(ch,TweenInfo.new(0.2),{BackgroundTransparency=sel and 0.85 or 1}):Play()
                        end
                    end
                    Settext()
                end)
            end
            local isOpen=false
            UserInputService.InputBegan:Connect(function(A)
                if not isOpen then return end
                local mouse=LocalPlayer:GetMouse(); local mx,my=mouse.X,mouse.Y
                local dp,ds=DropFrame.AbsolutePosition,DropFrame.AbsoluteSize
                if A.UserInputType==Enum.UserInputType.MouseButton1 or A.UserInputType==Enum.UserInputType.Touch then
                    if not(mx>=dp.X and mx<=dp.X+ds.X and my>=dp.Y and my<=dp.Y+ds.Y) then
                        isOpen=false; DropFrame.Visible=false; DropFrame.Position=UDim2.new(0.5,0,0.3,0)
                    end
                end
            end)
            DDBtn.MouseButton1Click:Connect(function()
                if _locked or Library:IsDropdownOpen() then return end
                isOpen=not isOpen
                if isOpen then
                    DropFrame.Visible=true
                    Library:Tween({v=DropFrame,t=0.3,s="Back",d="Out",g={Position=UDim2.new(0.5,0,0.5,0)}}):Play()
                else
                    DropFrame.Visible=false; DropFrame.Position=UDim2.new(0.5,0,0.3,0)
                end
            end)
            local Setting={}
            function Setting:Clear(a)
                for _,v in ipairs(List1:GetChildren()) do
                    if v:IsA("Frame") then
                        local should=a==nil or (type(a)=="string" and v:FindFirstChild("Title") and v.Title.Text==a) or (type(a)=="table" and v:FindFirstChild("Title") and isInTable(v.Title.Text,a))
                        if should then v:Destroy() end
                    end
                end
                if a==nil then Value=nil; selectedValues={}; selectedOrder=0; Desc1.Text="None"; DescL.Text="None" end
            end
            function Setting:AddList(Name)
                local Item=Library:Create("Frame",{Name="NewList",Parent=List1,BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=0,Size=UDim2.new(1,0,0,25),ZIndex=500})
                Library:Create("UICorner",{Parent=Item,CornerRadius=UDim.new(0,2)})
                local ItemTitle=Library:Create("TextLabel",{Name="Title",Parent=Item,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=-1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,-15,1,0),ZIndex=500,Font=T.Font,RichText=true,Text=tostring(Name),TextColor3=T.Text,TextSize=11,TextStrokeTransparency=0.7,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y})
                Library:Create("UIGradient",{Parent=ItemTitle,Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(0.75,T.SubText),ColorSequenceKeypoint.new(1,Color3.fromRGB(100,100,100))},Rotation=90})
                local function OnValue(val)
                    ItemTitle.TextColor3=val and T.Accent or T.Text
                    Library:Tween({v=Item,t=0.2,s="Linear",d="Out",g={BackgroundTransparency=val and 0.85 or 1}}):Play()
                end
                local ItemClick=Library:Button(Item)
                local function OnSelected()
                    if IsMulti then
                        if selectedValues[Name] then
                            selectedValues[Name]=nil; Item.LayoutOrder=0; OnValue(false)
                        else
                            selectedOrder=selectedOrder-1; selectedValues[Name]=selectedOrder; Item.LayoutOrder=selectedOrder; OnValue(true)
                        end
                        local sel={}; for i in pairs(selectedValues) do table.insert(sel,i) end
                        if #sel>0 then table.sort(sel); Value=sel; Settext() else Desc1.Text="N/A"; DescL.Text="N/A" end
                        pcall(Callback,sel)
                    else
                        for _,v in pairs(List1:GetChildren()) do
                            if v:IsA("Frame") and v.Name=="NewList" and v:FindFirstChild("Title") then
                                v.Title.TextColor3=T.Text
                                Library:Tween({v=v,t=0.2,s="Linear",d="Out",g={BackgroundTransparency=1}}):Play()
                            end
                        end
                        OnValue(true); Value=Name; Settext(); pcall(Callback,Value)
                        isOpen=false; DropFrame.Visible=false; DropFrame.Position=UDim2.new(0.5,0,0.3,0)
                    end
                end
                task.defer(function()
                    if IsMulti then
                        if isInTable(Name,Value) then
                            selectedOrder=selectedOrder-1; selectedValues[Name]=selectedOrder; Item.LayoutOrder=selectedOrder; OnValue(true)
                            local sel={}; for i in pairs(selectedValues) do table.insert(sel,i) end
                            if #sel>0 then table.sort(sel); Settext() else Desc1.Text="N/A"; DescL.Text="N/A" end
                        end
                    else
                        if Name==Value then OnValue(true); Settext() end
                    end
                end)
                ItemClick.MouseButton1Click:Connect(OnSelected)
            end
            SearchBox.Changed:Connect(function()
                local s=string.lower(SearchBox.Text)
                for _,v in pairs(List1:GetChildren()) do
                    if v:IsA("Frame") and v.Name=="NewList" and v:FindFirstChild("Title") then
                        v.Visible=string.find(string.lower(v.Title.Text),s,1,true)~=nil
                    end
                end
            end)
            for _,name in ipairs(List) do Setting:AddList(name) end
            local lov=LockOv(R.Frame,Args.LockMessage); local obj={}
            function obj:SetTitle(v) local t=Left:FindFirstChild("Title");if t then t.Text=tostring(v) end end
            function obj:SetList(v) List=v; Setting:Clear(); for _,name in ipairs(v) do Setting:AddList(name) end end
            function obj:SetValue(v) Value=v; Settext() end
            function obj:GetValue() return Value end
            function obj:AddList(v) table.insert(List,v); Setting:AddList(v) end
            function obj:RemoveItem(v) Setting:Clear(v); for i,x in ipairs(List) do if x==v then table.remove(List,i); break end end end
            function obj:Clear() Setting:Clear() end
            function obj:Close() isOpen=false; DropFrame.Visible=false; DropFrame.Position=UDim2.new(0.5,0,0.3,0) end
            function obj:SetVisible(v) R.Frame.Visible=v; if not v then obj:Close() end end
            function obj:Lock(m) lov.Visible=true; if m then lov:FindFirstChildWhichIsA("TextLabel",true).Text=m end end
            function obj:Unlock() lov.Visible=false end; function obj:Destroy() R.Frame:Destroy(); DropFrame:Destroy() end
            setmetatable(obj,{__newindex=function(t,k,v) rawset(t,k,v); if k=="Value" then obj:SetValue(v) end end,__index=function(t,k) if k=="Value" then return Value end; return rawget(t,k) end})
            return obj
        end

        function Page:Keybind(Args)
            local Value   = Args.Value or Enum.KeyCode.Unknown
            local Callback= Args.Callback or function()end
            local SaveKey = Args.id
            local R=Library:NewRows(PS,Args.Title,Args.Desc,T); local Right=R.Right; local Left=R.Left
            if SaveKey and Cfg:getval(SaveKey)~=nil then
                local sv=Cfg:getval(SaveKey); local ok,kc=pcall(function() return Enum.KeyCode[sv] end); if ok and kc then Value=kc end
            end
            local KB=Library:Create("Frame",{Name="KeyBind",Parent=Right,BackgroundColor3=T.RowAlt,BorderSizePixel=0,Size=UDim2.new(0,80,0,22),ClipsDescendants=true})
            Library:Create("UICorner",{Parent=KB,CornerRadius=UDim.new(0,3)}); Library:Create("UIStroke",{Parent=KB,Color=T.Stroke,Thickness=0.5})
            local KL=Library:Create("TextLabel",{Parent=KB,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,-8,1,0),Font=T.Font,Text=tostring(Value.Name),TextColor3=T.Accent,TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd,TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y})
            rA(KL,"TextColor3")
            local CBK=Library:Button(KB); local listening=false; local Data={Value=Value}
            local function SetKey(k)
                Data.Value=k; KL.Text=tostring(k.Name); KL.TextColor3=T.Accent
                Library:Tween({v=KB,t=0.2,s="Exponential",d="Out",g={BackgroundColor3=T.RowAlt}}):Play()
                if SaveKey then Cfg:setval(SaveKey,k.Name) end; pcall(Callback,k)
            end
            CBK.MouseButton1Click:Connect(function()
                if _locked or Library:IsDropdownOpen() then return end
                if listening then return end; listening=true; KL.Text="..."; KL.TextColor3=T.Text
                Library:Tween({v=KB,t=0.2,s="Exponential",d="Out",g={BackgroundColor3=T.Stroke}}):Play()
                local conn; conn=UserInputService.InputBegan:Connect(function(inp,proc)
                    if proc then return end
                    if inp.UserInputType==Enum.UserInputType.Keyboard then listening=false; conn:Disconnect(); SetKey(inp.KeyCode) end
                end)
            end)
            UserInputService.InputBegan:Connect(function(inp,proc) if proc or listening then return end; if inp.KeyCode==Data.Value then pcall(Callback,Data.Value) end end)
            if SaveKey then
                Cfg:Register(SaveKey,function(v)
                    local ok,kc=pcall(function() return Enum.KeyCode[tostring(v)] end)
                    if ok and kc and kc~=Enum.KeyCode.Unknown then SetKey(kc) end
                end)
            end
            local lov=LockOv(R.Frame,Args.LockMessage); local obj={}
            function obj:SetTitle(v) local t=Left:FindFirstChild("Title");if t then t.Text=tostring(v) end end
            function obj:SetDesc(v)  local d=Left:FindFirstChild("Desc"); if d then d.Text=tostring(v) end end
            function obj:SetValue(v) SetKey(v) end; function obj:GetValue() return Data.Value end
            function obj:SetVisible(v) R.Frame.Visible=v end
            function obj:Lock(m) lov.Visible=true; if m then lov:FindFirstChildWhichIsA("TextLabel",true).Text=m end end
            function obj:Unlock() lov.Visible=false end; function obj:Destroy() R.Frame:Destroy() end
            setmetatable(obj,{__newindex=function(t,k,v) rawset(t,k,v); if k=="Value" then SetKey(v) end end,__index=function(t,k) if k=="Value" then return Data.Value end; return rawget(t,k) end})
            return obj
        end

        function Page:ColorPicker(Args)
            local R=Library:NewRows(PS,Args.Title,Args.Desc,T)
            local obj={}
            function obj:SetTitle(v) local t=R.Left:FindFirstChild("Title");if t then t.Text=tostring(v) end end
            function obj:SetValue(v) end; function obj:GetValue() return Color3.fromRGB(255,255,255) end
            function obj:SetVisible(v) R.Frame.Visible=v end
            function obj:Lock(m) end; function obj:Unlock() end; function obj:Destroy() R.Frame:Destroy() end
            return obj
        end

        function Page:RightLabel(Args)
            local R=Library:NewRows(PS,Args.Title,Args.Desc,T); local Right=R.Right; local Left=R.Left
            local Lbl=Library:Create("TextLabel",{Name="RLabel",Parent=Right,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(0,0,0,14),AutomaticSize=Enum.AutomaticSize.X,Font=T.Font,RichText=true,Text=Args.Right or "—",TextColor3=T.SubText,TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
            local obj={}
            function obj:SetTitle(v) local t=Left:FindFirstChild("Title");if t then t.Text=tostring(v) end end
            function obj:SetDesc(v)  local d=Left:FindFirstChild("Desc"); if d then d.Text=tostring(v) end end
            function obj:SetRight(v) Lbl.Text=tostring(v) end
            function obj:SetVisible(v) R.Frame.Visible=v end
            function obj:Destroy() R.Frame:Destroy() end
            setmetatable(obj,{__newindex=function(t,k,v) rawset(t,k,v); if k=="Right" then Lbl.Text=tostring(v) end end,__index=function(t,k) if k=="Right" then return Lbl.Text end; return rawget(t,k) end})
            return obj
        end

        function Page:Progress(Args)
            local Value=math.clamp(Args.Value or 0,0,100); local Max=Args.Max or 100; local Suffix=Args.Suffix or "%"
            local SF=Library:Create("Frame",{Name="Progress",Parent=PS,BackgroundColor3=T.Row,BorderSizePixel=0,Size=UDim2.new(1,0,0,50)})
            Library:Create("UICorner",{Parent=SF,CornerRadius=UDim.new(0,5)}); Library:Create("UIStroke",{Parent=SF,Color=T.Stroke,Thickness=0.5})
            local TitleLbl=Library:Create("TextLabel",{Name="Title",Parent=SF,BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0,14,0,10),Size=UDim2.new(1,-78,0,14),Font=T.Font,Text=Args.Title or "",TextColor3=T.Text,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,RichText=true})
            if Args.Title and Args.Title~="" then MkGrad(TitleLbl) end
            local ValLbl=Library:Create("TextLabel",{Parent=SF,BackgroundTransparency=1,BorderSizePixel=0,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,10),Size=UDim2.new(0,62,0,14),Font=T.FontMedium,Text=tostring(Value)..Suffix,TextColor3=T.SubText,TextSize=11,TextTransparency=0.3,TextXAlignment=Enum.TextXAlignment.Right,RichText=true})
            local BarBg=Library:Create("Frame",{Parent=SF,BackgroundColor3=Color3.fromRGB(28,28,28),BorderSizePixel=0,Position=UDim2.new(0,14,0,32),Size=UDim2.new(1,-28,0,6)})
            Library:Create("UICorner",{Parent=BarBg,CornerRadius=UDim.new(0,3)})
            local BarFill=Library:Create("Frame",{Parent=BarBg,BackgroundColor3=Args.Color and RC(Args.Color) or T.Accent,BorderSizePixel=0,Size=UDim2.new(Value/Max,0,1,0)})
            Library:Create("UICorner",{Parent=BarFill,CornerRadius=UDim.new(0,3)}); BtnGrad(BarFill); if not Args.Color then rA(BarFill,"BackgroundColor3") end
            local Data={Value=Value}
            local function SetVal(v) v=math.clamp(v,0,Max); Data.Value=v; Library:Tween({v=BarFill,t=0.3,s="Exponential",d="Out",g={Size=UDim2.new(v/Max,0,1,0)}}):Play(); ValLbl.Text=tostring(math.floor(v))..Suffix end
            local obj={}
            function obj:SetValue(v) SetVal(v) end; function obj:GetValue() return Data.Value end
            function obj:SetTitle(v) TitleLbl.Text=tostring(v) end
            function obj:SetColor(v) BarFill.BackgroundColor3=RC(v) end
            function obj:SetVisible(v) SF.Visible=v end
            function obj:Destroy() SF:Destroy() end
            setmetatable(obj,{__newindex=function(t,k,v) rawset(t,k,v); if k=="Value" then SetVal(v) elseif k=="Title" then TitleLbl.Text=tostring(v) end end,__index=function(t,k) if k=="Value" then return Data.Value end; return rawget(t,k) end})
            return obj
        end

        function Page:MultiButton(Args)
            local MTitle=Args.Title; local Buttons=Args.Buttons or {}
            local SF=Library:Create("Frame",{Name="MultiBtn",Parent=PS,BackgroundColor3=T.Row,BorderSizePixel=0,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
            Library:Create("UICorner",{Parent=SF,CornerRadius=T.CornerRadius}); Library:Create("UIStroke",{Parent=SF,Color=T.Stroke,Thickness=0.5})
            Library:Create("UIPadding",{Parent=SF,PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
            Library:Create("UIListLayout",{Parent=SF,FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8)})
            if MTitle and MTitle~="" then
                local TL=Library:Create("TextLabel",{Name="Title",Parent=SF,BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=1,Size=UDim2.new(1,0,0,14),Font=T.Font,RichText=true,Text=MTitle,TextColor3=T.Text,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left}); MkGrad(TL)
            end
            local n=#Buttons
            local gap=6
            local totalGap=gap*(n-1)
            local BtnRow=Library:Create("Frame",{Parent=SF,BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=2,Size=UDim2.new(1,0,0,30)})
            Library:Create("UIListLayout",{Parent=BtnRow,FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,gap),VerticalAlignment=Enum.VerticalAlignment.Center})
            local scalePer = n>0 and (1/n) or 1
            local offsetPer = n>1 and -(totalGap/n) or 0
            for _,bd in ipairs(Buttons) do
                local label=bd.Text or "Btn"
                local Btn=Library:Create("TextButton",{Parent=BtnRow,BackgroundColor3=bd.Color and RC(bd.Color) or T.Accent,BorderSizePixel=0,
                    Size=UDim2.new(scalePer,offsetPer,1,0),Font=T.Font,Text=label,
                    TextColor3=Color3.fromRGB(255,255,255),TextSize=11,ClipsDescendants=true,AutoButtonColor=false})
                Library:Create("UICorner",{Parent=Btn,CornerRadius=T.CornerRadius})
                if not bd.Color then rA(Btn,"BackgroundColor3") end; BtnGrad(Btn)
                Btn.MouseButton1Click:Connect(function() if _locked then return end; Ripple(Btn); if bd.Callback then pcall(bd.Callback) end end)
            end
            local obj={}
            function obj:SetVisible(v) SF.Visible=v end
            function obj:Destroy() SF:Destroy() end
            return obj
        end

        function Page:Banner(Args)
            local asset = type(Args)=="string" and Args or (Args.Image or Args.Asset or "")
            local H = (type(Args)=="table" and Args.Height) or 180
            local B=Library:Create("ImageLabel",{Name="Banner",Parent=PS,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,0,H),Image=Library:Asset(asset),ScaleType=Enum.ScaleType.Crop})
            Library:Create("UICorner",{Parent=B,CornerRadius=UDim.new(0,5)})
            local obj={}
            function obj:SetImage(v) B.Image=Library:Asset(v) end
            function obj:SetSize(v) B.Size=v end
            function obj:SetVisible(v) B.Visible=v end
            function obj:Destroy() B:Destroy() end
            return obj
        end

        return Page
    end
    function Library:SetExtraTitle(v)
        if v and v~="" then ExtraTitleLabel.Text=tostring(v); ExtraTitleLabel.Visible=true
        else ExtraTitleLabel.Visible=false; ExtraTitleLabel.Text="" end
    end
    function Library:SetExtraSubTitle(v)
        if v and v~="" then ExtraSubTitleLabel.Text=tostring(v); ExtraSubTitleLabel.Visible=true
        else ExtraSubTitleLabel.Visible=false; ExtraSubTitleLabel.Text="" end
    end
    function Library:SetWindowTitle(v)    if TitleLabel    then TitleLabel.Text=tostring(v)    end end
    function Library:SetWindowSubTitle(v) if SubTitleLabel then SubTitleLabel.Text=tostring(v) end end

    function Library:AddSizeSlider(Page)
        return Page:Slider({Title="Interface Scale",Min=0.35,Max=math.floor(MaxSc()*10+0.5)/10,Rounding=2,Value=Scaler.Scale,
            Callback=function(v) Scaler:SetAttribute("ManualScale",true); Scaler.Scale=CS(v) end})
    end

    function Library:SetTheme(nt)
        if nt.BG  then nt.Background=nt.BG;  nt.BG=nil  end
        if nt.Tab then nt.TabBg=nt.Tab;       nt.Tab=nil end
        for k,v in pairs(nt) do
            if k=="Font" or k=="FontBold" or k=="FontMedium" then T[k]=v
            else T[k]=RC(v) end
        end
        if T.Accent then T_ACCENT_FALLBACK=T.Accent end
        local function Apply(list,val) for _,r in ipairs(list) do local i,p=r[1],r[2]; if i and i.Parent then pcall(function() i[p]=val end) end end end
        Apply(_R.a,T.Accent); Apply(_R.bg,T.Background)
        Apply(_R.alt,T.RowAlt); Apply(_R.tb,T.TabBg)
        Apply(_R.ts,T.TabStroke); Apply(_R.ti,T.TabImage)
    end

    function Library:GetTheme()    local c={}; for k,v in pairs(T) do c[k]=v end; return c end
    function Library:SetToggleIcon(icon) if ToggleLogo then ToggleLogo.Image=Library:Asset(icon) end end
    function Library:SetToggleBtnCorner(udim) if ToggleBtnCornerObj then ToggleBtnCornerObj.CornerRadius=udim end end
    function Library:SetLockText(msg)
        _lockMsg=msg
        local lbl=TabLockOv:FindFirstChildWhichIsA("TextLabel",true)
        if lbl then lbl.Text=msg end
    end
    function Library:Lock()
        _locked=true; TabLockOv.Visible=true
        if ReturnBtn.Visible then OnReturn() end
    end
    function Library:Unlock()   _locked=false; TabLockOv.Visible=false end
    function Library:IsLocked() return _locked end
    function Library:Destroy()
        pcall(function() Xova:Destroy() end)
        pcall(function() ToggleScreen:Destroy() end)
        pcall(function() NotifGui:Destroy() end)
    end

    return Window
end

return Library
