different between v0.10.1 and v0.10.2

extension/fts/fts_extension.cpp:81-91 version=v0.10.2 snippet_id=4
```cpp
extern "C" {

DUCKDB_EXTENSION_API void fts_init(duckdb::DatabaseInstance &db) {
	duckdb::DuckDB db_wrapper(db);
	duckdb::LoadInternal(db_wrapper);
}

DUCKDB_EXTENSION_API const char *fts_version() {
	return duckdb::DuckDB::LibraryVersion();
}
}
```

fenced block content does not changed, but linenum in head line has changed between v0.10.1 and v0.10.2

extension/json/buffered_json_reader.cpp:59-61 version=v0.10.1 snippet_id=5
```cpp
FileHandle &JSONFileHandle::GetHandle() {
	return *file_handle;
}
```
