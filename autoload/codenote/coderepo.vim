" vim: set noet:
const s:note_repo_name = '__codenote_note_repo__'

function codenote#coderepo#get_layout_mode()
	return get(g:, 'codenote_layout_mode', 'tab')
endfunction

function s:is_window_mode()
	return codenote#coderepo#get_layout_mode() ==# 'window'
endfunction

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

function codenote#coderepo#get_first_repo_name()
	if empty(g:coderepo_dir)
		echoerr 'g:coderepo_dir is empty'
		return ''
	endif
	return g:coderepo_dir[0][0]
endfunction

function s:ensure_tab_exists(tabid)
	while tabpagenr('$') < a:tabid
		tabnew
	endwhile
endfunction

function s:goto_tab(tabid)
	call s:ensure_tab_exists(a:tabid)
	execute "tabnext " . a:tabid
endfunction

function s:mark_current_tab(repo_name, path)
	call settabvar(tabpagenr(), 'codenote_repo_name', a:repo_name)
	call settabvar(tabpagenr(), 'codenote_repo_path', fnamemodify(a:path, ':p'))
	execute 'tcd ' . fnameescape(a:path)
endfunction

function s:find_tabid_by_repo_name(repo_name)
	for l:tabid in range(1, tabpagenr('$'))
		if gettabvar(l:tabid, 'codenote_repo_name', '') ==# a:repo_name
			return l:tabid
		endif
	endfor
	return 0
endfunction

function s:ensure_repo_tab(repo_name, path, preferred_tabid)
	let l:tabid = s:find_tabid_by_repo_name(a:repo_name)
	if l:tabid == 0
		if a:preferred_tabid == 1
			0tabnew
		else
			call s:goto_tab(a:preferred_tabid)
		endif
	else
		call s:goto_tab(l:tabid)
	endif

	if tabpagenr() != a:preferred_tabid
		execute 'tabmove ' . (a:preferred_tabid - 1)
		call s:goto_tab(a:preferred_tabid)
	endif

	call s:mark_current_tab(a:repo_name, a:path)
endfunction

function s:mark_current_window(role, repo_name, path)
	let l:winid = win_getid()
	call setwinvar(l:winid, 'codenote_role', a:role)
	call setwinvar(l:winid, 'codenote_repo_name', a:repo_name)
	call setwinvar(l:winid, 'codenote_repo_path', fnamemodify(a:path, ':p'))
	execute 'lcd ' . fnameescape(a:path)
endfunction

function s:find_winnr_by_role(role)
	for l:winnr in range(1, winnr('$'))
		if getwinvar(l:winnr, 'codenote_role', '') ==# a:role
			return l:winnr
		endif
	endfor
	return 0
endfunction

function s:goto_winnr(winnr)
	execute a:winnr . 'wincmd w'
endfunction

function s:ensure_role_window(role, repo_name, path)
	let l:winnr = s:find_winnr_by_role(a:role)
	if l:winnr > 0
		call s:goto_winnr(l:winnr)
	elseif winnr('$') == 1
		if a:role ==# 'note'
			leftabove vsp
		else
			rightbelow vsp
		endif
	else
		if a:role ==# 'note'
			call s:goto_winnr(1)
		else
			call s:goto_winnr(winnr('$'))
		endif
	endif

	if a:role ==# 'note'
		wincmd H
	else
		wincmd L
	endif

	call s:mark_current_window(a:role, a:repo_name, a:path)
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

function codenote#coderepo#has_note_target()
	if s:is_window_mode()
		return s:find_winnr_by_role('note') > 0
	endif
	return s:find_tabid_by_repo_name(s:note_repo_name) > 0
endfunction

function codenote#coderepo#goto_note_buffer()
	if s:is_window_mode()
		call s:ensure_role_window('note', s:note_repo_name, g:noterepo_dir)
		return
	endif
	call s:ensure_repo_tab(s:note_repo_name, g:noterepo_dir, 1)
endfunction

function codenote#coderepo#OpenNoteRepo()
	call codenote#coderepo#goto_note_buffer()
	execute 'edit ' . fnameescape(g:noterepo_dir)
	call codenote#codelinks#Init()
endfunction

function codenote#coderepo#goto_code_buffer(repo_name)
	let l:path = codenote#coderepo#get_path_by_repo_name(a:repo_name)
	if s:is_window_mode()
		call s:ensure_role_window('code', a:repo_name, l:path)
		return
	endif
	let tabid = s:get_tabid(a:repo_name)
	call s:ensure_repo_tab(a:repo_name, l:path, tabid)
endfunction

function codenote#coderepo#OpenCodeRepo()
	if s:is_window_mode()
		let l:repo_name = codenote#coderepo#get_first_repo_name()
		if empty(l:repo_name)
			return
		endif
		call codenote#coderepo#goto_note_buffer()
		call codenote#coderepo#goto_code_buffer(l:repo_name)
		execute 'edit ' . fnameescape(codenote#coderepo#get_path_by_repo_name(l:repo_name))
		call codenote#codelinks#Init()
		return
	endif

	for [repo_name, coderepo] in g:coderepo_dir
		let tabid = s:get_tabid(repo_name)
		call s:ensure_repo_tab(repo_name, coderepo, tabid)
		" open directory
		execute 'edit ' . fnameescape(coderepo)
	endfor
	call codenote#codelinks#Init()
endfunction
