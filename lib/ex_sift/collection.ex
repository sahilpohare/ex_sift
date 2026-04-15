defprotocol ExSift.Collection do
  @moduledoc """
  Protocol for types that can be queried by ExSift.

  Implement this protocol to make any collection type work with ExSift's
  filtering and query matching. By default, maps, lists, MapSets, and any
  struct are supported.

  ## Implementing for custom types

      defimpl ExSift.Collection, for: MyStruct do
        def fetch(collection, key), do: Map.get(collection, key)
        def to_pairs(collection), do: Map.to_list(collection)
        def member?(collection, value), do: value in collection.items
        def size(collection), do: length(collection.items)
      end
  """

  @fallback_to_any true

  @doc """
  Fetch a value by key. Returns the value or `nil` if not found.
  """
  @spec fetch(t(), term()) :: term()
  def fetch(collection, key)

  @doc """
  Convert collection to a list of `{key, value}` pairs for shape matching.
  Return `nil` if the collection cannot be used as a key-value structure.
  """
  @spec to_pairs(t()) :: [{term(), term()}] | nil
  def to_pairs(collection)

  @doc """
  Check if a value is a member of the collection. Used for `$in` and `$all`.
  """
  @spec member?(t(), term()) :: boolean()
  def member?(collection, value)

  @doc """
  Return the size/count of the collection. Used for `$size`.
  """
  @spec size(t()) :: non_neg_integer()
  def size(collection)
end

defimpl ExSift.Collection, for: Map do
  def fetch(map, key) when is_binary(key) do
    Map.get(map, key) || Map.get(map, to_existing_atom(key))
  end

  def fetch(map, key), do: Map.get(map, key)

  def to_pairs(map), do: Map.to_list(map)
  def member?(map, value), do: value in Map.values(map)
  def size(map), do: map_size(map)

  defp to_existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end

defimpl ExSift.Collection, for: List do
  # Keyword list: fetch by atom key
  def fetch(list, key) when is_atom(key) and is_list(list) do
    if Keyword.keyword?(list), do: Keyword.get(list, key), else: nil
  end

  # Plain list: numeric index access
  def fetch(list, key) when is_binary(key) do
    case Integer.parse(key) do
      {idx, ""} -> Enum.at(list, idx)
      _ ->
        if Keyword.keyword?(list) do
          atom_key = String.to_existing_atom(key)
          Keyword.get(list, atom_key)
        else
          nil
        end
    end
  rescue
    ArgumentError -> nil
  end

  def fetch(list, idx) when is_integer(idx), do: Enum.at(list, idx)
  def fetch(_, _), do: nil

  # Keyword list: pairs are the key-value tuples
  def to_pairs(list) when is_list(list) do
    if Keyword.keyword?(list), do: list, else: nil
  end

  def member?(list, value), do: value in list
  def size(list), do: length(list)
end

defimpl ExSift.Collection, for: MapSet do
  # MapSets have no meaningful key access
  def fetch(_mapset, _key), do: nil
  def to_pairs(_mapset), do: nil
  def member?(mapset, value), do: MapSet.member?(mapset, value)
  def size(mapset), do: MapSet.size(mapset)
end

defimpl ExSift.Collection, for: Any do
  # Structs are maps under the hood — delegate to map operations
  def fetch(%_{} = struct, key) when is_binary(key) do
    Map.get(struct, key) ||
      try do
        Map.get(struct, String.to_existing_atom(key))
      rescue
        ArgumentError -> nil
      end
  end

  def fetch(%_{} = struct, key), do: Map.get(struct, key)
  def fetch(_, _), do: nil

  def to_pairs(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.to_list()
  end

  def to_pairs(_), do: nil

  def member?(%_{} = struct, value), do: value in Map.values(struct)
  def member?(_, _), do: false

  def size(%_{} = struct), do: struct |> Map.from_struct() |> map_size()
  def size(_), do: 0
end
