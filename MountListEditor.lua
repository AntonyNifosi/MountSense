-------------------------------------------------------------------------------
-- MountList — List Editor
-- Left panel: list overview cards  |  Right panel: details, conditions, mounts
-------------------------------------------------------------------------------
local addonName, addon = ...
local Editor = {}
addon.Editor = Editor

Editor.frame = nil
Editor.selectedListID = nil
Editor.listButtons = {}
Editor.mountIcons = {}

-------------------------------------------------------------------------------
-- Create the editor UI inside the given parent
-------------------------------------------------------------------------------
function Editor:Create(parent)
    if self.frame then return end

    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f

    ---------------------------------------------------------------------------
    -- LEFT PANEL — List of lists
    ---------------------------------------------------------------------------
    local leftPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    leftPanel:SetWidth(360)
    leftPanel:SetPoint("TOPLEFT", 8, -8)
    leftPanel:SetPoint("BOTTOMLEFT", 8, 8)
    leftPanel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    leftPanel:SetBackdropColor(unpack(addon.UI.C.bgPanel))
    leftPanel:SetBackdropBorderColor(unpack(addon.UI.C.border))
    self.leftPanel = leftPanel

    -- Header
    local leftHeader = leftPanel:CreateFontString(nil, "OVERLAY")
    leftHeader:SetFont(addon.UI.FONT, 12, "")
    leftHeader:SetPoint("TOPLEFT", 12, -10)
    leftHeader:SetText("My Lists")
    leftHeader:SetTextColor(unpack(addon.UI.C.accent))

    -- Count
    local listCountText = leftPanel:CreateFontString(nil, "OVERLAY")
    listCountText:SetFont(addon.UI.FONT, 10, "")
    listCountText:SetPoint("LEFT", leftHeader, "RIGHT", 6, 0)
    listCountText:SetTextColor(unpack(addon.UI.C.textDim))
    self.listCountText = listCountText

    -- New List button
    local newBtn = addon.UI:CreateAccentButton(leftPanel, "+ New List", 100, 26)
    newBtn:SetPoint("TOPRIGHT", -8, -6)
    newBtn:SetScript("OnClick", function()
        StaticPopup_Show("MOUNTLIST_NEW_LIST")
    end)

    -- Separator
    local sep = leftPanel:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 8, -34)
    sep:SetPoint("TOPRIGHT", -8, -34)
    sep:SetColorTexture(addon.UI.C.border[1], addon.UI.C.border[2],
                        addon.UI.C.border[3], 0.5)

    -- Scroll area for lists
    local listScroll = CreateFrame("ScrollFrame", "MountListEditorListScroll",
                                    leftPanel, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 4, -38)
    listScroll:SetPoint("BOTTOMRIGHT", -24, 4)

    local scrollBar = listScroll.ScrollBar or _G["MountListEditorListScrollScrollBar"]
    if scrollBar then scrollBar:SetWidth(10) end

    local listScrollChild = CreateFrame("Frame", nil, listScroll)
    listScrollChild:SetWidth(listScroll:GetWidth())
    listScrollChild:SetHeight(1)
    listScroll:SetScrollChild(listScrollChild)
    self.listScrollChild = listScrollChild
    self.listScroll = listScroll

    listScroll:SetScript("OnSizeChanged", function(self, w)
        listScrollChild:SetWidth(w - 14)
    end)

    ---------------------------------------------------------------------------
    -- RIGHT PANEL — Details / Conditions / Mounts
    ---------------------------------------------------------------------------
    local rightPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 6, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", -8, 8)
    rightPanel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    rightPanel:SetBackdropColor(unpack(addon.UI.C.bgPanel))
    rightPanel:SetBackdropBorderColor(unpack(addon.UI.C.border))
    self.rightPanel = rightPanel

    -- Placeholder when no list selected
    local placeholder = rightPanel:CreateFontString(nil, "OVERLAY")
    placeholder:SetFont(addon.UI.FONT, 12, "")
    placeholder:SetPoint("CENTER")
    placeholder:SetText("Select a list to edit\nor create a new one")
    placeholder:SetTextColor(unpack(addon.UI.C.textDim))
    placeholder:SetJustifyH("CENTER")
    self.placeholder = placeholder

    ---------------------------------------------------------------------------
    -- Detail content (hidden until a list is selected)
    ---------------------------------------------------------------------------
    local detail = CreateFrame("Frame", nil, rightPanel)
    detail:SetAllPoints()
    detail:Hide()
    self.detail = detail

    -- List name header
    local nameHeader = CreateFrame("Button", nil, detail)
    nameHeader:SetHeight(30)
    nameHeader:SetPoint("TOPLEFT", 12, -8)
    nameHeader:SetPoint("TOPRIGHT", -100, -8)

    local nameText = nameHeader:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(addon.UI.FONT, 15, "")
    nameText:SetPoint("LEFT")
    nameText:SetTextColor(unpack(addon.UI.C.textBright))
    self.nameText = nameText

    -- Edit name icon
    local editIcon = nameHeader:CreateFontString(nil, "OVERLAY")
    editIcon:SetFont(addon.UI.FONT, 11, "")
    editIcon:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
    editIcon:SetText("[Edit]")
    editIcon:SetTextColor(unpack(addon.UI.C.textDim))

    nameHeader:SetScript("OnClick", function()
        if Editor.selectedListID then
            local dialog = StaticPopup_Show("MOUNTLIST_RENAME_LIST")
            if dialog then
                dialog.data = Editor.selectedListID
            end
        end
    end)
    nameHeader:SetScript("OnEnter", function()
        editIcon:SetTextColor(unpack(addon.UI.C.accent))
    end)
    nameHeader:SetScript("OnLeave", function()
        editIcon:SetTextColor(unpack(addon.UI.C.textDim))
    end)

    -- Delete button
    local deleteBtn = addon.UI:CreateDangerButton(detail, "Delete", 70, 24)
    deleteBtn:SetPoint("TOPRIGHT", -10, -10)
    deleteBtn:SetScript("OnClick", function()
        if Editor.selectedListID then
            local list = addon.Data:GetList(Editor.selectedListID)
            if list then
                local dialog = StaticPopup_Show("MOUNTLIST_DELETE_LIST",
                                                 list.name)
                if dialog then
                    dialog.data = Editor.selectedListID
                end
            end
        end
    end)

    -- Separator
    local detailSep1 = detail:CreateTexture(nil, "ARTWORK")
    detailSep1:SetHeight(1)
    detailSep1:SetPoint("TOPLEFT", 8, -42)
    detailSep1:SetPoint("TOPRIGHT", -8, -42)
    detailSep1:SetColorTexture(addon.UI.C.border[1], addon.UI.C.border[2],
                                addon.UI.C.border[3], 0.5)

    ---------------------------------------------------------------------------
    -- CONDITIONS SECTION
    ---------------------------------------------------------------------------
    local condHeader = addon.UI:CreateSectionHeader(detail, "Conditions")
    condHeader:SetPoint("TOPLEFT", 12, -52)

    local condHint = detail:CreateFontString(nil, "OVERLAY")
    condHint:SetFont(addon.UI.FONT, 9, "")
    condHint:SetPoint("LEFT", condHeader, "RIGHT", 8, 0)
    condHint:SetText("(none = always active)")
    condHint:SetTextColor(unpack(addon.UI.C.textDim))

    -- Context checkboxes
    local contextLabel = detail:CreateFontString(nil, "OVERLAY")
    contextLabel:SetFont(addon.UI.FONT, 10, "")
    contextLabel:SetPoint("TOPLEFT", condHeader, "BOTTOMLEFT", 0, -8)
    contextLabel:SetText("Context:")
    contextLabel:SetTextColor(unpack(addon.UI.C.textDim))

    self.contextLabel = contextLabel
    self.contextCheckboxes = {}

    for i, info in ipairs(addon.Data.CONTEXT_INFO) do
        local cb = addon.UI:CreateCheckbox(detail, info.label, 16)
        cb.contextKey = info.key
        cb.onToggle = function(self, checked)
            Editor:SaveConditions()
        end
        self.contextCheckboxes[i] = cb
    end

    -- Spec section
    local specLabel = detail:CreateFontString(nil, "OVERLAY")
    specLabel:SetFont(addon.UI.FONT, 10, "")
    specLabel:SetText("Specialization:")
    specLabel:SetTextColor(unpack(addon.UI.C.textDim))
    self.specLabel = specLabel

    self.specCheckboxes = {}
    -- Spec checkboxes will be created dynamically in Refresh
    
    detail:SetScript("OnSizeChanged", function()
        Editor:UpdateLayout()
    end)

    ---------------------------------------------------------------------------
    -- MOUNTS SECTION
    ---------------------------------------------------------------------------
    local mountSep = detail:CreateTexture(nil, "ARTWORK")
    mountSep:SetHeight(1)
    mountSep:SetPoint("LEFT", 8, 0)
    mountSep:SetPoint("RIGHT", -8, 0)
    self.mountSep = mountSep

    local mountHeader = addon.UI:CreateSectionHeader(detail, "Mounts")
    self.mountHeader = mountHeader

    local mountCountText = detail:CreateFontString(nil, "OVERLAY")
    mountCountText:SetFont(addon.UI.FONT, 10, "")
    mountCountText:SetTextColor(unpack(addon.UI.C.textDim))
    self.mountCountText = mountCountText

    local browseBtn = addon.UI:CreateAccentButton(detail, "Add Mounts", 100, 24)
    browseBtn:SetScript("OnClick", function()
        addon.UI:SwitchTab("browser")
        if addon.Browser and addon.Browser.listDD then
            addon.Browser.targetListID = Editor.selectedListID
            addon.Browser.listDD:SetValue(Editor.selectedListID, true)
            addon.Browser:UpdateCards()
        end
    end)
    self.browseBtn = browseBtn

    -- Mount icons scroll area
    local mountScroll = CreateFrame("ScrollFrame", "MountListEditorMountScroll",
                                     detail, "UIPanelScrollFrameTemplate")
    self.mountScroll = mountScroll

    local mountScrollBar = mountScroll.ScrollBar or
                           _G["MountListEditorMountScrollScrollBar"]
    if mountScrollBar then mountScrollBar:SetWidth(10) end

    local mountScrollChild = CreateFrame("Frame", nil, mountScroll)
    mountScrollChild:SetHeight(1)
    mountScroll:SetScrollChild(mountScrollChild)
    self.mountScrollChild = mountScrollChild
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------
function Editor:Refresh()
    if not self.frame then return end

    self:RefreshListPanel()
    self:RefreshDetailPanel()
end

-------------------------------------------------------------------------------
-- Left panel: list of lists
-------------------------------------------------------------------------------
function Editor:RefreshListPanel()
    -- Hide old buttons
    for _, btn in ipairs(self.listButtons) do
        btn:Hide()
    end

    local sorted = addon.Data:GetSortedLists()
    self.listCountText:SetText("(" .. #sorted .. ")")

    local parent = self.listScrollChild
    local yOffset = -4

    for i, entry in ipairs(sorted) do
        local btn = self.listButtons[i]
        if not btn then
            btn = self:CreateListButton(parent, i)
            self.listButtons[i] = btn
        end

        self:SetupListButton(btn, entry.id, entry.list)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 2, yOffset)
        btn:SetPoint("TOPRIGHT", -2, yOffset)
        btn:Show()

        yOffset = yOffset - 56
    end

    parent:SetHeight(math.max(1, math.abs(yOffset) + 4))
end

function Editor:CreateListButton(parent, index)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(52)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(unpack(addon.UI.C.bgCard))
    btn:SetBackdropBorderColor(unpack(addon.UI.C.border))

    -- List name
    local name = btn:CreateFontString(nil, "OVERLAY")
    name:SetFont(addon.UI.FONT, 12, "")
    name:SetPoint("TOPLEFT", 26, -8)
    name:SetPoint("TOPRIGHT", -40, -8)
    name:SetJustifyH("LEFT")
    name:SetTextColor(unpack(addon.UI.C.text))
    btn.nameText = name

    -- Drag handle (3 horizontal texture lines — font-safe alternative to ≡)
    local gripContainer = CreateFrame("Frame", nil, btn)
    gripContainer:SetSize(12, 14)
    gripContainer:SetPoint("LEFT", 6, 0)
    btn.grip = gripContainer

    local lineColor = { unpack(addon.UI.C.textDim) }
    for i = 0, 2 do
        local line = gripContainer:CreateTexture(nil, "OVERLAY")
        line:SetHeight(2)
        line:SetPoint("TOPLEFT", 0, -(i * 5))
        line:SetPoint("TOPRIGHT", 0, -(i * 5))
        line:SetColorTexture(lineColor[1], lineColor[2], lineColor[3], 0.7)
        gripContainer["line" .. i] = line
    end

    function gripContainer:SetLineColor(r, g, b, a)
        for i = 0, 2 do
            self["line" .. i]:SetColorTexture(r, g, b, a or 0.9)
        end
    end

    -- Mount count
    local count = btn:CreateFontString(nil, "OVERLAY")
    count:SetFont(addon.UI.FONT, 9, "")
    count:SetPoint("TOPRIGHT", -10, -9)
    count:SetTextColor(unpack(addon.UI.C.textDim))
    btn.countText = count

    -- Condition badges area
    local badges = btn:CreateFontString(nil, "OVERLAY")
    badges:SetFont(addon.UI.FONT, 8, "")
    badges:SetPoint("BOTTOMLEFT", 10, 7)
    badges:SetPoint("BOTTOMRIGHT", -10, 7)
    badges:SetJustifyH("LEFT")
    badges:SetTextColor(unpack(addon.UI.C.textDim))
    btn.badgesText = badges

    -- Active indicator
    local indicator = btn:CreateTexture(nil, "OVERLAY")
    indicator:SetWidth(3)
    indicator:SetPoint("TOPLEFT", 0, -2)
    indicator:SetPoint("BOTTOMLEFT", 0, 2)
    indicator:SetColorTexture(unpack(addon.UI.C.accent))
    indicator:Hide()
    btn.indicator = indicator

    -- Drop indicator line (shown between items during drag)
    local dropLine = btn:CreateTexture(nil, "OVERLAY")
    dropLine:SetHeight(2)
    dropLine:SetPoint("TOPLEFT", 4, 1)
    dropLine:SetPoint("TOPRIGHT", -4, 1)
    dropLine:SetColorTexture(unpack(addon.UI.C.accent))
    dropLine:Hide()
    btn.dropLine = dropLine

    ---------------------------------------------------------------------------
    -- Drag & Drop logic
    ---------------------------------------------------------------------------
    btn:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.mouseDownX, self.mouseDownY = GetCursorPosition()
        self.dragging = false
    end)

    btn:SetScript("OnUpdate", function(self)
        if not self.mouseDownX then return end
        if self.dragging then return end
        -- Detect drag threshold (10px movement)
        local x, y = GetCursorPosition()
        local dx = math.abs(x - self.mouseDownX)
        local dy = math.abs(y - self.mouseDownY)
        if dx > 10 or dy > 10 then
            self.dragging = true
            Editor:StartDrag(self)
        end
    end)

    btn:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        if not self.dragging then
            -- It was a click, not a drag
            Editor:SelectList(self.listID)
        end
        self.mouseDownX = nil
        self.mouseDownY = nil
        self.dragging = false
    end)

    btn:SetScript("OnEnter", function(self)
        self.grip:SetLineColor(addon.UI.C.accent[1], addon.UI.C.accent[2], addon.UI.C.accent[3], 1)
        if Editor.selectedListID ~= self.listID then
            self:SetBackdropColor(unpack(addon.UI.C.bgCardHover))
        end
        -- Show drop line if we're dragging something else
        if Editor.draggingBtn and Editor.draggingBtn ~= self then
            self.dropLine:Show()
            Editor.dropTarget = self
        end
    end)

    btn:SetScript("OnLeave", function(self)
        local c = addon.UI.C.textDim
        self.grip:SetLineColor(c[1], c[2], c[3], 0.7)
        if Editor.selectedListID ~= self.listID then
            self:SetBackdropColor(unpack(addon.UI.C.bgCard))
        end
        self.dropLine:Hide()
    end)

    return btn
end

-------------------------------------------------------------------------------
-- Drag helpers
-------------------------------------------------------------------------------
function Editor:StartDrag(sourceBtn)
    self.draggingBtn = sourceBtn
    self.dropTarget  = nil

    -- Ghost frame that follows the cursor
    if not self.dragGhost then
        local ghost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        ghost:SetHeight(52)
        ghost:SetWidth(320)
        ghost:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        ghost:SetBackdropColor(0.15, 0.15, 0.22, 0.85)
        ghost:SetBackdropBorderColor(unpack(addon.UI.C.accent))
        ghost:SetFrameStrata("TOOLTIP")
        ghost:SetFrameLevel(200)

        local ghostText = ghost:CreateFontString(nil, "OVERLAY")
        ghostText:SetFont(addon.UI.FONT, 12, "")
        ghostText:SetPoint("LEFT", 12, 0)
        ghostText:SetTextColor(unpack(addon.UI.C.accent))
        ghost.text = ghostText
        self.dragGhost = ghost
    end

    self.dragGhost.text:SetText(sourceBtn.nameText:GetText())
    self.dragGhost:Show()

    -- Highlight source as being dragged
    sourceBtn:SetBackdropBorderColor(unpack(addon.UI.C.accent))
    sourceBtn:SetAlpha(0.5)

    -- Track cursor + drop in OnUpdate
    self.dragGhost:SetScript("OnUpdate", function(ghost)
        local x, y = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        ghost:ClearAllPoints()
        ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s + 30)

        if not IsMouseButtonDown("LeftButton") then
            Editor:StopDrag()
        end
    end)
end

function Editor:StopDrag()
    local sourceBtn = self.draggingBtn
    local targetBtn = self.dropTarget

    -- Clean up ghost
    if self.dragGhost then
        self.dragGhost:Hide()
        self.dragGhost:SetScript("OnUpdate", nil)
    end

    -- Restore source appearance
    if sourceBtn then
        sourceBtn:SetAlpha(1.0)
        self:SetupListButton(sourceBtn, sourceBtn.listID,
                             addon.Data:GetList(sourceBtn.listID))
    end

    -- Hide all drop lines
    for _, btn in ipairs(self.listButtons) do
        if btn.dropLine then btn.dropLine:Hide() end
    end

    -- Apply reorder if we have a valid target
    if sourceBtn and targetBtn and sourceBtn.listID ~= targetBtn.listID then
        self:ApplyDragReorder(sourceBtn.listID, targetBtn.listID)
    end

    self.draggingBtn = nil
    self.dropTarget  = nil
end

function Editor:ApplyDragReorder(sourceID, targetID)
    -- Build current ordered list
    local sorted = addon.Data:GetSortedLists()
    local orderedIDs = {}
    for _, entry in ipairs(sorted) do
        orderedIDs[#orderedIDs + 1] = entry.id
    end

    -- Find positions
    local srcPos, tgtPos
    for i, id in ipairs(orderedIDs) do
        if id == sourceID then srcPos = i end
        if id == targetID then tgtPos = i end
    end

    if not srcPos or not tgtPos then return end

    -- Move source to target position
    table.remove(orderedIDs, srcPos)
    table.insert(orderedIDs, tgtPos, sourceID)

    addon.Data:ReorderLists(orderedIDs)
    self:Refresh()
    addon.Summon:UpdateMount()
end

function Editor:SetupListButton(btn, listID, list)
    btn.listID = listID
    btn.nameText:SetText(list.name)
    btn.countText:SetText(#list.mounts .. " mount" .. (#list.mounts ~= 1 and "s" or ""))

    -- Build condition badges text
    local badges = {}
    if list.conditions and list.conditions.contexts then
        for _, ctx in ipairs(list.conditions.contexts) do
            for _, info in ipairs(addon.Data.CONTEXT_INFO) do
                if info.key == ctx then
                    badges[#badges + 1] = info.label
                    break
                end
            end
        end
    end
    btn.badgesText:SetText(#badges > 0 and table.concat(badges, " · ") or "All contexts")

    -- Highlight if selected
    if self.selectedListID == listID then
        btn:SetBackdropColor(addon.UI.C.selected[1], addon.UI.C.selected[2],
                             addon.UI.C.selected[3], addon.UI.C.selected[4])
        btn:SetBackdropBorderColor(unpack(addon.UI.C.accent))
        btn.indicator:Show()
        btn.nameText:SetTextColor(unpack(addon.UI.C.accent))
    else
        btn:SetBackdropColor(unpack(addon.UI.C.bgCard))
        btn:SetBackdropBorderColor(unpack(addon.UI.C.border))
        btn.indicator:Hide()
        btn.nameText:SetTextColor(unpack(addon.UI.C.text))
    end
end

-------------------------------------------------------------------------------
-- Select a list
-------------------------------------------------------------------------------
function Editor:SelectList(listID)
    self.selectedListID = listID
    self:RefreshListPanel()
    self:RefreshDetailPanel()
end

-------------------------------------------------------------------------------
-- Right panel: detail view
-------------------------------------------------------------------------------
function Editor:RefreshDetailPanel()
    if not self.selectedListID then
        self.placeholder:Show()
        self.detail:Hide()
        return
    end

    local list = addon.Data:GetList(self.selectedListID)
    if not list then
        self.selectedListID = nil
        self.placeholder:Show()
        self.detail:Hide()
        return
    end

    self.placeholder:Hide()
    self.detail:Show()

    -- Name
    self.nameText:SetText(list.name)

    -- Context checkboxes
    local contexts = (list.conditions and list.conditions.contexts) or {}
    for _, cb in ipairs(self.contextCheckboxes) do
        local found = false
        for _, ctx in ipairs(contexts) do
            if ctx == cb.contextKey then found = true; break end
        end
        cb:SetChecked(found)
    end

    -- Spec checkboxes (dynamic)
    self:RefreshSpecCheckboxes(list)

    -- Position mount section below specs
    self:UpdateLayout()

    self.mountHeader:ClearAllPoints()
    self.mountHeader:SetPoint("TOPLEFT", self.mountSep, "BOTTOMLEFT", 4, -8)

    self.mountCountText:ClearAllPoints()
    self.mountCountText:SetPoint("LEFT", self.mountHeader, "RIGHT", 8, 0)
    self.mountCountText:SetText("(" .. #list.mounts .. ")")

    self.browseBtn:ClearAllPoints()
    self.browseBtn:SetPoint("LEFT", self.mountCountText, "RIGHT", 12, 0)

    -- Mount icon grid
    self.mountScroll:ClearAllPoints()
    self.mountScroll:SetPoint("TOPLEFT", self.mountHeader, "BOTTOMLEFT", -4, -8)
    self.mountScroll:SetPoint("BOTTOMRIGHT", self.detail, "BOTTOMRIGHT", -24, 8)
    self.mountScrollChild:SetWidth(self.mountScroll:GetWidth() - 14)

    self:RefreshMountIcons(list)
end

-------------------------------------------------------------------------------
-- Spec checkboxes (created once per class, refreshed per list)
-------------------------------------------------------------------------------
function Editor:RefreshSpecCheckboxes(list)
    -- Hide old
    for _, cb in ipairs(self.specCheckboxes) do
        cb:Hide()
    end

    local specs = addon.Conditions:GetPlayerSpecs()
    local listSpecs = (list.conditions and list.conditions.specs) or {}

    for i, spec in ipairs(specs) do
        local cb = self.specCheckboxes[i]
        if not cb then
            cb = addon.UI:CreateCheckbox(self.detail, spec.name, 16)
            self.specCheckboxes[i] = cb
        end

        cb.label:SetText(spec.name)
        cb.specID = spec.id
        cb.onToggle = function(self, checked)
            Editor:SaveConditions()
        end

        -- Position will be handled by UpdateLayout

        -- Checked state
        local found = false
        for _, specID in ipairs(listSpecs) do
            if specID == spec.id then found = true; break end
        end
        cb:SetChecked(found)
        cb:Show()
    end
end

-------------------------------------------------------------------------------
-- Save conditions from checkboxes
-------------------------------------------------------------------------------
function Editor:SaveConditions()
    if not self.selectedListID then return end

    -- Contexts
    local contexts = {}
    for _, cb in ipairs(self.contextCheckboxes) do
        if cb:GetChecked() then
            contexts[#contexts + 1] = cb.contextKey
        end
    end
    addon.Data:SetListContexts(self.selectedListID, contexts)

    -- Specs
    local specs = {}
    for _, cb in ipairs(self.specCheckboxes) do
        if cb:IsShown() and cb:GetChecked() then
            specs[#specs + 1] = cb.specID
        end
    end
    addon.Data:SetListSpecs(self.selectedListID, specs)

    -- Refresh list badges
    self:RefreshListPanel()

    -- Update summon
    addon.Summon:UpdateMount()
end

-------------------------------------------------------------------------------
-- Mount icons in detail panel
-------------------------------------------------------------------------------
function Editor:RefreshMountIcons(list)
    -- Hide old
    for _, icon in ipairs(self.mountIcons) do
        icon:Hide()
    end

    local mounts = list.mounts
    local parent = self.mountScrollChild
    local ICON_SIZE = 38
    local GAP = 4
    local parentWidth = parent:GetWidth()
    if parentWidth < 50 then parentWidth = 380 end
    local cols = math.max(1, math.floor((parentWidth + GAP) / (ICON_SIZE + GAP)))
    local row, col = 0, 0

    for i, mountID in ipairs(mounts) do
        local frame = self.mountIcons[i]
        if not frame then
            frame = self:CreateMountIcon(parent, i)
            self.mountIcons[i] = frame
        end

        local mountData = addon.Data:GetMountData(mountID)
        if mountData then
            frame.icon:SetTexture(mountData.icon)
            frame.mountID = mountID
            frame.mountData = mountData
        else
            frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            frame.mountID = mountID
            frame.mountData = nil
        end

        local x = col * (ICON_SIZE + GAP)
        local y = -(row * (ICON_SIZE + GAP))
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", x, y)
        frame:Show()

        col = col + 1
        if col >= cols then
            col = 0
            row = row + 1
        end
    end

    local totalRows = row + (col > 0 and 1 or 0)
    parent:SetHeight(math.max(1, totalRows * (ICON_SIZE + GAP)))
end

function Editor:CreateMountIcon(parent, index)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(38, 38)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(unpack(addon.UI.C.bgCard))
    btn:SetBackdropBorderColor(unpack(addon.UI.C.border))

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    -- Remove "x" overlay (shown on hover)
    local removeOverlay = btn:CreateTexture(nil, "OVERLAY")
    removeOverlay:SetAllPoints()
    removeOverlay:SetColorTexture(0.9, 0.1, 0.1, 0.25)
    removeOverlay:Hide()
    btn.removeOverlay = removeOverlay

    local removeIcon = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    removeIcon:SetSize(18, 18)
    removeIcon:SetPoint("CENTER")
    removeIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
    removeIcon:Hide()
    btn.removeText = removeIcon

    btn:SetScript("OnEnter", function(self)
        self.removeOverlay:Show()
        self.removeText:Show()
        self:SetBackdropBorderColor(unpack(addon.UI.C.danger))
        if self.mountData then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.mountData.name, 1, 1, 1)
            GameTooltip:AddLine("Click to remove", 0.9, 0.3, 0.3)
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function(self)
        self.removeOverlay:Hide()
        self.removeText:Hide()
        self:SetBackdropBorderColor(unpack(addon.UI.C.border))
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function(self)
        if self.mountID and Editor.selectedListID then
            addon.Data:RemoveMountFromList(Editor.selectedListID, self.mountID)
            Editor:RefreshDetailPanel()
            Editor:RefreshListPanel()
            addon.Summon:UpdateMount()
        end
    end)

    return btn
end

-------------------------------------------------------------------------------
-- Dynamic Layout for Checkboxes
-------------------------------------------------------------------------------
function Editor:UpdateLayout()
    if not self.detail:IsShown() then return end
    
    local width = self.detail:GetWidth() - 24
    if width < 100 then width = 300 end
    
    -- Layout contexts
    local cbX = 0
    local cbY = -10
    for i, cb in ipairs(self.contextCheckboxes) do
        cb:ClearAllPoints()
        local cbWidth = cb:GetWidth()
        
        if i == 1 then
            cb:SetPoint("TOPLEFT", self.contextLabel, "BOTTOMLEFT", cbX, cbY)
        else
            if cbX + cbWidth > width then
                cbX = 0
                cbY = cbY - 26
            end
            cb:SetPoint("TOPLEFT", self.contextLabel, "BOTTOMLEFT", cbX, cbY)
        end
        cbX = cbX + cbWidth + 15
    end
    
    -- Position specLabel below contexts (more breathing room)
    self.specLabel:ClearAllPoints()
    self.specLabel:SetPoint("TOPLEFT", self.contextLabel, "BOTTOMLEFT", 0, cbY - 38)
    
    -- Layout specs
    cbX = 0
    local specY = -10
    local hasSpecs = false
    if self.specCheckboxes then
        for i, cb in ipairs(self.specCheckboxes) do
            if not cb:IsShown() then break end
            hasSpecs = true
            cb:ClearAllPoints()
            local cbWidth = cb:GetWidth()
            
            if i == 1 then
                cb:SetPoint("TOPLEFT", self.specLabel, "BOTTOMLEFT", cbX, specY)
            else
                if cbX + cbWidth > width then
                    cbX = 0
                    specY = specY - 26
                end
                cb:SetPoint("TOPLEFT", self.specLabel, "BOTTOMLEFT", cbX, specY)
            end
            cbX = cbX + cbWidth + 15
        end
    end
    
    -- Position mountSep below specs (more breathing room)
    self.mountSep:ClearAllPoints()
    if hasSpecs then
        self.mountSep:SetPoint("TOPLEFT", self.specLabel, "BOTTOMLEFT", -4, specY - 28)
    else
        self.mountSep:SetPoint("TOPLEFT", self.specLabel, "BOTTOMLEFT", -4, -20)
    end
    self.mountSep:SetPoint("RIGHT", self.detail, "RIGHT", -8, 0)
end
