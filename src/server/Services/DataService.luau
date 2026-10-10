-- Laadt en bewaart de voortgang van spelers.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)

local DataService = {}

local STORE_NAME = "AuraFarmTycoon_v1"
local AUTOSAVE_INTERVAL = 60

local TEMPLATE = {
	Aura = Config.StartAura,
	TotalEarned = 0,
	Rebirths = 0,
	Purchased = {},
	OwnedAuras = {},
	EquippedAura = "",
	LastOnline = 0,
	LastFreeRoll = 0,
	LastDaily = 0,
	DailyStreak = 0,
	RedeemedCodes = {},
	ProcessedReceipts = {},
	RollCount = 0,
	PityCounter = 0,
	Boosts = {},
	Quests = { Day = 0, List = {}, AllClaimed = false },
	StarterPackBought = false,
}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] Geen DataStore beschikbaar, opslaan staat uit:", result)
	end
end

local profiles = {} -- [Player] = { Data = table, CanSave = boolean }
local changedCallbacks = {}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		end
	end
end

local function keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

function DataService.Load(player: Player)
	local data = nil
	local loaded = false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player.UserId))
			end)
			if ok then
				data = result
				loaded = true
				break
			end
			warn("[DataService] Laden mislukt (poging " .. attempt .. "):", result)
			task.wait(attempt * 1.5)
		end
	end

	if type(data) ~= "table" then
		data = deepCopy(TEMPLATE)
	else
		reconcile(data, TEMPLATE)
	end

	if not player.Parent then
		return nil
	end

	local profile = { Data = data, CanSave = loaded }
	profiles[player] = profile
	return profile
end

function DataService.Get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService.CanSave(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.CanSave
end

function DataService.Save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.CanSave or not store then
		return
	end
	profile.Data.LastOnline = os.time()
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player.UserId), function()
			return profile.Data
		end)
	end)
	if not ok then
		warn("[DataService] Opslaan mislukt voor " .. player.Name .. ":", err)
	end
end

function DataService.Release(player: Player)
	DataService.Save(player)
	profiles[player] = nil
end

function DataService.OnChanged(callback)
	table.insert(changedCallbacks, callback)
end

function DataService.Changed(player: Player)
	for _, callback in changedCallbacks do
		callback(player)
	end
end

function DataService.AddAura(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.Aura += amount
	data.TotalEarned += amount
	DataService.Changed(player)
end

function DataService.Init()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local remaining = 0
		for _, player in Players:GetPlayers() do
			remaining += 1
			task.spawn(function()
				DataService.Save(player)
				remaining -= 1
			end)
		end
		local started = os.clock()
		while remaining > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
