-- Every JSON classification fixture is evaluated by real Lua code in both profiles.
-- WoW APIs are isolated mocks. Target-client compatibility remains unverified.
local root = arg[1] or '.'
local H = assert(loadfile(root..'/tests/harness.lua'))()
local suite = assert(loadfile(root..'/tests/Fixtures.generated.lua'))()
local report = {suite='research',runtime=_VERSION,classification={total=0,passed=0,failed=0,failures={}},
    adapter={total=0,passed=0,failed=0,failures={}},contracts={},target_client='not_run'}
local printed = 0
local function failure(group, id, profile, actual, expected, note)
    group.failed = group.failed + 1
    group.failures[#group.failures+1] = {id=id,profile=profile,actual=tostring(actual),expected=tostring(expected),note=note}
    if printed < 40 then
        print('FAIL '..id..' ['..profile..']: '..tostring(actual)..' expected '..tostring(expected)..(note and ('; '..note) or ''))
        printed = printed + 1
    end
end
local function hasID(ids, id)
    for _, value in ipairs(ids or {}) do if value == id then return true end end
    return false
end

for _, profile in ipairs({'balanced','strict'}) do
    local e, ns = H.game('modern'); e:boot()
    for index, case in ipairs(suite.test_cases) do
        if case.kind == 'classification' then
            local cfg, context = ns.Rules.Defaults(), H.copy(case.context or {})
            cfg.mode = profile
            for key, value in pairs(suite.default_configuration or {}) do
                if key ~= 'manual_allowlist' and key ~= 'manual_blocklist' then cfg[key] = H.copy(value) end
            end
            for key, value in pairs(case.config_overrides or {}) do cfg[key] = H.copy(value) end
            context.event = case.event
            local ok, block, reason, detail, explanation = pcall(ns.Rules.Evaluate, case.message, cfg, context)
            local actual = ok and (block and 'block' or 'allow') or 'exception'
            local note
            if not ok then note = tostring(block)
            elseif type(explanation) ~= 'table' then note = 'missing structured explanation'
            else
                for _, id in ipairs(case.expected_indicator_ids_contains or {}) do
                    if not hasID(explanation.indicator_ids, id) then note = 'missing indicator '..id; break end
                end
                if not note then
                    for _, id in ipairs(case.expected_indicator_ids_excludes or {}) do
                        if hasID(explanation.indicator_ids, id) then note = 'unexpected indicator '..id; break end
                    end
                end
            end
            report.classification.total = report.classification.total + 1
            if actual ~= case.expected[profile] or note then
                failure(report.classification, case.id, profile, actual, case.expected[profile], note)
            else report.classification.passed = report.classification.passed + 1 end

            -- Run the same fixture through Core's callback, including scope and exceptions.
            local author, flags, guid = 'Fixture Seller-Realm', '', 'Player-Fixture'
            if context.sender_on_manual_allowlist then cfg.allow[ns.NameKey(author)] = true end
            if context.sender_on_manual_blocklist then cfg.block[ns.NameKey(author)] = true end
            if context.verified_gm_flag then flags = 'GM' end
            if context.is_self_guid then guid = 'Player-Self' end
            ns.db, e.ForeverCleanChatDB = cfg, cfg
            ns.Invalidate()
            local adapterOK, adapterBlock = pcall(e.chat, e, case.message, author, index, guid, flags, {}, case.event)
            local adapterActual = adapterOK and (adapterBlock and 'block' or 'allow') or 'exception'
            report.adapter.total = report.adapter.total + 1
            if adapterActual ~= case.expected[profile] then
                failure(report.adapter, case.id, profile, adapterActual, case.expected[profile], not adapterOK and tostring(adapterBlock) or nil)
            else report.adapter.passed = report.adapter.passed + 1 end
        end
    end
end

local assertions = 0
local function eq(actual, expected, label)
    assertions = assertions + 1
    assert(actual == expected, (label or 'assertion')..': '..tostring(actual)..' expected '..tostring(expected))
end
local function truth(actual, label) eq(actual == true, true, label) end
local function fresh(api, saved)
    local e, ns = H.game(api or 'modern', saved); e:boot(); return e, ns
end
local implementations = {}
function implementations.contract_api_namespace()
    local e, ns = fresh()
    eq(e.addCalls, 5); eq(ns.Install(), true); eq(ns.Install(), true)
    e:emit('ADDON_LOADED','ForeverCleanChat'); e:emit('PLAYER_LOGIN')
    eq(e.addCalls, 5); eq(ns.registeredCount, 5)
    for _, frame in ipairs(e.frames) do eq(frame.scripts.OnUpdate, nil) end
end
function implementations.contract_api_legacy()
    local e, ns = fresh('legacy')
    eq(ns.api,'ChatFrame_AddMessageEventFilter'); eq(e.addCalls,5)
    eq(e:chat('mythicstore.com',nil,1),true)
end
function implementations.contract_api_missing()
    local e, ns = fresh('none')
    eq(ns.installed,false); eq(e.addCalls,0); eq(#e.messages,1)
    eq(e.ChatFrame_AddMessageEventFilter,nil); eq(e.ChatFrame_MessageEventHandler,nil)
    eq(e.SendChatMessage,nil)
    e.ChatFrameUtil = {AddMessageEventFilter=e.mockAdd}
    e:emit('ADDON_LOADED','Blizzard_ChatFrameBase')
    eq(ns.installed,true); eq(e.addCalls,5)
end
function implementations.contract_api_signature()
    local e, ns = fresh()
    local function call() return ns.Filter({},'CHAT_MSG_CHANNEL','normal text','Author','language','channel','target','',0,2,'base',0,1,'Player-Other') end
    eq(select('#',call()),1); eq(call(),false)
    eq(select('#',e:chat('mythicstore.com',nil,2)),1); eq(e:chat('mythicstore.com',nil,2),true)
end
function implementations.contract_api_secret()
    local e, ns = fresh()
    eq(e:chat(e.secret,nil,1),false); eq(e:chat('mythicstore.com',e.secret,2),false)
    eq(ns.sessionBlocked,0); eq(#ns.log,0); eq(ns.sessionErrors,0)
    e.canaccessvalue = function() error('guard cannot read') end
    eq(e:chat('mythicstore.com',nil,3),false); eq(ns.sessionBlocked,0)
end
function implementations.contract_api_bad_type()
    local e, ns = fresh()
    for _, message in ipairs({17,{}}) do
        eq(ns.Rules.Evaluate(message,ns.db),false); eq(e:chat(message,nil,1),false)
    end
    eq(ns.Rules.Evaluate(nil,ns.db),false); eq(e:chat(nil,nil,2),false); eq(ns.sessionErrors,0)
end
function implementations.contract_api_invalid_utf8()
    local e, ns = fresh()
    for _, suffix in ipairs({'\255','\192\128','\240\159','\237\160\128','\244\144\128\128'}) do
        eq(ns.Rules.Evaluate('mythicstore.com'..suffix,ns.db),false)
        eq(e:chat('mythicstore.com'..suffix,nil,1),false)
    end
    eq(ns.sessionErrors,0)
end
function implementations.contract_api_arg_layout()
    local e, ns = fresh()
    eq(ns.Filter({},'CHAT_MSG_CHANNEL','mythicstore.com','Other',nil,nil,nil,nil,nil,nil,nil,nil,nil,nil),true)
    eq(ns.Filter({},'CHAT_MSG_CHANNEL','mythicstore.com','Other','Player-Self'),true)
    eq(e:chat('mythicstore.com','Other',e.secret,e.secret),true)
    eq(ns.sessionErrors,0)
end
function implementations.contract_multi_frames()
    local e, ns = fresh()
    for i=1,4 do eq(e:chat('mythicstore.com',nil,4711,nil,nil,{}),true) end
    eq(ns.sessionBlocked,1); eq(#ns.log,1); eq(ns.db.totalBlocked,1)
end
function implementations.contract_dedupe_fallback()
    local e, ns = fresh()
    eq(e:chat('mythicstore.com',nil,nil),true); eq(e:chat('mythicstore.com',nil,nil),true)
    eq(ns.sessionBlocked,1)
    e.now = e.now + 0.26
    eq(e:chat('mythicstore.com',nil,nil),true); eq(ns.sessionBlocked,2)
end
function implementations.contract_cache_config()
    local e, ns = fresh(); e:cmd('mode balanced')
    eq(e:chat('WTS RFC boosts 5g/run',nil,1),false,'balanced paid boost')
    e:cmd('mode strict'); eq(e:chat('WTS RFC boosts 5g/run',nil,2),true,'strict paid boost')
    e:cmd('allow Seller Name-Realm'); eq(e:chat('WTS RFC boosts 5g/run',nil,3),false,'allowlist update')
    e:cmd('unallow Seller Name-Realm'); eq(e:chat('WTS RFC boosts 5g/run',nil,4),true,'allowlist removal')
    eq(e:chat('mythicstore.com',nil,5),true)
    e:cmd('domainpolicy contextual'); eq(e:chat('mythicstore.com',nil,6),false,'contextual policy update')
    e:cmd('domainpolicy hide_all'); eq(e:chat('mythicstore.com',nil,7),true)
    eq(e:chat('mythicstore.com',nil,8,nil,nil,nil,'CHAT_MSG_GUILD'),false,'event scope differs')
end
function implementations.contract_cache_bound()
    local e, ns = fresh()
    for i=1,10000 do e:chat('mythicstore.com '..i,'Advertiser-Realm',i) end
    local counts = ns.CacheStats()
    truth(counts.decisions <= 256,'decision count'); truth(counts.seen <= 256,'dedupe count')
    eq(counts.log,50); eq(ns.sessionErrors,0); eq(ns.sessionBlocked,10000)
end
function implementations.contract_long_input()
    local e, ns = fresh()
    local long = 'mythicstore.com'..string.rep('x',4096)
    eq(ns.Rules.Evaluate(long,ns.db),false); eq(e:chat(long,nil,1),false)
    local malformed = '|Hitem:'..string.rep('x',4000)
    eq(e:chat(malformed,nil,2),false); eq(ns.sessionErrors,0)
end
function implementations.contract_normalization_work()
    local e, ns = fresh()
    local hosts = {}
    for i=1,33 do hosts[#hosts+1]='candidate'..i..'.example' end
    local message = 'mythicstore.com '..table.concat(hosts,' ')
    eq(ns.Rules.Evaluate(message,ns.db),false,'domain candidate work budget')
    eq(e:chat(message,nil,1),false)
    eq(ns.Rules.Evaluate('mythic'..string.rep(' ',100)..'store.com',ns.db),false,'separator budget')
    eq(ns.sessionErrors,0)
end
function implementations.contract_hidden_link_payload()
    local e, ns = fresh()
    for _, kind in ipairs({'item','spell','achievement'}) do
        eq(ns.Rules.Evaluate('|H'..kind..':mythicstore.com|h[Ordinary label]|h',ns.db),false)
    end
    eq(ns.Rules.Evaluate('|Hurl:https://mythicstore.com|h[Visit]|h',ns.db),true)
    eq(ns.Rules.Evaluate('|Hitem:123|h[mythicstore.com]|h',ns.db),true)
end
function implementations.contract_display_safe()
    local e, ns = fresh()
    local display = ns.Normalize.SafeDisplay('|Hurl:x|h[Click]|h\r\n|cffff0000red|r')
    truth(string.find(display,'||Hurl:x||h[Click]||h',1,true) ~= nil,'link pipes are escaped')
    truth(string.find(display,'||cffff0000red||r',1,true) ~= nil,'color pipes are escaped')
    eq(string.find(display,'\r',1,true),nil); eq(string.find(display,'\n',1,true),nil)
    e:chat('|cffff0000mythicstore.com|r\nnext',nil,1)
    e:cmd('log 1')
    local last = e.messages[#e.messages]
    truth(string.find(last,'||cffff0000',1,true) ~= nil,'display escapes link/color pipes')
    eq(string.find(last,'\n',1,true),nil)
    eq(e.SendChatMessage,nil)
end
function implementations.contract_no_user_identity_inference()
    local e, ns = fresh()
    eq(e:chat('mythicstore.com','Spam Seller-Realm',1),true)
    eq(e:chat('hi','Spam Seller2-Realm',2),false)
    eq(H.count(ns.db.block),0); eq(H.count(ns.db.allow),0)
end
function implementations.contract_no_network()
    local e, ns = fresh()
    local attempts = 0
    local function forbidden() attempts=attempts+1; error('network/code evaluation forbidden') end
    e.HTTP,e.Request,e.loadstring,e.dofile,e.SendChatMessage = forbidden,forbidden,forbidden,forbidden,forbidden
    eq(e:chat('mythicstore.com',nil,1),true); eq(attempts,0)
    truth(type(ns.Data.domains)=='table','packaged domain data')
end
function implementations.contract_migration_saved()
    local saved = {schema=1,enabled=false,mode='balanced',totalBlocked=42,
        domains={mythicstorecom='mythicstore.com',abcom='a-b.com',othercom='other.com'},
        phrases={['custom phrase']=true},allow={['trusted player-realm']=true},block={['blocked player-realm']=true}}
    local e, ns = fresh('modern',saved)
    eq(ns.db.enabled,false); eq(ns.db.mode,'balanced'); eq(ns.db.totalBlocked,42)
    eq(ns.db.domains['a-b.com'],'a-b.com'); eq(ns.db.domains['other.com'],'other.com')
    eq(ns.db.phrases['custom phrase'],true); eq(ns.db.allow['trusted player-realm'],true)
    eq(ns.db.block['blocked player-realm'],true); eq(ns.db.schema,2)
    local re,rns = fresh('modern',ns.db)
    eq(rns.db.domains['a-b.com'],'a-b.com'); eq(rns.db.totalBlocked,42)
    eq(#rns.log,0)
end
function implementations.contract_migration_missing()
    local e, ns = fresh()
    eq(ns.db.mode,'strict'); eq(ns.db.enabled,true); eq(ns.db.schema,2)
    eq(H.count(ns.db.domains),0,'builtins remain separate from custom entries')
    local le,lns = fresh('modern',{mode='balanced',domains={mythicstorecom='mythicstore.com'}})
    eq(lns.db.mode,'balanced')
    local cfg=ns.Rules.Defaults(); cfg.domains['a.com']='a.com'
    eq(ns.Rules.Defaults().domains['a.com'],nil,'fresh defaults do not share tables')
end
function implementations.contract_migration_invalid()
    local e, ns = fresh('modern',{mode='balanced',domains={badcompact=42,othercompact=false,validcom='valid.com'}})
    eq(ns.db.domains['valid.com'],'valid.com')
    eq(ns.db.domains['badcompact.com'],nil)
    local retained = {}
    for _, row in ipairs(ns.db.legacyReview or {}) do retained[row.key]=row.value end
    eq(retained.badcompact,42); eq(retained.othercompact,false)
    local re,rns = fresh('modern',ns.db)
    eq(#rns.db.legacyReview,#ns.db.legacyReview)
end

-- Extra regression checks for bugs identified during the original addon review.
function implementations.extra_domain_identity_and_boundaries()
    local e, ns = fresh()
    e:cmd('domain add a-b.com'); e:cmd('domain add ab.com'); e:cmd('domain add a.b.com')
    eq(ns.db.domains['a-b.com'],'a-b.com'); eq(ns.db.domains['ab.com'],'ab.com')
    eq(ns.db.domains['a.b.com'],'a.b.com')
    e:cmd('domain remove a-b.com')
    eq(ns.db.domains['a-b.com'],nil); eq(e:chat('ab.com',nil,1),true)
    eq(e:chat('a.b.com',nil,2),true); eq(e:chat('a-b.com',nil,3),false)
    eq(e:chat('notmythicstore.com',nil,4),false); eq(e:chat('mythicstore.com.example',nil,5),false)
    eq(e:chat('https://safe.example/mythicstore.com',nil,6),false)
    eq(e:chat('https://mythicstore.com@safe.example/',nil,7),false)
    eq(e:chat('https://shop.mythicstore.com/path',nil,8),true)
    e:cmd('mode balanced')
    eq(e:chat('WTS Copper Bar for leveling professions, see wowhead.com',nil,9),false)
end

local deferred = {
    contract_compile_deterministic='python_runner',contract_test_parity='python_runner',
    contract_regression_existing='python_runner',contract_live_scope='pending_live_client',
    contract_no_bubbles_claim='documentation_only',
}
for _, case in ipairs(suite.test_cases) do
    if case.kind == 'engineering_acceptance' then
        local body = implementations[case.id]
        if body then
            local before = assertions
            local ok, err = pcall(body)
            report.contracts[#report.contracts+1]={id=case.id,status=ok and 'passed_mock' or 'failed',assertions=assertions-before,error=not ok and tostring(err) or nil}
            if not ok then print('FAIL '..case.id..': '..tostring(err)) end
        else
            report.contracts[#report.contracts+1]={id=case.id,status=deferred[case.id] or 'not_implemented',assertions=0}
        end
    end
end
local before = assertions
local extraOK, extraError = pcall(implementations.extra_domain_identity_and_boundaries)
report.extra={id='extra_domain_identity_and_boundaries',status=extraOK and 'passed_mock' or 'failed',assertions=assertions-before,error=not extraOK and tostring(extraError) or nil}
if not extraOK then print('FAIL extra_domain_identity_and_boundaries: '..tostring(extraError)) end
report.engineering_assertions = assertions
print('Runtime: '.._VERSION)
print('JSON classifier/profile checks: '..report.classification.passed..'/'..report.classification.total)
print('JSON mocked adapter/profile checks: '..report.adapter.passed..'/'..report.adapter.total)
local passed,failed,pending=0,0,0
for _, contract in ipairs(report.contracts) do
    if contract.status=='passed_mock' then passed=passed+1
    elseif contract.status=='failed' or contract.status=='not_implemented' then failed=failed+1
    else pending=pending+1 end
end
print('Engineering contracts in Lua mocks: '..passed..' passed, '..failed..' failed, '..pending..' handled separately or pending')
print('Live WoW/Forever validation: NOT RUN')
FCC_RESEARCH_RESULT = report
if report.classification.failed>0 or report.adapter.failed>0 or failed>0 or not extraOK then error('Research test suite failed') end
