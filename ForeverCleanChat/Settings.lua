local _, NS = ...
local N, S = NS.Normalize, {}
NS.Settings = S
local LIMIT = 100
local anchors = {CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,
    TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}

local function finite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end
local function changed()
    NS.Invalidate()
    return true
end
function S.SetEnabled(value)
    if type(value) ~= 'boolean' then return false, 'Choose On or Off.' end
    NS.db.enabled = value
    return changed()
end
function S.SetMode(value)
    if value ~= 'balanced' and value ~= 'strict' then return false, 'Choose Balanced or Strict.' end
    NS.db.mode = value
    return changed()
end
function S.SetDomainPolicy(value)
    if value ~= 'hide_all' and value ~= 'contextual' then return false, 'Choose Hide all or Contextual.' end
    NS.db.known_domain_mention_policy = value
    return changed()
end
function S.SetChatEvent(event, value)
    if not NS.Scope[event] or type(value) ~= 'boolean' then return false, 'Unknown chat event.' end
    NS.db.chatEvents[event] = value
    return changed()
end
function S.SetDomainEnabled(domain, value)
    local key = type(domain) == 'string' and N.Domain(domain)
    if not key or type(value) ~= 'boolean' then return false, 'Invalid domain preference.' end
    local builtin = false
    for _, indicator in ipairs(NS.Data.domains) do
        if indicator.value == key then builtin = true; break end
    end
    if not builtin then return false, 'Only built-in domains can be enabled or disabled.' end
    -- An older explicit addition of this same host must not bypass its disabled state.
    if not value then NS.db.domains[key] = nil end
    NS.db.domainDisabled[key] = not value or nil
    return changed()
end
function S.SetLanguage(value)
    if value ~= 'en' then return false, 'The control panel language is English.' end
    NS.db.ui.language = value
    NS.NotifyChange('ui')
    return true
end
function S.SetMinimapShown(value)
    if type(value) ~= 'boolean' then return false, 'Choose whether to show the minimap button.' end
    NS.db.ui.minimap.hide = not value
    NS.NotifyChange('ui')
    return true
end
function S.SaveMinimapAngle(value)
    if not finite(value) then return false, 'Invalid minimap position.' end
    NS.db.ui.minimap.angle = value % 360
    NS.NotifyChange('ui')
    return true
end
function S.SaveWindow(point, relativePoint, x, y)
    if not anchors[point] or not anchors[relativePoint] or not finite(x) or not finite(y) then
        return false, 'Invalid window position.'
    end
    local window = NS.db.ui.window
    window.point, window.relativePoint = point, relativePoint
    window.x, window.y = math.max(-10000, math.min(10000, x)), math.max(-10000, math.min(10000, y))
    return true
end
function S.ResetWindow()
    local window = NS.db.ui.window
    window.point, window.relativePoint, window.x, window.y = 'CENTER', 'CENTER', 0, 0
    NS.NotifyChange('window')
    return true
end
function S.ClearLog()
    -- Acknowledging the log does not reset counters or duplicate protection.
    NS.log = {}
    NS.NotifyChange('log')
    return true
end

function S.EditList(kind, action, text)
    if action ~= 'add' and action ~= 'remove' then return false, 'Choose Add or Remove.' end
    if type(text) ~= 'string' or #text > 4096 then return false, 'Invalid entry.' end
    local key, label, field
    if kind == 'domain' or kind == 'domainAllow' then
        key, label = N.Domain(text)
        field = kind == 'domain' and 'domains' or 'domainAllow'
        if not key then return false, 'Enter a valid domain, for example example.com.' end
    elseif kind == 'phrase' or kind == 'word' then
        key = N.Text(text)
        if #key < 3 or #key > 160 then return false, 'Use a phrase of 3-160 normalized bytes.' end
        label, field = key, 'phrases'
    elseif kind == 'allow' or kind == 'block' then
        key = NS.NameKey(text)
        if not key then return false, 'Enter a player name, optionally including -Realm.' end
        label, field = key, kind
    else return false, 'Unknown list.' end
    local list = NS.db[field]
    if action == 'add' then
        local count = 0
        for _ in pairs(list) do count = count + 1 end
        if count >= LIMIT and not list[key] then return false, 'Maximum 100 entries per list. Remove an entry first.' end
        list[key] = field == 'domains' and label or true
        if kind == 'domain' then
            NS.db.domainDisabled[key], NS.db.domainAllow[key] = nil, nil
        elseif kind == 'allow' or kind == 'block' then
            NS.db[kind == 'allow' and 'block' or 'allow'][key] = nil
        end
    else
        list[key] = nil
        if kind == 'domain' then
            for _, indicator in ipairs(NS.Data.domains) do
                if indicator.value == key then NS.db.domainDisabled[key] = true; break end
            end
        end
    end
    changed()
    return true, label
end
