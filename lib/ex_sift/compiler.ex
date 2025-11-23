defmodule ExSift.Compiler do
  @moduledoc """
  Compiles MongoDB-style queries into optimized Elixir functions.

  This module is responsible for traversing the query structure and building a
  tree of matcher functions. It performs several optimizations:

  1.  **Path Unrolling**: Nested property paths (e.g., "user.profile.age") are
      resolved into efficient traversal functions.
  2.  **Operator Resolution**: Operators are looked up and bound to their
      implementation functions at compile time.
  3.  **Implicit Traversal**: Logic for handling list traversal (e.g., checking
      if any element in a list matches a condition) is embedded in the
      matcher.
  """

  alias ExSift.Operators
  alias ExSift.Query

  def compile(query) do
    matcher = build_matcher(query)
    fn item -> matcher.(item) end
  end

  defp build_matcher(%Regex{} = regex) do
    fn value -> Operators.equals?(value, regex) end
  end

  defp build_matcher(query) when is_map(query) do
    cond do
      Query.has_operator?(query) ->
        build_operator_matcher(query)

      true ->
        build_shape_matcher(query)
    end
  end

  defp build_matcher(value) do
    fn item -> Operators.equals?(item, value) end
  end

  defp build_operator_matcher(operators) do
    matchers =
      Enum.map(operators, fn {op, param} ->
        build_single_operator_matcher(op, param)
      end)

    fn value ->
      Enum.all?(matchers, fn matcher -> matcher.(value) end)
    end
  end

  defp build_single_operator_matcher("$eq", param), do: fn v -> Operators.equals?(v, param) end

  defp build_single_operator_matcher("$ne", param),
    do: fn v -> Operators.not_equals?(v, param) end

  defp build_single_operator_matcher("$gt", param),
    do: fn v -> Operators.greater_than?(v, param) end

  defp build_single_operator_matcher("$gte", param),
    do: fn v -> Operators.greater_than_or_equal?(v, param) end

  defp build_single_operator_matcher("$lt", param), do: fn v -> Operators.less_than?(v, param) end

  defp build_single_operator_matcher("$lte", param),
    do: fn v -> Operators.less_than_or_equal?(v, param) end

  defp build_single_operator_matcher("$in", param), do: fn v -> Operators.in?(v, param) end
  defp build_single_operator_matcher("$nin", param), do: fn v -> Operators.not_in?(v, param) end

  defp build_single_operator_matcher("$exists", param),
    do: fn v -> Operators.exists?(v, param) end

  defp build_single_operator_matcher("$type", param),
    do: fn v -> Operators.type_check?(v, param) end

  defp build_single_operator_matcher("$mod", param), do: fn v -> Operators.mod?(v, param) end
  defp build_single_operator_matcher("$regex", param), do: fn v -> Operators.regex?(v, param) end
  defp build_single_operator_matcher("$all", param), do: fn v -> Operators.all?(v, param) end
  defp build_single_operator_matcher("$size", param), do: fn v -> Operators.size?(v, param) end

  defp build_single_operator_matcher("$elemMatch", param) do
    inner_matcher = build_matcher(param)

    fn v ->
      is_list(v) and Enum.any?(v, inner_matcher)
    end
  end

  defp build_single_operator_matcher("$not", param) do
    inner_matcher = build_matcher(param)
    fn v -> not inner_matcher.(v) end
  end

  defp build_single_operator_matcher("$and", param) when is_list(param) do
    matchers = Enum.map(param, &build_matcher/1)
    fn v -> Enum.all?(matchers, fn m -> m.(v) end) end
  end

  defp build_single_operator_matcher("$or", param) when is_list(param) do
    matchers = Enum.map(param, &build_matcher/1)
    fn v -> Enum.any?(matchers, fn m -> m.(v) end) end
  end

  defp build_single_operator_matcher("$nor", param) when is_list(param) do
    matchers = Enum.map(param, &build_matcher/1)
    fn v -> Enum.all?(matchers, fn m -> not m.(v) end) end
  end

  defp build_single_operator_matcher(op, _) do
    raise ArgumentError, "Unknown operator: #{op}"
  end

  defp build_shape_matcher(query) do
    matchers =
      Enum.map(query, fn {key, expected} ->
        build_property_matcher(key, expected)
      end)

    fn value ->
      is_map(value) and Enum.all?(matchers, fn matcher -> matcher.(value) end)
    end
  end

  defp build_property_matcher(key, expected) do
    key_str = to_string(key)
    path = String.split(key_str, ".")
    traverser = build_path_traverser(path)
    value_matcher = build_matcher(expected)
    last_key_numeric = is_numeric_key?(List.last(path))

    # $type operator should strictly check the value type, not elements
    has_type_operator = is_map(expected) and Map.has_key?(expected, "$type")

    fn root ->
      actual = traverser.(root)

      if is_list(actual) and not last_key_numeric and not has_type_operator do
        # Try matching the list itself first (e.g. for $size, $all)
        if value_matcher.(actual) do
          true
        else
          # If not, check if any element matches (implicit traversal)
          Enum.any?(actual, value_matcher)
        end
      else
        value_matcher.(actual)
      end
    end
  end

  defp build_path_traverser([]) do
    fn root -> root end
  end

  defp build_path_traverser([key | rest]) do
    next_traverser = build_path_traverser(rest)

    atom_key =
      try do
        String.to_existing_atom(key)
      rescue
        _ -> nil
      end

    fn root ->
      if is_map(root) do
        val = Map.get(root, key) || (atom_key && Map.get(root, atom_key))
        next_traverser.(val)
      else
        nil
      end
    end
  end

  defp is_numeric_key?(key) when is_binary(key) do
    case Integer.parse(key) do
      {_, ""} -> true
      _ -> false
    end
  end

  defp is_numeric_key?(_), do: false
end
