local BadgeService = game:GetService("BadgeService")

local BadgeIntegration = {}

-- mapping: { achievementId = badgeId }
function BadgeIntegration.Bind(store, mapping)
    assert(store and mapping, "BadgeIntegration.Bind requires store and mapping")
    store.AchievementUnlocked:Connect(function(player, handle, achievementId)
        local badgeId = mapping[achievementId]
        if badgeId then
            pcall(function()
                BadgeService:AwardBadgeAsync(player.UserId, badgeId)
            end)
        end
    end)
end

return BadgeIntegration
