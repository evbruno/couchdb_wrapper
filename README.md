![workflow status](https://github.com/evbruno/couchdb_wrapper/actions/workflows/elixir.yml/badge.svg)

# CouchdbWrapper

## Description

Just a CouchDB wrapper.

_..trying some Elixir stuff.._ 😉 🇧🇷

## Tasks

The main goal for this project is to purge/delete data from CouchDB.

We have a few tools (tasks) for this.

Note: setup env vars to configure the Wrapper:

```bash
$COUCHDB_URL      # defaults to "http://localhost:5984/"
$COUCHDB_USERNAME # defaults to "admin"
$COUCHDB_PASSWORD # defaults to "admin"
```

### Purge deleted documents

Lookup on  `<database>/_changes` where `deleted: true`

```bash
mix purge.changes database_name
```

### Purge ALL documents

```bash
mix purge.docs database_name
```

### Purge SOME documents

We can add extra "predicates" to filter what we want to purge.

```bash
mix purge.docs database_name p1 p2 ...pn
```

Some valid predicates:

  - `doc.age:gt:20` (`doc.age` greater than `20` - a `number`)
  - `doc._id:eq:1234567` (`doc._id` equals to `1234567`)
  - `doc._id:in:1,2,3` (`doc.id` is equal to `1` or `2` or `3`,)
  - `doc.reply_to:exists` (the field `doc.reply_to` exists in the doc)
  
See [the tests](/test/predicate_test.exs) for more examples.

**Note**: the task purge.docs will also call the `/<database>/_compact` and `<database>/_view_cleanup` endpoints once is done.

### Compact/Cleanup documents

It calls `<database>/_compact` and `<database>/_view_cleanup` API.

If `doc1` is provided, it will also call `<database>/_compact/doc1`, `<database>/_compact/doc2`, etc.

```bash
mix purge.clean database_name
```
or

```bash
mix purge.clean database_name doc1 doc2
```

## API Usage

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

## Copy and Pasta

```yaml
# docker compose up
version: '3'
services:
  couchdb:
    image: couchdb:latest
    ports:
      - "5984:5984"
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=admin
    volumes:
      - couchdb_data:/opt/couchdb/data

volumes:
  couchdb_data:
```

Create a bunch of docs

```elixir
# iex -S mix
database = "my-cool-db"
{:ok, _} = CouchdbWrapper.create_database(database)

(
  (1..10_000)
  |> Stream.chunk_every(100)
  |> Stream.each(fn idx -> 
    # we can use index as the document "_id" `%{_id: to_string(i)`
    docs = idx |> Enum.map(fn i -> %{id: to_string(i), index: i, foo: "bar"} end)
    {:ok, _} = CouchdbWrapper.bulk_insert_docs(database, docs)
  end)
  |> Stream.run()
)
```
