-- Aura rollen, aura's aandoen en het effect om je character heen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Auras = require(ReplicatedStorage.Shared.Auras)
local Format = require(ReplicatedStorage.Shared.Format)
local Bus = require(script.Parent.Bus)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)

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
	label.Text = if player:GetAttribute("Pass_VIP") then "[VIP] " .. aura.Name else aura.Name
	label.TextColor3 = if aura.Name == "Void Aura" then Color3.fromRGB(190, 120, 255) else aura.Color
	label.Parent = tag
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
end

local function giveAura(player: Player, data, aura)
	local discoveredBefore = Economy.DiscoveredCount(data)
	local isNew = data.OwnedAuras[aura.Name] == nil
	data.OwnedAuras[aura.Name] = (data.OwnedAuras[aura.Name] or 0) + 1

	local current = Auras.ByName[data.EquippedAura]
	local equipped = false
	if not current or aura.Multiplier > current.Multiplier then
		data.EquippedAura = aura.Name
		equipped = true
		AuraService.ApplyVisual(player)
	end

	-- Nieuwe Index-trede gehaald?
	local discoveredAfter = Economy.DiscoveredCount(data)
	for _, tier in Config.IndexTiers do
		if discoveredBefore < tier.Count and discoveredAfter >= tier.Count then
			task.delay(1.6, notify, player, "Aura Index " .. tier.Count .. "/" .. #Auras.List .. "! Permanent +" .. math.floor(tier.Luck * 100) .. "% Luck", "rare")
		end
	end
	return isNew, equipped
end

function AuraService.GiveExclusive(player: Player, auraName: string)
	local data = DataService.Get(player)
	local aura = Auras.ByName[auraName]
	if not data or not aura then
		return
	end
	giveAura(player, data, aura)
	DataService.Changed(player)
end

function AuraService.FreeRollWait(data): number
	return math.max(0, data.LastFreeRoll + Config.FreeRollCooldown - os.time())
end

function AuraService.Roll(player: Player, free: boolean, silentFail: boolean?): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local now = os.clock()
	if lastRoll[player] and now - lastRoll[player] < Config.RollCooldown then
		return false
	end

	if free then
		local waitLeft = AuraService.FreeRollWait(data)
		if waitLeft > 0 then
			if not silentFail then
				notify(player, "Free roll ready in " .. Format.Time(waitLeft), "error")
			end
			return false
		end
		data.LastFreeRoll = os.time()
	else
		local cost = Config.RollCost(data.Rebirths)
		if data.Aura < cost then
			if not silentFail then
				notify(player, "You need " .. Format.Number(cost) .. " Aura to roll!", "error")
			end
			return false
		end
		data.Aura -= cost
	end
	lastRoll[player] = now

	-- Pity: na veel pech krijg je gegarandeerd een zeldzame aura
	data.RollCount += 1
	data.PityCounter += 1
	local aura
	if data.PityCounter >= Config.PityRolls then
		aura = Auras.Roll(Economy.GetLuck(player), rng, Config.PityMinChance)
	else
		aura = Auras.Roll(Economy.GetLuck(player), rng)
	end
	if aura.Chance >= Config.PityMinChance then
		data.PityCounter = 0
	end

	local isNew, equipped = giveAura(player, data, aura)
	DataService.Changed(player)
	Remotes.RollResult:FireClient(player, aura.Name, isNew, equipped)
	Bus.Fire("Rolled", player, aura, free)

	if aura.Chance >= Config.AnnounceChance then
		-- Even wachten zodat de speler zelf eerst de animatie ziet
		task.delay(1.5, function()
			for _, other in Players:GetPlayers() do
				notify(other, player.DisplayName .. " rolled " .. aura.Name .. " (" .. Auras.RarityText(aura) .. ")!", "rare")
			end
		end)
	end
	return true
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
	Remotes.SetAutoRoll.OnServerEvent:Connect(function(player, enabled)
		local data = DataService.Get(player)
		if enabled == true and data and data.Rebirths < Config.AutoRollRebirths then
			notify(player, "Auto Roll unlocks after your first Rebirth!", "error")
			return
		end
		player:SetAttribute("AutoRoll", enabled == true)
		DataService.Changed(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRoll[player] = nil
	end)

	-- Auto Roll: gebruikt eerst de gratis roll, anders Aura. Stopt als je te weinig Aura hebt.
	task.spawn(function()
		while true do
			task.wait(Config.AutoRollInterval)
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if player:GetAttribute("AutoRoll") and data then
					local rolled = AuraService.FreeRollWait(data) <= 0 and AuraService.Roll(player, true, true)
					if not rolled and not AuraService.Roll(player, false, true) and data.Aura < Config.RollCost(data.Rebirths) then
						player:SetAttribute("AutoRoll", false)
						notify(player, "Auto Roll stopped: not enough Aura", "error")
						DataService.Changed(player)
					end
				end
			end
		end
	end)
end

return AuraService
