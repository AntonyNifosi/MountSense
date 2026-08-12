-------------------------------------------------------------------------------
-- MountSense — Settings Panel
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
    subtext:SetText("Configure MountSense behaviour.")
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

    -- Smart aquatic toggle
    local aquaticToggle = self:CreateToggleRow(panel,
        "Interface\\Icons\\INV_Misc_Fish_35",
        "Smart Aquatic Detection",
        "While swimming, prefer aquatic mounts. Otherwise, exclude aquatic mounts. Falls back to all mounts if no match found.",
        "smartAquatic")
    aquaticToggle:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -168)
    aquaticToggle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -168)
    self.aquaticToggle = aquaticToggle

    -- Anti-repeat toggle
    local antiRepeatToggle = self:CreateToggleRow(panel,
        "Interface\\Icons\\INV_Misc_Dice_02",
        "Avoid Repeats",
        "Don't resummon any of the last few mounts you actually rode. Falls back to repeats if your matching mounts run out.",
        "antiRepeat")
    antiRepeatToggle:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -236)
    antiRepeatToggle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -236)
    self.antiRepeatToggle = antiRepeatToggle

    -- Separator
    local sep2 = panel:CreateTexture(nil, "ARTWORK")
    sep2:SetHeight(1)
    sep2:SetPoint("TOPLEFT", 12, -304)
    sep2:SetPoint("TOPRIGHT", -12, -304)
    sep2:SetColorTexture(addon.UI.C.border[1], addon.UI.C.border[2],
                         addon.UI.C.border[3], 0.5)

    ---------------------------------------------------------------------------
    -- Section: Browse & Preview
    ---------------------------------------------------------------------------
    local secBrowse = addon.UI:CreateSectionHeader(panel, "Browse & Preview")
    secBrowse:SetPoint("TOPLEFT", 16, -320)

    -- Preview rotation toggle
    local rotateToggle = self:CreateToggleRow(panel,
        "Interface\\Icons\\spell_arcane_portalundercity",
        "3D Preview Auto-Rotation",
        "Automatically rotate the 3D mount preview after 2 seconds of hovering over a mount card.",
        "previewRotation")
    rotateToggle:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -346)
    rotateToggle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -346)
    self.rotateToggle = rotateToggle

    -- Separator
    local sep3 = panel:CreateTexture(nil, "ARTWORK")
    sep3:SetHeight(1)
    sep3:SetPoint("TOPLEFT", 12, -414)
    sep3:SetPoint("TOPRIGHT", -12, -414)
    sep3:SetColorTexture(addon.UI.C.border[1], addon.UI.C.border[2],
                         addon.UI.C.border[3], 0.5)

    ---------------------------------------------------------------------------
    -- Section: Keybinding
    ---------------------------------------------------------------------------
    local secKeybind = addon.UI:CreateSectionHeader(panel, "Keybinding")
    secKeybind:SetPoint("TOPLEFT", 16, -430)

    local keybindRow = self:CreateKeybindRow(panel)
    keybindRow:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -458)
    keybindRow:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -458)
end

-------------------------------------------------------------------------------
-- Helper: the keybind row — a capture button that sets the "MOUNTSENSE_INSPECT"
-- binding (declared in Bindings.xml) directly, the same way Blizzard's own
-- Key Bindings UI would, without leaving the addon. Pattern (ignoreKeys list,
-- modifier prefixing, SetBinding/SaveBindings) follows the widely-used
-- PhanxConfig-KeyBinding library: https://github.com/phanx-wow/PhanxConfig-KeyBinding
-------------------------------------------------------------------------------
local INSPECT_BINDING_ACTION = "MOUNTSENSE_INSPECT"

local IGNORE_KEYS = {
    ["LeftButton"] = true, ["RightButton"] = true,
    ["BUTTON1"] = true, ["BUTTON2"] = true,
    ["LALT"] = true, ["LCTRL"] = true, ["LSHIFT"] = true,
    ["RALT"] = true, ["RCTRL"] = true, ["RSHIFT"] = true,
    ["UNKNOWN"] = true,
}

function Settings:CreateKeybindRow(parent)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(58)
    row:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    row:SetBackdropColor(unpack(addon.UI.C.bgCard))
    row:SetBackdropBorderColor(unpack(addon.UI.C.border))

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", 12, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local titleText = row:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(addon.UI.FONT, 12, "")
    titleText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -6)
    titleText:SetText("Inspect Mount Keybind")
    titleText:SetTextColor(unpack(addon.UI.C.textBright))

    local descText = row:CreateFontString(nil, "OVERLAY")
    descText:SetFont(addon.UI.FONT, 9, "")
    descText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -3)
    descText:SetPoint("RIGHT", row, "RIGHT", -160, 0)
    descText:SetText("Add your target/moused-over player's mount to a list. Click to set a key, right-click to clear.")
    descText:SetTextColor(unpack(addon.UI.C.textDim))
    descText:SetJustifyH("LEFT")
    descText:SetWordWrap(true)

    local keyBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
    keyBtn:SetSize(150, 26)
    keyBtn:SetPoint("RIGHT", -12, 0)
    keyBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    keyBtn:SetBackdropColor(unpack(addon.UI.C.bgInput))
    keyBtn:SetBackdropBorderColor(unpack(addon.UI.C.border))
    keyBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local keyText = keyBtn:CreateFontString(nil, "OVERLAY")
    keyText:SetFont(addon.UI.FONT, 11, "")
    keyText:SetPoint("CENTER")
    keyText:SetTextColor(unpack(addon.UI.C.text))
    keyBtn.text = keyText
    self.keyBtn = keyBtn

    keyBtn:SetScript("OnClick", function(self, button)
        if self.waitingForKey then return end

        if button == "RightButton" then
            Settings:SetInspectBinding(nil)
            return
        end

        self.waitingForKey = true
        self.text:SetText("Press a key...")
        self:SetBackdropBorderColor(unpack(addon.UI.C.accent))
        self:EnableKeyboard(true)
        self:SetPropagateKeyboardInput(false)
    end)

    keyBtn:SetScript("OnKeyDown", function(self, key)
        if not self.waitingForKey or IGNORE_KEYS[key] then return end

        self.waitingForKey = nil
        self:EnableKeyboard(false)
        self:SetBackdropBorderColor(unpack(addon.UI.C.border))

        if key == "ESCAPE" then
            Settings:RefreshKeybindDisplay()
            return
        end

        if key == "MiddleButton" then
            key = "BUTTON3"
        elseif key:match("^Button%d+$") then
            key = key:upper()
        end

        if IsShiftKeyDown() then key = "SHIFT-" .. key end
        if IsControlKeyDown() then key = "CTRL-" .. key end
        if IsAltKeyDown() then key = "ALT-" .. key end

        Settings:SetInspectBinding(key)
    end)

    keyBtn:SetScript("OnHide", function(self)
        self.waitingForKey = nil
        self:EnableKeyboard(false)
    end)

    keyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Click to set a key")
        GameTooltip:AddLine("Right-click to clear", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    keyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self:RefreshKeybindDisplay()

    return row
end

-------------------------------------------------------------------------------
-- Assign (or, if key is nil, clear) the MOUNTSENSE_INSPECT binding and save
-- it to whichever binding set (account-wide vs this-character) is currently
-- active — same call Blizzard's own Key Bindings UI makes on confirm.
-------------------------------------------------------------------------------
function Settings:SetInspectBinding(key)
    local prev1, prev2 = GetBindingKey(INSPECT_BINDING_ACTION)
    if prev1 then SetBinding(prev1) end
    if prev2 then SetBinding(prev2) end

    if key then
        local conflictAction = GetBindingAction(key)
        if conflictAction and conflictAction ~= "" and conflictAction ~= INSPECT_BINDING_ACTION then
            addon:Print("That key was already bound elsewhere — it's now bound to MountSense instead.")
        end
        SetBinding(key, INSPECT_BINDING_ACTION)
    end

    SaveBindings(GetCurrentBindingSet())
    self:RefreshKeybindDisplay()
end

function Settings:RefreshKeybindDisplay()
    if not self.keyBtn then return end
    local key = GetBindingKey(INSPECT_BINDING_ACTION)
    self.keyBtn.text:SetText(key or "Not Bound")
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
        -- Live apply: re-pick mount if smart flyable/aquatic/anti-repeat toggled
        if row.optionKey == "smartFlyable" or row.optionKey == "smartAquatic"
           or row.optionKey == "antiRepeat" then
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
    if self.aquaticToggle then
        self.aquaticToggle.toggle:SetEnabled(opts.smartAquatic ~= false)
    end
    if self.antiRepeatToggle then
        self.antiRepeatToggle.toggle:SetEnabled(opts.antiRepeat ~= false)
    end
    if self.rotateToggle then
        self.rotateToggle.toggle:SetEnabled(opts.previewRotation ~= false)
    end

    self:RefreshKeybindDisplay()
end
