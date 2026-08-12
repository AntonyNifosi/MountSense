-------------------------------------------------------------------------------
-- MountSense — Summon Logic
-- SecureActionButton for random mount invocation respecting list conditions
-------------------------------------------------------------------------------
local addonName, addon = ...
local Summon = {}
addon.Summon = Summon

Summon.button      = nil
Summon.lastMountID = nil
Summon.history      = {}  -- most recently actually-summoned mount IDs, oldest first

local HISTORY_SIZE = 3

local function RecordHistory(mountID)
    if not mountID then return end
    table.insert(Summon.history, mountID)
    while #Summon.history > HISTORY_SIZE do
        table.remove(Summon.history, 1)
    end
end

-------------------------------------------------------------------------------
-- Create the secure summon button
-------------------------------------------------------------------------------
function Summon:CreateButton()
    if self.button then return end

    if not addon.UI.frame then
        addon.UI:Create()
    end
    local parent = addon.UI.frame.sidebar

    local btn = CreateFrame("Button", "MountSenseSummonButton", parent, "BackdropTemplate")
    btn:SetSize(44, 44)
    btn:SetPoint("BOTTOM", parent, "BOTTOM", 0, 24)

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
    local macroName = "MountSense"
    local function EnsureAndPickupMacro()
        if InCombatLockdown() then
            addon:Print("Cannot create macro during combat.")
            return
        end
        local name, _, body = GetMacroInfo(macroName)
        local desiredBody = "/ms summon"
        if not name then
            local numGlobal, numChar = GetNumMacros()
            if numGlobal < 120 then
                CreateMacro(macroName, 413588, desiredBody, false)
            else
                addon:Print("Macro limit reached! Please delete a macro first, or create one manually with '/ms summon'.")
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
        GameTooltip:SetText("|cffFFB800MountSense|r", 1, 1, 1)
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

    -- Combat/mounted handling lives in SummonRandom() itself (dismounting is
    -- allowed in combat, only summoning a new mount isn't) — don't gate here too.
    btn:SetScript("OnClick", function(self)
        Summon:SummonRandom()
    end)

    self.button = btn
    self:PickRandomMount()

    -- Respect saved visibility preference
    if addon.Data.db.options and not addon.Data.db.options.showButton then
        btn:Hide()
    end
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

    -- Gather unique, collected and usable mount IDs
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

    -- Smart aquatic filter (checked first: actively swimming overrides the
    -- flyable-zone preference below, since you can't fly out of the water)
    local opts = addon.Data.db.options
    local aquaticLockedIn = false
    if opts and opts.smartAquatic and #allMounts > 0 then
        local swimming = addon.Conditions:IsSwimming()
        local filtered = {}
        for _, mountID in ipairs(allMounts) do
            local data = addon.Data:GetMountData(mountID)
            if data then
                if swimming then
                    -- Swimming: prefer AQUATIC mounts
                    if data.category == "AQUATIC" then
                        filtered[#filtered + 1] = mountID
                    end
                else
                    -- Not swimming: exclude AQUATIC mounts so they don't flop around on land
                    if data.category ~= "AQUATIC" then
                        filtered[#filtered + 1] = mountID
                    end
                end
            end
        end
        -- Only apply the filter if it yields at least one mount
        if #filtered > 0 then
            allMounts = filtered
            aquaticLockedIn = swimming
        end
    end

    -- Smart flyable zone filter (skipped if the aquatic filter above already
    -- locked onto AQUATIC mounts for active swimming)
    if opts and opts.smartFlyable and not aquaticLockedIn and #allMounts > 0 then
        local canFly = addon.Conditions:CanFly()
        local filtered = {}
        for _, mountID in ipairs(allMounts) do
            local data = addon.Data:GetMountData(mountID)
            if data then
                if canFly then
                    -- In flyable zone: prefer FLYING mounts
                    if data.category == "FLYING" then
                        filtered[#filtered + 1] = mountID
                    end
                else
                    -- In non-flyable zone: exclude FLYING mounts to ensure they don't run on the ground
                    if data.category ~= "FLYING" then
                        filtered[#filtered + 1] = mountID
                    end
                end
            end
        end
        -- Only apply the filter if it yields at least one mount
        if #filtered > 0 then
            allMounts = filtered
        end
    end

    -- Anti-repeat: avoid resummoning any of the last few actually-summoned
    -- mounts, so long as it still leaves at least one candidate
    if opts and opts.antiRepeat ~= false and #self.history > 0 and #allMounts > 0 then
        local recent = {}
        for _, id in ipairs(self.history) do recent[id] = true end
        local filtered = {}
        for _, mountID in ipairs(allMounts) do
            if not recent[mountID] then
                filtered[#filtered + 1] = mountID
            end
        end
        if #filtered > 0 then
            allMounts = filtered
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
    -- Dismounting isn't restricted in combat (only summoning a new mount is),
    -- so always let this through first — same as clicking any mount button.
    if IsMounted() then
        Dismount()
        return
    end

    if InCombatLockdown() then
        addon:Print("Cannot summon while in combat!")
        return
    end
    self:PickRandomMount()
    if self.lastMountID then
        RecordHistory(self.lastMountID)
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
