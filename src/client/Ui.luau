-- Helpers om de schermen (UI) te bouwen.

local Ui = {}

Ui.Colors = {
	Panel = Color3.fromRGB(32, 22, 54),
	PanelLight = Color3.fromRGB(52, 38, 84),
	Accent = Color3.fromRGB(160, 95, 255),
	Gold = Color3.fromRGB(255, 205, 70),
	Green = Color3.fromRGB(70, 210, 110),
	Red = Color3.fromRGB(235, 75, 85),
	Text = Color3.fromRGB(245, 240, 255),
	SubText = Color3.fromRGB(190, 175, 220),
}

function Ui.Create(className: string, props, children)
	local instance = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for key, value in props do
		(instance :: any)[key] = value
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	instance.Parent = parent
	return instance
end

function Ui.Corner(radius: number?)
	return Ui.Create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Ui.Stroke(color: Color3?, thickness: number?)
	return Ui.Create("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.Label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Ui.Colors.Text,
		TextScaled = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	local label = Ui.Create("TextLabel", defaults)
	Ui.Create("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0), Parent = label })
	return label
end

function Ui.Button(props, onClick)
	local defaults = {
		AutoButtonColor = true,
		BackgroundColor3 = Ui.Colors.Accent,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Ui.Colors.Text,
		TextScaled = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = Ui.Create("TextButton", defaults, { Ui.Corner(10), Ui.Stroke(Color3.new(0, 0, 0), 2) })
	Ui.Create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = button,
	})
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

return Ui
