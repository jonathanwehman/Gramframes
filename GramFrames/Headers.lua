-- GramFrames: secure group headers (separate raid groups or one grid), automatic
-- layout switching (party / 10 / 20 / 40), movers + lock, tank panel, test mode,
-- and hiding Blizzard's party/raid frames.
local _, GT = ...

local headers = { groups = {} }
GT.headers = headers

-------------------------------------------------------------------------------
-- Movers: the pink tab above each frame block (hidden while locked)
-------------------------------------------------------------------------------
local function CreateMover(key, label, getPos, setPos)
    local m = CreateFrame("Frame", "GramFrames" .. key .. "Anchor", UIParent)
    m:SetSize(110, 12)
    m:SetMovable(true)
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    m:SetClampedToScreen(true)
    m:SetFrameStrata("MEDIUM")
    m.bg = m:CreateTexture(nil, "BACKGROUND")
    m.bg:SetTexture(GT.FLAT)
    m.bg:SetAllPoints()
    m.bg:SetVertexColor(GT.colors.accent[1], GT.colors.accent[2], GT.colors.accent[3], 0.9)
    m.text = m:CreateFontString(nil, "OVERLAY")
    GT.SetFont(m.text, 9, "")
    m.text:SetPoint("CENTER")
    m.text:SetTextColor(1, 1, 1)
    m.text:SetText(label)
    m:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() and not GT.db.general.locked then self:StartMoving() end
    end)
    m:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        setPos({ p, "UIParent", rp, math.floor(x + 0.5), math.floor(y + 0.5) })
    end)
    m:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cffff4fa3Gram Frames|r " .. label)
        GameTooltip:AddLine("Drag to move. Right-click the minimap button (or /gf lock) to lock.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- nothing gets to re-show a bar while locked
    m:SetScript("OnShow", function(self) if not GT.ShouldShowBar() then self:Hide() end end)
    m:Hide()
    function m:Restore()
        local pos = getPos()
        self:ClearAllPoints()
        self:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
    end
    return m
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function PreCreate(header, count)
    header:SetAttribute("startingIndex", -(count - 1))
    header:Show()
    header:SetAttribute("startingIndex", 1)
end

local function EachChild(header, fn)
    for i = 1, 40 do
        local child = header:GetAttribute("child" .. i)
        if not child then break end
        fn(child)
    end
end

local function RefreshChildren(header, w, h)
    EachChild(header, function(child)
        child:SetSize(w, h)
        if GT.ApplyClicks then GT.ApplyClicks(child) end
        GT.ApplyLook(child)
        if child.unit then GT.UpdateAll(child) end
    end)
end

local function SetSort(h, L)
    if L.sortWithin == "ROLE" then
        h:SetAttribute("groupBy", "ASSIGNEDROLE")
        h:SetAttribute("groupingOrder", "TANK,HEALER,DAMAGER,NONE")
    else
        h:SetAttribute("groupBy", nil)
        h:SetAttribute("groupingOrder", nil)
    end
    h:SetAttribute("sortMethod", "INDEX")
end

local function SetInitialConfig(h, w, hgt)
    h:SetAttribute("initialConfigFunction", string.format([[ self:SetWidth(%d) self:SetHeight(%d) ]], w, hgt))
    if GT.SetHeaderClickAttributes then GT.SetHeaderClickAttributes(h) end
end

-------------------------------------------------------------------------------
-- Raid headers
-------------------------------------------------------------------------------
local function ConfigureGroups(L)
    local cols = L.direction == "COLUMNS"
    for i = 1, 8 do
        local h = headers.groups[i]
        h:SetScale(L.scale)
        SetInitialConfig(h, L.width, L.height)
        h:SetAttribute("groupFilter", tostring(i))
        SetSort(h, L)
        h:SetAttribute("unitsPerColumn", 5)
        h:SetAttribute("maxColumns", 1)
        if cols then
            h:SetAttribute("point", "TOP")
            h:SetAttribute("xOffset", 0)
            h:SetAttribute("yOffset", -L.spacing)
        else
            h:SetAttribute("point", "LEFT")
            h:SetAttribute("xOffset", L.spacing)
            h:SetAttribute("yOffset", 0)
        end
        h:SetAttribute("showRaid", true)
        h:SetAttribute("showParty", i == 1)
        h:SetAttribute("showPlayer", i == 1 and L.showPlayer ~= false)
        h:SetAttribute("showSolo", i == 1 and L.showSolo and not GT.db.general.hideSolo)
        RefreshChildren(h, L.width, L.height)
        -- fixed slots: group N always sits in column (or row) N
        h:ClearAllPoints()
        if cols then
            h:SetPoint("TOPLEFT", GT.movers.main, "BOTTOMLEFT", (i - 1) * (L.width + L.groupSpacing), -2)
        else
            h:SetPoint("TOPLEFT", GT.movers.main, "BOTTOMLEFT", 0, -2 - (i - 1) * (L.height + L.groupSpacing))
        end
    end
end

local function ConfigureCombined(L)
    local h = headers.combined
    h:SetScale(L.scale)
    SetInitialConfig(h, L.width, L.height)
    h:SetAttribute("groupFilter", nil)
    SetSort(h, L)
    h:SetAttribute("unitsPerColumn", L.unitsPerColumn)
    h:SetAttribute("maxColumns", math.ceil(40 / L.unitsPerColumn))
    h:SetAttribute("columnSpacing", L.groupSpacing)
    if L.direction == "COLUMNS" then
        h:SetAttribute("point", "TOP")
        h:SetAttribute("xOffset", 0)
        h:SetAttribute("yOffset", -L.spacing)
        h:SetAttribute("columnAnchorPoint", "LEFT")
    else
        h:SetAttribute("point", "LEFT")
        h:SetAttribute("xOffset", L.spacing)
        h:SetAttribute("yOffset", 0)
        h:SetAttribute("columnAnchorPoint", "TOP")
    end
    h:SetAttribute("showRaid", true)
    h:SetAttribute("showParty", true)
    h:SetAttribute("showPlayer", L.showPlayer ~= false)
    h:SetAttribute("showSolo", L.showSolo and not GT.db.general.hideSolo)
    RefreshChildren(h, L.width, L.height)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", GT.movers.main, "BOTTOMLEFT", 0, -2)
end

local function ConfigureTank()
    local h, T = headers.tank, GT.db.tank
    h:SetScale(GT.ActiveLayout().scale)
    SetInitialConfig(h, T.width, T.height)
    h:SetAttribute("roleFilter", T.includeMainTanks and "MAINTANK,TANK" or "TANK")
    h:SetAttribute("strictFiltering", false)
    h:SetAttribute("sortMethod", "INDEX")
    h:SetAttribute("point", "TOP")
    h:SetAttribute("yOffset", -T.spacing)
    h:SetAttribute("unitsPerColumn", 8)
    h:SetAttribute("maxColumns", 1)
    h:SetAttribute("showRaid", true)
    h:SetAttribute("showParty", true)
    h:SetAttribute("showPlayer", true)
    h:SetAttribute("showSolo", false)
    EachChild(h, function(child)
        child:SetSize(T.width, T.height)
        if GT.ApplyClicks then GT.ApplyClicks(child) end
        GT.ApplyLook(child)
        local t = child.targetButton
        if t then
            t:SetSize(T.targetWidth, T.height)
            t:ClearAllPoints()
            t:SetPoint("LEFT", child, "RIGHT", T.spacing, 0)
            t:SetShown(T.showTargets)
            GT.ApplyLook(t)
        end
        if child.unit then GT.UpdateAll(child) end
    end)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", GT.movers.tank, "BOTTOMLEFT", 0, -2)
end

function GT.UpdateVisibility()
    GT.RunOOC("visibility", function()
        local L = GT.ActiveLayout()
        local testing = GT.testMode
        local separate = L.groupMode == "SEPARATE"
        for i = 1, 8 do headers.groups[i]:SetShown(separate and not testing) end
        headers.combined:SetShown(not separate and not testing)
        headers.tank:SetShown(GT.db.tank.enabled and not testing)
    end)
    GT.UpdateBars()
end

-- the pink frame bars aren't secure, so they update instantly (even in combat)
-- and never wait on the secure headers. Locked = gone, period.
function GT.ShouldShowBar()
    local G = GT.db and GT.db.general
    if not G or G.locked then return false end
    local optionsOpen = GramFramesOptions and GramFramesOptions:IsShown()
    return (not G.hideBar) or (optionsOpen and true or false)
end
function GT.UpdateBars()
    if not GT.movers then return end
    local show = GT.ShouldShowBar()
    GT.movers.main:SetShown(show)
    GT.movers.tank:SetShown(show and GT.db.tank.enabled)
end

local currentLayout
function GT.ConfigureAll()
    GT.RunOOC("configure", function()
        local key = GT.ActiveLayoutKey()
        local L = GT.db.layouts[key]
        currentLayout = key
        GT.movers.main:Restore()
        GT.movers.tank:Restore()
        GT.UpdateMoverLabel()
        ConfigureGroups(L)
        ConfigureCombined(L)
        ConfigureTank()
        GT.UpdateVisibility()
        if GT.testMode then GT.RefreshTestMode() end
        GT.Fire("LayoutApplied", key)
    end)
end

local function CreateHeaders()
    GT.movers = {
        -- party and every raid size keep their own spot. The bar moves whatever is on screen:
        -- your current layout, or (in Test Mode) the one you're editing.
        main = CreateMover("Raid", "Gram Frames",
            function() return GT.db.layouts[GT.ViewKey()].pos end,
            function(pos) GT.db.layouts[GT.ViewKey()].pos = pos end),
        tank = CreateMover("Tank", "Tank Panel",
            function() local T = GT.db.tank; return GT.ViewKey() == "party" and T.posParty or T.posRaid end,
            function(pos) local T = GT.db.tank; if GT.ViewKey() == "party" then T.posParty = pos else T.posRaid = pos end end),
    }
    GT.movers.main:Restore(); GT.movers.tank:Restore()
    GT.UpdateBars()
    for i = 1, 8 do
        local h = CreateFrame("Frame", "GramFramesGroup" .. i, UIParent, "SecureGroupHeaderTemplate")
        h:SetAttribute("template", "GramFramesUnitButtonTemplate")
        headers.groups[i] = h
    end
    headers.combined = CreateFrame("Frame", "GramFramesRaidHeader", UIParent, "SecureGroupHeaderTemplate")
    headers.combined:SetAttribute("template", "GramFramesUnitButtonTemplate")
    headers.tank = CreateFrame("Frame", "GramFramesTankHeader", UIParent, "SecureGroupHeaderTemplate")
    headers.tank:SetAttribute("template", "GramFramesTankButtonTemplate")

    local L = GT.ActiveLayout()
    ConfigureGroups(L)
    ConfigureCombined(L)
    ConfigureTank()
    for i = 1, 8 do PreCreate(headers.groups[i], 5) end
    PreCreate(headers.combined, 40)
    PreCreate(headers.tank, 8)
    GT.ConfigureAll()
end

-- switch layouts when the group size crosses 5 / 10 / 20
local function CheckLayout()
    if not GT.movers then return end
    if GT.ActiveLayoutKey() ~= currentLayout then GT.ConfigureAll() end
end
GT.On("GROUP_ROSTER_UPDATE", CheckLayout)
GT.On("PLAYER_ENTERING_WORLD", CheckLayout)

-------------------------------------------------------------------------------
-- Hide Blizzard party/raid frames
-------------------------------------------------------------------------------
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local function Bury(frame)
    if not frame then return end
    pcall(frame.UnregisterAllEvents, frame)
    pcall(frame.Hide, frame)
    pcall(frame.SetParent, frame, hiddenParent)
end
function GT.HideBlizzard()
    local g = GT.db.general
    if g.hideBlizzParty then
        if _G.CompactPartyFrame then Bury(_G.CompactPartyFrame) end
        if _G.PartyFrame then
            if _G.PartyFrame.PartyMemberFramePool then
                for f in _G.PartyFrame.PartyMemberFramePool:EnumerateActive() do Bury(f) end
            end
            pcall(_G.PartyFrame.SetScript, _G.PartyFrame, "OnShow", nil)
            Bury(_G.PartyFrame)
        end
    end
    if g.hideBlizzRaid and _G.CompactRaidFrameContainer then Bury(_G.CompactRaidFrameContainer) end
    if g.hideRaidManager then
        if CompactRaidFrameManager_SetSetting then pcall(CompactRaidFrameManager_SetSetting, "IsShown", "0") end
        Bury(_G.CompactRaidFrameManager)
    end
end

-------------------------------------------------------------------------------
-- Test mode: fake group sized to the layout you're editing
-------------------------------------------------------------------------------
local FAKE_NAMES = {
    { "Grahamaton", "WARRIOR", "TANK" }, { "Brickwall", "PALADIN", "TANK" }, { "Moonbrew", "DRUID", "HEALER" },
    { "Holyrolla", "PRIEST", "HEALER" }, { "Sparkz", "SHAMAN", "HEALER" }, { "Pewpewz", "HUNTER", "DAMAGER" },
    { "Frostbyte", "MAGE", "DAMAGER" }, { "Shadowkiss", "WARLOCK", "DAMAGER" }, { "Stabbington", "ROGUE", "DAMAGER" },
    { "Bonk", "WARRIOR", "DAMAGER" }, { "Lightfoot", "ROGUE", "DAMAGER" }, { "Hexxy", "SHAMAN", "DAMAGER" },
    { "Grizzly", "DRUID", "DAMAGER" }, { "Felbane", "WARLOCK", "DAMAGER" }, { "Arcanix", "MAGE", "DAMAGER" },
    { "Dawnblade", "PALADIN", "HEALER" }, { "Quickshot", "HUNTER", "DAMAGER" }, { "Ironhide", "WARRIOR", "DAMAGER" },
    { "Mistral", "PRIEST", "DAMAGER" }, { "Embers", "MAGE", "DAMAGER" },
}
local HP = { 1, 0.55, 0.8, 1, 0.64, 0.33, 0.87, 0.71, 0, 0.48, 0.95, 1, 0.62, 0.9, 0.77, 0.4, 1, 0.85, 0.2, 0.69 }
local THREAT = { [2] = 2, [6] = 3, [8] = 2 }
local SIZES = { party = 5, raid10 = 10, raid20 = 20, raid40 = 40 }
local fakes, fakeTanks = {}, {}

local function FillFake(b, i)
    local d = FAKE_NAMES[(i - 1) % #FAKE_NAMES + 1]
    local name, class, role = d[1], d[2], d[3]
    local hp = HP[(i - 1) % #HP + 1]
    b.unit = nil
    b.fakeRole = role
    local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local r, g, bl = cc and cc.r or 0.5, cc and cc.g or 0.5, cc and cc.b or 0.5
    b.isOffline = false
    b.health:SetMinMaxValues(0, 1)
    b.health:SetValue(hp)
    GT.PaintBar(b, r, g, bl, hp)
    b.name:SetText(name)
    local mode = GT.Look().healthText
    if hp <= 0 then
        b.status:SetTextColor(0.75, 0.75, 0.78)
        b.status:SetText("DEAD"); b.status:Show(); b.htext:Hide()
    elseif i == 3 and GT.Look().afk ~= false then -- preview: someone AFK for a few minutes
        b.status:SetTextColor(1, 0.75, 0.3)
        b.status:SetText("AFK 4m"); b.status:Show(); b.htext:Hide()
    elseif i == 12 then -- preview: someone offline (raid sizes only)
        b.status:SetTextColor(0.75, 0.75, 0.78)
        b.status:SetText("OFFLINE 12m"); b.status:Show(); b.htext:Hide()
    else
        b.status:Hide()
        if mode == "PERCENT" then b.htext:SetText(string.format("%.0f%%", hp * 100)); b.htext:Show()
        elseif mode == "MISSING" and hp < 1 then b.htext:SetText(string.format("-%.1fK", (1 - hp) * 6.2)); b.htext:Show()
        else b.htext:Hide() end
    end
    local showPower = b.showPower and (GT.Look().powerBar == "ALL" or role == "HEALER")
    b.power:SetShown(showPower)
    if showPower then
        b.power:SetStatusBarColor(0.25, 0.55, 1)
        b.power:SetMinMaxValues(0, 1)
        b.power:SetValue(0.35 + (i % 5) * 0.13)
    end
    GT.UpdateRole(b)
    b.leader:SetShown(GT.Look().leaderIcon and i == 1)
    -- aggro preview
    local a, threat = GT.db.aggro, THREAT[i]
    b.aggro:Hide()
    if a.enabled and threat then
        if role == "TANK" and threat == 2 and a.showLosingOnTanks then
            GT.SetAggroRed(b); b.aggroLabel:SetText("LOSING"); b.aggroLabel:SetShown(a.showLabel); b.aggro:Show()
        elseif role ~= "TANK" and a.warnNonTanks then
            if threat >= 3 then
                GT.SetAggroRed(b); b.aggroLabel:SetText("AGGRO"); b.aggroLabel:SetShown(a.showLabel)
            else
                GT.SetAggroRed(b); b.aggroLabel:Hide()
            end
            b.aggro:Show()
        end
        b.aggro:SetAlpha(1)
    end
    -- auras
    for _, ic in ipairs(b.debuffs) do ic:Hide() end
    for _, ic in ipairs(b.buffs) do ic:Hide() end
    -- preview auras: a couple of debuffs (first one dispellable) and your HoTs
    local deb, buf = GT.Debuffs(), GT.Buffs()
    local DEB_ICONS = { 136118, 136207, 135813 }   -- curse, shadow word: pain, fire
    local BUFF_ICONS = { 135953, 136081, 135907 }  -- renew, rejuv, flash heal
    local nDeb = ({ [2] = 1, [3] = 2, [5] = 3, [7] = 1, [9] = 2 })[(i - 1) % 10 + 1] or 0
    local nBuff = ({ [1] = 2, [2] = 1, [4] = 3, [6] = 1, [8] = 2 })[(i - 1) % 10 + 1] or 0
    if deb.enabled then
        for k = 1, math.min(nDeb, deb.max) do
            local ic = b.debuffs[k]
            ic.icon:SetTexture(DEB_ICONS[k])
            if k == 1 and deb.dispelBorder then ic.border:SetVertexColor(0.2, 0.6, 1, 1) else ic.border:SetVertexColor(0, 0, 0, 1) end
            ic.count:SetText(k == 2 and "3" or ""); ic.cd:Hide(); ic:Show()
        end
    end
    if buf.enabled then
        for k = 1, math.min(nBuff, buf.max) do
            local ic = b.buffs[k]
            ic.icon:SetTexture(BUFF_ICONS[k])
            ic.border:SetVertexColor(0, 0, 0, 1)
            ic.count:SetText(""); ic.cd:Hide(); ic:Show()
        end
    end
    local tc = GT.Look().targetColor or { 1, 0.82, 0.2 }
    b.targetBorder:SetColor(tc[1], tc[2], tc[3], 1)
    b.targetBorder:SetShown(GT.Look().targetHighlight and i == 4)
    -- preview: one frame out of range in party (5) and raid (11), a couple of markers
    GT.ApplyRange(b, not (i == 5 or i == 11))
    b.fakeMarker = ({ [2] = 8, [7] = 1, [14] = 3 })[i]
    GT.UpdateRaidIcon(b)
end

local function FillFakeTarget(t, name, who, mine)
    t.unit = nil
    t.health:SetMinMaxValues(0, 1)
    t.health:SetValue(mine and 0.62 or 0.88)
    t.health:SetStatusBarColor(0.78, 0.18, 0.20)
    t.healthBG:SetVertexColor(0.17, 0.04, 0.04, 1)
    t.name:SetText(name); t.name:SetTextColor(1, 1, 1)
    t.sub:SetText("> " .. who); t.sub:Show()
    t.status:Hide()
    t.htext:SetText(mine and "62%" or "88%"); t.htext:SetShown(GT.Look().healthText ~= "NONE")
    t.aggro:Hide()
    if GT.db.aggro.enabled and mine then
        GT.SetAggroRed(t)
        t.aggroLabel:SetText("YOU"); t.aggroLabel:SetShown(GT.db.aggro.showLabel)
        t.aggro:SetAlpha(1); t.aggro:Show()
    end
end

local MOVER_NAMES = { party = "Party", raid10 = "Raid 10", raid20 = "Raid 20", raid40 = "Raid 40" }
function GT.UpdateMoverLabel()
    if not GT.movers then return end
    local key = GT.ViewKey()
    GT.movers.main.text:SetText((GT.testMode and "Preview: " or "Gram Frames - ") .. (MOVER_NAMES[key] or key))
end

-- test mode previews the layout you're editing in the options
function GT.RefreshTestMode()
    local key = GT.db.general.editLayout
    local L, T = GT.db.layouts[key], GT.db.tank
    GT.movers.main:Restore()   -- jump to where THIS layout lives
    GT.movers.tank:Restore()   -- party and raid tank panels live apart too
    GT.UpdateMoverLabel()
    local holder = GT.testHolder
    if not holder then holder = CreateFrame("Frame", nil, UIParent); GT.testHolder = holder end
    holder:SetScale(L.scale)
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", GT.movers.main, "BOTTOMLEFT", 0, -2)
    holder:SetSize(1, 1)
    local n = SIZES[key] or 5
    -- party with "Show Me" off: preview the other four, without you
    local skip = (key == "party" and L.showPlayer == false) and 1 or 0
    n = n - skip
    local cols = L.direction == "COLUMNS"
    for i = 1, 40 do
        local b = fakes[i]
        if i <= n then
            if not b then
                b = CreateFrame("Button", nil, holder)
                GT.BuildVisuals(b, "unit")
                fakes[i] = b
            end
            b:SetSize(L.width, L.height)
            GT.ApplyLook(b)
            local group, slot
            if L.groupMode == "SEPARATE" then
                group, slot = math.floor((i - 1) / 5), (i - 1) % 5
            else
                group, slot = math.floor((i - 1) / L.unitsPerColumn), (i - 1) % L.unitsPerColumn
            end
            b:ClearAllPoints()
            if cols then
                b:SetPoint("TOPLEFT", holder, "TOPLEFT", group * (L.width + L.groupSpacing), -slot * (L.height + L.spacing))
            else
                b:SetPoint("TOPLEFT", holder, "TOPLEFT", slot * (L.width + L.spacing), -group * (L.height + L.groupSpacing))
            end
            b:Show()
            FillFake(b, i + skip)
        elseif b then
            b:Hide()
        end
    end

    local th = GT.testTankHolder
    if not th then th = CreateFrame("Frame", nil, UIParent); GT.testTankHolder = th end
    th:SetScale(L.scale)
    th:ClearAllPoints()
    th:SetPoint("TOPLEFT", GT.movers.tank, "BOTTOMLEFT", 0, -2)
    th:SetSize(1, 1)
    th:SetShown(T.enabled)
    local tankData = { { 1, "Onyxia", "Grahamaton", true }, { 2, "Onyxian Whelp", "Pewpewz", false } }
    for i, td in ipairs(tankData) do
        local b = fakeTanks[i]
        if not b then
            b = CreateFrame("Button", nil, th)
            GT.BuildVisuals(b, "tank")
            b.targetButton = CreateFrame("Button", nil, b)
            GT.BuildVisuals(b.targetButton, "target")
            fakeTanks[i] = b
        end
        b:SetSize(T.width, T.height)
        GT.ApplyLook(b); GT.ApplyLook(b.targetButton)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", th, "TOPLEFT", 0, -(i - 1) * (T.height + T.spacing))
        FillFake(b, td[1])
        local t = b.targetButton
        t:SetSize(T.targetWidth, T.height)
        t:ClearAllPoints()
        t:SetPoint("LEFT", b, "RIGHT", T.spacing, 0)
        t:SetShown(T.showTargets)
        FillFakeTarget(t, td[2], td[3], td[4])
        b:Show()
    end
end

function GT.SetTestMode(on)
    if InCombatLockdown() then GT.Print("test mode is out-of-combat only") return end
    GT.testMode = on and true or false
    if GT.testMode then
        GT.RefreshTestMode()
        GT.testHolder:Show()
    else
        if GT.testHolder then GT.testHolder:Hide() end
        if GT.testTankHolder then GT.testTankHolder:Hide() end
    end
    GT.UpdateVisibility()
    if not GT.testMode then GT.ConfigureAll() end -- real frames go back to their own layout's look
    GT.Fire("TestModeChanged", GT.testMode)
end
function GT.ToggleTestMode() GT.SetTestMode(not GT.testMode) end

GT.On("CombatStart", function()
    if GT.testMode then
        if GT.testHolder then GT.testHolder:Hide() end
        if GT.testTankHolder then GT.testTankHolder:Hide() end
        GT.testMode = false
        GT.RunOOC("visibility", GT.UpdateVisibility)
        GT.Fire("TestModeChanged", false)
    end
end)

-------------------------------------------------------------------------------
-- Wiring
-------------------------------------------------------------------------------
GT.On("Login", function()
    CreateHeaders()
    GT.HideBlizzard()
end)
GT.On("PLAYER_ENTERING_WORLD", function() GT.HideBlizzard() end)

GT.On("SettingChanged", function(section, key)
    if section == "general" then
        if key == "locked" or key == "hideBar" then GT.UpdateBars(); GT.UpdateVisibility()
        elseif key == "hideSolo" then GT.ConfigureAll()
        elseif key == "editLayout" then if GT.testMode then GT.RefreshTestMode() end
        elseif key ~= "uiScale" and key ~= "lastPage" then GT.HideBlizzard() end
        return
    end
    if (section == "layout" or section == "tank") and key == "pos" then return end
    if section == "minimap" then return end
    -- colors: just repaint (instant, works in combat, no frame rebuild while you drag the picker)
    -- out-of-range look: just re-apply range (instant, combat-safe)
    if section == "layout" and (key == "rangeStyle" or key == "oorColor" or key == "oorTextAlpha" or key == "rangeAlpha") then
        GT.ForEachButton(GT.UpdateRange)
        if GT.testMode and not InCombatLockdown() then GT.RefreshTestMode() end
        return
    end
    if section == "style" and (key == "targetColor" or key == "healthTextColor" or key == "borderColor") then
        local look = GT.Look()
        for b in pairs(GT.buttons) do
            if key == "borderColor" then
                local ec = look.borderColor or { 0, 0, 0 }
                b.bg:SetVertexColor(ec[1], ec[2], ec[3], look.bgAlpha)
            elseif key == "healthTextColor" then
                local hc = look.healthTextColor or { 1, 1, 1 }
                b.htext:SetTextColor(hc[1], hc[2], hc[3])
            elseif b.unit then
                GT.UpdateTargetHighlight(b)
            end
        end
        if GT.testMode and not InCombatLockdown() then GT.RefreshTestMode() end
        return
    end
    if section == "style" and (key == "barTexture" or key == "barColor" or key == "lossColor" or key == "classBG" or key == "matchEUI" or key == "healthColor" or key == "nameColor" or key == "nameCustomColor") then
        for b in pairs(GT.buttons) do
            if key == "barTexture" then GT.ApplyBarTexture(b) end
            if b.unit then GT.UpdateColor(b) end
        end
        if GT.testMode and not InCombatLockdown() then GT.RefreshTestMode() end
        return
    end
    GT.ConfigureAll()
    if not InCombatLockdown() then
        for b in pairs(GT.buttons) do
            GT.ApplyLook(b)
            if b.unit then GT.UpdateAll(b) end
        end
        for t in pairs(GT.targetButtons) do GT.ApplyLook(t) end
    end
end)
