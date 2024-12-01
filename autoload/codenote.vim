" vim: set noet:
const s:fd = 'fd'

" sed -i 's/^+\(.*\) \(.*\)$/\2:\1/' *.md
function s:ConvertFormat(line)
	" 使用 substitute() 函数来交换 +linenumber 和 path/to/filename
	let converted = substitute(a:line, '+\(\d\+\) \(.*\)', '\2:\1', '')
	return converted
endfunction

function codenote#check()
	if !exists('g:coderepo_dir') || !exists('g:noterepo_dir')
		echom 'g:coderepo_dir or g:noterepo_dir does not exist!'
		return v:false
	endif
	return v:true
endfunction

" 根据文件名的绝对路径，来判断当前buffer属于coderepo还是noterepo
" return 'code', 'note', or ''
function s:get_repo_type_of_current_buffer()
	if !codenote#check()
		return ''
	endif
	let bufpath = expand('%:p')
	let [coderepo_path, repo_name] = codenote#coderepo#get_path_and_reponame_by_filename(bufpath)
	let prefix_with_coderepo = codenote#coderepo#CommonPrefixLength(bufpath, coderepo_path)
	let prefix_with_noterepo = codenote#coderepo#CommonPrefixLength(bufpath, g:noterepo_dir)
	if prefix_with_coderepo == 0 && prefix_with_noterepo == 0
		return ''
	elseif prefix_with_coderepo < prefix_with_noterepo
		return 'note'
	elseif prefix_with_coderepo > prefix_with_noterepo
		return 'code'
	elseif len(g:noterepo_dir) == prefix_with_noterepo
		return 'note'
	elseif len(coderepo_path) == prefix_with_coderepo
		return 'code'
	endif
endfunction

" 约定第1个tab作为note repo window，第2-n个tab作为code repo window
function s:goto_note_buffer()
	tabfirst
endfunction

function codenote#OpenNoteRepo()
	execute "0tabnew " . g:noterepo_dir
	execute "tcd " . g:noterepo_dir
	call codenote#GetAllCodeLinks()
endfunction

function s:GoToCodeLink()
	let l:cur = line('.')

	" find code link
	let l:cur_line = getline(l:cur)
	while l:cur >= 0 && l:cur_line !~# s:codelink_regex
		let l:cur -= 1
		let l:cur_line = getline(l:cur)
	endwhile

	if l:cur < 0
		echoerr "No code link found"
		return
	endif

	" 支持类似 src/execution/operator/aggregate/physical_hash_aggregate.cpp|478 col 7-32| 的格式
	let l:dest = split(l:cur_line, "[:|]")
	let l:line = '+' . split(l:dest[2])[0]
	let l:file = l:dest[1]
	let l:repo_name = l:dest[0]
	echom l:repo_name l:line l:file

	" switch tab
	call codenote#coderepo#goto_code_buffer(l:repo_name)

	let l:line_start = split(l:line, '-')[0]
	exe "edit " . l:line_start . " " . codenote#coderepo#get_path_by_repo_name(l:repo_name) . "/" . l:file
endfunction

function s:GoToNoteLink(jump_to_note)
	let [path, repo_name] = codenote#coderepo#get_path_and_reponame_by_filename(expand("%:p"))
	let l:file = expand("%:p")[len(path) + 1:]
	let l:line = line(".")
	let l:pattern = s:filepath(repo_name, l:file, l:line)
	" 将 / 转义为 \/
	let l:pattern = substitute(l:pattern, "/", "\\\\/", "g")
	if a:jump_to_note
		if codenote#only_has_one_repo()
			call codenote#OpenNoteRepo()
		else
			call s:goto_note_buffer()
		endif
	endif

	call setqflist([], 'f')
	let l:flag = 'j'
	if a:jump_to_note
		let l:flag = ''
	endif
	silent! exe "vim /" . l:pattern . "/" . l:flag . " " . codenote#coderepo#get_path_by_repo_name(repo_name) . "/**/*.md"
endfunction

function codenote#GoToCodeNoteLink(jump)
	if !codenote#check()
		return
	endif
	let buf_repo_type = s:get_repo_type_of_current_buffer()
	if buf_repo_type == "note"
		call s:GoToCodeLink()
	elseif buf_repo_type == "code"
		call s:GoToNoteLink(a:jump)
	else
		echoerr "current buffer doesn't belong to codenote repo"
	endif
endfunction

function codenote#PreviewNoteSnippet()
	call codenote#GoToCodeNoteLink(v:false)
	let items = getqflist()
	for item in items
		call quickui#preview#open(bufname(item.bufnr), {"cursor": item.lnum, "syntax": "markdown"})
	endfor
endfunction

function codenote#only_has_one_repo()
	return tabpagenr('$') == 1
endfunction

" Supported formats:
" 1) /path/to/file:123
" 2) +123 /path/to/file
" 3) src/execution/operator/aggregate/physical_hash_aggregate.cpp|478 col 7-32|
"
" 3) 是coc.nvim/nvim lsp在quickfix list中的显示格式
let s:codelink_regex = '[A-Za-z0-9\-\+./]\+\([:|][0-9]\+\)\|\(^\+[0-9]\+\s\)'

function! s:filepath(repo_name, file, line_start)
	return a:repo_name . ":" . a:file . ":" . a:line_start
endfunction

function s:yank_registers(repo_name, file, line_start, content, need_beginline, need_endline, append)
	if a:need_beginline && &filetype != 'markdown'
		let l:beginline = "```" . &filetype . "\n"
	else
		let l:beginline = ""
	endif
	if a:need_endline && &filetype != 'markdown'
		let l:endline = "```\n"
	else
		let l:endline = ""
	endif
	let l:line_end = a:line_start + len(a:content->split('\n')) - 1
	let l:filepath = s:filepath(a:repo_name, a:file, a:line_start) . '-' . l:line_end
	if a:append
		let @" .= l:filepath . "\n" . l:beginline . a:content . "\n" . l:endline
		echo "append to @"
	else
		let @" = l:filepath . "\n" . l:beginline . a:content . "\n" . l:endline
	endif
endfunction

function s:yank_code_link(repo_name, file, line, content, need_beginline, need_endline, append, goto_buf)
	call s:yank_registers(a:repo_name, a:file, a:line, a:content, a:need_beginline, a:need_endline, a:append)
	if a:goto_buf
		if codenote#only_has_one_repo()
			call codenote#OpenNoteRepo()
		endif
		call s:goto_note_buffer()
	endif
endfunction
" See also: root/vimrc.d/asynctasks.vim
function codenote#YankCodeLink(need_beginline, need_endline, append, goto_buf)
	let [l:path, l:repo_name] = codenote#coderepo#get_path_and_reponame_by_filename(expand("%:p"))
	let l:file = expand("%:p")[len(l:path):]
	let l:content = getline(".")
	call s:yank_code_link(l:repo_name, l:file, line("."), l:content, a:need_beginline, a:need_endline, a:append, a:goto_buf)
endfunction

function s:GetVisualSelection()
	" https://stackoverflow.com/questions/1533565/how-to-get-visually-selected-text-in-vimscript
	" Why is this not a built-in Vim script function?!
	let [line_start, column_start] = getpos("'<")[1:2]
	let [line_end, column_end] = getpos("'>")[1:2]
	let lines = getline(line_start, line_end)
	if len(lines) == 0
		return ''
	endif
	let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
	let lines[0] = lines[0][column_start - 1:]
	return join(lines, "\n")
endfunction

function codenote#YankCodeLinkVisual(need_beginline, need_endline, append, goto_buf) range
	let [l:path, l:repo_name] = codenote#coderepo#get_path_and_reponame_by_filename(expand("%:p"))
	let l:file = expand("%:p")[len(l:path):]
	let [l:line, l:column_start] = getpos("'<")[1:2]
	let l:content = s:GetVisualSelection()
	call s:yank_code_link(l:repo_name, l:file, l:line, l:content, a:need_beginline, a:need_endline, a:append, a:goto_buf)
endfunction
