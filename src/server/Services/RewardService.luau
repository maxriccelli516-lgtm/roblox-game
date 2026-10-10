-- Offline inkomen, dagelijkse beloning en codes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)

local Remotes = ReplicatedStorage.Remotes

local RewardService = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

-- Een beloning uitdelen. reward = { Kind = "Aura" | "Luck" | "Double", Minutes = n }
function RewardService.Describe(player: Player?, reward): string
	if reward.Kind == "Luck" then
		return reward.Minutes .. " min 2x Luck"
	elseif reward.Kind == "Double" then
		return reward.Minutes .. " min 2x Aura"
	end
	if player then
		return "+" .. Format.Number(RewardService.AuraAmount(player, reward.Minutes)) .. " Aura"
	end
	return reward.Minutes .. " min of Aura"
end

function RewardService.AuraAmount(player: Player, minutes: number): number
	local data = DataService.Get(player)
	local minimum = 150 * ((data and data.Rebirths or 0) + 1)
	return math.floor(math.max(minimum, Economy.BaseIncomePerSecond(player) * minutes * 60))
end

function RewardService.Grant(player: Player, reward, title: string)
	local text = RewardService.Describe(player, reward)
	if reward.Kind == "Luck" then
		BoostService.Add(player, "Luck", reward.Minutes)
	elseif reward.Kind == "Double" then
		BoostService.Add(player, "Double", reward.Minutes)
	else
		DataService.AddAura(player, RewardService.AuraAmount(player, reward.Minutes))
	end
	notify(player, title .. ": " .. text .. "!", "rare")
end

function RewardService.GiveOfflineEarnings(player: Player)
	local data = DataService.Get(player)
	if not data or data.LastOnline <= 0 then
		return
	end
	local seconds = math.min(os.time() - data.LastOnline, Config.OfflineMaxSeconds)
	if seconds < 60 then
		return
	end
	local amount = math.floor(Economy.BaseIncomePerSecond(player) * seconds * Config.OfflineRate)
	if amount > 0 then
		DataService.AddAura(player, amount)
		notify(player, "Welcome back! Your farm made " .. Format.Number(amount) .. " Aura while you were away", "rare")
	end
end

function RewardService.DailyWait(data): number
	return math.max(0, data.LastDaily + Config.DailyCooldown - os.time())
end

function RewardService.ClaimDaily(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local waitLeft = RewardService.DailyWait(data)
	if waitLeft > 0 then
		notify(player, "Next daily reward in " .. Format.Time(waitLeft), "error")
		return
	end
	if os.time() - data.LastDaily > Config.DailyStreakReset then
		data.DailyStreak = 1
	else
		data.DailyStreak += 1
	end
	data.LastDaily = os.time()
	local streak = math.min(data.DailyStreak, 7)
	local amount = math.floor(math.max(250 * streak, Economy.BaseIncomePerSecond(player) * 120 * streak))
	DataService.AddAura(player, amount)
	notify(player, "Day " .. data.DailyStreak .. " reward: +" .. Format.Number(amount) .. " Aura!", "rare")
end

function RewardService.RedeemCode(player: Player, code: string)
	local data = DataService.Get(player)
	if not data or type(code) ~= "string" then
		return
	end
	code = string.upper((string.gsub(code, "%s", "")))
	local reward = Config.Codes[code]
	if not reward then
		notify(player, "That code doesn't exist", "error")
		return
	end
	if data.RedeemedCodes[code] then
		notify(player, "You already used this code", "error")
		return
	end
	data.RedeemedCodes[code] = true
	DataService.AddAura(player, reward)
	notify(player, "Code redeemed! +" .. Format.Number(reward) .. " Aura", "success")
end

function RewardService.Init()
	Remotes.ClaimDaily.OnServerEvent:Connect(function(player)
		RewardService.ClaimDaily(player)
	end)
	Remotes.RedeemCode.OnServerEvent:Connect(function(player, code)
		if type(code) == "string" and #code <= 30 then
			RewardService.RedeemCode(player, code)
		end
	end)
end

return RewardService
