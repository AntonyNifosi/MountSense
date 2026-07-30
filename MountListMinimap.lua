-------------------------------------------------------------------------------
-- MountList — Minimap Button
-- Draggable button around the minimap edge
-------------------------------------------------------------------------------
local addonName, addon = ...
local MM = {}
addon.Minimap = MM

MM.button = nil

local MINIMAP_RADIUS = 80

-------------------------------------------------------------------------------
-- Create
-------------------------------------------------------------------------------
function MM:Create()
    if self.button then return end

    local btn = CreateFrame("Button", "MountListMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetClampedToScreen(true)
    btn:EnableMouse(true)
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Background circle
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(34, 34)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    -- Overlay highlight
    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(24, 24)
    overlay:SetPoint("CENTER")
    overlay:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    overlay:SetBlendMode("ADD")
    overlay:SetAlpha(0)
    btn.overlay = overlay

    -- Position
    self:UpdatePosition()

    ---------------------------------------------------------------------------
    -- Dragging around minimap edge
    ---------------------------------------------------------------------------
    btn:SetScript("OnDragStart", function(self)
        self.dragging = true
    end)

    btn:SetScript("OnDragStop", function(self)
        self.dragging = false
    end)

    btn:SetScript("OnUpdate", function(self)
        if not self.dragging then return end

        local cx, cy = Minimap:GetCenter()
        local mx, my = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        mx, my = mx / scale, my / scale

        local angle = math.atan2(my - cy, mx - cx)
        local deg = math.deg(angle)
        if deg < 0 then deg = deg + 360 end

        addon.Data.db.minimap.minimapPos = deg
        MM:SetPosition(deg)
    end)

    ---------------------------------------------------------------------------
    -- Click handlers
    ---------------------------------------------------------------------------
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            addon.UI:Toggle()
        elseif button == "RightButton" then
            addon.Summon:SummonRandom()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        self.overlay:SetAlpha(0.3)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cffFFB800MountList|r", 1, 1, 1)
        GameTooltip:AddLine("Left-click: Open panel", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Right-click: Summon random mount", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Drag: Reposition", 0.55, 0.55, 0.6)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        self.overlay:SetAlpha(0)
        GameTooltip:Hide()
    end)

    self.button = btn

    -- Hide if user preference
    if addon.Data.db.minimap.hide then
        btn:Hide()
    end
end

-------------------------------------------------------------------------------
-- Position helpers
-------------------------------------------------------------------------------
function MM:SetPosition(degrees)
    if not self.button then return end
    local rad = math.rad(degrees)
    local x = math.cos(rad) * MINIMAP_RADIUS
    local y = math.sin(rad) * MINIMAP_RADIUS
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MM:UpdatePosition()
    local deg = addon.Data.db.minimap.minimapPos or 220
    self:SetPosition(deg)
end

-------------------------------------------------------------------------------
-- Toggle visibility
-------------------------------------------------------------------------------
function MM:Toggle()
    if not self.button then return end
    if self.button:IsShown() then
        self.button:Hide()
        addon.Data.db.minimap.hide = true
    else
        self.button:Show()
        addon.Data.db.minimap.hide = false
    end
end
