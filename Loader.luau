local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local function notify(message)
    game.StarterGui:SetCore("SendNotification", {
        Title = "Lz Hub",
        Text = message,
        Duration = 5
    })
end

local function checkBlacklist()
    local requestFunc = request or http_request or (syn and syn.request) or (http and http.request)
    
    if not requestFunc then
        return false
    end
    
    local requestBody = HttpService:JSONEncode({
        userId = tostring(player.UserId)
    })
    
    local response
    local success = pcall(function()
        response = requestFunc({
            Url = "https://lzhub.vercel.app/api/check-blacklist",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = requestBody
        })
    end)
    
    if not success or not response then
        return false
    end
    
    local statusCode = response.StatusCode or response.statusCode or response.status
    local body = response.Body or response.body or response.content
    
    if not body or body == "" or (statusCode ~= 200 and statusCode ~= "200") then
        return false
    end
    
    local data
    local parseSuccess = pcall(function()
        data = HttpService:JSONDecode(body)
    end)
    
    if not parseSuccess or not data then
        return false
    end
    
    if data.blacklisted == true then
        notify("You are blacklisted! Contact support.")
        task.wait(2)
        player:Kick("🚫 BLACKLISTED\n\nYou have been banned from Lz Hub.\n\nReason: " .. (data.reason or "Violation of terms") .. "\n\nContact support on Discord.")
        return true
    end
    
    return false
end

if checkBlacklist() then
    return
end

do
    local placeId = 79546208627805
    if game.PlaceId == placeId then
        notify("In The Lobby, Please Join The Main Game! (99 Nights)")
        loadstring(game:HttpGet(""))()
        return
    end
end

do
    local placeId = 126509999114328
    if game.PlaceId == placeId then
        notify("Loading Script! (99 Nights)")
        loadstring(game:HttpGet(""))()
        return
    end
end

do
    if game.PlaceId == 108808025081246 or game.PlaceId == 120073741652089 then
        notify("Loading Script! (Hunting Season)")
        loadstring(game:HttpGet(""))()
        return
    end
end

do
    local placeId = 16732694052
    if game.PlaceId == placeId then
        notify("Loading Script! (Fisch)")
        loadstring(game:HttpGet("https://raw.githubusercontent.com/YallSumLs/LzHubScript/refs/heads/main/Fisch.luau"))()
        return
    end
end

notify("Game Unsupported, Loading Universal script.")
loadstring(game:HttpGet("https://raw.githubusercontent.com/YallSumLs/LzHubScript/refs/heads/main/Universal.Luau"))()
