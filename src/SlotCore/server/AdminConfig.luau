--!strict

local AdminConfig = {}

AdminConfig.Enabled = true

-- When true, running in Studio will use a separate datastore name/scope (suffixed with `_dev`) so developers
-- don't interfere with production data. Toggle this in your game's copy of AdminConfig.
AdminConfig.UseDevDataInStudio = true

AdminConfig.RolePermissions = {
    slotcore_mod = {
        "slotcore.view",
        "slotcore.switch",
    },

    slotcore_admin = {
        "slotcore.view",
        "slotcore.switch",
        "slotcore.wipe",
        "slotcore.inspect",
        "slotcore.modify",
    },
}

AdminConfig.UserRoles = {
    [797399348] = { "slotcore_admin" },
}

AdminConfig.Commands = {
    slots = true,
    load = true,
    wipe = true,
    account = true,
    doc = true,
    add = true,
    set = true,
}

return AdminConfig
