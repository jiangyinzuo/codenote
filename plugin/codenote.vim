command -nargs=0 OpenNoteRepo call codenote#OpenNoteRepo()
command -nargs=0 OpenCodeRepo call codenote#coderepo#OpenCodeRepo()
command -nargs=0 CodenoteRefreshLinks call codenote#codelinks#Init()

" need_beginline, need_endline, append, goto_buf
nnoremap <silent> <leader>ny :call codenote#YankCodeLink(1, 1, 0, 1)<CR>
vnoremap <silent> <leader>ny :call codenote#YankCodeLinkVisual(1, 1, 0, 1)<CR>

" 1) goto code/note link
" 2) put the cursor to center of screen
nnoremap <silent> <leader><C-]> <cmd>call codenote#GoToCodeNoteLink(v:true)<CR>
nnoremap <silent> <leader>p <cmd>call codenote#PreviewNoteSnippet()<CR>
