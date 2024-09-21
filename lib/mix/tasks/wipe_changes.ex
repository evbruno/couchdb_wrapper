defmodule Mix.Tasks.Wipe.Changes do
  @moduledoc ~S"""
  The wipe.changes mix task: `mix help wipe.changes`

  ## Usage

    ```mix wipe.changes database-name```

    That remove all the changes that are `deleted: true`

  """
  use Mix.Task

  @shortdoc "Delete all deleted /_changes"
  def run(args) do
    # Logger.configure(level: :info)

    if length(args) < 1 do
      Mix.shell().error("Usage: mix wipe.changes <database>")
      System.halt(1)
    end

    database = hd(args)

    Mix.shell().info("Going to wipe all changes from #{database}...")

    if !Mix.shell().yes?("Are you sure?") do
      Mix.shell().info("Aborted.")
      System.halt(1)
    end

    database
    |> CouchdbWrapper.changes_stream()
    |> Stream.filter(& &1["deleted"])
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
