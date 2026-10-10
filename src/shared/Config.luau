-- Alle getallen van de game staan hier, zodat je de balans makkelijk kunt aanpassen.

local Config = {}

-- Speler start
Config.StartAura = 30

-- Plots (de tycoons van de spelers)
Config.PlotCount = 6
Config.PlotRadius = 170 -- afstand van het midden van de map tot een plot
Config.PlotSize = 110

-- Druppels (aura orbs)
Config.ConveyorSpeed = 10
Config.MaxOrbsPerPlot = 80
Config.OrbLifetime = 25

-- Lopende banden: Z-positie binnen het plot
Config.Lines = {
	[1] = { Z = 0 },
	[2] = { Z = 20 },
}

-- Rebirth
function Config.RebirthCost(rebirths: number): number
	return 500000 * 3 ^ rebirths
end

function Config.RebirthMultiplier(rebirths: number): number
	return 1 + 0.5 * rebirths
end

-- Aura rollen
Config.FreeRollCooldown = 45 -- seconden tussen gratis rolls
Config.RollCooldown = 1.3 -- minimale tijd tussen twee rolls (voor de animatie)
Config.AnnounceChance = 250 -- vanaf "1 in 250" krijgt de hele server een melding

function Config.RollCost(rebirths: number): number
	return 250 * (rebirths + 1) ^ 2
end

-- Bonussen
Config.PremiumBonus = 1.1 -- Roblox Premium spelers krijgen 10% extra
Config.OfflineRate = 0.25 -- je krijgt 25% van je inkomen terwijl je offline bent
Config.OfflineMaxSeconds = 4 * 60 * 60 -- maximaal 4 uur offline inkomen
Config.DailyCooldown = 20 * 60 * 60
Config.DailyStreakReset = 48 * 60 * 60

-- Codes: hoofdletters, waarde = hoeveel Aura je krijgt
Config.Codes = {
	AURAFARM = 500,
	["67"] = 670,
	SIGMA = 1000,
}

-- Gamepasses: vul hier het Id in nadat je ze op Roblox hebt aangemaakt (0 = staat uit)
Config.GamePasses = {
	DoubleAura = { Id = 0, Name = "2x Aura", Description = "Verdubbelt al je Aura voor altijd" },
	AutoCollect = { Id = 0, Name = "Auto Collect", Description = "Je Aura wordt vanzelf opgehaald" },
	FastDroppers = { Id = 0, Name = "Fast Generators", Description = "Je generators werken 25% sneller" },
}

-- Developer products (steeds opnieuw te kopen): geven X minuten van je inkomen
Config.DevProducts = {
	AuraPackSmall = { Id = 0, Name = "Aura Pack", Minutes = 10, Minimum = 1000 },
	AuraPackBig = { Id = 0, Name = "Mega Aura Pack", Minutes = 60, Minimum = 10000 },
}

-- Plekken voor de koopknoppen (lokale X, Z binnen het plot)
Config.ButtonSlots = {}
for _, z in { -14, -23, -32 } do
	for _, x in { -40, -28, -16, 16, 28, 40 } do
		table.insert(Config.ButtonSlots, Vector2.new(x, z))
	end
end

-- Alles wat je kunt kopen, in volgorde. Elk item verschijnt pas als het vorige is gekocht.
-- Types: Dropper (maakt orbs), Upgrader (maakt orbs meer waard), Line (extra lopende band), Decor (mooi)
Config.Items = {
	{ Id = "Dropper1", Name = "Aura Spark", Type = "Dropper", Price = 0, Line = 1, X = -32, Value = 2, Interval = 1.5, Color = Color3.fromRGB(235, 235, 255) },
	{ Id = "Dropper2", Name = "Chill Generator", Type = "Dropper", Price = 40, Line = 1, X = -24, Value = 4, Interval = 1.5, Color = Color3.fromRGB(120, 200, 255) },
	{ Id = "Walls", Name = "Glow Walls", Type = "Decor", Price = 120 },
	{ Id = "Dropper3", Name = "Vibe Generator", Type = "Dropper", Price = 250, Line = 1, X = -16, Value = 8, Interval = 1.5, Color = Color3.fromRGB(110, 255, 160) },
	{ Id = "Upgrader1", Name = "Aura Booster", Type = "Upgrader", Price = 600, Line = 1, X = 10, Multiplier = 1.5, Color = Color3.fromRGB(255, 220, 90) },
	{ Id = "Dropper4", Name = "Rizz Generator", Type = "Dropper", Price = 1200, Line = 1, X = -8, Value = 18, Interval = 1.5, Color = Color3.fromRGB(255, 120, 220) },
	{ Id = "Lamps", Name = "Aura Lamps", Type = "Decor", Price = 2000 },
	{ Id = "Dropper5", Name = "Drip Generator", Type = "Dropper", Price = 3500, Line = 1, X = 0, Value = 40, Interval = 1.5, Color = Color3.fromRGB(180, 110, 255) },
	{ Id = "Upgrader2", Name = "Sigma Gate", Type = "Upgrader", Price = 7000, Line = 1, X = 17, Multiplier = 2, Color = Color3.fromRGB(255, 150, 60) },
	{ Id = "Line2", Name = "Second Aura Line", Type = "Line", Price = 11000, Line = 2 },
	{ Id = "Dropper6", Name = "Main Character Generator", Type = "Dropper", Price = 16000, Line = 2, X = -32, Value = 70, Interval = 1.5, Color = Color3.fromRGB(90, 255, 255) },
	{ Id = "Dropper7", Name = "Goofy Generator", Type = "Dropper", Price = 26000, Line = 2, X = -22, Value = 120, Interval = 1.5, Color = Color3.fromRGB(255, 255, 120) },
	{ Id = "Upgrader3", Name = "Mega Booster", Type = "Upgrader", Price = 45000, Line = 2, X = 12, Multiplier = 2, Color = Color3.fromRGB(255, 80, 80) },
	{ Id = "Tower", Name = "Aura Tower", Type = "Decor", Price = 70000 },
	{ Id = "Dropper8", Name = "Galaxy Generator", Type = "Dropper", Price = 100000, Line = 2, X = -12, Value = 250, Interval = 1.5, Color = Color3.fromRGB(120, 90, 255) },
	{ Id = "Dropper9", Name = "Void Generator", Type = "Dropper", Price = 160000, Line = 2, X = -2, Value = 450, Interval = 1.5, Color = Color3.fromRGB(40, 20, 60) },
	{ Id = "Upgrader4", Name = "Ultra Aura Portal", Type = "Upgrader", Price = 240000, Line = 1, X = 24, Multiplier = 2, Color = Color3.fromRGB(80, 255, 120) },
	{ Id = "Throne", Name = "Aura Throne", Type = "Decor", Price = 350000 },
}

Config.ItemsById = {}
for index, item in Config.Items do
	item.Index = index
	item.Requires = if index > 1 then Config.Items[index - 1].Id else nil
	Config.ItemsById[item.Id] = item
end

assert(#Config.Items <= #Config.ButtonSlots, "Er zijn meer items dan knopplekken")

return Config
