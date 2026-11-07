-- GramFrames: Healer Mana
-- A plain text list beside your frames: healer name in class color + mana %.
-- % color: white when high, blue when getting low, red when low.
-- Mana can be a secret value in combat, so it's only ever handed to widget
-- setters and to a Blizzard color curve - never compared or added up here.
local _, GT = ...

local MAX_ROWS = 15
local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

GT.defaults.healerMana = {
    enabled = true,
    showParty = true,
    showRaid = true,
    size = 12,
    spacing = 2,
    x = 4,
    y = 0,
    midBelow = 50,                      -- blue at or under this %
    lowBelow = 25,                      -- red at or under this %
    highColor = { 1, 1, 1 },
    midColor = { 0.25, 0.55, 1 },
    lowColor = { 1, 0.15, 0.15 },
}

-- test-mode healers: same people Gram Frames' preview uses, by slot
local FAKE_HEALERS = {
    { 3, "Moonbrew", "DRUID", 88 }, { 4, "Holyrolla", "PRIEST", 42 },
    { 5, "Sparkz", "SHAMAN", 18 }, { 16, "Dawnblade", "PALADIN", 67 },
}
local SIZES = { party = 5, raid10 = 10, raid20 = 20, raid40 = 40 }

local function S() return GT.db.healerMana end

-------------------------------------------------------------------------------
-- Widgets
-------------------------------------------------------------------------------
local holder = CreateFrame("Frame", "GramFramesHealerMana", UIParent)
holder:SetSize(1, 1)
holder:SetFrameStrata("MEDIUM")
holder:Hide()

local rows = {}
local function MakeRow(i)
    local name = holder:CreateFontString(nil, "OVERLAY")
    name:SetJustifyH("LEFT")
    local pct = holder:CreateFontString(nil, "OVERLAY")
    pct:SetJustifyH("LEFT")
    pct:SetPoint("LEFT", name, "RIGHT", 4, 0)
    rows[i] = { name = name, pct = pct }
    return rows[i]
end

local function ApplyStyle()
    local s = S()
    for i = 1, MAX_ROWS do
        local r = rows[i] or MakeRow(i)
        GT.SetFont(r.name, s.size, "OUTLINE")
        GT.SetFont(r.pct, s.size, "OUTLINE")
        r.name:ClearAllPoints()
        r.name:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * (s.size + s.spacing))
    end
end

-------------------------------------------------------------------------------
-- Colors (Blizzard color curve, so it still works in combat)
-------------------------------------------------------------------------------
local curve
local function BuildCurve()
    curve = nil
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum.LuaCurveType and CreateColor) then return end
    local s = S()
    local lo, mid, hi = s.lowColor, s.midColor, s.highColor
    local c = C_CurveUtil.CreateColorCurve()
    c:SetType(Enum.LuaCurveType.Step)
    c:AddPoint(0, CreateColor(lo[1], lo[2], lo[3], 1))
    c:AddPoint(math.min(s.lowBelow, s.midBelow) / 100 + 0.0001, CreateColor(mid[1], mid[2], mid[3], 1))
    c:AddPoint(s.midBelow / 100 + 0.0001, CreateColor(hi[1], hi[2], hi[3], 1))
    curve = c
end

local function ColorForReadable(pct)
    local s = S()
    if pct <= s.lowBelow then return s.lowColor end
    if pct <= s.midBelow then return s.midColor end
    return s.highColor
end

local function ManaPct(unit)
    if UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100 then
        return UnitPowerPercent(unit, MANA, false, CurveConstants.ScaleTo100)
    end
    local cur, max = UnitPower(unit, MANA), UnitPowerMax(unit, MANA)
    if not GT.Readable(cur) or not GT.Readable(max) or not max or max == 0 then return nil end
    return cur / max * 100
end

local function ClassRGB(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

-------------------------------------------------------------------------------
-- Where to sit: right edge of the frames actually on screen
-------------------------------------------------------------------------------
local function Edge()
    local uiScale = UIParent:GetEffectiveScale()
    local right, top
    local function consider(f)
        if f and f:IsVisible() and f:GetRight() then
            local sc = f:GetEffectiveScale() / uiScale
            local r, t = f:GetRight() * sc, f:GetTop() * sc
            if not right or r > right then right = r end
            if not top or t > top then top = t end
        end
    end
    if GT.testMode and GT.testHolder then
        for _, child in ipairs({ GT.testHolder:GetChildren() }) do consider(child) end
    elseif GT.headers then
        local list = {}
        for i = 1, 8 do list[#list + 1] = GT.headers.groups and GT.headers.groups[i] end
        list[#list + 1] = GT.headers.combined
        for _, h in ipairs(list) do
            if h and h:IsVisible() then
                for i = 1, 40 do
                    local child = h:GetAttribute("child" .. i)
                    if not child then break end
                    consider(child)
                end
            end
        end
    end
    return right, top
end

local function Position()
    local right, top = Edge()
    holder:ClearAllPoints()
    if right then
        holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right + S().x, top + S().y)
        return true
    end
    return false
end

-------------------------------------------------------------------------------
-- Roster
-------------------------------------------------------------------------------
local unitToRow = {}

local function UpdateRow(r, unit)
    local pct = ManaPct(unit)
    if pct == nil or not pcall(r.pct.SetFormattedText, r.pct, "%.0f%%", pct) then
        r.pct:SetText("--")
    end
    local dead = GT.IsTrue(UnitIsDeadOrGhost(unit))
    local online = UnitIsConnected(unit)
    if dead or (GT.Readable(online) and not online) then
        r.pct:SetTextColor(0.5, 0.5, 0.5)
        return
    end
    if curve and UnitPowerPercent then
        local ok = pcall(function()
            local color = UnitPowerPercent(unit, MANA, false, curve)
            r.pct:SetTextColor(color:GetRGB())
        end)
        if ok then return end
    end
    local c = (GT.Readable(pct) and type(pct) == "number") and ColorForReadable(pct) or S().highColor
    r.pct:SetTextColor(c[1], c[2], c[3])
end

local function HideRows(from)
    for i = from, MAX_ROWS do
        if rows[i] then rows[i].name:Hide(); rows[i].pct:Hide() end
    end
end

local function ShowFakes()
    local n = SIZES[GT.db.general.editLayout] or 5
    local i = 0
    for _, f in ipairs(FAKE_HEALERS) do
        if f[1] <= n then
            i = i + 1
            local r = rows[i]
            r.name:SetText(f[2]); r.name:SetTextColor(ClassRGB(f[3])); r.name:Show()
            r.pct:SetText(f[4] .. "%")
            local c = ColorForReadable(f[4])
            r.pct:SetTextColor(c[1], c[2], c[3]); r.pct:Show()
        end
    end
    HideRows(i + 1)
end

local function Rebuild()
    if not GT.db or not rows[1] then return end -- not logged in yet
    wipe(unitToRow)
    local s = S()
    local inRaid = IsInRaid()
    local allowed = s.enabled and ((inRaid and s.showRaid) or (not inRaid and s.showParty))

    if GT.testMode then
        if not s.enabled then holder:Hide() return end
        ShowFakes()
        holder:SetShown(Position())
        return
    end
    if not allowed or not IsInGroup() then holder:Hide() return end

    local units = {}
    if inRaid then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    end

    local i = 0
    for _, unit in ipairs(units) do
        if i < MAX_ROWS and UnitExists(unit) and GT.UnitRole(unit) == "HEALER" then
            i = i + 1
            local r = rows[i]
            unitToRow[unit] = r
            r.name:SetText(UnitName(unit))
            local ok, _, class = pcall(UnitClass, unit)
            r.name:SetTextColor(ClassRGB(ok and GT.Str(class) or nil))
            UpdateRow(r, unit)
            r.name:Show(); r.pct:Show()
        end
    end
    HideRows(i + 1)
    holder:SetShown(i > 0 and Position())
end

-- Gram Frames lays its groups out a moment after a roster change
local function RebuildSoon()
    Rebuild()
    C_Timer.After(0.5, Rebuild)
end
GT.HealerManaRefresh = RebuildSoon

-------------------------------------------------------------------------------
-- Wiring
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_CONNECTION", "UNIT_FLAGS" }) do
    GT.SafeRegister(ev, e)
end
ev:SetScript("OnEvent", function(_, _, unit)
    local r = unit and unitToRow[unit]
    if r then UpdateRow(r, unit) end
end)

GT.On("Login", function()
    ApplyStyle()
    BuildCurve()
    -- the old standalone HealerMana addon would double up - keep it out of the way
    local old = _G.HealerManaFrame
    if old then
        old:Hide()
        old:HookScript("OnShow", old.Hide)
        GT.Print("Healer Mana is built in now - you can untick the old HealerMana addon.")
    end
    C_Timer.After(2, Rebuild)
end)
GT.On("GROUP_ROSTER_UPDATE", RebuildSoon)
GT.On("PLAYER_ROLES_ASSIGNED", RebuildSoon)
GT.On("PLAYER_ENTERING_WORLD", RebuildSoon)
GT.On("LayoutApplied", RebuildSoon)
GT.On("TestModeChanged", RebuildSoon)

GT.On("SettingChanged", function(section, key)
    if section == "all" then
        ApplyStyle(); BuildCurve(); RebuildSoon()
    elseif section == "healerMana" then
        if key == "size" or key == "spacing" then ApplyStyle() end
        BuildCurve()
        Rebuild()
    elseif section == "layout" or section == "general" then
        RebuildSoon()   -- frames moved, resized, or test preview changed
    end
end)
