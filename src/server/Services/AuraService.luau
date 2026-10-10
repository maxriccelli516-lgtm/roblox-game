-- Aura rollen, aura's aandoen en het effect om je character heen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Auras = require(ReplicatedStorage.Shared.Auras)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)

local Remotes = ReplicatedStorage.Remotes

local AuraService = {}

local lastRoll: { [Player]: number } = {}
local rng = Random.new()

local function notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

function AuraService.ApplyVisual(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not root or not head then
		return
	end
	local old = root:FindFirstChild("AuraFX")
	if old then
		old:Destroy()
	end
	local oldTag = head:FindFirstChild("AuraTag")
	if oldTag then
		oldTag:Destroy()
	end

	local data = DataService.Get(player)
	local aura = data and Auras.ByName[data.EquippedAura]
	if not aura then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "AuraFX"
	attachment.Parent = root

	local color = if aura.Rainbow
		then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 255, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 60, 255)),
		})
		else ColorSequence.new(aura.Color)

	-- Hoe zeldzamer, hoe meer deeltjes
	local power = math.clamp(math.log(aura.Chance + 1, 10), 0.3, 4)

	local glow = Instance.new("ParticleEmitter")
	glow.Name = "Glow"
	glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glow.Color = color
	glow.LightEmission = 1
	glow.Rate = 10 + power * 15
	glow.Lifetime = NumberRange.new(0.8, 1.6)
	glow.Speed = NumberRange.new(1, 2 + power)
	glow.SpreadAngle = Vector2.new(180, 180)
	glow.Acceleration = Vector3.new(0, 4, 0)
	glow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4 + power * 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	glow.Parent = attachment

	if aura.Chance >= 64 then
		local flames = Instance.new("ParticleEmitter")
		flames.Name = "Flames"
		flames.Texture = "rbxasset://textures/particles/fire_main.dds"
		flames.Color = color
		flames.LightEmission = 1
		flames.Rate = 20 + power * 10
		flames.Lifetime = NumberRange.new(0.5, 1)
		flames.Speed = NumberRange.new(2, 4)
		flames.SpreadAngle = Vector2.new(25, 25)
		flames.EmissionDirection = Enum.NormalId.Top
		flames.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2),
			NumberSequenceKeypoint.new(1, 0),
		})
		flames.Transparency = NumberSequence.new(0.4, 1)
		flames.Parent = attachment
	end

	local light = Instance.new("PointLight")
	light.Color = aura.Color
	light.Range = 8 + power * 3
	light.Brightness = 1 + power * 0.5
	light.Parent = attachment

	local tag = Instance.new("BillboardGui")
	tag.Name = "AuraTag"
	tag.Size = UDim2.new(8, 0, 1.2, 0)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 80
	tag.LightInfluence = 0
	tag.Adornee = head
	tag.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = aura.Name
	label.TextColor3 = if aura.Name == "Void Aura" then Color3.fromRGB(190, 120, 255) else aura.Color
	label.Parent = tag
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
end

local function giveAura(player: Player, data, aura)
	local isNew = data.OwnedAuras[aura.Name] == nil
	data.OwnedAuras[aura.Name] = (data.OwnedAuras[aura.Name] or 0) + 1
	data.RollCount += 1

	local current = Auras.ByName[data.EquippedAura]
	local equipped = false
	if not current or aura.Multiplier > current.Multiplier then
		data.EquippedAura = aura.Name
		equipped = true
		AuraService.ApplyVisual(player)
	end
	return isNew, equipped
end

function AuraService.Roll(player: Player, free: boolean)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local now = os.clock()
	if lastRoll[player] and now - lastRoll[player] < Config.RollCooldown then
		return
	end

	if free then
		local waitLeft = data.LastFreeRoll + Config.FreeRollCooldown - os.time()
		if waitLeft > 0 then
			notify(player, "Free roll ready in " .. Format.Time(waitLeft), "error")
			return
		end
		data.LastFreeRoll = os.time()
	else
		local cost = Config.RollCost(data.Rebirths)
		if data.Aura < cost then
			notify(player, "You need " .. Format.Number(cost) .. " Aura to roll!", "error")
			return
		end
		data.Aura -= cost
	end
	lastRoll[player] = now

	local aura = Auras.Roll(1, rng)
	local isNew, equipped = giveAura(player, data, aura)
	DataService.Changed(player)
	Remotes.RollResult:FireClient(player, aura.Name, isNew, equipped)

	if aura.Chance >= Config.AnnounceChance then
		-- Even wachten zodat de speler zelf eerst de animatie ziet
		task.delay(1.5, function()
			for _, other in Players:GetPlayers() do
				notify(other, player.DisplayName .. " rolled " .. aura.Name .. " (" .. Auras.RarityText(aura) .. ")!", "rare")
			end
		end)
	end
end

function AuraService.Equip(player: Player, auraName: string)
	local data = DataService.Get(player)
	if not data or type(auraName) ~= "string" or not data.OwnedAuras[auraName] then
		return
	end
	data.EquippedAura = auraName
	AuraService.ApplyVisual(player)
	DataService.Changed(player)
end

function AuraService.Init()
	Remotes.RollAura.OnServerEvent:Connect(function(player, free)
		AuraService.Roll(player, free == true)
	end)
	Remotes.EquipAura.OnServerEvent:Connect(function(player, auraName)
		AuraService.Equip(player, auraName)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRoll[player] = nil
	end)
end

return AuraService
