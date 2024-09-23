defmodule Predicate do
  def eval(p, obj) do
    # Thanks CoPilot for your hardwork ! 🤖
    case p do
      {field, :eq, value} -> Map.get(obj, field) == value
      {field, :ne, value} -> Map.get(obj, field) != value
      {field, :gt, value} -> Map.get(obj, field) > value
      {field, :gte, value} -> Map.get(obj, field) >= value
      {field, :lt, value} -> Map.get(obj, field) < value
      {field, :lte, value} -> Map.get(obj, field) <= value
      {field, :in, values} -> Enum.member?(values, Map.get(obj, field))
      {field, :nin, values} -> !Enum.member?(values, Map.get(obj, field))
      {field, :exists} -> Map.has_key?(obj, field)
      {field, :regex, regex} -> Regex.match?(~r/#{regex}/, Map.get(obj, field))
      {field, :elem, index} -> Enum.at(Map.get(obj, field), index) != nil
      {field, :size, size} -> length(Map.get(obj, field)) == size
      {field, :mod, {divisor, remainder}} -> rem(Map.get(obj, field), divisor) == remainder
    end
  end

  def parse(str) do
    case String.split(str, ~r/:/, trim: true) do
      [field, "eq", value] ->
        {String.to_existing_atom(field), :ne, String.to_integer(value)}

      [field, "ne", value] ->
        {String.to_existing_atom(field), :ne, String.to_integer(value)}

      [field, "gt", value] ->
        {String.to_existing_atom(field), :gt, String.to_integer(value)}

      [field, "gte", value] ->
        {String.to_existing_atom(field), :gte, String.to_integer(value)}

      [field, "lt", value] ->
        {String.to_existing_atom(field), :lt, String.to_integer(value)}

      [field, "lte", value] ->
        {String.to_existing_atom(field), :lte, String.to_integer(value)}

      [field, "in", values] ->
        {String.to_existing_atom(field), :in,
         String.split(values, ",") |> Enum.map(&String.to_integer/1)}

      [field, "nin", values] ->
        {String.to_existing_atom(field), :nin,
         String.split(values, ",") |> Enum.map(&String.to_integer/1)}

      [field, "exists"] ->
        {String.to_existing_atom(field), :exists}

      [field, "regex", regex] ->
        {String.to_existing_atom(field), :regex, regex}

      [field, "elem", index] ->
        {String.to_existing_atom(field), :elem, String.to_integer(index)}

      [field, "size", size] ->
        {String.to_existing_atom(field), :size, String.to_integer(size)}

      [field, "mod", divisor, remainder] ->
        {String.to_existing_atom(field), :mod,
         {String.to_integer(divisor), String.to_integer(remainder)}}

      _ ->
        raise ArgumentError, "Invalid predicate -->#{str}<--"
    end
  end

  def get_nested(obj, keys) when is_bitstring(keys),
    do: get_nested(obj, String.split(keys, ".", trim: true))

  def get_nested(obj, keys) do
    Enum.reduce(keys, obj, fn key, acc ->
      case acc do
        nil -> nil
        _ -> Map.get(acc, key)
      end
    end)
  end

  def combine_actions([]), do: fn _ -> true end

  def combine_actions(ps) do
    fn obj ->
      Enum.all?(ps, fn p -> eval(p, obj) end)
    end
  end
end
