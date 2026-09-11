local Reader = {}
Reader.__index = Reader

local readu8 = buffer.readu8
local readu16 = buffer.readu16
local readu32 = buffer.readu32
local readi16 = buffer.readi16
local readi32 = buffer.readi32
local readf32 = buffer.readf32
local readf64 = buffer.readf64
local readstring = buffer.readstring
local create = buffer.create
local copy = buffer.copy

function Reader.new(buf, maxStringLen)
	local self = setmetatable({
		buf = buf,
		len = buf and buffer.len(buf) or 0,
		pos = 0,
		maxStringLen = maxStringLen or 20000000,
	}, Reader)
	return self
end

function Reader:GetBuffer()
	return self.buf
end

function Reader:Length()
	return self.len
end

function Reader:Position()
	return self.pos
end

function Reader:Remaining()
	return self.len - self.pos
end

function Reader:_checkAvailable(size)
	if self.pos + size > self.len then
		error(("Reader: attempted to read %d bytes at position %d, but buffer length is %d"):format(
			size, self.pos, self.len
		))
	end
end

function Reader:PeekByte()
	if self.pos >= self.len then
		return nil
	end
	return readu8(self.buf, self.pos)
end

function Reader:ReadByte()
	self:_checkAvailable(1)
	local val = readu8(self.buf, self.pos)
	self.pos = self.pos + 1
	return val
end

function Reader:ReadU16()
	self:_checkAvailable(2)
	local val = readu16(self.buf, self.pos)
	self.pos = self.pos + 2
	return val
end

function Reader:ReadU32()
	self:_checkAvailable(4)
	local val = readu32(self.buf, self.pos)
	self.pos = self.pos + 4
	return val
end

function Reader:ReadI16()
	self:_checkAvailable(2)
	local val = readi16(self.buf, self.pos)
	self.pos = self.pos + 2
	return val
end

function Reader:ReadI32()
	self:_checkAvailable(4)
	local val = readi32(self.buf, self.pos)
	self.pos = self.pos + 4
	return val
end

function Reader:ReadI64()
	self:_checkAvailable(8)
	local lo = readu32(self.buf, self.pos)
	local hi = readi32(self.buf, self.pos + 4)
	self.pos = self.pos + 8
	return hi * 2^32 + lo
end

function Reader:ReadF32()
	self:_checkAvailable(4)
	local val = readf32(self.buf, self.pos)
	self.pos = self.pos + 4
	return val
end

function Reader:ReadF64()
	self:_checkAvailable(8)
	local val = readf64(self.buf, self.pos)
	self.pos = self.pos + 8
	return val
end

function Reader:ReadNumber()
	self:_checkAvailable(8)
	local val = readf64(self.buf, self.pos)
	self.pos = self.pos + 8
	return val
end

function Reader:ReadString()
	self:_checkAvailable(2)
	local byteLen = readu16(self.buf, self.pos)
	self.pos = self.pos + 2
	if byteLen == 0xFFFF then

		self:_checkAvailable(4)
		byteLen = readu32(self.buf, self.pos)
		self.pos = self.pos + 4
	end
	self:_checkAvailable(byteLen)
	if byteLen > self.maxStringLen then
		error(("Reader: string length %d exceeds limit %d"):format(byteLen, self.maxStringLen))
	end
	if byteLen == 0 then
		return ""
	end
	local str = readstring(self.buf, self.pos, byteLen)
	self.pos = self.pos + byteLen
	return str
end

function Reader:ReadLongString()
	self:_checkAvailable(4)
	local byteLen = readu32(self.buf, self.pos)
	self.pos = self.pos + 4
	self:_checkAvailable(byteLen)
	if byteLen > self.maxStringLen then
		error(("Reader: string length %d exceeds limit %d"):format(byteLen, self.maxStringLen))
	end
	if byteLen == 0 then
		return ""
	end
	local str = readstring(self.buf, self.pos, byteLen)
	self.pos = self.pos + byteLen
	return str
end

function Reader:ReadBuffer(size)
	self:_checkAvailable(size)
	local newBuf = create(size)
	copy(newBuf, 0, self.buf, self.pos, size)
	self.pos = self.pos + size
	return newBuf
end

return Reader
