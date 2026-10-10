-- Maakt grote getallen kort: 1500 -> 1.5K, 2500000 -> 2.5M

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.Number(value: number): string
	if value ~= value then
		return "0"
	end
	local negative = value < 0
	local n = math.abs(value)
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local text
	if index == 1 then
		text = tostring(math.floor(n))
	elseif n >= 100 then
		text = string.format("%d", math.floor(n)) .. SUFFIXES[index]
	else
		text = string.gsub(string.format("%.2f", math.floor(n * 100) / 100), "%.?0+$", "") .. SUFFIXES[index]
	end
	return if negative then "-" .. text else text
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%d:%02d", m, s)
end

return Format
