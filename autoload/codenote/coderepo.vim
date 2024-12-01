" vim: set noet:
function codenote#coderepo#CommonPrefixLength(s1, s2)
	const n1 = len(a:s1)
	const n2 = len(a:s2)
	const min_len = min([n1, n2])
	let i = 0
	let slash_cnt = 0
	while i < min_len && a:s1[i] ==# a:s2[i]
		if a:s1[i] == '/'
			let slash_cnt += 1
		endif
		let i += 1
	endwhile
	return i - slash_cnt
endfunction

function codenote#coderepo#get_path_and_reponame_by_filename(filename)
	let l:max_common_prefix_length = 0
	let l:best_path = ""
	let l:best_repo_name = ""
	for [repo_name, path] in g:coderepo_dir
		let common_prefix_length = codenote#coderepo#CommonPrefixLength(a:filename, path)
		if common_prefix_length > l:max_common_prefix_length || common_prefix_length == l:max_common_prefix_length && path < l:best_path
			let l:max_common_prefix_length = common_prefix_length
			let l:best_path = path
			let l:best_repo_name = repo_name
		endif
	endfor
	return [l:best_path, l:best_repo_name]
endfunction

function codenote#coderepo#get_path_by_repo_name(repo_name)
	for [name, path] in g:coderepo_dir
		if name == a:repo_name
			return path
		endif
	endfor
	echoerr "repo_name not found in g:coderepo_dir: " . a:repo_name
endfunction

function s:goto_tab(tabid, path)
	if a:tabid > tabpagenr('$')
		execute (a:tabid - 1) . "tabnew"
		execute 'tcd ' . a:path
	else
		execute "tabnext " . a:tabid
	endif
endfunction

function s:get_tabid(repo_name)
	let i = 2
	for [repo_name, _] in g:coderepo_dir
		if repo_name == a:repo_name
			return i
		endif
		let i += 1
	endfor
	echoerr "repo_name not found in g:coderepo_dir: " . a:repo_name
endfunction

function codenote#coderepo#goto_code_buffer(repo_name)
	let tabid = s:get_tabid(a:repo_name)
	call s:goto_tab(tabid, codenote#coderepo#get_path_by_repo_name(a:repo_name))
endfunction

function codenote#coderepo#OpenCodeRepo()
	for [repo_name, coderepo] in g:coderepo_dir
		let tabid = s:get_tabid(repo_name)
		call s:goto_tab(tabid, coderepo)
		" open directory
		execute 'edit ' . coderepo
	endfor
	call codenote#GetAllCodeLinks()
endfunction
