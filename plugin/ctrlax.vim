" ctrlax.vim:   (plugin) Functions to enhance <C-A> and <C-X>
" Maintainer:   Preben 'Peppe' Guldberg <peppe@xs4all.nl>
" Version:      1.1
" Last Change:  23th July, 2003

" Exit quickly when already loaded or when 'compatible' is set.
if exists("loaded_ctrlax") || &cp
  finish
endif
let loaded_ctrlax = 1
let s:save_cpo = &cpo
set cpo&vim

" Allow mappings to <Plug> versions
if !hasmapto('<Plug>Ctrl_A')
    nmap <unique> <Leader><C-A> <Plug>Ctrl_A
endif
if !hasmapto('<Plug>Ctrl_X')
    nmap <unique> <Leader><C-X> <Plug>Ctrl_X
endif
" Remap <Plug> versions to script local <SID> versions
nnoremap <unique> <script> <Plug>Ctrl_A <SID>Ctrl_A
nnoremap <unique> <script> <Plug>Ctrl_X <SID>Ctrl_X
" And, finally, do something useful :-)
nnoremap <SID>Ctrl_A    :<C-U>call <SID>CtrlAX(v:count1)<CR>
nnoremap <SID>Ctrl_X    :<C-U>call <SID>CtrlAX(- v:count1)<CR>

" Set some default functions
let s:ctrlax_functions = "_vim_default_"
let s:ctrlax_functions = s:ctrlax_functions . ",CtrlAX_LongMonths"
let s:ctrlax_functions = s:ctrlax_functions . ",CtrlAX_ShortMonths"
let s:ctrlax_functions = s:ctrlax_functions . ",CtrlAX_LongDays"
let s:ctrlax_functions = s:ctrlax_functions . ",CtrlAX_ShortDays"

" Function to enhance <C-A> and <C-X>
" It uses functions set in "[wbg]:ctrlax_functions" as a comma separated
" list. If none is set, it emulates vim.
" Add vim emulation by including '_vim_default_'.
"
" The functions are passed three arguments:
"       1.  A string: getline(line('.'))
"       2.  The current string position: col('.') - 1
"       3.  How much to increment the value (may be negative)
"
" The functions must return a string containing, in order:
"
"       1.  The new position in the string
"       2.  A comma
"       3.  The length of the text to replace
"       4.  Another comma
"       5.  The replacement string
"
" While not mandatory, the intent is that functions find a string which end at
" or later than the current position in the string.
"
" The functions are not allowed to move the cursor position (checked) and not
" supposed to change the buffer. A side effect is that functions can rely on
" the cursor staying put if they want to check buffer context.
"
fun! s:CtrlAX(n)
    if type(a:n) != 0
        echoerr "Argument must be a number"
        return
    endif

    " First get the set of functions to use later on
    let funvar = s:GetVarName('wbg', 'ctrlax_functions')
    " We can't do this - there seem to be a bug in vim with {...} here
    " let funs = (funvar == '' ? '_vim_default_' : {funvar})
    if funvar == ''
        let funs = s:ctrlax_functions
    else
        let funs = {funvar}
    endif
    if ',' . funs . ',' =~# ',_vim_default_,'
        " Order is important here
        let tmp = 's:Decimal'
        if -1 != stridx(&nrformats, 'alpha')
            let tmp = tmp . ',' . 's:Alpha'
        endif
        if -1 != stridx(&nrformats, 'octal')
            let tmp = tmp . ',' . 's:Octal'
        endif
        if -1 != stridx(&nrformats, 'hex')
            let tmp = tmp . ',' . 's:Hex'
        endif
        let tmp = ',' . tmp . ','
        let funs = substitute(',' . funs . ',', ',_vim_default_,', tmp, 'g')
        let funs = strpart(funs, 1, strlen(funs) - 2)
    endif

    " col is the offset into getline()
    let col = col('.') - 1
    let line = line('.')
    let maxcol = col('$')
    let str = getline('.')

    " Dummy empty function makes life easier
    let funs = funs . ','
    while funs != ''
        let c = stridx(funs, ',')
        let f = strpart(funs, 0, c)
        let funs = strpart(funs, c + 1)
        if f == ''
            continue
        endif
        if !exists('*' . f)
            echoerr 'Unknown function: "' . f . '"'
            return
        endif
        let tmp = {f}(str, col, a:n)
        if tmp !~ '^\d\+,\d\+,'
            continue
        endif
        let c = stridx(tmp, ',')
        let i = strpart(tmp, 0, c) + 0      " number convertion
        if i <= maxcol
            let maxcol = i
            let c2 = matchend(tmp, '^[^,]*,[^,]*')
            let len = strpart(tmp, c + 1, c2 - c) + 0
            let sub = strpart(tmp, c2 + 1)
        endif
    endwhile

    " Check that we did not move (forbidden!)
    if line != line('.') || col + 1 != col('.')
        echoerr "Some subfunction moved the cursor! Can't have that"
        return
    endif

    " If we defined sub above, we can substitute in the value
    if exists('sub')
        let newstr = strpart(str, 0, maxcol) . sub . strpart(str, maxcol + len)
        call setline(line, newstr)
        call cursor(line, maxcol + strlen(sub))
    endif
endfun

" CtrlAX_WordArray(str, pos, array, style, n)
"
" Find the word in an array that matches the earliest in a str ending at or
" later than a given position.
" The word is the incremented by "n" by looking up the n'th next array entry.
" If we get out of bounds, we either wrap around to the start/end of the
" array or select the last/first entry in the array.
"
" Returns:  "i,n,str", where i is the index into the string, n is the length
"           of the replaced text and str is the replacement text.
"
" The words are part of a variable array, say "g:MyWords", which could be
" defined as:
"
"       let g:MyWords_wrap = 1          " Wrap around array
"       let g:MyWords = 3               " Number of elements in array
"       let g:MyWords_0 = 'foo'         " First element in array
"       let g:MyWords_1 = 'bar'         " Second element in array
"       let g:MyWords_2 = 'baz'         " Last element in array
"
" No check is made whether the word actually only consists of word characters.
" Abuse this at will - as long as you know what you are doing :-)
"
" The function understands four styles: 'any', 'upper', 'lower' and
" 'verbatim'. How this apply is explained below.
"
" WARNING:  Currently 'verbatim' is not checked, so anything other than the
"           four options above is effectively 'verbatim'.
"           I may make enhancements that rely on 'verbatim'. so please use it.
"
" Finding the match:
" ------------------
" The search ignores case only if style is 'any'.
" If style is 'upper'/'lower' the words in the array are made upper/lower case
" before searching.
"
" Finding substitute value:
" -------------------------
" Find the Nth next element in the array. May wrap around the array.
"
" Whether we wrap or not is defined by {a:array}_wrap. In the example above
" that is "g:MyWords_wrap". The default is to wrap.
"
" If style is 'any', the returned value is made lower case if the matched
" word above did not contain any upper case characters. If the matched word
" did not contain any lower case characters, the returned value is all caps.
" When there is a mix of characters, the return value is not altered.
"
" If style is 'upper'/'lower' the result is made upper/lower case.
"
" If style is 'verbatim', the array value is returned unaltered.
"
fun! CtrlAX_WordArray(str, pos, array, style, n)
    let array = (a:array[1] == ':' ? a:array : 'g:' . a:array)
    let case = (a:style ==# 'any' ? '\c' : '\C')

    let idx = strlen(a:str)
    let match = -1
    let ai = 0
    while ai < {array}
        let word = {array}_{ai}
        if a:style ==# 'upper'
            let word = toupper(word)
        elseif a:style ==# 'lower'
            let word = tolower(word)
        endif
        let pat = case . '\<' . word . '\>'
        let i = match(a:str, pat, a:pos - strlen(word) + 1)
        if i >= 0 && i <= idx
            let idx = i
            let match = ai
        endif
        let ai = ai + 1
    endwhile
    if idx == strlen(a:str)
        return '-1,,'
    endif

    let len = strlen({array}_{match})
    let str = strpart(a:str, idx, len)
    let i = (match + a:n)
    let wrap = (exists(array . '_wrap') ? {array}_wrap : 1)
    if wrap
        let i = i % {array}
        if i < 0
            let i = i + {array}
        endif
    elseif i >= {array}
        let i = {array} - 1
    elseif i < 0
        let i = 0
    endif
    let val = {array}_{i}
    if a:style == 'lower' || (a:style == 'any' && str !~# '\u')
        let val = tolower(val)
    elseif a:style == 'upper' || (a:style == 'any' && str !~# '\l')
        let val = toupper(val)
    endif
    return idx . ',' . strlen(str) . ',' . val
endfun

" CtrlAX_WordArrayStr() is pretty much like CtrlAX_WordArray() except that
" instead of an array variable, it takes a comma delimited list of words.
" It transforms the list into a script internal variable array for
"
" Furthermore an additional argument may be added to specify whether to wrap
" around the end of the array or not. The default follows
" CtrlAX_WordArray().
"
" CtrlAX_WordArray().
fun! CtrlAX_WordArrayStr(str, pos, strarray, style, n, ...)
    let tmp = a:strarray . ','
    let len = strlen(tmp)
    let ai = 0
    let i = 0
    while i < len
        let j = match(tmp, ',', i)
        let s:wordarray_{ai} = strpart(tmp, i, j - i)
        let i = j + 1
        let ai = ai + 1
    endwhile
    let s:wordarray = ai
    if a:0
        let s:wordarray_wrap = a:1
    endif
    let val = CtrlAX_WordArray(a:str, a:pos, 's:wordarray', a:style, a:n)
    while ai > 0
        let ai = ai - 1
        unlet! s:wordarray_{ai}
    endwhile
    unlet! s:wordarray s:wordarray_wrap
    return val
endfun

"
" Internal Functions
"

" Return a variable name in one of the given scopes (string of scope chars)
fun! s:GetVarName(scope, var)
    let i = 0
    while a:scope[i] != ''
        let var = a:scope[i] . ':' . a:var
        if exists(var)
            return var
        endif
        let i = i + 1
    endwhile
    return ''
endfun

" Signed 32 bit values
let s:s32max = 2147483647
let s:s32min = -2147483648

" TODO: see if we can emulate vim for decimal numbers.
"       The next few lines are test cases for that project.
" Vim <C-A>         Vim <C-X>
" 37777777777       37777777777
" 3418039410        3418039408
" Us:               Us:
" 37777777777       37777777777
" -876927886        -876927888    (add 2^32 to get vims result)

" max and min (signed)      max and min (unsigned)
"  2147483647                4294967295
" -2147483648               -4294967295

" Emulate nrformats=
fun! s:Decimal(str, pos, n)
    let i = match(a:str, '\v-?\d*%(.{' . a:pos . ',})@<=\d')
    if i == -1
        return '-1,,'
    else
        let str = matchstr(a:str, '-\?\d\+', i)
        let val = s:VimDecimalAdd(a:n, str)
        return i . ',' . strlen(str) . ',' . val
    endif
endfun

" Note: n31 is a number, n32 is a string.
" TODO: How to detect that a number is too large for expressions,
"       but OK for <C-A>/<C-X>? The latter is 32 bit unsigned either way.
"       As we can't reliably use "0 + a:n32" to get a number, we probably
"       have to write a function to compare strings as numbers :-(
"       For now we just return the sum of the two numbers.
fun! s:VimDecimalAdd(n31, n32)
    return a:n31 + a:n32
endfun

" Emulate nrformats=octal
fun! s:Octal(str, pos, n)
    let i =  match(a:str, '\v0\o*%(.{' . a:pos . ',})@<=\o')
    if i == -1
        return '-1,,'
    else
        let str = matchstr(a:str, '\o\+', i)
        let val = s:VimOctalAdd(a:n, str)
        return i . ',' . strlen(str) . ',' . val
    endif
endfun

fun! s:VimOctalAdd(n, m)
    let vimval = a:n + a:m
    let tmp = (vimval < 0 ? s:s32max + vimval + 1 : vimval)
    let val = ''
    while tmp
        let val = (tmp % 8) . val
        let tmp = tmp / 8
    endwhile
    if vimval < 0
        let val = (val[0] + 2) . strpart(val, 1)
    endif
    let n = strlen(a:m) - strlen(val)
    let i = 0
    while i < n
        let i = i + 1
        let val = '0' . val
    endwhile
    return val
endfun

" Emulate nrformats=hex
fun! s:Hex(str, pos, n)
    let i = match(a:str, '\v0[xX]\x*%(.{' . (a:pos - 2) . ',})@<=\x')
    if i == -1
        return '-1,,'
    else
        let str = matchstr(a:str, '0[xX]\x\+', i)
        let val = s:VimHexAdd(a:n, str)
        return i . ',' . strlen(str) . ',' . val
    endif
endfun

fun! s:VimHexAdd(n, m)
    let vimval = a:n + a:m
    let tmp = (vimval < 0 ? s:s32max + vimval + 1 : vimval)
    let val = ''
    while tmp
        let val = '0123456789abcdef'[tmp % 16] . val
        let tmp = tmp / 16
    endwhile
    if vimval < 0
        let val = '0123456789abcdef'[val[0] + 8] . strpart(val, 1)
    endif
    let n = strlen(a:m) - 2 - strlen(val)
    let i = 0
    while i < n
        let i = i + 1
        let val = '0' . val
    endwhile
    if strpart(a:m, 2) =~# '[A-F]'
        let val = toupper(val)
    endif
    return strpart(a:m, 0, 2) . val
endfun

" Emulate nrformats=alpha
fun! s:Alpha(str, pos, n)
    let i = match(a:str, '\a', a:pos)
    if i == -1
        return '-1,,'
    else
        return i . ',1,' . s:VimAlphaAdd(a:n, a:str[a:pos])
    endif
endfun

let s:alpha_chars = 'abcdefghijklmnopqrstuvwxyz'
fun! s:VimAlphaAdd(n, c)
    let i = a:n + stridx(s:alpha_chars, tolower(a:c))
    if i < 0
        let c = 'a'
    elseif i > 25
        let c = 'z'
    else
        let c = s:alpha_chars[i]
    endif
    if a:c =~# '\u'
        let c = toupper(c)
    endif
    return c
endfun

"
" Predefined functions available to the user
"

" Cycle through short month names
let s:shortmonths_wrap = 1
let s:shortmonths = 12
let s:shortmonths_0 = 'Jan' | let s:shortmonths_6 =  'Jul'
let s:shortmonths_1 = 'Feb' | let s:shortmonths_7 =  'Aug'
let s:shortmonths_2 = 'Mar' | let s:shortmonths_8 =  'Sep'
let s:shortmonths_3 = 'Apr' | let s:shortmonths_9 =  'Oct'
let s:shortmonths_4 = 'May' | let s:shortmonths_10 = 'Nov'
let s:shortmonths_5 = 'Jun' | let s:shortmonths_11 = 'Dec'
fun! CtrlAX_ShortMonths(str, pos, n, ...)
    let var = s:GetVarName('wbg', 'ctrlax_shortmonths')
    let array = (var == '' ? 's:shortmonths' : var)
    let var = s:GetVarName('wbg', 'ctrlax_shortmonths_style')
    " We can't do this - there seem to be a bug in vim with {...} here
    " let style = (var == '' ? 'verbatim' : {var})
    if var == ''
        let style = 'verbatim'
    else
        let style = {var}
    endif
    return CtrlAX_WordArray(a:str, a:pos, array, style, a:n)
endfun

" Cycle through long month names
let s:longmonths_wrap = 1
let s:longmonths = 12
let s:longmonths_0 = 'January'  | let s:longmonths_6  = 'July'
let s:longmonths_1 = 'February' | let s:longmonths_7  = 'August'
let s:longmonths_2 = 'March'    | let s:longmonths_8  = 'September'
let s:longmonths_3 = 'April'    | let s:longmonths_9  = 'October'
let s:longmonths_4 = 'May'      | let s:longmonths_10 = 'November'
let s:longmonths_5 = 'June'     | let s:longmonths_11 = 'December'
fun! CtrlAX_LongMonths(str, pos, n)
    let var = s:GetVarName('wbg', 'ctrlax_longmonths')
    let array = (var == '' ? 's:longmonths' : var)
    let var = s:GetVarName('wbg', 'ctrlax_longmonths_style')
    " We can't do this - there seem to be a bug in vim with {...} here
    " let style = (var == '' ? 'verbatim' : {var})
    if var == ''
        let style = 'verbatim'
    else
        let style = {var}
    endif
    return CtrlAX_WordArray(a:str, a:pos, array, style, a:n)
endfun

" Cycle through short day names
let s:shortdays_wrap = 1
let s:shortdays = 7
let s:shortdays_0 = 'Mon' | let s:shortdays_4  = 'Fri'
let s:shortdays_1 = 'Tue' | let s:shortdays_5  = 'Sat'
let s:shortdays_2 = 'Wed' | let s:shortdays_6  = 'Sun'
let s:shortdays_3 = 'Thu'
fun! CtrlAX_ShortDays(str, pos, n)
    let var = s:GetVarName('wbg', 'ctrlax_shortdays')
    let array = (var == '' ? 's:shortdays' : var)
    let var = s:GetVarName('wbg', 'ctrlax_shortdays_style')
    " We can't do this - there seem to be a bug in vim with {...} here
    " let style = (var == '' ? 'verbatim' : {var})
    if var == ''
        let style = 'verbatim'
    else
        let style = {var}
    echoerr 'asdasd'
    endif
    return CtrlAX_WordArray(a:str, a:pos, array, style, a:n)
endfun

" Cycle through long day names
let s:longdays_wrap = 1
let s:longdays = 7
let s:longdays_0 = 'Monday'    | let s:longdays_4  = 'Friday'
let s:longdays_1 = 'Tuesday'   | let s:longdays_5  = 'Saturday'
let s:longdays_2 = 'Wednesday' | let s:longdays_6  = 'Sunday'
let s:longdays_3 = 'Thursday'
fun! CtrlAX_LongDays(str, pos, n)
    let var = s:GetVarName('wbg', 'ctrlax_longdays')
    let array = (var == '' ? 's:longdays' : var)
    let var = s:GetVarName('wbg', 'ctrlax_longdays_style')
    " We can't do this - there seem to be a bug in vim with {...} here
    " let style = (var == '' ? 'verbatim' : {var})
    if var == ''
        let style = 'verbatim'
    else
        let style = {var}
    endif
    return CtrlAX_WordArray(a:str, a:pos, array, style, a:n)
endfun

" Restore
let &cpo= s:save_cpo
unlet s:save_cpo
