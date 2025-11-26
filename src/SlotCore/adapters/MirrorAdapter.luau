--!strict

local DataStoreService = game:GetService("DataStoreService")

local MirrorAdapter = {}
MirrorAdapter.__index = MirrorAdapter

function MirrorAdapter.new(primaryAdapter: any, mirrorStoreName: string?, scope: string?)
	assert(primaryAdapter, "MirrorAdapter requires a primary adapter")

	local self = setmetatable({}, MirrorAdapter)
	self._primary = primaryAdapter
	self._mirrorName = mirrorStoreName or ("SlotCore_Mirror_" .. tostring(math.random(1000, 9999)))
	self._mirror = DataStoreService:GetDataStore(self._mirrorName, scope)

	return self
end

function MirrorAdapter:AcquireSessionAsync(userId: number, token: string)
	return self._primary:AcquireSessionAsync(userId, token)
end

function MirrorAdapter:PeekDocumentAsync(userId: number)
	return self._primary:PeekDocumentAsync(userId)
end

function MirrorAdapter:ReleaseSessionAsync(userId: number, token: string)
	return self._primary:ReleaseSessionAsync(userId, token)
end

function MirrorAdapter:FlushAndLockAsync(userId: number)
	local ok, res, err = self._primary:FlushAndLockAsync(userId)

	if ok then
		task.spawn(function()
			local okDoc, doc = self._primary:PeekDocumentAsync(userId)
			if okDoc and doc then
				pcall(function()
					self._mirror:SetAsync(tostring(userId), doc)
				end)
			end
		end)
	end

	return ok, res, err
end

function MirrorAdapter:SaveDocumentAsync(userId: number, token: string, doc: any)
	local ok, res, err = self._primary:SaveDocumentAsync(userId, token, doc)

	if ok then
		task.spawn(function()
			pcall(function()
				self._mirror:SetAsync(tostring(userId), doc)
			end)
		end)
	end

	return ok, res, err
end

return MirrorAdapter
