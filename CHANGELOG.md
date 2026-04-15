# Changelog

## 0.2.0 (2026-04-16)

### Breaking Changes

None. Fully backwards-compatible with 0.1.0.

### New Features

#### Universal Collection Protocol (`ExSift.Collection`)

ExSift now works on any Elixir data type, not just plain maps.

**Keyword lists**
```elixir
ExSift.filter([[name: "Alice", age: 30], [name: "Bob", age: 25]], %{"age" => %{"$gt" => 28}})
# => [[name: "Alice", age: 30]]
```

**MapSet fields** — `$size`, `$all`, `$in`, `$elemMatch` all work on MapSet values:
```elixir
data = [
  %{perms: MapSet.new([:read, :write, :delete])},
  %{perms: MapSet.new([:read])}
]
ExSift.filter(data, %{perms: %{"$all" => [:read, :write]}})
# => [%{perms: #MapSet<[:delete, :read, :write]>}]
```

**Structs** — shape matching, dot notation, and all operators work on any struct:
```elixir
defmodule User, do: defstruct [:name, :age, :role]

data = [%User{name: "Alice", age: 30, role: "admin"}, %User{name: "Bob", age: 25, role: "user"}]
ExSift.filter(data, %{age: %{"$gte" => 28}})
# => [%User{name: "Alice", age: 30, role: "admin"}]
```

**Dot notation through nested structs:**
```elixir
ExSift.filter(data, %{"address.city" => "NYC"})
```

**Custom types** — implement `ExSift.Collection` for any type:
```elixir
defimpl ExSift.Collection, for: MyCollection do
  def fetch(c, key), do: ...
  def to_pairs(c), do: ...
  def member?(c, value), do: ...
  def size(c), do: ...
end
```

#### Compiled filters work across all types

`ExSift.compile/1` returns a reusable function that works on any collection type — useful with `Enum.filter/2`, `Enum.count/2`, etc.:

```elixir
active = ExSift.compile(%{status: "active"})

Enum.filter(maps, active)
Enum.filter(structs, active)
Enum.filter(keyword_lists, active)
```

### Fixes

- `equals?/2` — structs now compare by field equality without requiring `Enumerable`
- `$elemMatch` — correctly handles MapSet fields
- `$in` / `$nin` — correctly checks membership when field value is a MapSet or custom struct
- Struct query values (e.g. `%{address: %MyStruct{...}}`) now use equality comparison instead of incorrectly triggering shape matching

### Internal

- `Compiler` path traversal and shape matching now delegate to the `Collection` protocol instead of hardcoding `is_map`/`Map.get`
- Protocol consolidation disabled in test env (`consolidate_protocols: Mix.env() != :test`)

---

## 0.1.0 (2024-11-23)

Initial release. MongoDB-style query filtering for Elixir maps with support for `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`, `$in`, `$nin`, `$all`, `$size`, `$elemMatch`, `$exists`, `$type`, `$mod`, `$regex`, `$and`, `$or`, `$nor`, `$not`.
