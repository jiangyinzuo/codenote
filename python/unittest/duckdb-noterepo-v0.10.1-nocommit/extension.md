different between v0.10.1 and v0.10.2

extension/fts/fts_extension.cpp:77
```cpp
extern "C" {

DUCKDB_EXTENSION_API void fts_init(duckdb::DatabaseInstance &db) {
	duckdb::DuckDB db_wrapper(db);
	db_wrapper.LoadExtension<duckdb::FtsExtension>();
}

DUCKDB_EXTENSION_API const char *fts_version() {
	return duckdb::DuckDB::LibraryVersion();
}
}
```

fenced block content does not changed, but linenum in head line has changed between v0.10.1 and v0.10.2

extension/json/buffered_json_reader.cpp:59
```cpp
FileHandle &JSONFileHandle::GetHandle() {
	return *file_handle;
}
```
