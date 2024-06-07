from storage.duckdb import DuckDBStorage
from storage.memory import MemoryStore
from storage import Storage, SnippetKey, SnippetValue


def test_db():
    db: Storage
    for db in [MemoryStore(), DuckDBStorage(":memory:")]:
        for i in range(1, 10):
            result = db.insert_snippet(
                repo_name="xxx/fa",
                submodule="llvm",
                git_version="v1.0.0",
                snippet_value=SnippetValue(1, 1, "print('Hello, World!')"),
            )
            assert result == i
            result = db.checkout_snippet(SnippetKey(i, "xxx/fa", "llvm", "v1.0.0"))
            assert result == SnippetValue(1, 1, "print('Hello, World!')")
        db.insert_snippet_with_snippet_id(
            SnippetKey(123, "xxx/fa", "duckdb", "vv"), SnippetValue(2, 2, "int main()")
        )
        result = db.checkout_snippet(SnippetKey(123, "xxx/fa", "duckdb", "v1.0.0"))
        assert result is None
        result = db.checkout_snippet(SnippetKey(123, "xxx/fa", "duckdb", "vv"))
        assert result == SnippetValue(2, 2, "int main()")
        result = db.select_snippet_count()
        assert result == 10
        assert db.select_all_git_versions() == {"v1.0.0", "vv"}
