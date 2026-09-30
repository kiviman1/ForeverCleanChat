-- Actual production callbacks run on stateful native WoW frame doubles.
-- This suite never sends chat and cannot confirm rendering in the target client.
local root=arg[1] or '.'
local H=assert(loadfile(root..'/tests/harness_ui.lua'))()
local report={suite='ui',runtime=_VERSION,total=0,passed=0,failed=0,failures={},checks={},
    native_rendering='not_run',target_client='not_run'}
local label='setup'
local function eq(actual,expected,description)
    report.total=report.total+1
    if actual~=expected then
        report.failed=report.failed+1
        local text=(description or 'assertion')..': '..tostring(actual)..' expected '..tostring(expected)
        report.failures[#report.failures+1]={id=label,description=description,actual=tostring(actual),expected=tostring(expected)}
        error(text,2)
    end
    report.passed=report.passed+1
end
local function truth(actual,description) eq(actual==true,true,description) end
local function contains(text,value) return string.find(text or '',value,1,true)~=nil end
local function fresh(saved,options)
    local e,ns=H.uiGame('modern',saved,options)
    e:boot()
    return e,ns
end
local function open(e,ns,tab)
    ns.UI.Show(tab or 'overview')
    truth(ns.UI.frame and ns.UI.frame:IsShown(),'control panel visible')
    return ns.UI.controls
end
local function chooseKind(e,c,kind)
    e:click(c.listsKinds[kind]);e:input(c.listSearch,'')
end
local function selectEntry(e,c,key)
    e:input(c.listSearch,key)
    eq(c.listRows[1].entry.key,key,'search finds exact list entry')
    e:click(c.listRows[1])
end
local function captionButton(parent,text)
    for _,child in ipairs(parent.children or {}) do
        if child.kind=='Button' and child.caption and child.caption:GetText()==text then return child end
    end
    error('missing button caption '..text)
end
local function group(name,callback)
    label=name
    local beforeFailed,beforeTotal=report.failed,report.total
    local ok,err=pcall(callback)
    if not ok and report.failed==beforeFailed then
        report.total=report.total+1;report.failed=report.failed+1
        report.failures[#report.failures+1]={id=name,description=tostring(err)}
    end
    report.checks[#report.checks+1]={id=name,status=ok and 'passed_mock' or 'failed',
        assertions=report.total-beforeTotal,error=not ok and tostring(err) or nil}
    if not ok then print('FAIL UI '..name..': '..tostring(err)) end
end

group('startup_and_panel_navigation',function()
    local e,ns=fresh()
    eq(ns.installed,true,'filter installed before UI interaction')
    eq(e.addCalls,5,'one registration per supported chat event')
    eq(ns.UI.frame,nil,'panel built lazily')
    truth(ns.Minimap.button and ns.Minimap.button:IsShown(),'minimap visible by default')
    for _,frame in ipairs(e.frames) do eq(frame.scripts.OnUpdate,nil,'startup has no OnUpdate polling') end
    e:cmd('')
    truth(ns.UI.frame:IsShown(),'empty /fcc opens panel')
    eq(ns.UI.tab,'overview','default overview tab')
    eq(ns.db.ui.language,'en','English preference')
    local c=ns.UI.controls
    for _,tab in ipairs({'log','lists','settings','test','overview'}) do
        e:click(c.tabs[tab]);eq(ns.UI.tab,tab,'tab click selects '..tab)
    end
    e:click(c.close);eq(ns.UI.frame:IsShown(),false,'close button hides panel')
    e:cmd('');truth(ns.UI.frame:IsShown(),'slash reopens panel')
    e:escape();eq(ns.UI.frame:IsShown(),false,'Escape through UISpecialFrames hides panel')
    e:cmd('settings');eq(ns.UI.tab,'settings','settings slash opens settings')
    truth(ns.UI.frame:IsShown(),'settings slash shows panel')
    ns.UI.Hide();eq(ns.UI.frame:IsShown(),false,'public Hide')
end)

group('minimap_click_tooltip_and_visibility',function()
    local e,ns=fresh()
    local b=ns.Minimap.button
    e:click(b,'LeftButton');truth(ns.UI.frame:IsShown(),'left click opens panel')
    e:click(b,'LeftButton');eq(ns.UI.frame:IsShown(),false,'second left click toggles panel')
    e:click(b,'RightButton');eq(ns.UI.tab,'settings','right click opens settings')
    e:fire(b,'OnEnter');truth(e.GameTooltip:IsShown(),'hover tooltip shown')
    local lines={}
    for _,line in ipairs(e.GameTooltip.lines) do lines[#lines+1]=line[1] end
    local tooltip=table.concat(lines,'\n')
    truth(contains(tooltip,'Forever Clean Chat'),'tooltip title')
    truth(contains(tooltip,'Hidden this session:'),'tooltip counters')
    truth(contains(tooltip,'Right-click: open settings'),'tooltip right click instruction')
    e:fire(b,'OnLeave');eq(e.GameTooltip:IsShown(),false,'leave hides tooltip')
    local c=ns.UI.controls
    e:click(c.minimap);eq(ns.db.ui.minimap.hide,true,'setting stores hidden minimap')
    eq(b:IsShown(),false,'setting hides button immediately')
    e:click(c.minimap);eq(ns.db.ui.minimap.hide,false,'setting restores minimap')
    truth(b:IsShown(),'button restored immediately')
    e:cmd('minimap hide');eq(b:IsShown(),false,'slash hides minimap')
    e:cmd('minimap show');truth(b:IsShown(),'slash restores minimap')
    eq(b.scripts.OnUpdate,nil,'minimap has no idle polling')
end)

group('overview_controls_and_shortcuts',function()
    local e,ns=fresh()
    local c=open(e,ns,'overview')
    e:click(c.overviewBalanced);eq(ns.db.mode,'balanced','overview selects balanced')
    e:click(c.overviewStrict);eq(ns.db.mode,'strict','overview selects strict')
    e:click(c.overviewToggle);eq(ns.db.enabled,false,'overview pauses protection')
    e:click(c.overviewToggle);eq(ns.db.enabled,true,'overview resumes protection')
    e:click(captionButton(ns.UI.panels.overview,'Review hidden messages'))
    eq(ns.UI.tab,'log','overview log shortcut')
    e:click(c.tabs.overview)
    e:click(captionButton(ns.UI.panels.overview,'Try a local sample'))
    eq(ns.UI.tab,'test','overview local test shortcut')
    c.testInput:SetFocus();e:input(c.testInput,'LFM healer')
    e:fire(c.testInput,'OnEscapePressed')
    eq(ns.UI.frame:IsShown(),false,'focused edit Escape closes panel')
    eq(c.testInput:HasFocus(),false,'Escape clears focus')
end)

group('settings_immediately_change_filtering',function()
    local e,ns=fresh()
    local c=open(e,ns,'settings')
    truth(e:chat('mythicstore.com',nil,1001),'enabled hides known host')
    e:click(c.enabled);eq(ns.db.enabled,false,'enabled toggle off')
    eq(e:chat('mythicstore.com',nil,1002),false,'disabled allows same cached message')
    e:click(c.enabled);truth(ns.db.enabled,'enabled toggle on')
    e:click(c.balanced);eq(ns.db.mode,'balanced','balanced selected')
    eq(e:chat('WTS RFC boosts 5g/run',nil,1003),false,'balanced allows in-game paid boost')
    e:click(c.strict);eq(ns.db.mode,'strict','strict selected')
    truth(e:chat('WTS RFC boosts 5g/run',nil,1004),'strict blocks same text after invalidation')
    e:click(c.contextual);eq(ns.db.known_domain_mention_policy,'contextual','contextual selected')
    eq(e:chat('Avoid mythicstore.com advertisements',nil,1005),false,'contextual allows warning about known host')
    e:click(c.hideAll);eq(ns.db.known_domain_mention_policy,'hide_all','hide all selected')
    truth(e:chat('Avoid mythicstore.com advertisements',nil,1006),'hide all changes cached decision')
    for index,event in ipairs(ns.Events) do
        e:click(c.events[event]);eq(ns.db.chatEvents[event],false,'scope off '..event)
        eq(e:chat('mythicstore.com',nil,1100+index,nil,event),false,'disabled scope allows '..event)
        e:click(c.events[event]);eq(ns.db.chatEvents[event],true,'scope restored '..event)
        truth(e:chat('mythicstore.com',nil,1200+index,nil,event),'enabled scope blocks '..event)
    end
    eq(e.addCalls,5,'settings changes never duplicate filter installation')
    for _,frame in ipairs(e.frames) do eq(frame.scripts.OnUpdate,nil,'settings do not install polling') end
end)

group('lists_validate_edit_and_preserve_builtin_pack',function()
    local e,ns=fresh()
    local c=open(e,ns,'lists')
    local defaultCount=#ns.Data.domains
    e:click(c.listsKinds.domain)
    e:input(c.listInput,'not a domain');e:click(c.listAdd)
    eq(H.count(ns.db.domains),0,'invalid domain never stored')
    e:input(c.listInput,'https://www.Example.COM/path');e:click(c.listAdd)
    truth(ns.db.domains['example.com']~=nil,'domain input canonicalized')
    truth(e:chat('example.com',nil,2001),'custom domain changes filter')
    for _,domain in ipairs({'a-b.com','ab.com','a.b.com'}) do
        e:input(c.listInput,domain);e:click(c.listAdd)
        truth(ns.db.domains[domain]~=nil,'distinct structural domain '..domain)
    end
    selectEntry(e,c,'a-b.com');e:click(c.listRemove);e:input(c.listSearch,'')
    eq(ns.db.domains['a-b.com'],nil,'remove only requested domain')
    truth(ns.db.domains['ab.com']~=nil,'other domain retained')
    selectEntry(e,c,'mythicstore.com');e:click(c.listRemove);e:input(c.listSearch,'')
    eq(ns.db.domainDisabled['mythicstore.com'],true,'builtin removal is an exclusion')
    eq(#ns.Data.domains,defaultCount,'offline builtin pack unchanged')
    eq(e:chat('mythicstore.com',nil,2002),false,'excluded builtin host allowed')
    chooseKind(e,c,'phrase')
    e:input(c.listInput,'ab');e:click(c.listAdd);eq(H.count(ns.db.phrases),0,'short phrase rejected')
    e:input(c.listInput,'Custom Special Offer');e:click(c.listAdd)
    truth(ns.db.phrases['custom special offer'],'phrase normalized')
    truth(e:chat('Our custom special offer',nil,2003),'custom phrase hides')
    selectEntry(e,c,'custom special offer');e:click(c.listRemove)
    eq(e:chat('Our custom special offer',nil,2004),false,'phrase removal invalidates decision')
    chooseKind(e,c,'block');e:input(c.listInput,'Helpful Seller-Realm');e:click(c.listAdd)
    truth(ns.db.block['helpful seller-realm'],'manual block added')
    truth(e:chat('LFM healer','Helpful Seller-Realm',2005),'manually blocked player hidden')
    chooseKind(e,c,'allow');e:input(c.listInput,'Helpful Seller-Realm');e:click(c.listAdd)
    truth(ns.db.allow['helpful seller-realm'],'manual allow added')
    eq(ns.db.block['helpful seller-realm'],nil,'allow action resolves block conflict')
    eq(e:chat('example.com','Helpful Seller-Realm',2006),false,'allow player takes precedence')
    e:input(c.listInput,'Bad|Hname');e:click(c.listAdd)
    eq(H.count(ns.db.allow),1,'unsafe name rejected')
    chooseKind(e,c,'domainAllow');e:input(c.listInput,'example.com');e:click(c.listAdd)
    truth(ns.db.domainAllow['example.com'],'domain exception stored')
    eq(e:chat('example.com','Other Seller-Realm',2007),false,'domain exception immediate')
    selectEntry(e,c,'example.com');e:click(c.listRemove)
    truth(e:chat('example.com','Other Seller-Realm',2008),'exception removal immediate')
end)

group('lists_search_paging_and_row_selection',function()
    local e,ns=fresh()
    for index=1,20 do ns.Settings.EditList('domain','add','test'..string.format('%02d',index)..'.example') end
    local c=open(e,ns,'lists')
    e:click(c.listsKinds.domain)
    local first=c.listRows[1].caption:GetText()
    e:click(c.listNext)
    truth(c.listRows[1].caption:GetText()~=first,'next page changes first list row')
    e:click(c.listPrev);eq(c.listRows[1].caption:GetText(),first,'previous page restores rows')
    e:input(c.listSearch,'test17')
    truth(contains(c.listRows[1].caption:GetText(),'test17.example'),'search finds canonical domain')
    e:click(c.listRows[1])
    eq(ns.UI.listSelected.key,'test17.example','selection identifies chosen entry')
    e:click(c.listRemove);eq(ns.db.domains['test17.example'],nil,'remove selected row')
    e:input(c.listSearch,'')
    truth(c.listRows[1]:IsShown(),'cleared search restores rows')
end)

group('builtin_domain_toggle_works_with_full_personal_list',function()
    local e,ns=fresh()
    for index=1,100 do truth(ns.Settings.EditList('domain','add','custom'..index..'.example'),'custom entry '..index) end
    eq(H.count(ns.db.domains),100,'personal domain list filled')
    local c=open(e,ns,'lists')
    chooseKind(e,c,'domain');selectEntry(e,c,'mythicstore.com');e:click(c.listRemove)
    truth(ns.db.domainDisabled['mythicstore.com'],'builtin disabled at personal list cap')
    selectEntry(e,c,'mythicstore.com');e:click(c.listRemove)
    eq(ns.db.domainDisabled['mythicstore.com'],nil,'builtin reenabled at personal list cap')
    eq(H.count(ns.db.domains),100,'builtin toggle never consumes personal entry')
    truth(e:chat('mythicstore.com',nil,2901),'reenabled builtin filters immediately')
end)

group('hidden_log_bounded_paging_selection_and_actions',function()
    local e,ns=fresh()
    for index=1,60 do truth(e:chat('mythicstore.com','Seller '..index..'-Realm',3000+index),'sample hidden '..index) end
    eq(#ns.log,50,'log bounded to last 50')
    eq(ns.log[1].author,'Seller 11-Realm','oldest discarded')
    local c=open(e,ns,'log')
    local first=c.logRows[1].caption:GetText()
    truth(contains(first,'Seller 60'),'newest row first')
    e:click(c.logNext);truth(c.logRows[1].caption:GetText()~=first,'log next page')
    e:click(c.logPrev);eq(c.logRows[1].caption:GetText(),first,'log previous page')
    e:input(c.logSearch,'Seller 57-')
    eq(c.logRows[1].entry.author,'Seller 57-Realm','log search locates author')
    e:input(c.logSearch,'R001_KNOWN_HOST')
    truth(c.logRows[1]:IsShown(),'log search locates rule')
    e:input(c.logSearch,'nothing will match this')
    eq(c.logRows[1]:IsShown(),false,'no matching log row')
    e:input(c.logSearch,'')
    e:click(c.logRows[1]);e:click(c.logAllow)
    truth(ns.db.allow['seller 60-realm'],'selected author allowed')
    eq(e:chat('mythicstore.com','Seller 60-Realm',4001),false,'log allow immediately affects future chat')
    e:click(c.logBlock);truth(ns.db.block['seller 60-realm'],'selected author can be blocked')
    eq(ns.db.allow['seller 60-realm'],nil,'block action resolves allow conflict')
    truth(e:chat('Normal message','Seller 60-Realm',4002),'log block hides ordinary message')
    e:click(c.logRows[2]);e:click(c.logDomainAllow)
    truth(ns.db.domainAllow['mythicstore.com'],'selected domain exception')
    eq(e:chat('mythicstore.com','Unlisted Seller-Realm',4003),false,'domain exception affects other senders')
    local session,total=ns.sessionBlocked,ns.db.totalBlocked
    e:click(c.logClear);eq(#ns.log,0,'clear hides session records')
    eq(ns.sessionBlocked,session,'clear preserves session count')
    eq(ns.db.totalBlocked,total,'clear preserves total count')
end)

group('maximum_lifetime_counter_remains_valid_after_reload',function()
    local e,ns=fresh({schema=2,enabled=true,mode='strict',totalBlocked=1000000000000})
    truth(e:chat('mythicstore.com',nil,5001),'max-counter message hidden')
    eq(ns.db.totalBlocked,1000000000000,'lifetime counter saturates at valid maximum')
    eq(ns.sessionBlocked,1,'session counter still increments')
    local other,reloaded=fresh(H.copy(ns.db))
    eq(reloaded.db.totalBlocked,1000000000000,'reload preserves saturated lifetime count')
end)

group('long_message_detail_native_scroll_handlers',function()
    local e,ns=fresh()
    truth(e:chat('mythicstore.com '..string.rep('long sample ',100),nil,5201),'long host advertisement hidden')
    open(e,ns,'log')
    local detail=ns.UI.panels.log.detail
    truth(detail.scroll:GetVerticalScrollRange()>0,'long message has scroll range')
    e:click(captionButton(detail,'v'))
    truth(detail.scroll:GetVerticalScroll()>0,'down arrow scrolls detail')
    e:click(captionButton(detail,'^'))
    eq(detail.scroll:GetVerticalScroll(),0,'up arrow returns to top')
    e:fire(detail.scroll,'OnMouseWheel',-1)
    truth(detail.scroll:GetVerticalScroll()>0,'mouse wheel scrolls detail')
    e:fire(detail.scroll,'OnMouseWheel',-1000)
    eq(detail.scroll:GetVerticalScroll(),detail.scroll:GetVerticalScrollRange(),'scroll clamps to native range')
    e:fire(detail.scroll,'OnMouseWheel',1000)
    eq(detail.scroll:GetVerticalScroll(),0,'scroll clamps at top')
end)

group('local_test_tab_and_slash_never_send_or_count',function()
    local e,ns=fresh()
    local c=open(e,ns,'test')
    local session,total,callbacks=ns.sessionBlocked,ns.db.totalBlocked,ns.callbackCount
    e:input(c.testInput,'mythicstore.com');e:click(c.testRun)
    truth(ns.UI.lastTest.block,'known-host local sample HIDE')
    eq(ns.UI.lastTest.explanation.rule_id,'R001_KNOWN_HOST','local result shows structured rule')
    e:input(c.testInput,'WTS Copper Bar 2g per stack');e:click(c.testRun)
    eq(ns.UI.lastTest.block,false,'normal item local sample ALLOW')
    for index,button in ipairs(c.testSamples) do
        e:click(button)
        truth(#c.testInput:GetText()>0,'sample '..index..' populates local input')
        e:click(c.testRun)
        eq(type(ns.UI.lastTest.block),'boolean','sample '..index..' evaluates')
    end
    e:click(c.selfTest)
    e:cmd('test');e:cmd('why mythicstore.com')
    eq(ns.sessionBlocked,session,'local tests do not increase session counter')
    eq(ns.db.totalBlocked,total,'local tests do not increase saved counter')
    eq(ns.callbackCount,callbacks,'local tests never invoke incoming chat adapter')
    eq(#ns.log,0,'local tests do not populate hidden log')
    eq(e.SendChatMessage,nil,'harness never exposes outbound chat API')
end)

group('window_and_preferences_survive_reload',function()
    local saved={schema=2,enabled=false,mode='balanced',totalBlocked=23,
        domains={['private.example']='private.example'},phrases={['custom phrase']=true},
        allow={['trusted player-realm']=true},block={['bad player-realm']=true},
        domainDisabled={['mythicstore.com']=true},domainAllow={['wowgold.com']=true},
        known_domain_mention_policy='contextual',chatEvents={CHAT_MSG_WHISPER=false},
        ui={language='en',window={point='TOPLEFT',relativePoint='TOPLEFT',x=100,y=-120},minimap={hide=true,angle=77}}}
    local e,ns=fresh(H.copy(saved))
    eq(ns.db.enabled,false,'old enabled preserved');eq(ns.db.mode,'balanced','old mode preserved')
    eq(ns.db.totalBlocked,23,'old total preserved')
    truth(ns.db.domains['private.example']~=nil,'custom domain preserved')
    truth(ns.db.phrases['custom phrase'],'custom phrase preserved')
    truth(ns.db.allow['trusted player-realm'],'allow preserved');truth(ns.db.block['bad player-realm'],'block preserved')
    truth(ns.db.domainDisabled['mythicstore.com'],'builtin exclusion preserved')
    truth(ns.db.domainAllow['wowgold.com'],'domain exception preserved')
    eq(ns.db.chatEvents.CHAT_MSG_WHISPER,false,'scope preference preserved')
    eq(ns.Minimap.button:IsShown(),false,'hidden preference used at startup')
    local c=open(e,ns,'settings')
    local point,relative,relativePoint,x,y=ns.UI.frame:GetPoint()
    eq(point,'TOPLEFT','restored window point');eq(relativePoint,'TOPLEFT','restored relative point')
    eq(x,100,'restored x');eq(y,-120,'restored y')
    local dragHandle
    for _,child in ipairs(ns.UI.frame.children) do if child.scripts.OnDragStart then dragHandle=child;break end end
    truth(dragHandle~=nil,'window title bar has native drag handler')
    e:fire(dragHandle,'OnDragStart','LeftButton')
    ns.UI.frame:ClearAllPoints();ns.UI.frame:SetPoint('BOTTOMRIGHT',e.UIParent,'BOTTOMRIGHT',-85,90)
    e:fire(dragHandle,'OnDragStop')
    eq(ns.db.ui.window.x,-85,'window drag saves x');eq(ns.db.ui.window.y,90,'window drag saves y')
    local other,loaded=fresh(H.copy(ns.db));open(other,loaded,'settings')
    local nextPoint,_,nextRelative,nextX,nextY=loaded.UI.frame:GetPoint()
    eq(nextPoint,'BOTTOMRIGHT','reload window point');eq(nextRelative,'BOTTOMRIGHT','reload relative point')
    eq(nextX,-85,'reload x');eq(nextY,90,'reload y')
    other:click(loaded.UI.controls.resetWindow)
    eq(loaded.db.ui.window.point,'CENTER','reset saves center');eq(loaded.db.ui.window.x,0,'reset saves x')
    eq(loaded.db.mode,'balanced','window reset preserves mode')
    truth(loaded.db.allow['trusted player-realm'],'window reset preserves allow list')
end)

group('minimap_native_drag_angles_and_scaled_geometry',function()
    local e,ns=fresh()
    local b=ns.Minimap.button
    for _,sample in ipairs({{600,500,0},{500,600,90},{400,500,180},{500,400,270},{400,400,225}}) do
        e:fire(b,'OnMouseDown','LeftButton');e:fire(b,'OnDragStart')
        eq(b.moving,true,'native movement starts')
        local before=ns.db.ui.minimap.angle
        e.cursorX,e.cursorY=sample[1],sample[2]
        eq(ns.db.ui.minimap.angle,before,'angle is not polled while dragging')
        e:fire(b,'OnDragStop');eq(b.moving,false,'native movement ends')
        truth(math.abs(ns.db.ui.minimap.angle-sample[3])<0.0001,'saved quadrant angle '..sample[3])
        e:click(b,'LeftButton');eq(ns.UI.frame,nil,'drag-release click suppressed')
    end
    e.Minimap:SetScale(2);e.cursorX,e.cursorY=1200,1000
    e:fire(b,'OnMouseDown','LeftButton');e:fire(b,'OnDragStart');e:fire(b,'OnDragStop')
    truth(math.abs(ns.db.ui.minimap.angle)<0.0001,'scaled cursor converted to minimap coordinates')
    e.cursorX,e.cursorY=1000,1000
    local angle=ns.db.ui.minimap.angle
    e:fire(b,'OnMouseDown','LeftButton');e:fire(b,'OnDragStart');e:fire(b,'OnDragStop')
    eq(ns.db.ui.minimap.angle,angle,'center drop leaves angle unchanged')
    ns.Settings.SaveMinimapAngle(45);e.minimapShape='SQUARE';e:emit('DISPLAY_SIZE_CHANGED')
    local point,parent,relativePoint,x,y=b:GetPoint()
    eq(parent,e.Minimap,'reanchored to minimap parent')
    truth(math.abs(x-80)<0.0001 and math.abs(y-80)<0.0001,'square rim respects corners')
    e.GetMinimapShape=nil
    e.Minimap.GetMaskTexture=function() return 'Interface\\Buttons\\WHITE8X8' end
    e:emit('DISPLAY_SIZE_CHANGED')
    local _,_,_,fallbackX,fallbackY=b:GetPoint()
    truth(math.abs(fallbackX-80)<0.0001 and math.abs(fallbackY-80)<0.0001,'mask texture fallback identifies square minimap')
    e.GetCursorPosition=nil
    local beforeMissingCursor=ns.db.ui.minimap.angle
    e:fire(b,'OnMouseDown','LeftButton');e:fire(b,'OnDragStart');e:fire(b,'OnDragStop')
    eq(ns.db.ui.minimap.angle,beforeMissingCursor,'missing cursor API preserves saved angle')
    ns.Settings.SetMinimapShown(false)
    eq(b:IsShown(),false,'hide during idle safe')
    ns.Settings.SetMinimapShown(true)
    local other,loaded=fresh(H.copy(ns.db))
    truth(math.abs(loaded.db.ui.minimap.angle-45)<0.0001,'angle survives reload')
    truth(loaded.Minimap.button:IsShown(),'minimap visibility survives reload')
    eq(b.scripts.OnUpdate,nil,'drag never installs OnUpdate')
end)

group('settings_validation_caps_and_malformed_saved_ui',function()
    local e,ns=fresh({schema=2,mode='balanced',enabled=true,ui={language='en',window={point='INVALID',x=0/0,y=math.huge},minimap={hide='yes',angle=math.huge}},chatEvents={CHAT_MSG_SAY='no'}})
    eq(ns.db.mode,'balanced','malformed UI never alters valid filtering mode')
    eq(ns.db.ui.window.point,'CENTER','bad window point repaired')
    eq(ns.db.ui.window.x,0,'nonfinite window x repaired')
    eq(ns.db.ui.window.y,0,'nonfinite window y repaired')
    eq(ns.db.ui.minimap.hide,false,'bad minimap hide repaired')
    eq(ns.db.ui.minimap.angle,225,'bad minimap angle repaired')
    eq(ns.db.chatEvents.CHAT_MSG_SAY,true,'bad scope boolean repaired')
    eq(ns.Settings.SetMode('unknown'),false,'invalid mode rejected')
    eq(ns.Settings.SetEnabled('false'),false,'invalid toggle rejected')
    eq(ns.Settings.SetDomainPolicy('unknown'),false,'invalid policy rejected')
    eq(ns.Settings.SetChatEvent('CHAT_MSG_GUILD',false),false,'unregistered scope rejected')
    eq(ns.Settings.SaveMinimapAngle(0/0),false,'NaN angle rejected')
    eq(ns.Settings.EditList('allow','add','Bad\nName'),false,'control character name rejected')
    for index=1,100 do truth(ns.Settings.EditList('phrase','add','Entry '..index),'phrase below cap') end
    eq(ns.Settings.EditList('phrase','add','Entry 101'),false,'101st unique phrase rejected')
    eq(H.count(ns.db.phrases),100,'cap respected')
    truth(ns.Settings.EditList('phrase','add','Entry 1'),'existing entry permitted at cap')
    eq(ns.db.mode,'balanced','invalid operations preserve mode')
end)

group('missing_optional_apis_and_ui_errors_do_not_disable_filter',function()
    local e,ns=fresh(nil,{noMinimap=true,noTooltip=true,noBackdropMixin=true})
    eq(ns.Minimap.button,nil,'missing minimap safely skips button')
    eq(ns.installed,true,'chat filter still registered')
    truth(e:chat('mythicstore.com',nil,8001),'missing minimap preserves filtering')
    e:cmd('');truth(ns.UI.frame:IsShown(),'panel still opens without minimap/tooltip')
    eq(e:chat('WTS Copper Bar 2g per stack',nil,8002),false,'normal chat still allowed')
    local bad,failedUI=fresh(nil,{createFrameError=true})
    eq(failedUI.installed,true,'UI creation error leaves filter installed')
    local ok=pcall(bad.cmd,bad,'')
    eq(ok,true,'panel creation failure guarded from slash command')
    truth(bad:chat('mythicstore.com',nil,8003),'panel failure cannot break hide decision')
    eq(bad:chat('LFM healer',nil,8004),false,'panel failure cannot swallow ordinary chat')
    local normal,safe=fresh()
    open(normal,safe,'overview')
    safe.AddChangeListener(function() error('simulated UI listener failure') end)
    truth(normal:chat('mythicstore.com',nil,8005),'listener error cannot change valid filter outcome')
    eq(normal:chat('LFM healer',nil,8006),false,'listener error preserves ordinary chat')
    eq(safe.sessionErrors,0,'UI listener failures are not chat classification failures')
end)

group('native_regions_have_nonnegative_geometry',function()
    local e,ns=fresh()
    open(e,ns,'overview')
    local visited=0
    local function validate(item)
        assert(item:GetWidth()>=0,'negative native region width: '..tostring(item.text or item.kind))
        assert(item:GetHeight()>=0,'negative native region height: '..tostring(item.text or item.kind))
        visited=visited+1
        for _,child in ipairs(item.children or {}) do validate(child) end
    end
    validate(ns.UI.frame)
    truth(visited>100,'all panel native children inspected')
    eq(ns.UI.frame:GetWidth(),860,'root window width')
    eq(ns.UI.frame:GetHeight(),590,'root window height')
    e.UIParent:SetSize(800,600);ns.UI.Show('settings')
    truth(ns.UI.frame:GetScale()<1,'small viewport scales native panel')
    truth(ns.UI.frame:GetWidth()*ns.UI.frame:GetScale()<=776,'scaled panel fits horizontal margin')
    truth(ns.UI.frame:GetHeight()*ns.UI.frame:GetScale()<=576,'scaled panel fits vertical margin')
end)

FCC_UI_RESULT=report
print('UI interactions: '..report.passed..'/'..report.total..' passed on '.._VERSION..'; native rendering and live Forever: NOT RUN')
if report.failed>0 then error('UI interaction failures: '..report.failed) end
