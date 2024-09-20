defmodule CouchdbWrapper do
  use Tesla

  @moduledoc """
  Documentation for `CouchdbWrapper`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> CouchdbWrapper.hello()
      :world

  """
  def hello do
    :world
  end

  def ping do
    {:ok, env } = get("https://www.google.com")
    IO.inspect(env)
  end
end
