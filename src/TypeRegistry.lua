local TypeRegistry = {}
TypeRegistry.__index = TypeRegistry

function TypeRegistry.new()
	local self = setmetatable({

		byTag = {},

		byName = {},

		byLuaType = {},

		byTypeof = {},

		nextCustomTag = 0x30,
	}, TypeRegistry)
	return self
end

function TypeRegistry:Register(name, handler, tag)
	assert(type(name) == "string", "TypeRegistry:Register: name must be a string")
	assert(type(handler) == "table", "TypeRegistry:Register: handler must be a table")
	assert(handler.Serialize, "TypeRegistry:Register: handler must have Serialize function")
	assert(handler.Deserialize, "TypeRegistry:Register: handler must have Deserialize function")

	if tag then
		assert(type(tag) == "number", "TypeRegistry:Register: tag must be a number")
		assert(self.byTag[tag] == nil, ("TypeRegistry:Register: tag 0x%X is already registered"):format(tag))
		self.byTag[tag] = handler
	end

	self.byName[name] = handler
	handler._name = name

	handler._tag = tag or handler._tag
	handler.Tag = tag or handler.Tag
	return handler
end

function TypeRegistry:RegisterLuaType(luaType, handler)
	assert(type(luaType) == "string", "TypeRegistry:RegisterLuaType: luaType must be a string")
	self.byLuaType[luaType] = handler
end

function TypeRegistry:RegisterTypeof(typeofStr, handler, tag)
	assert(type(typeofStr) == "string", "TypeRegistry:RegisterTypeof: typeofStr must be a string")
	self.byTypeof[typeofStr] = handler
	if tag then
		self.byTag[tag] = handler
		handler._tag = handler._tag or tag
		handler.Tag = handler.Tag or tag
	end
end

function TypeRegistry:RegisterCustom(name, handler, tag)
	if tag then
		assert(type(tag) == "number", "TypeRegistry:RegisterCustom: tag must be a number")
		assert(tag >= 0x30 and tag <= 0x7E,
			("TypeRegistry:RegisterCustom: tag 0x%X out of custom range 0x30..0x7E"):format(tag))
		assert(self.byTag[tag] == nil,
			("TypeRegistry:RegisterCustom: tag 0x%X is already registered"):format(tag))

		if tag >= self.nextCustomTag then
			self.nextCustomTag = tag + 1
		end
		return self:Register(name, handler, tag)
	end
	local autoTag = self.nextCustomTag
	self.nextCustomTag = self.nextCustomTag + 1
	assert(self.nextCustomTag <= 0x7F, "TypeRegistry:RegisterCustom: too many custom types registered (max tag 0x7E)")
	return self:Register(name, handler, autoTag)
end

function TypeRegistry:ByTag(tag)
	return self.byTag[tag]
end

function TypeRegistry:ByName(name)
	return self.byName[name]
end

function TypeRegistry:ByLuaType(luaType)
	return self.byLuaType[luaType]
end

function TypeRegistry:ByTypeof(typeofStr)
	return self.byTypeof[typeofStr]
end

function TypeRegistry:GetTag(handler)
	return handler._tag
end

function TypeRegistry:GetName(handler)
	return handler._name
end

return TypeRegistry
