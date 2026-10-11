-- Rekent uit hoeveel extra Aura en geluk een speler krijgt
-- (rebirths, level, aura, gamepasses, boosts, PEAK AURA, events, vrienden, index).

local Config = require(game.ReplicatedStorage.Shared.Config)
local Auras = require(game.ReplicatedStorage.Shared.Auras)
local Levels = require(game.ReplicatedStorage.Shared.Levels)
local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)

local Economy = {}

function Economy.HasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function Economy.CurrentEvent()
	local id = workspace:GetAttribute("EventId")
	return if type(id) == "string" then Config.Events[id] else nil
end

function Economy.AuraMultiplier(player: Player): number
	local data = DataService.Get(player)
	local aura = data and Auras.ByName[data.EquippedAura]
	return if aura then aura.Multiplier else 1
end

function Economy.FriendMultiplier(player: Player): number
	local friends = player:GetAttribute("FriendsInServer")
	local count = if type(friends) == "number" then math.min(friends, Config.MaxFriendBonus) else 0
	return 1 + count * Config.FriendBonus
end

function Economy.GetMultiplier(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local multiplier = Config.RebirthMultiplier(data.Rebirths) * Economy.AuraMultiplier(player) * Levels.Multiplier(data.Level)
	if Economy.HasPass(player, "DoubleAura") then
		multiplier *= 2
	end
	if Economy.HasPass(player, "VIP") then
		multiplier *= Config.VipBonus
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		multiplier *= Config.PremiumBonus
	end
	if BoostService.IsActive(player, "Double") then
		multiplier *= 2
	end
	if BoostService.PeakRemaining(player) > 0 then
		multiplier *= Config.PeakAuraMultiplier
	end
	local event = Economy.CurrentEvent()
	if event and event.Aura then
		multiplier *= event.Aura
	end
	return multiplier * Economy.FriendMultiplier(player)
end

function Economy.DiscoveredCount(data): number
	local count = 0
	for _, aura in Auras.List do
		if data.OwnedAuras[aura.Name] then
			count += 1
		end
	end
	return count
end

function Economy.IndexLuck(data): number
	local bonus = 0
	local discovered = Economy.DiscoveredCount(data)
	for _, tier in Config.IndexTiers do
		if discovered >= tier.Count then
			bonus += tier.Luck
		end
	end
	return bonus
end

function Economy.GetLuck(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local luck = 1 + Economy.IndexLuck(data)
	if BoostService.IsActive(player, "Luck") then
		luck *= Config.LuckBoost
	end
	local event = Economy.CurrentEvent()
	if event and event.Luck then
		luck *= event.Luck
	end
	return luck
end

function Economy.DropperSpeed(player: Player): number
	local speed = if Economy.HasPass(player, "FastDroppers") then 1.25 else 1
	local event = Economy.CurrentEvent()
	if event and event.Speed then
		speed *= event.Speed
	end
	return speed
end

-- Basis-opbrengst van de generators per seconde, zonder bonussen
local function plotIncome(data): number
	local total = 0
	for line in Config.Lines do
		local base = 0
		local lineMultiplier = 1
		for _, item in Config.Items do
			if item.Line == line and data.Purchased[item.Id] then
				if item.Type == "Dropper" then
					base += item.Value / item.Interval
				elseif item.Type == "Upgrader" then
					lineMultiplier *= item.Multiplier
				end
			end
		end
		total += base * lineMultiplier
	end
	return total
end

-- Hoeveel Aura per seconde dit plot nu oplevert, met alle bonussen
function Economy.IncomePerSecond(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	return plotIncome(data) * Economy.DropperSpeed(player) * Economy.GetMultiplier(player)
end

-- Inkomen zonder tijdelijke boosts, zodat beloningen niet extra groot worden tijdens een boost
function Economy.BaseIncomePerSecond(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	return plotIncome(data) * Config.RebirthMultiplier(data.Rebirths) * Economy.AuraMultiplier(player) * Levels.Multiplier(data.Level)
end

return Economy
