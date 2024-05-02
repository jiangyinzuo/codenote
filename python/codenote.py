from typing import Optional, Any
import pathlib
import re
from storage.duckdb import DuckDBStorage
from storage import SnippetKey, Storage, SnippetValue
from abc import ABC, abstractmethod
import subprocess


def diff_strs(a: list[str], b: list[str]) -> str:
    import difflib

    diff = difflib.unified_diff(a, b)
    return "\n".join(diff)


class FileCache:
    class CacheItem:
        def __init__(self, content):
            self.content: list[str] = content

    def __init__(self):
        self.cache: dict[str, FileCache.CacheItem] = {}

    def get_file_content(self, filename) -> list[str]:
        if filename in self.cache:
            return self.cache[filename].content
        else:
            with open(filename, "r") as f:
                content = f.readlines()
            self.cache[filename] = FileCache.CacheItem(content)
            return content

    def clear_all(self):
        self.cache.clear()


def find_all_sublist_indexes(sublist, mainlist) -> list[tuple[int, int]]:
    if not sublist:  # 空列表是任何列表的子列表
        return [(0, 0)]
    if len(sublist) > len(mainlist):
        return []  # 子列表长度大于主列表，不可能是子列表

    results = []
    main_index: int = 0
    sublist_index = 0
    start_index: Optional[int] = None

    while main_index < len(mainlist):
        if sublist[sublist_index] == mainlist[main_index]:
            if start_index is None:
                start_index = main_index  # 记录起始位置
            sublist_index += 1
            if sublist_index == len(sublist):  # 所有元素都匹配了
                results.append((start_index, main_index))
                # 重置开始查找新的可能匹配
                sublist_index = 0
                main_index = start_index + 1  # 从当前匹配的下一个位置开始新的搜索
                start_index = None
        else:
            # 如果之前有匹配开始但未完成，则重置
            if sublist_index > 0:
                assert start_index is not None
                main_index = start_index  # 回溯到起始匹配点后的下一个点重新开始
                sublist_index = 0
                start_index = None
        main_index += 1

    return results


def _line_end(file_content: list, line_start):
    for i, line in enumerate(file_content[line_start:]):
        if line == "```\n":
            return line_start + i
    raise ValueError(f"No end of code block found. {file_content}")


class Snippet:

    class HeadLine:
        """
        Parse snippet head line.

        format:
            <code_file>:<line_num_start>(-<line_num_end>)? (submodule=<path>)? (version=<commit>)? (snippet_id=<snippet_id>)?

        """

        _STR_PATTERN = r"[\w\d\-./]+"
        PATTERN = rf"^({_STR_PATTERN}):([0-9]+)(-[0-9]+)?(\s+submodule={_STR_PATTERN})?(\s+version={_STR_PATTERN})?(\s+snippet_id=[0-9]+)?(.+)?"
        REGEX = re.compile(PATTERN)

        def __init__(
            self,
            code_file: str,
            line_num_start: int,
            *,
            line_num_end=None,
            submodule: str = "",
            git_version=None,
            snippet_id=None,
        ):
            self.code_file = code_file
            self.line_num_start = line_num_start
            self.line_num_end: Optional[int] = line_num_end
            if self.line_num_end is not None:
                assert self.line_num_start <= self.line_num_end
            self.submodule: str = submodule
            self.git_version: Optional[str] = git_version
            self.snippet_id: Optional[int] = snippet_id
            if self.git_version is None:
                assert self.snippet_id is None

        @staticmethod
        def from_raw_str(s: str) -> Optional[Any]:
            result = Snippet.HeadLine.REGEX.match(s.strip())
            assert result is not None
            assert len(result.groups()) == 7
            if result.group(7) is not None and len(result.group(7).strip()) > 0:
                return None
            code_file = result.group(1)
            line_num_start = int(result.group(2))
            # remove -
            line_num_end = (
                int(result.group(3)[1:]) if result.group(3) is not None else None
            )

            def _parse_str_item(group: Optional[str], key: str, default):
                return group.strip()[len(f"{key}=") :] if group is not None else default

            submodule: str = _parse_str_item(result.group(4), "submodule", "")
            git_version = _parse_str_item(result.group(5), "version", None)
            snippet_id = (
                int(result.group(6).strip()[len("snippet_id=") :])
                if result.group(6) is not None
                else None
            )
            return Snippet.HeadLine(
                code_file,
                line_num_start,
                line_num_end=line_num_end,
                submodule=submodule,
                git_version=git_version,
                snippet_id=snippet_id,
            )

        def __eq__(self, value, /) -> bool:
            return (
                isinstance(value, Snippet.HeadLine)
                and self.code_file == value.code_file
                and self.line_num_start == value.line_num_start
                and self.line_num_end == value.line_num_end
                and self.submodule == value.submodule
                and self.git_version == value.git_version
                and self.snippet_id == value.snippet_id
            )

        @staticmethod
        def to_str(
            code_file: str,
            line_num_start: int,
            line_num_end: Optional[int],
            submodule: str,
            git_version: Optional[str],
            snippet_id: Optional[int],
        ) -> str:
            s = f"{code_file}:{line_num_start}"
            if line_num_end is not None:
                s += f"-{line_num_end}"
            if len(submodule) > 0:
                s += f" submodule={submodule}"
            if git_version is not None and len(git_version) > 0:
                s += f" version={git_version}"
            if snippet_id is not None:
                s += f" snippet_id={snippet_id}"
            return s

        def __str__(self) -> str:
            return Snippet.HeadLine.to_str(
                self.code_file,
                self.line_num_start,
                self.line_num_end,
                self.submodule,
                self.git_version,
                self.snippet_id,
            )

    def __init__(
        self,
        snippet_head_line: str,
        coderepo: str,
        note_file_content: list[str],
        snippet_head_line_num: int,
    ):
        self.file_cache = FileCache()
        if (head_line := Snippet.HeadLine.from_raw_str(snippet_head_line)) is None:
            print(f"ERROR: Invalid head_line: {snippet_head_line}")
            exit(1)
        self.head_line: Snippet.HeadLine = head_line

        # self.snippet_head_line = snippet_head_line
        # line_list = snippet_head_line.split()
        # assert 1 <= len(line_list) <= 3, "Invalid line format."
        # filepath = line_list[0]
        # if len(line_list) >= 2:
        #     self.commit = line_list[1]
        # else:
        #     self.commit = ""
        # if len(line_list) >= 3:
        #     self.snippet_id: Optional[int] = int(line_list[2][len("snippet_id=") :])
        # else:
        #     self.snippet_id: Optional[int] = None
        # self.code_file, code_line_num = filepath.split(":")
        self.coderepo = coderepo

        snippet_head_line_idx = snippet_head_line_num - 1
        note_fenced_block_start_idx = snippet_head_line_idx + 1
        self.note_fenced_block_end_idx = _line_end(
            note_file_content, note_fenced_block_start_idx
        )
        assert (
            note_fenced_block_start_idx <= self.note_fenced_block_end_idx
        ), "Invalid note line range."

        # block outer content includes 2 ```.
        # each str is ended with '\n'
        self.fenced_block_outer_content = note_file_content[
            note_fenced_block_start_idx : self.note_fenced_block_end_idx + 1
        ]
        self.check_fenced_block_outer_content()

        # self.code_line_num = int(code_line_num)
        # code_line_start_idx = self.code_line_num - 1
        code_line_start_idx = self.head_line.line_num_start - 1
        # minus 2 ```
        code_line_end_idx = (
            self.note_fenced_block_end_idx
            - note_fenced_block_start_idx
            + code_line_start_idx
            - 2
        )
        if self.head_line.line_num_end is None:
            self.head_line.line_num_end = code_line_end_idx + 1
        else:
            assert (
                code_line_end_idx == self.head_line.line_num_end - 1
            ), f"Inconsistent line_num_end {self.head_line}"
        assert code_line_start_idx <= code_line_end_idx, "Invalid code line range."
        self.code_content = self.file_cache.get_file_content(self.absolute_code_file)[
            code_line_start_idx : code_line_end_idx + 1
        ]
        assert len(self.fenced_block_inner_content) == len(
            self.code_content
        ), f"""Inconsistent code and note content: {len(self.fenced_block_inner_content)}, {len(self.code_content)}
            {self.fenced_block_outer_content}
            {self.fenced_block_inner_content}
            {self.code_content}
            """

    def check_fenced_block_outer_content(self):
        assert self.fenced_block_outer_content[0].startswith(
            "```"
        ), f"""Invalid fenced block:
            {self.fenced_block_outer_content}
            """
        assert (
            self.fenced_block_outer_content[-1] == "```\n"
        ), f"""Invalid fenced block:
        {self.fenced_block_outer_content}
            """

    def get_new_note_snippet_from_coderepo(
        self, new_commit: str
    ) -> Optional[tuple[list[str], int, int]]:
        if self.fenced_block_inner_content == self.code_content:
            assert self.head_line.line_num_end is not None
            return (
                self._get_note_snippet(
                    self.head_line.line_num_start,
                    self.head_line.line_num_end,
                    new_commit,
                    self.head_line.snippet_id,
                ),
                self.head_line.line_num_start,
                self.head_line.line_num_end,
            )
        indexes = find_all_sublist_indexes(
            self.fenced_block_inner_content,
            self.file_cache.get_file_content(self.absolute_code_file),
        )
        if len(indexes) == 1:
            new_line_start, new_line_end = indexes[0][0] + 1, indexes[0][1] + 1
            return (
                self._get_note_snippet(
                    new_line_start, new_line_end, new_commit, self.head_line.snippet_id
                ),
                new_line_start,
                new_line_end,
            )
        return None

    def _get_note_snippet(
        self,
        line_num_start: int,
        line_num_end: Optional[int],
        git_version: Optional[str],
        snippet_id: Optional[int],
    ) -> list[str]:
        return [
            Snippet.HeadLine.to_str(
                self.head_line.code_file,
                line_num_start,
                line_num_end,
                self.head_line.submodule,
                git_version,
                snippet_id,
            )
            + "\n"
        ] + self.fenced_block_outer_content

    @property
    def note_snippet(self) -> list[str]:
        return self._get_note_snippet(
            self.head_line.line_num_start,
            self.head_line.line_num_end,
            self.head_line.git_version,
            self.head_line.snippet_id,
        )

    @property
    def fenced_block_inner_content(self) -> list[str]:
        return self.fenced_block_outer_content[1:-1]

    @property
    def absolute_code_file(self) -> str:
        return f"{self.coderepo}/{self.head_line.code_file}"

    def save_unstaged_to_storage(self, storage: Storage):
        assert (
            self.head_line.git_version is not None
            and len(self.head_line.git_version) > 0
        ), "Commit not set."
        assert (
            self.head_line.snippet_id is None
        ), f"Snippet id already set. {self.head_line.snippet_id}"
        assert self.head_line.line_num_end is not None, f"line_num_end is None."
        self.head_line.snippet_id = storage.insert_snippet(
            submodule=self.head_line.submodule,
            git_version=self.head_line.git_version,
            snippet_value=SnippetValue(
                self.head_line.line_num_start,
                self.head_line.line_num_end,
                "".join(self.fenced_block_outer_content),
            ),
        )
        assert self.head_line.snippet_id is not None, "Snippet id not set."

    def save_edited_manually_to_storage(self, storage: Storage):
        assert (
            self.head_line.git_version is not None
            and len(self.head_line.git_version) > 0
        ), "Commit not set."
        assert self.head_line.snippet_id is not None, "Snippet id not set."
        assert self.head_line.line_num_end is not None
        self.check_fenced_block_outer_content()
        storage.insert_snippet_with_snippet_id(
            SnippetKey(
                self.head_line.snippet_id,
                self.head_line.submodule,
                self.head_line.git_version,
            ),
            SnippetValue(
                self.head_line.line_num_start,
                self.head_line.line_num_end,
                "".join(self.fenced_block_outer_content),
            ),
        )


class ParseLineProcessor(ABC):

    def __init__(self, args, storage: Storage):
        self.args = args
        self.storage = storage
        self._current_md_file: Optional[pathlib.Path] = None

    def execute(self, mdfile_content) -> Optional[list[str]]:
        i = 0
        new_content = []
        matched = False
        while i < len(mdfile_content):
            snippet_head_line = mdfile_content[i]
            match = Snippet.HeadLine.REGEX.match(snippet_head_line)
            if match:
                matched = True
                snippet = Snippet(
                    snippet_head_line,
                    self.args.coderepo,
                    mdfile_content,
                    i + 1,
                )
                i = self.update_new_content(snippet, new_content, i)
            else:
                new_content.append(snippet_head_line)
                i += 1
        if matched:
            return new_content
        else:
            return None

    def process_files(self):
        # glob all markdown files in noterepo
        for mdfile in pathlib.Path(self.args.noterepo).rglob("*.md"):
            self.process_file(mdfile)

    def process_file(self, mdfile: pathlib.Path):
        self._current_md_file = mdfile
        with open(mdfile, "r+") as f:
            content = f.readlines()
            new_content = self.execute(content)
            if new_content is not None:
                f.seek(0)
                f.writelines(new_content)
                f.truncate()
        self._current_md_file = None

    @abstractmethod
    def update_new_content(self, snippet: Snippet, new_content: list, i: int) -> int:
        """
        i: current line index, start from 0
        """
        pass


class SaveToStorageProcessor(ParseLineProcessor):
    """
    Allocate snippet_id for snippet that does not have one.
    """

    def __init__(self, args, storage):
        super().__init__(args, storage)
        self.vim_quickfix_list = []

    def update_new_content(self, snippet: Snippet, new_content: list, i: int) -> int:
        if snippet.code_content == snippet.fenced_block_inner_content:
            if len(snippet.head_line.submodule) == 0:
                snippet.head_line.submodule = self.args.submodule
            if snippet.head_line.git_version is None:
                snippet.head_line.git_version = self.args.commit
            if snippet.head_line.snippet_id is None:
                snippet.save_unstaged_to_storage(self.storage)
        else:
            self.vim_quickfix_list.append(
                f"{self._current_md_file}:{i+1}: {str(snippet.head_line)}"
            )
        note_snippet = snippet.note_snippet
        new_content.extend(note_snippet)
        assert i + len(note_snippet) == snippet.note_fenced_block_end_idx + 1
        i += len(note_snippet)
        return i


class RebaseToCurrentProcessor(ParseLineProcessor):
    pattern = r"^[\w\d\-./]+:[0-9]+"
    regex = re.compile(pattern)

    def update_new_content(self, snippet: Snippet, new_content: list, i: int) -> int:
        if snippet.head_line.snippet_id is None and snippet.head_line.git_version is not None:
            snippet.save_unstaged_to_storage(self.storage)
        maybe_result = snippet.get_new_note_snippet_from_coderepo(self.args.commit)
        if maybe_result is not None:
            note_snippet, new_head_line_num_start, new_head_line_num_end = maybe_result
            new_content.extend(note_snippet)
            assert (
                i + len(note_snippet) == snippet.note_fenced_block_end_idx + 1
            ), f"""
            {i}, {len(note_snippet)}, {snippet.note_fenced_block_end_idx}
            {note_snippet}
            """
            i += len(note_snippet)

            # save new snippet to storage
            if snippet.head_line.snippet_id is not None and snippet.head_line.line_num_end is not None:
                self.storage.insert_snippet_with_snippet_id(
                    SnippetKey(
                        snippet.head_line.snippet_id,
                        self.args.submodule,
                        self.args.commit,
                    ),
                    SnippetValue(
                        new_head_line_num_start,
                        new_head_line_num_end,
                        "".join(snippet.fenced_block_outer_content),
                    ),
                )
        else:
            note_snippet = snippet.note_snippet
            new_content.extend(note_snippet)
            assert i + len(note_snippet) == snippet.note_fenced_block_end_idx + 1
            i += len(note_snippet)
        return i


def check_consistency(args):
    vim_quickfix_list = []
    commit: str = args.commit
    # glob all markdown files in noterepo
    for mdfile in pathlib.Path(args.noterepo).rglob("*.md"):
        with open(mdfile, "r") as f:
            mdfile_content = f.readlines()
            i = 0
            while i < len(mdfile_content):
                snippet_head_line = mdfile_content[i]
                match = Snippet.HeadLine.REGEX.match(snippet_head_line)
                if match:
                    snippet = Snippet(
                        snippet_head_line,
                        args.coderepo,
                        mdfile_content,
                        i + 1,
                    )
                    note_snippet = snippet.note_snippet
                    maybe_result = snippet.get_new_note_snippet_from_coderepo(commit)
                    if maybe_result is None or note_snippet != maybe_result[0]:
                        vim_quickfix_list.append(
                            f"{mdfile}:{i+1}: {str(snippet.head_line)}"
                        )
                    i += len(note_snippet)
                else:
                    i += 1


class CheckoutProcessor(ParseLineProcessor):
    def update_new_content(self, snippet: Snippet, new_content: list, i: int) -> int:
        # old snippet that is edited manually may have not been saved to storage
        snippet.save_edited_manually_to_storage(self.storage)
        # bump the old note_snippet instead the new one
        old_snippet_len = len(snippet.note_snippet)
        i += old_snippet_len
        old_snippet_note_fenced_block_end_idx = snippet.note_fenced_block_end_idx
        if snippet.head_line.snippet_id is not None:
            checkout_commit = self.args.commit
            assert checkout_commit is not None, "New commit not set."
            # remain '\n' in the end of each line
            maybe_fenced_block_outer_content: Optional[SnippetValue] = (
                self.storage.checkout_snippet(
                    SnippetKey(
                        snippet.head_line.snippet_id,
                        self.args.submodule,
                        checkout_commit,
                    )
                )
            )
            if maybe_fenced_block_outer_content is not None:
                # update code_line_num, commit and fenced_block_outer_content for the new note snippet
                snippet.head_line.line_num_start = (
                    maybe_fenced_block_outer_content.line_num_start
                )
                snippet.head_line.line_num_end = (
                    maybe_fenced_block_outer_content.line_num_end
                )
                snippet.head_line.git_version = checkout_commit
                snippet.fenced_block_outer_content = (
                    maybe_fenced_block_outer_content.text.splitlines(keepends=True)
                )
            snippet.check_fenced_block_outer_content()

        note_snippet = snippet.note_snippet
        new_content.extend(note_snippet)
        assert (
            i == old_snippet_note_fenced_block_end_idx + 1
        ), f"""
        {i}, {old_snippet_len}, {old_snippet_note_fenced_block_end_idx}
        {note_snippet}
        """

        return i

    def checkout(self):
        with open(self.args.note_file, "r+") as f:
            content: list[str] = f.readlines()
            snippet_head_line_num = self.args.linenum
            snippet_head_line_idx = snippet_head_line_num - 1
            snippet_head_line: str = content[snippet_head_line_idx]
            if Snippet.HeadLine.REGEX.match(snippet_head_line) is None:
                print(f"Invalid snippet head line: {snippet_head_line}")
                return
            snippet = Snippet(
                snippet_head_line,
                self.args.coderepo,
                content,
                snippet_head_line_num,
            )
            new_content = content[:snippet_head_line_idx]
            i = self.update_new_content(snippet, new_content, snippet_head_line_idx)
            new_content.extend(content[i:])
            f.seek(0)
            f.writelines(new_content)
            f.truncate()


def get_commit_hash(ref, repo_path):
    try:
        # 将给定的ref（HEAD, tag, 或 commit hash）解析为commit hash
        output = subprocess.check_output(["git", "rev-parse", ref], cwd=repo_path)
        return output.strip().decode("utf-8")
    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")
        return None


def validate_current_commit(
    repo_path: str, input_ref: str, submodule: str = ""
) -> bool:
    if len(submodule) > 0:
        repo_path = str(pathlib.Path(repo_path) / submodule)
    head_hash = get_commit_hash("HEAD", repo_path)
    input_hash = get_commit_hash(input_ref, repo_path)

    if input_hash is not None and head_hash is not None:
        if head_hash == input_hash:
            return True
        else:
            print(
                f"""
The input reference '{input_ref}' does not match the current HEAD. Current HEAD is at {head_hash}
Run:

    cd {repo_path}
    git checkout {input_ref}

first.
                """
            )
    else:
        print("Failed to retrieve commit hashes.")
    return False


def parse_args():
    import argparse

    parser = argparse.ArgumentParser(
        description="Check differences between coderepo and noterepo."
    )
    parser.add_argument("--noterepo", required=True)
    parser.add_argument("--submodule", default="")

    subparsers = parser.add_subparsers(dest="command", help="Available subcommands")

    save_to_storage_parser = subparsers.add_parser(
        "save", help="Add line_num_end, commit, snippet_id to note and save to storage."
    )
    save_to_storage_parser.add_argument("--commit", help="Commit hash.", required=True)
    save_to_storage_parser.add_argument("--coderepo", required=True)
    save_to_storage_parser.add_argument("--note-file", dest="note_file")

    rebase_parser = subparsers.add_parser(
        "rebase", help="Rebase to current coderepo commit."
    )
    rebase_parser.add_argument("--commit", help="Commit hash.", required=True)
    rebase_parser.add_argument("--coderepo", required=True)

    check_parser = subparsers.add_parser(
        "check",
        help="Check consistency of current commit between noterepo and coderepo.",
    )
    check_parser.add_argument("--commit", help="Commit hash.", required=True)
    check_parser.add_argument("--coderepo", required=True)

    checkout_parser = subparsers.add_parser(
        "checkout", help="Checkout a snippet to the given commit if exists."
    )
    checkout_parser.add_argument("--commit", help="Commit hash.", required=True)
    checkout_parser.add_argument(
        "--linenum",
        help="Line Number of the snippet header",
        type=int,
        required=True,
    )
    checkout_parser.add_argument("--coderepo", required=True)
    checkout_parser.add_argument("--note-file", dest="note_file", required=True)

    checkout_all_parser = subparsers.add_parser(
        "checkout-all", help="Checkout all snippets to the given commit if exists."
    )
    checkout_all_parser.add_argument("--commit", help="Commit hash.", required=True)
    checkout_all_parser.add_argument("--coderepo", required=True)

    subparsers.add_parser("show-db", help="Show database content.")
    subparsers.add_parser("show-commits", help="Show commits.")
    return parser.parse_args()


def main():
    args = parse_args()
    storage = DuckDBStorage(f"{args.noterepo}/codenote-duckdb.db")
    match args.command:
        case "save":
            if validate_current_commit(args.coderepo, args.commit, args.submodule):
                processor = SaveToStorageProcessor(args, storage)
                if args.note_file is not None:
                    processor.process_file(args.note_file)
                else:
                    processor.process_files()
                for qf in processor.vim_quickfix_list:
                    print(qf)
        case "rebase":
            if validate_current_commit(args.coderepo, args.commit, args.submodule):
                RebaseToCurrentProcessor(args, storage).process_files()
        case "check":
            if validate_current_commit(args.coderepo, args.commit, args.submodule):
                check_consistency(args)
        case "checkout":
            CheckoutProcessor(args, storage).checkout()
        case "checkout-all":
            CheckoutProcessor(args, storage).process_files()
        case "show-db":
            print(storage.select_all_snippet_head_lines())
        case "show-commits":
            for commits in storage.select_all_git_versions():
                print(commits, end=' ')
        case _:
            raise NotImplementedError()


if __name__ == "__main__":
    main()
