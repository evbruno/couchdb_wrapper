# CouchdbWrapper

## Description

Just a CouchDB wrapper.

_..trying some Elixir stuff.._ 😉 🇧🇷


## Usage

Loads the docs from database `my_db` with `CouchdbWrapper.all_docs/1` and `CouchdbWrapper.all_docs/2`. 

This is equivalent to a single request to `{database}/_all_docs`.

```elixir
CouchdbWrapper.all_docs("my_db")

{:ok,
 %CouchdbWrapper.PageResponse{
   rows: [
     %{
       "doc" => %{},
      ...
   ],
   next_key: nil,
   error: nil,
   total_rows: 10
 }}
```

... basic arguments are available:

```elixir
{:ok, r} = CouchdbWrapper.all_docs("my_db", limit: 1, start_key: "key1", include_docs?: false)

{:ok,
 %CouchdbWrapper.PageResponse{
   rows: [
     %{
       "id" => "key1",
       "key" => "key1",
       "value" => %{"rev" => "1-a8e1c735ccd4a2f2feac239c7e307aff"}
     }
   ],
   next_key: "key2",
   error: nil,
   total_rows: 10
 }}
```

Build a stream that loads the documents with `CouchdbWrapper.all_docs_stream/1` and `CouchdbWrapper.all_docs_stream/2`. 

```elixir
CouchdbWrapper.all_docs_stream("my_db") |> Stream.drop(1) |> Enum.take(1) |> hd
%{
  "doc" => %{
    "_id" => "key2",
    "_rev" => "1-a8e1c735ccd4a2f2feac239c7e307aff",
    "foo": "bar",
  },
  "id" => "key2",
  "key" => "key2",
  "value" => %{"rev" => "1-a8e1c735ccd4a2f2feac239c7e307aff"}
}
```
