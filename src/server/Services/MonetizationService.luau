-- Gamepasses en developer products (Robux aankopen).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
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

	local amount = math.max(product.Minimum, math.floor(Economy.IncomePerSecond(player) * product.Minutes * 60))
	DataService.AddAura(player, amount)

	table.insert(data.ProcessedReceipts, receipt.PurchaseId)
	while #data.ProcessedReceipts > MAX_RECEIPTS do
		table.remove(data.ProcessedReceipts, 1)
	end
	DataService.Save(player)

	Remotes.Notify:FireClient(player, "Thanks! +" .. Format.Number(amount) .. " Aura", "rare")
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
			DataService.Changed(player)
		end
	end)
end

return MonetizationService
