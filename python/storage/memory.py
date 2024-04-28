from typing import Optional
from . import Storage, SnippetKey, SnippetValue


class MemoryStore(Storage):
    def __init__(self):
        # snippet_id, git_version -> line_num, text
        self.snippets: dict[SnippetKey, SnippetValue] = {}
        self.next_snippet_id = 1

    def insert_snippet(
        self,
        *,
        submodule: str,
        git_version: str,
        snippet_value: SnippetValue,
    ) -> int:
        snippet_id = self.next_snippet_id
        key = SnippetKey(snippet_id, submodule, git_version)
        self.snippets[key] = snippet_value
        self.next_snippet_id += 1
        return snippet_id

    def insert_snippet_with_snippet_id(
        self,
        key: SnippetKey,
        snippet_value: SnippetValue,
    ) -> None:
        if key not in self.snippets:
            self.snippets[key] = snippet_value

    def checkout_snippet(
        self,
        key: SnippetKey,
    ) -> Optional[SnippetValue]:
        return self.snippets.get(key)

    def select_all_snippet_head_lines(self):
        return [
            (key, snippet.line_num_start, snippet.line_num_end)
            for key, snippet in self.snippets.items()
        ]

    def select_snippet_count(self) -> int:
        return len(self.snippets)

    def select_all_git_versions(self) -> set[str]:
        return set(key.git_version for key in self.snippets)

    def select_all(self):
        return self.snippets
