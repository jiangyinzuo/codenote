let g:codenote_submodule = get(g:, 'codenote_submodule', '')
command -nargs=0 OpenNoteRepo call codenote#OpenNoteRepo()
command -nargs=0 OpenCodeRepo call codenote#OpenCodeRepo()
command -nargs=0 RefreshCodeLinks call codenote#GetAllCodeLinks()

command -nargs=1 CodenoteCheck call codenote#py#Check(<q-args>)
command -nargs=0 CodenoteCheckHEAD call codenote#py#Check(codenote#py#GetCodeRepoCommit())
command -nargs=1 CodenoteCheckout call codenote#py#Checkout(<q-args>)
command -nargs=0 CodenoteCheckoutHEAD call codenote#py#Checkout(codenote#py#GetCodeRepoCommit())
command -nargs=1 CodenoteCheckoutAll call codenote#py#CheckoutAll(<q-args>)
command -nargs=0 CodenoteCheckoutAllHEAD call codenote#py#CheckoutAll(codenote#py#GetCodeRepoCommit())
command -nargs=0 CodenoteRebaseToHEAD call codenote#py#RebaseToCurrent(codenote#py#GetCodeRepoCommit())
command -nargs=0 CodenoteSaveAllHEAD call codenote#py#Save(codenote#py#GetCodeRepoCommit(), '')
command -nargs=0 CodenoteSaveCurrentFileHEAD call codenote#py#Save(codenote#py#GetCodeRepoCommit(), expand('%:p'))
command -nargs=0 CodenoteShowDB call codenote#py#ShowDB()

if exists(':Git') > 0
	function s:GitLog(mods)
		let output = codenote#py#GetAllCommits()
		if v:shell_error
			echoerr output
			return
		endif
		if codenote#only_has_one_repo()
			tabnew
			exe 'tcd ' . g:coderepo_dir
		else
			tabnext 2
		endif
		exe a:mods . ' Git log --oneline --no-walk ' . output
	endfunction
	command -nargs=0 CodenoteShowCommits call s:GitLog(<q-mods>)
endif

" need_beginline, need_endline, append, goto_buf
nnoremap <silent> <leader>ny :call codenote#YankCodeLink(1, 1, 0, 1)<CR>
nnoremap <silent> <leader>nf :call codenote#YankCodeWithFunctionHeader('[f')<CR>


vnoremap <silent> <leader>nf :call codenote#YankCodeWithFunctionHeaderVisual('[f')<CR>
vnoremap <silent> <leader>ny :call codenote#YankCodeLinkVisual(1, 1, 0, 1)<CR>

" 1) goto code/note link
" 2) put the cursor to center of screen
nnoremap <silent> <leader><C-]> <cmd>call codenote#GoToCodeNoteLink(v:true)<CR>z.
nnoremap <silent> <leader>p <cmd>call codenote#PreviewNoteSnippet()<CR>
