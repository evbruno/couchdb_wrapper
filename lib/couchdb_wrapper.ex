defmodule CouchdbWrapper.PageResponse do
  defstruct rows: [], next_key: nil, error: nil, total_rows: 0

  @moduledoc ~S"""
  A struct to represent the all_docs responses from CouchDB API.
  """
end

defmodule CouchdbWrapper.ChangesResponse do
  defstruct rows: [], last_seq: nil, error: nil, pending: 0

  @moduledoc ~S"""
  A struct to represent the changes responses from CouchDB API.
  """
end

defmodule CouchdbWrapper.IdAndRev do
  @enforce_keys [:id, :rev]
  defstruct [:id, :rev]

  @moduledoc ~S"""
  A struct to represent id+rev pair on Couchdb
  """

  def from_doc(doc), do: %CouchdbWrapper.IdAndRev{id: doc["id"], rev: doc["value"]["rev"]}
  def new(id, rev), do: %CouchdbWrapper.IdAndRev{id: id, rev: rev}
end

defmodule CouchdbWrapper do
  use Tesla
  require Logger
  alias CouchdbWrapper.ChangesResponse, as: Changes
  alias CouchdbWrapper.PageResponse, as: AllDocs

  @moduledoc ~S"""
  CouchDB Wrapper.
  """

  @base_url System.get_env("COUCHDB_URL") || "http://localhost:5984/"
  @username System.get_env("COUCHDB_USERNAME") || "admin"
  @password System.get_env("COUCHDB_PASSWORD") || "admin"

  @default_limit 100

  plug(Tesla.Middleware.BaseUrl, @base_url)
  plug(Tesla.Middleware.BasicAuth, username: @username, password: @password)
  plug(Tesla.Middleware.JSON)
  # plug(Tesla.Middleware.Logger)

  @doc ~S"""
  Loads all docs from CouchDB, paginating as a stream.

  See `all_docs/2` for more details.

  """
  def all_docs_stream(database, options \\ []) do
    Stream.resource(
      fn -> :start end,
      &fetch_next_page_doc_stream(&1, database, options),
      fn _ -> :ok end
    )
  end

  defp fetch_next_page_doc_stream(:start, database, options) do
    handle_all_docs_stream(options, database)
  end

  defp fetch_next_page_doc_stream(next_key, database, options) when next_key != nil do
    options
    |> Keyword.put(:start_key, next_key)
    |> handle_all_docs_stream(database)
  end

  defp fetch_next_page_doc_stream(_, _, _), do: {:halt, nil}

  defp handle_all_docs_stream(options, database) do
    case all_docs(database, options) do
      {:ok, %AllDocs{rows: rows, next_key: next_key}} ->
        {rows, next_key}

      {:error, %AllDocs{error: error}} ->
        Logger.warning("Error loading all_docs with #{inspect(options)}: #{inspect(error)}")
        {:halt, error}
    end
  end

  @doc ~S"""
  Loads all docs from CouchDB

  API: `GET /{database}/_all_docs`

  ## Options

    * `:limit` (integer) defaults to 100
    * `:include_docs?` (boolean) - defaults to `true`
    * `:start_key` (string) - start key for the query
    * `:end_key` (string) - end key for the query

  ## Examples

      iex> CouchdbWrapper.all_docs("my_database")
      {:ok, %CouchdbWrapper.PageResponse{...}}

  """
  def all_docs(database, options \\ []) do
    url = build_all_docs_url(database, options)
    Logger.debug("all_docs_url: #{url}")
    get(url) |> handle_all_docs(options)
  end

  defp handle_all_docs(
         {:ok, %Tesla.Env{status: 200, body: %{"rows" => rows, "total_rows" => total_rows}}},
         options
       ) do
    rows
    |> handle_last_page_all_docs(
      options,
      %AllDocs{rows: rows, total_rows: total_rows}
    )
  end

  defp handle_all_docs({_op, %Tesla.Env{body: body}}, _options) do
    {:error, %AllDocs{error: body}}
  end

  defp handle_all_docs({_op, res}, _options) do
    {:error, %AllDocs{error: res}}
  end

  #  if empty or single row, we are done
  defp handle_last_page_all_docs([], _options, response) do
    Logger.debug("Loaded empty last page single row, total_rows: #{response.total_rows}")
    {:ok, %AllDocs{}}
  end

  # defp handle_last_page_all_docs([_], _options, response) do
  #   Logger.debug("Loaded last page single row, total_rows: #{response.total_rows}")
  #   {:ok, %AllDocs{}}
  # end

  defp handle_last_page_all_docs(rows, options, response) do
    Logger.debug("Loaded all_docs rows: #{length(rows)}")
    ret = Enum.take(rows, limit(options))
    {:ok, %AllDocs{response | rows: ret, next_key: last_key(rows, options)}}
  end

  defp build_all_docs_url(database, options) do
    params =
      [
        "limit=#{limit(options) + 1}",
        "include_docs=#{include_docs?(options)}"
      ] ++
        build_key_param("startkey", options[:start_key]) ++
        build_key_param("endkey", options[:end_key])

    "/#{database}/_all_docs?" <> Enum.join(params, "&")
  end

  defp build_key_param(_key, nil), do: []

  defp build_key_param(key, value) do
    encoded_key = URI.encode("\"#{value}\"")
    ["#{key}=#{encoded_key}"]
  end

  defp limit(options), do: options[:limit] || @default_limit
  defp include_docs?(options), do: options[:include_docs?] != false

  defp last_key(rows, options) do
    if length(rows) > limit(options) do
      List.last(rows)["id"]
    else
      nil
    end
  end

  @doc ~S"""
  Deletes a list of documents from a database.

  API: `POST /{database}/_bulk_docs`

  Returns `:ok`.

  ## Examples

      iex> CouchdbWrapper.bulk_delete_docs(
        "database_name",
        [ CouchdbWrapper.IdAndRev.new("id1", "1-rev1") ]
      )

      {:ok,
       [
        %{
          "id" => "id1",
          "ok" => true,
          "rev" => "2-rev2"
        }
      ]}

  """
  def bulk_delete_docs(database, ids_and_revs) do
    data =
      ids_and_revs
      |> Enum.map(fn row -> %{_id: row.id, _rev: row.rev, _deleted: true} end)

    post("/#{database}/_bulk_docs", %{docs: data}) |> handle_bulk_delete_docs()
  end

  defp handle_bulk_delete_docs({:ok, %Tesla.Env{status: 201, body: rows}}) do
    if Enum.any?(rows, fn row -> row["error"] != nil end) do
      IO.warn("Bulk deletion did not complete for some ids/revs")
      Logger.debug("Bulk deletion did not complete for some ids/revs: #{inspect(rows)}")
      {:error, rows}
    else
      Logger.debug("Bulk deletion completed for #{Enum.count(rows)}")
      {:ok, rows}
    end
  end

  defp handle_bulk_delete_docs({:ok, %Tesla.Env{body: rows}}) do
    Logger.debug("Bulk deletion did not complete for some ids/revs: #{inspect(rows)}")
    {:error, rows}
  end

  @doc ~S"""
  Purges a map of documents from a database, key => [rev1, rev2, ...].

  API: `POST /{database}/_purge`

  Current tests are showing a CouchDB payload limit. So a guard was added.

  Returns `:ok`.

  ## Examples

      iex> CouchdbWrapper.bulk_purge_docs(
        "database_name",
        %{
          "id1": ["1-rev1"],
          "id2": ["2-rev"]
        }
      )

      {:ok, %{"id1" => ["2-rev2"], "id2" => ["2-rev2"]}}

  """
  def bulk_purge_docs(_, [rows_to_delete]) when map_size(rows_to_delete) > 1000,
    do: {:error, "Too many rows to delete"}

  def bulk_purge_docs(database, rows_to_delete) do
    post("/#{database}/_purge", rows_to_delete) |> handle_purge_docs()
  end

  defp handle_purge_docs({:ok, %Tesla.Env{status: 201, body: %{"purged" => purged}}}) do
    Logger.debug("Bulk purge completed for #{Enum.count(purged)} elements (batch)")
    {:ok, purged}
  end

  defp handle_purge_docs({:ok, %Tesla.Env{body: body}}) do
    Logger.debug("Bulk purge did not complete: #{inspect(body)}")
    {:error, body}
  end

  @doc ~S"""
  API: `POST /{database}/_compact`
  """
  def compact(database) do
    # FIXME handle result here, result is supposed to be 202
    post("/#{database}/_compact", [])
  end

  @doc ~S"""
  API: `POST /{database}/_compact/{design_doc}`
  """
  def compact(database, design_doc) do
    # FIXME handle result here, result is supposed to be 202
    post("/#{database}/_compact/#{design_doc}", [])
  end

  @doc ~S"""
  API: `POST /{database}/_view_cleanup/`
  """
  def cleanup(database) do
    # FIXME handle result here, result is supposed to be 202
    post("/#{database}/_view_cleanup", [])
  end

  @doc ~S"""
  Loads all doc changes from CouchDB

  API: `GET /{database}/_changes`

  ## Options

    * `:limit` (integer) defaults to 100
    * `:include_docs?` (boolean) - defaults to `true`
    * `:last_seq` (string) - start key for the query (maps to `last-event-id`)

  """
  def changes(database, options \\ [include_docs?: false]) do
    url = build_changes_url(database, options)
    Logger.debug("changes_url: #{url}")

    get(url) |> handle_changes(options)
  end

  defp handle_changes(
         {:ok,
          %Tesla.Env{
            status: 200,
            body: %{
              "results" => rows,
              "last_seq" => last_seq,
              "pending" => pending
            }
          }},
         options
       ) do
    rows
    |> handle_last_page_changes(
      options,
      %Changes{rows: rows, pending: pending, last_seq: last_seq}
    )
  end

  defp handle_changes({:ok, %Tesla.Env{body: body}}, _options),
    do: {:error, %Changes{error: body}}

  defp handle_changes({_, res}, _options), do: {:error, %Changes{error: res}}

  defp handle_last_page_changes([], _, res) do
    Logger.debug("Loaded empty last page single row, total_rows: #{inspect(res)}")
    {:ok, %Changes{}}
  end

  defp handle_last_page_changes(rows, _options, %Changes{} = c) do
    Logger.debug(
      "Loaded changes rows: #{length(rows)} last_seq: #{c.last_seq} pending: #{c.pending}"
    )

    {:ok, %Changes{c | rows: rows, last_seq: c.last_seq, pending: c.pending}}
  end

  defp build_changes_url(database, options) do
    params =
      [
        "limit=#{limit(options)}",
        "include_docs=#{include_docs?(options)}"
      ] ++
        build_key_param("last-event-id", options[:last_seq])

    "/#{database}/_changes?" <> Enum.join(params, "&")
  end

  @doc ~S"""
  Loads all changes from CouchDB, paginating as a stream.

  See `changes/2` for more details.

  """
  def changes_stream(database, options \\ [include_docs?: false]) do
    Stream.resource(
      fn -> {:start, nil} end,
      fn el ->
        # IO.inspect(el, label: "stream.el")
        case el do
          {:start, _} ->
            handle_changes_stream(options, database)

          {ls, pending} when ls != nil and pending > 0 ->
            options
            |> Keyword.put(:last_seq, ls)
            |> handle_changes_stream(database)

          _ ->
            {:halt, el}
        end
      end,
      fn _ -> :ok end
    )
  end

  defp handle_changes_stream(options, database) do
    case changes(database, options) do
      {:ok, %Changes{rows: rows, last_seq: last_seq, pending: pending}} ->
        {rows, {last_seq, pending}}

      {:error, %Changes{error: error}} ->
        Logger.warning("Error loading changes with #{inspect(options)}: #{inspect(error)}")
        {:halt, error}
    end
  end
end
