-- Rekent uit hoeveel extra Aura een speler krijgt (rebirths, aura, gamepasses, premium).

local Config = require(game.ReplicatedStorage.Shared.Config)
local Auras = require(game.ReplicatedStorage.Shared.Auras)
local DataService = require(script.Parent.DataService)

local Economy = {}

function Economy.HasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function Economy.AuraMultiplier(player: Player): number
	local data = DataService.Get(player)
	local aura = data and Auras.ByName[data.EquippedAura]
	return if aura then aura.Multiplier else 1
end

function Economy.GetMultiplier(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local multiplier = Config.RebirthMultiplier(data.Rebirths) * Economy.AuraMultiplier(player)
	if Economy.HasPass(player, "DoubleAura") then
		multiplier *= 2
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		multiplier *= Config.PremiumBonus
	end
	return multiplier
end

function Economy.DropperSpeed(player: Player): number
	return if Economy.HasPass(player, "FastDroppers") then 1.25 else 1
end

-- Ongeveer hoeveel Aura per seconde dit plot oplevert (voor offline inkomen en beloningen)
function Economy.IncomePerSecond(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
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
	return total * Economy.DropperSpeed(player) * Economy.GetMultiplier(player)
end

return Economy
