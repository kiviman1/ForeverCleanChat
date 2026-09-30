local ADDON, NS = ...
local M = {}
NS.Minimap = M

local DEFAULT_ANGLE, SIZE, EDGE_OFFSET = 225, 31, 10
local button, dragging, dragged, tooltipOpen
local lastAngle, lastWidth, lastHeight, lastShape

-- A true entry uses a rounded quadrant. The quadrant order is bottom-right,
-- bottom-left, top-right, top-left, matching the minimap shape API convention.
local shapes = {
    ROUND = {true, true, true, true},
    SQUARE = {false, false, false, false},
    ['CORNER-TOPLEFT'] = {true, false, false, false},
    ['CORNER-TOPRIGHT'] = {false, false, true, false},
    ['CORNER-BOTTOMLEFT'] = {false, true, false, false},
    ['CORNER-BOTTOMRIGHT'] = {false, false, false, true},
    ['SIDE-LEFT'] = {true, true, false, false},
    ['SIDE-RIGHT'] = {false, false, true, true},
    ['SIDE-TOP'] = {true, false, true, false},
    ['SIDE-BOTTOM'] = {false, true, false, true},
    ['TRICORNER-TOPLEFT'] = {true, true, true, false},
    ['TRICORNER-TOPRIGHT'] = {false, false, true, true},
    ['TRICORNER-BOTTOMLEFT'] = {true, true, false, true},
    ['TRICORNER-BOTTOMRIGHT'] = {false, true, true, true},
}

local function finite(value)
    return type(value) == 'number' and value == value
        and value > -math.huge and value < math.huge
end

local function config()
    return NS.db and type(NS.db.ui) == 'table' and NS.db.ui.minimap
end

local function angle()
    local settings = config()
    return type(settings) == 'table' and finite(settings.angle)
        and settings.angle % 360 or DEFAULT_ANGLE
end

local function size(frame, width, height)
    if frame.SetSize then frame:SetSize(width, height)
    else frame:SetWidth(width); frame:SetHeight(height) end
end

local function minimapShape()
    if type(GetMinimapShape) == 'function' then
        local ok, shape = pcall(GetMinimapShape)
        if ok and shapes[shape] then return shape end
    end
    -- Some minimap addons set a square mask without advertising a shape.
    -- WHITE8X8 (file ID 130937) is the square mask used by the local EllesmereUI
    -- build. Only explicit mask names are recognized; unknown masks stay round.
    if Minimap and type(Minimap.GetMaskTexture) == 'function' then
        local ok, mask = pcall(Minimap.GetMaskTexture, Minimap)
        if ok then
            if mask == 130937 then return 'SQUARE' end
            if type(mask) == 'string' then
                local name = string.lower(mask)
                if string.find(name, 'white8x8', 1, true)
                    or string.find(name, '%f[%a]square%f[%A]')
                    or string.find(name, '%f[%a]rectangle%f[%A]')
                    or string.find(name, '%f[%a]rectangular%f[%A]') then
                    return 'SQUARE'
                end
            end
        end
    end
    return 'ROUND'
end

local function reposition(force)
    if not button or dragging then return end
    local width = Minimap.GetWidth and Minimap:GetWidth() or 140
    local height = Minimap.GetHeight and Minimap:GetHeight() or 140
    if not finite(width) or width <= 0 then width = 140 end
    if not finite(height) or height <= 0 then height = 140 end
    local degrees, shape = angle(), minimapShape()
    if not force and degrees == lastAngle and width == lastWidth
        and height == lastHeight and shape == lastShape then return end
    local radians = degrees * math.pi / 180
    local x, y = math.cos(radians), math.sin(radians)
    local quadrant = 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)
    local rx, ry = width / 2 + EDGE_OFFSET, height / 2 + EDGE_OFFSET
    if not shapes[shape][quadrant] then
        -- Intersect the ray with a rectangular rim instead of forcing a circular
        -- button position onto square minimaps. This also supports unequal sides.
        local projection = math.max(math.abs(x), math.abs(y))
        x, y = x / projection, y / projection
    end
    button:ClearAllPoints()
    button:SetPoint('CENTER', Minimap, 'CENTER', x * rx, y * ry)
    if button.SetUserPlaced then button:SetUserPlaced(false) end
    lastAngle, lastWidth, lastHeight, lastShape = degrees, width, height, shape
end

local function hideTooltip()
    tooltipOpen = false
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
end

local function tooltip()
    if not button or dragging or not GameTooltip or not GameTooltip.SetOwner
        or not GameTooltip.AddLine or not GameTooltip.Show then return end
    local db = NS.db or {}
    GameTooltip:SetOwner(button, 'ANCHOR_LEFT')
    if GameTooltip.ClearLines then GameTooltip:ClearLines() end
    GameTooltip:AddLine('Forever Clean Chat', 0.47, 0.80, 0.91)
    GameTooltip:AddLine('Version ' .. tostring(NS.VERSION or '?'), 0.75, 0.78, 0.82)
    local enabled = db.enabled ~= false
    local status = enabled and '|cff70e6a0ON|r' or '|cffff9b75OFF|r'
    local mode = db.mode == 'strict' and 'Strict' or 'Balanced'
    GameTooltip:AddLine(status .. '  |  ' .. mode, 1, 1, 1)
    GameTooltip:AddLine('Hidden this session: ' .. tostring(NS.sessionBlocked or 0), 0.80, 0.84, 0.89)
    GameTooltip:AddLine('Hidden total: ' .. tostring(db.totalBlocked or 0), 0.80, 0.84, 0.89)
    GameTooltip:AddLine(' ')
    GameTooltip:AddLine('Left-click: open control panel', 0.93, 0.84, 0.57)
    GameTooltip:AddLine('Right-click: open settings', 0.93, 0.84, 0.57)
    GameTooltip:AddLine('Drag: move around the minimap', 0.72, 0.76, 0.81)
    GameTooltip:Show()
    tooltipOpen = true
end

-- Lua 5.1's atan takes one argument, while some clients expose atan2. Use a
-- quadrant-correct one-argument fallback rather than assuming atan(y, x).
local function atan2(y, x)
    if type(math.atan2) == 'function' then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 then
        return math.atan(y / x) + (y >= 0 and math.pi or -math.pi)
    end
    if y > 0 then return math.pi / 2 end
    if y < 0 then return -math.pi / 2 end
    return 0
end

local function saveCursorAngle()
    if type(GetCursorPosition) ~= 'function' or not Minimap.GetCenter
        or not Minimap.GetEffectiveScale then return end
    local cx, cy = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not finite(cx) or not finite(cy) or not finite(px) or not finite(py)
        or not finite(scale) or scale <= 0 then return end
    local x, y = px / scale - cx, py / scale - cy
    if x == 0 and y == 0 then return end
    local degrees = (atan2(y, x) * 180 / math.pi) % 360
    if NS.Settings and NS.Settings.SaveMinimapAngle then
        NS.Settings.SaveMinimapAngle(degrees)
    elseif type(config()) == 'table' then
        config().angle = degrees
    end
end

local function stopDrag(save)
    if not dragging then return end
    button:StopMovingOrSizing()
    dragging = false
    if save then saveCursorAngle() end
    reposition(true)
end

local function openPanel(which)
    if NS.UI then
        if which == 'settings' and NS.UI.Show then NS.UI.Show('settings'); return end
        if NS.UI.Toggle then NS.UI.Toggle(); return end
    end
    if NS.Print then NS.Print('The control panel is unavailable. Use /fcc status for diagnostics.') end
end

function M.Refresh()
    if not button then return false end
    local settings = config()
    local hidden = type(settings) == 'table' and settings.hide == true
    if hidden then button:Hide()
    else
        reposition()
        button:Show()
    end
    if button.icon and button.icon.SetVertexColor then
        if NS.db and NS.db.enabled == false then button.icon:SetVertexColor(0.52, 0.52, 0.52)
        else button.icon:SetVertexColor(1, 1, 1) end
    end
    if tooltipOpen and not hidden then tooltip() end
    return true
end

function M.SetShown(shown)
    if type(shown) ~= 'boolean' then return false end
    if NS.Settings and NS.Settings.SetMinimapShown then
        NS.Settings.SetMinimapShown(shown)
    elseif type(config()) == 'table' then
        config().hide = not shown
    else return false end
    M.Refresh()
    return true
end

function M.ResetPosition()
    if NS.Settings and NS.Settings.SaveMinimapAngle then
        NS.Settings.SaveMinimapAngle(DEFAULT_ANGLE)
    elseif type(config()) == 'table' then
        config().angle = DEFAULT_ANGLE
    else return false end
    if button then reposition(true) end
    return true
end

function M.Initialize()
    if button then M.Refresh(); return true end
    if type(CreateFrame) ~= 'function' or not Minimap or not NS.db then
        M.unavailableReason = 'The minimap API is unavailable.'
        return false
    end
    button = CreateFrame('Button', 'ForeverCleanChatMinimapButton', Minimap)
    M.button = button
    size(button, SIZE, SIZE)
    button:SetFrameStrata('MEDIUM')
    if button.SetFrameLevel then
        local level = Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 3
        button:SetFrameLevel((finite(level) and level or 3) + 5)
    end
    button:EnableMouse(true)
    button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    if button.SetMovable and button.RegisterForDrag and button.StartMoving
        and button.StopMovingOrSizing then
        button:SetMovable(true)
        button:RegisterForDrag('LeftButton')
    end
    if button.SetClampedToScreen then button:SetClampedToScreen(true) end
    button:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')

    local background = button:CreateTexture(nil, 'BACKGROUND')
    size(background, 20, 20)
    background:SetPoint('TOPLEFT', button, 'TOPLEFT', 7, -5)
    background:SetTexture('Interface\\Minimap\\UI-Minimap-Background')
    local icon = button:CreateTexture(nil, 'ARTWORK')
    size(icon, 20, 20)
    icon:SetPoint('TOPLEFT', button, 'TOPLEFT', 7, -5)
    icon:SetTexture('Interface\\Icons\\INV_Shield_06')
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon
    local border = button:CreateTexture(nil, 'OVERLAY')
    size(border, 53, 53)
    border:SetPoint('TOPLEFT', button, 'TOPLEFT', 0, 0)
    border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')

    button:SetScript('OnEnter', tooltip)
    button:SetScript('OnLeave', hideTooltip)
    button:SetScript('OnMouseDown', function() dragged = false end)
    button:SetScript('OnClick', function(_, mouseButton)
        if dragged or dragging then dragged = false; return end
        hideTooltip()
        openPanel(mouseButton == 'RightButton' and 'settings' or nil)
    end)
    button:SetScript('OnDragStart', function(self)
        if not self.StartMoving or not self.StopMovingOrSizing then return end
        hideTooltip()
        dragged, dragging = true, true
        self:StartMoving()
    end)
    button:SetScript('OnDragStop', function() stopDrag(true) end)
    button:SetScript('OnHide', function() stopDrag(false); hideTooltip() end)
    -- Native movement runs only while dragging. There is no OnUpdate polling.
    if NS.AddChangeListener then NS.AddChangeListener(M.Refresh) end
    if button.RegisterEvent then
        button:RegisterEvent('DISPLAY_SIZE_CHANGED')
        button:RegisterEvent('UI_SCALE_CHANGED')
        button:RegisterEvent('PLAYER_ENTERING_WORLD')
        button:SetScript('OnEvent', function() reposition(true) end)
    end
    M.unavailableReason = nil
    M.Refresh()
    return true
end
