defmodule Mix.Tasks.Purge.Clean do
  @moduledoc ~S"""
  The purge.doc mix task: `mix help purge.docs`

  ## Usage

    ```mix purge.clean database-name [doc1, doc2, ...]```

    It calls `<database>/_compact` and `<database>/_view_cleanup` API.

    If `doc1` is provided, it will also call `<database>/_compact/doc1`, `<database>/_compact/doc2`, etc.


  """
  use Mix.Task

  def run(args) do
    # Logger.configure(level: :info)

    validate_args(args)
    [database | design_docs] = args

    {:ok, _} = CouchdbWrapper.compact(database)

    design_docs
    |> Enum.each(fn doc ->
      {:ok, _} = CouchdbWrapper.compact(database, doc)
    end)

    {:ok, _} = CouchdbWrapper.cleanup(database)

    Mix.shell().info("Done.")
  end

  defp validate_args(args) do
    if length(args) < 1 do
      Mix.shell().error("Usage: mix purge.clean <database> [doc1, doc2, ...]")
      System.halt(1)
    end
  end
end
