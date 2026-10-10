-- Een simpel berichtensysteem tussen services, zodat bijvoorbeeld quests kunnen horen
-- dat iemand Aura heeft opgehaald zonder dat alles elkaar moet kennen.
-- Berichten: "Collected" (player, amount), "Rolled" (player, aura, free), "Bought" (player, item),
-- "Posed" (player, seconds), "PeakAura" (player)

local Bus = {}

local listeners: { [string]: { (...any) -> () } } = {}

function Bus.On(name: string, callback: (...any) -> ())
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], callback)
end

function Bus.Fire(name: string, ...: any)
	local list = listeners[name]
	if not list then
		return
	end
	for _, callback in list do
		task.spawn(callback, ...)
	end
end

return Bus
