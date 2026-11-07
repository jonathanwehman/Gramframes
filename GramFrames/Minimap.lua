-- GramFrames: minimap button (left-click options, right-click lock, drag to move)
local _, GT = ...

local button

local function UpdatePosition()
    if not button then return end
    local angle = math.rad(GT.db.minimap.angle or 220)
    local radius = (Minimap:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local atan2 = math.atan2 or atan2
    GT.db.minimap.angle = math.deg(atan2(py - my, px - mx))
    UpdatePosition()
end

local function Create()
    if button or not Minimap then return end
    button = CreateFrame("Button", "GramFramesMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(136477) -- UI-Minimap-ZoomButton-Highlight

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(136467) -- UI-Minimap-Background
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(GT.media .. "emblem")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture(136430) -- MiniMap-TrackingBorder
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then GT.ToggleLock() else GT.ToggleOptions() end
    end)
    button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cffff4fa3GRAM|r FRAMES")
        GameTooltip:AddLine("|cffffffffLeft-click:|r options", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffffffRight-click:|r " .. (GT.db.general.locked and "unlock frames" or "lock frames"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffffffDrag:|r move this button", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UpdatePosition()
end

local function Update()
    if GT.db.minimap.hide then
        if button then button:Hide() end
    else
        Create()
        if button then button:Show() end
    end
end

GT.On("Login", Update)
GT.On("MinimapChanged", Update)
GT.On("SettingChanged", function(section)
    if section == "minimap" or section == "all" then Update() end
end)
