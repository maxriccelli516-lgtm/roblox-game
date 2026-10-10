-- Bouwt de plots, generators, lopende banden, knoppen en regelt kopen, ophalen en rebirth.

local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Builder = require(script.Parent.Builder)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)

local Remotes = ReplicatedStorage.Remotes

local TycoonService = {}

local AFFORD_COLOR = Color3.fromRGB(60, 255, 120)
local TOO_EXPENSIVE_COLOR = Color3.fromRGB(255, 80, 80)
local PLOT_COLORS = {
	Color3.fromRGB(70, 50, 110),
	Color3.fromRGB(40, 70, 110),
	Color3.fromRGB(40, 95, 80),
	Color3.fromRGB(110, 60, 80),
	Color3.fromRGB(100, 85, 40),
	Color3.fromRGB(60, 60, 75),
}

local plots = {}
local plotByPlayer: { [Player]: any } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

local function at(plot, x: number, y: number, z: number): CFrame
	return plot.CFrame * CFrame.new(x, y, z)
end

local function ownerFromHit(plot, hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if player and player == plot.Owner then
		return player
	end
	return nil
end

local function updateStoredLabel(plot)
	if not plot.StoredLabel then
		return
	end
	local amount = plot.Stored
	if plot.Owner then
		amount = math.floor(plot.Stored * Economy.GetMultiplier(plot.Owner))
	end
	plot.StoredLabel.Text = "COLLECT\n" .. Format.Number(amount) .. " Aura"
end

local function updateSign(plot)
	plot.SignLabel.Text = if plot.Owner then plot.Owner.DisplayName .. "'s Aura Farm" else "Free Plot"
end

------------------------------------------------------------------------
-- Orbs
------------------------------------------------------------------------

local function spawnOrb(plot, session, item)
	if session.Count >= Config.MaxOrbsPerPlot then
		return
	end
	local z = Config.Lines[item.Line].Z
	local orb = Builder.Part({
		Name = "AuraOrb",
		Size = Vector3.new(1.2, 1.2, 1.2),
		Material = Enum.Material.Neon,
		Color = item.Color,
		Anchored = false,
		CanCollide = true,
		CanQuery = false,
		CollisionGroup = "Orbs",
		CFrame = at(plot, item.X, 7.2, z),
		Parent = plot.OrbFolder,
	})
	orb:SetAttribute("Value", item.Value)
	session.Count += 1
	orb.Destroying:Once(function()
		session.Count -= 1
	end)
	pcall(function()
		orb:SetNetworkOwner(nil)
	end)
	Debris:AddItem(orb, Config.OrbLifetime)
end

local function isPlotOrb(plot, hit: BasePart): boolean
	return hit.Parent == plot.OrbFolder and hit:GetAttribute("Value") ~= nil
end

------------------------------------------------------------------------
-- Onderdelen bouwen
------------------------------------------------------------------------

local function buildLine(plot, lineIndex: number, folder: Instance)
	local z = Config.Lines[lineIndex].Z
	local conveyor = Builder.Part({
		Name = "Conveyor",
		Size = Vector3.new(66, 1, 6),
		CFrame = at(plot, -3, 1.5, z),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(45, 45, 55),
		Parent = folder,
	})
	conveyor.AssemblyLinearVelocity = plot.CFrame.RightVector * Config.ConveyorSpeed

	Builder.Part({
		Name = "Stripe",
		Size = Vector3.new(66, 0.05, 0.6),
		CFrame = at(plot, -3, 2.03, z),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(170, 110, 255),
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})

	for _, side in { -1, 1 } do
		Builder.Part({
			Name = "Rail",
			Size = Vector3.new(66, 1.6, 0.6),
			CFrame = at(plot, -3, 2.8, z + side * 3.3),
			Color = Color3.fromRGB(25, 25, 30),
			Parent = folder,
		})
	end
	Builder.Part({
		Name = "BackStop",
		Size = Vector3.new(0.6, 1.6, 6),
		CFrame = at(plot, -36.3, 2.8, z),
		Color = Color3.fromRGB(25, 25, 30),
		Parent = folder,
	})

	local collector = Builder.Part({
		Name = "Collector",
		Size = Vector3.new(6, 5, 8),
		CFrame = at(plot, 33, 3.5, z),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(150, 70, 255),
		Transparency = 0.15,
		Parent = folder,
	})
	Builder.Sparkles(collector, Color3.fromRGB(200, 150, 255), 12)
	Builder.Billboard(collector, "AURA COLLECTOR", UDim2.new(8, 0, 1.5, 0), Vector3.new(0, 4, 0))

	collector.Touched:Connect(function(hit)
		if not isPlotOrb(plot, hit) or hit:GetAttribute("Collected") then
			return
		end
		hit:SetAttribute("Collected", true)
		plot.Stored += hit:GetAttribute("Value") :: number
		hit:Destroy()
		updateStoredLabel(plot)
	end)
end

local function buildDropper(plot, item, folder: Instance, session)
	local z = Config.Lines[item.Line].Z
	local dark = Color3.fromRGB(30, 30, 40)
	Builder.Part({ Name = "Pillar", Size = Vector3.new(2, 11, 2), CFrame = at(plot, item.X, 6.5, z + 7), Color = dark, Parent = folder })
	Builder.Part({ Name = "Arm", Size = Vector3.new(2, 1.2, 8), CFrame = at(plot, item.X, 11.5, z + 3.5), Color = dark, Parent = folder })
	local head = Builder.Part({
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4.5, 4.5, 4.5),
		CFrame = at(plot, item.X, 10, z),
		Material = Enum.Material.Neon,
		Color = item.Color,
		CanCollide = false,
		Parent = folder,
	})
	Builder.Sparkles(head, item.Color, 6)
	Builder.Billboard(head, item.Name, UDim2.new(8, 0, 1.4, 0), Vector3.new(0, 3.6, 0), item.Color)

	local owner = plot.Owner
	task.spawn(function()
		while session.Active and folder.Parent do
			task.wait(item.Interval / Economy.DropperSpeed(owner))
			if not session.Active or not folder.Parent then
				break
			end
			spawnOrb(plot, session, item)
		end
	end)
end

local function buildUpgrader(plot, item, folder: Instance)
	local z = Config.Lines[item.Line].Z
	local frameColor = Color3.fromRGB(30, 30, 40)
	for _, side in { -1, 1 } do
		Builder.Part({ Name = "Post", Size = Vector3.new(1, 6, 1), CFrame = at(plot, item.X, 4, z + side * 3.9), Color = frameColor, Parent = folder })
	end
	local bar = Builder.Part({ Name = "Bar", Size = Vector3.new(1, 1, 8.8), CFrame = at(plot, item.X, 7.5, z), Color = frameColor, Parent = folder })
	local laser = Builder.Part({
		Name = "Laser",
		Size = Vector3.new(0.6, 3.5, 6.6),
		CFrame = at(plot, item.X, 3.75, z),
		Material = Enum.Material.Neon,
		Color = item.Color,
		Transparency = 0.45,
		CanCollide = false,
		Parent = folder,
	})
	Builder.Billboard(bar, item.Name .. " x" .. tostring(item.Multiplier), UDim2.new(9, 0, 1.4, 0), Vector3.new(0, 1.8, 0), item.Color)

	local attribute = "Up_" .. item.Id
	laser.Touched:Connect(function(hit)
		if not isPlotOrb(plot, hit) or hit:GetAttribute(attribute) then
			return
		end
		hit:SetAttribute(attribute, true)
		hit:SetAttribute("Value", (hit:GetAttribute("Value") :: number) * item.Multiplier)
		hit.Color = item.Color
	end)
end

local function buildWalls(plot, folder: Instance)
	local half = Config.PlotSize / 2
	local glass = Color3.fromRGB(150, 120, 255)
	local function wall(size: Vector3, x: number, z: number)
		Builder.Part({
			Name = "Wall",
			Size = size,
			CFrame = at(plot, x, 5, z),
			Material = Enum.Material.Glass,
			Color = glass,
			Transparency = 0.6,
			Parent = folder,
		})
		Builder.Part({
			Name = "WallGlow",
			Size = Vector3.new(size.X, 0.5, size.Z) + Vector3.new(0.2, 0, 0.2),
			CFrame = at(plot, x, 9.25, z),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(190, 140, 255),
			Parent = folder,
		})
	end
	wall(Vector3.new(Config.PlotSize, 8, 1), 0, half)
	wall(Vector3.new(1, 8, Config.PlotSize), half, 0)
	wall(Vector3.new(1, 8, Config.PlotSize), -half, 0)
	local pieceLength = half - 10
	wall(Vector3.new(pieceLength, 8, 1), 10 + pieceLength / 2, -half)
	wall(Vector3.new(pieceLength, 8, 1), -(10 + pieceLength / 2), -half)
end

local function buildLamps(plot, folder: Instance)
	for _, pos in { Vector2.new(-50, -50), Vector2.new(50, -50), Vector2.new(-50, 0), Vector2.new(50, 0), Vector2.new(-50, 50), Vector2.new(50, 50) } do
		Builder.Part({ Name = "LampPost", Size = Vector3.new(1, 10, 1), CFrame = at(plot, pos.X, 6, pos.Y), Color = Color3.fromRGB(30, 30, 40), Parent = folder })
		local bulb = Builder.Part({
			Name = "Bulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.5, 2.5, 2.5),
			CFrame = at(plot, pos.X, 11.5, pos.Y),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 200, 255),
			Parent = folder,
		})
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 1.5
		light.Color = Color3.fromRGB(220, 170, 255)
		light.Parent = bulb
	end
end

local function buildTower(plot, folder: Instance)
	Builder.Part({ Name = "TowerBase", Size = Vector3.new(10, 2, 10), CFrame = at(plot, -44, 2, 44), Color = Color3.fromRGB(30, 30, 40), Parent = folder })
	local tower = Builder.Part({
		Name = "Tower",
		Size = Vector3.new(4, 36, 4),
		CFrame = at(plot, -44, 21, 44),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(170, 90, 255),
		Parent = folder,
	})
	local top = Builder.Part({
		Name = "TowerTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		CFrame = at(plot, -44, 41, 44),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 120, 255),
		Parent = folder,
	})
	Builder.Sparkles(tower, Color3.fromRGB(200, 140, 255), 20)
	Builder.Sparkles(top, Color3.fromRGB(255, 180, 255), 30)
	local light = Instance.new("PointLight")
	light.Range = 45
	light.Brightness = 2
	light.Color = Color3.fromRGB(220, 150, 255)
	light.Parent = top
end

local function buildThrone(plot, folder: Instance)
	local gold = Color3.fromRGB(255, 205, 60)
	Builder.Part({ Name = "ThroneBase", Size = Vector3.new(14, 2, 10), CFrame = at(plot, 0, 2, 44), Material = Enum.Material.Marble, Color = Color3.fromRGB(240, 240, 250), Parent = folder })
	Builder.Part({ Name = "ThroneBack", Size = Vector3.new(10, 12, 2), CFrame = at(plot, 0, 9, 48), Material = Enum.Material.Neon, Color = gold, Parent = folder })
	for _, side in { -1, 1 } do
		Builder.Part({ Name = "ThroneArm", Size = Vector3.new(1.5, 3, 6), CFrame = at(plot, side * 4, 4.5, 45), Material = Enum.Material.Neon, Color = gold, Parent = folder })
	end
	local seat = Instance.new("Seat")
	seat.Name = "ThroneSeat"
	seat.Anchored = true
	seat.Size = Vector3.new(6, 1, 5)
	seat.CFrame = at(plot, 0, 3.5, 45)
	seat.Color = Color3.fromRGB(150, 40, 200)
	seat.Material = Enum.Material.Fabric
	seat.Parent = folder
	Builder.Sparkles(seat, gold, 25)
	local back = folder:FindFirstChild("ThroneBack") :: BasePart
	Builder.Billboard(back, "👑 AURA KING 👑", UDim2.new(12, 0, 2, 0), Vector3.new(0, 8, 0), gold)
end

local function buildItem(plot, item, session)
	local folder = Instance.new("Model")
	folder.Name = "Item_" .. item.Id
	folder.Parent = plot.ItemFolder
	if item.Type == "Dropper" then
		buildDropper(plot, item, folder, session)
	elseif item.Type == "Upgrader" then
		buildUpgrader(plot, item, folder)
	elseif item.Type == "Line" then
		buildLine(plot, item.Line, folder)
	elseif item.Id == "Walls" then
		buildWalls(plot, folder)
	elseif item.Id == "Lamps" then
		buildLamps(plot, folder)
	elseif item.Id == "Tower" then
		buildTower(plot, folder)
	elseif item.Id == "Throne" then
		buildThrone(plot, folder)
	end
end

------------------------------------------------------------------------
-- Knoppen
------------------------------------------------------------------------

local function updateButtonColors(plot)
	local data = plot.Owner and DataService.Get(plot.Owner)
	if not data then
		return
	end
	for itemId, button in plot.Buttons do
		local item = Config.ItemsById[itemId]
		button.Color = if data.Aura >= item.Price then AFFORD_COLOR else TOO_EXPENSIVE_COLOR
	end
end

local function refreshButtons(plot)
	local data = plot.Owner and DataService.Get(plot.Owner)
	for itemId, button in plot.Buttons do
		if not data or data.Purchased[itemId] then
			button:Destroy()
			plot.Buttons[itemId] = nil
		end
	end
	if not data then
		return
	end
	for _, item in Config.Items do
		local unlocked = item.Requires == nil or data.Purchased[item.Requires]
		if unlocked and not data.Purchased[item.Id] and not plot.Buttons[item.Id] then
			local slot = Config.ButtonSlots[item.Index]
			local button = Builder.Part({
				Name = "Button_" .. item.Id,
				Size = Vector3.new(5, 0.6, 5),
				CFrame = at(plot, slot.X, 1.3, slot.Y),
				Material = Enum.Material.Neon,
				Color = AFFORD_COLOR,
				Parent = plot.ButtonFolder,
			})
			local priceText = if item.Price == 0 then "FREE" else Format.Number(item.Price) .. " Aura"
			Builder.Billboard(button, item.Name .. "\n" .. priceText, UDim2.new(7, 0, 3, 0), Vector3.new(0, 3, 0))

			local debounce = false
			button.Touched:Connect(function(hit)
				if debounce then
					return
				end
				local player = ownerFromHit(plot, hit)
				if not player then
					return
				end
				debounce = true
				TycoonService.Purchase(player, item.Id)
				task.wait(0.6)
				debounce = false
			end)
			plot.Buttons[item.Id] = button
		end
	end
	updateButtonColors(plot)
end

------------------------------------------------------------------------
-- Plot opbouwen
------------------------------------------------------------------------

local function clearPlot(plot)
	if plot.Session then
		plot.Session.Active = false
	end
	plot.ItemFolder:ClearAllChildren()
	plot.OrbFolder:ClearAllChildren()
	for _, button in plot.Buttons do
		button:Destroy()
	end
	plot.Buttons = {}
	plot.Stored = 0
end

local function rebuildPlot(plot)
	clearPlot(plot)
	local session = { Active = true, Count = 0 }
	plot.Session = session
	if plot.Owner then
		local data = DataService.Get(plot.Owner)
		local baseLine = Instance.new("Model")
		baseLine.Name = "BaseLine"
		baseLine.Parent = plot.ItemFolder
		buildLine(plot, 1, baseLine)
		for _, item in Config.Items do
			if data and data.Purchased[item.Id] then
				buildItem(plot, item, session)
			end
		end
	end
	refreshButtons(plot)
	updateStoredLabel(plot)
	updateSign(plot)
end

local function createPlot(index: number, parent: Instance)
	local angle = (index - 1) / Config.PlotCount * math.pi * 2
	local position = Vector3.new(math.cos(angle) * Config.PlotRadius, 0, math.sin(angle) * Config.PlotRadius)
	local plot = {
		Index = index,
		CFrame = CFrame.lookAt(position, Vector3.zero),
		Owner = nil,
		Stored = 0,
		Buttons = {},
		Session = nil,
	}

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = parent
	plot.Model = model

	Builder.Part({
		Name = "Floor",
		Size = Vector3.new(Config.PlotSize, 1, Config.PlotSize),
		CFrame = at(plot, 0, 0.5, 0),
		Color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1],
		Material = Enum.Material.Slate,
		Parent = model,
	})
	Builder.Part({
		Name = "SpawnPad",
		Size = Vector3.new(8, 0.2, 8),
		CFrame = at(plot, 0, 1.1, -46),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 200, 255),
		CanCollide = false,
		Parent = model,
	})

	for _, side in { -1, 1 } do
		Builder.Part({ Name = "SignPost", Size = Vector3.new(1, 12, 1), CFrame = at(plot, side * 12.5, 7, -53), Color = Color3.fromRGB(30, 30, 40), Parent = model })
	end
	local sign = Builder.Part({
		Name = "Sign",
		Size = Vector3.new(26, 5, 1),
		CFrame = at(plot, 0, 11, -53),
		Color = Color3.fromRGB(25, 20, 40),
		Parent = model,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.fromRGB(230, 200, 255)
	signLabel.Parent = surface
	plot.SignLabel = signLabel

	local collectPad = Builder.Part({
		Name = "CollectPad",
		Size = Vector3.new(9, 0.4, 9),
		CFrame = at(plot, 44, 1.2, 9),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 220, 80),
		Parent = model,
	})
	plot.StoredLabel = Builder.Billboard(collectPad, "COLLECT", UDim2.new(10, 0, 3.5, 0), Vector3.new(0, 4, 0), Color3.fromRGB(255, 230, 120))
	local lastCollect = 0
	collectPad.Touched:Connect(function(hit)
		if os.clock() - lastCollect < 1 then
			return
		end
		local player = ownerFromHit(plot, hit)
		if player then
			lastCollect = os.clock()
			TycoonService.Collect(player)
		end
	end)

	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = model
	plot.ItemFolder = items

	local buttons = Instance.new("Folder")
	buttons.Name = "Buttons"
	buttons.Parent = model
	plot.ButtonFolder = buttons

	local orbs = Instance.new("Folder")
	orbs.Name = "Orbs"
	orbs.Parent = model
	plot.OrbFolder = orbs

	updateSign(plot)
	updateStoredLabel(plot)
	return plot
end

------------------------------------------------------------------------
-- Publiek
------------------------------------------------------------------------

function TycoonService.GetPlot(player: Player)
	return plotByPlayer[player]
end

function TycoonService.Claim(player: Player): boolean
	if plotByPlayer[player] then
		return true
	end
	for _, plot in plots do
		if not plot.Owner then
			plot.Owner = player
			plotByPlayer[player] = plot
			rebuildPlot(plot)
			return true
		end
	end
	return false
end

function TycoonService.Release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	clearPlot(plot)
	plot.Owner = nil
	updateSign(plot)
	updateStoredLabel(plot)
end

function TycoonService.SpawnCFrame(player: Player): CFrame?
	local plot = plotByPlayer[player]
	return plot and at(plot, 0, 4, -44)
end

function TycoonService.Collect(player: Player, silent: boolean?)
	local plot = plotByPlayer[player]
	if not plot or plot.Stored <= 0 or not DataService.Get(player) then
		return
	end
	local amount = math.floor(plot.Stored * Economy.GetMultiplier(player))
	plot.Stored = 0
	updateStoredLabel(plot)
	if amount > 0 then
		DataService.AddAura(player, amount)
		if not silent then
			notify(player, "+" .. Format.Number(amount) .. " Aura", "collect")
		end
	end
end

function TycoonService.Purchase(player: Player, itemId: string)
	local plot = plotByPlayer[player]
	local data = DataService.Get(player)
	local item = Config.ItemsById[itemId]
	if not plot or not data or not item or data.Purchased[item.Id] then
		return
	end
	if item.Requires and not data.Purchased[item.Requires] then
		return
	end
	if data.Aura < item.Price then
		notify(player, "You need " .. Format.Number(item.Price - data.Aura) .. " more Aura!", "error")
		return
	end
	data.Aura -= item.Price
	data.Purchased[item.Id] = true
	buildItem(plot, item, plot.Session)
	refreshButtons(plot)
	DataService.Changed(player)
	notify(player, "Unlocked " .. item.Name .. "!", "success")
end

function TycoonService.Rebirth(player: Player)
	local plot = plotByPlayer[player]
	local data = DataService.Get(player)
	if not plot or not data then
		return
	end
	local cost = Config.RebirthCost(data.Rebirths)
	if data.Aura < cost then
		notify(player, "You need " .. Format.Number(cost) .. " Aura to rebirth!", "error")
		return
	end
	data.Rebirths += 1
	data.Aura = Config.StartAura
	data.Purchased = {}
	rebuildPlot(plot)
	DataService.Changed(player)
	notify(player, "REBIRTH! You now earn x" .. tostring(Config.RebirthMultiplier(data.Rebirths)) .. " Aura", "rare")
	for _, other in Players:GetPlayers() do
		if other ~= player then
			notify(other, player.DisplayName .. " just rebirthed! (" .. data.Rebirths .. ")", "info")
		end
	end
end

function TycoonService.Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Orbs")
		PhysicsService:RegisterCollisionGroup("Players")
	end)
	PhysicsService:CollisionGroupSetCollidable("Orbs", "Orbs", false)
	PhysicsService:CollisionGroupSetCollidable("Orbs", "Players", false)

	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = workspace
	for index = 1, Config.PlotCount do
		plots[index] = createPlot(index, folder)
	end

	DataService.OnChanged(function(player)
		local plot = plotByPlayer[player]
		if plot then
			updateButtonColors(plot)
			updateStoredLabel(plot)
		end
	end)

	-- Auto Collect gamepass
	task.spawn(function()
		while true do
			task.wait(1)
			for player, _ in plotByPlayer do
				if Economy.HasPass(player, "AutoCollect") then
					TycoonService.Collect(player, true)
				end
			end
		end
	end)
end

return TycoonService
