-- Server events (zoals biomes in Sol's RNG): elke paar minuten iets speciaals voor iedereen.
-- De client leest workspace attributen "EventId", "EventEnds" en "NextEventAt" voor de banner.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = ReplicatedStorage.Remotes

local EventService = {}

local LOOKS = {
	AuraStorm = { ClockTime = 20, Tint = Color3.fromRGB(210, 170, 255), Atmosphere = Color3.fromRGB(150, 80, 255), Density = 0.45 },
	GoldenHour = { ClockTime = 17.2, Tint = Color3.fromRGB(255, 225, 170), Atmosphere = Color3.fromRGB(255, 200, 120), Density = 0.3 },
	VoidNight = { ClockTime = 0.5, Tint = Color3.fromRGB(170, 140, 220), Atmosphere = Color3.fromRGB(40, 10, 70), Density = 0.5 },
	SpeedRush = { ClockTime = 14, Tint = Color3.fromRGB(190, 240, 255), Atmosphere = Color3.fromRGB(150, 220, 255), Density = 0.25 },
}

local normalLook = nil

local function applyLook(look)
	local info = TweenInfo.new(3)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	TweenService:Create(Lighting, info, { ClockTime = look.ClockTime }):Play()
	if atmosphere then
		TweenService:Create(atmosphere, info, { Color = look.Atmosphere, Density = look.Density }):Play()
	end
	if color then
		TweenService:Create(color, info, { TintColor = look.Tint }):Play()
	end
end

local function saveNormalLook()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	normalLook = {
		ClockTime = Lighting.ClockTime,
		Tint = if color then color.TintColor else Color3.new(1, 1, 1),
		Atmosphere = if atmosphere then atmosphere.Color else Color3.new(1, 1, 1),
		Density = if atmosphere then atmosphere.Density else 0.3,
	}
end

local function announce(text: string)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, text, "rare")
	end
end

function EventService.Start(eventId: string)
	local event = Config.Events[eventId]
	if not event then
		return
	end
	workspace:SetAttribute("EventId", eventId)
	workspace:SetAttribute("EventEnds", workspace:GetServerTimeNow() + Config.EventDuration)
	applyLook(LOOKS[eventId])
	announce(event.Name .. "! " .. event.Description)
end

function EventService.Stop()
	workspace:SetAttribute("EventId", nil)
	workspace:SetAttribute("EventEnds", nil)
	if normalLook then
		applyLook(normalLook)
	end
end

function EventService.Init()
	saveNormalLook()
	local ids = {}
	for id in Config.Events do
		table.insert(ids, id)
	end
	table.sort(ids)

	task.spawn(function()
		local rng = Random.new()
		local last = nil
		while true do
			workspace:SetAttribute("NextEventAt", workspace:GetServerTimeNow() + Config.EventEvery)
			task.wait(Config.EventEvery)
			local pick
			repeat
				pick = ids[rng:NextInteger(1, #ids)]
			until pick ~= last or #ids == 1
			last = pick
			EventService.Start(pick)
			task.wait(Config.EventDuration)
			EventService.Stop()
		end
	end)
end

return EventService
