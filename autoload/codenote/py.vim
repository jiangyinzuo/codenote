let s:codenote_py= 'python3 ' . expand('<sfile>:p:h:h:h') . '/python/codenote.py --noterepo='
function s:codenote_py_submodule_noterepo()
	return s:codenote_py . g:noterepo_dir . ' --submodule=' . g:codenote_submodule
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
	let l:cmd = s:codenote_py_submodule_noterepo() . ' checkout --linenum=' . l:linenum . ' --commit=' . a:commit . ' --coderepo=' . g:coderepo_dir . ' --note-file=' . expand('%:p')
	exe ':!' . l:cmd
endfunction

function s:execute_with_code_note_commit(subcommand, commit)
	call codenote#check()
	let l:cmd = s:codenote_py_submodule_noterepo() . ' '.a:subcommand.' --commit=' . a:commit . ' --coderepo=' . g:coderepo_dir
	exe ':!' . l:cmd
endfunction

function codenote#py#CheckoutAll(commit)
	call s:execute_with_code_note_commit('checkout-all', a:commit)
endfunction

function codenote#py#Save(commit)
	call s:execute_with_code_note_commit('save', a:commit)
endfunction

function codenote#py#Check(commit)
	call s:execute_with_code_note_commit('check', a:commit)
endfunction

function codenote#py#RebaseToCurrent(commit)
	call s:execute_with_code_note_commit('rebase', a:commit)
endfunction

function codenote#py#ShowDB()
	call codenote#check()
	let l:cmd = s:codenote_py_submodule_noterepo() . ' show-db'
	exe ':!' . l:cmd
endfunction
