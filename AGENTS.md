# AGENTS.md

## Project Summary

`codenote` is a small Vim plugin for linking source code locations to Markdown notes.

The repository is intentionally minimal:

- [`plugin/codenote.vim`](/root/plugged/codenote/plugin/codenote.vim): user commands and keymaps
- [`autoload/codenote.vim`](/root/plugged/codenote/autoload/codenote.vim): main navigation and yank logic
- [`autoload/codenote/coderepo.vim`](/root/plugged/codenote/autoload/codenote/coderepo.vim): code repo detection and tab management
- [`autoload/codenote/codelinks.vim`](/root/plugged/codenote/autoload/codenote/codelinks.vim): note link indexing and sign placement
- [`doc/codenote.txt`](/root/plugged/codenote/doc/codenote.txt): help text

## Configuration Contract

This plugin depends on two globals being set by the user:

```vim
let g:coderepo_dir = [["repo/name", "/abs/path/to/code/"]]
let g:noterepo_dir = "/abs/path/to/notes/"
```

Important assumptions:

- Code repo paths should end with `/`
- Note repo is a directory containing Markdown files
- `g:coderepo_dir` is a list of `[repo_name, path]`
- The plugin uses `ripgrep` via `rg`

## Core Behavior

The canonical link format is:

```txt
repo_name:path/to/file:start-end
```

Main workflows:

- From code buffers, yank a pathline or pathline plus code snippet
- From code buffers, jump to matching Markdown notes
- From note buffers, jump back to code
- Scan notes for code links and place signs in matching code buffers

## Editing Guidelines

When changing behavior, preserve these conventions unless the task explicitly requires otherwise:

- Keep `plugin/` thin; put logic in `autoload/`
- Reuse `codenote#coderepo#get_path_and_reponame_by_filename()` for repo resolution
- Preserve existing tab model:
  - tab 1 is the note repo
  - tabs 2..n are code repos
- Keep link generation consistent with `repo:file:start-end`
- Avoid adding hard dependencies beyond Vim, `rg`, and the optional `vim-quickui`

## Validation

There is no formal test suite in this repository.

For changes, prefer lightweight validation:

- Read the diff for `plugin/` and `autoload/` call flow consistency
- Check that exported function names and mappings match exactly
- If updating docs or mappings, keep `README.md`, `doc/codenote.txt`, and `plugin/codenote.vim` aligned when relevant

Manual runtime checks in Vim are the primary verification method for behavior changes.

## Documentation Expectations

If you add a user-facing command, keymap, or config requirement:

- update [`plugin/codenote.vim`](/root/plugged/codenote/plugin/codenote.vim) or the relevant autoload file
- document the behavior in [`doc/codenote.txt`](/root/plugged/codenote/doc/codenote.txt)
- update [`README.md`](/root/plugged/codenote/README.md) if the change affects installation, usage, or dependencies
