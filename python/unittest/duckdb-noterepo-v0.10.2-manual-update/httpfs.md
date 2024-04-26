different snippets between v0.10.1 and v0.10.2

extension/httpfs/httpfs.cpp:307-372 version=v0.10.2 snippet_id=2
```cpp
unique_ptr<ResponseWrapper> HTTPFileSystem::GetRangeRequest(FileHandle &handle, string url, HeaderMap header_map,
                                                            idx_t file_offset, char *buffer_out, idx_t buffer_out_len) {
	auto &hfs = handle.Cast<HTTPFileHandle>();
	string path, proto_host_port;
	ParseUrl(url, path, proto_host_port);
	auto headers = initialize_http_headers(header_map);

	// send the Range header to read only subset of file
	string range_expr = "bytes=" + to_string(file_offset) + "-" + to_string(file_offset + buffer_out_len - 1);
	headers->insert(pair<string, string>("Range", range_expr));

	idx_t out_offset = 0;

	std::function<duckdb_httplib_openssl::Result(void)> request([&]() {
		if (hfs.state) {
			hfs.state->get_count++;
		}
		return hfs.http_client->Get(
		    path.c_str(), *headers,
		    [&](const duckdb_httplib_openssl::Response &response) {
			    if (response.status >= 400) {
				    string error = "HTTP GET error on '" + url + "' (HTTP " + to_string(response.status) + ")";
				    if (response.status == 416) {
					    error += " This could mean the file was changed. Try disabling the duckdb http metadata cache "
					             "if enabled, and confirm the server supports range requests.";
				    }
				    throw HTTPException(response, error);
			    }
			    if (response.status < 300) { // done redirecting
				    out_offset = 0;
				    if (response.has_header("Content-Length")) {
					    auto content_length = stoll(response.get_header_value("Content-Length", 0));
					    if ((idx_t)content_length != buffer_out_len) {
						    throw IOException("HTTP GET error: Content-Length from server mismatches requested "
						                      "range, server may not support range requests.");
					    }
				    }
			    }
			    return true;
		    },
		    [&](const char *data, size_t data_length) {
			    if (hfs.state) {
				    hfs.state->total_bytes_received += data_length;
			    }
			    if (buffer_out != nullptr) {
				    if (data_length + out_offset > buffer_out_len) {
					    // As of v0.8.2-dev4424 we might end up here when very big files are served from servers
					    // that returns more data than requested via range header. This is an uncommon but legal
					    // behaviour, so we have to improve logic elsewhere to properly handle this case.

					    // To avoid corruption of memory, we bail out.
					    throw IOException("Server sent back more data than expected, `SET force_download=true` might "
					                      "help in this case");
				    }
				    memcpy(buffer_out + out_offset, data, data_length);
				    out_offset += data_length;
			    }
			    return true;
		    });
	});

	std::function<void(void)> on_retry(
	    [&]() { hfs.http_client = GetClient(hfs.http_params, proto_host_port.c_str()); });

	return RunRequestWithRetry(request, url, "GET Range", hfs.http_params, on_retry);
}
```

same between v0.10.1 and v0.10.2

extension/httpfs/httpfs.cpp:385-402 version=v0.10.2 snippet_id=3
```cpp
unique_ptr<FileHandle> HTTPFileSystem::OpenFile(const string &path, FileOpenFlags flags,
                                                optional_ptr<FileOpener> opener) {
	D_ASSERT(flags.Compression() == FileCompressionType::UNCOMPRESSED);

	if (flags.ReturnNullIfNotExists()) {
		try {
			auto handle = CreateHandle(path, flags, opener);
			handle->Initialize(opener);
			return std::move(handle);
		} catch (...) {
			return nullptr;
		}
	}

	auto handle = CreateHandle(path, flags, opener);
	handle->Initialize(opener);
	return std::move(handle);
}
```
