-- Aura Levels: XP verdienen (vooral door aura te farmen), level up met een grote beloning,
-- een titel boven je hoofd en mijlpalen met poses, exclusieve aura's en boosts.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Levels = require(ReplicatedStorage.Shared.Levels)
local AuraService = require(script.Parent.AuraService)
local BoostService = require(script.Parent.BoostService)
local Bus = require(script.Parent.Bus)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)

local Remotes = ReplicatedStorage.Remotes

local LevelService = {}

local lastCollectXp: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

-- "Lv 7 • Rizzler" boven je hoofd (boven de naam van je aura)
function LevelService.ApplyTag(player: Player)
	local data = DataService.Get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local title = Levels.TitleFor(data.Level)
	local tag = head:FindFirstChild("LevelTag") :: BillboardGui?
	local label: TextLabel
	if tag then
		label = tag:FindFirstChildOfClass("TextLabel") :: TextLabel
	else
		local gui = Instance.new("BillboardGui")
		gui.Name = "LevelTag"
		gui.Size = UDim2.new(8, 0, 1.1, 0)
		gui.StudsOffset = Vector3.new(0, 3.8, 0)
		gui.MaxDistance = 80
		gui.LightInfluence = 0
		gui.Adornee = head
		gui.Parent = head
		label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		tag = gui
	end
	label.Text = "Lv " .. data.Level .. " • " .. title.Title
	label.TextColor3 = title.Color
end

-- Een gouden lichtstraal en een explosie van sterretjes
local function levelUpEffect(player: Player, level: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local pillar = Instance.new("Part")
	pillar.Name = "LevelUpBeam"
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Material = Enum.Material.Neon
	pillar.Color = Levels.TitleFor(level).Color:Lerp(Color3.fromRGB(255, 220, 90), 0.5)
	pillar.Transparency = 0.2
	pillar.Size = Vector3.new(4, 7, 7)
	pillar.CFrame = CFrame.new(root.Position + Vector3.new(0, -1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Parent = workspace
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(pillar, info, {
		Size = Vector3.new(120, 3, 3),
		CFrame = CFrame.new(root.Position + Vector3.new(0, 58, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 1,
	}):Play()
	Debris:AddItem(pillar, 1.8)

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 255, 255))
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(1.2, 2)
	emitter.Speed = NumberRange.new(20, 40)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.Size = NumberSequence.new(1.4, 0)
	emitter.Parent = attachment
	emitter:Emit(200)
	Debris:AddItem(attachment, 3)
end

local function grantLevel(player: Player, data, level: number): { string }
	local lines = {}

	-- Elk level: een zak Aura en permanent meer Aura
	local minutes = Levels.RewardMinutes(level)
	local amount = math.floor(math.max(level * 400 * (data.Rebirths + 1), Economy.BaseIncomePerSecond(player) * minutes * 60))
	DataService.AddAura(player, amount)
	table.insert(lines, "+" .. Format.Number(amount) .. " Aura")
	table.insert(lines, "Aura x" .. string.format("%.2f", Levels.Multiplier(level)) .. " forever")

	local milestone = Levels.Milestones[level]
	if milestone then
		if milestone.Reward then
			BoostService.Add(player, milestone.Reward.Kind, milestone.Reward.Minutes)
		end
		if milestone.Aura then
			AuraService.GiveExclusive(player, milestone.Aura)
		end
	end
	for _, line in Levels.MilestoneText(level) do
		table.insert(lines, line)
	end
	return lines
end

function LevelService.AddXP(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 or data.Level >= Levels.MaxLevel then
		return
	end
	data.XP += amount
	local gained = {}
	while data.Level < Levels.MaxLevel and data.XP >= Levels.XpFor(data.Level) do
		data.XP -= Levels.XpFor(data.Level)
		data.Level += 1
		table.insert(gained, data.Level)
	end
	if data.Level >= Levels.MaxLevel then
		data.XP = 0
	end

	for _, level in gained do
		local lines = grantLevel(player, data, level)
		local title = Levels.TitleFor(level)
		local newTitle = title.Level == level
		Remotes.LevelUp:FireClient(player, level, lines, if newTitle then title.Title else nil)
		levelUpEffect(player, level)
		Bus.Fire("LevelUp", player, level)
		if Levels.Milestones[level] or newTitle then
			for _, other in Players:GetPlayers() do
				if other ~= player then
					notify(other, "⭐ " .. player.DisplayName .. " reached Aura Level " .. level .. "!", "info")
				end
			end
		end
	end
	if #gained > 0 then
		LevelService.ApplyTag(player)
		local stats = player:FindFirstChild("leaderstats")
		local levelValue = stats and stats:FindFirstChild("Level") :: IntValue?
		if levelValue then
			levelValue.Value = data.Level
		end
	end
	DataService.Changed(player)
end

function LevelService.Init()
	local Xp = Levels.Xp
	Bus.On("Posed", function(player, seconds)
		LevelService.AddXP(player, seconds * Xp.PoseSecond)
	end)
	Bus.On("PeakAura", function(player)
		LevelService.AddXP(player, Xp.Peak)
	end)
	Bus.On("Collected", function(player)
		local now = os.clock()
		if now - (lastCollectXp[player] or 0) >= 5 then
			lastCollectXp[player] = now
			LevelService.AddXP(player, Xp.Collect)
		end
	end)
	Bus.On("Rolled", function(player)
		LevelService.AddXP(player, Xp.Roll)
	end)
	Bus.On("QuestClaimed", function(player)
		LevelService.AddXP(player, Xp.Quest)
	end)
	Bus.On("Rebirthed", function(player)
		LevelService.AddXP(player, Xp.Rebirth)
	end)
	Bus.On("BattleEnded", function(player, won, vsBot)
		if vsBot then
			LevelService.AddXP(player, if won then Xp.BotWin else Xp.BotLoss)
		else
			LevelService.AddXP(player, if won then Xp.BattleWin else Xp.BattleLoss)
		end
	end)
	Bus.On("ObbyCleared", function(player)
		LevelService.AddXP(player, Xp.Obby)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastCollectXp[player] = nil
	end)
end

return LevelService
