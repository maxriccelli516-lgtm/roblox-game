-- Bouwt de wereld: gras en water (Terrain), heuvels, een bos, het grote plein met de Aura Battle Arena,
-- het Aura Altaar, standbeelden, een fontein, stenen paden met lantaarns naar elk plot, en zonnig daglicht.
-- Onder paden, plein en plots zetten we de Terrain op steen, anders groeit het gras er dwars doorheen.
-- MapBuilder.Spots vertelt andere services waar dingen staan (battle plekken, standbeelden, borden, obby).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Builder = require(script.Parent.Builder)
local Decor = require(script.Parent.Decor)

local MapBuilder = {}

local WORLD_SIZE = 1400
local PLAZA_RADIUS = 62
local ARENA_RADIUS = 28
local POND_DISTANCE = 100
local POND_RADIUS = 15
local OBBY_ANGLE = 210 -- graden, op de plek van een vijver
local OBBY_DISTANCE = 100

-- Richting op de kaart: 0 graden = +X (plot 1), 90 graden = +Z
local function dir(degrees: number): Vector3
	local a = math.rad(degrees)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

-- Kijkt vanaf een plek op het plein naar het midden
local function facingCenter(degrees: number, distance: number, y: number?): CFrame
	local position = dir(degrees) * distance + Vector3.new(0, y or 0, 0)
	return CFrame.lookAt(position, Vector3.new(0, y or 0, 0))
end

MapBuilder.Spots = {
	-- Twee battle podia in de arena, elk met twee plekken tegenover elkaar
	Stages = {
		{ A = Vector3.new(-11, 1.6, -9), B = Vector3.new(11, 1.6, -9) },
		{ A = Vector3.new(-11, 1.6, 9), B = Vector3.new(11, 1.6, 9) },
	},
	TopFarmerStatue = facingCenter(30, 50),
	ChampionStatue = facingCenter(150, 50),
	Boards = {
		Battle = facingCenter(221, 54, 12),
		Aura = facingCenter(257, 54, 12),
		Level = facingCenter(283, 54, 12),
	},
	Obby = dir(OBBY_ANGLE) * OBBY_DISTANCE,
}

-- Vijvers tussen de paden (behalve waar de obby staat)
local function pondCenters(): { Vector3 }
	local ponds = {}
	for index = 1, Config.PlotCount do
		local degrees = (index - 0.5) / Config.PlotCount * 360
		if math.abs(degrees - OBBY_ANGLE) > 1 then
			table.insert(ponds, dir(degrees) * POND_DISTANCE)
		end
	end
	return ponds
end

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

-- Is deze plek vrij van plots, paden, vijvers, de obby en het plein?
local function plotCenters(): { Vector3 }
	local centers = {}
	for index = 1, Config.PlotCount do
		local angle = (index - 1) / Config.PlotCount * math.pi * 2
		table.insert(centers, Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.PlotRadius)
	end
	return centers
end

local function isFree(position: Vector3, centers: { Vector3 }, margin: number): boolean
	if position.Magnitude < PLAZA_RADIUS + 3 + margin then
		return false
	end
	for _, pond in pondCenters() do
		if (position - pond).Magnitude < POND_RADIUS + 6 + margin then
			return false
		end
	end
	if (position - MapBuilder.Spots.Obby).Magnitude < 18 + margin then
		return false
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
	terrain.WaterColor = Color3.fromRGB(30, 140, 210)
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 10
	terrain.WaterReflectance = 0.25
	terrain.WaterTransparency = 0.5

	-- Steen onder het plein, de paden, de plots en de obby: daar groeit geen gras doorheen
	terrain:FillCylinder(CFrame.new(0, -2, 0), 4, PLAZA_RADIUS + 3, Enum.Material.Pavement)
	local pathStart = PLAZA_RADIUS - 2
	local pathEnd = Config.PlotRadius - Config.PlotSize / 2 + 2
	for _, center in centers do
		local direction = center.Unit
		local middle = direction * (pathStart + pathEnd) / 2
		terrain:FillBlock(CFrame.lookAt(middle + Vector3.new(0, -2, 0), middle + direction + Vector3.new(0, -2, 0)), Vector3.new(18, 4, pathEnd - pathStart + 4), Enum.Material.Pavement)
		terrain:FillBlock(CFrame.lookAt(center + Vector3.new(0, -2, 0), Vector3.new(0, -2, 0)), Vector3.new(Config.PlotSize + 6, 4, Config.PlotSize + 6), Enum.Material.Concrete)
	end
	terrain:FillCylinder(CFrame.new(MapBuilder.Spots.Obby + Vector3.new(0, -2, 0)), 4, 16, Enum.Material.Pavement)

	-- Vijvers tussen de paden, met een zandrand
	for _, center in pondCenters() do
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -2, 0)), 4, POND_RADIUS + 4, Enum.Material.Sand)
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -3, 0)), 6, POND_RADIUS, Enum.Material.Water)
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

	-- Bomen, struiken, bloemen en stenen rond de vijvers, plus een steigertje
	for index, pond in pondCenters() do
		for step = 1, 8 do
			local a = step / 8 * math.pi * 2 + index
			local spot = pond + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(POND_RADIUS + 6, POND_RADIUS + 9)
			if isFree(spot, centers, -6) or (spot - pond).Magnitude < POND_RADIUS + 10 then
				if step % 4 == 0 then
					Decor.Tree(spot, rng:NextNumber(0.8, 1.1), nature)
				elseif step % 4 == 1 then
					Decor.Bush(spot, 1, nature)
				elseif step % 4 == 2 then
					Decor.Flowers(spot, nature, 6)
				else
					Decor.Rock(spot, rng:NextNumber(0.6, 1), nature)
				end
			end
		end
		local toCenter = -pond.Unit
		local dockStart = pond + toCenter * (POND_RADIUS + 3)
		local dockCf = CFrame.lookAt(dockStart, pond) * CFrame.new(0, 0.6, -5)
		Builder.Part({ Name = "Dock", Size = Vector3.new(5, 0.5, 12), CFrame = dockCf, Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 105, 70), Parent = nature })
		for _, x in { -2.2, 2.2 } do
			Builder.Part({ Name = "DockPost", Size = Vector3.new(0.6, 3, 0.6), CFrame = dockCf * CFrame.new(x, -0.6, -5.4), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 75, 50), Parent = nature })
		end
	end

	-- Losse bloemen en struiken in het gras
	for _ = 1, 160 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(70, 330)
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

local function disc(name: string, center: Vector3, radius: number, height: number, material: Enum.Material, color: Color3, parent: Instance, props: { [string]: any }?)
	local part = Builder.Part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Material = material,
		Color = color,
		Parent = parent,
	})
	if props then
		for key, value in props do
			(part :: any)[key] = value
		end
	end
	return part
end

-- Aura Altaar: trapjes, pilaren en een zwevend, draaiend kristal (hier rol je aura's)
local function buildAltar(center: Vector3, parent: Instance)
	local scale = 0.75
	local steps = {
		{ 13, 1.2, 1.6 },
		{ 10, 1.2, 2.8 },
		{ 7.5, 1.2, 4 },
	}
	local altarBase = nil
	for _, step in steps do
		altarBase = disc("AltarStep", center + Vector3.new(0, step[3], 0), step[1] * scale, step[2], Enum.Material.Marble, Color3.fromRGB(245, 243, 250), parent)
	end
	for index = 1, 4 do
		local angle = (index - 0.5) / 4 * math.pi * 2
		local spot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 11 * scale
		disc("Pillar", spot + Vector3.new(0, 9, 0), 1, 14, Enum.Material.Marble, Color3.fromRGB(245, 243, 250), parent)
		local orb = Builder.Part({
			Name = "PillarOrb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.4,
			CFrame = CFrame.new(spot + Vector3.new(0, 17.4, 0)),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(200, 140, 255),
			CanCollide = false,
			Parent = parent,
		})
		Decor.Animate(orb, nil, 0.5)
	end
	local ring = Builder.Part({
		Name = "AltarRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 12, 12),
		CFrame = CFrame.new(center + Vector3.new(0, 11, 0)) * CFrame.Angles(math.rad(20), 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 210, 90),
		Transparency = 0.55,
		CanCollide = false,
		Parent = parent,
	})
	Decor.Animate(ring, 40, nil, 0.2)
	local crystal = Builder.Part({
		Name = "AuraCrystal",
		Size = Vector3.new(3.5, 7, 3.5),
		CFrame = CFrame.new(center + Vector3.new(0, 11, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(190, 120, 255),
		CanCollide = false,
		Parent = parent,
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

-- De Aura Battle Arena in het midden: verhoogde vloer met gloeiende rand, tribunes,
-- lichtmasten met schijnwerpers en een groot zwevend bord
local function buildArena(parent: Instance)
	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = parent
	local purple = Color3.fromRGB(150, 80, 255)
	local gold = Color3.fromRGB(255, 205, 80)

	disc("ArenaGlow", Vector3.new(0, 0.7, 0), ARENA_RADIUS + 0.6, 1.4, Enum.Material.Neon, purple, arena)
	disc("ArenaFloor", Vector3.new(0, 0.8, 0), ARENA_RADIUS, 1.6, Enum.Material.Slate, Color3.fromRGB(60, 50, 80), arena)
	disc("ArenaInner", Vector3.new(0, 1.62, 0), ARENA_RADIUS - 3, 0.05, Enum.Material.Marble, Color3.fromRGB(235, 230, 245), arena)
	disc("ArenaRing", Vector3.new(0, 1.66, 0), 7, 0.05, Enum.Material.Neon, gold, arena)
	disc("ArenaCore", Vector3.new(0, 1.68, 0), 6.2, 0.05, Enum.Material.Marble, Color3.fromRGB(70, 40, 120), arena)
	-- Lijnen tussen de battle plekken
	for _, z in { -9, 9 } do
		Builder.Part({ Name = "BattleLane", Size = Vector3.new(20, 0.05, 1), CFrame = CFrame.new(0, 1.66, z), Material = Enum.Material.Neon, Color = purple, Transparency = 0.3, Parent = arena })
	end

	-- Opstapjes rondom (zodat je makkelijk de arena op loopt)
	for index = 0, 11 do
		local degrees = index * 30
		local cf = facingCenter(degrees, ARENA_RADIUS + 1.6, 0.4)
		Builder.Part({ Name = "ArenaStep", Size = Vector3.new(6, 0.8, 2.4), CFrame = cf, Material = Enum.Material.Marble, Color = Color3.fromRGB(235, 230, 245), Parent = arena })
	end

	-- Tribunes: 6 stukken met openingen ertussen, 3 rijen hoog
	local rows = { { 32, 1.2 }, { 34.5, 2.4 }, { 37, 3.6 } }
	for sector = 0, 5 do
		local middle = 30 + sector * 60
		for step = -3, 3 do
			local degrees = middle + step * 6.5
			for rowIndex, row in rows do
				local cf = facingCenter(degrees, row[1], row[2] / 2)
				local width = row[1] * math.rad(6.5) + 0.2
				Builder.Part({
					Name = "Tribune",
					Size = Vector3.new(width, row[2], 2.5),
					CFrame = cf,
					Material = Enum.Material.Concrete,
					Color = Color3.fromRGB(215, 210, 225),
					Parent = arena,
				})
				Builder.Part({
					Name = "Seat",
					Size = Vector3.new(width - 0.6, 0.3, 1.6),
					CFrame = cf * CFrame.new(0, row[2] / 2 + 0.15, 0.2),
					Material = Enum.Material.SmoothPlastic,
					Color = if (step + rowIndex) % 2 == 0 then purple else Color3.fromRGB(255, 120, 200),
					Parent = arena,
				})
			end
		end
		-- Lichtmast met schijnwerper achter elke tribune (niet bij het altaar)
		if middle == 90 then
			continue
		end
		local mast = facingCenter(middle, 40.5)
		disc("LightMast", mast.Position + Vector3.new(0, 12, 0), 0.7, 24, Enum.Material.Metal, Color3.fromRGB(60, 60, 70), arena)
		local lamp = Builder.Part({
			Name = "Floodlight",
			Size = Vector3.new(4, 2.4, 1.2),
			CFrame = mast * CFrame.new(0, 24, 0) * CFrame.Angles(math.rad(-35), 0, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 250, 230),
			CanCollide = false,
			Parent = arena,
		})
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = 60
		spot.Range = 60
		spot.Brightness = 2
		spot.Color = Color3.fromRGB(255, 240, 220)
		spot.Parent = lamp
		local flag = Decor.Flag(mast.Position + mast.RightVector * 3, 16, if sector % 2 == 0 then purple else gold, arena)
		Decor.Animate(flag, nil, 0.3)
	end

	-- Zwevend bord met draaiende ring
	local sign = Builder.Part({
		Name = "ArenaSign",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 30, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = arena,
	})
	local label = Builder.Billboard(sign, "⚔️ AURA BATTLE ARENA ⚔️", UDim2.new(40, 0, 6, 0), Vector3.zero, Color3.fromRGB(255, 220, 110))
	local gui = label.Parent :: BillboardGui
	gui.MaxDistance = 400
	local ring = Builder.Part({
		Name = "ArenaHalo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 26, 26),
		CFrame = CFrame.new(0, 26, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = purple,
		Transparency = 0.5,
		CanCollide = false,
		Parent = arena,
	})
	Decor.Animate(ring, 25, 1, 0.2)
	local crystal = Builder.Part({
		Name = "ArenaCrystal",
		Size = Vector3.new(3, 6, 3),
		CFrame = CFrame.new(0, 22, 0) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = gold,
		CanCollide = false,
		Parent = arena,
	})
	Decor.Animate(crystal, 50, 1.5)
	Builder.Sparkles(crystal, gold, 20)
end

local function buildPlaza(map: Instance)
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = map

	-- Bestrating met een sierrand en een marmeren wandelring
	disc("PlazaEdge", Vector3.new(0, 0.3, 0), PLAZA_RADIUS + 1.5, 0.6, Enum.Material.Concrete, Color3.fromRGB(150, 150, 155), plaza)
	disc("Plaza", Vector3.new(0, 0.35, 0), PLAZA_RADIUS, 0.7, Enum.Material.Cobblestone, Color3.fromRGB(205, 195, 180), plaza)
	disc("PlazaRingOuter", Vector3.new(0, 0.72, 0), 46, 0.05, Enum.Material.Marble, Color3.fromRGB(240, 236, 228), plaza)
	disc("PlazaRingInner", Vector3.new(0, 0.74, 0), 43.5, 0.05, Enum.Material.Cobblestone, Color3.fromRGB(190, 175, 160), plaza)

	buildArena(plaza)
	buildAltar(dir(90) * 48.5, plaza)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.lookAt(dir(270) * 48 + Vector3.new(0, 0.9, 0), Vector3.new(0, 0.9, 0))
	spawn.Material = Enum.Material.Marble
	spawn.Color = Color3.fromRGB(240, 238, 235)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Parent = plaza
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- Klassieke standbeelden van de bekendste aura farm poses
	Decor.Statue(facingCenter(200, 50), { Right = { 110, 25 }, Left = { 40, 35 } }, 2.2, Color3.fromRGB(240, 238, 235), Enum.Material.Marble, "THE BOAT KID", plaza)
	Decor.Statue(facingCenter(341, 50), { Right = { 175, 5 }, Left = { -10, 30 } }, 2.2, Color3.fromRGB(255, 200, 70), Enum.Material.Foil, "THE SKY POINTER", plaza)
	Decor.Fountain(dir(319) * 50, 5.5, plaza)

	-- Lantaarns en vlaggen bij elke ingang van het plein
	for index = 1, Config.PlotCount do
		local degrees = (index - 1) / Config.PlotCount * 360
		local direction = dir(degrees)
		local side = Vector3.new(-direction.Z, 0, direction.X)
		for _, s in { -1, 1 } do
			Decor.Lamp(direction * (PLAZA_RADIUS - 1) + side * s * 9 + Vector3.new(0, 0.7, 0), plaza)
		end
	end

	-- Heggetjes langs de rand van het plein, met openingen bij de paden
	for index = 1, Config.PlotCount do
		local from = (index - 1) / Config.PlotCount * 360 + 11
		local to = index / Config.PlotCount * 360 - 11
		local pieces = 7
		for step = 0, pieces - 1 do
			local a = dir(from + (to - from) * step / pieces) * (PLAZA_RADIUS - 1.5)
			local b = dir(from + (to - from) * (step + 0.92) / pieces) * (PLAZA_RADIUS - 1.5)
			Decor.Hedge(a + Vector3.new(0, 0.7, 0), b + Vector3.new(0, 0.7, 0), plaza)
		end
	end
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
		Builder.Part({
			Name = "PathStripe",
			Size = Vector3.new(3, 0.42, length),
			CFrame = cf,
			Material = Enum.Material.Cobblestone,
			Color = Color3.fromRGB(215, 205, 190),
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
		-- Lantaarns, struikjes en bankjes langs het pad
		local count = math.floor(length / 18)
		for step = 1, count do
			local side = if step % 2 == 0 then 1 else -1
			local z = -length / 2 + step * (length / (count + 1))
			Decor.Lamp((cf * CFrame.new(side * 10, -0.2, z)).Position, paths)
			Decor.Bush((cf * CFrame.new(-side * 10.5, -0.2, z)).Position, 0.7, paths)
			if step % 2 == 1 then
				Decor.Bench(cf * CFrame.new(side * 10, -0.2, z + 6) * CFrame.Angles(0, math.rad(90 * side), 0), paths)
			end
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
