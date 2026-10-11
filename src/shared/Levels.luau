-- Aura Levels: je krijgt XP vooral door aura te farmen (poseren, PEAK AURA) en door battles te winnen.
-- Elk level geeft een flinke beloning, en op mijlpalen krijg je iets bijzonders (pose, aura, boost, titel).
-- De client gebruikt dit bestand ook voor de Level Road (wat krijg je wanneer).

local Levels = {}

Levels.MaxLevel = 100

-- Zoveel XP heb je nodig om van dit level naar het volgende te gaan
function Levels.XpFor(level: number): number
	return math.floor(60 * level ^ 1.45)
end

-- Elk level: permanent meer Aura
Levels.MultiplierPerLevel = 0.03

function Levels.Multiplier(level: number): number
	return 1 + Levels.MultiplierPerLevel * (math.max(1, level) - 1)
end

-- Elk level: zoveel minuten van je inkomen als beloning
function Levels.RewardMinutes(level: number): number
	return math.min(30, 2 + level)
end

-- Kracht in een Aura Battle per tik
function Levels.BattlePower(level: number): number
	return 1 + 0.04 * (math.max(1, level) - 1)
end

-- XP per bron
Levels.Xp = {
	PoseSecond = 2, -- per seconde aura farmen
	Peak = 40, -- PEAK AURA gehaald
	Collect = 2, -- Aura opgehaald bij je collector (hooguit 1x per 5 seconden)
	Roll = 3,
	Quest = 40,
	Rebirth = 150,
	BattleWin = 60,
	BattleLoss = 20,
	BotWin = 30,
	BotLoss = 10,
	Obby = 120,
}

-- Titels boven je hoofd
Levels.Titles = {
	{ Level = 1, Title = "Noob", Color = Color3.fromRGB(200, 200, 200) },
	{ Level = 3, Title = "NPC", Color = Color3.fromRGB(170, 220, 255) },
	{ Level = 5, Title = "Aura Rookie", Color = Color3.fromRGB(120, 255, 150) },
	{ Level = 10, Title = "Rizzler", Color = Color3.fromRGB(255, 130, 210) },
	{ Level = 15, Title = "Sigma", Color = Color3.fromRGB(255, 170, 60) },
	{ Level = 20, Title = "Main Character", Color = Color3.fromRGB(255, 230, 120) },
	{ Level = 30, Title = "Aura Legend", Color = Color3.fromRGB(190, 120, 255) },
	{ Level = 40, Title = "Aura Overlord", Color = Color3.fromRGB(255, 70, 70) },
	{ Level = 50, Title = "AURA GOD", Color = Color3.fromRGB(255, 255, 255) },
}

function Levels.TitleFor(level: number)
	local best = Levels.Titles[1]
	for _, entry in Levels.Titles do
		if level >= entry.Level then
			best = entry
		end
	end
	return best
end

-- Mijlpalen. Reward: { Kind = "Luck" | "Double", Minutes = n }, Aura = exclusieve aura, Pose = pose Id
Levels.Milestones = {
	[2] = { Reward = { Kind = "Luck", Minutes = 10 } },
	[3] = { Pose = "Lean" },
	[5] = { Reward = { Kind = "Double", Minutes = 15 } },
	[7] = { Reward = { Kind = "Luck", Minutes = 15 } },
	[10] = { Aura = "Rookie Flame", Pose = "Levitate" },
	[12] = { Reward = { Kind = "Double", Minutes = 20 } },
	[15] = { Reward = { Kind = "Luck", Minutes = 20 } },
	[20] = { Aura = "Ascended", Pose = "Wings" },
	[25] = { Reward = { Kind = "Double", Minutes = 30 } },
	[30] = { Aura = "Aura Overlord" },
	[35] = { Reward = { Kind = "Luck", Minutes = 30 } },
	[40] = { Reward = { Kind = "Double", Minutes = 60 } },
	[50] = { Aura = "Aura God" },
}

-- Korte tekst voor de mijlpaal (Level Road en level-up scherm)
function Levels.MilestoneText(level: number): { string }
	local lines = {}
	local milestone = Levels.Milestones[level]
	if milestone then
		if milestone.Aura then
			table.insert(lines, "Exclusive aura: " .. milestone.Aura)
		end
		if milestone.Pose then
			table.insert(lines, "New pose unlocked!")
		end
		if milestone.Reward then
			local kind = if milestone.Reward.Kind == "Luck" then "2x Luck" else "2x Aura"
			table.insert(lines, milestone.Reward.Minutes .. " min " .. kind)
		end
	end
	for _, entry in Levels.Titles do
		if entry.Level == level and level > 1 then
			table.insert(lines, "New title: " .. entry.Title)
		end
	end
	return lines
end

return Levels
