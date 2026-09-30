-- Contract-derived audit regressions, separate from the unmodified JSON fixtures.
-- Runs the actual addon classifier and mock callback in both supported Lua runtimes.
local root = arg[1] or '.'
local H = assert(loadfile(root..'/tests/harness.lua'))()
local report = {suite='adversarial',runtime=_VERSION,classification={total=0,passed=0,failed=0,failures={}},
    adapter={total=0,passed=0,failed=0,failures={}},checks={},target_client='not_run'}
local cases = {
    {id='free_help_does_not_mask_separate_offer',message='Free boost for guildmates, WTS carries for other players.',balanced=false,strict=true},
    {id='free_carry_does_not_mask_boost_sale',message='WTS boosts, free carry for guildmates.',balanced=false,strict=true},
    {id='free_help_with_paid_upsell',message='Free carry for new players, paid boosts available for everyone else.',balanced=false,strict=true},
    {id='service_gold_is_price',message='We offer boosts for 100 gold at discord.gg/example.',balanced=false,strict=true},
    {id='service_gold_price_no_destination',message='We offer boosts for 100 gold.',balanced=false,strict=true},
    {id='ordinary_item_gold_price',message='WTS Runecloth 10 gold per stack.',balanced=false,strict=false},
    {id='payment_negated_paypal',message='WTS gold for in-game gold only, no PayPal.',balanced=false,strict=true},
    {id='payment_negated_real_money',message='WTS gold, no real money accepted.',balanced=false,strict=true},
    {id='currency_unit_without_amount',message='WTS gold USD',balanced=false,strict=true},
    {id='currency_unit_word_suffix',message='WTS gold 10USDollars.',balanced=false,strict=true},
    {id='currency_unit_alphabetic_suffix',message='WTS gold 10USDabc.',balanced=false,strict=true},
    {id='currency_unit_exponent_rejected',message='WTS gold 1e3USD.',balanced=false,strict=true},
    {id='currency_malformed_separators',message='WTS gold $1,2,3.',balanced=false,strict=true},
    {id='currency_fraction_too_long',message='WTS gold $1.234',balanced=false,strict=true},
    {id='currency_integer_too_long',message='WTS gold 1234567890USD',balanced=false,strict=true},
    {id='currency_nonpositive',message='WTS gold 0USD',balanced=false,strict=true},
    {id='currency_valid_suffix_control',message='WTS gold 10USD',balanced=true,strict=true},
    {id='currency_valid_euro_suffix',message='WTS gold 12€',balanced=true,strict=true},
    {id='currency_valid_prefix_control',message='WTS gold $10',balanced=true,strict=true},
    {id='free_offered_boosts',message='We offer free boosts for new players.',balanced=false,strict=false},
    {id='free_offered_dungeon_no_gold',message='We offer free dungeon boosts, no gold required.',balanced=false,strict=false},
    {id='personal_future_gold_buyer',message='I will buy gold for $10.',balanced=false,strict=false},
    {id='personal_future_boost_buyer',message='I will buy boosts for $10.',balanced=false,strict=false},
    {id='buyer_does_not_mask_gold_sale',message='WTB boosts but we sell gold for $5.',balanced=true,strict=true},
    {id='buyer_does_not_mask_boost_sale',message='WTB portal but WTS dungeon boosts $10.',balanced=true,strict=true},
    {id='unrelated_boost_and_item_sale',message='Need boost, selling Runecloth 5g/stack.',balanced=false,strict=false},
    {id='malformed_service_rate_goo',message='WTS leveling 5goo per level.',balanced=false,strict=false},
    {id='malformed_service_rate_glad',message='WTS leveling 5glad per level.',balanced=false,strict=false},
    {id='malformed_service_rate_gal',message='WTS leveling 5 gal per level.',balanced=false,strict=false},
    {id='valid_service_rate_g',message='WTS leveling 5g/run.',balanced=false,strict=true},
    {id='valid_service_rate_k_space_g',message='WTS leveling 5k g/run.',balanced=false,strict=true},
    {id='valid_service_rate_kg',message='WTS leveling 5kg/run.',balanced=false,strict=true},
    {id='weak_leet_unrelated_warning',message='WTS RFC boosts 5g/run! I read about mythic5tore.com in a warning.',balanced=false,strict=true,no_indicators=true},
    {id='weak_leet_before_unrelated_sale',message='I read about mythic5tore.com in a warning. WTS gold $5.',balanced=true,strict=true,no_indicators=true},
    {id='weak_leet_same_offer_control',message='WTS gold $5 at mythic5tore.com.',balanced=true,strict=true,indicator='dom_mythicstore_com'},
    {id='unrelated_guide_money_not_offer_evidence',message='WTS RFC boosts for gold. Guide at wowhead.com costs $10.',balanced=false,strict=true},
    {id='unrelated_recipe_guide_not_service_promotion',message='We offer leveling. This guide offers cheap recipes at wowhead.com.',balanced=false,strict=false},
    {id='declared_brand_sells_gold',message='Skycoach sells gold $10.',balanced=true,strict=true},
    {id='declared_brand_provides_leveling',message='Skycoach provides leveling $5.',balanced=true,strict=true},
    {id='payment_postnegated_paypal',message='WTS gold, PayPal not accepted.',balanced=false,strict=true},
    {id='payment_postnegated_paypal_auxiliary',message='WTS gold, PayPal is not accepted.',balanced=false,strict=true},
}
local function fail(group,case,profile,actual,note)
    group.failed=group.failed+1
    group.failures[#group.failures+1]={id=case.id,profile=profile,message=case.message,actual=tostring(actual),expected=tostring(case[profile]),note=note}
    print('FAIL adversarial '..case.id..' ['..profile..']: '..tostring(actual)..' expected '..tostring(case[profile])..(note and ('; '..note) or ''))
end
for _, profile in ipairs({'balanced','strict'}) do
    local e,ns=H.game('modern');e:boot()
    for index,case in ipairs(cases) do
        local cfg=ns.Rules.Defaults();cfg.mode=profile
        local ok,block,reason,detail,explanation=pcall(ns.Rules.Evaluate,case.message,cfg,{event='CHAT_MSG_CHANNEL'})
        local note
        if not ok then note=tostring(block)
        elseif type(explanation)~='table' then note='missing explanation'
        elseif case.no_indicators and #explanation.indicator_ids~=0 then note='unrelated clause supplied weak domain evidence'
        elseif case.indicator then
            local found=false
            for _,id in ipairs(explanation.indicator_ids) do if id==case.indicator then found=true end end
            if not found then note='missing same-offer indicator '..case.indicator end
        end
        report.classification.total=report.classification.total+1
        if not ok or block~=case[profile] or note then fail(report.classification,case,profile,ok and tostring(block) or 'exception',note)
        else report.classification.passed=report.classification.passed+1 end
        ns.db,e.ForeverCleanChatDB=cfg,cfg;ns.Invalidate()
        local adapterOK,adapter=pcall(e.chat,e,case.message,'Audit Seller-Realm',index)
        report.adapter.total=report.adapter.total+1
        if not adapterOK or adapter~=case[profile] then fail(report.adapter,case,profile,adapterOK and tostring(adapter) or 'exception',not adapterOK and tostring(adapter) or nil)
        else report.adapter.passed=report.adapter.passed+1 end
    end
end
report.case_count=#cases

local assertions=0
local function eq(actual,expected,label)
    assertions=assertions+1
    assert(actual==expected,(label or 'assertion')..': '..tostring(actual)..' expected '..tostring(expected))
end
local function truth(actual,label) eq(actual==true,true,label) end
local function check(id,body)
    local before=assertions
    local ok,err=pcall(body)
    report.checks[#report.checks+1]={id=id,status=ok and 'passed_mock' or 'failed',assertions=assertions-before,error=not ok and tostring(err) or nil}
    if not ok then print('FAIL adversarial '..id..': '..tostring(err)) end
end
local function fresh(saved)
    local e,ns=H.game('modern',saved);e:boot();return e,ns
end
check('local_why_pack_do_not_change_counters',function()
    local e,ns=fresh();e:chat('mythicstore.com',nil,100)
    local session,total,callback,logs=ns.sessionBlocked,ns.db.totalBlocked,ns.callbackCount,#ns.log
    e:cmd('why WTS gold $5');e:cmd('pack')
    eq(ns.sessionBlocked,session);eq(ns.db.totalBlocked,total);eq(ns.callbackCount,callback);eq(#ns.log,logs)
    truth(string.find(table.concat(e.messages,'\n'),'HIDE',1,true)~=nil,'why produced a decision')
    truth(string.find(table.concat(e.messages,'\n'),ns.Data.dataset_version,1,true)~=nil,'pack showed data version')
    eq(e.SendChatMessage,nil)
end)
check('domain_allow_keeps_independent_cash_rule',function()
    local e,ns=fresh();e:cmd('mode balanced')
    eq(e:chat('mythicstore.com',nil,1),true)
    e:cmd('domain allow mythicstore.com')
    eq(ns.db.domainAllow['mythicstore.com'],true)
    eq(e:chat('mythicstore.com',nil,2),false)
    eq(e:chat('WTS gold $5 at mythicstore.com',nil,3),true)
    local _,_,_,explanation=ns.Rules.Evaluate('WTS gold $5 at mythicstore.com',ns.db)
    eq(#explanation.indicator_ids,0,'domain-only exception removes domain evidence')
    e:cmd('domain unallow mythicstore.com');eq(e:chat('mythicstore.com',nil,4),true)
end)
for _,behavior in ipairs({'throw','false','partial'}) do
    check('modern_'..behavior..'_legacy_fallback',function()
        local e,ns=H.game('none')
        local modernCalls,legacyCalls=0,0
        e.ChatFrameUtil={AddMessageEventFilter=function(event,callback)
            modernCalls=modernCalls+1
            if behavior=='throw' then error('modern registry unavailable') end
            if behavior=='false' then return false end
            if event~='CHAT_MSG_CHANNEL' and event~='CHAT_MSG_SAY' then return false end
            e.mockAdd(event,callback)
        end}
        e.ChatFrame_AddMessageEventFilter=function(event,callback) legacyCalls=legacyCalls+1;e.mockAdd(event,callback) end
        e:boot()
        eq(ns.installed,true);eq(ns.registeredCount,5);eq(e.addCalls,5);eq(modernCalls,5)
        eq(legacyCalls,behavior=='partial' and 3 or 5)
        eq(ns.Install(),true);eq(ns.Install(),true);eq(e.addCalls,5);eq(modernCalls,5)
        eq(e:chat('mythicstore.com',nil,1),true)
        eq(ns.eventAPIs.CHAT_MSG_CHANNEL,behavior=='partial' and 'ChatFrameUtil' or 'ChatFrame_AddMessageEventFilter')
        eq(ns.eventAPIs.CHAT_MSG_WHISPER,'ChatFrame_AddMessageEventFilter')
    end)
end
check('false_registry_without_fallback_is_unsupported',function()
    local e,ns=H.game('none')
    e.ChatFrameUtil={AddMessageEventFilter=function() return false end}
    e:boot()
    eq(ns.installed,false);eq(ns.registeredCount,0);eq(e.addCalls,0);eq(#e.messages,1)
    eq(next(ns.registeredEvents),nil);eq(next(ns.apiObservedEvents),nil)
end)
check('schema2_reload_preserves_exclusions_backup_review',function()
    local saved={schema=1,enabled=true,mode='balanced',totalBlocked=73,
        domains={mythicstorecom='mythicstore.com',customcom='custom.com',unusable=42},
        phrases={['custom phrase']=true},allow={['trusted player-realm']=true},block={['blocked player-realm']=true}}
    local e,ns=fresh(saved)
    e:cmd('domain remove skycoach.gg');e:cmd('domain allow mythicstore.com')
    eq(ns.db.migrationBackup.domains.unusable,42);eq(ns.db.migrationBackup.domains.customcom,'custom.com')
    eq(ns.db.domainDisabled['skycoach.gg'],true);eq(ns.db.domainAllow['mythicstore.com'],true)
    eq(#ns.db.legacyReview,1)
    local re,rns=fresh(H.copy(ns.db))
    eq(rns.db.schema,2);eq(rns.db.mode,'balanced');eq(rns.db.enabled,true);eq(rns.db.totalBlocked,73)
    eq(rns.db.domains['custom.com'],'custom.com');eq(rns.db.domainDisabled['skycoach.gg'],true)
    eq(rns.db.domainAllow['mythicstore.com'],true);eq(#rns.db.legacyReview,1)
    eq(rns.db.legacyReview[1].field,'domains');eq(rns.db.legacyReview[1].key,'unusable');eq(rns.db.legacyReview[1].value,42)
    eq(rns.db.migrationBackup.domains.unusable,42);eq(rns.db.migrationBackup.domains.customcom,'custom.com')
    eq(re:chat('skycoach.gg',nil,1),false);eq(re:chat('mythicstore.com',nil,2),false)
    eq(re:chat('custom.com',nil,3),true);eq(rns.sessionErrors,0)
end)
check('legacy_removed_builtin_survives_pack_reload',function()
    local e,ns=fresh({schema=1,mode='balanced',enabled=true,totalBlocked=21,domains={},phrases={},allow={},block={}})
    eq(ns.db.domainDisabled['mythicstore.com'],true)
    eq(e:chat('mythicstore.com',nil,1),false);eq(e:chat('skycoach.gg',nil,2),true)
    local total=ns.db.totalBlocked
    local re,rns=fresh(H.copy(ns.db))
    eq(rns.db.domainDisabled['mythicstore.com'],true);eq(rns.db.totalBlocked,total)
    eq(next(rns.db.migrationBackup.domains),nil)
    eq(re:chat('mythicstore.com',nil,3),false);eq(re:chat('skycoach.gg',nil,4),true)
end)
check('normalization_structural_offsets_and_scope',function()
    local e,ns=fresh();local N=ns.Normalize
    local n=N.Message('Only. PayPal is not accepted.')
    eq(n.domain_candidates[1].host,'only.paypal');eq(n.domain_candidates[1].external_eligible,false)
    n=N.Message('new-store dot example');eq(n.domain_candidates[1].host,'new-store.example');eq(n.domain_candidates[1].external_eligible,true)
    n=N.Message('?!!Buy gold!?!WTS boost');eq(#n.clauses,2)
    n=N.Message('WTS gold 12€');eq(n.clauses[1].text,'wts gold 12€')
    n=N.Message('https://mythicstоre.com/x')
    local matches=N.MatchDomains(n,ns.Data.domains,false)
    eq(#matches,1);eq(matches[1].value,'mythicstore.com');eq(matches[1].kind,'obfuscated');eq(matches[1].transform,'confusable')
    eq(matches[1].raw_start,9);eq(matches[1].raw_finish,24)
    local custom={{id='custom',value='a.boost.com'}}
    eq(#N.MatchDomains(N.Message('x.b00st.com'),custom,true),0)
    eq(#N.MatchDomains(N.Message('a.b00st.com'),custom,true),1)
    eq(#N.MatchDomains(N.Message('G2G.COM'),ns.Data.domains,true),1)
    eq(#N.MatchDomains(N.Message('mythicstore.c0m'),ns.Data.domains,true),0)
    for _,message in ipairs({'mythicstore.com..example','example..mythicstore.com','mythicstore.com@help.example/',
        '(https://example.org/path/mythicstore.com?ref=skycoach.gg)'}) do
        eq(#N.MatchDomains(N.Message(message),ns.Data.domains,true),0,'invalid/userinfo/path host isolation')
    end
    n=N.Message('(https://example.org/path/mythicstore.com?ref=skycoach.gg)')
    eq(#n.domain_candidates,1);eq(n.domain_candidates[1].host,'example.org')
    eq(#N.MatchDomains(N.Message('mythicstore.com...'),ns.Data.domains,false),1)
    eq(N.Message(string.rep('a',129)..'.com').valid,false,'candidate codepoint budget')
end)
check('normalization_uses_generated_work_and_leet_limits',function()
    local e,ns=fresh()
    ns.Data.normalization.max_domain_candidates=1
    H.chunk(root..'/Normalize.lua',e)('ForeverCleanChat',ns)
    eq(ns.Normalize.Message('one.example two.example').valid,false,'generated candidate limit')
    local le,lns=fresh()
    lns.Data.normalization.domain_transforms.leet_max_substitutions=0
    H.chunk(root..'/Normalize.lua',le)('ForeverCleanChat',lns)
    eq(#lns.Normalize.MatchDomains(lns.Normalize.Message('myth1cstore.com'),lns.Data.domains,true),0,'generated leet limit')
end)
report.engineering_assertions=assertions
local failed=report.classification.failed+report.adapter.failed
for _,row in ipairs(report.checks) do if row.status=='failed' then failed=failed+1 end end
report.failed=failed
print('Runtime: '.._VERSION)
print('Independent adversarial classifier/profile checks: '..report.classification.passed..'/'..report.classification.total)
print('Independent adversarial mock callback/profile checks: '..report.adapter.passed..'/'..report.adapter.total)
print('Independent adversarial engineering assertions: '..assertions..'; '..#report.checks..' groups; '..failed..' failures')
FCC_ADVERSARIAL_RESULT=report
if failed>0 then error('Adversarial test suite failed') end
