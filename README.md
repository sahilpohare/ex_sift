# ExSift

MongoDB-style query filtering for Elixir collections.

ExSift is an Elixir library inspired by [sift.js](https://github.com/crcn/sift.js) that brings MongoDB's powerful query syntax to Elixir. Filter lists, maps, and any enumerable with an expressive, familiar query language.

## Features

- **MongoDB-compatible query syntax** - Use the same operators you know from MongoDB
- **Type-safe** - Full Elixir typespecs and pattern matching
- **Comprehensive operators** - Support for comparison, logical, array, and special operators
- **Nested property access** - Query deeply nested maps with dot notation
- **Regex support** - Pattern matching with Elixir's `Regex` module
- **Date/Time support** - Compare `DateTime`, `NaiveDateTime`, and `Date` types
- **Well-tested** - 40+ tests covering all operators and edge cases

## Installation

Add `ex_sift` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_sift, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
data = [
  %{name: "Alice", age: 30, city: "NYC"},
  %{name: "Bob", age: 25, city: "SF"},
  %{name: "Charlie", age: 35, city: "NYC"}
]

# Simple equality
ExSift.filter(data, %{city: "NYC"})
# => [%{name: "Alice", ...}, %{name: "Charlie", ...}]

# Comparison operators
ExSift.filter(data, %{age: %{"$gt" => 28}})
# => [%{name: "Alice", age: 30, ...}, %{name: "Charlie", age: 35, ...}]

# Multiple conditions
ExSift.filter(data, %{city: "NYC", age: %{"$gte" => 30}})
# => [%{name: "Alice", ...}, %{name: "Charlie", ...}]
```

## Supported Operators

### Comparison Operators

- **`$eq`** - Equals (same as direct value)
  ```elixir
  ExSift.filter(data, %{age: %{"$eq" => 30}})
  ```

- **`$ne`** - Not equals
  ```elixir
  ExSift.filter(data, %{city: %{"$ne" => "NYC"}})
  ```

- **`$gt`** - Greater than
  ```elixir
  ExSift.filter(data, %{age: %{"$gt" => 25}})
  ```

- **`$gte`** - Greater than or equal
  ```elixir
  ExSift.filter(data, %{age: %{"$gte" => 30}})
  ```

- **`$lt`** - Less than
  ```elixir
  ExSift.filter(data, %{age: %{"$lt" => 30}})
  ```

- **`$lte`** - Less than or equal
  ```elixir
  ExSift.filter(data, %{age: %{"$lte" => 25}})
  ```

### Logical Operators

- **`$and`** - All conditions must match
  ```elixir
  ExSift.filter(data, %{
    "$and" => [
      %{age: %{"$gte" => 25}},
      %{city: "NYC"}
    ]
  })
  ```

- **`$or`** - At least one condition must match
  ```elixir
  ExSift.filter(data, %{
    "$or" => [
      %{age: %{"$lt" => 26}},
      %{city: "LA"}
    ]
  })
  ```

- **`$nor`** - No conditions match
  ```elixir
  ExSift.filter(data, %{
    "$nor" => [
      %{city: "NYC"},
      %{city: "SF"}
    ]
  })
  ```

- **`$not`** - Negation
  ```elixir
  ExSift.filter(data, %{age: %{"$not" => %{"$lt" => 30}}})
  ```

### Array Operators

- **`$in`** - Value in array
  ```elixir
  ExSift.filter(data, %{city: %{"$in" => ["NYC", "LA", "SF"]}})
  ```

- **`$nin`** - Value not in array
  ```elixir
  ExSift.filter(data, %{city: %{"$nin" => ["NYC"]}})
  ```

- **`$all`** - Array contains all values
  ```elixir
  ExSift.filter(data, %{tags: %{"$all" => ["admin", "user"]}})
  ```

- **`$elemMatch`** - Array element matches query
  ```elixir
  data = [%{items: [%{id: 1, active: true}]}]
  ExSift.filter(data, %{items: %{"$elemMatch" => %{id: 1, active: true}}})
  ```

- **`$size`** - Array has specific length
  ```elixir
  ExSift.filter(data, %{tags: %{"$size" => 3}})
  ```

### Other Operators

- **`$exists`** - Field exists (not nil)
  ```elixir
  ExSift.filter(data, %{email: %{"$exists" => true}})
  ExSift.filter(data, %{phone: %{"$exists" => false}})
  ```

- **`$type`** - Type checking
  ```elixir
  ExSift.filter(data, %{age: %{"$type" => "number"}})
  ExSift.filter(data, %{name: %{"$type" => "string"}})
  # Supported types: "string", "number", "integer", "float",
  #                  "boolean", "map", "list", "atom", "date", "datetime", "nil"
  ```

- **`$mod`** - Modulus operation
  ```elixir
  ExSift.filter(data, %{count: %{"$mod" => [5, 0]}})  # divisible by 5
  ```

- **`$regex`** - Regular expression matching
  ```elixir
  # Using Elixir regex
  ExSift.filter(data, %{name: ~r/^[AB]/})

  # Using $regex operator
  ExSift.filter(data, %{email: %{"$regex" => "@gmail\\.com$"}})
  ```

## Advanced Usage

### Nested Properties

Use dot notation to query nested maps:

```elixir
data = [
  %{user: %{profile: %{age: 30, verified: true}}},
  %{user: %{profile: %{age: 25, verified: false}}}
]

ExSift.filter(data, %{"user.profile.age" => %{"$gt" => 28}})
# => [%{user: %{profile: %{age: 30, ...}}}]
```

### Complex Queries

Combine multiple operators for powerful filtering:

```elixir
data = [
  %{name: "Alice", age: 30, status: "active", tags: ["admin"]},
  %{name: "Bob", age: 25, status: "inactive", tags: ["user"]},
  %{name: "Charlie", age: 35, status: "active", tags: ["admin", "moderator"]}
]

ExSift.filter(data, %{
  "$and" => [
    %{age: %{"$gte" => 25, "$lte" => 35}},
    %{status: "active"},
    %{tags: %{"$in" => ["admin"]}}
  ]
})
# => [%{name: "Alice", ...}, %{name: "Charlie", ...}]
```

### Utility Functions

ExSift provides several utility functions beyond `filter/2`:

```elixir
data = [%{a: 1}, %{a: 2}, %{a: 3}]

# Test a single item
ExSift.test(%{a: 1}, %{a: 1})  # => true

# Find first matching item
ExSift.find(data, %{a: 2})  # => %{a: 2}

# Check if any match
ExSift.any?(data, %{a: %{"$gt" => 2}})  # => true

# Check if all match
ExSift.all?(data, %{a: %{"$gte" => 1}})  # => true

# Count matches
ExSift.count(data, %{a: %{"$lt" => 3}})  # => 2

# Compile query for reuse
tester = ExSift.compile(%{a: %{"$gt" => 1}})
tester.(%{a: 2})  # => true
tester.(%{a: 1})  # => false
```

## Architecture

ExSift is built with three main modules:

- **`ExSift`** - Main API and utility functions
- **`ExSift.Query`** - Query parsing and matching logic
- **`ExSift.Operators`** - Operator implementations

The library leverages Elixir's pattern matching and protocol system for extensible, type-safe query operations.

### Comparison with sift.js

ExSift is inspired by [sift.js](https://github.com/crcn/sift.js) but adapted for Elixir's functional programming paradigm:

| Feature | sift.js | ExSift |
|---------|---------|--------|
| Language | JavaScript/TypeScript | Elixir |
| Architecture | Operation classes with state | Pattern matching + pure functions |
| Extensibility | Custom operations via options | Protocol-based (future) |
| Type Safety | TypeScript generics | Dialyzer typespecs |
| Immutability | Depends on usage | Built-in (Elixir default) |

## Performance

ExSift uses single-pass filtering with early termination where possible. All operations are implemented as pure functions without side effects.

For large datasets, consider:
- Using `ExSift.compile/1` to create reusable query functions
- Leveraging `ExSift.find/2` or `ExSift.any?/2` for early termination
- Pre-filtering with simpler queries before complex ones

## Testing

Run the test suite:

```bash
mix test
```

ExSift includes 40+ tests covering:
- All operators
- Nested property access
- Complex query combinations
- Edge cases and error handling

## License

MIT License - See LICENSE file for details

## Acknowledgments

Inspired by [sift.js](https://github.com/crcn/sift.js) by Craig Condon.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
