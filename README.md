# Code Note

Taking notes on code repositories.

## Configuration

Set these variables in your Vim config:

```vim
" paths should be absolute, and code repo paths should end with /
let g:coderepo_dir = [["duckdb/duckdb", "/path/to/duckdb/"]]
let g:noterepo_dir = "/path/to/note/"
let g:codenote_layout_mode = "tab"  " or: "window"
```

Layout modes:

- `tab` (default): note repo in tab 1, code repos in tabs 2..n
- `window`: note repo in the left window, code repo in the right window, using `:lcd` on each switch and `:vsp` only when there is a single window

## Requirements

- ripgrep
- [vim-quickui](https://github.com/skywind3000/vim-quickui): preview note snippet

## Commands

- `:OpenNoteRepo`: open the note repo in the current layout and initialize code link signs
- `:OpenCodeRepo`: open code repos in the current layout and initialize code link signs
- `:CodenoteRefreshLinks`: rescan notes and refresh code link signs

## Keymaps

- `<leader>ny`: yank current line or visual selection as `pathline + code block`, then jump to the note tab
- `<leader>nl`: yank only the current cursor line as `pathline`, then jump to the note tab
- `<leader><C-]>`: jump between code and note
- `<leader>]`: update the matching code or note buffer to the matched location, while keeping the current cursor and focus in the original buffer
- `<leader>np`: preview the matched note snippet for the current code location

`pathline` format:

```txt
repo_name:path/to/file:start-end
```

## Alternatives

- [quicknote.nvim](https://github.com/RutaTang/quicknote.nvim)
