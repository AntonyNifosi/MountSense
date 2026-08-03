-------------------------------------------------------------------------------
-- MountSense — Condition Engine
-- Detects player context (instance type, spec) and evaluates list conditions
-------------------------------------------------------------------------------
local addonName, addon = ...
local Conditions = {}
addon.Conditions = Conditions

-------------------------------------------------------------------------------
-- Context detection
-------------------------------------------------------------------------------
function Conditions:GetCurrentContext()
    local inInstance, instanceType = IsInInstance()

    if not inInstance or instanceType == "none" then
        return "openworld"
    end

    -- instanceType: "party", "raid", "pvp", "arena", "scenario"
    return instanceType
end

function Conditions:CanFly()
    -- Returns true if the player is currently in a zone where flying is allowed
    local zoneName = GetRealZoneText()
    if zoneName and zoneName:find("Quel'Danas") then
        return false
    end

    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if mapID then
        -- Workaround for WoW API bug where IsAdvancedFlyableArea() incorrectly returns true
        -- in The Burning Crusade starting zones (which do not support any form of flying)
        local noFly = {
            [94] = true, [95] = true, [110] = true, -- Blood Elf zones (Eversong, Ghostlands, Silvermoon)
            [97] = true, [106] = true, [114] = true, -- Draenei zones (Azuremyst, Bloodmyst, Exodar)
        }
        if noFly[mapID] then return false end
    end

    return (IsFlyableArea() or (IsAdvancedFlyableArea and IsAdvancedFlyableArea())) and true or false
end

-------------------------------------------------------------------------------
-- Specialisation helpers
-------------------------------------------------------------------------------
function Conditions:GetCurrentSpec()
    local specIndex = GetSpecialization()
    if specIndex then
        local id, name, description, icon, background, role = GetSpecializationInfo(specIndex)
        return id, name, icon, role
    end
    return nil
end

function Conditions:GetPlayerSpecs()
    local specs = {}
    local numSpecs = GetNumSpecializations()
    for i = 1, numSpecs do
        local id, name, description, icon, background, role = GetSpecializationInfo(i)
        if id then
            specs[#specs + 1] = {
                index = i,
                id    = id,
                name  = name,
                icon  = icon,
                role  = role,
            }
        end
    end
    return specs
end

-------------------------------------------------------------------------------
-- Transmogrification helpers
-- Detects whether the player is currently wearing a given player-saved
-- Transmog Outfit — the "Enregistrer la tenue" / Save Outfit combos managed
-- from the Transmogrifier NPC, via the current C_TransmogOutfitInfo API
-- (confirmed against the in-game NPC panel; this is a client-specific,
-- fairly new namespace, distinct from the older/unrelated C_TransmogSets
-- and C_TransmogCollection Custom Sets systems).
-------------------------------------------------------------------------------

-- [outfitID] = { [inventorySlot] = sourceID } — static game data for the
-- session (invalidated whenever the outfit list changes).
Conditions.outfitSlotCache = {}

-- Real InventorySlotId for each TransmogOutfitSlot, matched by the
-- self-describing "slotName" string returned by
-- C_TransmogOutfitInfo.GetAllSlotLocationInfo() — confirmed live in-game
-- rather than guessed. Shirt/Tabard are intentionally excluded: outfits
-- track a value for them, but requiring an exact shirt/tabard match would
-- make "wearing this outfit" needlessly fragile for slots nobody treats as
-- part of the look.
local OUTFIT_SLOTNAME_TO_INVSLOT = {
    HEADSLOT          = 1,
    SHOULDERSLOT      = 3,
    CHESTSLOT         = 5,
    WAISTSLOT         = 6,
    LEGSSLOT          = 7,
    FEETSLOT          = 8,
    WRISTSLOT         = 9,
    HANDSSLOT         = 10,
    BACKSLOT          = 15,
    MAINHANDSLOT      = 16,
    SECONDARYHANDSLOT = 17,
}

-- [TransmogOutfitSlot enum] = real InventorySlotId. Static for the whole
-- session (client-defined, doesn't depend on the outfit or the player).
Conditions.outfitSlotMapCache = nil

function Conditions:GetOutfitSlotMap()
    if self.outfitSlotMapCache then return self.outfitSlotMapCache end

    local map = {}
    if C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetAllSlotLocationInfo then
        local appearanceSlots = C_TransmogOutfitInfo.GetAllSlotLocationInfo() or {}
        for _, info in ipairs(appearanceSlots) do
            if not info.isSecondary then
                local invSlot = OUTFIT_SLOTNAME_TO_INVSLOT[info.slotName]
                if invSlot then
                    map[info.slot] = invSlot
                end
            end
        end
    end

    self.outfitSlotMapCache = map
    return map
end

--- Returns the player's saved Transmog Outfits (name + id), sorted by name.
function Conditions:GetUsableOutfits()
    if self.outfitsCache then return self.outfitsCache end

    -- Outfit data lives behind the load-on-demand Blizzard_Collections
    -- addon; make sure it's loaded before querying, in case the player has
    -- never opened their Wardrobe/Transmogrifier this session.
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_Collections")
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_Collections")
    end

    local outfits = {}
    if C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitsInfo then
        local outfitsInfo = C_TransmogOutfitInfo.GetOutfitsInfo() or {}
        for _, info in ipairs(outfitsInfo) do
            if info.name and info.name ~= "" and not info.isDisabled then
                outfits[#outfits + 1] = { outfitID = info.outfitID, name = info.name }
            end
        end
        table.sort(outfits, function(a, b) return a.name < b.name end)
    end

    self.outfitsCache = outfits
    return outfits
end

--- For a given Outfit, returns { [inventorySlot] = sourceID } listing what
--- it expects to see worn in each slot it covers. Reading an outfit's
--- contents goes through its "viewed outfit" session
--- (ChangeViewedOutfit + GetViewedOutfitSlotInfo) — confirmed in-game to
--- work fine outside an active NPC transmog session.
function Conditions:GetOutfitSlotAppearances(outfitID)
    local cached = self.outfitSlotCache[outfitID]
    if cached then return cached end

    local slotAppearances = {}
    if C_TransmogOutfitInfo and C_TransmogOutfitInfo.ChangeViewedOutfit
       and C_TransmogOutfitInfo.GetViewedOutfitSlotInfo then
        local slotMap = self:GetOutfitSlotMap()
        C_TransmogOutfitInfo.ChangeViewedOutfit(outfitID)
        for outfitSlot, invSlot in pairs(slotMap) do
            local info = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(outfitSlot, 0, 0)
            if info and info.transmogID and info.transmogID > 0 then
                slotAppearances[invSlot] = info.transmogID
            end
        end
    end

    self.outfitSlotCache[outfitID] = slotAppearances
    return slotAppearances
end

--- Per-slot sourceIDs for 3D preview purposes (the outfit data already
--- stores sourceIDs directly, confirmed via C_TransmogCollection.GetSourceInfo).
function Conditions:GetOutfitPreviewSources(outfitID)
    local slotAppearances = self:GetOutfitSlotAppearances(outfitID)
    local preview = {}
    for _, sourceID in pairs(slotAppearances) do
        preview[#preview + 1] = sourceID
    end
    return preview
end

--- Whether the given Outfit is the player's currently active one. Uses the
--- game's own notion of "active outfit" rather than comparing gear
--- ourselves — confirmed live in-game to be accurate (equipped items don't
--- reliably expose their displayed transmog appearance via
--- GetInventoryItemLink, only their base item identity).
function Conditions:IsWearingOutfit(outfitID)
    if not (C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID) then
        return false
    end
    return C_TransmogOutfitInfo.GetActiveOutfitID() == outfitID
end

-------------------------------------------------------------------------------
-- Evaluation
-------------------------------------------------------------------------------
function Conditions:EvaluateList(list)
    if not list or not list.conditions then
        return true, false
    end

    local conditions = list.conditions
    local contextMatch  = true
    local specMatch     = true
    local transmogMatch = true
    local isStrict       = false

    -- Context check
    if conditions.contexts and #conditions.contexts > 0 then
        isStrict = true
        local current = self:GetCurrentContext()
        contextMatch = false
        for _, ctx in ipairs(conditions.contexts) do
            if ctx == current then
                contextMatch = true
                break
            end
        end
    end

    -- Spec check
    if conditions.specs and #conditions.specs > 0 then
        isStrict = true
        local currentSpecID = self:GetCurrentSpec()
        specMatch = false
        if currentSpecID then
            for _, specID in ipairs(conditions.specs) do
                if specID == currentSpecID then
                    specMatch = true
                    break
                end
            end
        end
    end

    -- Transmog outfit check (matches if the player is wearing ANY of the
    -- selected outfits)
    if conditions.transmogOutfits and #conditions.transmogOutfits > 0 then
        isStrict = true
        transmogMatch = false
        for _, outfitID in ipairs(conditions.transmogOutfits) do
            if self:IsWearingOutfit(outfitID) then
                transmogMatch = true
                break
            end
        end
    end

    return (contextMatch and specMatch and transmogMatch), isStrict
end

-------------------------------------------------------------------------------
-- Get all lists that match current conditions (and have mounts)
-------------------------------------------------------------------------------
function Conditions:GetMatchingLists()
    local strictMatches = {}
    local globalMatches = {}
    local allLists = addon.Data:GetAllLists()

    for id, list in pairs(allLists) do
        if #list.mounts > 0 then
            local isMatch, isStrict = self:EvaluateList(list)
            if isMatch then
                if isStrict then
                    strictMatches[#strictMatches + 1] = { id = id, list = list }
                else
                    globalMatches[#globalMatches + 1] = { id = id, list = list }
                end
            end
        end
    end

    if #strictMatches > 0 then
        return strictMatches
    end
    return globalMatches
end
