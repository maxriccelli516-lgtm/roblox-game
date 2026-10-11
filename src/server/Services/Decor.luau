-- Decoratie die overal in de wereld gebruikt wordt: bomen, struiken, bloemen, lantaarns, bankjes en hekjes.
-- Animaties: geef een onderdeel de tag "Fx" met attributen Spin (graden per seconde), Bob (studs op en neer)
-- of Pulse (hoeveel de doorzichtigheid knippert). De speler zijn computer laat ze dan soepel bewegen.

local CollectionService = game:GetService("CollectionService")

local Builder = require(script.Parent.Builder)

local Decor = {}

local LEAVES = {
	Color3.fromRGB(75, 151, 75),
	Color3.fromRGB(58, 125, 21),
	Color3.fromRGB(96, 165, 70),
	Color3.fromRGB(45, 120, 60),
}
local PINE = Color3.fromRGB(40, 100, 55)
local TRUNK = Color3.fromRGB(105, 70, 45)
local FLOWERS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(180, 120, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 150, 60),
	Color3.fromRGB(110, 180, 255),
}
local METAL = Color3.fromRGB(45, 45, 55)

local rng = Random.new(67)

-- Animatie aanzetten voor een onderdeel (zie uitleg bovenaan)
function Decor.Animate(part: BasePart, spin: number?, bob: number?, pulse: number?)
	if spin then
		part:SetAttribute("Spin", spin)
	end
	if bob then
		part:SetAttribute("Bob", bob)
	end
	if pulse then
		part:SetAttribute("Pulse", pulse)
	end
	CollectionService:AddTag(part, "Fx")
end

local function vertical(position: Vector3): CFrame
	return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

-- Ronde boom met een paar bollen bladeren
function Decor.Tree(position: Vector3, scale: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = 9 * scale
	Builder.Part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.8 * scale, 1.8 * scale),
		CFrame = vertical(position + Vector3.new(0, height / 2, 0)),
		Material = Enum.Material.Wood,
		Color = TRUNK,
		Parent = model,
	})
	local leaf = LEAVES[rng:NextInteger(1, #LEAVES)]
	local blobs = {
		{ Vector3.new(0, height + 2, 0), 8 },
		{ Vector3.new(2.6, height, 0.8), 6 },
		{ Vector3.new(-2.2, height + 0.6, -1.6), 6 },
		{ Vector3.new(0.4, height - 0.2, 2.4), 5.5 },
	}
	for _, blob in blobs do
		Builder.Part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * blob[2] * scale,
			CFrame = CFrame.new(position + blob[1] * scale),
			Material = Enum.Material.Grass,
			Color = leaf,
			CanCollide = false,
			Parent = model,
		})
	end
	model.Parent = parent
	return model
end

-- Dennenboom van gestapelde schijven
function Decor.Pine(position: Vector3, scale: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Pine"
	Builder.Part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5 * scale, 1.4 * scale, 1.4 * scale),
		CFrame = vertical(position + Vector3.new(0, 2.5 * scale, 0)),
		Material = Enum.Material.Wood,
		Color = TRUNK,
		Parent = model,
	})
	local layers = { 9, 7.2, 5.4, 3.6, 1.8 }
	for index, width in layers do
		Builder.Part({
			Name = "Needles",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.6 * scale, width * scale, width * scale),
			CFrame = vertical(position + Vector3.new(0, (3.5 + index * 2.4) * scale, 0)),
			Material = Enum.Material.Grass,
			Color = PINE:Lerp(Color3.fromRGB(70, 140, 80), index / #layers),
			CanCollide = index == 1,
			Parent = model,
		})
	end
	model.Parent = parent
	return model
end

function Decor.Bush(position: Vector3, scale: number, parent: Instance)
	local leaf = LEAVES[rng:NextInteger(1, #LEAVES)]
	for _, offset in { Vector3.new(0, 1.4, 0), Vector3.new(1.6, 1, 0.5), Vector3.new(-1.4, 1, -0.6) } do
		Builder.Part({
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 3.4 * scale,
			CFrame = CFrame.new(position + offset * scale),
			Material = Enum.Material.Grass,
			Color = leaf,
			CanCollide = false,
			Parent = parent,
		})
	end
end

function Decor.Rock(position: Vector3, scale: number, parent: Instance)
	Builder.Part({
		Name = "Rock",
		Size = Vector3.new(4, 2.6, 3.4) * scale,
		CFrame = CFrame.new(position + Vector3.new(0, 0.8 * scale, 0))
			* CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-15, 15))),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(130, 130, 135),
		Parent = parent,
	})
end

-- Een plukje bloemen
function Decor.Flowers(position: Vector3, parent: Instance, count: number?)
	for _ = 1, count or 5 do
		local spot = position + Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8))
		Builder.Part({
			Name = "Stem",
			Size = Vector3.new(0.2, 1.2, 0.2),
			CFrame = CFrame.new(spot + Vector3.new(0, 0.6, 0)),
			Color = Color3.fromRGB(60, 140, 60),
			CanCollide = false,
			CanQuery = false,
			Parent = parent,
		})
		Builder.Part({
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.8,
			CFrame = CFrame.new(spot + Vector3.new(0, 1.3, 0)),
			Color = FLOWERS[rng:NextInteger(1, #FLOWERS)],
			CanCollide = false,
			CanQuery = false,
			Parent = parent,
		})
	end
end

-- Bloembak van hout met bloemen erin
function Decor.Planter(cf: CFrame, length: number, parent: Instance)
	Builder.Part({ Name = "Planter", Size = Vector3.new(length, 1.6, 4), CFrame = cf * CFrame.new(0, 0.8, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 100, 65), Parent = parent })
	Builder.Part({ Name = "Soil", Size = Vector3.new(length - 0.6, 0.2, 3.4), CFrame = cf * CFrame.new(0, 1.65, 0), Material = Enum.Material.Ground, Color = Color3.fromRGB(90, 65, 45), Parent = parent })
	for x = -length / 2 + 2, length / 2 - 2, 3.5 do
		Decor.Flowers((cf * CFrame.new(x, 1.6, 0)).Position, parent, 3)
	end
end

-- Straatlantaarn met warm licht
function Decor.Lamp(position: Vector3, parent: Instance, glow: Color3?)
	Builder.Part({
		Name = "LampPost",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(11, 0.8, 0.8),
		CFrame = vertical(position + Vector3.new(0, 5.5, 0)),
		Material = Enum.Material.Metal,
		Color = METAL,
		Parent = parent,
	})
	Builder.Part({ Name = "LampFoot", Size = Vector3.new(1.8, 0.8, 1.8), CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0)), Material = Enum.Material.Metal, Color = METAL, Parent = parent })
	Builder.Part({ Name = "LampCap", Size = Vector3.new(2, 0.4, 2), CFrame = CFrame.new(position + Vector3.new(0, 12.7, 0)), Material = Enum.Material.Metal, Color = METAL, Parent = parent })
	local bulb = Builder.Part({
		Name = "Lantern",
		Size = Vector3.new(1.5, 1.6, 1.5),
		CFrame = CFrame.new(position + Vector3.new(0, 11.7, 0)),
		Material = Enum.Material.Neon,
		Color = glow or Color3.fromRGB(255, 225, 160),
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = glow or Color3.fromRGB(255, 210, 150)
	light.Parent = bulb
	return bulb
end

-- Bankje. cf kijkt de kant op waar je naar kijkt als je zit.
function Decor.Bench(cf: CFrame, parent: Instance)
	local wood = Color3.fromRGB(160, 105, 60)
	Builder.Part({ Name = "BenchSeat", Size = Vector3.new(6, 0.4, 2), CFrame = cf * CFrame.new(0, 1.6, 0), Material = Enum.Material.WoodPlanks, Color = wood, Parent = parent })
	Builder.Part({ Name = "BenchBack", Size = Vector3.new(6, 1.6, 0.3), CFrame = cf * CFrame.new(0, 2.8, 0.9) * CFrame.Angles(math.rad(-10), 0, 0), Material = Enum.Material.WoodPlanks, Color = wood, Parent = parent })
	for _, x in { -2.5, 2.5 } do
		Builder.Part({ Name = "BenchLeg", Size = Vector3.new(0.4, 1.6, 2), CFrame = cf * CFrame.new(x, 0.8, 0), Material = Enum.Material.Metal, Color = METAL, Parent = parent })
	end
end

-- Wit houten hekje van a naar b
function Decor.Fence(a: Vector3, b: Vector3, parent: Instance, color: Color3?)
	local white = color or Color3.fromRGB(245, 245, 240)
	local length = (b - a).Magnitude
	local middle = (a + b) / 2
	local cf = CFrame.lookAt(middle, b)
	for _, y in { 1.4, 2.8 } do
		Builder.Part({ Name = "Rail", Size = Vector3.new(0.3, 0.4, length), CFrame = cf + Vector3.new(0, y, 0), Material = Enum.Material.Wood, Color = white, Parent = parent })
	end
	local posts = math.max(1, math.floor(length / 5))
	for index = 0, posts do
		local spot = a:Lerp(b, index / posts)
		Builder.Part({ Name = "FencePost", Size = Vector3.new(0.6, 3.6, 0.6), CFrame = CFrame.lookAt(spot, spot + cf.LookVector) + Vector3.new(0, 1.8, 0), Material = Enum.Material.Wood, Color = white, Parent = parent })
	end
end

-- Fontein met spuitend water
function Decor.Fountain(position: Vector3, radius: number, parent: Instance)
	Builder.Part({
		Name = "FountainRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, radius * 2, radius * 2),
		CFrame = vertical(position + Vector3.new(0, 0.8, 0)),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(235, 235, 240),
		Parent = parent,
	})
	Builder.Part({
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2 - 1.6, radius * 2 - 1.6),
		CFrame = vertical(position + Vector3.new(0, 1.55, 0)),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(80, 170, 255),
		Transparency = 0.3,
		CanCollide = false,
		Parent = parent,
	})
	local spout = Builder.Part({
		Name = "FountainSpout",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 1.2, 1.2),
		CFrame = vertical(position + Vector3.new(0, 3, 0)),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(235, 235, 240),
		Parent = parent,
	})
	local water = Instance.new("ParticleEmitter")
	water.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	water.Color = ColorSequence.new(Color3.fromRGB(170, 220, 255))
	water.LightEmission = 0.4
	water.Rate = 60
	water.Lifetime = NumberRange.new(1, 1.3)
	water.Speed = NumberRange.new(12, 14)
	water.SpreadAngle = Vector2.new(12, 12)
	water.Acceleration = Vector3.new(0, -25, 0)
	water.EmissionDirection = Enum.NormalId.Right
	water.Size = NumberSequence.new(0.5, 0.2)
	water.Parent = spout
end

return Decor
