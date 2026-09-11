local Writer = require(script.Parent.Parent.Writer)
local Reader = require(script.Parent.Parent.Reader)

local TAG_NIL    = 0x00
local TAG_TRUE   = 0x01
local TAG_FALSE  = 0x02
local TAG_NUMBER = 0x03
local TAG_STRING = 0x04
local TAG_ARRAY  = 0x05
local TAG_DICT   = 0x06
local TAG_REF    = 0x7F

local Primitives = {}

function Primitives:IsArray(t)
	local len = #t
	if len == 0 then

		return next(t) == nil, len
	end

	if t[len] == nil then
		return false, 0
	end

	if next(t, len) ~= nil then
		return false, 0
	end
	return true, len
end

Primitives.Nil = {
	Tag = TAG_NIL,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteByte(TAG_NIL)
	end,
	Deserialize = function(reader, context, schemaNode)
		return nil
	end,
}

Primitives.Boolean = {
	Tag = TAG_TRUE,
	Serialize = function(value, writer, context, schemaNode)
		if value then
			writer:WriteByte(TAG_TRUE)
		else
			writer:WriteByte(TAG_FALSE)
		end
	end,
	Deserialize = function(reader, context, schemaNode)

		error("Boolean.Deserialize should not be called directly; use BooleanDeserialize")
	end,
	DeserializeTrue = function(reader, context, schemaNode)
		return true
	end,
	DeserializeFalse = function(reader, context, schemaNode)
		return false
	end,
}

Primitives.Number = {
	Tag = TAG_NUMBER,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteByte(TAG_NUMBER)
		writer:WriteF64(value)
	end,
	Deserialize = function(reader, context, schemaNode)
		return reader:ReadF64()
	end,
}

Primitives.String = {
	Tag = TAG_STRING,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteByte(TAG_STRING)
		writer:WriteString(value)
	end,
	Deserialize = function(reader, context, schemaNode)
		return reader:ReadString()
	end,
}

Primitives.Table = {
	Tag = TAG_ARRAY,
	Serialize = function(value, writer, context, schemaNode)
		local isArray, len = Primitives:IsArray(value)

		if context.refTracker then
			local isTracked, id, isFirst = context.refTracker:TrackTable(value)
			if isTracked and not isFirst then

				writer:WriteByte(TAG_REF)
				writer:WriteU32(id)
				return
			end
		end

		if isArray then
			writer:WriteByte(TAG_ARRAY)
			writer:WriteU32(len)
			for i = 1, len do
				context:Serialize(value[i], nil)
			end
		else

			local pairCount = 0
			for _ in pairs(value) do
				pairCount = pairCount + 1
			end
			writer:WriteByte(TAG_DICT)
			writer:WriteU32(pairCount)
			for k, v in pairs(value) do
				context:Serialize(k, nil)
				context:Serialize(v, nil)
			end
		end
	end,
	Deserialize = function(reader, context, schemaNode)

		error("Table.Deserialize should not be called directly; use DeserializeArray or DeserializeDict")
	end,
}

function Primitives.DeserializeArray(reader, context, schemaNode)
	local len = reader:ReadU32()

	local maxSize = context.options and context.options.maxTableSize or 1000000
	if len > maxSize then
		error(("Compressor: Array length %d exceeds limit %d"):format(len, maxSize))
	end
	local t = table.create(len)

	if context.refTracker then

		local id = context.refTracker.nextId
		context.refTracker.nextId = id + 1
		context.refTracker.deserialized[id] = t
	end

	for i = 1, len do
		t[i] = context:Deserialize(nil)
	end

	return t
end

function Primitives.DeserializeDict(reader, context, schemaNode)
	local pairCount = reader:ReadU32()
	local maxSize = context.options and context.options.maxTableSize or 1000000
	if pairCount > maxSize then
		error(("Compressor: Dict pair count %d exceeds limit %d"):format(pairCount, maxSize))
	end
	local t = {}

	if context.refTracker then
		local id = context.refTracker.nextId
		context.refTracker.nextId = id + 1
		context.refTracker.deserialized[id] = t
	end

	for _ = 1, pairCount do
		local key = context:Deserialize(nil)
		local val = context:Deserialize(nil)
		t[key] = val
	end

	return t
end

function Primitives.DeserializeRef(reader, context, schemaNode)
	local id = reader:ReadU32()
	return context.refTracker:GetTable(id)
end

return Primitives
