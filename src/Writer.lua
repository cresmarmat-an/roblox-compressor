local Writer = {}
Writer.__index = Writer

local writeu8 = buffer.writeu8
local writeu16 = buffer.writeu16
local writeu32 = buffer.writeu32
local writei16 = buffer.writei16
local writei32 = buffer.writei32
local writef32 = buffer.writef32
local writef64 = buffer.writef64
local create = buffer.create
local copy = buffer.copy

local DEFAULT_CAPACITY = 256

function Writer.new(initialCapacity)
	initialCapacity = initialCapacity or DEFAULT_CAPACITY
	local self = setmetatable({
		buf = create(initialCapacity),
		len = 0,
		cap = initialCapacity,
	}, Writer)
	return self
end

function Writer:_ensure(size)
	local needed = self.len + size
	if needed <= self.cap then return end

	local newCap = self.cap
	while needed > newCap do
		newCap = newCap * 2
		if newCap == 0 then newCap = DEFAULT_CAPACITY end
	end
	local newBuf = create(newCap)
	copy(newBuf, 0, self.buf, 0, self.len)
	self.buf = newBuf
	self.cap = newCap
end

function Writer:Reserve(size)
	self:_ensure(size)
end

function Writer:GetBuffer()
	local result = create(self.len)
	if self.len > 0 then
		buffer.copy(result, 0, self.buf, 0, self.len)
	end
	return result
end

function Writer:Length()
	return self.len
end

function Writer:WriteByte(value)
	self:_ensure(1)
	writeu8(self.buf, self.len, value)
	self.len = self.len + 1
end

function Writer:WriteU16(value)
	self:_ensure(2)
	writeu16(self.buf, self.len, value)
	self.len = self.len + 2
end

function Writer:WriteU32(value)
	self:_ensure(4)
	writeu32(self.buf, self.len, value)
	self.len = self.len + 4
end

function Writer:WriteI16(value)
	self:_ensure(2)
	writei16(self.buf, self.len, value)
	self.len = self.len + 2
end

function Writer:WriteI32(value)
	self:_ensure(4)
	writei32(self.buf, self.len, value)
	self.len = self.len + 4
end

function Writer:WriteI64(value)
	assert(type(value) == "number", "WriteI64 expects a number value")
	assert(value % 1 == 0, "WriteI64 expects an integer value")
	assert(value > -2^53 and value < 2^53, "WriteI64 value out of exactly-representable range")
	self:_ensure(8)
	local hi = math.floor(value / 2^32)
	local lo = value - hi * 2^32
	writeu32(self.buf, self.len, lo)
	writei32(self.buf, self.len + 4, hi)
	self.len = self.len + 8
end

function Writer:WriteF32(value)
	self:_ensure(4)
	writef32(self.buf, self.len, value)
	self.len = self.len + 4
end

function Writer:WriteF64(value)
	self:_ensure(8)
	writef64(self.buf, self.len, value)
	self.len = self.len + 8
end

function Writer:WriteString(str)
	assert(type(str) == "string", "WriteString expects a string value")
	local byteLen = #str
	if byteLen <= 0xFFFF then
		self:_ensure(2 + byteLen)
		writeu16(self.buf, self.len, byteLen)
		self.len = self.len + 2
		if byteLen > 0 then
			buffer.writestring(self.buf, self.len, str, byteLen)
			self.len = self.len + byteLen
		end
	else

		self:_ensure(2 + 4 + byteLen)
		writeu16(self.buf, self.len, 0xFFFF)
		writeu32(self.buf, self.len + 2, byteLen)
		self.len = self.len + 6
		if byteLen > 0 then
			buffer.writestring(self.buf, self.len, str, byteLen)
			self.len = self.len + byteLen
		end
	end
end

function Writer:WriteLongString(str)
	assert(type(str) == "string", "WriteLongString expects a string value")
	local byteLen = #str
	self:_ensure(4 + byteLen)
	writeu32(self.buf, self.len, byteLen)
	self.len = self.len + 4
	if byteLen > 0 then
		buffer.writestring(self.buf, self.len, str, byteLen)
		self.len = self.len + byteLen
	end
end

return Writer
