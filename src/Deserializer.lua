local Reader = require(script.Parent.Reader)
local TypeRegistry = require(script.Parent.TypeRegistry)
local ReferenceTracker = require(script.Parent.ReferenceTracker)
local Primitives = require(script.Parent.Handlers.Primitives)
local RobloxTypes = require(script.Parent.Handlers.RobloxTypes)
local Instance = require(script.Parent.Handlers.Instance)

local TAG_NIL    = 0x00
local TAG_TRUE   = 0x01
local TAG_FALSE  = 0x02
local TAG_NUMBER = 0x03
local TAG_STRING = 0x04
local TAG_ARRAY  = 0x05
local TAG_DICT   = 0x06
local TAG_REF    = 0x7F

local TAG_INSTANCE_PATH = 0x26

local TAG_VECTOR2 = RobloxTypes.TAG_VECTOR2
local TAG_VECTOR3 = RobloxTypes.TAG_VECTOR3
local TAG_CFRAME = RobloxTypes.TAG_CFRAME
local TAG_COLOR3 = RobloxTypes.TAG_COLOR3
local TAG_BRICKCOLOR = RobloxTypes.TAG_BRICKCOLOR
local TAG_UDIM = RobloxTypes.TAG_UDIM
local TAG_UDIM2 = RobloxTypes.TAG_UDIM2
local TAG_RAY = RobloxTypes.TAG_RAY
local TAG_RECT = RobloxTypes.TAG_RECT
local TAG_REGION3 = RobloxTypes.TAG_REGION3
local TAG_ENUMITEM = RobloxTypes.TAG_ENUMITEM
local TAG_NUMBERSEQ = RobloxTypes.TAG_NUMBERSEQ
local TAG_COLORSEQ = RobloxTypes.TAG_COLORSEQ
local TAG_NUMBERRANGE = RobloxTypes.TAG_NUMBERRANGE
local TAG_PHYSPROPS = RobloxTypes.TAG_PHYSPROPS
local TAG_TWEENINFO = RobloxTypes.TAG_TWEENINFO
local TAG_DATETIME = RobloxTypes.TAG_DATETIME
local TAG_FONT = RobloxTypes.TAG_FONT
local TAG_AXES = RobloxTypes.TAG_AXES
local TAG_FACES = RobloxTypes.TAG_FACES

local Deserializer = {}

function Deserializer.Deserialize(buf, schema, options)
	options = options or {}
	local registry = options.registry

	local reader = Reader.new(buf, options.maxStringLen)
	local version = reader:ReadByte()

	if version ~= 1 then
		error(("Compressor: Unsupported version %d (expected 1)"):format(version))
	end

	local refTracker = ReferenceTracker.new()

	local context = {
		reader = reader,
		registry = registry,
		refTracker = refTracker,
		options = options,
		schema = schema,
		depth = 0,
		maxDepth = options and options.maxDepth or 100,
	}

	function context:Deserialize(schemaNode)
		self.depth = self.depth + 1
		if self.depth > self.maxDepth then
			self.depth = self.depth - 1
			error("Compressor: Maximum recursion depth (" .. self.maxDepth .. ") exceeded during deserialization")
		end

		local result

		if schemaNode and schemaNode._schemaMode and schemaNode._handler then
			result = schemaNode._handler.Deserialize(reader, context, schemaNode)
		else
			local tag = reader:ReadByte()

			if tag == TAG_NIL then
				result = nil
			elseif tag == TAG_TRUE then
				result = true
			elseif tag == TAG_FALSE then
				result = false
			elseif tag == TAG_NUMBER then
				result = reader:ReadF64()
			elseif tag == TAG_STRING then
				result = reader:ReadString()
			elseif tag == TAG_ARRAY then
				if schemaNode and schemaNode._schemaMode then
					result = schemaNode._handler.Deserialize(reader, context, schemaNode)
				else
					result = Primitives.DeserializeArray(reader, context, schemaNode)
				end
			elseif tag == TAG_DICT then
				if schemaNode and schemaNode._schemaMode then
					result = schemaNode._handler.Deserialize(reader, context, schemaNode)
				else
					result = Primitives.DeserializeDict(reader, context, schemaNode)
				end
			elseif tag == TAG_REF then
				result = Primitives.DeserializeRef(reader, context, schemaNode)

			elseif tag == TAG_INSTANCE_PATH then
				local path = reader:ReadString()
				local instance = Instance.ResolvePath(path)
				if not instance and options.strict then
					error(("Compressor: Instance at path '%s' not found"):format(path))
				end
				result = instance

			elseif tag == TAG_VECTOR2 then
				result = RobloxTypes.Vector2.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_VECTOR3 then
				result = RobloxTypes.Vector3.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_CFRAME then
				result = RobloxTypes.CFrame.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_COLOR3 then
				result = RobloxTypes.Color3.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_UDIM then
				result = RobloxTypes.UDim.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_UDIM2 then
				result = RobloxTypes.UDim2.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_RAY then
				result = RobloxTypes.Ray.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_RECT then
				result = RobloxTypes.Rect.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_REGION3 then
				result = RobloxTypes.Region3.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_ENUMITEM then
				result = RobloxTypes.EnumItem.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_NUMBERSEQ then
				result = RobloxTypes.NumberSequence.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_COLORSEQ then
				result = RobloxTypes.ColorSequence.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_NUMBERRANGE then
				result = RobloxTypes.NumberRange.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_PHYSPROPS then
				result = RobloxTypes.PhysicalProperties.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_TWEENINFO then
				result = RobloxTypes.TweenInfo.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_DATETIME then
				result = RobloxTypes.DateTime.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_FONT then
				result = RobloxTypes.Font.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_AXES then
				result = RobloxTypes.Axes.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_FACES then
				result = RobloxTypes.Faces.Deserialize(reader, context, schemaNode)
			elseif tag == TAG_BRICKCOLOR then
				result = RobloxTypes.BrickColor.Deserialize(reader, context, schemaNode)
			else

				local handler = registry and registry:ByTag(tag)
				if handler then
					result = handler.Deserialize(reader, context, schemaNode)
				else
					error(("Compressor: Unknown tag byte 0x%X encountered during deserialization"):format(tag))
				end
			end
		end

		self.depth = self.depth - 1
		return result
	end

	local value = context:Deserialize(schema)

	if options.strict and reader:Remaining() > 0 then
		error(("Compressor: %d trailing bytes after deserialization (strict mode)"):format(reader:Remaining()))
	end

	return value
end

return Deserializer
