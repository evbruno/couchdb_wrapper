defmodule Predicate do
  def eval(p, obj) do
    # Thanks CoPilot for your hardwork ! 🤖
    case p do
      # string representation
      {field, :eq, value} ->
        field_path(obj, field) |> to_string == value

      {field, :ne, value} ->
        field_path(obj, field) |> to_string != value

      {field, :in, values} ->
        Enum.member?(values, field_path(obj, field) |> to_string)

      {field, :nin, values} ->
        !Enum.member?(values, field_path(obj, field) |> to_string)

      {field, :regex, regex} ->
        Regex.match?(~r/#{regex}/, field_path(obj, field) |> to_string)

      # cast to number
      {field, :gt, value} ->
        field_path(obj, field) > value

      {field, :gte, value} ->
        field_path(obj, field) >= value

      {field, :lt, value} ->
        field_path(obj, field) < value

      {field, :lte, value} ->
        field_path(obj, field) <= value

      {field, :mod, {divisor, remainder}} ->
        rem(field_path(obj, field), divisor) == remainder

      # string based operations
      {field, :elem, index} ->
        Enum.at(field_path(obj, field), index) != nil

      {field, :size, size} ->
        length(field_path(obj, field)) == size

      # else....
      {field, :exists} ->
        field_path(obj, field) != nil
        # Map.has_key?(obj, field)
    end
  end

  def parse(str) do
    case String.split(str, ~r/:/, trim: true) do
      [field, "eq", value] ->
        {field, :eq, value}

      [field, "ne", value] ->
        {field, :ne, value}

      [field, "gt", value] ->
        {field, :gt, String.to_integer(value)}

      [field, "gte", value] ->
        {field, :gte, String.to_integer(value)}

      [field, "lt", value] ->
        {field, :lt, String.to_integer(value)}

      [field, "lte", value] ->
        {field, :lte, String.to_integer(value)}

      [field, "in", values] ->
        # |> Enum.map(&String.to_integer/1)}
        {field, :in, String.split(values, ",", trim: true)}

      [field, "nin", values] ->
        # |> Enum.map(&String.to_integer/1)}
        {field, :nin, String.split(values, ",", trim: true)}

      [field, "exists"] ->
        {field, :exists}

      [field, "regex", regex] ->
        {field, :regex, regex}

      [field, "elem", index] ->
        {field, :elem, String.to_integer(index)}

      [field, "size", size] ->
        {field, :size, String.to_integer(size)}

      [field, "mod", divisor, remainder] ->
        {field, :mod, {String.to_integer(divisor), String.to_integer(remainder)}}

      _ ->
        raise ArgumentError, "Invalid predicate -->#{str}<--"
    end
  end

  def field_path(obj, keys),
    # TODO: Kernel.get_in/2 does not work for `get_in(%{"foo" => %{"bar" => "11"}}, ["foo", "bar"])`
    do: get_nested(obj, String.split(keys, ".", trim: true))

  defp get_nested(obj, _) when not is_map(obj),
    do: nil

  defp get_nested(obj, [key | tail]) when length(tail) > 0 do
    with x when not is_nil(x) <- Map.get(obj, key) do
      get_nested(x, tail)
    else
      _ -> nil
    end
  end

  defp get_nested(obj, [key]), do: Map.get(obj, key)

  def combine_actions([]), do: fn _ -> true end

  def combine_actions(ps) do
    fn obj ->
      Enum.all?(ps, fn p -> eval(p, obj) end)
    end
  end
end
