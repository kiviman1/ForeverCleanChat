-- Native, event-driven control panel. No libraries, remote assets or chat output.
local _, NS = ...
local UI = {controls={}, tab='overview', logPage=1, listPage=1, listKind='domain'}
NS.UI = UI
local N, PAGE = NS.Normalize, 8
local unpack=unpack or table.unpack
local WIDTH, HEIGHT, CONTENT = 860, 590, 650
local C = {bg={0.025,0.040,0.047,0.98}, card={0.047,0.072,0.081,1},
    line={0.16,0.23,0.25,1}, teal={0.40,0.85,0.76,1}, gold={0.87,0.72,0.43,1},
    text={0.90,0.92,0.91,1}, muted={0.58,0.66,0.68,1}, red={0.96,0.44,0.40,1}}
local tabs = {{'overview','Overview','Protection at a glance'}, {'log','Hidden messages','Review this session'},
    {'lists','Your lists','Fine-tune your rules'}, {'settings','Settings','Choose your preferences'},
    {'test','Local test','Try a sample safely'}}
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
local function fill(parent,x,y,w,h,rgba,layer)
    local t=parent:CreateTexture(nil,layer or 'BACKGROUND')
    t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); size(t,w,h)
    if t.SetColorTexture then t:SetColorTexture(unpack(rgba))
    else t:SetTexture('Interface\\Buttons\\WHITE8X8'); t:SetVertexColor(unpack(rgba)) end
    return t
end
local function label(parent,text,x,y,width,font,rgba,height)
    local f=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlight')
    f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); f:SetWidth(width)
    f:SetJustifyH('LEFT'); if f.SetJustifyV then f:SetJustifyV('TOP') end
    if height then f:SetHeight(height) end
    if f.SetWordWrap then f:SetWordWrap(true) end
    color(f,rgba or C.text); f:SetText(text); return f
end
local function surface(frame,rgba,border)
    if frame.SetBackdrop then
        frame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',
            tile=false,edgeSize=1,insets={left=1,right=1,top=1,bottom=1}})
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
    b.caption=label(b,text,padding,-9,w-padding*2,'GameFontHighlightSmall',C.text,(h or 30)-10)
    b.caption:SetJustifyH('CENTER')
    b:SetScript('OnClick',function(self) if not self.disabled then action(self) end end)
    b:SetScript('OnEnter',function(self)
        if not self.disabled and self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(C.teal)) end
    end)
    b:SetScript('OnLeave',function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(self.active and C.teal or C.line)) end
    end)
    function b:SetLabel(value) self.caption:SetText(value) end
    function b:SetActive(value)
        self.active=value; color(self.caption,value and C.teal or C.text)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(value and C.teal or C.line)) end
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
    UI.SetMessage('Saved. Your preference is applied immediately.')
    UI.Refresh(); return true
end
local function edit(parent,x,y,w,h,multiline,maxChars)
    local box=make('EditBox',parent); size(box,w,h)
    box:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y); surface(box,C.bg)
    box:SetAutoFocus(false); box:SetFontObject('GameFontHighlightSmall')
    box:SetTextInsets(10,10,8,8); box:SetMaxLetters(maxChars or 160)
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
    b.mark=label(b,'',10,-8,18,'GameFontNormal',C.teal,20)
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
    if UI.footer then UI.footer:SetText(message or 'Preferences are saved automatically.'); color(UI.footer,isError and C.red or C.muted) end
end

local function buildOverview(p)
    heading(p,'A quieter adventure.','Commercial spam is hidden quietly. Review a decision or make the rules your own.')
    p.status=label(p,'',0,-73,CONTENT,'GameFontNormalLarge',C.teal)
    p.description=label(p,'',0,-102,CONTENT,'GameFontHighlightSmall',C.muted,34)
    p.cards={}
    for i,title in ipairs({'Hidden this session','Hidden all time','Saved in session log'}) do
        local card=make('Frame',p); size(card,206,86); card:SetPoint('TOPLEFT',p,'TOPLEFT',(i-1)*222,-150); surface(card)
        label(card,title,14,-15,180,'GameFontHighlightSmall',C.muted)
        p.cards[i]=label(card,'0',14,-42,180,'GameFontNormalLarge',C.text)
    end
    label(p,'CHOOSE YOUR PROTECTION',0,-261,CONTENT,'GameFontNormalSmall',C.gold)
    UI.controls.overviewBalanced=button(p,'Balanced',0,-286,160,function() call('SetMode','balanced') end)
    UI.controls.overviewStrict=button(p,'Strict',174,-286,160,function() call('SetMode','strict') end)
    label(p,'Balanced targets commercial spam. Strict also catches paid boost and carry offers. Ordinary trading and group recruitment remain welcome.',0,-330,CONTENT,'GameFontHighlightSmall',C.muted,42)
    UI.controls.overviewToggle=button(p,'',0,-391,190,function() call('SetEnabled',not NS.db.enabled) end)
    button(p,'Review hidden messages',204,-391,214,function() UI.Show('log') end)
    button(p,'Try a local sample',432,-391,218,function() UI.Show('test') end)
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
    UI.controls.logSearch=edit(p,0,-61,314,27,false,160)
    UI.controls.logSearch:SetScript('OnTextChanged',function() UI.logPage=1; UI.Refresh() end)
    p.count=label(p,'',0,-92,314,'GameFontHighlightSmall',C.muted,13)
    UI.controls.logClear=button(p,'Clear session log',462,-61,188,function() call('ClearLog'); UI.logSelected=nil; UI.Refresh() end)
    p.rows={}; UI.controls.logRows=p.rows
    for i=1,PAGE do
        local row=button(p,'',0,-110-(i-1)*36,314,function(self) UI.logSelected=self.entry; UI.Refresh() end,33)
        row.caption:SetJustifyH('LEFT'); row.caption:SetWidth(294); p.rows[i]=row
    end
    p.empty=label(p,'',14,-128,285,'GameFontHighlightSmall',C.muted,170)
    p.detail=textScroll(p,330,-104,320,205)
    UI.controls.logAllow=button(p,'Allow player',330,-322,153,function()
        if UI.logSelected then call('EditList','allow','add',UI.logSelected.author) end
    end)
    UI.controls.logBlock=button(p,'Block player',497,-322,153,function()
        if UI.logSelected then call('EditList','block','add',UI.logSelected.author) end
    end)
    UI.controls.logDomainAllow=button(p,'Add domain exception',330,-361,320,function()
        local host=selectedDomain(UI.logSelected)
        if host then call('EditList','domainAllow','add',host) end
    end)
    p.domain=label(p,'',330,-407,320,'GameFontHighlightSmall',C.muted,38)
    UI.controls.logPrev=button(p,'< Previous',0,-409,106,function() UI.logPage=UI.logPage-1; UI.Refresh() end)
    UI.controls.logNext=button(p,'Next >',208,-409,106,function() UI.logPage=UI.logPage+1; UI.Refresh() end)
    p.page=label(p,'',116,-418,86,'GameFontHighlightSmall',C.muted); p.page:SetJustifyH('CENTER')
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
    local widths={105,93,147,147,118}; local x=0
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
        row.caption:SetJustifyH('LEFT'); row.caption:SetPoint('TOPLEFT',row,'TOPLEFT',10,-6); p.rows[i]=row
    end
    p.empty=label(p,'',14,-188,CONTENT-28,'GameFontHighlightSmall',C.muted,130)
    UI.controls.listPrev=button(p,'< Previous',0,-393,106,function() UI.listPage=UI.listPage-1; UI.Refresh() end,26)
    UI.controls.listNext=button(p,'Next >',208,-393,106,function() UI.listPage=UI.listPage+1; UI.Refresh() end,26)
    p.page=label(p,'',116,-401,86,'GameFontHighlightSmall',C.muted); p.page:SetJustifyH('CENTER')
    UI.controls.listRemove=button(p,'Remove selected',434,-393,216,function()
        local selected=UI.listSelected; if not selected then return end
        local ok
        if UI.listKind=='domain' and selected.builtin then ok=call('SetDomainEnabled',selected.key,selected.disabled)
        else ok=call('EditList',UI.listKind,'remove',selected.key) end
        if ok then UI.listSelected=nil; UI.Refresh() end
    end,26)
    UI.controls.listInput=edit(p,0,-431,520,30,false,160)
    UI.controls.listAdd=button(p,'Add entry',534,-431,116,function()
        if call('EditList',UI.listKind,'add',UI.controls.listInput:GetText()) then
            UI.controls.listInput:SetText(''); UI.controls.listInput:ClearFocus(); UI.listSelected=nil; UI.Refresh()
        end
    end)
    p.hint=label(p,'',0,-374,CONTENT,'GameFontHighlightSmall',C.muted,17)
end
local function buildSettings(p)
    heading(p,'Protection settings','Changes apply immediately and are saved between sessions.')
    UI.controls.enabled=check(p,'Enable chat protection',0,-63,CONTENT,function(value) call('SetEnabled',value) end)
    label(p,'PROFILE',0,-111,304,'GameFontNormalSmall',C.gold)
    UI.controls.balanced=button(p,'Balanced',0,-134,150,function() call('SetMode','balanced') end)
    UI.controls.strict=button(p,'Strict',164,-134,150,function() call('SetMode','strict') end)
    label(p,'Balanced targets commercial advertising. Strict adds paid boost and carry sales.',0,-178,314,'GameFontHighlightSmall',C.muted,41)
    label(p,'KNOWN DOMAIN MENTIONS',336,-111,314,'GameFontNormalSmall',C.gold)
    UI.controls.hideAll=button(p,'Hide all',336,-134,150,function() call('SetDomainPolicy','hide_all') end)
    UI.controls.contextual=button(p,'With sales context',500,-134,150,function() call('SetDomainPolicy','contextual') end)
    label(p,'Hide all catches every known seller domain. Sales context allows neutral mentions.',336,-178,314,'GameFontHighlightSmall',C.muted,41)
    label(p,'FILTER THESE CHAT TYPES',0,-235,314,'GameFontNormalSmall',C.gold)
    UI.controls.events={}
    for i,event in ipairs(NS.Events) do
        local key=event
        UI.controls.events[key]=check(p,eventLabels[key] or safe(key),0,-258-(i-1)*34,314,function(value) call('SetChatEvent',key,value) end)
    end
    label(p,'ACCESS & WINDOW',336,-235,314,'GameFontNormalSmall',C.gold)
    UI.controls.minimap=check(p,'Show minimap button',336,-258,314,function(value) call('SetMinimapShown',value) end)
    UI.controls.resetWindow=button(p,'Center window',336,-300,314,function()
        if call('ResetWindow') then UI.ApplyWindowPosition() end
    end)
    label(p,'Minimap: left-click opens this panel.\nRight-click opens Settings. Drag to move.',336,-342,314,'GameFontHighlightSmall',C.muted,44)
    p.diagnostics=label(p,'',336,-391,314,'GameFontHighlightSmall',C.muted,62)
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
    UI.controls.testSamples={}; local x=0
    for i,item in ipairs(samples) do
        local sample=item[2]
        UI.controls.testSamples[i]=button(p,item[1],x,-65,155,function()
            UI.controls.testInput:SetText(sample); UI.controls.testInput:ClearFocus(); UI.RunLocalTest()
        end); x=x+165
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
        UI.frame:SetScale(math.min(1,(w-24)/WIDTH,(h-24)/HEIGHT))
    end
end
local function build()
    local f=make('Frame',UIParent,'ForeverCleanChatPanel'); UI.frame=f
    size(f,WIDTH,HEIGHT); f:SetFrameStrata('DIALOG'); f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true)
    surface(f,C.bg,C.line); f:Hide(); scaleWindow(); UI.ApplyWindowPosition()
    local top=CreateFrame('Frame',nil,f); size(top,WIDTH-80,73); top:SetPoint('TOPLEFT',f,'TOPLEFT',1,-1)
    top:EnableMouse(true); top:RegisterForDrag('LeftButton')
    top:SetScript('OnDragStart',function() f:StartMoving() end); top:SetScript('OnDragStop',saveWindow)
    f:SetScript('OnHide',saveWindow)
    fill(f,1,-1,WIDTH-2,72,C.card)
    fill(f,1,-73,WIDTH-2,1,C.line); fill(f,1,-74,157,HEIGHT-108,C.card)
    fill(f,158,-74,1,HEIGHT-108,C.line); fill(f,1,-HEIGHT+34,WIDTH-2,1,C.line)
    local icon=f:CreateTexture(nil,'ARTWORK'); size(icon,42,42); icon:SetPoint('TOPLEFT',f,'TOPLEFT',18,-15)
    icon:SetTexture('Interface\\Icons\\INV_Shield_05'); if icon.SetTexCoord then icon:SetTexCoord(0.07,0.93,0.07,0.93) end
    label(f,'FOREVER CLEAN CHAT',74,-18,WIDTH-180,'GameFontNormalLarge',C.gold)
    UI.subtitle=label(f,'',74,-46,WIDTH-180,'GameFontHighlightSmall',C.muted)
    UI.controls.close=button(f,'x',WIDTH-48,-17,30,function() UI.Hide() end)
    UI.panels={}; UI.controls.tabs={}
    local builders={overview=buildOverview,log=buildLog,lists=buildLists,settings=buildSettings,test=buildTest}
    for i,item in ipairs(tabs) do
        local key=item[1]
        local b=button(f,item[2],12,-99-(i-1)*67,133,function() UI.Show(key) end,35)
        UI.controls.tabs[key]=b
        label(f,item[3],23,-137-(i-1)*67,124,'GameFontHighlightSmall',C.muted,22)
        local p=CreateFrame('Frame',nil,f); p:SetPoint('TOPLEFT',f,'TOPLEFT',183,-94); size(p,CONTENT,486)
        builders[key](p); UI.panels[key]=p; p:Hide()
    end
    label(f,'OFFLINE RULE PACK',23,-471,124,'GameFontNormalSmall',C.gold,25)
    label(f,'Quiet by design.\nMade for Forever.',23,-501,124,'GameFontHighlightSmall',C.muted,40)
    UI.footer=label(f,UI.message or 'Preferences are saved automatically.',18,-HEIGHT+22,WIDTH-36,'GameFontHighlightSmall',C.muted,18)
    if type(UISpecialFrames)=='table' then
        local present=false; for _,name in ipairs(UISpecialFrames) do if name=='ForeverCleanChatPanel' then present=true end end
        if not present then UISpecialFrames[#UISpecialFrames+1]='ForeverCleanChatPanel' end
    end
end
local function refreshOverview(p)
    local db=NS.db
    p.status:SetText(db.enabled and 'Protection is active' or 'Protection is paused'); color(p.status,db.enabled and C.teal or C.gold)
    p.description:SetText(db.enabled and 'Hidden messages stay in your session log. The sender receives no notification.' or 'New messages are shown normally. Your rules and saved preferences are ready when you resume.')
    p.cards[1]:SetText(safe(NS.sessionBlocked or 0)); p.cards[2]:SetText(safe(db.totalBlocked or 0)); p.cards[3]:SetText(safe(#(NS.log or {})))
    UI.controls.overviewBalanced:SetActive(db.mode=='balanced'); UI.controls.overviewStrict:SetActive(db.mode=='strict')
    UI.controls.overviewToggle:SetLabel(db.enabled and 'Pause protection' or 'Resume protection')
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
    if not UI.frame or not UI.frame:IsShown() or not NS.db then return end
    UI.subtitle:SetText('v'..safe(NS.VERSION)..'  |  '..safe(NS.Data.dataset_version)..' offline rules')
    for key,p in pairs(UI.panels) do if key==UI.tab then p:Show() else p:Hide() end; UI.controls.tabs[key]:SetActive(key==UI.tab) end
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
            UI.controls={}; UI.lastError=tostring(err); NS.uiErrors=(NS.uiErrors or 0)+1
            UI.SetMessage('The control panel could not open. Try /reload, then /fcc.',true)
            if NS.Print then NS.Print('The control panel could not open. Try /reload, then /fcc. Diagnostics: /fcc status.') end
            return false,'ui_build_failed'
        end
    end
    if tab=='localtest' then tab='test' elseif tab=='history' then tab='log' elseif tab=='home' then tab='overview' end
    if tab and UI.panels[tab] then UI.tab=tab end
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
