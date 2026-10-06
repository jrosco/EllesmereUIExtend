local addonName, ns = ...
if EUI_CLIENT_BLOCKED or not ns.IsSecret then return end

local addon = {}
ns.Addon = addon
_G.EllesmereUIExtendQuestTracker = addon
ns.Defaults = {
    wowhead = true,
    wowheadDatabase = "auto",
    objectiveColors = true,
    progressColor = { r = 1, g = 0.82, b = 0.25 },
    completedColor = { r = 0.25, g = 1, b = 0.35 },
    messages = true,
    sounds = false,
    soundChannel = "Master",
    statusSounds = { progress = "none", ready = "ready" },
    notificationDestinations = { localChat = true, toast = false, party = false,
        raid = false, instance = false, guild = false },
    toastOpacity = 0.92,
    toastAccentColor = { r = 0.9, g = 0.62, b = 0.16 },
    toastTextAlign = "left",
    toastX = 0,
    toastY = 210,
    questItem = false,
    itemRetailArt = true,
    itemSize = 56,
    itemIconAlpha = 1,
    itemProximityYards = 100,
    itemBorderTexture = "none",
    itemBorderSize = 1,
    itemBorderColor = { r = 1, g = 1, b = 1 },
    itemVisibility = {
        visibility = "always", visibilityMatch = "all",
        visibilityModes = { mouseover = false, in_combat = false, out_of_combat = false,
            in_raid = false, in_party = false, solo = false, show_dragonriding = false, show_not_dragonriding = false,
            hide_in_combat = false, hide_out_of_combat = false, hide_in_raid = false, hide_in_party = false,
            hide_solo = false, hide_dragonriding = false, hide_not_dragonriding = false },
        visOnlyInstances = false, visHideInstances = false, visOnlyDungeons = false, visHideDungeons = false,
        visOnlyHousing = false, visHideHousing = false, visOnlyMounted = false, visHideMounted = false,
        visHideNoTarget = false, visHideWithTarget = false, visHideNoEnemy = false, visHideWithEnemy = false,
        visOnlyResting = false, visHideResting = false, visOnlyVehicle = false, visHideVehicle = false,
        visOnlyPartyMode = false, visHidePartyMode = false, visOnlySkyriding = false, visHideDragonriding = false,
    },
    itemX = 0,
    itemY = -180,
}

local function Normalize(source, defaults)
    source = ns.Table(source) or {}
    local result = {}
    for key, fallback in pairs(defaults) do
        local value = source[key]
        if type(fallback) == "table" then
            result[key] = Normalize(value, fallback)
        elseif type(fallback) == "boolean" then
            local boolean = ns.Boolean(value)
            if boolean == nil then boolean = fallback end
            result[key] = boolean
        elseif type(fallback) == "number" then
            value = ns.Number(value) or fallback
            if key == "r" or key == "g" or key == "b" then value = math.max(0, math.min(1, value)) end
            if key == "itemX" or key == "itemY" or key == "toastX" or key == "toastY" then value = math.max(-10000, math.min(10000, value)) end
            if key == "itemSize" then value = math.floor(math.max(24, math.min(112, value)) + 0.5) end
            if key == "itemIconAlpha" then value = math.max(0, math.min(1, value)) end
            if key == "toastOpacity" then value = math.max(0, math.min(1, value)) end
            if key == "itemProximityYards" then value = math.floor(math.max(1, math.min(1000, value)) + 0.5) end
            if key == "itemBorderSize" then value = math.floor(math.max(1, math.min(4, value)) + 0.5) end
            result[key] = value
        else
            result[key] = ns.String(value) or fallback
        end
    end
    return result
end

function addon.Settings()
    if not ns.settings then
        local saved = ns.Table(_G.EllesmereUIExtendQuestTrackerDB) or {}
        local oldStatuses = ns.Table(saved.statuses)
        ns.settings = Normalize(saved, ns.Defaults)
        -- Preserve existing opt-outs when old status toggles become None choices.
        for kind, enabled in pairs(oldStatuses or {}) do
            if (kind == "progress" or kind == "ready") and ns.Boolean(enabled) == false then
                ns.settings.statusSounds[kind] = "none"
            end
        end
        if not ({ auto = true, retail = true, classic = true })[ns.settings.wowheadDatabase] then
            ns.settings.wowheadDatabase = "auto"
        end
        if ns.settings.toastTextAlign ~= "left" and ns.settings.toastTextAlign ~= "center"
            and ns.settings.toastTextAlign ~= "right" then ns.settings.toastTextAlign = "left" end
        for kind, key in pairs(ns.settings.statusSounds) do
            if key ~= "none" and not (ns.SoundNames and ns.SoundNames[key]) then
                ns.settings.statusSounds[kind] = ns.Defaults.statusSounds[kind]
            end
        end
        if not ({ Master = true, SFX = true, Music = true, Ambience = true, Dialog = true })[ns.settings.soundChannel] then
            ns.settings.soundChannel = "Master"
        end
        local vis = ns.settings.itemVisibility
        if vis.visibilityMatch ~= "all" and vis.visibilityMatch ~= "any" then vis.visibilityMatch = "all" end
        if not ({ always = true, never = true, mouseover = true, in_combat = true, out_of_combat = true,
            in_raid = true, in_party = true, solo = true, show_dragonriding = true, show_not_dragonriding = true })[vis.visibility] then
            vis.visibility = "never"
        end
        local border = ns.settings.itemBorderTexture
        if #border == 0 or #border > 256 or border:find("%c") then ns.settings.itemBorderTexture = "none" end
        _G.EllesmereUIExtendQuestTrackerDB = ns.settings
    end
    return ns.settings
end

function ns.Active()
    return ns.initialized
end

-- Own-frame scheduling also works on clients without C_Timer. Native post-hooks
-- only mark dirty: no frame writes, tracker layout calls or inline callbacks.
local scheduler = CreateFrame("Frame")
local pending = {}
function ns.Queue(key, callback)
    pending[key] = callback
    scheduler:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        local batch = pending
        pending = {}
        for _, func in pairs(batch) do func() end
    end)
end

function ns.Print(text)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff0cd29fExtend Quest Tracker:|r " .. text)
    elseif type(print) == "function" then
        print("Extend Quest Tracker: " .. text)
    end
end

function addon.Refresh()
    if not ns.initialized then return end
    if ns.RefreshObjectives then ns.RefreshObjectives() end
    if ns.RefreshNotifications then ns.RefreshNotifications() end
    if ns.RefreshQuestItem then ns.RefreshQuestItem() end
    if ns.InitMenus then ns.InitMenus() end
end

function addon.Reset()
    _G.EllesmereUIExtendQuestTrackerDB = nil
    ns.settings = nil
    addon.Settings()
    addon.Refresh()
end

function addon.Capabilities()
    return { menus = ns.HasMenus(), questLog = ns.HasQuestLog(), objectives = ns.HasObjectives(), questItem = ns.HasQuestItems()
        and not ns.itemTemplateUnavailable, itemMover = ns.HasItemMover(),
        itemBorders = ns.HasItemBorders(), itemVisibility = ns.HasItemVisibility(), itemNavigation = ns.HasQuestNavigation(), filters = false, collapse = false }
end

local events = CreateFrame("Frame")
local eventNames = { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE",
    "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_WATCH_LIST_CHANGED", "QUEST_DATA_LOAD_RESULT",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "BAG_UPDATE_DELAYED", "SPELL_UPDATE_COOLDOWN", "ZONE_CHANGED_NEW_AREA",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "QUEST_POI_UPDATE", "SUPER_TRACKING_CHANGED",
    "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }
ns.RegisteredEvents = {}
for _, event in ipairs(eventNames) do
    ns.RegisteredEvents[event] = pcall(events.RegisterEvent, events, event)
end

local function Init()
    if ns.initialized or EUI_CLIENT_BLOCKED then return end
    addon.Settings()
    ns.initialized = true
    addon.Refresh()
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then addon.Settings() end
        if ns.RegisterOptions then ns.RegisterOptions() end
        if ns.RegisterToastMover then ns.RegisterToastMover() end
        if ns.initialized then
            if ns.InitMenus then ns.InitMenus() end
            if ns.RefreshObjectives then ns.RefreshObjectives() end
            if ns.RegisterQuestItemMover then ns.RegisterQuestItemMover() end
            if ns.RefreshQuestItem then ns.RefreshQuestItem() end
        end
        return
    elseif event == "PLAYER_LOGIN" then
        ns.Queue("init", Init)
        return
    end
    if not ns.initialized then return end
    if ns.NotificationEvent then ns.NotificationEvent(event, ...) end
    if ns.QuestItemEvent then ns.QuestItemEvent(event, ...) end
    if event == "PLAYER_ENTERING_WORLD" and ns.RefreshObjectives then ns.RefreshObjectives() end
end)

SLASH_ELLESMEREUIEXTENDQUESTTRACKER1 = "/eqtx"
SlashCmdList.ELLESMEREUIEXTENDQUESTTRACKER = function(message)
    message = ns.String(message) or ""
    if message:lower():match("^%s*status%s*$") then
        local c = addon.Capabilities()
        ns.Print((ns.Forever() and "Forever" or "Retail") .. "; menus: " .. tostring(c.menus)
            .. "; quest log: " .. tostring(c.questLog) .. "; objective hooks: " .. tostring(c.objectives)
            .. "; tracked item APIs/template: " .. tostring(c.questItem) .. "; EUI item mover API: " .. tostring(c.itemMover))
        ns.Print("Item borders: " .. tostring(c.itemBorders)
            .. "; secure visibility: " .. tostring(c.itemVisibility) .. "; nav distance: " .. tostring(c.itemNavigation))
        if ns.QuestItemDebugInfo then
            local d = ns.QuestItemDebugInfo()
            ns.Print("Quest item: quest=" .. tostring(d.questID)
                .. " nav=" .. tostring(d.navDistance)
                .. " threshold=" .. tostring(d.proximityYards)
                .. " eligible=" .. tostring(d.eligible)
                .. " reason=" .. tostring(d.reason))
            ns.Print("Item display: liveQuest=" .. tostring(d.liveQuest) .. " shown=" .. tostring(d.shown)
                .. " alpha=" .. tostring(d.alpha) .. " iconAlpha=" .. tostring(d.iconAlpha)
                .. " combat=" .. tostring(d.combat) .. " editing=" .. tostring(d.editing) .. " dead=" .. tostring(d.dead)
                .. " driver=" .. tostring(d.driver))
        end
        ns.Print("Display-only filtering and native collapse features are omitted: no verified taint-safe integration.")
    elseif not ns.InCombat() and EllesmereUI and type(EllesmereUI.OpenPlugin) == "function" then
        EllesmereUI.OpenPlugin(addonName)
    end
end
