-- Tijdelijke boosts (2x Aura, 2x Luck) en PEAK AURA. Boosts lopen door als je offline bent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local Remotes = ReplicatedStorage.Remotes

local BoostService = {}

-- Kind: "Double" of "Luck"
function BoostService.Add(player: Player, kind: string, minutes: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local now = os.time()
	local current = data.Boosts[kind] or 0
	data.Boosts[kind] = math.max(current, now) + math.floor(minutes * 60)
	DataService.Changed(player)
end

function BoostService.Remaining(player: Player, kind: string): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	return math.max(0, (data.Boosts[kind] or 0) - os.time())
end

function BoostService.IsActive(player: Player, kind: string): boolean
	return BoostService.Remaining(player, kind) > 0
end

function BoostService.StartPeak(player: Player, seconds: number)
	player:SetAttribute("PeakUntil", os.time() + seconds)
	DataService.Changed(player)
	Remotes.Notify:FireClient(player, "PEAK AURA! 2x Aura for " .. seconds .. " seconds", "rare")
end

function BoostService.PeakRemaining(player: Player): number
	local untilTime = player:GetAttribute("PeakUntil")
	return if type(untilTime) == "number" then math.max(0, untilTime - os.time()) else 0
end

return BoostService
