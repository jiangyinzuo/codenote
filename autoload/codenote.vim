let s:fd = 'fd'
let g:codenote_submodule = get(g:, 'codenote_submodule', '')

sign define code_note_link text=📓 texthl=Search

" sed -i 's/^+\(.*\) \(.*\)$/\2:\1/' *.md
function codenote#ConvertFormat(line)
	" 使用 substitute() 函数来交换 +linenumber 和 path/to/filename
	let converted = substitute(a:line, '+\(\d\+\) \(.*\)', '\2:\1', '')
	return converted
endfunction

function codenote#SignCodeLinks()
	if !exists('g:code_link_dict') || !exists('g:coderepo_dir') || !exists('g:noterepo_dir')
		return
	endif
	if g:code_link_dict == {}
		return
	endif
	let l:current_file = expand("%:p")
	let [coderepo_path, repo_name] = codenote#coderepo#get_path_and_reponame_by_filename(l:current_file)
	if len(coderepo_path) > 0
		let l:current_file = l:current_file[len(coderepo_path) + 1:]
		let l:key = repo_name . ":" . l:current_file
		if has_key(g:code_link_dict, l:key)
			sign unplace * group=code_note_link
			for l:line in g:code_link_dict[l:key]
				execute "sign place " . l:line . " line=" . l:line . " group=code_note_link priority=2000 name=code_note_link file=" . l:current_file
			endfor
		endif
	endif
endfunction

function codenote#GetCodeLinkDict()
	if !exists("g:noterepo_dir")
		echoerr "g:noterepo_dir is not set"
		return
	endif

	" 高亮标记支持
	" repo_name:/path/to/filename.ext:line_number
	" --max-columns=0 防止rg显示 [ ... xxx more matches ]
	let g:code_links = system("rg -INo --max-columns=0 '^[\\w\\d\\-\\+./]+:[\\w\\d\\-\\+./]+:[0-9]+' " . g:noterepo_dir)
	let g:code_links = split(g:code_links, "\n")

	let g:code_link_dict = {}
	for code_link in g:code_links
		let l:dest = split(code_link, ":")
		let l:line = l:dest[2]
		let l:file = l:dest[1]
		let l:repo_name = l:dest[0]
		let l:key = l:repo_name . ":" . l:file
		if has_key(g:code_link_dict, l:key)
			call add(g:code_link_dict[l:key], l:line)
		else
			let g:code_link_dict[l:key] = [l:line]
		endif
	endfor
endfunction

function codenote#check()
	if !exists('g:coderepo_dir') || !exists('g:noterepo_dir')
		echom 'g:coderepo_dir or g:noterepo_dir does not exist!'
		return
	endif
	if len(g:codenote_py_reponame) == 0
		let g:codenote_py_reponame = input('coderepo name: ')
	endif
endfunction

" 根据文件名的绝对路径，来判断当前buffer属于coderepo还是noterepo
" return 'code', 'note', or ''
function s:get_repo_type_of_current_buffer()
	call codenote#check()
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
	execute "tabnew " . g:noterepo_dir
	tabmove 0
	execute "tcd " . g:noterepo_dir
	call codenote#GetAllCodeLinks()
endfunction

function s:GoToCodeLink()
	let l:cur = line('.')
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
	echo l:repo_name l:line l:file

	if codenote#only_has_one_repo()
		call codenote#coderepo#OpenCodeRepo()
	endif
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
	if !exists('g:coderepo_dir') || !exists('g:noterepo_dir')
		echo 'codenote: set g:coderepo_dir and g:noterepo_dir at first!'
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
	let l:file = expand("%:p")[len(l:path) + 1:]
	let l:content = getline(".")
	call s:yank_code_link(l:repo_name, l:file, l:line, l:content, a:need_beginline, a:need_endline, a:append, a:goto_buf)
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
	let l:file = expand("%:p")[len(l:path) + 1:]
	let [l:line, l:column_start] = getpos("'<")[1:2]
	let l:content = s:GetVisualSelection()
	call s:yank_code_link(l:repo_name, l:file, l:line, l:content, a:need_beginline, a:need_endline, a:append, a:goto_buf)
endfunction

function codenote#GetAllCodeLinks()
	if exists('g:coderepo_dir') && exists('g:noterepo_dir') && g:noterepo_dir != ""
		call codenote#GetCodeLinkDict()
		call codenote#SignCodeLinks()
		augroup codenote
			autocmd!
			autocmd BufWinEnter * call codenote#SignCodeLinks()
			autocmd BufWritePost *.md call codenote#GetCodeLinkDict()
		augroup END
	endif
endfunction
