-- GramFrames: Mouseover Macros
-- For people who'd rather heal with action-bar keys than click-casting: makes a
-- "/cast [@mouseover,help,nodead][] Spell" macro for each of your class's
-- helpful spells and puts it on your cursor to drop on an action bar.
local _, GT = ...

GT.defaults.macros = {
    fallback = true,    -- no mouseover: cast on your target (or yourself)
    perChar = "CHAR",   -- CHAR = this character's macros, ACCOUNT = shared
}

-- the spells raid-frame players usually want, per class (only ones you know show up)
-- dead = true: resurrection, cast on dead players
local CLASS_SPELLS = {
    PRIEST = {
        "Flash Heal", "Greater Heal", "Heal", "Lesser Heal", "Renew", "Power Word: Shield",
        "Prayer of Mending", "Binding Heal", "Dispel Magic", "Cure Disease", "Abolish Disease",
        "Power Word: Fortitude", "Divine Spirit", "Shadow Protection", "Fear Ward", "Pain Suppression",
        "Guardian Spirit", "Penance", { "Resurrection", dead = true },
    },
    DRUID = {
        "Healing Touch", "Regrowth", "Rejuvenation", "Lifebloom", "Swiftmend", "Wild Growth", "Nourish",
        "Remove Curse", "Abolish Poison", "Cure Poison", "Mark of the Wild", "Thorns", "Innervate",
        { "Rebirth", dead = true }, { "Revive", dead = true },
    },
    PALADIN = {
        "Flash of Light", "Holy Light", "Holy Shock", "Cleanse", "Purify", "Lay on Hands",
        "Blessing of Protection", "Blessing of Freedom", "Blessing of Sacrifice", "Blessing of Might",
        "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation", "Blessing of Light",
        "Blessing of Sanctuary", "Beacon of Light", "Sacred Shield", "Hand of Protection",
        "Hand of Freedom", "Hand of Sacrifice", "Hand of Salvation", { "Redemption", dead = true },
    },
    SHAMAN = {
        "Healing Wave", "Lesser Healing Wave", "Chain Heal", "Riptide", "Earth Shield",
        "Cure Poison", "Cure Disease", "Cure Toxins", "Cleanse Spirit", "Water Walking", "Water Breathing",
        { "Ancestral Spirit", dead = true },
    },
    MAGE = { "Remove Lesser Curse", "Remove Curse", "Arcane Intellect", "Arcane Brilliance", "Dampen Magic", "Amplify Magic", "Focus Magic" },
    WARLOCK = { "Unending Breath", "Detect Invisibility", "Detect Lesser Invisibility" },
    WARRIOR = { "Intervene", "Vigilance" },
    ROGUE = { "Tricks of the Trade" },
    HUNTER = { "Misdirection" },
    DEATHKNIGHT = { { "Raise Ally", dead = true } },
}

local function S() return GT.db.macros end

-- WoW caps macro names at 16 letters: shorten common words first so
-- "Blessing of Sacrifice" and "Blessing of Salvation" don't end up the same
local SHORT = {
    { "Blessing of ", "Bless " }, { "Power Word: ", "PW " }, { "Hand of ", "Hand " },
    { "Greater ", "Gr " }, { "Lesser ", "Ls " }, { "Remove ", "Rm " }, { "Abolish ", "Ab " },
}
local function MacroName(spell)
    local name = "GF " .. spell
    if #name > 16 then
        for _, p in ipairs(SHORT) do
            local a, b = p[1], p[2]
            local i = name:find(a, 1, true)
            if i then name = name:sub(1, i - 1) .. b .. name:sub(i + #a) end
        end
    end
    return name:sub(1, 16)
end
GT.MacroName = MacroName

local function MacroBody(spell, dead)
    local cond = dead and "[@mouseover,help,dead]" or "[@mouseover,help,nodead]"
    if S().fallback then cond = cond .. "[]" end
    return "#showtooltip " .. spell .. "\n/cast " .. cond .. " " .. spell
end

-- the list for the page: your class's spells you know, then any other helpful
-- spells in your spellbook. If the spellbook isn't read yet, the class list.
function GT.MacroSpells()
    local _, class = UnitClass("player")
    local book = GT.spellbook or {}
    local haveBook = next(book) ~= nil
    local out, seen = {}, {}
    for _, e in ipairs(CLASS_SPELLS[class] or {}) do
        local name = type(e) == "table" and e[1] or e
        if not haveBook or book[name] then
            out[#out + 1] = { name = name, dead = type(e) == "table" and e.dead or false, preset = true }
            seen[name] = true
        end
    end
    if haveBook then
        local extra = {}
        for name, list in pairs(book) do
            if list.helpful and not seen[name] then extra[#extra + 1] = name end
        end
        table.sort(extra)
        for _, name in ipairs(extra) do out[#out + 1] = { name = name } end
    end
    return out
end

function GT.SpellIcon(name)
    local list = GT.spellbook and GT.spellbook[name]
    local icon = list and (list.icon or (list[#list] and list[#list].icon))
    if not icon and C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, name)
        if ok then icon = t end
    end
    return icon
end

function GT.HasMacro(spell)
    local i = GetMacroIndexByName and GetMacroIndexByName(MacroName(spell))
    return i and i > 0 and i or nil
end

-- create (or update) the macro; returns its index or nil + a reason
function GT.MakeMacro(spell, dead)
    if InCombatLockdown() then return nil, "can't make macros in combat" end
    if not (CreateMacro and GetMacroIndexByName) then return nil, "macros aren't available" end
    local name, body = MacroName(spell), MacroBody(spell, dead)
    local icon = "INV_Misc_QuestionMark" -- #showtooltip shows the spell's own icon
    local idx = GetMacroIndexByName(name)
    if idx and idx > 0 then
        local ok, res = pcall(EditMacro, idx, name, icon, body)
        if ok then return res or idx end
        return nil, "couldn't update the macro"
    end
    local perChar = S().perChar ~= "ACCOUNT"
    local numAccount, numChar = GetNumMacros()
    if perChar and numChar >= (MAX_CHARACTER_MACROS or 18) then
        return nil, "your character macros are full - delete one or switch Save Macros For to Account"
    elseif not perChar and numAccount >= (MAX_ACCOUNT_MACROS or 120) then
        return nil, "your account macros are full - delete one or switch Save Macros For to This Character"
    end
    local ok, res = pcall(CreateMacro, name, icon, body, perChar)
    if ok and res then return res end
    return nil, "couldn't make the macro"
end

-- make it, then put it on the cursor so you can drop it on a bar
function GT.MakeAndPickUp(spell, dead)
    local idx, err = GT.MakeMacro(spell, dead)
    if not idx then GT.Print(err) return end
    if PickupMacro then PickupMacro(idx) end
    GT.Print("macro |cffff4fa3" .. MacroName(spell) .. "|r is on your cursor - drop it on an action bar")
end

function GT.MakeAllMacros()
    local made, failed = 0, nil
    for _, s in ipairs(GT.MacroSpells()) do
        if s.preset then -- your class's main spells; the extras are one click each
            local idx, err = GT.MakeMacro(s.name, s.dead)
            if idx then made = made + 1 else failed = err break end
        end
    end
    GT.Print(made .. " mouseover macro" .. (made == 1 and "" or "s") .. " ready - open your macros (/macro) to drag them to your bars")
    if failed then GT.Print(failed) end
end

-- macro option changed: rewrite the macros you've already made
GT.On("SettingChanged", function(section, key)
    if section ~= "macros" or key ~= "fallback" or InCombatLockdown() then return end
    for _, s in ipairs(GT.MacroSpells()) do
        if GT.HasMacro(s.name) then GT.MakeMacro(s.name, s.dead) end
    end
end)

-------------------------------------------------------------------------------
-- Options page rows (custom section)
-------------------------------------------------------------------------------
function GT.BuildMacroRows(parent, width)
    local UI, C = GT.UI, GT.colors
    local y = 0
    local list = GT.MacroSpells()
    local all = UI.Button(parent, "Make All Class Spells", function() GT.MakeAllMacros(); GT.ShowPage("macros") end, 190)
    all:SetPoint("TOPLEFT", 6, -y)
    local tip = UI.Font(parent, 11, C.muted)
    tip:SetPoint("LEFT", all, "RIGHT", 12, 0)
    tip:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
    tip:SetJustifyH("LEFT")
    tip:SetWordWrap(true)
    tip:SetText("Make puts the macro on your cursor: drop it on an action bar, then hover a frame and press the key.")
    y = y + 36
    if #list == 0 then
        local none = UI.Font(parent, 12, C.muted)
        none:SetPoint("TOPLEFT", 6, -y)
        none:SetText("No helpful spells found yet. Open your spellbook once, then come back.")
        return y + 24
    end
    for i, s in ipairs(list) do
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetSize(width, 26)
        if i % 2 == 0 then UI.Fill(row, { 1, 1, 1 }, 0.025) end
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", 6, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetTexture(GT.SpellIcon(s.name) or 134400)
        local name = UI.Font(row, 12, C.text)
        name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        name:SetText(s.name)
        local made = UI.Font(row, 11, { 0.45, 0.85, 0.45 })
        made:SetPoint("LEFT", name, "RIGHT", 10, 0)
        made:SetText(GT.HasMacro(s.name) and "made" or "")
        local btn = UI.Button(row, GT.HasMacro(s.name) and "Pick Up" or "Make", function()
            GT.MakeAndPickUp(s.name, s.dead)
            GT.ShowPage("macros")
        end, 110)
        btn:SetPoint("RIGHT", -6, 0)
        y = y + 28
    end
    return y + 4
end
