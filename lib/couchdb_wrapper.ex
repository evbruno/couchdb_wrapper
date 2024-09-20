defmodule CouchdbWrapper.PageResponse do
  defstruct rows: [], next_key: nil, error: nil, total_rows: 0
end

defmodule CouchdbWrapper do
  use Tesla
  require Logger
  alias CouchdbWrapper.PageResponse, as: Response

  @base_url System.get_env("COUCHDB_URL") || "http://localhost:5984/"
  @username System.get_env("COUCHDB_USERNAME") || "admin"
  @password System.get_env("COUCHDB_PASSWORD") || "admin"

  @default_limit 100

  plug(Tesla.Middleware.BaseUrl, @base_url)
  plug(Tesla.Middleware.BasicAuth, username: @username, password: @password)
  plug(Tesla.Middleware.JSON)
  # plug(Tesla.Middleware.Logger)

  @doc ~S"""
  Loads all docs from CouchDB

  API: `/{database}/_all_docs`

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
      %Response{rows: rows, total_rows: total_rows}
    )
  end

  defp handle_all_docs({_op, res}, _options) do
    {:error, %Response{error: res}}
  end

  #  if empty or single row, we are done
  defp handle_last_page_all_docs([], _options, response) do
    Logger.debug("Loaded empty last page single row, total_rows: #{response.total_rows}")
    {:ok, %Response{}}
  end

  defp handle_last_page_all_docs([_], _options, response) do
    Logger.debug("Loaded last page single row, total_rows: #{response.total_rows}")
    {:ok, %Response{}}
  end

  defp handle_last_page_all_docs(rows, options, response) do
    Logger.debug("Loaded all_docs rows: #{length(rows)}")
    ret = Enum.take(rows, limit(options))
    {:ok, %Response{response | rows: ret, next_key: last_key(rows, options)}}
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
      if include_docs?(options) do
        List.last(rows)["doc"]["_id"]
      else
        List.last(rows)["id"]
      end
    else
      nil
    end
  end
end
