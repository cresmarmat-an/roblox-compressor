local Writer = require(script.Parent.Writer)
local ReferenceTracker = require(script.Parent.ReferenceTracker)
local Primitives = require(script.Parent.Handlers.Primitives)

local VERSION = 1

local Serializer = {}

local TAG_NIL    = 0x00
local TAG_TRUE   = 0x01
local TAG_FALSE  = 0x02
local TAG_NUMBER = 0x03
local TAG_STRING = 0x04
local TAG_ARRAY  = 0x05
local TAG_DICT   = 0x06
local TAG_REF    = 0x7F

local TAG_INSTANCE_PATH = 0x26

function Serializer.Serialize(value, schema, options)
	options = options or {}
	local registry = options.registry

	local writer = Writer.new(256)
	writer:WriteByte(VERSION)

	local refTracker = ReferenceTracker.new()

	local context = {
		writer = writer,
		registry = registry,
		refTracker = refTracker,
		options = options,
		schema = schema,
		depth = 0,
		maxDepth = options and options.maxDepth or 100,
	}

	function context:Serialize(val, schemaNode)
		self.depth = self.depth + 1
		if self.depth > self.maxDepth then
			self.depth = self.depth - 1
			error("Compressor: Maximum recursion depth (" .. self.maxDepth .. ") exceeded")
		end

		if schemaNode and schemaNode._type and schemaNode._handler then
			local handler = schemaNode._handler
			if schemaNode._schemaMode then

				local kind = schemaNode._kind
				local trackable = type(val) == "table"
					and (kind == "object" or kind == "array" or kind == "map")
				if trackable and context.refTracker then
					local isTracked, id, isFirst = context.refTracker:TrackTable(val)
					if isTracked and not isFirst then
						self.depth = self.depth - 1
						error(("Compressor: Cyclic reference (id %d) in schema-typed value cannot be framed"):format(id))
					end
				end
				handler.Serialize(val, writer, context, schemaNode)
			else
				if handler.Tag then
					writer:WriteByte(handler.Tag)
				end
				handler.Serialize(val, writer, context, schemaNode)
			end
		elseif val == nil then
			writer:WriteByte(TAG_NIL)
		else

			local luaType = type(val)

			if luaType == "nil" then
				writer:WriteByte(TAG_NIL)
			elseif luaType == "boolean" then
				if val then
					writer:WriteByte(TAG_TRUE)
				else
					writer:WriteByte(TAG_FALSE)
				end
			elseif luaType == "number" then
				writer:WriteByte(TAG_NUMBER)
				writer:WriteF64(val)
			elseif luaType == "string" then
				writer:WriteByte(TAG_STRING)
				writer:WriteString(val)
			elseif luaType == "table" then
				local typeStr = typeof(val)
				if typeStr == "Instance" then
					local instanceMode = options.instanceMode or "error"
					if instanceMode == "error" then
						error("Compressor: Instances cannot be serialized. Set instanceMode to 'path' or register a custom Instance handler.")
					elseif instanceMode == "path" then
						writer:WriteByte(TAG_INSTANCE_PATH)
						writer:WriteString(val:GetFullName())
					else
						error(("Compressor: Unknown instanceMode '%s'"):format(tostring(instanceMode)))
					end
				elseif typeStr == "table" then
					Primitives.Table.Serialize(val, writer, context, nil)
				else

					local handler = registry and registry:ByTypeof(typeStr)
					if handler then
						if handler.Tag then
							writer:WriteByte(handler.Tag)
						end
						handler.Serialize(val, writer, context, nil)
					else
						error(("Compressor: Unsupported type '%s' cannot be serialized"):format(typeStr))
					end
				end
			else
				local typeStr = typeof(val)
				if typeStr == "Instance" then
					local instanceMode = options.instanceMode or "error"
					if instanceMode == "error" then
						error("Compressor: Instances cannot be serialized. Set instanceMode to 'path' or register a custom Instance handler.")
					elseif instanceMode == "path" then
						writer:WriteByte(TAG_INSTANCE_PATH)
						writer:WriteString(val:GetFullName())
					else
						error(("Compressor: Unknown instanceMode '%s'"):format(tostring(instanceMode)))
					end
				else

					local handler = registry and registry:ByTypeof(typeStr)
					if handler then
						if handler.Tag then
							writer:WriteByte(handler.Tag)
						end
						handler.Serialize(val, writer, context, nil)
					else
						error(("Compressor: Unsupported type '%s' cannot be serialized"):format(typeStr))
					end
				end
			end
		end
		self.depth = self.depth - 1
	end

	context:Serialize(value, schema)

	return writer:GetBuffer()
end

return Serializer
