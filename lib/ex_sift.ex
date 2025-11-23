defmodule ExSift do
  @moduledoc """
  MongoDB-style query filtering for Elixir collections.

  ExSift allows you to filter Elixir enumerables using MongoDB-like query syntax.

  ## Examples

      # Simple filtering
      ExSift.filter([%{name: "Alice", age: 30}, %{name: "Bob", age: 25}], %{name: "Alice"})
      # => [%{name: "Alice", age: 30}]

      # Using operators
      ExSift.filter([%{age: 30}, %{age: 25}], %{age: %{"$gt" => 28}})
      # => [%{age: 30}]

  ## Supported Operators

  ### Comparison Operators
  - `$eq` - Equals
  - `$ne` - Not equals
  - `$gt` - Greater than
  - `$gte` - Greater than or equal
  - `$lt` - Less than
  - `$lte` - Less than or equal

  ### Logical Operators
  - `$and` - All conditions must match
  - `$or` - At least one condition must match
  - `$nor` - No conditions match
  - `$not` - Negation

  ### Array Operators
  - `$in` - Value in array
  - `$nin` - Value not in array
  - `$all` - Array contains all values
  - `$elemMatch` - Array element matches query
  - `$size` - Array has specific length

  ### Other Operators
  - `$exists` - Field exists
  - `$regex` - Regular expression match
  - `$type` - Type checking
  - `$mod` - Modulus operation
  """

  @doc """
  Filters an enumerable based on a MongoDB-style query.

  Returns a list of items that match the query.

  ## Examples

      iex> ExSift.filter([%{a: 1}, %{a: 2}], %{a: 1})
      [%{a: 1}]

      iex> ExSift.filter([%{a: 1}, %{a: 2}], %{a: %{"$gt" => 1}})
      [%{a: 2}]
  """
  def filter(enumerable, query) do
    tester = compile(query)
    Enum.filter(enumerable, tester)
  end

  @doc """
  Compiles a query into a testing function.

  Returns a function that takes an item and returns true if it matches the query.

  ## Examples

      iex> tester = ExSift.compile(%{age: %{"$gt" => 25}})
      iex> tester.(%{age: 30})
      true
      iex> tester.(%{age: 20})
      false
  """
  def compile(query) do
    ExSift.Compiler.compile(query)
  end

  @doc """
  Tests if a single item matches a query.

  ## Examples

      iex> ExSift.test(%{name: "Alice", age: 30}, %{age: 30})
      true

      iex> ExSift.test(%{name: "Bob", age: 25}, %{age: %{"$gte" => 30}})
      false
  """
  def test(item, query) do
    tester = compile(query)
    tester.(item)
  end

  @doc """
  Returns the first item that matches the query, or nil.

  ## Examples

      iex> ExSift.find([%{a: 1}, %{a: 2}], %{a: 2})
      %{a: 2}

      iex> ExSift.find([%{a: 1}, %{a: 2}], %{a: 3})
      nil
  """
  def find(enumerable, query) do
    tester = compile(query)
    Enum.find(enumerable, tester)
  end

  @doc """
  Returns true if any item matches the query.

  ## Examples

      iex> ExSift.any?([%{a: 1}, %{a: 2}], %{a: 2})
      true

      iex> ExSift.any?([%{a: 1}, %{a: 2}], %{a: 3})
      false
  """
  def any?(enumerable, query) do
    tester = compile(query)
    Enum.any?(enumerable, tester)
  end

  @doc """
  Returns true if all items match the query.

  ## Examples

      iex> ExSift.all?([%{a: 1}, %{a: 2}], %{a: %{"$gte" => 1}})
      true

      iex> ExSift.all?([%{a: 1}, %{a: 2}], %{a: 1})
      false
  """
  def all?(enumerable, query) do
    tester = compile(query)
    Enum.all?(enumerable, tester)
  end

  @doc """
  Counts the number of items that match the query.

  ## Examples

      iex> ExSift.count([%{a: 1}, %{a: 2}, %{a: 1}], %{a: 1})
      2
  """
  def count(enumerable, query) do
    tester = compile(query)
    Enum.count(enumerable, tester)
  end
end
