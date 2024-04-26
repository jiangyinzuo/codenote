let g:codenote_submodule = get(g:, 'codenote_submodule', '')
command -nargs=0 OpenNoteRepo call codenote#OpenNoteRepo()
command -nargs=0 OpenCodeRepo call codenote#OpenCodeRepo()
command -nargs=0 RefreshCodeLinks call codenote#GetAllCodeLinks()

command -nargs=1 CodenoteCheck call codenote#py#Check(<q-args>)
command -nargs=1 CodenoteCheckout call codenote#py#Checkout(<q-args>)
command -nargs=1 CodenoteCheckoutAll call codenote#py#CheckoutAll(<q-args>)
command -nargs=1 CodenoteRebaseToCurrent call codenote#py#RebaseToCurrent(<q-args>)
command -nargs=1 CodenoteSave call codenote#py#Save(<q-args>)
command -nargs=0 CodenoteShowDB call codenote#py#ShowDB()

" need_beginline, need_endline, append, goto_buf
nnoremap <silent> <leader>ny :call codenote#YankCodeLink(1, 1, 0, 1)<CR>
nnoremap <silent> <leader>nf :call codenote#YankCodeWithFunctionHeader('[f')<CR>


vnoremap <silent> <leader>nf :call codenote#YankCodeWithFunctionHeaderVisual('[f')<CR>
vnoremap <silent> <leader>ny :call codenote#YankCodeLinkVisual(1, 1, 0, 1)<CR>

" 1) goto code/note link
" 2) put the cursor to center of screen
nnoremap <silent> <leader><C-]> :call codenote#GoToCodeNoteLink()<CR>z.
