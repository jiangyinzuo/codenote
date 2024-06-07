let g:codenote_py_reponame = get(g:, 'codenote_py_reponame', '')

let s:codenote_py= 'python3 ' . expand('<sfile>:p:h:h:h') . '/python/codenote.py --noterepo='
function s:common_cmd()
	let l:result = s:codenote_py . g:noterepo_dir 
	if len(g:codenote_py_reponame) > 0 
		let l:result .= ' --reponame=' . g:codenote_py_reponame 
	endif
	if len(g:codenote_submodule)
		let l:result .= ' --submodule=' . g:codenote_submodule
	endif
	return l:result
endfunction

let s:str_pat = '[A-Za-z0-9\-./]+'
let s:regex = '\v'.s:str_pat.'(:[0-9]+)(-[0-9]+)?(\s+version\='.s:str_pat.')?(\s+snippet_id\=[0-9]+)?\s*$'
function codenote#py#Checkout(commit)
	call codenote#check()
	let l:linenum = line('.')
	while l:linenum > 0
		if getline(l:linenum) !~# s:regex
			let l:linenum -= 1
		else
			break
		endif
	endwhile
	if l:linenum == 0
		echom "valid head line not found"
		return
	endif
	let l:cmd = s:common_cmd() . ' checkout --linenum=' . l:linenum . ' --commit=' . a:commit . ' --coderepo=' . codenote#coderepo#get_path_by_repo_name(g:codenote_py_reponame) . ' --note-file=' . expand('%:p')
	exe ':!' . l:cmd
endfunction

function s:execute_with_code_note_commit(subcommand, commit)
	call codenote#check()
	let l:cmd = s:common_cmd() . ' '.a:subcommand.' --commit=' . a:commit . ' --coderepo=' . codenote#coderepo#get_path_by_repo_name(g:codenote_py_reponame)
	exe ':!' . l:cmd
endfunction

function codenote#py#CheckoutAll(commit)
	call s:execute_with_code_note_commit('checkout-all', a:commit)
endfunction

function codenote#py#Save(commit, file)
	call codenote#check()
	let l:cmd = s:common_cmd() . ' save --commit=' . a:commit . ' --coderepo=' . codenote#coderepo#get_path_by_repo_name(g:codenote_py_reponame)
	if len(a:file) > 0
		let l:cmd .= ' --note-file=' . a:file
	endif
	let l:result = system(l:cmd)
	if v:shell_error
		echom l:result
	else
		:cexpr l:result
	endif
endfunction

function codenote#py#Check(commit)
	call s:execute_with_code_note_commit('check', a:commit)
endfunction

function codenote#py#RebaseToCurrent(commit)
	call s:execute_with_code_note_commit('rebase', a:commit)
endfunction

function codenote#py#ShowDB()
	call codenote#check()
	let l:cmd = s:common_cmd() . ' show-db'
	exe ':!' . l:cmd
endfunction

function codenote#py#GetCodeRepoCommit()
	call codenote#check()
	let coderepo_path = codenote#coderepo#get_path_by_repo_name(g:codenote_py_reponame)
	if len(coderepo_path) == 0
		echoerr 'coderepo not found'
		return 
	endif
	return system('cd ' . coderepo_path . ' && git rev-parse HEAD')->trim()
endfunction

function codenote#py#GetAllCommits()
	call codenote#check()
	let l:cmd = s:common_cmd() . ' show-commits'
	return system(l:cmd)
endfunction
