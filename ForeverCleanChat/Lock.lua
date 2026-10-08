-- A small native padlock. Its update script exists only while a transition is running.
local _, NS = ...
local WHITE = 'Interface\\Buttons\\WHITE8X8'
local PI = math.pi
local GOLD = {0.91,0.64,0.20,1}
local LIGHT = {1,0.87,0.48,1}
local SHADE = {0.30,0.18,0.055,1}
local GREEN = {0.32,1,0.15,1}
local unpack = unpack or table.unpack

local function size(region,w,h)
    if region.SetSize then region:SetSize(w,h)
    else region:SetWidth(w); region:SetHeight(h) end
end

local function rectangle(parent,x,y,w,h,rgba,layer)
    local t=parent:CreateTexture(nil,layer or 'ARTWORK')
    t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y)
    size(t,w,h)
    t:SetTexture(WHITE)
    t:SetVertexColor(unpack(rgba))
    return t
end

local function stroke(parent,x1,y1,x2,y2,thickness,rgba)
    if parent.CreateLine then
        local line=parent:CreateLine(nil,'ARTWORK')
        line:SetThickness(thickness)
        line:SetTexture(WHITE)
        line:SetVertexColor(unpack(rgba))
        line:SetStartPoint('TOPLEFT',parent,x1,-y1)
        line:SetEndPoint('TOPLEFT',parent,x2,-y2)
        return line
    end
    -- Texture rotation rotates UV coordinates, so use real rectangular geometry
    -- on older clients. Short overlapping squares trace diagonal curve segments.
    local dx,dy=x2-x1,y2-y1
    if math.abs(dx)<0.0001 then
        return rectangle(parent,x1-thickness/2,math.min(y1,y2)-thickness/2,
            thickness,math.abs(dy)+thickness,rgba)
    elseif math.abs(dy)<0.0001 then
        return rectangle(parent,math.min(x1,x2)-thickness/2,y1-thickness/2,
            math.abs(dx)+thickness,thickness,rgba)
    end
    local steps=math.max(1,math.ceil(math.max(math.abs(dx),math.abs(dy))))
    local first
    for i=0,steps do
        local amount=i/steps
        local tile=rectangle(parent,x1+dx*amount-thickness/2,y1+dy*amount-thickness/2,
            thickness,thickness,rgba)
        first=first or tile
    end
    return first
end

local function child(parent,w,h,level)
    local frame=CreateFrame('Frame',nil,parent)
    size(frame,w,h)
    if frame.EnableMouse then frame:EnableMouse(false) end
    if frame.SetFrameLevel and parent.GetFrameLevel then
        frame:SetFrameLevel(parent:GetFrameLevel()+level)
    end
    return frame
end

local function clamp(value) return math.max(0,math.min(1,value)) end
local function mix(a,b,t) return a+(b-a)*t end
local function ease(t) return t*t*(3-2*t) end

function NS.CreateProtectionLock(parent,x,y,w,h)
    w,h=w or 54,h or 68
    local lock=child(parent,w,h,1)
    lock:SetPoint('TOPLEFT',parent,'TOPLEFT',x or 0,y or 0)
    local sx,sy=w/56,h/68
    local thickness=math.min(sx,sy)
    lock.durations={fadeIn=0.5,close=0.24,flash=0.28,open=0.24,fadeOut=0.35}
    lock.enabled=false
    lock.visualAlpha,lock.openAmount,lock.glowAlpha=0,1,0
    lock.phase,lock.animating='hidden',false

    local shackle=child(lock,w,h,1)
    lock.shackle=shackle
    local points={{17,39},{17,18}}
    for i=1,12 do
        local angle=PI-PI*i/12
        points[#points+1]={28+11*math.cos(angle),18-11*math.sin(angle)}
    end
    points[#points+1]={39,39}
    shackle.segments={}
    for _,style in ipairs({{7,SHADE},{4.7,GOLD},{1.3,LIGHT}}) do
        for i=1,#points-1 do
            local a,b=points[i],points[i+1]
            shackle.segments[#shackle.segments+1]=stroke(shackle,
                a[1]*sx,a[2]*sy,b[1]*sx,b[2]*sy,style[1]*thickness,style[2])
        end
    end
    -- The left hinge stays connected while the right end rises clear of the body.
    lock.hinge=rectangle(lock,15.4*sx,28*sy,3.2*sx,12*sy,SHADE)
    rectangle(lock,16.2*sx,28*sy,1.6*sx,12*sy,GOLD)

    local body=child(lock,40*sx,29*sy,2)
    body:SetPoint('TOPLEFT',lock,'TOPLEFT',8*sx,-35*sy)
    lock.body=body
    rectangle(body,2*sx,3*sy,38*sx,27*sy,{0,0,0,0.35},'BACKGROUND')
    -- A bevel and a pale upper reflection keep the metal legible at compact UI scale.
    rectangle(body,0,3*sy,40*sx,23*sy,SHADE)
    rectangle(body,3*sx,0,34*sx,29*sy,SHADE)
    rectangle(body,1.5*sx,3*sy,37*sx,23*sy,GOLD)
    rectangle(body,3*sx,1.5*sy,34*sx,26*sy,GOLD)
    rectangle(body,3*sx,3*sy,34*sx,21*sy,{0.77,0.50,0.12,1})
    rectangle(body,3*sx,3*sy,34*sx,7*sy,{0.93,0.69,0.27,1})
    rectangle(body,3*sx,1.5*sy,34*sx,1.6*sy,LIGHT)
    rectangle(body,3*sx,26*sy,34*sx,1.5*sy,{0.43,0.26,0.065,1})
    local outline={{3,0},{37,0},{40,3},{40,26},{37,29},{3,29},{0,26},{0,3},{3,0}}
    body.outline={}
    for i=1,#outline-1 do
        local a,b=outline[i],outline[i+1]
        body.outline[#body.outline+1]=stroke(body,a[1]*sx,a[2]*sy,b[1]*sx,b[2]*sy,
            1.2*thickness,{0.99,0.79,0.35,1})
    end
    local hole={0.09,0.065,0.022,1}
    local head=rectangle(body,17.4*sx,9.4*sy,5.2*sx,5.2*sy,hole)
    head:SetTexture('Interface\\CHARACTERFRAME\\TempPortraitAlphaMask')
    rectangle(body,19*sx,12*sy,2*sx,7*sy,hole)

    local glow=child(lock,44*sx,33*sy,3)
    glow:SetPoint('TOPLEFT',lock,'TOPLEFT',6*sx,-33*sy)
    lock.glow=glow
    rectangle(glow,0,2*sy,44*sx,29*sy,{GREEN[1],GREEN[2],GREEN[3],0.17})
    rectangle(glow,2*sx,0,40*sx,33*sy,{GREEN[1],GREEN[2],GREEN[3],0.13})
    rectangle(glow,2*sx,2*sy,40*sx,2*sy,GREEN)
    rectangle(glow,2*sx,29*sy,40*sx,2*sy,GREEN)
    rectangle(glow,2*sx,4*sy,2*sx,25*sy,GREEN)
    rectangle(glow,40*sx,4*sy,2*sx,25*sy,GREEN)

    local function draw(self)
        self.visualAlpha=clamp(self.visualAlpha)
        self.openAmount=clamp(self.openAmount)
        self.glowAlpha=clamp(self.glowAlpha)
        self:SetAlpha(self.visualAlpha)
        self.shackle:ClearAllPoints()
        self.shackle:SetPoint('TOPLEFT',self,'TOPLEFT',0,11*sy*self.openAmount)
        self.glow:SetAlpha(self.glowAlpha)
    end

    function lock:Finish()
        self:SetScript('OnUpdate',nil)
        self.stage=nil
        self.animating=false
        self.visualAlpha=self.enabled and 1 or 0
        self.openAmount=self.enabled and 0 or 1
        self.glowAlpha=0
        self.phase=self.enabled and 'closed' or 'hidden'
        draw(self)
    end

    local function begin(self,phase,duration,alpha,open)
        self.phase=phase
        self.stage={duration=math.max(0,duration),elapsed=0,
            alpha=self.visualAlpha,open=self.openAmount,glow=self.glowAlpha,
            targetAlpha=alpha,targetOpen=open}
        self.animating=true
    end

    local function advance(self,elapsed)
        local remaining=math.max(0,tonumber(elapsed) or 0)
        -- An oversized tick can finish several finite stages without changing their timing.
        while self.animating do
            local stage=self.stage
            local step=math.min(remaining,math.max(0,stage.duration-stage.elapsed))
            stage.elapsed=stage.elapsed+step
            remaining=remaining-step
            local t=stage.duration==0 and 1 or clamp(stage.elapsed/stage.duration)
            local smooth=ease(t)
            self.visualAlpha=mix(stage.alpha,stage.targetAlpha,smooth)
            self.openAmount=mix(stage.open,stage.targetOpen,smooth)
            self.glowAlpha=self.phase=='glowing' and math.sin(PI*t)^2
                or stage.glow*(1-smooth)
            draw(self)
            if t<1 then break end
            if self.phase=='fading_in' then
                begin(self,'closing',self.durations.close*self.openAmount,1,0)
            elseif self.phase=='closing' then
                begin(self,'glowing',self.durations.flash,1,0)
            elseif self.phase=='opening' then
                begin(self,'fading_out',self.durations.fadeOut*self.visualAlpha,0,1)
            else self:Finish() end
            if remaining<=0 and (not self.stage or self.stage.duration>0) then break end
        end
    end

    function lock:SetEnabled(enabled,animate)
        enabled=not not enabled
        local unchanged=self.enabled==enabled
        self.enabled=enabled
        if not animate or (self.IsVisible and not self:IsVisible()) then
            self:Finish()
            return
        end
        if unchanged then return end
        if enabled then
            begin(self,'fading_in',self.durations.fadeIn*(1-self.visualAlpha),1,self.openAmount)
        else
            begin(self,'opening',self.durations.open*(1-self.openAmount),self.visualAlpha,1)
        end
        self:SetScript('OnUpdate',advance)
        advance(self,0)
    end

    lock:SetScript('OnHide',function(self) self:Finish() end)
    draw(lock)
    return lock
end
