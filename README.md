# Compressor

Compressor turns Roblox values — numbers, strings, tables, `Vector3`s,
player data, anything — into compact blocks of bytes (called `buffer`s),
and turns them back. Use it to send less data over remotes and to save
smaller snapshots in DataStores.

```lua
local Compressor = require(game:GetService("ReplicatedStorage").Compressor)

local buf = Compressor:Compress({coins = 100, pos = Vector3.new(1, 2, 3)})
local back = Compressor:Decompress(buf)
-- back.coins == 100, back.pos == Vector3.new(1, 2, 3)
```

## Contents

- [Install](#install)
- [Quick start](#quick-start)
- [Values](#values)
- [Schemas](#schemas)
- [Custom types](#custom-types)
- [Instances](#instances)
- [DataStores](#datastores)
- [Networking](#networking)
- [Options](#options)
- [Schema evolution](#schema-evolution)
- [Limits](#limits)
- [Wire format](#wire-format)

## Install

Pick one of three ways. All three give you a `Compressor` ModuleScript;
the examples in this guide assume it lives at
`game.ReplicatedStorage.Compressor`.

### From Wally (recommended if you use Wally)

Open the package page and copy the dependency line into your `wally.toml`:

[https://wally.run/package/cresmarmat-an/compressor](https://wally.run/package/cresmarmat-an/compressor)

```toml
[dependencies]
Compressor = "cresmarmat-an/compressor@LATEST_VERSION"
```

Then run `wally install` and sync. (If the page is empty, the package has
not been published yet — use the file below meanwhile.)

### From a release file (no tools needed)

1. Open the releases page:
   [https://github.com/cresmarmat-an/roblox-compressor/releases](https://github.com/cresmarmat-an/roblox-compressor/releases)
2. Download `Compressor.rbxm` from the newest release. (It appears there
   automatically whenever a new version is tagged.)
3. In Roblox Studio, right-click `ReplicatedStorage` → *Insert from File*,
   pick the file. You now have a `Compressor` ModuleScript with everything
   inside it — no dependencies.

### From source (contributors)

Clone the repo and use the Rojo projects: `default.project.json` builds the
`Compressor` tree, `demo.project.json` builds the demo place. You need
[Rojo 7](https://rojo.space/) (`rokit.toml` pins the toolchain).

## Quick start

`Compress(data, schema?)` takes any value and returns a `buffer` — Roblox's
built-in container for raw bytes. Buffers are cheap to send and store.
`Decompress(buf, schema?)` turns one back into the value:

```lua
local buf = Compressor:Compress("Hello")
print(Compressor:Decompress(buf)) -- Hello
print(Compressor:GetSize(buf))    -- how many bytes it took
```

The second argument, `schema`, is optional. Without it, anything round-trips
as-is. With it (see [Schemas](#schemas)), the output gets smaller and your
data gets checked and filled in.

## Values

You can compress plain Lua values — `nil`, booleans, numbers, strings,
arrays, dicts, nested mixes — and every Roblox value type: `Vector2`,
`Vector3`, `CFrame`, `Color3`, `BrickColor`, `UDim`, `UDim2`, `Ray`,
`Rect`, `Region3`, `EnumItem`, `NumberSequence`, `ColorSequence`,
`NumberRange`, `PhysicalProperties`, `TweenInfo`, `DateTime`, `Font`,
`Axes`, `Faces` (`Instance` needs opting in — see
[Instances](#instances)).

Tables keep their shape, including tricks that break most serializers:

```lua
-- The same table twice stays the same table:
local shared = {x = 1}
local r = Compressor:Decompress(Compressor:Compress({shared, shared}))
-- r[1] == r[2]

-- Cycles survive too:
local loop = {}
loop.self = loop
local r2 = Compressor:Decompress(Compressor:Compress(loop))
-- r2.self == r2
```

## Schemas

A schema is a short description of what your data looks like. You build one
from pieces under `Compressor.Schema` and pass it as the second argument.
Three things happen: the output gets smaller (types don't need labels),
missing fields get their defaults, and wrong data is rejected with the field
path in the error.

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
```

Start simple — `Compress` works fine without any schema — and add schemas
where payload size or validation matters.

### The pieces

Group several named fields:

- `Schema.Object({name = ..., level = ...})` — a dict with known fields.
  Only the values travel (in sorted order); fields the reader doesn't know
  are dropped.

Collect many of the same thing:

- `Schema.Array(itemSchema)` — a list where every element matches, e.g.
  `Schema.Array(Schema.String())`.
- `Schema.Map(keySchema, valueSchema)` — a dict with typed keys and values,
  e.g. `Schema.Map(Schema.String(), Schema.Number())`.

Single values: `Schema.Nil()`, `Schema.Boolean()`, `Schema.Number()`,
`Schema.String()`, and `Schema.Any()` (accepts anything; costs a few extra
bytes since the type travels along).

One constructor per Roblox type: `Schema.Vector2()`, `Schema.Vector3()`,
`Schema.CFrame()`, `Schema.Color3()`, `Schema.BrickColor()`,
`Schema.UDim()`, `Schema.UDim2()`, `Schema.Ray()`, `Schema.Rect()`,
`Schema.Region3()`, `Schema.EnumItem()`, `Schema.NumberSequence()`,
`Schema.ColorSequence()`, `Schema.NumberRange()`,
`Schema.PhysicalProperties()`, `Schema.TweenInfo()`, `Schema.DateTime()`,
`Schema.Font()`, `Schema.Axes()`, `Schema.Faces()`.

Two specials: `Schema.Enum("Material")` accepts `EnumItem`s of one enum,
and `Schema.Custom("MyType")` accepts a type you registered yourself
(see [Custom types](#custom-types)).

### Field options

Each piece accepts `{ required, default, validate }`:

```lua
Schema.Object({
    name  = Schema.String({ required = true }),
    level = Schema.Number({ default = 1 }),
    score = Schema.Number({ validate = function(v)
        return v >= 0, "score must be non-negative"
    end }),
})
```

- `required = true` — compressing without this field is an error.
- `default = v` — used when the field is missing. Defaults are written into
  a copy, so the table you passed in is never changed. This also works in
  nested objects, and shared references stay shared.
- `validate = fn` — your own check. Return `true` when the value is fine;
  anything else fails validation, and the error names the field:

```lua
-- Compressor:Compress({}, Player)
-- error: Compressor: Schema validation failed: Required field '.name' is missing
```

### Advanced: Compile, Validate, ApplyDefaults

You normally never call these — `Compress` / `Decompress` run them for you.
They exist for tooling and for checking data early:

- `Schema.Compile(node, registry)` — prepares a schema (and its children)
  for use; the result is cached on the node.
- `Schema.Validate(value, node, path?)` — returns `true`, or `false` plus a
  message with the field path.
- `Schema.ApplyDefaults(value, node)` — returns the copy with defaults filled.
- `Schema.RegisterTypeHandler(name, handler)` — hooks a custom type into
  schemas. `RegisterType` already calls this for you.

## Custom types

Teach the library your own values with two small functions: one writes the
bytes, one reads them back. Register once, then use the name in schemas:

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

`RegisterType(name, handler, tag?)` — `tag` is an optional fixed byte
(`0x30`–`0x7E`); leave it out for auto-assignment. Inside handlers you can
use: `WriteByte`, `WriteU16`, `WriteU32`, `WriteI16`, `WriteI32`, `WriteI64`
(whole numbers within ±2^53), `WriteF32`, `WriteF64`, `WriteString` — and the
matching `ReadByte`, `ReadU16`, `ReadU32`, `ReadI16`, `ReadI32`, `ReadI64`,
`ReadF32`, `ReadF64`, `ReadString`. Custom table types only trigger through
schemas; without one they encode as plain dicts.

## Instances

Live objects (`Part`s, `Folder`s, …) are not values, so the library refuses
them by default. If both ends are in the same server session and the object
exists on both, you can send it by path:

```lua
Compressor:SetOption("instanceMode", "path")
local buf = Compressor:Compress(workspace.SpawnLocation)
local back = Compressor:Decompress(buf) -- the same Part, or nil if gone
Compressor:SetOption("instanceMode", "error") -- back to refusing Instances
```

Paths cannot cross restarts, and they never clone objects — they only point
at things already there. With `strict` on, a missing path throws instead of
returning `nil`.

## DataStores

DataStores only accept valid text (UTF-8), so raw binary is rejected there.
Encode first — the helpers are plain Luau with no dependencies:

```lua
store:SetAsync(key, Compressor:ToBase64(Compressor:Compress(data, schema)))

local raw = store:GetAsync(key)
local data = Compressor:Decompress(Compressor:FromBase64(raw), schema)
```

Base64 costs about a third extra in size. DataStore values cap at 4MB, so
keep encoded payloads comfortably below that — budget ~3MB of binary.

## Networking

`RemoteEvent`s (fire-and-forget messages) and `RemoteFunction`s (call and
wait for an answer) both carry `buffer`s as-is:

```lua
-- server
remote.OnServerInvoke = function(player, buf) return buf end
-- client
local echo = remote:InvokeServer(Compressor:Compress(payload, schema))
local back = Compressor:Decompress(echo, schema)
```

On live games each client gets roughly 50KB/s, so chunk big state into
several sends instead of one giant buffer.

## Options

`Compressor:SetOption(name, value)` changes a setting;
`Compressor:GetOption(name)` reads it back:

| Option | Default | What it does |
|---|---|---|
| `instanceMode` | `"error"` | `"error"` refuses live objects; `"path"` sends their location |
| `strict` | `false` | missing objects and trailing bytes become errors instead of `nil` / ignored |
| `maxDepth` | `100` | how deeply tables may nest, both directions |
| `maxTableSize` | `1000000` | most array items / dict pairs allowed in one table; checked before allocating |
| `maxStringLen` | `20000000` | most bytes allowed in one string |
| `internStrings` | `false` | reserved, does nothing yet |
| `refThreshold` | `2` | reserved, tracking is always on |

If you read data from untrusted clients, turn `strict` on and lower
`maxDepth` and `maxTableSize`.

## Schema evolution

Rules for data you keep (DataStores, files):

- Same fields: old bytes always read back, no matter the order you wrote
  the fields in.
- Adding or removing a field: **breaking**. Added fields usually fail loudly;
  removed fields are silently dropped — unless `strict` is on, which errors
  on trailing bytes.
- Safe habit: store a version next to the payload (for example
  `{v = 2, data = Compressor:ToBase64(...)}`) and convert old versions when
  you load them.

## Limits

- 64-bit integers must be whole numbers within ±2^53 (covers timestamps).
- `Vector3`, `Color3`, `CFrame` and other engine values store float32:
  compare with a small tolerance (~1e-6) rather than `==`.
- `Region3` is a legacy type; it round-trips through center and size.

## Wire format

Version byte `1`, then the payload. Without a schema every value carries a
tag byte:

| Type | Tag | Payload |
|---|---|---|
| `nil` / `true` / `false` | `0x00` / `0x01` / `0x02` | none |
| `number` | `0x03` | float64 |
| `string` | `0x04` | u16 length + bytes (`0xFFFF` + u32 length past 64KB) |
| array / dict | `0x05` / `0x06` | u32 count + items |
| reference | `0x7F` | u32 id of an earlier table |
| Roblox types | `0x10`–`0x23` | fixed layouts per type |
| instance path | `0x26` | path string |
| custom types | `0x30`–`0x7E` | handler-defined |

With a schema the tags are omitted: objects write a presence marker per
field (`0x00` absent, `0x01` present, `0x02` repeat reference) in sorted
field order. `Compressor:ToHex(buf)` prints any buffer as hex while you
debug, and `GetSize(buf)` returns its byte size.
