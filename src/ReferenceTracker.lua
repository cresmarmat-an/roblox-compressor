local ReferenceTracker = {}
ReferenceTracker.__index = ReferenceTracker

ReferenceTracker.REF_TAG = 0x7F

function ReferenceTracker.new()
	local self = setmetatable({

		refs = {},

		nextId = 1,

		deserialized = {},
	}, ReferenceTracker)
	return self
end

function ReferenceTracker:TrackTable(t)
	if self.refs[t] ~= nil then

		return true, self.refs[t], false
	else

		local id = self.nextId
		self.nextId = self.nextId + 1
		self.refs[t] = id
		return true, id, true
	end
end

function ReferenceTracker:IsReference(t)
	return self.refs[t] ~= nil
end

function ReferenceTracker:AssignId(t)
	if self.refs[t] == nil then
		local id = self.nextId
		self.nextId = self.nextId + 1
		self.refs[t] = id
		return id
	end
	return self.refs[t]
end

function ReferenceTracker:RegisterTable(id, t)
	self.deserialized[id] = t
end

function ReferenceTracker:GetTable(id)
	return self.deserialized[id]
end

function ReferenceTracker:Reset()
	self.refs = {}
	self.deserialized = {}
	self.nextId = 1
end

return ReferenceTracker
