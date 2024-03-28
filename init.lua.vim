" Called from init.lua

" search visual selection using '*'
vnoremap * y/\V<C-R>=escape(@",'/\')<CR><CR>

" search and replace visual selection
vnoremap <C-r> "hy:%s/<C-r>h//gc<left><left><left>
