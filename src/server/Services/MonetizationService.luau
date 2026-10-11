-- Gamepasses en developer products (Robux aankopen).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local AuraService = require(script.Parent.AuraService)
local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)

local Remotes = ReplicatedStorage.Remotes

local MonetizationService = {}

local MAX_RECEIPTS = 50

local function passKeyForId(passId: number): string?
	for key, pass in Config.GamePasses do
		if pass.Id ~= 0 and pass.Id == passId then
			return key
		end
	end
	return nil
end

local function productForId(productId: number)
	for _, product in Config.DevProducts do
		if product.Id ~= 0 and product.Id == productId then
			return product
		end
	end
	return nil
end

-- Landen zoals Nederland en België hebben regels voor loot boxes. Omdat je met Aura kunt rollen,
-- verbergen we daar de Aura packs (Robux -> Aura). Als de check mislukt, gaan we uit van "wel regels".
function MonetizationService.LoadPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local restricted = true
	if ok and info then
		restricted = info.ArePaidRandomItemsRestricted == true
	end
	player:SetAttribute("PaidRandomRestricted", restricted)
end

function MonetizationService.LoadPasses(player: Player)
	for key, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				player:SetAttribute("Pass_" .. key, true)
			end
		end
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.Get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if table.find(data.ProcessedReceipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local product = productForId(receipt.ProductId)
	if not product then
		warn("[Monetization] Onbekend product:", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local message
	if product.Kind == "Starter" then
		data.StarterPackBought = true
		BoostService.Add(player, "Double", product.BoostMinutes)
		AuraService.GiveExclusive(player, "Starter Spark")
		message = "Starter Pack unlocked! " .. product.BoostMinutes .. " min 2x Aura + Starter Spark aura"
	elseif product.Kind == "Boost" then
		BoostService.Add(player, "Double", product.BoostMinutes)
		message = "2x Aura for " .. product.BoostMinutes .. " more minutes!"
	else
		local amount = math.max(product.Minimum, math.floor(Economy.BaseIncomePerSecond(player) * product.Minutes * 60))
		DataService.AddAura(player, amount)
		message = "Thanks! +" .. Format.Number(amount) .. " Aura"
	end

	table.insert(data.ProcessedReceipts, receipt.PurchaseId)
	while #data.ProcessedReceipts > MAX_RECEIPTS do
		table.remove(data.ProcessedReceipts, 1)
	end
	DataService.Save(player)

	Remotes.Notify:FireClient(player, message, "rare")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = passKeyForId(passId)
		if key then
			player:SetAttribute("Pass_" .. key, true)
			Remotes.Notify:FireClient(player, "You got " .. Config.GamePasses[key].Name .. "!", "rare")
			if key == "VIP" then
				AuraService.ApplyVisual(player) -- [VIP] tag boven je hoofd
			end
			DataService.Changed(player)
		end
	end)
end

return MonetizationService
