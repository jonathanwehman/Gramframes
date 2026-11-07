-- GramFrames: tiny widget kit for the options window (flat dark style, pink accent)
local _, GT = ...
local UI = {}
GT.UI = UI

local FLAT = GT.FLAT
local C = GT.colors

local function Tex(parent, layer, col, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(FLAT)
    if col then t:SetVertexColor(col[1], col[2], col[3], a or 1) end
    return t
end
UI.Tex = Tex

function UI.Font(parent, size, col, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    GT.SetFont(fs, size or 12, flags or "")
    col = col or C.text
    fs:SetTextColor(col[1], col[2], col[3])
    fs:SetWordWrap(false)
    return fs
end

function UI.Fill(frame, col, a)
    local t = Tex(frame, "BACKGROUND", col, a)
    t:SetAllPoints()
    frame.fill = t
    return t
end

-- 1px outline
function UI.Outline(frame, col, a)
    local b = GT.CreateBorder(frame, "BORDER", 0)
    b:SetColor(col[1], col[2], col[3], a or 1)
    return b
end

-------------------------------------------------------------------------------
-- Toggle (pill switch)
-------------------------------------------------------------------------------
function UI.Toggle(parent, get, set)
    local f = CreateFrame("Button", nil, parent)
    local W, H = 32, 16
    f:SetSize(W, H)
    -- pill track: a round cap on each end + a flat middle (masks make the circles)
    local function Round(tex)
        local ok, mask = pcall(f.CreateMaskTexture, f)
        if ok and mask then
            mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(tex)
            pcall(tex.AddMaskTexture, tex, mask)
        end
    end
    local capL, capR, mid = Tex(f, "BACKGROUND"), Tex(f, "BACKGROUND"), Tex(f, "BACKGROUND")
    capL:SetSize(H, H); capL:SetPoint("LEFT")
    capR:SetSize(H, H); capR:SetPoint("RIGHT")
    mid:SetPoint("TOPLEFT", H / 2, 0); mid:SetPoint("BOTTOMRIGHT", -H / 2, 0)
    Round(capL); Round(capR)
    f.trackParts = { capL, capR, mid }
    f.track = { SetAlpha = function(_, a) for _, t in ipairs(f.trackParts) do t:SetAlpha(a) end end }
    f.knob = Tex(f, "ARTWORK", { 0.97, 0.97, 0.99 })
    f.knob:SetSize(H - 4, H - 4)
    Round(f.knob)
    local function Paint(r, g, b, a) for _, t in ipairs(f.trackParts) do t:SetVertexColor(r, g, b, a) end end
    function f:Refresh()
        local on = get() and true or false
        self.on = on
        if on then
            Paint(C.accent[1], C.accent[2], C.accent[3], 1)
            self.knob:ClearAllPoints(); self.knob:SetPoint("RIGHT", -2, 0)
        else
            Paint(0.27, 0.26, 0.30, 1)
            self.knob:ClearAllPoints(); self.knob:SetPoint("LEFT", 2, 0)
        end
    end
    f:SetScript("OnClick", function(self)
        set(not self.on)
        self:Refresh()
        if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
    end)
    f:SetScript("OnEnter", function(self) self.track:SetAlpha(0.85) end)
    f:SetScript("OnLeave", function(self) self.track:SetAlpha(1) end)
    f:Refresh()
    return f
end

-------------------------------------------------------------------------------
-- Slider + value box
-------------------------------------------------------------------------------
local function Round(v, step)
    return math.floor(v / step + 0.5) * step
end

function UI.Slider(parent, min, max, step, get, set, decimals)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(190, 20)
    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("LEFT", 0, 0)
    s:SetPoint("RIGHT", -60, 0)
    s:SetHeight(14)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s.track = Tex(s, "BACKGROUND", { 0.30, 0.29, 0.34 })
    s.track:SetHeight(3)
    s.track:SetPoint("LEFT", 0, 0)
    s.track:SetPoint("RIGHT", 0, 0)
    s.fillTex = Tex(s, "BORDER", C.accent)
    s.fillTex:SetHeight(3)
    s.fillTex:SetPoint("LEFT", 0, 0)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(FLAT)
    thumb:SetSize(12, 12)
    thumb:SetVertexColor(0.95, 0.95, 0.97)
    s:SetThumbTexture(thumb)
    local ok, mask = pcall(s.CreateMaskTexture, s)
    if ok and mask then
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(thumb)
        pcall(thumb.AddMaskTexture, thumb, mask)
    end
    f.slider = s

    local box = CreateFrame("EditBox", nil, f)
    box:SetSize(50, 20)
    box:SetPoint("RIGHT", 0, 0)
    box:SetAutoFocus(false)
    GT.SetFont(box, 12, "")
    box:SetJustifyH("CENTER")
    box:SetTextColor(C.text[1], C.text[2], C.text[3])
    UI.Fill(box, { 0.06, 0.06, 0.07 })
    UI.Outline(box, C.border)
    f.box = box

    local fmt = "%." .. (decimals or 0) .. "f"
    local updating = false
    local function UpdateFill(v)
        local w = s:GetWidth()
        if w and w > 0 then
            s.fillTex:SetWidth(math.max(1, (v - min) / (max - min) * w))
        end
    end
    function f:Refresh()
        updating = true
        local v = get()
        s:SetValue(v)
        box:SetText(string.format(fmt, v))
        UpdateFill(v)
        updating = false
    end
    s:SetScript("OnValueChanged", function(_, v)
        if updating then return end
        v = Round(v, step)
        box:SetText(string.format(fmt, v))
        UpdateFill(v)
        set(v)
    end)
    s:SetScript("OnSizeChanged", function() UpdateFill(s:GetValue()) end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(_, delta)
        local v = math.min(max, math.max(min, Round(s:GetValue() + delta * step, step)))
        s:SetValue(v)
    end)
    box:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then
            v = math.min(max, math.max(min, Round(v, step)))
            set(v)
        end
        f:Refresh()
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self) f:Refresh(); self:ClearFocus() end)
    f:Refresh()
    return f
end

-------------------------------------------------------------------------------
-- Dropdown
-------------------------------------------------------------------------------
local menu -- one shared popup
local function GetMenu()
    if menu then return menu end
    menu = CreateFrame("Frame", "GramFramesDropdownMenu", UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    UI.Fill(menu, { 0.07, 0.068, 0.08 })
    UI.Outline(menu, C.border)
    menu.items = {}
    menu:Hide()
    menu:SetScript("OnHide", function(self) self.owner = nil end)
    return menu
end
UI.GetMenu = GetMenu

local MAX_ROWS = 14
function UI.Dropdown(parent, options, get, set)
    local function Opts() return type(options) == "function" and options() or options end
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(190, 22)
    UI.Fill(f, { 0.155, 0.148, 0.172 })
    f.text = UI.Font(f, 12)
    f.text:SetPoint("LEFT", 8, 0)
    f.text:SetPoint("RIGHT", -18, 0)
    f.text:SetJustifyH("LEFT")
    f.arrow = UI.Font(f, 10, C.muted)
    f.arrow:SetPoint("RIGHT", -7, 0)
    f.arrow:SetText("v")
    function f:Refresh()
        local v = get()
        for _, o in ipairs(Opts()) do
            if o[1] == v then self.text:SetText(o[2]) return end
        end
        self.text:SetText((v == nil or v == "") and "|cff888888choose...|r" or tostring(v))
    end
    f:SetScript("OnEnter", function(self) self.fill:SetVertexColor(0.19, 0.18, 0.21) end)
    f:SetScript("OnLeave", function(self) self.fill:SetVertexColor(0.155, 0.148, 0.172) end)
    local function Render(m, offset)
        local opts = Opts()
        for _, it in ipairs(m.items) do it:Hide() end
        local rows = math.min(#opts, MAX_ROWS)
        for row = 1, rows do
            local o = opts[row + offset]
            if not o then break end
            local it = m.items[row]
            if not it then
                it = CreateFrame("Button", nil, m)
                it:SetHeight(22)
                it.hl = Tex(it, "BACKGROUND", C.accent, 0)
                it.hl:SetAllPoints()
                it.text = UI.Font(it, 12)
                it.text:SetPoint("LEFT", 8, 0)
                it.text:SetPoint("RIGHT", -8, 0)
                it.text:SetJustifyH("LEFT")
                it:SetScript("OnEnter", function(s2) s2.hl:SetAlpha(0.25) end)
                it:SetScript("OnLeave", function(s2) s2.hl:SetAlpha(s2.selected and 0.12 or 0) end)
                m.items[row] = it
            end
            it:ClearAllPoints()
            it:SetPoint("TOPLEFT", 1, -1 - (row - 1) * 22)
            it:SetPoint("TOPRIGHT", -1, -1 - (row - 1) * 22)
            it.text:SetText(o[2])
            it.selected = (o[1] == get())
            it.hl:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
            it.hl:SetAlpha(it.selected and 0.12 or 0)
            it:SetScript("OnClick", function()
                set(o[1])
                f:Refresh()
                m:Hide()
            end)
            it:Show()
        end
        m:SetHeight(rows * 22 + 2)
        -- scroll thumb so long lists (spells) obviously scroll
        if not m.thumb then
            m.thumb = Tex(m, "OVERLAY", C.accent, 0.8)
            m.thumb:SetWidth(3)
        end
        if #opts > MAX_ROWS then
            local trackH = rows * 22
            local thumbH = math.max(16, trackH * MAX_ROWS / #opts)
            local maxOff = #opts - MAX_ROWS
            m.thumb:SetHeight(thumbH)
            m.thumb:ClearAllPoints()
            m.thumb:SetPoint("TOPRIGHT", -1, -1 - (trackH - thumbH) * (offset / maxOff))
            m.thumb:Show()
        else
            m.thumb:Hide()
        end
    end
    f:SetScript("OnClick", function(self)
        local m = GetMenu()
        if m:IsShown() and m.owner == self then m:Hide() return end
        m.owner = self
        m:SetScale(self:GetEffectiveScale() / UIParent:GetEffectiveScale())
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        m:SetWidth(math.max(self:GetWidth(), #Opts() > MAX_ROWS and 210 or 160))
        m.offset = 0
        -- long lists (like a spellbook) scroll with the mouse wheel
        m:EnableMouseWheel(true)
        m:SetScript("OnMouseWheel", function(menu, delta)
            local maxOff = math.max(0, #Opts() - MAX_ROWS)
            menu.offset = math.max(0, math.min(maxOff, (menu.offset or 0) - delta * 3))
            Render(menu, menu.offset)
        end)
        Render(m, 0)
        m:Show()
    end)
    f:Refresh()
    return f
end

-------------------------------------------------------------------------------
-- Button
-------------------------------------------------------------------------------
function UI.Button(parent, text, onClick, width)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 120, 26)
    UI.Fill(b, { 0.26, 0.20, 0.32 })
    b.text = UI.Font(b, 12)
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    function b:SetActive(on)
        self.active = on
        if on then self.fill:SetVertexColor(C.accent[1] * 0.75, C.accent[2] * 0.75, C.accent[3] * 0.75)
        else self.fill:SetVertexColor(0.26, 0.20, 0.32) end
    end
    b:SetScript("OnEnter", function(self) self.fill:SetAlpha(0.85) end)
    b:SetScript("OnLeave", function(self) self.fill:SetAlpha(1) end)
    b:SetScript("OnClick", function(self) onClick(self) end)
    return b
end

-------------------------------------------------------------------------------
-- Text input
-------------------------------------------------------------------------------
function UI.Input(parent, get, set, placeholder)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(190, 22)
    box:SetAutoFocus(false)
    GT.SetFont(box, 12, "")
    box:SetTextInsets(8, 8, 0, 0)
    box:SetTextColor(C.text[1], C.text[2], C.text[3])
    UI.Fill(box, { 0.06, 0.06, 0.07 })
    UI.Outline(box, C.border)
    box.ph = UI.Font(box, 12, C.muted)
    box.ph:SetPoint("LEFT", 8, 0)
    box.ph:SetText(placeholder or "")
    function box:Refresh()
        self:SetText(get() or "")
        self.ph:SetShown(self:GetText() == "")
    end
    box:SetScript("OnTextChanged", function(self) self.ph:SetShown(self:GetText() == "") end)
    box:SetScript("OnEnterPressed", function(self) set(self:GetText()); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self) set(self:GetText()) end)
    box:SetScript("OnEscapePressed", function(self) self:Refresh(); self:ClearFocus() end)
    box:Refresh()
    return box
end

-------------------------------------------------------------------------------
-- Color swatch (opens the game's color picker)
-------------------------------------------------------------------------------
function UI.Swatch(parent, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(40, 18)
    UI.Outline(b, { 0, 0, 0 })
    b.color = Tex(b, "ARTWORK")
    b.color:SetPoint("TOPLEFT", 1, -1)
    b.color:SetPoint("BOTTOMRIGHT", -1, 1)
    function b:Refresh()
        local c = get()
        self.color:SetVertexColor(c[1], c[2], c[3], 1)
    end
    b:SetScript("OnClick", function(self)
        local c = get()
        local prev = { c[1], c[2], c[3] }
        local function apply()
            local r, g, bl = ColorPickerFrame:GetColorRGB()
            set({ r, g, bl })
            self:Refresh()
        end
        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = c[1], g = c[2], b = c[3], hasOpacity = false,
                swatchFunc = apply,
                cancelFunc = function() set(prev); self:Refresh() end,
            })
        end
    end)
    b:Refresh()
    return b
end
