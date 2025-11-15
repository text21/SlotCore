--!strict

local AdminConfig = {}

AdminConfig.Enabled = true

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
    -- [123456789] = { "slotcore_admin" },
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
