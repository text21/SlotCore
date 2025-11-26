local MarketplaceService = game:GetService("MarketplaceService")

local DevProductIntegration = {}

-- mapping: { [productId] = function(userId, receiptInfo, store) end }
function DevProductIntegration.Bind(store, mapping)
    assert(store and mapping, "DevProductIntegration.Bind requires store and mapping")

    MarketplaceService.ProcessReceipt = function(receiptInfo)
        local playerId = receiptInfo.PlayerId or receiptInfo.PlayerId
        local productId = receiptInfo.ProductId or receiptInfo.ProductId
        local handler = mapping[productId]
        if handler then
            local ok, err = pcall(function()
                handler(receiptInfo.PlayerId, receiptInfo, store)
            end)
            if ok then
                return Enum.ProductPurchaseDecision.PurchaseGranted
            else
                warn("DevProduct handler error:", err)
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end
        end
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
end

return DevProductIntegration
