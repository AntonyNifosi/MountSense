-------------------------------------------------------------------------------
-- MountList — Mount Browser
-- Grid of mount icons with filters, search, sort, 3D preview, multi-select
-------------------------------------------------------------------------------
local addonName, addon = ...
local Browser = {}
addon.Browser = Browser

Browser.frame = nil
Browser.cards = {}
Browser.selected = {}    -- [mountID] = true
Browser.currentMounts = {}
Browser.previewMountID = nil
Browser.filterType = "ALL"
Browser.sortBy = "NAME_ASC"
Browser.collectedOnly = true
Browser.searchText = ""
Browser.targetListID = nil  -- for "add to list"

local CARD_WIDTH  = 100
local CARD_HEIGHT = 120
local CARD_GAP    = 6
local GRID_COLS   = 5

-------------------------------------------------------------------------------
-- Create the browser UI inside the given parent
-------------------------------------------------------------------------------
function Browser:Create(parent)
    if self.frame then return end

    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    self.frame = f

    ---------------------------------------------------------------------------
    -- Filter Bar (top)
    ---------------------------------------------------------------------------
    local filterBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    filterBar:SetHeight(42)
    filterBar:SetPoint("TOPLEFT", 8, -8)
    filterBar:SetPoint("TOPRIGHT", -8, -8)
    filterBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    filterBar:SetBackdropColor(unpack(addon.UI.C.bgPanel))
    filterBar:SetBackdropBorderColor(unpack(addon.UI.C.border))
    self.filterBar = filterBar

    -- Search box
    local searchBox = addon.UI:CreateEditBox(filterBar, 160, 24, "Search...")
    searchBox:SetPoint("LEFT", 8, 0)
    searchBox.onTextChanged = function(self, userInput)
        if userInput then
            Browser.searchText = self:GetText()
            Browser:Refresh()
        end
    end
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    self.searchBox = searchBox

    -- Type filter buttons
    local typeButtons = {}
    local categories = addon.Data.MOUNT_CATEGORIES
    local btnX = 180
    for _, cat in ipairs(categories) do
        local btn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
        btn:SetSize(24, 24)
        btn:SetPoint("LEFT", btnX, 0)
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(unpack(addon.UI.C.bgCard))
        btn:SetBackdropBorderColor(unpack(addon.UI.C.border))

        local ico = btn:CreateTexture(nil, "ARTWORK")
        ico:SetPoint("TOPLEFT", 2, -2)
        ico:SetPoint("BOTTOMRIGHT", -2, 2)
        ico:SetTexture(addon.Data.MOUNT_TYPE_ICONS[cat])
        ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.ico = ico

        btn.cat = cat
        btn:SetScript("OnClick", function(self)
            Browser.filterType = self.cat
            Browser:UpdateTypeButtons()
            Browser:Refresh()
        end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(addon.Data.MOUNT_TYPE_LABELS[self.cat] or self.cat)
            GameTooltip:Show()
            if Browser.filterType ~= self.cat then
                self:SetBackdropBorderColor(unpack(addon.UI.C.accent))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            if Browser.filterType ~= self.cat then
                self:SetBackdropBorderColor(unpack(addon.UI.C.border))
            end
        end)

        typeButtons[cat] = btn
        btnX = btnX + 30
    end
    self.typeButtons = typeButtons

    -- Sort dropdown
    local sortItems = {
        { text = "Name (A - Z)", value = "NAME_ASC" },
        { text = "Name (Z - A)", value = "NAME_DESC" },
        { text = "Rarity",     value = "RARITY" },
    }
    local sortDD = addon.UI:CreateDropdown(filterBar, 130, sortItems, function(value)
        Browser.sortBy = value
        Browser:Refresh()
    end)
    sortDD:SetPoint("RIGHT", -8, 0)
    self.sortDD = sortDD

    -- Collected toggle
    local collectedCB = addon.UI:CreateCheckbox(filterBar, "Collected", 16)
    collectedCB:SetPoint("RIGHT", sortDD, "LEFT", -12, 0)
    collectedCB:SetChecked(true)
    collectedCB.onToggle = function(self, checked)
        Browser.collectedOnly = checked
        Browser:Refresh()
    end
    self.collectedCB = collectedCB
    Browser.collectedOnly = true

    -- Usable toggle
    local usableCB = addon.UI:CreateCheckbox(filterBar, "Usable", 16)
    usableCB:SetPoint("RIGHT", collectedCB, "LEFT", -70, 0)
    usableCB:SetChecked(true)
    usableCB.onToggle = function(self, checked)
        Browser.usableOnly = checked
        Browser:Refresh()
    end
    self.usableCB = usableCB
    Browser.usableOnly = true

    ---------------------------------------------------------------------------
    -- Main area: Grid (left) + Preview (right)
    ---------------------------------------------------------------------------
    local mainArea = CreateFrame("Frame", nil, f)
    mainArea:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -6)
    mainArea:SetPoint("BOTTOMRIGHT", -8, 44)

    -- Preview panel (right)
    local preview = CreateFrame("Frame", nil, mainArea, "BackdropTemplate")
    local savedWidth = addon.Data.db.options and addon.Data.db.options.previewWidth
    local totalW = addon.UI.frame:GetWidth() - 160
    local initWidth = savedWidth or math.floor(totalW * 0.3)
    preview:SetWidth(initWidth)
    preview:SetPoint("TOPRIGHT", 0, 0)
    preview:SetPoint("BOTTOMRIGHT", 0, 0)
    preview:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    preview:SetBackdropColor(unpack(addon.UI.C.bgPanel))
    preview:SetBackdropBorderColor(unpack(addon.UI.C.border))
    self.preview = preview

    -- Resizer (dragger)
    local resizer = CreateFrame("Button", nil, mainArea)
    resizer:SetWidth(6)
    resizer:SetPoint("TOPRIGHT", preview, "TOPLEFT", 0, 0)
    resizer:SetPoint("BOTTOMRIGHT", preview, "BOTTOMLEFT", 0, 0)
    resizer:EnableMouse(true)
    
    local resizerHighlight = resizer:CreateTexture(nil, "HIGHLIGHT")
    resizerHighlight:SetAllPoints()
    resizerHighlight:SetColorTexture(1, 1, 1, 0.05)

    resizer:SetScript("OnMouseDown", function(self)
        local startX = GetCursorPosition()
        local startW = preview:GetWidth()
        local scale = self:GetEffectiveScale()
        
        self:SetScript("OnUpdate", function(self)
            if not IsMouseButtonDown("LeftButton") then
                self:SetScript("OnUpdate", nil)
                if addon.Data.db.options then
                    addon.Data.db.options.previewWidth = preview:GetWidth()
                end
                return
            end
            
            local x = GetCursorPosition()
            local dx = (startX - x) / scale
            local newW = startW + dx
            
            local maxW = mainArea:GetWidth() * 0.5
            if newW > maxW then newW = maxW end
            if newW < 160 then newW = 160 end
            
            preview:SetWidth(newW)
            if Browser.model then
                local modelSize = newW - 20
                Browser.model:SetSize(modelSize, modelSize)
                Browser.previewContainer:SetSize(newW, modelSize + 140)
            end
        end)
    end)
    resizer:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        if addon.Data.db.options then
            addon.Data.db.options.previewWidth = preview:GetWidth()
        end
    end)
    resizer:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    -- Container to center content vertically
    local previewContainer = CreateFrame("Frame", nil, preview)
    local initialModelSize = initWidth - 20
    previewContainer:SetSize(initWidth, initialModelSize + 140)
    previewContainer:SetPoint("CENTER", preview, "CENTER", 0, 0)
    self.previewContainer = previewContainer

    -- 3D Model
    local model = CreateFrame("ModelScene", nil, previewContainer, "ModelSceneMixinTemplate")
    model:SetSize(initialModelSize, initialModelSize)
    model:SetPoint("TOP", 0, 0)
    model:SetScript("OnMouseDown", function(self) self.rotating = true end)
    model:SetScript("OnMouseUp", function(self) self.rotating = false end)
    model:SetScript("OnUpdate", function(self, elapsed)
        if self.rotating then
            local x, y = GetCursorPosition()
            if self.lastX then
                local dx = (x - self.lastX) * 0.02
                local actor = self:GetActorByTag("unwrapped") or self:GetActorAtIndex(1)
                if actor then
                    actor:SetYaw(actor:GetYaw() + dx)
                end
            end
            self.lastX = x
        else
            self.lastX = nil
        end
    end)
    self.model = model

    -- Mount name in preview
    local previewName = previewContainer:CreateFontString(nil, "OVERLAY")
    previewName:SetFont(addon.UI.FONT, 13, "")
    previewName:SetPoint("TOP", model, "BOTTOM", 0, -20)
    previewName:SetPoint("LEFT", 12, 0)
    previewName:SetPoint("RIGHT", -12, 0)
    previewName:SetJustifyH("CENTER")
    previewName:SetWordWrap(true)
    previewName:SetMaxLines(2)
    previewName:SetTextColor(unpack(addon.UI.C.accent))
    previewName:SetText("")
    self.previewName = previewName

    -- Mount source in preview
    local previewSource = previewContainer:CreateFontString(nil, "OVERLAY")
    previewSource:SetFont(addon.UI.FONT, 10, "")
    previewSource:SetPoint("TOP", previewName, "BOTTOM", 0, -3)
    previewSource:SetPoint("LEFT", 12, 0)
    previewSource:SetPoint("RIGHT", -12, 0)
    previewSource:SetJustifyH("CENTER")
    previewSource:SetWordWrap(true)
    previewSource:SetTextColor(unpack(addon.UI.C.textDim))
    self.previewSource = previewSource

    -- Mount type in preview
    local previewType = previewContainer:CreateFontString(nil, "OVERLAY")
    previewType:SetFont(addon.UI.FONT, 10, "")
    previewType:SetPoint("TOP", previewSource, "BOTTOM", 0, -2)
    previewType:SetPoint("LEFT", 12, 0)
    previewType:SetPoint("RIGHT", -12, 0)
    previewType:SetJustifyH("CENTER")
    previewType:SetWordWrap(true)
    previewType:SetTextColor(unpack(addon.UI.C.textDim))
    self.previewType = previewType

    -- Mount description (scrollable)
    local previewDesc = previewContainer:CreateFontString(nil, "OVERLAY")
    previewDesc:SetFont(addon.UI.FONT, 9, "")
    previewDesc:SetPoint("TOP", previewType, "BOTTOM", 0, -8)
    previewDesc:SetPoint("LEFT", 12, 0)
    previewDesc:SetPoint("RIGHT", -12, 0)
    previewDesc:SetJustifyH("LEFT")
    previewDesc:SetWordWrap(true)
    previewDesc:SetTextColor(0.7, 0.7, 0.72)
    previewDesc:SetMaxLines(6)
    self.previewDesc = previewDesc

    -- "No mount selected" placeholder
    local previewPlaceholder = previewContainer:CreateFontString(nil, "OVERLAY")
    previewPlaceholder:SetFont(addon.UI.FONT, 11, "")
    previewPlaceholder:SetPoint("CENTER")
    previewPlaceholder:SetText("Hover a mount\nto preview")
    previewPlaceholder:SetTextColor(unpack(addon.UI.C.textDim))
    previewPlaceholder:SetJustifyH("CENTER")
    self.previewPlaceholder = previewPlaceholder

    ---------------------------------------------------------------------------
    -- Grid area (left of preview)
    ---------------------------------------------------------------------------
    local gridArea = CreateFrame("Frame", nil, mainArea)
    gridArea:SetPoint("TOPLEFT", 0, 0)
    gridArea:SetPoint("BOTTOMRIGHT", preview, "BOTTOMLEFT", -6, 0)

    -- ScrollFrame
    local scroll = CreateFrame("ScrollFrame", "MountListBrowserScroll", gridArea, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -22, 0)

    -- Style the scrollbar
    local scrollBar = scroll.ScrollBar or _G["MountListBrowserScrollScrollBar"]
    if scrollBar then
        scrollBar:SetWidth(12)
    end

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetWidth(scroll:GetWidth())
    scrollChild:SetHeight(1) -- will be updated
    scroll:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild
    self.scroll = scroll

    -- Update scrollChild width when grid resizes
    gridArea:SetScript("OnSizeChanged", function(self, w, h)
        scrollChild:SetWidth(w - 24)
        Browser:LayoutCards()
    end)

    ---------------------------------------------------------------------------
    -- Selection bar (bottom)
    ---------------------------------------------------------------------------
    local selBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    selBar:SetHeight(36)
    selBar:SetPoint("BOTTOMLEFT", 8, 6)
    selBar:SetPoint("BOTTOMRIGHT", -8, 6)
    selBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    selBar:SetBackdropColor(unpack(addon.UI.C.bgPanel))
    selBar:SetBackdropBorderColor(unpack(addon.UI.C.border))
    self.selBar = selBar

    -- Selection count
    local selCount = selBar:CreateFontString(nil, "OVERLAY")
    selCount:SetFont(addon.UI.FONT, 11, "")
    selCount:SetPoint("LEFT", 12, 0)
    selCount:SetText("0 selected")
    selCount:SetTextColor(unpack(addon.UI.C.textDim))
    self.selCount = selCount

    -- Add to list dropdown
    local listDD = addon.UI:CreateDropdown(selBar, 180, {}, function(value)
        Browser.targetListID = value
        Browser:UpdateCards()
    end)
    listDD:SetPoint("RIGHT", -120, 0)
    self.listDD = listDD

    -- Add button
    local addBtn = addon.UI:CreateAccentButton(selBar, "Add to List", 108, 26)
    addBtn:SetPoint("RIGHT", -6, 0)
    addBtn:SetScript("OnClick", function()
        Browser:AddSelectedToList()
    end)
    self.addBtn = addBtn

    -- Clear selection button
    local clearBtn = addon.UI:CreateButton(selBar, "Clear", 60, 26)
    clearBtn:SetPoint("LEFT", selCount, "RIGHT", 10, 0)
    clearBtn:SetScript("OnClick", function()
        wipe(Browser.selected)
        Browser:UpdateSelection()
        Browser:UpdateCards()
    end)
    self.clearBtn = clearBtn

    -- Select All button
    local selectAllBtn = addon.UI:CreateButton(selBar, "Select All", 80, 26)
    selectAllBtn:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
    selectAllBtn:SetScript("OnClick", function()
        Browser:SelectAll()
    end)
    self.selectAllBtn = selectAllBtn

    -- Initial type button state
    self:UpdateTypeButtons()
end

-------------------------------------------------------------------------------
-- Type filter button highlighting
-------------------------------------------------------------------------------
function Browser:UpdateTypeButtons()
    for cat, btn in pairs(self.typeButtons) do
        if cat == self.filterType then
            btn:SetBackdropColor(unpack(addon.UI.C.accentBg))
            btn:SetBackdropBorderColor(unpack(addon.UI.C.accent))
        else
            btn:SetBackdropColor(unpack(addon.UI.C.bgCard))
            btn:SetBackdropBorderColor(unpack(addon.UI.C.border))
        end
    end
end

-------------------------------------------------------------------------------
-- Refresh the mount grid
-------------------------------------------------------------------------------
function Browser:Refresh()
    if not self.frame or not self.frame:IsShown() then return end

    -- Refresh list dropdown
    self:RefreshListDropdown()

    -- Get filtered mounts
    self.currentMounts = addon.Data:GetFilteredMounts(
        self.searchText,
        self.filterType,
        self.sortBy,
        self.collectedOnly,
        self.usableOnly
    )

    self:BuildCards()
    self:UpdateSelection()
end

function Browser:RefreshListDropdown()
    local items = {}
    local sortedLists = addon.Data:GetSortedLists()
    for _, entry in ipairs(sortedLists) do
        items[#items + 1] = {
            text = entry.list.name .. " (" .. #entry.list.mounts .. ")",
            value = entry.id,
        }
    end
    if #items == 0 then
        items[#items + 1] = { text = "No lists created", value = nil }
    end
    self.listDD:SetItems(items)
    
    if not self.targetListID and #sortedLists > 0 then
        self.targetListID = sortedLists[1].id
    end
    
    if self.targetListID then
        self.listDD:SetValue(self.targetListID, true)
    end
end

-------------------------------------------------------------------------------
-- Build card frames
-------------------------------------------------------------------------------
function Browser:BuildCards()
    -- Hide existing cards
    for _, card in ipairs(self.cards) do
        card:Hide()
    end

    local mounts = self.currentMounts
    local parent = self.scrollChild

    for i, mountData in ipairs(mounts) do
        local card = self.cards[i]
        if not card then
            card = self:CreateCard(parent, i)
            self.cards[i] = card
        end
        self:SetupCard(card, mountData)
        card:Show()
    end

    self:LayoutCards()
end

-------------------------------------------------------------------------------
-- Layout cards in grid
-------------------------------------------------------------------------------
function Browser:LayoutCards()
    local parentWidth = self.scrollChild:GetWidth()
    if parentWidth < 50 then parentWidth = 480 end

    local cols = math.max(1, math.floor((parentWidth + CARD_GAP) / (CARD_WIDTH + CARD_GAP)))
    local totalShown = 0

    for i, card in ipairs(self.cards) do
        if card:IsShown() then
            totalShown = totalShown + 1
            local row = math.floor((totalShown - 1) / cols)
            local col = (totalShown - 1) % cols
            local x = col * (CARD_WIDTH + CARD_GAP) + 4
            local y = -(row * (CARD_HEIGHT + CARD_GAP) + 4)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", x, y)
        end
    end

    local rows = math.ceil(totalShown / cols)
    self.scrollChild:SetHeight(math.max(1, rows * (CARD_HEIGHT + CARD_GAP) + 8))
end

-------------------------------------------------------------------------------
-- Create a single card frame
-------------------------------------------------------------------------------
function Browser:CreateCard(parent, index)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetSize(CARD_WIDTH, CARD_HEIGHT)
    card:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    card:SetBackdropColor(unpack(addon.UI.C.bgCard))
    card:SetBackdropBorderColor(unpack(addon.UI.C.border))

    -- Icon
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 8, -8)
    icon:SetPoint("TOPRIGHT", -8, -8)
    icon:SetHeight(CARD_WIDTH - 16)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.icon = icon

    -- Source colour stripe (top)
    local stripe = card:CreateTexture(nil, "OVERLAY")
    stripe:SetHeight(2)
    stripe:SetPoint("TOPLEFT", 1, -1)
    stripe:SetPoint("TOPRIGHT", -1, -1)
    card.stripe = stripe

    -- Name
    local name = card:CreateFontString(nil, "OVERLAY")
    name:SetFont(addon.UI.FONT, 9, "")
    name:SetPoint("BOTTOMLEFT", 4, 4)
    name:SetPoint("BOTTOMRIGHT", -4, 4)
    name:SetHeight(24)
    name:SetJustifyH("CENTER")
    name:SetJustifyV("BOTTOM")
    name:SetWordWrap(true)
    name:SetMaxLines(2)
    name:SetTextColor(unpack(addon.UI.C.text))
    card.nameText = name

    -- Selection overlay
    local selOverlay = card:CreateTexture(nil, "OVERLAY", nil, 2)
    selOverlay:SetAllPoints()
    selOverlay:SetColorTexture(0.25, 0.55, 1.0, 0.25)
    selOverlay:Hide()
    card.selOverlay = selOverlay

    -- Checkmark (for selection)
    local checkmark = card:CreateFontString(nil, "OVERLAY", nil, 3)
    checkmark:SetFont(addon.UI.FONT, 16, "OUTLINE")
    checkmark:SetPoint("TOPRIGHT", -3, -3)
    checkmark:SetText("v")
    checkmark:SetTextColor(0.2, 0.9, 0.4)
    checkmark:Hide()
    card.checkmark = checkmark

    -- "Already in list" indicator
    local inListGroup = CreateFrame("Frame", nil, card)
    inListGroup:SetAllPoints(icon)
    inListGroup:SetFrameLevel(card:GetFrameLevel() + 2)
    inListGroup:Hide()
    card.inListBadge = inListGroup

    local inListTint = inListGroup:CreateTexture(nil, "BACKGROUND")
    inListTint:SetAllPoints()
    inListTint:SetColorTexture(0.0, 0.8, 0.2, 0.35)

    local inListText = inListGroup:CreateFontString(nil, "OVERLAY")
    inListText:SetFont(addon.UI.FONT, 10, "OUTLINE")
    inListText:SetPoint("CENTER", 0, 0)
    inListText:SetText("IN LIST")
    inListText:SetTextColor(0.4, 1.0, 0.4)

    -- Hover highlight
    local highlight = card:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.06)

    -- Scripts
    card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    card:SetScript("OnClick", function(self, button)
        local mountID = self.mountID
        if not mountID then return end

        if button == "LeftButton" then
            if Browser.selected[mountID] then
                Browser.selected[mountID] = nil
            else
                Browser.selected[mountID] = true
            end
            Browser:UpdateCardSelection(self)
            Browser:UpdateSelection()
        elseif button == "RightButton" then
            C_MountJournal.SummonByID(mountID)
        end
    end)

    card:SetScript("OnEnter", function(self)
        if self.mountData then
            Browser:ShowPreview(self.mountData)
            self:SetBackdropColor(unpack(addon.UI.C.bgCardHover))
        end
    end)

    card:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(addon.UI.C.bgCard))
    end)

    return card
end

-------------------------------------------------------------------------------
-- Setup a card with mount data
-------------------------------------------------------------------------------
function Browser:SetupCard(card, mountData)
    card.mountID = mountData.mountID
    card.mountData = mountData
    card.icon:SetTexture(mountData.icon)
    card.nameText:SetText(mountData.name)

    -- Source colour stripe
    local srcColor = addon.Data.SOURCE_COLORS[mountData.sourceType] or { 0.5, 0.5, 0.5 }
    card.stripe:SetColorTexture(srcColor[1], srcColor[2], srcColor[3], 0.8)

    -- Update selection state
    self:UpdateCardSelection(card)
end

function Browser:UpdateCardSelection(card)
    if not card.mountID then return end

    -- Check if it's already in the target list
    card.inListBadge:Hide()
    if self.targetListID then
        local targetList = addon.Data:GetList(self.targetListID)
        if targetList then
            for _, mID in ipairs(targetList.mounts) do
                if mID == card.mountID then
                    card.inListBadge:Show()
                    break
                end
            end
        end
    end

    if self.selected[card.mountID] then
        card.selOverlay:Show()
        card.checkmark:Show()
        card:SetBackdropBorderColor(0.3, 0.65, 1.0, 1)
    else
        card.selOverlay:Hide()
        card.checkmark:Hide()
        card:SetBackdropBorderColor(addon.UI.C.border[1], addon.UI.C.border[2],
                                     addon.UI.C.border[3], addon.UI.C.border[4])
    end
end

function Browser:UpdateCards()
    for _, card in ipairs(self.cards) do
        if card:IsShown() and card.mountID then
            self:UpdateCardSelection(card)
        end
    end
end

-------------------------------------------------------------------------------
-- Selection management
-------------------------------------------------------------------------------
function Browser:SelectAll()
    for _, mountData in ipairs(self.currentMounts) do
        self.selected[mountData.mountID] = true
    end
    self:UpdateCards()
    self:UpdateSelection()
end

function Browser:UpdateSelection()
    local count = 0
    for _ in pairs(self.selected) do
        count = count + 1
    end
    self.selCount:SetText(count .. " selected")
    if count > 0 then
        self.selCount:SetTextColor(unpack(addon.UI.C.accentBlue))
    else
        self.selCount:SetTextColor(unpack(addon.UI.C.textDim))
    end
end

function Browser:AddSelectedToList()
    local listID = self.targetListID
    if not listID then
        addon:Print("Please select a list first!")
        return
    end

    local list = addon.Data:GetList(listID)
    if not list then
        addon:Print("List not found!")
        return
    end

    local mountIDs = {}
    for mountID in pairs(self.selected) do
        mountIDs[#mountIDs + 1] = mountID
    end

    if #mountIDs == 0 then
        addon:Print("No mounts selected!")
        return
    end

    addon.Data:AddMountsToList(listID, mountIDs)
    addon:Print(#mountIDs .. " mount(s) added to \"" .. list.name .. "\"!")

    -- Re-fetch lists and update dropdown
    self:RefreshListDropdown()
    self.listDD:SetValue(listID, true)

    -- Clear selection
    wipe(self.selected)
    self:UpdateSelection()
    self:UpdateCards()

    -- Update summon button
    if addon.Summon then
        addon.Summon:UpdateMount()
    end
end

-------------------------------------------------------------------------------
-- 3D Preview
-------------------------------------------------------------------------------
function Browser:ShowPreview(mountData)
    if not mountData then return end

    self.previewPlaceholder:Hide()
    self.previewName:SetText(mountData.name)

    local srcLabel = addon.Data.SOURCE_TYPE_LABELS[mountData.sourceType] or "Unknown"
    local srcColor = addon.Data.SOURCE_COLORS[mountData.sourceType] or { 0.5, 0.5, 0.5 }
    self.previewSource:SetText(srcLabel)
    self.previewSource:SetTextColor(srcColor[1], srcColor[2], srcColor[3])

    local typeLabel = addon.Data.MOUNT_TYPE_LABELS[mountData.category] or "Other"
    self.previewType:SetText(typeLabel)

    self.previewDesc:SetText(mountData.description or "")

    -- Set 3D model
    if mountData.uiModelSceneID and mountData.uiModelSceneID > 0 then
        self.model:TransitionToModelSceneID(mountData.uiModelSceneID, 2, 2, true)
        local actor = self.model:GetActorByTag("unwrapped") or self.model:GetActorAtIndex(1)
        if not actor then
            actor = self.model:AcquireActor("ModelSceneActorTemplate")
            if actor then
                actor:SetTag("unwrapped")
            end
        end
        if actor and mountData.creatureDisplayID then
            actor:SetModelByCreatureDisplayID(mountData.creatureDisplayID)
            actor:SetScale(1.116)
        end
    elseif mountData.creatureDisplayID and mountData.creatureDisplayID > 0 then
        local actor = self.model:GetActorAtIndex(1)
        if not actor then
            actor = self.model:AcquireActor("ModelSceneActorTemplate")
        end
        if actor then
            actor:SetModelByCreatureDisplayID(mountData.creatureDisplayID)
            actor:SetScale(1.116)
        end
    end
end
