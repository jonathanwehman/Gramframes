-- GramFrames: options window (sidebar + collapsible sections, Cow's Toolkit style)
local _, GT = ...
local UI, C = GT.UI, GT.colors

local W, H = 860, 580
local SIDEBAR_W, HEADER_H = 200, 48
local ROW_H, SECTION_HEADER_H = 32, 30

-------------------------------------------------------------------------------
-- Page definitions
-------------------------------------------------------------------------------
local yes = function() return true end
local isCombined = function() return GT.Get("layout.groupMode") == "COMBINED" end
local isSolid = function() local m = GT.Get("layout.look.healthColor"); return m == "DARK" or m == "CUSTOM" end
local notSolid = function() return not isSolid() end
local showBG = function() return isSolid() or GT.Get("layout.look.classBG") == false end

-- the settings every frame type has; Party Frames and Raid Frames each get their own copy
local function FrameSections(kind)
    local arrangement = {
        { "dropdown", "Groups", "layout.groupMode", { { "SEPARATE", "Separate raid groups" }, { "COMBINED", "One combined grid" } } },
        { "dropdown", "Direction", "layout.direction", { { "COLUMNS", "Groups left to right" }, { "ROWS", "Groups top to bottom" } } },
        { "dropdown", "Sort Inside Group", "layout.sortWithin", { { "ROLE", "Tanks, healers, DPS" }, { "INDEX", "Raid order" } } },
        { "slider", "Units Per Column", "layout.unitsPerColumn", 1, 10, 1, cond = isCombined },
        { "toggle", "Separate Tank Frames", "tank.enabled" },
    }
    if kind == "party" then
        arrangement = {
            { "dropdown", "Direction", "layout.direction", { { "COLUMNS", "Stacked (column)" }, { "ROWS", "Side by side (row)" } } },
            { "dropdown", "Sort", "layout.sortWithin", { { "ROLE", "Tanks, healers, DPS" }, { "INDEX", "Party order" } } },
            { "toggle", "Show Me", "layout.showPlayer" },
            { "toggle", "Hide When Solo", "general.hideSolo" },
            { "toggle", "Separate Tank Frames", "tank.enabled" },
        }
    end
    local out = {}
    if kind == "raid" then
        local sizes = {}
        for _, o in ipairs(GT.LAYOUTS) do if o[1] ~= "party" then sizes[#sizes + 1] = o end end
        out[#out + 1] = { title = "Raid Size", rows = {
            { "dropdown", "Editing", "general.editLayout", sizes },
            { "button", "Copy To Other Raid Sizes", function(btn)
                local key = GT.db.general.editLayout
                local src = GT.db.layouts[key]
                for _, o in ipairs(sizes) do
                    if o[1] ~= key then
                        local pos = GT.db.layouts[o[1]].pos
                        GT.db.layouts[o[1]] = GT.CopyDefaults(src, {})
                        GT.db.layouts[o[1]].pos = pos
                    end
                end
                GT.Fire("SettingChanged", "layout", "copy")
                btn.text:SetText("Copied!")
            end },
        } }
    end
    local rest = {
        { title = "Position", rows = {
            { "info", "", kind == "party"
                and "Party frames have their own spot, separate from raid. Turn on Test Mode on this tab, unlock, and drag the pink bar."
                or "Each raid size has its own spot, separate from party. Turn on Test Mode on this tab, unlock, and drag the pink bar.",
              full = true },
            { "button", "Reset Position", function(btn)
                local L = GT.db.layouts[GT.db.general.editLayout]
                L.pos = kind == "party" and { "CENTER", "UIParent", "CENTER", -480, -40 } or { "CENTER", "UIParent", "CENTER", -360, 60 }
                GT.ConfigureAll()
                if GT.testMode then GT.RefreshTestMode() end
                btn.text:SetText("Reset!")
            end },
        } },
        { title = "Arrangement", rows = arrangement },
        { title = "Size", rows = {
            { "slider", "Width", "layout.width", 40, 200, 1 },
            { "slider", "Height", "layout.height", 20, 100, 1 },
            { "slider", "Spacing", "layout.spacing", 0, 10, 1 },
            { "slider", "Group Spacing", "layout.groupSpacing", 0, 30, 1, cond = function() return kind == "raid" end },
            { "slider", "Scale", "layout.scale", 0.5, 2, 0.05, 2 },
        } },
        { title = "Health Bar", rows = {
            { "dropdown", "Color Mode", "layout.look.healthColor", {
                { "DARK", "Dark mode (pick colors)" }, { "CLASS", "Class colors" }, { "CLASSDARK", "Class colors (dark)" },
                { "GRADIENT", "Health gradient (healer)" } } },
            { "toggle", "Match EllesmereUI", "layout.look.matchEUI", cond = function() return isSolid() and EllesmereUI ~= nil end },
            { "swatch", "Bar Color", "layout.look.barColor", cond = function() return isSolid() and not (EllesmereUI and GT.Get("layout.look.matchEUI")) end },
            { "toggle", "Class-Tinted Background", "layout.look.classBG", cond = notSolid },
            { "swatch", "Background Color", "layout.look.lossColor", cond = showBG },
            { "button", "Reset Colors", function(btn)
                GT.Set("layout.look.barColor", { 0.17, 0.17, 0.17 })
                GT.Set("layout.look.lossColor", { 0.62, 0.05, 0.07 })
                GT.Set("layout.look.classBG", true)
                GT.RefreshOptions()
            end },
            { "dropdown", "Bar Texture", "layout.look.barTexture", "TEXTURES" },
            { "slider", "Border Opacity", "layout.look.bgAlpha", 0, 1, 0.05, 2 },
        } },
        { title = "Text", rows = {
            { "dropdown", "Font", "layout.look.font", "FONTS" },
            { "dropdown", "Name Color", "layout.look.nameColor", { { "CLASS", "Class color" }, { "WHITE", "White" } } },
            { "slider", "Name Size", "layout.look.nameSize", 8, 20, 1 },
            { "dropdown", "Health Text", "layout.look.healthText", { { "NONE", "None" }, { "PERCENT", "Percent" }, { "MISSING", "Missing health" } } },
            { "slider", "Health Text Size", "layout.look.healthTextSize", 8, 18, 1 },
        } },
        { title = "Power", rows = {
            { "dropdown", "Power Bar", "layout.look.powerBar", { { "NONE", "Off" }, { "HEALERS", "Healers only" }, { "ALL", "Everyone" } } },
            { "slider", "Power Bar Height", "layout.look.powerHeight", 1, 10, 1 },
        } },
        { title = "Buffs", rows = {
            { "toggle", "Show Buffs", "layout.buffs.enabled" },
            { "dropdown", "Which Buffs", "layout.buffs.filter", { { "MINE", "Ones I cast (HoTs, blessings)" }, { "RAID", "Raid-frame buffs" } } },
            { "slider", "Buff Size", "layout.buffs.size", 8, 30, 1 },
            { "slider", "Max Buffs", "layout.buffs.max", 1, 6, 1 },
        } },
        { title = "Debuffs", rows = {
            { "toggle", "Show Debuffs", "layout.debuffs.enabled" },
            { "toggle", "Color Dispellable", "layout.debuffs.dispelBorder" },
            { "slider", "Debuff Size", "layout.debuffs.size", 8, 30, 1 },
            { "slider", "Max Debuffs", "layout.debuffs.max", 1, 6, 1 },
        } },
        { title = "Icons", rows = {
            { "toggle", "Role Icons", "layout.look.roleIcon" },
            { "slider", "Role Icon Size", "layout.look.roleSize", 6, 20, 1 },
            { "toggle", "Hide DPS Icon", "layout.look.hideDPSIcon" },
            { "toggle", "Leader Icon", "layout.look.leaderIcon" },
            { "toggle", "Raid Markers", "layout.look.raidIcon" },
            { "toggle", "Highlight My Target", "layout.look.targetHighlight" },
            { "slider", "Out of Range Opacity", "layout.look.rangeAlpha", 0.1, 1, 0.05, 2 },
        } },
    }
    for _, sec in ipairs(rest) do out[#out + 1] = sec end
    return out
end

local pages = {
    { key = "party", group = "Frames", title = "Party Frames", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
      editKey = "party",
      desc = "Solo and 5-man. Everything here only changes your party frames.",
      sections = FrameSections("party") },
    { key = "raid", group = "Frames", title = "Raid Frames", icon = "Interface\\Icons\\INV_Misc_GroupLooking",
      editKey = "raid",
      desc = "10, 20 and 40-man each have their own setup and switch by themselves.",
      sections = FrameSections("raid") },
    { key = "clicks", group = "Controls", title = "Click-Casting", icon = "Interface\\Icons\\INV_Gauntlets_04",
      desc = "Bind spells to clicks on frames. Pick a rank to downrank - Max always casts your best.",
      sections = {
        { title = "Bindings", custom = function(parent, width) return GT.BuildClickRows(parent, width) end },
      } },
    { key = "tank", group = "Tank", title = "Tank Panel", icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
      toggle = "tank.enabled",
      desc = "Every tank plus what they're hitting. Click a target to grab it, pink = you hold it.",
      sections = {
        { title = "Panel", rows = {
            { "toggle", "Show Tank Targets", "tank.showTargets" },
            { "toggle", "Include Main Tanks", "tank.includeMainTanks" },
            { "slider", "Tank Width", "tank.width", 60, 220, 1 },
            { "slider", "Target Width", "tank.targetWidth", 60, 220, 1 },
            { "slider", "Height", "tank.height", 20, 80, 1 },
            { "slider", "Spacing", "tank.spacing", 0, 12, 1 },
        } },
      } },
    { key = "aggro", group = "Tank", title = "Aggro Alerts", icon = "Interface\\Icons\\Spell_Nature_Reincarnation",
      toggle = "aggro.enabled",
      desc = "Know who to taunt off of. Red = a healer or DPS has aggro, orange = they're close.",
      sections = {
        { title = "Warnings", rows = {
            { "toggle", "Warn When Healer/DPS Pulls", "aggro.warnNonTanks" },
            { "toggle", "Warn When a Tank Is Losing It", "aggro.showLosingOnTanks" },
            { "toggle", "Show AGGRO / LOSING Labels", "aggro.showLabel" },
            { "slider", "Border Thickness", "aggro.thickness", 1, 5, 1 },
        } },
      } },
    { key = "healermana", group = "Tank", title = "Healer Mana", icon = "Interface\\Icons\\INV_Potion_76",
      toggle = "healerMana.enabled",
      desc = "Your healers' mana beside the frames. White = fine, blue = getting low, red = out soon.",
      sections = {
        { title = "Show", rows = {
            { "toggle", "In Party", "healerMana.showParty" },
            { "toggle", "In Raid", "healerMana.showRaid" },
        } },
        { title = "Text", rows = {
            { "slider", "Text Size", "healerMana.size", 8, 20, 1 },
            { "slider", "Line Spacing", "healerMana.spacing", 0, 10, 1 },
            { "slider", "Distance From Frames", "healerMana.x", -20, 60, 1 },
            { "slider", "Move Up / Down", "healerMana.y", -100, 100, 1 },
        } },
        { title = "Colors", rows = {
            { "swatch", "Plenty of Mana", "healerMana.highColor" },
            { "swatch", "Getting Low", "healerMana.midColor" },
            { "slider", "Getting Low At %", "healerMana.midBelow", 10, 90, 5 },
            { "swatch", "Low Mana", "healerMana.lowColor" },
            { "slider", "Low At %", "healerMana.lowBelow", 5, 50, 5 },
            { "button", "Reset Colors", function()
                GT.Set("healerMana.highColor", { 1, 1, 1 })
                GT.Set("healerMana.midColor", { 0.25, 0.55, 1 })
                GT.Set("healerMana.lowColor", { 1, 0.15, 0.15 })
                GT.Set("healerMana.midBelow", 50)
                GT.Set("healerMana.lowBelow", 25)
                GT.RefreshOptions()
            end },
        } },
      } },
    { key = "general", group = "Setup", title = "General", icon = "Interface\\Icons\\INV_Misc_Gear_01",
      desc = "Lock, minimap button, Blizzard frames and reset. /gf opens this window.",
      sections = {
        { title = "Frames", rows = {
            { "toggle", "Lock Frames", "general.locked" },
            { "toggle", "Hide When Solo", "general.hideSolo" },
            { "toggle", "Hide Frame Bar", "general.hideBar" },
            { "toggle", "Hide Minimap Button", "minimap.hide" },
        } },
        { title = "Blizzard Frames", rows = {
            { "toggle", "Hide Blizzard Party Frames", "general.hideBlizzParty" },
            { "toggle", "Hide Blizzard Raid Frames", "general.hideBlizzRaid" },
            { "toggle", "Hide Raid Manager", "general.hideRaidManager" },
        } },
        { title = "Profile", rows = {
            { "button", "Reset Everything", function(btn)
                if btn.armed then
                    SlashCmdList.GRAMFRAMES("reset")
                    btn.armed = false
                    btn.text:SetText("Reset Everything")
                    GT.RefreshOptions()
                else
                    btn.armed = true
                    btn.text:SetText("Click again to confirm")
                end
            end },
            { "info", "Commands", "/gf  -  /gf test  -  /gf lock  -  /gf minimap" },
        } },
      } },
}

-------------------------------------------------------------------------------
-- Click-casting rows (custom section)
-------------------------------------------------------------------------------
function GT.BuildClickRows(parent, width)
    local y = 0
    -- everything has to fit, Rank included: the spell column takes what's left
    local cols = { 95, 95, 125, 0, 80 }
    local function spare() return width - (cols[1] + cols[2] + cols[3] + cols[5] + 22 + 6 * 6) end
    if spare() < 130 then cols[1], cols[2], cols[3], cols[5] = 80, 80, 110, 74 end
    cols[4] = math.max(110, spare())
    local function header(text, x, w)
        local fs = UI.Font(parent, 11, C.muted)
        fs:SetPoint("TOPLEFT", x, -y)
        fs:SetWidth(w)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
    end
    local xs, x = {}, 6
    for i, w in ipairs(cols) do xs[i] = x; x = x + w + 6 end
    header("Modifier", xs[1], cols[1]); header("Mouse", xs[2], cols[2]); header("Action", xs[3], cols[3])
    header("Spell / Macro", xs[4], cols[4]); header("Rank", xs[5], cols[5])
    y = y + 18
    local rebuild = function() GT.ApplyAllClicks(); GT.ShowPage("clicks") end
    for i, bnd in ipairs(GT.db.clicks.bindings) do
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetSize(width, 26)
        if i % 2 == 0 then UI.Fill(row, { 1, 1, 1 }, 0.025) end
        local function dd(col, opts, get, set)
            local d = UI.Dropdown(row, opts, get, set)
            d:SetWidth(cols[col]); d:SetPoint("LEFT", xs[col], 0)
            return d
        end
        dd(1, GT.MODS, function() return bnd.mod end, function(v) bnd.mod = v; GT.ApplyAllClicks() end)
        dd(2, GT.MOUSE, function() return bnd.button end, function(v) bnd.button = v; GT.ApplyAllClicks() end)
        dd(3, GT.ACTIONS, function() return bnd.action end, function(v) bnd.action = v; bnd.value = ""; bnd.rank = "MAX"; rebuild() end)
        if bnd.action == "SPELL" then
            if #GT.SpellOptions() > 0 and GT.SpellOptions()[1][1] ~= "" then
                dd(4, GT.SpellOptions, function() return bnd.value end, function(v) bnd.value = v; bnd.rank = "MAX"; rebuild() end)
            else
                local box = UI.Input(row, function() return bnd.value end, function(v) bnd.value = v; GT.ApplyAllClicks() end, "Spell name")
                box:SetWidth(cols[4]); box:SetPoint("LEFT", xs[4], 0)
            end
            dd(5, function() return GT.RankOptions(bnd.value) end, function() return bnd.rank or "MAX" end,
                function(v) bnd.rank = v; GT.ApplyAllClicks() end)
        elseif bnd.action == "MACRO" then
            local box = UI.Input(row, function() return bnd.value end, function(v) bnd.value = v; GT.ApplyAllClicks() end, "/cast [@mouseover] Spell")
            box:SetWidth(cols[4] + cols[5] + 6); box:SetPoint("LEFT", xs[4], 0)
        end
        local del = CreateFrame("Button", nil, row)
        del:SetSize(22, 22)
        del:SetPoint("LEFT", xs[5] + cols[5] + 6, 0)
        del.t = UI.Font(del, 14, C.muted)
        del.t:SetPoint("CENTER")
        del.t:SetText("x")
        del:SetScript("OnEnter", function(s2) s2.t:SetTextColor(1, 0.3, 0.3) end)
        del:SetScript("OnLeave", function(s2) s2.t:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
        del:SetScript("OnClick", function() GT.RemoveBinding(i); GT.ShowPage("clicks") end)
        y = y + 28
    end
    local add = UI.Button(parent, "+ Add Binding", function() GT.AddBinding(); GT.ShowPage("clicks") end, 150)
    add:SetPoint("TOPLEFT", 6, -(y + 6))
    local tip = UI.Font(parent, 11, C.muted)
    tip:SetPoint("LEFT", add, "RIGHT", 12, 0)
    tip:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
    tip:SetJustifyH("LEFT")
    tip:SetWordWrap(true)
    tip:SetText("Downrank: pick a lower rank for cheaper heals. Changes apply out of combat.")
    return y + 40
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
local win, content, scroll, sidebarItems, currentPage, searchText
local sectionsCollapsed = {}

local function Matches(label)
    if not searchText or searchText == "" then return true end
    return label:lower():find(searchText, 1, true) ~= nil
end

local function PageMatches(page)
    if not searchText or searchText == "" then return true end
    if Matches(page.title) then return true end
    for _, sec in ipairs(page.sections) do
        if Matches(sec.title) then return true end
        for _, row in ipairs(sec.rows or {}) do
            if Matches(row[2]) then return true end
        end
    end
    return false
end

local function MakeControl(parent, row)
    local kind = row[1]
    if kind == "toggle" then
        return UI.Toggle(parent, function() return GT.Get(row[3]) end, function(v) GT.Set(row[3], v) end)
    elseif kind == "slider" then
        return UI.Slider(parent, row[4], row[5], row[6], function() return GT.Get(row[3]) end,
            function(v) GT.Set(row[3], v) end, row[7])
    elseif kind == "dropdown" then
        local opts = (row[4] == "FONTS" and GT.FontOptions()) or (row[4] == "TEXTURES" and GT.TextureOptions()) or row[4]
        return UI.Dropdown(parent, opts, function() return GT.Get(row[3]) end, function(v)
            GT.Set(row[3], v)
            if currentPage then GT.ShowPage(currentPage.key) end -- conditional rows may change
        end)
    elseif kind == "input" then
        return UI.Input(parent, function() return GT.Get(row[3]) end, function(v) GT.Set(row[3], v) end, row[4])
    elseif kind == "swatch" then
        return UI.Swatch(parent, function() return GT.Get(row[3]) end, function(v) GT.Set(row[3], v) end)
    elseif kind == "button" then
        return UI.Button(parent, row[2], row[3], 190)
    elseif kind == "info" then
        local fs = UI.Font(parent, 12, C.muted)
        fs:SetText(row[3])
        if row.full then
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", parent, "LEFT", 6, 0)
            fs:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
            fs:SetJustifyH("LEFT")
        end
        return fs
    end
end

-- Each page is built once, then re-laid out (search, collapse, conditional rows).
local function BuildPage(page)
    if page.holder then return end
    local holder = CreateFrame("Frame", nil, content)
    holder:SetPoint("TOPLEFT")
    holder:SetPoint("TOPRIGHT")
    holder:SetHeight(1)
    page.holder = holder
    local colW = math.floor((content:GetWidth() - 36) / 2)
    for si, sec in ipairs(page.sections) do
        sec.key = page.key .. si
        local box = CreateFrame("Frame", nil, holder)
        UI.Fill(box, C.row, 0.55)
        sec.box = box
        local head = CreateFrame("Button", nil, box)
        head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT")
        head:SetHeight(SECTION_HEADER_H)
        UI.Fill(head, { 0.15, 0.142, 0.17 })
        local ht = UI.Font(head, 13, C.accent)
        ht:SetPoint("LEFT", 12, 0)
        ht:SetText(sec.title)
        sec.chev = UI.Font(head, 12, C.muted)
        sec.chev:SetPoint("RIGHT", -12, 0)
        head:SetScript("OnClick", function()
            sectionsCollapsed[sec.key] = not sectionsCollapsed[sec.key]
            GT.ShowPage(page.key)
        end)
        sec.frames = {}
        for ri, row in ipairs(sec.rows or {}) do
            local r = CreateFrame("Frame", nil, box)
            r:SetSize(colW, ROW_H)
            r.stripe = UI.Fill(r, { 1, 1, 1 }, 0.025)
            local label = UI.Font(r, 12, C.muted)
            label:SetJustifyH("LEFT")
            if label.SetWordWrap then label:SetWordWrap(false) end
            label:SetText((row[1] == "button") and "" or row[2])
            local ctl = MakeControl(r, row)
            r.full = row.full
            -- switches and color swatches keep their own small size; everything else gets a fixed column
            if row[1] ~= "info" and row[1] ~= "swatch" and row[1] ~= "toggle" then
                ctl:SetWidth(math.min(170, math.floor(colW * 0.5)))
            end
            if not row.full then
                ctl:SetPoint("RIGHT", -10, 0)
                label:SetPoint("LEFT", 6, 0)
                label:SetPoint("RIGHT", ctl, "LEFT", -10, 0)
            end
            r.ctl = ctl
            sec.frames[ri] = r
        end
    end
end

local function LayoutPage(page)
    local colW = math.floor((content:GetWidth() - 36) / 2)
    local y = 0
    for _, sec in ipairs(page.sections) do
        if sec.custom then
            -- custom sections (click-casting) rebuild their content every time
            if sec.inner then sec.inner:Hide(); sec.inner:SetParent(nil) end
            local inner = CreateFrame("Frame", nil, sec.box)
            sec.inner = inner
            local collapsed = sectionsCollapsed[sec.key]
            sec.chev:SetText(collapsed and ">" or "v")
            local w = content:GetWidth() - 20
            inner:SetPoint("TOPLEFT", 10, -(SECTION_HEADER_H + 8))
            inner:SetSize(w, 10)
            local h = collapsed and 0 or (sec.custom(inner, w) + 10)
            inner:SetShown(not collapsed)
            sec.box:Show()
            sec.box:ClearAllPoints()
            sec.box:SetPoint("TOPLEFT", 0, -y)
            sec.box:SetPoint("TOPRIGHT", 0, -y)
            sec.box:SetHeight(SECTION_HEADER_H + h)
            y = y + SECTION_HEADER_H + h + 10
        end
        local visible = {}
        for ri, row in ipairs(sec.rows or {}) do
            local r = sec.frames[ri]
            local show = (not row.cond or row.cond()) and (Matches(row[2]) or Matches(sec.title) or Matches(page.title))
            r:SetShown(show)
            if show then
                visible[#visible + 1] = r
                if r.ctl.Refresh then r.ctl:Refresh() end
            end
        end
        if sec.custom then
            -- handled above
        elseif #visible == 0 then
            sec.box:Hide()
        else
            local collapsed = sectionsCollapsed[sec.key]
            sec.chev:SetText(collapsed and ">" or "v")
            sec.box:Show()
            sec.box:ClearAllPoints()
            sec.box:SetPoint("TOPLEFT", 0, -y)
            sec.box:SetPoint("TOPRIGHT", 0, -y)
            local bodyH = 0
            if collapsed then
                for _, r in ipairs(visible) do r:Hide() end
            else
                -- two columns; "full" rows (notes) take a whole line
                local slot = 0
                for _, r in ipairs(visible) do
                    if r.full and slot % 2 == 1 then slot = slot + 1 end
                    local col, line = slot % 2, math.floor(slot / 2)
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", 10 + col * (colW + 12), -(SECTION_HEADER_H + 6 + line * ROW_H))
                    r:SetWidth(r.full and (colW * 2 + 12) or colW)
                    r.stripe:SetShown(line % 2 == 1)
                    slot = slot + (r.full and 2 or 1)
                end
                bodyH = 6 + math.ceil(slot / 2) * ROW_H + 8
            end
            sec.box:SetHeight(SECTION_HEADER_H + bodyH)
            y = y + SECTION_HEADER_H + bodyH + 10
        end
    end
    page.holder:SetHeight(math.max(y, 1))
    return y
end

function GT.ShowPage(key)
    if not win then return end
    local page
    for _, p in ipairs(pages) do if p.key == key then page = p end end
    page = page or pages[1]
    currentPage = page
    GT.db.general.lastPage = page.key
    -- Party Frames / Raid Frames tabs decide which layout the controls edit
    local G = GT.db.general
    if page.editKey == "party" and G.editLayout ~= "party" then
        if G.editLayout ~= "party" then G.lastRaid = G.editLayout end
        GT.Set("general.editLayout", "party")
    elseif page.editKey == "raid" and G.editLayout == "party" then
        local want = G.lastRaid
        local active = GT.ActiveLayoutKey()
        if active ~= "party" then want = active end
        GT.Set("general.editLayout", (want and GT.db.layouts[want] and want ~= "party") and want or "raid20")
    end

    for _, item in ipairs(sidebarItems) do
        local sel = item.page == page
        item.sel:SetShown(sel)
        item.bar:SetShown(sel)
        local match = PageMatches(item.page)
        local v = sel and 1 or (match and C.text[1] or 0.4)
        item.label:SetTextColor(v, v, sel and 1 or (match and C.text[3] or 0.42))
        item.icon:SetAlpha(match and 1 or 0.35)
        if item.toggle then item.toggle:Refresh() end
    end

    win.pageIcon:SetTexture(page.icon)
    win.pageTitle:SetText(page.title)
    win.pageDesc:SetText(page.desc)

    for _, p in ipairs(pages) do if p.holder then p.holder:Hide() end end
    BuildPage(page)
    page.holder:Show()
    local y = LayoutPage(page)
    win.noMatch:SetShown(y == 0)
    if y == 0 then win.noMatch:SetText("Nothing here matches \"" .. (searchText or "") .. "\"") end
    content:SetHeight(math.max(y, 1))
    scroll:SetVerticalScroll(0)
end

function GT.RefreshOptions()
    if win and win:IsShown() and currentPage then
        GT.ShowPage(currentPage.key)
        win.lockToggle:Refresh()
        win.scaleSlider:Refresh()
    end
end

local function CreateWindow()
    win = CreateFrame("Frame", "GramFramesOptions", UIParent)
    win:SetSize(W, H)
    win:SetPoint("CENTER")
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:SetClampedToScreen(true)
    win:SetScale(GT.db.general.uiScale)
    UI.Fill(win, C.bg, 0.97)
    UI.Outline(win, C.border)
    tinsert(UISpecialFrames, "GramFramesOptions")

    -- header bar ------------------------------------------------------------
    local header = CreateFrame("Frame", nil, win)
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_H)
    UI.Fill(header, { 0.06, 0.057, 0.068 })
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() win:StartMoving() end)
    header:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)
    local line = UI.Tex(header, "ARTWORK", C.accent, 0.35)
    line:SetHeight(1); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(GT.media .. "emblem")
    logo:SetSize(38, 38)
    logo:SetPoint("LEFT", 10, 0)
    local title = UI.Font(header, 17, C.accent)
    title:SetPoint("LEFT", logo, "RIGHT", 8, 1)
    title:SetText("GRAM")
    local title2 = UI.Font(header, 17, { 1, 1, 1 })
    title2:SetPoint("LEFT", title, "RIGHT", 6, 0)
    title2:SetText("Frames")

    local close = CreateFrame("Button", nil, header)
    close:SetSize(28, 28)
    close:SetPoint("RIGHT", -10, 0)
    close.t = UI.Font(close, 16, C.muted)
    close.t:SetPoint("CENTER")
    close.t:SetText("x")
    close:SetScript("OnEnter", function(s) s.t:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function(s) s.t:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    close:SetScript("OnClick", function() win:Hide() end)

    local scale = UI.Slider(header, 0.7, 1.5, 0.05, function() return GT.db.general.uiScale end, function(v)
        GT.db.general.uiScale = v
    end, 2)
    scale:SetWidth(200)
    scale:SetPoint("RIGHT", close, "LEFT", -16, 0)
    scale.slider:SetScript("OnMouseUp", function() win:SetScale(GT.db.general.uiScale) end)
    scale.box:HookScript("OnEnterPressed", function() win:SetScale(GT.db.general.uiScale) end)
    win.scaleSlider = scale
    local scaleLabel = UI.Font(header, 12, C.muted)
    scaleLabel:SetPoint("RIGHT", scale, "LEFT", -10, 0)
    scaleLabel:SetText("Scale")

    -- sidebar ---------------------------------------------------------------
    local side = CreateFrame("Frame", nil, win)
    side:SetPoint("TOPLEFT", 0, -HEADER_H)
    side:SetPoint("BOTTOMLEFT")
    side:SetWidth(SIDEBAR_W)
    UI.Fill(side, C.sidebar)
    local sep = UI.Tex(side, "ARTWORK", C.border)
    sep:SetWidth(1); sep:SetPoint("TOPRIGHT"); sep:SetPoint("BOTTOMRIGHT")

    sidebarItems = {}
    local y, lastGroup = -12, nil
    for _, page in ipairs(pages) do
        if page.group ~= lastGroup then
            if lastGroup then y = y - 8 end
            local g = UI.Font(side, 11, C.muted)
            g:SetPoint("TOPLEFT", 16, y)
            g:SetText(page.group)
            y = y - 20
            lastGroup = page.group
        end
        local item = CreateFrame("Button", nil, side)
        item:SetPoint("TOPLEFT", 8, y)
        item:SetPoint("TOPRIGHT", -8, y)
        item:SetHeight(30)
        item.page = page
        item.sel = UI.Tex(item, "BACKGROUND", { 0.17, 0.16, 0.21 })
        item.sel:SetAllPoints()
        item.bar = UI.Tex(item, "ARTWORK", C.accent)
        item.bar:SetWidth(3)
        item.bar:SetPoint("TOPLEFT"); item.bar:SetPoint("BOTTOMLEFT")
        item.hover = UI.Tex(item, "BACKGROUND", { 1, 1, 1 }, 0.04)
        item.hover:SetAllPoints(); item.hover:Hide()
        item.icon = item:CreateTexture(nil, "ARTWORK")
        item.icon:SetSize(18, 18)
        item.icon:SetPoint("LEFT", 12, 0)
        item.icon:SetTexture(page.icon)
        item.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        item.label = UI.Font(item, 13)
        item.label:SetPoint("LEFT", item.icon, "RIGHT", 10, 0)
        item.label:SetText(page.title)
        if page.toggle then
            item.toggle = UI.Toggle(item, function() return GT.Get(page.toggle) end, function(v) GT.Set(page.toggle, v) end)
            item.toggle:SetPoint("RIGHT", -8, 0)
        end
        item:SetScript("OnEnter", function(s) s.hover:Show() end)
        item:SetScript("OnLeave", function(s) s.hover:Hide() end)
        item:SetScript("OnClick", function() GT.ShowPage(page.key) end)
        sidebarItems[#sidebarItems + 1] = item
        y = y - 32
    end
    local ver = UI.Font(side, 10, C.muted)
    ver:SetPoint("BOTTOMLEFT", 16, 12)
    ver:SetText("v" .. GT.version .. "  -  for WoW Forever")

    -- main area -------------------------------------------------------------
    local main = CreateFrame("Frame", nil, win)
    main:SetPoint("TOPLEFT", SIDEBAR_W, -HEADER_H)
    main:SetPoint("BOTTOMRIGHT")

    win.pageIcon = main:CreateTexture(nil, "ARTWORK")
    win.pageIcon:SetSize(30, 30)
    win.pageIcon:SetPoint("TOPLEFT", 18, -16)
    win.pageIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    win.pageTitle = UI.Font(main, 18, { 1, 1, 1 })
    win.pageTitle:SetPoint("TOPLEFT", win.pageIcon, "TOPRIGHT", 10, 1)
    win.pageDesc = UI.Font(main, 12, C.muted)
    win.pageDesc:SetPoint("TOPLEFT", win.pageTitle, "BOTTOMLEFT", 0, -4)
    win.pageDesc:SetPoint("RIGHT", main, "RIGHT", -230, 0)
    win.pageDesc:SetJustifyH("LEFT")

    local search = UI.Input(main, function() return searchText or "" end, function() end, "Search options")
    search:SetSize(200, 26)
    search:SetPoint("TOPRIGHT", -18, -18)
    search:SetScript("OnTextChanged", function(self)
        self.ph:SetShown(self:GetText() == "")
        searchText = self:GetText():lower()
        -- jump to a page that has a hit
        if currentPage and not PageMatches(currentPage) then
            for _, p in ipairs(pages) do
                if PageMatches(p) then GT.ShowPage(p.key) return end
            end
        end
        GT.ShowPage(currentPage and currentPage.key or "party")
    end)
    search:SetScript("OnEditFocusLost", nil)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- action bar
    local bar = CreateFrame("Frame", nil, main)
    bar:SetPoint("TOPLEFT", 18, -62)
    bar:SetPoint("TOPRIGHT", -18, -62)
    bar:SetHeight(40)
    UI.Fill(bar, C.row, 0.8)
    local test = UI.Button(bar, "Test Mode", function(b)
        GT.ToggleTestMode()
    end, 130)
    test:SetPoint("CENTER", -70, 0)
    win.testButton = test
    local lockBtn = UI.Button(bar, "Lock / Unlock", function()
        GT.Set("general.locked", not GT.db.general.locked)
        win.lockToggle:Refresh()
    end, 130)
    lockBtn:SetPoint("LEFT", test, "RIGHT", 10, 0)
    local lockLabel = UI.Font(bar, 12, C.muted)
    lockLabel:SetText("Lock")
    win.lockToggle = UI.Toggle(bar, function() return GT.db.general.locked end, function(v) GT.Set("general.locked", v) end)
    win.lockToggle:SetPoint("RIGHT", -12, 0)
    lockLabel:SetPoint("RIGHT", win.lockToggle, "LEFT", -8, 0)

    -- scrolling content
    scroll = CreateFrame("ScrollFrame", nil, main)
    scroll:SetPoint("TOPLEFT", 18, -112)
    scroll:SetPoint("BOTTOMRIGHT", -18, 14)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(W - SIDEBAR_W - 36, 10)
    scroll:SetScrollChild(content)
    win.noMatch = UI.Font(content, 12, C.muted)
    win.noMatch:SetPoint("TOPLEFT", 8, -8)
    win.noMatch:Hide()
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40)))
    end)

    win:SetScript("OnHide", function()
        local m = UI.GetMenu(); if m then m:Hide() end
    end)

    GT.On("TestModeChanged", function(on)
        test:SetActive(on)
        test.text:SetText(on and "Test Mode: ON" or "Test Mode")
    end)
    GT.On("SettingChanged", function(section, key)
        if section == "general" and key == "locked" and win.lockToggle then win.lockToggle:Refresh() end
        -- the class-tint switch shows/hides the Background Color picker
        if (key == "classBG" or key == "matchEUI") and win:IsShown() and currentPage then GT.ShowPage(currentPage.key) end
        local isColor = key == "barTexture" or key == "barColor" or key == "lossColor" or key == "classBG" or key == "matchEUI" or key == "healthColor" or key == "nameColor"
        if isColor then return end -- colors repaint instantly and work in combat; Headers already did it
        if GT.testMode and not InCombatLockdown() then GT.RefreshTestMode() end
        if InCombatLockdown() and not GT.warnedCombat then
            GT.warnedCombat = true
            GT.Print("you're in combat - frame changes will apply when it ends")
        end
    end)
    GT.On("CombatEnd", function() GT.warnedCombat = false end)
    win:Hide() -- frames start shown; ToggleOptions decides
    -- "Hide Frame Bar" lets the bar peek out only while this window is open
    win:HookScript("OnShow", function() if GT.UpdateBars then GT.UpdateBars() end end)
    win:HookScript("OnHide", function() if GT.UpdateBars then GT.UpdateBars() end end)
end

function GT.ToggleOptions()
    if not GT.db then return end
    if not win then CreateWindow() end
    if win:IsShown() then
        win:Hide()
    else
        win:Show()
        GT.ShowPage(GT.db.general.lastPage)
    end
end
