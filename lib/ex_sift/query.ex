defmodule ExSift.Query do
  @moduledoc """
  Core query matching logic for ExSift.

  This module handles parsing and matching MongoDB-style queries against values.
  Supports any type implementing the `ExSift.Collection` protocol.
  """

  alias ExSift.{Collection, Operators}

  @doc """
  Tests if a value matches a query.

  ## Examples

      iex> ExSift.Query.matches?(%{age: 30}, %{age: 30})
      true

      iex> ExSift.Query.matches?(%{age: 30}, %{age: %{"$gt" => 25}})
      true

      iex> ExSift.Query.matches?(MapSet.new([1, 2, 3]), %{"$size" => 3})
      true

      iex> ExSift.Query.matches?([a: 1, b: 2], %{"a" => 1})
      true
  """
  # Handle Regex directly (must come before map guard)
  def matches?(value, %Regex{} = regex) do
    Operators.equals?(value, regex)
  end

  def matches?(value, query) when is_map(query) and not is_struct(query) do
    cond do
      has_operator?(query) -> match_operators?(value, query)
      true -> match_shape?(value, query)
    end
  end

  # Structs used as query values — direct equality
  def matches?(value, %_{} = query) do
    Operators.equals?(value, query)
  end

  # Direct value comparison
  def matches?(value, query) do
    Operators.equals?(value, query)
  end

  @doc """
  Checks if a map contains any operator keys (starting with $).
  """
  def has_operator?(map) when is_map(map) do
    Enum.any?(map, fn {key, _} ->
      is_binary(key) and String.starts_with?(key, "$")
    end)
  end

  def has_operator?(_), do: false

  # Match against operators like $gt, $eq, etc.
  defp match_operators?(value, operators) when is_map(operators) do
    Enum.all?(operators, fn {op, param} ->
      apply_operator(op, value, param)
    end)
  end

  # Match against object shape — delegates to Collection protocol
  defp match_shape?(value, query) when is_map(query) do
    pairs = Collection.to_pairs(value)

    if pairs != nil do
      Enum.all?(query, fn {key, expected} ->
        match_property?(value, key, expected)
      end)
    else
      false
    end
  end

  defp match_shape?(_, _), do: false

  # Match a specific property path (dot notation supported)
  defp match_property?(value, key, expected) when is_binary(key) do
    path = String.split(key, ".")
    actual = get_nested_value(value, path)

    # If actual is a plain list (not keyword) and last key isn't a numeric index,
    # check if any element matches (MongoDB-style implicit $elemMatch)
    if plain_list?(actual) and not is_numeric_key?(List.last(path)) do
      Enum.any?(actual, &matches?(&1, expected))
    else
      matches?(actual, expected)
    end
  end

  defp match_property?(value, key, expected) do
    actual = Collection.fetch(value, key)
    matches?(actual, expected)
  end

  # Traverse nested path using the Collection protocol
  defp get_nested_value(value, []), do: value

  defp get_nested_value(value, [key | rest]) do
    next = Collection.fetch(value, key)
    get_nested_value(next, rest)
  end

  defp is_numeric_key?(key) when is_binary(key) do
    match?({_, ""}, Integer.parse(key))
  end

  defp is_numeric_key?(_), do: false

  # A plain list (not a keyword list) — these get implicit element matching
  defp plain_list?(value) when is_list(value), do: not Keyword.keyword?(value)
  defp plain_list?(_), do: false

  # Apply operator to value
  defp apply_operator("$eq", value, param), do: Operators.equals?(value, param)
  defp apply_operator("$ne", value, param), do: Operators.not_equals?(value, param)
  defp apply_operator("$gt", value, param), do: Operators.greater_than?(value, param)
  defp apply_operator("$gte", value, param), do: Operators.greater_than_or_equal?(value, param)
  defp apply_operator("$lt", value, param), do: Operators.less_than?(value, param)
  defp apply_operator("$lte", value, param), do: Operators.less_than_or_equal?(value, param)
  defp apply_operator("$in", value, param), do: Operators.in?(value, param)
  defp apply_operator("$nin", value, param), do: Operators.not_in?(value, param)
  defp apply_operator("$exists", value, param), do: Operators.exists?(value, param)
  defp apply_operator("$type", value, param), do: Operators.type_check?(value, param)
  defp apply_operator("$mod", value, param), do: Operators.mod?(value, param)
  defp apply_operator("$regex", value, param), do: Operators.regex?(value, param)
  defp apply_operator("$all", value, param), do: Operators.all?(value, param)
  defp apply_operator("$size", value, param), do: Operators.size?(value, param)
  defp apply_operator("$elemMatch", value, param), do: Operators.elem_match?(value, param)
  defp apply_operator("$not", value, param), do: Operators.not?(value, param)
  defp apply_operator("$and", value, param), do: Operators.and?(value, param)
  defp apply_operator("$or", value, param), do: Operators.or?(value, param)
  defp apply_operator("$nor", value, param), do: Operators.nor?(value, param)

  defp apply_operator(op, _, _) do
    raise ArgumentError, "Unknown operator: #{op}"
  end
end
