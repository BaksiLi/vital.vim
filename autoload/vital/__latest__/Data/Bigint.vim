" Utilities for multi precision integer.

let s:save_cpo = &cpo
set cpo&vim

let s:zero = {'num': [0], 'sign': 1}
let s:node_max_digit = 4
let s:node_max_num = 10000

function! s:_is_digit(str) abort
  return match(a:str, '^[+-]\?\d\+$') != -1
endfunction

function! s:from_int(n) abort
  " TODO: do not use s:from_string
  return s:from_string(string(a:n))
endfunction

function! s:from_string(str) abort
  if s:_is_digit(a:str) != 1
    call s:_throw('is not digit: '.a:str)
  endif
  let bigint = deepcopy(s:zero)
  let bigint.sign = (a:str[0] == "-") ? -1 : 1
  if match(a:str, '^[+-]') != -1
    let l:str = a:str[1:]
  else
    let l:str = a:str
  endif
  let l:strlen = len(l:str)
  let l:nodes = ((l:strlen-1)/s:node_max_digit)+1
  let l:head_node_len = l:strlen % s:node_max_digit

  if l:head_node_len != 0
    call add(bigint.num, l:str[: l:head_node_len-1])
  endif

  let l:tail_nodes = split(l:str[l:head_node_len :], '.\{' . s:node_max_digit . '}\zs')
  let l:bigint.num = map(l:bigint.num + l:tail_nodes, 'str2nr(v:val)')
  return s:_fix_form(l:bigint)
endfunction

function! s:to_string(bigint) abort
  let l:str = ''
  let l:str .= string(a:bigint.num[0])
  for node in a:bigint.num[1:]
    let l:str .= printf('%0'.s:node_max_digit.'d', node)
  endfor
  if a:bigint.sign == -1
    let l:str = '-' .l:str
  endif
  return l:str
endfunction

function! s:_of(n) abort
  " n: Number or String or Bigint
  let l:t = type(a:n)
  if l:t == 4 " Dictionary
    return a:n
  elseif l:t == 0 " Number
    return s:from_int(a:n)
  elseif l:t == 1 " String
    return s:from_string(a:n)
  else
    call s:_throw('type error')
  endif
endfunction

" a > b: return 1
" a = b: return 0
" a < b: return -1
function! s:compare(a,b) abort
  let l:a = s:_of(a:a)
  let l:b = s:_of(a:b)

  if l:a.sign != l:b.sign
    return (l:a.sign == 1) ? 1 : -1
  endif
  return s:_abs_compare(l:a,l:b) * l:a.sign
endfunction

function! s:_abs_compare(a,b) abort
  let l:len_a = len(a:a.num)
  let l:len_b = len(a:b.num)

  if len_a != len_b
    return (len_a > len_b) ? 1 : -1
  endif
  for i in range(len_a)
    if a:a.num[i] != a:b.num[i]
      return (a:a.num[i] > a:b.num[i]) ? 1 : -1
    endif
  endfor
  return 0
endfunction

function! s:add(a,b) abort
  let l:a = s:_of(a:a)
  let l:b = s:_of(a:b)

  if l:a.sign == l:b.sign
    let l:tmp = s:_abs_add(l:a,l:b)
    let l:tmp.sign = l:a.sign
    return l:tmp
  else
    let l:comp = s:_abs_compare(l:a,l:b)
    if l:comp >= 0
      let l:tmp = s:_abs_sub(l:a,l:b)
      let l:tmp.sign = l:a.sign
      return l:tmp
    else
      let l:tmp = s:_abs_sub(l:b,l:a)
      let l:tmp.sign = l:b.sign
      return l:tmp
    endif
  endif
endfunction

function! s:sub(a,b) abort
  let l:a = s:_of(a:a)
  let l:b = s:_of(a:b)

  let l:b = deepcopy(l:b)
  let l:b.sign = l:b.sign*(-1)
  return s:add(l:a,l:b)
endfunction

function! s:_abs_add(a,b) abort
  if s:_abs_compare(a:a,a:b) >= 0
    let l:res = deepcopy(a:a)
    let l:addend = a:b
  else
    let l:res = deepcopy(a:b)
    let l:addend = a:a
  endif

  let l:res_len = len(l:res.num)
  let l:addend_len = len(l:addend.num)
  let l:carry = 0

  for i in range(res_len)
    let l:res_idx = l:res_len-i-1
    let l:addend_idx = l:addend_len-i-1

    if l:addend_idx >= 0
      let l:tmp_add = l:addend.num[l:addend_idx]
    else
      let l:tmp_add = 0
    endif

    let l:tmp = l:res.num[l:res_idx] + l:tmp_add + l:carry
    let l:carry = l:tmp / s:node_max_num
    let l:tmp = l:tmp % s:node_max_num
    let l:res.num[l:res_idx] = l:tmp
  endfor

  if l:carry > 0
    call insert(l:res.num, l:carry, 0)
  endif
  return s:_fix_form(l:res)
endfunction

function! s:_abs_sub(a,b) abort
  if s:_abs_compare(a:a,a:b) >= 0
    let l:res = deepcopy(a:a)
    let l:subtrahend = a:b
  else
    let l:res = deepcopy(a:b)
    let l:subtrahend = a:a
  endif

  let l:res_len = len(l:res.num)
  let l:subtrahend_len = len(l:subtrahend.num)
  let l:borrow = 0

  for i in range(l:res_len)
    let l:res_idx = l:res_len-i-1
    let l:subtrahend_idx = l:subtrahend_len-i-1

    if l:subtrahend_idx >= 0
      let l:tmp_sub = l:subtrahend.num[l:subtrahend_idx]
    else
      let l:tmp_sub = 0
    endif
    let l:tmp = l:res.num[l:res_idx] - l:tmp_sub - l:borrow

    if l:tmp < 0
      let l:borrow = 1
      let l:tmp += s:node_max_num
    else
      let l:borrow = 0
    endif
    let l:res.num[l:res_idx] = l:tmp
  endfor

  return s:_fix_form(l:res)
endfunction

function! s:mul(a,b) abort
  let l:a = s:_of(a:a)
  let l:b = s:_of(a:b)

  let l:res = deepcopy(s:zero)
  if s:_abs_compare(l:a,l:b) >= 0
    let l:multiplicand = l:a
    let l:multiplier = l:b
  else
    let l:multiplicand = l:b
    let l:multiplier = l:a
  endif

  let l:multiplier_len = len(l:multiplier.num)
  for i in range(l:multiplier_len)
    let l:multiplier_idx = l:multiplier_len-i-1
    let l:multiplier_int = l:multiplier.num[l:multiplier_idx]

    let l:tmp = s:_abs_mul_shortint(l:multiplicand, l:multiplier_int)
    for j in range(i)
      call add(l:tmp.num, 0)
    endfor
    let l:res = s:_abs_add(l:res, l:tmp)
  endfor

  let l:res.sign = l:a.sign * l:b.sign
  return s:_fix_form(l:res)
endfunction

function! s:div_mod(a,b) abort
  let l:a = s:_of(a:a)
  let l:b = s:_of(a:b)
  if s:compare(l:b, s:zero) == 0
    if s:compare(l:a, s:zero) == 0
      call s:_throw('indeterminate')
    else
      call s:_throw('incompatible')
    endif
  endif

  let l:res = deepcopy(s:zero)
  let l:dividend = deepcopy(l:a)
  let l:divisor = deepcopy(l:b)
  if s:_abs_compare(l:a,l:b) < 0
    return [l:res, l:a]
  endif

  let l:dividend_len = len(l:dividend.num)
  let l:divisor_len = len(l:divisor.num)
  let l:extend_nodes_len = l:dividend_len - l:divisor_len

  " # i=0
  " 1 234 567 890
  " 1 111
  " # i=1
  " 1 234 567 890
  "     1 111
  " # i=2
  " 1 234 567 890
  "         1 111
  "
  let l:part_divisor = l:divisor.num[0] + 1
  for i in range(l:extend_nodes_len+1)
    let l:part_dividend_idx = len(l:dividend.num) - l:divisor_len - l:extend_nodes_len + i
    if l:part_dividend_idx == 0
      let l:part_dividend = l:dividend.num[0]
    else " l:part_dividend_idx == 1
      let l:part_dividend = l:dividend.num[0] * s:node_max_num + l:dividend.num[1]
    endif

    let l:part_div = s:from_int(l:part_dividend / l:part_divisor)
    let l:extend_divisor = deepcopy(l:divisor)
    for j in range(l:extend_nodes_len - i)
      call add(l:extend_divisor.num, 0)
    endfor

    let l:tmp = s:mul(l:extend_divisor, l:part_div)
    let l:dividend = s:_abs_sub(l:dividend, l:tmp)

    while s:_abs_compare(l:dividend, l:extend_divisor) >= 0
      let l:dividend = s:_abs_sub(l:dividend, l:extend_divisor)
      let l:part_div = s:add(l:part_div, s:from_int(1))
    endwhile

    for j in range(l:extend_nodes_len - i)
      call add(l:part_div.num, 0)
    endfor
    let l:res = s:add(l:res, l:part_div)
  endfor

  let l:res.sign = l:a.sign * l:b.sign
  return [s:_fix_form(l:res), s:_fix_form(l:dividend)]
endfunction

function! s:div(a,b) abort
  return s:div_mod(a:a, a:b)[0]
endfunction

function! s:mod(a,b) abort
  return s:div_mod(a:a, a:b)[1]
endfunction

function! s:_abs_mul_shortint(a,n) abort
  " n < 10000
  if a:n >= s:node_max_num
    call s:_throw('too large: '.a:n)
  endif

  let l:res = deepcopy(a:a)
  let l:res_len = len(l:res.num)
  let l:carry = 0

  for i in range(res_len)
    let l:res_idx = l:res_len-i-1
    let l:tmp = l:res.num[l:res_idx] * a:n + l:carry
    let l:carry = l:tmp / s:node_max_num
    let l:tmp = l:tmp % s:node_max_num
    let l:res.num[l:res_idx] = l:tmp
  endfor

  if l:carry > 0
    call insert(l:res.num, l:carry, 0)
  endif
  return l:res
endfunction

function! s:sign(a) abort
  let l:a = s:_of(a:a)
  if l:a.num == [0]
    return 0
  else
    return l:a.sign
  endif
endfunction

function! s:neg(a) abort
  let l:a = s:_of(a:a)
  if s:compare(l:a, s:zero) == 0
    return l:a
  endif
  let l:res = deepcopy(l:a)
  let l:res.sign = l:res.sign*(-1)
  return l:res
endfunction

function! s:_fix_form(a) abort
  let l:res = a:a
  while len(l:res.num) > 1
    if l:res.num[0] == 0
      call remove(l:res.num, 0)
    else
      break
    endif
  endwhile
  return l:res
endfunction

function! s:_throw(message) abort
  throw 'vital: Data.Bigint: ' . a:message
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:
