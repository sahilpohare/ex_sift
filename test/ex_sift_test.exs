defmodule ExSiftTest do
  use ExUnit.Case
  doctest ExSift

  @sample_data [
    %{name: "Alice", age: 30, city: "NYC", tags: ["admin", "user"]},
    %{name: "Bob", age: 25, city: "SF", tags: ["user"]},
    %{name: "Charlie", age: 35, city: "NYC", tags: ["admin", "moderator"]},
    %{name: "Diana", age: 28, city: "LA", tags: ["user", "moderator"]}
  ]

  describe "basic filtering" do
    test "filters by exact match" do
      result = ExSift.filter(@sample_data, %{city: "NYC"})
      assert length(result) == 2
      assert Enum.all?(result, &(&1.city == "NYC"))
    end

    test "filters by multiple fields" do
      result = ExSift.filter(@sample_data, %{city: "NYC", age: 30})
      assert length(result) == 1
      assert hd(result).name == "Alice"
    end

    test "returns empty list when no match" do
      result = ExSift.filter(@sample_data, %{city: "Tokyo"})
      assert result == []
    end
  end

  describe "comparison operators" do
    test "$eq operator" do
      result = ExSift.filter(@sample_data, %{age: %{"$eq" => 30}})
      assert length(result) == 1
      assert hd(result).name == "Alice"
    end

    test "$ne operator" do
      result = ExSift.filter(@sample_data, %{city: %{"$ne" => "NYC"}})
      assert length(result) == 2
      assert Enum.all?(result, &(&1.city != "NYC"))
    end

    test "$gt operator" do
      result = ExSift.filter(@sample_data, %{age: %{"$gt" => 28}})
      assert length(result) == 2
      assert Enum.all?(result, &(&1.age > 28))
    end

    test "$gte operator" do
      result = ExSift.filter(@sample_data, %{age: %{"$gte" => 30}})
      assert length(result) == 2
      assert Enum.all?(result, &(&1.age >= 30))
    end

    test "$lt operator" do
      result = ExSift.filter(@sample_data, %{age: %{"$lt" => 30}})
      assert length(result) == 2
      assert Enum.all?(result, &(&1.age < 30))
    end

    test "$lte operator" do
      result = ExSift.filter(@sample_data, %{age: %{"$lte" => 28}})
      assert length(result) == 2
      assert Enum.all?(result, &(&1.age <= 28))
    end
  end

  describe "array operators" do
    test "$in operator" do
      result = ExSift.filter(@sample_data, %{city: %{"$in" => ["NYC", "LA"]}})
      assert length(result) == 3
    end

    test "$nin operator" do
      result = ExSift.filter(@sample_data, %{city: %{"$nin" => ["NYC", "LA"]}})
      assert length(result) == 1
      assert hd(result).city == "SF"
    end

    test "$all operator with arrays" do
      result = ExSift.filter(@sample_data, %{tags: %{"$all" => ["admin", "user"]}})
      assert length(result) == 1
      assert hd(result).name == "Alice"
    end

    test "$size operator" do
      result = ExSift.filter(@sample_data, %{tags: %{"$size" => 1}})
      assert length(result) == 1
      assert hd(result).name == "Bob"
    end

    test "$elemMatch operator" do
      data = [
        %{items: [%{id: 1, status: "active"}, %{id: 2, status: "inactive"}]},
        %{items: [%{id: 3, status: "active"}]},
        %{items: [%{id: 4, status: "inactive"}]}
      ]

      result = ExSift.filter(data, %{items: %{"$elemMatch" => %{id: 1, status: "active"}}})
      assert length(result) == 1
    end
  end

  describe "logical operators" do
    test "$and operator" do
      result =
        ExSift.filter(@sample_data, %{
          "$and" => [
            %{age: %{"$gte" => 28}},
            %{city: "NYC"}
          ]
        })

      assert length(result) == 2
      assert Enum.all?(result, &(&1.age >= 28 and &1.city == "NYC"))
    end

    test "$or operator" do
      result =
        ExSift.filter(@sample_data, %{
          "$or" => [
            %{age: %{"$lt" => 26}},
            %{city: "LA"}
          ]
        })

      assert length(result) == 2
    end

    test "$nor operator" do
      result =
        ExSift.filter(@sample_data, %{
          "$nor" => [
            %{city: "NYC"},
            %{city: "SF"}
          ]
        })

      assert length(result) == 1
      assert hd(result).city == "LA"
    end

    test "$not operator" do
      result = ExSift.filter(@sample_data, %{age: %{"$not" => %{"$lt" => 30}}})
      assert length(result) == 2
      assert Enum.all?(result, &(&1.age >= 30))
    end
  end

  describe "other operators" do
    test "$exists operator - true" do
      data = [
        %{name: "Alice", age: 30},
        %{name: "Bob"},
        %{name: "Charlie", age: 35}
      ]

      result = ExSift.filter(data, %{age: %{"$exists" => true}})
      assert length(result) == 2
    end

    test "$exists operator - false" do
      data = [
        %{name: "Alice", age: 30},
        %{name: "Bob"},
        %{name: "Charlie", age: 35}
      ]

      result = ExSift.filter(data, %{age: %{"$exists" => false}})
      assert length(result) == 1
      assert hd(result).name == "Bob"
    end

    test "$type operator" do
      data = [
        %{value: "hello"},
        %{value: 123},
        %{value: true},
        %{value: [1, 2, 3]}
      ]

      result = ExSift.filter(data, %{value: %{"$type" => "string"}})
      assert length(result) == 1

      result = ExSift.filter(data, %{value: %{"$type" => "number"}})
      assert length(result) == 1

      result = ExSift.filter(data, %{value: %{"$type" => "list"}})
      assert length(result) == 1
    end

    test "$mod operator" do
      data = [
        %{count: 10},
        %{count: 15},
        %{count: 20},
        %{count: 25}
      ]

      result = ExSift.filter(data, %{count: %{"$mod" => [5, 0]}})
      assert length(result) == 4

      result = ExSift.filter(data, %{count: %{"$mod" => [10, 0]}})
      assert length(result) == 2
    end

    test "$regex operator with Regex" do
      result = ExSift.filter(@sample_data, %{name: ~r/^[AB]/})
      assert length(result) == 2
      assert Enum.all?(result, &String.starts_with?(&1.name, ["A", "B"]))
    end

    test "$regex operator with string pattern" do
      result = ExSift.filter(@sample_data, %{name: %{"$regex" => "^[CD]"}})
      assert length(result) == 2
    end
  end

  describe "nested property queries" do
    test "dot notation for nested properties" do
      data = [
        %{user: %{name: "Alice", profile: %{age: 30}}},
        %{user: %{name: "Bob", profile: %{age: 25}}},
        %{user: %{name: "Charlie", profile: %{age: 35}}}
      ]

      result = ExSift.filter(data, %{"user.profile.age" => %{"$gt" => 28}})
      assert length(result) == 2
    end

    test "nested map queries" do
      data = [
        %{address: %{city: "NYC", state: "NY"}},
        %{address: %{city: "SF", state: "CA"}},
        %{address: %{city: "LA", state: "CA"}}
      ]

      result = ExSift.filter(data, %{address: %{state: "CA"}})
      assert length(result) == 2
    end

    test "nested map partial matching (implicit)" do
      data = [
        %{user: %{name: "Alice", profile: %{age: 30, city: "NYC"}}},
        %{user: %{name: "Bob", profile: %{age: 25, city: "SF"}}}
      ]

      # Should match even though profile has 'age' as well
      result = ExSift.filter(data, %{user: %{profile: %{city: "NYC"}}})
      assert length(result) == 1
      assert hd(result).user.name == "Alice"
    end

    test "nested map with operators" do
      data = [
        %{meta: %{score: 10, tags: ["a"]}},
        %{meta: %{score: 20, tags: ["b"]}}
      ]

      result = ExSift.filter(data, %{meta: %{score: %{"$gt" => 15}}})
      assert length(result) == 1
      assert hd(result).meta.score == 20
    end
  end

  describe "utility functions" do
    test "test/2 checks if single item matches" do
      assert ExSift.test(%{age: 30}, %{age: 30})
      refute ExSift.test(%{age: 25}, %{age: 30})
    end

    test "find/2 returns first matching item" do
      result = ExSift.find(@sample_data, %{city: "NYC"})
      assert result.name == "Alice"
    end

    test "find/2 returns nil when no match" do
      result = ExSift.find(@sample_data, %{city: "Tokyo"})
      assert is_nil(result)
    end

    test "any?/2 returns true if any match" do
      assert ExSift.any?(@sample_data, %{city: "NYC"})
      refute ExSift.any?(@sample_data, %{city: "Tokyo"})
    end

    test "all?/2 returns true if all match" do
      assert ExSift.all?(@sample_data, %{age: %{"$gte" => 25}})
      refute ExSift.all?(@sample_data, %{city: "NYC"})
    end

    test "count/2 returns number of matches" do
      assert ExSift.count(@sample_data, %{city: "NYC"}) == 2
      assert ExSift.count(@sample_data, %{age: %{"$lt" => 30}}) == 2
    end

    test "compile/1 creates a reusable tester function" do
      tester = ExSift.compile(%{age: %{"$gt" => 28}})

      assert is_function(tester)
      assert tester.(%{age: 30})
      refute tester.(%{age: 25})
    end
  end

  describe "complex queries" do
    test "combining multiple operators" do
      result =
        ExSift.filter(@sample_data, %{
          age: %{"$gte" => 25, "$lte" => 30},
          city: %{"$in" => ["NYC", "SF"]}
        })

      assert length(result) == 2
    end

    test "nested logical operators" do
      result =
        ExSift.filter(@sample_data, %{
          "$or" => [
            %{"$and" => [%{age: %{"$lt" => 30}}, %{city: "SF"}]},
            %{"$and" => [%{age: %{"$gte" => 30}}, %{city: "NYC"}]}
          ]
        })

      assert length(result) == 3
    end

    test "array field matching with $in" do
      result = ExSift.filter(@sample_data, %{tags: %{"$in" => ["admin"]}})
      assert length(result) == 2
      assert Enum.all?(result, &("admin" in &1.tags))
    end
  end

  describe "edge cases" do
    test "empty query matches all" do
      result = ExSift.filter(@sample_data, %{})
      assert length(result) == 4
    end

    test "query with nil values" do
      data = [
        %{name: "Alice", age: nil},
        %{name: "Bob", age: 25}
      ]

      result = ExSift.filter(data, %{age: nil})
      assert length(result) == 1
      assert hd(result).name == "Alice"
    end

    test "works with atom keys" do
      result = ExSift.filter(@sample_data, %{name: "Alice"})
      assert length(result) == 1
    end

    test "handles empty arrays" do
      data = [
        %{items: []},
        %{items: [1, 2, 3]}
      ]

      result = ExSift.filter(data, %{items: %{"$size" => 0}})
      assert length(result) == 1
    end
  end
end
