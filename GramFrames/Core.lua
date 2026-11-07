-- GramFrames: tank-focused raid frames for World of Warcraft: Forever
-- Core: namespace, saved settings, secret-value helpers, events, slash commands.
local ADDON, GT = ...
_G.GramFrames = GT

GT.version = "2.1.2"
GT.media = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
GT.FLAT = "Interface\\Buttons\\WHITE8X8"
GT.FONT = "Fonts\\ARIALN.TTF" -- fallback; the chosen font comes from GT.GetFont()

-------------------------------------------------------------------------------
-- Fonts. Built-ins always exist; Expressway needs the .ttf on disk, so we look
-- in our own Media\Fonts folder first, then the places other addons keep it.
-------------------------------------------------------------------------------
local ADDON_FONTS = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Fonts\\"
GT.fontChoices = {
    { "Expressway", "Expressway", {
        ADDON_FONTS .. "Expressway.ttf",
        "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF",
        "Interface\\AddOns\\ElvUI\\Core\\Media\\Fonts\\Expressway.ttf",
        "Interface\\AddOns\\ElvUI\\Media\\Fonts\\Expressway.ttf",
        "Interface\\AddOns\\SharedMedia_MyMedia\\font\\Expressway.ttf",
    } },
    { "ArialNarrow", "Arial Narrow", { "Fonts\\ARIALN.TTF" } },
    { "Friz", "Friz Quadrata (WoW default)", { "Fonts\\FRIZQT__.TTF" } },
    { "Morpheus", "Morpheus", { "Fonts\\MORPHEUS.TTF" } },
    { "Skurri", "Skurri", { "Fonts\\SKURRI.TTF" } },
}

-- Can the client actually load this file? A fresh FontString has no font, so
-- if SetFont fails GetFont stays nil.
local probeFrame
local function CanLoad(path)
    probeFrame = probeFrame or CreateFrame("Frame")
    local fs = probeFrame:CreateFontString()
    local ok, res = pcall(fs.SetFont, fs, path, 12, "")
    if not ok or res == false then return false end
    return fs:GetFont() ~= nil
end

local resolved = {}
function GT.ResolveFont(key)
    if resolved[key] ~= nil then return resolved[key] end
    resolved[key] = false
    for _, choice in ipairs(GT.fontChoices) do
        if choice[1] == key then
            for _, path in ipairs(choice[3]) do
                if CanLoad(path) then resolved[key] = path break end
            end
        end
    end
    -- fonts registered by other addons through LibSharedMedia
    if not resolved[key] and LibStub then
        local LSM = LibStub("LibSharedMedia-3.0", true)
        local path = LSM and LSM:Fetch("font", key, true)
        if path and CanLoad(path) then resolved[key] = path end
    end
    return resolved[key]
end

-- dropdown list: our choices + anything LibSharedMedia knows about
function GT.FontOptions()
    local out, seen = {}, {}
    for _, c in ipairs(GT.fontChoices) do
        out[#out + 1] = { c[1], c[2] }
        seen[c[1]] = true
        seen[c[2]] = true
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            if not seen[name] then out[#out + 1] = { name, name } end
        end
    end
    return out
end

local warnedMissing
function GT.GetFont()
    local key = GT.db and GT.Look().font or "Expressway"
    local path = GT.ResolveFont(key)
    if not path then
        if GT.db and not warnedMissing and key == "Expressway" then
            warnedMissing = true
            GT.Print("Expressway.ttf not found - put it in Interface\\AddOns\\GramFrames\\Media\\Fonts\\ and fully restart WoW. Using Arial Narrow for now.")
        end
        return GT.FONT
    end
    return path
end

-- Every font in the addon goes through here so a font change can redo them all.
local fontRegistry = setmetatable({}, { __mode = "k" })
function GT.SetFont(fs, size, flags)
    fontRegistry[fs] = { size, flags or "" }
    fs:SetFont(GT.GetFont(), size, flags or "")
end
function GT.ApplyFonts()
    local path = GT.GetFont()
    for fs, spec in pairs(fontRegistry) do
        fs:SetFont(path, spec[1], spec[2])
    end
end

-- brand colors (pulled from the logo)
GT.colors = {
    accent    = { 1.00, 0.31, 0.64 },   -- hot pink
    accentDim = { 0.62, 0.20, 0.42 },
    text      = { 0.92, 0.91, 0.94 },
    muted     = { 0.60, 0.58, 0.64 },
    bg        = { 0.075, 0.072, 0.085 },
    panel     = { 0.105, 0.100, 0.118 },
    sidebar   = { 0.090, 0.086, 0.100 },
    row       = { 0.130, 0.124, 0.145 },
    border    = { 0.20, 0.19, 0.22 },
}

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------
-- one layout per group size; switches automatically
-- each layout (party / 10 / 20 / 40) carries its own look, buffs and debuffs
local VIEW_DEFAULTS = {
    look = {
        font = "Expressway",
        healthColor = "DARK",       -- DARK | CLASS | CLASSDARK | GRADIENT | CUSTOM
        barColor = { 0.17, 0.17, 0.17 },
        lossColor = { 0.62, 0.05, 0.07 },
        classBG = true,             -- class modes: tint the background with the class color (off = Background Color)
        nameColor = "CLASS",        -- CLASS | WHITE
        nameSize = 12,
        healthText = "NONE",        -- NONE | PERCENT | MISSING
        healthTextSize = 10,
        powerBar = "NONE",          -- ALL | HEALERS | NONE
        powerHeight = 3,
        rangeAlpha = 0.40,
        roleIcon = true,
        roleSize = 10,
        leaderIcon = true,
        raidIcon = true,
        targetHighlight = true,
        bgAlpha = 1,
    },
    buffs = {
        enabled = true,
        filter = "MINE",            -- MINE: buffs you cast | RAID: Blizzard's raid-frame buff list
        size = 14,
        max = 3,
    },
    debuffs = {
        enabled = true,
        size = 16,
        max = 3,
        dispelBorder = true,
    },
}

local function LayoutDefaults(x, y, scale)
    return {
        width = 72, height = 42, spacing = 2, groupSpacing = 4,
        groupMode = "SEPARATE",     -- SEPARATE: one column/row per raid group | COMBINED: one grid
        direction = "COLUMNS",      -- COLUMNS: groups left->right, members top->bottom | ROWS: the other way
        unitsPerColumn = 5,         -- combined mode only
        sortWithin = "ROLE",        -- ROLE: tanks, healers, dps | INDEX: raid order
        showSolo = true,
        showPlayer = true,          -- party only: show your own frame
        scale = scale or 1,
        pos = { "CENTER", "UIParent", "CENTER", x or -360, y or 60 },
        look = VIEW_DEFAULTS.look, buffs = VIEW_DEFAULTS.buffs, debuffs = VIEW_DEFAULTS.debuffs,
    }
end
-- party starts roomier than raid: bigger frames, power bars on, bigger auras
local PARTY_STYLE = {
    width = 110, height = 48,
    look = { powerBar = "ALL", powerHeight = 4, nameSize = 13 },
    buffs = { size = 16 },
    debuffs = { size = 20 },
}
local function Copy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == "table" and Copy(v) or v end
    return o
end
local function PartyDefaults()
    local L = LayoutDefaults(-480, -40) -- party sits somewhere other than raid by default
    L.look, L.buffs, L.debuffs = Copy(VIEW_DEFAULTS.look), Copy(VIEW_DEFAULTS.buffs), Copy(VIEW_DEFAULTS.debuffs)
    L.showPlayer = false -- party frames show your groupmates, not you
    for k, v in pairs(PARTY_STYLE) do
        if type(v) == "table" then for k2, v2 in pairs(v) do L[k][k2] = v2 end else L[k] = v end
    end
    return L
end
GT.PARTY_STYLE = PARTY_STYLE

GT.LAYOUTS = { { "party", "Solo / Party" }, { "raid10", "10-man Raid" }, { "raid20", "20-man Raid" }, { "raid40", "40-man Raid" } }

GT.defaults = {
    version = 2,
    layouts = {
        party = PartyDefaults(),
        raid10 = LayoutDefaults(-360, 60),
        raid20 = LayoutDefaults(-360, 60),
        raid40 = LayoutDefaults(-360, 60, 0.9),
    },
    tank = {
        enabled = true,
        showTargets = true,
        includeMainTanks = true,
        width = 120, height = 36, targetWidth = 110, spacing = 3,
        -- the tank panel has its own spot for party and for raid
        posParty = { "CENTER", "UIParent", "CENTER", -480, 120 },
        posRaid = { "CENTER", "UIParent", "CENTER", -360, 260 },
    },
    aggro = {
        enabled = true,
        warnNonTanks = true,
        showLosingOnTanks = true,
        showLabel = true,
        thickness = 2,
    },
    clicks = {
        bindings = {
            { mod = "", button = "1", action = "TARGET", value = "" },
            { mod = "", button = "2", action = "MENU", value = "" },
            { mod = "", button = "3", action = "ASSIST", value = "" },
            { mod = "shift-", button = "1", action = "FOCUS", value = "" },
        },
    },
    minimap = { angle = 220, hide = false },
    general = {
        locked = false,
        hideBar = false,
        hideSolo = false,
        hideBlizzParty = true,
        hideBlizzRaid = true,
        hideRaidManager = false,
        uiScale = 1,
        lastPage = "party",
        lastRaid = "raid20",
        editLayout = "party",
    },
}

-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------
local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" and v[1] ~= nil and type(v[1]) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = CopyDefaults(v, {}) end -- list: copy once
        elseif type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
GT.CopyDefaults = CopyDefaults

function GT.Print(...)
    print("|cffff4fa3Gram Frames|r:", ...)
end

-- Secret values (Forever inherits Midnight's addon lockdown). A secret can be
-- stored and handed to widget setters, but any math/compare/test on it errors.
local issecretvalue = issecretvalue
function GT.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end
function GT.Readable(v)
    return not (issecretvalue and issecretvalue(v))
end
-- true only when the value is a readable true
function GT.IsTrue(v)
    if issecretvalue and issecretvalue(v) then return false end
    return v and true or false
end
-- readable string or nil
function GT.Str(v)
    if issecretvalue and issecretvalue(v) then return nil end
    if type(v) == "string" then return v end
    return nil
end
function GT.Num(v)
    if issecretvalue and issecretvalue(v) then return nil end
    if type(v) == "number" then return v end
    return nil
end

-- unit role, never secret-unsafe
function GT.UnitRole(unit)
    if not UnitGroupRolesAssigned then return "NONE" end
    local ok, role = pcall(UnitGroupRolesAssigned, unit)
    role = ok and GT.Str(role) or nil
    if (not role or role == "NONE") and GetPartyAssignment then
        local ok2, mt = pcall(GetPartyAssignment, "MAINTANK", unit)
        if ok2 and GT.IsTrue(mt) then return "TANK" end
    end
    return role or "NONE"
end

-- Things that touch secure frames can't run in combat. Queue them.
local pending = {}
function GT.RunOOC(key, fn)
    if InCombatLockdown() then
        pending[key] = fn
        return false
    end
    fn()
    return true
end

-------------------------------------------------------------------------------
-- Callbacks (settings changed -> refresh)
-------------------------------------------------------------------------------
local callbacks = {}
function GT.On(name, fn)
    callbacks[name] = callbacks[name] or {}
    table.insert(callbacks[name], fn)
end
function GT.Fire(name, ...)
    if not callbacks[name] then return end
    for _, fn in ipairs(callbacks[name]) do
        local ok, err = pcall(fn, ...)
        if not ok then geterrorhandler()(err) end
    end
end

-- Read/write a setting by path "section.key"
local function Root(path)
    if path:sub(1, 7) == "layout." then
        return GT.db.layouts[GT.db.general.editLayout] or GT.db.layouts.party, path:sub(8), "layout"
    end
    return GT.db, path, nil
end

-- the layout whose look is on screen: the one you're editing while test mode
-- is up, otherwise the one that fits your group
function GT.ViewKey()
    if GT.testMode then return GT.db.general.editLayout end
    return GT.ActiveLayoutKey()
end
local function View() return GT.db.layouts[GT.ViewKey()] or GT.db.layouts.party end
function GT.Look() return View().look end
function GT.Buffs() return View().buffs end
function GT.Debuffs() return View().debuffs end

-- which layout fits the current group
function GT.ActiveLayoutKey()
    if IsInRaid and IsInRaid() then
        local n = GT.Num(GetNumGroupMembers and GetNumGroupMembers()) or 40
        if n <= 10 then return "raid10" elseif n <= 20 then return "raid20" end
        return "raid40"
    end
    return "party"
end
function GT.ActiveLayout()
    return GT.db.layouts[GT.ActiveLayoutKey()]
end

function GT.Get(path)
    local t
    t, path = Root(path)
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[part]
    end
    return t
end
function GT.Set(path, value)
    local t, last, section
    t, path, section = Root(path)
    local parts = {}
    for part in path:gmatch("[^%.]+") do parts[#parts + 1] = part end
    for i = 1, #parts - 1 do
        t[parts[i]] = t[parts[i]] or {}
        t = t[parts[i]]
    end
    last = parts[#parts]
    t[last] = value
    GT.Fire("SettingChanged", section or parts[1], last, value)
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
GT.eventFrame = ev
local function SafeRegister(frame, event)
    local ok = pcall(frame.RegisterEvent, frame, event)
    return ok
end
GT.SafeRegister = SafeRegister

ev:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON then return end
        if type(GramFramesDB) == "table" and GramFramesDB.version ~= 2 then GramFramesDB = nil end -- v1 settings don't carry over
        -- older saves kept one shared look; hand a copy to every layout
        local db = GramFramesDB
        if type(db) == "table" and type(db.layouts) == "table" then
            for _, sect in ipairs({ "look", "buffs", "debuffs" }) do
                if type(db[sect]) == "table" then
                    for _, L in pairs(db.layouts) do
                        if type(L) == "table" and type(L[sect]) ~= "table" then L[sect] = CopyDefaults(db[sect], {}) end
                    end
                    db[sect] = nil
                end
            end
        end
        GramFramesDB = CopyDefaults(GT.defaults, GramFramesDB)
        GT.db = GramFramesDB
        -- one time: give existing installs the new roomier party style
        if not GT.db.general.partyStyle2 then
            local P = GT.db.layouts.party
            for k, v in pairs(PARTY_STYLE) do
                if type(v) == "table" then for k2, v2 in pairs(v) do P[k][k2] = v2 end else P[k] = v end
            end
            GT.db.general.partyStyle2 = true
        end
        -- one time: party frames hide your own frame (turn "Show Me" back on to see it)
        if not GT.db.general.hideSelf1 then
            GT.db.layouts.party.showPlayer = false
            GT.db.general.hideSelf1 = true
        end
        -- one time: party and raid used to share a spot; split them apart
        if not GT.db.general.splitPos then
            local P, R = GT.db.layouts.party.pos, GT.db.layouts.raid20.pos
            local same = true
            for i = 1, 5 do if P[i] ~= R[i] then same = false end end
            if same then GT.db.layouts.party.pos = { "CENTER", "UIParent", "CENTER", -480, -40 } end
            local T = GT.db.tank
            if type(T.pos) == "table" then
                T.posRaid = T.pos
                T.posParty = { T.pos[1], T.pos[2], T.pos[3], T.pos[4] - 120, T.pos[5] - 140 }
                T.pos = nil
            end
            GT.db.general.splitPos = true
        end
        ev:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        GT.Fire("Login")
    elseif event == "PLAYER_REGEN_ENABLED" then
        for key, fn in pairs(pending) do
            pending[key] = nil
            local ok, err = pcall(fn)
            if not ok then geterrorhandler()(err) end
        end
        GT.Fire("CombatEnd")
    elseif event == "PLAYER_REGEN_DISABLED" then
        GT.Fire("CombatStart")
    else
        GT.Fire(event, ...)
    end
end)
SafeRegister(ev, "ADDON_LOADED")
SafeRegister(ev, "PLAYER_LOGIN")
SafeRegister(ev, "PLAYER_REGEN_ENABLED")
SafeRegister(ev, "PLAYER_REGEN_DISABLED")
for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE",
                     "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD", "PARTY_LEADER_CHANGED" }) do
    SafeRegister(ev, e)
end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
SLASH_GRAMFRAMES1 = "/gf"
SLASH_GRAMFRAMES2 = "/gt"
SLASH_GRAMFRAMES3 = "/gramframes"
SlashCmdList.GRAMFRAMES = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "lock" or msg == "unlock" then
        GT.ToggleLock()
    elseif msg == "test" then
        GT.ToggleTestMode()
    elseif msg == "minimap" then
        GT.db.minimap.hide = not GT.db.minimap.hide
        GT.Fire("MinimapChanged")
        GT.Print(GT.db.minimap.hide and "minimap button hidden (/gf minimap brings it back)" or "minimap button shown")
    elseif msg == "reset" then
        if InCombatLockdown() then GT.Print("can't reset in combat") return end
        GramFramesDB = CopyDefaults(GT.defaults, {})
        GT.db = GramFramesDB
        GT.Fire("SettingChanged", "all")
        GT.Print("settings reset")
    else
        GT.ToggleOptions()
    end
end

function GT.ToggleLock()
    GT.Set("general.locked", not GT.db.general.locked)
    if GT.UpdateBars then GT.UpdateBars() end
    GT.Print(GT.db.general.locked and "frames |cffff4fa3locked|r" or "frames unlocked - drag the pink tab")
end

-- Addon compartment (the little addon button by the minimap)
function GramFrames_OnAddonCompartmentClick()
    GT.ToggleOptions()
end

GT.On("SettingChanged", function(section, key)
    if key == "font" or section == "all" then GT.ApplyFonts() end
end)
