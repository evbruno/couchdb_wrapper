defmodule CouchdbWrapperTest do
  use ExUnit.Case
  import Tesla.Mock
  alias CouchdbWrapper.PageResponse, as: Res

  describe "CouchdbWrapper" do
    test "all_docs/1" do
      {:ok, %Res{} = res} = CouchdbWrapper.all_docs("foo")
      assert res.total_rows == 123
      assert length(res.rows) == 10
      assert res.next_key == nil
    end

    test "all_docs/2 include_docs: false" do
      {:ok, %Res{} = res} = CouchdbWrapper.all_docs("foo", limit: 2, include_docs?: false)
      assert res.total_rows == 123
      assert length(res.rows) == 2
      assert res.next_key == "14d6dfc7a54c2dc1e7244a768a000118"
    end

    test "all_docs/2 include_docs: true" do
      {:ok, %Res{} = res} = CouchdbWrapper.all_docs("foo", limit: 2)
      assert res.total_rows == 123
      assert length(res.rows) == 2
      assert res.next_key == "14d6dfc7a54c2dc1e7244a768a000118"
    end
  end

  setup do
    mock(fn
      %{method: :get, url: "http://localhost:5984/foo/_all_docs?limit=101&include_docs=true"} ->
        json(json_no_docs(101))

      %{method: :get, url: "http://localhost:5984/foo/_all_docs?limit=3&include_docs=false"} ->
        json(json_no_docs(3))

      %{method: :get, url: "http://localhost:5984/foo/_all_docs?limit=3&include_docs=true"} ->
        json(json_docs(3))
    end)

    :ok
  end

  defp json_docs(), do: File.read!("test/fixtures/all_docs_0.json") |> Jason.decode!()

  defp json_docs(limit) do
    j = json_docs()
    Map.put(j, "rows", j["rows"] |> Enum.take(limit))
  end

  defp json_no_docs(), do: File.read!("test/fixtures/all_docs_1.json") |> Jason.decode!()

  defp json_no_docs(limit) do
    j = json_no_docs()
    Map.put(j, "rows", j["rows"] |> Enum.take(limit))
  end
end
