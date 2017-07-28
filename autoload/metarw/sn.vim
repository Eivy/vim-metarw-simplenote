if !exists('s:token')
  let s:email = ''
  let s:token = ''
  let s:titles = {}
endif

function! metarw#sn#complete(arglead, cmdline, cursorpos)
  if len(s:authorization())
    return [[], 'sn:', '']
  endif
  let url = printf('https://simple-note.appspot.com/api2/index?auth=%s&email=%s', s:token, s:email)
  let res = webapi#http#get(url)
  let nodes = webapi#json#decode(iconv(res.content, 'utf-8', &encoding)).data
  let candidate = []
  for node in nodes
    if !node.deleted
      if !has_key(s:titles, node.key)
        let url = printf('https://simple-note.appspot.com/api2/data/%s?auth=%s&email=%s', node.key, s:token, s:email)
        let res = webapi#http#get(url)
        let lines = split(iconv(webapi#json#decode(res.content).content, 'utf-8', &encoding), "\n")
        let s:titles[node.key] = len(lines) > 0 ? lines[0] : ''
      endif
      call add(candidate, printf('sn:%s:%s', escape(node.key, ' \/#%'), escape(s:titles[node.key], ' \/#%')))
    endif
  endfor
  return [candidate, 'sn:', '']
endfunction

function! metarw#sn#read(fakepath)
  let l = split(a:fakepath, ':')
  if len(l) < 2
    let result = []
    let nodes = metarw#sn#complete('','','')
    for node in nodes[0]
      call add(result, {
            \  'label': split(node, ':')[2],
            \  'fakepath': node
      \})
    endfor
    return ['browse', result]
  endif
  let err = s:authorization()
  if len(err)
    return ['error', err)
  endif
  let url = printf('https://simple-note.appspot.com/api2/data/%s?auth=%s&email=%s', l[1], s:token, s:email)
  let res = webapi#http#get(url)
  if res.status == '200'
    setlocal noswapfile
    put =iconv(webapi#json#decode(res.content).content, 'utf-8', &encoding)
    let b:sn_key = l[1]
    return ['done', '']
  endif
  return ['error', res.header[0]]
endfunction

function! metarw#sn#write(fakepath, line1, line2, append_p)
  let l = split(a:fakepath, ':', 1)
  if len(l) < 2
    return ['error', printf('Unexpected fakepath: %s', string(a:fakepath))]
  endif
  let err = s:authorization()
  if len(err)
    return ['error', err)
  endif
  let data = {}
    if len(l[1]) > 0
      let url = printf('https://simple-note.appspot.com/api2/data/%s?auth=%s&email=%s', l[1], s:token, s:email)
      let data.key = l[1]
      if line('$') == 1 && getline(1) == ''
        let data.deleted = 1
      else
        let data.deleted = 0
      endif
    else
      let url = printf('https://simple-note.appspot.com/api2/data?auth=%s&email=%s', s:token, s:email)
    endif
    let data.content = iconv(join(getline(a:line1, a:line2), "\n"), &encoding, 'utf-8')
    let res = webapi#http#post(url, webapi#json#encode(data))
    if res.status == '200'
      if len(l[1]) == 0
        let json = webapi#json#decode(res.content)
        let key = json.key
        if json.deleted
          echomsg 'deleted'
        else
          silent! exec 'file '.printf('sn:%s', escape(key, ' \/#%'))
        endif
        set nomodified
      endif
      return ['done', '']
    endif
  endif
  return ['error', res.header[0]]
endfunction

function! s:authorization()
  if len(s:token) > 0
    return ''
  endif
  if exists("g:SimplenoteUsername")
    let s:email = g:SimplenoteUsername
  else
      let s:email = input('email:')
  endif

  if exists("g:SimplenotePassword")
    let password = g:SimplenotePassword
  else
    let password = inputsecret('password:')
  endif

  let creds = webapi#base64#b64encode(printf('email=%s&password=%s', s:email, password))
  let res = webapi#http#post('https://simple-note.appspot.com/api/login', creds)
  if res.status == '200'
    let s:token = res.content
    return ''
  endif
  return 'failed to authenticate'
endfunction

