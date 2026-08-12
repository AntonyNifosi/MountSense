-------------------------------------------------------------------------------
-- MountSense — Mount Inspector
-- Keybind: check what mount your mouseover (or, failing that, your current
-- target) is riding. If it's a mount you own, open a picker to add it to
-- one or more of your lists.
-------------------------------------------------------------------------------
local addonName, addon = ...
local Inspect = {}
addon.Inspect = Inspect

Inspect.frame       = nil
Inspect.mountID     = nil
Inspect.searchText  = ""
Inspect.rows        = {}

local ROW_HEIGHT = 22

-------------------------------------------------------------------------------
-- Keybinding — declared in Bindings.xml (required for it to show up in
-- Blizzard's own Key Bindings UI at all; this BINDING_NAME_* global only
-- supplies the display text for the binding action Bindings.xml already
-- registered). MountSense_InspectKeybind() is the global function
-- Bindings.xml calls.
--
-- Confirmed in-game: Bindings.xml's `header` attribute does NOT currently
-- give a binding its own named section in the list — it silently falls
-- into whatever section precedes it (here, the generic "Add-ons" bucket
-- shared by every addon using category="ADDONS"). Putting the addon's own
-- name directly in `category` instead (see Bindings.xml) is what actually
-- produces a distinct "MountSense" row, matching how other addons
-- (Raider.IO, MDT, etc.) do it. No corresponding BINDING_HEADER_* global
-- is needed for this.
-------------------------------------------------------------------------------
BINDING_NAME_MOUNTSENSE_INSPECT = "Add Targeted/Moused-over Mount to a List"

function MountSense_InspectKeybind()
    Inspect:Run()
end

-------------------------------------------------------------------------------
-- Detection
-------------------------------------------------------------------------------
function Inspect:GetInspectUnit()
    if UnitExists("mouseover") and UnitIsPlayer("mouseover") then
        return "mouseover"
    end
    if UnitExists("target") and UnitIsPlayer("target") then
        return "target"
    end
    return nil
end

--- Scans the unit's buffs for one that resolves to a Mount Journal entry.
--- C_MountJournal.GetMountFromSpell works even for mounts we don't personally
--- own, since mount data (unlike collection state) is global. Uses
--- AuraUtil.ForEachAura rather than the old positional UnitAura(unit, index)
--- signature, which newer clients have moved away from.
function Inspect:GetMountIDFromUnit(unit)
    local foundMountID = nil
    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(aura)
        if aura and aura.spellId then
            local mountID = C_MountJournal.GetMountFromSpell(aura.spellId)
            if mountID then
                foundMountID = mountID
                return true -- stop iterating
            end
        end
    end, true)
    return foundMountID
end

function Inspect:Run()
    local unit = self:GetInspectUnit()
    if not unit then
        addon:Print("No target or moused-over player to inspect.")
        return
    end

    local mountID = self:GetMountIDFromUnit(unit)
    if not mountID then
        addon:Print((UnitName(unit) or "That player") .. " isn't riding a mount.")
        return
    end

    local data = addon.Data:GetMountData(mountID)
    if not data or not data.isCollected then
        local mountName = (data and data.name) or C_MountJournal.GetMountInfoByID(mountID) or "That mount"
        addon:Print("You don't own " .. mountName .. ".")
        return
    end

    self:Open(mountID)
end

-------------------------------------------------------------------------------
-- Popup: choose which list(s) this mount belongs in
-------------------------------------------------------------------------------
function Inspect:Create()
    if self.frame then return end

    local f = CreateFrame("Frame", "MountSenseInspectPicker", UIParent, "BackdropTemplate")
    f:SetSize(340, 420)
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
    table.insert(UISpecialFrames, "MountSenseInspectPicker")
    self.frame = f

    -- Header: mount icon + name
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("TOPLEFT", 14, -14)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.mountIcon = icon

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(addon.UI.FONT, 13, "")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
    title:SetPoint("RIGHT", -34, 0)
    title:SetJustifyH("LEFT")
    title:SetText("Add Mount to Lists")
    title:SetTextColor(unpack(addon.UI.C.accent))

    local mountNameText = f:CreateFontString(nil, "OVERLAY")
    mountNameText:SetFont(addon.UI.FONT, 12, "")
    mountNameText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    mountNameText:SetPoint("RIGHT", -34, 0)
    mountNameText:SetJustifyH("LEFT")
    mountNameText:SetTextColor(unpack(addon.UI.C.textBright))
    self.mountNameText = mountNameText

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
    closeBtn:SetScript("OnClick", function() Inspect:Close() end)

    local hint = f:CreateFontString(nil, "OVERLAY")
    hint:SetFont(addon.UI.FONT, 9, "")
    hint:SetPoint("TOPLEFT", 14, -52)
    hint:SetPoint("RIGHT", -14, 0)
    hint:SetText("Checked = already in that list.")
    hint:SetTextColor(unpack(addon.UI.C.textDim))
    hint:SetJustifyH("LEFT")

    -- Search box
    local searchBox = addon.UI:CreateEditBox(f, 200, 24, "Search lists...")
    searchBox:SetPoint("TOPLEFT", 14, -72)
    searchBox.onTextChanged = function(self, userInput)
        if userInput then
            Inspect.searchText = self:GetText()
            Inspect:Refresh()
        end
    end
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    self.searchBox = searchBox

    -- Scrollable list checklist
    local scroll = CreateFrame("ScrollFrame", "MountSenseInspectScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -104)
    scroll:SetPoint("BOTTOMRIGHT", -28, 46)

    local scrollBar = scroll.ScrollBar or _G["MountSenseInspectScrollScrollBar"]
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
    doneBtn:SetScript("OnClick", function() Inspect:Close() end)

    if not (C_MountJournal and C_MountJournal.GetMountFromSpell) then
        local unavailable = f:CreateFontString(nil, "OVERLAY")
        unavailable:SetFont(addon.UI.FONT, 11, "")
        unavailable:SetPoint("CENTER")
        unavailable:SetText("Mount inspection API unavailable.")
        unavailable:SetTextColor(unpack(addon.UI.C.danger))
    end
end

-------------------------------------------------------------------------------
-- Open / Close
-------------------------------------------------------------------------------
function Inspect:Open(mountID)
    if not self.frame then self:Create() end
    self.mountID = mountID

    local data = addon.Data:GetMountData(mountID)
    if data then
        self.mountIcon:SetTexture(data.icon)
        self.mountNameText:SetText(data.name)
    end

    self.searchText = ""
    if self.searchBox then self.searchBox:SetText("") end

    self:Refresh()
    self.frame:Show()
end

function Inspect:Close()
    if self.frame then self.frame:Hide() end
end

-------------------------------------------------------------------------------
-- Refresh the checklist
-------------------------------------------------------------------------------
function Inspect:Refresh()
    if not self.frame then return end

    local sorted = addon.Data:GetSortedLists()
    local filtered = {}
    local search = self.searchText and self.searchText:lower() or ""
    for _, entry in ipairs(sorted) do
        if search == "" or entry.list.name:lower():find(search, 1, true) then
            filtered[#filtered + 1] = entry
        end
    end

    for i, entry in ipairs(filtered) do
        local row = self.rows[i]
        if not row then
            row = self:CreateRow(self.scrollChild)
            self.rows[i] = row
        end
        row.listID = entry.id
        local count = #entry.list.mounts
        row.cb.label:SetText(entry.list.name .. "  |cff888888(" .. count .. ")|r")
        row.cb:SetChecked(addon.Data:IsMountInList(entry.id, self.mountID))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, -((i - 1) * ROW_HEIGHT))
        row:SetPoint("RIGHT", self.scrollChild, "RIGHT", -2, 0)
        row:Show()
    end

    for i = #filtered + 1, #self.rows do
        self.rows[i]:Hide()
    end

    self.scrollChild:SetHeight(math.max(1, #filtered * ROW_HEIGHT))
end

function Inspect:CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    local cb = addon.UI:CreateCheckbox(row, "", 14)
    cb:SetPoint("LEFT", 2, 0)
    cb.onToggle = function()
        Inspect:ToggleList(row.listID)
    end
    row.cb = cb

    -- Make the whole row clickable, not just the small checkbox hitbox
    row:EnableMouse(true)
    row:SetScript("OnMouseUp", function()
        cb:SetChecked(not cb:GetChecked())
        Inspect:ToggleList(row.listID)
    end)

    return row
end

-------------------------------------------------------------------------------
-- Selection
-------------------------------------------------------------------------------
function Inspect:ToggleList(listID)
    if not listID or not self.mountID then return end

    if addon.Data:IsMountInList(listID, self.mountID) then
        addon.Data:RemoveMountFromList(listID, self.mountID)
    else
        addon.Data:AddMountsToList(listID, { self.mountID })
    end

    -- Refresh row counts/checked-state rather than just flipping the one
    -- checkbox, since the "(N)" mount count suffix also just changed.
    self:Refresh()

    if addon.Editor then
        addon.Editor:RefreshDetailPanel()
        addon.Editor:RefreshListPanel()
    end
end
