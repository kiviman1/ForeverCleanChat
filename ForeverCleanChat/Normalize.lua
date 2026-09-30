-- Bounded UTF-8, markup and host parsing; Lua 5.1-compatible, no WoW API.
-- Finite maps intentionally do not claim complete Unicode support.
local _, NS = ...
local N = {}; NS.Normalize = N
local byte, char, sub, find, gsub = string.byte,string.char,string.sub,string.find,string.gsub
local concat, lower = table.concat,string.lower
local normalizationData=NS.Data and NS.Data.normalization or {}
local transformsData=normalizationData.domain_transforms or {}
local function bound(value,fallback,maximum)
 return type(value)=='number' and value>=1 and value<=maximum and math.floor(value) or fallback
end
-- Data can tighten work budgets; the documented hard ceilings remain in code.
local MAX_BYTES=bound(normalizationData.message_max_bytes,4096,4096)
local MAX_CANDIDATES=bound(normalizationData.max_domain_candidates,32,32)
local MAX_VISIBLE=bound(normalizationData.max_candidate_visible_codepoints,128,128)
local MAX_GAP=bound(normalizationData.max_separator_codepoints_between_signature_characters,3,3)
local LEET_MAX=transformsData.leet_max_substitutions==0 and 0 or bound(transformsData.leet_max_substitutions,2,2)
local mathStarts = {0x1D400,0x1D41A,0x1D434,0x1D44E,0x1D468,0x1D482,
 0x1D5A0,0x1D5BA,0x1D5D4,0x1D5EE,0x1D608,0x1D622,0x1D63C,0x1D656,0x1D670,0x1D68A}
local latin = {
 [0xC0]='a',[0xC1]='a',[0xC2]='a',[0xC3]='a',[0xC4]='a',[0xC5]='a',
 [0xE0]='a',[0xE1]='a',[0xE2]='a',[0xE3]='a',[0xE4]='a',[0xE5]='a',
 [0xC7]='c',[0xE7]='c',[0xC8]='e',[0xC9]='e',[0xCA]='e',[0xCB]='e',
 [0xE8]='e',[0xE9]='e',[0xEA]='e',[0xEB]='e',[0xCC]='i',[0xCD]='i',
 [0xCE]='i',[0xCF]='i',[0xEC]='i',[0xED]='i',[0xEE]='i',[0xEF]='i',
 [0x130]='i',[0x131]='i',[0xD1]='n',[0xF1]='n',[0xD2]='o',[0xD3]='o',
 [0xD4]='o',[0xD5]='o',[0xD6]='o',[0xF2]='o',[0xF3]='o',[0xF4]='o',
 [0xF5]='o',[0xF6]='o',[0xD9]='u',[0xDA]='u',[0xDB]='u',[0xDC]='u',
 [0xF9]='u',[0xFA]='u',[0xFB]='u',[0xFC]='u',[0x15E]='s',[0x15F]='s',
 [0x11E]='g',[0x11F]='g',[0xDF]='ss',
}
local confusable = {
 [0x430]='a',[0x251]='a',[0x441]='c',[0x3F2]='c',[0x435]='e',[0x456]='i',
 [0x3B9]='i',[0x131]='i',[0x458]='j',[0x43E]='o',[0x3BF]='o',[0x440]='p',
 [0x3C1]='p',[0x455]='s',[0x445]='x',[0x3C7]='x',[0x443]='y',[0x3C5]='y',
 [0x4BB]='h',[0x2C6D]='a',[0x3F9]='c',
}
local ignored = {
 [0x200B]=true,[0x200C]=true,[0x200D]=true,[0x2060]=true,[0xFEFF]=true,[0xAD]=true,
 [0x202A]=true,[0x202B]=true,[0x202C]=true,[0x202D]=true,[0x202E]=true,
 [0x2066]=true,[0x2067]=true,[0x2068]=true,[0x2069]=true,
}
local dotWords = {dot=true,nokta=true,punkt=true,punto=true}
local dotMarkers={['[dot]']=true,['(dot)']=true,['{dot}']=true}
local dotCharacters={[46]=true,[0x3002]=true,[0xFF61]=true}
local leet={o={['0']=true},i={['1']=true},e={['3']=true},a={['4']=true},s={['5']=true},t={['7']=true}}
local icons = {star=true,circle=true,diamond=true,triangle=true,moon=true,square=true,cross=true,skull=true}
local function decode(s,i)
 local a=byte(s,i); if not a then return nil,i end; if a<128 then return a,i+1 end
 local count,cp,minimum
 if a>=194 and a<=223 then count,cp,minimum=2,a-192,128
 elseif a>=224 and a<=239 then count,cp,minimum=3,a-224,2048
 elseif a>=240 and a<=244 then count,cp,minimum=4,a-240,65536
 else return nil,i+1 end
 for j=1,count-1 do
  local b=byte(s,i+j); if not b or b<128 or b>191 then return nil,i+1 end
  cp=cp*64+b-128
 end
 if cp<minimum or cp>0x10FFFF or (cp>=0xD800 and cp<=0xDFFF) then return nil,i+1 end
 return cp,i+count
end
-- Literal table data only: no evaluation, generated patterns, locale, or IDNA.
if transformsData.selected_confusables then
 confusable={}
 for ascii,alternatives in pairs(transformsData.selected_confusables) do
  if type(ascii)=='string' and ascii:match('^[a-z]$') then
   for _,value in ipairs(alternatives) do
    local cp,finish=decode(value,1)
    if cp and finish==#value+1 then confusable[cp]=ascii end
   end
  end
 end
end
if transformsData.format_characters_to_ignore_in_domain_candidate then
 ignored={}
 for _,value in ipairs(transformsData.format_characters_to_ignore_in_domain_candidate) do
  local code=type(value)=='string' and value:match('^U%+([A-Fa-f0-9]+)$')
  local cp=code and tonumber(code,16)
  if cp and cp<=0x10FFFF then ignored[cp]=true end
 end
end
if transformsData.dot_characters then
 dotCharacters={}
 for _,value in ipairs(transformsData.dot_characters) do
  local cp,finish=decode(value,1)
  if cp and finish==#value+1 then dotCharacters[cp]=true end
 end
end
if transformsData.dot_words then
 dotWords,dotMarkers={},{}
 for _,value in ipairs(transformsData.dot_words) do
  if type(value)=='string' and #value<=24 then
   if value:match('^[a-z]+$') then dotWords[value]=true else dotMarkers[value]=true end
  end
 end
end
if transformsData.leet_alternatives_for_canonical_ascii_letters then
 leet={}
 for letter,alternatives in pairs(transformsData.leet_alternatives_for_canonical_ascii_letters) do
  if type(letter)=='string' and letter:match('^[a-z]$') then
   leet[letter]={}
   for _,value in ipairs(alternatives) do
    if type(value)=='string' and #value==1 and value:match('^[0-9]$') then leet[letter][value]=true end
   end
  end
 end
end
local function encode(cp)
 if cp<128 then return char(cp) end
 if cp<2048 then return char(192+math.floor(cp/64),128+cp%64) end
 if cp<65536 then return char(224+math.floor(cp/4096),128+math.floor(cp/64)%64,128+cp%64) end
 return char(240+math.floor(cp/262144),128+math.floor(cp/4096)%64,128+math.floor(cp/64)%64,128+cp%64)
end
local function casepoint(cp)
 if cp>=65 and cp<=90 then return cp+32 end
 if cp>=0x410 and cp<=0x42F then return cp+32 end
 if cp==0x401 then return 0x451 end
 if cp>=0x400 and cp<=0x40F then return cp+80 end
 if cp>=0x391 and cp<=0x3AB and cp~=0x3A2 then return cp+32 end
 if cp==0x4BA then return 0x4BB end
 if cp==0x2C6D then return 0x251 end
 if cp==0x3F9 then return 0x3F2 end
 return cp
end
local function whitespace(cp)
 return cp==32 or (cp>=9 and cp<=13) or cp==0xA0 or cp==0x3000
  or (cp>=0x2000 and cp<=0x200A) or cp==0x2028 or cp==0x2029 or cp==0x202F
end
local function combining(cp) return cp>=0x300 and cp<=0x36F end
local function validUTF8(s)
 local i=1; while i<=#s do local cp; cp,i=decode(s,i); if not cp then return false end end
 return true
end
N.ValidUTF8=validUTF8

local function markup(s)
 local out,offsets,itemBytes,urls,length,work={},{},{},{},0,0
 local function append(a,b,item)
  if b<a then return end; out[#out+1]=sub(s,a,b)
  for p=a,b do length=length+1; offsets[length]=p; itemBytes[length]=item or false end
 end
 local parse
 parse=function(a,b,item,depth)
  if depth>4 then return false end
  local i=a
  while i<=b do
   if sub(s,i,i)=='|' then
    work=work+1; if work>256 then return false end
    local tag=sub(s,i+1,i+1)
    if tag=='c' and sub(s,i+2,i+9):match('^%x%x%x%x%x%x%x%x$') then i=i+10
    elseif tag=='r' then i=i+2
    elseif tag=='|' then append(i,i,item); i=i+2
    elseif tag=='T' or tag=='A' then
     local finish=find(s,tag=='T' and '|t' or '|a',i+2,true)
     if not finish or finish+1>b then return false end; i=finish+2
    elseif tag=='H' then
     local label=find(s,'|h',i+2,true)
     local finish=label and find(s,'|h',label+2,true)
     if not finish or finish+1>b then return false end
     local payload=sub(s,i+2,label-1)
     if sub(payload,1,4)=='url:' then
      urls[#urls+1]={text=sub(payload,5),raw_start=i+6,raw_finish=label-1}
     end
     if not parse(label+2,finish-1,item or sub(payload,1,5)=='item:',depth+1) then return false end
     i=finish+2
    else append(i,i,item); i=i+1 end
   elseif sub(s,i,i)=='{' then
    -- Decorative icon names are short; never repeatedly scan the whole tail.
    local localFinish=find(sub(s,i,i+16),'}',2,true)
    local finish=localFinish and (i+localFinish-1)
    local tag=finish and lower(sub(s,i+1,finish-1))
    if finish and finish<=b and (tag:match('^rt[1-8]$') or icons[tag]) then i=finish+1
    else append(i,i,item); i=i+1 end
   else append(i,i,item); i=i+1 end
  end
  return true
 end
 if not parse(1,#s,false,0) then return nil,'markup-budget-or-malformed' end
 return concat(out),offsets,itemBytes,urls
end
function N.StripMarkup(s)
 if type(s)~='string' or #s>MAX_BYTES or not validUTF8(s) then return '' end
 local display=markup(s); return display or ''
end
local function semantic(display,offsets,itemBytes)
 local out,map,items,ends,length,i,previousSpace={},{},{},{},0,1,false
 while i<=#display do
  local start,cp=i; cp,i=decode(display,i)
  local value
  if whitespace(cp) or cp<32 or cp==127 then value=' '
  else
   cp=casepoint(cp); value=latin[cp] or encode(cp)
   if cp==0x2018 or cp==0x2019 then value="'" end
   if cp==0x2010 or cp==0x2011 then value='-' end
  end
  if value~=' ' or not previousSpace then
   out[#out+1]=value
   for j=1,#value do
    length=length+1; map[length]=offsets and offsets[start] or start
    ends[length]=offsets and offsets[i-1] or i-1
    items[length]=itemBytes and itemBytes[start] or false
   end
  end
  previousSpace=value==' '
 end
 return concat(out),map,items,ends
end
function N.Ascii(s)
 if type(s)~='string' or #s>MAX_BYTES or not validUTF8(s) then return '' end
 local text=semantic(s); return text
end
local function isword(cp)
 if cp<128 then return (cp>=48 and cp<=57) or (cp>=97 and cp<=122) or (cp>=65 and cp<=90) end
 return (cp>=0xC0 and cp<=0x2AF and cp~=0xD7 and cp~=0xF7)
  or (cp>=0x300 and cp<=0x52F) or (cp>=0x590 and cp<=0x1FFF)
  or (cp>=0x24B6 and cp<=0x24E9) or (cp>=0x2C00 and cp<=0xD7FF)
  or (cp>=0xF900 and cp<=0xFAFF) or (cp>=0xFF10 and cp<=0xFF5A)
  or (cp>=0x1D400 and cp<=0x1D6A3)
end
local function tokenize(text,itemBytes)
 local tokens,clauses,itemSpans,i,clause,clauseStart={},{},{},1,1,1
 local function finishClause(position)
  local current=clauses[clause]
  if current then
   current.finish=position; current.text=sub(text,current.start,position); clause=clause+1
  end
  clauseStart=position+1
 end
 while i<=#text do
  local start=i; local cp,nextIndex=decode(text,i)
  if isword(cp) then
   local item=itemBytes[i] or false; i=nextIndex
   while i<=#text do
    local nextCP,finish=decode(text,i)
    if not isword(nextCP) or (itemBytes[i] or false)~=item then break end
    i=finish
   end
   local token={text=sub(text,start,i-1),start=start,finish=i-1,clause=clause,item=item}
   tokens[#tokens+1]=token
   if not clauses[clause] then clauses[clause]={first=#tokens,start=clauseStart} end
   clauses[clause].last=#tokens; clauses[clause].finish=i-1
   if item then itemSpans[#itemSpans+1]={start=start,finish=i-1} end
  else
   i=nextIndex
   local innerDot=byte(text,start-1) and sub(text,start-1,start-1):match('[%w]') and sub(text,i,i):match('[%w]')
   if cp==33 or cp==63 or cp==59 or (cp==46 and not innerDot) then finishClause(start) end
  end
 end
 local current=clauses[clause]
 if current then current.finish=#text end
 for _,c in ipairs(clauses) do c.text=c.text or sub(text,c.start,c.finish) end
 return tokens,clauses,itemSpans
end
function N.Text(s)
 if type(s)~='string' or #s>MAX_BYTES or not validUTF8(s) then return '' end
 local text=semantic(N.StripMarkup(s)); local tokens=tokenize(text,{})
 local words={}; for i=1,#tokens do words[i]=tokens[i].text end
 return concat(words,' ')
end

local function domainFold(display)
 local chars,map,transforms,i,ignoredRun,previousLatin,pendingTransform={},{},{},1,0,false,nil
 while i<=#display do
  local start,cp=i; cp,i=decode(display,i)
  local value,transform
  if cp>=0xFF01 and cp<=0xFF5E then cp=cp-65248; transform='fullwidth' end
  cp=casepoint(cp)
  if ignored[cp] or (combining(cp) and previousLatin) then
   ignoredRun=ignoredRun+1; value=ignoredRun<=MAX_GAP and '' or '~'
   transform=combining(cp) and 'combining' or 'format'
  else
   ignoredRun=0
   if dotCharacters[cp] then value='.'; if cp~=46 then transform='unicode-dot' end
   elseif confusable[cp] then value=confusable[cp]; transform='confusable'
   elseif latin[cp] then value=latin[cp]; transform='accent'
   elseif whitespace(cp) then value=(cp==10 or cp==13) and '\n' or ' '
   elseif cp>=0x24B6 and cp<=0x24CF then value=char(97+cp-0x24B6); transform='circled'
   elseif cp>=0x24D0 and cp<=0x24E9 then value=char(97+cp-0x24D0); transform='circled'
   elseif cp<128 then value=char(cp)
   else
    for j=1,#mathStarts do
     if cp>=mathStarts[j] and cp<mathStarts[j]+26 then value=char(97+cp-mathStarts[j]); transform='mathematical'; break end
    end
    value=value or '~'
   end
  end
  if value=='' then pendingTransform=transform
  elseif pendingTransform then transform=transform or pendingTransform; pendingTransform=nil end
  for j=1,#value do chars[#chars+1]=sub(value,j,j); map[#chars]=start; transforms[#chars]=transform end
  previousLatin=(value~='' and value:match('^[a-z]$')~=nil) or (value=='' and previousLatin)
 end
 return concat(chars),map,transforms
end
local function validHost(host)
 if #host>253 or not host:match('^[a-z0-9][a-z0-9%.%-]*%.[a-z][a-z]+$') then return false end
 for label in host:gmatch('[^.]+') do
  if #label>63 or not label:match('^[a-z0-9]') or not label:match('[a-z0-9]$') then return false end
 end
 return not host:find('..',1,true)
end
local function urlHost(value)
 value=gsub(value,'[.,!;%)%]%}]+$','')
 local start=value:match('^https?://()') or 1
 local finish=(value:find('[/#?]',start) or (#value+1))-1
 local authority=sub(value,start,finish)
 if not authority then return nil end
 local userinfo=authority:match('.*@()')
 if userinfo then start=start+userinfo-1; authority=sub(authority,userinfo) end
 local port=authority:find(':%d+$'); if port then finish=start+port-2; authority=sub(authority,1,port-1) end
 if sub(authority,1,4)=='www.' then start=start+4; authority=sub(authority,5) end
 if sub(authority,-1)=='.' then finish=finish-1; authority=sub(authority,1,-2) end
 if validHost(authority) then return authority,start,finish end
end
local function candidates(display,offsets,payloads)
 local stream,map,transformations=domainFold(display)
 local result,seen,consumed,work={},{},{},0
 local function add(host,a,b,transform,source,rawStart,rawFinish,externalEligible)
  if b-a+1>MAX_VISIBLE then return false end
  if not validHost(host) then return true end
  local key=source..':'..a..':'..b..':'..host
  if seen[key] then return true end; seen[key]=true; work=work+1
  if work>MAX_CANDIDATES then return false end
  local displayFinish=map[b]
  if source=='display' and displayFinish then local cp,finish=decode(display,displayFinish); displayFinish=finish-1 end
  result[#result+1]={host=host,start=source=='display' and map[a] or nil,finish=source=='display' and displayFinish or nil,
   raw_start=rawStart or (offsets and offsets[map[a]]),raw_finish=rawFinish or (offsets and offsets[displayFinish]),
   kind=(transform=='literal' or transform=='url') and 'exact' or 'obfuscated',transform=transform,source=source,
   external_eligible=externalEligible~=false}
  return true
 end
 -- Consume the whole visible URL once; path, query and userinfo are not rescanned.
 local p=1
 while p<=#stream do
  local a,b=stream:find('[^%s<>"|]+',p); if not a then break end
  local block=sub(stream,a,b)
  local scheme=block:find('https?://')
  local prefix=scheme or ((block:match('^[%[%(%{]*()')) or 1)
  local address=sub(block,prefix)
  local naked=address:match('^[a-z0-9][a-z0-9%.%-]*%.[a-z][a-z]+[/#?]')
  local authority=address:match('^[^@/]+@[a-z0-9][a-z0-9%.%-]*%.[a-z][a-z]+')
  if scheme or naked or authority then
   for j=a,b do consumed[j]=true end
   local host,hostStart,hostFinish=urlHost(address)
   if host then
    local first,last=a+prefix+hostStart-2,a+prefix+hostFinish-2
    local transform='url'
    for q=first,last do if transformations[q] then transform=transformations[q] end end
    if not add(host,first,last,transform,'display') then return nil,'domain-budget' end
   end
  end
  p=b+1
 end
 for i=1,#payloads do
  local folded,payloadMap,payloadTransforms=domainFold(payloads[i].text)
  local host,first,last=urlHost(folded)
  if host then
   local transform='url'
   for q=first,last do if payloadTransforms[q] then transform=payloadTransforms[q] end end
   local cp,finish=decode(payloads[i].text,payloadMap[last])
   if not add(host,first,last,transform,'payload',payloads[i].raw_start+payloadMap[first]-1,
    payloads[i].raw_start+finish-2) then return nil,'domain-budget' end
  end
 end
 local atoms,i,gap={},1,0
 while i<=#stream do
  local c=sub(stream,i,i)
  if consumed[i] then atoms[#atoms+1]={kind='boundary',start=i,finish=i}; i=i+1; gap=0
  elseif c==' ' then gap=gap+1; i=i+1
  elseif c:match('[a-z0-9%-]') then
   local start=i
   repeat i=i+1; c=sub(stream,i,i) until i>#stream or consumed[i] or not c:match('[a-z0-9%-]')
   atoms[#atoms+1]={kind='word',text=sub(stream,start,i-1),start=start,finish=i-1,gap=gap}; gap=0
  else
   local close=({['[']=']',['(']=')',['{']='}'})[c]
   local localFinish=close and find(sub(stream,i,i+26),close,2,true)
   local finish=localFinish and (i+localFinish-1)
   local marker
   if finish then
    local inner=sub(stream,i+1,finish-1)
    local trimmed=gsub(gsub(inner,'^ *',''),' *$','')
    local leading=#inner-#gsub(inner,'^ *','')
    local trailing=#inner-#gsub(inner,' *$','')
    if leading<=MAX_GAP and trailing<=MAX_GAP and dotMarkers[c..trimmed..close] then marker=true
    else finish=nil end
   end
   atoms[#atoms+1]={kind=(c=='.' or marker) and 'dot' or 'boundary',start=i,finish=finish or i,gap=gap,marker=marker~=nil}
   i=(finish or i)+1; gap=0
  end
 end
 for j=2,#atoms-1 do
  local atom=atoms[j]
  if atom.kind=='word' and dotWords[atom.text] and atom.gap>0 and atom.gap<=MAX_GAP
   and atoms[j+1].gap>0 and atoms[j+1].gap<=MAX_GAP and atoms[j-1].kind=='word' and atoms[j+1].kind=='word' then
   atom.kind='dot'; atom.marker=true
  end
 end
 local function leftLabel(index)
  local atom=atoms[index]; if not atom or atom.kind~='word' then return nil end
  local start=index
  if #atom.text==1 then
   while start>1 and atoms[start].gap>0 and atoms[start].gap<=MAX_GAP
    and atoms[start-1].kind=='word' and #atoms[start-1].text==1 do start=start-1 end
  end
  return start,index
 end
 local function rightLabel(index)
  local atom=atoms[index]; if not atom or atom.kind~='word' then return nil end
  local finish=index
  if #atom.text==1 then
   while atoms[finish+1] and atoms[finish+1].gap>0 and atoms[finish+1].gap<=MAX_GAP
    and atoms[finish+1].kind=='word' and #atoms[finish+1].text==1 do finish=finish+1 end
  end
  return index,finish
 end
 local j=1
 while j<=#atoms do
  if atoms[j].kind=='dot' then
   local left=leftLabel(j-1); local _,right=rightLabel(j+1)
   if left and right and atoms[j].gap<=MAX_GAP and atoms[j+1].gap<=MAX_GAP then
    while left>2 and atoms[left-1].kind=='dot' and atoms[left].gap<=MAX_GAP and atoms[left-1].gap<=MAX_GAP do
     local previous=leftLabel(left-2); if not previous then break end; left=previous
    end
    while atoms[right+2] and atoms[right+1].kind=='dot' and atoms[right+1].gap<=MAX_GAP and atoms[right+2].gap<=MAX_GAP do
     local _,following=rightLabel(right+2); if not following then break end; right=following
    end
    local pieces,transform,spaced,explicitDotWord={},'literal',false,false
    for k=left,right do
     pieces[#pieces+1]=atoms[k].kind=='dot' and '.' or atoms[k].text
     if atoms[k].marker then
      if transform=='literal' or transform=='spaced' then transform='dot-word' end
      spaced=true; explicitDotWord=true
     elseif k>left and atoms[k].gap>0 then
      if transform=='literal' then transform='spaced' end
      spaced=true
     end
     for q=atoms[k].start,atoms[k].finish do if transformations[q] then transform=transformations[q] end end
    end
    local a,b=atoms[left].start,atoms[right].finish
    local before,after=sub(stream,a-1,a-1),sub(stream,b+1,b+1)
    local leftDot,rightDot=a-1,b+1
    while sub(stream,leftDot,leftDot)=='.' and leftDot>0 do leftDot=leftDot-1 end
    while sub(stream,rightDot,rightDot)=='.' and rightDot<=#stream do rightDot=rightDot+1 end
    local malformedLeft=before=='.' and sub(stream,leftDot,leftDot):match('[a-z0-9%-]')
    local malformedRight=after=='.' and sub(stream,rightDot,rightDot):match('[a-z0-9%-]')
    if before~='~' and after~='~' and not malformedLeft and not malformedRight
     and not (before:match('[a-z0-9%-]') or after:match('[a-z0-9%-]')) then
     local host=concat(pieces)
     local eligible=not spaced or explicitDotWord
     if spaced then
      -- Reconstructing separated signature characters is safe for known roots.
      -- It must not turn sentence punctuation ("only. PayPal") into a website.
      for _,indicator in ipairs(NS.Data and NS.Data.domains or {}) do
       local root=indicator.value
       if host==root or sub(host,-#root-1)=='.'..root then eligible=true; break end
      end
     end
     if not add(host,a,b,transform,'display',nil,nil,eligible) then return nil,'domain-budget' end
    end
    -- Every maximal host cluster is processed once, avoiding quadratic rescans.
    j=right
   end
  end
  j=j+1
 end
 return result
end
function N.DomainText(s)
 if type(s)~='string' or not validUTF8(s) or #s>MAX_BYTES then return '' end
 local text=domainFold(s); return text
end
function N.Domain(s)
 if type(s)~='string' or #s==0 or #s>MAX_BYTES or not validUTF8(s) then return nil end
 local list=candidates(s,nil,{})
 if not list or #list~=1 then return nil end
 local host=gsub(list[1].host,'^www%.','')
 local folded=domainFold(s); folded=gsub(gsub(folded,'^%s+',''),'%s+$','')
 if folded:match('^https?://') then return host,host end
 if not folded:match('%s') and folded:match('^[a-z0-9][a-z0-9%.%-]*%.[a-z][a-z]+[/#?]') then return host,host end
 local start,finish=list[1].start,list[1].finish
 if start and sub(s,1,start-1):match('^%s*$') and sub(s,finish+1):match('^[%s%./?#]*$') then return host,host end
 if validHost(folded) then return gsub(folded,'^www%.',''),gsub(folded,'^www%.','') end
 return nil
end
function N.Message(s)
 if type(s)~='string' then return {valid=false,reason='unreadable'} end
 if #s==0 or #s>MAX_BYTES then return {valid=false,reason='empty-or-too-long'} end
 if not validUTF8(s) then return {valid=false,reason='invalid-utf8'} end
 local display,offsets,itemBytes,payloads=markup(s)
 if not display then return {valid=false,reason=offsets} end
 local domains,reason=candidates(display,offsets,payloads)
 if not domains then return {valid=false,reason=reason} end
 local text,map,items,ends=semantic(display,offsets,itemBytes)
 local tokens,clauses,itemSpans=tokenize(text,items); local words={}
 for i=1,#tokens do
  local token=tokens[i]; token.raw_start=map[token.start]; token.raw_finish=ends[token.finish]; words[i]=token.text
 end
 for i=1,#domains do
  local candidate=domains[i]
  for j=1,#tokens do
   if candidate.raw_start and tokens[j].raw_start>=candidate.raw_start then candidate.clause=tokens[j].clause; break end
  end
 end
 return {valid=true,raw=s,display_text=display,display_offsets=offsets,semantic_text=text,price_text=text,
  semantic_offsets=map,semantic_end_offsets=ends,words=' '..concat(words,' ')..' ',ascii=text,tokens=tokens,clauses=clauses,
  item_spans=itemSpans,domain_candidates=domains}
end
local function hostMatch(host,root,commercial)
 if host==root or sub(host,-#root-1)=='.'..root then return true,false end
 if not commercial then return false end
 -- Compare the complete structural root; custom roots can contain more labels.
 -- Only the registrable label may use finite leet substitutions.
 if #host<#root or (#host>#root and sub(host,-#root-1,-#root-1)~='.') then return false end
 local candidate=sub(host,-#root)
 local prefix,label,tld=root:match('^(.-)([^.]+)%.([^.]+)$')
 if not label then return false end
 local labelStart=#prefix+1
 local labelFinish=labelStart+#label-1
 local count=0
 for i=1,#root do
  local a,b=sub(root,i,i),sub(candidate,i,i)
  if a~=b then
   if i<labelStart or i>labelFinish or not (leet[a] and leet[a][b]) then return false end
   count=count+1; if count>LEET_MAX then return false end
  end
 end
 return count>0,true
end
function N.MatchDomains(normalized,indicators,commercial,excluded)
 local out={}; if not normalized or not normalized.valid then return out end
 local seen={}
 for i=1,#(normalized.domain_candidates or {}) do
  local candidate=normalized.domain_candidates[i]
  for j=1,#(indicators or {}) do
   local indicator=indicators[j]; local root=indicator.value or indicator.domain
   if type(root)=='string' and not (excluded and (excluded[root] or excluded[indicator.id])) then
    local matched,isLeet=hostMatch(candidate.host,root,commercial)
    local key=tostring(indicator.id or root)..':'..tostring(candidate.raw_start)
    if matched and not seen[key] then
     seen[key]=true
     out[#out+1]={id=indicator.id,value=root,kind=isLeet and 'obfuscated' or candidate.kind,
      transform=isLeet and 'leet' or candidate.transform,start=candidate.start,finish=candidate.finish,
      raw_start=candidate.raw_start,raw_finish=candidate.raw_finish,clause=candidate.clause,host=candidate.host}
    end
   end
  end
 end
 return out
end
function N.SafeDisplay(s)
 if type(s)~='string' then return '' end
 return (gsub(gsub(sub(s,1,MAX_BYTES),'|','||'),'[%c]',' '))
end
