-- De Aura Tower: een obby (parkour) van zwevende platforms in een spiraal rond een toren.
-- Bovenaan staat een kristal: aanraken geeft een flinke beloning en XP (elke 10 minuten opnieuw).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Builder = require(script.Parent.Builder)
local Bus = require(script.Parent.Bus)
local DataService = require(script.Parent.DataService)
local Decor = require(script.Parent.Decor)
local Economy = require(script.Parent.Economy)
local MapBuilder = require(script.Parent.MapBuilder)

local Remotes = ReplicatedStorage.Remotes
local Settings = Config.Obby

local ObbyService = {}

local PLATFORMS = 22
local RISE = 3.1
local SPIRAL_RADIUS = 10
local STEP_DEGREES = 36

local touchedAt: { [Player]: number } = {}

local function claim(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local now = os.time()
	local wait = data.LastObby + Settings.CooldownSeconds - now
	if wait > 0 then
		Remotes.Notify:FireClient(player, "Tower reward again in " .. Format.Time(wait), "info")
		return
	end
	data.LastObby = now
	data.ObbyClears += 1
	local minimum = Settings.MinimumReward * (data.Rebirths + 1)
	local amount = math.floor(math.max(minimum, Economy.BaseIncomePerSecond(player) * Settings.RewardMinutes * 60))
	DataService.AddAura(player, amount)
	Bus.Fire("ObbyCleared", player)
	Remotes.Notify:FireClient(player, "🗼 You beat the Aura Tower! +" .. Format.Number(amount) .. " Aura", "rare")
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.Notify:FireClient(other, "🗼 " .. player.DisplayName .. " climbed the Aura Tower!", "info")
		end
	end
end

function ObbyService.Init(map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "AuraTower"
	folder.Parent = map
	local center = MapBuilder.Spots.Obby
	local towerHeight = (PLATFORMS + 1) * RISE

	-- Toren in het midden met gloeiende ringen
	Builder.Part({
		Name = "TowerBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 30, 30),
		CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(190, 180, 170),
		Parent = folder,
	})
	Builder.Part({
		Name = "Tower",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(towerHeight, 8, 8),
		CFrame = CFrame.new(center + Vector3.new(0, towerHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(235, 230, 245),
		Parent = folder,
	})
	for y = 10, towerHeight - 4, 12 do
		Builder.Part({
			Name = "TowerRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 8.6, 8.6),
			CFrame = CFrame.new(center + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(170, 100, 255),
			Parent = folder,
		})
	end

	-- Startbord
	local signPost = Builder.Part({
		Name = "TowerSign",
		Size = Vector3.new(10, 4, 0.6),
		CFrame = CFrame.lookAt(center * (1 - 15 / center.Magnitude) + Vector3.new(0, 4, 0), Vector3.new(0, 4, 0)),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(150, 100, 65),
		Parent = folder,
	})
	Builder.Billboard(signPost, "🗼 AURA TOWER OBBY\nReward at the top!", UDim2.new(14, 0, 3.4, 0), Vector3.new(0, 4.5, 0), Color3.fromRGB(255, 225, 120))

	-- Platforms in een spiraal, in regenboogkleuren. Elk 5e platform is kleiner (lastiger).
	for index = 1, PLATFORMS do
		local degrees = 180 + index * STEP_DEGREES
		local a = math.rad(degrees)
		local position = center + Vector3.new(math.cos(a) * SPIRAL_RADIUS, index * RISE, math.sin(a) * SPIRAL_RADIUS)
		local size = if index % 5 == 0 then 3 else 4.5
		local color = Color3.fromHSV((index / PLATFORMS) * 0.8, 0.65, 1)
		Builder.Part({
			Name = "ObbyPlatform",
			Size = Vector3.new(size, 1, size),
			CFrame = CFrame.new(position) * CFrame.Angles(0, -a, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = color,
			Parent = folder,
		})
		Builder.Part({
			Name = "ObbyGlow",
			Size = Vector3.new(size + 0.3, 0.3, size + 0.3),
			CFrame = CFrame.new(position - Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, -a, 0),
			Material = Enum.Material.Neon,
			Color = color,
			CanCollide = false,
			Parent = folder,
		})
	end

	-- Bovenkant met het beloningskristal
	local topY = towerHeight + 0.5
	Builder.Part({
		Name = "TowerTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 14, 14),
		CFrame = CFrame.new(center + Vector3.new(0, topY, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(245, 240, 250),
		Parent = folder,
	})
	Builder.Part({
		Name = "TowerTopTrim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 14.6, 14.6),
		CFrame = CFrame.new(center + Vector3.new(0, topY - 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 205, 80),
		CanCollide = false,
		Parent = folder,
	})
	for _, degrees in { 45, 135, 225, 315 } do
		local a = math.rad(degrees)
		Decor.Flag(center + Vector3.new(math.cos(a) * 6, topY + 0.5, math.sin(a) * 6), 8, Color3.fromRGB(170, 100, 255), folder)
	end
	local crystal = Builder.Part({
		Name = "TowerCrystal",
		Size = Vector3.new(3, 5, 3),
		CFrame = CFrame.new(center + Vector3.new(0, topY + 4, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 215, 90),
		CanCollide = false,
		Parent = folder,
	})
	Decor.Animate(crystal, 70, 0.8)
	Builder.Sparkles(crystal, Color3.fromRGB(255, 235, 150), 30)
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 2.5
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Parent = crystal
	Builder.Billboard(crystal, "🏆 TOUCH FOR REWARD", UDim2.new(12, 0, 2.4, 0), Vector3.new(0, 5, 0), Color3.fromRGB(255, 235, 140))

	-- Grote aanraakzone rond het kristal (draaiende onderdelen raak je lastig)
	local zone = Builder.Part({
		Name = "RewardZone",
		Size = Vector3.new(6, 7, 6),
		CFrame = CFrame.new(center + Vector3.new(0, topY + 4, 0)),
		Transparency = 1,
		CanCollide = false,
		Parent = folder,
	})
	zone.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		if now - (touchedAt[player] or 0) < 3 then
			return
		end
		touchedAt[player] = now
		claim(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		touchedAt[player] = nil
	end)
end

return ObbyService
