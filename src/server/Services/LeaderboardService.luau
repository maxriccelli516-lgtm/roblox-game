-- Een groot scorebord op het plein met de top 10 Aura farmers van alle servers.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Builder = require(script.Parent.Builder)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local REFRESH_INTERVAL = 90
local nameCache: { [number]: string } = {}

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

local function buildBoard(parent: Instance)
	local board = Builder.Part({
		Name = "Leaderboard",
		Size = Vector3.new(18, 22, 1),
		CFrame = CFrame.lookAt(Vector3.new(-22, 12, 14), Vector3.new(0, 12, -18)),
		Color = Color3.fromRGB(25, 20, 40),
		Parent = parent,
	})
	Builder.Part({
		Name = "LeaderboardPost",
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(-22, 1, 14),
		Color = Color3.fromRGB(25, 20, 40),
		Parent = parent,
	})

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
	title.TextColor3 = Color3.fromRGB(255, 210, 90)
	title.Text = "🏆 TOP AURA FARMERS"
	title.LayoutOrder = 0
	title.Parent = gui

	local rows = {}
	for rank = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(1, 0.085)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextColor3 = Color3.fromRGB(235, 225, 255)
		row.Text = ""
		row.LayoutOrder = rank
		row.Parent = gui
		rows[rank] = row
	end
	return rows
end

function LeaderboardService.Init(mapFolder: Instance)
	local rows = buildBoard(mapFolder)

	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("AuraFarmTycoon_TotalAura_v1")
	end)
	if not ok then
		rows[1].Text = "Leaderboard offline"
		return
	end

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data and DataService.CanSave(player) then
					pcall(function()
						store:SetAsync(tostring(player.UserId), math.floor(math.min(data.TotalEarned, 2 ^ 52)))
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
						rows[rank].Text = "#" .. rank .. "  " .. getName(tonumber(entry.key) or 0) .. "  -  " .. Format.Number(entry.value)
					else
						rows[rank].Text = ""
					end
				end
			else
				rows[1].Text = "Leaderboard works in the live game"
			end
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return LeaderboardService
