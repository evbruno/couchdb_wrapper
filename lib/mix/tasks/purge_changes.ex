defmodule Mix.Tasks.Purge.Changes do
  @moduledoc ~S"""
  The purge.changes mix task: `mix help purge.changes`

  ## Usage

    ```mix purge.changes database-name```

    It will purge all the documents that are marked as `deleted: true` on the API `<database>/_changes`

  """
  use Mix.Task

  @shortdoc "Delete all deleted /_changes"
  def run(args) do
    # Logger.configure(level: :info)

    if length(args) < 1 do
      Mix.shell().error("Usage: mix purge.changes <database>")
      System.halt(1)
    end

    database = hd(args)

    Mix.shell().info("Going to purge all changes from #{database}...")

    if !Mix.shell().yes?("Are you sure?") do
      Mix.shell().info("Aborted.")
      System.halt(1)
    end

    database
    |> CouchdbWrapper.changes_stream()
    |> Stream.filter(& &1["deleted"])
    |> Stream.take(5)
    |> Stream.map(fn x -> {x["id"], [hd(x["changes"])["rev"]]} end)
    |> Stream.chunk_every(100)
    |> Stream.each(fn chunk ->
      Mix.shell().info("Wiping #{length(chunk)} changes from #{database}...")

      case CouchdbWrapper.bulk_purge_docs(database, Map.new(chunk)) do
        {:ok, _} -> Mix.shell().info("... Deleted")
      end

      # Process.sleep(5_000)
    end)
    |> Stream.run()

    Mix.shell().info("Done.")
  end
end
