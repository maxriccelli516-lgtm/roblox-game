-- Twee gouden sokkels op het plein met een standbeeld van een echte speler (hun eigen avatar):
-- de beste Aura farmer in deze server en de Aura Battle kampioen in deze server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Builder = require(script.Parent.Builder)
local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.MapBuilder)

local StatueService = {}

local REFRESH_INTERVAL = 30
local SCALE = 2.2

type Spot = {
	Top: CFrame,
	Folder: Folder,
	Label: TextLabel,
	UserId: number?,
	Model: Model?,
}

local function buildPedestal(cf: CFrame, color: Color3, parent: Instance): (CFrame, TextLabel)
	local y = 0
	for _, step in { { 10, 1.2 }, { 8, 1.2 }, { 6.5, 4.5 } } do
		Builder.Part({
			Name = "Pedestal",
			Size = Vector3.new(step[1], step[2], step[1]),
			CFrame = cf * CFrame.new(0, y + step[2] / 2, 0),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(40, 35, 55),
			Parent = parent,
		})
		y += step[2]
	end
	local trim = Builder.Part({
		Name = "GoldTrim",
		Size = Vector3.new(6.9, 0.6, 6.9),
		CFrame = cf * CFrame.new(0, y - 0.3, 0),
		Material = Enum.Material.Neon,
		Color = color,
		Parent = parent,
	})
	Builder.Sparkles(trim, color, 10)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 1.5
	light.Parent = trim
	local plaque = Builder.Part({
		Name = "Plaque",
		Size = Vector3.one * 0.2,
		CFrame = cf * CFrame.new(0, 2.2, -3.6),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
	local label = Builder.Billboard(plaque, "", UDim2.new(11, 0, 2.4, 0), Vector3.zero, color)
	return cf * CFrame.new(0, y, 0), label
end

local function placeAvatar(spot: Spot, userId: number)
	if spot.UserId == userId and spot.Model and spot.Model.Parent then
		return
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)
	if not ok or not model then
		return
	end
	if spot.Model then
		spot.Model:Destroy()
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	model.Name = "PlayerStatue"
	pcall(function()
		model:ScaleTo(SCALE)
	end)
	model:PivotTo(spot.Top)
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, spot.Top.Position.Y - bottom, 0))
	model.Parent = spot.Folder
	spot.Model = model
	spot.UserId = userId
end

local function clear(spot: Spot)
	if spot.Model then
		spot.Model:Destroy()
		spot.Model = nil
	end
	spot.UserId = nil
end

local function best(field: string): (Player?, number)
	local bestPlayer, bestValue = nil, 0
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		local value = data and data[field] or 0
		if value > bestValue then
			bestPlayer, bestValue = player, value
		end
	end
	return bestPlayer, bestValue
end

function StatueService.Init(map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "PlayerStatues"
	folder.Parent = map

	local function makeSpot(cf: CFrame, color: Color3): Spot
		local spotFolder = Instance.new("Folder")
		spotFolder.Parent = folder
		local top, label = buildPedestal(cf, color, spotFolder)
		return { Top = top, Folder = spotFolder, Label = label, UserId = nil, Model = nil }
	end
	local farmer = makeSpot(MapBuilder.Spots.TopFarmerStatue, Color3.fromRGB(255, 205, 80))
	local champion = makeSpot(MapBuilder.Spots.ChampionStatue, Color3.fromRGB(255, 110, 190))

	task.spawn(function()
		while true do
			local player, value = best("TotalEarned")
			if player then
				farmer.Label.Text = "👑 #1 AURA FARMER\n" .. player.DisplayName .. " • " .. Format.Number(value)
				placeAvatar(farmer, player.UserId)
			else
				farmer.Label.Text = "👑 #1 AURA FARMER\nCould be you!"
				clear(farmer)
			end

			local winner, wins = best("BattleWins")
			if winner then
				champion.Label.Text = "⚔️ BATTLE CHAMPION\n" .. winner.DisplayName .. " • " .. wins .. " wins"
				placeAvatar(champion, winner.UserId)
			else
				champion.Label.Text = "⚔️ BATTLE CHAMPION\nWin an Aura Battle to stand here!"
				clear(champion)
			end
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return StatueService
