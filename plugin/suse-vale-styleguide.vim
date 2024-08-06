" Vim plugin that contains Vale rules corresponding to the SUSE Documentation Styleguide
" Maintainer:   Tomáš Bažant <tomik.bazik@seznam.cz>
" License:      This file is placed in the public domain.

" - - - - - - - - - - - - - - i n i t i a l   s e t u p - - - - - - - - - - "
" save the value of cpoptions
let s:save_cpo = &cpo
set cpo&vim

" do not load the plugin if it's already loaded
if exists("g:loaded_vale")
  finish
endif
let g:loaded_vale = 1

" remember the script's directory
let s:plugindir = resolve(expand('<sfile>:p:h:h'))

" define actions triggered by events
" read g:vale_* variables from .vimrc and set defaults
autocmd FileType docbk :call s:Init()

" - - - - - - - - - - - - -  c o m m a n d   d e f i n i t i o n s   - - - - - - - - - - - - "
" dummy command and function for testing purposes
if !exists(":ValeDummy")
  command -nargs=* ValeDummy :call s:ValeDummy(<f-args>)
endif

" vale stylecheck
if !exists(":ValeStylecheck")
  command -nargs=0 ValeStylecheck :call s:ValeStylecheck(<f-args>)
endif


" - - - - - - - - - - - - -   f u n c t i o n s   - - - - - - - - - - - - "

" read g:vale_* variables from ~/.vimrc and set buffer-wide defaults
function s:Init()

  "   L   O   G   G   I   N   G
  let b:vale_debug = get(g:, 'vale_debug', 0)
  if b:vale_debug == 1
    let b:vale_log_file = get(g:, 'vale_log_file')
    " check if file exists and is writable, or try to create an empty one
    try
      let buffer_filename = expand("%")
      call writefile([ repeat('*', len(buffer_filename)) , buffer_filename, repeat('*', len(buffer_filename))], b:vale_log_file, 'a')
    catch
      echoerr "Error creating the file: " . v:exception
    endtry
  endif

  "   O  P  T  I  O  N  S'    D  E  F  A  U  L  T     V  A  L  U  E  S
  let b:vale_executable = get(g:, 'vale_executable', '/usr/bin/vale')
  let b:vale_stylecheck_on_save = get(g:, 'vale_stylecheck_on_save', 0)
  let b:vale_stylecheck_qfwindow = get(g:, 'vale_stylecheck_qfwindow', 1)
endfunction

function s:dbg(msg)
  if b:vale_debug == 1
    let msg = "DEBUG: " . a:msg
    if exists("b:vale_log_file") && !empty(b:vale_log_file)
      call writefile([msg], b:vale_log_file, 'a')
    else
      echom msg
    endif
  endif
endfunction

" vale style check
function s:ValeStylecheck()
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  " erase all signs and underlinings
  call clearmatches()
  execute 'cclose'
  execute 'sign unplace *'
  " check for 'vale' binary
  if !executable('vale')
    echoe "Command 'vale' was not found"
    return 1
  endif
  "save the current  buffer to disk
  write
  " remember current path, find the path of the active file and cd to that dir
  let cwd = getcwd()
  let current_file_dir = expand('%:h')
  exe "lcd " . current_file_dir
  let current_file_path = expand('%:t')
  " compile vale command and run it
  let vale_cmd = "vale --output " . s:plugindir . "/tools/vale_template --no-wrap --config " . s:plugindir . "/.vale.ini " . current_file_path
  call s:dbg('vale_cmd -> ' . vale_cmd)
  silent let output = systemlist(vale_cmd)
  " remove empty lines from the output
  call filter(output, 'v:val != ""')
  " sort the output so that ERRORS are first and SUGGESTIONS last
  let sorted_output = sort(output, 's:CompareStylePriority')
  call s:dbg('output -> ' . string(sorted_output))
  " cd back to cwd
  exe "lcd " . cwd
  " define signs for quickfix list
  let qflist = []
  let id = 1
  sign define error text=E
  sign define warning text=W
  sign define suggestion text=S
  if len(sorted_output) > 0
    for line in sorted_output
      call s:dbg('line -> ' . string(line))
      if !empty(line)
        " get the line array
        let la = split(trim(line), ':')
        let item = { 'bufnr': bufnr('%'), 'lnum': la[1], 'col': la[2], 'type': la[3], 'text': la[5] }
        call add (qflist, item)
        execute 'sign place ' . id . ' line=' . la[1] . ' name=' . la[3] . ' file=' . bufname('%')
        call matchadd('Underlined', '\%' . la[1] . 'l\%' . la[2] . 'c\k\+')
        let id += 1
      endif
    endfor
    call setqflist(qflist)
    if g:vale_stylecheck_qfwindow == 1
      execute 'copen'
    endif
  else
    execute 'cclose'
    execute 'sign unplace *'
    echow 'No style mistakes found'
  endif
endfunction

" compares priority of style check results
function s:CompareStylePriority(a, b)
  call s:dbg('# # # # # ' . expand('<sfile>') . ' # # # # #')
  let a_priority = -1
  let b_priority = -1
  if a:a =~# 'error'
    let a_priority = 0
  elseif a:a =~# 'warning'
    let a_priority = 1
  elseif a:a =~# 'suggestion'
    let a_priority = 2
  endif
  if a:b =~# 'error'
    let b_priority = 0
  elseif a:b =~# 'warning'
    let b_priority = 1
  elseif a:b =~# 'suggestion'
    let b_priority = 2
  endif
  return (a_priority - b_priority)
endfunction


" - - - - - - - - - - - - -  e n d  f u n c t i o n s   - - - - - - - - - - - - "

" restore the value of cpoptions
let &cpo = s:save_cpo
