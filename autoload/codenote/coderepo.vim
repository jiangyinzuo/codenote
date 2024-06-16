let s:repo_name_dict = {}
let g:codenote_next_tabid = get(g:, "codenote_next_tabid", 2)
" repo_name, tabid
let g:codenote_tabid_to_repo_name = get(g:, "codenote_tabid_to_repo_name", {})

function s:increment_tabid(repo_name)
	let g:codenote_tabid_to_repo_name[a:repo_name] = g:codenote_next_tabid
	let g:codenote_next_tabid += 1
endfunction

for [repo_name, path] in items(g:coderepo_dir)
	if len(repo_name) > 0
		let s:repo_name_dict[path] = repo_name
		call s:increment_tabid(repo_name)
	else
		echom "repo_name is empty for path: " . path
	endif
endfor

function codenote#coderepo#CommonPrefixLength(s1, s2)
	let n1 = len(a:s1)
	let n2 = len(a:s2)
	let min_len = min([n1, n2])
	let i = 0

	while i < min_len && a:s1[i] ==# a:s2[i]
		let i += 1
	endwhile

	return i
endfunction

function codenote#coderepo#get_path_and_reponame_by_filename(filename)
	let l:max_common_prefix_length = 0
	let l:best_path = ""
	let l:best_repo_name = ""
	for [path, repo_name] in items(s:repo_name_dict)
		let common_prefix_length = codenote#coderepo#CommonPrefixLength(a:filename, path)
		if common_prefix_length > l:max_common_prefix_length
			let l:max_common_prefix_length = common_prefix_length
			let l:best_path = path
			let l:best_repo_name = repo_name
		endif
	endfor
	return [l:best_path, l:best_repo_name]
endfunction

function codenote#coderepo#get_path_by_repo_name(repo_name)
	return get(g:coderepo_dir, a:repo_name, "")
endfunction

function s:goto_tab(tabid, path)
	if a:tabid > tabpagenr('$')
		execute (a:tabid - 1) . "tabnew"
		execute 'tcd ' . a:path
	else
		execute "tabnext " . a:tabid
	endif
endfunction

function codenote#coderepo#goto_code_buffer(repo_name)
	let tabid = get(g:codenote_tabid_to_repo_name, a:repo_name, g:codenote_next_tabid)
	if tabid == g:codenote_next_tabid
		call s:increment_tabid(a:repo_name)
	endif
	call s:goto_tab(tabid, codenote#coderepo#get_path_by_repo_name(a:repo_name))
endfunction

function codenote#coderepo#OpenCodeRepo()
	for [repo_name, coderepo] in items(g:coderepo_dir)
		let tabid = get(g:codenote_tabid_to_repo_name, repo_name, g:codenote_next_tabid)
		if tabid == g:codenote_next_tabid
			call s:increment_tabid(a:repo_name)
		endif
		call s:goto_tab(tabid, coderepo)
		" open directory
		execute 'edit ' . coderepo
	endfor
	call codenote#GetAllCodeLinks()
endfunction

