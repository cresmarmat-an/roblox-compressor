local Instance = {}

local TAG_INSTANCE_PATH = 0x26
local TAG_INSTANCE_CUSTOM = 0x27

function Instance.ResolvePath(path)
	if not path or path == "" then
		return nil
	end

	local parts = string.split(path, ".")
	if #parts == 0 then
		return nil
	end

	local startIdx = 1
	if parts[1] == "game" then
		startIdx = 2
	end

	local current = game
	for i = startIdx, #parts do
		local part = parts[i]
		if part ~= "" and part ~= "game" then
			local finder = current and current.FindFirstChild
			if type(finder) ~= "function" then
				return nil
			end
			current = finder(current, part)
			if not current then
				return nil
			end
		end
	end

	return current
end

function Instance.SerializePath(instance, writer)
	local path = instance:GetFullName()
	writer:WriteByte(TAG_INSTANCE_PATH)
	writer:WriteString(path)
end

function Instance.DeserializePath(reader, options)
	options = options or {}
	local path = reader:ReadString()
	local instance = Instance.ResolvePath(path)
	if not instance then
		if options.strict then
			error(("Compressor: Instance at path '%s' not found"):format(path))
		end
		return nil
	end
	return instance
end

function Instance.SerializeCustom(instance, writer, idFunc)
	assert(type(idFunc) == "function", "Instance:SerializeCustom requires an idFunc")
	local id = idFunc(instance)
	assert(type(id) == "string" or type(id) == "number", "Instance:SerializeCustom: idFunc must return string or number")
	writer:WriteByte(TAG_INSTANCE_CUSTOM)
	if type(id) == "string" then
		writer:WriteByte(1)
		writer:WriteString(id)
	else
		writer:WriteByte(0)
		writer:WriteI32(id)
	end
end

function Instance.DeserializeCustom(reader, lookupFunc)
	assert(type(lookupFunc) == "function", "Instance:DeserializeCustom requires a lookupFunc")
	local idType = reader:ReadByte()
	local id
	if idType == 1 then
		id = reader:ReadString()
	else
		id = reader:ReadI32()
	end
	return lookupFunc(id)
end

function Instance.SerializeError(instance, writer)
	error("Compressor: Instances cannot be serialized. Register a custom handler for 'Instance', or set instanceMode to 'path'.")
end

return Instance
