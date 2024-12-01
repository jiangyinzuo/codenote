sign define code_note_link text=📓 texthl=Search

function codenote#codelinks#Sign()
	if !exists('s:code_link_dict') || s:code_link_dict == {}
		return
	endif
	let l:current_file = expand("%:p")
	let [coderepo_path, repo_name] = codenote#coderepo#get_path_and_reponame_by_filename(l:current_file)
	if len(coderepo_path) > 0
		let l:current_file = l:current_file[len(coderepo_path):]
		let l:key = repo_name . ":" . l:current_file
		echom "current buffer is in coderepo: " . l:key
		if has_key(s:code_link_dict, l:key)
			sign unplace * group=code_note_link
			for l:line in s:code_link_dict[l:key]
				execute "sign place " . l:line . " line=" . l:line . " group=code_note_link priority=2000 name=code_note_link file=" . l:current_file
			endfor
		endif
	endif
endfunction

function codenote#codelinks#GetCodeLinkDict()
	if !exists("g:noterepo_dir")
		echoerr "g:noterepo_dir is not set"
		return
	endif

	" 高亮标记支持
	" repo_name:/path/to/filename.ext:line_number
	" --max-columns=0 防止rg显示 [ ... xxx more matches ]
	let l:code_links = system("rg -INo --max-columns=0 '^[\\w\\d\\-\\+./]+:[\\w\\d\\-\\+./]+:[0-9]+' " . g:noterepo_dir)
	let l:code_links = split(l:code_links, "\n")

	let s:code_link_dict = {}
	for code_link in l:code_links
		let l:dest = split(code_link, ":")
		let l:line = l:dest[2]
		let l:file = l:dest[1]
		let l:repo_name = l:dest[0]
		let l:key = l:repo_name . ":" . l:file
		if has_key(s:code_link_dict, l:key)
			call add(s:code_link_dict[l:key], l:line)
		else
			let s:code_link_dict[l:key] = [l:line]
		endif
	endfor
endfunction

function codenote#codelinks#Init()
	if !codenote#check()
		echoerr "g:coderepo_dir or g:noterepo_dir does not exist!"
	endif
	call codenote#codelinks#GetCodeLinkDict()
	call codenote#codelinks#Sign()
	augroup codenote
		autocmd!
		autocmd BufWinEnter * call codenote#codelinks#Sign()
		autocmd BufWritePost *.md call codenote#codelinks#GetCodeLinkDict()
	augroup END
endfunction
