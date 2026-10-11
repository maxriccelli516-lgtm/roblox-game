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

type Joint = { Motor: Motor6D, Name: string }
type CharacterState = { Character: Model, Joints: { Joint }, R6: boolean, Weight: number, PoseId: string?, Started: number }

local states: { [Player]: CharacterState } = {}

local function findJoints(character: Model): ({ Joint }, boolean)
	local joints = {}
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local isR6 = humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
	if isR6 then
		local torso = character:FindFirstChild("Torso")
		local root = character:FindFirstChild("HumanoidRootPart")
		local map = {
			RightShoulder = torso and torso:FindFirstChild("Right Shoulder"),
			LeftShoulder = torso and torso:FindFirstChild("Left Shoulder"),
			Root = root and root:FindFirstChild("RootJoint"),
		}
		for name, motor in map do
			if motor and motor:IsA("Motor6D") then
				table.insert(joints, { Motor = motor, Name = name })
			end
		end
	else
		for name, partName in R15_JOINTS do
			local part = character:FindFirstChild(partName)
			local motor = part and part:FindFirstChild(name)
			if motor and motor:IsA("Motor6D") then
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
	if not state or state.Character ~= character or #state.Joints == 0 then
		local joints, isR6 = findJoints(character)
		state = { Character = character, Joints = joints, R6 = isR6, Weight = 0, PoseId = nil, Started = os.clock() }
		states[player] = state
	end
	return state
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
		if state.Weight <= 0 or not state.PoseId then
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
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)
