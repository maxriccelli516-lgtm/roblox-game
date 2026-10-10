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
-- Order = volgorde in de shop
Config.GamePasses = {
	VIP = { Id = 0, Order = 1, Name = "VIP", Description = "+20% Aura, faster Aura Meter, 2 extra poses, VIP tag" },
	DoubleAura = { Id = 0, Order = 2, Name = "2x Aura", Description = "Double ALL your Aura forever" },
	AutoCollect = { Id = 0, Order = 3, Name = "Auto Collect", Description = "Your Aura is collected automatically" },
	FastDroppers = { Id = 0, Order = 4, Name = "Fast Generators", Description = "Your generators work 25% faster" },
}
Config.VipBonus = 1.2

-- Developer products (steeds opnieuw te kopen)
-- Kind: "Aura" = geeft X minuten van je inkomen (verborgen voor landen met loot box regels,
-- omdat je met Aura kunt rollen), "Boost" = tijdelijke 2x Aura, "Starter" = eenmalig startpakket
Config.DevProducts = {
	StarterPack = { Id = 0, Order = 1, Kind = "Starter", Name = "Starter Pack (one time)", Description = "30 min 2x Aura + exclusive Starter Spark aura", BoostMinutes = 30 },
	DoubleBoost = { Id = 0, Order = 2, Kind = "Boost", Name = "2x Aura Boost", Description = "Double Aura for 15 minutes (stacks)", BoostMinutes = 15 },
	AuraPackSmall = { Id = 0, Order = 3, Kind = "Aura", Name = "Aura Pack", Description = "10 minutes of your Aura income", Minutes = 10, Minimum = 1000 },
	AuraPackBig = { Id = 0, Order = 4, Kind = "Aura", Name = "Mega Aura Pack", Description = "60 minutes of your Aura income", Minutes = 60, Minimum = 10000 },
}

-- Aura farmen met poses (zoals de boat kid): stil staan in een pose vult je Aura Meter
Config.MeterFillSeconds = 30 -- zo lang poseren voor een volle meter
Config.PeakAuraSeconds = 45 -- zo lang duurt PEAK AURA
Config.PeakAuraMultiplier = 2
Config.Poses = {
	{ Id = "BoatKid", Name = "Boat Kid" },
	{ Id = "SkyPoint", Name = "Sky Point" },
	{ Id = "Sigma", Name = "Sigma Stare", Vip = true },
	{ Id = "Hero", Name = "Main Character", Vip = true },
}

-- Server events (zoals biomes in Sol's RNG): af en toe iets speciaals voor iedereen
Config.EventEvery = 8 * 60 -- seconden tussen events
Config.EventDuration = 2 * 60
Config.Events = {
	AuraStorm = { Name = "AURA STORM", Description = "2x Luck for everyone!", Luck = 2 },
	GoldenHour = { Name = "GOLDEN HOUR", Description = "2x Aura for everyone!", Aura = 2 },
	VoidNight = { Name = "VOID NIGHT", Description = "3x Luck! Void Aura can appear...", Luck = 3 },
	SpeedRush = { Name = "SPEED RUSH", Description = "Generators work 2x faster!", Speed = 2 },
}

-- Geluk
Config.LuckBoost = 2 -- tijdelijke luck boost (alleen te verdienen, niet te kopen)
Config.PityRolls = 75 -- na zoveel rolls zonder zeldzame aura krijg je er gegarandeerd een
Config.PityMinChance = 128 -- "zeldzaam" = 1 in 128 of zeldzamer
Config.AutoRollRebirths = 1 -- Auto Roll gaat open na de eerste rebirth
Config.AutoRollInterval = 2

-- Aura Index: verzamel aura's voor een blijvende luck bonus
Config.IndexTiers = {
	{ Count = 3, Luck = 0.1 },
	{ Count = 6, Luck = 0.1 },
	{ Count = 9, Luck = 0.2 },
	{ Count = 12, Luck = 0.3 },
}

-- Vrienden in dezelfde server geven een bonus
Config.FriendBonus = 0.1
Config.MaxFriendBonus = 3

-- Dagelijkse quests: Reward = minuten inkomen, of een boost
Config.QuestsPerDay = 3
Config.QuestPool = {
	{ Type = "Collect", Text = "Collect %s Aura", IncomeMinutes = 8, Reward = { Kind = "Aura", Minutes = 5 } },
	{ Type = "Roll", Text = "Roll %s auras", Goal = 15, Reward = { Kind = "Luck", Minutes = 5 } },
	{ Type = "Buy", Text = "Unlock %s items", Goal = 3, Reward = { Kind = "Aura", Minutes = 6 } },
	{ Type = "Pose", Text = "Aura farm for %s seconds", Goal = 90, Reward = { Kind = "Double", Minutes = 5 } },
	{ Type = "Peak", Text = "Reach PEAK AURA %s times", Goal = 2, Reward = { Kind = "Luck", Minutes = 8 } },
	{ Type = "FreeRoll", Text = "Use %s free rolls", Goal = 5, Reward = { Kind = "Double", Minutes = 5 } },
}
Config.QuestAllDoneReward = { Kind = "Luck", Minutes = 10 }

-- Cadeaus voor lang spelen (minuten in deze sessie)
Config.PlaytimeGifts = {
	{ Minutes = 3, Reward = { Kind = "Aura", Minutes = 3 } },
	{ Minutes = 8, Reward = { Kind = "Luck", Minutes = 5 } },
	{ Minutes = 15, Reward = { Kind = "Aura", Minutes = 8 } },
	{ Minutes = 25, Reward = { Kind = "Double", Minutes = 10 } },
	{ Minutes = 40, Reward = { Kind = "Aura", Minutes = 15 } },
	{ Minutes = 60, Reward = { Kind = "Luck", Minutes = 15 } },
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
