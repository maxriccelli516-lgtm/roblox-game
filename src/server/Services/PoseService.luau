-- Aura farmen: sta stil in een coole pose (zoals de boat kid). Je Aura Meter loopt vol
-- en dan krijg je PEAK AURA (2x Aura). Elke paar seconden verschijnt "+1000 AURA" boven je hoofd.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local BoostService = require(script.Parent.BoostService)
local Bus = require(script.Parent.Bus)
local Economy = require(script.Parent.Economy)

local Remotes = ReplicatedStorage.Remotes

local PoseService = {}

local UPDATE_RATE = 1 / 15
local POPUP_EVERY = 3
local POPUP_TEXTS = { "+1000 AURA", "+1000 AURA", "AURA FARMING", "+500 AURA", "PEAK AURA SOON", "+9999 AURA" }

local rad = math.rad
local sin = math.sin

-- Elke pose geeft per gewricht (R15) een draaiing terug, afhankelijk van de tijd t
local POSES = {
	BoatKid = function(t: number)
		local beat = t * 5
		return {
			RightShoulder = CFrame.Angles(rad(55 + 40 * sin(beat)), 0, rad(10)),
			LeftShoulder = CFrame.Angles(rad(55 + 40 * sin(beat + math.pi)), 0, rad(-10)),
			Waist = CFrame.Angles(0, rad(14 * sin(beat / 2)), 0),
			Neck = CFrame.Angles(rad(6 * sin(beat)), rad(-10 * sin(beat / 2)), 0),
		}
	end,
	SkyPoint = function(t: number)
		return {
			RightShoulder = CFrame.Angles(rad(165), 0, rad(-8)),
			LeftShoulder = CFrame.Angles(0, 0, rad(-12)),
			Neck = CFrame.Angles(rad(18 + 2 * sin(t * 2)), 0, 0),
			Waist = CFrame.Angles(rad(-6), 0, 0),
		}
	end,
	Sigma = function(t: number)
		return {
			RightShoulder = CFrame.Angles(0, rad(55), 0) * CFrame.Angles(rad(85), 0, 0),
			LeftShoulder = CFrame.Angles(0, rad(-55), 0) * CFrame.Angles(rad(80), 0, 0),
			Neck = CFrame.Angles(rad(10), rad(4 * sin(t)), 0),
			Waist = CFrame.Angles(rad(-4), 0, 0),
		}
	end,
	Hero = function(t: number)
		return {
			RightShoulder = CFrame.Angles(rad(-15), 0, rad(35)),
			LeftShoulder = CFrame.Angles(rad(-15), 0, rad(-35)),
			Neck = CFrame.Angles(rad(8), rad(25 * sin(t * 0.8)), 0),
			Waist = CFrame.Angles(rad(-8), 0, 0),
		}
	end,
}

local JOINT_PARENTS = {
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	Neck = "Head",
	Waist = "UpperTorso",
}

-- [Player] = { PoseId, Joints = { [name] = { Motor, Original } }, Started, Meter, Seconds, NextPopup }
local posing = {}

local function poseConfig(poseId: string)
	for _, pose in Config.Poses do
		if pose.Id == poseId then
			return pose
		end
	end
	return nil
end

local function findJoints(character: Model)
	local joints = {}
	for name, partName in JOINT_PARENTS do
		local part = character:FindFirstChild(partName)
		local motor = part and part:FindFirstChild(name)
		if motor and motor:IsA("Motor6D") then
			joints[name] = { Motor = motor, Original = motor.C0 }
		end
	end
	return joints
end

local function popup(player: Player, text: string, color: Color3)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(7, 0, 1.6, 0)
	gui.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 3.5, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Adornee = head
	gui.Parent = head
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

	local info = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = gui.StudsOffset + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	Debris:AddItem(gui, 1.5)
end

local function burst(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(200, 120, 255))
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(15, 30)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(1.2, 0)
	emitter.Parent = root
	emitter:Emit(120)
	Debris:AddItem(emitter, 2.5)
end

function PoseService.Stop(player: Player)
	local state = posing[player]
	if not state then
		return
	end
	posing[player] = nil
	for _, joint in state.Joints do
		if joint.Motor.Parent then
			joint.Motor.C0 = joint.Original
		end
	end
	player:SetAttribute("Posing", nil)
end

function PoseService.Start(player: Player, poseId: string)
	local pose = poseConfig(poseId)
	if not pose then
		return
	end
	if pose.Vip and not Economy.HasPass(player, "VIP") then
		Remotes.Notify:FireClient(player, pose.Name .. " is a VIP pose!", "error")
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	PoseService.Stop(player)
	posing[player] = {
		PoseId = poseId,
		Joints = findJoints(character),
		Started = os.clock(),
		Seconds = 0,
		NextPopup = POPUP_EVERY,
	}
	player:SetAttribute("Posing", poseId)
end

local function isMoving(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return true
	end
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2.5 or math.abs(velocity.Y) > 6
end

local function update(dt: number)
	for player, state in posing do
		if not player.Parent or (os.clock() - state.Started > 0.6 and isMoving(player)) then
			PoseService.Stop(player)
			continue
		end

		local t = os.clock() - state.Started
		local offsets = POSES[state.PoseId](t)
		for name, joint in state.Joints do
			local offset = offsets[name]
			if offset and joint.Motor.Parent then
				joint.Motor.C0 = joint.Original * offset
			end
		end

		-- Aura Meter vullen (VIP gaat 50% sneller). Tijdens PEAK AURA staat de meter stil.
		local speed = if Economy.HasPass(player, "VIP") then 1.5 else 1
		if BoostService.PeakRemaining(player) > 0 then
			speed = 0
		end
		local meter = (player:GetAttribute("AuraMeter") or 0) + dt * 100 / Config.MeterFillSeconds * speed
		if meter >= 100 then
			meter = 0
			BoostService.StartPeak(player, Config.PeakAuraSeconds)
			Bus.Fire("PeakAura", player)
			burst(player)
			popup(player, "PEAK AURA", Color3.fromRGB(255, 220, 90))
		end
		player:SetAttribute("AuraMeter", meter)

		state.Seconds += dt
		if state.Seconds >= 1 then
			local whole = math.floor(state.Seconds)
			state.Seconds -= whole
			Bus.Fire("Posed", player, whole)
		end

		state.NextPopup -= dt
		if state.NextPopup <= 0 then
			state.NextPopup = POPUP_EVERY
			popup(player, POPUP_TEXTS[math.random(1, #POPUP_TEXTS)], Color3.fromRGB(200, 150, 255))
		end
	end
end

function PoseService.Init()
	Remotes.SetPose.OnServerEvent:Connect(function(player, poseId)
		if type(poseId) == "string" then
			PoseService.Start(player, poseId)
		else
			PoseService.Stop(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		posing[player] = nil
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= UPDATE_RATE then
			update(accumulator)
			accumulator = 0
		end
	end)
end

return PoseService
