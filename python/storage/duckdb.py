import duckdb
from typing import Optional
from . import Storage, SnippetKey, SnippetValue


class DuckDBStorage(Storage):
    def __init__(self, db_path):
        self.con = duckdb.connect(db_path)
        self.con.execute(
            """
CREATE SEQUENCE IF NOT EXISTS snippet_serial;

CREATE TABLE IF NOT EXISTS snippet(
    id INT NOT NULL DEFAULT nextval('snippet_serial'),
    submodule TEXT NOT NULL,
    git_version TEXT NOT NULL,
    line_num_start INT NOT NULL,
    line_num_end INT NOT NULL,
    text TEXT NOT NULL,
    PRIMARY KEY (id, submodule, git_version),
);
            """
        )

    def insert_snippet(
        self,
        *,
        submodule: str,
        git_version: str,
        snippet_value: SnippetValue,
    ) -> int:
        result = self.con.execute(
            """
INSERT INTO snippet(submodule, git_version, line_num_start, line_num_end, text)
    VALUES (?, ?, ?, ?, ?) RETURNING id;
            """,
            [
                submodule,
                git_version,
                snippet_value.line_num_start,
                snippet_value.line_num_end,
                snippet_value.text,
            ],
        ).fetchall()
        return result[0][0]

    def insert_snippet_with_snippet_id(
        self,
        key: SnippetKey,
        snippet_value: SnippetValue,
    ) -> None:
        self.con.execute(
            """
INSERT INTO snippet(id, submodule, git_version, line_num_start, line_num_end, text)
    VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT DO NOTHING;
            """,
            [
                key.snippet_id,
                key.submodule,
                key.git_version,
                snippet_value.line_num_start,
                snippet_value.line_num_end,
                snippet_value.text,
            ],
        )

    def checkout_snippet(
        self,
        key: SnippetKey,
    ) -> Optional[SnippetValue]:
        result = self.con.execute(
            """
SELECT line_num_start, line_num_end, text
FROM snippet WHERE id = ? AND submodule = ? AND git_version = ?;
            """,
            [key.snippet_id, key.submodule, key.git_version],
        ).fetchall()
        if len(result) == 0:
            return None
        assert len(result) == 1, result
        assert len(result[0]) == 3, result
        return SnippetValue(result[0][0], result[0][1], result[0][2])

    def select_all_snippet_head_lines(self):
        result = self.con.sql(
            "SELECT id, submodule, git_version, line_num_start, line_num_end FROM snippet"
        ).fetchall()
        return result

    def select_snippet_count(self) -> int:
        result = self.con.sql("SELECT COUNT(*) FROM snippet").fetchall()
        return result[0][0]

    def select_all(self):
        result = self.con.sql("SELECT * FROM snippet").fetchall()
        return result

    def select_all_git_versions(self) -> set[str]:
        result: list[tuple] = self.con.sql("SELECT DISTINCT git_version FROM snippet").fetchall()
        return set(x[0] for x in result)
