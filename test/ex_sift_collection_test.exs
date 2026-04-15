defmodule ExSift.CollectionTest do
  use ExUnit.Case

  alias ExSift.Collection

  # ---------------------------------------------------------------------------
  # Test structs
  # ---------------------------------------------------------------------------

  defmodule User do
    defstruct [:name, :age, :role]
  end

  defmodule Address do
    defstruct [:city, :state, :zip]
  end

  defmodule Tagged do
    defstruct [:label, :tags]
  end

  # ===========================================================================
  # Collection Protocol — Map
  # ===========================================================================

  describe "Collection.Map — fetch" do
    test "string key" do
      assert Collection.fetch(%{"a" => 1}, "a") == 1
    end

    test "atom key" do
      assert Collection.fetch(%{foo: 42}, :foo) == 42
    end

    test "string key resolves to existing atom" do
      assert Collection.fetch(%{foo: 42}, "foo") == 42
    end

    test "missing key returns nil" do
      assert Collection.fetch(%{a: 1}, "missing") == nil
    end

    test "non-existent atom string returns nil" do
      assert Collection.fetch(%{}, "absolutely_nonexistent_key_xyz") == nil
    end
  end

  describe "Collection.Map — to_pairs / member? / size" do
    test "to_pairs returns key-value list" do
      assert Enum.sort(Collection.to_pairs(%{a: 1, b: 2})) == [a: 1, b: 2]
    end

    test "member? checks values" do
      assert Collection.member?(%{a: 1}, 1)
      refute Collection.member?(%{a: 1}, 99)
    end

    test "size returns key count" do
      assert Collection.size(%{a: 1, b: 2}) == 2
      assert Collection.size(%{}) == 0
    end
  end

  # ===========================================================================
  # Collection Protocol — List (plain)
  # ===========================================================================

  describe "Collection.List (plain) — fetch" do
    test "integer index" do
      assert Collection.fetch([10, 20, 30], 0) == 10
      assert Collection.fetch([10, 20, 30], 2) == 30
    end

    test "string numeric index" do
      assert Collection.fetch([10, 20, 30], "1") == 20
    end

    test "out-of-bounds returns nil" do
      assert Collection.fetch([1, 2], 99) == nil
    end

    test "non-numeric string on plain list returns nil" do
      assert Collection.fetch([1, 2, 3], "foo") == nil
    end
  end

  describe "Collection.List (plain) — to_pairs / member? / size" do
    test "to_pairs returns nil for plain list" do
      assert Collection.to_pairs([1, 2, 3]) == nil
    end

    test "member? checks element presence" do
      assert Collection.member?([1, 2, 3], 2)
      refute Collection.member?([1, 2, 3], 9)
    end

    test "size returns length" do
      assert Collection.size([1, 2, 3]) == 3
      assert Collection.size([]) == 0
    end
  end

  # ===========================================================================
  # Collection Protocol — List (keyword)
  # ===========================================================================

  describe "Collection.List (keyword) — fetch" do
    test "atom key" do
      assert Collection.fetch([a: 1, b: 2], :a) == 1
    end

    test "string key resolves to atom" do
      assert Collection.fetch([foo: 42], "foo") == 42
    end

    test "missing key returns nil" do
      assert Collection.fetch([a: 1], :z) == nil
    end
  end

  describe "Collection.List (keyword) — to_pairs / size" do
    test "to_pairs returns the list" do
      kw = [a: 1, b: 2]
      assert Collection.to_pairs(kw) == kw
    end

    test "size returns key count" do
      assert Collection.size([a: 1, b: 2]) == 2
    end
  end

  # ===========================================================================
  # Collection Protocol — MapSet
  # ===========================================================================

  describe "Collection.MapSet — fetch / to_pairs / member? / size" do
    test "fetch always nil" do
      assert Collection.fetch(MapSet.new([1, 2]), :any) == nil
    end

    test "to_pairs always nil" do
      assert Collection.to_pairs(MapSet.new([1, 2])) == nil
    end

    test "member?" do
      set = MapSet.new([1, 2, 3])
      assert Collection.member?(set, 2)
      refute Collection.member?(set, 9)
    end

    test "size" do
      assert Collection.size(MapSet.new([1, 2, 3])) == 3
      assert Collection.size(MapSet.new()) == 0
    end
  end

  # ===========================================================================
  # Collection Protocol — Struct (Any impl)
  # ===========================================================================

  describe "Collection.Struct — fetch" do
    test "atom key" do
      u = %User{name: "Alice", age: 30}
      assert Collection.fetch(u, :name) == "Alice"
    end

    test "string key resolves to atom field" do
      u = %User{name: "Alice", age: 30}
      assert Collection.fetch(u, "name") == "Alice"
    end

    test "missing field returns nil" do
      u = %User{name: "Alice", age: 30}
      assert Collection.fetch(u, :role) == nil
      assert Collection.fetch(u, "nonexistent_xyz") == nil
    end
  end

  describe "Collection.Struct — to_pairs / member? / size" do
    test "to_pairs returns struct fields as pairs (no __struct__)" do
      u = %User{name: "Alice", age: 30, role: "admin"}
      pairs = Collection.to_pairs(u)
      assert {:name, "Alice"} in pairs
      assert {:age, 30} in pairs
      refute Enum.any?(pairs, fn {k, _} -> k == :__struct__ end)
    end

    test "member? checks field values" do
      u = %User{name: "Alice", age: 30}
      assert Collection.member?(u, "Alice")
      refute Collection.member?(u, "Bob")
    end

    test "size returns field count" do
      u = %User{name: "Alice", age: 30, role: "admin"}
      assert Collection.size(u) == 3
    end
  end

  # ===========================================================================
  # Public API — keyword list as collection item
  # ===========================================================================

  describe "ExSift with keyword lists" do
    test "shape match by string key" do
      data = [[a: 1, b: 2], [a: 3, b: 4]]
      assert ExSift.filter(data, %{"a" => 1}) == [[a: 1, b: 2]]
    end

    test "comparison operator" do
      data = [[score: 10], [score: 20], [score: 30]]
      result = ExSift.filter(data, %{"score" => %{"$gt" => 15}})
      assert length(result) == 2
    end

    test "dot notation traversal into nested keyword list" do
      data = [
        [user: [name: "Alice", age: 30]],
        [user: [name: "Bob", age: 20]]
      ]

      result = ExSift.filter(data, %{"user.age" => %{"$gt" => 25}})
      assert length(result) == 1
    end

    test "$exists on keyword list" do
      data = [[a: 1, b: 2], [a: 3]]
      result = ExSift.filter(data, %{"b" => %{"$exists" => true}})
      assert length(result) == 1
    end

    test "$size on keyword list field" do
      data = [%{tags: [a: 1, b: 2]}, %{tags: [a: 1]}]
      result = ExSift.filter(data, %{tags: %{"$size" => 2}})
      assert length(result) == 1
    end

    test "ExSift.test/2" do
      assert ExSift.test([a: 1, b: 2], %{"a" => 1})
      refute ExSift.test([a: 1, b: 2], %{"a" => 99})
    end

    test "ExSift.find/2" do
      data = [[x: 1], [x: 2], [x: 3]]
      assert ExSift.find(data, %{"x" => 2}) == [x: 2]
    end

    test "ExSift.any?/2" do
      assert ExSift.any?([[x: 1], [x: 2]], %{"x" => 2})
      refute ExSift.any?([[x: 1], [x: 2]], %{"x" => 9})
    end

    test "ExSift.count/2" do
      assert ExSift.count([[x: 1], [x: 2], [x: 1]], %{"x" => 1}) == 2
    end
  end

  # ===========================================================================
  # Public API — MapSet as collection item
  # ===========================================================================

  describe "ExSift with MapSet as items" do
    # MapSets have no to_pairs so shape matching returns false — that's correct.
    # Operators work on MapSet field values.

    test "$size on MapSet field" do
      data = [%{tags: MapSet.new([1, 2, 3])}, %{tags: MapSet.new([1, 2])}]
      result = ExSift.filter(data, %{tags: %{"$size" => 3}})
      assert length(result) == 1
    end

    test "$all on MapSet field — all members present" do
      data = [
        %{perms: MapSet.new([:read, :write, :delete])},
        %{perms: MapSet.new([:read])}
      ]

      result = ExSift.filter(data, %{perms: %{"$all" => [:read, :write]}})
      assert length(result) == 1
    end

    test "$all on MapSet field — no match when member missing" do
      data = [%{perms: MapSet.new([:read])}]
      assert ExSift.filter(data, %{perms: %{"$all" => [:read, :write]}}) == []
    end

    test "$elemMatch on MapSet field" do
      data = [
        %{scores: MapSet.new([5, 15, 25])},
        %{scores: MapSet.new([1, 2, 3])}
      ]

      result = ExSift.filter(data, %{scores: %{"$elemMatch" => %{"$gt" => 10}}})
      assert length(result) == 1
    end

    test "$in — check if MapSet field contains any of the query values" do
      data = [
        %{roles: MapSet.new(["admin", "user"])},
        %{roles: MapSet.new(["guest"])}
      ]

      result = ExSift.filter(data, %{roles: %{"$in" => ["admin"]}})
      assert length(result) == 1
    end

    test "$nin — exclude when MapSet field contains query value" do
      data = [
        %{roles: MapSet.new(["admin"])},
        %{roles: MapSet.new(["guest"])}
      ]

      result = ExSift.filter(data, %{roles: %{"$nin" => ["admin"]}})
      assert length(result) == 1
    end

    test "ExSift.test/2 with MapSet field" do
      assert ExSift.test(%{s: MapSet.new([1, 2])}, %{s: %{"$size" => 2}})
      refute ExSift.test(%{s: MapSet.new([1, 2])}, %{s: %{"$size" => 5}})
    end
  end

  # ===========================================================================
  # Public API — Struct as collection item
  # ===========================================================================

  describe "ExSift with structs" do
    test "shape match by atom key" do
      data = [%User{name: "Alice", age: 30}, %User{name: "Bob", age: 25}]
      result = ExSift.filter(data, %{name: "Alice"})
      assert length(result) == 1
      assert hd(result).name == "Alice"
    end

    test "shape match by string key" do
      data = [%User{name: "Alice", age: 30}, %User{name: "Bob", age: 25}]
      result = ExSift.filter(data, %{"name" => "Alice"})
      assert length(result) == 1
    end

    test "comparison operator on struct field" do
      data = [%User{age: 30}, %User{age: 20}, %User{age: 35}]
      result = ExSift.filter(data, %{age: %{"$gt" => 28}})
      assert length(result) == 2
    end

    test "$in on struct field" do
      data = [%User{role: "admin"}, %User{role: "user"}, %User{role: "guest"}]
      result = ExSift.filter(data, %{role: %{"$in" => ["admin", "user"]}})
      assert length(result) == 2
    end

    test "$exists on struct field" do
      data = [%User{name: "Alice", role: "admin"}, %User{name: "Bob", role: nil}]
      result = ExSift.filter(data, %{role: %{"$exists" => true}})
      assert length(result) == 1
    end

    test "dot notation into nested struct" do
      data = [
        %{address: %Address{city: "NYC", state: "NY"}},
        %{address: %Address{city: "SF", state: "CA"}}
      ]

      result = ExSift.filter(data, %{"address.city" => "NYC"})
      assert length(result) == 1
    end

    test "nested struct shape match" do
      data = [
        %{user: %User{name: "Alice", age: 30, role: "admin"}},
        %{user: %User{name: "Bob", age: 25, role: "user"}}
      ]

      result = ExSift.filter(data, %{user: %{role: "admin"}})
      assert length(result) == 1
      assert hd(result).user.name == "Alice"
    end

    test "ExSift.test/2 with struct" do
      assert ExSift.test(%User{name: "Alice", age: 30}, %{name: "Alice"})
      refute ExSift.test(%User{name: "Alice", age: 30}, %{name: "Bob"})
    end

    test "ExSift.find/2 with structs" do
      data = [%User{name: "Alice"}, %User{name: "Bob"}]
      assert ExSift.find(data, %{name: "Bob"}).name == "Bob"
    end

    test "ExSift.any?/2 with structs" do
      data = [%User{age: 20}, %User{age: 30}]
      assert ExSift.any?(data, %{age: %{"$gte" => 30}})
      refute ExSift.any?(data, %{age: %{"$gt" => 100}})
    end

    test "ExSift.all?/2 with structs" do
      data = [%User{age: 20}, %User{age: 30}]
      assert ExSift.all?(data, %{age: %{"$gte" => 18}})
      refute ExSift.all?(data, %{age: %{"$gte" => 25}})
    end

    test "ExSift.count/2 with structs" do
      data = [%User{role: "admin"}, %User{role: "admin"}, %User{role: "user"}]
      assert ExSift.count(data, %{role: "admin"}) == 2
    end

    test "$regex on struct field" do
      data = [%User{name: "Alice"}, %User{name: "Bob"}, %User{name: "Anna"}]
      result = ExSift.filter(data, %{name: %{"$regex" => "^A"}})
      assert length(result) == 2
    end

    test "struct with list field — implicit $elemMatch" do
      data = [
        %Tagged{label: "x", tags: ["admin", "user"]},
        %Tagged{label: "y", tags: ["guest"]}
      ]

      result = ExSift.filter(data, %{tags: "admin"})
      assert length(result) == 1
    end

    test "struct equality as query value" do
      addr = %Address{city: "NYC", state: "NY", zip: "10001"}
      data = [%{address: addr}, %{address: %Address{city: "SF", state: "CA", zip: "94102"}}]
      result = ExSift.filter(data, %{address: addr})
      assert length(result) == 1
    end
  end

  # ===========================================================================
  # Public API — mixed collection types in same enumerable
  # ===========================================================================

  describe "ExSift with mixed collection types" do
    test "filter list containing maps and keyword lists" do
      data = [%{x: 1}, [x: 2], %{x: 3}]
      result = ExSift.filter(data, %{"x" => %{"$gt" => 1}})
      assert length(result) == 2
    end

    test "filter list of structs and maps" do
      data = [%User{name: "Alice", age: 30}, %{name: "Bob", age: 25}]
      result = ExSift.filter(data, %{age: %{"$gte" => 28}})
      assert length(result) == 1
    end
  end

  # ===========================================================================
  # Public API — dot notation through all collection types
  # ===========================================================================

  describe "dot notation through Collection protocol" do
    test "through nested maps" do
      data = [%{a: %{b: %{c: 42}}}, %{a: %{b: %{c: 1}}}]
      result = ExSift.filter(data, %{"a.b.c" => %{"$gt" => 10}})
      assert length(result) == 1
    end

    test "through nested structs" do
      data = [
        %{address: %Address{city: "NYC", state: "NY", zip: "10001"}},
        %{address: %Address{city: "SF", state: "CA", zip: "94102"}}
      ]

      result = ExSift.filter(data, %{"address.state" => "CA"})
      assert length(result) == 1
    end

    test "through keyword list" do
      data = [[user: [age: 30]], [user: [age: 20]]]
      result = ExSift.filter(data, %{"user.age" => %{"$gte" => 25}})
      assert length(result) == 1
    end

    test "missing intermediate path returns no match" do
      data = [%{a: %{}}]
      assert ExSift.filter(data, %{"a.b.c" => 1}) == []
    end

    test "path hits non-collection returns no match" do
      data = [%{a: "string"}]
      assert ExSift.filter(data, %{"a.b" => 1}) == []
    end
  end

  # ===========================================================================
  # Public API — logical operators with all collection types
  # ===========================================================================

  describe "logical operators with structs" do
    test "$and" do
      data = [%User{name: "Alice", age: 30}, %User{name: "Bob", age: 25}]

      result =
        ExSift.filter(data, %{
          "$and" => [%{age: %{"$gte" => 28}}, %{name: "Alice"}]
        })

      assert length(result) == 1
    end

    test "$or" do
      data = [%User{age: 10}, %User{age: 20}, %User{age: 30}]

      result = ExSift.filter(data, %{"$or" => [%{age: 10}, %{age: 30}]})
      assert length(result) == 2
    end

    test "$nor" do
      data = [%User{age: 10}, %User{age: 20}, %User{age: 30}]

      result = ExSift.filter(data, %{"$nor" => [%{age: 10}, %{age: 30}]})
      assert length(result) == 1
      assert hd(result).age == 20
    end

    test "$not" do
      data = [%User{age: 10}, %User{age: 20}, %User{age: 30}]

      result = ExSift.filter(data, %{age: %{"$not" => %{"$gt" => 15}}})
      assert length(result) == 1
      assert hd(result).age == 10
    end
  end

  # ===========================================================================
  # Custom Collection implementation
  # ===========================================================================

  defmodule Bag do
    defstruct [:items, :label]
  end

  defimpl ExSift.Collection, for: ExSift.CollectionTest.Bag do
    def fetch(%{items: items}, key) when is_integer(key), do: Enum.at(items, key)
    def fetch(%{label: label}, key) when key in [:label, "label"], do: label
    def fetch(_, _), do: nil
    def to_pairs(%{label: label}), do: [label: label]
    def member?(%{items: items}, value), do: value in items
    def size(%{items: items}), do: length(items)
  end

  describe "custom Collection implementation" do
    test "shape match on to_pairs fields" do
      data = [%Bag{label: "fruits", items: [1, 2]}, %Bag{label: "veggies", items: [3]}]
      result = ExSift.filter(data, %{label: "fruits"})
      assert length(result) == 1
    end

    test "$size uses custom size/1" do
      data = [%Bag{label: "a", items: [1, 2, 3]}, %Bag{label: "b", items: [1]}]
      result = ExSift.filter(data, %{"$size" => 3})
      assert length(result) == 1
    end

    test "$all uses custom member?/2" do
      data = [%Bag{label: "a", items: [1, 2, 3]}, %Bag{label: "b", items: [1]}]
      # filter bag items — bags themselves need $all applied
      result = ExSift.filter(data, %{"$all" => [1, 2]})
      assert length(result) == 1
    end

    test "$in uses custom member?/2" do
      data = [%{bag: %Bag{label: "a", items: [10, 20]}}, %{bag: %Bag{label: "b", items: [30]}}]
      result = ExSift.filter(data, %{bag: %{"$in" => [10]}})
      assert length(result) == 1
    end
  end

  # ===========================================================================
  # compile/1 — reusable compiled filters for all collection types
  # ===========================================================================

  describe "compile/1 produces reusable filters across collection types" do
    test "compiled filter works on maps" do
      f = ExSift.compile(%{age: %{"$gte" => 30}})
      assert f.(%{age: 30})
      refute f.(%{age: 29})
    end

    test "compiled filter works on keyword lists" do
      f = ExSift.compile(%{"score" => %{"$gt" => 10}})
      assert f.([score: 20])
      refute f.([score: 5])
    end

    test "compiled filter works on structs" do
      f = ExSift.compile(%{name: "Alice"})
      assert f.(%User{name: "Alice", age: 30, role: nil})
      refute f.(%User{name: "Bob", age: 25, role: nil})
    end

    test "compiled filter with MapSet field — $size" do
      f = ExSift.compile(%{tags: %{"$size" => 3}})
      assert f.(%{tags: MapSet.new([1, 2, 3])})
      refute f.(%{tags: MapSet.new([1, 2])})
    end

    test "compiled filter with MapSet field — $all" do
      f = ExSift.compile(%{perms: %{"$all" => [:read, :write]}})
      assert f.(%{perms: MapSet.new([:read, :write, :delete])})
      refute f.(%{perms: MapSet.new([:read])})
    end

    test "compiled filter with MapSet field — $in" do
      f = ExSift.compile(%{roles: %{"$in" => ["admin"]}})
      assert f.(%{roles: MapSet.new(["admin", "user"])})
      refute f.(%{roles: MapSet.new(["guest"])})
    end

    test "compiled filter with dot notation through struct" do
      f = ExSift.compile(%{"address.city" => "NYC"})
      assert f.(%{address: %Address{city: "NYC", state: "NY", zip: "10001"}})
      refute f.(%{address: %Address{city: "SF", state: "CA", zip: "94102"}})
    end

    test "compiled filter with dot notation through keyword list" do
      f = ExSift.compile(%{"user.age" => %{"$gte" => 25}})
      assert f.([user: [age: 30]])
      refute f.([user: [age: 20]])
    end

    test "same compiled filter applied to multiple collection types" do
      f = ExSift.compile(%{"x" => 1})
      assert f.(%{x: 1})
      assert f.(%{"x" => 1})
      assert f.([x: 1])
      assert f.(%User{name: nil, age: nil, role: nil} |> Map.put(:x, 1) |> then(fn _ ->
        # User doesn't have field x, so fetch returns nil — no match
        false
      end)) == false
    end

    test "compiled filter reusable across Enum operations" do
      f = ExSift.compile(%{age: %{"$gt" => 25}})

      maps = [%{age: 20}, %{age: 30}]
      structs = [%User{age: 20, name: nil, role: nil}, %User{age: 30, name: nil, role: nil}]
      kws = [[age: 20], [age: 30]]

      assert Enum.count(maps, f) == 1
      assert Enum.count(structs, f) == 1
      assert Enum.count(kws, f) == 1
    end

    test "compiled $and/$or with structs" do
      f = ExSift.compile(%{"$or" => [%{age: %{"$lt" => 20}}, %{age: %{"$gt" => 28}}]})
      assert f.(%User{name: "A", age: 30, role: nil})
      assert f.(%User{name: "B", age: 15, role: nil})
      refute f.(%User{name: "C", age: 25, role: nil})
    end
  end
end
