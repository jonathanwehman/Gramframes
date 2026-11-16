-- GramFrames: first-run welcome. Pick a look: Modern (Gram's dark frames) or
-- Blizzard (the default raid frame look). Shows once; change it later in
-- /gf -> General -> Frame Skin.
local _, GT = ...
local UI, C = GT.UI, GT.colors

local win

-- a little sample frame so you can see what you're picking
local function Preview(parent, blizz)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(150, 48)
    UI.Fill(f, blizz and { 0.22, 0.22, 0.22 } or { 0, 0, 0 })
    local tex = blizz and "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" or GT.FLAT
    local bg = f:CreateTexture(nil, "BORDER")
    bg:SetTexture(tex)
    bg:SetPoint("TOPLEFT", 1, -1); bg:SetPoint("BOTTOMRIGHT", -1, 1)
    local hp = f:CreateTexture(nil, "ARTWORK")
    hp:SetTexture(tex)
    hp:SetPoint("TOPLEFT", 1, -1); hp:SetPoint("BOTTOMLEFT", 1, 1)
    hp:SetWidth(148 * 0.7)
    local paladin = { 0.96, 0.55, 0.73 }
    local name = f:CreateFontString(nil, "OVERLAY")
    if blizz then
        bg:SetVertexColor(0.08, 0.08, 0.08)
        hp:SetVertexColor(paladin[1], paladin[2], paladin[3])
        name:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        name:SetShadowOffset(1, -1)
        name:SetPoint("TOPLEFT", 5, -4)
        name:SetTextColor(1, 1, 1)
    else
        bg:SetVertexColor(0.31, 0.31, 0.31)
        hp:SetVertexColor(0.067, 0.067, 0.067)
        name:SetFont(GT.ResolveFont("Expressway") or GT.FONT, 13, "OUTLINE")
        name:SetPoint("CENTER", 0, 0)
        name:SetTextColor(paladin[1], paladin[2], paladin[3])
    end
    name:SetText("Dawnblade")
    return f
end

local function Choose(skin)
    GT.db.general.welcomed = true
    if skin then GT.Set("style.skin", skin) end
    if win then win:Hide() end
    if skin then
        GT.Print((skin == "BLIZZARD" and "Blizzard" or "Modern") .. " look picked. Change it any time: /gf -> General -> Frame Skin.")
    end
end

local function Card(parent, x, title, desc, skin)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(200, 190)
    card:SetPoint("TOP", x, -96)
    UI.Fill(card, C.row)
    local outline = UI.Outline(card, C.border)
    local p = Preview(card, skin == "BLIZZARD")
    p:SetPoint("TOP", 0, -16)
    local t = UI.Font(card, 15, C.text)
    t:SetPoint("TOP", p, "BOTTOM", 0, -12)
    t:SetText(title)
    local d = UI.Font(card, 11, C.muted)
    d:SetPoint("TOP", t, "BOTTOM", 0, -6)
    d:SetWidth(180)
    d:SetWordWrap(true)
    d:SetText(desc)
    local pick = UI.Button(card, "Pick " .. title, function() Choose(skin) end, 170)
    pick:SetPoint("BOTTOM", 0, 10)
    card:SetScript("OnEnter", function() outline:SetColor(C.accent[1], C.accent[2], C.accent[3], 1) end)
    card:SetScript("OnLeave", function() outline:SetColor(C.border[1], C.border[2], C.border[3], 1) end)
    card:SetScript("OnClick", function() Choose(skin) end)
    return card
end

local function Create()
    win = CreateFrame("Frame", "GramFramesWelcome", UIParent)
    win:SetSize(470, 350)
    win:SetPoint("CENTER", 0, 60)
    win:SetFrameStrata("DIALOG")
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    UI.Fill(win, C.bg, 0.97)
    UI.Outline(win, C.accent, 0.8)

    local logo = win:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(GT.media .. "emblem")
    logo:SetSize(44, 44)
    logo:SetPoint("TOPLEFT", 16, -12)
    local title = UI.Font(win, 20, C.accent)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -4)
    title:SetText("Welcome to Gram Frames")
    local sub = UI.Font(win, 12, C.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("Pick a look for your party and raid frames.")

    Card(win, -110, "Modern", "Dark bars, class-colored names. Pick your own colors.", "GRAM")
    Card(win, 110, "Blizzard", "Looks like the default raid frames: class-colored bars.", "BLIZZARD")

    local foot = UI.Font(win, 11, C.muted)
    foot:SetPoint("BOTTOM", 0, 16)
    foot:SetText("Change it any time: /gf  ->  General  ->  Frame Skin")

    local close = CreateFrame("Button", nil, win)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -6, -6)
    close.t = UI.Font(close, 14, C.muted)
    close.t:SetPoint("CENTER")
    close.t:SetText("x")
    close:SetScript("OnClick", function() Choose(nil) end) -- keep the current look
end

function GT.ShowWelcome()
    if InCombatLockdown() then return end
    if not win then Create() end
    win:Show()
end

local function MaybeShow()
    if not GT.db or GT.db.general.welcomed then return end
    if InCombatLockdown() then return end -- try again after combat
    GT.ShowWelcome()
end

GT.On("Login", function()
    if C_Timer and C_Timer.After then C_Timer.After(3, MaybeShow) else MaybeShow() end
end)
GT.On("CombatEnd", MaybeShow)
