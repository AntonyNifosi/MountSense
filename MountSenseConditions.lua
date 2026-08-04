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

-- Outfit data is served by load-on-demand Blizzard addon modules — the
-- Wardrobe (Blizzard_Collections) and the Transmogrifier NPC frame itself
-- (Blizzard_ItemInteractionUI, which also backs Void Storage / Item
-- Upgrade). Blizzard's own Transmogrifier is known to sometimes need a UI
-- reload before it behaves correctly (reported on their own forums), which
-- points at this module not always finishing its own setup on a fresh
-- login; force-loading both explicitly is the best mitigation available
-- from an addon.
local didLoadOutfitAddOns = false
local function EnsureOutfitAddOnsLoaded()
    if didLoadOutfitAddOns then return end
    didLoadOutfitAddOns = true
    local loadAddOn = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if not loadAddOn then return end
    pcall(loadAddOn, "Blizzard_Collections")
    pcall(loadAddOn, "Blizzard_ItemInteractionUI")
end

-- [TransmogOutfitSlot enum] = real InventorySlotId. Static for the whole
-- session (client-defined, doesn't depend on the outfit or the player).
Conditions.outfitSlotMapCache = nil

-- Below this many resolved slots, GetAllSlotLocationInfo() almost certainly
-- returned an incomplete result (e.g. queried too soon after login, before
-- the transmog UI data streamed in) — there are 11 real slots we map to,
-- and that list is static client data, not outfit- or class-specific.
local OUTFIT_SLOT_MAP_MIN_ENTRIES = 10

function Conditions:GetOutfitSlotMap()
    if self.outfitSlotMapCache then return self.outfitSlotMapCache end
    EnsureOutfitAddOnsLoaded()

    local map = {}
    local count = 0
    if C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetAllSlotLocationInfo then
        local appearanceSlots = C_TransmogOutfitInfo.GetAllSlotLocationInfo() or {}
        for _, info in ipairs(appearanceSlots) do
            if not info.isSecondary then
                local invSlot = OUTFIT_SLOTNAME_TO_INVSLOT[info.slotName]
                if invSlot then
                    map[info.slot] = invSlot
                    count = count + 1
                end
            end
        end
    end

    -- Only cache a result that looks complete; an incomplete one is almost
    -- certainly a transient readiness issue, so let the next call retry
    -- instead of freezing bad data for the rest of the session.
    if count >= OUTFIT_SLOT_MAP_MIN_ENTRIES then
        self.outfitSlotMapCache = map
    end
    return map
end

--- Returns the player's saved Transmog Outfits (name + id), sorted by name.
function Conditions:GetUsableOutfits()
    if self.outfitsCache then return self.outfitsCache end
    EnsureOutfitAddOnsLoaded()

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

    -- Don't lock in an empty result forever — it's more likely a transient
    -- readiness issue (e.g. queried right after login) than a character
    -- that genuinely has zero saved outfits.
    if #outfits > 0 then
        self.outfitsCache = outfits
    end
    return outfits
end

--- For a given Outfit, returns { [inventorySlot] = sourceID } listing what
--- it expects to see worn in each slot it covers. Reading an outfit's
--- contents goes through its "viewed outfit" session
--- (ChangeViewedOutfit + GetViewedOutfitSlotInfo) — confirmed in-game to
--- work fine outside an active NPC transmog session, but confirmed
--- unreliable for a moment right after switching from a different
--- previously-viewed outfit: consecutive queries can return different
--- (sometimes stale, carried over from whatever was viewed before)
--- results until it settles, with no fixed delay that reliably covers it.
--- This is deliberately NOT cached here — callers that need a *stable*
--- reading (like the 3D preview) must query repeatedly until two
--- consecutive reads agree; see MountSenseTransmog.lua.
function Conditions:GetOutfitSlotAppearances(outfitID)
    EnsureOutfitAddOnsLoaded()

    local slotAppearances = {}
    if C_TransmogOutfitInfo and C_TransmogOutfitInfo.ChangeViewedOutfit
       and C_TransmogOutfitInfo.GetViewedOutfitSlotInfo then
        local slotMap = self:GetOutfitSlotMap()
        C_TransmogOutfitInfo.ChangeViewedOutfit(outfitID)
        for outfitSlot, invSlot in pairs(slotMap) do
            local info = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(outfitSlot, 0, 0)
            -- isTransmogrified == true is what actually distinguishes a
            -- slot the outfit defines from one it doesn't: confirmed
            -- in-game that a not-really-set slot can still return a
            -- nonzero, even plausible-looking transmogID, so transmogID
            -- alone isn't a reliable filter — isTransmogrified is.
            if info and info.isTransmogrified and info.transmogID and info.transmogID > 0 then
                slotAppearances[invSlot] = info.transmogID
            end
        end
    end

    return slotAppearances
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
