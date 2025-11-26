--!strict

local MemoryAdapter = require(script.Parent.adapters.MemoryAdapter)

local TestHarness = {}

-- Run a fake session with an in-memory adapter. Callers should construct a store
-- using the `dataAdapter = MemoryAdapter.new()` option in config.
function TestHarness.RunFakeAdapter()
    local adapter = MemoryAdapter.new()
    return adapter
end

function TestHarness.RunFakeSession(storeFactory, userId)
    local adapter = MemoryAdapter.new()
    local store = storeFactory(adapter)

    local fakePlayer = { UserId = userId or 1, Name = "FakePlayer" .. tostring(userId or 1) }

    local ok, doc, err = store:_ensureDocument(fakePlayer)
    if ok then
        local firstSlot = (store._cfg and store._cfg.allowedSlotIds and store._cfg.allowedSlotIds[1]) or "1"
        local ok2, handle, err2 = store:LoadSlotAsync(fakePlayer, firstSlot, { createIfMissing = true })
        if ok2 and handle then
            handle.Data._fakeRun = (handle.Data._fakeRun or 0) + 1
            handle:SaveAsync()
            handle:Release()
        end
    end

    function fakePlayer:Remove()
        store:SavePlayerAsync(fakePlayer)
        store:_releaseSession(fakePlayer)
    end

    return store, fakePlayer, ok, doc, err
end

return TestHarness
