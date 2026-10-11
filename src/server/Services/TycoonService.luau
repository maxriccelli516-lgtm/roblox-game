-- Bouwt de plots, generators, lopende banden, knoppen en regelt kopen, ophalen en rebirth.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Builder = require(script.Parent.Builder)
local Decor = require(script.Parent.Decor)
local Bus = require(script.Parent.Bus)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)

local Remotes = ReplicatedStorage.Remotes

local TycoonService = {}

local AFFORD_COLOR = Color3.fromRGB(60, 255, 120)
local TOO_EXPENSIVE_COLOR = Color3.fromRGB(255, 80, 80)
local PLOT_COLORS = {
	Color3.fromRGB(160, 100, 255),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(50, 200, 150),
	Color3.fromRGB(255, 100, 160),
	Color3.fromRGB(255, 160, 50),
	Color3.fromRGB(110, 210, 70),
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

local METAL = Color3.fromRGB(70, 72, 82)
local DARK_METAL = Color3.fromRGB(40, 42, 50)
local WHITE = Color3.fromRGB(240, 240, 245)

local function buildLine(plot, lineIndex: number, folder: Instance)
	local z = Config.Lines[lineIndex].Z
	local conveyor = Builder.Part({
		Name = "Conveyor",
		Size = Vector3.new(66, 1, 6),
		CFrame = at(plot, -3, 1.5, z),
		Material = Enum.Material.Rubber,
		Color = Color3.fromRGB(35, 35, 40),
		Parent = folder,
	})
	conveyor.AssemblyLinearVelocity = plot.CFrame.RightVector * Config.ConveyorSpeed
	-- De client tekent bewegende streepjes op de band
	CollectionService:AddTag(conveyor, "Conveyor")

	for _, side in { -1, 1 } do
		Builder.Part({
			Name = "Rail",
			Size = Vector3.new(66, 1.6, 0.6),
			CFrame = at(plot, -3, 2.8, z + side * 3.3),
			Material = Enum.Material.Metal,
			Color = METAL,
			Parent = folder,
		})
		Builder.Part({
			Name = "RailStripe",
			Size = Vector3.new(66, 0.3, 0.65),
			CFrame = at(plot, -3, 3.3, z + side * 3.3),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(255, 200, 40),
			CanCollide = false,
			Parent = folder,
		})
		for x = -33, 27, 10 do
			Builder.Part({ Name = "Leg", Size = Vector3.new(0.8, 1, 0.8), CFrame = at(plot, x, 0.9, z + side * 2.6), Material = Enum.Material.Metal, Color = DARK_METAL, Parent = folder })
		end
	end
	Builder.Part({
		Name = "BackStop",
		Size = Vector3.new(0.6, 1.6, 6),
		CFrame = at(plot, -36.3, 2.8, z),
		Material = Enum.Material.Metal,
		Color = METAL,
		Parent = folder,
	})

	-- Aura Collector: een glazen tank met een gloeiende kern
	Builder.Part({ Name = "CollectorBase", Size = Vector3.new(8, 1, 10), CFrame = at(plot, 33, 1, z), Material = Enum.Material.DiamondPlate, Color = METAL, Parent = folder })
	local collector = Builder.Part({
		Name = "Collector",
		Size = Vector3.new(6, 5, 8),
		CFrame = at(plot, 33, 3.5, z),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(190, 150, 255),
		Transparency = 0.45,
		Parent = folder,
	})
	Builder.Part({ Name = "CollectorCap", Size = Vector3.new(7, 1, 9), CFrame = at(plot, 33, 6.5, z), Material = Enum.Material.Metal, Color = METAL, Parent = folder })
	Builder.Part({
		Name = "CollectorPipe",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 1.6, 1.6),
		CFrame = at(plot, 33, 9, z) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = METAL,
		Parent = folder,
	})
	local core = Builder.Part({
		Name = "CollectorCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3,
		CFrame = at(plot, 33, 3.6, z),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(170, 90, 255),
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = folder,
	})
	Decor.Animate(core, nil, 0.4, 0.35)
	local top = Builder.Part({
		Name = "CollectorGem",
		Size = Vector3.one * 1.6,
		CFrame = at(plot, 33, 12, z) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(200, 150, 255),
		CanCollide = false,
		Parent = folder,
	})
	Decor.Animate(top, 90, 0.5)
	Builder.Sparkles(core, Color3.fromRGB(200, 150, 255), 10)
	Builder.Billboard(top, "AURA COLLECTOR", UDim2.new(8, 0, 1.5, 0), Vector3.new(0, 2.2, 0))

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
	local accent = item.Color:Lerp(Color3.new(0, 0, 0), 0.35)
	Builder.Part({ Name = "Foot", Size = Vector3.new(4, 1, 4), CFrame = at(plot, item.X, 1.5, z + 7), Material = Enum.Material.DiamondPlate, Color = METAL, Parent = folder })
	Builder.Part({ Name = "Pillar", Size = Vector3.new(2, 11, 2), CFrame = at(plot, item.X, 7, z + 7), Material = Enum.Material.Metal, Color = METAL, Parent = folder })
	Builder.Part({ Name = "PillarStripe", Size = Vector3.new(2.1, 1, 2.1), CFrame = at(plot, item.X, 5, z + 7), Color = item.Color, Material = Enum.Material.SmoothPlastic, Parent = folder })
	Builder.Part({ Name = "Arm", Size = Vector3.new(2, 1.2, 6), CFrame = at(plot, item.X, 11.8, z + 4), Material = Enum.Material.Metal, Color = METAL, Parent = folder })
	-- De machine boven de band
	Builder.Part({ Name = "Housing", Size = Vector3.new(4.4, 3, 4.4), CFrame = at(plot, item.X, 11, z), Material = Enum.Material.SmoothPlastic, Color = accent, Parent = folder })
	Builder.Part({ Name = "HousingTrim", Size = Vector3.new(4.8, 0.5, 4.8), CFrame = at(plot, item.X, 12.6, z), Material = Enum.Material.Metal, Color = METAL, Parent = folder })
	local window = Builder.Part({
		Name = "Window",
		Size = Vector3.new(2.6, 1.6, 0.2),
		CFrame = at(plot, item.X, 11, z - 2.25),
		Material = Enum.Material.Neon,
		Color = item.Color,
		CanCollide = false,
		Parent = folder,
	})
	Decor.Animate(window, nil, nil, 0.3)
	Builder.Part({
		Name = "Nozzle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 1.8, 1.8),
		CFrame = at(plot, item.X, 8.9, z) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = DARK_METAL,
		CanCollide = false,
		Parent = folder,
	})
	local gem = Builder.Part({
		Name = "Gem",
		Size = Vector3.one * 2.2,
		CFrame = at(plot, item.X, 15, z) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Material = Enum.Material.Neon,
		Color = item.Color,
		CanCollide = false,
		Parent = folder,
	})
	Decor.Animate(gem, 120, 0.6)
	Builder.Sparkles(gem, item.Color, 6)
	Builder.Billboard(gem, item.Name, UDim2.new(8, 0, 1.4, 0), Vector3.new(0, 2.6, 0), item.Color)

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
	for _, side in { -1, 1 } do
		Builder.Part({ Name = "Post", Size = Vector3.new(1.4, 7, 1.4), CFrame = at(plot, item.X, 4.5, z + side * 4), Material = Enum.Material.Metal, Color = METAL, Parent = folder })
		Builder.Part({ Name = "PostLight", Size = Vector3.new(1.5, 0.6, 1.5), CFrame = at(plot, item.X, 6.5, z + side * 4), Material = Enum.Material.Neon, Color = item.Color, Parent = folder })
	end
	local bar = Builder.Part({ Name = "Bar", Size = Vector3.new(1.6, 1.4, 9.4), CFrame = at(plot, item.X, 8.6, z), Material = Enum.Material.Metal, Color = METAL, Parent = folder })
	local laser = Builder.Part({
		Name = "Laser",
		Size = Vector3.new(0.6, 3.5, 6.6),
		CFrame = at(plot, item.X, 3.75, z),
		Material = Enum.Material.Neon,
		Color = item.Color,
		Transparency = 0.5,
		CanCollide = false,
		Parent = folder,
	})
	Decor.Animate(laser, nil, nil, 0.3)
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
	-- Wit hek rondom het plot met stenen hoekpilaren
	local half = Config.PlotSize / 2 - 1
	local function p(x: number, z: number): Vector3
		return at(plot, x, 1, z).Position
	end
	Decor.Fence(p(-half, half), p(half, half), folder)
	Decor.Fence(p(half, -half), p(half, half), folder)
	Decor.Fence(p(-half, -half), p(-half, half), folder)
	Decor.Fence(p(-half, -half), p(-15, -half), folder)
	Decor.Fence(p(15, -half), p(half, -half), folder)
	for _, corner in { Vector2.new(-half, -half), Vector2.new(half, -half), Vector2.new(-half, half), Vector2.new(half, half) } do
		Builder.Part({ Name = "CornerPillar", Size = Vector3.new(2.4, 5, 2.4), CFrame = at(plot, corner.X, 3.5, corner.Y), Material = Enum.Material.Brick, Color = Color3.fromRGB(170, 160, 150), Parent = folder })
		local cap = Builder.Part({
			Name = "CornerGlow",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2,
			CFrame = at(plot, corner.X, 7, corner.Y),
			Material = Enum.Material.Neon,
			Color = plot.Accent,
			Parent = folder,
		})
		Decor.Animate(cap, nil, 0.25)
	end
end

local LAMP_SPOTS = { Vector2.new(-52, -40), Vector2.new(52, -40), Vector2.new(-52, 16), Vector2.new(52, 22), Vector2.new(-52, 52), Vector2.new(52, 52) }

local function buildLamps(plot, folder: Instance)
	for _, spot in LAMP_SPOTS do
		Decor.Lamp(at(plot, spot.X, 1, spot.Y).Position, folder, Color3.fromRGB(230, 180, 255))
	end
end

local function buildTower(plot, folder: Instance)
	local function cylinder(name: string, height: number, width: number, y: number, material: Enum.Material, color: Color3)
		return Builder.Part({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, width, width),
			CFrame = at(plot, -44, y, 44) * CFrame.Angles(0, 0, math.rad(90)),
			Material = material,
			Color = color,
			Parent = folder,
		})
	end
	Builder.Part({ Name = "TowerBase", Size = Vector3.new(10, 2, 10), CFrame = at(plot, -44, 2, 44), Material = Enum.Material.Brick, Color = Color3.fromRGB(170, 160, 150), Parent = folder })
	cylinder("Tower", 30, 5, 18, Enum.Material.SmoothPlastic, WHITE)
	for _, y in { 10, 18, 26 } do
		cylinder("TowerWindow", 2, 5.3, y, Enum.Material.Glass, Color3.fromRGB(120, 190, 255))
	end
	cylinder("TowerDeck", 1, 9, 33.5, Enum.Material.Metal, METAL)
	local top = Builder.Part({
		Name = "TowerTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 6,
		CFrame = at(plot, -44, 39, 44),
		Material = Enum.Material.Neon,
		Color = plot.Accent,
		CanCollide = false,
		Parent = folder,
	})
	Decor.Animate(top, nil, 0.8)
	local ring = Builder.Part({
		Name = "TowerRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 10, 10),
		CFrame = at(plot, -44, 39, 44) * CFrame.Angles(math.rad(25), 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 220, 100),
		Transparency = 0.4,
		CanCollide = false,
		Parent = folder,
	})
	Decor.Animate(ring, 50)
	Builder.Sparkles(top, Color3.fromRGB(255, 200, 255), 25)
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 2
	light.Color = plot.Accent
	light.Parent = top
end

local function buildThrone(plot, folder: Instance)
	local gold = Color3.fromRGB(255, 200, 60)
	local velvet = Color3.fromRGB(170, 30, 60)
	Builder.Part({ Name = "ThroneBase", Size = Vector3.new(14, 2, 10), CFrame = at(plot, 0, 2.6, 44), Material = Enum.Material.Marble, Color = WHITE, Parent = folder })
	Builder.Part({ Name = "Carpet", Size = Vector3.new(6, 0.2, 5), CFrame = at(plot, 0, 1.7, 36.5), Material = Enum.Material.Fabric, Color = velvet, Parent = folder })
	local back = Builder.Part({ Name = "ThroneBack", Size = Vector3.new(10, 12, 2), CFrame = at(plot, 0, 9.6, 48), Material = Enum.Material.Metal, Color = gold, Parent = folder })
	Builder.Part({ Name = "ThroneCushion", Size = Vector3.new(7, 9, 0.6), CFrame = at(plot, 0, 9, 46.8), Material = Enum.Material.Fabric, Color = velvet, Parent = folder })
	for _, side in { -1, 1 } do
		Builder.Part({ Name = "ThroneArm", Size = Vector3.new(1.5, 3, 6), CFrame = at(plot, side * 4, 5.1, 45), Material = Enum.Material.Metal, Color = gold, Parent = folder })
		local jewel = Builder.Part({
			Name = "ThroneJewel",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.6,
			CFrame = at(plot, side * 4.5, 16.4, 48),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 80, 120),
			Parent = folder,
		})
		Decor.Animate(jewel, nil, 0.2, 0.2)
	end
	local seat = Instance.new("Seat")
	seat.Name = "ThroneSeat"
	seat.Anchored = true
	seat.Size = Vector3.new(6, 1, 5)
	seat.CFrame = at(plot, 0, 4.1, 45)
	seat.Color = velvet
	seat.Material = Enum.Material.Fabric
	seat.Parent = folder
	Builder.Sparkles(back, gold, 15)
	Builder.Billboard(back, "👑 AURA KING 👑", UDim2.new(12, 0, 2, 0), Vector3.new(0, 8, 0), gold)
end

local function buildItem(plot, item, session, animate: boolean?)
	local folder = Instance.new("Model")
	folder.Name = "Item_" .. item.Id
	if animate then
		-- De client laat het item dan in beeld "vallen" met een plopje
		folder:SetAttribute("BuiltAt", workspace:GetServerTimeNow())
	end
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
		local color = if data.Aura >= item.Price then AFFORD_COLOR else TOO_EXPENSIVE_COLOR
		button.Top.Color = color
		button.Ring.Color = color
	end
end

local function refreshButtons(plot)
	local data = plot.Owner and DataService.Get(plot.Owner)
	for itemId, button in plot.Buttons do
		if not data or data.Purchased[itemId] then
			button.Model:Destroy()
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
			local model = Instance.new("Model")
			model.Name = "Button_" .. item.Id
			model:SetAttribute("BuiltAt", workspace:GetServerTimeNow())
			local flat = at(plot, slot.X, 0, slot.Y) * CFrame.Angles(0, 0, math.rad(90))
			Builder.Part({
				Name = "ButtonBase",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.6, 6.4, 6.4),
				CFrame = flat + Vector3.new(0, 1.3, 0),
				Material = Enum.Material.Metal,
				Color = DARK_METAL,
				Parent = model,
			})
			local ring = Builder.Part({
				Name = "ButtonRing",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 7.4, 7.4),
				CFrame = flat + Vector3.new(0, 1.15, 0),
				Material = Enum.Material.Neon,
				Color = AFFORD_COLOR,
				Transparency = 0.4,
				CanCollide = false,
				CanTouch = false,
				Parent = model,
			})
			Decor.Animate(ring, nil, nil, 0.35)
			local top = Builder.Part({
				Name = "ButtonTop",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.6, 4.8, 4.8),
				CFrame = flat + Vector3.new(0, 1.8, 0),
				Material = Enum.Material.Neon,
				Color = AFFORD_COLOR,
				Parent = model,
			})
			model.Parent = plot.ButtonFolder
			local priceText = if item.Price == 0 then "FREE" else Format.Number(item.Price) .. " Aura"
			Builder.Billboard(top, item.Name .. "\n" .. priceText, UDim2.new(7, 0, 3, 0), Vector3.new(0, 3.2, 0))

			local debounce = false
			top.Touched:Connect(function(hit)
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
			plot.Buttons[item.Id] = { Model = model, Top = top, Ring = ring }
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
		button.Model:Destroy()
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

	plot.Accent = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local accent = plot.Accent

	-- Vloer met een gekleurde rand
	Builder.Part({
		Name = "Floor",
		Size = Vector3.new(Config.PlotSize, 1, Config.PlotSize),
		CFrame = at(plot, 0, 0.5, 0),
		Color = Color3.fromRGB(200, 200, 205),
		Material = Enum.Material.Concrete,
		Parent = model,
	})
	local half = Config.PlotSize / 2
	local function curb(size: Vector3, x: number, z: number)
		Builder.Part({ Name = "Curb", Size = size, CFrame = at(plot, x, 1.1, z), Material = Enum.Material.SmoothPlastic, Color = accent, Parent = model })
	end
	curb(Vector3.new(Config.PlotSize, 0.4, 1.4), 0, half - 0.7)
	curb(Vector3.new(1.4, 0.4, Config.PlotSize), half - 0.7, 0)
	curb(Vector3.new(1.4, 0.4, Config.PlotSize), -(half - 0.7), 0)
	curb(Vector3.new(half - 9, 0.4, 1.4), (half + 9) / 2, -(half - 0.7))
	curb(Vector3.new(half - 9, 0.4, 1.4), -(half + 9) / 2, -(half - 0.7))
	-- Looppad van de ingang naar het midden
	Builder.Part({ Name = "Walkway", Size = Vector3.new(12, 0.2, 40), CFrame = at(plot, 0, 1.05, -35), Material = Enum.Material.Brick, Color = Color3.fromRGB(190, 160, 130), Parent = model })

	local spawnPad = Builder.Part({
		Name = "SpawnPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 8, 8),
		CFrame = at(plot, 0, 1.2, -46) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 200, 255),
		Transparency = 0.3,
		CanCollide = false,
		Parent = model,
	})
	Decor.Animate(spawnPad, nil, nil, 0.25)

	-- Poort met naambord
	for _, side in { -1, 1 } do
		Builder.Part({ Name = "GatePillar", Size = Vector3.new(2.4, 14, 2.4), CFrame = at(plot, side * 13, 8, -53), Material = Enum.Material.SmoothPlastic, Color = WHITE, Parent = model })
		Builder.Part({ Name = "GateCap", Size = Vector3.new(3, 1, 3), CFrame = at(plot, side * 13, 15.5, -53), Material = Enum.Material.SmoothPlastic, Color = accent, Parent = model })
		local gem = Builder.Part({
			Name = "GateGem",
			Size = Vector3.one * 1.6,
			CFrame = at(plot, side * 13, 17.4, -53) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Material = Enum.Material.Neon,
			Color = accent,
			CanCollide = false,
			Parent = model,
		})
		Decor.Animate(gem, 80, 0.3)
	end
	local sign = Builder.Part({
		Name = "Sign",
		Size = Vector3.new(24, 5, 1),
		CFrame = at(plot, 0, 12, -53),
		Material = Enum.Material.SmoothPlastic,
		Color = accent:Lerp(Color3.new(0, 0, 0), 0.45),
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
	signLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	signLabel.Parent = surface
	local signStroke = Instance.new("UIStroke")
	signStroke.Thickness = 3
	signStroke.Parent = signLabel
	plot.SignLabel = signLabel

	-- Aura HQ: een gebouwtje achterin met ramen en een dak (hier komt later de troon)
	Builder.Part({ Name = "HQFloor", Size = Vector3.new(36, 0.6, 20), CFrame = at(plot, 0, 1.3, 44), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(175, 130, 90), Parent = model })
	Builder.Part({ Name = "HQBack", Size = Vector3.new(36, 17, 1), CFrame = at(plot, 0, 10, 53.5), Material = Enum.Material.SmoothPlastic, Color = WHITE, Parent = model })
	for _, side in { -1, 1 } do
		Builder.Part({ Name = "HQSide", Size = Vector3.new(1, 17, 14), CFrame = at(plot, side * 17.5, 10, 46.5), Material = Enum.Material.SmoothPlastic, Color = WHITE, Parent = model })
		Builder.Part({ Name = "HQWindow", Size = Vector3.new(1.2, 6, 8), CFrame = at(plot, side * 17.5, 10, 46.5), Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 210, 255), Transparency = 0.3, Parent = model })
		Builder.Part({ Name = "HQPillar", Size = Vector3.new(2, 17, 2), CFrame = at(plot, side * 17, 10, 35), Material = Enum.Material.SmoothPlastic, Color = WHITE, Parent = model })
		Builder.Part({ Name = "HQPlant", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = at(plot, side * 13, 4, 36.5), Material = Enum.Material.Grass, Color = Color3.fromRGB(70, 150, 70), CanCollide = false, Parent = model })
		Builder.Part({ Name = "HQPot", Size = Vector3.new(2.4, 2, 2.4), CFrame = at(plot, side * 13, 2.6, 36.5), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(190, 110, 70), Parent = model })
	end
	Builder.Part({ Name = "HQRoof", Size = Vector3.new(40, 1.4, 23), CFrame = at(plot, 0, 19.2, 44), Material = Enum.Material.SmoothPlastic, Color = accent, Parent = model })
	Builder.Part({ Name = "HQRoofTrim", Size = Vector3.new(40.4, 0.6, 23.4), CFrame = at(plot, 0, 18.2, 44), Material = Enum.Material.SmoothPlastic, Color = WHITE, Parent = model })
	local hqSign = Builder.Part({ Name = "HQSign", Size = Vector3.new(16, 3, 0.6), CFrame = at(plot, 0, 21.4, 33), Material = Enum.Material.SmoothPlastic, Color = WHITE, Parent = model })
	local hqGui = Instance.new("SurfaceGui")
	hqGui.Face = Enum.NormalId.Front
	hqGui.LightInfluence = 0
	hqGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	hqGui.PixelsPerStud = 40
	hqGui.Parent = hqSign
	local hqLabel = Instance.new("TextLabel")
	hqLabel.Size = UDim2.fromScale(1, 1)
	hqLabel.BackgroundTransparency = 1
	hqLabel.Font = Enum.Font.FredokaOne
	hqLabel.TextScaled = true
	hqLabel.Text = "✨ AURA HQ ✨"
	hqLabel.TextColor3 = accent:Lerp(Color3.new(0, 0, 0), 0.3)
	hqLabel.Parent = hqGui

	-- Groen: bomen, struiken, bloembakken, een bankje en een fontein
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	local function p(x: number, z: number): Vector3
		return at(plot, x, 1, z).Position
	end
	Decor.Tree(p(-46, -47), 1, decor)
	Decor.Tree(p(46, -47), 1, decor)
	Decor.Bush(p(-49, -22), 1, decor)
	Decor.Bush(p(49, -22), 1, decor)
	Decor.Bush(p(49, 36), 1, decor)
	Decor.Planter(at(plot, -26, 1, -50), 12, decor)
	Decor.Planter(at(plot, 26, 1, -50), 12, decor)
	Decor.Planter(at(plot, -29, 1, 52.5), 10, decor)
	Decor.Bench(at(plot, -29, 1, 48.5), decor)
	Decor.Fountain(p(36, 44), 5, decor)
	Decor.Flowers(p(-49, 36), decor, 6)
	Decor.Flowers(p(24, 50), decor, 5)

	-- Ophalen: een grote gouden knop
	Builder.Part({
		Name = "CollectBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 11, 11),
		CFrame = at(plot, 44, 1.3, 9) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = DARK_METAL,
		Parent = model,
	})
	local collectPad = Builder.Part({
		Name = "CollectPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 9, 9),
		CFrame = at(plot, 44, 1.8, 9) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 210, 60),
		Parent = model,
	})
	local collectRing = Builder.Part({
		Name = "CollectRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 12.4, 12.4),
		CFrame = at(plot, 44, 1.15, 9) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 230, 120),
		Transparency = 0.4,
		CanCollide = false,
		CanTouch = false,
		Parent = model,
	})
	Decor.Animate(collectRing, nil, nil, 0.35)
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
			plot.Model:SetAttribute("OwnerId", player.UserId)
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
	plot.Model:SetAttribute("OwnerId", nil)
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
		Bus.Fire("Collected", player, amount)
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
	buildItem(plot, item, plot.Session, true)
	refreshButtons(plot)
	DataService.Changed(player)
	Bus.Fire("Bought", player, item)
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
