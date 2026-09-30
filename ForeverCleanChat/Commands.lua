local _, NS = ...
local N, R = NS.Normalize, NS.Rules
local reasonLabels = {
    domain='Blocked domain', phrase='Custom phrase', ['service-catalogue']='Commercial service catalogue',
    ['commercial-services']='Services + sales + website/real money', ['gold-advertisement']='Gold advertisement',
    ['strict-boost-sale']='Strict: boost/carry sale', ['manual-player']='Manually blocked player',
}
for _, rule in ipairs(NS.Data.decision_rules) do reasonLabels[rule.reason_code]=rule.reason_code end
reasonLabels.user_defined='Custom phrase'

local function status()
    local db = NS.db
    NS.Print('v' .. NS.VERSION .. ' | ' .. (db.enabled and 'ON' or 'OFF') .. ' | mode: ' .. db.mode
        .. ' | API: ' .. (NS.api or 'NOT FOUND') .. ' | events: ' .. (NS.registeredCount or 0) .. '/' .. #NS.Events)
    NS.Print('Hidden: ' .. NS.sessionBlocked .. ' this session, ' .. db.totalBlocked .. ' total. Errors: ' .. NS.sessionErrors)
    local observed=0
    for _ in pairs(NS.apiObservedEvents) do observed=observed+1 end
    NS.Print('Policy: '..db.known_domain_mention_policy..' | callbacks observed: '..observed..'/'..#NS.Events
        ..' | registration is not live compatibility verification.')
    if #db.legacyReview>0 then NS.Print('Legacy entries awaiting review: '..#db.legacyReview..' (/fcc list)') end
    if NS.allowBlockConflicts>0 then NS.Print('Allow/block conflicts observed: '..NS.allowBlockConflicts..' (allow wins)') end
end
local function help()
    NS.Print('/fcc opens the control panel | /fcc settings | /fcc close | /fcc minimap show/hide/reset')
    NS.Print('/fcc status | on | off | mode balanced | mode strict | test | log [1-20]')
    NS.Print('/fcc domain add/remove example.com | /fcc word add/remove phrase | /fcc list')
    NS.Print('/fcc allow/unallow Player Name-Realm | block/unblock Player Name-Realm')
    NS.Print('/fcc why local sample | pack | domainpolicy hide_all/contextual')
    NS.Print('/fcc domain allow/unallow example.com (domain-rule exception only)')
end
local function listing()
    NS.Print('Builtin domains: '..#NS.Data.domains..' (/fcc pack)')
    for _, field in ipairs({'domains','domainDisabled','domainAllow','phrases','allow','block'}) do
        local entries = {}
        for key, value in pairs(NS.db[field]) do entries[#entries + 1] = type(value) == 'string' and value or key end
        table.sort(entries)
        NS.Print(field .. ': ' .. (#entries > 0 and N.SafeDisplay(table.concat(entries, ', ')) or '(none)'))
    end
    for _, row in ipairs(NS.db.legacyReview) do
        local function valueText(value)
            local kind=type(value)
            if kind=='string' then return N.SafeDisplay(value) end
            if kind=='number' or kind=='boolean' then return tostring(value) end
            return '('..kind..')'
        end
        NS.Print('REVIEW '..valueText(row.field)..' ['..valueText(row.key)..']: '..valueText(row.value))
    end
end
local function showLog(n)
    n = math.max(1, math.min(20, math.floor(tonumber(n) or 5)))
    if #NS.log == 0 then NS.Print('No messages hidden this session.'); return end
    for i = math.max(1, #NS.log - n + 1), #NS.log do
        local row = NS.log[i]
        NS.Print(N.SafeDisplay(row.author) .. ' | ' .. (reasonLabels[row.reason] or row.reason)
            .. (row.rule_id and (' | '..N.SafeDisplay(row.rule_id)) or '')
            .. (row.detail and (' [' .. N.SafeDisplay(row.detail) .. ']') or ''))
        NS.Print(N.SafeDisplay(row.message))
    end
end
local function editTextList(which, rest)
    local action, value = string.match(rest, '^(%S+)%s+(.+)$')
    action = action and string.lower(action)
    if not action or (action ~= 'add' and action ~= 'remove' and not (which=='domain' and (action=='allow' or action=='unallow'))) then
        NS.Print('Usage: /fcc ' .. which .. ' add/remove ' .. (which == 'domain' and 'example.com' or 'phrase'))
        return
    end
    local exception = which == 'domain' and (action == 'allow' or action == 'unallow')
    local listKind = exception and 'domainAllow' or (which == 'word' and 'phrase' or which)
    local editAction = exception and (action == 'allow' and 'add' or 'remove') or action
    local ok, label = NS.Settings.EditList(listKind, editAction, value)
    if not ok then NS.Print(label); return end
    if exception then NS.Print('Domain-only exception '..action..': '..N.SafeDisplay(label)); return end
    NS.Print((action == 'add' and 'Added: ' or 'Removed: ') .. N.SafeDisplay(label))
end

local function pack()
    NS.Print('Offline pack '..NS.Data.dataset_version..' | '..#NS.Data.domains..' domains | '..#NS.Data.lexicons..' lexicons')
    NS.Print('Dataset: '..NS.Data.dataset_id..' | schema: '..NS.Data.schema_version)
    NS.Print('Source evidence is not sender attribution. No remote updates. /fcc list shows user overrides.')
end
local function why(sample)
    if sample=='' then NS.Print('Usage: /fcc why local sample (no chat sent)');return end
    local ok,block,reason,detail,explanation=pcall(R.Evaluate,sample,NS.db,{event='CHAT_MSG_CHANNEL'})
    if not ok then NS.Print('Local classification failed; sample left visible.');return end
    NS.Print((block and 'HIDE' or 'ALLOW')..' | '..N.SafeDisplay(reason)
        ..(explanation.rule_id and (' | '..N.SafeDisplay(explanation.rule_id)) or ''))
    if #explanation.indicator_ids>0 then NS.Print('Indicators: '..N.SafeDisplay(table.concat(explanation.indicator_ids,', '))) end
    for _, match in ipairs(explanation.domain_matches) do
        NS.Print(N.SafeDisplay(match.value)..' | '..N.SafeDisplay(match.kind)..' | '..N.SafeDisplay(match.transform))
    end
    NS.Print('Local sample only; sender identity and live API were not tested. Counters unchanged.')
end
local function editNameList(cmd, rest)
    local field = (cmd == 'allow' or cmd == 'unallow') and 'allow' or 'block'
    local adding = cmd == 'allow' or cmd == 'block'
    local ok, key = NS.Settings.EditList(field, adding and 'add' or 'remove', rest)
    if not ok then NS.Print(key); return end
    NS.Print(field .. ': ' .. (adding and 'added ' or 'removed ') .. N.SafeDisplay(key))
end

SLASH_FOREVERCLEANCHAT1 = '/fcc'
SLASH_FOREVERCLEANCHAT2 = '/fclean'
SlashCmdList.FOREVERCLEANCHAT = function(input)
    NS.Initialize()
    NS.Install()
    input = string.gsub(string.gsub(input or '', '^%s+', ''), '%s+$', '')
    local command, rest = string.match(input, '^(%S+)%s*(.-)$')
    command, rest = string.lower(command or ''), rest or ''
    if command == '' or command == 'open' or command == 'ui' then
        if NS.UI and NS.UI.Toggle then NS.UI.Toggle() else status(); help() end
    elseif command == 'settings' then
        if NS.UI and NS.UI.Show then NS.UI.Show('settings') else status() end
    elseif command == 'close' then
        if NS.UI and NS.UI.Hide then NS.UI.Hide() end
    elseif command == 'minimap' then
        rest = string.lower(rest)
        if rest == 'show' or rest == 'hide' then NS.Settings.SetMinimapShown(rest == 'show')
        elseif rest == 'reset' then NS.Settings.SaveMinimapAngle(225); NS.Settings.SetMinimapShown(true)
        else NS.Print('Usage: /fcc minimap show | hide | reset') end
    elseif command == 'status' or command == 'stats' then status()
    elseif command == 'help' then help()
    elseif command == 'on' or command == 'off' then
        NS.Settings.SetEnabled(command == 'on'); status()
    elseif command == 'mode' then
        rest = string.lower(rest)
        if rest ~= 'balanced' and rest ~= 'strict' then NS.Print('Usage: /fcc mode balanced | /fcc mode strict'); return end
        NS.Settings.SetMode(rest); status()
    elseif command=='domainpolicy' then
        rest=string.lower(rest)
        if rest~='hide_all' and rest~='contextual' then NS.Print('Usage: /fcc domainpolicy hide_all | contextual');return end
        NS.Settings.SetDomainPolicy(rest);status()
    elseif command=='pack' then pack()
    elseif command=='why' then why(rest)
    elseif command == 'test' then
        local passed, total = R.RunSelfTests()
        NS.Print('Built-in rule checks: ' .. passed .. '/' .. total .. ' passed. No chat sent; counters unchanged.')
        status()
    elseif command == 'log' then showLog(rest)
    elseif command == 'list' then listing()
    elseif command == 'domain' or command == 'word' then editTextList(command, rest)
    elseif command == 'allow' or command == 'unallow' or command == 'block' or command == 'unblock' then
        editNameList(command, rest)
    else help() end
end
