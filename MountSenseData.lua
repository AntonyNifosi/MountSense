-------------------------------------------------------------------------------
-- MountSense — Data Layer
-- Mount cache, SavedVariables management, CRUD for lists
-------------------------------------------------------------------------------
local addonName, addon = ...
local Data = {}
addon.Data = Data

Data.mountCache = {}   -- [mountID] = mountData
Data.mountsByType = {} -- [category] = { mountData, ... }

-------------------------------------------------------------------------------
-- Defaults (SavedVariables schema)
-------------------------------------------------------------------------------
Data.defaults = {
    lists = {},
    nextListID = 1,
    minimap = { hide = false, minimapPos = 220 },
    options = {
        showButton      = true,
        previewWidth    = nil,   -- nil = auto (30% of available width)
        smartFlyable    = true,  -- prefer flying mounts in flyable zones
        smartAquatic    = true,  -- prefer aquatic mounts while swimming
        antiRepeat      = true,  -- avoid resummoning recently-summoned mounts
        previewRotation = true,  -- auto-rotate 3D model after 2s hover
    },
}

-------------------------------------------------------------------------------
-- Mount Type categorisation (mountTypeID → category)
-- These IDs come from MountType.db2 and may evolve across patches.
-- Unknown IDs fall back to "OTHER".
-------------------------------------------------------------------------------
Data.MOUNT_TYPE_MAP = {
    -- Ground-only
    [230] = "GROUND",
    [284] = "GROUND",
    [398] = "GROUND",
    [412] = "GROUND",
    -- Flying (includes Skyriding — all modern flying mounts)
    [247] = "FLYING",
    [248] = "FLYING",
    [242] = "FLYING",
    [169] = "FLYING",
    [402] = "FLYING",
    [424] = "FLYING",
    -- Aquatic / Underwater
    [231] = "AQUATIC",
    [232] = "AQUATIC",
    [254] = "AQUATIC",
    [407] = "AQUATIC",
}

Data.MOUNT_CATEGORIES = { "ALL", "GROUND", "FLYING", "AQUATIC", "OTHER" }

Data.MOUNT_TYPE_LABELS = {
    ALL      = "All",
    GROUND   = "Ground",
    FLYING   = "Flying",
    AQUATIC  = "Aquatic",
    OTHER    = "Other",
}

Data.MOUNT_TYPE_ICONS = {
    ALL      = "Interface\\Icons\\Ability_Mount_RidingHorse",
    GROUND   = "Interface\\Icons\\Spell_Nature_Swiftness",
    FLYING   = "Interface\\Icons\\ability_mount_drake_blue",
    AQUATIC  = "Interface\\Icons\\INV_Misc_Fish_35",
    OTHER    = "Interface\\Icons\\trade_engineering",
}

-------------------------------------------------------------------------------
-- Source type labels and rarity ranking
-------------------------------------------------------------------------------
Data.SOURCE_TYPE_LABELS = {
    [0]  = "Unknown",
    [1]  = "Drop",
    [2]  = "Quest",
    [3]  = "Vendor",
    [4]  = "Profession",
    [5]  = "Pet Battle",
    [6]  = "Achievement",
    [7]  = "World Event",
    [8]  = "Promotion",
    [9]  = "Trading Card",
    [10] = "Store",
}

-- Higher = rarer (used for sorting)
Data.SOURCE_RARITY = {
    [9]  = 10,  -- TCG
    [1]  = 9,   -- Drop
    [8]  = 8,   -- Promotion
    [10] = 7,   -- Store
    [6]  = 6,   -- Achievement
    [7]  = 5,   -- World Event
    [5]  = 4,   -- Pet Battle
    [4]  = 3,   -- Profession
    [2]  = 2,   -- Quest
    [3]  = 1,   -- Vendor
    [0]  = 0,   -- Unknown
}

-- Border colours per source type  { r, g, b }
Data.SOURCE_COLORS = {
    [0]  = { 0.50, 0.50, 0.50 },  -- Unknown
    [1]  = { 0.64, 0.21, 0.93 },  -- Drop — purple
    [2]  = { 1.00, 0.82, 0.00 },  -- Quest — yellow
    [3]  = { 0.00, 0.44, 0.87 },  -- Vendor — blue
    [4]  = { 1.00, 0.50, 0.00 },  -- Profession — orange
    [5]  = { 0.12, 0.75, 0.37 },  -- Pet Battle — green
    [6]  = { 1.00, 0.84, 0.00 },  -- Achievement — gold
    [7]  = { 0.67, 0.83, 0.45 },  -- World Event — lime
    [8]  = { 0.00, 0.80, 1.00 },  -- Promotion — cyan
    [9]  = { 0.90, 0.10, 0.10 },  -- TCG — red
    [10] = { 0.00, 0.80, 1.00 },  -- Store — cyan
}

Data.SOURCE_LABELS = {
    [0]  = "Unknown",
    [1]  = "Drop",
    [2]  = "Quest",
    [3]  = "Vendor",
    [4]  = "Profession",
    [5]  = "Pet Battle",
    [6]  = "Achievement",
    [7]  = "World Event",
    [8]  = "Promotion",
    [9]  = "TCG",
    [10] = "Store",
}

-- Context display data
Data.CONTEXT_INFO = {
    { key = "openworld", label = "Open World",   icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { key = "resting",   label = "City",         icon = "Interface\\Icons\\INV_Misc_Map_02" },
    { key = "party",     label = "Dungeon",       icon = "Interface\\Icons\\INV_Helmet_03" },
    { key = "raid",      label = "Raid",          icon = "Interface\\Icons\\Achievement_Dungeon_ClassicDungeonMaster" },
    { key = "pvp",       label = "Battleground",  icon = "Interface\\Icons\\INV_BannerPVP_02" },
    { key = "arena",     label = "Arena",         icon = "Interface\\Icons\\Ability_Dualwield" },
    { key = "scenario",  label = "Delve",         icon = "Interface\\Icons\\INV_Misc_Map08" },
}

-------------------------------------------------------------------------------
-- Initialisation
-------------------------------------------------------------------------------
function Data:InitDB()
    if not MountSenseDB then
        MountSenseDB = self:CopyTable(self.defaults)
    end
    -- Merge missing keys (two levels deep for sub-tables)
    for k, v in pairs(self.defaults) do
        if MountSenseDB[k] == nil then
            if type(v) == "table" then
                MountSenseDB[k] = self:CopyTable(v)
            else
                MountSenseDB[k] = v
            end
        elseif type(v) == "table" and type(MountSenseDB[k]) == "table" then
            for k2, v2 in pairs(v) do
                if MountSenseDB[k][k2] == nil then
                    if type(v2) == "table" then
                        MountSenseDB[k][k2] = self:CopyTable(v2)
                    else
                        MountSenseDB[k][k2] = v2
                    end
                end
            end
        end
    end
    self.db = MountSenseDB
end

function Data:CopyTable(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = self:CopyTable(v)
    end
    return copy
end

-------------------------------------------------------------------------------
-- Mount Cache
-------------------------------------------------------------------------------
function Data:BuildMountCache()
    wipe(self.mountCache)
    wipe(self.mountsByType)

    -- Mount rarity (% of players who own it) comes from the embedded
    -- MountsRarity library (Libs/MountsRarity) rather than our own data —
    -- it's maintained upstream and kept current automatically.
    local rarityLib = LibStub and LibStub("MountsRarity-2.0", true)

    local mountIDs = C_MountJournal.GetMountIDs()
    for _, mountID in ipairs(mountIDs) do
        -- isUsable is deliberately not captured here — it reflects whether
        -- the mount can be summoned RIGHT NOW (zone, indoors, underwater,
        -- etc.), not a fixed property, so it must be queried live wherever
        -- it's actually needed rather than cached.
        local name, spellID, icon, isActive, _, sourceType, isFavorite,
              isFactionSpecific, faction, shouldHideOnChar, isCollected, mID =
              C_MountJournal.GetMountInfoByID(mountID)

        if name and not shouldHideOnChar then
            local creatureDisplayID, description, source, isSelfMount,
                  mountTypeID, uiModelSceneID =
                  C_MountJournal.GetMountInfoExtraByID(mountID)

            local category = self.MOUNT_TYPE_MAP[mountTypeID] or "OTHER"

            local mountData = {
                mountID            = mountID,
                name               = name,
                spellID            = spellID,
                icon               = icon,
                isCollected        = isCollected,
                sourceType         = sourceType or 0,
                mountTypeID        = mountTypeID,
                category           = category,
                creatureDisplayID  = creatureDisplayID,
                description        = description,
                source             = source,
                isFavorite         = isFavorite,
                family             = addon.ExternalData and addon.ExternalData.MountFamilies and addon.ExternalData.MountFamilies[mountID],
                rarity             = rarityLib and rarityLib:GetRarityByID(mountID),
                uiModelSceneID    = uiModelSceneID,
            }

            self.mountCache[mountID] = mountData

            if not self.mountsByType[category] then
                self.mountsByType[category] = {}
            end
            self.mountsByType[category][#self.mountsByType[category] + 1] = mountData
        end
    end
end

function Data:GetMountData(mountID)
    return self.mountCache[mountID]
end

function Data:GetAllMounts()
    return self.mountCache
end

-------------------------------------------------------------------------------
-- "Usable" filtering
--
-- C_MountJournal.GetMountUsabilityByID returns whether a mount can be
-- summoned RIGHT NOW, plus a localized reason when it can't. Confirmed
-- in-game that those reasons split into two kinds:
--   * environmental — depends only on where you're standing ("ground mounts
--     aren't allowed here", "unusable here", ...). Standing indoors makes
--     EVERY mount report one of these, which is why filtering on raw
--     usability emptied the Browse tab whenever you organised lists inside
--     a building.
--   * permanent — faction / class / riding-skill restrictions that will
--     never be satisfied on this character, plus "you don't own this mount".
-- So a mount passes the filter when it's usable now OR its only blocker is
-- environmental: "Usable" means "usable somewhere that allows mounting"
-- rather than "usable on this exact spot". Summon:PickRandomMount
-- deliberately does NOT use this — when actually summoning, only
-- usable-right-now counts.
--
-- Matched against the global string constants rather than hardcoded text so
-- it keeps working on non-English clients, and listed by NAME rather than by
-- value so a constant missing on some client version is simply skipped
-- instead of silently truncating the list (a nil in a table literal would
-- cut ipairs short).
-------------------------------------------------------------------------------
local ENVIRONMENTAL_USE_ERROR_GLOBALS = {
    "SPELL_FAILED_NOT_HERE",
    "SPELL_FAILED_GROUND_MOUNT_NOT_ALLOWED",
    "SPELL_FAILED_FLOATING_MOUNT_NOT_ALLOWED",
    "SPELL_FAILED_NO_MOUNTS_ALLOWED",
    "SPELL_FAILED_INCORRECT_AREA",
    "SPELL_FAILED_ONLY_OUTDOORS",
    "SPELL_FAILED_AFFECTING_COMBAT",
    "SPELL_FAILED_NOT_WHILE_FATIGUED",
    "SPELL_FAILED_NOT_WHILE_SHAPESHIFTED",
}

local environmentalUseErrors
local function IsEnvironmentalUseError(useError)
    if not useError then return false end
    if not environmentalUseErrors then
        environmentalUseErrors = {}
        for _, globalName in ipairs(ENVIRONMENTAL_USE_ERROR_GLOBALS) do
            local msg = _G[globalName]
            if msg then environmentalUseErrors[msg] = true end
        end
    end
    return environmentalUseErrors[useError] == true
end

--- Whether the mount is usable ignoring purely locational restrictions.
function Data:IsMountUsableIgnoringLocation(mountID)
    local isUsable, useError = C_MountJournal.GetMountUsabilityByID(mountID, false)
    if isUsable then return true end
    return IsEnvironmentalUseError(useError)
end

-------------------------------------------------------------------------------
-- Filtered & Sorted mount retrieval
-------------------------------------------------------------------------------
function Data:GetFilteredMounts(searchText, typeFilters, sortBy, collectedOnly, usableOnly, sourceFilter, familyFilters, hideListID)
    local results = {}

    local hideList = hideListID and self:GetList(hideListID) or nil
    local hiddenMounts = {}
    if hideList then
        for _, id in ipairs(hideList.mounts) do
            hiddenMounts[id] = true
        end
    end

    -- Last-resort guard: should some location produce a blocker the
    -- environmental list above doesn't cover, every mount would drop out and
    -- the tab would look broken. Detect that (you own mounts, yet none pass)
    -- and let the filter through rather than showing an empty grid.
    local blanketMountBlock = false
    if usableOnly then
        local collectedCount, usableCount = 0, 0
        for _, data in pairs(self.mountCache) do
            if data.isCollected then
                collectedCount = collectedCount + 1
                if self:IsMountUsableIgnoringLocation(data.mountID) then
                    usableCount = usableCount + 1
                end
            end
        end
        blanketMountBlock = collectedCount > 0 and usableCount == 0
    end

    for _, data in pairs(self.mountCache) do
        local include = true

        if include and hiddenMounts[data.mountID] then
            include = false
        end

        if include and collectedOnly and not data.isCollected then
            include = false
        end

        if include and usableOnly and not blanketMountBlock
           and not self:IsMountUsableIgnoringLocation(data.mountID) then
            include = false
        end

        if include and typeFilters and not typeFilters["ALL"] then
            if not typeFilters[data.category] then
                include = false
            end
        end

        if include and sourceFilter and sourceFilter ~= -1 then
            if data.sourceType ~= sourceFilter then
                include = false
            end
        end

        if include and familyFilters and not familyFilters["ALL"] then
            if not familyFilters[data.family] then
                include = false
            end
        end

        if include and searchText and searchText ~= "" then
            if not data.name:lower():find(searchText:lower(), 1, true) then
                include = false
            end
        end

        if include then
            results[#results + 1] = data
        end
    end

    -- Sort
    if sortBy == "NAME_ASC" then
        table.sort(results, function(a, b) return a.name < b.name end)
    elseif sortBy == "NAME_DESC" then
        table.sort(results, function(a, b) return a.name > b.name end)
    elseif sortBy == "RARITY" then
        table.sort(results, function(a, b)
            local ra = Data.SOURCE_RARITY[a.sourceType] or 0
            local rb = Data.SOURCE_RARITY[b.sourceType] or 0
            if ra ~= rb then return ra > rb end
            return a.name < b.name
        end)
    elseif sortBy == "RARITY_ASC" then
        table.sort(results, function(a, b)
            local ra = a.rarity or 100
            local rb = b.rarity or 100
            if ra ~= rb then return ra < rb end
            return a.name < b.name
        end)
    elseif sortBy == "RARITY_DESC" then
        table.sort(results, function(a, b)
            local ra = a.rarity or 100
            local rb = b.rarity or 100
            if ra ~= rb then return ra > rb end
            return a.name < b.name
        end)
    else
        table.sort(results, function(a, b) return a.name < b.name end)
    end

    return results
end

-------------------------------------------------------------------------------
-- List CRUD
-------------------------------------------------------------------------------
function Data:CreateList(name)
    local id = self.db.nextListID
    self.db.nextListID = id + 1

    self.db.lists[id] = {
        name     = name or ("List " .. id),
        mounts   = {},
        conditions = {
            contexts        = {},
            specs           = {},
            transmogOutfits = {},
        },
        priority = id,
    }
    return id
end

function Data:DeleteList(listID)
    self.db.lists[listID] = nil
end

function Data:GetList(listID)
    return self.db.lists[listID]
end

function Data:GetAllLists()
    return self.db.lists
end

function Data:GetSortedLists()
    local sorted = {}
    for id, list in pairs(self.db.lists) do
        sorted[#sorted + 1] = { id = id, list = list }
    end
    table.sort(sorted, function(a, b)
        return (a.list.priority or 0) < (b.list.priority or 0)
    end)
    return sorted
end

function Data:RenameList(listID, newName)
    local list = self.db.lists[listID]
    if list then list.name = newName end
end

function Data:AddMountsToList(listID, mountIDs)
    local list = self.db.lists[listID]
    if not list then return end

    for _, mountID in ipairs(mountIDs) do
        local found = false
        for _, existing in ipairs(list.mounts) do
            if existing == mountID then found = true; break end
        end
        if not found then
            list.mounts[#list.mounts + 1] = mountID
        end
    end
end

function Data:RemoveMountFromList(listID, mountID)
    local list = self.db.lists[listID]
    if not list then return end
    for i, id in ipairs(list.mounts) do
        if id == mountID then
            table.remove(list.mounts, i)
            return true
        end
    end
    return false
end

function Data:SetListConditions(listID, conditions)
    local list = self.db.lists[listID]
    if list then list.conditions = conditions end
end

function Data:SetListContexts(listID, contexts)
    local list = self.db.lists[listID]
    if list then
        list.conditions = list.conditions or {}
        list.conditions.contexts = contexts
    end
end

function Data:SetListTransmogOutfits(listID, outfitIDs)
    local list = self.db.lists[listID]
    if list then
        list.conditions = list.conditions or {}
        list.conditions.transmogOutfits = outfitIDs
    end
end

function Data:SetListSpecs(listID, specs)
    local list = self.db.lists[listID]
    if list then
        list.conditions = list.conditions or {}
        list.conditions.specs = specs
    end
end

function Data:IsMountInList(listID, mountID)
    local list = self.db.lists[listID]
    if not list then return false end
    for _, id in ipairs(list.mounts) do
        if id == mountID then return true end
    end
    return false
end

function Data:GetListCount()
    local count = 0
    for _ in pairs(self.db.lists) do
        count = count + 1
    end
    return count
end

function Data:ReorderLists(orderedIDs)
    for i, id in ipairs(orderedIDs) do
        if self.db.lists[id] then
            self.db.lists[id].priority = i
        end
    end
end
