-- Pure, data-driven classifier. No game APIs, network, or executable data.
local _, NS = ...
local N, D, R = NS.Normalize, NS.Data, {}
NS.Rules = R
local scope = {CHAT_MSG_CHANNEL=true,CHAT_MSG_SAY=true,CHAT_MSG_YELL=true,
    CHAT_MSG_WHISPER=true,CHAT_MSG_EMOTE=true}
local lexiconIndex, brandTerms
local budgets=D.normalization.semantic_rules
local CLAUSE_TOKENS=budgets.clause_scope_max_content_tokens
local OBJECT_DISTANCE=budgets.offer_object_max_token_distance
local NEGATION_DISTANCE=5
local LINK_CLAUSES=budgets.ad_segment_linking.max_adjacent_clauses
local LINK_TOKENS=budgets.ad_segment_linking.max_total_content_tokens
local serviceFamilies = {'service_leveling','service_dungeon','service_raid',
    'service_gearing','service_professions','service_pvp','service_collections'}
local promotionFamilies = {'promotion_price','promotion_delivery','promotion_trust',
    'promotion_convenience','promotion_urgency'}

function R.Defaults()
    return {schema=2,enabled=true,mode=D.profiles.default_new_install or 'strict',
        known_domain_mention_policy='hide_all',totalBlocked=0,
        domains={},domainDisabled={},domainAllow={},phrases={},allow={},block={},legacyReview={}}
end

local function words(text)
    local out = {}
    for word in string.gmatch(N.Text(text) or '', '%S+') do out[#out+1] = word end
    return out
end

local function prepare()
    if lexiconIndex then return end
    lexiconIndex, brandTerms = {}, {}
    for _, family in ipairs(D.lexicons) do
        local seen = {}
        for _, terms in pairs(family.terms_by_language) do
            for _, term in ipairs(terms) do
                local tokens = words(term)
                local signature = table.concat(tokens, ' ')
                if #tokens > 0 and not seen[signature] then
                    seen[signature] = true
                    local first = tokens[1]
                    lexiconIndex[first] = lexiconIndex[first] or {}
                    local bucket = lexiconIndex[first]
                    bucket[#bucket+1] = {family=family.id,tokens=tokens}
                end
            end
        end
    end
    for _, vendor in ipairs(D.vendors) do
        for _, term in ipairs(vendor.generated_text_aliases or {}) do
            brandTerms[#brandTerms+1] = {id=vendor.id,tokens=words(term)}
        end
    end
end

local function sameTokens(tokens, first, phrase)
    if #phrase == 0 or first+#phrase-1 > #tokens then return false end
    for j = 1, #phrase do
        if tokens[first+j-1].text ~= phrase[j] then return false end
    end
    return true
end

local function spans(n)
    prepare()
    local result = {}
    for i, token in ipairs(n.tokens) do
        for _, term in ipairs(lexiconIndex[token.text] or {}) do
            if sameTokens(n.tokens,i,term.tokens) then
                local last = i+#term.tokens-1
                if n.tokens[last].clause == token.clause then
                    result[term.family] = result[term.family] or {}
                    local bucket = result[term.family]
                    bucket[#bucket+1] = {first=i,last=last,clause=token.clause}
                end
            end
        end
    end
    for _, brand in ipairs(brandTerms) do
        for i = 1, #n.tokens do
            if sameTokens(n.tokens,i,brand.tokens) then
                result.known_brand_alias = result.known_brand_alias or {}
                local bucket = result.known_brand_alias
                bucket[#bucket+1] = {first=i,last=i+#brand.tokens-1,id=brand.id}
            end
        end
    end
    return result
end

local function within(list, first, last)
    local out = {}
    for _, hit in ipairs(list or {}) do
        if hit.first >= first and hit.last <= last then out[#out+1] = hit end
    end
    return out
end
local function overlaps(a,b) return a.first <= b.last and b.first <= a.last end
local function distance(a,b)
    return math.max(0, math.max(a.first,b.first)-math.min(a.last,b.last)-1)
end
local function anyHits(all, family, first, last)
    return #within(all[family],first,last) > 0
end

local function validAmount(value)
    local integer, fraction = string.match(value, '^(%d+)[%.,]?(%d*)$')
    return integer and #integer <= 9 and #fraction <= 2 and tonumber((string.gsub(value,',','.'))) > 0
end
local function amountNear(text, marker)
    local start = 1
    while true do
        local a,b = string.find(text,marker,start,true)
        if not a then return false end
        local before, after = string.sub(text,1,a-1),string.sub(text,b+1)
        local la,lb,left = string.find(before,'(%d+[%.,]?%d*)%s?$')
        local ra,rb,right = string.find(after,'^%s?(%d+[%.,]?%d*)')
        local unit=string.match(marker,'^[a-z]+$')~=nil
        local function bad(c) return c~='' and string.find(c,'[a-z0-9%.,]')~=nil end
        if left and validAmount(left) and not bad(string.sub(before,la-1,la-1))
            and not (unit and string.find(string.sub(after,1,1),'[a-z0-9]')) then return true end
        if right and validAmount(right) and not bad(string.sub(after,rb+1,rb+1))
            and not (unit and string.find(string.sub(before,-1),'[a-z0-9]')) then return true end
        start = b+1
    end
end
local function money(text, payment, offered)
    for symbol in pairs(D.numeric_parsers.real_money_symbols) do
        if amountNear(text,symbol) then return true end
    end
    for _, unit in ipairs(D.numeric_parsers.real_money_units) do
        if amountNear(text,unit) then return true end
    end
    return offered and payment
end
local function rate(text)
    for _, unit in ipairs({'g','gold'}) do
        for _, divider in ipairs({'%s*/%s*','%s+per%s+'}) do
            local pattern='(%d+[%.,]?%d*)%s*k?%s*'..unit..divider..'(%a+)'
            local start=1
            while true do
                local a,b,amount,label=string.find(text,pattern,start)
                if not a then break end
                if validAmount(amount) and not string.find(string.sub(text,a-1,a-1),'[a-z0-9%.,]')
                    and not string.find(string.sub(text,b+1,b+1),'[a-z0-9]') then
                    for _, alias in ipairs(D.numeric_parsers.rate_unit_aliases) do if label==alias then return true end end
                end
                start=b+1
            end
        end
    end
    return false
end

local function features(n, all, first, last)
    local f = {}
    local firstClause,lastClause=n.clauses[n.tokens[first].clause],n.clauses[n.tokens[last].clause]
    local start=n.tokens[first].start
    local finish=n.tokens[last].finish
    if firstClause and first==firstClause.first then start=firstClause.start end
    if lastClause and last==lastClause.last then finish=lastClause.finish end
    local text = string.sub(n.semantic_text,start,finish)
    local buyer = within(all.buyer_question,first,last)
    local warnings = within(all.negation_warning,first,last)
    local reporting = string.find(text,'report this spam',1,true) or string.find(text,'someone posted',1,true)
    local contrasts={but=true,however=true,instead=true,ama=true,aber=true,mais=true,pero=true,['но']=true}
    local personal={i=true,will=true,can=true,could=true,would=true,to=true,want=true,need=true,might=true}
    local function guarded(hit)
        if n.tokens[hit.first].text=='buy' or n.tokens[hit.first].text=='order' or n.tokens[hit.first].text=='book' then
            if hit.first>first and personal[n.tokens[hit.first-1].text] then return true end
        end
        for _, b in ipairs(buyer) do
            if n.tokens[b.first].clause==n.tokens[hit.first].clause and distance(b,hit)<=OBJECT_DISTANCE then
                local separate=false
                if b.last<hit.first then
                    for k=b.last+1,hit.first do if contrasts[n.tokens[k].text] then separate=true end end
                    for _, positive in ipairs(within(all.seller_offer,b.last+1,hit.last)) do
                        local token=n.tokens[positive.first].text
                        if token=='wts' or token=='we' or token=='our' then separate=true end
                    end
                end
                if not separate then return true end
            end
        end
        for _, warning in ipairs(warnings) do
            if n.tokens[warning.first].clause == n.tokens[hit.first].clause
                and warning.first <= hit.last and distance(warning,hit) <= NEGATION_DISTANCE then return true end
        end
        return reporting ~= nil
    end
    local seller, cta = {}, {}
    for _, hit in ipairs(within(all.seller_offer,first,last)) do
        if not guarded(hit) then seller[#seller+1] = hit end
    end
    for _, hit in ipairs(within(all.merchant_cta,first,last)) do
        if not guarded(hit) then cta[#cta+1] = hit end
    end
    for _, template in ipairs(D.lexical_templates) do
        if template.id == 'cta_buy_object' then
            local verbs, modifiers = {}, {}
            for _, value in ipairs(template.verb_tokens) do verbs[value] = true end
            for _, value in ipairs(template.allowed_intervening_tokens) do modifiers[value] = true end
            for i = first,last do
                local token = n.tokens[i]
                if verbs[token.text] then
                    local hit = {first=i,last=i}
                    local previous = i>first and n.tokens[i-1].text or ''
                    local personal = previous == 'will' or previous == 'to' or previous == 'i' or previous == 'can'
                    if not personal and not guarded(hit) then
                        for j = i+1,math.min(last,i+template.max_intervening_tokens+1) do
                            local found = false
                            for _, family in ipairs(template.object_lexicon_refs) do
                                for _, object in ipairs(within(all[family],j,last)) do
                                    if object.first == j then found = true; break end
                                end
                                if found then break end
                            end
                            if found then cta[#cta+1] = hit; break end
                            if not modifiers[n.tokens[j].text] then break end
                        end
                    end
                end
            end
        elseif template.id=='brand_offers_object' then
            for _, brand in ipairs(within(all.known_brand_alias,first,last)) do
                local verb=brand.last+1
                local token=n.tokens[verb]
                if token and (token.text=='offers' or token.text=='provides' or token.text=='sells') then
                    local hit={first=verb,last=verb,maximum_distance=4}
                    if not guarded(hit) then seller[#seller+1]=hit end
                end
            end
        end
    end
    f.seller_intent, f.merchant_cta = #seller>0,#cta>0
    local intents = {}
    for _, hit in ipairs(seller) do intents[#intents+1] = hit end
    for _, hit in ipairs(cta) do intents[#intents+1] = hit end
    local ordinary = within(all.ordinary_trade,first,last)
    local unrelated = within(all.unrelated_boost,first,last)
    local function freeObject(object)
        for k=math.max(first,object.first-2),object.first-1 do
            if n.tokens[k].text=='free' then
                local between=string.sub(n.semantic_text,n.tokens[k].finish+1,n.tokens[object.first].start-1)
                if not string.find(between,'[,;!?]') then return true end
            end
        end
        for _, help in ipairs(within(all.free_help,first,last)) do
            if overlaps(help,object) then return true end
            if help.first>object.last and distance(help,object)<=8
                and n.tokens[help.first].clause==n.tokens[object.first].clause then
                local separate=false
                for _, intent in ipairs(within(all.seller_offer,object.last+1,help.first)) do separate=true end
                for _, other in ipairs(within(all.boost_explicit,object.last+1,help.first)) do separate=true end
                for _, other in ipairs(within(all.boost_explicit,help.first,help.last)) do
                    if not overlaps(other,object) then separate=true end
                end
                if not separate then return true end
            end
        end
        if object.last+2<=last and n.tokens[object.last+1].text=='for' and n.tokens[object.last+2].text=='free' then return true end
        return false
    end
    local modifiers={our=true,your=true,the=true,a=true,an=true,cheap=true,cheapest=true,discounted=true,
        wow=true,classic=true,forever=true,retail=true,fast=true,heroic=true,mythic=true,professional=true,
        services=true,service=true,['and']=true,['or']=true,runs=true,through=true,['for']=true,of=true}
    local objectFamilies={'gold_commodity','boost_explicit','account_trade'}
    for _, family in ipairs(serviceFamilies) do objectFamilies[#objectFamilies+1]=family end
    local function firstObject(intent)
        for k=intent.last+1,math.min(last,intent.last+OBJECT_DISTANCE) do
            for _, family in ipairs(objectFamilies) do
                for _, target in ipairs(within(all[family],k,last)) do
                    if target.first==k then return target end
                end
            end
            if not modifiers[n.tokens[k].text] and not string.match(n.tokens[k].text,'^%d') then return nil end
        end
    end
    local function linked(object,commodity)
        for j=object.first,object.last do if n.tokens[j].item then return false end end
        if guarded(object) then return false end
        for _, normal in ipairs(ordinary) do
            if overlaps(normal,object) then return false end
        end
        if commodity then
            local before=object.first>first and n.tokens[object.first-1].text or ''
            local after=object.last<last and n.tokens[object.last+1].text or ''
            if before=='no' or after=='needed' or after=='required' then return false end
        end
        for _, intent in ipairs(intents) do
            if distance(intent,object) <= (intent.maximum_distance or OBJECT_DISTANCE) then
                local ordinaryObject = false
                for _, normal in ipairs(ordinary) do
                    if normal.first > intent.last and normal.first < object.first then ordinaryObject=true end
                end
                if not ordinaryObject then
                    if object.first>=intent.first then
                        local direct=firstObject(intent)
                        if overlaps(intent,object) then direct=object end
                        if direct and direct.first<=object.first then
                            local joined=true
                            for k=direct.last+1,object.first-1 do
                                local token=n.tokens[k].text
                                if contrasts[token] or token=='while' or token=='farming' or token=='guide'
                                    or token=='i' or token=='need' then joined=false end
                            end
                            if commodity and direct.first<object.first then
                                for _, family in ipairs(serviceFamilies) do
                                    if anyHits(all,family,direct.first,object.first-1) then joined=false end
                                end
                                if anyHits(all,'boost_explicit',direct.first,object.first-1) then joined=false end
                            end
                            if joined then return true end
                        end
                    elseif distance(intent,object)<=4 and n.tokens[object.first].clause==n.tokens[intent.first].clause then
                        local between=string.sub(n.semantic_text,n.tokens[object.last].finish+1,n.tokens[intent.first].start-1)
                        if not string.find(between,'[,;!?]') then return true end
                    elseif n.tokens[object.first].clause<n.tokens[intent.first].clause and #cta>0 then
                        -- A bounded catalogue can precede its explicit order CTA.
                        local families=0
                        for _, family in ipairs(serviceFamilies) do
                            if anyHits(all,family,first,intent.first) then families=families+1 end
                        end
                        if families>=2 then return true end
                    end
                end
            end
        end
        return false
    end
    local familyCount,paidObject = 0,false
    for _, family in ipairs(serviceFamilies) do
        local offered = false
        for _, object in ipairs(within(all[family],first,last)) do
            if linked(object) then
                offered=true
                if not freeObject(object) then paidObject=true end
            end
        end
        if offered then familyCount=familyCount+1 end
    end
    f.offered_game_service = familyCount>0
    local numericRate = rate(text)
    f.offered_boost = false
    for _, object in ipairs(within(all.boost_explicit,first,last)) do
        local unrelatedObject = false
        for _, other in ipairs(unrelated) do if overlaps(other,object) then unrelatedObject=true end end
        if not unrelatedObject and (linked(object) or (numericRate and #buyer==0 and not guarded(object))) then
            f.offered_boost = true
            if not freeObject(object) then paidObject=true end
        end
    end
    f.gold_commodity_offer = false
    for _, object in ipairs(within(all.gold_commodity,first,last)) do
        if linked(object,true) then f.gold_commodity_offer=true end
    end
    f.wow_account_offer = false
    for _, object in ipairs(within(all.account_trade,first,last)) do
        if linked(object) then f.wow_account_offer=true end
    end
    local offered = f.gold_commodity_offer or f.offered_boost or f.offered_game_service or f.wow_account_offer
    local payment=false
    local negativePayment={no=true,['not']=true,without=true,kein=true,nicht=true,pas=true,sin=true,['без']=true,['не']=true}
    for _, hit in ipairs(within(all.real_money,first,last)) do
        local value=table.concat((function()
            local out={} for i=hit.first,hit.last do out[#out+1]=n.tokens[i].text end return out
        end)(),' ')
        local currencyOnly=false
        for _, unit in ipairs(D.numeric_parsers.real_money_units) do if value==unit then currencyOnly=true end end
        if value=='руб' or value=='рублей' then currencyOnly=true end
        local negated=false
        for k=math.max(first,hit.first-3),hit.first-1 do
            if negativePayment[n.tokens[k].text] then negated=true end
        end
        local nextWord=hit.last<last and n.tokens[hit.last+1].text or ''
        local following=hit.last+1<last and n.tokens[hit.last+2].text or ''
        if nextWord=='not' or ((nextWord=='is' or nextWord=='are' or nextWord=='was') and following=='not') then negated=true end
        if not currencyOnly and not negated and not guarded(hit) then payment=true end
    end
    f.money_anchor = money(text,payment,offered) and offered or false
    f.service_rate = numericRate and (f.offered_boost or f.offered_game_service) or false
    local promotionCount = 0
    for _, family in ipairs(promotionFamilies) do
        if anyHits(all,family,first,last) and offered then promotionCount=promotionCount+1 end
    end
    f.promotion_evidence = promotionCount>0
    f.distinct_promotion_families = promotionCount
    f.distinct_offered_service_families = familyCount
    f.preorder_hook = anyHits(all,'promotion_urgency',first,last) and offered and f.merchant_cta or false
    f.buyer_request_only = #buyer>0 and not offered
    f.clear_local_warning = #warnings>0 and not offered or reporting ~= nil
    local free=anyHits(all,'free_help',first,last) or ((f.offered_boost or f.offered_game_service) and not paidObject)
    f.free_help_only = free and not paidObject and not numericRate and not f.money_anchor
        and not f.gold_commodity_offer and not f.wow_account_offer
    if f.free_help_only then f.offered_boost=false; f.offered_game_service=false end
    f.known_brand_alias = anyHits(all,'known_brand_alias',first,last)
    f.external_destination = false
    for _, candidate in ipairs(n.domain_candidates or {}) do
        local candidateClause = candidate.clause
        if candidate.external_eligible~=false and (not candidateClause or (candidateClause>=n.tokens[first].clause and candidateClause<=n.tokens[last].clause)) then
            f.external_destination = true
        end
    end
    return f
end

local function segments(n, all)
    local out = {}
    for _, clause in ipairs(n.clauses) do
        if clause.first and clause.last and clause.last>=clause.first then
            local first=clause.first
            while first<=clause.last do
                local last=math.min(clause.last,first+CLAUSE_TOKENS-1)
                out[#out+1]={first=first,last=last,features=features(n,all,first,last)}
                first=last+1
            end
        end
    end
    local singleCount=#out
    for i=1,singleCount do
        local base=out[i]
        local bf=base.features
        local catalogue=false
        for _, family in ipairs(serviceFamilies) do
            if anyHits(all,family,base.first,base.last) then catalogue=true end
        end
        if bf.seller_intent or bf.merchant_cta or bf.offered_boost or bf.offered_game_service or catalogue then
            for j=i+1,math.min(singleCount,i+LINK_CLAUSES-1) do
                local nextSegment=out[j]
                local nf=nextSegment.features
                local text=string.sub(n.semantic_text,n.tokens[nextSegment.first].start,n.tokens[nextSegment.last].finish)
                -- Continue an offer only from a leading CTA/promotion/contact,
                -- not from a website or price mentioned in an unrelated sentence.
                local leadingPromotion=false
                for _, family in ipairs(promotionFamilies) do
                    for _, hit in ipairs(within(all[family],nextSegment.first,nextSegment.last)) do
                        if hit.first<=nextSegment.first+1 then leadingPromotion=true end
                    end
                end
                local leadingContact=false
                for _, hit in ipairs(within(all.external_contact_cue,nextSegment.first,nextSegment.last)) do
                    if hit.first==nextSegment.first then leadingContact=true end
                end
                local head=n.tokens[nextSegment.first].text
                if head=='visit' or head=='at' or head=='contact' or head=='order' then leadingContact=true end
                local continuation = nf.merchant_cta or leadingPromotion
                    or (nf.external_destination and leadingContact)
                if not continuation or string.find(text,'^i ') or string.find(text,'^my ')
                    or string.find(text,'^our guild') or string.find(text,'^someone ') then break end
                if nextSegment.last-base.first+1>LINK_TOKENS then break end
                out[#out+1]={first=base.first,last=nextSegment.last,
                    features=features(n,all,base.first,nextSegment.last)}
            end
        end
    end
    return out
end

local function eval(node, f)
    if node.feature then return f[node.feature] == true end
    if node.metric then return (f[node.metric] or 0) >= node.gte end
    if node['not'] then return not eval(node['not'],f) end
    if node.all then
        for _, child in ipairs(node.all) do if not eval(child,f) then return false end end
        return true
    end
    if node.any then
        for _, child in ipairs(node.any) do if eval(child,f) then return true end end
    end
    return false
end
R.EvaluateCondition = eval

local function result(block, reason, rule, matches, f, detail, extra)
    local ids, seen = {}, {}
    for _, match in ipairs(matches or {}) do
        if not seen[match.id] then ids[#ids+1]=match.id; seen[match.id]=true end
    end
    table.sort(ids)
    local explanation = {rule_id=rule,reason=reason,indicator_ids=ids,domain_matches=matches or {},features=f or {}}
    if extra then for key,value in pairs(extra) do explanation[key]=value end end
    return block,reason,detail,explanation
end

function R.Evaluate(message, cfg, context)
    cfg, context = cfg or R.Defaults(),context or {}
    if cfg.enabled==false then return result(false,'disabled') end
    if context.event and not scope[context.event] then return result(false,'out_of_scope') end
    if context.event and cfg.chatEvents and cfg.chatEvents[context.event] == false then return result(false,'event_disabled') end
    if type(message)~='string' then return result(false,'unreadable') end
    local n=N.Message(message)
    if not n.valid then return result(false,n.reason or 'invalid_input') end
    if context.is_self_guid or context.verified_gm_flag then return result(false,'verified_identity') end
    if context.sender_on_manual_allowlist then
        return result(false,'manual_allow',nil,nil,nil,nil,{allow_block_conflict=context.sender_on_manual_blocklist==true})
    end
    if context.sender_on_manual_blocklist then return result(true,'manual-player','USER_PLAYER') end
    for phrase in pairs(cfg.phrases or {}) do
        if type(phrase)=='string' then
            local phraseTokens=words(phrase)
            for i=1,#n.tokens do
                if sameTokens(n.tokens,i,phraseTokens) then return result(true,'user_defined','USER_PHRASE',nil,nil,phrase) end
            end
        end
    end
    local all=spans(n)
    local offers=segments(n,all)
    local commercial,commercialClauses=false,{}
    for _, offer in ipairs(offers) do
        local f=offer.features
        if (f.seller_intent or f.merchant_cta) and (f.gold_commodity_offer or f.offered_boost or f.offered_game_service or f.wow_account_offer) then
            commercial=true
            for clause=n.tokens[offer.first].clause,n.tokens[offer.last].clause do commercialClauses[clause]=true end
        end
    end
    local excluded={}
    for host in pairs(cfg.domainDisabled or {}) do excluded[host]=true end
    for host in pairs(cfg.domainAllow or {}) do excluded[host]=true end
    local matches=N.MatchDomains(n,D.domains,commercial,excluded)
    local custom={}
    for host,label in pairs(cfg.domains or {}) do
        local canonical=N.Domain(type(label)=='string' and label or host)
        if canonical then custom[#custom+1]={id='user_domain:'..canonical,value=canonical,include_subdomains=true} end
    end
    for _, match in ipairs(N.MatchDomains(n,custom,commercial,cfg.domainAllow or {})) do matches[#matches+1]=match end
    for i=#matches,1,-1 do
        if matches[i].transform=='leet' and not commercialClauses[matches[i].clause] then table.remove(matches,i) end
    end
    local policy=cfg.known_domain_mention_policy or 'hide_all'
    for _, offer in ipairs(offers) do
        local f=offer.features
        f.known_domain_exact,f.known_domain_obfuscated=false,false
        for _, match in ipairs(matches) do
            if not match.clause or (match.clause>=n.tokens[offer.first].clause and match.clause<=n.tokens[offer.last].clause) then
                if match.kind=='exact' then f.known_domain_exact=true else f.known_domain_obfuscated=true end
                f.external_destination=true
            end
        end
    end
    if policy=='hide_all' and #matches>0 then
        local exact=false
        for _, match in ipairs(matches) do if match.kind=='exact' then exact=true end end
        local reason=exact and 'known_seller_domain' or 'known_seller_domain_obfuscated'
        return result(true,reason,exact and 'R001_KNOWN_HOST' or 'R002_OBFUSCATED_HOST',matches,nil,matches[1].value)
    end
    for _, rule in ipairs(D.decision_rules) do
        local profile=false
        for _, mode in ipairs(rule.profiles) do if mode==(cfg.mode or 'strict') then profile=true end end
        if rule.enabled and profile and rule.action=='block' then
            for _, offer in ipairs(offers) do
                local f=offer.features
                local domainRule=rule.id=='R001_KNOWN_HOST' or rule.id=='R002_OBFUSCATED_HOST'
                local eligible=not domainRule or policy~='contextual' or eval(D.profiles.known_domain_policy_options.contextual_gate,f)
                if eligible and eval(rule.when,f) then
                    return result(true,rule.reason_code,rule.id,matches,f,matches[1] and matches[1].value)
                end
            end
        end
    end
    return result(false,'allowed',nil,matches,offers[1] and offers[1].features)
end

R.SelfTests = {
    {true,'mythicstore.com'}, {true,'skycoach.gg'}, {true,'MythicStore [dot] com'},
    {true,'ＭｙｔｈｉｃＳｔｏｒｅ．ｃｏｍ'}, {true,'WTS gold $10'},
    {true,'We offer leveling, dungeons, gearing and professions! Order for beta.'},
    {false,'LFM Wailing Caverns, need healer'}, {false,'WTS Copper Bar 2g per stack'},
    {false,'Anyone leveling professions while doing dungeons?'}, {false,'Free boost for guildmates, no gold required.'},
    {false,'WTS RFC boosts 5g/run'}, {false,'Our guild does dungeons. Join discord.gg/example'},
}
function R.RunSelfTests()
    local cfg,passed=R.Defaults(),0
    cfg.mode='balanced'
    for _, case in ipairs(R.SelfTests) do if R.Evaluate(case[2],cfg)==case[1] then passed=passed+1 end end
    return passed,#R.SelfTests
end
