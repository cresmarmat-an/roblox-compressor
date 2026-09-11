--[[
	Every Compressor use case in one runnable script.
	Run it in Studio with:
		require(game.ReplicatedStorage.Demo)(require(game.ReplicatedStorage.Compressor))
]]
return function(Compressor)
	local Schema = Compressor.Schema
	local lines = {}

	local function show(name, value)
		local line = name .. " => " .. tostring(value)
		table.insert(lines, line)
		print(line)
	end

	local function approx(a, b)
		return math.abs(a - b) <= 1e-6
	end

	-- Primitives and tables, including shared references and cycles.
	local back = Compressor:Decompress(Compressor:Compress({
		nothing = nil,
		flag = true,
		count = 42,
		name = "Ada",
	}))
	show("primitives", tostring(back.count) .. "/" .. back.name .. "/" .. tostring(back.flag))
	local shared = {x = 1}
	local r = Compressor:Decompress(Compressor:Compress({shared, shared, {nested = {deep = true}}}))
	show("shared-identity", tostring(r[1] == r[2]))
	local loop = {}
	loop.self = loop
	show("cycle", tostring(Compressor:Decompress(Compressor:Compress(loop)).self ~= nil))

	-- Every Roblox value type.
	local values = {
		Vector2.new(1.5, -2.25),
		Vector3.new(1, -2, 3.5),
		CFrame.new(1, 2, 3) * CFrame.Angles(0.3, -0.7, 1.1),
		Color3.new(0.1, 0.5, 0.9),
		BrickColor.new(194),
		UDim.new(0.5, -10),
		UDim2.new(0.5, 10, 0.25, -20),
		Ray.new(Vector3.new(1, 2, 3), Vector3.new(0, 1, 0)),
		Rect.new(Vector2.new(1, 2), Vector2.new(30, 40)),
		Region3.new(Vector3.new(-4, 0, 2), Vector3.new(4, 8, 6)),
		Enum.Material.WoodPlanks,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0, 0),
			NumberSequenceKeypoint.new(1, 1, 0),
		}),
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.new(0, 0, 1)),
		}),
		NumberRange.new(-5.5, 42.25),
		PhysicalProperties.new(2.5, 0.6, 0.3, 1, 2),
		TweenInfo.new(2.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.InOut, 3, true, 0.5),
		DateTime.fromUnixTimestampMillis(-1000),
		Font.new("Gotham", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
		Axes.new(Enum.Axis.X, Enum.Axis.Y),
		Faces.new(Enum.NormalId.Front, Enum.NormalId.Top),
	}
	local typesOk = true
	for i, v in ipairs(values) do
		local ok, back2 = pcall(function()
			return Compressor:Decompress(Compressor:Compress(v))
		end)
		if not ok then
			typesOk = false
			warn("demo type failed at index " .. i .. ": " .. tostring(back2))
		elseif typeof(back2) ~= typeof(v) then
			typesOk = false
			warn("demo type mismatch at index " .. i)
		end
	end
	show("roblox-types-20", tostring(typesOk))
	local cf = Compressor:Decompress(Compressor:Compress(values[3]))
	local e, g = {values[3]:GetComponents()}, {cf:GetComponents()}
	local close = true
	for i = 1, 12 do
		if not approx(e[i], g[i]) then
			close = false
		end
	end
	show("cframe-exact", tostring(close))

	-- Schemas: every constructor, defaults, required, validation.
	local Player = Schema.Object({
		name = Schema.String({ required = true }),
		nick = Schema.String(),
		level = Schema.Number({ default = 1 }),
		alive = Schema.Boolean({ default = true }),
		pos = Schema.Vector3(),
		home = Schema.CFrame(),
		tint = Schema.Color3(),
		tags = Schema.Array(Schema.String()),
		bag = Schema.Map(Schema.String(), Schema.Number()),
		faction = Schema.Enum("Material"),
		note = Schema.Any(),
		empty = Schema.Nil(),
	})
	local p = Compressor:Decompress(Compressor:Compress({
		name = "Ada",
		pos = Vector3.new(1, 2, 3),
		home = CFrame.new(4, 5, 6),
		tint = Color3.new(1, 0, 0),
		tags = {"a", "b"},
		bag = {gold = 3},
		faction = Enum.Material.Wood,
		note = {1, 2},
	}, Player), Player)
	show("schema", p.name .. " lv" .. p.level .. " alive=" .. tostring(p.alive))
	local okReq = pcall(function()
		return Compressor:Compress({}, Player)
	end)
	show("schema-required-rejects", tostring(not okReq))
	local okType = pcall(function()
		return Compressor:Compress({name = "Ada", pos = "nope"}, Player)
	end)
	show("schema-type-rejects", tostring(not okType))

	-- Custom types.
	Compressor:RegisterType("Point2D", {
		Serialize = function(val, writer)
			writer:WriteF64(val.x)
			writer:WriteF64(val.y)
		end,
		Deserialize = function(reader)
			return {x = reader:ReadF64(), y = reader:ReadF64()}
		end,
	})
	local Pt = Schema.Custom("Point2D")
	local pt = Compressor:Decompress(Compressor:Compress({x = 1.5, y = 2.5}, Pt), Pt)
	show("custom", pt.x .. "," .. pt.y)

	-- Instances: path mode, missing paths, strict mode, error mode.
	local oldMode = Compressor:GetOption("instanceMode")
	local oldStrict = Compressor:GetOption("strict")
	Compressor:SetOption("instanceMode", "path")
	local folder = Instance.new("Folder")
	folder.Name = "DemoFolder"
	folder.Parent = workspace
	local part = Instance.new("Part")
	part.Name = "DemoPart"
	part.Parent = folder
	local same = Compressor:Decompress(Compressor:Compress(part)) == part
	folder:Destroy()
	local gone = Compressor:Decompress(Compressor:Compress(part))
	Compressor:SetOption("strict", true)
	local okStrict = pcall(function()
		return Compressor:Decompress(Compressor:Compress(part))
	end)
	part:Destroy()
	Compressor:SetOption("strict", oldStrict)
	Compressor:SetOption("instanceMode", "error")
	local part2 = Instance.new("Part")
	local okErr = pcall(function()
		return Compressor:Compress(part2)
	end)
	part2:Destroy()
	Compressor:SetOption("instanceMode", oldMode)
	show("instance", tostring(same) .. "/" .. tostring(gone == nil) .. "/" .. tostring(not okStrict) .. "/" .. tostring(not okErr))

	-- DataStore-ready encoding plus size/hex helpers.
	local enc = Compressor:ToBase64(Compressor:Compress({coins = 100}))
	local r3 = Compressor:Decompress(Compressor:FromBase64(enc))
	show("base64", r3.coins .. " (" .. #enc .. " chars)")
	show("size", Compressor:GetSize(Compressor:Compress(42)))
	show("hex", Compressor:ToHex(Compressor:Compress(true)))

	return lines
end
