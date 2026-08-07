" Vim indent file
" Language: LikeC4 (https://likec4.dev)
"
" Brace-based indent derived from the increaseIndentPattern /
" decreaseIndentPattern in packages/vscode/language-configuration.json.

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

let s:cpo_save = &cpoptions
set cpoptions&vim

setlocal indentexpr=GetLikeC4Indent()
setlocal indentkeys=0},0),!^F,o,O
setlocal nosmartindent nolisp nocindent

let b:undo_indent = 'setlocal indentexpr< indentkeys< smartindent< lisp< cindent<'

if exists('*GetLikeC4Indent')
  let &cpoptions = s:cpo_save
  unlet s:cpo_save
  finish
endif

" Three single quotes or three double quotes. Written with \{3} so the pattern
" itself needs no quote escaping.
let s:delim = "\\%('\\{3}\\|\"\\{3}\\)"

" How far back to look for an unterminated triple-quoted block.
let s:lookback = 200

" Strip line comments and trailing whitespace before testing for a trailing
" brace. A `//` inside a string can be removed spuriously, but that only ever
" shortens the line and so cannot introduce a trailing brace.
function! s:Significant(line) abort
  return substitute(substitute(a:line, '//.*$', '', ''), '\s\+$', '', '')
endfunction

" If a:lnum sits inside a triple-quoted Markdown block -- either prose or the
" closing delimiter -- return the line number that opened the block. Otherwise
" return 0. The opening line itself counts as outside.
"
" This is decided from the text, not from synID(): during the |=| operator
" Neovim has not computed syntax state, so synID() returns 0 for every line
" and a syntax-based test silently never fires.
"
" LikeC4 only opens a block when the delimiter ends the line, and in practice
" an opener always has the property name before it (`description '''`), while
" a closer leads with the delimiter (`'''` or `''' }`). So the nearest
" delimiter above tells us which side of a block we are on.
function! s:BlockOpener(lnum) abort
  let l:view = winsaveview()
  call cursor(a:lnum, 1)
  let l:found = search(s:delim, 'bnW', max([1, a:lnum - s:lookback]))
  call winrestview(l:view)

  if l:found == 0 || getline(l:found) =~# '^\s*' . s:delim
    return 0
  endif
  return l:found
endfunction

function! GetLikeC4Indent() abort
  let l:prevlnum = prevnonblank(v:lnum - 1)
  if l:prevlnum == 0
    return 0
  endif

  let l:opener = s:BlockOpener(v:lnum)
  if l:opener > 0
    " The closing delimiter realigns with the line that opened the block, so
    " that structure resumes cleanly afterwards...
    if getline(v:lnum) =~# '^\s*' . s:delim
      return indent(l:opener)
    endif
    " ...while the Markdown in between keeps the author's own formatting.
    " Returning the current indent rather than -1 is deliberate: -1 means "use
    " 'autoindent'", which copies the previous line's indent and so would
    " still reflow the block (this config sets autoindent globally).
    return indent(v:lnum)
  endif

  let l:ind = indent(l:prevlnum)

  " Only trust a trailing brace on the previous line if that line is real
  " LikeC4 and not Markdown prose inside a block.
  if s:BlockOpener(l:prevlnum) == 0
        \ && s:Significant(getline(l:prevlnum)) =~# '[{[(]$'
    let l:ind += shiftwidth()
  endif

  if s:Significant(getline(v:lnum)) =~# '^\s*[}\])]'
    let l:ind -= shiftwidth()
  endif

  return l:ind > 0 ? l:ind : 0
endfunction

let &cpoptions = s:cpo_save
unlet s:cpo_save
