-- Bouwt de wereld: gras en water (Terrain), heuvels, een bos, het plein met het Aura Altaar,
-- paden met lantaarns naar elk plot, en zonnig daglicht.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Builder = require(script.Parent.Builder)
local Decor = require(script.Parent.Decor)

local MapBuilder = {}

local WORLD_SIZE = 1400
local PLAZA_RADIUS = 34

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(95, 95, 105)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(200, 220, 255)
	atmosphere.Decay = Color3.fromRGB(110, 130, 170)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 2
	bloom.Parent = Lighting

	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.12
	color.Contrast = 0.06
	color.Brightness = 0.02
	color.TintColor = Color3.new(1, 1, 1)
	color.Parent = Lighting

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
end

-- Is deze plek vrij van plots, paden en het plein?
local function plotCenters(): { Vector3 }
	local centers = {}
	for index = 1, Config.PlotCount do
		local angle = (index - 1) / Config.PlotCount * math.pi * 2
		table.insert(centers, Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.PlotRadius)
	end
	return centers
end

local function isFree(position: Vector3, centers: { Vector3 }, margin: number): boolean
	if position.Magnitude < PLAZA_RADIUS + margin then
		return false
	end
	-- vijvers
	for index = 1, Config.PlotCount do
		local angle = (index - 0.5) / Config.PlotCount * math.pi * 2
		if (position - Vector3.new(math.cos(angle), 0, math.sin(angle)) * 80).Magnitude < 20 + margin then
			return false
		end
	end
	for _, center in centers do
		if (position - center).Magnitude < Config.PlotSize * 0.75 + margin then
			return false
		end
		-- pad van het plein naar dit plot
		local direction = center.Unit
		local along = position:Dot(direction)
		if along > 0 and along < Config.PlotRadius and (position - direction * along).Magnitude < 9 + margin then
			return false
		end
	end
	return true
end

local function buildTerrain(centers: { Vector3 })
	local terrain = workspace.Terrain
	terrain:Clear()
	-- Grond van gras, 12 studs dik, bovenkant op hoogte 0
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(WORLD_SIZE, 12, WORLD_SIZE), Enum.Material.Grass)
	pcall(function()
		(terrain :: any).Decoration = true -- wapperende grassprietjes
	end)
	terrain.WaterColor = Color3.fromRGB(40, 150, 210)
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 12
	terrain.WaterReflectance = 0.6
	terrain.WaterTransparency = 0.4

	-- Vijvers tussen de paden, met een zandrand
	for index = 1, Config.PlotCount do
		local angle = (index - 0.5) / Config.PlotCount * math.pi * 2
		local center = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 80
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -2, 0)), 4, 19, Enum.Material.Sand)
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -2, 0)), 4, 14, Enum.Material.Water)
	end

	-- Heuvels rondom de map
	local rng = Random.new(7)
	for index = 1, 22 do
		local angle = index / 22 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local distance = rng:NextNumber(540, 640)
		local radius = rng:NextNumber(55, 95)
		local center = Vector3.new(math.cos(angle) * distance, -radius * 0.45, math.sin(angle) * distance)
		terrain:FillBall(center, radius, Enum.Material.Grass)
		if rng:NextNumber() < 0.4 then
			terrain:FillBall(center + Vector3.new(0, radius * 0.5, 0), radius * 0.4, Enum.Material.Rock)
		end
	end
	return centers
end

local function buildNature(map: Instance, centers: { Vector3 })
	local nature = Instance.new("Folder")
	nature.Name = "Nature"
	nature.Parent = map
	local rng = Random.new(42)

	-- Bos rondom de plots
	local placed = 0
	local tries = 0
	while placed < 170 and tries < 2000 do
		tries += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(250, 440)
		local position = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		if isFree(position, centers, 6) then
			placed += 1
			local scale = rng:NextNumber(0.9, 1.6)
			if rng:NextNumber() < 0.45 then
				Decor.Pine(position, scale, nature)
			else
				Decor.Tree(position, scale, nature)
			end
			if rng:NextNumber() < 0.25 then
				Decor.Rock(position + Vector3.new(rng:NextNumber(5, 9), 0, rng:NextNumber(-4, 4)), rng:NextNumber(0.8, 1.6), nature)
			end
		end
	end

	-- Bomen, struiken en bloemen rond de vijvers
	for index = 1, Config.PlotCount do
		local angle = (index - 0.5) / Config.PlotCount * math.pi * 2
		local pond = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 80
		for step = 1, 7 do
			local a = step / 7 * math.pi * 2 + index
			local spot = pond + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(24, 28)
			if isFree(spot, centers, 1) then
				if step % 3 == 0 then
					Decor.Tree(spot, rng:NextNumber(0.8, 1.1), nature)
				elseif step % 3 == 1 then
					Decor.Bush(spot, 1, nature)
				else
					Decor.Flowers(spot, nature, 6)
				end
			end
		end
	end

	-- Losse bloemen en struiken in het gras
	for _ = 1, 140 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(45, 330)
		local position = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		if isFree(position, centers, 3) then
			if rng:NextNumber() < 0.7 then
				Decor.Flowers(position, nature, 4)
			else
				Decor.Bush(position, rng:NextNumber(0.7, 1.1), nature)
			end
		end
	end
end

local function buildPlaza(map: Instance)
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = map

	local function disc(name: string, radius: number, height: number, y: number, material: Enum.Material, color: Color3)
		return Builder.Part({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, radius * 2, radius * 2),
			CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Material = material,
			Color = color,
			Parent = plaza,
		})
	end
	disc("PlazaEdge", PLAZA_RADIUS + 1.5, 0.8, 0.4, Enum.Material.Concrete, Color3.fromRGB(150, 150, 155))
	disc("Plaza", PLAZA_RADIUS, 1, 0.5, Enum.Material.Cobblestone, Color3.fromRGB(205, 195, 180))
	disc("PlazaRing", 16, 1.1, 0.5, Enum.Material.Marble, Color3.fromRGB(240, 238, 235))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 1.1, -22)
	spawn.Material = Enum.Material.Marble
	spawn.Color = Color3.fromRGB(240, 238, 235)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Parent = plaza
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- Bloembakken en bankjes tussen de paden
	for index = 1, Config.PlotCount do
		local angle = (index - 0.5) / Config.PlotCount * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local spot = direction * (PLAZA_RADIUS - 4)
		-- Niet bij het leaderboard (links achter) en niet bij de spawn
		local nearBoard = (spot - Vector3.new(-22, 0, 14)).Magnitude < 14
		local nearSpawn = (spot - Vector3.new(0, 0, -22)).Magnitude < 10
		if not nearBoard and not nearSpawn then
			local cf = CFrame.lookAt(spot + Vector3.new(0, 1, 0), Vector3.new(0, 1, 0))
			Decor.Planter(cf, 12, plaza)
			Decor.Bench(cf * CFrame.new(0, 0, -4), plaza)
		end
	end
	for index = 1, Config.PlotCount do
		local angle = (index - 1) / Config.PlotCount * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local side = Vector3.new(-direction.Z, 0, direction.X)
		for _, s in { -1, 1 } do
			Decor.Lamp(direction * (PLAZA_RADIUS - 1) + side * s * 10 + Vector3.new(0, 1, 0), plaza)
		end
	end

	-- Aura Altaar: trapjes, pilaren en een zwevend, draaiend kristal
	local altarCenter = Vector3.new(0, 0, 6)
	local steps = {
		{ 13, 1.2, 1.6 },
		{ 10, 1.2, 2.8 },
		{ 7.5, 1.2, 4 },
	}
	local altarBase = nil
	for _, step in steps do
		altarBase = Builder.Part({
			Name = "AltarStep",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(step[2], step[1] * 2, step[1] * 2),
			CFrame = CFrame.new(altarCenter + Vector3.new(0, step[3], 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(245, 243, 250),
			Parent = plaza,
		})
	end
	for index = 1, 4 do
		local angle = (index - 0.5) / 4 * math.pi * 2
		local spot = altarCenter + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 11
		Builder.Part({
			Name = "Pillar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(14, 2, 2),
			CFrame = CFrame.new(spot + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(245, 243, 250),
			Parent = plaza,
		})
		local orb = Builder.Part({
			Name = "PillarOrb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.4,
			CFrame = CFrame.new(spot + Vector3.new(0, 17.4, 0)),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(200, 140, 255),
			CanCollide = false,
			Parent = plaza,
		})
		Decor.Animate(orb, nil, 0.5)
	end
	local ring = Builder.Part({
		Name = "AltarRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 12, 12),
		CFrame = CFrame.new(altarCenter + Vector3.new(0, 11, 0)) * CFrame.Angles(math.rad(20), 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 210, 90),
		Transparency = 0.55,
		CanCollide = false,
		Parent = plaza,
	})
	Decor.Animate(ring, 40, nil, 0.2)
	local crystal = Builder.Part({
		Name = "AuraCrystal",
		Size = Vector3.new(3.5, 7, 3.5),
		CFrame = CFrame.new(altarCenter + Vector3.new(0, 11, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(190, 120, 255),
		CanCollide = false,
		Parent = plaza,
	})
	Decor.Animate(crystal, 60, 1.2)
	Builder.Sparkles(crystal, Color3.fromRGB(230, 180, 255), 30)
	local light = Instance.new("PointLight")
	light.Range = 26
	light.Brightness = 2
	light.Color = Color3.fromRGB(200, 140, 255)
	light.Parent = crystal
	Builder.Billboard(crystal, "✨ ROLL AURA ✨", UDim2.new(14, 0, 3, 0), Vector3.new(0, 7, 0), Color3.fromRGB(255, 225, 120))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AuraAltarPrompt"
	prompt.ActionText = "Roll Aura"
	prompt.ObjectText = "Aura Altar"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = altarBase
end

local function buildPaths(map: Instance)
	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = map
	local pathStart = PLAZA_RADIUS - 1
	local pathEnd = Config.PlotRadius - Config.PlotSize / 2
	local length = pathEnd - pathStart
	for index = 1, Config.PlotCount do
		local angle = (index - 1) / Config.PlotCount * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local middle = direction * (pathStart + length / 2)
		local cf = CFrame.lookAt(middle + Vector3.new(0, 0.2, 0), middle + direction + Vector3.new(0, 0.2, 0))
		Builder.Part({
			Name = "Path",
			Size = Vector3.new(14, 0.4, length),
			CFrame = cf,
			Material = Enum.Material.Brick,
			Color = Color3.fromRGB(190, 160, 130),
			Parent = paths,
		})
		for _, side in { -1, 1 } do
			Builder.Part({
				Name = "Curb",
				Size = Vector3.new(1, 0.7, length),
				CFrame = cf * CFrame.new(side * 7.5, 0.15, 0),
				Material = Enum.Material.Concrete,
				Color = Color3.fromRGB(170, 170, 175),
				Parent = paths,
			})
		end
		-- Lantaarns en struikjes langs het pad
		local count = math.floor(length / 24)
		for step = 1, count do
			local side = if step % 2 == 0 then 1 else -1
			local spot = cf * CFrame.new(side * 10, -0.2, -length / 2 + step * (length / (count + 1)))
			Decor.Lamp(spot.Position, paths)
			Decor.Bush((cf * CFrame.new(-side * 10.5, -0.2, -length / 2 + step * (length / (count + 1)))).Position, 0.7, paths)
		end
	end
end

function MapBuilder.Build()
	-- Haal de standaard baseplate en spawn van een nieuwe Studio-place weg
	for _, name in { "Baseplate", "SpawnLocation" } do
		local existing = workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	setupLighting()

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	local centers = plotCenters()
	buildTerrain(centers)
	buildPlaza(map)
	buildPaths(map)
	buildNature(map, centers)

	return map
end

return MapBuilder
