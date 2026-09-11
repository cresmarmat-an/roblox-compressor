local RobloxTypes = {}

RobloxTypes.TAG_VECTOR2      = 0x10
RobloxTypes.TAG_VECTOR3      = 0x11
RobloxTypes.TAG_CFRAME       = 0x12
RobloxTypes.TAG_COLOR3       = 0x13
RobloxTypes.TAG_BRICKCOLOR   = 0x14
RobloxTypes.TAG_UDIM         = 0x15
RobloxTypes.TAG_UDIM2        = 0x16
RobloxTypes.TAG_RAY          = 0x17
RobloxTypes.TAG_RECT         = 0x18
RobloxTypes.TAG_REGION3      = 0x19
RobloxTypes.TAG_ENUMITEM     = 0x1A
RobloxTypes.TAG_NUMBERSEQ    = 0x1B
RobloxTypes.TAG_COLORSEQ     = 0x1C
RobloxTypes.TAG_NUMBERRANGE  = 0x1D
RobloxTypes.TAG_PHYSPROPS     = 0x1E
RobloxTypes.TAG_TWEENINFO    = 0x1F
RobloxTypes.TAG_DATETIME     = 0x20
RobloxTypes.TAG_FONT         = 0x21
RobloxTypes.TAG_AXES          = 0x22
RobloxTypes.TAG_FACES         = 0x23

RobloxTypes.Vector2 = {
	Tag = RobloxTypes.TAG_VECTOR2,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteF64(value.X)
		writer:WriteF64(value.Y)
	end,
	Deserialize = function(reader, context, schemaNode)
		local x = reader:ReadF64()
		local y = reader:ReadF64()
		return Vector2.new(x, y)
	end,
}

RobloxTypes.Vector3 = {
	Tag = RobloxTypes.TAG_VECTOR3,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteF64(value.X)
		writer:WriteF64(value.Y)
		writer:WriteF64(value.Z)
	end,
	Deserialize = function(reader, context, schemaNode)
		local x = reader:ReadF64()
		local y = reader:ReadF64()
		local z = reader:ReadF64()
		return Vector3.new(x, y, z)
	end,
}

RobloxTypes.CFrame = {
	Tag = RobloxTypes.TAG_CFRAME,
	Serialize = function(value, writer, context, schemaNode)
		local px, py, pz,
			xx, xy, xz,
			yx, yy, yz,
			zx, zy, zz = value:GetComponents()
		writer:WriteF64(px)
		writer:WriteF64(py)
		writer:WriteF64(pz)
		writer:WriteF64(xx)
		writer:WriteF64(xy)
		writer:WriteF64(xz)
		writer:WriteF64(yx)
		writer:WriteF64(yy)
		writer:WriteF64(yz)
		writer:WriteF64(zx)
		writer:WriteF64(zy)
		writer:WriteF64(zz)
	end,
	Deserialize = function(reader, context, schemaNode)
		local px = reader:ReadF64()
		local py = reader:ReadF64()
		local pz = reader:ReadF64()
		local xx = reader:ReadF64()
		local xy = reader:ReadF64()
		local xz = reader:ReadF64()
		local yx = reader:ReadF64()
		local yy = reader:ReadF64()
		local yz = reader:ReadF64()
		local zx = reader:ReadF64()
		local zy = reader:ReadF64()
		local zz = reader:ReadF64()

		return CFrame.fromMatrix(Vector3.new(px, py, pz), Vector3.new(xx, yx, zx), Vector3.new(xy, yy, zy), Vector3.new(xz, yz, zz))
	end,
}

RobloxTypes.Color3 = {
	Tag = RobloxTypes.TAG_COLOR3,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteF32(value.R)
		writer:WriteF32(value.G)
		writer:WriteF32(value.B)
	end,
	Deserialize = function(reader, context, schemaNode)
		local r = reader:ReadF32()
		local g = reader:ReadF32()
		local b = reader:ReadF32()
		return Color3.new(r, g, b)
	end,
}

RobloxTypes.BrickColor = {
	Tag = RobloxTypes.TAG_BRICKCOLOR,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteI32(value.Number)
	end,
	Deserialize = function(reader, context, schemaNode)
		local number = reader:ReadI32()
		return BrickColor.new(number)
	end,
}

RobloxTypes.UDim = {
	Tag = RobloxTypes.TAG_UDIM,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteF32(value.Scale)
		writer:WriteI32(value.Offset)
	end,
	Deserialize = function(reader, context, schemaNode)
		local scale = reader:ReadF32()
		local offset = reader:ReadI32()
		return UDim.new(scale, offset)
	end,
}

RobloxTypes.UDim2 = {
	Tag = RobloxTypes.TAG_UDIM2,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteF32(value.X.Scale)
		writer:WriteI32(value.X.Offset)
		writer:WriteF32(value.Y.Scale)
		writer:WriteI32(value.Y.Offset)
	end,
	Deserialize = function(reader, context, schemaNode)
		local xScale = reader:ReadF32()
		local xOffset = reader:ReadI32()
		local yScale = reader:ReadF32()
		local yOffset = reader:ReadI32()
		return UDim2.new(xScale, xOffset, yScale, yOffset)
	end,
}

RobloxTypes.Ray = {
	Tag = RobloxTypes.TAG_RAY,
	Serialize = function(value, writer, context, schemaNode)
		local origin = value.Origin
		local direction = value.Direction
		writer:WriteF64(origin.X)
		writer:WriteF64(origin.Y)
		writer:WriteF64(origin.Z)
		writer:WriteF64(direction.X)
		writer:WriteF64(direction.Y)
		writer:WriteF64(direction.Z)
	end,
	Deserialize = function(reader, context, schemaNode)
		local ox = reader:ReadF64()
		local oy = reader:ReadF64()
		local oz = reader:ReadF64()
		local dx = reader:ReadF64()
		local dy = reader:ReadF64()
		local dz = reader:ReadF64()
		return Ray.new(Vector3.new(ox, oy, oz), Vector3.new(dx, dy, dz))
	end,
}

RobloxTypes.Rect = {
	Tag = RobloxTypes.TAG_RECT,
	Serialize = function(value, writer, context, schemaNode)
		local min = value.Min
		local max = value.Max
		writer:WriteF32(min.X)
		writer:WriteF32(min.Y)
		writer:WriteF32(max.X)
		writer:WriteF32(max.Y)
	end,
	Deserialize = function(reader, context, schemaNode)
		local minX = reader:ReadF32()
		local minY = reader:ReadF32()
		local maxX = reader:ReadF32()
		local maxY = reader:ReadF32()
		return Rect.new(Vector2.new(minX, minY), Vector2.new(maxX, maxY))
	end,
}

RobloxTypes.Region3 = {
	Tag = RobloxTypes.TAG_REGION3,
	Serialize = function(value, writer, context, schemaNode)
		local cf = value.CFrame
		local size = value.Size
		local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
		writer:WriteF64(cf.X - hx)
		writer:WriteF64(cf.Y - hy)
		writer:WriteF64(cf.Z - hz)
		writer:WriteF64(cf.X + hx)
		writer:WriteF64(cf.Y + hy)
		writer:WriteF64(cf.Z + hz)
	end,
	Deserialize = function(reader, context, schemaNode)
		local minX = reader:ReadF64()
		local minY = reader:ReadF64()
		local minZ = reader:ReadF64()
		local maxX = reader:ReadF64()
		local maxY = reader:ReadF64()
		local maxZ = reader:ReadF64()
		return Region3.new(Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ))
	end,
}

RobloxTypes.EnumItem = {
	Tag = RobloxTypes.TAG_ENUMITEM,
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
}

RobloxTypes.NumberSequence = {
	Tag = RobloxTypes.TAG_NUMBERSEQ,
	Serialize = function(value, writer, context, schemaNode)
		local keypoints = value.Keypoints
		writer:WriteU32(#keypoints)
		for _, kp in ipairs(keypoints) do
			writer:WriteF64(kp.Time)
			writer:WriteF64(kp.Value)
			if kp.Envelope then
				writer:WriteF64(kp.Envelope)
			else
				writer:WriteF64(0)
			end
		end
	end,
	Deserialize = function(reader, context, schemaNode)
		local count = reader:ReadU32()
		local keypoints = table.create(count)
		for i = 1, count do
			local time = reader:ReadF64()
			local value = reader:ReadF64()
			local envelope = reader:ReadF64()
			keypoints[i] = NumberSequenceKeypoint.new(time, value, envelope)
		end
		return NumberSequence.new(keypoints)
	end,
}

RobloxTypes.ColorSequence = {
	Tag = RobloxTypes.TAG_COLORSEQ,
	Serialize = function(value, writer, context, schemaNode)
		local keypoints = value.Keypoints
		writer:WriteU32(#keypoints)
		for _, kp in ipairs(keypoints) do
			writer:WriteF64(kp.Time)
			writer:WriteF32(kp.Value.R)
			writer:WriteF32(kp.Value.G)
			writer:WriteF32(kp.Value.B)
		end
	end,
	Deserialize = function(reader, context, schemaNode)
		local count = reader:ReadU32()
		local keypoints = table.create(count)
		for i = 1, count do
			local time = reader:ReadF64()
			local r = reader:ReadF32()
			local g = reader:ReadF32()
			local b = reader:ReadF32()
			keypoints[i] = ColorSequenceKeypoint.new(time, Color3.new(r, g, b))
		end
		return ColorSequence.new(keypoints)
	end,
}

RobloxTypes.NumberRange = {
	Tag = RobloxTypes.TAG_NUMBERRANGE,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteF64(value.Min)
		writer:WriteF64(value.Max)
	end,
	Deserialize = function(reader, context, schemaNode)
		local min = reader:ReadF64()
		local max = reader:ReadF64()
		return NumberRange.new(min, max)
	end,
}

RobloxTypes.PhysicalProperties = {
	Tag = RobloxTypes.TAG_PHYSPROPS,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteF32(value.Density)
		writer:WriteF32(value.Friction)
		writer:WriteF32(value.Elasticity)
		writer:WriteF32(value.FrictionWeight)
		writer:WriteF32(value.ElasticityWeight)
	end,
	Deserialize = function(reader, context, schemaNode)
		local density = reader:ReadF32()
		local friction = reader:ReadF32()
		local elasticity = reader:ReadF32()
		local frictionWeight = reader:ReadF32()
		local elasticityWeight = reader:ReadF32()
		return PhysicalProperties.new(density, friction, elasticity, frictionWeight, elasticityWeight)
	end,
}

local function resolveEasingStyle(value)
	for _, style in ipairs(Enum.EasingStyle:GetEnumItems()) do
		if style.Value == value then
			return style
		end
	end
	return Enum.EasingStyle.Quad
end

local function resolveEasingDirection(value)
	for _, dir in ipairs(Enum.EasingDirection:GetEnumItems()) do
		if dir.Value == value then
			return dir
		end
	end
	return Enum.EasingDirection.Out
end

RobloxTypes.TweenInfo = {
	Tag = RobloxTypes.TAG_TWEENINFO,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteF64(value.Time)
		writer:WriteI32(value.EasingStyle.Value)
		writer:WriteI32(value.EasingDirection.Value)
		writer:WriteI32(value.RepeatCount)
		if value.Reverses then
			writer:WriteByte(1)
		else
			writer:WriteByte(0)
		end
		writer:WriteF64(value.DelayTime)
	end,
	Deserialize = function(reader, context, schemaNode)
		local time = reader:ReadF64()
		local easingStyleValue = reader:ReadI32()
		local easingDirectionValue = reader:ReadI32()
		local repeatCount = reader:ReadI32()
		local reverses = reader:ReadByte() == 1
		local delayTime = reader:ReadF64()

		local easingStyle = resolveEasingStyle(easingStyleValue)
		local easingDirection = resolveEasingDirection(easingDirectionValue)

		return TweenInfo.new(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)
	end,
}

RobloxTypes.DateTime = {
	Tag = RobloxTypes.TAG_DATETIME,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteI64(value.UnixTimestampMillis)
	end,
	Deserialize = function(reader, context, schemaNode)
		local unixMillis = reader:ReadI64()
		return DateTime.fromUnixTimestampMillis(unixMillis)
	end,
}

local function resolveFontWeight(value)
	for _, weight in ipairs(Enum.FontWeight:GetEnumItems()) do
		if weight.Value == value then
			return weight
		end
	end
	return Enum.FontWeight.Regular
end

local function resolveFontStyle(value)
	for _, style in ipairs(Enum.FontStyle:GetEnumItems()) do
		if style.Value == value then
			return style
		end
	end
	return Enum.FontStyle.Normal
end

RobloxTypes.Font = {
	Tag = RobloxTypes.TAG_FONT,
	Serialize = function(value, writer, context, schemaNode)
		writer:WriteString(value.Family)
		writer:WriteI32(value.Weight.Value)
		writer:WriteI32(value.Style.Value)
	end,
	Deserialize = function(reader, context, schemaNode)
		local family = reader:ReadString()
		local weightValue = reader:ReadI32()
		local styleValue = reader:ReadI32()
		return Font.new(family, resolveFontWeight(weightValue), resolveFontStyle(styleValue))
	end,
}

RobloxTypes.Axes = {
	Tag = RobloxTypes.TAG_AXES,
	Serialize = function(value, writer, context, schemaNode)
		local bitmask = 0
		if value.X then bitmask = bitmask + 1 end
		if value.Y then bitmask = bitmask + 2 end
		if value.Z then bitmask = bitmask + 4 end
		writer:WriteByte(bitmask)
	end,
	Deserialize = function(reader, context, schemaNode)
		local bitmask = reader:ReadByte()
		local args = {}
		if bitmask % 2 >= 1 then
			args[#args + 1] = Enum.Axis.X
		end
		if math.floor(bitmask / 2) % 2 >= 1 then
			args[#args + 1] = Enum.Axis.Y
		end
		if math.floor(bitmask / 4) % 2 >= 1 then
			args[#args + 1] = Enum.Axis.Z
		end
		return Axes.new(table.unpack(args))
	end,
}

RobloxTypes.Faces = {
	Tag = RobloxTypes.TAG_FACES,
	Serialize = function(value, writer, context, schemaNode)
		local bitmask = 0
		if value.Front then bitmask = bitmask + 1 end
		if value.Back then bitmask = bitmask + 2 end
		if value.Top then bitmask = bitmask + 4 end
		if value.Bottom then bitmask = bitmask + 8 end
		if value.Left then bitmask = bitmask + 16 end
		if value.Right then bitmask = bitmask + 32 end
		writer:WriteByte(bitmask)
	end,
	Deserialize = function(reader, context, schemaNode)
		local bitmask = reader:ReadByte()
		local args = {}
		if bitmask % 2 >= 1 then
			args[#args + 1] = Enum.NormalId.Front
		end
		if math.floor(bitmask / 2) % 2 >= 1 then
			args[#args + 1] = Enum.NormalId.Back
		end
		if math.floor(bitmask / 4) % 2 >= 1 then
			args[#args + 1] = Enum.NormalId.Top
		end
		if math.floor(bitmask / 8) % 2 >= 1 then
			args[#args + 1] = Enum.NormalId.Bottom
		end
		if math.floor(bitmask / 16) % 2 >= 1 then
			args[#args + 1] = Enum.NormalId.Left
		end
		if math.floor(bitmask / 32) % 2 >= 1 then
			args[#args + 1] = Enum.NormalId.Right
		end
		return Faces.new(table.unpack(args))
	end,
}

return RobloxTypes
