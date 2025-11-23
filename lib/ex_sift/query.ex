defmodule ExSift.Query do
  @moduledoc """
  Core query matching logic for ExSift.

  This module handles parsing and matching MongoDB-style queries against values.
  """

  alias ExSift.Operators

  @doc """
  Tests if a value matches a query.

  ## Examples

      iex> ExSift.Query.matches?(%{age: 30}, %{age: 30})
      true

      iex> ExSift.Query.matches?(%{age: 30}, %{age: %{"$gt" => 25}})
      true
  """
  # Handle Regex directly (must come before is_map guard)
  def matches?(value, %Regex{} = regex) do
    Operators.equals?(value, regex)
  end

  def matches?(value, query) when is_map(query) do
    cond do
      # Check if it's an operator query (keys start with $)
      has_operator?(query) ->
        match_operators?(value, query)

      # It's a shape query - match against object properties
      true ->
        match_shape?(value, query)
    end
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

  # Match against object shape
  defp match_shape?(value, query) when is_map(value) and is_map(query) do
    Enum.all?(query, fn {key, expected} ->
      match_property?(value, key, expected)
    end)
  end

  defp match_shape?(_, _), do: false

  # Match a specific property path
  defp match_property?(value, key, expected) when is_binary(key) do
    # Support dot notation for nested paths
    path = String.split(key, ".")
    actual = get_nested_value(value, path)

    cond do
      # If actual is a list and we're not at a numeric index,
      # check if any element matches (like MongoDB)
      is_list(actual) and not is_numeric_key?(List.last(path)) ->
        Enum.any?(actual, &matches?(&1, expected))

      true ->
        matches?(actual, expected)
    end
  end

  defp match_property?(value, key, expected) do
    # Handle atom keys
    actual = Map.get(value, key)
    matches?(actual, expected)
  end

  # Get nested value using dot notation
  defp get_nested_value(value, []), do: value

  defp get_nested_value(value, [key | rest]) when is_map(value) do
    # Try both string and atom keys
    next_value =
      Map.get(value, key) ||
        Map.get(value, String.to_existing_atom(key))

    get_nested_value(next_value, rest)
  rescue
    ArgumentError -> get_nested_value(nil, rest)
  end

  defp get_nested_value(_, _), do: nil

  defp is_numeric_key?(key) when is_binary(key) do
    case Integer.parse(key) do
      {_, ""} -> true
      _ -> false
    end
  end

  defp is_numeric_key?(_), do: false

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
