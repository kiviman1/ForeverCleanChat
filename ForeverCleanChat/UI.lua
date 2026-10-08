-- Native, event-driven control panel. Artwork is bundled; all controls remain live WoW frames.
local _, NS = ...
local UI = {controls={}, tab='overview', logPage=1, listPage=1, listKind='domain'}
NS.UI = UI
local N, PAGE = NS.Normalize, 8
local unpack=unpack or table.unpack
local CONTENT = 628
local COLUMN, SECOND_COLUMN = 302, 326
local MEDIA='Interface\\AddOns\\ForeverCleanChat\\Media\\'
local SERIF='Fonts\\FRIZQT__.TTF'
UI.media={frame=MEDIA..'Frame.tga',emblem=MEDIA..'Emblem.tga'}
UI.maxScale=0.72
local C = {bg={0.036,0.035,0.032,1}, card={0.065,0.062,0.053,0.98},
    line={0.34,0.29,0.19,1}, teal={0.34,0.93,0.24,1}, gold={0.96,0.74,0.33,1},
    text={0.96,0.91,0.77,1}, muted={0.64,0.64,0.61,1}, red={0.93,0.30,0.24,1},
    active={0.15,0.105,0.046,1}, inactive={0.065,0.067,0.068,1}}
UI.metrics={home={width=760,height=724,contentX=34,contentY=-138,contentWidth=692},
    advanced={width=900,height=700,contentX=218,contentY=-145,contentWidth=CONTENT}}
local tabs = {{'overview','Home'}, {'log','Hidden messages'}, {'lists','Your lists'},
    {'settings','Settings'}, {'test','Local test'}}
local kinds = {{'domain','Domains'}, {'phrase','Phrases'}, {'allow','Allowed players'},
    {'block','Blocked players'}, {'domainAllow','Exceptions'}}
local eventLabels = {CHAT_MSG_CHANNEL='Public channels', CHAT_MSG_SAY='Say', CHAT_MSG_YELL='Yell',
    CHAT_MSG_WHISPER='Whisper', CHAT_MSG_EMOTE='Emotes'}
local reasons = {known_seller_domain='Known seller domain', known_seller_domain_obfuscated='Obfuscated seller domain',
    brand_commercial_context='Commercial seller advertisement', real_money_game_service='Service sold for real money',
    gold_commodity_ad='Gold sale', commercial_catalogue='Commercial service catalogue',
    strict_boost_sale='Boost or carry sale', ['manual-player']='Manually blocked player',
    user_defined='Your phrase rule', allowed='No blocking rule matched', disabled='Protection is paused',
    manual_allow='Allowed player', out_of_scope='Chat type is outside your scope'}

local function safe(value)
    if type(value)~='string' then value = value==nil and '' or tostring(value) end
    return N.SafeDisplay(value)
end
local function count(list) local n=0; for _ in pairs(list or {}) do n=n+1 end; return n end
local function make(kind, parent, name)
    local template = BackdropTemplateMixin and 'BackdropTemplate' or nil
    local ok, frame = pcall(CreateFrame, kind, name, parent, template)
    if not ok then frame = CreateFrame(kind, name, parent) end
    return frame
end
local function size(frame,w,h)
    if frame.SetSize then frame:SetSize(w,h) else frame:SetWidth(w); frame:SetHeight(h) end
end
local function color(region, rgba)
    if region.SetTextColor then region:SetTextColor(unpack(rgba)) end
end
local function serif(region,pixels)
    if region.SetFont then region:SetFont(SERIF,pixels,'') end
    if region.fitOwner then region.fitOwner.fontSize=pixels end
    if region.SetShadowColor then region:SetShadowColor(0,0,0,0.85); region:SetShadowOffset(1,-1) end
    return region
end
local function unboundedWidth(region,text)
    region:SetText(text)
    if region.GetUnboundedStringWidth then return region:GetUnboundedStringWidth() end
    local width=region:GetWidth()
    region:SetWidth(0)
    local measured=region:GetStringWidth()
    region:SetWidth(width)
    return measured
end
local function fitCaption(b)
    local f=b.caption
    if not f then return end
    f:SetWordWrap(false)
    if f.SetNonSpaceWrap then f:SetNonSpaceWrap(false) end
    if f.SetMaxLines then f:SetMaxLines(1) end
    local target=f:GetWidth()
    local base=b.fontSize or 12
    f:SetFont(SERIF,base,'')
    local text=b.fullLabel or ''
    local width=unboundedWidth(f,text)
    if width>target and base>10 then
        f:SetFont(SERIF,math.max(10,math.floor(base*target/width)),'')
        width=unboundedWidth(f,text)
    end
    b.truncated=width>target
    if b.truncated then
        -- Keep UTF-8 characters and escaped literal pipes intact when shortening display text.
        local ends,i={},1
        while i<=#text do
            local byte=string.byte(text,i)
            local length=byte==124 and string.byte(text,i+1)==124 and 2
                or byte>=240 and 4 or byte>=224 and 3 or byte>=192 and 2 or 1
            i=i+length; ends[#ends+1]=i-1
        end
        local lo,hi,best=0,#ends,''
        while lo<=hi do
            local mid=math.floor((lo+hi)/2)
            local candidate=string.sub(text,1,ends[mid] or 0)..'...'
            if unboundedWidth(f,candidate)<=target then best=candidate; lo=mid+1
            else hi=mid-1 end
        end
        f:SetText(best)
    else f:SetText(text) end
end
local function fill(parent,x,y,w,h,rgba,layer)
    local t=parent:CreateTexture(nil,layer or 'BACKGROUND')
    t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); size(t,w,h)
    if t.SetColorTexture then t:SetColorTexture(unpack(rgba))
    else t:SetTexture('Interface\\Buttons\\WHITE8X8'); t:SetVertexColor(unpack(rgba)) end
    return t
end
local function label(parent,text,x,y,width,font,rgba,height)
    local f=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlight')
    local pixels=font=='GameFontNormalLarge' and 20 or font=='GameFontHighlight' and 14 or 12
    f:SetFont(SERIF,pixels,'')
    f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); f:SetWidth(width)
    f:SetJustifyH('LEFT'); if f.SetJustifyV then f:SetJustifyV('TOP') end
    if height then f:SetHeight(height) end
    if f.SetWordWrap then f:SetWordWrap(true) end
    color(f,rgba or C.text); f:SetText(text); return f
end
local function surface(frame,rgba,border)
    if frame.SetBackdrop then
        frame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',
            tile=false,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
        if frame.SetBackdropColor then frame:SetBackdropColor(unpack(rgba or C.card)) end
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(unpack(border or C.line)) end
    else
        local w,h=frame:GetWidth(),frame:GetHeight()
        fill(frame,0,0,w,h,rgba or C.card)
        fill(frame,0,0,w,1,border or C.line); fill(frame,0,-h+1,w,1,border or C.line)
    end
end
local function button(parent,text,x,y,w,action,h)
    local b=make('Button',parent); size(b,w,h or 30)
    b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); surface(b)
    local padding=w<40 and 3 or 10
    b.caption=label(b,text,0,0,w-padding*2,'GameFontHighlightSmall',C.text,(h or 30)-6)
    b.fontSize=12; b.caption.fitOwner=b; b.fullLabel=text
    b.caption:ClearAllPoints(); b.caption:SetPoint('CENTER',b,'CENTER',0,0)
    b.caption:SetJustifyV('MIDDLE')
    b.caption:SetJustifyH('CENTER')
    fitCaption(b)
    b:SetScript('OnClick',function(self) if not self.disabled then action(self) end end)
    b:SetScript('OnEnter',function(self)
        if not self.disabled and self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(C.gold)) end
        if self.truncated and GameTooltip and GameTooltip.SetOwner then
            GameTooltip:SetOwner(self,'ANCHOR_TOPRIGHT')
            if GameTooltip.ClearLines then GameTooltip:ClearLines() end
            GameTooltip:AddLine(self.fullLabel,C.text[1],C.text[2],C.text[3],true)
            GameTooltip:Show()
        end
    end)
    b:SetScript('OnLeave',function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(self.active and C.gold or C.line)) end
        if self.truncated and GameTooltip then GameTooltip:Hide() end
    end)
    function b:SetLabel(value) self.fullLabel=value; fitCaption(self) end
    function b:FitCaption() fitCaption(self) end
    function b:SetActive(value)
        self.active=value; color(self.caption,value and C.gold or C.text)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(value and C.gold or C.line)) end
        if self.SetBackdropColor then self:SetBackdropColor(unpack(value and C.active or C.inactive)) end
    end
    function b:SetAvailable(value)
        self.disabled=not value
        if value then self:Enable() else self:Disable() end
        self:SetAlpha(value and 1 or 0.38)
    end
    return b
end
local function call(method,...)
    local fn=NS.Settings and NS.Settings[method]
    if not fn then UI.SetMessage('This control is not available yet.',true); return false end
    local success,ok,reason=pcall(fn,...)
    if not success or ok==false then
        UI.SetMessage(not success and 'The setting could not be applied.' or ('Could not apply: '..safe(reason)),true)
        return false
    end
    UI.SetMessage('Changes saved automatically')
    UI.Refresh(); return true
end
local function edit(parent,x,y,w,h,multiline,maxChars)
    local box
    if multiline then
        -- Native multiline EditBoxes grow to their text height. The viewport owns the fixed border.
        local viewport=make('Frame',parent); size(viewport,w,h)
        viewport:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); surface(viewport,C.bg)
        local scroll=CreateFrame('ScrollFrame',nil,viewport); size(scroll,w-20,h-16)
        scroll:SetPoint('TOPLEFT',viewport,'TOPLEFT',10,-8)
        local content=CreateFrame('Frame',nil,scroll); size(content,w-20,h-16)
        scroll:SetScrollChild(content)
        box=make('EditBox',content); box:SetPoint('TOPLEFT',content,'TOPLEFT',0,0)
        size(box,w-20,20)
        box.viewport,box.scroll,box.content=viewport,scroll,content
        local function range() return math.max(0,content:GetHeight()-scroll:GetHeight()) end
        local function refresh()
            content:SetHeight(math.max(scroll:GetHeight(),box:GetHeight()))
            if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
            scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll() or 0,range()))
        end
        box:SetScript('OnTextChanged',refresh); box:SetScript('OnSizeChanged',refresh)
        box:SetScript('OnCursorChanged',function(_,_,cursorY,_,cursorHeight)
            if type(cursorY)~='number' or type(cursorHeight)~='number' then return end
            refresh()
            local top,current=-cursorY,scroll:GetVerticalScroll() or 0
            if top<current then scroll:SetVerticalScroll(math.max(0,math.min(range(),top)))
            elseif top+cursorHeight>current+scroll:GetHeight() then
                scroll:SetVerticalScroll(math.max(0,math.min(range(),top+cursorHeight-scroll:GetHeight())))
            end
        end)
        scroll:EnableMouseWheel(true)
        scroll:SetScript('OnMouseWheel',function(_,delta)
            scroll:SetVerticalScroll(math.max(0,math.min(range(),(scroll:GetVerticalScroll() or 0)-delta*24)))
        end)
        viewport:EnableMouse(true); viewport:SetScript('OnMouseDown',function() box:SetFocus() end)
    else
        box=make('EditBox',parent); size(box,w,h)
        box:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); surface(box,C.bg)
    end
    box:SetAutoFocus(false); box:SetFontObject('GameFontHighlightSmall')
    box:SetFont(SERIF,12,'')
    if multiline then box:SetTextInsets(0,0,0,0) else box:SetTextInsets(10,10,5,5) end
    box:SetMaxLetters(maxChars or 160)
    if box.SetMultiLine then box:SetMultiLine(multiline==true) end
    if box.SetMaxBytes then box:SetMaxBytes(multiline and 4096 or 640) end
    if multiline and box.SetJustifyV then box:SetJustifyV('TOP') end
    box:SetScript('OnEscapePressed',function(self) self:ClearFocus(); UI.Hide() end)
    box:SetScript('OnEnterPressed',function(self) if not multiline then self:ClearFocus() end end)
    return box
end
local function check(parent,text,x,y,w,action)
    local b=button(parent,'',x,y,w,function(self) action(not self.checked) end,30)
    b.caption:SetJustifyH('LEFT'); b.caption:ClearAllPoints()
    b.caption:SetPoint('LEFT',b,'LEFT',38,0); b.caption:SetWidth(w-46); b.caption:SetText(text)
    b.fullLabel=text; b:FitCaption()
    b.mark=label(b,'',10,-8,18,'GameFontNormal',C.teal,20)
    b.mark:SetFont(SERIF,11,'')
    function b:SetChecked(value) self.checked=value==true; self.mark:SetText(self.checked and '[x]' or '[ ]'); self:SetActive(self.checked) end
    return b
end
local function heading(parent,title,description)
    label(parent,title,0,0,CONTENT,'GameFontNormalLarge',C.gold)
    label(parent,description,0,-30,CONTENT,'GameFontHighlightSmall',C.muted,34)
end
local function textScroll(parent,x,y,w,h)
    local holder=make('Frame',parent); holder:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); size(holder,w,h); surface(holder,C.bg)
    local scroll=CreateFrame('ScrollFrame',nil,holder); scroll:SetPoint('TOPLEFT',holder,'TOPLEFT',10,-10); size(scroll,w-34,h-20)
    local child=CreateFrame('Frame',nil,scroll); size(child,w-34,h-20)
    local body=label(child,'',0,0,w-36,'GameFontHighlightSmall',C.text)
    scroll:SetScrollChild(child)
    local function move(delta)
        local range=scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or math.max(0,child:GetHeight()-scroll:GetHeight())
        scroll:SetVerticalScroll(math.max(0,math.min(range,(scroll:GetVerticalScroll() or 0)+delta)))
    end
    scroll:EnableMouseWheel(true); scroll:SetScript('OnMouseWheel',function(_,delta) move(-delta*35) end)
    button(holder,'^',w-21,-4,18,function() move(-70) end,26)
    button(holder,'v',w-21,-h+30,18,function() move(70) end,26)
    function holder:SetBody(text)
        if self.lastText==text then return end
        self.lastText=text
        body:SetText(text)
        local contentHeight=body.GetStringHeight and body:GetStringHeight() or h-20
        child:SetHeight(math.max(h-20,contentHeight+8)); scroll:SetVerticalScroll(0)
    end
    holder.scroll,holder.body=scroll,body
    return holder
end
function UI.SetMessage(message,isError)
    UI.message=message; UI.messageError=isError
    if UI.footer then
        local text=message or 'Changes saved automatically'
        UI.footer:SetText(text); serif(UI.footer,#text>65 and 14 or 17)
        color(UI.footer,isError and C.red or C.muted)
    end
end

local function largeButton(parent,text,x,y,w,h,action,fontSize)
    local b=button(parent,text,x,y,w,action,h)
    b.caption:ClearAllPoints(); b.caption:SetPoint('CENTER',b,'CENTER',0,0)
    b.caption:SetWidth(w-26); b.caption:SetHeight(h-12); b.caption:SetJustifyV('MIDDLE')
    serif(b.caption,fontSize or 25)
    b:FitCaption()
    return b
end
local function circle(parent,x,y,diameter,rgba,layer)
    local t=parent:CreateTexture(nil,layer or 'ARTWORK')
    t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); size(t,diameter,diameter)
    t:SetTexture('Interface\\CHARACTERFRAME\\TempPortraitAlphaMask')
    if t.SetVertexColor then t:SetVertexColor(unpack(rgba)) end
    return t
end
local function card(parent,y,h)
    local f=make('Frame',parent); f:SetPoint('TOPLEFT',parent,'TOPLEFT',0,y); size(f,692,h)
    surface(f,C.card,C.line)
    -- A restrained inset bevel keeps the live controls readable over the stone artwork.
    fill(f,7,-6,678,1,{0.34,0.29,0.20,0.28},'BORDER')
    fill(f,7,-h+7,678,1,{0,0,0,0.55},'BORDER')
    return f
end
local function buildOverview(p)
    local protection=card(p,0,106); p.protectionCard=protection
    p.protectionLock=NS.CreateProtectionLock(protection,25,-17,54,68)
    UI.controls.protectionLock=p.protectionLock
    p.protectionLock:SetEnabled(NS.db.enabled,false)
    p:SetScript('OnHide',function() p.protectionLock:Finish() end)
    serif(label(protection,'Chat protection',94,-22,398,'GameFontNormalLarge',C.text,35),28)
    p.status=serif(label(protection,'',94,-60,398,'GameFontNormalLarge',C.teal,30),24)
    local toggle=largeButton(protection,'ON',526,-28,137,51,function() call('SetEnabled',not NS.db.enabled) end,23)
    if toggle.SetBackdrop then toggle:SetBackdrop(nil) end
    -- Circular ends plus a center strip form a real capsule rather than a square checkbox.
    toggle.trackOuter={circle(toggle,0,0,51,C.teal,'BACKGROUND'),
        fill(toggle,25,0,87,51,C.teal,'BACKGROUND'),circle(toggle,86,0,51,C.teal,'BACKGROUND')}
    local trackDark={0.025,0.19,0.016,1}
    toggle.trackInner={circle(toggle,3,-3,45,trackDark,'ARTWORK'),
        fill(toggle,25,-3,87,45,trackDark,'ARTWORK'),circle(toggle,89,-3,45,trackDark,'ARTWORK')}
    toggle.caption:SetWidth(75); toggle.caption:ClearAllPoints(); toggle.caption:SetPoint('LEFT',toggle,'LEFT',10,0)
    toggle.thumbRim=circle(toggle,88,-4,43,{0.30,0.43,0.12,1},'OVERLAY')
    toggle.thumb=circle(toggle,91,-7,37,{0.85,0.88,0.57,1},'OVERLAY')
    toggle.thumbHighlight=circle(toggle,97,-10,20,{0.97,0.99,0.77,0.46},'OVERLAY')
    local function toggleBorder() end
    toggle:SetScript('OnEnter',toggleBorder); toggle:SetScript('OnLeave',toggleBorder)
    UI.controls.overviewToggle=toggle; UI.controls.homeToggle=toggle

    local mode=card(p,-114,178); p.modeCard=mode
    serif(label(mode,'Filtering mode',29,-21,634,'GameFontNormalLarge',C.muted,30),24)
    UI.controls.overviewBalanced=largeButton(mode,'Balanced',26,-60,312,54,function() call('SetMode','balanced') end,26)
    UI.controls.overviewStrict=largeButton(mode,'Strict',354,-60,312,54,function() call('SetMode','strict') end,26)
    UI.controls.homeBalanced=UI.controls.overviewBalanced; UI.controls.homeStrict=UI.controls.overviewStrict
    p.modeDescription=serif(label(mode,'',29,-129,634,'GameFontHighlight',C.muted,37),21)

    local statistics=card(p,-300,122); p.statisticsCard=statistics
    serif(label(statistics,'Hidden this session',29,-21,366,'GameFontNormalLarge',C.muted,30),25)
    p.hiddenCounter=serif(label(statistics,'0',29,-61,350,'GameFontNormalLarge',C.text,50),44)
    p.cards={p.hiddenCounter}
    UI.controls.homeMessages=largeButton(statistics,'View messages',398,-43,268,57,function() UI.Show('log') end,25)
    UI.controls.homeMessages.caption:SetWidth(221); UI.controls.homeMessages.caption:ClearAllPoints(); UI.controls.homeMessages.caption:SetPoint('CENTER',UI.controls.homeMessages,'CENTER',-9,0)
    serif(label(UI.controls.homeMessages,'>',237,-14,22,'GameFontNormalLarge',C.gold,31),28)
    UI.controls.homeAdvanced=largeButton(p,'Advanced settings',0,-430,692,82,function() UI.Show('settings') end,27)
    UI.controls.homeAdvanced.caption:SetJustifyH('LEFT'); UI.controls.homeAdvanced.caption:SetWidth(585)
    UI.controls.homeAdvanced.caption:ClearAllPoints(); UI.controls.homeAdvanced.caption:SetPoint('LEFT',UI.controls.homeAdvanced,'LEFT',74,0)
    serif(label(UI.controls.homeAdvanced,'>',34,-25,26,'GameFontNormalLarge',C.gold,36),32)
end
local function selectedDomain(row)
    if not row then return nil end
    if row.detail then local host=N.Domain(row.detail); if host then return host end end
    local ok,_,_,_,why=pcall(NS.Rules.Evaluate,row.message or '',NS.db,{event=row.event or 'CHAT_MSG_CHANNEL'})
    if ok and type(why)=='table' and why.domain_matches and why.domain_matches[1] then return why.domain_matches[1].value end
    local normalized=N.Message(row.message or '')
    if normalized.valid and normalized.domain_candidates[1] then return normalized.domain_candidates[1].host end
end
local function buildLog(p)
    heading(p,'Hidden messages','The latest 50 hidden messages stay here for this session. Select one to inspect the decision.')
    UI.controls.logSearch=edit(p,0,-61,COLUMN,27,false,160)
    UI.controls.logSearch:SetScript('OnTextChanged',function() UI.logPage=1; UI.Refresh() end)
    p.count=label(p,'',0,-92,COLUMN,'GameFontHighlightSmall',C.muted,13)
    UI.controls.logClear=button(p,'Clear session log',CONTENT-188,-61,188,function() call('ClearLog'); UI.logSelected=nil; UI.Refresh() end)
    p.rows={}; UI.controls.logRows=p.rows
    for i=1,PAGE do
        local row=button(p,'',0,-110-(i-1)*36,COLUMN,function(self) UI.logSelected=self.entry; UI.Refresh() end,33)
        row.caption:SetJustifyH('LEFT'); row.caption:SetWidth(COLUMN-20); p.rows[i]=row
    end
    p.empty=label(p,'',14,-128,COLUMN-28,'GameFontHighlightSmall',C.muted,170)
    p.detail=textScroll(p,SECOND_COLUMN,-104,COLUMN,205)
    UI.controls.logAllow=button(p,'Allow player',SECOND_COLUMN,-322,144,function()
        if UI.logSelected then call('EditList','allow','add',UI.logSelected.author) end
    end)
    UI.controls.logBlock=button(p,'Block player',SECOND_COLUMN+158,-322,144,function()
        if UI.logSelected then call('EditList','block','add',UI.logSelected.author) end
    end)
    UI.controls.logDomainAllow=button(p,'Add domain exception',SECOND_COLUMN,-361,COLUMN,function()
        local host=selectedDomain(UI.logSelected)
        if host then call('EditList','domainAllow','add',host) end
    end)
    p.domain=label(p,'',SECOND_COLUMN,-407,COLUMN,'GameFontHighlightSmall',C.muted,38)
    UI.controls.logPrev=button(p,'< Previous',0,-409,106,function() UI.logPage=UI.logPage-1; UI.Refresh() end)
    UI.controls.logNext=button(p,'Next >',COLUMN-106,-409,106,function() UI.logPage=UI.logPage+1; UI.Refresh() end)
    p.page=label(p,'',116,-418,COLUMN-228,'GameFontHighlightSmall',C.muted); p.page:SetJustifyH('CENTER')
end
local function listEntries()
    local db,rows=NS.db,{}
    if UI.listKind=='domain' then
        local seen={}
        for _,item in ipairs(NS.Data.domains or {}) do
            local host=item.value
            if not seen[host] then
                seen[host]=true; rows[#rows+1]={key=host,label=host,builtin=true,
                    disabled=db.domainDisabled[host]==true,exception=db.domainAllow[host]==true,custom=db.domains[host]~=nil}
            end
        end
        for key,value in pairs(db.domains or {}) do
            if not seen[key] then rows[#rows+1]={key=key,label=type(value)=='string' and value or key,custom=true,exception=db.domainAllow[key]==true} end
        end
    else
        local field=UI.listKind=='phrase' and 'phrases' or UI.listKind
        for key in pairs(db[field] or {}) do rows[#rows+1]={key=key,label=key} end
    end
    table.sort(rows,function(a,b) return a.key<b.key end)
    local query=string.lower(UI.controls.listSearch:GetText() or '')
    if query~='' then
        local filtered={}; for _,row in ipairs(rows) do if string.find(string.lower(row.label),query,1,true) then filtered[#filtered+1]=row end end
        rows=filtered
    end
    return rows
end
local function buildLists(p)
    heading(p,'Your rules, your chat.','Manage domains, phrases and players. Each personal list supports up to 100 entries.')
    UI.controls.listsKinds={}
    local widths={101,89,143,143,112}; local x=0
    for i,item in ipairs(kinds) do
        local kind=item[1]
        UI.controls.listsKinds[kind]=button(p,item[2],x,-65,widths[i],function()
            UI.listKind=kind; UI.listPage=1; UI.listSelected=nil; UI.Refresh()
        end); x=x+widths[i]+10
    end
    label(p,'Search this list',0,-108,300,'GameFontHighlightSmall',C.muted)
    UI.controls.listSearch=edit(p,0,-128,CONTENT,30,false,160)
    UI.controls.listSearch:SetScript('OnTextChanged',function() UI.listPage=1; UI.Refresh() end)
    p.rows={}; UI.controls.listRows=p.rows
    for i=1,PAGE do
        local row=button(p,'',0,-170-(i-1)*25,CONTENT,function(self) UI.listSelected=self.entry; UI.Refresh() end,23)
        row.caption:SetJustifyH('LEFT'); row.caption:ClearAllPoints()
        row.caption:SetPoint('LEFT',row,'LEFT',10,0); p.rows[i]=row
    end
    p.empty=label(p,'',14,-188,CONTENT-28,'GameFontHighlightSmall',C.muted,130)
    UI.controls.listPrev=button(p,'< Previous',0,-393,106,function() UI.listPage=UI.listPage-1; UI.Refresh() end,26)
    UI.controls.listNext=button(p,'Next >',208,-393,106,function() UI.listPage=UI.listPage+1; UI.Refresh() end,26)
    p.page=label(p,'',116,-401,86,'GameFontHighlightSmall',C.muted); p.page:SetJustifyH('CENTER')
    UI.controls.listRemove=button(p,'Remove selected',CONTENT-216,-393,216,function()
        local selected=UI.listSelected; if not selected then return end
        local ok
        if UI.listKind=='domain' and selected.builtin then ok=call('SetDomainEnabled',selected.key,selected.disabled)
        else ok=call('EditList',UI.listKind,'remove',selected.key) end
        if ok then UI.listSelected=nil; UI.Refresh() end
    end,26)
    UI.controls.listInput=edit(p,0,-431,CONTENT-130,30,false,160)
    UI.controls.listAdd=button(p,'Add entry',CONTENT-116,-431,116,function()
        if call('EditList',UI.listKind,'add',UI.controls.listInput:GetText()) then
            UI.controls.listInput:SetText(''); UI.controls.listInput:ClearFocus(); UI.listSelected=nil; UI.Refresh()
        end
    end)
    p.hint=label(p,'',0,-374,CONTENT,'GameFontHighlightSmall',C.muted,17)
end
local function buildSettings(p)
    heading(p,'Protection settings','Changes apply immediately and are saved between sessions.')
    UI.controls.enabled=check(p,'Enable chat protection',0,-63,CONTENT,function(value) call('SetEnabled',value) end)
    label(p,'PROFILE',0,-111,COLUMN,'GameFontNormalSmall',C.gold)
    UI.controls.balanced=button(p,'Balanced',0,-134,144,function() call('SetMode','balanced') end)
    UI.controls.strict=button(p,'Strict',158,-134,144,function() call('SetMode','strict') end)
    label(p,'Balanced targets commercial advertising. Strict adds paid boost and carry sales.',0,-178,COLUMN,'GameFontHighlightSmall',C.muted,41)
    label(p,'KNOWN DOMAIN MENTIONS',SECOND_COLUMN,-111,COLUMN,'GameFontNormalSmall',C.gold)
    UI.controls.hideAll=button(p,'Hide all',SECOND_COLUMN,-134,144,function() call('SetDomainPolicy','hide_all') end)
    UI.controls.contextual=button(p,'With sales context',SECOND_COLUMN+158,-134,144,function() call('SetDomainPolicy','contextual') end)
    label(p,'Hide all catches every known seller domain. Sales context allows neutral mentions.',SECOND_COLUMN,-178,COLUMN,'GameFontHighlightSmall',C.muted,41)
    label(p,'FILTER THESE CHAT TYPES',0,-235,COLUMN,'GameFontNormalSmall',C.gold)
    UI.controls.events={}
    for i,event in ipairs(NS.Events) do
        local key=event
        UI.controls.events[key]=check(p,eventLabels[key] or safe(key),0,-258-(i-1)*34,COLUMN,function(value) call('SetChatEvent',key,value) end)
    end
    label(p,'ACCESS & WINDOW',SECOND_COLUMN,-235,COLUMN,'GameFontNormalSmall',C.gold)
    UI.controls.minimap=check(p,'Show minimap button',SECOND_COLUMN,-258,COLUMN,function(value) call('SetMinimapShown',value) end)
    UI.controls.resetWindow=button(p,'Center window',SECOND_COLUMN,-300,COLUMN,function()
        if call('ResetWindow') then UI.ApplyWindowPosition() end
    end)
    label(p,'Minimap: left-click opens this panel.\nRight-click opens Settings. Drag to move.',SECOND_COLUMN,-342,COLUMN,'GameFontHighlightSmall',C.muted,44)
    p.diagnostics=label(p,'',SECOND_COLUMN,-391,COLUMN,'GameFontHighlightSmall',C.muted,62)
end
local samples = {{'Known domain','mythicstore.com'}, {'Boost sale','WTS RFC boosts 5g/run'},
    {'Ordinary trade','WTS Copper Bar 2g per stack'}, {'Group finder','LFM WC need healer'}}
function UI.RunLocalTest()
    if not UI.controls.testInput or not NS.db then return end
    local sample=UI.controls.testInput:GetText() or ''
    if sample=='' then UI.lastTest=nil; UI.SetMessage('Enter a message to test.',true); UI.Refresh(); return false end
    local ok,block,reason,detail,explanation=pcall(NS.Rules.Evaluate,sample,NS.db,{event='CHAT_MSG_CHANNEL'})
    if not ok then UI.lastTest=nil; UI.SetMessage('The local classifier could not evaluate this sample.',true); UI.Refresh(); return false end
    UI.lastTest={block=block,reason=reason,detail=detail,explanation=explanation or {}}
    UI.SetMessage('Local test complete. No chat message sent; counters unchanged.'); UI.Refresh(); return true
end
local function buildTest(p)
    heading(p,'Understand a decision.','Enter a sample message. This runs the classifier locally without sending chat or changing counters.')
    UI.controls.testSamples={}; local x=0; local sampleWidth=(CONTENT-30)/4
    for i,item in ipairs(samples) do
        local sample=item[2]
        UI.controls.testSamples[i]=button(p,item[1],x,-65,sampleWidth,function()
            UI.controls.testInput:SetText(sample); UI.controls.testInput:ClearFocus(); UI.RunLocalTest()
        end); x=x+sampleWidth+10
    end
    UI.controls.testInput=edit(p,0,-111,CONTENT,94,true,4096)
    UI.controls.testRun=button(p,'Evaluate sample',0,-217,198,function() UI.controls.testInput:ClearFocus(); UI.RunLocalTest() end)
    UI.controls.selfTest=button(p,'Run built-in checks',212,-217,198,function()
        local ok,passed,total=pcall(NS.Rules.RunSelfTests)
        if ok then UI.SetMessage('Built-in rule checks: '..safe(passed)..' / '..safe(total)..' passed. Counters unchanged.',passed~=total)
        else UI.SetMessage('The built-in checks could not run.',true) end
    end)
    p.result=label(p,'Ready for a sample.',0,-268,CONTENT,'GameFontNormalLarge',C.muted)
    p.details=textScroll(p,0,-304,CONTENT,105)
    label(p,'This checks content rules and the active profile. Live chat also checks sender identity, your player lists and chat scope.',0,-425,CONTENT,'GameFontHighlightSmall',C.muted,34)
end

function UI.ApplyWindowPosition()
    local f=UI.frame; if not f then return end
    f:ClearAllPoints()
    local pos=NS.db and NS.db.ui and NS.db.ui.window
    if pos and pos.point and pos.relativePoint then f:SetPoint(pos.point,UIParent,pos.relativePoint,pos.x or 0,pos.y or 0)
    else f:SetPoint('CENTER',UIParent,'CENTER',0,0) end
end
local function saveWindow()
    local f=UI.frame; if not f then return end
    f:StopMovingOrSizing()
    local point,_,relativePoint,x,y=f:GetPoint(1)
    if NS.Settings and NS.Settings.SaveWindow then NS.Settings.SaveWindow(point,relativePoint,x,y) end
end
local function scaleWindow()
    if not UI.frame or not UIParent then return end
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    if type(w)=='number' and type(h)=='number' and w>0 and h>0 and UI.frame.SetScale then
        UI.frame:SetScale(math.min(UI.maxScale,(w-32)/UI.frame:GetWidth(),(h-32)/UI.frame:GetHeight()))
    end
end
local function applyLayout()
    local home=UI.tab=='overview'
    local dimensions=home and UI.metrics.home or UI.metrics.advanced
    if UI.viewMode~=(home and 'home' or 'advanced') then
        size(UI.frame,dimensions.width,dimensions.height)
        UI.viewMode=home and 'home' or 'advanced'
        UI.title:ClearAllPoints(); UI.title:SetPoint('TOPLEFT',UI.frame,'TOPLEFT',156,home and -57 or -53)
        UI.title:SetWidth(dimensions.width-216); serif(UI.title,home and 40 or 36)
        UI.controls.close:ClearAllPoints(); UI.controls.close:SetPoint('TOPRIGHT',UI.frame,'TOPRIGHT',-29,-29)
        UI.dragBar:SetWidth(dimensions.width-100)
        UI.footer:ClearAllPoints(); UI.footer:SetPoint('TOPLEFT',UI.frame,'TOPLEFT',51,-dimensions.height+68)
        UI.footer:SetWidth(dimensions.width-102)
        UI.feedbackFrame:ClearAllPoints(); UI.feedbackFrame:SetPoint('TOPLEFT',UI.frame,'TOPLEFT',51,-dimensions.height+68)
        UI.feedbackFrame:SetWidth(dimensions.width-102)
    end
    if home then UI.sidebar:Hide(); UI.subtitle:Hide() else UI.sidebar:Show(); UI.subtitle:Show() end
    scaleWindow()
end
local function build()
    local f=make('Frame',UIParent,'ForeverCleanChatPanel'); UI.frame=f
    size(f,UI.metrics.home.width,UI.metrics.home.height); f:SetFrameStrata('DIALOG'); f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true)
    f:Hide(); scaleWindow(); UI.ApplyWindowPosition()
    -- Keep transparent corners transparent; the bundled border owns the outer silhouette.
    local base=f:CreateTexture(nil,'BACKGROUND'); base:SetPoint('TOPLEFT',f,'TOPLEFT',24,-24); base:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-24,24)
    if base.SetColorTexture then base:SetColorTexture(unpack(C.bg)) else base:SetTexture('Interface\\Buttons\\WHITE8X8'); base:SetVertexColor(unpack(C.bg)) end
    local art=f:CreateTexture(nil,'BACKGROUND'); art:SetAllPoints(f); art:SetTexture(UI.media.frame)
    if art.SetDrawLayer then art:SetDrawLayer('BACKGROUND',1) end
    UI.frameArtwork=art
    local top=CreateFrame('Frame',nil,f); UI.dragBar=top; size(top,UI.metrics.home.width-100,126); top:SetPoint('TOPLEFT',f,'TOPLEFT',24,-18)
    top:EnableMouse(true); top:RegisterForDrag('LeftButton')
    top:SetScript('OnDragStart',function() f:StartMoving() end); top:SetScript('OnDragStop',saveWindow)
    f:SetScript('OnHide',function()
        if UI.controls.protectionLock then UI.controls.protectionLock:Finish() end
        saveWindow()
    end)
    f:SetScript('OnEvent',function() if f:IsShown() then scaleWindow() end end)
    if f.RegisterEvent then
        pcall(f.RegisterEvent,f,'DISPLAY_SIZE_CHANGED'); pcall(f.RegisterEvent,f,'UI_SCALE_CHANGED')
    end
    local icon=f:CreateTexture(nil,'ARTWORK'); UI.emblem=icon; size(icon,104,104); icon:SetPoint('TOPLEFT',f,'TOPLEFT',41,-28)
    icon:SetTexture(UI.media.emblem)
    UI.title=serif(label(f,'Forever Clean Chat',156,-57,544,'GameFontNormalLarge',C.gold,51),40)
    UI.subtitle=label(f,'',160,-101,610,'GameFontHighlightSmall',C.muted,22)
    local close=make('Button',f); size(close,34,34); surface(close); UI.controls.close=close
    if close.SetBackdropColor then close:SetBackdropColor(0.27,0.025,0.012,1); close:SetBackdropBorderColor(unpack(C.gold)) end
    close.strokes={}
    -- Draw the X with geometry so font width and ellipsis cannot replace the close symbol.
    if close.CreateLine then
        for _,direction in ipairs({-1,1}) do
            local stroke=close:CreateLine(nil,'OVERLAY')
            stroke:SetStartPoint('CENTER',close,-7,direction*7)
            stroke:SetEndPoint('CENTER',close,7,-direction*7)
            stroke:SetThickness(2)
            stroke:SetTexture('Interface\\Buttons\\WHITE8X8'); stroke:SetVertexColor(unpack(C.gold))
            close.strokes[#close.strokes+1]=stroke
        end
    else
        local glyph=close:CreateTexture(nil,'OVERLAY')
        glyph:SetPoint('CENTER',close,'CENTER',0,0); size(glyph,30,30)
        glyph:SetTexture('Interface\\Buttons\\UI-Panel-MinimizeButton-Up')
        glyph:SetVertexColor(unpack(C.gold)); close.closeGlyph=glyph
    end
    close:SetScript('OnClick',function() UI.Hide() end)
    close:SetScript('OnEnter',function(self) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(1,0.9,0.5,1) end end)
    close:SetScript('OnLeave',function(self) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(C.gold)) end end)
    UI.panels={}; UI.controls.tabs={}
    local sidebar=CreateFrame('Frame',nil,f); UI.sidebar=sidebar; size(sidebar,160,440); sidebar:SetPoint('TOPLEFT',f,'TOPLEFT',34,-145)
    UI.controls.backHome=button(sidebar,'< Back to home',0,0,160,function() UI.Show('overview') end,36)
    UI.controls.tabs.overview=UI.controls.backHome
    local builders={overview=buildOverview,log=buildLog,lists=buildLists,settings=buildSettings,test=buildTest}
    for i,item in ipairs(tabs) do
        local key=item[1]
        if key~='overview' then
            UI.controls.tabs[key]=button(sidebar,item[2],0,-61-(i-2)*55,160,function() UI.Show(key) end,42)
        end
        local p=CreateFrame('Frame',nil,f)
        if key=='overview' then p:SetPoint('TOPLEFT',f,'TOPLEFT',34,-138); size(p,692,512)
        else p:SetPoint('TOPLEFT',f,'TOPLEFT',218,-145); size(p,CONTENT,486) end
        builders[key](p); UI.panels[key]=p; p:Hide()
    end
    label(sidebar,'OFFLINE PROTECTION',7,-312,150,'GameFontNormalSmall',C.gold,31)
    label(sidebar,'Your rules and preferences stay on this computer.',7,-346,150,'GameFontHighlightSmall',C.muted,56)
    UI.footer=serif(label(f,UI.message or 'Changes saved automatically',51,-656,658,'GameFontHighlightSmall',C.muted,22),17)
    UI.footer:SetJustifyH('RIGHT')
    if UI.footer.SetMaxLines then UI.footer:SetMaxLines(1) end
    UI.feedbackFrame=CreateFrame('Frame',nil,f); size(UI.feedbackFrame,658,22); UI.feedbackFrame:EnableMouse(true)
    UI.feedbackFrame:SetScript('OnEnter',function(self)
        if not UI.message or not GameTooltip or not GameTooltip.SetOwner then return end
        GameTooltip:SetOwner(self,'ANCHOR_TOPRIGHT')
        if GameTooltip.ClearLines then GameTooltip:ClearLines() end
        GameTooltip:AddLine('Forever Clean Chat',C.gold[1],C.gold[2],C.gold[3])
        GameTooltip:AddLine(UI.message,0.90,0.87,0.78,true); GameTooltip:Show()
    end)
    UI.feedbackFrame:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    UI.viewMode=nil; applyLayout()
    if type(UISpecialFrames)=='table' then
        local present=false; for _,name in ipairs(UISpecialFrames) do if name=='ForeverCleanChatPanel' then present=true end end
        if not present then UISpecialFrames[#UISpecialFrames+1]='ForeverCleanChatPanel' end
    end
end
local function refreshOverview(p)
    local db=NS.db
    p.status:SetText(db.enabled and 'Active' or 'Paused'); color(p.status,db.enabled and C.teal or C.red)
    p.protectionLock:SetEnabled(db.enabled,true)
    p.hiddenCounter:SetText(safe(NS.sessionBlocked or 0))
    p.modeDescription:SetText(db.mode=='strict' and 'Also filters paid boost and carry offers.' or 'Filters seller advertising and real-money service offers.')
    UI.controls.overviewBalanced:SetActive(db.mode=='balanced'); UI.controls.overviewStrict:SetActive(db.mode=='strict')
    local toggle=UI.controls.overviewToggle
    toggle:SetLabel(db.enabled and 'ON' or 'OFF')
    local trackColor=db.enabled and C.teal or C.red
    for _,t in ipairs(toggle.trackOuter) do
        if t==toggle.trackOuter[2] and t.SetColorTexture then t:SetColorTexture(unpack(trackColor))
        elseif t.SetVertexColor then t:SetVertexColor(unpack(trackColor)) end
    end
    local innerColor=db.enabled and {0.025,0.19,0.016,1} or {0.22,0.030,0.018,1}
    for _,t in ipairs(toggle.trackInner) do
        if t==toggle.trackInner[2] and t.SetColorTexture then t:SetColorTexture(unpack(innerColor))
        elseif t.SetVertexColor then t:SetVertexColor(unpack(innerColor)) end
    end
    toggle.caption:ClearAllPoints(); toggle.caption:SetPoint(db.enabled and 'LEFT' or 'RIGHT',toggle,db.enabled and 'LEFT' or 'RIGHT',db.enabled and 7 or -7,0)
    toggle.thumbRim:ClearAllPoints(); toggle.thumbRim:SetPoint('TOPLEFT',toggle,'TOPLEFT',db.enabled and 88 or 6,-4)
    toggle.thumb:ClearAllPoints(); toggle.thumb:SetPoint('TOPLEFT',toggle,'TOPLEFT',db.enabled and 91 or 9,-7)
    toggle.thumbHighlight:ClearAllPoints(); toggle.thumbHighlight:SetPoint('TOPLEFT',toggle,'TOPLEFT',db.enabled and 97 or 15,-10)
end
local function refreshLog(p)
    local all=NS.log or {}; local log={}
    local query=string.lower(UI.controls.logSearch:GetText() or '')
    for _,row in ipairs(all) do
        local searchable=string.lower((row.author or '')..' '..(row.message or '')..' '..(row.rule_id or '')..' '..(row.reason or ''))
        if query=='' or string.find(searchable,query,1,true) then log[#log+1]=row end
    end
    local pages=math.max(1,math.ceil(#log/PAGE))
    UI.logPage=math.max(1,math.min(pages,UI.logPage))
    local found=false; for _,row in ipairs(log) do if row==UI.logSelected then found=true end end
    if not found then UI.logSelected=log[#log] end
    p.count:SetText(query=='' and (safe(#all)..' / 50 messages | search above') or (safe(#log)..' matches | newest first'))
    for i,b in ipairs(p.rows) do
        local row=log[#log-(UI.logPage-1)*PAGE-i+1]; b.entry=row
        if row then
            b:SetLabel(safe(row.author)..'  |  '..safe(row.rule_id or row.reason)); b:SetActive(row==UI.logSelected); b:Show()
        else b:Hide() end
    end
    p.empty:SetText(#all==0 and 'No messages hidden yet.\n\nYou can try the classifier in Local test while you wait for a chat message.' or 'No hidden messages match your search.')
    if #log==0 then p.empty:Show() else p.empty:Hide() end
    p.page:SetText(UI.logPage..' / '..pages); UI.controls.logPrev:SetAvailable(UI.logPage>1); UI.controls.logNext:SetAvailable(UI.logPage<pages)
    UI.controls.logClear:SetAvailable(#all>0)
    local row=UI.logSelected; local host=selectedDomain(row)
    local canName=row and NS.NameKey(row.author)~=nil
    UI.controls.logAllow:SetAvailable(canName); UI.controls.logBlock:SetAvailable(canName); UI.controls.logDomainAllow:SetAvailable(host~=nil)
    if row then
        local explanation = safe(reasons[row.reason] or row.reason)
        p.detail:SetBody('PLAYER\n'..safe(row.author)..'\n\nDECISION\n'..explanation..'\n'..safe(row.rule_id or 'Personal rule')
            ..'\n\nMESSAGE\n'..safe(row.message)..'\n\nCHAT TYPE\n'..safe(eventLabels[row.event] or row.event)
            ..((row.indicator_ids and #row.indicator_ids>0) and ('\n\nINDICATORS\n'..safe(table.concat(row.indicator_ids,', '))) or ''))
        p.domain:SetText(host and ('Exception: '..safe(host)..'\nApplies to domain rules only.') or 'No domain found in this message.')
    else p.detail:SetBody('Select a hidden message to see its full text and rule. Scroll here to read longer messages.'); p.domain:SetText('') end
end
local function refreshLists(p)
    local rows=listEntries(); local pages=math.max(1,math.ceil(#rows/PAGE))
    UI.listPage=math.max(1,math.min(pages,UI.listPage))
    local selected
    for _,row in ipairs(rows) do if UI.listSelected and row.key==UI.listSelected.key then selected=row end end
    UI.listSelected=selected
    for kind,b in pairs(UI.controls.listsKinds) do b:SetActive(kind==UI.listKind) end
    for i,b in ipairs(p.rows) do
        local row=rows[(UI.listPage-1)*PAGE+i]; b.entry=row
        if row then
            local suffix=''
            if UI.listKind=='domain' then
                suffix='  |  '..(row.builtin and 'Built-in' or 'Custom')..(row.builtin and row.custom and ' / Your override' or '')
                    ..(row.disabled and ' / Disabled' or '')..(row.exception and ' / Exception' or '')
            end
            b:SetLabel(safe(row.label)..suffix); b:SetActive(selected and selected.key==row.key); b:Show()
        else b:Hide() end
    end
    p.empty:SetText(UI.controls.listSearch:GetText()~='' and 'No entries match your search.' or 'This list is empty. Add an entry below.')
    if #rows==0 then p.empty:Show() else p.empty:Hide() end
    p.page:SetText(UI.listPage..' / '..pages); UI.controls.listPrev:SetAvailable(UI.listPage>1); UI.controls.listNext:SetAvailable(UI.listPage<pages)
    UI.controls.listRemove:SetAvailable(selected~=nil)
    UI.controls.listRemove:SetLabel(selected and selected.builtin and (selected.disabled and 'Enable selected domain' or 'Disable selected domain') or 'Remove selected')
    local hints={domain='Domain: example.com. Disabling a built-in entry preserves your override.',phrase='Phrase: 3-160 normalized bytes. Matches complete words.',
        allow='Player name, optionally with -Realm. An allow entry takes priority.',block='Player name, optionally with -Realm. Applies to selected chat types.',domainAllow='Domain exceptions skip domain rules. Other content rules still apply.'}
    p.hint:SetText(hints[UI.listKind])
end
local function refreshSettings(p)
    local db=NS.db
    UI.controls.enabled:SetChecked(db.enabled); UI.controls.balanced:SetActive(db.mode=='balanced'); UI.controls.strict:SetActive(db.mode=='strict')
    UI.controls.hideAll:SetActive(db.known_domain_mention_policy=='hide_all'); UI.controls.contextual:SetActive(db.known_domain_mention_policy=='contextual')
    for event,b in pairs(UI.controls.events) do b:SetChecked(not db.chatEvents or db.chatEvents[event]~=false) end
    UI.controls.minimap:SetChecked(not (db.ui and db.ui.minimap and db.ui.minimap.hide))
    local observed=count(NS.apiObservedEvents); local registered=NS.registeredCount or 0
    p.diagnostics:SetText('Diagnostics: registered '..safe(registered)..' / '..#NS.Events..' chat hooks.\n'
        ..'Live chat types observed: '..observed..' / '..#NS.Events..'. Errors: '..safe(NS.sessionErrors or 0)..'.\n'
        ..'Registration alone does not verify live filtering.')
end
local function refreshTest(p)
    local result=UI.lastTest
    if not result then p.result:SetText('Ready for a sample.'); color(p.result,C.muted); p.details:SetBody('Try one of the examples or enter your own message above.'); return end
    p.result:SetText(result.block and 'HIDE  |  This message would be hidden.' or 'ALLOW  |  This message would remain visible.')
    color(p.result,result.block and C.gold or C.teal)
    local why=result.explanation; local parts={'Reason: '..safe(reasons[result.reason] or result.reason), 'Rule: '..safe(why.rule_id or 'No blocking rule')}
    if result.detail then parts[#parts+1]='Detail: '..safe(result.detail) end
    if why.indicator_ids and #why.indicator_ids>0 then parts[#parts+1]='Indicators: '..safe(table.concat(why.indicator_ids,', ')) end
    for _,match in ipairs(why.domain_matches or {}) do
        parts[#parts+1]='Domain: '..safe(match.value)..' | '..safe(match.kind)..' | transform: '..safe(match.transform)
    end
    local features={}; for key,value in pairs(why.features or {}) do if value==true then features[#features+1]=safe(key) end end
    table.sort(features); if #features>0 then parts[#parts+1]='Signals: '..table.concat(features,', ') end
    p.details:SetBody(table.concat(parts,'\n\n'))
end
function UI.Refresh()
    if not UI.frame or not NS.db then return end
    if not UI.frame:IsShown() then
        if UI.controls.protectionLock then UI.controls.protectionLock:SetEnabled(NS.db.enabled,false) end
        return
    end
    applyLayout()
    UI.subtitle:SetText('v'..safe(NS.VERSION)..'  |  '..safe(NS.Data.dataset_version)..' offline rules')
    for key,p in pairs(UI.panels) do if key==UI.tab then p:Show() else p:Hide() end; UI.controls.tabs[key]:SetActive(key==UI.tab) end
    if UI.tab~='overview' then UI.controls.protectionLock:SetEnabled(NS.db.enabled,false) end
    local refreshers={overview=refreshOverview,log=refreshLog,lists=refreshLists,settings=refreshSettings,test=refreshTest}
    refreshers[UI.tab](UI.panels[UI.tab]); UI.SetMessage(UI.message,UI.messageError)
end
function UI.Initialize()
    if UI.initialized then return true end
    UI.initialized=true
    if NS.AddChangeListener then NS.AddChangeListener(function(kind)
        if kind=='window' then UI.ApplyWindowPosition() end
        UI.Refresh()
    end) end
    return true
end
function UI.Show(tab)
    if type(CreateFrame)~='function' or not UIParent then return false,'ui_unavailable' end
    if not NS.db and NS.Initialize then NS.Initialize() end
    if not NS.db then return false,'not_initialized' end
    UI.Initialize()
    if not UI.frame then
        local ok,err=pcall(build)
        if not ok then
            -- WoW frames cannot be deleted. Hide a partial build and permit a fresh attempt.
            if UI.frame and UI.frame.Hide then pcall(UI.frame.Hide,UI.frame) end
            UI.frame,UI.panels,UI.footer,UI.subtitle=nil,nil,nil,nil
            UI.viewMode,UI.sidebar,UI.title,UI.emblem,UI.dragBar,UI.feedbackFrame=nil,nil,nil,nil,nil,nil
            UI.controls={}; UI.lastError=tostring(err); NS.uiErrors=(NS.uiErrors or 0)+1
            UI.SetMessage('The control panel could not open. Try /reload, then /fcc.',true)
            if NS.Print then NS.Print('The control panel could not open. Try /reload, then /fcc. Diagnostics: /fcc status.') end
            return false,'ui_build_failed'
        end
    end
    if tab=='localtest' then tab='test' elseif tab=='history' then tab='log' elseif tab=='home' then tab='overview' end
    if tab and UI.panels[tab] then UI.tab=tab end
    if not UI.frame:IsShown() then UI.controls.protectionLock:SetEnabled(NS.db.enabled,false) end
    scaleWindow(); UI.frame:Show(); UI.Refresh(); return true
end
function UI.Hide()
    if not UI.frame then return end
    for _,key in ipairs({'listInput','listSearch','logSearch','testInput'}) do if UI.controls[key] then UI.controls[key]:ClearFocus() end end
    UI.frame:Hide()
end
function UI.Toggle()
    if UI.frame and UI.frame:IsShown() then UI.Hide(); return true end
    return UI.Show()
end
