-- Alles wat de speler op het scherm ziet: Aura teller, menu's, aura rollen, meldingen.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared:WaitForChild("Auras"))
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Levels = require(Shared:WaitForChild("Levels"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local Colors = Ui.Colors

local state = nil
local stateReceivedAt = os.clock()
local rolling = false
local badges: { [string]: TextLabel } = {}

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
	Size = UDim2.fromOffset(340, 106),
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

-- Aura Level balk in de teller
local levelBack = Ui.Create("Frame", {
	Position = UDim2.fromOffset(10, 76),
	Size = UDim2.new(1, -20, 0, 22),
	BackgroundColor3 = Colors.PanelLight,
	Parent = hud,
}, { Ui.Corner(8) })
local levelFill = Ui.Create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(90, 200, 255),
	Parent = levelBack,
}, { Ui.Corner(8) })
local levelLabel = Ui.Label({
	Size = UDim2.fromScale(1, 1),
	Text = "Lv 1",
	ZIndex = 2,
	Parent = levelBack,
})

-- Actieve boosts onder de teller
local chipRow = Ui.Create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 122),
	Size = UDim2.fromOffset(600, 30),
	BackgroundTransparency = 1,
	Parent = screen,
})
Ui.Create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = chipRow,
})
local chips = {}
local function makeChip(name: string, order: number, color: Color3)
	local chip = Ui.Label({
		Size = UDim2.fromOffset(140, 28),
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		Text = "",
		LayoutOrder = order,
		Visible = false,
		Parent = chipRow,
	})
	Ui.Corner(8).Parent = chip
	chips[name] = chip
end
makeChip("Peak", 1, Color3.fromRGB(200, 150, 30))
makeChip("Double", 2, Color3.fromRGB(40, 150, 80))
makeChip("Luck", 3, Color3.fromRGB(60, 120, 220))
makeChip("Friends", 4, Color3.fromRGB(200, 80, 140))

-- Event banner
local eventBanner = Ui.Label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 156),
	Size = UDim2.fromOffset(460, 30),
	BackgroundTransparency = 0.2,
	BackgroundColor3 = Colors.Panel,
	Text = "",
	TextColor3 = Colors.SubText,
	Parent = screen,
})
Ui.Corner(8).Parent = eventBanner

-- Aura farm knop + Aura Meter onderaan
local openPanel: (name: string) -> () -- staat verderop
local selectedPose = 1
local poseBar = Ui.Create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(400, 96),
	BackgroundColor3 = Colors.Panel,
	BackgroundTransparency = 0.15,
	Parent = screen,
}, { Ui.Corner(14), Ui.Stroke(Colors.Accent, 2) })
local meterBack = Ui.Create("Frame", {
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.new(1, -16, 0, 22),
	BackgroundColor3 = Colors.PanelLight,
	Parent = poseBar,
}, { Ui.Corner(8) })
local meterFill = Ui.Create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Colors.Gold,
	Parent = meterBack,
}, { Ui.Corner(8) })
local meterLabel = Ui.Label({
	Size = UDim2.fromScale(1, 1),
	Text = "AURA METER",
	ZIndex = 2,
	Parent = meterBack,
})
local function poseAt(index: number)
	return Config.Poses[(index - 1) % #Config.Poses + 1]
end
local function poseLocked(pose): boolean
	if pose.Level then
		return not state or state.Level < pose.Level
	end
	return pose.Vip == true and not (state and state.Passes.VIP)
end
-- Een vergrendelde pose aanklikken: VIP kopen, of laten zien bij welk level hij open gaat
local function unlockHint(pose)
	if pose.Level then
		openPanel("Levels")
		return
	end
	local vip = Config.GamePasses.VIP
	if vip.Id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, vip.Id)
	end
end

local farmButton = Ui.Button({
	Position = UDim2.fromOffset(8, 38),
	Size = UDim2.new(0.6, -12, 0, 50),
	Text = "🕺 AURA FARM",
	BackgroundColor3 = Color3.fromRGB(130, 70, 230),
	Parent = poseBar,
}, function()
	if player:GetAttribute("Posing") then
		Remotes.SetPose:FireServer(nil)
		return
	end
	local pose = poseAt(selectedPose)
	if poseLocked(pose) then
		selectedPose = 1
		pose = poseAt(1)
	end
	Remotes.SetPose:FireServer(pose.Id)
end)
-- Knop met je gekozen pose: opent het pose menu
local poseButton = Ui.Button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 38),
	Size = UDim2.new(0.4, -4, 0, 50),
	Text = "",
	BackgroundColor3 = Colors.PanelLight,
	Parent = poseBar,
}, function()
	openPanel("Poses")
end)

local refreshPoseCards: () -> () = function() end -- wordt verderop ingevuld

local function refreshPoseBar()
	local pose = poseAt(selectedPose)
	poseButton.Text = (pose.Icon or "🕺") .. " " .. pose.Name .. " ▼"
	local posing = player:GetAttribute("Posing") ~= nil
	farmButton.Text = if posing then "⏹ STOP" else "🕺 AURA FARM"
	farmButton.BackgroundColor3 = if posing then Colors.Red else Color3.fromRGB(130, 70, 230)
	refreshPoseCards()
end
player:GetAttributeChangedSignal("Posing"):Connect(refreshPoseBar)

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

function openPanel(name: string)
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
rollPanel.Size = UDim2.fromOffset(500, 520)

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
local rollInfo = Ui.Label({
	Position = UDim2.fromOffset(0, 100),
	Size = UDim2.new(1, 0, 0, 22),
	Text = "",
	TextColor3 = Colors.SubText,
	Parent = rollBody,
})

local rollButton = Ui.Button({
	Position = UDim2.fromOffset(0, 128),
	Size = UDim2.new(0.5, -5, 0, 50),
	Text = "Roll",
	BackgroundColor3 = Colors.Accent,
	Parent = rollBody,
}, function()
	if not rolling then
		Remotes.RollAura:FireServer(false)
	end
end)

local freeRollButton = Ui.Button({
	Position = UDim2.new(0.5, 5, 0, 128),
	Size = UDim2.new(0.5, -5, 0, 50),
	Text = "Free Roll",
	BackgroundColor3 = Colors.Green,
	Parent = rollBody,
}, function()
	if not rolling then
		Remotes.RollAura:FireServer(true)
	end
end)

local autoRollButton = Ui.Button({
	Position = UDim2.fromOffset(0, 184),
	Size = UDim2.new(0.5, -5, 0, 40),
	Text = "Auto Roll: OFF",
	BackgroundColor3 = Colors.PanelLight,
	Parent = rollBody,
}, function()
	if state then
		Remotes.SetAutoRoll:FireServer(not state.AutoRoll)
	end
end)

local oddsButton = Ui.Button({
	Position = UDim2.new(0.5, 5, 0, 184),
	Size = UDim2.new(0.5, -5, 0, 40),
	Text = "📊 Odds",
	BackgroundColor3 = Color3.fromRGB(60, 130, 220),
	Parent = rollBody,
})

local auraList = makeList(rollBody, UDim2.fromOffset(0, 232), UDim2.new(1, 0, 1, -232))

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
	local shown = {}
	for _, aura in Auras.Exclusive do
		if state.OwnedAuras[aura.Name] then
			table.insert(shown, aura)
		end
	end
	for index = #Auras.List, 1, -1 do
		table.insert(shown, Auras.List[index])
	end
	for order, aura in shown do
		local count = state.OwnedAuras[aura.Name]
		local row = Ui.Create("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Colors.Panel,
			LayoutOrder = order,
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

-- Odds panel (kansen in procenten, verplicht volgens de Roblox regels) ---

local _, oddsBody = makePanel("Odds", "📊 Aura Odds")
local oddsInfo = Ui.Label({
	Size = UDim2.new(1, 0, 0, 56),
	Text = "",
	TextColor3 = Colors.SubText,
	Parent = oddsBody,
})
local oddsList = makeList(oddsBody, UDim2.fromOffset(0, 62), UDim2.new(1, 0, 1, -62))

local function percentText(value: number): string
	if value >= 1 then
		return string.format("%.2f%%", value)
	elseif value >= 0.01 then
		return string.format("%.3f%%", value)
	end
	return string.format("%.4f%%", value)
end

local function refreshOdds()
	for _, child in oddsList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local luck = if state then state.Luck else 1
	oddsInfo.Text = "Chances with your luck (x" .. (math.floor(luck * 100) / 100) .. ") for every roll. Every " .. Config.PityRolls .. " rolls without a 1 in " .. Config.PityMinChance .. "+ aura, the next one is guaranteed.\nRounded, so they may not add up to exactly 100%."
	local odds = Auras.Odds(luck)
	for index = #Auras.List, 1, -1 do
		local aura = Auras.List[index]
		local row = Ui.Create("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Colors.Panel,
			LayoutOrder = #Auras.List - index,
			Parent = oddsList,
		}, { Ui.Corner(8) })
		Ui.Label({
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(0.55, -10, 1, -8),
			Text = aura.Name,
			TextColor3 = auraTextColor(aura),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Ui.Label({
			Position = UDim2.new(0.55, 0, 0, 4),
			Size = UDim2.new(0.45, -10, 1, -8),
			Text = percentText(odds[aura.Name]),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
	end
end

oddsButton.Activated:Connect(function()
	refreshOdds()
	openPanel("Odds")
end)

-- Shop panel ----------------------------------------------------------

local _, shopBody = makePanel("Shop", "🛒 Shop")
local shopList = makeList(shopBody, UDim2.new(), UDim2.fromScale(1, 1))
local shopKey = ""
local refreshShop: () -> ()

local function addShopRow(order: number, title: string, description: string, buttonText: string, buttonColor: Color3, onClick)
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
		BackgroundColor3 = buttonColor,
		Parent = row,
	}, onClick)
end

local function inviteFriends()
	local ok, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok and canInvite then
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	end
end

-- Echte prijzen ophalen van Roblox (zoals je ze op create.roblox.com hebt ingesteld)
local prices: { [string]: number } = {}
local pricesLoading = false
local function loadPrices()
	if pricesLoading then
		return
	end
	pricesLoading = true
	task.spawn(function()
		local function fetch(kind: string, id: number, infoType: Enum.InfoType)
			if id == 0 then
				return
			end
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, infoType)
			end)
			if ok and info and type(info.PriceInRobux) == "number" then
				prices[kind .. id] = info.PriceInRobux
			end
		end
		for _, pass in Config.GamePasses do
			fetch("Pass", pass.Id, Enum.InfoType.GamePass)
		end
		for _, product in Config.DevProducts do
			fetch("Product", product.Id, Enum.InfoType.Product)
		end
		shopKey = "" -- opnieuw tekenen met de prijzen
		refreshShop()
	end)
end

local function priceText(kind: string, id: number, fallback: number?): string
	local price = prices[kind .. id] or fallback
	return if price then "R$ " .. price else "Buy"
end

function refreshShop()
	if not state then
		return
	end
	loadPrices()
	local key = tostring(state.PaidRandomRestricted) .. tostring(state.StarterPackBought)
	for passKey in Config.GamePasses do
		key ..= tostring(state.Passes[passKey])
	end
	if key == shopKey then
		return
	end
	shopKey = key
	for _, child in shopList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	addShopRow(0, "Invite Friends", "+10% Aura for each friend in your server", "Invite", Color3.fromRGB(200, 80, 140), inviteFriends)

	for passKey, pass in Config.GamePasses do
		local owned = state.Passes[passKey]
		addShopRow(10 + pass.Order, pass.Name, pass.Description, if owned then "Owned ✓" elseif pass.Id == 0 then "Soon" else priceText("Pass", pass.Id, pass.Price), if owned then Colors.PanelLight else Colors.Green, function()
			if pass.Id ~= 0 and not owned then
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end
		end)
	end
	for _, product in Config.DevProducts do
		local hidden = (product.Kind == "Aura" and state.PaidRandomRestricted) or (product.Kind == "Starter" and state.StarterPackBought)
		if not hidden then
			addShopRow(20 + product.Order, product.Name, product.Description, if product.Id == 0 then "Soon" else priceText("Product", product.Id, product.Price), Colors.Green, function()
				if product.Id ~= 0 then
					MarketplaceService:PromptProductPurchase(player, product.Id)
				end
			end)
		end
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

-- Quests panel --------------------------------------------------------

local _, questBody = makePanel("Quests", "📜 Daily Quests")
local questInfo = Ui.Label({
	Size = UDim2.new(1, 0, 0, 30),
	Text = "",
	TextColor3 = Colors.SubText,
	Parent = questBody,
})
local questList = makeList(questBody, UDim2.fromOffset(0, 36), UDim2.new(1, 0, 1, -36))
local questKey = ""

local function refreshQuests()
	local quest = state and state.Quest
	if not quest then
		return
	end
	local key = ""
	for _, q in quest.Quests do
		key ..= q.Progress .. "/" .. tostring(q.Claimed) .. ";"
	end
	if key == questKey then
		return
	end
	questKey = key
	for _, child in questList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local readyCount = 0
	for index, q in quest.Quests do
		local done = q.Progress >= q.Goal
		if done and not q.Claimed then
			readyCount += 1
		end
		local row = Ui.Create("Frame", {
			Size = UDim2.new(1, 0, 0, 82),
			BackgroundColor3 = Colors.Panel,
			LayoutOrder = index,
			Parent = questList,
		}, { Ui.Corner(10) })
		Ui.Label({
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(0.66, -10, 0, 28),
			Text = q.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Ui.Label({
			Position = UDim2.fromOffset(10, 34),
			Size = UDim2.new(0.66, -10, 0, 20),
			Text = "Reward: " .. q.Reward,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Colors.Gold,
			Parent = row,
		})
		local bar = Ui.Create("Frame", {
			Position = UDim2.fromOffset(10, 58),
			Size = UDim2.new(0.66, -10, 0, 16),
			BackgroundColor3 = Colors.PanelLight,
			Parent = row,
		}, { Ui.Corner(6) })
		Ui.Create("Frame", {
			Size = UDim2.fromScale(math.clamp(q.Progress / q.Goal, 0, 1), 1),
			BackgroundColor3 = Colors.Green,
			Parent = bar,
		}, { Ui.Corner(6) })
		Ui.Label({
			Size = UDim2.fromScale(1, 1),
			Text = Format.Number(q.Progress) .. " / " .. Format.Number(q.Goal),
			ZIndex = 2,
			Parent = bar,
		})
		Ui.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0.32, -8, 0, 48),
			Text = if q.Claimed then "Done ✓" elseif done then "Claim!" else "...",
			BackgroundColor3 = if done and not q.Claimed then Colors.Green else Colors.PanelLight,
			Parent = row,
		}, function()
			if done and not q.Claimed then
				Remotes.ClaimQuest:FireServer(index)
			end
		end)
	end
	badges.Quests.Visible = readyCount > 0
	badges.Quests.Text = tostring(readyCount)
end

-- Gifts panel ---------------------------------------------------------

local _, giftBody = makePanel("Gifts", "🎉 Playtime Gifts")
Ui.Label({
	Size = UDim2.new(1, 0, 0, 30),
	Text = "Keep playing to unlock gifts!",
	TextColor3 = Colors.SubText,
	Parent = giftBody,
})
local giftList = makeList(giftBody, UDim2.fromOffset(0, 36), UDim2.new(1, 0, 1, -36))
local giftButtons = {}

for index in Config.PlaytimeGifts do
	local row = Ui.Create("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Colors.Panel,
		LayoutOrder = index,
		Parent = giftList,
	}, { Ui.Corner(10) })
	local rewardLabel = Ui.Label({
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(0.62, -10, 1, -16),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Gold,
		Parent = row,
	})
	local button = Ui.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.36, -8, 0, 40),
		Text = "",
		BackgroundColor3 = Colors.PanelLight,
		Parent = row,
	}, function()
		Remotes.ClaimGift:FireServer(index)
	end)
	giftButtons[index] = { Button = button, Reward = rewardLabel }
end

-- Poses panel: alle poses als kaartjes, met slotje als je hem nog niet hebt ------
local _, posesBody = makePanel("Poses", "🕺 Choose your pose")
Ui.Label({
	Size = UDim2.new(1, 0, 0, 22),
	Text = "Tap a pose to start aura farming with it!",
	TextColor3 = Colors.SubText,
	Parent = posesBody,
})
local poseGrid = Ui.Create("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 28),
	Size = UDim2.new(1, 0, 1, -28),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 8,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = posesBody,
})
Ui.Create("UIGridLayout", {
	CellSize = UDim2.fromOffset(132, 126),
	CellPadding = UDim2.fromOffset(8, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = poseGrid,
})

local poseCards = {}
for index, pose in Config.Poses do
	local card = Ui.Button({
		Text = "",
		LayoutOrder = index,
		BackgroundColor3 = Colors.PanelLight,
		Parent = poseGrid,
	}, function()
		if poseLocked(pose) then
			unlockHint(pose)
			return
		end
		selectedPose = index
		Remotes.SetPose:FireServer(pose.Id)
		local panel = panels.Poses
		if panel and panel.Visible then
			togglePanel("Poses")
		end
		refreshPoseBar()
	end)
	local icon = Ui.Label({ Size = UDim2.new(1, 0, 0, 52), Text = pose.Icon or "🕺", Parent = card })
	local name = Ui.Label({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 26), Text = pose.Name, Parent = card })
	local status = Ui.Label({
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		Parent = card,
	})
	poseCards[index] = { Card = card, Icon = icon, Name = name, Status = status }
end

refreshPoseCards = function()
	local posingId = player:GetAttribute("Posing")
	for index, pose in Config.Poses do
		local entry = poseCards[index]
		if not entry then
			continue
		end
		local locked = poseLocked(pose)
		local selected = index == selectedPose
		if locked then
			entry.Status.Text = if pose.Level then "🔒 Level " .. pose.Level else "🔒 VIP"
			entry.Status.TextColor3 = Colors.SubText
			entry.Card.BackgroundColor3 = Color3.fromRGB(45, 40, 60)
			entry.Icon.TextTransparency = 0.6
		else
			entry.Status.Text = if posingId == pose.Id then "✨ Farming!" elseif selected then "✓ Selected" else "Tap to use"
			entry.Status.TextColor3 = if selected then Colors.Gold else Colors.Green
			entry.Card.BackgroundColor3 = if selected then Color3.fromRGB(120, 70, 210) else Colors.PanelLight
			entry.Icon.TextTransparency = 0
		end
	end
end

-- Levels panel (Level Road: wat krijg je bij welk level) ----------------
local _, levelsBody = makePanel("Levels", "⭐ Aura Levels")
local levelsInfo = Ui.Label({
	Size = UDim2.new(1, 0, 0, 26),
	Text = "",
	TextColor3 = Colors.Gold,
	Parent = levelsBody,
})
Ui.Label({
	Position = UDim2.fromOffset(0, 28),
	Size = UDim2.new(1, 0, 0, 20),
	Text = "Get XP: aura farm (pose!), PEAK AURA, battles, Aura Tower, quests",
	TextColor3 = Colors.SubText,
	Parent = levelsBody,
})
Ui.Label({
	Position = UDim2.fromOffset(0, 50),
	Size = UDim2.new(1, 0, 0, 20),
	Text = "EVERY level: a big bag of Aura + 3% more Aura forever",
	TextColor3 = Colors.Green,
	Parent = levelsBody,
})
local levelsList = makeList(levelsBody, UDim2.fromOffset(0, 76), UDim2.new(1, 0, 1, -76))
local levelsKey = -1

local function refreshLevels()
	if not state or state.Level == levelsKey then
		return
	end
	levelsKey = state.Level
	for _, child in levelsList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local order = 0
	for level = 2, Levels.MaxLevel do
		local lines = Levels.MilestoneText(level)
		if #lines == 0 then
			continue
		end
		order += 1
		local reached = state.Level >= level
		local isNext = not reached and levelsList:FindFirstChild("Next") == nil
		local row = Ui.Create("Frame", {
			Name = if isNext then "Next" else "Row",
			Size = UDim2.new(1, 0, 0, 30 + #lines * 20),
			BackgroundColor3 = if reached then Color3.fromRGB(40, 110, 70) elseif isNext then Color3.fromRGB(110, 70, 30) else Colors.Panel,
			LayoutOrder = level,
			Parent = levelsList,
		}, { Ui.Corner(10) })
		local title = Levels.TitleFor(level)
		Ui.Label({
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 24),
			Text = (if reached then "✅ " elseif isNext then "⭐ NEXT: " else "🔒 ") .. "Level " .. level .. (if title.Level == level then "  (" .. title.Title .. ")" else ""),
			TextColor3 = if reached then Colors.Text else Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		for index, line in lines do
			Ui.Label({
				Position = UDim2.fromOffset(28, 6 + index * 20),
				Size = UDim2.new(1, -40, 0, 18),
				Text = "• " .. line,
				TextColor3 = Colors.SubText,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
		end
	end
end

------------------------------------------------------------------------
-- Level up feest
------------------------------------------------------------------------

local levelUpFrame = Ui.Create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.36),
	Size = UDim2.fromOffset(460, 250),
	BackgroundColor3 = Color3.fromRGB(40, 25, 70),
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 20,
	Parent = screen,
}, { Ui.Corner(22), Ui.Stroke(Colors.Gold, 4) })
local levelUpScale = Ui.Create("UIScale", { Parent = levelUpFrame })
Ui.Label({
	Position = UDim2.fromOffset(10, 8),
	Size = UDim2.new(1, -20, 0, 64),
	Text = "LEVEL UP!",
	TextColor3 = Colors.Gold,
	ZIndex = 21,
	Parent = levelUpFrame,
})
local levelUpLevel = Ui.Label({
	Position = UDim2.fromOffset(10, 70),
	Size = UDim2.new(1, -20, 0, 34),
	Text = "",
	ZIndex = 21,
	Parent = levelUpFrame,
})
local levelUpRewards = Ui.Label({
	Position = UDim2.fromOffset(20, 110),
	Size = UDim2.new(1, -40, 1, -120),
	Text = "",
	TextColor3 = Color3.fromRGB(170, 255, 190),
	TextYAlignment = Enum.TextYAlignment.Top,
	TextScaled = false,
	TextSize = 22,
	TextWrapped = true,
	ZIndex = 21,
	Parent = levelUpFrame,
})

local CONFETTI = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(120, 220, 255),
	Color3.fromRGB(180, 120, 255),
	Color3.fromRGB(110, 255, 150),
}
local function confetti()
	for _ = 1, 60 do
		local piece = Ui.Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(math.random(), 0, -0.05, 0),
			Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)),
			Rotation = math.random(0, 360),
			BackgroundColor3 = CONFETTI[math.random(1, #CONFETTI)],
			BorderSizePixel = 0,
			ZIndex = 19,
			Parent = screen,
		})
		local duration = 1.8 + math.random() * 1.6
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.05, 0),
			Rotation = piece.Rotation + math.random(-540, 540),
		}):Play()
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

local levelUpToken = 0
Remotes.LevelUp.OnClientEvent:Connect(function(level, lines, newTitle)
	levelUpToken += 1
	local token = levelUpToken
	levelUpLevel.Text = "You are now Level " .. tostring(level) .. (if newTitle then "  •  " .. newTitle else "")
	levelUpRewards.Text = table.concat(lines, "\n")
	levelUpFrame.Visible = true
	levelUpScale.Scale = 0.3
	TweenService:Create(levelUpScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	confetti()
	task.spawn(function()
		for step = 1, 4 do
			playPing(1 + step * 0.25)
			task.wait(0.12)
		end
	end)
	task.delay(5, function()
		if token == levelUpToken then
			levelUpFrame.Visible = false
		end
	end)
end)
levelUpFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		levelUpFrame.Visible = false
	end
end)

------------------------------------------------------------------------
-- Menu links
------------------------------------------------------------------------

local menu = Ui.Create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(2 * 76 + 8, 4 * 84),
	BackgroundTransparency = 1,
	Parent = screen,
})
Ui.Create("UIGridLayout", {
	CellSize = UDim2.fromOffset(76, 76),
	CellPadding = UDim2.fromOffset(8, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = menu,
})

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
menuButton(5, "Quests", "📜", "Quests", Color3.fromRGB(90, 160, 200))
menuButton(6, "Gifts", "🎉", "Gifts", Color3.fromRGB(240, 120, 60))
menuButton(7, "Codes", "🎟️", "Codes", Color3.fromRGB(60, 130, 220))
menuButton(8, "Levels", "⭐", "Levels", Color3.fromRGB(40, 170, 200))

------------------------------------------------------------------------
-- Meldingen
------------------------------------------------------------------------

local toastHolder = Ui.Create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -124),
	Size = UDim2.fromOffset(520, 260),
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
	local title = Levels.TitleFor(state.Level)
	levelFill.Size = UDim2.fromScale(math.clamp(state.XP / math.max(1, state.XPNeeded), 0, 1), 1)
	levelLabel.Text = "Lv " .. state.Level .. " " .. title.Title .. "  •  " .. Format.Number(state.XP) .. "/" .. Format.Number(state.XPNeeded) .. " XP"
	incomeLabel.Text = "x" .. tostring(math.floor(state.Multiplier * 100) / 100) .. " boost  •  " .. Format.Number(state.IncomePerSecond) .. "/s"

	rollButton.Text = "Roll (" .. Format.Number(state.RollCost) .. ")"

	rebirthMultiplierLabel.Text = "x" .. state.RebirthMultiplier .. "  →  x" .. state.NextRebirthMultiplier
	local progress = math.clamp(state.Aura / state.RebirthCost, 0, 1)
	progressFill.Size = UDim2.fromScale(progress, 1)
	progressLabel.Text = Format.Number(state.Aura) .. " / " .. Format.Number(state.RebirthCost)
	rebirthButton.BackgroundColor3 = if progress >= 1 then Colors.Gold else Colors.PanelLight
	rebirthButton.Text = if progress >= 1 then "REBIRTH NOW!" else "Need " .. Format.Number(state.RebirthCost) .. " Aura"
	badges.Rebirth.Visible = progress >= 1

	local discovered = 0
	for _, aura in Auras.List do
		if state.OwnedAuras[aura.Name] then
			discovered += 1
		end
	end
	rollInfo.Text = "Luck x" .. (math.floor(state.Luck * 100) / 100)
		.. "  •  Rare aura guaranteed in " .. state.PityLeft .. " rolls"
		.. "  •  Index " .. discovered .. "/" .. #Auras.List
	autoRollButton.Text = if not state.AutoRollUnlocked then "🔒 Auto Roll (Rebirth 1)" elseif state.AutoRoll then "Auto Roll: ON" else "Auto Roll: OFF"
	autoRollButton.BackgroundColor3 = if state.AutoRoll then Colors.Green else Colors.PanelLight

	dailyStreakLabel.Text = "Streak: day " .. state.DailyStreak

	if listChanged then
		refreshAuraList()
	end
	if openPanelName == "Odds" then
		refreshOdds()
	end
	refreshShop()
	refreshQuests()
	refreshPoseBar()
	refreshLevels()
	levelsInfo.Text = "Level " .. state.Level .. " • " .. title.Title .. " • Aura x" .. string.format("%.2f", state.LevelMultiplier)
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

	-- Boosts
	local peak = math.max(0, state.Boosts.Peak - elapsed)
	local double = math.max(0, state.Boosts.Double - elapsed)
	local luck = math.max(0, state.Boosts.Luck - elapsed)
	chips.Peak.Visible = peak > 0
	chips.Peak.Text = "PEAK AURA " .. Format.Time(peak)
	chips.Double.Visible = double > 0
	chips.Double.Text = "2x Aura " .. Format.Time(double)
	chips.Luck.Visible = luck > 0
	chips.Luck.Text = "2x Luck " .. Format.Time(luck)
	chips.Friends.Visible = state.FriendsInServer > 0
	chips.Friends.Text = "Friends +" .. math.min(state.FriendsInServer, Config.MaxFriendBonus) * 10 .. "%"

	-- Gifts
	local readyGifts = 0
	if state.Quest then
		for index, gift in state.Quest.Gifts do
			local entry = giftButtons[index]
			if entry then
				local readyIn = math.max(0, gift.ReadyIn - elapsed)
				entry.Reward.Text = gift.Reward
				if gift.Claimed then
					entry.Button.Text = "Claimed ✓"
					entry.Button.BackgroundColor3 = Colors.PanelLight
				elseif readyIn <= 0 then
					readyGifts += 1
					entry.Button.Text = "Claim!"
					entry.Button.BackgroundColor3 = Colors.Green
				else
					entry.Button.Text = Format.Time(readyIn)
					entry.Button.BackgroundColor3 = Colors.PanelLight
				end
			end
		end
		questInfo.Text = "All 3 done = " .. state.Quest.AllDoneReward .. "  •  New quests in " .. Format.Time(state.Quest.ResetIn - elapsed)
	end
	badges.Gifts.Visible = readyGifts > 0
	badges.Gifts.Text = tostring(readyGifts)

	-- Aura Meter
	local peakActive = peak > 0
	local meter = player:GetAttribute("AuraMeter") or 0
	meterFill.Size = UDim2.fromScale(if peakActive then 1 else math.clamp(meter / 100, 0, 1), 1)
	meterFill.BackgroundColor3 = if peakActive then Color3.fromRGB(255, 120, 220) else Colors.Gold
	meterLabel.Text = if peakActive then "PEAK AURA! 2x Aura " .. Format.Time(peak) elseif player:GetAttribute("Posing") then "AURA FARMING... " .. math.floor(meter) .. "%" else "AURA METER " .. math.floor(meter) .. "%  (stand still + pose)"

	-- Event banner
	local now = workspace:GetServerTimeNow()
	local eventId = workspace:GetAttribute("EventId")
	local event = if type(eventId) == "string" then Config.Events[eventId] else nil
	if event then
		local ends = workspace:GetAttribute("EventEnds") or now
		eventBanner.Text = "⚡ " .. event.Name .. " " .. Format.Time(ends - now) .. "  •  " .. event.Description
		eventBanner.TextColor3 = Colors.Gold
		eventBanner.BackgroundColor3 = Color3.fromRGB(110, 50, 190)
	else
		local nextAt = workspace:GetAttribute("NextEventAt")
		eventBanner.Text = if type(nextAt) == "number" then "Next event in " .. Format.Time(nextAt - now) else ""
		eventBanner.TextColor3 = Colors.SubText
		eventBanner.BackgroundColor3 = Colors.Panel
	end
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
