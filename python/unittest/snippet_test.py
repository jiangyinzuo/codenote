from codenote import Snippet


def test_headline():
    table = [
        (
            "/abc/文件-sss_.cpp:12",
            (None, "/abc/文件-sss_.cpp", "12", None, None, None, None, None),
            Snippet.HeadLine("", "/abc/文件-sss_.cpp", 12),
            "/abc/文件-sss_.cpp:12",
        ),
        (
            "/abc/def-sss_.cpp:12",
            (None, "/abc/def-sss_.cpp", "12", None, None, None, None, None),
            Snippet.HeadLine("", "/abc/def-sss_.cpp", 12),
            "/abc/def-sss_.cpp:12",
        ),
        (
            "/abc/def.cpp:12",
            (None, "/abc/def.cpp", "12", None, None, None, None, None),
            Snippet.HeadLine("", "/abc/def.cpp", 12),
            "/abc/def.cpp:12",
        ),
        (
            "/abc/def.cpp:12  ",
            (None, "/abc/def.cpp", "12", None, None, None, None, None),
            Snippet.HeadLine("", "/abc/def.cpp", 12),
            "/abc/def.cpp:12",
        ),
        (
            "/abc/def:12 v0.1.1 33",
            (None, "/abc/def", "12", None, None, None, None, " v0.1.1 33"),
            None,
            "None",
        ),
        (
            "/abc/def:12 v0.1.1 snippet_id=33",
            (None, "/abc/def", "12", None, None, None, None, " v0.1.1 snippet_id=33"),
            None,
            "None",
        ),
        (
            "/abc/def:12-23 v0.1.1  snippet_id=3",
            (None, "/abc/def", "12", "-23", None, None, None, " v0.1.1  snippet_id=3"),
            None,
            "None",
        ),
        (
            "/abc/def:12-23 version=v0.1.1 ",
            (None, "/abc/def", "12", "-23", None, " version=v0.1.1", None, None),
            Snippet.HeadLine("", "/abc/def", 12, line_num_end=23, git_version="v0.1.1"),
            "/abc/def:12-23 version=v0.1.1",
        ),
        (
            "/abc/def:12-23 submodule=llvm  version=18.0",
            (
                None,
                "/abc/def",
                "12",
                "-23",
                " submodule=llvm",
                "  version=18.0",
                None,
                None,
            ),
            Snippet.HeadLine(
                "",
                "/abc/def",
                12,
                line_num_end=23,
                submodule="llvm",
                git_version="18.0",
            ),
            "/abc/def:12-23 submodule=llvm version=18.0",
        ),
        (
            "/abc/def:12-23 submodule=llvm ",
            (None, "/abc/def", "12", "-23", " submodule=llvm", None, None, None),
            Snippet.HeadLine("", "/abc/def", 12, line_num_end=23, submodule="llvm"),
            "/abc/def:12-23 submodule=llvm",
        ),
        (
            "/abc/def:12-23   33    ",
            (None, "/abc/def", "12", "-23", None, None, None, "   33"),
            None,
            "None",
        ),
        (
            "/abc/def:12 version=v0.1.1 nippet_id=33",
            (
                None,
                "/abc/def",
                "12",
                None,
                None,
                " version=v0.1.1",
                None,
                " nippet_id=33",
            ),
            None,
            "None",
        ),
        (
            "/abc/def.h:12 version=v0.1.1 snippet_id=33",
            (
                None,
                "/abc/def.h",
                "12",
                None,
                None,
                " version=v0.1.1",
                " snippet_id=33",
                None,
            ),
            Snippet.HeadLine(
                "",
                "/abc/def.h",
                12,
                line_num_end=None,
                git_version="v0.1.1",
                snippet_id=33,
            ),
            "/abc/def.h:12 version=v0.1.1 snippet_id=33",
        ),
        (
            "/abc/def.h:12    version=v0.1.1       snippet_id=33     ",
            (
                None,
                "/abc/def.h",
                "12",
                None,
                None,
                "    version=v0.1.1",
                "       snippet_id=33",
                None,
            ),
            Snippet.HeadLine(
                "",
                "/abc/def.h",
                12,
                line_num_end=None,
                git_version="v0.1.1",
                snippet_id=33,
            ),
            "/abc/def.h:12 version=v0.1.1 snippet_id=33",
        ),
        # with repo_name
        (
            "duckdb/duckdb:/abc/文件-sss_.cpp:12",
            ("duckdb/duckdb:", "/abc/文件-sss_.cpp", "12", None, None, None, None, None),
            Snippet.HeadLine("duckdb/duckdb", "/abc/文件-sss_.cpp", 12),
            "duckdb/duckdb:/abc/文件-sss_.cpp:12",
        ),
    ]
    for s, expected, expected_headline, expected_str in table:
        result = Snippet.HeadLine.REGEX.match(s.strip())
        assert result is not None
        assert result.groups() == expected, f"invalid: {s}"
        headline = Snippet.HeadLine.from_raw_str(s)
        assert (
            headline == expected_headline
        ), f"{str(headline)}, {str(expected_headline)}"
        assert str(headline) == expected_str
