-- KatssinnnHub loader: 1 link untuk semua game
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"

-- [PlaceId] = "path file script di repo"
local Games = {
    [110730550789828] = "example.lua",        -- game pertama
    [91296119701853] = "games/game2.lua",    -- game kedua (Fishing)
    [79389059854988] = "games/game3.lua",    -- My Anime Mine
}

local path = Games[game.PlaceId]

if not path then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "KatssinnnHub",
            Text = "Game ini belum didukung (PlaceId " .. tostring(game.PlaceId) .. ")",
            Duration = 6,
        })
    end)
    warn("[KatssinnnHub] Game belum didukung, PlaceId: " .. tostring(game.PlaceId))
    return
end

-- ===== TUNGGU OPENING GAME SELESAI =====
-- UI library + script baru dimuat setelah: game loaded, karakter ada, kamera bukan cutscene,
-- dan tidak ada layar loading/intro yang masih tampil. Batas tunggu: 90 detik (lalu tetap lanjut).
local MAX_WAIT = 90
local STABLE   = 1.5        -- harus bersih dari opening selama sekian detik berturut-turut
local KEYWORDS = { "load", "intro", "opening", "splash", "cutscene", "cinematic", "welcome" }

local function WaitForOpening()
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer
    while not LP do task.wait(); LP = Players.LocalPlayer end
    if not game:IsLoaded() then game.Loaded:Wait() end

    local t0 = os.clock()
    local function left() return MAX_WAIT - (os.clock() - t0) end

    local pg = LP:WaitForChild("PlayerGui", math.max(left(), 1))
    if not LP.Character then
        local c = LP.CharacterAdded:Wait()
        c:WaitForChild("HumanoidRootPart", 15)
    else
        LP.Character:WaitForChild("HumanoidRootPart", 15)
    end

    local notified = false
    local function notify()
        if notified then return end
        notified = true
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "KatssinnnHub",
                Text = "Menunggu opening game selesai...",
                Duration = 5,
            })
        end)
    end

    -- true kalau masih ada layar loading / intro yang menutupi layar
    local function loadingGuiActive()
        if not pg then return false end
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        for _, g in ipairs(pg:GetChildren()) do
            if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "KatssinnnUI" then
                local n = string.lower(g.Name)
                for _, k in ipairs(KEYWORDS) do
                    if n:find(k, 1, true) then
                        for _, d in ipairs(g:GetDescendants()) do
                            if d:IsA("GuiObject") and d.Visible then
                                local big = d.AbsoluteSize.X >= vp.X * 0.5 and d.AbsoluteSize.Y >= vp.Y * 0.5
                                local seen = (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.ImageTransparency < 0.95
                                    or d.BackgroundTransparency < 0.95
                                if big and seen then return true end
                            end
                        end
                        break
                    end
                end
            end
        end
        return false
    end

    local function opening()
        local cam = workspace.CurrentCamera
        if cam and cam.CameraType == Enum.CameraType.Scriptable then return true end   -- cutscene
        return loadingGuiActive()
    end

    local clean = 0
    while left() > 0 do
        if opening() then
            clean = 0
            notify()
        else
            clean += 0.25
        end
        if clean >= STABLE then return true end
        task.wait(0.25)
    end
    warn("[KatssinnnHub] Opening belum selesai setelah " .. MAX_WAIT .. "s, script tetap dimuat.")
    return false
end

pcall(WaitForOpening)

local ok, err = pcall(function()
    loadstring(game:HttpGet(BASE .. path))()
end)

if not ok then
    warn("[KatssinnnHub] Gagal memuat script: " .. tostring(err))
end
