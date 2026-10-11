-- Alles wat beweegt in de wereld, alleen op de computer van de speler (soepel en zonder lag):
-- * Onderdelen met de tag "Fx" draaien (Spin), zweven (Bob) of knipperen (Pulse)
-- * Lopende banden krijgen bewegende streepjes
-- * Nieuw gekochte dingen vallen met een plopje in beeld
-- * "+12" boven de Aura Collector als een orb binnenkomt, en "+5K Aura" bij het ophalen
-- * Een draaiende aura-ring onder iedereen die aan het posen is

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local rad = math.rad
local sin = math.sin

local effects = Instance.new("Folder")
effects.Name = "LocalEffects"
effects.Parent = workspace

------------------------------------------------------------------------
-- Geluid
------------------------------------------------------------------------

local function playSound(id: string, pitch: number, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.PlaybackSpeed = pitch
	sound.Volume = volume
	sound.Parent = SoundService
	SoundService:PlayLocalSound(sound)
	Debris:AddItem(sound, 3)
end

local PING = "rbxasset://sounds/electronicpingshort.wav"

------------------------------------------------------------------------
-- Hulpjes
------------------------------------------------------------------------

local function myPlot(): Instance?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function burst(position: Vector3, color: Color3, amount: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.Size = NumberSequence.new(0.7, 0)
	emitter.Parent = attachment
	emitter:Emit(amount)
	Debris:AddItem(attachment, 1.5)
end

local function floatingText(position: Vector3, text: string, color: Color3, size: number, rise: number, seconds: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(size * 4, 0, size, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.AlwaysOnTop = true
	gui.Adornee = attachment
	gui.Parent = attachment
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

	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, rise, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(seconds * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, seconds * 0.4), { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, TweenInfo.new(seconds * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, seconds * 0.4), { Transparency = 1 }):Play()
	Debris:AddItem(attachment, seconds + 0.1)
end

------------------------------------------------------------------------
-- Draaien, zweven en knipperen (tag "Fx")
------------------------------------------------------------------------

type Fx = { Home: CFrame, Spin: number, Bob: number, Pulse: number, Base: number, Phase: number }
local fxParts: { [BasePart]: Fx } = {}

local function addFx(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local position = instance.Position
	fxParts[instance] = {
		Home = instance.CFrame,
		Spin = instance:GetAttribute("Spin") or 0,
		Bob = instance:GetAttribute("Bob") or 0,
		Pulse = instance:GetAttribute("Pulse") or 0,
		Base = instance.Transparency,
		Phase = (position.X + position.Z) * 0.13,
	}
end

for _, instance in CollectionService:GetTagged("Fx") do
	addFx(instance)
end
CollectionService:GetInstanceAddedSignal("Fx"):Connect(addFx)
CollectionService:GetInstanceRemovedSignal("Fx"):Connect(function(instance)
	fxParts[instance :: BasePart] = nil
end)

------------------------------------------------------------------------
-- Lopende banden: streepjes die meebewegen
------------------------------------------------------------------------

local STRIPES = 8
local BELT_LENGTH = 66
type Belt = { Stripes: { BasePart } }
local belts: { [BasePart]: Belt } = {}

local function addBelt(instance: Instance)
	if not instance:IsA("BasePart") or belts[instance] then
		return
	end
	local stripes = {}
	for _ = 1, STRIPES do
		local stripe = Instance.new("Part")
		stripe.Name = "BeltStripe"
		stripe.Anchored = true
		stripe.CanCollide = false
		stripe.CanQuery = false
		stripe.CanTouch = false
		stripe.CastShadow = false
		stripe.Material = Enum.Material.SmoothPlastic
		stripe.Color = Color3.fromRGB(110, 110, 120)
		stripe.Size = Vector3.new(0.6, 0.05, instance.Size.Z - 0.6)
		stripe.Parent = effects
		table.insert(stripes, stripe)
	end
	belts[instance] = { Stripes = stripes }
end

local function removeBelt(instance: Instance)
	local belt = belts[instance :: BasePart]
	if belt then
		for _, stripe in belt.Stripes do
			stripe:Destroy()
		end
		belts[instance :: BasePart] = nil
	end
end

for _, instance in CollectionService:GetTagged("Conveyor") do
	addBelt(instance)
end
CollectionService:GetInstanceAddedSignal("Conveyor"):Connect(addBelt)
CollectionService:GetInstanceRemovedSignal("Conveyor"):Connect(removeBelt)

------------------------------------------------------------------------
-- Aura ring onder spelers die posen
------------------------------------------------------------------------

local rings: { [Player]: BasePart } = {}

local function ringFor(other: Player): BasePart
	local ring = rings[other]
	if ring and ring.Parent then
		return ring
	end
	local part = Instance.new("Part")
	part.Name = "PoseRing"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(200, 140, 255)
	part.Transparency = 0.45
	part.Size = Vector3.new(0.2, 7, 7)
	part.Parent = effects
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(200, 140, 255))
	emitter.LightEmission = 1
	emitter.Rate = 25
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(3, 6)
	emitter.EmissionDirection = Enum.NormalId.Right
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Size = NumberSequence.new(0.6, 0)
	emitter.Parent = part
	rings[other] = part
	return part
end

------------------------------------------------------------------------
-- Elke frame
------------------------------------------------------------------------

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero

	for part, fx in fxParts do
		if not part.Parent then
			fxParts[part] = nil
			continue
		end
		if (fx.Home.Position - cameraPosition).Magnitude > 350 then
			continue
		end
		if fx.Spin ~= 0 or fx.Bob ~= 0 then
			local position = fx.Home.Position + Vector3.new(0, sin(t * 2 + fx.Phase) * fx.Bob, 0)
			part.CFrame = CFrame.new(position) * CFrame.Angles(0, rad(fx.Spin) * t, 0) * fx.Home.Rotation
		end
		if fx.Pulse ~= 0 then
			part.Transparency = math.clamp(fx.Base + (sin(t * 3 + fx.Phase) * 0.5 + 0.5) * fx.Pulse, 0, 1)
		end
	end

	local spacing = BELT_LENGTH / STRIPES
	local shift = (t * Config.ConveyorSpeed) % spacing
	for conveyor, belt in belts do
		if not conveyor.Parent then
			removeBelt(conveyor)
			continue
		end
		local base = conveyor.CFrame
		local top = conveyor.Size.Y / 2 + 0.03
		for index, stripe in belt.Stripes do
			local x = -BELT_LENGTH / 2 + shift + (index - 1) * spacing
			stripe.CFrame = base * CFrame.new(x, top, 0)
		end
	end

	for _, other in Players:GetPlayers() do
		local posing = other:GetAttribute("Posing") ~= nil
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if posing and root and humanoid then
			local ring = ringFor(other)
			local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 3 else humanoid.HipHeight + root.Size.Y / 2
			local feet = root.Position - Vector3.new(0, legs - 0.1, 0)
			ring.CFrame = CFrame.new(feet) * CFrame.Angles(0, t * 2, 0) * CFrame.Angles(0, 0, rad(90))
			ring.Size = Vector3.new(0.2, 7 + sin(t * 4) * 0.6, 7 + sin(t * 4) * 0.6)
		elseif rings[other] then
			rings[other]:Destroy()
			rings[other] = nil
		end
	end
end)

Players.PlayerRemoving:Connect(function(other)
	if rings[other] then
		rings[other]:Destroy()
		rings[other] = nil
	end
end)

------------------------------------------------------------------------
-- Nieuwe dingen vallen met een plopje in beeld
------------------------------------------------------------------------

local plotsFolder = workspace:WaitForChild("Plots")
local stagger: { [Instance]: number } = {}

plotsFolder.DescendantAdded:Connect(function(instance)
	if not instance:IsA("BasePart") or CollectionService:HasTag(instance, "Fx") then
		return
	end
	local model = instance.Parent
	if not model or not model:IsA("Model") then
		return
	end
	local builtAt = model:GetAttribute("BuiltAt")
	if type(builtAt) ~= "number" or workspace:GetServerTimeNow() - builtAt > 2 then
		return
	end

	local index = stagger[model]
	if not index then
		index = 0
		local first = instance
		task.delay(0.15, function()
			if first.Parent then
				burst(first.Position, Color3.fromRGB(255, 230, 140), 30)
			end
			local plot = model:FindFirstAncestorWhichIsA("Model")
			if plot and plot:GetAttribute("OwnerId") == player.UserId then
				playSound(PING, 1.6, 0.4)
			end
		end)
		model.Destroying:Once(function()
			stagger[model] = nil
		end)
		task.delay(3, function()
			stagger[model] = nil
		end)
	end
	stagger[model] = index + 1

	local target = instance.CFrame
	local transparency = instance.Transparency
	instance.CFrame = target + Vector3.new(0, 7, 0)
	instance.Transparency = 1
	task.delay(math.min(index, 25) * 0.025, function()
		if instance.Parent then
			TweenService:Create(instance, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				CFrame = target,
				Transparency = transparency,
			}):Play()
		end
	end)
end)

------------------------------------------------------------------------
-- "+12" bij de collector en "+5K Aura" bij het ophalen
------------------------------------------------------------------------

local lastOrbPopup = 0
plotsFolder.DescendantRemoving:Connect(function(instance)
	if instance.Name ~= "AuraOrb" or not instance:IsA("BasePart") or not instance:GetAttribute("Collected") then
		return
	end
	local plot = myPlot()
	if not plot or not instance:IsDescendantOf(plot) then
		return
	end
	local now = os.clock()
	if now - lastOrbPopup < 0.12 then
		return
	end
	lastOrbPopup = now
	local value = instance:GetAttribute("Value")
	if type(value) == "number" then
		floatingText(instance.Position + Vector3.new(0, 3, 0), "+" .. Format.Number(value), instance.Color, 1.4, 4, 0.9)
	end
	burst(instance.Position, instance.Color, 6)
end)

Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text, kind)
	if kind ~= "collect" then
		return
	end
	local plot = myPlot()
	local pad = plot and plot:FindFirstChild("CollectPad") :: BasePart?
	if pad then
		floatingText(pad.Position + Vector3.new(0, 4, 0), text, Color3.fromRGB(255, 225, 90), 3, 8, 1.6)
		burst(pad.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 215, 80), 60)
	end
	playSound(PING, 1.25, 0.5)
end)
