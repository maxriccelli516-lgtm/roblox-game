-- Startpunt van de server: zet alles aan en regelt spelers die joinen en weggaan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Levels = require(ReplicatedStorage.Shared.Levels)

local Services = script.Parent.Services
local AuraService = require(Services.AuraService)
local BattleService = require(Services.BattleService)
local BoostService = require(Services.BoostService)
local DataService = require(Services.DataService)
local Economy = require(Services.Economy)
local EventService = require(Services.EventService)
local FriendService = require(Services.FriendService)
local LeaderboardService = require(Services.LeaderboardService)
local LevelService = require(Services.LevelService)
local MapBuilder = require(Services.MapBuilder)
local MonetizationService = require(Services.MonetizationService)
local ObbyService = require(Services.ObbyService)
local PoseService = require(Services.PoseService)
local QuestService = require(Services.QuestService)
local RewardService = require(Services.RewardService)
local StatueService = require(Services.StatueService)
local TycoonService = require(Services.TycoonService)

local Remotes = ReplicatedStorage.Remotes

local map = MapBuilder.Build()
DataService.Init()
TycoonService.Init()
AuraService.Init()
MonetizationService.Init()
RewardService.Init()
QuestService.Init()
PoseService.Init()
FriendService.Init()
EventService.Init()
LevelService.Init()
BattleService.Init(map)
ObbyService.Init(map)
StatueService.Init(map)
LeaderboardService.Init(map)

------------------------------------------------------------------------
-- Status naar de speler sturen (maximaal 4 keer per seconde)
------------------------------------------------------------------------

local dirty: { [Player]: boolean } = {}

local function buildState(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local passes = {}
	for key in Config.GamePasses do
		passes[key] = Economy.HasPass(player, key)
	end
	return {
		Aura = data.Aura,
		TotalEarned = data.TotalEarned,
		Rebirths = data.Rebirths,
		RebirthCost = Config.RebirthCost(data.Rebirths),
		Multiplier = Economy.GetMultiplier(player),
		RebirthMultiplier = Config.RebirthMultiplier(data.Rebirths),
		NextRebirthMultiplier = Config.RebirthMultiplier(data.Rebirths + 1),
		IncomePerSecond = Economy.IncomePerSecond(player),
		RollCost = Config.RollCost(data.Rebirths),
		FreeRollIn = AuraService.FreeRollWait(data),
		DailyIn = RewardService.DailyWait(data),
		DailyStreak = data.DailyStreak,
		OwnedAuras = data.OwnedAuras,
		EquippedAura = data.EquippedAura,
		Passes = passes,
		CanSave = DataService.CanSave(player),
		Luck = Economy.GetLuck(player),
		IndexLuck = Economy.IndexLuck(data),
		PityLeft = math.max(0, Config.PityRolls - data.PityCounter),
		Boosts = {
			Double = BoostService.Remaining(player, "Double"),
			Luck = BoostService.Remaining(player, "Luck"),
			Peak = BoostService.PeakRemaining(player),
		},
		FriendsInServer = player:GetAttribute("FriendsInServer") or 0,
		AutoRollUnlocked = data.Rebirths >= Config.AutoRollRebirths,
		AutoRoll = player:GetAttribute("AutoRoll") == true,
		StarterPackBought = data.StarterPackBought,
		PaidRandomRestricted = player:GetAttribute("PaidRandomRestricted") ~= false,
		Quest = QuestService.State(player),
		Level = data.Level,
		XP = data.XP,
		XPNeeded = Levels.XpFor(data.Level),
		LevelMultiplier = Levels.Multiplier(data.Level),
		BattleWins = data.BattleWins,
		ObbyIn = math.max(0, data.LastObby + Config.Obby.CooldownSeconds - os.time()),
	}
end

local function updateLeaderstats(player: Player)
	local data = DataService.Get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	local auraValue = stats:FindFirstChild("Aura") :: StringValue
	local levelValue = stats:FindFirstChild("Level") :: IntValue
	local rebirthValue = stats:FindFirstChild("Rebirths") :: IntValue
	local winsValue = stats:FindFirstChild("Wins") :: IntValue
	auraValue.Value = Format.Number(data.Aura)
	levelValue.Value = data.Level
	rebirthValue.Value = data.Rebirths
	winsValue.Value = data.BattleWins
end

DataService.OnChanged(function(player)
	dirty[player] = true
end)

task.spawn(function()
	while true do
		task.wait(0.25)
		for player in dirty do
			dirty[player] = nil
			if player.Parent then
				local state = buildState(player)
				if state then
					Remotes.SyncState:FireClient(player, state)
					updateLeaderstats(player)
				end
			end
		end
	end
end)

------------------------------------------------------------------------
-- Spelers
------------------------------------------------------------------------

local function setCollisionGroup(character: Model)
	local function apply(part: Instance)
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end
	for _, descendant in character:GetDescendants() do
		apply(descendant)
	end
	character.DescendantAdded:Connect(apply)
end

local function onCharacterAdded(player: Player, character: Model)
	setCollisionGroup(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	character:WaitForChild("Head", 10)
	if not root or not player.Parent then
		return
	end
	task.wait(0.1)
	PoseService.Stop(player)
	local spawnCFrame = TycoonService.SpawnCFrame(player)
	if spawnCFrame then
		character:PivotTo(spawnCFrame)
	end
	AuraService.ApplyVisual(player)
	LevelService.ApplyTag(player)
end

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local auraValue = Instance.new("StringValue")
	auraValue.Name = "Aura"
	auraValue.Value = "0"
	auraValue.Parent = stats
	local levelValue = Instance.new("IntValue")
	levelValue.Name = "Level"
	levelValue.Value = 1
	levelValue.Parent = stats
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirths"
	rebirthValue.Parent = stats
	local winsValue = Instance.new("IntValue")
	winsValue.Name = "Wins"
	winsValue.Parent = stats
	stats.Parent = player

	MonetizationService.LoadPasses(player)
	MonetizationService.LoadPolicy(player)

	local profile = DataService.Load(player)
	if not profile or not player.Parent then
		return
	end

	if not TycoonService.Claim(player) then
		player:Kick("This server is full, please join another server!")
		return
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	RewardService.GiveOfflineEarnings(player)
	QuestService.OnJoin(player)
	FriendService.OnJoin(player)
	DataService.Changed(player)

	if not profile.CanSave then
		Remotes.Notify:FireClient(player, "Saving is off (turn on API access in Studio to test saving)", "error")
	end
end

local function onPlayerRemoving(player: Player)
	PoseService.Stop(player)
	TycoonService.Collect(player, true)
	TycoonService.Release(player)
	DataService.Release(player)
	dirty[player] = nil
end

Remotes.RequestRebirth.OnServerEvent:Connect(function(player)
	TycoonService.Rebirth(player)
end)

-- Tijden (gratis roll, daily, boosts) elke paar seconden opnieuw sturen
task.spawn(function()
	while true do
		task.wait(3)
		for _, player in Players:GetPlayers() do
			dirty[player] = true
		end
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
