-- Tekent de aura farm poses voor ALLE spelers die aan het posen zijn.
-- Roblox zijn eigen animaties (lopen, stilstaan) zetten elke frame de gewrichten. Wij zetten daarna,
-- in RunService.Stepped, onze pose eroverheen. Zo zie je de armen en het hoofd echt bewegen.
-- Werkt voor R15 en (simpeler) voor R6 avatars.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local rad = math.rad
local sin = math.sin
local pi = math.pi

local BLEND_SECONDS = 0.25

-- Hoeken in graden. Shoulder: P = arm naar voren/omhoog, Y = draaien, R = arm opzij (naar buiten).
-- Elbow: P = onderarm buigen. Neck en Waist: P = omhoog kijken / achterover, Y = opzij draaien.
-- Root: Bob = hele lichaam op en neer (studs), Y en R = heupen draaien en wiegen.
-- Hip: P = been naar voren, R = been opzij. Knee: P = onderbeen buigen (negatief = naar achteren).
local POSES = {
	-- De boat kid dans: armen golven om de beurt, heupen wiegen mee, kin omhoog
	BoatKid = function(t: number)
		local beat = t * 4.5
		local other = beat + pi
		return {
			RightShoulder = { P = 70 + 35 * sin(beat), R = 25 + 20 * sin(beat + 1) },
			LeftShoulder = { P = 70 + 35 * sin(other), R = 25 + 20 * sin(other + 1) },
			RightElbow = { P = 40 + 30 * sin(beat + 0.8) },
			LeftElbow = { P = 40 + 30 * sin(other + 0.8) },
			Neck = { P = 10, Y = 12 * sin(beat / 2) },
			Waist = { Y = 10 * sin(beat) },
			Root = { Bob = 0.15 * sin(beat * 2), Y = 8 * sin(beat), R = 4 * sin(beat) },
		}
	end,
	-- Wijzen naar de lucht, andere hand in de zij
	SkyPoint = function(t: number)
		return {
			RightShoulder = { P = 160, R = -8 },
			LeftShoulder = { P = -10, R = 40 },
			LeftElbow = { P = 75 },
			Neck = { P = 24 + 3 * sin(t * 2), Y = -8 },
			Waist = { P = -6, Y = -10 },
			Root = { Bob = 0.05 * sin(t * 2) },
		}
	end,
	-- Armen over elkaar, kin omhoog
	Sigma = function(t: number)
		return {
			RightShoulder = { P = 80, Y = 50 },
			LeftShoulder = { P = 75, Y = -50 },
			RightElbow = { P = 70 },
			LeftElbow = { P = 70 },
			Neck = { P = 14, Y = 6 * sin(t) },
			Waist = { P = -4 },
			Root = { Bob = 0.04 * sin(t * 1.5) },
		}
	end,
	-- Superheld: handen in de zij, borst vooruit, rustig rondkijken
	Hero = function(t: number)
		return {
			RightShoulder = { P = -15, R = 45 },
			LeftShoulder = { P = -15, R = 45 },
			RightElbow = { P = 95 },
			LeftElbow = { P = 95 },
			Neck = { P = 10, Y = 25 * sin(t * 0.8) },
			Waist = { P = -8 },
			Root = { Bob = 0.04 * sin(t * 1.5) },
		}
	end,
	-- Level 3: achterover leunen met je handen achter je hoofd
	Lean = function(t: number)
		return {
			RightShoulder = { P = 150, R = 45 },
			LeftShoulder = { P = 150, R = 45 },
			RightElbow = { P = 115 },
			LeftElbow = { P = 115 },
			Neck = { P = 12, Y = 15 * sin(t * 0.7) },
			Waist = { P = -14, Y = 4 * sin(t * 0.7) },
			Root = { Bob = 0.05 * sin(t * 1.5), R = 3 * sin(t * 0.8) },
			RightHip = { R = 8 },
			LeftHip = { R = 8 },
		}
	end,
	-- Level 10: in kleermakerszit zweven, handen open
	Levitate = function(t: number)
		return {
			RightShoulder = { P = 30, R = 35 },
			LeftShoulder = { P = 30, R = 35 },
			RightElbow = { P = 40 },
			LeftElbow = { P = 40 },
			Neck = { P = 8 },
			Root = { Bob = 1.6 + 0.35 * sin(t * 1.6), Y = 6 * sin(t * 0.5) },
			RightHip = { P = 80, R = 35 },
			LeftHip = { P = 80, R = 35 },
			RightKnee = { P = -110 },
			LeftKnee = { P = -110 },
		}
	end,
	-- Level 20: armen wijd als vleugels die langzaam klapperen
	Wings = function(t: number)
		local flap = sin(t * 3)
		return {
			RightShoulder = { P = 10, R = 85 + 20 * flap },
			LeftShoulder = { P = 10, R = 85 + 20 * flap },
			RightElbow = { P = 15 - 10 * flap },
			LeftElbow = { P = 15 - 10 * flap },
			Neck = { P = 20 },
			Waist = { P = -8 },
			Root = { Bob = 0.6 + 0.3 * flap },
		}
	end,
	-- Tijdens een Aura Battle: beide handen naar voren, energie afvuren
	Battle = function(t: number)
		local shake = sin(t * 40)
		return {
			RightShoulder = { P = 90 + 2 * shake, R = -12 },
			LeftShoulder = { P = 90 - 2 * shake, R = -12 },
			RightElbow = { P = 5 },
			LeftElbow = { P = 5 },
			Neck = { P = -4 },
			Waist = { P = 10 },
			Root = { Bob = -0.3 },
			RightHip = { P = -15, R = 10 },
			LeftHip = { P = 25, R = 10 },
			RightKnee = { P = -10 },
			LeftKnee = { P = -30 },
		}
	end,
}

-- Waar zitten de gewrichten (R15)? Naam van het gewricht = naam van het onderdeel waarin het zit.
local R15_JOINTS = {
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm",
	Neck = "Head",
	Waist = "UpperTorso",
	Root = "LowerTorso",
	RightHip = "RightUpperLeg",
	LeftHip = "LeftUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftKnee = "LeftLowerLeg",
}

local function angle(values, key: string): number
	return rad(values[key] or 0)
end

-- R15: de gewrichten staan gelijk met het lichaam, dus X = voor/achter, Z = opzij
local function r15Offset(name: string, values): CFrame
	if name == "Root" then
		return CFrame.new(0, values.Bob or 0, 0) * CFrame.Angles(0, angle(values, "Y"), angle(values, "R"))
	end
	local roll = angle(values, "R")
	if name == "LeftShoulder" or name == "LeftHip" then
		roll = -roll
	end
	return CFrame.Angles(0, angle(values, "Y"), 0) * CFrame.Angles(angle(values, "P"), 0, roll)
end

-- Een gewricht is een Motor6D (oude avatars) of een AnimationConstraint (nieuwe "Avatar Joint Upgrade"
-- avatars). Allebei hebben een Transform die we kunnen zetten.
type Joint = { Motor: any, Name: string }

local function isJoint(instance: Instance?): boolean
	return instance ~= nil and (instance:IsA("Motor6D") or instance:IsA("AnimationConstraint"))
end

-- Zoek een gewricht eerst op de bekende plek, anders ergens in het karakter
local function findJoint(character: Model, partName: string?, name: string): Instance?
	local part = partName and character:FindFirstChild(partName)
	local direct = part and part:FindFirstChild(name)
	if isJoint(direct) then
		return direct
	end
	for _, descendant in character:GetDescendants() do
		if descendant.Name == name and isJoint(descendant) then
			return descendant
		end
	end
	return nil
end
type CharacterState = { Character: Model, Joints: { Joint }, R6: boolean, Weight: number, PoseId: string?, Started: number }

local states: { [Player]: CharacterState } = {}

local function findJoints(character: Model): ({ Joint }, boolean)
	local joints = {}
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local isR6 = humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
	if isR6 then
		local map = {
			RightShoulder = findJoint(character, "Torso", "Right Shoulder"),
			LeftShoulder = findJoint(character, "Torso", "Left Shoulder"),
			Root = findJoint(character, "HumanoidRootPart", "RootJoint"),
		}
		for name, motor in map do
			if motor then
				table.insert(joints, { Motor = motor, Name = name })
			end
		end
	else
		for name, partName in R15_JOINTS do
			local motor = findJoint(character, partName, name)
			if motor then
				table.insert(joints, { Motor = motor, Name = name })
			end
		end
	end
	return joints, isR6
end

-- R6: schouders draaien om hun eigen Z-as (zoals de oude Roblox animaties), alleen voor/achter
local function r6Offset(name: string, values): CFrame?
	if name == "RightShoulder" then
		return CFrame.Angles(0, 0, angle(values, "P"))
	elseif name == "LeftShoulder" then
		return CFrame.Angles(0, 0, -angle(values, "P"))
	elseif name == "Root" then
		return CFrame.new(0, 0, values.Bob or 0)
	end
	return nil
end

local function stateFor(player: Player): CharacterState?
	local character = player.Character
	if not character then
		states[player] = nil
		return nil
	end
	local state = states[player]
	-- Opnieuw zoeken als het karakter nieuw is, of (hooguit 1x per seconde) als er nog geen gewrichten waren
	local retry = state ~= nil and #state.Joints == 0 and os.clock() - state.Started > 1
	if not state or state.Character ~= character or retry then
		local joints, isR6 = findJoints(character)
		state = { Character = character, Joints = joints, R6 = isR6, Weight = 0, PoseId = nil, Started = os.clock() }
		states[player] = state
	end
	return state
end

-- Pose over de animaties heen zetten. We doen dit in Stepped én vlak voor het tekenen (PreRender),
-- zodat het werkt hoe laat de animaties van Roblox ook worden toegepast.
local function applyPoses()
	for _, state in states do
		if state.Weight <= 0 or not state.PoseId or not state.Character.Parent then
			continue
		end
		local values = POSES[state.PoseId :: string](os.clock() - state.Started)
		local weight = state.Weight
		for _, joint in state.Joints do
			local jointValues = values[joint.Name]
			if jointValues and joint.Motor.Parent then
				local offset = if state.R6 then r6Offset(joint.Name, jointValues) else r15Offset(joint.Name, jointValues)
				if offset then
					joint.Motor.Transform = joint.Motor.Transform:Lerp(offset, weight)
				end
			end
		end
	end
end

RunService.Stepped:Connect(function(_, dt)
	for _, player in Players:GetPlayers() do
		local poseId = player:GetAttribute("BattlePose") or player:GetAttribute("Posing")
		local state = states[player]
		if poseId == nil and (state == nil or state.Weight <= 0) then
			continue
		end
		state = stateFor(player)
		if not state then
			continue
		end

		if type(poseId) == "string" and POSES[poseId] then
			if state.PoseId ~= poseId then
				state.PoseId = poseId
				state.Started = os.clock()
			end
			state.Weight = math.min(1, state.Weight + dt / BLEND_SECONDS)
		else
			state.Weight = math.max(0, state.Weight - dt / BLEND_SECONDS)
		end
	end
	applyPoses()
end)
RunService.RenderStepped:Connect(applyPoses)

------------------------------------------------------------------------
-- Extra zekerheid: jouw eigen karakter speelt ook een standaard Roblox emote (dansje, wijzen,
-- juichen). Die animaties zijn van Roblox zelf, dus ze werken in elke game zonder iets te uploaden,
-- en andere spelers zien ze ook. Lukt onze eigen pose, dan ligt die er gewoon overheen.
------------------------------------------------------------------------

local EMOTES = {
	R15 = { Dance = 507776043, Point = 507770453, Cheer = 507770677, Dance3 = 507777268 },
	R6 = { Dance = 182436842, Point = 128853357, Cheer = 129423030, Dance3 = 182436935 },
}
local EMOTE_FOR_POSE = {
	BoatKid = "Dance",
	SkyPoint = "Point",
	Sigma = "Dance3",
	Hero = "Cheer",
	Lean = "Dance3",
	Levitate = "Dance",
	Wings = "Cheer",
	Battle = "Point",
}

local localPlayer = Players.LocalPlayer
local emoteTrack: AnimationTrack? = nil
local emotePose: string? = nil

local function stopEmote()
	if emoteTrack then
		emoteTrack:Stop(0.25)
		emoteTrack = nil
	end
	emotePose = nil
end

local function updateEmote()
	local poseId = localPlayer:GetAttribute("BattlePose") or localPlayer:GetAttribute("Posing")
	if poseId == emotePose then
		return
	end
	stopEmote()
	if type(poseId) ~= "string" then
		return
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not animator then
		return
	end
	local set = if humanoid.RigType == Enum.HumanoidRigType.R6 then EMOTES.R6 else EMOTES.R15
	local id = set[EMOTE_FOR_POSE[poseId] or "Dance"]
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.25)
		emoteTrack = track
		emotePose = poseId
	end
end

localPlayer:GetAttributeChangedSignal("Posing"):Connect(updateEmote)
localPlayer:GetAttributeChangedSignal("BattlePose"):Connect(updateEmote)
localPlayer.CharacterAdded:Connect(function()
	emoteTrack = nil
	emotePose = nil
	task.wait(0.5)
	updateEmote()
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)
