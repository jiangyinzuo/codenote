import codenote
import pytest
import subprocess
import pathlib
from storage.memory import MemoryStore
from storage.duckdb import DuckDBStorage
from storage import Storage, SnippetKey
import filecmp


class AttrDict:
    def __init__(self, d):
        self.__d = d

    def __getattr__(self, name):
        return self.__d[name]


def checkout_duckdb_version(version):
    result = subprocess.run(
        ["git", "checkout", version], cwd="unittest/duckdb", check=True
    )
    assert result.returncode == 0


def dir_compare(a, b):
    dircmp = filecmp.dircmp(
        a,
        b,
        ignore=["codenote-duckdb.db"],
    )
    print(dircmp.report())
    assert not dircmp.diff_files, f"diff_files: {dircmp.diff_files}"


class TestProcessors:
    @pytest.fixture(scope="class", autouse=True)
    def prepare_duckdb_coderepo(self):
        # if duckdb directory does not exist, clone it
        if not pathlib.Path("unittest/duckdb").exists():
            subprocess.run(["./clone_duckdb.sh"], cwd="unittest", check=True)
        checkout_duckdb_version("v0.10.1")

    def _do_test_processors(self, tmp_path: pathlib.Path, storage: Storage):
        checkout_duckdb_version("v0.10.1")
        # copy 'duckdb-noterepo-v0.10.1' to a temporary directory
        src = pathlib.Path("unittest/duckdb-noterepo-v0.10.1-nocommit")
        tmp_dest = tmp_path / ("duckdb-noterepo-v0.10.1" + storage.name())
        subprocess.run(["cp", "-r", src, tmp_dest], check=True)
        # assert dest has 3 md files
        assert len(list(tmp_dest.glob("*.md"))) == 4
        dir_compare(tmp_dest, "./unittest/duckdb-noterepo-v0.10.1-nocommit")

        repo_name: str = ""
        args_0_10_1 = AttrDict(
            {
                "repo_name": repo_name,
                "submodule": "",
                "commit": "v0.10.1",
                "coderepo": "unittest/duckdb",
                "noterepo": str(tmp_dest),
            },
        )
        assert codenote.validate_current_commit(
            args_0_10_1.coderepo, args_0_10_1.commit
        )
        codenote.SaveToStorageProcessor(
            args_0_10_1,
            storage,
        ).process_files()
        dir_compare(tmp_dest, "./unittest/duckdb-noterepo-v0.10.1-after-saving/")
        assert storage.select_snippet_count() == 6

        args_0_10_2 = AttrDict(
            {
                "repo_name": repo_name,
                "submodule": "",
                "commit": "v0.10.2",
                "coderepo": "unittest/duckdb",
                "noterepo": str(tmp_dest),
            },
        )
        assert not codenote.validate_current_commit(
            args_0_10_2.coderepo, args_0_10_2.commit
        )
        checkout_duckdb_version("v0.10.2")
        assert codenote.validate_current_commit(
            args_0_10_2.coderepo, args_0_10_2.commit
        )

        print(storage.select_all_snippet_head_lines())
        codenote.CheckoutProcessor(args_0_10_2, storage).process_files()
        # database does not contain any v0.10.2 snippet, so equal to v0.10.1-after-saving
        dir_compare(tmp_dest, "./unittest/duckdb-noterepo-v0.10.1-after-saving/")
        assert storage.select_snippet_count() == 6
        print(storage.select_all_snippet_head_lines())
        snippet_value = storage.checkout_snippet(SnippetKey(5, repo_name, "", "v0.10.2"))
        assert snippet_value is None

        codenote.RebaseToCurrentProcessor(args_0_10_2, storage).process_files()
        print(storage.select_all_snippet_head_lines())
        assert storage.select_snippet_count() == 9
        dir_compare(tmp_dest, "./unittest/duckdb-noterepo-v0.10.2")
        snippet_value = storage.checkout_snippet(SnippetKey(5, repo_name, "", "v0.10.2"))
        assert snippet_value is not None
        assert snippet_value.line_num_start == 67
        assert snippet_value.line_num_end == 69

        codenote.CheckoutProcessor(args_0_10_1, storage).process_files()
        dir_compare(tmp_dest, "./unittest/duckdb-noterepo-v0.10.1-after-saving/")

        # check v0.10.2 manual update
        src = pathlib.Path("unittest/duckdb-noterepo-v0.10.2-manual-update")
        tmp_dest = tmp_path / ("duckdb-noterepo-v0.10.2-manual-update" + storage.name())
        args_0_10_1 = AttrDict(
            {
                "repo_name": "",
                "submodule": "",
                "commit": "v0.10.1",
                "coderepo": "unittest/duckdb",
                "noterepo": str(tmp_dest),
            },
        )
        subprocess.run(["cp", "-r", src, tmp_dest], check=True)
        codenote.CheckoutProcessor(args_0_10_1, storage).process_files()
        print(storage.select_all_snippet_head_lines())
        assert storage.select_snippet_count() == 12
        if storage.name() == "MemoryStore":
            text: str = storage.select_all()[SnippetKey(3, repo_name, "", "v0.10.2")].text
            assert text.splitlines() == [
                "```cpp",
                "unique_ptr<FileHandle> HTTPFileSystem::OpenFile(const string &path, FileOpenFlags flags,",
                "                                                optional_ptr<FileOpener> opener) {",
                "\tD_ASSERT(flags.Compression() == FileCompressionType::UNCOMPRESSED);",
                "",
                "\tif (flags.ReturnNullIfNotExists()) {",
                "\t\ttry {",
                "\t\t\tauto handle = CreateHandle(path, flags, opener);",
                "\t\t\thandle->Initialize(opener);",
                "\t\t\treturn std::move(handle);",
                "\t\t} catch (...) {",
                "\t\t\treturn nullptr;",
                "\t\t}",
                "\t}",
                "",
                "\tauto handle = CreateHandle(path, flags, opener);",
                "\thandle->Initialize(opener);",
                "\treturn std::move(handle);",
                "}",
                "```",
            ]
            text: str = storage.select_all()[SnippetKey(3, repo_name, "", "v0.10.1")].text
            assert text.splitlines() == [
                "```cpp",
                "unique_ptr<FileHandle> HTTPFileSystem::OpenFile(const string &path, uint8_t flags, FileLockType lock,",
                "                                                FileCompressionType compression, FileOpener *opener) {",
                "\tD_ASSERT(compression == FileCompressionType::UNCOMPRESSED);",
                "",
                "\tauto handle = CreateHandle(path, flags, lock, compression, opener);",
                "\thandle->Initialize(opener);",
                "\treturn std::move(handle);",
                "}",
                "```",
            ]
        elif storage.name() == "DuckDBStorage":
            print(storage.select_all_snippet_head_lines())

        dir_compare(tmp_dest, "./unittest/duckdb-noterepo-v0.10.1-after-saving/")
        args_0_10_2 = AttrDict(
            {
                "repo_name": repo_name,
                "submodule": "",
                "commit": "v0.10.2",
                "coderepo": "unittest/duckdb",
                "noterepo": str(tmp_dest),
            },
        )
        args_checkout = AttrDict(
            {
                "repo_name": repo_name,
                "submodule": "",
                "commit": "v0.10.1",
                "coderepo": "unittest/duckdb",
                "noterepo": str(tmp_dest),
                "linenum": 20,
                "note_file": str(tmp_dest / "extension.md"),
            }
        )
        for _ in range(3):
            codenote.CheckoutProcessor(args_0_10_2, storage).process_files()
            assert storage.select_snippet_count() == 12
            dir_compare(tmp_dest, "unittest/duckdb-noterepo-v0.10.2-manual-update")
            codenote.CheckoutProcessor(args_0_10_1, storage).process_files()
            assert storage.select_snippet_count() == 12
            dir_compare(tmp_dest, "./unittest/duckdb-noterepo-v0.10.1-after-saving/")
            codenote.CheckoutProcessor(args_0_10_2, storage).process_files()
            assert storage.select_snippet_count() == 12
            dir_compare(tmp_dest, "unittest/duckdb-noterepo-v0.10.2-manual-update")
            codenote.CheckoutProcessor(args_checkout, storage).checkout()
            assert filecmp.cmp("unittest/extension-1.md", args_checkout.note_file)

    def test_processors(self, tmp_path: pathlib.Path):
        for storage in [MemoryStore(), DuckDBStorage(":memory:")]:
            self._do_test_processors(tmp_path, storage)
