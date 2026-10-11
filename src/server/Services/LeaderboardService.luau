-- Grote scoreborden op het plein met de top 10 van alle servers:
-- meeste Aura, hoogste Aura Level en meeste gewonnen Aura Battles.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Builder = require(script.Parent.Builder)
local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.MapBuilder)

local LeaderboardService = {}

local REFRESH_INTERVAL = 90
local nameCache: { [number]: string } = {}

local BOARDS = {
	{ Spot = "Aura", Store = "AuraFarmTycoon_TotalAura_v1", Field = "TotalEarned", Title = "🏆 TOP AURA FARMERS", Color = Color3.fromRGB(255, 210, 90), Short = true },
	{ Spot = "Level", Store = "AuraFarmTycoon_Level_v1", Field = "Level", Title = "⭐ HIGHEST AURA LEVEL", Color = Color3.fromRGB(140, 230, 255), Prefix = "Lv " },
	{ Spot = "Battle", Store = "AuraFarmTycoon_BattleWins_v1", Field = "BattleWins", Title = "⚔️ TOP AURA BATTLERS", Color = Color3.fromRGB(255, 120, 200), Suffix = " wins" },
}

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and name then name else "Player"
	nameCache[userId] = result
	return result
end

local function buildBoard(parent: Instance, cf: CFrame, titleText: string, titleColor: Color3)
	local board = Builder.Part({
		Name = "Leaderboard",
		Size = Vector3.new(16, 20, 1),
		CFrame = cf,
		Color = Color3.fromRGB(25, 20, 40),
		Parent = parent,
	})
	Builder.Part({
		Name = "LeaderboardFrame",
		Size = Vector3.new(16.8, 20.8, 0.8),
		CFrame = cf * CFrame.new(0, 0, 0.2),
		Material = Enum.Material.Neon,
		Color = titleColor,
		Parent = parent,
	})
	for _, x in { -6, 6 } do
		Builder.Part({
			Name = "LeaderboardLeg",
			Size = Vector3.new(1.2, 3, 1.2),
			CFrame = cf * CFrame.new(x, -11, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(45, 45, 55),
			Parent = parent,
		})
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = titleColor
	title.Text = titleText
	title.LayoutOrder = 0
	title.Parent = gui

	local rows = {}
	for rank = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(1, 0.085)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextColor3 = if rank == 1 then Color3.fromRGB(255, 225, 120) else Color3.fromRGB(235, 225, 255)
		row.Text = ""
		row.LayoutOrder = rank
		row.Parent = gui
		rows[rank] = row
	end
	return rows
end

local function runBoard(config, rows)
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(config.Store)
	end)
	if not ok then
		rows[1].Text = "Leaderboard offline"
		return
	end

	while true do
		for _, player in Players:GetPlayers() do
			local data = DataService.Get(player)
			if data and DataService.CanSave(player) then
				pcall(function()
					store:SetAsync(tostring(player.UserId), math.floor(math.min(data[config.Field] or 0, 2 ^ 52)))
				end)
			end
		end

		local success, pages = pcall(function()
			return store:GetSortedAsync(false, 10)
		end)
		if success then
			local entries = pages:GetCurrentPage()
			for rank = 1, 10 do
				local entry = entries[rank]
				if entry then
					local value = if config.Short then Format.Number(entry.value) else tostring(entry.value)
					rows[rank].Text = "#" .. rank .. "  " .. getName(tonumber(entry.key) or 0) .. "  -  " .. (config.Prefix or "") .. value .. (config.Suffix or "")
				else
					rows[rank].Text = ""
				end
			end
		else
			rows[1].Text = "Leaderboard works in the live game"
		end
		task.wait(REFRESH_INTERVAL)
	end
end

function LeaderboardService.Init(mapFolder: Instance)
	for index, config in BOARDS do
		local rows = buildBoard(mapFolder, MapBuilder.Spots.Boards[config.Spot], config.Title, config.Color)
		task.delay(index * 3, runBoard, config, rows)
	end
end

return LeaderboardService
