-- Bouwt de wereld: grond, het plein in het midden met het Aura Altaar, paden en licht.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Builder = require(script.Parent.Builder)

local MapBuilder = {}

local function setupLighting()
	Lighting.ClockTime = 18.3
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(70, 60, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 100, 140)
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Color = Color3.fromRGB(200, 170, 255)
	atmosphere.Decay = Color3.fromRGB(120, 80, 160)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.5
	atmosphere.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 30
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.15
	color.Contrast = 0.05
	color.Parent = Lighting
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

	Builder.Part({
		Name = "Ground",
		Size = Vector3.new(900, 4, 900),
		CFrame = CFrame.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(70, 90, 75),
		Parent = map,
	})

	-- Plein in het midden
	Builder.Part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 64, 64),
		CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(225, 220, 240),
		Parent = map,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 1.2, -18)
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(150, 110, 255)
	spawn.Duration = 0
	spawn.Parent = map

	-- Aura Altaar: hier kun je aura's rollen
	local altarBase = Builder.Part({
		Name = "AltarBase",
		Size = Vector3.new(12, 3, 12),
		CFrame = CFrame.new(0, 2, 6),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(60, 40, 90),
		Parent = map,
	})
	local crystal = Builder.Part({
		Name = "AuraCrystal",
		Size = Vector3.new(4, 9, 4),
		CFrame = CFrame.new(0, 9, 6) * CFrame.Angles(0, math.rad(45), math.rad(15)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(190, 120, 255),
		CanCollide = false,
		Parent = map,
	})
	Builder.Sparkles(crystal, Color3.fromRGB(230, 180, 255), 40)
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 3
	light.Color = Color3.fromRGB(200, 140, 255)
	light.Parent = crystal
	Builder.Billboard(crystal, "✨ ROLL AURA ✨", UDim2.new(14, 0, 3, 0), Vector3.new(0, 7, 0), Color3.fromRGB(240, 210, 255))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AuraAltarPrompt"
	prompt.ActionText = "Roll Aura"
	prompt.ObjectText = "Aura Altar"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = altarBase

	-- Neon paden van het plein naar elk plot
	local pathStart = 32
	local pathEnd = Config.PlotRadius - Config.PlotSize / 2
	local length = pathEnd - pathStart
	for index = 1, Config.PlotCount do
		local angle = (index - 1) / Config.PlotCount * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local middle = direction * (pathStart + length / 2)
		local cf = CFrame.lookAt(middle + Vector3.new(0, 0.15, 0), middle + direction + Vector3.new(0, 0.15, 0))
		Builder.Part({
			Name = "Path",
			Size = Vector3.new(14, 0.3, length),
			CFrame = cf,
			Material = Enum.Material.Pavement,
			Color = Color3.fromRGB(90, 85, 110),
			Parent = map,
		})
		for _, side in { -1, 1 } do
			Builder.Part({
				Name = "PathGlow",
				Size = Vector3.new(0.6, 0.35, length),
				CFrame = cf * CFrame.new(side * 7, 0, 0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(170, 110, 255),
				CanCollide = false,
				Parent = map,
			})
		end
	end

	return map
end

return MapBuilder
