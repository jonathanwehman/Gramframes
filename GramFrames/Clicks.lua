-- GramFrames: click-casting bindings with spell rank / downrank support.
-- A binding = modifier + mouse button -> action. Spells can be cast at max rank or
-- any specific rank; ranks are resolved to that rank's own spell ID from the spellbook.
local _, GT = ...

GT.MODS = {
    { "", "None" }, { "shift-", "Shift" }, { "ctrl-", "Ctrl" }, { "alt-", "Alt" },
    { "ctrl-shift-", "Ctrl + Shift" }, { "alt-shift-", "Alt + Shift" }, { "alt-ctrl-", "Alt + Ctrl" },
}
GT.MOUSE = { { "1", "Left Click" }, { "2", "Right Click" }, { "3", "Middle Click" }, { "4", "Button 4" }, { "5", "Button 5" } }
GT.ACTIONS = {
    { "TARGET", "Target" }, { "MENU", "Unit Menu" }, { "ASSIST", "Assist (their target)" }, { "FOCUS", "Set Focus" },
    { "SPELL", "Cast Spell" }, { "MACRO", "Macro" },
}
local ACTION_TYPE = { TARGET = "target", MENU = "togglemenu", ASSIST = "assist", FOCUS = "focus", SPELL = "spell", MACRO = "macro" }

-------------------------------------------------------------------------------
-- Spellbook scan: name -> list of { rank, id, icon } (rank 0 = no ranks)
-------------------------------------------------------------------------------
local book, spellNames = {}, {}
GT.spellbook = book

local GENERAL_NAMES = { General = true, GENERAL = true }
function GT.ScanSpellbook()
    wipe(book); wipe(spellNames)
    local SB = C_SpellBook
    if not (SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo) then return end
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local okN, lines = pcall(SB.GetNumSpellBookSkillLines)
    if not okN or type(lines) ~= "number" then return end
    local generalName = _G.GENERAL
    for line = 1, lines do
        local ok, info = pcall(SB.GetSpellBookSkillLineInfo, line)
        -- class spells only: skip the General tab (auto attack, racials, professions) and guild perks
        local isGeneral = type(info) == "table" and (line == 1 or GENERAL_NAMES[info.name] or info.name == generalName)
        if ok and type(info) == "table" and not info.shouldHide and not info.isGuild and not isGeneral then
            local off, num = info.itemIndexOffset or 0, info.numSpellBookItems or 0
            for idx = off + 1, off + num do
                local ok2, item = pcall(SB.GetSpellBookItemInfo, idx, bank)
                if ok2 and type(item) == "table" and item.spellID and item.name and not item.isPassive then
                    local sub = item.subName
                    if (not sub or sub == "") and C_Spell and C_Spell.GetSpellSubtext then
                        local ok3, s = pcall(C_Spell.GetSpellSubtext, item.spellID)
                        sub = ok3 and s or ""
                    end
                    local rank = tonumber(tostring(sub or ""):match("(%d+)")) or 0
                    local list = book[item.name]
                    if not list then
                        local helpful = false
                        if SB.IsSpellBookItemHelpful then
                            local okH, h = pcall(SB.IsSpellBookItemHelpful, idx, bank)
                            helpful = okH and h == true
                        end
                        list = { helpful = helpful, icon = item.iconID }
                        book[item.name] = list
                        spellNames[#spellNames + 1] = item.name
                    end
                    local dup
                    for _, e in ipairs(list) do if e.id == item.spellID then dup = true end end
                    if not dup then list[#list + 1] = { rank = rank, id = item.spellID, icon = item.iconID } end
                end
            end
        end
    end
    for _, list in pairs(book) do table.sort(list, function(a, b) return a.rank < b.rank end) end
    -- heals and buffs first (what you click raid frames for), then everything else
    table.sort(spellNames, function(a, b)
        local ha, hb = book[a].helpful, book[b].helpful
        if ha ~= hb then return ha end
        return a < b
    end)
end

local function Label(name)
    local list = book[name]
    local icon = list and (list.icon or (list[#list] and list[#list].icon))
    if icon then return "|T" .. icon .. ":14:14:0:0:64:64:5:59:5:59|t " .. name end
    return name
end

function GT.SpellOptions()
    local out = {}
    for _, n in ipairs(spellNames) do out[#out + 1] = { n, Label(n) } end
    if #out == 0 then out[1] = { "", "(open your spellbook once, or type a name)" } end
    return out
end

function GT.RankOptions(name)
    local out = { { "MAX", "Max rank" } }
    local list = name and book[name]
    if list then
        local top, have = 0, {}
        for _, e in ipairs(list) do
            if e.rank > 0 then have[e.rank] = true; if e.rank > top then top = e.rank end end
        end
        -- if the spellbook only lists your best rank, still offer the lower ones
        for r = 1, top do out[#out + 1] = { tostring(r), "Rank " .. r } end
    end
    return out
end

-- what to put in the "spell" attribute for a binding
local function ResolveSpell(name, rank)
    if not name or name == "" then return nil end
    if not rank or rank == "MAX" then return name end
    local list = book[name]
    local r = tonumber(rank)
    if list and r then
        for _, e in ipairs(list) do
            if e.rank == r then return e.id end -- exact rank by spell ID
        end
    end
    return name .. "(Rank " .. rank .. ")"   -- classic-style fallback
end
GT.ResolveSpell = ResolveSpell

-------------------------------------------------------------------------------
-- Bindings -> secure attributes
-------------------------------------------------------------------------------
function GT.ClickAttributes()
    local out = {}
    for _, bnd in ipairs(GT.db.clicks.bindings) do
        local prefix, btn = bnd.mod or "", bnd.button or "1"
        local t = ACTION_TYPE[bnd.action]
        if bnd.action == "SPELL" then
            local spell = ResolveSpell(bnd.value, bnd.rank)
            if spell then
                out[#out + 1] = { prefix .. "type" .. btn, "spell" }
                out[#out + 1] = { prefix .. "spell" .. btn, spell }
            end
        elseif bnd.action == "MACRO" then
            if bnd.value and bnd.value ~= "" then
                out[#out + 1] = { prefix .. "type" .. btn, "macro" }
                out[#out + 1] = { prefix .. "macrotext" .. btn, bnd.value }
            end
        elseif t then
            out[#out + 1] = { prefix .. "type" .. btn, t }
        end
    end
    return out
end

-- apply to one button, clearing anything a removed binding left behind
function GT.ApplyClicks(b)
    if InCombatLockdown() then return end
    local old = b.gtClickAttrs
    if old then
        for name in pairs(old) do b:SetAttribute(name, nil) end
    end
    local now = {}
    for _, pair in ipairs(GT.ClickAttributes()) do
        b:SetAttribute(pair[1], pair[2])
        now[pair[1]] = true
    end
    b.gtClickAttrs = now
end

-- headers copy these onto buttons they create later (even in combat)
function GT.SetHeaderClickAttributes(h)
    local names = {}
    for _, pair in ipairs(GT.ClickAttributes()) do
        names[#names + 1] = pair[1]
        h:SetAttribute("_initialAttribute-" .. pair[1], pair[2])
    end
    h:SetAttribute("_initialAttributeNames", table.concat(names, ","))
end

function GT.ApplyAllClicks()
    GT.RunOOC("clicks", function()
        if GT.headers and GT.headers.combined then
            for i = 1, 8 do GT.SetHeaderClickAttributes(GT.headers.groups[i]) end
            GT.SetHeaderClickAttributes(GT.headers.combined)
            GT.SetHeaderClickAttributes(GT.headers.tank)
        end
        for b in pairs(GT.buttons) do GT.ApplyClicks(b) end
    end)
end

function GT.AddBinding()
    table.insert(GT.db.clicks.bindings, { mod = "", button = "1", action = "SPELL", value = "", rank = "MAX" })
    GT.ApplyAllClicks()
end
function GT.RemoveBinding(i)
    table.remove(GT.db.clicks.bindings, i)
    GT.ApplyAllClicks()
end

-- rescan the spellbook when it changes (new rank learned, respec, etc.)
local f = CreateFrame("Frame")
for _, e in ipairs({ "SPELLS_CHANGED", "PLAYER_LOGIN", "LEARNED_SPELL_IN_SKILL_LINE" }) do GT.SafeRegister(f, e) end
f:SetScript("OnEvent", function()
    GT.ScanSpellbook()
    GT.ApplyAllClicks()
end)
