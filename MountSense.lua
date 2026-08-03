-------------------------------------------------------------------------------
-- MountSense — Main Entry Point
-- Namespace, events, slash commands, initialization
-------------------------------------------------------------------------------
local addonName, addon = ...

-- Expose globally so macros can use MountSense:...
MountSense = addon

addon.version = "1.2.0"
addon.name    = "MountSense"

-------------------------------------------------------------------------------
-- Event handling
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            addon:Initialize()
            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_LOGIN" then
        addon:OnPlayerLogin()

    elseif event == "PLAYER_ENTERING_WORLD" then
        addon:OnEnteringWorld()

    elseif event == "PLAYER_REGEN_ENABLED" then
        addon.Summon:UpdateMount()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        addon.Summon:UpdateMount()

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- Small delay so instance info is updated
        C_Timer.After(1, function()
            addon.Summon:UpdateMount()
        end)
    end
end)

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------
function addon:Initialize()
    self.Data:InitDB()
end

function addon:OnPlayerLogin()
    self.Data:BuildMountCache()
    self.Summon:CreateButton()
    self.Minimap:Create()
    self:Print("|cffFFB800MountSense|r v" .. self.version .. " loaded — |cff88ff88/ms|r to open")
end

function addon:OnEnteringWorld()
    -- Rebuild cache (handles faction-specific mounts on character change)
    self.Data:BuildMountCache()
    self.Summon:UpdateMount()
end

-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------
function addon:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFB800[MountSense]|r " .. msg)
end

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
SLASH_MountSense1 = "/MountSense"
SLASH_MountSense2 = "/ms"

SlashCmdList["MountSense"] = function(msg)
    msg = (msg or ""):trim():lower()

    if msg == "summon" then
        addon.Summon:SummonRandom()

    elseif msg == "button" then
        addon.Summon:ToggleButton()

    elseif msg == "minimap" then
        addon.Minimap:Toggle()

    elseif msg == "debug" then
        addon:Print("--- MountSense Debug Info ---")
        addon:Print("Zone: " .. tostring(GetRealZoneText()))
        local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        addon:Print("MapID: " .. tostring(mapID))
        addon:Print("IsFlyableArea(): " .. tostring(IsFlyableArea()))
        addon:Print("CanFly(): " .. tostring(addon.Conditions:CanFly()))
        addon:Print("Context: " .. tostring(addon.Conditions:GetCurrentContext()))
        local lists = addon.Conditions:GetMatchingLists()
        addon:Print("Matching Lists: " .. #lists)
        for i, entry in ipairs(lists) do
            local name = entry.list.name or "Unnamed"
            local isStrict = false
            if entry.list.conditions then
                if entry.list.conditions.contexts and #entry.list.conditions.contexts > 0 then isStrict = true end
                if entry.list.conditions.specs and #entry.list.conditions.specs > 0 then isStrict = true end
                if entry.list.conditions.outfits and #entry.list.conditions.outfits > 0 then isStrict = true end
            end
            addon:Print("  " .. i .. ". " .. name .. " (Strict: " .. tostring(isStrict) .. ", Mounts: " .. #(entry.list.mounts) .. ")")
            for j=1, math.min(5, #(entry.list.mounts)) do
                local data = addon.Data:GetMountData(entry.list.mounts[j])
                if data then
                    addon:Print("    - " .. data.name .. " (ID: " .. tostring(data.mountTypeID) .. ", Cat: " .. tostring(data.category) .. ")")
                end
            end
        end

    elseif msg == "help" then
        addon:Print("Commands:")
        addon:Print("  /ms — Open the MountSense panel")
        addon:Print("  /ms summon — Summon a random mount from your lists")
        addon:Print("  /ms button — Toggle the summon button")
        addon:Print("  /ms minimap — Toggle the minimap icon")
        addon:Print("  /ms debug — Print debugging information in chat")

    else
        addon.UI:Toggle()
    end
end
