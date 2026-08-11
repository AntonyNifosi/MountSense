-------------------------------------------------------------------------------
-- MountSense — Main UI Frame
-- Creates the main window, tab system, shared style helpers, popups
-------------------------------------------------------------------------------
local addonName, addon = ...
local UI = {}
addon.UI = UI

UI.frame = nil
UI.currentTab = nil

-------------------------------------------------------------------------------
-- Style Palette
-------------------------------------------------------------------------------
UI.C = {
    bg           = { 0.06, 0.06, 0.10, 0.96 },
    bgPanel      = { 0.09, 0.09, 0.14, 1 },
    bgCard       = { 0.12, 0.12, 0.18, 1 },
    bgCardHover  = { 0.16, 0.16, 0.24, 1 },
    bgInput      = { 0.08, 0.08, 0.13, 1 },
    accent       = { 1.0, 0.72, 0.0 },
    accentDim    = { 0.80, 0.58, 0.0 },
    accentBg     = { 0.18, 0.14, 0.02, 1 },
    accentBgHov  = { 0.25, 0.20, 0.04, 1 },
    accentBlue   = { 0.30, 0.65, 1.0 },
    text         = { 0.93, 0.93, 0.93 },
    textDim      = { 0.55, 0.55, 0.60 },
    textBright   = { 1, 1, 1 },
    border       = { 0.22, 0.22, 0.28, 0.8 },
    borderAccent = { 1.0, 0.72, 0.0, 0.40 },
    success      = { 0.20, 0.80, 0.35 },
    danger       = { 0.90, 0.25, 0.25 },
    dangerBg     = { 0.25, 0.08, 0.08, 1 },
    selected     = { 0.25, 0.55, 1.0, 0.25 },
    tabActive    = { 1.0, 0.72, 0.0, 0.15 },
    tabHover     = { 1, 1, 1, 0.06 },
}

-- Font references (game built-in)
UI.FONT        = "Fonts\\FRIZQT__.TTF"
UI.FONT_HEADER = "Fonts\\MORPHEUS.TTF"

-------------------------------------------------------------------------------
-- Widget Helpers
-------------------------------------------------------------------------------

--- Create a styled button
function UI:CreateButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 120, height or 28)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(unpack(self.C.bgCard))
    btn:SetBackdropBorderColor(unpack(self.C.border))

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont(self.FONT, 11, "")
    label:SetPoint("CENTER")
    label:SetText(text or "")
    label:SetTextColor(unpack(self.C.text))
    btn.label = label

    btn:SetScript("OnEnter", function(s)
        s:SetBackdropColor(unpack(UI.C.bgCardHover))
        s:SetBackdropBorderColor(unpack(UI.C.accent))
    end)
    btn:SetScript("OnLeave", function(s)
        s:SetBackdropColor(unpack(UI.C.bgCard))
        s:SetBackdropBorderColor(unpack(UI.C.border))
    end)

    return btn
end

--- Create an accent (primary) button
function UI:CreateAccentButton(parent, text, width, height)
    local btn = self:CreateButton(parent, text, width, height)
    btn:SetBackdropColor(unpack(self.C.accentBg))
    btn:SetBackdropBorderColor(unpack(self.C.accent))
    btn.label:SetTextColor(unpack(self.C.accent))

    btn:SetScript("OnEnter", function(s)
        s:SetBackdropColor(unpack(UI.C.accentBgHov))
        s:SetBackdropBorderColor(1, 0.85, 0.2, 1)
        s.label:SetTextColor(1, 0.85, 0.2)
    end)
    btn:SetScript("OnLeave", function(s)
        s:SetBackdropColor(unpack(UI.C.accentBg))
        s:SetBackdropBorderColor(unpack(UI.C.accent))
        s.label:SetTextColor(unpack(UI.C.accent))
    end)
    return btn
end

--- Create a danger button
function UI:CreateDangerButton(parent, text, width, height)
    local btn = self:CreateButton(parent, text, width, height)
    btn.label:SetTextColor(unpack(self.C.danger))
    btn:SetScript("OnEnter", function(s)
        s:SetBackdropColor(unpack(UI.C.dangerBg))
        s:SetBackdropBorderColor(unpack(UI.C.danger))
    end)
    btn:SetScript("OnLeave", function(s)
        s:SetBackdropColor(unpack(UI.C.bgCard))
        s:SetBackdropBorderColor(unpack(UI.C.border))
    end)
    return btn
end

--- Create a search / text input
function UI:CreateEditBox(parent, width, height, placeholder)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width or 180, height or 26)
    box:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(unpack(self.C.bgInput))
    box:SetBackdropBorderColor(unpack(self.C.border))
    box:SetFont(self.FONT, 11, "")
    box:SetTextColor(unpack(self.C.text))
    box:SetTextInsets(8, 8, 0, 0)
    box:SetAutoFocus(false)
    box:EnableMouse(true)

    if placeholder then
        local ph = box:CreateFontString(nil, "ARTWORK")
        ph:SetFont(self.FONT, 11, "")
        ph:SetPoint("LEFT", 8, 0)
        ph:SetText(placeholder)
        ph:SetTextColor(unpack(self.C.textDim))
        box.placeholder = ph

        box:SetScript("OnTextChanged", function(self, userInput)
            if self:GetText() == "" then
                self.placeholder:Show()
            else
                self.placeholder:Hide()
            end
            if self.onTextChanged then
                self:onTextChanged(userInput)
            end
        end)
    end

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(unpack(UI.C.accent))
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(unpack(UI.C.border))
    end)

    return box
end

--- Create a styled checkbox
function UI:CreateCheckbox(parent, text, size)
    size = size or 18
    local frame = CreateFrame("Button", nil, parent)
    frame.checked = false

    -- Box background
    local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box:SetSize(size, size)
    box:SetPoint("LEFT")
    box:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(unpack(self.C.bgInput))
    box:SetBackdropBorderColor(unpack(self.C.border))
    frame.box = box

    -- Checkmark
    local check = box:CreateTexture(nil, "OVERLAY")
    check:SetPoint("CENTER")
    check:SetSize(size - 4, size - 4)
    check:SetColorTexture(unpack(self.C.accent))
    check:Hide()
    frame.check = check

    -- Label
    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFont(self.FONT, 11, "")
    label:SetPoint("LEFT", box, "RIGHT", 6, 0)
    label:SetText(text or "")
    label:SetTextColor(unpack(self.C.text))
    frame.label = label

    -- Size the hitbox to fit the box + label
    local labelWidth = label:GetStringWidth() or 0
    if labelWidth < 10 then labelWidth = #(text or "") * 7 end  -- fallback
    frame:SetSize(size + 6 + labelWidth + 4, size)

    function frame:SetChecked(val)
        self.checked = val
        if val then
            self.check:Show()
            self.box:SetBackdropBorderColor(unpack(UI.C.accent))
        else
            self.check:Hide()
            self.box:SetBackdropBorderColor(unpack(UI.C.border))
        end
    end

    function frame:GetChecked()
        return self.checked
    end

    frame:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        if self.onToggle then
            self:onToggle(self.checked)
        end
    end)

    frame:SetScript("OnEnter", function(self)
        self.box:SetBackdropBorderColor(unpack(UI.C.accent))
    end)

    frame:SetScript("OnLeave", function(self)
        if not self.checked then
            self.box:SetBackdropBorderColor(unpack(UI.C.border))
        end
    end)

    return frame
end

--- Horizontal separator line
function UI:CreateSeparator(parent, offsetY)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("LEFT", 0, 0)
    sep:SetPoint("RIGHT", 0, 0)
    if offsetY then
        sep:SetPoint("TOP", 0, offsetY)
    end
    sep:SetColorTexture(unpack(self.C.border))
    return sep
end

--- Section header text
function UI:CreateSectionHeader(parent, text)
    local header = parent:CreateFontString(nil, "OVERLAY")
    header:SetFont(self.FONT, 12, "")
    header:SetText(text)
    header:SetTextColor(unpack(self.C.accent))
    return header
end

-------------------------------------------------------------------------------
-- Static Popup Dialogs
-------------------------------------------------------------------------------
StaticPopupDialogs["MountSense_NEW_LIST"] = {
    text = "Enter a name for the new list:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self)
        local editBox = _G[self:GetName().."EditBox"] or self.editBox
        local text = editBox and editBox:GetText() or ""
        local name = strtrim(text)
        if name ~= "" then
            local id = addon.Data:CreateList(name)
            addon:Print("List \"" .. name .. "\" created!")
            if addon.Editor and addon.Editor.Refresh then
                addon.Editor:Refresh()
                addon.Editor:SelectList(id)
            end
        end
    end,
    OnShow = function(self)
        local editBox = _G[self:GetName().."EditBox"] or self.editBox
        if editBox then
            editBox:SetText("")
            editBox:SetFocus()
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local text = self:GetText() or ""
        local name = strtrim(text)
        if name ~= "" then
            local id = addon.Data:CreateList(name)
            addon:Print("List \"" .. name .. "\" created!")
            if addon.Editor and addon.Editor.Refresh then
                addon.Editor:Refresh()
                addon.Editor:SelectList(id)
            end
        end
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["MountSense_DELETE_LIST"] = {
    text = "Delete list \"%s\"?\nThis cannot be undone.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, listID)
        addon.Data:DeleteList(listID)
        addon:Print("List deleted.")
        if addon.Editor then
            addon.Editor.selectedListID = nil
            addon.Editor:Refresh()
        end
        if addon.Summon then
            addon.Summon:UpdateMount()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

StaticPopupDialogs["MountSense_RENAME_LIST"] = {
    text = "Rename list:",
    button1 = "Rename",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self, listID)
        local editBox = _G[self:GetName().."EditBox"] or self.editBox
        local text = editBox and editBox:GetText() or ""
        local name = strtrim(text)
        if name ~= "" then
            addon.Data:RenameList(listID, name)
            if addon.Editor and addon.Editor.Refresh then
                addon.Editor:Refresh()
            end
        end
    end,
    OnShow = function(self, listID)
        local editBox = _G[self:GetName().."EditBox"] or self.editBox
        local list = addon.Data:GetList(listID)
        if editBox and list then
            editBox:SetText(list.name)
            editBox:HighlightText()
            editBox:SetFocus()
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local text = self:GetText() or ""
        local name = strtrim(text)
        if name ~= "" then
            local dialog = self:GetParent()
            addon.Data:RenameList(dialog.data, name)
            if addon.Editor and addon.Editor.Refresh then
                addon.Editor:Refresh()
            end
        end
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-------------------------------------------------------------------------------
-- Main Frame Creation
-------------------------------------------------------------------------------
function UI:Create()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "MountSenseMainFrame", UIParent, "BackdropTemplate")
    local screenW = UIParent:GetWidth() or 1920
    local screenH = UIParent:GetHeight() or 1080

    -- Narrowest width the busiest tab (Browse — search box, 5 type filter
    -- buttons, family/source dropdowns and checkboxes all sharing one toolbar
    -- row, some left-anchored and some right-anchored) can render at without
    -- those controls overlapping each other. Clamped to the screen so it
    -- never exceeds what SetResizeBounds' max is allowed to be.
    local MIN_WIDTH = math.min(1300, screenW)

    local defW = math.floor(math.max(MIN_WIDTH, screenW * 0.6))
    local defH = math.floor(math.max(560, screenH * 0.7))
    f:SetSize(defW, defH)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (screenW - defW) / 2, -(screenH - defH) / 2)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(unpack(self.C.bg))
    f:SetBackdropBorderColor(unpack(self.C.borderAccent))
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetResizeBounds(MIN_WIDTH, 400, screenW, screenH)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(10)

    -- Helper: force anchor to TOPLEFT so resize from BOTTOMRIGHT is stable
    local function ReanchorToTopLeft()
        -- GetRect() returns pixel coords in the native UI coordinate system
        local left  = f:GetLeft()
        local top   = f:GetTop()
        if not left or not top then return end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end

    -- Ensure frame starts life with a TOPLEFT anchor (avoids jump on first resize)
    C_Timer.After(0, function() ReanchorToTopLeft() end)

    -- Drag to move (title bar area)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ReanchorToTopLeft()
    end)

    -- Resize handle (bottom-right corner)
    local resizeBtn = CreateFrame("Button", nil, f)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function(self)
        ReanchorToTopLeft()   -- stabilise anchor first, THEN start sizing
        f:StartSizing("BOTTOMRIGHT")
    end)
    resizeBtn:SetScript("OnMouseUp", function(self)
        f:StopMovingOrSizing()
        ReanchorToTopLeft()
    end)

    -- Close on Escape
    table.insert(UISpecialFrames, "MountSenseMainFrame")

    ---------------------------------------------------------------------------
    -- Title bar
    ---------------------------------------------------------------------------
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(36)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)

    -- Accent line under title
    local titleLine = titleBar:CreateTexture(nil, "ARTWORK")
    titleLine:SetHeight(1)
    titleLine:SetPoint("BOTTOMLEFT")
    titleLine:SetPoint("BOTTOMRIGHT")
    titleLine:SetColorTexture(self.C.accent[1], self.C.accent[2], self.C.accent[3], 0.3)

    -- Title text
    local title = titleBar:CreateFontString(nil, "OVERLAY")
    title:SetFont(self.FONT, 14, "")
    title:SetPoint("LEFT", 16, 0)
    title:SetText("|cffFFB800Mount|r|cffffffffSense|r")

    -- Version
    local version = titleBar:CreateFontString(nil, "OVERLAY")
    version:SetFont(self.FONT, 9, "")
    version:SetPoint("LEFT", title, "RIGHT", 8, -1)
    version:SetText("v" .. addon.version)
    version:SetTextColor(unpack(self.C.textDim))

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("RIGHT", -6, 0)

    local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
    closeText:SetFont(self.FONT, 16, "")
    closeText:SetPoint("CENTER", 0, 1)
    closeText:SetText("×")
    closeText:SetTextColor(unpack(self.C.textDim))
    closeBtn.text = closeText

    closeBtn:SetScript("OnEnter", function(self)
        self.text:SetTextColor(unpack(UI.C.danger))
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self.text:SetTextColor(unpack(UI.C.textDim))
    end)
    closeBtn:SetScript("OnClick", function()
        UI:Hide()
    end)

    ---------------------------------------------------------------------------
    -- Tab sidebar
    ---------------------------------------------------------------------------
    local sidebar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sidebar:SetWidth(140)
    sidebar:SetPoint("TOPLEFT", 0, -36)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    sidebar:SetBackdropColor(0.04, 0.04, 0.07, 1)
    f.sidebar = sidebar

    -- Sidebar / content separator
    local sidebarLine = sidebar:CreateTexture(nil, "OVERLAY")
    sidebarLine:SetWidth(1)
    sidebarLine:SetPoint("TOPRIGHT", 0, 0)
    sidebarLine:SetPoint("BOTTOMRIGHT", 0, 0)
    sidebarLine:SetColorTexture(self.C.border[1], self.C.border[2], self.C.border[3], 0.5)

    -- Tab definitions
    local tabDefs = {
        { key = "lists",    label = "My Lists",  icon = "Interface\\Icons\\INV_Misc_Bag_10_Blue" },
        { key = "browser",  label = "Browse",     icon = "Interface\\Icons\\Tracking_WildPet" },
        { key = "settings", label = "Settings",   icon = "Interface\\Icons\\inv_misc_wrench_01" },
    }

    f.tabs = {}
    f.tabButtons = {}
    local tabY = -12

    for i, def in ipairs(tabDefs) do
        local tab = CreateFrame("Button", nil, sidebar)
        tab:SetSize(138, 36)
        tab:SetPoint("TOPLEFT", 1, tabY)

        local tabBg = tab:CreateTexture(nil, "BACKGROUND")
        tabBg:SetAllPoints()
        tabBg:SetColorTexture(0, 0, 0, 0)
        tab.bg = tabBg

        local tabIcon = tab:CreateTexture(nil, "ARTWORK")
        tabIcon:SetSize(18, 18)
        tabIcon:SetPoint("LEFT", 12, 0)
        tabIcon:SetTexture(def.icon)
        tabIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tab.icon = tabIcon

        local tabLabel = tab:CreateFontString(nil, "OVERLAY")
        tabLabel:SetFont(self.FONT, 11, "")
        tabLabel:SetPoint("LEFT", tabIcon, "RIGHT", 8, 0)
        tabLabel:SetText(def.label)
        tabLabel:SetTextColor(unpack(self.C.textDim))
        tab.label = tabLabel

        -- Active indicator bar
        local indicator = tab:CreateTexture(nil, "OVERLAY")
        indicator:SetWidth(3)
        indicator:SetPoint("TOPLEFT", 0, -4)
        indicator:SetPoint("BOTTOMLEFT", 0, 4)
        indicator:SetColorTexture(unpack(self.C.accent))
        indicator:Hide()
        tab.indicator = indicator

        tab.key = def.key

        tab:SetScript("OnEnter", function(self)
            if UI.currentTab ~= self.key then
                self.bg:SetColorTexture(unpack(UI.C.tabHover))
            end
        end)
        tab:SetScript("OnLeave", function(self)
            if UI.currentTab ~= self.key then
                self.bg:SetColorTexture(0, 0, 0, 0)
            end
        end)
        tab:SetScript("OnClick", function(self)
            UI:SwitchTab(self.key)
        end)

        f.tabButtons[def.key] = tab
        tabY = tabY - 38
    end

    ---------------------------------------------------------------------------
    -- Content area
    ---------------------------------------------------------------------------
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", 0, 0)
    f.content = content

    -- Tab content containers
    f.tabFrames = {}

    -- Lists tab
    local listsFrame = CreateFrame("Frame", nil, content)
    listsFrame:SetAllPoints()
    listsFrame:Hide()
    f.tabFrames["lists"] = listsFrame

    -- Browser tab
    local browserFrame = CreateFrame("Frame", nil, content)
    browserFrame:SetAllPoints()
    browserFrame:Hide()
    f.tabFrames["browser"] = browserFrame

    -- Settings tab
    local settingsFrame = CreateFrame("Frame", nil, content)
    settingsFrame:SetAllPoints()
    settingsFrame:Hide()
    f.tabFrames["settings"] = settingsFrame

    self.frame = f
    f:Hide()

    -- Build tab content
    C_Timer.After(0, function()
        if addon.Editor   then addon.Editor:Create(listsFrame)       end
        if addon.Browser  then addon.Browser:Create(browserFrame)    end
        if addon.Settings then addon.Settings:Create(settingsFrame)  end
        -- Default tab
        self:SwitchTab("lists")
    end)

    return f
end

-------------------------------------------------------------------------------
-- Shared "click outside to close" handling for the dropdowns below.
-- Only one custom dropdown list may be open at a time; clicking anywhere
-- else on screen closes it.
-------------------------------------------------------------------------------
function UI:CloseOpenDropdown()
    if self.openDropdown then
        self.openDropdown:Hide()
        self.openDropdown = nil
    end
    if self.dropdownOverlay then
        self.dropdownOverlay:Hide()
    end
end

function UI:OpenDropdown(listFrame)
    self:CloseOpenDropdown()
    if not self.dropdownOverlay then
        local overlay = CreateFrame("Button", nil, UIParent)
        overlay:SetAllPoints(UIParent)
        overlay:SetFrameStrata("FULLSCREEN")
        overlay:Hide()
        overlay:SetScript("OnClick", function() UI:CloseOpenDropdown() end)
        self.dropdownOverlay = overlay
    end
    listFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.dropdownOverlay:Show()
    listFrame:Show()
    self.openDropdown = listFrame
end

--- Create a custom dropdown menu
function UI:CreateDropdown(parent, width, items, defaultVal, onSelect)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 120, 26)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(unpack(self.C.bgInput))
    btn:SetBackdropBorderColor(unpack(self.C.border))

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont(self.FONT, 10, "")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(unpack(self.C.text))
    btn.text = text

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")

    local function GetLabel(val)
        for _, item in ipairs(items) do
            if item.value == val then return item.text end
        end
        return tostring(val)
    end

    btn.value = defaultVal
    text:SetText(GetLabel(defaultVal))

    local listFrame = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    listFrame:SetWidth(width or 120)
    listFrame:SetHeight(#items * 20 + 8)
    listFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    listFrame:SetBackdropColor(unpack(self.C.bgPanel))
    listFrame:SetBackdropBorderColor(unpack(self.C.border))
    listFrame:SetFrameLevel(100)
    listFrame:Hide()
    btn.listFrame = listFrame

    function btn:SetValue(val, silent)
        btn.value = val
        text:SetText(GetLabel(val))
        if not silent and onSelect then onSelect(val) end
    end

    function btn:SetItems(newItems)
        items = newItems
        local children = { listFrame:GetChildren() }
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end

        local yOff = -4
        for _, item in ipairs(items) do
            local itemBtn = CreateFrame("Button", nil, listFrame)
            itemBtn:SetSize((width or 120) - 8, 20)
            itemBtn:SetPoint("TOP", 0, yOff)
            
            local highlight = itemBtn:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(1, 1, 1, 0.1)

            local itemText = itemBtn:CreateFontString(nil, "OVERLAY")
            itemText:SetFont(UI.FONT, 10, "")
            itemText:SetPoint("LEFT", 8, 0)
            itemText:SetText(item.text)
            itemText:SetTextColor(unpack(UI.C.textDim))

            itemBtn:SetScript("OnClick", function()
                btn:SetValue(item.value, false)
                UI:CloseOpenDropdown()
            end)

            itemBtn:SetScript("OnEnter", function() itemText:SetTextColor(unpack(UI.C.text)) end)
            itemBtn:SetScript("OnLeave", function() itemText:SetTextColor(unpack(UI.C.textDim)) end)

            yOff = yOff - 20
        end
        listFrame:SetHeight(math.max(8, #items * 20 + 8))
        text:SetText(GetLabel(btn.value))
    end

    btn:SetItems(items)

    btn:SetScript("OnClick", function()
        if listFrame:IsShown() then
            UI:CloseOpenDropdown()
        else
            UI:OpenDropdown(listFrame)
        end
    end)
    btn:SetScript("OnHide", function()
        if UI.openDropdown == listFrame then UI:CloseOpenDropdown() else listFrame:Hide() end
    end)

    return btn
end

--- Create a custom multiselect dropdown menu
function UI:CreateMultiDropdown(parent, width, items, defaultVals, onSelect)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 120, 26)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(unpack(self.C.bgInput))
    btn:SetBackdropBorderColor(unpack(self.C.border))

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont(self.FONT, 10, "")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(unpack(self.C.text))
    btn.text = text

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")

    local function GetLabel(vals)
        local count = 0
        local firstLabel = ""
        if vals["ALL"] then return "All Families" end
        for _, item in ipairs(items) do
            if vals[item.value] then
                count = count + 1
                if count == 1 then firstLabel = item.text end
            end
        end
        if count == 0 then return "None" end
        if count == 1 then return firstLabel end
        return count .. " selected"
    end

    btn.values = defaultVals or { ALL = true }
    text:SetText(GetLabel(btn.values))

    local listFrame = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    listFrame:SetWidth(width or 120)
    listFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    listFrame:SetBackdropColor(unpack(self.C.bgPanel))
    listFrame:SetBackdropBorderColor(unpack(self.C.border))
    listFrame:SetFrameLevel(100)
    listFrame:Hide()
    btn.listFrame = listFrame

    function btn:SetValues(vals, silent)
        btn.values = vals
        text:SetText(GetLabel(vals))
        -- Update checks
        local children = { listFrame:GetChildren() }
        for _, child in ipairs(children) do
            if child.check and child.value then
                child.check:SetShown(btn.values[child.value] == true)
            end
        end
        if not silent and onSelect then onSelect(vals) end
    end

    function btn:SetItems(newItems)
        items = newItems
        local children = { listFrame:GetChildren() }
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end

        local yOff = -4
        for _, item in ipairs(items) do
            local itemBtn = CreateFrame("Button", nil, listFrame)
            itemBtn:SetSize((width or 120) - 8, 20)
            itemBtn:SetPoint("TOP", 0, yOff)
            itemBtn.value = item.value
            
            local highlight = itemBtn:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(1, 1, 1, 0.1)

            local check = itemBtn:CreateTexture(nil, "OVERLAY")
            check:SetSize(14, 14)
            check:SetPoint("LEFT", 4, 0)
            check:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
            check:SetShown(btn.values[item.value] == true)
            itemBtn.check = check

            local itemText = itemBtn:CreateFontString(nil, "OVERLAY")
            itemText:SetFont(UI.FONT, 10, "")
            itemText:SetPoint("LEFT", 20, 0)
            itemText:SetText(item.text)
            itemText:SetTextColor(unpack(UI.C.textDim))

            itemBtn:SetScript("OnClick", function()
                if item.value == "ALL" then
                    btn.values = { ALL = true }
                else
                    btn.values["ALL"] = nil
                    if btn.values[item.value] then
                        btn.values[item.value] = nil
                        if next(btn.values) == nil then
                            btn.values["ALL"] = true
                        end
                    else
                        btn.values[item.value] = true
                    end
                end
                btn:SetValues(btn.values, false)
            end)
            
            itemBtn:SetScript("OnEnter", function() itemText:SetTextColor(unpack(UI.C.text)) end)
            itemBtn:SetScript("OnLeave", function() itemText:SetTextColor(unpack(UI.C.textDim)) end)
            
            yOff = yOff - 20
        end
        listFrame:SetHeight(math.max(8, #items * 20 + 8))
        text:SetText(GetLabel(btn.values))
    end

    btn:SetItems(items)

    btn:SetScript("OnClick", function()
        if listFrame:IsShown() then
            UI:CloseOpenDropdown()
        else
            UI:OpenDropdown(listFrame)
        end
    end)
    btn:SetScript("OnHide", function()
        if UI.openDropdown == listFrame then UI:CloseOpenDropdown() else listFrame:Hide() end
    end)

    return btn
end

-------------------------------------------------------------------------------
-- Tab switching
-------------------------------------------------------------------------------
function UI:SwitchTab(key)
    self.currentTab = key

    for tabKey, frame in pairs(self.frame.tabFrames) do
        frame:Hide()
    end

    for tabKey, btn in pairs(self.frame.tabButtons) do
        if tabKey == key then
            btn.bg:SetColorTexture(self.C.tabActive[1], self.C.tabActive[2],
                                    self.C.tabActive[3], self.C.tabActive[4])
            btn.label:SetTextColor(unpack(self.C.accent))
            btn.indicator:Show()
        else
            btn.bg:SetColorTexture(0, 0, 0, 0)
            btn.label:SetTextColor(unpack(self.C.textDim))
            btn.indicator:Hide()
        end
    end

    if self.frame.tabFrames[key] then
        self.frame.tabFrames[key]:Show()
    end

    -- Refresh content
    if key == "lists" and addon.Editor then
        addon.Editor:Refresh()
    elseif key == "browser" and addon.Browser then
        addon.Browser:Refresh()
    elseif key == "settings" and addon.Settings then
        addon.Settings:Refresh()
    end
end

-------------------------------------------------------------------------------
-- Show / Hide / Toggle
-------------------------------------------------------------------------------
function UI:Show()
    if not self.frame then self:Create() end
    -- Invalidate any pending fade-out hide from a previous Hide() call
    self.hideGen = (self.hideGen or 0) + 1
    self.frame:Show()
    -- Fade in
    self.frame:SetAlpha(0)
    UIFrameFadeIn(self.frame, 0.15, 0, 1)
end

function UI:Hide()
    if self.frame then
        self.hideGen = (self.hideGen or 0) + 1
        local gen = self.hideGen
        UIFrameFadeOut(self.frame, 0.1, self.frame:GetAlpha(), 0)
        C_Timer.After(0.1, function()
            if self.frame and self.hideGen == gen then
                self.frame:Hide()
            end
        end)
    end
end

function UI:Toggle()
    if not self.frame then
        self:Show()
    elseif self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function UI:IsShown()
    return self.frame and self.frame:IsShown()
end
