-- Aura Battles in de arena in het midden.
-- Ga op een gloeiende cirkel staan. Staat er iemand tegenover je, dan begint de battle.
-- Sta je te lang alleen, dan komt de Aura Bot. Tik zo snel je kunt op AURA!: je aura-straal duwt
-- de botsbal naar de ander. Wie de bal het verst duwt (of helemaal bij de ander krijgt) wint.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Auras = require(ReplicatedStorage.Shared.Auras)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Builder = require(script.Parent.Builder)
local Bus = require(script.Parent.Bus)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local MapBuilder = require(script.Parent.MapBuilder)
local PoseService = require(script.Parent.PoseService)

local Remotes = ReplicatedStorage.Remotes
local Settings = Config.Battle

local BattleService = {}

local PAD_RADIUS = 3.6
local TICK = 0.1
local BOT_COLOR = Color3.fromRGB(255, 70, 90)
local BOT_TAPS_PER_SECOND = 5.5

type Fighter = {
	Player: Player?,
	Bot: Model?,
	Name: string,
	Level: number,
	Power: number,
	Total: number,
	Tokens: number,
	Color: Color3,
	Attachment: Attachment?,
}

type Stage = {
	Index: number,
	A: Vector3,
	B: Vector3,
	Folder: Folder,
	Label: TextLabel,
	Phase: string, -- "Idle" | "Countdown" | "Fight" | "Cooldown"
	PhaseEnds: number,
	WaitStart: number?,
	Fighters: { Fighter },
	Ball: BasePart?,
	BallAttachment: Attachment?,
	Beams: { Beam },
	SendTimer: number,
}

local stages: { Stage } = {}
local fighterByPlayer: { [Player]: Fighter } = {}
local needsStepOff: { [Player]: boolean } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function onPad(root: BasePart, pad: Vector3): boolean
	local offset = root.Position - pad
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= PAD_RADIUS and offset.Y > -1 and offset.Y < 7
end

local function auraColor(player: Player): Color3
	local data = DataService.Get(player)
	local aura = data and Auras.ByName[data.EquippedAura]
	if aura and aura.Name ~= "Void Aura" then
		return aura.Color
	end
	return Color3.fromRGB(170, 90, 255)
end

-- Kracht per tik: je level telt het meest, je aura helpt een beetje
local function powerFor(player: Player): number
	local data = DataService.Get(player)
	local level = if data then data.Level else 1
	local auraFactor = 1 + 0.08 * (math.min(Economy.AuraMultiplier(player), 12) - 1)
	return Levels.BattlePower(level) * auraFactor
end

local function send(fighter: Fighter, payload)
	if fighter.Player and fighter.Player.Parent then
		Remotes.BattleState:FireClient(fighter.Player, payload)
	end
end

local function popup(adornee: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(10, 0, 2, 0)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = adornee
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	local info = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 9, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	Debris:AddItem(gui, 2.1)
end

------------------------------------------------------------------------
-- De Aura Bot: een gloeiend blokpoppetje
------------------------------------------------------------------------

local function buildBot(stage: Stage, position: Vector3, facing: Vector3, level: number): (Model, Attachment)
	local model = Instance.new("Model")
	model.Name = "AuraBot"
	local cf = CFrame.lookAt(position, Vector3.new(facing.X, position.Y, facing.Z))
	local dark = Color3.fromRGB(40, 30, 55)
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		return Builder.Part({
			Name = name,
			Size = size,
			CFrame = cf * offset,
			Material = material or Enum.Material.SmoothPlastic,
			Color = color,
			CanCollide = false,
			Parent = model,
		})
	end
	piece("LeftLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), dark)
	piece("RightLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), dark)
	local torso = piece("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), dark)
	local head = piece("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 4.65, 0), dark)
	piece("Visor", Vector3.new(1.1, 0.35, 0.1), CFrame.new(0, 4.75, -0.66), BOT_COLOR, Enum.Material.Neon)
	piece("Core", Vector3.new(0.8, 0.8, 0.1), CFrame.new(0, 3.2, -0.52), BOT_COLOR, Enum.Material.Neon)
	-- Armen naar voren, alsof hij een energiestraal afvuurt
	for _, side in { 1, -1 } do
		piece("Arm", Vector3.new(1, 2, 1), CFrame.new(1.5 * side, 3.9, 0) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, -0.9, 0), dark)
	end
	Builder.Sparkles(torso, BOT_COLOR, 20)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 0.6, -1.4)
	attachment.Parent = torso
	local label = Builder.Billboard(head, "🤖 AURA BOT  Lv " .. level, UDim2.new(8, 0, 1.3, 0), Vector3.new(0, 2.2, 0), BOT_COLOR)
	label.Parent.Name = "BotTag"
	model.PrimaryPart = torso
	model.Parent = stage.Folder
	return model, attachment
end

------------------------------------------------------------------------
-- Battle starten en beëindigen
------------------------------------------------------------------------

local function freeze(player: Player, position: Vector3, facing: Vector3)
	local root = rootOf(player)
	if not root then
		return nil
	end
	PoseService.Stop(player)
	local standAt = position + Vector3.new(0, 3, 0)
	root.CFrame = CFrame.lookAt(standAt, Vector3.new(facing.X, standAt.Y, facing.Z))
	root.Anchored = true
	player:SetAttribute("BattlePose", "Battle")
	local attachment = Instance.new("Attachment")
	attachment.Name = "BattleBeam"
	attachment.Position = Vector3.new(0, 0.6, -1.6)
	attachment.Parent = root
	return attachment
end

local function release(fighter: Fighter)
	local player = fighter.Player
	if player then
		fighterByPlayer[player] = nil
		needsStepOff[player] = true
		player:SetAttribute("BattlePose", nil)
		local root = rootOf(player)
		if root then
			root.Anchored = false
		end
	end
	if fighter.Attachment then
		fighter.Attachment:Destroy()
	end
	if fighter.Bot then
		local bot = fighter.Bot
		task.delay(1.5, function()
			bot:Destroy()
		end)
	end
end

local function makeFighter(player: Player): Fighter
	local data = DataService.Get(player)
	return {
		Player = player,
		Bot = nil,
		Name = player.DisplayName,
		Level = if data then data.Level else 1,
		Power = powerFor(player),
		Total = 0,
		Tokens = 2,
		Color = auraColor(player),
		Attachment = nil,
	}
end

local function startBattle(stage: Stage, first: Player, second: Player?)
	local a = makeFighter(first)
	local b: Fighter
	if second then
		b = makeFighter(second)
	else
		local botLevel = math.max(1, a.Level + math.random(-2, 1))
		b = {
			Player = nil,
			Bot = nil,
			Name = "Aura Bot",
			Level = botLevel,
			Power = Levels.BattlePower(botLevel),
			Total = 0,
			Tokens = 0,
			Color = BOT_COLOR,
			Attachment = nil,
		}
	end

	a.Attachment = freeze(first, stage.A, stage.B)
	if second then
		b.Attachment = freeze(second, stage.B, stage.A)
	else
		local bot, attachment = buildBot(stage, stage.B, stage.A, b.Level)
		b.Bot = bot
		b.Attachment = attachment
	end
	if not a.Attachment or not b.Attachment then
		release(a)
		release(b)
		return
	end

	fighterByPlayer[first] = a
	if second then
		fighterByPlayer[second] = b
	end
	stage.Fighters = { a, b }
	stage.Phase = "Countdown"
	stage.PhaseEnds = os.clock() + Settings.CountdownSeconds
	stage.WaitStart = nil
	stage.Label.Text = "⚔️ " .. a.Name .. "  VS  " .. b.Name .. " ⚔️"

	-- Botsbal in het midden met twee aura-stralen
	local middle = (stage.A + stage.B) / 2 + Vector3.new(0, 3.6, 0)
	local ball = Builder.Part({
		Name = "ClashBall",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3.5,
		CFrame = CFrame.new(middle),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 245, 200),
		CanCollide = false,
		CanQuery = false,
		Parent = stage.Folder,
	})
	Builder.Sparkles(ball, Color3.fromRGB(255, 230, 150), 40)
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 230, 160)
	light.Parent = ball
	local ballAttachment = Instance.new("Attachment")
	ballAttachment.Parent = ball
	stage.Ball = ball
	stage.BallAttachment = ballAttachment
	stage.Beams = {}
	for _, fighter in stage.Fighters do
		local beam = Instance.new("Beam")
		beam.Attachment0 = fighter.Attachment
		beam.Attachment1 = ballAttachment
		beam.Color = ColorSequence.new(fighter.Color, Color3.fromRGB(255, 255, 255))
		beam.LightEmission = 1
		beam.Width0 = 1.2
		beam.Width1 = 2.6
		beam.FaceCamera = true
		beam.Segments = 12
		beam.CurveSize0 = 0
		beam.Transparency = NumberSequence.new(0.1)
		beam.Enabled = false
		beam.Parent = ball
		table.insert(stage.Beams, beam)
	end

	local endsAt = workspace:GetServerTimeNow() + Settings.CountdownSeconds
	send(a, { Phase = "Countdown", EndsAt = endsAt, Opponent = b.Name, OpponentLevel = b.Level })
	send(b, { Phase = "Countdown", EndsAt = endsAt, Opponent = a.Name, OpponentLevel = a.Level })
end

-- Positief = speler A wint, negatief = speler B wint (van -1 tot 1)
local function lead(stage: Stage): number
	local a, b = stage.Fighters[1], stage.Fighters[2]
	return math.clamp((a.Total - b.Total) / (a.Total + b.Total + 15), -1, 1)
end

local function rewardAmount(player: Player, minutes: number): number
	local data = DataService.Get(player)
	local minimum = Settings.MinimumReward * ((data and data.Rebirths or 0) + 1)
	return math.floor(math.max(minimum, Economy.BaseIncomePerSecond(player) * minutes * 60))
end

local function finishBattle(stage: Stage, forfeit: Fighter?)
	local a, b = stage.Fighters[1], stage.Fighters[2]
	local winner, loser
	if forfeit then
		winner = if forfeit == a then b else a
		loser = forfeit
	elseif a.Total == b.Total then
		if math.random() < 0.5 then
			winner, loser = a, b
		else
			winner, loser = b, a
		end
	elseif a.Total > b.Total then
		winner, loser = a, b
	else
		winner, loser = b, a
	end
	local vsBot = a.Bot ~= nil or b.Bot ~= nil

	-- Explosie bij de verliezer
	local ball = stage.Ball
	if ball and loser.Attachment then
		local target = loser.Attachment.WorldPosition
		TweenService:Create(ball, TweenInfo.new(0.25), { CFrame = CFrame.new(target), Size = Vector3.one * 9, Transparency = 1 }):Play()
		local boom = Instance.new("ParticleEmitter")
		boom.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		boom.Color = ColorSequence.new(winner.Color, Color3.fromRGB(255, 255, 255))
		boom.LightEmission = 1
		boom.Rate = 0
		boom.Lifetime = NumberRange.new(0.8, 1.5)
		boom.Speed = NumberRange.new(25, 45)
		boom.SpreadAngle = Vector2.new(180, 180)
		boom.Size = NumberSequence.new(1.6, 0)
		boom.Parent = ball
		boom:Emit(150)
	end
	for _, beam in stage.Beams do
		beam.Enabled = false
	end

	-- Beloningen
	if winner.Player and winner.Player.Parent then
		local player = winner.Player
		local data = DataService.Get(player)
		local amount = rewardAmount(player, if vsBot then Settings.BotWinMinutes else Settings.WinMinutes)
		DataService.AddAura(player, amount)
		if data and not vsBot then
			data.BattleWins += 1
			local stats = player:FindFirstChild("leaderstats")
			local wins = stats and stats:FindFirstChild("Wins") :: IntValue?
			if wins then
				wins.Value = data.BattleWins
			end
		end
		send(winner, { Phase = "End", Won = true, Reward = amount, Opponent = loser.Name })
		notify(player, "🏆 You won the Aura Battle! +" .. Format.Number(amount) .. " Aura", "rare")
		Bus.Fire("BattleEnded", player, true, vsBot)
		local root = rootOf(player)
		if root then
			popup(root, "+1000 AURA", Color3.fromRGB(255, 230, 120))
		end
	end
	if loser.Player and loser.Player.Parent then
		local player = loser.Player
		local data = DataService.Get(player)
		if data and not vsBot then
			data.BattleLosses += 1
		end
		send(loser, { Phase = "End", Won = false, Reward = 0, Opponent = winner.Name, Knockback = true })
		Bus.Fire("BattleEnded", player, false, vsBot)
		local root = rootOf(player)
		if root then
			popup(root, "-1000 AURA", Color3.fromRGB(160, 160, 170))
		end
	end
	if loser.Bot and loser.Bot.PrimaryPart then
		popup(loser.Bot.PrimaryPart, "-1000 AURA", Color3.fromRGB(160, 160, 170))
	end
	if not vsBot then
		for _, other in Players:GetPlayers() do
			notify(other, "⚔️ " .. winner.Name .. " beat " .. loser.Name .. " in an AURA BATTLE!", if other == winner.Player then "success" else "info")
		end
	end

	stage.Label.Text = "🏆 " .. winner.Name .. " WINS! 🏆"
	release(a)
	release(b)
	stage.Fighters = {}
	stage.Beams = {}
	if ball then
		Debris:AddItem(ball, 1)
	end
	stage.Ball = nil
	stage.BallAttachment = nil
	stage.Phase = "Cooldown"
	stage.PhaseEnds = os.clock() + 3
end

------------------------------------------------------------------------
-- Elke tick
------------------------------------------------------------------------

local function fighterGone(fighter: Fighter): boolean
	return fighter.Player ~= nil and (not fighter.Player.Parent or rootOf(fighter.Player) == nil)
end

local function updateIdle(stage: Stage, now: number)
	local onA, onB = nil, nil
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and not fighterByPlayer[player] then
			local atA, atB = onPad(root, stage.A), onPad(root, stage.B)
			if (atA or atB) and needsStepOff[player] then
				continue
			end
			if atA and not onA then
				onA = player
			elseif atB and not onB then
				onB = player
			end
		end
	end

	if onA and onB then
		startBattle(stage, onA, onB)
	elseif onA or onB then
		local alone = (onA or onB) :: Player
		-- Iemand alleen op plek B? Dan draaien we het om zodat hij op A staat
		if onB then
			stage.A, stage.B = stage.B, stage.A
		end
		stage.WaitStart = stage.WaitStart or now
		local left = Settings.BotWaitSeconds - (now - (stage.WaitStart :: number))
		if left <= 0 then
			startBattle(stage, alone, nil)
		else
			stage.Label.Text = "Waiting for an opponent...  🤖 Aura Bot in " .. math.ceil(left)
		end
	else
		stage.WaitStart = nil
		stage.Label.Text = "⚔️ AURA BATTLE ⚔️\nStand on a glowing circle!"
	end
end

local function updateFight(stage: Stage, dt: number)
	local a, b = stage.Fighters[1], stage.Fighters[2]
	for _, fighter in stage.Fighters do
		if fighter.Bot then
			fighter.Total += fighter.Power * BOT_TAPS_PER_SECOND * dt * (0.6 + math.random() * 0.8)
		else
			fighter.Tokens = math.min(Settings.MaxTapsPerSecond, fighter.Tokens + dt * Settings.MaxTapsPerSecond)
		end
	end

	local value = lead(stage)
	if stage.Ball then
		local from = stage.A + Vector3.new(0, 3.6, 0)
		local to = stage.B + Vector3.new(0, 3.6, 0)
		local t = 0.5 + value * 0.42
		stage.Ball.CFrame = CFrame.new(from:Lerp(to, t))
		stage.Ball.Size = Vector3.one * (3.5 + math.min(6, (a.Total + b.Total) / 60))
	end

	stage.SendTimer -= dt
	if stage.SendTimer <= 0 then
		stage.SendTimer = 0.2
		local endsAt = workspace:GetServerTimeNow() + (stage.PhaseEnds - os.clock())
		send(a, { Phase = "Fight", EndsAt = endsAt, Mine = a.Total, Theirs = b.Total, Lead = value, Opponent = b.Name })
		send(b, { Phase = "Fight", EndsAt = endsAt, Mine = b.Total, Theirs = a.Total, Lead = -value, Opponent = a.Name })
	end

	if math.abs(value) >= Settings.KnockoutLead and a.Total + b.Total > 40 then
		finishBattle(stage)
	end
end

local function tick(dt: number)
	local now = os.clock()
	for _, stage in stages do
		-- Weggelopen of dood gegaan tijdens een battle? Dan wint de ander
		if stage.Phase == "Countdown" or stage.Phase == "Fight" then
			for _, fighter in stage.Fighters do
				if fighterGone(fighter) then
					finishBattle(stage, fighter)
					break
				end
			end
		end

		if stage.Phase == "Idle" then
			updateIdle(stage, now)
		elseif stage.Phase == "Countdown" then
			stage.Label.Text = "⚔️ " .. stage.Fighters[1].Name .. "  VS  " .. stage.Fighters[2].Name .. " ⚔️\n" .. math.max(1, math.ceil(stage.PhaseEnds - now))
			if now >= stage.PhaseEnds then
				stage.Phase = "Fight"
				stage.PhaseEnds = now + Settings.FightSeconds
				stage.SendTimer = 0
				for _, beam in stage.Beams do
					beam.Enabled = true
				end
			end
		elseif stage.Phase == "Fight" then
			stage.Label.Text = "⚔️ " .. stage.Fighters[1].Name .. "  VS  " .. stage.Fighters[2].Name .. " ⚔️\nTAP TAP TAP! " .. math.max(0, math.ceil(stage.PhaseEnds - now))
			updateFight(stage, dt)
			if stage.Phase == "Fight" and now >= stage.PhaseEnds then
				finishBattle(stage)
			end
		elseif stage.Phase == "Cooldown" and now >= stage.PhaseEnds then
			stage.Phase = "Idle"
		end
	end

	-- Wie van een plek af is gestapt mag weer meedoen
	for player in needsStepOff do
		local root = rootOf(player)
		local still = false
		if root then
			for _, stage in stages do
				if onPad(root, stage.A) or onPad(root, stage.B) then
					still = true
				end
			end
		end
		if not still or not player.Parent then
			needsStepOff[player] = nil
		end
	end
end

local function onTap(player: Player)
	local fighter = fighterByPlayer[player]
	if not fighter then
		return
	end
	for _, stage in stages do
		if stage.Phase == "Fight" and (stage.Fighters[1] == fighter or stage.Fighters[2] == fighter) then
			if fighter.Tokens >= 1 then
				fighter.Tokens -= 1
				fighter.Total += fighter.Power
			end
			return
		end
	end
end

------------------------------------------------------------------------
-- Opbouwen
------------------------------------------------------------------------

local function buildPad(position: Vector3, color: Color3, parent: Instance)
	local pad = Builder.Part({
		Name = "BattlePad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, PAD_RADIUS * 2, PAD_RADIUS * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.15,
		Parent = parent,
	})
	local ring = Builder.Part({
		Name = "BattlePadRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, PAD_RADIUS * 2 + 1.2, PAD_RADIUS * 2 + 1.2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.5,
		Parent = parent,
	})
	ring:SetAttribute("Pulse", 0.4)
	game:GetService("CollectionService"):AddTag(ring, "Fx")
	local emitter = Builder.Sparkles(pad, color, 6)
	emitter.Acceleration = Vector3.new(0, 6, 0)
	return pad
end

function BattleService.Init(map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Battles"
	folder.Parent = map

	for index, spot in MapBuilder.Spots.Stages do
		local stageFolder = Instance.new("Folder")
		stageFolder.Name = "Stage" .. index
		stageFolder.Parent = folder
		buildPad(spot.A, Color3.fromRGB(90, 170, 255), stageFolder)
		buildPad(spot.B, Color3.fromRGB(255, 90, 170), stageFolder)
		local anchor = Builder.Part({
			Name = "StageLabel",
			Size = Vector3.one,
			CFrame = CFrame.new((spot.A + spot.B) / 2 + Vector3.new(0, 9, 0)),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Parent = stageFolder,
		})
		local label = Builder.Billboard(anchor, "", UDim2.new(18, 0, 3.2, 0), Vector3.zero, Color3.fromRGB(255, 230, 140))
		table.insert(stages, {
			Index = index,
			A = spot.A,
			B = spot.B,
			Folder = stageFolder,
			Label = label,
			Phase = "Idle",
			PhaseEnds = 0,
			WaitStart = nil,
			Fighters = {},
			Ball = nil,
			BallAttachment = nil,
			Beams = {},
			SendTimer = 0,
		})
	end

	Remotes.BattleTap.OnServerEvent:Connect(onTap)
	Players.PlayerRemoving:Connect(function(player)
		needsStepOff[player] = nil
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= TICK then
			tick(accumulator)
			accumulator = 0
		end
	end)
end

return BattleService
