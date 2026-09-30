local ADDON, NS = ...
local N, R = NS.Normalize, NS.Rules
NS.VERSION = '1.0.0'
NS.Events = {'CHAT_MSG_CHANNEL','CHAT_MSG_SAY','CHAT_MSG_YELL','CHAT_MSG_WHISPER','CHAT_MSG_EMOTE'}
NS.sessionBlocked, NS.sessionErrors = 0, 0
NS.log, NS.installed = {}, false
NS.Scope = {}
for _, event in ipairs(NS.Events) do NS.Scope[event] = true end
NS.configGeneration, NS.callbackCount = 0, 0
NS.apiObservedEvents, NS.allowBlockConflicts = {}, 0
NS.uiErrors = 0
local changeListeners = {}
local frame = CreateFrame('Frame')
local decisionMap, decisionSlots, decisionNext = {}, {}, 1
local seenMap, seenSlots, seenNext = {}, {}, 1
local DECISIONS, SEEN, LOG = 256, 256, 50
local ownGUID, ownShort, ownFull

local function readable(value)
    if type(canaccessvalue) == 'function' then return canaccessvalue(value) end
    if type(issecretvalue) == 'function' then return not issecretvalue(value) end
    return true
end
NS.Readable = readable

function NS.Print(text)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage('|cff78cce8Forever Clean Chat:|r ' .. text)
    elseif type(print) == 'function' then
        print('Forever Clean Chat: ' .. text)
    end
end

function NS.NameKey(name)
    if type(name) ~= 'string' then return nil end
    name = string.gsub(string.gsub(name, '^%s+', ''), '%s+$', '')
    if name == '' or #name > 160 or string.find(name, '[|%c]') then return nil end
    -- Keep spaces within Forever character names. Do not merge different names.
    return string.lower(name)
end
local function shortName(key)
    return key and string.match(key, '^([^%-]+)')
end
local function listed(list, key)
    return key and (list[key] or list[shortName(key)])
end

function NS.AddChangeListener(listener)
    if type(listener) ~= 'function' then return false end
    for _, existing in ipairs(changeListeners) do if existing == listener then return true end end
    changeListeners[#changeListeners + 1] = listener
    return true
end

function NS.NotifyChange(kind)
    -- UI refresh errors must never change a chat filter decision.
    for _, listener in ipairs(changeListeners) do
        local ok = pcall(listener, kind)
        if not ok then NS.uiErrors = NS.uiErrors + 1 end
    end
end

function NS.Invalidate()
    decisionMap, decisionSlots, decisionNext = {}, {}, 1
    NS.configGeneration = NS.configGeneration + 1
    NS.NotifyChange('settings')
end

function NS.CacheStats()
    local decisions, seen = 0, 0
    for _ in pairs(decisionMap) do decisions=decisions+1 end
    for _ in pairs(seenMap) do seen=seen+1 end
    return {decisions=decisions,seen=seen,log=#NS.log,
        decision_limit=DECISIONS,dedupe_limit=SEEN,log_limit=LOG}
end

function NS.GetStatusSnapshot()
    local db, observed = NS.db or {}, 0
    for _ in pairs(NS.apiObservedEvents) do observed = observed + 1 end
    local enabledEvents = 0
    for _, event in ipairs(NS.Events) do
        if not db.chatEvents or db.chatEvents[event] ~= false then enabledEvents = enabledEvents + 1 end
    end
    return {version=NS.VERSION, enabled=db.enabled, mode=db.mode,
        policy=db.known_domain_mention_policy, sessionBlocked=NS.sessionBlocked,
        totalBlocked=db.totalBlocked or 0, sessionErrors=NS.sessionErrors, uiErrors=NS.uiErrors,
        registeredCount=NS.registeredCount or 0, totalEvents=#NS.Events,
        enabledEvents=enabledEvents, callbackCount=NS.callbackCount, observedCount=observed,
        api=NS.api, packVersion=NS.Data.dataset_version, domainsCount=#NS.Data.domains,
        cache=NS.CacheStats()}
end

function NS.InitializeUI()
    for _, module in ipairs({NS.UI or false, NS.Minimap or false}) do
        if module and type(module.Initialize) == 'function' then
            local ok, available = pcall(module.Initialize)
            if not ok then NS.uiErrors = NS.uiErrors + 1 end
            if not ok or available == false then
                NS.Print('A control panel component is unavailable. /fcc status remains available.')
            end
        end
    end
end

local function playerIdentity()
    if type(UnitGUID) == 'function' then
        local value = UnitGUID('player')
        if readable(value) and type(value) == 'string' then ownGUID = value end
    end
    local name, realm
    if type(UnitFullName) == 'function' then name, realm = UnitFullName('player')
    elseif type(UnitName) == 'function' then name, realm = UnitName('player') end
    if readable(name) and type(name) == 'string' then
        ownShort = NS.NameKey(name)
        if readable(realm) and type(realm) == 'string' and realm ~= '' then
            ownFull = NS.NameKey(name .. '-' .. string.gsub(realm, '%s+', ''))
        end
    end
end

function NS.Initialize()
    if NS.db then return end
    local d = R.Defaults()
    local existing = type(ForeverCleanChatDB) == 'table'
    local db = existing and ForeverCleanChatDB or {}
    local legacy = existing and db.schema ~= 2
    local review = type(db.legacyReview)=='table' and db.legacyReview or {}
    local function preserve(field,key,value)
        review[#review+1]={field=field,key=key,value=value}
    end
    if legacy and not db.migrationBackup then
        -- Original records remain available even when a value cannot be canonicalized.
        db.migrationBackup={schema=db.schema,enabled=db.enabled,mode=db.mode,totalBlocked=db.totalBlocked,
            domains=db.domains,phrases=db.phrases,allow=db.allow,block=db.block}
    end
    if type(db.enabled) ~= 'boolean' then db.enabled = d.enabled end
    if db.mode ~= 'balanced' and db.mode ~= 'strict' then db.mode = existing and 'balanced' or d.mode end
    if type(db.totalBlocked) ~= 'number' or db.totalBlocked ~= db.totalBlocked
        or db.totalBlocked < 0 or db.totalBlocked > 1000000000000 then db.totalBlocked = 0 end
    db.totalBlocked = math.floor(db.totalBlocked)
    local oldDomains=db.domains
    local domains = {}
    local hadOriginalDomain=false
    if type(oldDomains)=='table' then
      for oldKey, value in pairs(oldDomains) do
        if type(value)=='string' then
            local key, label = N.Domain(value)
            if key then
                domains[key] = label
                if key=='mythicstore.com' then hadOriginalDomain=true end
            else preserve('domains',oldKey,value) end
        else preserve('domains',oldKey,value) end
      end
    elseif oldDomains~=nil then preserve('domains',nil,oldDomains) end
    db.domains = domains
    for _, field in ipairs({'domainDisabled','domainAllow'}) do
        local clean={}
        if type(db[field])=='table' then
            for key,value in pairs(db[field]) do
                local canonical=type(key)=='string' and N.Domain(key)
                if canonical and value then clean[canonical]=true
                else preserve(field,key,value) end
            end
        elseif db[field]~=nil then preserve(field,nil,db[field]) end
        db[field]=clean
    end
    -- v0.1.0 had one default entry. Its explicit removal must survive a pack update.
    if legacy and type(oldDomains)=='table' and not hadOriginalDomain then db.domainDisabled['mythicstore.com']=true end
    if db.known_domain_mention_policy~='hide_all' and db.known_domain_mention_policy~='contextual' then
        db.known_domain_mention_policy='hide_all'
    end
    for _, field in ipairs({'phrases','allow','block'}) do
        local clean = {}
        if type(db[field]) == 'table' then
            for key, value in pairs(db[field]) do
                if value and type(key) == 'string' and #key <= 160 then
                    local valid = field == 'phrases' and N.Text(key) or NS.NameKey(key)
                    if valid and #valid >= (field == 'phrases' and 3 or 1) then clean[valid] = true
                    else preserve(field,key,value) end
                else preserve(field,key,value) end
            end
        elseif db[field]~=nil then preserve(field,nil,db[field]) end
        db[field] = clean
    end
    db.schema,db.legacyReview = 2,review
    db.packVersion=NS.Data.dataset_version
    -- Add presentation preferences without replacing existing filtering choices.
    if type(db.chatEvents) ~= 'table' then db.chatEvents = {} end
    for _, event in ipairs(NS.Events) do
        if type(db.chatEvents[event]) ~= 'boolean' then db.chatEvents[event] = true end
    end
    if type(db.ui) ~= 'table' then db.ui = {} end
    db.ui.language = 'en'
    if type(db.ui.window) ~= 'table' then db.ui.window = {} end
    local anchors = {CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,
        TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
    local function finite(value)
        return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
    end
    local window = db.ui.window
    if not anchors[window.point] then window.point = 'CENTER' end
    if not anchors[window.relativePoint] then window.relativePoint = 'CENTER' end
    window.x = finite(window.x) and math.max(-10000, math.min(10000, window.x)) or 0
    window.y = finite(window.y) and math.max(-10000, math.min(10000, window.y)) or 0
    if type(db.ui.minimap) ~= 'table' then db.ui.minimap = {} end
    local minimap = db.ui.minimap
    if type(minimap.hide) ~= 'boolean' then minimap.hide = false end
    minimap.angle = finite(minimap.angle) and minimap.angle % 360 or 225
    ForeverCleanChatDB, NS.db = db, db
    playerIdentity()
end

local function decision(event,message)
    local key=event..'\031'..NS.db.mode..'\031'..NS.db.known_domain_mention_policy
        ..'\031'..NS.Data.dataset_version..'\031'..NS.configGeneration..'\031'..message
    local cached = decisionMap[key]
    if cached then return cached.block, cached.reason, cached.detail,cached.explanation end
    local block, reason, detail,explanation = R.Evaluate(message, NS.db,{event=event})
    local old = decisionSlots[decisionNext]
    if old then decisionMap[old] = nil end
    decisionSlots[decisionNext] = key
    decisionMap[key] = {block=block, reason=reason, detail=detail,explanation=explanation}
    decisionNext = decisionNext % DECISIONS + 1
    return block, reason, detail,explanation
end

local function record(event, message, author, lineID, reason, detail,explanation)
    local now = type(GetTime) == 'function' and GetTime() or 0
    local stable = readable(lineID) and (type(lineID) == 'number' or type(lineID) == 'string')
    stable = stable and lineID ~= '' and lineID ~= 0 and lineID ~= '0'
    local key
    if stable then key = event .. '\031id:' .. tostring(lineID)
    else key = event .. '\031' .. (author or '') .. '\031' .. message end
    local previous = seenMap[key]
    -- A filter is called once per chat frame. Count each incoming line only once.
    -- Without a line ID, identical messages within 0.25s share a counter entry.
    if previous and (stable or now - previous.time < 0.25) then return end
    local old = seenSlots[seenNext]
    if old and seenMap[old.key] == old then seenMap[old.key] = nil end
    local entry = {key=key,time=now}
    seenSlots[seenNext], seenMap[key] = entry, entry
    seenNext = seenNext % SEEN + 1
    NS.sessionBlocked = NS.sessionBlocked + 1
    NS.db.totalBlocked = math.min(1000000000000, NS.db.totalBlocked + 1)
    NS.log[#NS.log + 1] = {
        author=author or '?', event=event, reason=reason, detail=detail,
        rule_id=explanation and explanation.rule_id,indicator_ids=explanation and explanation.indicator_ids,
        -- Full normal chat messages fit; cap unusual oversized custom-event data.
        message=string.sub(message, 1, 1024), time=now,
    }
    if #NS.log > LOG then table.remove(NS.log, 1) end
    NS.NotifyChange('log')
end

local function process(event, message, author, flags, lineID, guid)
    if not NS.db or not NS.db.enabled or not NS.Scope[event] then return false end
    if NS.db.chatEvents and NS.db.chatEvents[event] == false then return false end
    if not readable(message) or type(message) ~= 'string' or #message > 4096 then return false end
    if not readable(author) then return false end
    if readable(flags) and (flags == 'GM' or flags == 'DEV') then return false end
    if readable(guid) and type(guid) == 'string' and ownGUID and guid == ownGUID then return false end
    local safeAuthor = readable(author) and type(author) == 'string' and author or nil
    local key = NS.NameKey(safeAuthor)
    local hasGUID=readable(guid) and type(guid)=='string' and guid~=''
    if not hasGUID and key and (key==ownFull or (not string.find(key,'-',1,true) and key==ownShort)) then return false end
    if listed(NS.db.allow,key) then
        if listed(NS.db.block,key) then NS.allowBlockConflicts=NS.allowBlockConflicts+1 end
        return false
    end
    local block, reason, detail,explanation
    if listed(NS.db.block,key) then
        block,reason,detail,explanation=R.Evaluate(message,NS.db,{event=event,sender_on_manual_blocklist=true})
    else block, reason, detail,explanation = decision(event,message) end
    if block then record(event, message, safeAuthor, lineID, reason, detail,explanation) end
    return block == true
end

function NS.Filter(_, event, message, author, ...)
    -- After message/author: language, channel, target, flags, zoneID,
    -- channelIndex, baseChannel, unused, lineID, GUID, ...
    -- Read only fields needed by this addon; never return rewritten chat arguments.
    local flags, lineID, guid = select(4, ...), select(9, ...), select(10, ...)
    NS.callbackCount=NS.callbackCount+1
    if type(event)=='string' and NS.Scope[event] then NS.apiObservedEvents[event]=true end
    local ok, blocked = pcall(process, event, message, author, flags, lineID, guid)
    if not ok then
        NS.sessionErrors = NS.sessionErrors + 1
        -- Fail OPEN. A beta API change must not silently swallow normal chat.
        if NS.sessionErrors == 1 then
            NS.Print('A filtering error occurred; that message was left visible. /fcc status')
        end
        return false
    end
    return blocked
end

function NS.Install()
    if NS.installed or not NS.db then return NS.installed end
    local candidates={}
    if type(ChatFrameUtil) == 'table' and type(ChatFrameUtil.AddMessageEventFilter) == 'function' then
        candidates[#candidates+1]={add=ChatFrameUtil.AddMessageEventFilter,api='ChatFrameUtil'}
    end
    if type(ChatFrame_AddMessageEventFilter) == 'function' then
        candidates[#candidates+1]={add=ChatFrame_AddMessageEventFilter,api='ChatFrame_AddMessageEventFilter'}
    end
    if #candidates==0 then return false end
    NS.registeredEvents = NS.registeredEvents or {}
    NS.eventAPIs=NS.eventAPIs or {}
    local count = 0
    for i = 1, #NS.Events do
        local event = NS.Events[i]
        if not NS.registeredEvents[event] then
            for _, candidate in ipairs(candidates) do
                local ok,result=pcall(candidate.add,event,NS.Filter)
                if ok and result~=false then
                    NS.registeredEvents[event]=true
                    NS.eventAPIs[event]=candidate.api
                    break
                end
            end
        end
        if NS.registeredEvents[event] then count = count + 1 end
    end
    local used,names={},{}
    for _, api in pairs(NS.eventAPIs) do used[api]=true end
    for api in pairs(used) do names[#names+1]=api end
    table.sort(names)
    NS.api, NS.registeredCount = #names>0 and table.concat(names,' + ') or candidates[1].api, count
    NS.installed = count == #NS.Events
    return NS.installed
end

frame:RegisterEvent('ADDON_LOADED')
frame:RegisterEvent('PLAYER_LOGIN')
frame:SetScript('OnEvent', function(self, event, name)
    if event == 'ADDON_LOADED' then
        if name == ADDON then NS.Initialize() end
        if NS.db and NS.Install() then self:UnregisterEvent('ADDON_LOADED') end
    elseif event == 'PLAYER_LOGIN' then
        NS.Initialize()
        playerIdentity()
        if NS.Install() then self:UnregisterEvent('ADDON_LOADED')
        else NS.Print('Chat filter API unavailable or incomplete. No full protection. /fcc status') end
        NS.InitializeUI()
        self:UnregisterEvent('PLAYER_LOGIN')
    end
end)
