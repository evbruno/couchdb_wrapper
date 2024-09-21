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

    test "all_docs/2 limit: 2, include_docs?: false" do
      {:ok, %Res{} = res} = CouchdbWrapper.all_docs("foo", limit: 2, include_docs?: false)
      assert res.total_rows == 123
      assert length(res.rows) == 2
      assert hd(res.rows)["id"] == "00001"
      assert res.next_key == "00003"
    end

    test "all_docs/2 limit: 2, include_docs?: true" do
      {:ok, %Res{} = res} = CouchdbWrapper.all_docs("foo", limit: 2, include_docs?: true)
      assert res.total_rows == 123
      assert length(res.rows) == 2
      assert hd(res.rows)["id"] == "00001"
      assert res.next_key == "00003"
    end

    test "all_docs/2 mutiple ranges" do
      call_test(1, "00001", "00002")
      call_test(2, "00001", "00003")
      call_test(9, "00001", "00010")
      call_test(10, "00001", nil)
    end

    test "all_docs/2 paginate w/ start_key" do
      call_test(1, "00002", "00003", "00001")
      call_test(2, "00002", "00004", "00001")
      call_test(8, "00002", "00010", "00001")
      call_test(9, "00002", nil, "00001")
    end
  end

  defp call_test(limit, expected_id, expected_next_key, start_key \\ "") do
    [true, false]
    |> Enum.each(fn include_docs? ->
      opts =
        [limit: limit, include_docs?: include_docs?] ++
          if start_key != "", do: [start_key: start_key], else: []

      {:ok, %Res{} = res} = CouchdbWrapper.all_docs("foo", opts)
      assert res.total_rows == 123
      assert length(res.rows) == limit
      assert hd(res.rows)["id"] == expected_id
      assert res.next_key == expected_next_key
    end)
  end

  setup do
    all_docs_reg =
      ~r/^http:\/\/localhost:5984\/foo\/_all_docs\?limit\=(?<limit>\d+)&include_docs=(?<inc>true|false)(&startkey=%22(?<sk>\w+)%22)?$/

    mock(fn
      %{
        method: :get,
        url: <<"http://localhost:5984/foo/_all_docs?limit=", _rest::bitstring>> = url0
      } ->
        capture = Regex.named_captures(all_docs_reg, url0)
        %{"limit" => l, "inc" => i, "sk" => k} = capture

        case i do
          "true" -> json_docs(String.to_integer(l), k)
          "false" -> json_no_docs(String.to_integer(l), k)
        end
        |> json()
    end)

    :ok
  end

  defp json_docs(), do: File.read!("test/fixtures/all_docs_0.json") |> Jason.decode!()

  defp json_docs(limit, start) do
    doc = json_docs()

    rows =
      case start do
        nil -> doc["rows"]
        _ -> doc["rows"] |> Enum.drop_while(fn x -> x["id"] == start end)
      end
      |> Enum.take(limit)

    Map.put(doc, "rows", rows)
  end

  defp json_no_docs(), do: File.read!("test/fixtures/all_docs_1.json") |> Jason.decode!()

  defp json_no_docs(limit, start) do
    doc = json_no_docs()

    rows =
      case start do
        nil -> doc["rows"]
        _ -> doc["rows"] |> Enum.drop_while(fn x -> x["id"] == start end)
      end
      |> Enum.take(limit)

    Map.put(doc, "rows", rows)
  end
end
