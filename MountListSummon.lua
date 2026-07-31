-------------------------------------------------------------------------------
-- MountList — Summon Logic
-- SecureActionButton for random mount invocation respecting list conditions
-------------------------------------------------------------------------------
local addonName, addon = ...
local Summon = {}
addon.Summon = Summon

Summon.button      = nil
Summon.lastMountID = nil

-------------------------------------------------------------------------------
-- Create the secure summon button
-------------------------------------------------------------------------------
function Summon:CreateButton()
    if self.button then return end

    if not addon.UI.frame then
        addon.UI:Create()
    end
    local parent = addon.UI.frame.sidebar

    local btn = CreateFrame("Button", "MountListSummonButton", parent, "SecureActionButtonTemplate")
    btn:SetSize(44, 44)
    btn:SetPoint("BOTTOM", parent, "BOTTOM", 0, 24)

    -- Secure attributes
    btn:SetAttribute("type1", "macro")
    btn:SetAttribute("macrotext1", "/run C_MountJournal.SummonByID(0)")

    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    ---------------------------------------------------------------------------
    -- Visuals
    ---------------------------------------------------------------------------
    -- Background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.12, 0.9)
    btn.bg = bg

    -- Icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    -- Border ring
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(1.0, 0.72, 0.0, 0.45)
    border:SetDrawLayer("OVERLAY", -1)
    btn.borderTex = border

    -- Inner border mask (creates border effect)
    local inner = btn:CreateTexture(nil, "OVERLAY")
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    inner:SetColorTexture(0.08, 0.08, 0.12, 0.9)
    inner:SetDrawLayer("OVERLAY", 0)
    btn.inner = inner

    -- Icon re-layer above inner
    icon:SetDrawLayer("OVERLAY", 1)

    -- Highlight
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", 3, -3)
    highlight:SetPoint("BOTTOMRIGHT", -3, 3)
    highlight:SetColorTexture(1, 1, 1, 0.12)

    ---------------------------------------------------------------------------
    -- Scripts
    ---------------------------------------------------------------------------
    local macroName = "MountList"
    local function EnsureAndPickupMacro()
        if InCombatLockdown() then
            addon:Print("Cannot create macro during combat.")
            return
        end
        local name, _, body = GetMacroInfo(macroName)
        local desiredBody = "/ml summon"
        if not name then
            local numGlobal, numChar = GetNumMacros()
            if numGlobal < 120 then
                CreateMacro(macroName, 413588, desiredBody, false)
            else
                addon:Print("Macro limit reached! Please delete a macro first, or create one manually with '/ml summon'.")
                return
            end
        elseif body ~= desiredBody then
            EditMacro(name, macroName, 413588, desiredBody)
        end
        PickupMacro(macroName)
    end

    btn:SetScript("OnDragStart", function(self)
        -- Allow user to drag the macro to action bars!
        EnsureAndPickupMacro()
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffFFB800MountList|r", 1, 1, 1)
        GameTooltip:AddLine("Drag to action bar to place macro", 0.0, 1.0, 0.5)
        if Summon.lastMountID then
            local data = addon.Data:GetMountData(Summon.lastMountID)
            if data then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Next: " .. data.name, 0.0, 1.0, 0.5)
            end
        end
        local ctx = addon.Conditions:GetCurrentContext()
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Context: " .. ctx, 0.5, 0.7, 1.0)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- PreClick: pick a fresh random mount right before the click fires
    btn:SetScript("PreClick", function(self)
        if not InCombatLockdown() then
            Summon:PickRandomMount()
        end
    end)

    -- PostClick: prepare next mount
    btn:SetScript("PostClick", function(self)
        if not InCombatLockdown() then
            C_Timer.After(0.5, function()
                Summon:PickRandomMount()
            end)
        end
    end)

    self.button = btn
    self:PickRandomMount()
end

-------------------------------------------------------------------------------
-- Pick a random mount from matching lists
-------------------------------------------------------------------------------
function Summon:PickRandomMount()
    if InCombatLockdown() then return end

    local matchingLists = addon.Conditions:GetMatchingLists()

    -- Fallback: if nothing matches, use ALL lists
    if #matchingLists == 0 then
        local allLists = addon.Data:GetSortedLists()
        for _, entry in ipairs(allLists) do
            if #entry.list.mounts > 0 then
                matchingLists[#matchingLists + 1] = entry
            end
        end
    end

    -- Gather unique, collected mount IDs
    local allMounts = {}
    local seen = {}
    for _, entry in ipairs(matchingLists) do
        for _, mountID in ipairs(entry.list.mounts) do
            if not seen[mountID] then
                seen[mountID] = true
                local data = addon.Data:GetMountData(mountID)
                if data and data.isCollected then
                    local _, _, _, _, isUsable = C_MountJournal.GetMountInfoByID(mountID)
                    if isUsable then
                        allMounts[#allMounts + 1] = mountID
                    end
                end
            end
        end
    end

    -- If still empty, fallback to SummonByID(0) = random favorite
    if #allMounts == 0 then
        if self.button then
            self.button:SetAttribute("macrotext1", "/run C_MountJournal.SummonByID(0)")
            self.button.icon:SetTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
        end
        self.lastMountID = nil
        return
    end

    local mountID = allMounts[math.random(#allMounts)]
    self.lastMountID = mountID

    if self.button then
        self.button:SetAttribute("macrotext1",
            "/run C_MountJournal.SummonByID(" .. mountID .. ")")
        local data = addon.Data:GetMountData(mountID)
        if data then
            self.button.icon:SetTexture(data.icon)
        end
    end
end

-------------------------------------------------------------------------------
-- Called whenever conditions might have changed
-------------------------------------------------------------------------------
function Summon:UpdateMount()
    if not InCombatLockdown() then
        self:PickRandomMount()
    end
end

-------------------------------------------------------------------------------
-- Manual summon (slash command)
-------------------------------------------------------------------------------
function Summon:SummonRandom()
    if InCombatLockdown() then
        addon:Print("Cannot summon while in combat!")
        return
    end
    self:PickRandomMount()
    if self.lastMountID then
        C_MountJournal.SummonByID(self.lastMountID)
    else
        C_MountJournal.SummonByID(0)
    end
end

-------------------------------------------------------------------------------
-- Toggle button visibility
-------------------------------------------------------------------------------
function Summon:ToggleButton()
    if not self.button then return end
    if self.button:IsShown() then
        self.button:Hide()
        addon.Data.db.options.showButton = false
    else
        self.button:Show()
        addon.Data.db.options.showButton = true
    end
end
