-- Dagelijkse quests en cadeaus voor lang spelen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Bus = require(script.Parent.Bus)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local RewardService = require(script.Parent.RewardService)

local Remotes = ReplicatedStorage.Remotes

local QuestService = {}

local giftsClaimed: { [Player]: { [number]: boolean } } = {}

local function today(): number
	return os.time() // 86400
end

local function roundGoal(value: number): number
	if value < 100 then
		return math.max(10, math.floor(value / 10 + 0.5) * 10)
	end
	local magnitude = 10 ^ math.floor(math.log10(value))
	return math.floor(value / magnitude * 2 + 0.5) / 2 * magnitude
end

function QuestService.Ensure(player: Player)
	local data = DataService.Get(player)
	if not data or data.Quests.Day == today() then
		return
	end
	local rng = Random.new(player.UserId + today())
	local pool = table.clone(Config.QuestPool)
	local list = {}
	for _ = 1, math.min(Config.QuestsPerDay, #pool) do
		local index = rng:NextInteger(1, #pool)
		local quest = table.remove(pool, index)
		local goal = quest.Goal
		if quest.IncomeMinutes then
			goal = roundGoal(math.max(500, Economy.BaseIncomePerSecond(player) * 60 * quest.IncomeMinutes))
		end
		table.insert(list, { Type = quest.Type, Goal = goal, Progress = 0, Claimed = false })
	end
	data.Quests = { Day = today(), List = list, AllClaimed = false }
	DataService.Changed(player)
end

local function poolEntry(questType: string)
	for _, quest in Config.QuestPool do
		if quest.Type == questType then
			return quest
		end
	end
	return nil
end

function QuestService.Progress(player: Player, questType: string, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	QuestService.Ensure(player)
	for _, quest in data.Quests.List do
		if quest.Type == questType and quest.Progress < quest.Goal then
			quest.Progress = math.min(quest.Goal, quest.Progress + amount)
			if quest.Progress >= quest.Goal then
				Remotes.Notify:FireClient(player, "Quest complete! Open Quests to claim your reward", "success")
			end
			DataService.Changed(player)
		end
	end
end

function QuestService.Claim(player: Player, index: number)
	local data = DataService.Get(player)
	local quest = data and data.Quests.List[index]
	if not quest or quest.Claimed or quest.Progress < quest.Goal then
		return
	end
	quest.Claimed = true
	local entry = poolEntry(quest.Type)
	if entry then
		RewardService.Grant(player, entry.Reward, "Quest reward")
	end

	local allClaimed = true
	for _, other in data.Quests.List do
		if not other.Claimed then
			allClaimed = false
		end
	end
	if allClaimed and not data.Quests.AllClaimed then
		data.Quests.AllClaimed = true
		RewardService.Grant(player, Config.QuestAllDoneReward, "All quests done")
	end
	DataService.Changed(player)
end

function QuestService.ClaimGift(player: Player, index: number)
	local gift = Config.PlaytimeGifts[index]
	local claimed = giftsClaimed[player]
	local joinedAt = player:GetAttribute("JoinedAt")
	if not gift or not claimed or claimed[index] or type(joinedAt) ~= "number" then
		return
	end
	if os.time() - joinedAt < gift.Minutes * 60 then
		return
	end
	claimed[index] = true
	RewardService.Grant(player, gift.Reward, "Gift")
	DataService.Changed(player)
end

-- Wat de speler in de Quests en Gifts schermen ziet
function QuestService.State(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local quests = {}
	for index, quest in data.Quests.List do
		local entry = poolEntry(quest.Type)
		quests[index] = {
			Text = if entry then string.format(entry.Text, Format.Number(quest.Goal)) else quest.Type,
			Progress = quest.Progress,
			Goal = quest.Goal,
			Claimed = quest.Claimed,
			Reward = if entry then RewardService.Describe(player, entry.Reward) else "",
		}
	end

	local gifts = {}
	local joinedAt = player:GetAttribute("JoinedAt")
	local played = if type(joinedAt) == "number" then os.time() - joinedAt else 0
	local claimed = giftsClaimed[player] or {}
	for index, gift in Config.PlaytimeGifts do
		gifts[index] = {
			ReadyIn = math.max(0, gift.Minutes * 60 - played),
			Claimed = claimed[index] == true,
			Reward = RewardService.Describe(player, gift.Reward),
		}
	end

	return {
		Quests = quests,
		AllDoneReward = RewardService.Describe(player, Config.QuestAllDoneReward),
		ResetIn = (today() + 1) * 86400 - os.time(),
		Gifts = gifts,
	}
end

function QuestService.OnJoin(player: Player)
	player:SetAttribute("JoinedAt", os.time())
	giftsClaimed[player] = {}
	QuestService.Ensure(player)
end

function QuestService.Init()
	Bus.On("Collected", function(player, amount)
		QuestService.Progress(player, "Collect", amount)
	end)
	Bus.On("Rolled", function(player, _, free)
		QuestService.Progress(player, "Roll", 1)
		if free then
			QuestService.Progress(player, "FreeRoll", 1)
		end
	end)
	Bus.On("Bought", function(player)
		QuestService.Progress(player, "Buy", 1)
	end)
	Bus.On("Posed", function(player, seconds)
		QuestService.Progress(player, "Pose", seconds)
	end)
	Bus.On("PeakAura", function(player)
		QuestService.Progress(player, "Peak", 1)
	end)

	Remotes.ClaimQuest.OnServerEvent:Connect(function(player, index)
		if type(index) == "number" then
			QuestService.Claim(player, index)
		end
	end)
	Remotes.ClaimGift.OnServerEvent:Connect(function(player, index)
		if type(index) == "number" then
			QuestService.ClaimGift(player, index)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		giftsClaimed[player] = nil
	end)
end

return QuestService
