-- Lua 5.1-compatible isolated WoW mocks; never sends chat or loads the live client.
local root = arg[1] or '.'
local H = {}
function H.chunk(path, env)
    local f, err
    if _VERSION == 'Lua 5.1' then
        f, err = loadfile(path)
        if f then setfenv(f, env) end
    else f, err = loadfile(path, 't', env) end
    assert(f, err)
    return f
end
function H.game(api, saved)
    local env, ns = {}, {}
    setmetatable(env, {__index=_G})
    env._G = env
    env.ForeverCleanChatDB = saved
    env.SlashCmdList, env.frames, env.messages, env.filters, env.addCalls = {}, {}, {}, {}, 0
    env.now, env.secret = 10, {}
    env.DEFAULT_CHAT_FRAME = {AddMessage=function(_, message) env.messages[#env.messages+1] = message end}
    env.GetTime = function() return env.now end
    env.UnitGUID = function() return 'Player-Self' end
    env.UnitFullName = function() return 'Test Player', 'Test Realm' end
    env.canaccessvalue = function(value) return value ~= env.secret end
    env.CreateFrame = function()
        local f = {events={},scripts={}}
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:SetScript(e,fn) self.scripts[e] = fn end
        env.frames[#env.frames+1] = f
        return f
    end
    local function add(event, fn)
        if env.failEvent == event then error('simulated unsupported event') end
        env.addCalls = env.addCalls + 1
        env.filters[event] = fn
    end
    env.mockAdd = add
    if api == 'modern' then env.ChatFrameUtil = {AddMessageEventFilter=add}
    elseif api == 'legacy' then env.ChatFrame_AddMessageEventFilter = add end
    for _, name in ipairs({'Data.generated.lua','Normalize.lua','Rules.lua','Core.lua','Settings.lua','Commands.lua'}) do
        H.chunk(root..'/'..name, env)('ForeverCleanChat', ns)
    end
    function env:emit(event, ...)
        for _, f in ipairs(self.frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
        end
    end
    function env:boot()
        self:emit('ADDON_LOADED', 'ForeverCleanChat')
        self:emit('PLAYER_LOGIN')
    end
    function env:cmd(text) self.SlashCmdList.FOREVERCLEANCHAT(text) end
    function env:chat(message, author, id, guid, flags, frameID, event)
        return ns.Filter(frameID or {}, event or 'CHAT_MSG_CHANNEL', message, author or 'Seller Name-Realm',
            'Common', '2. Trade', '', flags or '', 0, 2, 'Trade', 0, id, guid or 'Player-Seller')
    end
    return env, ns
end
function H.copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = H.copy(item) end
    return out
end
function H.count(value)
    local n = 0
    for _ in pairs(value or {}) do n = n + 1 end
    return n
end
return H
