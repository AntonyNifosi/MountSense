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
    return (IsFlyableArea() or IsAdvancedFlyableArea()) and true or false
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
-- Evaluation
-------------------------------------------------------------------------------
function Conditions:EvaluateList(list)
    if not list or not list.conditions then
        return true, false
    end

    local conditions = list.conditions
    local contextMatch = true
    local specMatch    = true
    local isStrict     = false

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

    return (contextMatch and specMatch), isStrict
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
