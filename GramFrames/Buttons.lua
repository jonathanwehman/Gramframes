-- GramFrames: unit button visuals + updates.
-- Every value the game may hand back as a "secret" goes straight into a widget
-- setter (SetValue, SetText, SetTexture, SetAlpha). Lua never does math on it.
local _, GT = ...

local FLAT = GT.FLAT
local pcall, type, ipairs = pcall, type, ipairs
local IsSecret, Readable, IsTrue, Str, Num = GT.IsSecret, GT.Readable, GT.IsTrue, GT.Str, GT.Num

GT.buttons = {}        -- every live secure button (raid + tank)
GT.targetButtons = {}  -- tank-target buttons (polled; target units fire no events)

local UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_AURA", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_CONNECTION", "UNIT_NAME_UPDATE",
    "UNIT_FLAGS", "UNIT_PHASE", "INCOMING_RESURRECT_CHANGED",
}

-------------------------------------------------------------------------------
-- small helpers
-------------------------------------------------------------------------------
local function Call(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
    return nil
end

local function Edge(parent, layer)
    local t = parent:CreateTexture(nil, layer or "OVERLAY")
    t:SetTexture(FLAT)
    return t
end

-- A 4-sided border made of textures; SetColor/SetAlpha accept secrets (alpha aspect).
local function CreateBorder(parent, layer, sub)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    f:SetFrameLevel(parent:GetFrameLevel() + (sub or 3))
    f.edges = {}
    for i = 1, 4 do f.edges[i] = Edge(f, layer) end
    function f:SetThickness(px)
        local t, r, b, l = self.edges[1], self.edges[2], self.edges[3], self.edges[4]
        t:ClearAllPoints(); t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(px)
        b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(px)
        l:ClearAllPoints(); l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(px)
        r:ClearAllPoints(); r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(px)
    end
    function f:SetColor(r, g, b, a)
        for i = 1, 4 do self.edges[i]:SetVertexColor(r, g, b, a or 1) end
    end
    f:SetThickness(1)
    return f
end
GT.CreateBorder = CreateBorder

local function NewFont(parent, size, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    GT.SetFont(fs, size or 11, "OUTLINE")
    fs:SetShadowOffset(0, 0)
    fs:SetWordWrap(false)
    return fs
end

-- Step curve: threat status 3 ("has aggro") -> 1, anything lower -> 0.
-- Lets the client do the comparison when the threat value is secret.
local aggroCurve
local function GetAggroCurve()
    if aggroCurve ~= nil then return aggroCurve end
    aggroCurve = false
    if C_CurveUtil and C_CurveUtil.CreateCurve then
        local ok, curve = pcall(C_CurveUtil.CreateCurve)
        if ok and curve then
            if Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step and curve.SetType then
                pcall(curve.SetType, curve, Enum.LuaCurveType.Step)
            end
            pcall(curve.AddPoint, curve, 0, 0)
            pcall(curve.AddPoint, curve, 2.99, 0)
            pcall(curve.AddPoint, curve, 3, 1)
            aggroCurve = curve
        end
    end
    return aggroCurve
end

-------------------------------------------------------------------------------
-- Visual construction (shared by real secure buttons and test-mode fakes)
-------------------------------------------------------------------------------
function GT.BuildVisuals(b, kind)
    b.kind = kind or "unit"
    local c = GT.colors

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetTexture(FLAT)
    b.bg:SetAllPoints()

    b.health = CreateFrame("StatusBar", nil, b)
    b.health:SetStatusBarTexture(FLAT)
    b.health:SetMinMaxValues(0, 1)
    b.health:SetValue(1)
    b.healthBG = b.health:CreateTexture(nil, "BACKGROUND")
    b.healthBG:SetTexture(FLAT)
    b.healthBG:SetAllPoints()

    b.power = CreateFrame("StatusBar", nil, b)
    b.power:SetStatusBarTexture(FLAT)
    b.power:SetMinMaxValues(0, 1)
    b.power:SetValue(1)
    b.powerBG = b.power:CreateTexture(nil, "BACKGROUND")
    b.powerBG:SetTexture(FLAT)
    b.powerBG:SetAllPoints()
    b.powerBG:SetVertexColor(0, 0, 0, 0.7)

    local overlay = CreateFrame("Frame", nil, b)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(b.health:GetFrameLevel() + 2)
    b.overlay = overlay

    b.name = NewFont(overlay, 11)
    b.htext = NewFont(overlay, 10)
    b.status = NewFont(overlay, 10)
    b.status:SetTextColor(0.75, 0.75, 0.78)
    b.sub = NewFont(overlay, 9) -- tank-target: who the mob is hitting
    b.sub:SetTextColor(c.muted[1], c.muted[2], c.muted[3])

    b.role = overlay:CreateTexture(nil, "OVERLAY")
    b.role:SetSize(10, 10)
    b.leader = overlay:CreateTexture(nil, "OVERLAY")
    b.leader:SetSize(10, 10)
    b.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    b.leader:Hide()
    b.raidIcon = overlay:CreateTexture(nil, "OVERLAY")
    b.raidIcon:SetSize(14, 14)
    b.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    b.raidIcon:Hide()

    b.frameBorder = CreateBorder(b, "BORDER", 1)
    b.frameBorder:SetColor(0, 0, 0, 1)

    b.targetBorder = CreateBorder(b, "OVERLAY", 4)
    b.targetBorder:SetColor(1, 1, 1, 0.9)
    b.targetBorder:Hide()

    b.aggro = CreateBorder(b, "OVERLAY", 5)
    b.aggro:Hide()
    b.aggroLabel = NewFont(b.aggro, 9)
    b.aggroLabel:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
    b.aggroLabel:SetText("AGGRO")

    b.highlight = b.health:CreateTexture(nil, "OVERLAY")
    b.highlight:SetTexture(FLAT)
    b.highlight:SetAllPoints(b.health)
    b.highlight:SetVertexColor(1, 1, 1, 0.08)
    b.highlight:Hide()

    b.debuffs = {}
    b.buffs = {}
    local function AuraIcon()
        local d = CreateFrame("Frame", nil, overlay)
        d:SetFrameLevel(overlay:GetFrameLevel() + 1)
        d.icon = d:CreateTexture(nil, "ARTWORK")
        d.icon:SetPoint("TOPLEFT", 1, -1)
        d.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        d.border = d:CreateTexture(nil, "BACKGROUND")
        d.border:SetTexture(FLAT)
        d.border:SetAllPoints()
        d.border:SetVertexColor(0, 0, 0, 1)
        d.cd = CreateFrame("Cooldown", nil, d, "CooldownFrameTemplate")
        d.cd:SetAllPoints(d.icon)
        d.cd:SetDrawEdge(false)
        if d.cd.SetHideCountdownNumbers then d.cd:SetHideCountdownNumbers(true) end
        d.count = NewFont(d, 9)
        d.count:SetPoint("BOTTOMRIGHT", 2, -1)
        d:Hide()
        return d
    end
    for i = 1, 6 do
        b.debuffs[i] = AuraIcon()
        b.buffs[i] = AuraIcon()
    end

    b:HookScript("OnEnter", function(self)
        self.highlight:Show()
        if self.unit and UnitExists(self.unit) and GameTooltip_SetDefaultAnchor then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            pcall(GameTooltip.SetUnit, GameTooltip, self.unit)
            GameTooltip:Show()
        end
    end)
    b:HookScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)

    GT.ApplyLook(b)
end

-- Apply appearance settings that don't touch protected attributes
function GT.ApplyLook(b)
    local db = GT.db
    if not db then return end
    local look, deb = GT.Look(), GT.Debuffs()
    local isTarget = b.kind == "target"

    b.bg:SetVertexColor(0, 0, 0, look.bgAlpha) -- 1px black edge around the bar
    b.frameBorder:Hide()

    local showPower = not isTarget and look.powerBar ~= "NONE"
    local ph = showPower and look.powerHeight or 0
    b.health:ClearAllPoints()
    b.health:SetPoint("TOPLEFT", 1, -1)
    b.health:SetPoint("BOTTOMRIGHT", -1, 1 + (ph > 0 and (ph + 1) or 0))
    b.power:ClearAllPoints()
    b.power:SetPoint("BOTTOMLEFT", 1, 1)
    b.power:SetPoint("BOTTOMRIGHT", -1, 1)
    b.power:SetHeight(math.max(ph, 1))
    b.power:SetShown(ph > 0)
    b.showPower = ph > 0

    GT.SetFont(b.name, look.nameSize, "OUTLINE")
    GT.SetFont(b.htext, look.healthTextSize, "OUTLINE")
    GT.SetFont(b.status, look.healthTextSize, "OUTLINE")

    b.name:ClearAllPoints()
    b.htext:ClearAllPoints()
    b.status:ClearAllPoints()
    b.sub:ClearAllPoints()
    if isTarget then
        b.name:SetPoint("TOPLEFT", b.health, "TOPLEFT", 4, -3)
        b.name:SetPoint("TOPRIGHT", b.health, "TOPRIGHT", -30, -3)
        b.name:SetJustifyH("LEFT")
        b.sub:SetPoint("BOTTOMLEFT", b.health, "BOTTOMLEFT", 4, 3)
        b.sub:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", -4, 3)
        b.sub:SetJustifyH("LEFT")
        b.htext:SetPoint("TOPRIGHT", b.health, "TOPRIGHT", -3, -3)
        b.status:SetPoint("CENTER", b.health, "CENTER", 0, 0)
    else
        local nameY = (look.healthText ~= "NONE") and 4 or 0
        b.name:SetPoint("LEFT", b.health, "LEFT", 4, nameY)
        b.name:SetPoint("RIGHT", b.health, "RIGHT", -4, nameY)
        b.name:SetJustifyH("CENTER")
        b.htext:SetPoint("TOP", b.name, "BOTTOM", 0, -1)
        b.status:SetPoint("TOP", b.name, "BOTTOM", 0, -1)
    end

    local rs = look.roleSize or 10
    b.role:SetSize(rs, rs)
    b.role:ClearAllPoints()
    b.role:SetPoint("TOPLEFT", b.health, "TOPLEFT", 2, -2)
    b.leader:SetSize(math.max(8, rs), math.max(8, rs))
    b.leader:ClearAllPoints()
    b.leader:SetPoint("TOPLEFT", b.health, "TOPLEFT", (look.roleIcon and rs + 4) or 2, -1)
    b.raidIcon:ClearAllPoints()
    b.raidIcon:SetPoint("TOP", b, "TOP", 0, 6)

    b.aggro:SetThickness(GT.db.aggro.thickness)
    b.targetBorder:SetThickness(1)

    local bsize = GT.Buffs().size
    for i, d in ipairs(b.buffs) do
        d:SetSize(bsize, bsize)
        d:ClearAllPoints()
        if i == 1 then
            d:SetPoint("TOPRIGHT", b.health, "TOPRIGHT", -2, -2)
        else
            d:SetPoint("RIGHT", b.buffs[i - 1], "LEFT", -1, 0)
        end
    end

    local size = deb.size
    for i, d in ipairs(b.debuffs) do
        d:SetSize(size, size)
        d:ClearAllPoints()
        if i == 1 then
            d:SetPoint("BOTTOMLEFT", b.health, "BOTTOMLEFT", 2, 2)
        else
            d:SetPoint("LEFT", b.debuffs[i - 1], "RIGHT", 1, 0)
        end
    end
end

-------------------------------------------------------------------------------
-- Secure button init (called from XML OnLoad)
-------------------------------------------------------------------------------
local function RegisterUnit(b, unit)
    b:UnregisterAllEvents()
    if not unit then return end
    for _, e in ipairs(UNIT_EVENTS) do
        if b.RegisterUnitEvent then
            pcall(b.RegisterUnitEvent, b, e, unit)
        else
            pcall(b.RegisterEvent, b, e)
        end
    end
end

local function OnUnitEvent(self, event, unit)
    if unit and self.unit and unit ~= self.unit then return end
    if event == "UNIT_HEALTH" then
        GT.UpdateHealth(self)
    elseif event == "UNIT_MAXHEALTH" then
        GT.UpdateMaxHealth(self); GT.UpdateHealth(self)
    elseif event == "UNIT_POWER_UPDATE" then
        GT.UpdatePower(self)
    elseif event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
        GT.UpdatePowerFull(self)
    elseif event == "UNIT_AURA" then
        GT.UpdateDebuffs(self)
        GT.UpdateBuffs(self)
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
        GT.UpdateAggro(self)
    elseif event == "UNIT_NAME_UPDATE" then
        GT.UpdateName(self); GT.UpdateColor(self)
    else
        GT.UpdateAll(self)
    end
end

function GT.InitUnitButton(b, isTank)
    GT.BuildVisuals(b, isTank and "tank" or "unit")
    b:RegisterForClicks("AnyUp")
    b:SetScript("OnEvent", OnUnitEvent)
    b:HookScript("OnAttributeChanged", function(self, name, value)
        if name ~= "unit" then return end
        if value == self.unit then return end
        self.unit = value
        RegisterUnit(self, value)
        if value then GT.UpdateAll(self) end
    end)
    b:HookScript("OnShow", function(self)
        if self.unit then GT.UpdateAll(self) end
    end)
    GT.buttons[b] = true
    if GT.ApplyClicks then GT.ApplyClicks(b) end
end

function GT.InitTankTargetButton(b)
    GT.BuildVisuals(b, "target")
    b:RegisterForClicks("AnyUp")
    GT.targetButtons[b] = true
end

-------------------------------------------------------------------------------
-- Updates
-------------------------------------------------------------------------------
function GT.UpdateMaxHealth(b)
    local u = b.unit
    if not u then return end
    local max = Call(UnitHealthMax, u)
    if not rawequal(max, nil) then b.health:SetMinMaxValues(0, max) end
end

function GT.UpdateHealthText(b)
    local u, mode = b.unit, GT.Look().healthText
    if mode == "NONE" or b.isDead or b.isOffline then b.htext:Hide() return end
    if mode == "PERCENT" then
        local pct
        if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
            pct = Call(UnitHealthPercent, u, true, CurveConstants.ScaleTo100)
        end
        if rawequal(pct, nil) then
            local h, m = Num(Call(UnitHealth, u)), Num(Call(UnitHealthMax, u))
            if h and m and m > 0 then pct = h / m * 100 end
        end
        if rawequal(pct, nil) then b.htext:Hide() return end
        local ok, s = pcall(string.format, "%.0f%%", pct)
        if ok then b.htext:SetText(s); b.htext:Show() else b.htext:Hide() end
    else -- MISSING
        local missing = UnitHealthMissing and Call(UnitHealthMissing, u)
        if rawequal(missing, nil) then
            local h, m = Num(Call(UnitHealth, u)), Num(Call(UnitHealthMax, u))
            if h and m then missing = m - h end
        end
        if rawequal(missing, nil) then b.htext:Hide() return end
        local readable = Num(missing)
        if readable and readable <= 0 then b.htext:Hide() return end
        local short = missing
        if AbbreviateNumbers then
            local abbr = Call(AbbreviateNumbers, missing)
            if not rawequal(abbr, nil) then short = abbr end
        end
        local ok, s = pcall(string.format, "-%s", short)
        if ok then b.htext:SetText(s); b.htext:Show() else b.htext:Hide() end
    end
end

function GT.UpdateHealth(b)
    local u = b.unit
    if not u then return end
    local h = Call(UnitHealth, u)
    if not rawequal(h, nil) then b.health:SetValue(h) end
    GT.UpdateStatus(b)
    GT.UpdateHealthText(b)
    if GT.Look().healthColor == "GRADIENT" then GT.UpdateColor(b) end
end

function GT.UpdateStatus(b)
    local u = b.unit
    local connected = Call(UnitIsConnected, u)
    b.isOffline = Readable(connected) and connected == false
    local dead = Call(UnitIsDeadOrGhost, u)
    b.isDead = IsTrue(dead)
    if b.isOffline then
        b.status:SetText("OFFLINE"); b.status:Show()
    elseif b.isDead then
        b.status:SetText(IsTrue(Call(UnitIsGhost, u)) and "GHOST" or "DEAD"); b.status:Show()
    else
        b.status:Hide()
    end
end

local POWER_COLORS = {
    MANA = { 0.25, 0.55, 1.0 }, RAGE = { 0.9, 0.2, 0.25 }, ENERGY = { 1.0, 0.85, 0.2 },
    FOCUS = { 1.0, 0.55, 0.25 }, RUNIC_POWER = { 0.0, 0.82, 1.0 },
}

function GT.UpdatePowerFull(b)
    local u = b.unit
    if not u or not b.showPower then b.power:Hide() return end
    local mode = GT.Look().powerBar
    if mode == "HEALERS" and b.kind ~= "fake" then
        if GT.UnitRole(u) ~= "HEALER" then b.power:Hide() return end
    end
    b.power:Show()
    local _, token = Call(UnitPowerType, u)
    token = Str(token) or "MANA"
    local col = POWER_COLORS[token] or (PowerBarColor and PowerBarColor[token])
    if col then
        local r, g, bb = col[1] or col.r, col[2] or col.g, col[3] or col.b
        b.power:SetStatusBarColor(r, g, bb)
    end
    local max = Call(UnitPowerMax, u)
    if not rawequal(max, nil) then b.power:SetMinMaxValues(0, max) end
    GT.UpdatePower(b)
end

function GT.UpdatePower(b)
    if not b.unit or not b.power:IsShown() then return end
    local p = Call(UnitPower, b.unit)
    if not rawequal(p, nil) then b.power:SetValue(p) end
end

function GT.ClassColor(unit)
    local _, class = Call(UnitClass, unit)
    class = Str(class)
    local cc = class and (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if cc then return cc.r, cc.g, cc.b end
    return nil
end

-- Health colors. Modes: DARK (dark bar, red missing health), CLASS, CLASSDARK,
-- GRADIENT (red -> yellow -> green by health) and CUSTOM (pick both colors).
local gradientCurve
local function GradientCurve()
    if gradientCurve ~= nil then return gradientCurve end
    gradientCurve = false
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor then
        local ok, c = pcall(C_CurveUtil.CreateColorCurve)
        if ok and c then
            pcall(c.AddPoint, c, 0, CreateColor(0.9, 0.1, 0.1, 1))
            pcall(c.AddPoint, c, 0.5, CreateColor(1, 0.85, 0.1, 1))
            pcall(c.AddPoint, c, 1, CreateColor(0.15, 0.8, 0.25, 1))
            gradientCurve = c
        end
    end
    return gradientCurve
end

function GT.GradientRGB(pct)
    if pct < 0.5 then
        local t = pct / 0.5
        return 0.9 + 0.1 * t, 0.1 + 0.75 * t, 0.1
    end
    local t = (pct - 0.5) / 0.5
    return 1 - 0.85 * t, 0.85 - 0.05 * t, 0.1 + 0.15 * t
end

-- r, g, bl = class color; pct = readable health fraction (or nil); unit for secret gradients
function GT.PaintBar(b, r, g, bl, pct, unit)
    local look = GT.Look()
    local mode = look.healthColor
    local br, bg, bb, lr, lg, lb
    local bc, lc = look.barColor or { 0.17, 0.17, 0.17 }, look.lossColor or { 0.62, 0.05, 0.07 }
    if mode == "DARK" or mode == "CUSTOM" then -- solid: your bar color + your background color
        br, bg, bb = bc[1], bc[2], bc[3]
        lr, lg, lb = lc[1], lc[2], lc[3]
    elseif mode == "CLASSDARK" then
        br, bg, bb, lr, lg, lb = r * 0.28, g * 0.28, bl * 0.28, r * 0.8, g * 0.8, bl * 0.8
    elseif mode == "GRADIENT" then
        lr, lg, lb = 0.12, 0.12, 0.12
        if pct then
            br, bg, bb = GT.GradientRGB(pct)
        elseif unit and UnitHealthPercent and GradientCurve() then
            -- health is hidden: let the client turn health % into a color
            local col = Call(UnitHealthPercent, unit, true, gradientCurve)
            if not rawequal(col, nil) and pcall(function() b.health:SetStatusBarColor(col:GetRGB()) end) then
                br = false
            end
        end
        if br == nil then br, bg, bb = r, g, bl end
    else -- CLASS
        br, bg, bb, lr, lg, lb = r, g, bl, r * 0.25, g * 0.25, bl * 0.25
    end
    if mode ~= "DARK" and mode ~= "CUSTOM" and look.classBG == false then
        lr, lg, lb = lc[1], lc[2], lc[3] -- your own background under class colors
    end
    if b.isOffline then br, bg, bb, lr, lg, lb = 0.3, 0.3, 0.3, 0.2, 0.2, 0.2 end
    if br then b.health:SetStatusBarColor(br, bg, bb) end
    b.healthBG:SetVertexColor(lr, lg, lb, 1)
    if look.nameColor == "CLASS" and not b.isOffline then
        b.name:SetTextColor(r, g, bl)
    else
        b.name:SetTextColor(1, 1, 1)
    end
end

function GT.UpdateColor(b)
    local u = b.unit
    if not u then return end
    if b.kind == "target" then
        local r, g, bl
        if IsTrue(Call(UnitCanAttack, "player", u)) then
            r, g, bl = 0.78, 0.18, 0.20
        elseif IsTrue(Call(UnitIsPlayer, u)) then
            r, g, bl = GT.ClassColor(u)
        end
        r, g, bl = r or 0.25, g or 0.65, bl or 0.30
        b.health:SetStatusBarColor(r, g, bl)
        b.healthBG:SetVertexColor(r * 0.22, g * 0.22, bl * 0.22, 1)
        b.name:SetTextColor(1, 1, 1)
        return
    end
    local r, g, bl = GT.ClassColor(u)
    r, g, bl = r or 0.4, g or 0.8, bl or 0.4
    local pct
    local h, m = Num(Call(UnitHealth, u)), Num(Call(UnitHealthMax, u))
    if h and m and m > 0 then pct = h / m end
    GT.PaintBar(b, r, g, bl, pct, u)
end

function GT.UpdateLeader(b)
    if not GT.Look().leaderIcon or not b.unit or b.kind == "target" then b.leader:Hide() return end
    b.leader:SetShown(IsTrue(Call(UnitIsGroupLeader, b.unit)))
end

function GT.UpdateName(b)
    local u = b.unit
    if not u then return end
    local name = Call(UnitName, u)
    if not rawequal(name, nil) then b.name:SetText(name) else b.name:SetText("") end
    if b.kind == "target" then
        local tt = u .. "target"
        if IsTrue(Call(UnitExists, tt)) then
            local who = Call(UnitName, tt)
            local ok, s = pcall(string.format, "> %s", who or "?")
            b.sub:SetText(ok and s or "")
            b.sub:Show()
        else
            b.sub:Hide()
        end
    else
        b.sub:Hide()
    end
end

local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
function GT.UpdateRole(b)
    if not GT.Look().roleIcon or b.kind == "target" then b.role:Hide() return end
    local role = b.fakeRole or GT.UnitRole(b.unit)
    local atlas = ROLE_ATLAS[role]
    if atlas and role ~= "DAMAGER" then -- DPS icon is noise on a tank's frames
        b.role:SetAtlas(atlas, false) -- keep OUR size, not the atlas's
        local rs = GT.Look().roleSize or 10
        b.role:SetSize(rs, rs)
        b.role:Show()
    else
        b.role:Hide()
    end
end

function GT.UpdateRaidIcon(b)
    if not GT.Look().raidIcon or not b.unit then b.raidIcon:Hide() return end
    local idx = Num(Call(GetRaidTargetIndex, b.unit))
    if idx and SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(b.raidIcon, idx)
        b.raidIcon:Show()
    else
        b.raidIcon:Hide()
    end
end

function GT.UpdateTargetHighlight(b)
    if not GT.Look().targetHighlight or not b.unit then b.targetBorder:Hide() return end
    b.targetBorder:SetShown(IsTrue(Call(UnitIsUnit, b.unit, "target")))
end

-- Aggro: the tank's bread and butter.
--  * healer/DPS with aggro (status 3)      -> red border + AGGRO tag  (go taunt)
--  * healer/DPS about to pull (status 2)   -> orange border
--  * tank losing threat (status 2)         -> orange border + LOSING tag
--  * mob you're watching in the tank panel -> pink border when YOU hold it
function GT.UpdateAggro(b)
    local a = GT.db.aggro
    local u = b.unit
    if not a.enabled or not u then b.aggro:Hide() return end

    if b.kind == "target" then
        local s = Call(UnitThreatSituation, "player", u)
        local n = Num(s)
        if n and n >= 3 then
            b.aggro:SetColor(GT.colors.accent[1], GT.colors.accent[2], GT.colors.accent[3], 1)
            b.aggroLabel:SetText("YOU")
            b.aggroLabel:SetShown(a.showLabel)
            b.aggro:SetAlpha(1)
            b.aggro:Show()
        elseif IsSecret(s) and GetAggroCurve() then
            local alpha = Call(aggroCurve.Evaluate, aggroCurve, s)
            if not rawequal(alpha, nil) then
                b.aggro:SetColor(GT.colors.accent[1], GT.colors.accent[2], GT.colors.accent[3], 1)
                b.aggroLabel:SetText("YOU")
                b.aggroLabel:SetShown(a.showLabel)
                b.aggro:SetAlpha(alpha)
                b.aggro:Show()
            else
                b.aggro:Hide()
            end
        else
            b.aggro:Hide()
        end
        return
    end

    local status = b.fakeThreat or Call(UnitThreatSituation, u)
    local role = b.fakeRole or GT.UnitRole(u)
    local isTank = role == "TANK"
    local n = Num(status)

    if n then
        if isTank then
            if a.showLosingOnTanks and n == 2 then
                b.aggro:SetColor(1, 0.55, 0.1, 1)
                b.aggroLabel:SetText("LOSING")
                b.aggroLabel:SetShown(a.showLabel)
                b.aggro:SetAlpha(1); b.aggro:Show()
                return
            end
        elseif a.warnNonTanks and n >= 2 then
            if n >= 3 then
                b.aggro:SetColor(1, 0.12, 0.12, 1)
                b.aggroLabel:SetText("AGGRO")
                b.aggroLabel:SetShown(a.showLabel)
            else
                b.aggro:SetColor(1, 0.55, 0.1, 1)
                b.aggroLabel:Hide()
            end
            b.aggro:SetAlpha(1); b.aggro:Show()
            return
        end
        b.aggro:Hide()
    elseif IsSecret(status) and not isTank and a.warnNonTanks and GetAggroCurve() then
        -- threat is secret: let the client decide visibility through the curve
        local alpha = Call(aggroCurve.Evaluate, aggroCurve, status)
        if not rawequal(alpha, nil) then
            b.aggro:SetColor(1, 0.12, 0.12, 1)
            b.aggroLabel:SetText("AGGRO")
            b.aggroLabel:SetShown(a.showLabel)
            b.aggro:SetAlpha(alpha)
            b.aggro:Show()
        else
            b.aggro:Hide()
        end
    else
        b.aggro:Hide()
    end
end

local DISPEL_COLORS = {
    Magic = { 0.2, 0.6, 1.0 }, Curse = { 0.6, 0.0, 1.0 }, Disease = { 0.6, 0.4, 0.0 },
    Poison = { 0.0, 0.6, 0.0 },
}

local function ShowDebuff(d, unit, aura, showDispel)
    d.icon:SetTexture(aura.icon)
    -- border: dispellable debuffs get colored
    local dn = aura.dispelName
    if showDispel and not rawequal(dn, nil) then
        local name = Str(dn)
        local col = name and DISPEL_COLORS[name] or { 0.85, 0.3, 1.0 }
        d.border:SetVertexColor(col[1], col[2], col[3], 1)
    else
        d.border:SetVertexColor(0, 0, 0, 1)
    end
    -- timer swipe
    d.cd:Hide()
    local id = aura.auraInstanceID
    if C_UnitAuras.GetAuraDuration and not rawequal(id, nil) and d.cd.SetCooldownFromDurationObject then
        local dur = Call(C_UnitAuras.GetAuraDuration, unit, id)
        if not rawequal(dur, nil) and pcall(d.cd.SetCooldownFromDurationObject, d.cd, dur, true) then
            d.cd:Show()
        end
    else
        local exp, dura = Num(aura.expirationTime), Num(aura.duration)
        if exp and dura and dura > 0 then
            d.cd:SetCooldown(exp - dura, dura)
            d.cd:Show()
        end
    end
    -- stacks
    local count
    if C_UnitAuras.GetAuraApplicationDisplayCount and not rawequal(id, nil) then
        count = Call(C_UnitAuras.GetAuraApplicationDisplayCount, unit, id, 2, 99)
    else
        local n = Num(aura.applications)
        if n and n > 1 then count = n end
    end
    if not rawequal(count, nil) then d.count:SetText(count) else d.count:SetText("") end
    d:Show()
end

-------------------------------------------------------------------------------
-- Native aura containers (WoW Forever / 12.1). The client itself picks and
-- draws the auras, so they keep working in dungeons and combat where reading
-- auras from Lua gets restricted. Falls back to the Lua path if unavailable.
-------------------------------------------------------------------------------
local nativeOK
local function NativeAvailable()
    if nativeOK ~= nil then return nativeOK end
    nativeOK = false
    if not (C_AddOns and AnchorUtil and AnchorUtil.FlowDirection) then return false end
    if C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    local ok, probe = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if ok and probe and probe.AddAuraGroup and probe.SetUnit then
        probe:Hide()
        nativeOK = true
    end
    return nativeOK
end
GT.NativeAurasAvailable = NativeAvailable
function GT.ResetNativeAuras() nativeOK = nil end

local function MakeInit(kind)
    return function(button)
        pcall(button.EnableMouse, button, false) -- clicks/mouseover belong to the unit frame
        local border = button:CreateTexture(nil, "BACKGROUND")
        border:SetTexture(FLAT)
        border:SetAllPoints(button)
        if kind == "dispel" then border:SetVertexColor(0.2, 0.6, 1, 1) else border:SetVertexColor(0, 0, 0, 1) end
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetAllPoints(icon)
        cd:SetDrawEdge(false)
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        local holder = CreateFrame("Frame", nil, button)
        holder:SetAllPoints(button)
        holder:SetFrameLevel(cd:GetFrameLevel() + 2)
        local count = NewFont(holder, 9) -- font set BEFORE the client writes to it
        count:SetPoint("BOTTOMRIGHT", 2, -1)
        button:SetIcon(icon)
        button:SetDurationCooldown(cd)
        button:SetApplicationCount(count, {})
    end
end

local function NewBox(b, groups, anchor, x, y, gh, gv)
    local box = CreateFrame("AuraContainer", nil, b.overlay, "CustomAuraContainerTemplate")
    box:SetFrameLevel(b.overlay:GetFrameLevel() + 2)
    box:SetPoint(anchor, b.health, anchor, x, y)
    box:SetSize(1, 1)
    local FD = AnchorUtil.FlowDirection
    local setA = box.SetFlowLayoutAnchorPoint or box.SetAuraLayoutAnchorPoint
    local setG = box.SetFlowLayoutGrowthDirection or box.SetAuraLayoutGrowthDirection
    if setA then setA(box, anchor) end
    if setG then setG(box, FD[gh], FD[gv]) end
    for _, g in ipairs(groups) do
        box:AddAuraGroup(g.key, g.filter, {
            maxFrameCount = g.max,
            initializeFrame = MakeInit(g.kind),
            layout = { elementWidth = g.size, elementHeight = g.size, elementSpacing = 1, lineSpacing = 1 },
        })
    end
    return box
end

-- the client keeps the box up to date on its own; we only touch it when the unit changes
local function BindBox(box, unit)
    if not box:IsShown() then box:Show() end
    if box.gfUnit ~= unit then
        box.gfUnit = unit
        pcall(box.SetUnit, box, unit)
        pcall(box.UpdateAllAuras, box)
    end
end

-- returns true when the native path handled it
local function NativeDebuffs(b, deb)
    if b.kind == "fake" or not NativeAvailable() then return false end
    for _, d in ipairs(b.debuffs) do d:Hide() end
    local sig = table.concat({ tostring(deb.enabled), deb.size, deb.max, tostring(deb.dispelBorder) }, ":")
    if b.gfDebSig ~= sig then
        if b.gfDebBox then b.gfDebBox:Hide(); pcall(b.gfDebBox.SetUnit, b.gfDebBox, nil) end
        b.gfDebBox, b.gfDebSig = nil, sig
        if deb.enabled then
            local groups
            if deb.dispelBorder and deb.max > 1 then
                local nd = math.min(2, deb.max - 1)
                groups = {
                    { key = "disp", filter = "HARMFUL|RAID_PLAYER_DISPELLABLE", max = nd, size = deb.size, kind = "dispel" },
                    { key = "rest", filter = "HARMFUL|!RAID_PLAYER_DISPELLABLE", max = deb.max - nd, size = deb.size, kind = "debuff" },
                }
            else
                groups = { { key = "all", filter = "HARMFUL", max = deb.max, size = deb.size, kind = "debuff" } }
            end
            local ok, box = pcall(NewBox, b, groups, "BOTTOMLEFT", 2, 2, "Right", "Up")
            if not ok then nativeOK = false; return false end
            b.gfDebBox = box
        end
    end
    local box = b.gfDebBox
    if box then
        if b.unit and deb.enabled then BindBox(box, b.unit) else box:Hide() end
    end
    return true
end

local function NativeBuffs(b, cfg)
    if b.kind == "fake" or not NativeAvailable() then return false end
    for _, d in ipairs(b.buffs) do d:Hide() end
    local sig = table.concat({ tostring(cfg.enabled), cfg.size, cfg.max, cfg.filter }, ":")
    if b.gfBuffSig ~= sig then
        if b.gfBuffBox then b.gfBuffBox:Hide(); pcall(b.gfBuffBox.SetUnit, b.gfBuffBox, nil) end
        b.gfBuffBox, b.gfBuffSig = nil, sig
        if cfg.enabled then
            local filter = (cfg.filter == "RAID") and "HELPFUL|RAID" or "HELPFUL|PLAYER"
            local ok, box = pcall(NewBox, b, { { key = "buffs", filter = filter, max = cfg.max, size = cfg.size, kind = "buff" } },
                "TOPRIGHT", -2, -2, "Left", "Down")
            if not ok then nativeOK = false; return false end
            b.gfBuffBox = box
        end
    end
    local box = b.gfBuffBox
    if box then
        if b.unit and cfg.enabled then BindBox(box, b.unit) else box:Hide() end
    end
    return true
end

function GT.UpdateDebuffs(b)
    local deb = GT.Debuffs()
    local u = b.unit
    for _, d in ipairs(b.debuffs) do d:Hide() end
    if b.kind == "target" then return end
    if NativeDebuffs(b, deb) then return end
    if not deb.enabled or not u then return end
    if b.fakeDebuffs then
        for i = 1, math.min(#b.fakeDebuffs, deb.max) do
            local d = b.debuffs[i]
            d.icon:SetTexture(b.fakeDebuffs[i])
            d.border:SetVertexColor(i == 1 and 0.2 or 0, i == 1 and 0.6 or 0, i == 1 and 1 or 0, 1)
            d.count:SetText("")
            d:Show()
        end
        return
    end
    if not (C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot) then return end
    local res = { pcall(C_UnitAuras.GetAuraSlots, u, "HARMFUL", deb.max) }
    if not res[1] then return end
    local shown = 0
    for i = 3, #res do -- res[2] is the continuation token
        if shown >= deb.max then break end
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySlot, u, res[i])
        if ok and aura then
            shown = shown + 1
            local ok2 = pcall(ShowDebuff, b.debuffs[shown], u, aura, deb.dispelBorder)
            if not ok2 then b.debuffs[shown]:Hide(); shown = shown - 1 end
        end
    end
end

-- Buffs (top-right). Server-side filters do the picking, so nothing secret gets compared.
function GT.UpdateBuffs(b)
    local cfg = GT.Buffs()
    local u = b.unit
    for _, d in ipairs(b.buffs) do d:Hide() end
    if b.kind == "target" then return end
    if NativeBuffs(b, cfg) then return end
    if not cfg.enabled or not u then return end
    if not (C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot) then return end
    local filter = (cfg.filter == "RAID") and "HELPFUL|RAID" or "HELPFUL|PLAYER"
    local res = { pcall(C_UnitAuras.GetAuraSlots, u, filter, cfg.max) }
    if not res[1] then return end
    local shown = 0
    for i = 3, #res do
        if shown >= cfg.max then break end
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySlot, u, res[i])
        if ok and aura then
            shown = shown + 1
            if not pcall(ShowDebuff, b.buffs[shown], u, aura, false) then b.buffs[shown]:Hide(); shown = shown - 1 end
        end
    end
end

-- Range fade. UnitInRange can return secret booleans in restricted areas;
-- SetAlphaFromBoolean lets the client resolve those for us.
function GT.UpdateRange(b)
    local u = b.unit
    if not u or b.kind == "fake" then return end
    local oor = GT.Look().rangeAlpha
    if IsTrue(Call(UnitIsUnit, u, "player")) then b:SetAlpha(1) return end
    if b.kind == "target" then b:SetAlpha(1) return end
    local inRange, checked = Call(UnitInRange, u)
    if Readable(inRange) and Readable(checked) then
        b:SetAlpha((checked and not inRange) and oor or 1)
    elseif b.SetAlphaFromBoolean and IsSecret(inRange) then
        if not pcall(b.SetAlphaFromBoolean, b, inRange, 1, oor) then b:SetAlpha(1) end
    else
        b:SetAlpha(1)
    end
end

function GT.UpdateAll(b)
    if not b.unit then return end
    if b.kind == "target" then
        if not IsTrue(Call(UnitExists, b.unit)) then
            b.name:SetText(""); b.sub:Hide(); b.htext:Hide(); b.aggro:Hide(); b.raidIcon:Hide()
            b.health:SetMinMaxValues(0, 1); b.health:SetValue(0)
            b.healthBG:SetVertexColor(0.08, 0.08, 0.09, 1)
            b.status:SetText("no target"); b.status:Show()
            return
        end
    end
    GT.UpdateMaxHealth(b)
    GT.UpdateHealth(b)
    GT.UpdateColor(b)
    GT.UpdateName(b)
    GT.UpdatePowerFull(b)
    GT.UpdateRole(b)
    GT.UpdateRaidIcon(b)
    GT.UpdateTargetHighlight(b)
    GT.UpdateAggro(b)
    GT.UpdateDebuffs(b)
    GT.UpdateBuffs(b)
    GT.UpdateLeader(b)
    GT.UpdateRange(b)
end

function GT.ForEachButton(fn)
    for b in pairs(GT.buttons) do
        if b.unit then fn(b) end
    end
end

-------------------------------------------------------------------------------
-- Global events & polling
-------------------------------------------------------------------------------
GT.On("PLAYER_TARGET_CHANGED", function()
    GT.ForEachButton(GT.UpdateTargetHighlight)
end)
GT.On("PARTY_LEADER_CHANGED", function()
    GT.ForEachButton(GT.UpdateLeader)
end)
GT.On("RAID_TARGET_UPDATE", function()
    GT.ForEachButton(GT.UpdateRaidIcon)
end)
GT.On("PLAYER_ROLES_ASSIGNED", function()
    GT.ForEachButton(GT.UpdateAll)
end)
GT.On("GROUP_ROSTER_UPDATE", function()
    GT.ForEachButton(GT.UpdateAll)
end)

local ticker = CreateFrame("Frame")
local elapsedRange, elapsedTarget = 0, 0
ticker:SetScript("OnUpdate", function(_, dt)
    if not GT.db then return end
    elapsedRange = elapsedRange + dt
    elapsedTarget = elapsedTarget + dt
    if elapsedRange >= 0.4 then
        elapsedRange = 0
        for b in pairs(GT.buttons) do
            if b.unit and b:IsVisible() then GT.UpdateRange(b) end
        end
    end
    if elapsedTarget >= 0.2 then
        elapsedTarget = 0
        for t in pairs(GT.targetButtons) do
            local parent = t:GetParent()
            if parent and parent.unit and t:IsVisible() then
                t.unit = parent.unit .. "target"
                GT.UpdateAll(t)
            elseif t.unit then
                t.unit = nil
            end
        end
    end
end)
