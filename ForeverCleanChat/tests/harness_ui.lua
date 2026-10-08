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
    env.addCalls, env.now, env.secret, env.updateCalls = 0, 10, {}, 0
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

    local fontDefaults={GameFontNormalLarge=18,GameFontHighlightLarge=18,GameFontNormal=14,
        GameFontHighlight=14,GameFontNormalSmall=12,GameFontHighlightSmall=12}
    for name,px in pairs(fontDefaults) do
        env[name]={font={'Fonts\\FRIZQT__.TTF',options.inheritedFontSize or px,''}}
        env[name].GetFont=function(self) return unpackValues(self.font) end
    end
    local function resolveFont(item)
        if item.font then return item.font end
        local inherited=item.fontObject or item.template
        if type(inherited)=='string' then inherited=env[inherited] end
        return type(inherited)=='table' and inherited.font or {'Fonts\\FRIZQT__.TTF',12,''}
    end
    local function glyphWidth(text,px)
        text=(text or ''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('||','|')
        local maximum,width=0,0
        for character in text:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
            if character=='\n' then maximum=math.max(maximum,width); width=0
            else
                local factor=.55
                if character:match('[ilI%.,:;!|]') then factor=.29
                elseif character:match('[%[%]%(%){}<>]') then factor=.36
                elseif character:match('[MW@%%]') then factor=.91
                elseif character==' ' then factor=.30
                elseif character:match('[A-Z]') then factor=.68 end
                width=width+px*factor
            end
        end
        return math.max(maximum,width)
    end
    local function naturalTextHeight(item)
        local px=resolveFont(item)[2]
        local insets=item.textInsets or {0,0,0,0}
        local width=math.max((item.width or 400)-insets[1]-insets[2],px*.55)
        local lines=0
        for line in (item:GetText()..'\n'):gmatch('(.-)\n') do
            lines=lines+math.max(1,item.wordWrap==false and 1 or math.ceil(glyphWidth(line,px)/width))
        end
        return px+(math.max(1,lines)-1)*px*1.15+insets[3]+insets[4],lines
    end
    local function resizeNativeEditor(item)
        if item.kind~='EditBox' or not item.multiLine then return end
        local height=naturalTextHeight(item)
        if item.height~=height then
            item.height=height
            if item.scripts.OnSizeChanged then item.scripts.OnSizeChanged(item,item.width or 0,height) end
        end
    end

    local methods = {}
    function methods:GetName() return self.name end
    function methods:GetParent() return self.parent end
    function methods:SetParent(parent) self.parent=parent end
    function methods:SetSize(width,height)
        local changed=self.width~=width or self.height~=height
        self.width,self.height=width,height
        if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,width,height) end
    end
    function methods:SetWidth(width) self.width=width end
    function methods:SetHeight(height)
        local changed=self.height~=height;self.height=height
        if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,self.width or 0,height) end
    end
    function methods:GetWidth() return self.width or 0 end
    function methods:GetHeight() return self.height or 0 end
    function methods:SetPoint(...)
        local point={...}
        -- WoW replaces an existing anchor with the same point name.
        for index,previous in ipairs(self.points) do
            if previous[1]==point[1] then self.points[index]=point; return end
        end
        self.points[#self.points+1]=point
    end
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
    function methods:GetEffectiveScale() return (self.scale or 1)*(self.parent and self.parent:GetEffectiveScale() or 1) end
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
    local function visibilityEvent(item,event)
        if item.scripts[event] then item.scripts[event](item) end
        for _,child in ipairs(item.children) do
            if child:IsShown() then visibilityEvent(child,event) end
        end
    end
    function methods:Show()
        if self.shown then return end
        self.shown=true
        if self:IsVisible() then visibilityEvent(self,'OnShow') end
    end
    function methods:Hide()
        if not self.shown then return end
        local wasVisible=self:IsVisible()
        self.shown=false
        if wasVisible then visibilityEvent(self,'OnHide') end
    end
    function methods:IsShown() return self.shown==true end
    function methods:IsVisible()
        return self.shown==true and (not self.parent or self.parent:IsVisible())
    end
    function methods:SetShown(value) if value then self:Show() else self:Hide() end end
    function methods:SetAlpha(value) self.alpha=value end
    function methods:GetAlpha() return self.alpha or 1 end
    function methods:GetEffectiveAlpha()
        return self:GetAlpha()*(self.parent and self.parent:GetEffectiveAlpha() or 1)
    end
    function methods:Enable() self.enabled=true end
    function methods:Disable() self.enabled=false end
    function methods:IsEnabled() return self.enabled~=false end
    function methods:SetEnabled(value) self.enabled=value~=false end
    function methods:SetChecked(value) self.checked=value==true or value==1 end
    function methods:GetChecked() return self.checked==true end
    function methods:SetText(text)
        self.text=tostring(text or '')
        resizeNativeEditor(self)
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end
    end
    function methods:GetText() return self.text or '' end
    function methods:SetFormattedText(format,...) self:SetText(string.format(format,...)) end
    function methods:SetFont(...) self.font={...}; return true end
    function methods:GetFont() return unpackValues(resolveFont(self)) end
    function methods:SetFontObject(value) self.fontObject=value; self.font=nil end
    function methods:GetFontObject() return self.fontObject or self.template end
    function methods:SetTextColor(...) self.textColor={...} end
    function methods:SetJustifyH(value) self.justifyH=value end
    function methods:SetJustifyV(value) self.justifyV=value end
    function methods:SetWordWrap(value) self.wordWrap=value end
    function methods:SetNonSpaceWrap(value) self.nonSpaceWrap=value end
    function methods:SetMaxLines(value) self.maxLines=value end
    function methods:SetSpacing(value) self.spacing=value end
    function methods:GetUnboundedStringWidth()
        return glyphWidth(self:GetText(),resolveFont(self)[2])
    end
    function methods:GetStringWidth()
        local natural=self:GetUnboundedStringWidth()
        return self.width and self.width>0 and math.min(natural,self.width) or natural
    end
    function methods:GetStringHeight()
        local height,lines=naturalTextHeight(self)
        if self.maxLines and lines>self.maxLines then return resolveFont(self)[2]+(self.maxLines-1)*resolveFont(self)[2]*1.15 end
        return height
    end
    function methods:IsTruncated()
        local natural,lines=naturalTextHeight(self)
        local horizontal=self.width and self.width>0 and self:GetUnboundedStringWidth()>self.width
        local vertical=self.height and natural>self.height
        return (self.wordWrap==false and horizontal) or (self.maxLines and lines>self.maxLines) or vertical or false
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
    function methods:SetDesaturated(value) self.desaturated=value end
    function methods:SetHorizTile(value) self.horizTile=value end
    function methods:SetVertTile(value) self.vertTile=value end
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
    function methods:GetNumLetters() return #self:GetText() end
    function methods:SetCursorPosition(value)
        self.cursorPosition=value
        if self.scripts.OnCursorChanged then
            local before=self:GetText():sub(1,value)
            local _,lines=before:gsub('\n','')
            self.scripts.OnCursorChanged(self,0,-lines*resolveFont(self)[2]*1.15,1,resolveFont(self)[2])
        end
    end
    function methods:GetCursorPosition() return self.cursorPosition or #self:GetText() end
    function methods:CreateLine(name,layer,template)
        local item=self:CreateTexture(name,layer,template); item.kind='Line'; return item
    end
    function methods:SetStartPoint(...)
        local point={...}; assert(type(point[2])=='table','native Line:SetStartPoint requires relativeTo frame')
        self.lineStart=point
    end
    function methods:SetEndPoint(...)
        local point={...}; assert(type(point[2])=='table','native Line:SetEndPoint requires relativeTo frame')
        self.lineEnd=point
    end
    function methods:SetThickness(value) self.thickness=value end

    local function object(kind,name,parent,template)
        local item={kind=kind,name=name,parent=parent,template=template,shown=true,
            enabled=true,events={},scripts={},points={},children={},regions={}}
        setmetatable(item,{__index=function(current,key)
            if key=='CreateLine' and options.noCreateLine then return nil end
            if current.kind=='EditBox' and (key=='GetStringHeight' or key=='GetStringWidth' or key=='GetUnboundedStringWidth' or key=='IsTruncated') then return nil end
            return methods[key]
        end})
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
    for _,name in ipairs({'Data.generated.lua','Normalize.lua','Rules.lua','Core.lua','Settings.lua','Commands.lua','Lock.lua','UI.lua','Minimap.lua'}) do
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
    function env:advance(seconds,maximumStep)
        assert(type(seconds)=='number' and seconds>=0,'advance requires a nonnegative duration')
        maximumStep=maximumStep or 1/120
        assert(maximumStep>0,'advance requires a positive frame step')
        local remaining=seconds
        while remaining>1e-9 do
            local elapsed=math.min(remaining,maximumStep)
            self.now=self.now+elapsed
            local delivery={}
            for _,item in ipairs(self.frames) do
                if item:IsVisible() and item.scripts.OnUpdate then delivery[#delivery+1]=item end
            end
            for _,item in ipairs(delivery) do
                local callback=item.scripts.OnUpdate
                if item:IsVisible() and callback then
                    self.updateCalls=self.updateCalls+1
                    callback(item,elapsed)
                end
            end
            remaining=remaining-elapsed
        end
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
        resizeNativeEditor(item)
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
    -- Resolve production frame anchors into layout-space rectangles. This verifies
    -- bounds and drives the optional preview; it is not a WoW rendering oracle.
    local anchor={TOPLEFT={0,0},TOP={.5,0},TOPRIGHT={1,0},LEFT={0,.5},CENTER={.5,.5},
        RIGHT={1,.5},BOTTOMLEFT={0,1},BOTTOM={.5,1},BOTTOMRIGHT={1,1}}
    function env:fontSize(item)
        return resolveFont(item)[2]
    end
    function env:bounds(item,ancestor,seen)
        seen=seen or {}; assert(not seen[item],'cyclic native frame anchors')
        seen[item]=true
        if item==ancestor then seen[item]=nil; return 0,0,item:GetWidth(),item:GetHeight() end
        local function relativeRect(target)
            if type(target)=='string' then target=self[target] end
            return self:bounds(target or item.parent,ancestor,seen)
        end
        if item.allPoints then
            local x,y,w,h=relativeRect(item.allPoints); seen[item]=nil; return x,y,w,h
        end
        local w=item.width or (item.kind=='FontString' and math.max(1,#item:GetText()*self:fontSize(item)*.52)) or 0
        local h=item.height or (item.kind=='FontString' and item:GetStringHeight()) or 0
        local first=item.points[1]
        local x,y=0,0
        if first then
            local point,target,relative,dx,dy=first[1],first[2],first[3],first[4],first[5]
            if type(target)=='number' then dx,dy,relative,target=target,relative,point,item.parent end
            if type(relative)=='number' then dx,dy,relative=relative,dx,point end
            local rx,ry,rw,rh=relativeRect(target)
            local a,b=anchor[point] or anchor.TOPLEFT,anchor[relative or point] or anchor.TOPLEFT
            x=rx+rw*b[1]+(dx or 0)-w*a[1]; y=ry+rh*b[2]-(dy or 0)-h*a[2]
            -- Opposing anchors determine size where SetWidth/Height was omitted.
            for index=2,#item.points do
                local p=item.points[index]; local pa,pb=anchor[p[1]] or anchor.TOPLEFT,anchor[p[3] or p[1]] or anchor.TOPLEFT
                local px,py,pw,ph=relativeRect(p[2]); px=px+pw*pb[1]+(p[4] or 0); py=py+ph*pb[2]-(p[5] or 0)
                if pa[1]~=a[1] then w=(px-(x+w*a[1]))/(pa[1]-a[1]); x=px-w*pa[1] end
                if pa[2]~=a[2] then h=(py-(y+h*a[2]))/(pa[2]-a[2]); y=py-h*pa[2] end
            end
        elseif item.parent then x,y=relativeRect(item.parent) end
        if item.parent and item.parent.scrollChild==item then y=y-(item.parent.verticalScroll or 0) end
        seen[item]=nil; return x,y,w,h
    end
    function env:snapshot(item)
        local rows={}
        local function linePoint(point)
            if not point then return nil end
            local x,y,w,h=self:bounds(point[2] or item,item)
            local origin=anchor[point[1]] or anchor.CENTER
            return {x+w*origin[1]+(point[3] or 0),y+h*origin[2]-(point[4] or 0)}
        end
        local function visit(current,depth,clip)
            if not current:IsVisible() then return end
            local x,y,w,h=self:bounds(current,item)
            local row={kind=current.kind,name=current.name,text=current.text,x=x,y=y,width=w,height=h,
                alpha=current:GetEffectiveAlpha(),depth=depth,fontSize=self:fontSize(current),font=current.font and current.font[1],
                textColor=current.textColor,justifyH=current.justifyH,justifyV=current.justifyV,wordWrap=current.wordWrap,maxLines=current.maxLines,textInsets=current.textInsets,
                texture=current.texture,colorTexture=current.colorTexture,vertexColor=current.vertexColor,texCoord=current.texCoord,rotation=current.rotation,
                lineStart=linePoint(current.lineStart),lineEnd=linePoint(current.lineEnd),thickness=current.thickness,
                layer=current.layer or 'FRAME',backdrop=current.backdrop,backdropColor=current.backdropColor,
                backdropBorderColor=current.backdropBorderColor,shadowColor=current.shadowColor,shadowOffset=current.shadowOffset,clip=clip,
                normalTexture=type(current.normalTexture)=='string' and current.normalTexture or nil}
            rows[#rows+1]=row
            local regions,frames={},{}
            for _,child in ipairs(current.children or {}) do
                local bucket=(child.kind=='Texture' or child.kind=='FontString' or child.kind=='Line') and regions or frames
                bucket[#bucket+1]=child
            end
            local layers={BACKGROUND=0,BORDER=1,ARTWORK=2,OVERLAY=3,HIGHLIGHT=4}
            local creation={}; for index,child in ipairs(regions) do creation[child]=index end
            table.sort(regions,function(a,b)
                local left,right=layers[a.layer] or 2,layers[b.layer] or 2
                if left==right then return creation[a]<creation[b] end
                return left<right
            end)
            for _,child in ipairs(regions) do visit(child,depth+1,clip) end
            local childClip=clip
            if current.kind=='ScrollFrame' or current.clipsChildren then
                childClip={x,y,x+w,y+h}
                if clip then childClip={math.max(x,clip[1]),math.max(y,clip[2]),math.min(x+w,clip[3]),math.min(y+h,clip[4])} end
            end
            for _,child in ipairs(frames) do visit(child,depth+1,childClip) end
        end
        visit(item,0); return rows
    end
    return env,ns
end

return H
