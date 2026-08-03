-------------------------------------------------------------------------------
-- MountSense — Transmog Outfit Picker
-- Standalone modal: pick which player-saved Transmog Outfits (worn = the
-- condition is met) apply to the list currently being edited. Search +
-- scrollable checklist + 3D hover preview via a DressUpModel.
-------------------------------------------------------------------------------
local addonName, addon = ...
local Transmog = {}
addon.Transmog = Transmog

Transmog.frame     = nil
Transmog.listID    = nil
Transmog.selected  = {}   -- [outfitID] = true (working copy of the open list's condition)
Transmog.searchText = ""
Transmog.rows      = {}

local ROW_HEIGHT = 22

-------------------------------------------------------------------------------
-- Create the modal (built once, reused)
-------------------------------------------------------------------------------
function Transmog:Create()
    if self.frame then return end

    local f = CreateFrame("Frame", "MountSenseTransmogPicker", UIParent, "BackdropTemplate")
    f:SetSize(440, 400)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(unpack(addon.UI.C.bg))
    f:SetBackdropBorderColor(unpack(addon.UI.C.borderAccent))
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:Hide()
    table.insert(UISpecialFrames, "MountSenseTransmogPicker")
    self.frame = f

    -- Header
    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(addon.UI.FONT, 13, "")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("Choose Transmog Outfits")
    title:SetTextColor(unpack(addon.UI.C.accent))

    local hint = f:CreateFontString(nil, "OVERLAY")
    hint:SetFont(addon.UI.FONT, 9, "")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    hint:SetText("List is active while you're wearing any of the checked outfits.")
    hint:SetTextColor(unpack(addon.UI.C.textDim))

    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
    closeText:SetFont(addon.UI.FONT, 16, "")
    closeText:SetPoint("CENTER", 0, 1)
    closeText:SetText("×")
    closeText:SetTextColor(unpack(addon.UI.C.textDim))
    closeBtn:SetScript("OnEnter", function() closeText:SetTextColor(unpack(addon.UI.C.danger)) end)
    closeBtn:SetScript("OnLeave", function() closeText:SetTextColor(unpack(addon.UI.C.textDim)) end)
    closeBtn:SetScript("OnClick", function() Transmog:Close() end)

    -- Search box
    local searchBox = addon.UI:CreateEditBox(f, 220, 24, "Search outfits...")
    searchBox:SetPoint("TOPLEFT", 14, -46)
    searchBox.onTextChanged = function(self, userInput)
        if userInput then
            Transmog.searchText = self:GetText()
            Transmog:Refresh()
        end
    end
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    self.searchBox = searchBox

    -- Selection count
    local selCount = f:CreateFontString(nil, "OVERLAY")
    selCount:SetFont(addon.UI.FONT, 10, "")
    selCount:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
    selCount:SetTextColor(unpack(addon.UI.C.textDim))
    self.selCount = selCount

    ---------------------------------------------------------------------------
    -- 3D preview (right)
    ---------------------------------------------------------------------------
    local previewBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
    previewBox:SetWidth(150)
    previewBox:SetPoint("TOPRIGHT", -12, -78)
    previewBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 46)
    previewBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    previewBox:SetBackdropColor(unpack(addon.UI.C.bgPanel))
    previewBox:SetBackdropBorderColor(unpack(addon.UI.C.border))

    local previewHint = previewBox:CreateFontString(nil, "OVERLAY")
    previewHint:SetFont(addon.UI.FONT, 9, "")
    previewHint:SetPoint("BOTTOM", 0, 4)
    previewHint:SetPoint("LEFT", 4, 0)
    previewHint:SetPoint("RIGHT", -4, 0)
    previewHint:SetText("Hover an outfit to preview")
    previewHint:SetTextColor(unpack(addon.UI.C.textDim))
    previewHint:SetJustifyH("CENTER")
    previewHint:SetWordWrap(true)
    self.previewHint = previewHint

    local model = CreateFrame("DressUpModel", nil, previewBox)
    model:SetPoint("TOPLEFT", 4, -4)
    model:SetPoint("TOPRIGHT", -4, -4)
    model:SetPoint("BOTTOM", previewHint, "TOP", 0, 2)
    model:SetUnit("player")
    self.model = model

    ---------------------------------------------------------------------------
    -- Scrollable outfit list (left)
    ---------------------------------------------------------------------------
    local scroll = CreateFrame("ScrollFrame", "MountSenseTransmogScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -78)
    scroll:SetPoint("BOTTOMRIGHT", previewBox, "BOTTOMLEFT", -30, 0)

    local scrollBar = scroll.ScrollBar or _G["MountSenseTransmogScrollScrollBar"]
    if scrollBar then scrollBar:SetWidth(10) end

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetWidth(math.max(1, scroll:GetWidth() - 14))
    scrollChild:SetHeight(1)
    scroll:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild
    self.scroll = scroll

    scroll:SetScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(math.max(1, w - 14))
    end)

    -- Done button
    local doneBtn = addon.UI:CreateAccentButton(f, "Done", 90, 26)
    doneBtn:SetPoint("BOTTOMRIGHT", -12, 10)
    doneBtn:SetScript("OnClick", function() Transmog:Close() end)

    if not (C_TransmogCollection and (C_TransmogCollection.GetOutfits or C_TransmogCollection.GetCustomSets)) then
        local unavailable = f:CreateFontString(nil, "OVERLAY")
        unavailable:SetFont(addon.UI.FONT, 11, "")
        unavailable:SetPoint("CENTER")
        unavailable:SetText("Transmog Outfit API unavailable.")
        unavailable:SetTextColor(unpack(addon.UI.C.danger))
    end
end

-------------------------------------------------------------------------------
-- Open / Close
-------------------------------------------------------------------------------
function Transmog:Open(listID)
    if not self.frame then self:Create() end
    self.listID = listID

    self.selected = {}
    local list = addon.Data:GetList(listID)
    if list and list.conditions and list.conditions.transmogOutfits then
        for _, outfitID in ipairs(list.conditions.transmogOutfits) do
            self.selected[outfitID] = true
        end
    end

    self.searchText = ""
    if self.searchBox then self.searchBox:SetText("") end

    self:Refresh()
    self.frame:Show()
end

function Transmog:Close()
    if self.frame then self.frame:Hide() end
end

-------------------------------------------------------------------------------
-- Refresh the checklist
-------------------------------------------------------------------------------
function Transmog:Refresh()
    if not self.frame then return end

    local allOutfits = addon.Conditions:GetUsableOutfits()
    local filtered = {}
    local search = self.searchText and self.searchText:lower() or ""
    for _, outfit in ipairs(allOutfits) do
        if search == "" or outfit.name:lower():find(search, 1, true) then
            filtered[#filtered + 1] = outfit
        end
    end

    for i, outfit in ipairs(filtered) do
        local row = self.rows[i]
        if not row then
            row = self:CreateRow(self.scrollChild)
            self.rows[i] = row
        end
        row.outfitID = outfit.outfitID
        row.cb.label:SetText(outfit.name)
        row.cb:SetChecked(self.selected[outfit.outfitID] == true)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, -((i - 1) * ROW_HEIGHT))
        row:SetPoint("RIGHT", self.scrollChild, "RIGHT", -2, 0)
        row:Show()
    end

    for i = #filtered + 1, #self.rows do
        self.rows[i]:Hide()
    end

    self.scrollChild:SetHeight(math.max(1, #filtered * ROW_HEIGHT))

    local count = 0
    for _ in pairs(self.selected) do count = count + 1 end
    self.selCount:SetText(count .. " selected")
end

function Transmog:CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    local cb = addon.UI:CreateCheckbox(row, "", 14)
    cb:SetPoint("LEFT", 2, 0)
    cb.onToggle = function()
        Transmog:ToggleOutfit(row.outfitID)
    end
    row.cb = cb

    row:SetScript("OnEnter", function() Transmog:PreviewOutfit(row.outfitID) end)
    row:SetScript("OnLeave", function() Transmog:ClearPreview() end)
    cb:HookScript("OnEnter", function() Transmog:PreviewOutfit(row.outfitID) end)
    cb:HookScript("OnLeave", function() Transmog:ClearPreview() end)

    -- Make the whole row clickable, not just the small checkbox hitbox
    row:EnableMouse(true)
    row:SetScript("OnMouseUp", function()
        cb:SetChecked(not cb:GetChecked())
        Transmog:ToggleOutfit(row.outfitID)
    end)

    return row
end

-------------------------------------------------------------------------------
-- Selection
-------------------------------------------------------------------------------
function Transmog:ToggleOutfit(outfitID)
    if not outfitID then return end
    if self.selected[outfitID] then
        self.selected[outfitID] = nil
    else
        self.selected[outfitID] = true
    end

    local outfitIDs = {}
    for id in pairs(self.selected) do
        outfitIDs[#outfitIDs + 1] = id
    end
    table.sort(outfitIDs)
    addon.Data:SetListTransmogOutfits(self.listID, outfitIDs)

    if addon.Editor then
        addon.Editor:RefreshDetailPanel()
        addon.Editor:RefreshListPanel()
    end
    addon.Summon:UpdateMount()

    local count = 0
    for _ in pairs(self.selected) do count = count + 1 end
    self.selCount:SetText(count .. " selected")
end

-------------------------------------------------------------------------------
-- 3D preview
-------------------------------------------------------------------------------
local ITEM_TRY_ON_DATA_PENDING = 3 -- Enum.ItemTryOnReason.DataPending

function Transmog:PreviewOutfit(outfitID)
    if not self.model or not outfitID then return end
    self.previewingOutfitID = outfitID
    self.model:Undress()
    self:TryOnOutfit(outfitID)
end

-- TryOn() can fail with "DataPending" the first time an item's data hasn't
-- streamed in from the server yet; retry briefly until everything applies.
function Transmog:TryOnOutfit(outfitID, attempt)
    if self.previewingOutfitID ~= outfitID then return end -- superseded by a later hover

    local sourceIDs = addon.Conditions:GetOutfitPreviewSources(outfitID)
    local pending = false
    for _, sourceID in ipairs(sourceIDs) do
        local result = self.model:TryOn(sourceID)
        if result == ITEM_TRY_ON_DATA_PENDING then
            pending = true
        end
    end

    if pending and (attempt or 0) < 10 then
        C_Timer.After(0.2, function()
            Transmog:TryOnOutfit(outfitID, (attempt or 0) + 1)
        end)
    end
end

function Transmog:ClearPreview()
    self.previewingOutfitID = nil
    if not self.model then return end
    self.model:SetUnit("player")
end
