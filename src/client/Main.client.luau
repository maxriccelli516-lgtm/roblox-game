-- Alles wat de speler op het scherm ziet: Aura teller, menu's, aura rollen, meldingen.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared:WaitForChild("Auras"))
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local Colors = Ui.Colors

local state = nil
local stateReceivedAt = os.clock()
local rolling = false

------------------------------------------------------------------------
-- Geluid
------------------------------------------------------------------------

local pingSound = Instance.new("Sound")
pingSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
pingSound.Volume = 0.5
pingSound.Parent = SoundService

local function playPing(pitch: number)
	pingSound.PlaybackSpeed = pitch
	SoundService:PlayLocalSound(pingSound)
end

------------------------------------------------------------------------
-- Basis scherm
------------------------------------------------------------------------

local screen = Ui.Create("ScreenGui", {
	Name = "AuraUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local uiScale = Ui.Create("UIScale", { Parent = screen })
local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 650), 0.55, 1.25)
end
local function watchCamera()
	updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end
watchCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

-- Aura teller bovenaan
local hud = Ui.Create("Frame", {
	Name = "Hud",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(340, 78),
	BackgroundColor3 = Colors.Panel,
	BackgroundTransparency = 0.1,
	Parent = screen,
}, { Ui.Corner(16), Ui.Stroke(Colors.Accent, 3) })

local auraLabel = Ui.Label({
	Position = UDim2.fromOffset(10, 4),
	Size = UDim2.new(1, -20, 0, 44),
	Text = "✨ 0 Aura",
	TextColor3 = Colors.Gold,
	Parent = hud,
})
local incomeLabel = Ui.Label({
	Position = UDim2.fromOffset(10, 48),
	Size = UDim2.new(1, -20, 0, 24),
	Text = "",
	TextColor3 = Colors.SubText,
	Parent = hud,
})

------------------------------------------------------------------------
-- Panelen
------------------------------------------------------------------------

local panels = {}
local openPanelName: string? = nil

local function makePanel(name: string, title: string)
	local panel = Ui.Create("Frame", {
		Name = name .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(480, 400),
		BackgroundColor3 = Colors.Panel,
		Visible = false,
		Parent = screen,
	}, { Ui.Corner(18), Ui.Stroke(Colors.Accent, 3) })

	Ui.Label({
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -80, 0, 42),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	Ui.Button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(40, 40),
		Text = "X",
		BackgroundColor3 = Colors.Red,
		Parent = panel,
	}, function()
		panel.Visible = false
		openPanelName = nil
	end)

	local body = Ui.Create("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 1, -76),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	panels[name] = panel
	return panel, body
end

local function togglePanel(name: string)
	for panelName, panel in panels do
		panel.Visible = panelName == name and openPanelName ~= name
	end
	openPanelName = if openPanelName == name then nil else name
end

local function openPanel(name: string)
	if openPanelName ~= name then
		togglePanel(name)
	end
end

local function makeList(parent: Instance, position: UDim2, size: UDim2)
	local list = Ui.Create("ScrollingFrame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Colors.PanelLight,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, { Ui.Corner(12) })
	Ui.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	Ui.Create("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 6),
		Parent = list,
	})
	return list
end

-- Roll panel ----------------------------------------------------------

local rollPanel, rollBody = makePanel("Roll", "🔮 Aura Roll")
rollPanel.Size = UDim2.fromOffset(480, 460)

local resultBox = Ui.Create("Frame", {
	Size = UDim2.new(1, 0, 0, 96),
	BackgroundColor3 = Colors.PanelLight,
	Parent = rollBody,
}, { Ui.Corner(12) })
local resultName = Ui.Label({
	Position = UDim2.fromOffset(8, 6),
	Size = UDim2.new(1, -16, 0, 54),
	Text = "Roll to get an Aura!",
	Parent = resultBox,
})
local resultRarity = Ui.Label({
	Position = UDim2.fromOffset(8, 62),
	Size = UDim2.new(1, -16, 0, 26),
	Text = "Better auras = more Aura per orb",
	TextColor3 = Colors.SubText,
	Parent = resultBox,
})

local rollButton = Ui.Button({
	Position = UDim2.fromOffset(0, 106),
	Size = UDim2.new(0.5, -5, 0, 52),
	Text = "Roll",
	BackgroundColor3 = Colors.Accent,
	Parent = rollBody,
}, function()
	if not rolling then
		Remotes.RollAura:FireServer(false)
	end
end)

local freeRollButton = Ui.Button({
	Position = UDim2.new(0.5, 5, 0, 106),
	Size = UDim2.new(0.5, -5, 0, 52),
	Text = "Free Roll",
	BackgroundColor3 = Colors.Green,
	Parent = rollBody,
}, function()
	if not rolling then
		Remotes.RollAura:FireServer(true)
	end
end)

local auraList = makeList(rollBody, UDim2.fromOffset(0, 168), UDim2.new(1, 0, 1, -168))

local function auraTextColor(aura)
	return if aura.Name == "Void Aura" then Color3.fromRGB(190, 120, 255) else aura.Color
end

local function refreshAuraList()
	for _, child in auraList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if not state then
		return
	end
	for index = #Auras.List, 1, -1 do
		local aura = Auras.List[index]
		local count = state.OwnedAuras[aura.Name]
		local row = Ui.Create("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Colors.Panel,
			LayoutOrder = #Auras.List - index,
			Parent = auraList,
		}, { Ui.Corner(10) })
		Ui.Label({
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(0.5, -10, 1, -8),
			Text = if count then aura.Name else "???",
			TextColor3 = if count then auraTextColor(aura) else Colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Ui.Label({
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.new(0.25, -4, 1, -16),
			Text = Auras.RarityText(aura) .. "  x" .. aura.Multiplier,
			TextColor3 = Colors.SubText,
			Parent = row,
		})
		if count then
			local equipped = state.EquippedAura == aura.Name
			Ui.Button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.new(0.25, -6, 0, 34),
				Text = if equipped then "Equipped" else "Equip",
				BackgroundColor3 = if equipped then Colors.Green else Colors.Accent,
				AutoButtonColor = not equipped,
				Parent = row,
			}, function()
				if not equipped then
					Remotes.EquipAura:FireServer(aura.Name)
				end
			end)
		end
	end
end

-- Rebirth panel -------------------------------------------------------

local _, rebirthBody = makePanel("Rebirth", "♻️ Rebirth")
Ui.Label({
	Size = UDim2.new(1, 0, 0, 70),
	Text = "Rebirth resets your Aura and your farm,\nbut you keep your Auras and earn MORE forever!",
	TextColor3 = Colors.SubText,
	Parent = rebirthBody,
})
local rebirthMultiplierLabel = Ui.Label({
	Position = UDim2.fromOffset(0, 80),
	Size = UDim2.new(1, 0, 0, 44),
	Text = "",
	TextColor3 = Colors.Gold,
	Parent = rebirthBody,
})
local progressBack = Ui.Create("Frame", {
	Position = UDim2.fromOffset(0, 136),
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = Colors.PanelLight,
	Parent = rebirthBody,
}, { Ui.Corner(10) })
local progressFill = Ui.Create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Colors.Accent,
	Parent = progressBack,
}, { Ui.Corner(10) })
local progressLabel = Ui.Label({
	Size = UDim2.fromScale(1, 1),
	Text = "",
	ZIndex = 2,
	Parent = progressBack,
})
local rebirthButton = Ui.Button({
	Position = UDim2.fromOffset(0, 190),
	Size = UDim2.new(1, 0, 0, 60),
	Text = "REBIRTH",
	BackgroundColor3 = Colors.Gold,
	Parent = rebirthBody,
}, function()
	Remotes.RequestRebirth:FireServer()
end)

-- Shop panel ----------------------------------------------------------

local _, shopBody = makePanel("Shop", "🛒 Shop")
local shopList = makeList(shopBody, UDim2.new(), UDim2.fromScale(1, 1))
local passButtons = {}

local function addShopRow(order: number, title: string, description: string, buttonText: string, onClick)
	local row = Ui.Create("Frame", {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Colors.Panel,
		LayoutOrder = order,
		Parent = shopList,
	}, { Ui.Corner(10) })
	Ui.Label({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(0.65, -10, 0, 30),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Gold,
		Parent = row,
	})
	Ui.Label({
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(0.65, -10, 0, 24),
		Text = description,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.SubText,
		Parent = row,
	})
	return Ui.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.33, -8, 0, 44),
		Text = buttonText,
		BackgroundColor3 = Colors.Green,
		Parent = row,
	}, onClick)
end

do
	local order = 0
	for key, pass in Config.GamePasses do
		order += 1
		passButtons[key] = addShopRow(order, pass.Name, pass.Description, if pass.Id == 0 then "Soon" else "Buy", function()
			if pass.Id ~= 0 and not (state and state.Passes[key]) then
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end
		end)
	end
	for _, product in Config.DevProducts do
		order += 1
		addShopRow(order, product.Name, product.Minutes .. " minutes of your Aura income", if product.Id == 0 then "Soon" else "Buy", function()
			if product.Id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, product.Id)
			end
		end)
	end
end

-- Daily panel ---------------------------------------------------------

local _, dailyBody = makePanel("Daily", "🎁 Daily Reward")
local dailyStreakLabel = Ui.Label({
	Size = UDim2.new(1, 0, 0, 50),
	Text = "",
	TextColor3 = Colors.Gold,
	Parent = dailyBody,
})
Ui.Label({
	Position = UDim2.fromOffset(0, 56),
	Size = UDim2.new(1, 0, 0, 60),
	Text = "Come back every day for bigger rewards!\nYour streak goes up to day 7.",
	TextColor3 = Colors.SubText,
	Parent = dailyBody,
})
local dailyButton = Ui.Button({
	Position = UDim2.fromOffset(0, 140),
	Size = UDim2.new(1, 0, 0, 64),
	Text = "Claim",
	BackgroundColor3 = Colors.Green,
	Parent = dailyBody,
}, function()
	Remotes.ClaimDaily:FireServer()
end)

-- Codes panel ---------------------------------------------------------

local _, codesBody = makePanel("Codes", "🎟️ Codes")
Ui.Label({
	Size = UDim2.new(1, 0, 0, 40),
	Text = "Type a code and get free Aura!",
	TextColor3 = Colors.SubText,
	Parent = codesBody,
})
local codeBox = Ui.Create("TextBox", {
	Position = UDim2.fromOffset(0, 60),
	Size = UDim2.new(1, 0, 0, 56),
	BackgroundColor3 = Colors.PanelLight,
	PlaceholderText = "Enter code...",
	PlaceholderColor3 = Colors.SubText,
	Text = "",
	ClearTextOnFocus = false,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	TextColor3 = Colors.Text,
	Parent = codesBody,
}, { Ui.Corner(10) })
Ui.Button({
	Position = UDim2.fromOffset(0, 130),
	Size = UDim2.new(1, 0, 0, 60),
	Text = "Redeem",
	BackgroundColor3 = Colors.Green,
	Parent = codesBody,
}, function()
	if codeBox.Text ~= "" then
		Remotes.RedeemCode:FireServer(codeBox.Text)
		codeBox.Text = ""
	end
end)

------------------------------------------------------------------------
-- Menu links
------------------------------------------------------------------------

local menu = Ui.Create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(84, 5 * 84),
	BackgroundTransparency = 1,
	Parent = screen,
})
Ui.Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })

local badges = {}
local function menuButton(order: number, name: string, emoji: string, text: string, color: Color3)
	local button = Ui.Button({
		Size = UDim2.fromOffset(76, 76),
		Text = "",
		BackgroundColor3 = color,
		LayoutOrder = order,
		Parent = menu,
	}, function()
		togglePanel(name)
	end)
	Ui.Label({ Size = UDim2.new(1, 0, 0.62, 0), Text = emoji, Parent = button })
	Ui.Label({ Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.38), Text = text, Parent = button })
	local badge = Ui.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(44, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = Colors.Red,
		Text = "!",
		Visible = false,
		ZIndex = 3,
		Parent = button,
	})
	Ui.Corner(10).Parent = badge
	badges[name] = badge
end

menuButton(1, "Roll", "🔮", "Roll", Color3.fromRGB(130, 70, 230))
menuButton(2, "Rebirth", "♻️", "Rebirth", Color3.fromRGB(220, 160, 40))
menuButton(3, "Shop", "🛒", "Shop", Color3.fromRGB(50, 170, 90))
menuButton(4, "Daily", "🎁", "Daily", Color3.fromRGB(220, 70, 120))
menuButton(5, "Codes", "🎟️", "Codes", Color3.fromRGB(60, 130, 220))

------------------------------------------------------------------------
-- Meldingen
------------------------------------------------------------------------

local toastHolder = Ui.Create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.fromOffset(520, 300),
	BackgroundTransparency = 1,
	Parent = screen,
})
Ui.Create("UIListLayout", {
	Padding = UDim.new(0, 6),
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = toastHolder,
})

local TOAST_COLORS = {
	info = Colors.PanelLight,
	success = Color3.fromRGB(40, 140, 80),
	error = Color3.fromRGB(170, 50, 60),
	collect = Color3.fromRGB(150, 110, 20),
	rare = Color3.fromRGB(130, 60, 220),
}

local toastOrder = 0
local function showToast(text: string, kind: string)
	toastOrder += 1
	local toast = Ui.Create("Frame", {
		Size = UDim2.fromOffset(500, if kind == "rare" then 48 else 38),
		BackgroundColor3 = TOAST_COLORS[kind] or Colors.PanelLight,
		LayoutOrder = toastOrder,
		Parent = toastHolder,
	}, { Ui.Corner(10), Ui.Stroke(Color3.new(0, 0, 0), 2) })
	local label = Ui.Label({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 1, -8),
		Text = text,
		Parent = toast,
	})

	local visible = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(visible, child)
		end
	end
	if #visible > 5 then
		table.sort(visible, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		visible[1]:Destroy()
	end

	if kind == "success" or kind == "rare" then
		playPing(if kind == "rare" then 1.5 else 1.2)
	end

	task.delay(if kind == "rare" then 5 else 3, function()
		if not toast.Parent then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		task.wait(0.4)
		toast:Destroy()
	end)
end

Remotes.Notify.OnClientEvent:Connect(function(text, kind)
	showToast(text, kind or "info")
end)

------------------------------------------------------------------------
-- Aura roll animatie
------------------------------------------------------------------------

local flash = Ui.Create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	ZIndex = 10,
	Parent = screen,
})

Remotes.RollResult.OnClientEvent:Connect(function(auraName, isNew, equipped)
	local aura = Auras.ByName[auraName]
	if not aura then
		return
	end
	rolling = true
	openPanel("Roll")

	-- Snel door aura's heen draaien voor spanning
	local steps = 14
	for step = 1, steps do
		local fake = Auras.Roll(4)
		resultName.Text = fake.Name
		resultName.TextColor3 = auraTextColor(fake)
		resultRarity.Text = Auras.RarityText(fake)
		playPing(0.8 + step / steps * 0.6)
		task.wait(0.04 + step * 0.008)
	end

	resultName.Text = aura.Name
	resultName.TextColor3 = auraTextColor(aura)
	local extra = ""
	if isNew then
		extra ..= "  NEW!"
	end
	if equipped then
		extra ..= "  Equipped!"
	end
	resultRarity.Text = Auras.RarityText(aura) .. "  x" .. aura.Multiplier .. extra

	if aura.Chance >= 64 then
		flash.BackgroundColor3 = aura.Color
		flash.BackgroundTransparency = 0.2
		TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		playPing(2)
	end
	rolling = false
end)

-- Aura Altaar op het plein opent het roll panel
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "AuraAltarPrompt" then
		openPanel("Roll")
	end
end)

------------------------------------------------------------------------
-- Status bijwerken
------------------------------------------------------------------------

local function refreshStatic(listChanged: boolean)
	if not state then
		return
	end
	auraLabel.Text = "✨ " .. Format.Number(state.Aura) .. " Aura"
	incomeLabel.Text = "x" .. tostring(math.floor(state.Multiplier * 100) / 100) .. " boost  •  " .. Format.Number(state.IncomePerSecond) .. "/s"

	rollButton.Text = "Roll (" .. Format.Number(state.RollCost) .. ")"

	rebirthMultiplierLabel.Text = "x" .. state.RebirthMultiplier .. "  →  x" .. state.NextRebirthMultiplier
	local progress = math.clamp(state.Aura / state.RebirthCost, 0, 1)
	progressFill.Size = UDim2.fromScale(progress, 1)
	progressLabel.Text = Format.Number(state.Aura) .. " / " .. Format.Number(state.RebirthCost)
	rebirthButton.BackgroundColor3 = if progress >= 1 then Colors.Gold else Colors.PanelLight
	rebirthButton.Text = if progress >= 1 then "REBIRTH NOW!" else "Need " .. Format.Number(state.RebirthCost) .. " Aura"
	badges.Rebirth.Visible = progress >= 1

	for key, button in passButtons do
		if state.Passes[key] then
			button.Text = "Owned"
			button.BackgroundColor3 = Colors.PanelLight
		end
	end

	dailyStreakLabel.Text = "Streak: day " .. state.DailyStreak

	if listChanged then
		refreshAuraList()
	end
end

local function refreshTimers()
	if not state then
		return
	end
	local elapsed = os.clock() - stateReceivedAt
	local freeIn = math.max(0, state.FreeRollIn - elapsed)
	local dailyIn = math.max(0, state.DailyIn - elapsed)

	freeRollButton.Text = if freeIn <= 0 then "FREE ROLL!" else "Free in " .. Format.Time(freeIn)
	freeRollButton.BackgroundColor3 = if freeIn <= 0 then Colors.Green else Colors.PanelLight
	badges.Roll.Visible = freeIn <= 0
	badges.Roll.Text = "FREE"

	dailyButton.Text = if dailyIn <= 0 then "Claim!" else "Next in " .. Format.Time(dailyIn)
	dailyButton.BackgroundColor3 = if dailyIn <= 0 then Colors.Green else Colors.PanelLight
	badges.Daily.Visible = dailyIn <= 0
end

local lastOwnedKey = ""
Remotes.SyncState.OnClientEvent:Connect(function(newState)
	state = newState
	stateReceivedAt = os.clock()

	-- De aura lijst alleen opnieuw bouwen als er iets veranderd is
	local distinct, total = 0, 0
	for _, count in newState.OwnedAuras do
		distinct += 1
		total += count
	end
	local ownedKey = newState.EquippedAura .. "|" .. distinct .. "|" .. total
	local listChanged = ownedKey ~= lastOwnedKey
	lastOwnedKey = ownedKey

	refreshStatic(listChanged)
	refreshTimers()
end)

local timerAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	timerAccumulator += dt
	if timerAccumulator >= 0.25 then
		timerAccumulator = 0
		refreshTimers()
	end
end)
