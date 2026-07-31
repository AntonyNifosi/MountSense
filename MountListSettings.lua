-------------------------------------------------------------------------------
-- MountList — Settings Panel
-- Toggle options for smart flyable conditions and 3D preview rotation
-------------------------------------------------------------------------------
local addonName, addon = ...
local Settings = {}
addon.Settings = Settings

Settings.frame = nil

-------------------------------------------------------------------------------
-- Create the settings UI inside the given parent frame
-------------------------------------------------------------------------------
function Settings:Create(parent)
    if self.frame then return end

    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f

    ---------------------------------------------------------------------------
    -- Panel container
    ---------------------------------------------------------------------------
    local panel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", 8, -8)
    panel:SetPoint("BOTTOMRIGHT", -8, 8)
    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(unpack(addon.UI.C.bgPanel))
    panel:SetBackdropBorderColor(unpack(addon.UI.C.border))

    ---------------------------------------------------------------------------
    -- Header
    ---------------------------------------------------------------------------
    local header = panel:CreateFontString(nil, "OVERLAY")
    header:SetFont(addon.UI.FONT, 14, "")
    header:SetPoint("TOPLEFT", 16, -16)
    header:SetText("Settings")
    header:SetTextColor(unpack(addon.UI.C.accent))

    local subtext = panel:CreateFontString(nil, "OVERLAY")
    subtext:SetFont(addon.UI.FONT, 10, "")
    subtext:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    subtext:SetText("Configure MountList behaviour.")
    subtext:SetTextColor(unpack(addon.UI.C.textDim))

    -- Separator
    local sep1 = panel:CreateTexture(nil, "ARTWORK")
    sep1:SetHeight(1)
    sep1:SetPoint("TOPLEFT", 12, -54)
    sep1:SetPoint("TOPRIGHT", -12, -54)
    sep1:SetColorTexture(addon.UI.C.border[1], addon.UI.C.border[2],
                         addon.UI.C.border[3], 0.5)

    ---------------------------------------------------------------------------
    -- Section: Summon Behaviour
    ---------------------------------------------------------------------------
    local secSummon = addon.UI:CreateSectionHeader(panel, "Summon Behaviour")
    secSummon:SetPoint("TOPLEFT", 16, -72)

    -- Smart flyable toggle
    local smartToggle = self:CreateToggleRow(panel,
        "Interface\\Icons\\ability_mount_drake_blue",
        "Smart Zone Detection",
        "In flyable zones, prefer flying mounts. In non-flyable zones, exclude flying mounts. Falls back to all mounts if no match found.",
        "smartFlyable")
    smartToggle:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -100)
    smartToggle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -100)
    self.smartToggle = smartToggle

    -- Separator
    local sep2 = panel:CreateTexture(nil, "ARTWORK")
    sep2:SetHeight(1)
    sep2:SetPoint("TOPLEFT", 12, -168)
    sep2:SetPoint("TOPRIGHT", -12, -168)
    sep2:SetColorTexture(addon.UI.C.border[1], addon.UI.C.border[2],
                         addon.UI.C.border[3], 0.5)

    ---------------------------------------------------------------------------
    -- Section: Browse & Preview
    ---------------------------------------------------------------------------
    local secBrowse = addon.UI:CreateSectionHeader(panel, "Browse & Preview")
    secBrowse:SetPoint("TOPLEFT", 16, -184)

    -- Preview rotation toggle
    local rotateToggle = self:CreateToggleRow(panel,
        "Interface\\Icons\\spell_arcane_portalundercity",
        "3D Preview Auto-Rotation",
        "Automatically rotate the 3D mount preview after 2 seconds of hovering over a mount card.",
        "previewRotation")
    rotateToggle:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -210)
    rotateToggle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -210)
    self.rotateToggle = rotateToggle
end

-------------------------------------------------------------------------------
-- Helper: create a toggle row (icon + title + description + ON/OFF switch)
-------------------------------------------------------------------------------
function Settings:CreateToggleRow(parent, iconPath, title, desc, optionKey)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(58)
    row:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    row:SetBackdropColor(unpack(addon.UI.C.bgCard))
    row:SetBackdropBorderColor(unpack(addon.UI.C.border))
    row.optionKey = optionKey

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", 12, 0)
    icon:SetTexture(iconPath)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Title
    local titleText = row:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(addon.UI.FONT, 12, "")
    titleText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -6)
    titleText:SetText(title)
    titleText:SetTextColor(unpack(addon.UI.C.textBright))

    -- Description
    local descText = row:CreateFontString(nil, "OVERLAY")
    descText:SetFont(addon.UI.FONT, 9, "")
    descText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -3)
    descText:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    descText:SetText(desc)
    descText:SetTextColor(unpack(addon.UI.C.textDim))
    descText:SetJustifyH("LEFT")
    descText:SetWordWrap(true)

    -- Toggle switch (pill-style button)
    local toggle = CreateFrame("Button", nil, row, "BackdropTemplate")
    toggle:SetSize(52, 26)
    toggle:SetPoint("RIGHT", -12, 0)
    toggle:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    toggle:SetBackdropColor(unpack(addon.UI.C.bgInput))
    toggle:SetBackdropBorderColor(unpack(addon.UI.C.border))
    toggle.enabled = false
    row.toggle = toggle

    -- Toggle knob
    local knob = toggle:CreateTexture(nil, "OVERLAY")
    knob:SetSize(20, 20)
    knob:SetPoint("LEFT", 3, 0)
    knob:SetColorTexture(0.4, 0.4, 0.5, 1)
    toggle.knob = knob

    -- Toggle label
    local toggleLabel = toggle:CreateFontString(nil, "OVERLAY")
    toggleLabel:SetFont(addon.UI.FONT, 8, "")
    toggleLabel:SetPoint("RIGHT", -4, 0)
    toggleLabel:SetText("OFF")
    toggleLabel:SetTextColor(unpack(addon.UI.C.textDim))
    toggle.label = toggleLabel

    function toggle:SetEnabled(val)
        self.enabled = val
        if val then
            self:SetBackdropColor(unpack(addon.UI.C.accentBg))
            self:SetBackdropBorderColor(unpack(addon.UI.C.accent))
            self.knob:ClearAllPoints()
            self.knob:SetPoint("RIGHT", -3, 0)
            self.knob:SetColorTexture(addon.UI.C.accent[1], addon.UI.C.accent[2], addon.UI.C.accent[3], 1)
            self.label:ClearAllPoints()
            self.label:SetPoint("LEFT", 4, 0)
            self.label:SetText("ON")
            self.label:SetTextColor(unpack(addon.UI.C.accent))
        else
            self:SetBackdropColor(unpack(addon.UI.C.bgInput))
            self:SetBackdropBorderColor(unpack(addon.UI.C.border))
            self.knob:ClearAllPoints()
            self.knob:SetPoint("LEFT", 3, 0)
            self.knob:SetColorTexture(0.4, 0.4, 0.5, 1)
            self.label:ClearAllPoints()
            self.label:SetPoint("RIGHT", -4, 0)
            self.label:SetText("OFF")
            self.label:SetTextColor(unpack(addon.UI.C.textDim))
        end
    end

    toggle:SetScript("OnClick", function(self)
        local newVal = not self.enabled
        self:SetEnabled(newVal)
        local opts = addon.Data.db.options
        if opts then
            opts[row.optionKey] = newVal
        end
        -- Live apply: cancel rotation if disabled
        if row.optionKey == "previewRotation" and not newVal then
            if addon.Browser and addon.Browser.model then
                addon.Browser.model.autoRotateStarted = false
                if addon.Browser.model.autoRotateTimer then
                    addon.Browser.model.autoRotateTimer:Cancel()
                    addon.Browser.model.autoRotateTimer = nil
                end
            end
        end
        -- Live apply: re-pick mount if smart flyable toggled
        if row.optionKey == "smartFlyable" then
            addon.Summon:UpdateMount()
        end
    end)

    toggle:SetScript("OnEnter", function(self)
        if self.enabled then
            self:SetBackdropBorderColor(1, 0.9, 0.3, 1)
        else
            self:SetBackdropBorderColor(unpack(addon.UI.C.accent))
        end
    end)
    toggle:SetScript("OnLeave", function(self)
        if self.enabled then
            self:SetBackdropBorderColor(unpack(addon.UI.C.accent))
        else
            self:SetBackdropBorderColor(unpack(addon.UI.C.border))
        end
    end)

    return row
end

-------------------------------------------------------------------------------
-- Refresh — sync toggle states with saved DB values
-------------------------------------------------------------------------------
function Settings:Refresh()
    if not self.frame then return end
    local opts = addon.Data.db and addon.Data.db.options
    if not opts then return end

    if self.smartToggle then
        self.smartToggle.toggle:SetEnabled(opts.smartFlyable ~= false)
    end
    if self.rotateToggle then
        self.rotateToggle.toggle:SetEnabled(opts.previewRotation ~= false)
    end
end
