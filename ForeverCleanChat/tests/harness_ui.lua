-- Stateful native WoW UI doubles. Production Lua executes; this cannot render WoW.
local root = arg[1] or '.'
local H = assert(loadfile(root..'/tests/harness.lua'))()
local unpackValues = unpack or table.unpack

function H.uiGame(api, saved, options)
    options = options or {}
    local env, ns = {}, {}
    setmetatable(env, {__index=_G})
    env._G = env
    env.ForeverCleanChatDB = saved
    env.SlashCmdList, env.frames, env.named, env.messages, env.filters = {}, {}, {}, {}, {}
    env.addCalls, env.now, env.secret = 0, 10, {}
    env.cursorX, env.cursorY, env.sounds = 500, 500, {}
    env.UISpecialFrames = {}
    env.DEFAULT_CHAT_FRAME = {AddMessage=function(_, message) env.messages[#env.messages+1]=message end}
    env.GetTime = function() return env.now end
    env.UnitGUID = function() return 'Player-Self' end
    env.UnitFullName = function() return 'Test Player', 'Test Realm' end
    env.canaccessvalue = function(value) return value~=env.secret end
    env.GetCursorPosition = function() return env.cursorX, env.cursorY end
    env.GetMinimapShape = function() return env.minimapShape or 'ROUND' end
    env.PlaySound = function(sound) env.sounds[#env.sounds+1]=sound end
    env.SOUNDKIT = {IG_MAINMENU_OPEN=1,IG_MAINMENU_CLOSE=2,IG_MAINMENU_OPTION_CHECKBOX_ON=3}
    env.WOW_PROJECT_ID, env.WOW_PROJECT_MAINLINE = 1, 1

    local methods = {}
    function methods:GetName() return self.name end
    function methods:GetParent() return self.parent end
    function methods:SetParent(parent) self.parent=parent end
    function methods:SetSize(width,height) self.width,self.height=width,height end
    function methods:SetWidth(width) self.width=width end
    function methods:SetHeight(height) self.height=height end
    function methods:GetWidth() return self.width or 0 end
    function methods:GetHeight() return self.height or 0 end
    function methods:SetPoint(...) self.points[#self.points+1]={...} end
    function methods:GetPoint(index)
        local point = self.points[index or 1]
        if point then return unpackValues(point) end
    end
    function methods:GetNumPoints() return #self.points end
    function methods:ClearAllPoints() self.points={} end
    function methods:SetAllPoints(target) self.allPoints=target or self.parent end
    function methods:GetCenter()
        if self.center then return self.center[1],self.center[2] end
        if self.parent then return self.parent:GetCenter() end
        return 500,500
    end
    function methods:GetEffectiveScale() return self.scale or (self.parent and self.parent:GetEffectiveScale()) or 1 end
    function methods:GetScale() return self.scale or 1 end
    function methods:SetScale(value) self.scale=value end
    function methods:SetFrameStrata(value) self.strata=value end
    function methods:SetFrameLevel(value) self.level=value end
    function methods:GetFrameLevel() return self.level or 0 end
    function methods:SetClampedToScreen(value) self.clamped=value end
    function methods:SetMovable(value) self.movable=value end
    function methods:SetResizable(value) self.resizable=value end
    function methods:SetToplevel(value) self.toplevel=value end
    function methods:EnableMouse(value) self.mouseEnabled=value end
    function methods:EnableMouseWheel(value) self.mouseWheelEnabled=value end
    function methods:SetHitRectInsets(...) self.hitInsets={...} end
    function methods:StartMoving() self.moving=true end
    function methods:StopMovingOrSizing() self.moving=false end
    function methods:StartSizing() self.sizing=true end
    function methods:SetUserPlaced(value) self.userPlaced=value end
    function methods:SetClipsChildren(value) self.clipsChildren=value end
    function methods:SetScript(event,callback) self.scripts[event]=callback end
    function methods:GetScript(event) return self.scripts[event] end
    function methods:HookScript(event,callback)
        local previous=self.scripts[event]
        self.scripts[event]=function(...)
            if previous then previous(...) end
            return callback(...)
        end
    end
    function methods:RegisterEvent(event) self.events[event]=true end
    function methods:UnregisterEvent(event) self.events[event]=nil end
    function methods:RegisterForClicks(...) self.clickButtons={...} end
    function methods:RegisterForDrag(...) self.dragButtons={...} end
    function methods:Show()
        if self.shown then return end
        self.shown=true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function methods:Hide()
        if not self.shown then return end
        self.shown=false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function methods:IsShown() return self.shown==true end
    function methods:IsVisible()
        return self.shown==true and (not self.parent or self.parent:IsVisible())
    end
    function methods:SetShown(value) if value then self:Show() else self:Hide() end end
    function methods:SetAlpha(value) self.alpha=value end
    function methods:GetAlpha() return self.alpha or 1 end
    function methods:Enable() self.enabled=true end
    function methods:Disable() self.enabled=false end
    function methods:IsEnabled() return self.enabled~=false end
    function methods:SetEnabled(value) self.enabled=value~=false end
    function methods:SetChecked(value) self.checked=value==true or value==1 end
    function methods:GetChecked() return self.checked==true end
    function methods:SetText(text)
        self.text=tostring(text or '')
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end
    end
    function methods:GetText() return self.text or '' end
    function methods:SetFormattedText(format,...) self:SetText(string.format(format,...)) end
    function methods:SetFont(...) self.font={...}; return true end
    function methods:SetFontObject(value) self.fontObject=value end
    function methods:SetTextColor(...) self.textColor={...} end
    function methods:SetJustifyH(value) self.justifyH=value end
    function methods:SetJustifyV(value) self.justifyV=value end
    function methods:SetWordWrap(value) self.wordWrap=value end
    function methods:SetNonSpaceWrap(value) self.nonSpaceWrap=value end
    function methods:SetMaxLines(value) self.maxLines=value end
    function methods:SetSpacing(value) self.spacing=value end
    function methods:GetStringWidth() return #self:GetText()*7 end
    function methods:GetStringHeight()
        local width=math.max(self.width or 400,7)
        return math.max(1,math.ceil(#self:GetText()*7/width))*14
    end
    function methods:SetShadowColor(...) self.shadowColor={...} end
    function methods:SetShadowOffset(...) self.shadowOffset={...} end
    function methods:SetTextInsets(...) self.textInsets={...} end
    function methods:SetAutoFocus(value) self.autoFocus=value end
    function methods:SetMultiLine(value) self.multiLine=value end
    function methods:SetMaxLetters(value) self.maxLetters=value end
    function methods:SetMaxBytes(value) self.maxBytes=value end
    function methods:SetNumeric(value) self.numeric=value end
    function methods:SetFocus() self.focus=true end
    function methods:ClearFocus() self.focus=false end
    function methods:HasFocus() return self.focus==true end
    function methods:HighlightText(...) self.highlightText={...} end
    function methods:SetTexture(value) self.texture=value end
    function methods:GetTexture() return self.texture end
    function methods:SetColorTexture(...) self.colorTexture={...} end
    function methods:SetVertexColor(...) self.vertexColor={...} end
    function methods:SetTexCoord(...) self.texCoord={...} end
    function methods:SetBlendMode(value) self.blendMode=value end
    function methods:SetDrawLayer(...) self.drawLayer={...} end
    function methods:SetRotation(value) self.rotation=value end
    function methods:SetNormalTexture(value) self.normalTexture=value end
    function methods:SetPushedTexture(value) self.pushedTexture=value end
    function methods:SetHighlightTexture(value) self.highlightTexture=value end
    function methods:SetDisabledTexture(value) self.disabledTexture=value end
    function methods:SetNormalFontObject(value) self.normalFontObject=value end
    function methods:SetHighlightFontObject(value) self.highlightFontObject=value end
    function methods:SetDisabledFontObject(value) self.disabledFontObject=value end
    function methods:SetBackdrop(value) self.backdrop=value end
    function methods:SetBackdropColor(...) self.backdropColor={...} end
    function methods:SetBackdropBorderColor(...) self.backdropBorderColor={...} end
    function methods:SetScrollChild(child) self.scrollChild=child end
    function methods:GetScrollChild() return self.scrollChild end
    function methods:SetVerticalScroll(value)
        self.verticalScroll=math.max(0,math.min(self:GetVerticalScrollRange(),value))
    end
    function methods:GetVerticalScroll() return self.verticalScroll or 0 end
    function methods:GetVerticalScrollRange()
        return math.max(0,(self.scrollChild and self.scrollChild:GetHeight() or 0)-self:GetHeight())
    end
    function methods:UpdateScrollChildRect() end
    function methods:SetMinMaxValues(low,high) self.min,self.max=low,high end
    function methods:SetValue(value)
        self.value=value
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,value) end
    end
    function methods:GetValue() return self.value or 0 end
    function methods:SetValueStep(value) self.valueStep=value end
    function methods:SetObeyStepOnDrag(value) self.obeyStep=value end
    function methods:SetOrientation(value) self.orientation=value end
    function methods:SetThumbTexture(value) self.thumbTexture=value end

    local function object(kind,name,parent,template)
        local item={kind=kind,name=name,parent=parent,template=template,shown=true,
            enabled=true,events={},scripts={},points={},children={},regions={}}
        setmetatable(item,{__index=methods})
        if parent then parent.children[#parent.children+1]=item end
        if name then env[name],env.named[name]=item,item end
        return item
    end
    function methods:CreateTexture(name,layer,template)
        local item=object('Texture',name,self,template)
        item.layer=layer; self.regions[#self.regions+1]=item; return item
    end
    function methods:CreateFontString(name,layer,template)
        local item=object('FontString',name,self,template)
        item.layer=layer; self.regions[#self.regions+1]=item; return item
    end
    function methods:GetChildren() return unpackValues(self.children) end
    function methods:GetRegions() return unpackValues(self.regions) end
    env.UIParent=object('Frame','UIParent')
    env.UIParent:SetSize(1920,1080); env.UIParent.center={960,540}
    env.Minimap=object('Frame','Minimap',env.UIParent)
    env.Minimap:SetSize(140,140); env.Minimap.center={500,500}
    env.Minimap:SetFrameLevel(2)
    env.GameTooltip=object('Tooltip','GameTooltip',env.UIParent)
    env.GameTooltip.lines={}; env.GameTooltip:Hide()
    function env.GameTooltip:SetOwner(owner,anchor) self.owner,self.anchor=owner,anchor end
    function env.GameTooltip:ClearLines() self.lines={} end
    function env.GameTooltip:AddLine(text,...) self.lines[#self.lines+1]={text,...} end
    function env.GameTooltip:AddDoubleLine(left,right,...) self.lines[#self.lines+1]={left,right,...} end
    env.CreateFrame=function(kind,name,parent,template)
        if options.createFrameError and name then error('simulated unsupported UI frame') end
        local item=object(kind,name,parent,template)
        env.frames[#env.frames+1]=item
        return item
    end
    if options.noMinimap then env.Minimap=nil end
    if options.noTooltip then env.GameTooltip=nil end
    if options.noUIParent then env.UIParent=nil end
    if not options.noBackdropMixin then env.BackdropTemplateMixin={} end
    local function add(event,callback)
        if env.failEvent==event then error('simulated unsupported event') end
        env.addCalls=env.addCalls+1; env.filters[event]=callback
    end
    env.mockAdd=add
    if api=='modern' then env.ChatFrameUtil={AddMessageEventFilter=add}
    elseif api=='legacy' then env.ChatFrame_AddMessageEventFilter=add end
    for _,name in ipairs({'Data.generated.lua','Normalize.lua','Rules.lua','Core.lua','Settings.lua','Commands.lua','UI.lua','Minimap.lua'}) do
        H.chunk(root..'/'..name,env)('ForeverCleanChat',ns)
    end
    function env:emit(event,...)
        -- Events are delivered only to frames that were registered at dispatch start.
        local delivery={}
        for _,item in ipairs(self.frames) do
            if item.events[event] and item.scripts.OnEvent then delivery[#delivery+1]=item end
        end
        for _,item in ipairs(delivery) do item.scripts.OnEvent(item,event,...) end
    end
    function env:boot()
        self:emit('ADDON_LOADED','ForeverCleanChat'); self:emit('PLAYER_LOGIN')
    end
    function env:cmd(text) return self.SlashCmdList.FOREVERCLEANCHAT(text) end
    function env:chat(message,author,id,guid,event,frame)
        return ns.Filter(frame or {},event or 'CHAT_MSG_CHANNEL',message,author or 'Seller Name-Realm',
            'Common','2. Trade','','',0,2,'Trade',0,id,guid or 'Player-Seller')
    end
    function env:fire(item,event,...)
        assert(item,'missing control for '..event)
        local callback=item.scripts[event]
        assert(callback,'missing '..event..' handler on '..tostring(item.name or item.kind))
        return callback(item,...)
    end
    function env:click(item,button)
        assert(item,'missing clicked control')
        assert(item:IsVisible(),'attempt to click invisible control '..tostring(item.name or item.text))
        if not item:IsEnabled() then return false end
        if item.kind=='CheckButton' then item.checked=not item.checked end
        self:fire(item,'OnClick',button or 'LeftButton')
        return true
    end
    function env:input(item,text)
        assert(item:IsVisible(),'attempt to type in invisible edit box')
        item.text=tostring(text)
        if item.scripts.OnTextChanged then item.scripts.OnTextChanged(item,true) end
    end
    function env:escape()
        for _,name in ipairs(self.UISpecialFrames) do
            local item=self[name]
            if item and item:IsShown() then item:Hide() end
        end
    end
    function env:texts(item)
        local values={}
        local function visit(current)
            if current:IsVisible() and current.text then values[#values+1]=current.text end
            for _,child in ipairs(current.children or {}) do visit(child) end
        end
        visit(item or self.UIParent)
        return table.concat(values,'\n')
    end
    return env,ns
end

return H
