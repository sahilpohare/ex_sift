data = [
  %{id: 1, user: %{name: "Alice", profile: %{age: 30, city: "NYC"}}},
  %{id: 2, user: %{name: "Bob", profile: %{age: 25, city: "SF"}}},
  %{id: 3, user: %{name: "Charlie", profile: %{age: 35, city: "NYC"}}}
]

IO.puts("--- Test 1: Dot Notation ---")
# Should match Alice and Charlie
query1 = %{"user.profile.city" => "NYC"}
result1 = ExSift.filter(data, query1)
IO.inspect(result1, label: "Dot Notation Result")

IO.puts("\n--- Test 2: Nested Map (Partial Match) ---")
# Should match Alice and Charlie if partial matching works
# MongoDB would require exact match here, but ExSift might do partial
query2 = %{user: %{profile: %{city: "NYC"}}}
result2 = ExSift.filter(data, query2)
IO.inspect(result2, label: "Nested Map Result")

IO.puts("\n--- Test 3: Nested Map with Operator ---")
# Should match Alice
query3 = %{user: %{profile: %{age: %{"$gt" => 28}}}}
result3 = ExSift.filter(data, query3)
IO.inspect(result3, label: "Nested Map + Operator Result")
