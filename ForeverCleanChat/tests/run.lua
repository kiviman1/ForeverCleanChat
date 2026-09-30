-- Run: lua tests/run.lua .    OR    texlua tests/run.lua .
-- Runtime game APIs are mocked. This is NOT a live WoW integration test.
local root = arg[1] or '.'
local total, failed, failures = 0, 0, {}
local function check(label, actual, expected)
    total = total + 1
    if actual ~= expected then
        failed = failed + 1
        failures[#failures + 1] = {id=label,actual=tostring(actual),expected=tostring(expected)}
        print('FAIL: '..label..' | actual='..tostring(actual)..', expected='..tostring(expected))
    end
end
local function chunk(path, env)
    local f, err
    if _VERSION == 'Lua 5.1' then
        f, err = loadfile(path)
        if f then setfenv(f, env) end
    else f, err = loadfile(path, 't', env) end
    assert(f, err)
    return f
end
local function game(api, saved)
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
        chunk(root..'/'..name, env)('ForeverCleanChat', ns)
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
    function env:chat(message, author, id, guid, flags, frameID)
        return ns.Filter(frameID or {}, 'CHAT_MSG_CHANNEL', message, author or 'Seller Name-Realm',
            'Common', '2. Trade', '', flags or '', 0, 2, 'Trade', 0, id, guid or 'Player-Seller')
    end
    return env, ns
end

local e, ns = game('modern')
e:boot()
e:cmd('mode balanced') -- v0.1.0 baseline keeps its explicit balanced profile.
local R, N = ns.Rules, ns.Normalize
local cfg = R.Defaults()
cfg.mode = 'balanced'
local function expectRule(label, message, want, settings)
    check('rule: '..label, R.Evaluate(message, settings or cfg), want)
end
for i, t in ipairs(R.SelfTests) do expectRule('built-in '..i, t[2], t[1]) end
local spam = {
    'MythicStore.com', 'MYTHICSTORE.COM', 'Visit https://www.mythicstore.com/forever today',
    'mythicstore (dot) com', 'mythicstore {dot} com', 'mythicstore dot com',
    'MythicStore . com', 'm.y.t.h.i.c.s.t.o.r.e.c.o.m', 'M-Y-T-H-I-C-S-T-O-R-E COM',
    'Myth1cSt0re.c0m','mythic5tore.com','mythicstor3.com',
    'mythic\226\128\139store.com','mythic\226\128\140store.com','mythic\239\187\191store.com',
    'mythic\204\129store.com','ＭＹＴＨＩＣＳＴＯＲＥ．ＣＯＭ','ⓜⓨⓣⓗⓘⓒⓢⓣⓞⓡⓔ.ⓒⓞⓜ',
    '𝐌𝐲𝐭𝐡𝐢𝐜𝐒𝐭𝐨𝐫𝐞.𝐜𝐨𝐦', 'MythіcStоre.com', 'MythicStöre.com',
    '|cffff0000MythicStore|r.com', 'Mythic|TInterface\\Icons\\x:12|tStore.com',
    'Mythic|A:some-atlas:12:12|aStore.com', 'Mythic{rt8}Store.com',
    'Mythic{SKULL}Store.com', '|Hurl:fake|h[MythicStore.com]|h',
    'Buy gold, fast delivery, visit store-example.com',
    'WTS gold 10USD', 'Buy gold £10 fast delivery', 'WTS gold 12€',
    'Buy dungeon boosting $20', 'WTS leveling service 20GBP',
    'Book a dungeon carry at example.gg', 'Buy professions at example.net',
    'Enjoy Forever! Leveling, dungeons, gearing, professions. Order for Beta!',
    'We cover your leveling, dungeons and gearing. Order now.',
}
-- Research contract replaces global compact matching with structural host parsing.
-- These old positive samples have no independent sales context; they now allow.
-- R025/R027 additionally require defined promotion evidence in balanced mode.
-- The old "Book a dungeon carry", "Buy professions", and "We cover...Order now"
-- examples have none; keep each scenario while documenting its changed result.
local changedAdvertisementExpectations = {[8]=true,[9]=true,[10]=true,[11]=true,[12]=true,[34]=true,[35]=true,[37]=true}
for i, message in ipairs(spam) do expectRule('advertisement '..i, message, not changedAdvertisementExpectations[i]) end
local normal = {
    'LFG RFC tank and healer needed', 'LFM WC 1 tank 1 healer', 'LFM dungeon - no boosts',
    'Anyone leveling a shaman?', 'I hate dungeon boosting advertisements',
    'WTS Copper Ore 20s', 'WTS [Copper Bar] 2g', 'WTB Copper Ore',
    'WTS enchants, bring mats, tips welcome', 'WTS bags, cheap prices!',
    'WTS item [Gear Ring] for 5g', 'WTS Mithril Spurs, improve riding speed',
    'Can someone boost me for free?', 'Free dungeon boosts for new players',
    'WTS RFC boosts 5g/run', 'Selling dungeon carries for gold only',
    'Our guild has a website: guild-example.com', 'Look at wowhead.com for this quest',
    'Look at our professions guide at guild-example.org', 'Anyone doing dungeons while leveling professions?',
    'Pre-ordering Forever looks fun', 'The store has the new edition',
    'I need 12 gold for training', 'Anyone have spare gold?', 'Can you help with gearing?',
    'Buying copper for my profession', 'We cover leveling and dungeons in our guild',
    '|cff00ff00|Hitem:12345:0:0:0|h[Copper Bar]|h|r WTS 1g',
    '|Hitem:mythicstore.com|h[Copper Bar]|h', -- invisible link metadata must not trigger
    'Halp! 帮帮我', 'Türkçe konuşuyor musunuz?', 'Dungeons & dragons night?',
    'The Mythic Store company sounds questionable', 'The website example.com is offline',
    'I paid £20 for lunch', 'wowhead.com has a dungeon leveling guide',
    'WTS Copper Bar, 50% discount', 'I ordered dinner while leveling',
    '', '  ', '\255\254Hello', '\192\128Hello', '\240\159',
}
for i, message in ipairs(normal) do expectRule('normal chat '..i, message, false) end
expectRule('nil', nil, false)
expectRule('table', {}, false)
expectRule('oversized input', string.rep('x', 4097)..'mythicstore.com', false)
expectRule('newline split domain', 'mythic\nstore.com', false)
local strict = R.Defaults(); strict.mode = 'strict'
expectRule('strict paid boosts', 'WTS RFC boosts 5g/run', true, strict)
expectRule('strict carry sale', 'Selling dungeon carries for gold only', true, strict)
expectRule('strict normal WTS', 'WTS Copper Ore 20s', false, strict)
expectRule('strict free help', 'Free dungeon boosts for new players', false, strict)
expectRule('strict group', 'LF healer for dungeon', false, strict)
check('markup safety', N.SafeDisplay('|Hfoo|hbad|h\ntext'), '||Hfoo||hbad||h text')
check('Turkish normalization', N.Text('ŞİĞÖÇÜ ı'), 'sigocu i')
check('canonical domain', N.Domain('HTTPS://WWW.Example.COM/path'), 'example.com')
check('invalid domain', N.Domain('not a domain'), nil)

-- Loader, scope and live callback contract (mocked game API).
check('modern API installed', ns.installed, true)
check('five event registrations', e.addCalls, 5)
check('guild untouched', e.filters.CHAT_MSG_GUILD, nil)
check('party untouched', e.filters.CHAT_MSG_PARTY, nil)
check('raid untouched', e.filters.CHAT_MSG_RAID, nil)
check('BN whisper untouched', e.filters.CHAT_MSG_BN_WHISPER, nil)
check('system untouched', e.filters.CHAT_MSG_SYSTEM, nil)
check('incoming whisper registered', type(e.filters.CHAT_MSG_WHISPER), 'function')
check('no OnUpdate', e.frames[1].scripts.OnUpdate, nil)
check('no repeated install', ns.Install(), true)
check('no duplicate registrations', e.addCalls, 5)
check('normal callback passes', e:chat('LFM healer', nil, 1), false)
check('spam callback blocks', e:chat('MythicStore.com', nil, 2), true)
check('counter 1', ns.sessionBlocked, 1)
check('duplicate frame blocked too', e:chat('MythicStore.com', nil, 2, nil, nil, {}), true)
check('duplicate frame counted once', ns.sessionBlocked, 1)
check('repeat new line still blocked', e:chat('MythicStore.com', nil, 3), true)
check('new line counted', ns.sessionBlocked, 2)
check('new advertiser blocked', e:chat('MythicStore.com', 'Different Player-Realm', 4), true)
check('GM messages pass', e:chat('MythicStore.com', nil, 5, nil, 'GM'), false)
check('DEV messages pass', e:chat('MythicStore.com', nil, 6, nil, 'DEV'), false)
check('own GUID passes', e:chat('MythicStore.com', 'Test Player-TestRealm', 7, 'Player-Self'), false)
check('own name with conflicting GUID not exempt', e:chat('MythicStore.com', 'Test Player-TestRealm', 8), true)
check('different realm same name not exempt', e:chat('MythicStore.com', 'Test Player-OtherRealm', 9), true)
check('secret message passes safely', e:chat(e.secret, nil, 10), false)
check('secret author fails open', e:chat('MythicStore.com', e.secret, 11), false)
check('secret flags safe', e:chat('MythicStore.com', nil, 12, nil, e.secret), true)
check('secret ID safe', e:chat('MythicStore.com', 'SecretId Player', e.secret), true)
check('secret GUID safe', e:chat('MythicStore.com', nil, 13, e.secret), true)
check('non-string passes', e:chat(123, nil, 14), false)
check('no runtime errors', ns.sessionErrors, 0)
local before = ns.sessionBlocked
e:chat('MythicStore.com', 'NoId Player', nil)
e:chat('MythicStore.com', 'NoId Player', nil)
check('missing ID counted once across frames', ns.sessionBlocked, before+1)
e.now = e.now + 1
e:chat('MythicStore.com', 'NoId Player', nil)
check('missing ID later repeat counted', ns.sessionBlocked, before+2)

-- User controls and cache invalidation.
e:cmd('off')
check('off passes spam', e:chat('MythicStore.com', nil, 15), false)
e:cmd('on')
check('on blocks again', e:chat('MythicStore.com', nil, 16), true)
e:cmd('allow Seller Name-Realm')
check('name with spaces allowlist', e:chat('MythicStore.com', nil, 17), false)
e:cmd('unallow Seller Name-Realm')
check('unallow blocks again', e:chat('MythicStore.com', nil, 18), true)
e:cmd('allow Seller Name')
check('short-name allowlist', e:chat('MythicStore.com', nil, 19), false)
e:cmd('unallow Seller Name')
e:cmd('block Seller Name-Realm')
check('manual block normal message', e:chat('hello', nil, 20), true)
e:cmd('unblock Seller Name-Realm')
check('unblock normal message', e:chat('hello', nil, 21), false)
e:cmd('mode strict')
check('strict enables', e:chat('WTS RFC boosts 5g/run', nil, 22), true)
e:cmd('mode balanced')
check('balanced invalidates cached strict block', e:chat('WTS RFC boosts 5g/run', nil, 23), false)
e:cmd('domain add other-example.com')
check('custom domain', e:chat('other-example.com', nil, 24), true)
e:cmd('domain remove other-example.com')
check('remove domain invalidates cache', e:chat('other-example.com', nil, 25), false)
e:cmd('domain remove mythicstore.com')
check('built-in domain removable', e:chat('MythicStore.com', nil, 26), false)
e:cmd('domain add mythicstore.com')
e:cmd('word add annoying offer')
check('custom phrase', e:chat('My ANNOYING OFFER today', nil, 27), true)
check('phrase word boundary', e:chat('my annoying offers today', nil, 28), false)
e:cmd('word remove annoying offer')
check('phrase removal', e:chat('My annoying offer today', nil, 29), false)
e:cmd('word add [' )
check('invalid pattern input harmless', e:chat('normal message', nil, 30), false)
local testCount = ns.sessionBlocked
e:cmd('test')
check('selftest does not affect counters', ns.sessionBlocked, testCount)
for _,command in ipairs({'status','stats','help','log 2','list','','unknown','mode invalid','domain','allow'}) do
    local ok = pcall(e.cmd, e, command)
    check('command safe: '..command, ok, true)
end
check('invalid mode did not change setting', ns.db.mode, 'balanced')

-- Bounded collections and malformed data.
for i=100,500 do e:chat('MythicStore.com ad '..i, 'Spam Player-Realm', i) end
check('session log bounded at 50', #ns.log, 50)
check('large stream no errors', ns.sessionErrors, 0)
local savedCount = ns.db.totalBlocked
local re, rns = game('modern', e.ForeverCleanChatDB)
re:boot()
check('settings survive reload', rns.db.domains['mythicstore.com'], 'mythicstore.com')
check('counter survives reload', rns.db.totalBlocked, savedCount)
check('messages not persisted', #rns.log, 0)
check('session counter reset', rns.sessionBlocked, 0)
local badSaved = {enabled='broken',mode='bad',domains={['x']=42},phrases={['']=true,[15]=true},
    allow='bad',block={},totalBlocked=0/0}
local be,bns=game('modern',badSaved); be:boot()
check('corrupt enabled repaired', bns.db.enabled, true)
check('corrupt mode repaired', bns.db.mode, 'balanced')
check('NaN count repaired', bns.db.totalBlocked, 0)
check('corrupt lists safe', be:chat('hi',nil,1), false)
local se,sns=game('modern', {enabled=false,domains={},phrases={},allow={},block={}}); se:boot()
check('disabled setting preserved', sns.db.enabled, false)
check('empty domain list preserved', next(sns.db.domains), nil)

-- Legacy API, deferred API and partial registration.
local le,lns=game('legacy'); le:boot()
check('legacy API available', lns.installed, true)
check('legacy API chosen', lns.api, 'ChatFrame_AddMessageEventFilter')
check('legacy blocks', le:chat('mythicstore.com',nil,1), true)
local ne,nns=game('none'); ne:boot()
check('missing API recognized', nns.installed, false)
check('missing API warns once', #ne.messages, 1)
ne.ChatFrameUtil={AddMessageEventFilter=ne.mockAdd}
ne:emit('ADDON_LOADED','Blizzard_ChatFrameBase')
check('deferred API installed', nns.installed, true)
check('deferred five events', ne.addCalls, 5)
local pe,pns=game('modern'); pe.failEvent='CHAT_MSG_EMOTE'; pe:boot()
check('partial API not marked complete', pns.installed, false)
check('partial registration count', pns.registeredCount, 4)
pe.failEvent=nil; pe:cmd('status')
check('retry completes registration', pns.installed, true)
check('retry did not duplicate successes', pe.addCalls, 5)

-- Fail open on a genuine rule-engine exception.
local fe,fns=game('modern'); fe:boot()
fns.Rules.Evaluate=function() error('simulated rule failure') end
check('exception passes normal chat', fe:chat('must remain visible',nil,1), false)
check('exception recorded', fns.sessionErrors, 1)
check('second exception also passes', fe:chat('another message',nil,2), false)
check('only one error warning', #fe.messages, 1)

-- Deterministic byte fuzz: normalization must tolerate invalid UTF-8 without crashing.
local fuzzOK=true
math.randomseed(173)
for i=1,300 do
    local bytes={}
    for j=1,math.random(1,300) do bytes[j]=string.char(math.random(0,255)) end
    local ok=pcall(R.Evaluate,table.concat(bytes),cfg)
    if not ok then fuzzOK=false; break end
end
check('300 invalid-byte fuzz inputs', fuzzOK, true)

print('Runtime: '.._VERSION)
print('Checks: '..(total-failed)..'/'..total..' passed; '..failed..' failed')
print('Live WoW/Forever validation: NOT RUN (mocked APIs only)')
FCC_TEST_RESULT = {suite='v0.1.0_regression_adapted',runtime=_VERSION,total=total,passed=total-failed,
    failed=failed,failures=failures,live_validation='not_run'}
if failed > 0 then error('Test suite failed') end
