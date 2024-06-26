from abc import ABC, abstractmethod
from typing import Any
from dataclasses import dataclass


@dataclass
class SnippetKey:
    snippet_id: int
    repo_name: str
    submodule: str
    git_version: str

    def __eq__(self, value: object, /) -> bool:
        return (
            isinstance(value, SnippetKey)
            and self.snippet_id == value.snippet_id
            and self.repo_name == value.repo_name
            and self.submodule == value.submodule
            and self.git_version == value.git_version
        )

    def __hash__(self) -> int:
        return hash(f"{self.snippet_id}{self.repo_name}{self.submodule}{self.git_version}")


@dataclass
class SnippetValue:
    line_num_start: int
    line_num_end: int
    text: str


class Storage(ABC):
    @abstractmethod
    def insert_snippet(
        self,
        *,
        repo_name: str,
        submodule: str,
        git_version: str,
        snippet_value: SnippetValue,
    ) -> int:
        pass

    @abstractmethod
    def insert_snippet_with_snippet_id(
        self,
        key: SnippetKey,
        snippet_value: SnippetValue,
    ) -> None:
        pass

    @abstractmethod
    def checkout_snippet(
        self,
        key: SnippetKey,
    ) -> SnippetValue | None:
        pass

    @abstractmethod
    def select_all_snippet_head_lines(self) -> Any:
        pass

    @abstractmethod
    def select_snippet_count(self) -> int:
        pass

    @abstractmethod
    def select_all(self) -> Any:
        pass

    @abstractmethod
    def select_all_git_versions(self) -> set[str]:
        pass

    def name(self) -> str:
        return self.__class__.__name__
