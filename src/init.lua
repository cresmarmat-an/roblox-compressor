local Serializer = require(script.Serializer)
local Deserializer = require(script.Deserializer)
local Schema = require(script.Schema)
local TypeRegistry = require(script.TypeRegistry)
local RobloxTypes = require(script.Handlers.RobloxTypes)

local Compressor = {}

Compressor._options = {
	instanceMode = "error",
	internStrings = false,
	refThreshold = 2,
	strict = false,
	maxDepth = 100,
	maxTableSize = 1000000,
	maxStringLen = 20000000,
}

Compressor._registry = TypeRegistry.new()

Compressor.Schema = Schema

--[[ Sets a global option. Valid names: "instanceMode" ("error" | "path"),
	"strict" (missing instances and trailing bytes become errors),
	"maxDepth", "maxTableSize", "maxStringLen".
	`internStrings` and `refThreshold` are reserved and have no effect. ]]
function Compressor:SetOption(optionName, value)
	self._options[optionName] = value
end

--[[ Returns the current value of a global option (see SetOption). ]]
function Compressor:GetOption(optionName)
	return self._options[optionName]
end

--[[ Registers a custom type handler under `name` for Schema.Custom and
	schemaless dispatch. The handler must provide
	Serialize(value, writer, context) and Deserialize(reader, context).
	An explicit tag byte (0x30..0x7E) gives stable wire values; otherwise
	the next free tag is assigned. Returns the handler. ]]
function Compressor:RegisterType(name, handler, tag)
	self._registry:RegisterCustom(name, handler, tag)

	Schema.RegisterTypeHandler(name, handler)

	if handler.Tag and not tag then
		self._registry:RegisterTypeof(name, handler, handler.Tag)
	end
	return handler
end

--[[ Serializes `data` into a binary buffer. With a schema, the data is
	validated first (errors carry the field path) and defaults are filled
	into a copy — the caller's table is never mutated. Without a schema
	the value is self-describing (larger output) and supports cycles and
	shared references. ]]
function Compressor:Compress(data, schema)

	if schema and not schema._compiled then
		Schema.Compile(schema, self._registry)
	end

	if schema then
		local ok, err = Schema.Validate(data, schema)
		if not ok then
			error(("Compressor: Schema validation failed: %s"):format(err))
		end

		data = Schema.ApplyDefaults(data, schema)
	end

	local opts = {
		registry = self._registry,
		instanceMode = self._options.instanceMode,
		internStrings = self._options.internStrings,
		refThreshold = self._options.refThreshold,
		strict = self._options.strict,
		maxDepth = self._options.maxDepth,
		maxTableSize = self._options.maxTableSize,
		maxStringLen = self._options.maxStringLen,
	}

	return Serializer.Serialize(data, schema, opts)
end

--[[ Deserializes a buffer produced by Compress back to the original
	value, optionally with the same schema. Rejects unknown versions,
	truncated input and unknown tags, and — under `strict` — missing
	instances and trailing bytes. ]]
function Compressor:Decompress(buf, schema)

	if schema and not schema._compiled then
		Schema.Compile(schema, self._registry)
	end

	local opts = {
		registry = self._registry,
		instanceMode = self._options.instanceMode,
		internStrings = self._options.internStrings,
		refThreshold = self._options.refThreshold,
		strict = self._options.strict,
		maxDepth = self._options.maxDepth,
		maxTableSize = self._options.maxTableSize,
		maxStringLen = self._options.maxStringLen,
	}

	return Deserializer.Deserialize(buf, schema, opts)
end

--[[ Renders a buffer as a lowercase hex string (bytes separated by
	spaces) for debugging. ]]
function Compressor:ToHex(buf)
	if not buf then
		return ""
	end
	local len = buffer.len(buf)
	local hex = {}
	for i = 0, len - 1 do
		local b = buffer.readu8(buf, i)
		hex[i + 1] = string.format("%02x", b)
	end
	return table.concat(hex, " ")
end

--[[ Returns the byte size of a buffer. ]]
function Compressor:GetSize(buf)
	return buffer.len(buf)
end

local B64CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64REV
do
	local rev = {}
	for i = 1, 64 do
		rev[B64CHARS:sub(i, i)] = i - 1
	end
	B64REV = rev
end

--[[ Encodes a buffer as RFC 4648 base64 text, which DataStores
	accept (raw binary is rejected as invalid UTF-8). Costs ~4:3 in size. ]]
function Compressor:ToBase64(buf)
	local n = buffer.len(buf)
	if n == 0 then
		return ""
	end
	local raw = buffer.readstring(buf, 0, n)
	local out = table.create(math.ceil(n / 3) * 4)
	local o = 0
	for i = 1, n, 3 do
		local rem = n - i + 1
		local a = raw:byte(i)
		local b = 0
		local c = 0
		if rem > 1 then b = raw:byte(i + 1) end
		if rem > 2 then c = raw:byte(i + 2) end
		local n24 = a * 65536 + b * 256 + c
		o = o + 1
		out[o] = B64CHARS:sub(math.floor(n24 / 262144) + 1, math.floor(n24 / 262144) + 1)
		o = o + 1
		out[o] = B64CHARS:sub(math.floor(n24 / 4096) % 64 + 1, math.floor(n24 / 4096) % 64 + 1)
		o = o + 1
		if rem > 1 then
			out[o] = B64CHARS:sub(math.floor(n24 / 64) % 64 + 1, math.floor(n24 / 64) % 64 + 1)
		else
			out[o] = "="
		end
		o = o + 1
		if rem > 2 then
			out[o] = B64CHARS:sub(n24 % 64 + 1, n24 % 64 + 1)
		else
			out[o] = "="
		end
	end
	return table.concat(out)
end

--[[ Decodes a ToBase64 string back into a buffer. Errors on
	malformed input. ]]
function Compressor:FromBase64(str)
	assert(type(str) == "string", "Compressor:FromBase64 expects a string")
	local n = #str
	if n == 0 then
		return buffer.create(0)
	end
	if n % 4 ~= 0 then
		error("Compressor: Invalid base64 length")
	end
	local pad = 0
	if str:sub(n, n) == "=" then
		pad = pad + 1
	end
	if str:sub(n - 1, n - 1) == "=" then
		pad = pad + 1
	end
	if pad > 2 then
		error("Compressor: Invalid base64 padding")
	end
	local outLen = math.floor(n / 4) * 3 - pad
	local buf = buffer.create(outLen)
	local pos = 0
	for i = 1, n, 4 do
		local c1 = B64REV[str:sub(i, i)]
		local c2 = B64REV[str:sub(i + 1, i + 1)]
		local c3 = B64REV[str:sub(i + 2, i + 2)]
		local c4 = B64REV[str:sub(i + 3, i + 3)]
		if c1 == nil or c2 == nil then
			error("Compressor: Invalid base64 character")
		end
		if c3 == nil then
			if str:sub(i + 2, i + 2) ~= "=" then
				error("Compressor: Invalid base64 character")
			end
			c3 = 0
		end
		if c4 == nil then
			if str:sub(i + 3, i + 3) ~= "=" then
				error("Compressor: Invalid base64 character")
			end
			c4 = 0
		end
		local n24 = c1 * 262144 + c2 * 4096 + c3 * 64 + c4
		buffer.writeu8(buf, pos, math.floor(n24 / 65536) % 256)
		if pos + 1 < outLen then
			buffer.writeu8(buf, pos + 1, math.floor(n24 / 256) % 256)
		end
		if pos + 2 < outLen then
			buffer.writeu8(buf, pos + 2, n24 % 256)
		end
		pos = pos + 3
	end
	return buf
end

local RobloxTypeMap = {
	{"Vector2", RobloxTypes.Vector2},
	{"Vector3", RobloxTypes.Vector3},
	{"CFrame", RobloxTypes.CFrame},
	{"Color3", RobloxTypes.Color3},
	{"BrickColor", RobloxTypes.BrickColor},
	{"UDim", RobloxTypes.UDim},
	{"UDim2", RobloxTypes.UDim2},
	{"Ray", RobloxTypes.Ray},
	{"Rect", RobloxTypes.Rect},
	{"Region3", RobloxTypes.Region3},
	{"EnumItem", RobloxTypes.EnumItem},
	{"NumberSequence", RobloxTypes.NumberSequence},
	{"ColorSequence", RobloxTypes.ColorSequence},
	{"NumberRange", RobloxTypes.NumberRange},
	{"PhysicalProperties", RobloxTypes.PhysicalProperties},
	{"TweenInfo", RobloxTypes.TweenInfo},
	{"DateTime", RobloxTypes.DateTime},
	{"Font", RobloxTypes.Font},
	{"Axes", RobloxTypes.Axes},
	{"Faces", RobloxTypes.Faces},
}

for _, entry in ipairs(RobloxTypeMap) do
	local name, handler = entry[1], entry[2]
	Compressor._registry:RegisterTypeof(name, handler, handler.Tag)
	Schema.RegisterTypeHandler(name, handler)
end

return Compressor
