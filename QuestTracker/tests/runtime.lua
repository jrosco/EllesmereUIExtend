-- Run from the repository root. No upstream fixture or installed WoW is needed.
local unpack = table.unpack or unpack
local ns, frames, tickers, messages, sounds, menus, widgets = {}, {}, {}, {}, {}, {}, {}
local combat, now, failTemplate, prebuild, missingExtraArt = false, 100, false, false, false
local playerDead, playerGhost = false, false
function UnitIsDeadOrGhost(unit) assert(unit == "player"); return playerDead or playerGhost end
local checks, nativeUpdates, trackingWrites = 0, 0, 0
local secret = setmetatable({}, {
    __eq = function() error("secret comparison") end,
    __lt = function() error("secret comparison") end,
    __concat = function() error("secret concatenation") end,
    __index = function() error("secret indexing") end,
    __tostring = function() error("secret formatting") end,
})
function issecretvalue(value) return rawequal(value, secret) end
local function Check(condition, label)
    checks = checks + 1
    assert(condition, label)
end
local function Near(a, b) return math.abs(a - b) < 0.0001 end
function InCombatLockdown() return combat end
function GetTime() return now end
local function Noop() end
local function Protected(frame)
    if frame.secure and combat then error("secure frame write during combat") end
end
function CreateFrame(kind, name, parent, template)
    if failTemplate and template == "SecureActionButtonTemplate" then error("template unavailable") end
    local frame = { kind = kind, name = name, parent = parent, scripts = {}, events = {}, attrs = {},
        secure = template == "SecureActionButtonTemplate", shown = true, color = { 0.7, 0.7, 0.7, 1 }, x = 500, y = 400 }
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:GetParent() return self.parent end
    function frame:CreateTexture() return CreateFrame("Texture", nil, self) end
    function frame:CreateFontString() return CreateFrame("FontString", nil, self) end
    function frame:GetTextColor() return unpack(self.color) end
    function frame:SetTextColor(...) self.color = { ... } end
    function frame:SetAttribute(key, value) Protected(self); self.attrs[key] = value end
    function frame:Show()
        Protected(self)
        local wasShown = self.shown
        self.shown = true
        if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function frame:Hide()
        Protected(self); self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function frame:SetPoint(...) Protected(self); self.point = { ... } end
    function frame:ClearAllPoints() Protected(self); self.point = nil end
    function frame:GetCenter() return self.x, self.y end
    function frame:SetTexture(value)
        self.texture = value
        return not (missingExtraArt and value == "Interface\\ExtraButton\\Default")
    end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetHeight(height) self.height = height end
    function frame:SetScale(scale) self.scale = scale end
    function frame:SetAlpha(value) self.alpha = value end
    function frame:GetAlpha() return self.alpha or 1 end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function frame:SetColorTexture(...) self.colorTexture = { ... } end
    function frame:SetText(value) self.text = value end
    function frame:EnableMouse(value) self.mouseEnabled = value end
    function frame:SetCooldown(start, duration) self.cooldown = { start, duration } end
    function frame:Clear() self.cooldown = nil end
    function frame:StartMoving() Protected(self); self.moving = true end
    function frame:StopMovingOrSizing() Protected(self); self.moving = false end
    function frame:RegisterForClicks(...) self.clicks = { ... } end
    function frame:RegisterForDrag(...) self.drag = { ... } end
    function frame:GetWidth() return self.width or 700 end
    for _, method in ipairs({ "SetFrameStrata", "SetAllPoints", "SetFontObject", "SetWidth", "SetHeight",
        "SetJustifyH", "SetJustifyV", "SetWordWrap",
        "SetAutoFocus", "SetNormalFontObject", "ClearFocus", "SetFocus", "HighlightText", "SetClampedToScreen",
        "SetMovable", "SetHighlightTexture" }) do frame[method] = Noop end
    return frame
end
UIParent = CreateFrame("Frame")
SlashCmdList, UISpecialFrames = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
SOUNDKIT = { UI_AUTO_QUEST_COMPLETE = 23404, IG_QUEST_LIST_COMPLETE = 878, TELL_MESSAGE = 3081 }
function PlaySound(id, channel) sounds[#sounds + 1] = { id, channel }; return true end
C_Timer = { NewTicker = function(interval, callback)
    local ticker = { callback = callback, interval = interval, Cancel = function(self) self.cancelled = true end }
    tickers[#tickers + 1] = ticker
    return ticker
end }
local hooks = setmetatable({}, { __mode = "k" })
function hooksecurefunc(object, method, callback)
    hooks[object] = hooks[object] or {}
    hooks[object][method] = hooks[object][method] or {}
    table.insert(hooks[object][method], callback)
    local original = assert(object[method])
    object[method] = function(...)
        local results = { original(...) }
        callback(...)
        return unpack(results)
    end
end
local function PostUpdate(tracker)
    for _, callback in ipairs(hooks[tracker] and hooks[tracker].Update or {}) do callback(tracker) end
end
local function Pump()
    for _ = 1, 20 do
        local callbacks = {}
        for _, frame in ipairs(frames) do
            if frame.scripts.OnUpdate then callbacks[#callbacks + 1] = { frame, frame.scripts.OnUpdate } end
        end
        if #callbacks == 0 then return end
        for _, entry in ipairs(callbacks) do entry[2](entry[1], 1) end
    end
    error("scheduler did not settle")
end
local function Event(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
    Pump()
end

local quests = {
    { questID = 10, title = "Ten", isHeader = false },
    { questID = 20, title = "Twenty", isHeader = false },
    { questID = 30, title = "Untracked", isHeader = false },
}
local complete, failed, objective, distances, watches, counts = {}, {}, {}, { [10] = 100, [20] = 25, [30] = 1 }, { [10] = 0, [20] = 1 }, { [110] = 1, [120] = 1, [130] = 1 }
local continent, specialLinks = {}, {}
local navQuest, navDistance, trackingQuest = 20, 25, true
C_SuperTrack = {
    GetSuperTrackedQuestID = function() return navQuest end,
    IsSuperTrackingQuest = function() return trackingQuest end,
}
C_Navigation = { GetDistance = function(...)
    assert(select("#", ...) == 0, "navigation distance takes no quest argument")
    return navDistance
end }
C_QuestLog = {
    GetNumQuestLogEntries = function() return #quests end,
    GetInfo = function(index) return quests[index] end,
    GetQuestWatchType = function(id) return watches[id] end,
    GetDistanceSqToQuest = function(id) return distances[id], continent[id] == nil and true or continent[id] end,
    IsComplete = function(id) if complete[id] == nil then return false end; return complete[id] end,
    ReadyForTurnIn = function(id) if complete[id] == nil then return false end; return complete[id] end,
    IsFailed = function(id) if failed[id] == nil then return false end; return failed[id] end,
    GetQuestObjectives = function(id) return objective[id] or { { finished = false, numFulfilled = 0, text = "0/3 things" } } end,
    GetTitleForQuestID = function(id) for _, q in ipairs(quests) do if q.questID == id then return q.title end end end,
    GetLogIndexForQuestID = function(id) for index, q in ipairs(quests) do if q.questID == id then return index end end end,
    AddQuestWatch = function() trackingWrites = trackingWrites + 1 end,
    RemoveQuestWatch = function() trackingWrites = trackingWrites + 1 end,
}
function GetQuestLogSpecialItemInfo(index)
    if specialLinks[index] ~= nil then return specialLinks[index], 500 + index, 0, false end
    return "|Hitem:" .. tostring(100 + quests[index].questID) .. "|h[Item]|h", 500 + index, 0, false
end
function GetQuestLogSpecialItemCooldown() return 90, 30, 1 end
C_Item = { GetItemCount = function(id) return counts[id] or 0 end }
local foci = {}
function GetMouseFoci() return foci end
Menu = { ModifyMenu = function(tag, callback)
    Check(menus[tag] == nil, "menu registered only once")
    menus[tag] = callback
end }
local function MenuEntry(tag, owner, context)
    local entries = {}
    local root = { CreateButton = function(_, label, callback) entries[#entries + 1] = { label, callback } end }
    menus[tag](owner, root, context)
    return entries
end

OBJECTIVE_TRACKER_COLOR = {
    Normal = { r = 0.7, g = 0.7, b = 0.7 }, NormalHighlight = { r = 0.9, g = 0.9, b = 0.9 },
    Complete = { r = 0.1, g = 0.8, b = 0.1 }, Failed = { r = 1, g = 0, b = 0 },
}
OBJECTIVE_TRACKER_COLOR.Normal.reverse = OBJECTIVE_TRACKER_COLOR.NormalHighlight
local function Tracker()
    return { usedBlocks = {}, Update = function() nativeUpdates = nativeUpdates + 1 end }
end
QuestObjectiveTracker, CampaignQuestObjectiveTracker, AchievementObjectiveTracker = Tracker(), Tracker(), Tracker()
ScenarioObjectiveTracker = setmetatable({}, { __index = function() error("scenario tracker touched") end })
UIWidgetObjectiveTracker = setmetatable({}, { __index = function() error("shared widget tracker touched") end })
local fs = CreateFrame("FontString")
fs.colorStyle = OBJECTIVE_TRACKER_COLOR.Normal
local line = { Text = fs, used = true }
local block = { id = 10, parentModule = QuestObjectiveTracker, usedLines = { [1] = line } }
block.HeaderButton = CreateFrame("Button", nil, block)
QuestObjectiveTracker.usedBlocks.Template = { [10] = block }

local spec, pluginCalls = nil, 0
local activeLayoutSection, layoutRows = nil, {}
local aboutTexts = {}
local widgetRefreshCalls = 0
EllesmereUI = {
    _widgetRefreshList = { function() widgetRefreshCalls = widgetRefreshCalls + 1 end },
    RegisterPlugin = function(id, value)
        Check(id == "EllesmereUIExtendQuestTracker", "plugin installed identity")
        pluginCalls = pluginCalls + 1; spec = value; return true
    end,
    OpenPlugin = function(id) Check(id == "EllesmereUIExtendQuestTracker", "slash opens own section") end,
    IsSearchPrebuild = function() return prebuild end,
    CONTENT_PAD = 20,
    L = function(text) return text end,
    PanelPP = { Point = Noop, Size = function(frame, width, height) frame.width, frame.height = width, height end },
    MakeFont = function()
        local label = {}
        function label:SetWidth(width) self.width = width end
        function label:SetJustifyH(value) self.justifyH = value end
        function label:SetWordWrap(value) self.wordWrap = value end
        function label:SetText(text) self.text = text; aboutTexts[#aboutTexts + 1] = text end
        function label:GetStringHeight() return 32 end
        return label
    end,
    Widgets = {
        SectionHeader = function(_, _, text) activeLayoutSection = text; return {}, 30 end,
        Toggle = function(_, _, label, _, getter, setter, tip)
            widgets[label] = { getValue = getter, setValue = setter, tooltip = tip }; return {}, 50
        end,
        DualRow = function(_, _, _, left, right)
            layoutRows[#layoutRows + 1] = { section = activeLayoutSection, left = left and left.text,
                right = right and (right.text ~= "" and right.text or right.buttonText) or nil }
            if left then widgets[left.text] = left end
            if right then widgets[right.text] = right end
            return {}, 50
        end,
        Spacer = function(_, _, _, height) return {}, height or 20 end,
    },
}
local files = { "Compatibility", "QuestTracker", "Wowhead", "Objectives", "NotificationOutput", "Notifications", "ItemVisibility", "QuestItem", "Preview", "Options" }
for _, file in ipairs(files) do assert(loadfile("QuestTracker/" .. file .. ".lua"))("EllesmereUIExtendQuestTracker", ns) end
local addon = EllesmereUIExtendQuestTracker
Check(pluginCalls == 1, "plugin registered once at load")
Check(_G.EllesmereUIExtendQuestTrackerDB == nil, "saved settings not initialized before addon load")
Event("ADDON_LOADED", "EllesmereUIExtendQuestTracker")
Event("PLAYER_LOGIN")
local cfg = addon.Settings()
Check(cfg.objectiveColors and cfg.messages, "cosmetic/message defaults")
Check(not cfg.questItem and not cfg.sounds, "secure item and sounds opt in")
Check(#messages == 0 and #sounds == 0, "silent login baseline")
Check(Near(fs.color[1], cfg.progressColor.r), "progress color applied")
Check(not addon.Capabilities().filters and not addon.Capabilities().collapse, "unsupported features are explicit")
Check(ns.ID(secret) == nil and ns.ID(1.5) == nil and ns.ID(1e30) == nil, "unsafe or invalid IDs rejected")
Check(ns.Number(0/0) == nil and ns.Number(math.huge) == nil, "nonfinite values rejected")

-- Objective colors: native state, latest authored colors, missing/secret data and recycling.
fs.colorStyle = OBJECTIVE_TRACKER_COLOR.Complete
fs:SetTextColor(0.1, 0.8, 0.1, 0.6)
PostUpdate(QuestObjectiveTracker); Pump()
Check(Near(fs.color[2], cfg.completedColor.g) and Near(fs.color[4], 0.6), "completed objective keeps native alpha")
fs:SetTextColor(0.2, 0.3, 0.4, 0.8)
Pump()
cfg.objectiveColors = false; addon.Refresh(); Pump()
Check(Near(fs.color[1], 0.2) and Near(fs.color[3], 0.4) and Near(fs.color[4], 0.8), "disable restores latest external color")
cfg.objectiveColors = true; addon.Refresh(); Pump()
line.used = false; PostUpdate(QuestObjectiveTracker); Pump()
Check(Near(fs.color[1], 0.2), "unused recycled line restored")
line.used = true; fs.colorStyle = OBJECTIVE_TRACKER_COLOR.Failed
fs:SetTextColor(1, 0, 0, 1); Pump()
Check(fs.color[1] == 1 and fs.color[2] == 0, "failed/ineligible state preserved")
fs.colorStyle = secret; PostUpdate(QuestObjectiveTracker); Pump()
Check(fs.color[1] == 1, "secret authored color state is not inspected")
fs.colorStyle = OBJECTIVE_TRACKER_COLOR.Normal
PostUpdate(QuestObjectiveTracker); Pump()
QuestObjectiveTracker.usedBlocks = {}; PostUpdate(QuestObjectiveTracker); Pump()
Check(fs.color[1] == 1 and fs.color[2] == 0, "released block restores latest native color")
QuestObjectiveTracker.usedBlocks = { Template = { [10] = block } }
local secretFS = CreateFrame("FontString")
secretFS.color = { secret, secret, secret, secret }; secretFS.colorStyle = OBJECTIVE_TRACKER_COLOR.Normal
block.usedLines[2] = { Text = secretFS, used = true }
PostUpdate(QuestObjectiveTracker); Pump()
cfg.objectiveColors = false; addon.Refresh(); Pump()
Check(rawequal(secretFS.color[1], secret), "secret native RGB forwarded on release, not inspected")
block.usedLines[2] = nil
cfg.objectiveColors = true; addon.Refresh(); Pump()

-- Correct context menu IDs, no stale title/supertracked guesses, copy popup.
Check(addon.WowheadURL("quest", 10) == "https://www.wowhead.com/quest=10", "Retail URL")
EUI_CLIENT_FOREVER = true
Check(addon.WowheadURL("quest", 10) == "https://www.wowhead.com/classic/quest=10", "Forever auto Classic URL")
EUI_CLIENT_FOREVER = nil
Check(addon.WowheadURL("quest", secret) == nil and addon.WowheadURL("spell", 10) == nil, "invalid URL input rejected")
local entries = MenuEntry("MENU_QUEST_MAP_LOG_TITLE", { questID = 20 })
Check(#entries == 1 and entries[1][1] == "Wowhead URL", "quest-log menu entry")
entries[1][2]()
Check(EllesmereUIExtendQuestTrackerURL.edit.text == "https://www.wowhead.com/quest=20", "copy popup contains chosen log quest")
Check(#MenuEntry("MENU_QUEST_MAP_LOG_TITLE", { questID = secret }) == 0, "secret log quest ID omitted")
foci = { block.HeaderButton }
entries = MenuEntry("MENU_QUEST_OBJECTIVE_TRACKER", UIParent)
Check(#entries == 1, "tracker quest identified by current native header focus")
Check(#MenuEntry("MENU_QUEST_OBJECTIVE_TRACKER", UIParent, secret) == 0, "unreadable supplied context never falls back to a guessed quest")
block.id = 99
entries[1][2]()
Check(EllesmereUIExtendQuestTrackerURL.edit.text:match("quest=10$") ~= nil, "open menu captures ID before pool reuse")
block.id = 10
foci = {}
Check(#MenuEntry("MENU_QUEST_OBJECTIVE_TRACKER", UIParent) == 0, "no hovered block: no guessed tracker ID")
Check(#MenuEntry("MENU_ACHIEVEMENT_TRACKER", UIParent, { id = 123 }) == 1, "achievement menu supplied context")
cfg.wowhead = false
addon.Refresh(); Pump()
Check(#MenuEntry("MENU_QUEST_MAP_LOG_TITLE", { questID = 20 }) == 0, "disabled URL menus omitted")
entries[1][2]()
Check(not EllesmereUIExtendQuestTrackerURL.shown, "already-open menu action respects disabled URL setting")
cfg.wowhead = true

-- Notification transitions, silent refreshes, secrets, throttling and no abandonment guess.
cfg.sounds, cfg.statusSounds.progress = true, "global"
addon.Refresh(); Pump()
objective[10] = { { finished = false, numFulfilled = 1, text = "1/3 things" } }
Event("QUEST_LOG_UPDATE")
Check(#messages == 1 and messages[1]:find("Objective progress", 1, true), "readable progress notification")
Check(#sounds == 1 and sounds[1][1] == 23404, "client sound-kit constant used")
Event("QUEST_LOG_UPDATE")
Check(#messages == 1, "unchanged quest updates do not notify")
objective[10] = { { finished = true, numFulfilled = 3, text = "3/3 things" } }
Event("QUEST_LOG_UPDATE")
Check(#messages == 2 and messages[2]:find("Objective completed", 1, true), "objective completion notification")
Check(#sounds == 1, "sound bursts throttled")
now = now + 2; complete[10] = true
Event("QUEST_LOG_UPDATE")
Check(#messages == 3 and messages[3]:find("Ready for turn-in", 1, true), "ready transition notification")
Event("QUEST_TURNED_IN", 10)
local before = #messages
Event("QUEST_TURNED_IN", 10)
Check(#messages == before, "duplicate turned-in event suppressed")
Event("QUEST_REMOVED", 20)
Check(#messages == before, "removal does not invent abandonment")
now = now + 2; Event("QUEST_ACCEPTED", 20)
Check(messages[#messages]:find("Accepted", 1, true), "accepted notification")
failed[20] = true; Event("QUEST_LOG_UPDATE")
Check(messages[#messages]:find("Failed", 1, true), "failed transition notification")
before = #messages
complete[30], failed[30] = secret, secret
objective[30] = { { finished = secret, numFulfilled = secret, text = secret } }
Event("QUEST_LOG_UPDATE")
Check(#messages == before, "secret status/objective data skipped")
Event("PLAYER_ENTERING_WORLD")
Check(#messages == before, "zone/login baseline is silent")
cfg.messages = false; cfg.sounds = true; addon.Refresh(); Pump()
local beforeIndependentSound = #sounds
now = now + 2; Event("QUEST_ACCEPTED", 30)
Check(#messages == before and #sounds == beforeIndependentSound + 1,
    "disabling messages leaves notification sounds active")
cfg.messages = true; cfg.sounds = false; addon.Refresh(); Pump()
local beforeIndependentMessage, beforeMutedSound = #messages, #sounds
now = now + 2; Event("QUEST_ACCEPTED", 10)
Check(#messages == beforeIndependentMessage + 1 and #sounds == beforeMutedSound,
    "disabling sounds leaves notification messages active")
local play = PlaySound; SOUNDKIT.UI_AUTO_QUEST_COMPLETE = nil
now = now + 2; Event("QUEST_ACCEPTED", 20)
Check(ns.SoundID("ready") == nil, "missing sound does not guess a numeric ID")
SOUNDKIT.UI_AUTO_QUEST_COMPLETE = 23404; PlaySound = play

-- Removal can precede turn-in, after the title API no longer knows the quest.
now = now + 2
local removedQuest = table.remove(quests, 2)
Event("QUEST_REMOVED", 20)
before = #messages
Event("QUEST_TURNED_IN", 20)
Check(#messages == before + 1 and messages[#messages]:find("Twenty", 1, true), "turn-in after log removal retains a short-lived title")
Event("QUEST_TURNED_IN", 20)
Check(#messages == before + 1, "turn-in tombstone still deduplicates")
now = now + 6
Event("QUEST_TURNED_IN", 20)
Check(#messages == before + 1, "expired removal title is not guessed")
table.insert(quests, 2, removedQuest)

-- Last-objective and quest-ready statuses are independently selectable.
complete[20], failed[20], objective[20] = false, false, { { finished = false, numFulfilled = 0, text = "One task" } }
addon.Refresh(); Pump(); before = #messages
complete[20], objective[20] = true, { { finished = true, numFulfilled = 1, text = "One task" } }
Event("QUEST_LOG_UPDATE")
Check(#messages == before + 2, "final objective and ready notifications both respect their toggles")

-- Navigation identity and distance must belong to the same quest.
complete[10], complete[20], complete[30], failed[20] = false, false, false, false
Check(cfg.itemProximityYards == 100, "default proximity is 100 yards")
C_QuestLog.GetSelectedQuest = function() return 0 end
Check(addon.NearestQuestItem().questID == 20, "super-tracked quest works with Quest Log selection zero")
C_QuestLog.GetSelectedQuest = nil
Check(addon.NearestQuestItem().questID == 20, "Quest Log selection API is not a dependency")
navDistance = 101
Check(addon.NearestQuestItem() == nil, "distance above threshold hides the button")
Check(ns.QuestItemDebugInfo().reason == "item-feature-disabled", "diagnostics distinguish disabled feature")
cfg.questItem = true
Check(ns.QuestItemDebugInfo().reason == "too-far" and ns.QuestItemDebugInfo().questID == 20, "distance rejection preserves diagnostic quest identity")
cfg.questItem = false
navDistance = 100
Check(addon.NearestQuestItem() and addon.NearestQuestItem().questID == 20, "distance at threshold shows the button")
navDistance = 100.1
Check(addon.NearestQuestItem() == nil, "unrounded distance just outside threshold is rejected")
cfg.itemProximityYards = 150
Check(addon.NearestQuestItem().questID == 20, "configured threshold above default is used")
cfg.itemProximityYards = 50; navDistance = 51
Check(addon.NearestQuestItem() == nil, "configured threshold below default is used")
navDistance = 50
Check(addon.NearestQuestItem().questID == 20, "custom threshold boundary is inclusive")
cfg.itemProximityYards = 100
for _, value in ipairs({ secret, -1, math.huge, 0/0, "25" }) do
    navDistance = value
    Check(addon.NearestQuestItem() == nil, "unreadable/invalid navigation distance fails closed")
end
navDistance = nil
Check(addon.NearestQuestItem() == nil, "missing navigation distance fails closed")
navDistance = 0
Check(addon.NearestQuestItem().questID == 20, "zero distance is valid for an active quest")
navDistance = 25
for _, value in ipairs({ 0, secret, 999, 30 }) do
    navQuest = value
    Check(addon.NearestQuestItem() == nil, "invalid, absent or unwatched navigation quest never falls back to another item")
end
navQuest = 20
trackingQuest = false
Check(addon.NearestQuestItem() == nil, "user waypoint does not reuse a retained quest ID")
trackingQuest = secret
Check(addon.NearestQuestItem() == nil, "unreadable navigation type fails closed")
trackingQuest = true
navQuest = 10
Check(addon.NearestQuestItem().questID == 10, "changing navigation selects only that quest's item")
navQuest = 20
counts[120] = 0
Check(addon.NearestQuestItem() == nil, "missing selected item never falls back to quest 10")
counts[120] = 1
watches[20] = secret
Check(addon.NearestQuestItem() == nil, "secret tracking state excluded")
watches[20] = 1; complete[20] = secret
Check(addon.NearestQuestItem() == nil, "unreadable completion fails closed")
complete[20] = true
Check(addon.NearestQuestItem() == nil, "completed quest without show-item permission excluded")
complete[20] = false; specialLinks[2] = secret
Check(addon.NearestQuestItem() == nil, "secret item link not parsed")
specialLinks[2] = nil
local specialItemAPI = GetQuestLogSpecialItemInfo
GetQuestLogSpecialItemInfo = function(index)
    local link, icon, charges = specialItemAPI(index)
    return link, icon, charges, true
end
complete[20] = true
Check(addon.NearestQuestItem().questID == 20, "completed quest retains an item explicitly allowed after completion")
complete[20] = false; GetQuestLogSpecialItemInfo = specialItemAPI
local distanceAPI = C_QuestLog.GetDistanceSqToQuest
C_QuestLog.GetDistanceSqToQuest = nil
Check(addon.Capabilities().questItem and addon.NearestQuestItem().questID == 20, "legacy squared distance is not a dependency")
C_QuestLog.GetDistanceSqToQuest = distanceAPI
local navAPI = C_Navigation.GetDistance
C_Navigation.GetDistance = function() error("restricted") end
Check(addon.NearestQuestItem() == nil, "throwing navigation fails closed")
C_Navigation.GetDistance = nil
Check(not addon.Capabilities().questItem, "missing navigation gates item controls")
C_Navigation.GetDistance = navAPI
local superAPI = C_SuperTrack
C_SuperTrack = nil
Check(not addon.Capabilities().questItem and addon.NearestQuestItem() == nil, "missing super-tracking API cannot guess an item")
C_SuperTrack = superAPI
local identityAPI = C_SuperTrack.GetSuperTrackedQuestID
C_SuperTrack.GetSuperTrackedQuestID = function() error("restricted quest identity") end
Check(addon.NearestQuestItem() == nil, "throwing navigation identity fails closed")
C_SuperTrack.GetSuperTrackedQuestID = identityAPI
local timerAPI = C_Timer.NewTicker; C_Timer.NewTicker = nil
Check(not addon.Capabilities().questItem, "missing movement timer gates item feature")
C_Timer.NewTicker = timerAPI
cfg.questItem = true; combat = true; addon.Refresh(); Pump()
Check(_G.EllesmereUIExtendQuestTrackerItem == nil, "combat login/enable defers secure button creation")
combat = false; Event("PLAYER_REGEN_ENABLED")
local itemButton = EllesmereUIExtendQuestTrackerItem
Check(itemButton.shown and itemButton.attrs.type1 == "item" and itemButton.attrs.item1 == "item:120", "secure navigation quest item action configured")
Check(itemButton.clicks[1] == "AnyDown" and itemButton.clicks[2] == "AnyUp", "both key-down preferences supported")
Check(itemButton.drag[1] == "RightButton", "right drag leaves left item action intact")
Check(itemButton.cooldown.cooldown[2] == 30, "quest item cooldown displayed")
Check(itemButton.width == 56 and itemButton.height == 56, "art fix preserves live button hit area")
Check(itemButton.art.width == 256 and itemButton.art.height == 128, "native extra-action artwork rectangle is not squeezed to a square")
Check(itemButton.icon.point[2] == -2 and itemButton.icon.point[3] == 2, "52px icon matches native art proportions")
Check(addon.Settings().itemProximityYards == 100, "default proximity threshold is 100 yards")
local function NoAddedBorder(frame)
    for _, region in ipairs(frames) do
        if region.parent == frame and region.kind == "Texture" and region.colorTexture then return false end
    end
    return true
end
Check(NoAddedBorder(itemButton), "live item button has no added solid green outline")
playerDead = true; Event("PLAYER_DEAD")
Check(not itemButton.shown, "no-state-driver fallback hides dead player")
playerDead, playerGhost = false, true; Event("PLAYER_ALIVE")
Check(not itemButton.shown, "releasing spirit keeps fallback hidden")
playerGhost = false; Event("PLAYER_UNGHOST")
Check(itemButton.shown, "fallback restores eligible item after resurrection")
local deathAPI = UnitIsDeadOrGhost
UnitIsDeadOrGhost = function() return secret end
ns.UpdateQuestItem()
Check(not itemButton.shown, "unreadable fallback death state fails closed")
UnitIsDeadOrGhost = deathAPI; ns.UpdateQuestItem()
navDistance = 101; tickers[#tickers].callback()
Check(not itemButton.shown and itemButton.attrs.item1 == nil, "movement beyond configured yards clears and hides the live item")
Check(ns.QuestItemDebugInfo().reason == "too-far", "live rejection reports distance instead of no-item")
navDistance = 100; tickers[#tickers].callback()
Check(itemButton.shown and itemButton.attrs.item1 == "item:120", "movement back to threshold restores live item")
navQuest = 10; Event("SUPER_TRACKING_CHANGED")
Check(itemButton.attrs.item1 == "item:110", "navigation event switches the live item to the correct quest")
trackingQuest = false; Event("SUPER_TRACKING_CHANGED")
Check(not itemButton.shown and itemButton.attrs.item1 == nil, "nonquest navigation hides even with a retained quest ID")
trackingQuest = true; navQuest = 20; Event("SUPER_TRACKING_CHANGED")
combat = true; navQuest = 10
navDistance = 101
Event("QUEST_LOG_UPDATE"); tickers[#tickers].callback()
Check(itemButton.attrs.item1 == "item:120", "combat never reassigns protected item")
Check(ns.QuestItemDebugInfo().reason == "combat-deferred; evaluated=too-far", "diagnostics explain why combat retains the prior action")
cfg.questItem = false; addon.Refresh(); Pump()
Check(itemButton.shown, "combat disable parks protected visibility until regen")
combat = false; Event("PLAYER_REGEN_ENABLED")
Check(not itemButton.shown and itemButton.attrs.item1 == nil, "regen applies disable and clears item")
navDistance = 25
cfg.questItem = true; addon.Refresh(); Pump()
Check(itemButton.attrs.item1 == "item:110", "reenable rescans current navigation quest item")
itemButton.x, itemButton.y = 650, 350
itemButton.scripts.OnDragStop(itemButton)
Check(cfg.itemX == 150 and cfg.itemY == -50, "readable position saved")
addon.ResetItemPosition()
Check(cfg.itemX == 0 and cfg.itemY == -180, "position reset")
combat = secret
ns.UpdateQuestItem()
Check(ns.InCombat(), "unreadable combat lockdown fails closed")
combat = false
counts[110], counts[120] = 0, 0; Event("BAG_UPDATE_DELAYED")
Check(not itemButton.shown, "no eligible item hides button without untracked fallback")
counts[110], counts[120] = 1, 1

-- EUI Unlock Mode APIs can arrive after login. Only public registration APIs
-- are mocked here, using the shared factory's actual long-field convention.
local unlockActive, unlockElements, unlockListeners = false, {}, {}
local moverRegistrations, listenerRegistrations = 0, 0
EllesmereUI.MakeUnlockElement = function(opts)
    return { key = opts.key, label = opts.label, group = opts.group, getFrame = opts.getFrame, getSize = opts.getSize,
        isHidden = opts.isHidden, savePosition = opts.savePos, loadPosition = opts.loadPos,
        clearPosition = opts.clearPos, applyPosition = opts.applyPos, noResize = opts.noResize,
        noAnchorTo = opts.noAnchorTo, noAnchorTarget = opts.noAnchorTarget, noSizeMatchTarget = opts.noSizeMatchTarget }
end
EllesmereUI.IsUnlockModeActive = function() return unlockActive end
EllesmereUI.RegisterUnlockElements = function(_, elements, folder)
    Check(not combat, "mover registration deferred during combat")
    Check(folder == "EllesmereUIExtendQuestTracker", "mover folder is installed addon identity")
    moverRegistrations = moverRegistrations + 1
    for _, element in ipairs(elements) do unlockElements[element.key] = element end
end
EllesmereUI.RegisterUnlockModeListener = function(_, owner, callback)
    listenerRegistrations = listenerRegistrations + 1
    unlockListeners[owner] = callback
    if unlockActive then callback(true) end
end
Event("ADDON_LOADED", "EllesmereUIOptions")
local moverKey = "EQTX_QuestItem"
local mover = assert(unlockElements[moverKey])
local listener = assert(unlockListeners[moverKey])
local toastMoverKey = "EQTX_NotificationToast"
local toastMover = assert(unlockElements[toastMoverKey])
local toastListener = assert(unlockListeners[toastMoverKey])
Check(toastMover.label == "Quest Notification Toast" and toastMover.group == "Extend Quest Tracker"
    and toastMover.noResize and toastMover.noAnchorTarget, "local toast has isolated fixed-size EUI mover")
Check(toastMover.isHidden() and toastMover.getFrame() == nil, "toast mover is hidden until local toast destination enabled")
Check(mover.label == "Tracked Quest Item" and mover.group == "Extend Quest Tracker", "named EUI quest-item mover")
Check(mover.noResize and mover.noAnchorTo and mover.noAnchorTarget and mover.noSizeMatchTarget, "fixed mover cannot create secure anchor/size dependencies")
Check(addon.Capabilities().itemMover, "public mover API capability")
addon.Refresh(); addon.Refresh(); Pump()
Check(moverRegistrations == 2 and listenerRegistrations == 2, "quest and toast movers register once each")
local itemPreview = mover.getFrame()
Check(itemPreview ~= itemButton and not itemPreview.secure and itemPreview.kind == "Frame", "mover owns a separate non-secure preview")
Check(not itemPreview.shown and itemPreview.mouseEnabled == false and itemPreview.scripts.OnClick == nil, "preview is hidden outside edit mode and cannot use items")
Check(itemPreview.art.width == 256 and itemPreview.art.height == 128 and NoAddedBorder(itemPreview), "edit preview shares native-sized borderless artwork")
local width, height = mover.getSize()
Check(width == 56 and height == 56, "authoritative mover size does not measure secure geometry")
itemButton.moving = false
itemButton.scripts.OnDragStart(itemButton)
Check(not itemButton.moving, "right-drag reserved for missing mover API fallback")

local function OpenEdit()
    unlockActive = true
    listener(true)
    toastListener(true)
    Pump()
end
local function CloseEdit(action)
    unlockActive = false
    listener(false, action)
    toastListener(false, action)
    Pump()
end
cfg.notificationDestinations.toast = true; cfg.messages = true
ns.RefreshNotificationOutput()
local toastSample = toastMover.getFrame()
local toastWidth, toastHeight = toastMover.getSize()
Check(toastSample and toastSample.isPreview and toastWidth == 400 and toastHeight == 96,
    "enabled local toast exposes non-clickable EUI preview and fixed mover size")
toastListener(true)
Check(toastSample.shown and toastSample.mouseEnabled == false, "toast preview appears only as a non-clickable sample")
local originalToastX, originalToastY = cfg.toastX, cfg.toastY
toastMover.savePosition(toastMoverKey, "CENTER", "CENTER", 123, 456)
Check(cfg.toastX == 123 and cfg.toastY == 456, "toast mover saves its independent anchor")
toastListener(false, "discard")
Check(cfg.toastX == originalToastX and cfg.toastY == originalToastY and not toastSample.shown,
    "toast edit close hides sample and preserves saved position")
toastListener(true)
toastMover.savePosition(toastMoverKey, "CENTER", "CENTER", 9, 18)
toastListener(false, "exit")
Check(cfg.toastX == originalToastX and cfg.toastY == originalToastY, "toast Exit Without Saving restores entry position")
toastListener(true)
toastMover.savePosition(toastMoverKey, "CENTER", "CENTER", 321, 654)
toastListener(false, "save")
Check(cfg.toastX == 321 and cfg.toastY == 654, "toast Save & Exit commits new position")
ns.ResetToastPosition()
Check(cfg.toastX == 0 and cfg.toastY == 210, "toast reset restores default top-center position")
cfg.notificationDestinations.toast = false; ns.RefreshNotificationOutput()
Check(toastMover.isHidden() and toastMover.getFrame() == nil, "disabling local toast hides its mover")
cfg.notificationDestinations.toast = true; ns.RefreshNotificationOutput()
local securePoint = itemButton.point
counts[110], counts[120] = 0, 0
local timerCount = #tickers
OpenEdit()
Check(itemPreview.shown and not itemButton.shown, "edit mode shows preview without an eligible quest item")
Check(itemButton.attrs.item1 == nil and itemButton.attrs.type1 == nil, "edit mode disables the live secure action")
Check(#tickers == timerCount and tickers[#tickers].cancelled, "editing stops item polling")
itemPreview:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 90, -45)
local pendingPoint = itemPreview.point
Event("QUEST_LOG_UPDATE"); ns.RefreshQuestItem(); mover.applyPosition()
Check(itemPreview.point == pendingPoint and itemButton.point == securePoint, "refreshes preserve staged preview placement and never move the live action")
local oldX, oldY = cfg.itemX, cfg.itemY
mover.savePosition(moverKey, "CENTER", "CENTER", secret, 9)
mover.savePosition(moverKey, secret, "CENTER", 9, 9)
mover.savePosition(moverKey, "TOPLEFT", "TOPLEFT", 9, 9)
Check(cfg.itemX == oldX and cfg.itemY == oldY, "secret or noncanonical mover coordinates rejected")
mover.savePosition(moverKey, "CENTER", "CENTER", 321, -88)
Check(cfg.itemX == 321 and cfg.itemY == -88 and itemButton.point == securePoint, "mover saves canonical position without editing the secure frame")
CloseEdit("save")
Check(not itemPreview.shown and cfg.itemX == 321 and cfg.itemY == -88, "Save & Exit commits position and removes preview")
counts[110], counts[120] = 1, 1; Event("BAG_UPDATE_DELAYED")
Check(itemButton.shown and itemButton.attrs.item1 == "item:110" and itemButton.attrs.type1 == "item", "after edit mode the latest real quest item action resumes")
Check(itemButton.point[4] == 321 and itemButton.point[5] == -88, "live button applies committed EUI position")
ns.settings = nil; cfg = addon.Settings()
Check(cfg.itemX == 321 and cfg.itemY == -88, "mover position survives saved-settings reload normalization")

OpenEdit()
mover.savePosition(moverKey, "CENTER", "CENTER", 45, 67)
listener(true) -- Duplicate notification must not replace the session snapshot.
CloseEdit("discard")
Check(cfg.itemX == 321 and cfg.itemY == -88, "discard restores the original snapshot despite duplicate enter notifications")
OpenEdit()
mover.clearPosition()
Check(cfg.itemX == 0 and cfg.itemY == -180, "mover reset uses addon defaults")
CloseEdit("exit")
Check(cfg.itemX == 321 and cfg.itemY == -88, "Exit Without Saving restores pre-reset position")
OpenEdit()
cfg.questItem = false; addon.Refresh(); Pump()
Check(mover.isHidden() and mover.getFrame() == nil, "disabling tracked quest item hides its mover")
mover.savePosition(moverKey, "CENTER", "CENTER", 777, 888)
mover.clearPosition()
Check(cfg.itemX == 321 and cfg.itemY == -88, "already-open mover callbacks respect feature locks")
cfg.questItem = true; addon.Refresh(); Pump()
Check(not mover.isHidden(), "reenabling tracked quest item restores its mover without a duplicate listener")
itemPreview:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -70)
pendingPoint = itemPreview.point
combat = true; Event("PLAYER_REGEN_DISABLED")
Check(not itemPreview.shown, "combat suspension hides the non-secure preview")
mover.savePosition(moverKey, "CENTER", "CENTER", 555, 666)
mover.clearPosition(); addon.ResetItemPosition()
Check(cfg.itemX == 321 and cfg.itemY == -88 and mover.getFrame() == nil, "combat blocks geometry reads, mover saves and reset callbacks")
combat = false; Event("PLAYER_REGEN_ENABLED")
Check(itemPreview.shown and itemPreview.point == pendingPoint and not itemButton.shown, "combat recovery preserves pending edit placement and keeps the live action disabled")
combat = true; Event("PLAYER_REGEN_DISABLED"); CloseEdit("save")
Check(not itemPreview.shown and not itemButton.shown, "closing edit mode during combat defers secure restoration")
combat = false; Event("PLAYER_REGEN_ENABLED")
Check(itemButton.shown and itemButton.attrs.type1 == "item", "regen restores the live action after combat-time edit close")
listener(secret, "save")
Check(itemButton.shown and not itemPreview.shown, "unreadable edit-state notification is not branched on")
local listenerAPI = EllesmereUI.RegisterUnlockModeListener
EllesmereUI.RegisterUnlockModeListener = nil
Check(not addon.Capabilities().itemMover, "partial EUI mover API gates integration")
itemButton.scripts.OnDragStart(itemButton)
Check(itemButton.moving, "missing EUI mover API retains right-drag fallback")
itemButton.scripts.OnDragStop(itemButton)
EllesmereUI.RegisterUnlockModeListener = listenerAPI

-- Joining an already-open session must work without an EUI entry snapshot.
local publicMoverAPI = { MakeUnlockElement = EllesmereUI.MakeUnlockElement,
    RegisterUnlockElements = EllesmereUI.RegisterUnlockElements,
    RegisterUnlockModeListener = EllesmereUI.RegisterUnlockModeListener,
    IsUnlockModeActive = EllesmereUI.IsUnlockModeActive }
local joinedElement, joinedListener, joinedRegistrations, joinedActive = nil, nil, 0, true
EllesmereUI.IsUnlockModeActive = function() return joinedActive end
EllesmereUI.RegisterUnlockElements = function(_, elements) joinedElement = elements[1]; joinedRegistrations = joinedRegistrations + 1 end
EllesmereUI.RegisterUnlockModeListener = function(_, _, callback) joinedListener = callback; callback(true) end
local joined = setmetatable({ Addon = addon }, { __index = ns })
assert(loadfile("QuestTracker/QuestItem.lua"))("EllesmereUIExtendQuestTracker", joined)
counts[110], counts[120] = 0, 0
local joinX, joinY = cfg.itemX, cfg.itemY
missingExtraArt = true
joined.RefreshQuestItem()
local joinedPreview = joinedElement.getFrame()
Check(not joinedPreview.art.shown and NoAddedBorder(joinedPreview), "missing native artwork falls back to a plain icon without a green border")
missingExtraArt = false
Check(joinedRegistrations == 1 and joinedPreview.shown, "late registration in an open session handles synchronous notification without recursion")
joinedElement.savePosition(moverKey, "CENTER", "CENTER", 800, 900)
joinedActive = false; joinedListener(false, "exit")
Check(cfg.itemX == joinX and cfg.itemY == joinY and not joinedPreview.shown, "late-joined session restores its own original position on unsaved exit")
joinedActive = true; joinedListener(true)
joinedElement.savePosition(moverKey, "CENTER", "CENTER", 111, 222)
joinedActive = false; joinedListener(false, "save")
Check(cfg.itemX == 111 and cfg.itemY == 222, "late-joined session can save a position")
cfg.itemX, cfg.itemY = joinX, joinY
local previousRegistrations = joinedRegistrations
EllesmereUI.IsUnlockModeActive = function() return secret end
local unreadable = setmetatable({ Addon = addon }, { __index = ns })
assert(loadfile("QuestTracker/QuestItem.lua"))("EllesmereUIExtendQuestTracker", unreadable)
unreadable.RefreshQuestItem()
Check(joinedRegistrations == previousRegistrations, "unreadable public unlock state does not register or guess a session")
EllesmereUI.IsUnlockModeActive = function() return false end
EllesmereUI.MakeUnlockElement = function() error("factory unavailable on this EUI build") end
local badFactory = setmetatable({ Addon = addon }, { __index = ns })
assert(loadfile("QuestTracker/QuestItem.lua"))("EllesmereUIExtendQuestTracker", badFactory)
badFactory.RefreshQuestItem()
Check(joinedRegistrations == previousRegistrations, "throwing mover factory leaves registration untouched")
for key, func in pairs(publicMoverAPI) do EllesmereUI[key] = func end
counts[110], counts[120] = 1, 1
ns.RefreshQuestItem()

-- Old saved zone settings cannot restrict navigation-distance eligibility.
cfg.itemZoneOnly = true
ns.settings = nil; cfg = addon.Settings()
Check(cfg.itemZoneOnly == nil, "removed zone setting is dropped during normalization")
Check(C_Map == nil and C_QuestLog.GetQuestsOnMap == nil and addon.NearestQuestItem().questID == 10,
    "navigation quest qualifies without any zone/POI APIs")

-- Public border renderer and native visibility driver doubles. The real EUI
-- compiler itself is exercised separately by tests/visibility.lua.
EllesmereUI.GetBorderTextureDropdown = function() return { solid = "Solid", blizzard = "Blizzard" }, { "solid", "blizzard" } end
EllesmereUI.ApplyBorderStyle = function(host, size, r, g, b, a, texture, _, _, _, _, surface)
    Check(not combat or (host.parent and type(host.parent.RefreshAppearance) == "function"),
        "combat border rendering is confined to the isolated settings sample")
    host.testBorder = { size = size, r = r, g = g, b = b, a = a, texture = texture, surface = surface }
    if size > 0 then host:Show() else host:Hide() end
end
local visibilityUpdaters = {}
EllesmereUI.RegisterVisibilityUpdater = function(callback) visibilityUpdaters[#visibilityUpdaters + 1] = callback end
EllesmereUI.GetActiveVisibilityModes = function(store) return nil end
EllesmereUI.GetVisibilitySelection = function(store) return { [store.visibility] = true } end
EllesmereUI.CheckVisibilityOptionsNonMacro = function() return false end
EllesmereUI.BuildVisibilityDriverString = function(prefix, selection)
    if selection.in_combat then return prefix .. "[combat] show; hide" end
    if selection.out_of_combat then return prefix .. "[nocombat] show; hide" end
    return prefix .. "show"
end
EllesmereUI.BuildAnyMatchTail = function() return "show" end
EllesmereUI.VisWantsMouseover = function(store) return store.visibility == "mouseover" end
local drivers, driverWrites = {}, 0
local function NativeResolve(frame, driver)
    local shown = driver ~= "hide"
    if driver:find("[combat] show", 1, true) then shown = combat == true end
    if driver:find("[nocombat] show", 1, true) then shown = combat == false end
    if driver:find("[@player,dead] hide;", 1, true) and (playerDead or playerGhost) then shown = false end
    local wasShown = frame.shown
    frame.shown = shown -- Simulates native secure execution, not addon Show/Hide.
    if wasShown and not shown and frame.scripts.OnHide then frame.scripts.OnHide(frame) end
end
function RegisterStateDriver(frame, state, driver)
    Check(not combat and state == "visibility", "driver writes are out-of-combat only")
    drivers[frame] = driver; driverWrites = driverWrites + 1; NativeResolve(frame, driver)
end
function UnregisterStateDriver(frame)
    Check(not combat, "driver removal is out-of-combat only")
    drivers[frame] = nil
end
EllesmereUI.BuildVisibilityRow = function(_, _, _, opts)
    widgets.Visibility = { tooltip = opts.tooltip, control = opts }
    return {}, 50
end
cfg.itemRetailArt = false; cfg.itemSize = 84
cfg.itemBorderTexture, cfg.itemBorderSize = "solid", 3
cfg.itemBorderColor = { r = 0.2, g = 0.4, b = 0.6 }
ns.RefreshQuestItem()
Check(itemButton.width == 84 and itemButton.height == 84 and itemButton.art.width == 384 and itemButton.art.height == 192, "size changes scale the icon/art without distorting Retail proportions")
Check(not itemButton.art.shown, "Retail background toggle is independent")
Check(Near(itemButton.icon.alpha, 1), "default icon opacity is opaque")
Check(Near(itemButton.art.alpha, 1), "default background opacity is opaque")
Check(Near(itemButton.questItemBorder.alpha, 1), "default border opacity is opaque")
Check(itemButton.questItemBorder.testBorder.size == 3 and itemButton.questItemBorder.testBorder.surface == "actionbars", "EUI renderer uses action-bar border defaults")
Check(Near(itemButton.questItemBorder.width, 78) and Near(itemButton.questItemBorder.testBorder.g, 0.4), "border follows icon size and chosen tint")
Check(#visibilityUpdaters == 1, "shared visibility updater registered once")
OpenEdit()
Check(itemPreview.width == 84 and not itemPreview.art.shown and itemPreview.questItemBorder.shown, "edit preview reflects size, background toggle and border")
cfg.itemBorderTexture = "blizzard"; ns.RefreshQuestItem()
Check(itemPreview.questItemBorder.testBorder.texture == "blizzard", "preview uses selected textured EUI border")
cfg.itemBorderTexture = "none"; cfg.itemRetailArt = true; ns.RefreshQuestItem()
Check(not itemPreview.questItemBorder.shown and itemPreview.art.shown, "None removes border without disabling Retail art")
cfg.itemIconAlpha = 0.4; ns.RefreshQuestItem()
Check(Near(itemPreview.icon.alpha, 0.4) and Near(itemPreview.art.alpha, 0.4), "preview icon and background follow opacity setting")
Check(Near(itemPreview.questItemBorder.alpha, 0.4), "preview border follows opacity setting")
CloseEdit("save")
Check(Near(itemButton.icon.alpha, 0.4) and Near(itemButton.art.alpha, 0.4), "live appearance updates after leaving preview mode")
Check(Near(itemButton.questItemBorder.alpha, 0.4), "live border uses the same saved icon alpha")
Check(itemButton.width == 84 and itemButton.art.shown and not itemButton.questItemBorder.shown, "closing editor applies latest look to the live action")
cfg.itemVisibility.visibility = "in_combat"; ns.RefreshQuestItem()
Check(not itemButton.shown and drivers[itemButton]:find("[combat] show", 1, true), "in-combat visibility installs a native driver instead of an addon event Show")
local writesBeforeCombat = driverWrites
combat = true; NativeResolve(itemButton, drivers[itemButton]); Event("PLAYER_REGEN_DISABLED")
Check(itemButton.shown, "native combat visibility can show the secure button during lockdown")
playerDead = true; NativeResolve(itemButton, drivers[itemButton]); Event("PLAYER_DEAD")
Check(not itemButton.shown and driverWrites == writesBeforeCombat, "native death gate hides during combat without protected Lua writes")
Check(ns.QuestItemDebugInfo().reason == "player-dead-or-ghost", "status explains death hiding")
playerDead, playerGhost = false, true
NativeResolve(itemButton, drivers[itemButton]); Event("PLAYER_ALIVE")
Check(not itemButton.shown, "native death gate stays hidden as a ghost")
playerGhost = false; NativeResolve(itemButton, drivers[itemButton]); Event("PLAYER_UNGHOST")
Check(itemButton.shown and driverWrites == writesBeforeCombat, "native gate permits combat resurrection without rewriting driver")
cfg.itemSize, cfg.itemRetailArt = 112, false
navQuest = 20
Event("ZONE_CHANGED_NEW_AREA"); ns.RefreshQuestItem()
Check(driverWrites == writesBeforeCombat and itemButton.width == 84 and itemButton.attrs.item1 == "item:110", "combat defers appearance, quest selection and driver rewrites")
combat = false; NativeResolve(itemButton, drivers[itemButton]); Event("PLAYER_REGEN_ENABLED")
Check(itemButton.width == 112 and not itemButton.art.shown and itemButton.attrs.item1 == "item:120", "regen applies latest appearance and current navigation quest item")
Check(not itemButton.shown, "addon item refresh does not override native out-of-combat hiding")
cfg.itemVisibility.visibility = "mouseover"; ns.RefreshQuestItem()
Check(itemButton.shown and itemButton.alpha == 0, "mouseover remains native-shown for hover but starts transparent")
itemButton.scripts.OnEnter(itemButton)
Check(itemButton.alpha == 1, "hover reveals item button")
itemButton.scripts.OnLeave(itemButton)
Check(itemButton.alpha == 0, "leaving hover fades item button")
cfg.itemVisibility.visibility = "never"; ns.RefreshQuestItem()
Check(not itemButton.shown and itemButton.attrs.item1 ~= nil, "Never hides action without inventing an empty candidate")
OpenEdit()
Check(itemPreview.shown and not itemButton.shown, "Never visibility still permits a non-clickable edit preview")
CloseEdit("exit")
cfg.itemVisibility.visibility = "always"; navQuest = 0
ns.RefreshQuestItem()
Check(not itemButton.shown and itemButton.attrs.item1 == nil and drivers[itemButton] == "hide", "no navigation quest overrides Always and clears the action")
navQuest = 20; cfg.itemSize = 56; cfg.itemRetailArt = true
cfg.itemIconAlpha = 1
ns.RefreshQuestItem()
Check(itemButton.shown and itemButton.width == 56, "restored eligibility resumes the default native appearance")

-- EUI pages: searchable without real-frame work, tooltip coverage and stale locks.
local module, parent = spec.modules[1], CreateFrame("Frame")
local headerParent, hero, headerCalls, headerHeight = CreateFrame("Frame"), nil, 0, 0
headerParent.width = 700
EllesmereUI.SetContentHeader = function(_, builder)
    Check(not prebuild, "native header is never invoked in search prebuild")
    if hero then hero:Hide() end
    headerCalls = headerCalls + 1
    headerHeight = builder(headerParent, headerParent.width)
    for i = #frames, 1, -1 do
        if frames[i].parent == headerParent then hero = frames[i]; break end
    end
end
EllesmereUI.ClearContentHeader = function()
    Check(not prebuild, "native header clear is never invoked in search prebuild")
    if hero then hero:Hide() end
    headerHeight = 0
end
EllesmereUI.UpdateContentHeaderHeight = function(_, height) headerHeight = height end
local frameCount = #frames
prebuild = true
for _, page in ipairs(module.pages) do Check(module.buildPage(page, parent, 0) > 0, "search prebuild " .. page) end
Check(#frames == frameCount, "page prebuild has no frame/runtime side effects")
Check(headerCalls == 0, "search indexing does not build a hero")
prebuild = false
layoutRows = {}
module.buildPage("Quest Item", parent, 0)
local function HasLayout(section, left, right)
    for _, row in ipairs(layoutRows) do
        if row.section == section and row.left == left and row.right == right then return true end
    end
    return false
end
Check(HasLayout("APPEARANCE", "Retail style background", "Button size"),
    "appearance controls occupy aligned columns under Appearance")
Check(HasLayout("APPEARANCE", "Quest icon opacity", "Border thickness / size"),
    "opacity and border thickness align under Appearance")
Check(HasLayout("APPEARANCE", "Button border style", "Button border color"),
    "border style and color align under Appearance")
Check(HasLayout("PROXIMITY", "Quest proximity (yards)", nil),
    "quest distance control is under its own Proximity heading")
Check(hero and hero.parent == headerParent and hero.parent ~= parent, "sample is in pinned header outside scroll content")
Check(hero.sample.kind == "Frame" and not hero.sample.secure and hero.sample.mouseEnabled == false
    and next(hero.sample.attrs) == nil, "header sample cannot dispatch an item action")
Check(hero.sample ~= itemPreview and hero.sample ~= itemButton, "hero is independent of mover and gameplay button")
Check(hero.sample.icon.texture == "Interface\\Icons\\INV_Misc_QuestionMark", "hero always uses the fixed sample icon")
Check(module.getHeaderBuilder("Quest Item") == ns.BuildQuestItemHeader and module.getHeaderBuilder("General") == nil,
    "native cache knows which page owns the header")
widgets["Button size"].setValue(112)
Check(hero.sample.width == 112 and hero.sample.art.width == 512 and headerHeight == 336, "hero reserves maximum artwork height")
hero.width = 240; hero.scripts.OnSizeChanged(hero)
Check(hero.sample.scale < 1 and hero.sample.art.width * hero.sample.scale <= 192, "narrow header fits scaled artwork with margins")
hero.width = 700; hero.scripts.OnSizeChanged(hero)
widgets["Button border style"].setValue("solid")
widgets["Button border color"].setValue(0.2, 0.3, 0.4)
widgets["Border thickness / size"].setValue(3)
widgets["Quest icon opacity"].setValue(0.45)
Check(hero.sample.questItemBorder.testBorder.size == 3 and Near(hero.sample.questItemBorder.testBorder.g, 0.3),
    "hero shares live border renderer and settings")
Check(Near(hero.sample.icon.alpha, 0.45) and Near(hero.sample.art.alpha, 0.45)
    and Near(hero.sample.questItemBorder.alpha, 0.45), "hero shares icon artwork and border opacity")
widgets["Retail style background"].setValue(false)
Check(not hero.sample.art.shown and hero.sample.questItemBorder.shown, "hero artwork toggle is independent of border")
widgets["Button border style"].setValue("none")
Check(not hero.sample.questItemBorder.shown, "hero clears previous border when None selected")
navQuest = 0; playerDead = true; cfg.itemVisibility.visibility = "never"
ns.RefreshQuestItem()
Check(hero:IsVisible() and hero.sample:IsVisible() and not itemButton.shown,
    "hero remains available without quest and while dead with Never gameplay visibility")
cfg.questItem = false; ns.RefreshQuestItem()
Check(hero:IsVisible() and hero.sample:IsVisible(), "disabled quest-item feature keeps the appearance sample available")
local sampleSize = hero.sample.width
widgets["Button size"].setValue(24)
Check(hero.sample.width == sampleSize, "header does not bypass disabled appearance controls")
cfg.questItem = true
combat = true
local liveSize = itemButton.width
widgets["Button size"].setValue(80)
Check(hero.sample.width == 80 and itemButton.width == liveSize, "combat changes isolated header appearance without writing live geometry")
combat = false; playerDead = false; navQuest = 20; cfg.itemVisibility.visibility = "always"
widgets["Button size"].setValue(56)
widgets["Quest icon opacity"].setValue(1)
widgets["Retail style background"].setValue(true)
local cachedHero = hero
layoutRows = {}
module.buildPage("General", parent, 0)
Check(widgets["Enable extension"] == nil, "global Enable extension toggle is removed")
Check(HasLayout("WOWHEAD", "Wowhead URL menus", "Wowhead database"),
    "Wowhead controls share a row under their own heading")
Check(HasLayout("OBJECTIVE COLORS", "In-progress color", "Completed color"),
    "objective color pickers align under Objective Colors")
widgets["Wowhead URL menus"].setValue(false)
Check(not cfg.wowhead and widgets["Wowhead database"].disabled() and widgetRefreshCalls > 0,
    "disabling Wowhead URL menus locks its database selector")
widgets["Wowhead URL menus"].setValue(true)
layoutRows = {}
aboutTexts = {}
module.buildPage("About", parent, 0)
Check(#aboutTexts == 2 and aboutTexts[1]:find("Wowhead links", 1, true)
    and aboutTexts[2]:find("/eqtx status", 1, true),
    "About page renders visible wrapped feature and help paragraphs")
Check(not cachedHero:IsVisible() and headerHeight == 0, "leaving Quest Item removes the pinned preview")
cfg.itemSize = 100; ns.RefreshQuestItem()
Check(cachedHero.sample.width == 56 and headerHeight == 0, "hidden header cannot resize another page")
cachedHero:Show()
headerHeight = 208 -- EUI restores cached height after showing header children.
module.onPageCacheRestore("Quest Item")
Check(cachedHero.sample.width == 100 and headerHeight > 208, "cached header restores latest appearance and height")
headerParent:Hide(); cfg.itemSize = 90
ns.RefreshQuestItem()
Check(cachedHero.sample.width == 100, "closed options do not update hidden header")
headerParent:Show(); cachedHero.scripts.OnShow(cachedHero)
Check(cachedHero.sample.width == 90, "reopening settings refreshes the cached sample")
cfg.itemSize = 56; ns.RefreshQuestItem()
local savedHeaderAPI = EllesmereUI.SetContentHeader
EllesmereUI.SetContentHeader = nil
local calls = headerCalls
module.buildPage("Quest Item", parent, 0)
Check(headerCalls == calls and module.getHeaderBuilder("Quest Item") == nil, "missing native header API safely omits preview")
EllesmereUI.SetContentHeader = savedHeaderAPI
missingExtraArt = true
module.buildPage("Quest Item", parent, 0)
Check(not hero.sample.art.shown and hero.sample.icon.texture == "Interface\\Icons\\INV_Misc_QuestionMark",
    "header media fallback keeps sample icon")
missingExtraArt = false
module.buildPage("Quest Item", parent, 0)
Check(hero.sample.art.shown, "new header uses available Retail art")
local heightAPI = EllesmereUI.UpdateContentHeaderHeight
EllesmereUI.UpdateContentHeaderHeight = nil
module.buildPage("Quest Item", parent, 0)
Check(headerHeight == 336, "older EUI without resize API reserves full artwork height")
EllesmereUI.UpdateContentHeaderHeight = heightAPI
module.buildPage("Quest Item", parent, 0)
Check(widgets["Only in quest zone"] == nil, "removed zone control is absent from options")
for label, widget in pairs(widgets) do Check(type(widget.tooltip) == "string" and #widget.tooltip > 10, "tooltip: " .. label) end
cfg.questItem = false
widgets["Quest proximity (yards)"].setValue(250)
Check(cfg.itemProximityYards == 100, "stale proximity callback respects feature lock")
local beforeSize, beforeArt = cfg.itemSize, cfg.itemRetailArt
widgets["Button size"].setValue(95)
widgets["Retail style background"].setValue(not beforeArt)
Check(cfg.itemSize == beforeSize and cfg.itemRetailArt == beforeArt, "stale appearance controls respect the quest-item switch")
local visibilityControl = widgets.Visibility.control
local lockedVisibility = visibilityControl.getStore()
lockedVisibility.visibility = "never"
visibilityControl.setOption("visHideMounted", true)
visibilityControl.onChanged()
Check(cfg.itemVisibility.visibility == "always" and not cfg.itemVisibility.visHideMounted, "already-open native checklist writes only a detached store when locked")
cfg.questItem = true
widgets["Show tracked quest item"].setValue(false)
Check(widgets["Quest proximity (yards)"].disabled() and widgets["Button size"].disabled()
    and widgets["Button position"].disabled(),
    "quest-item dependent controls lock immediately when the feature is disabled")
widgets["Show tracked quest item"].setValue(true)
local originalColor, originalItem = cfg.progressColor.r, cfg.questItem
widgets["In-progress color"].setValue(0.1, 0.2, 0.3)
widgets["Show tracked quest item"].setValue(not originalItem)
Check(cfg.progressColor.r ~= originalColor and cfg.questItem ~= originalItem,
    "objective colors stay independent and the item toggle remains available")
cfg.questItem = originalItem
local originalStatusSound = cfg.statusSounds.accepted
cfg.sounds = false
widgets["Quest accepted sound"].setValue("tell")
Check(cfg.statusSounds.accepted == originalStatusSound and widgets["Quest accepted sound"].disabled(),
    "disabled notification sounds lock their status selector")
cfg.sounds = true
cfg.questItem = true; ns.RefreshQuestItem()
navDistance = 150
widgets["Quest proximity (yards)"].setValue(150)
Check(itemButton.shown and cfg.itemProximityYards == 150, "proximity slider immediately overrides default on live button")
ns.settings = nil; cfg = addon.Settings()
Check(cfg.itemProximityYards == 150 and addon.NearestQuestItem() ~= nil, "custom proximity survives saved-settings reload")
widgets["Quest proximity (yards)"].setValue(149)
Check(not itemButton.shown and itemButton.attrs.item1 == nil, "reducing proximity immediately hides and clears action")
widgets["Quest proximity (yards)"].setValue(secret)
Check(cfg.itemProximityYards == 149, "secret slider input rejected")
widgets["Quest proximity (yards)"].setValue(10000)
Check(cfg.itemProximityYards == 1000, "yard slider upper bound enforced")
widgets["Quest proximity (yards)"].setValue(-10)
Check(cfg.itemProximityYards == 1, "yard slider lower bound enforced")
navDistance = 25
widgets["Quest proximity (yards)"].setValue(100)
widgets["Button size"].setValue(1000)
Check(cfg.itemSize == 112, "size slider callback clamps oversized input")
cfg.itemBorderTexture = "solid"
widgets["Button border color"].setValue(-1, 2, 0.5)
Check(cfg.itemBorderColor.r == 0 and cfg.itemBorderColor.g == 1, "border picker clamps readable colors")
widgets["Border thickness / size"].setValue(12)
Check(cfg.itemBorderSize == 4, "border thickness callback clamps to EUI size steps")
widgets["Border thickness / size"].setValue(2.4)
Check(cfg.itemBorderSize == 2, "border sizes are integral EUI steps")
widgets["Quest icon opacity"].setValue(0.35)
Check(Near(itemButton.icon.alpha, 0.35) and Near(itemButton.art.alpha, 0.35)
    and Near(itemButton.questItemBorder.alpha, 0.35), "one opacity setting drives all three surfaces")
cfg.itemBorderTexture = "none"
local savedBorderColor = cfg.itemBorderColor.g
widgets["Button border color"].setValue(0.1, 0.1, 0.1)
Check(cfg.itemBorderColor.g == savedBorderColor, "open picker cannot recolor a disabled None border")
local objectiveAPI = C_QuestLog.GetQuestObjectives
C_QuestLog.GetQuestObjectives = nil
local originalObjectiveSound = cfg.statusSounds.objective
widgets["Objective completed sound"].setValue("tell")
Check(widgets["Objective completed sound"].disabled() and cfg.statusSounds.objective == originalObjectiveSound,
    "missing objective API gates status sound selector")
C_QuestLog.GetQuestObjectives = objectiveAPI
local failedAPI = C_QuestLog.IsFailed
C_QuestLog.IsFailed = nil
Check(widgets["Quest failed sound"].disabled(), "missing failure API clearly gates its sound selector")
C_QuestLog.IsFailed = failedAPI
local soundAPI = PlaySound
PlaySound = nil
Check(widgets["Notification sounds"].disabled(), "missing playback API gates sound control")
PlaySound = soundAPI
cfg.objectiveColors = false
local progressColorBeforeLockedEdit = cfg.progressColor.r
widgets["In-progress color"].setValue(0.1, 0.2, 0.3)
Check(cfg.progressColor.r == progressColorBeforeLockedEdit, "already-open picker honors color toggle lock")
combat = true
cfg.itemX = 321
widgets["Button position"].onClick()
Check(cfg.itemX == 321, "position callback honors combat lock")
combat = false
SlashCmdList.ELLESMEREUIEXTENDQUESTTRACKER("")
SlashCmdList.ELLESMEREUIEXTENDQUESTTRACKER(" status ")
Check(messages[#messages]:find("omitted", 1, true), "diagnostics explain unsupported features")

-- Malformed SavedVariables normalize cleanly; reset restores fresh defaults.
ns.settings = nil
EllesmereUIExtendQuestTrackerDB = { enabled = false, wowheadDatabase = "bad", sound = "bad", itemX = secret,
    itemProximityYards = secret, progressColor = { r = -4, g = 10, b = 0/0 }, statuses = { ready = false } }
cfg = addon.Settings()
Check(cfg.enabled == nil and cfg.wowheadDatabase == "auto" and cfg.sound == "ready",
    "removed global enable setting is ignored and remaining settings normalize")
Check(cfg.progressColor.r == 0 and cfg.progressColor.g == 1 and cfg.progressColor.b == ns.Defaults.progressColor.b, "saved color bounds and NaN normalization")
Check(cfg.itemX == 0 and cfg.statuses == nil and cfg.statusSounds.ready == "none"
    and cfg.statusSounds.accepted == "global", "old status opt-outs become None sound selections")
Check(cfg.itemProximityYards == 100, "unreadable saved proximity uses default")
addon.Reset(); Pump()
Check(addon.Settings().statusSounds.ready == "global" and addon.Settings().statusSounds.progress == "none"
    and not addon.Settings().questItem, "reset uses status sound choices as enable states")
Check(hero.sample.width == 56 and hero.sample.art.shown and Near(hero.sample.icon.alpha, 1),
    "reset restores header appearance even with gameplay feature off")
Check(nativeUpdates == 0 and trackingWrites == 0, "addon never invokes native layout or changes tracking")

-- Supported Forever behavior without a secret API; missing menu API is harmless.
issecretvalue = nil; EUI_CLIENT_FOREVER = true
Check(addon.WowheadURL("quest", 20):find("classic/quest=20", 1, true), "Forever without secret API URL")
Check(addon.NearestQuestItem().questID == navQuest, "Forever navigation identity and readable distance path")
cfg = addon.Settings(); cfg.questItem = true
OpenEdit()
Check(itemPreview.shown and itemButton.attrs.type1 == nil, "Forever edit preview works without a secret-value API")
CloseEdit("exit")
Check(itemButton.shown and itemButton.attrs.type1 == "item", "Forever exits edit mode back to a real secure item action")
cfg.questItem = false; addon.Refresh(); Pump()
local savedMenu = Menu; Menu = nil
ns.InitMenus()
Check(not addon.Capabilities().menus, "missing menu API gated")
Menu = savedMenu; EUI_CLIENT_FOREVER = nil
-- Separate namespace simulates a client where the secure template is absent.
local isolated = { Addon = addon }
setmetatable(isolated, { __index = ns })
assert(loadfile("QuestTracker/QuestItem.lua"))("EllesmereUIExtendQuestTracker", isolated)
cfg = addon.Settings(); cfg.questItem = true; failTemplate = true
local factoryAPI = EllesmereUI.MakeUnlockElement
EllesmereUI.MakeUnlockElement = nil
isolated.RefreshQuestItem()
Check(isolated.itemTemplateUnavailable == true, "unavailable secure template gated without error")
Check(tickers[#tickers].cancelled, "missing secure template stops its movement timer")
failTemplate = false
EllesmereUI.MakeUnlockElement = factoryAPI
EUI_CLIENT_BLOCKED = true
local blocked = {}
local previousAddon, previousFrames = EllesmereUIExtendQuestTracker, #frames
for _, file in ipairs(files) do assert(loadfile("QuestTracker/" .. file .. ".lua"))("EllesmereUIExtendQuestTracker", blocked) end
Check(next(blocked) == nil and EllesmereUIExtendQuestTracker == previousAddon and #frames == previousFrames, "blocked EUI client creates no runtime or settings")
EUI_CLIENT_BLOCKED = nil

print("PASS: " .. checks .. " QuestTracker settings, menus, restoration, notifications, secure items, UI locks and client-gate checks")
