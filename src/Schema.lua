local Schema = {}

local SchemaNode = {}
SchemaNode.__index = SchemaNode

function SchemaNode.new(kind, options)
	options = options or {}
	local self = setmetatable({
		_kind = kind,
		_required = options.required or false,
		_default = options.default,
		_validate = options.validate,
		_schemaMode = false,
		_handler = nil,
	}, SchemaNode)
	return self
end

function SchemaNode:setHandler(handler)
	self._handler = handler
	self._schemaMode = handler ~= nil
	return self
end

function SchemaNode:getType()
	return self._type
end

function SchemaNode:setType(typeName)
	self._type = typeName
end

function SchemaNode:clone()
	local new = SchemaNode.new(self._kind, {
		required = self._required,
		default = self._default,
		validate = self._validate,
	})
	new._handler = self._handler
	new._schemaMode = self._schemaMode
	new._type = self._type
	return new
end

--[[ Builds a schema node for a primitive type ("nil", "boolean",
	"number", "string", "any"). `options` accepts required, default
	and validate. ]]
function Schema.Primitive(typeName, options)
	options = options or {}
	local node = SchemaNode.new("primitive", options)
	node:setType(typeName)
	return node
end

Schema.Nil = function(options)
	local node = Schema.Primitive("nil", options)
	return node
end

Schema.Boolean = function(options)
	local node = Schema.Primitive("boolean", options)
	return node
end

Schema.Number = function(options)
	local node = Schema.Primitive("number", options)
	return node
end

Schema.String = function(options)
	local node = Schema.Primitive("string", options)
	return node
end

Schema.Any = function(options)
	local node = Schema.Primitive("any", options)
	return node
end

--[[ Builds a schema node for a Roblox value type ("Vector2",
	"Vector3", "CFrame", ...). Values are validated with typeof(). ]]
function Schema.RobloxType(typeName, options)
	options = options or {}
	local node = SchemaNode.new("roblox", options)
	node:setType(typeName)
	return node
end

Schema.Vector2 = function(options) return Schema.RobloxType("Vector2", options) end
Schema.Vector3 = function(options) return Schema.RobloxType("Vector3", options) end
Schema.CFrame = function(options) return Schema.RobloxType("CFrame", options) end
Schema.Color3 = function(options) return Schema.RobloxType("Color3", options) end
Schema.BrickColor = function(options) return Schema.RobloxType("BrickColor", options) end
Schema.UDim = function(options) return Schema.RobloxType("UDim", options) end
Schema.UDim2 = function(options) return Schema.RobloxType("UDim2", options) end
Schema.Ray = function(options) return Schema.RobloxType("Ray", options) end
Schema.Rect = function(options) return Schema.RobloxType("Rect", options) end
Schema.Region3 = function(options) return Schema.RobloxType("Region3", options) end
Schema.EnumItem = function(options) return Schema.RobloxType("EnumItem", options) end
Schema.NumberSequence = function(options) return Schema.RobloxType("NumberSequence", options) end
Schema.ColorSequence = function(options) return Schema.RobloxType("ColorSequence", options) end
Schema.NumberRange = function(options) return Schema.RobloxType("NumberRange", options) end
Schema.PhysicalProperties = function(options) return Schema.RobloxType("PhysicalProperties", options) end
Schema.TweenInfo = function(options) return Schema.RobloxType("TweenInfo", options) end
Schema.DateTime = function(options) return Schema.RobloxType("DateTime", options) end
Schema.Font = function(options) return Schema.RobloxType("Font", options) end
Schema.Axes = function(options) return Schema.RobloxType("Axes", options) end
Schema.Faces = function(options) return Schema.RobloxType("Faces", options) end

--[[ Builds a schema node for an array whose elements all follow
	itemSchema. ]]
function Schema.Array(itemSchema, options)
	options = options or {}
	local node = SchemaNode.new("array", options)
	node:setType("array")
	node._itemSchema = itemSchema
	return node
end

--[[ Builds a schema node for a dict whose keys follow keySchema
	and whose values follow valueSchema. ]]
function Schema.Map(keySchema, valueSchema, options)
	options = options or {}
	local node = SchemaNode.new("map", options)
	node:setType("map")
	node._keySchema = keySchema
	node._valueSchema = valueSchema
	return node
end

--[[ Builds a schema node for a table with named fields. On the wire
	only values travel (sorted order, presence markers); unknown fields
	are dropped on read. ]]
function Schema.Object(fields, options)
	options = options or {}
	local node = SchemaNode.new("object", options)
	node:setType("object")
	node._fields = fields or {}
	return node
end

--[[ Builds a schema node for EnumItems, optionally restricted to one
	enum (e.g. Schema.Enum("Material")). ]]
function Schema.Enum(enumName, options)
	options = options or {}
	local node = SchemaNode.new("enum", options)
	node:setType("Enum")
	node._enumName = enumName
	return node
end

--[[ Builds a schema node for a user-registered type. Requires a prior
	RegisterType call with the same name; validateFn optionally checks
	values during validation. ]]
function Schema.Custom(typeName, validateFn, options)
	options = options or {}
	local node = SchemaNode.new("custom", options)
	node:setType(typeName)
	node._validateFn = validateFn
	return node
end

local function isContainerKind(node)
	return node ~= nil
		and (node._kind == "object" or node._kind == "array" or node._kind == "map")
end

local typeHandlers = {}

--[[ Maps a type name to its handler for schema compilation. Called
	automatically by RegisterType for custom types. ]]
function Schema.RegisterTypeHandler(typeName, handler)
	typeHandlers[typeName] = handler
end

--[[ Pre-compiles a schema node (and its children) into handler form,
	cached on the node via _compiled. Takes the shared type registry for
	Roblox/custom lookups. Called automatically by Compress/Decompress. ]]
function Schema.Compile(node, registry)
	if not node or node._compiled then
		return node
	end

	local typeName = node._type

	if typeName == "nil" then
		node:setHandler(nil)

		node:setHandler({
			Serialize = function(value, writer, context, schemaNode)

			end,
			Deserialize = function(reader, context, schemaNode)
				return nil
			end,
		})
	elseif typeName == "boolean" then
		node:setHandler({
			Serialize = function(value, writer, context, schemaNode)
				writer:WriteByte(value and 1 or 0)
			end,
			Deserialize = function(reader, context, schemaNode)
				local b = reader:ReadByte()
				return b == 1
			end,
		})
	elseif typeName == "number" then
		node:setHandler({
			Serialize = function(value, writer, context, schemaNode)
				writer:WriteF64(value)
			end,
			Deserialize = function(reader, context, schemaNode)
				return reader:ReadF64()
			end,
		})
	elseif typeName == "string" then
		node:setHandler({
			Serialize = function(value, writer, context, schemaNode)
				writer:WriteString(value)
			end,
			Deserialize = function(reader, context, schemaNode)
				return reader:ReadString()
			end,
		})
	elseif typeName == "any" then

		node:setHandler(nil)
	elseif typeName == "array" then
		local itemSchema = node._itemSchema
		if itemSchema then
			Schema.Compile(itemSchema, registry)
		end
		node:setHandler({
			Serialize = function(value, writer, context, schemaNode)
				local len = #value
				writer:WriteU32(len)
				local itemSchema = schemaNode._itemSchema
				local itemHandler = itemSchema and itemSchema._handler
				local itemSchemaMode = itemSchema and itemSchema._schemaMode
				local frameItems = isContainerKind(itemSchema)
				for i = 1, len do
					local item = value[i]
					if frameItems and type(item) == "table" then
						local _, refId, isFirst = context.refTracker:TrackTable(item)
						if not isFirst then
							writer:WriteByte(0x02)
							writer:WriteU32(refId)
						else
							writer:WriteByte(0x01)
							if itemSchemaMode and itemSchema._type ~= "any" then
								itemHandler.Serialize(item, writer, context, itemSchema)
							else
								context:Serialize(item, nil)
							end
						end
					elseif itemSchemaMode and itemHandler then
						if itemSchema._type == "any" then

							context:Serialize(value[i], nil)
						else
							itemHandler.Serialize(value[i], writer, context, itemSchema)
						end
					else
						context:Serialize(value[i], nil)
					end
				end
			end,
			Deserialize = function(reader, context, schemaNode)
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
				local itemSchema = schemaNode._itemSchema
				local itemSchemaMode = itemSchema and itemSchema._schemaMode
				local frameItems = isContainerKind(itemSchema)
				for i = 1, len do
					if frameItems then
						local marker = reader:ReadByte()
						if marker == 0x02 then
							t[i] = context.refTracker:GetTable(reader:ReadU32())
						elseif marker == 0x01 then
							if itemSchemaMode and itemSchema._type ~= "any" then
								local handler = itemSchema._handler
								t[i] = handler.Deserialize(reader, context, itemSchema)
							else
								t[i] = context:Deserialize(itemSchema)
							end
						else
							error(("Compressor: Invalid array item marker 0x%X at index %d"):format(marker, i))
						end
					elseif itemSchemaMode and itemSchema._type ~= "any" then
						local handler = itemSchema._handler
						t[i] = handler.Deserialize(reader, context, itemSchema)
					else
						t[i] = context:Deserialize(itemSchema)
					end
				end
				return t
			end,
		})
	elseif typeName == "map" then
		local keySchema = node._keySchema
		local valueSchema = node._valueSchema
		if keySchema then Schema.Compile(keySchema, registry) end
		if valueSchema then Schema.Compile(valueSchema, registry) end
		node:setHandler({
			Serialize = function(value, writer, context, schemaNode)
				local count = 0
				for _ in pairs(value) do count = count + 1 end
				writer:WriteU32(count)
				local keySchema = schemaNode._keySchema
				local valueSchema = schemaNode._valueSchema
				local frameKeys = isContainerKind(keySchema)
				local frameValues = isContainerKind(valueSchema)
				for k, v in pairs(value) do

					if frameKeys and type(k) == "table" then
						local _, refId, isFirst = context.refTracker:TrackTable(k)
						if not isFirst then
							writer:WriteByte(0x02)
							writer:WriteU32(refId)
						else
							writer:WriteByte(0x01)
							keySchema._handler.Serialize(k, writer, context, keySchema)
						end
					elseif keySchema and keySchema._schemaMode and keySchema._handler and keySchema._type ~= "any" then
						keySchema._handler.Serialize(k, writer, context, keySchema)
					else
						context:Serialize(k, nil)
					end

					if frameValues and type(v) == "table" then
						local _, refId, isFirst = context.refTracker:TrackTable(v)
						if not isFirst then
							writer:WriteByte(0x02)
							writer:WriteU32(refId)
						else
							writer:WriteByte(0x01)
							valueSchema._handler.Serialize(v, writer, context, valueSchema)
						end
					elseif valueSchema and valueSchema._schemaMode and valueSchema._handler and valueSchema._type ~= "any" then
						valueSchema._handler.Serialize(v, writer, context, valueSchema)
					else
						context:Serialize(v, nil)
					end
				end
			end,
			Deserialize = function(reader, context, schemaNode)
				local count = reader:ReadU32()
				local maxSize = context.options and context.options.maxTableSize or 1000000
				if count > maxSize then
					error(("Compressor: Map pair count %d exceeds limit %d"):format(count, maxSize))
				end
				local t = {}

				if context.refTracker then
					local id = context.refTracker.nextId
					context.refTracker.nextId = id + 1
					context.refTracker.deserialized[id] = t
				end
				local keySchema = schemaNode._keySchema
				local valueSchema = schemaNode._valueSchema
				local frameKeys = isContainerKind(keySchema)
				local frameValues = isContainerKind(valueSchema)
				for _ = 1, count do
					local key, val
					if frameKeys then
						local marker = reader:ReadByte()
						if marker == 0x02 then
							key = context.refTracker:GetTable(reader:ReadU32())
						elseif marker == 0x01 then
							key = keySchema._handler.Deserialize(reader, context, keySchema)
						else
							error(("Compressor: Invalid map key marker 0x%X"):format(marker))
						end
					elseif keySchema and keySchema._schemaMode and keySchema._handler and keySchema._type ~= "any" then
						key = keySchema._handler.Deserialize(reader, context, keySchema)
					else
						key = context:Deserialize(keySchema)
					end
					if frameValues then
						local marker = reader:ReadByte()
						if marker == 0x02 then
							val = context.refTracker:GetTable(reader:ReadU32())
						elseif marker == 0x01 then
							val = valueSchema._handler.Deserialize(reader, context, valueSchema)
						else
							error(("Compressor: Invalid map value marker 0x%X"):format(marker))
						end
					elseif valueSchema and valueSchema._schemaMode and valueSchema._handler and valueSchema._type ~= "any" then
						val = valueSchema._handler.Deserialize(reader, context, valueSchema)
					else
						val = context:Deserialize(valueSchema)
					end
					t[key] = val
				end
				return t
			end,
		})
	elseif typeName == "object" then

		local fields = node._fields
		local compiledFields = {}

		local fieldOrder = {}
		for fieldName, fieldSchema in pairs(fields) do
			Schema.Compile(fieldSchema, registry)
			compiledFields[fieldName] = fieldSchema
			fieldOrder[#fieldOrder + 1] = fieldName
		end
		table.sort(fieldOrder)
		node._compiledFields = compiledFields
		node._fieldOrder = fieldOrder

		node:setHandler({
		Serialize = function(value, writer, context, schemaNode)
			local cf = schemaNode._compiledFields
			local order = schemaNode._fieldOrder
			for i = 1, #order do
				local fieldName = order[i]
				local fieldSchema = cf[fieldName]
				local fieldValue = value[fieldName]

				local useSchemaMode = fieldSchema._schemaMode and fieldSchema._handler
					and fieldSchema._type ~= "any"
				local trackable = fieldValue ~= nil and type(fieldValue) == "table"
					and isContainerKind(fieldSchema)
				if fieldValue == nil then
					if fieldSchema._required then
						error(("Compressor: Required field '%s' is missing"):format(fieldName))
					elseif useSchemaMode then

						writer:WriteByte(0x00)
					else

						context:Serialize(nil, nil)
					end
				elseif trackable then

					local _, refId, isFirst = context.refTracker:TrackTable(fieldValue)
					if isFirst then
						writer:WriteByte(0x01)
						fieldSchema._handler.Serialize(fieldValue, writer, context, fieldSchema)
					else
						writer:WriteByte(0x02)
						writer:WriteU32(refId)
					end
				elseif useSchemaMode then
					writer:WriteByte(0x01)
					fieldSchema._handler.Serialize(fieldValue, writer, context, fieldSchema)
				else

					context:Serialize(fieldValue, nil)
				end
			end
		end,
		Deserialize = function(reader, context, schemaNode)
			local cf = schemaNode._compiledFields
			local order = schemaNode._fieldOrder
			local result = {}

			if context.refTracker then
				local id = context.refTracker.nextId
				context.refTracker.nextId = id + 1
				context.refTracker.deserialized[id] = result
			end

			for i = 1, #order do
				local fieldName = order[i]
				local fieldSchema = cf[fieldName]
				local fieldValue
				local useSchemaMode = fieldSchema._schemaMode and fieldSchema._handler
					and fieldSchema._type ~= "any"
				if useSchemaMode then
					local marker = reader:ReadByte()
					if marker == 0x00 then

						fieldValue = fieldSchema._default
					elseif marker == 0x02 then

						fieldValue = context.refTracker:GetTable(reader:ReadU32())
					elseif marker == 0x01 then

						fieldValue = fieldSchema._handler.Deserialize(reader, context, fieldSchema)
					else
						error(("Compressor: Invalid presence marker 0x%X for field '%s'"):format(marker, fieldName))
					end
				else

					fieldValue = context:Deserialize(nil)
				end
				if fieldValue ~= nil or fieldSchema._default ~= nil then
					result[fieldName] = fieldValue
				end
			end
			return result
		end,
		})
	elseif typeName == "Enum" then
		node:setHandler({
			Serialize = function(value, writer, context, schemaNode)
				writer:WriteString(tostring(value.EnumType))
				writer:WriteString(value.Name)
			end,
			Deserialize = function(reader, context, schemaNode)
				local enumTypeName = reader:ReadString()
				local itemName = reader:ReadString()
				local enumType = Enum[enumTypeName]
				if enumType == nil then
					error(("Compressor: Enum type '%s' not found"):format(enumTypeName))
				end
				local item = enumType[itemName]
				if item == nil then
					error(("Compressor: Enum item '%s.%s' not found"):format(enumTypeName, itemName))
				end
				return item
			end,
		})
	else

		if registry then
			local handler = registry:ByLuaType(typeName) or registry:ByTypeof(typeName)
			if handler then
				node:setHandler(handler)
			end
		end

		if not node._handler and typeHandlers[typeName] then
			node:setHandler(typeHandlers[typeName])
		end
	end

	node._compiled = true
	return node
end

--[[ Checks a value against a schema node. Returns true, or false
	plus a message carrying the field path. ]]
function Schema.Validate(value, schemaNode, path)
	path = path or ""

	if not schemaNode then
		return true
	end

	local typeName = schemaNode._type

	if typeName == "nil" then
		if value ~= nil then
			return false, ("Expected nil at '%s', got %s"):format(path, type(value))
		end
	elseif typeName == "boolean" then
		if type(value) ~= "boolean" then
			return false, ("Expected boolean at '%s', got %s"):format(path, type(value))
		end
	elseif typeName == "number" then
		if type(value) ~= "number" then
			return false, ("Expected number at '%s', got %s"):format(path, type(value))
		end
	elseif typeName == "string" then
		if type(value) ~= "string" then
			return false, ("Expected string at '%s', got %s"):format(path, type(value))
		end
	elseif typeName == "any" then

	elseif typeName == "array" then
		if type(value) ~= "table" then
			return false, ("Expected array at '%s', got %s"):format(path, type(value))
		end
		local itemSchema = schemaNode._itemSchema
		if itemSchema then
			for i, v in ipairs(value) do
				local ok, err = Schema.Validate(v, itemSchema, path .. "[" .. i .. "]")
				if not ok then
					return false, err
				end
			end
		end
	elseif typeName == "map" then
		if type(value) ~= "table" then
			return false, ("Expected map at '%s', got %s"):format(path, type(value))
		end
		local keySchema = schemaNode._keySchema
		local valueSchema = schemaNode._valueSchema
		for k, v in pairs(value) do
			if keySchema then
				local ok, err = Schema.Validate(k, keySchema, path .. ".key")
				if not ok then return false, err end
			end
			if valueSchema then
				local ok, err = Schema.Validate(v, valueSchema, path .. "[" .. tostring(k) .. "]")
				if not ok then return false, err end
			end
		end
	elseif typeName == "object" then
		if type(value) ~= "table" then
			return false, ("Expected object at '%s', got %s"):format(path, type(value))
		end
		local fields = schemaNode._fields
		for fieldName, fieldSchema in pairs(fields) do
			local fieldValue = value[fieldName]
			if fieldValue == nil then
				if fieldSchema._required then
					return false, ("Required field '%s.%s' is missing"):format(path, fieldName)
				end
			else
				local ok, err = Schema.Validate(fieldValue, fieldSchema, path .. "." .. fieldName)
				if not ok then return false, err end
			end
		end
	elseif typeName == "Enum" then
		if typeof(value) ~= "EnumItem" then
			return false, ("Expected EnumItem at '%s', got %s"):format(path, typeof(value))
		end
		if schemaNode._enumName ~= nil and tostring(value.EnumType) ~= schemaNode._enumName then
			return false, ("Expected enum '%s' at '%s', got '%s'"):format(
				tostring(schemaNode._enumName), path, tostring(value.EnumType))
		end
	elseif schemaNode._kind == "roblox" then

		if typeof(value) ~= typeName then
			return false, ("Expected %s at '%s', got %s"):format(typeName, path, typeof(value))
		end
	elseif schemaNode._kind == "custom" then
		if schemaNode._validateFn then
			local ok, err = schemaNode._validateFn(value)
			if not ok then
				return false, ("Validation failed at '%s': %s"):format(path, err or "unknown error")
			end
		end
	elseif schemaNode._validate then
		local ok, err = schemaNode._validate(value)
		if not ok then
			return false, ("Validation failed at '%s': %s"):format(path, err or "unknown error")
		end
	end

	return true
end

local function deepCopyAny(nodeValue, memo)
	if type(nodeValue) ~= "table" then
		return nodeValue
	end
	if memo[nodeValue] ~= nil then
		return memo[nodeValue]
	end
	local copy = {}
	memo[nodeValue] = copy
	for k, v in pairs(nodeValue) do
		copy[deepCopyAny(k, memo)] = deepCopyAny(v, memo)
	end
	return copy
end

local function applyDefaultsCopy(value, schemaNode, memo)
	if type(value) ~= "table" then
		return value
	end
	if memo[value] ~= nil then
		return memo[value]
	end
	local copy = {}
	memo[value] = copy
	for k, v in pairs(value) do
		copy[k] = v
	end
	for fieldName, fieldSchema in pairs(schemaNode._fields) do
		if copy[fieldName] == nil and fieldSchema._default ~= nil then
			copy[fieldName] = fieldSchema._default
		end
		local fieldValue = copy[fieldName]
		if fieldValue ~= nil then
			if fieldSchema._type == "object" and fieldSchema._fields then
				copy[fieldName] = applyDefaultsCopy(fieldValue, fieldSchema, memo)
			elseif fieldSchema._type == "any" and type(fieldValue) == "table" then
				copy[fieldName] = deepCopyAny(fieldValue, memo)
			end
		end
	end
	return copy
end

--[[ Returns a copy of an object value with schema defaults filled in
	(shared references and cycles preserved); the input is never mutated. ]]
function Schema.ApplyDefaults(value, schemaNode)
	if not schemaNode or not schemaNode._fields then
		return value
	end

	if schemaNode._type == "object" then
		return applyDefaultsCopy(value, schemaNode, {})
	end

	return value
end

return Schema
