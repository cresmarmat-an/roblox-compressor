# Compressor

Binary serialization for Roblox. Convert values to compact `buffer`s and back,
with full Roblox type support, optional schemas, and reference preservation.

## Guide

Require the module (installed as `ReplicatedStorage.Compressor`, see Install
in the project files) and call `Compress` / `Decompress`:

```lua
local Compressor = require(game:GetService("ReplicatedStorage").Compressor)

local buf = Compressor:Compress({coins = 100, pos = Vector3.new(1, 2, 3)})
local back = Compressor:Decompress(buf)
-- back.coins == 100, back.pos == Vector3.new(1, 2, 3)
```

Anything goes: numbers, strings, booleans, nested tables, arrays, dicts,
`Vector2`, `Vector3`, `CFrame`, `Color3`, `BrickColor`, `UDim`, `UDim2`,
`Ray`, `Rect`, `Region3`, `EnumItem`, `NumberSequence`, `ColorSequence`,
`NumberRange`, `PhysicalProperties`, `TweenInfo`, `DateTime`, `Font`,
`Axes`, `Faces`. Tables keep shared references and cycles:

```lua
local shared = {x = 1}
local r = Compressor:Decompress(Compressor:Compress({shared, shared}))
-- r[1] == r[2]

local loop = {}
loop.self = loop
local r2 = Compressor:Decompress(Compressor:Compress(loop))
-- r2.self == r2
```

Schemas make payloads smaller and add defaults plus validation.
`Compressor.Schema` builds them; pass one as the second argument:

```lua
local Schema = Compressor.Schema

local Player = Schema.Object({
    name  = Schema.String({ required = true }),
    level = Schema.Number({ default = 1 }),
    pos   = Schema.Vector3(),
    tags  = Schema.Array(Schema.String()),
    bag   = Schema.Map(Schema.String(), Schema.Number()),
})

local buf = Compressor:Compress({name = "Ada"}, Player)
local p = Compressor:Decompress(buf, Player)
-- p.level == 1 (filled from default; your table is never modified)

-- Missing required fields fail with the field path:
-- Compressor:Compress({}, Player)
-- error: Compressor: Schema validation failed: Required field '.name' is missing
```

Other shapes work the same way: `Schema.Array(item)`,
`Schema.Map(key, value)`, `Schema.Enum("Material")`, `Schema.Custom("MyType")`,
primitives like `Schema.Boolean()`, and one constructor per Roblox type
(`Schema.CFrame()`, `Schema.Color3()`, …). A field can also carry its own
check via `validate = function(v) ... end`.

Your own types plug in through a handler with two functions.
Register once, then use the name in schemas:

```lua
Compressor:RegisterType("Point2D", {
    Serialize = function(v, writer)
        writer:WriteF64(v.x)
        writer:WriteF64(v.y)
    end,
    Deserialize = function(reader)
        return {x = reader:ReadF64(), y = reader:ReadF64()}
    end,
})

local Pt = Schema.Custom("Point2D")
local pt = Compressor:Decompress(Compressor:Compress({x = 1.5, y = 2.5}, Pt), Pt)
```

Instances serialize by path for objects that exist on both ends of the same
server session. Turn the mode on first; missing paths come back `nil`, or
throw when strict mode is on:

```lua
Compressor:SetOption("instanceMode", "path")
local buf = Compressor:Compress(workspace.SpawnLocation)
local back = Compressor:Decompress(buf) -- the same Part, or nil if gone
Compressor:SetOption("instanceMode", "error") -- back to refusing Instances
```

DataStores only accept valid UTF-8, so raw binary is rejected there.
Encode first — the helpers are pure Luau:

```lua
store:SetAsync(key, Compressor:ToBase64(Compressor:Compress(data, schema)))

local raw = store:GetAsync(key)
local data = Compressor:Decompress(Compressor:FromBase64(raw), schema)
```

`buffer`s travel through remotes as-is:

```lua
-- server
remote.OnServerInvoke = function(player, buf) return buf end
-- client
local echo = remote:InvokeServer(Compressor:Compress(payload, schema))
local back = Compressor:Decompress(echo, schema)
```

When you save bytes long-term, version the envelope (for example
`{v = 2, data = Compressor:ToBase64(...)}`) and migrate on load: same fields
always read back, but adding or removing a schema field breaks old payloads.
Compare `Vector3` and other float32 engine values with an epsilon (~1e-6)
rather than `==`, and keep 64-bit integers within ±2^53.
