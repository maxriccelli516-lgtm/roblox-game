-- Het scherm tijdens een Aura Battle: aftellen, een grote AURA! knop om op te tikken,
-- een balk die laat zien wie de botsbal wint, en VICTORY of DEFEAT aan het eind.
-- Tikken kan ook met spatie, E, of de A knop op een controller.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local Colors = Ui.Colors

local phase = "None"
local endsAt = 0

local tapSound = Instance.new("Sound")
tapSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
tapSound.Volume = 0.25
tapSound.Parent = SoundService

local screen = Ui.Create("ScreenGui", {
	Name = "BattleUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
	Parent = player:WaitForChild("PlayerGui"),
})
local uiScale = Ui.Create("UIScale", { Parent = screen })
local function updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 650), 0.55, 1.25)
	end
end
updateScale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- Paneel onderaan (ligt over de aura farm knop heen tijdens een battle)
local panel = Ui.Create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.fromOffset(520, 220),
	BackgroundColor3 = Colors.Panel,
	BackgroundTransparency = 0.05,
	Visible = false,
	Parent = screen,
}, { Ui.Corner(18), Ui.Stroke(Color3.fromRGB(255, 110, 190), 3) })

local vsLabel = Ui.Label({
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 0, 30),
	Text = "",
	TextColor3 = Colors.Gold,
	Parent = panel,
})

local barBack = Ui.Create("Frame", {
	Position = UDim2.fromOffset(16, 42),
	Size = UDim2.new(1, -32, 0, 26),
	BackgroundColor3 = Color3.fromRGB(255, 90, 170),
	Parent = panel,
}, { Ui.Corner(10), Ui.Stroke(Color3.new(0, 0, 0), 2) })
local barMine = Ui.Create("Frame", {
	Size = UDim2.fromScale(0.5, 1),
	BackgroundColor3 = Color3.fromRGB(90, 170, 255),
	Parent = barBack,
}, { Ui.Corner(10) })
local barMarker = Ui.Create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(16, 38),
	BackgroundColor3 = Color3.fromRGB(255, 245, 200),
	ZIndex = 3,
	Parent = barBack,
}, { Ui.Corner(6), Ui.Stroke(Color3.new(0, 0, 0), 2) })
Ui.Label({ Position = UDim2.fromOffset(6, 0), Size = UDim2.new(0.4, 0, 1, 0), Text = "YOU", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = barBack })
local themLabel = Ui.Label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), Text = "THEM", TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4, Parent = barBack })

local timerLabel = Ui.Label({
	Position = UDim2.fromOffset(12, 72),
	Size = UDim2.new(1, -24, 0, 22),
	Text = "",
	TextColor3 = Colors.SubText,
	Parent = panel,
})

local tapButton = Ui.Button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.new(1, -40, 0, 104),
	Text = "⚡ AURA! ⚡",
	BackgroundColor3 = Color3.fromRGB(150, 70, 255),
	Parent = panel,
})
local tapScale = Ui.Create("UIScale", { Parent = tapButton })

-- Grote tekst in het midden (3, 2, 1, VICTORY!)
local bigText = Ui.Label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.fromOffset(600, 120),
	Text = "",
	TextColor3 = Colors.Gold,
	Visible = false,
	Parent = screen,
})
local bigScale = Ui.Create("UIScale", { Parent = bigText })
local subText = Ui.Label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.4, 64),
	Size = UDim2.fromOffset(600, 40),
	Text = "",
	Visible = false,
	Parent = screen,
})

local function pop(text: string, color: Color3, sub: string?, seconds: number?)
	bigText.Text = text
	bigText.TextColor3 = color
	bigText.Visible = true
	subText.Text = sub or ""
	subText.Visible = sub ~= nil
	bigScale.Scale = 0.4
	TweenService:Create(bigScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if seconds then
		local shown = text
		task.delay(seconds, function()
			if bigText.Text == shown then
				bigText.Visible = false
				subText.Visible = false
			end
		end)
	end
end

local function tap()
	if phase ~= "Fight" then
		return
	end
	Remotes.BattleTap:FireServer()
	tapSound.PlaybackSpeed = 0.9 + math.random() * 0.5
	SoundService:PlayLocalSound(tapSound)
	tapScale.Scale = 0.9
	TweenService:Create(tapScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
end
tapButton.Activated:Connect(tap)

UserInputService.InputBegan:Connect(function(input, processed)
	if phase ~= "Fight" or processed then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Space or key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.ButtonR2 then
		tap()
	end
end)

local function knockback()
	task.wait(0.2)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or root.Anchored then
		return
	end
	root.AssemblyLinearVelocity = -root.CFrame.LookVector * 45 + Vector3.new(0, 35, 0)
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
end

local lastCount = -1
Remotes.BattleState.OnClientEvent:Connect(function(info)
	phase = info.Phase
	if info.EndsAt then
		endsAt = info.EndsAt
	end
	if info.Phase == "Countdown" then
		panel.Visible = true
		tapButton.Text = "GET READY..."
		tapButton.BackgroundColor3 = Colors.PanelLight
		vsLabel.Text = "⚔️ AURA BATTLE vs " .. tostring(info.Opponent) .. " (Lv " .. tostring(info.OpponentLevel) .. ")"
		themLabel.Text = string.upper(tostring(info.Opponent))
		barMine.Size = UDim2.fromScale(0.5, 1)
		barMarker.Position = UDim2.fromScale(0.5, 0.5)
		lastCount = -1
	elseif info.Phase == "Fight" then
		panel.Visible = true
		if tapButton.Text ~= "⚡ AURA! ⚡" then
			tapButton.Text = "⚡ AURA! ⚡"
			tapButton.BackgroundColor3 = Color3.fromRGB(150, 70, 255)
			pop("AURA!", Color3.fromRGB(255, 120, 220), "Tap as fast as you can!", 1)
		end
		local position = 0.5 + (info.Lead or 0) * 0.5
		TweenService:Create(barMine, TweenInfo.new(0.2), { Size = UDim2.fromScale(position, 1) }):Play()
		TweenService:Create(barMarker, TweenInfo.new(0.2), { Position = UDim2.fromScale(position, 0.5) }):Play()
	elseif info.Phase == "End" then
		panel.Visible = false
		phase = "None"
		if info.Won then
			pop("VICTORY!", Colors.Gold, "+" .. Format.Number(info.Reward or 0) .. " Aura  •  +1000 aura moment", 3.5)
		else
			pop("DEFEAT...", Color3.fromRGB(200, 200, 210), "-1000 aura. " .. tostring(info.Opponent) .. " was too strong. Level up and try again!", 3.5)
			if info.Knockback then
				task.spawn(knockback)
			end
		end
	end
end)

-- Timer en aftellen
game:GetService("RunService").Heartbeat:Connect(function()
	if phase == "None" then
		return
	end
	local left = endsAt - workspace:GetServerTimeNow()
	if phase == "Countdown" then
		local count = math.max(1, math.ceil(left))
		if count ~= lastCount then
			lastCount = count
			pop(tostring(count), Colors.Text, nil, nil)
			tapSound.PlaybackSpeed = 0.8
			SoundService:PlayLocalSound(tapSound)
		end
		timerLabel.Text = "Starting..."
	elseif phase == "Fight" then
		timerLabel.Text = "⏱ " .. string.format("%.1f", math.max(0, left)) .. "s  •  Tap AURA! (or Space)"
	end
end)
