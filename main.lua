-- KatssinnnHub loader: 1 link untuk semua game
local BASE = "https://raw.githubusercontent.com/katssV7/Test/refs/heads/main/"

-- [PlaceId] = "path file script di repo"
local Games = {
    [110730550789828] = "example.lua",        -- game pertama
    [91296119701853] = "games/game2.lua",    -- game kedua (Fishing)
    [79389059854988] = "games/game3.lua",    -- My Anime Mine
    [76427490154192] = "games/game4.lua",   -- Lonely
    [84556640895285] = "games/game5.lua",   -- Deagle Arena
    [118517641508250] = "games/autowalk.lua", -- Soreya
    [113384248926706] = "games/game6.lua",   -- Harpoon a fish
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

local ok, err = pcall(function()
    loadstring(game:HttpGet(BASE .. path))()
end)

if not ok then
    warn("[KatssinnnHub] Gagal memuat script: " .. tostring(err))
end
