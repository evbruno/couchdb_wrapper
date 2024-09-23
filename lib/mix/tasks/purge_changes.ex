defmodule Mix.Tasks.Purge.Changes do
  @moduledoc ~S"""
  The purge.changes mix task: `mix help purge.changes`

  ## Usage

    ```mix purge.changes database-name```

    It will purge all the documents that are marked as `deleted: true` on the API `<database>/_changes`

  """
  require Logger
  use Mix.Task

  @shortdoc "Delete all deleted /_changes"
  def run(args) do
    Logger.configure(level: :info)

    validate_args(args)

    database = hd(args)
    {prev, file, content} = TaskUtils.has_previous_run?(hd(System.argv()), database)

    pids = TaskUtils.start(file)
    opts = build_opts(prev, content)

    database
    |> CouchdbWrapper.changes_stream(opts)
    |> process_changes(pids, database)

    TaskUtils.stop(pids)

    Mix.shell().info("\nDone.")
  end

  defp validate_args(args) do
    if length(args) < 1 do
      Mix.shell().error("Usage: mix purge.changes <database>")
      System.halt(1)
    end
  end

  defp build_opts(true, content), do: [last_seq: content]
  defp build_opts(_, _), do: []

  defp process_changes(stream, pids, database) do
    stream
    |> TaskUtils.step(pids, "seq")
    |> Stream.filter(& &1["deleted"])
    |> Stream.map(&{&1["id"], [hd(&1["changes"])["rev"]]})
    |> Stream.chunk_every(100)
    |> Stream.each(&bulk_purge(database, &1))
    |> Stream.run()
  end

  defp bulk_purge(database, chunk) do
    case CouchdbWrapper.bulk_purge_docs(database, Map.new(chunk)) do
      {:ok, _} -> IO.write("\rX")
    end
  end
end
