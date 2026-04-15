defmodule ExSift.Operators do
  @moduledoc """
  Implementation of MongoDB-style query operators.

  This module provides the low-level implementation for all supported operators.
  These functions are typically not called directly but are used by the
  `ExSift.Compiler` to build matcher functions.

  ## Categories

  - **Comparison**: `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`
  - **Logical**: `$and`, `$or`, `$nor`, `$not`
  - **Array**: `$in`, `$nin`, `$all`, `$size`, `$elemMatch`
  - **Element**: `$exists`, `$type`
  - **Evaluation**: `$mod`, `$regex`
  """

  alias ExSift.{Collection, Query}

  # ============================================================================
  # Comparison Operators
  # ============================================================================

  @doc """
  Equality comparison.

  Supports deep comparison for maps and lists.
  """
  def equals?(value, value), do: true
  def equals?(nil, _), do: false
  def equals?(_, nil), do: false

  # Compare lists
  def equals?(a, b) when is_list(a) and is_list(b) do
    length(a) == length(b) and
      Enum.zip(a, b) |> Enum.all?(fn {x, y} -> equals?(x, y) end)
  end

  # Compare DateTime/NaiveDateTime
  def equals?(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) == :eq
  def equals?(%NaiveDateTime{} = a, %NaiveDateTime{} = b), do: NaiveDateTime.compare(a, b) == :eq

  # Compare Date
  def equals?(%Date{} = a, %Date{} = b), do: Date.compare(a, b) == :eq

  # Compare Regex (matches against strings)
  def equals?(value, %Regex{} = regex) when is_binary(value), do: Regex.match?(regex, value)

  # Non-string value against Regex never matches
  def equals?(_, %Regex{}), do: false

  # Compare structs (must be same type, then compare fields recursively)
  def equals?(%t{} = a, %t{} = b) do
    a_fields = Map.from_struct(a)
    b_fields = Map.from_struct(b)

    map_size(a_fields) == map_size(b_fields) and
      Enum.all?(a_fields, fn {key, val} ->
        Map.has_key?(b_fields, key) and equals?(val, Map.get(b_fields, key))
      end)
  end

  # Structs of different types are never equal; struct vs non-struct
  def equals?(%_{}, %_{}), do: false
  def equals?(%_{}, _), do: false
  def equals?(_, %_{}), do: false

  # Compare plain maps
  def equals?(a, b) when is_map(a) and is_map(b) do
    map_size(a) == map_size(b) and
      Enum.all?(a, fn {key, val} ->
        Map.has_key?(b, key) and equals?(val, Map.get(b, key))
      end)
  end

  # Default comparison
  def equals?(a, b), do: a == b

  @doc "Not equals comparison."
  def not_equals?(value, param), do: not equals?(value, param)

  @doc "Greater than comparison."
  def greater_than?(value, param) when is_number(value) and is_number(param), do: value > param
  def greater_than?(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) == :gt

  def greater_than?(%NaiveDateTime{} = a, %NaiveDateTime{} = b),
    do: NaiveDateTime.compare(a, b) == :gt

  def greater_than?(%Date{} = a, %Date{} = b), do: Date.compare(a, b) == :gt
  def greater_than?(value, param) when is_binary(value) and is_binary(param), do: value > param
  def greater_than?(_, _), do: false

  @doc "Greater than or equal comparison."
  def greater_than_or_equal?(value, param) when is_number(value) and is_number(param),
    do: value >= param

  def greater_than_or_equal?(%DateTime{} = a, %DateTime{} = b),
    do: DateTime.compare(a, b) in [:gt, :eq]

  def greater_than_or_equal?(%NaiveDateTime{} = a, %NaiveDateTime{} = b),
    do: NaiveDateTime.compare(a, b) in [:gt, :eq]

  def greater_than_or_equal?(%Date{} = a, %Date{} = b), do: Date.compare(a, b) in [:gt, :eq]

  def greater_than_or_equal?(value, param) when is_binary(value) and is_binary(param),
    do: value >= param

  def greater_than_or_equal?(_, _), do: false

  @doc "Less than comparison."
  def less_than?(value, param) when is_number(value) and is_number(param), do: value < param
  def less_than?(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) == :lt

  def less_than?(%NaiveDateTime{} = a, %NaiveDateTime{} = b),
    do: NaiveDateTime.compare(a, b) == :lt

  def less_than?(%Date{} = a, %Date{} = b), do: Date.compare(a, b) == :lt
  def less_than?(value, param) when is_binary(value) and is_binary(param), do: value < param
  def less_than?(_, _), do: false

  @doc "Less than or equal comparison."
  def less_than_or_equal?(value, param) when is_number(value) and is_number(param),
    do: value <= param

  def less_than_or_equal?(%DateTime{} = a, %DateTime{} = b),
    do: DateTime.compare(a, b) in [:lt, :eq]

  def less_than_or_equal?(%NaiveDateTime{} = a, %NaiveDateTime{} = b),
    do: NaiveDateTime.compare(a, b) in [:lt, :eq]

  def less_than_or_equal?(%Date{} = a, %Date{} = b), do: Date.compare(a, b) in [:lt, :eq]

  def less_than_or_equal?(value, param) when is_binary(value) and is_binary(param),
    do: value <= param

  def less_than_or_equal?(_, _), do: false

  # ============================================================================
  # Inclusion Operators
  # ============================================================================

  @doc """
  Checks if value is in the given list.

  If value is a list, checks if there's any intersection.
  """
  # Plain list value — check intersection with query list
  def in?(value, list) when is_list(list) and is_list(value) do
    Enum.any?(value, fn v -> Enum.any?(list, &equals?(v, &1)) end)
  end

  # MapSet value — check if any query item is a member of the set
  def in?(%MapSet{} = value, list) when is_list(list) do
    Enum.any?(list, &Collection.member?(value, &1))
  end

  # Custom struct value — check if any query item is a member
  def in?(%_{} = value, list) when is_list(list) do
    Enum.any?(list, &Collection.member?(value, &1))
  end

  # Scalar value — check if it is in the query list
  def in?(value, list) when is_list(list) do
    Enum.any?(list, &equals?(value, &1))
  end

  # MapSet on the right side (non-list)
  def in?(value, %MapSet{} = collection) do
    Collection.member?(collection, value)
  end

  def in?(_, _), do: false

  @doc "Checks if value is not in the given list."
  def not_in?(value, list), do: not in?(value, list)

  # ============================================================================
  # Array Operators
  # ============================================================================

  @doc """
  Checks if array contains all specified values.
  """
  def all?(value, expected) when is_list(value) and is_list(expected) do
    Enum.all?(expected, fn exp ->
      Enum.any?(value, &equals?(&1, exp))
    end)
  end

  # MapSet or custom struct — use Collection.member?/2
  def all?(%MapSet{} = value, expected) when is_list(expected) do
    Enum.all?(expected, &Collection.member?(value, &1))
  end

  def all?(%_{} = value, expected) when is_list(expected) do
    Enum.all?(expected, &Collection.member?(value, &1))
  end

  def all?(_, _), do: false

  @doc """
  Checks if array has the specified size.
  """
  def size?(value, size) when is_list(value) and is_integer(size) do
    length(value) == size
  end

  def size?(value, size) when is_binary(value) and is_integer(size) do
    String.length(value) == size
  end

  # MapSet or custom struct — use Collection.size/1
  def size?(%MapSet{} = value, size) when is_integer(size) do
    Collection.size(value) == size
  end

  def size?(%_{} = value, size) when is_integer(size) do
    Collection.size(value) == size
  end

  def size?(_, _), do: false

  @doc """
  Checks if at least one array element matches the query.
  """
  def elem_match?(value, query) when is_list(value) do
    Enum.any?(value, &Query.matches?(&1, query))
  end

  # MapSet — iterate elements
  def elem_match?(%MapSet{} = value, query) do
    value
    |> MapSet.to_list()
    |> Enum.any?(&Query.matches?(&1, query))
  end

  def elem_match?(_, _), do: false

  # ============================================================================
  # Existence Operator
  # ============================================================================

  @doc """
  Checks if value exists (is not nil).
  """
  def exists?(nil, true), do: false
  def exists?(nil, false), do: true
  def exists?(_, true), do: true
  def exists?(_, false), do: false
  def exists?(value, _), do: not is_nil(value)

  # ============================================================================
  # Type Operator
  # ============================================================================

  @doc """
  Checks if value is of the specified type.

  Supported types:
  - "string" or String
  - "number" or "integer" or "float" or Integer or Float
  - "boolean" or "bool" or Boolean
  - "map" or Map
  - "list" or "array" or List
  - "atom" or Atom
  - "date" or Date
  - "datetime" or DateTime
  - "nil" or "null"
  """
  def type_check?(value, type) do
    case normalize_type(type) do
      :string -> is_binary(value)
      :number -> is_number(value)
      :integer -> is_integer(value)
      :float -> is_float(value)
      :boolean -> is_boolean(value)
      :map -> is_map(value)
      :list -> is_list(value)
      :atom -> is_atom(value)
      :date -> match?(%Date{}, value)
      :datetime -> match?(%DateTime{}, value) or match?(%NaiveDateTime{}, value)
      nil -> is_nil(value)
      _ -> false
    end
  end

  defp normalize_type(type) when is_binary(type) do
    case String.downcase(type) do
      "string" -> :string
      "number" -> :number
      "integer" -> :integer
      "float" -> :float
      "boolean" -> :boolean
      "bool" -> :boolean
      "map" -> :map
      "list" -> :list
      "array" -> :list
      "atom" -> :atom
      "date" -> :date
      "datetime" -> :datetime
      "nil" -> nil
      "null" -> nil
      _ -> :unknown
    end
  end

  defp normalize_type(String), do: :string
  defp normalize_type(Integer), do: :integer
  defp normalize_type(Float), do: :float
  defp normalize_type(Map), do: :map
  defp normalize_type(List), do: :list
  defp normalize_type(Atom), do: :atom
  defp normalize_type(Date), do: :date
  defp normalize_type(DateTime), do: :datetime
  defp normalize_type(_), do: :unknown

  # ============================================================================
  # Modulus Operator
  # ============================================================================

  @doc """
  Performs modulus operation: value % divisor == remainder.

  Param should be [divisor, remainder].
  """
  def mod?(value, [divisor, remainder])
      when is_integer(value) and is_integer(divisor) and is_integer(remainder) do
    rem(value, divisor) == remainder
  end

  def mod?(_, _), do: false

  # ============================================================================
  # Regex Operator
  # ============================================================================

  @doc """
  Tests if value matches the regex pattern.
  """
  def regex?(value, %Regex{} = regex) when is_binary(value) do
    Regex.match?(regex, value)
  end

  def regex?(value, pattern) when is_binary(value) and is_binary(pattern) do
    case Regex.compile(pattern) do
      {:ok, regex} -> Regex.match?(regex, value)
      _ -> false
    end
  end

  def regex?(_, _), do: false

  # ============================================================================
  # Logical Operators
  # ============================================================================

  @doc """
  Negates the query result.
  """
  def not?(value, query) do
    not Query.matches?(value, query)
  end

  @doc """
  All queries must match (logical AND).
  """
  def and?(value, queries) when is_list(queries) do
    Enum.all?(queries, &Query.matches?(value, &1))
  end

  def and?(_, _), do: false

  @doc """
  At least one query must match (logical OR).
  """
  def or?(value, queries) when is_list(queries) do
    Enum.any?(queries, &Query.matches?(value, &1))
  end

  def or?(_, _), do: false

  @doc """
  No queries must match (logical NOR).
  """
  def nor?(value, queries) when is_list(queries) do
    Enum.all?(queries, &(not Query.matches?(value, &1)))
  end

  def nor?(_, _), do: false
end
