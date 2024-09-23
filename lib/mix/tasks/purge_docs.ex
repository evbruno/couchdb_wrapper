defmodule Mix.Tasks.Purge.Docs do
  @moduledoc ~S"""
  The purge.doc mix task: `mix help purge.docs`

  ## Usage

    ```mix purge.docs database-name```

    It will purge all the documents loaded from `<database>/_all_docs` API

  ## Predicates

    ```mix purge.docs database-name p1 p2 pn```

    It will purge all the documents loaded from `<database>/_all_docs` API, but only those that match the predicates.

    Some valid predicates:

    - `doc.age:gt:20` (`doc.age` greater than `20` - a `number`)
    - `doc._id:eq:1234567` (`doc._id` equals to `1234567`)
    - `doc._id:in:1,2,3` (`doc.id` is equal to `1` or `2` or `3`,)
    - `doc.reply_to:exists` (the field `doc.reply_to` exists in the doc)

  See [the tests](/test/predicate_test.exs) for more examples.

  """
  use Mix.Task
  alias CouchdbWrapper.IdAndRev

  @shortdoc "Delete all documents from a CouchDB database."
  def run(args) do
    # Logger.configure(level: :info)

    if length(args) < 1 do
      Mix.shell().error("Usage: mix purge.changes <database> [p1, p2, ...pN]")
      System.halt(1)
    end

    [database | predicates] = args

    msg =
      if length(predicates) == 0 do
        "Going to purge all documents from #{database} (with NO restrictions/predicates)..."
      else
        "Going to purge all documents from #{database}..."
      end

    Mix.shell().info(msg)

    if !Mix.shell().yes?("Are you sure?") do
      Mix.shell().info("Aborted.")
      System.halt(1)
    end

    build_stream(database, predicates)
    # |> Stream.take(5)
    # |> Enum.each(&IO.inspect(&1))
    |> delete_stream(database)
    |> Stream.run()

    Mix.shell().info("Done purging... Cleaning up after 5s!")

    :timer.sleep(:timer.seconds(5))

    {:ok, _} = CouchdbWrapper.compact(database)
    {:ok, _} = CouchdbWrapper.cleanup(database)

    Mix.shell().info("Done.")

    {:ok, database}
  end

  defp build_stream(database, []) do
    database
    |> CouchdbWrapper.all_docs_stream(limit: 250, include_docs?: false)
  end

  defp build_stream(database, ps) do
    IO.inspect(ps, label: "Predicates")

    filter =
      ps
      |> Enum.map(&Predicate.parse/1)
      |> Predicate.combine_actions()

    database
    |> CouchdbWrapper.all_docs_stream(limit: 250, include_docs?: true)
    |> Stream.filter(filter)
  end

  defp delete_stream(source, database) do
    source
    |> Stream.map(&IdAndRev.from_doc/1)
    |> Stream.chunk_every(100)
    |> Stream.each(fn chunk ->
      case CouchdbWrapper.bulk_delete_docs(database, chunk) do
        {:ok, deleted_docs} ->
          ids_and_revs =
            deleted_docs
            |> Enum.into(%{}, fn doc -> {doc["id"], [doc["rev"]]} end)

          CouchdbWrapper.bulk_purge_docs(database, ids_and_revs)
      end
    end)
  end
end
