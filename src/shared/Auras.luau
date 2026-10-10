-- Alle aura's die je kunt rollen. Chance = "1 in X". Multiplier = hoeveel extra Aura je verdient.

local Auras = {}

Auras.List = {
	{ Name = "Basic Glow", Chance = 1, Multiplier = 1.1, Color = Color3.fromRGB(230, 230, 230) },
	{ Name = "-1000 Aura", Chance = 3, Multiplier = 1, Color = Color3.fromRGB(120, 120, 120) },
	{ Name = "Green Vibe", Chance = 4, Multiplier = 1.2, Color = Color3.fromRGB(90, 255, 120) },
	{ Name = "Blue Chill", Chance = 8, Multiplier = 1.35, Color = Color3.fromRGB(80, 170, 255) },
	{ Name = "Purple Mystery", Chance = 16, Multiplier = 1.5, Color = Color3.fromRGB(170, 90, 255) },
	{ Name = "Pink Rizz", Chance = 32, Multiplier = 1.75, Color = Color3.fromRGB(255, 110, 200) },
	{ Name = "Golden Drip", Chance = 64, Multiplier = 2, Color = Color3.fromRGB(255, 205, 50) },
	{ Name = "Red Rage", Chance = 128, Multiplier = 2.5, Color = Color3.fromRGB(255, 50, 50) },
	{ Name = "Rainbow Rizz", Chance = 300, Multiplier = 3.5, Color = Color3.fromRGB(255, 255, 255), Rainbow = true },
	{ Name = "Main Character", Chance = 1000, Multiplier = 5, Color = Color3.fromRGB(255, 240, 150) },
	{ Name = "Galaxy Sigma", Chance = 2500, Multiplier = 7, Color = Color3.fromRGB(110, 60, 255) },
	{ Name = "Void Aura", Chance = 10000, Multiplier = 12, Color = Color3.fromRGB(25, 0, 40) },
}

Auras.ByName = {}
for index, aura in Auras.List do
	aura.Index = index
	Auras.ByName[aura.Name] = aura
end

-- Rol een aura: begin bij de zeldzaamste en probeer elke kans. Lukt niets, dan krijg je Basic Glow.
function Auras.Roll(luck: number?, rng: Random?)
	local useLuck = luck or 1
	local random = rng or Random.new()
	for index = #Auras.List, 2, -1 do
		local aura = Auras.List[index]
		if random:NextNumber() < useLuck / aura.Chance then
			return aura
		end
	end
	return Auras.List[1]
end

function Auras.RarityText(aura): string
	if aura.Chance <= 1 then
		return "Common"
	end
	return "1 in " .. tostring(aura.Chance)
end

return Auras
