-- Vrienden in dezelfde server geven allebei +10% Aura (max 3 vrienden).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local Remotes = ReplicatedStorage.Remotes

local FriendService = {}

local friendsOf: { [Player]: { [Player]: boolean } } = {}

local function update(player: Player)
	local count = 0
	local friends = friendsOf[player]
	if friends then
		for other in friends do
			if other.Parent then
				count += 1
			end
		end
	end
	player:SetAttribute("FriendsInServer", count)
	DataService.Changed(player)
end

function FriendService.OnJoin(player: Player)
	friendsOf[player] = friendsOf[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player and friendsOf[other] then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)
			if ok and isFriend then
				friendsOf[player][other] = true
				friendsOf[other][player] = true
				update(other)
				Remotes.Notify:FireClient(other, "Your friend " .. player.DisplayName .. " joined! +10% Aura", "success")
			end
		end
	end
	update(player)
end

function FriendService.Init()
	Players.PlayerRemoving:Connect(function(player)
		local friends = friendsOf[player]
		friendsOf[player] = nil
		if friends then
			for other in friends do
				if friendsOf[other] then
					friendsOf[other][player] = nil
					update(other)
				end
			end
		end
	end)
end

return FriendService
