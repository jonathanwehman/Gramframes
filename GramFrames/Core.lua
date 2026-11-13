-- GramFrames: tank-focused raid frames for World of Warcraft: Forever
-- Core: namespace, saved settings, secret-value helpers, events, slash commands.
local ADDON, GT = ...
_G.GramFrames = GT

GT.version = "2.2.8"
GT.media = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
GT.FLAT = "Interface\\Buttons\\WHITE8X8"
GT.FONT = "Fonts\\ARIALN.TTF" -- fallback; the chosen font comes from GT.GetFont()

-------------------------------------------------------------------------------
-- Fonts. Built-ins always exist. "Expressway" (the default) is found on its own,
-- no setup for anyone:
--   1. Expressway from any addon that has it (LibSharedMedia, EllesmereUI, ElvUI)
--   2. otherwise EllesmereUI's own font, if EllesmereUI is installed
--   3. otherwise Arial Narrow (always there)
-- Expressway is a paid font, so Gram Frames never ships it.
-------------------------------------------------------------------------------
GT.fontChoices = {
    { "Expressway", "Expressway", {
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

local function AddonOf(path)
    return path:match("^Interface\\AddOns\\([^\\]+)\\")
end
local function AddonLoaded(name)
    local f = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not f then return false end
    local ok, loaded = pcall(f, name)
    return ok and loaded and true or false
end
local function LSM() return LibStub and LibStub("LibSharedMedia-3.0", true) end

-- The client logs a missing font file as an error even inside pcall, so a file
-- path is only tried if its addon is loaded, and never again once it failed.
local function TryPath(path)
    local owner = AddonOf(path)
    if owner and not AddonLoaded(owner) then return nil end
    local bad = GT.db and GT.db.general
    if bad then
        bad.badFonts = bad.badFonts or {}
        if bad.badFonts[path] then return nil end
    elseif owner then
        return nil -- settings not loaded yet: wait rather than risk an error
    end
    if CanLoad(path) then return path end
    if bad then bad.badFonts[path] = true end
    return nil
end

local function FindExpressway(paths)
    local lsm = LSM()
    local p = lsm and lsm:Fetch("font", "Expressway", true)
    if p then return p end
    for _, path in ipairs(paths) do
        p = TryPath(path)
        if p then return p end
    end
    -- EllesmereUI's own font, through what it registered with LibSharedMedia
    if lsm and AddonLoaded("EllesmereUI") then
        local names = {}
        for name, path in pairs(lsm:HashTable("font")) do
            if type(path) == "string" and path:lower():find("\\ellesmereui", 1, true) then
                names[#names + 1] = name
            end
        end
        table.sort(names)
        for _, name in ipairs(names) do
            p = lsm:Fetch("font", name, true)
            if p then return p end
        end
    end
    return nil
end

local resolved = {}
function GT.ResolveFont(key)
    if resolved[key] then return resolved[key] end
    local found
    for _, choice in ipairs(GT.fontChoices) do
        if choice[1] == key then
            if key == "Expressway" then
                found = FindExpressway(choice[3])
            else
                for _, path in ipairs(choice[3]) do
                    found = TryPath(path)
                    if found then break end
                end
            end
        end
    end
    -- fonts registered by other addons through LibSharedMedia
    if not found then
        local lsm = LSM()
        found = lsm and lsm:Fetch("font", key, true) or nil
    end
    -- only remember a success; a miss is tried again later (another addon may
    -- not have registered its fonts yet)
    if found then resolved[key] = found end
    return found
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

-------------------------------------------------------------------------------
-- Bar textures: Blizzard built-ins, EllesmereUI's (only if it's installed;
-- we just point at its files), plus anything shared through LibSharedMedia.
-------------------------------------------------------------------------------
local EUI_TEX = "Interface\\AddOns\\EllesmereUI\\media\\textures\\"
GT.textureChoices = {
    { "Flat", "Flat (solid)", "Interface\\Buttons\\WHITE8X8" },
    { "Blizzard", "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" },
    { "BlizzardRaid", "Blizzard Raid", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { "BlizzardSkills", "Blizzard Smooth", "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    { "EUI_Matte", "Matte (EllesmereUI)", EUI_TEX .. "matte.tga", eui = true },
    { "EUI_Glass", "Glass (EllesmereUI)", EUI_TEX .. "glass.tga", eui = true },
    { "EUI_Melli", "Melli (EllesmereUI)", EUI_TEX .. "melli.tga", eui = true },
    { "EUI_Beautiful", "Beautiful (EllesmereUI)", EUI_TEX .. "beautiful.tga", eui = true },
    { "EUI_Atrocity", "Atrocity (EllesmereUI)", EUI_TEX .. "atrocity.tga", eui = true },
    { "EUI_Plating", "Plating (EllesmereUI)", EUI_TEX .. "plating.tga", eui = true },
    { "EUI_Sheer", "Sheer (EllesmereUI)", EUI_TEX .. "sheer.tga", eui = true },
    { "EUI_GradientLight", "Gradient Light (EllesmereUI)", EUI_TEX .. "gradient-light.tga", eui = true },
    { "EUI_Pixels", "Pixels (EllesmereUI)", EUI_TEX .. "pixels-fill.tga", eui = true },
}

local function HaveEUI()
    local f = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not f then return false end
    local ok, loaded = pcall(f, "EllesmereUI")
    return ok and loaded and true or false
end
GT.HaveEUI = HaveEUI

function GT.TextureOptions()
    local out, seen = {}, {}
    local eui = HaveEUI()
    for _, c in ipairs(GT.textureChoices) do
        if eui or not c.eui then out[#out + 1] = { c[1], c[2] } end
        seen[c[1]] = true; seen[c[2]] = true
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for _, name in ipairs(LSM:List("statusbar")) do
            if not seen[name] then out[#out + 1] = { name, name } end
        end
    end
    return out
end

-- the file for the current layout's bar texture (falls back to flat)
function GT.GetBarTexture()
    local key = GT.db and GT.Look().barTexture or "Flat"
    for _, c in ipairs(GT.textureChoices) do
        if c[1] == key then
            if c.eui and not HaveEUI() then break end
            return c[3]
        end
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local path = LSM and LSM:Fetch("statusbar", key, true)
    return path or "Interface\\Buttons\\WHITE8X8"
end

function GT.GetFont()
    local key = GT.db and GT.Look().font or "Expressway"
    return GT.ResolveFont(key) or GT.FONT
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
        nameSize = 12,
        healthText = "NONE",        -- NONE | PERCENT | MISSING
        healthTextSize = 10,
        powerBar = "NONE",          -- ALL | HEALERS | NONE
        powerHeight = 3,
        rangeAlpha = 0.40,          -- "Fade" style only
        rangeStyle = "FADE",         -- out of range: BOX = grey out the whole box, FADE = fade the frame
        oorColor = { 0.12, 0.12, 0.12 },
        oorTextAlpha = 0.55,        -- names/icons when out of range (BOX style)
        raidIconSize = 16,
        drinking = true,            -- show DRINKING when someone eats/drinks
        afk = true,                 -- show AFK with a minute timer (offline always shows its timer)
        roleIcon = true,
        hideDPSIcon = false,        -- tanks/healers only, if you like it quieter
        roleSize = 12,
        roleStyle = "ROUND",        -- ROUND = Blizzard's round role icons, TINY = small flat ones
        leaderIcon = true,
        raidIcon = true,
        targetHighlight = true,
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

-- colors, font and bar texture: one set for party and raid alike (General page)
local STYLE_DEFAULTS = {
    font = "Expressway",
    healthColor = "DARK",       -- DARK | CLASS | CLASSDARK | GRADIENT | CUSTOM
    barColor = { 0.067, 0.067, 0.067, 0.9 }, -- dark mode health (#111111 @ 90%)
    lossColor = { 0.31, 0.31, 0.31 },    -- dark mode missing health (#4f4f4f)
    classBG = true,             -- class modes: tint the background with the class color
    barTexture = "Flat",        -- health + power bar texture
    matchEUI = true,            -- dark mode: take the bar grey from EllesmereUI when it is installed
    nameColor = "CLASS",        -- CLASS | WHITE | CUSTOM
    nameCustomColor = { 1, 1, 1 },
    healthTextColor = { 1, 1, 1 },
    borderColor = { 0, 0, 0 },  -- the thin edge around each frame
    bgAlpha = 1,                -- border opacity
    targetColor = { 1, 0.82, 0.2 }, -- gold box around the person you have targeted
    targetThickness = 2,
}
GT.STYLE_KEYS = {}
for k in pairs(STYLE_DEFAULTS) do GT.STYLE_KEYS[k] = true end

GT.defaults = {
    version = 2,
    style = STYLE_DEFAULTS,
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
-- GT.Look(): the on-screen layout's look, with the shared style (colors, font,
-- texture) read from GT.db.style. Read-only: change settings with GT.Set.
local STYLE_KEYS = GT.STYLE_KEYS
local lookProxy = setmetatable({}, {
    __index = function(_, k)
        if STYLE_KEYS[k] then return GT.db.style[k] end
        return View().look[k]
    end,
    __newindex = function() error("GramFrames: use GT.Set to change settings") end,
})
function GT.Look() return lookProxy end
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
    elseif msg == "debug" then
        if GT.DebugFrames then GT.DebugFrames() end
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

-- by login every addon has loaded and shared its fonts: pick the font again
GT.On("Login", function() GT.ApplyFonts() end)

GT.On("SettingChanged", function(section, key)
    if key == "font" or section == "all" then GT.ApplyFonts() end
end)

-- one time: dark mode = dark health over light-grey missing health (EllesmereUI's look),
-- and out of range back to a plain fade
GT.On("Login", function()
    local G = GT.db and GT.db.general
    if not G or G.darkMode2 then return end
    G.darkMode2 = true
    G.lightGrey1 = true -- superseded
    for _, L in pairs(GT.db.layouts) do
        local lk = L.look
        if lk then
            lk.barColor = { 0.067, 0.067, 0.067, 0.9 }
            lk.lossColor = { 0.31, 0.31, 0.31 }
            lk.matchEUI = true
            lk.rangeStyle = "FADE"
        end
    end
    GT.Fire("SettingChanged", "style", "barColor")
end)

-- one time: lighter dark-mode grey (only if you still had the old default)
GT.On("Login", function()
    local G = GT.db and GT.db.general
    if not G or G.lightGrey1 then return end
    G.lightGrey1 = true
    for _, L in pairs(GT.db.layouts) do
        local c = L.look and L.look.barColor
        if type(c) == "table" and math.abs((c[1] or 0) - 0.17) < 0.005 and math.abs((c[2] or 0) - 0.17) < 0.005 then
            L.look.barColor = { 0.30, 0.30, 0.30 }
        end
        if L.look then L.look.matchEUI = false end
    end
    GT.Fire("SettingChanged", "style", "barColor")
end)

-- one time, for people running EllesmereUI: match its unit frames (Atrocity bars)
GT.On("Login", function()
    local G = GT.db and GT.db.general
    if not G or G.matchEUI1 then return end
    G.matchEUI1 = true
    if not GT.HaveEUI() then return end
    for _, L in pairs(GT.db.layouts) do
        if L.look and (L.look.barTexture == nil or L.look.barTexture == "Flat") then L.look.barTexture = "EUI_Atrocity" end
    end
    GT.Fire("SettingChanged", "style", "barTexture")
end)

-- one time: colors, font and bar texture moved to General (shared by party and
-- raid). Keep what you had on your party frames.
GT.On("Login", function()
    local G = GT.db and GT.db.general
    if not G or G.sharedStyle1 then return end
    G.sharedStyle1 = true
    local from = GT.db.layouts.party and GT.db.layouts.party.look or {}
    for k in pairs(GT.STYLE_KEYS) do
        local v = from[k]
        if v ~= nil then GT.db.style[k] = type(v) == "table" and CopyDefaults(v, {}) or v end
    end
    GT.ApplyFonts()
    GT.Fire("SettingChanged", "style", "barTexture")
end)

