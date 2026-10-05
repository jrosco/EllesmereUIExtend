-- Run from the repository root. No upstream fixture or installed WoW is needed.
local unpack = table.unpack or unpack
local ns, frames, tickers, messages, sounds, menus, widgets = {}, {}, {}, {}, {}, {}, {}
local combat, now, failTemplate, prebuild, missingExtraArt = false, 100, false, false, false
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
    function frame:Show() Protected(self); self.shown = true end
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
    function frame:SetAlpha(value) self.alpha = value end
    function frame:SetColorTexture(...) self.colorTexture = { ... } end
    function frame:SetText(value) self.text = value end
    function frame:EnableMouse(value) self.mouseEnabled = value end
    function frame:SetCooldown(start, duration) self.cooldown = { start, duration } end
    function frame:Clear() self.cooldown = nil end
    function frame:StartMoving() Protected(self); self.moving = true end
    function frame:StopMovingOrSizing() Protected(self); self.moving = false end
    function frame:RegisterForClicks(...) self.clicks = { ... } end
    function frame:RegisterForDrag(...) self.drag = { ... } end
    function frame:GetWidth() return 700 end
    for _, method in ipairs({ "SetFrameStrata", "SetAllPoints", "SetFontObject",
        "SetAutoFocus", "SetNormalFontObject", "ClearFocus", "SetFocus", "HighlightText", "SetClampedToScreen",
        "SetMovable", "SetHighlightTexture" }) do frame[method] = Noop end
    return frame
end
UIParent = CreateFrame("Frame")
SlashCmdList, UISpecialFrames = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
SOUNDKIT = { UI_AUTO_QUEST_COMPLETE = 23404, IG_QUEST_LIST_COMPLETE = 878, TELL_MESSAGE = 3081 }
function PlaySound(id, channel) sounds[#sounds + 1] = { id, channel } end
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
Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5 } }
local playerMap, mapData, zonePOIs = 900, {}, nil
C_Map = {
    GetBestMapForUnit = function(unit) assert(unit == "player"); return playerMap end,
    GetMapInfo = function(id) return mapData[id] or { mapType = Enum.UIMapType.Zone, parentMapID = 0 } end,
}
C_QuestLog.GetQuestsOnMap = function(map)
    if zonePOIs then return zonePOIs end
    return { { questID = 10, mapID = map }, { questID = 20, mapID = map }, { questID = 30, mapID = map } }
end
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
EllesmereUI = {
    RegisterPlugin = function(id, value)
        Check(id == "EllesmereUIExtendQuestTracker", "plugin installed identity")
        pluginCalls = pluginCalls + 1; spec = value; return true
    end,
    OpenPlugin = function(id) Check(id == "EllesmereUIExtendQuestTracker", "slash opens own section") end,
    IsSearchPrebuild = function() return prebuild end,
    Widgets = {
        SectionHeader = function() return {}, 30 end,
        Toggle = function(_, _, label, _, getter, setter, tip)
            widgets[label] = { getValue = getter, setValue = setter, tooltip = tip }; return {}, 50
        end,
        DualRow = function(_, _, _, left, right)
            if left then widgets[left.text] = left end
            if right then widgets[right.text] = right end
            return {}, 50
        end,
    },
}
local files = { "Compatibility", "QuestTracker", "Wowhead", "Objectives", "Notifications", "ItemVisibility", "QuestItem", "Options" }
for _, file in ipairs(files) do assert(loadfile("QuestTracker/" .. file .. ".lua"))("EllesmereUIExtendQuestTracker", ns) end
local addon = EllesmereUIExtendQuestTracker
Check(pluginCalls == 1, "plugin registered once at load")
Check(_G.EllesmereUIExtendQuestTrackerDB == nil, "saved settings not initialized before addon load")
Event("ADDON_LOADED", "EllesmereUIExtendQuestTracker")
Event("PLAYER_LOGIN")
local cfg = addon.Settings()
Check(cfg.enabled and cfg.objectiveColors and cfg.notifications, "cosmetic/message defaults")
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
cfg.sounds, cfg.statuses.progress = true, true
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
cfg.notifications = false; addon.Refresh(); Pump()
Event("QUEST_ACCEPTED", 30)
Check(#messages == before, "disabled notifications do not emit")
cfg.notifications = true; addon.Refresh(); Pump()
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

-- Nearest tracked quest item: distance, bag ownership, completion and combat locks.
complete[10], complete[20], complete[30], failed[20] = false, false, false, false
Check(addon.NearestQuestItem().questID == 20, "nearest tracked quest, not first or nearer untracked quest")
distances[10] = 25
Check(addon.NearestQuestItem().questID == 10, "stable quest-ID tie break")
distances[10] = 100; counts[120] = 0
Check(addon.NearestQuestItem().questID == 10, "item must be in bags")
counts[120] = 1; distances[20] = secret
Check(addon.NearestQuestItem().questID == 10, "secret distance excluded")
distances[20] = 25; watches[20] = secret
Check(addon.NearestQuestItem().questID == 10, "secret tracking state excluded")
watches[20] = 1; continent[20] = false
Check(addon.NearestQuestItem().questID == 10, "off-continent distance excluded")
continent[20] = secret
Check(addon.NearestQuestItem().questID == 10, "secret continent flag excluded")
continent[20] = true; complete[20] = true
Check(addon.NearestQuestItem().questID == 10, "completed quest without show-item permission excluded")
complete[20] = false; specialLinks[2] = secret
Check(addon.NearestQuestItem().questID == 10, "secret item link not parsed")
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
C_QuestLog.GetDistanceSqToQuest = function() error("distance unavailable") end
Check(addon.NearestQuestItem() == nil, "throwing distances fail closed")
C_QuestLog.GetDistanceSqToQuest = nil
Check(not addon.Capabilities().questItem, "missing distance gates item feature")
C_QuestLog.GetDistanceSqToQuest = distanceAPI
local timerAPI = C_Timer.NewTicker; C_Timer.NewTicker = nil
Check(not addon.Capabilities().questItem, "missing movement timer gates item feature")
C_Timer.NewTicker = timerAPI
cfg.questItem = true; combat = true; addon.Refresh(); Pump()
Check(_G.EllesmereUIExtendQuestTrackerItem == nil, "combat login/enable defers secure button creation")
combat = false; Event("PLAYER_REGEN_ENABLED")
local itemButton = EllesmereUIExtendQuestTrackerItem
Check(itemButton.shown and itemButton.attrs.type1 == "item" and itemButton.attrs.item1 == "item:120", "secure nearest item action configured")
Check(itemButton.clicks[1] == "AnyDown" and itemButton.clicks[2] == "AnyUp", "both key-down preferences supported")
Check(itemButton.drag[1] == "RightButton", "right drag leaves left item action intact")
Check(itemButton.cooldown.cooldown[2] == 30, "quest item cooldown displayed")
Check(itemButton.width == 56 and itemButton.height == 56, "art fix preserves live button hit area")
Check(itemButton.art.width == 256 and itemButton.art.height == 128, "native extra-action artwork rectangle is not squeezed to a square")
Check(itemButton.icon.point[2] == -2 and itemButton.icon.point[3] == 2, "52px icon matches native art proportions")
local function NoAddedBorder(frame)
    for _, region in ipairs(frames) do
        if region.parent == frame and region.kind == "Texture" and region.colorTexture then return false end
    end
    return true
end
Check(NoAddedBorder(itemButton), "live item button has no added solid green outline")
combat = true; distances[10] = 1
Event("QUEST_LOG_UPDATE"); tickers[#tickers].callback()
Check(itemButton.attrs.item1 == "item:120", "combat never reassigns protected item")
cfg.questItem = false; addon.Refresh(); Pump()
Check(itemButton.shown, "combat disable parks protected visibility until regen")
combat = false; Event("PLAYER_REGEN_ENABLED")
Check(not itemButton.shown and itemButton.attrs.item1 == nil, "regen applies disable and clears item")
cfg.questItem = true; addon.Refresh(); Pump()
Check(itemButton.attrs.item1 == "item:110", "reenable rescans actual nearest item")
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
Check(mover.label == "Nearest Quest Item" and mover.group == "Extend Quest Tracker", "named EUI quest-item mover")
Check(mover.noResize and mover.noAnchorTo and mover.noAnchorTarget and mover.noSizeMatchTarget, "fixed mover cannot create secure anchor/size dependencies")
Check(addon.Capabilities().itemMover, "public mover API capability")
addon.Refresh(); addon.Refresh(); Pump()
Check(moverRegistrations == 1 and listenerRegistrations == 1, "stable element/listener registration is idempotent")
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
    Pump()
end
local function CloseEdit(action)
    unlockActive = false
    listener(false, action)
    Pump()
end
local securePoint = itemButton.point
counts[110], counts[120] = 0, 0
local timerCount = #tickers
OpenEdit()
Check(itemPreview.shown and not itemButton.shown, "edit mode shows preview without an eligible quest item")
Check(itemButton.attrs.item1 == nil and itemButton.attrs.type1 == nil, "edit mode disables the live secure action")
Check(#tickers == timerCount and tickers[#tickers].cancelled, "editing stops nearest-item polling")
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
cfg.enabled = false; addon.Refresh(); Pump()
Check(mover.isHidden() and mover.getFrame() == nil and not itemPreview.shown, "disabling extension hides an already-open mover/preview")
mover.savePosition(moverKey, "CENTER", "CENTER", 777, 888)
mover.clearPosition()
Check(cfg.itemX == 321 and cfg.itemY == -88, "already-open mover callbacks respect feature locks")
cfg.enabled = true; addon.Refresh(); Pump()
Check(not mover.isHidden() and itemPreview.shown, "reenabling restores edit preview without a duplicate listener")
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

-- Strict zone selection: explicit player maps, micro-map ancestry, unknowns.
local normalZoneAPI = C_QuestLog.GetQuestsOnMap
distances[10], distances[20] = 1, 25
zonePOIs = { { questID = 20, mapID = 900 }, { questID = 10, mapID = 901 } }
Check(addon.NearestQuestItem().questID == 20, "nearest eligible current-zone quest wins over closer neighbouring-zone quest")
mapData[902] = { mapType = Enum.UIMapType.Micro, parentMapID = 900 }
playerMap = 902
zonePOIs = { { questID = 10, mapID = 902 } }
Check(addon.NearestQuestItem().questID == 10, "readable micro-map objectives resolve to current zone")
playerMap = 903; mapData[903] = { mapType = Enum.UIMapType.Continent, parentMapID = 0 }
Check(addon.NearestQuestItem() == nil, "continent map does not masquerade as a quest zone")
playerMap = secret
Check(addon.NearestQuestItem() == nil, "secret player map fails closed")
playerMap = 900; zonePOIs = { { questID = secret, mapID = 900 }, { questID = 10, mapID = secret } }
Check(addon.NearestQuestItem() == nil, "unreadable POI identities are not indexed or guessed")
zonePOIs = { { questID = 10, mapID = secret }, { questID = 20, mapID = 900 } }
Check(addon.NearestQuestItem().questID == 20, "unreadable candidates do not suppress other positively confirmed zone quests")
mapData[900] = { mapType = secret }
Check(addon.NearestQuestItem() == nil, "unreadable map kind fails closed before comparisons")
mapData[900] = nil
C_QuestLog.GetQuestsOnMap = function() error("map POIs restricted") end
Check(addon.NearestQuestItem() == nil, "throwing POI getter hides zone-restricted item")
cfg.itemZoneOnly = false
Check(addon.NearestQuestItem().questID == 10, "disabled zone filter does not query missing zone data")
cfg.itemZoneOnly = true; C_QuestLog.GetQuestsOnMap = normalZoneAPI
playerMap = 904; mapData[904] = { mapType = Enum.UIMapType.Micro, parentMapID = 904 }
Check(addon.NearestQuestItem() == nil, "cyclic map parents fail closed")
playerMap = 900; zonePOIs = nil

-- Public border renderer and native visibility driver doubles. The real EUI
-- compiler itself is exercised separately by tests/visibility.lua.
EllesmereUI.GetBorderTextureDropdown = function() return { solid = "Solid", blizzard = "Blizzard" }, { "solid", "blizzard" } end
EllesmereUI.ApplyBorderStyle = function(host, size, r, g, b, a, texture, _, _, _, _, surface)
    Check(not combat, "border rendering is out-of-combat only")
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
Check(Near(itemButton.icon.alpha, 0.4) and Near(itemButton.art.alpha, 0.4), "live icon and background follow opacity setting")
Check(Near(itemButton.questItemBorder.alpha, 0.4), "live border follows opacity setting")
OpenEdit(); ns.RefreshQuestItem()
Check(Near(itemPreview.icon.alpha, 0.4) and Near(itemPreview.art.alpha, 0.4), "preview icon and background follow opacity setting")
Check(Near(itemPreview.questItemBorder.alpha, 0.4), "preview border follows opacity setting")
CloseEdit("save")
Check(itemButton.width == 84 and itemButton.art.shown and not itemButton.questItemBorder.shown, "closing editor applies latest look to the live action")
cfg.itemVisibility.visibility = "in_combat"; ns.RefreshQuestItem()
Check(not itemButton.shown and drivers[itemButton]:find("[combat] show", 1, true), "in-combat visibility installs a native driver instead of an addon event Show")
local writesBeforeCombat = driverWrites
combat = true; NativeResolve(itemButton, drivers[itemButton]); Event("PLAYER_REGEN_DISABLED")
Check(itemButton.shown, "native combat visibility can show the secure button during lockdown")
cfg.itemSize, cfg.itemRetailArt = 112, false
zonePOIs = { { questID = 20, mapID = 900 } }
Event("ZONE_CHANGED_NEW_AREA"); ns.RefreshQuestItem()
Check(driverWrites == writesBeforeCombat and itemButton.width == 84 and itemButton.attrs.item1 == "item:110", "combat defers appearance, zone selection and driver rewrites")
combat = false; NativeResolve(itemButton, drivers[itemButton]); Event("PLAYER_REGEN_ENABLED")
Check(itemButton.width == 112 and not itemButton.art.shown and itemButton.attrs.item1 == "item:120", "regen applies latest appearance and nearest eligible zone item")
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
cfg.itemVisibility.visibility = "always"; zonePOIs = {}
ns.RefreshQuestItem()
Check(not itemButton.shown and itemButton.attrs.item1 == nil and drivers[itemButton] == "hide", "no zone candidate overrides Always and clears the action")
zonePOIs = nil; cfg.itemSize = 56; cfg.itemRetailArt = true
cfg.itemIconAlpha = 1
ns.RefreshQuestItem()
Check(itemButton.shown and itemButton.width == 56, "restored eligibility resumes the default native appearance")

-- EUI pages: searchable without real-frame work, tooltip coverage and stale locks.
local module, parent = spec.modules[1], CreateFrame("Frame")
local frameCount = #frames
prebuild = true
for _, page in ipairs(module.pages) do Check(module.buildPage(page, parent, 0) > 0, "search prebuild " .. page) end
Check(#frames == frameCount, "page prebuild has no frame/runtime side effects")
prebuild = false
module.buildPage("Quest Item", parent, 0)
for label, widget in pairs(widgets) do Check(type(widget.tooltip) == "string" and #widget.tooltip > 10, "tooltip: " .. label) end
cfg.enabled = false
local beforeSize, beforeArt = cfg.itemSize, cfg.itemRetailArt
widgets["Button size"].setValue(95)
widgets["Retail style background"].setValue(not beforeArt)
Check(cfg.itemSize == beforeSize and cfg.itemRetailArt == beforeArt, "stale appearance controls respect the master lock")
local visibilityControl = widgets.Visibility.control
local lockedVisibility = visibilityControl.getStore()
lockedVisibility.visibility = "never"
visibilityControl.setOption("visHideMounted", true)
visibilityControl.onChanged()
Check(cfg.itemVisibility.visibility == "always" and not cfg.itemVisibility.visHideMounted, "already-open native checklist writes only a detached store when locked")
local originalColor, originalItem = cfg.progressColor.r, cfg.questItem
widgets["In-progress color"].setValue(0.1, 0.2, 0.3)
widgets["Show nearest quest item"].setValue(not originalItem)
Check(cfg.progressColor.r == originalColor and cfg.questItem == originalItem, "already-open color/item controls honor master lock")
local originalStatus = cfg.statuses.accepted
widgets["Quest accepted"].setValue(not originalStatus)
Check(cfg.statuses.accepted == originalStatus, "already-open status toggle honors lock")
cfg.enabled = true
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
Check(Near(cfg.itemIconAlpha, 0.35) and Near(cfg.itemBorderAlpha, 0.35), "opacity slider stores readable alpha for icon and border")
cfg.itemBorderTexture = "none"
local savedBorderColor = cfg.itemBorderColor.g
widgets["Button border color"].setValue(0.1, 0.1, 0.1)
Check(cfg.itemBorderColor.g == savedBorderColor, "open picker cannot recolor a disabled None border")
local zoneMapAPI = C_Map.GetBestMapForUnit
C_Map.GetBestMapForUnit = nil
widgets["Only in quest zone"].setValue(false)
Check(not cfg.itemZoneOnly and addon.NearestQuestItem() ~= nil, "missing zone API still allows disabling a saved strict zone filter")
widgets["Only in quest zone"].setValue(true)
Check(not cfg.itemZoneOnly, "missing zone API prevents enabling a filter it cannot evaluate")
C_Map.GetBestMapForUnit = zoneMapAPI; cfg.itemZoneOnly = true
local objectiveAPI = C_QuestLog.GetQuestObjectives
C_QuestLog.GetQuestObjectives = nil
local originalObjectiveStatus = cfg.statuses.objective
widgets["Objective completed"].setValue(not originalObjectiveStatus)
Check(widgets["Objective completed"].disabled() and cfg.statuses.objective == originalObjectiveStatus, "missing objective API gates stale notification control")
C_QuestLog.GetQuestObjectives = objectiveAPI
local failedAPI = C_QuestLog.IsFailed
C_QuestLog.IsFailed = nil
Check(widgets["Quest failed"].disabled(), "missing failure API clearly gates its control")
C_QuestLog.IsFailed = failedAPI
local soundAPI = PlaySound
PlaySound = nil
Check(widgets["Notification sounds"].disabled(), "missing playback API gates sound control")
PlaySound = soundAPI
cfg.objectiveColors = false
widgets["In-progress color"].setValue(0.1, 0.2, 0.3)
Check(cfg.progressColor.r == originalColor, "already-open picker honors color toggle lock")
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
EllesmereUIExtendQuestTrackerDB = { enabled = "yes", wowheadDatabase = "bad", sound = "bad", itemX = secret,
    progressColor = { r = -4, g = 10, b = 0/0 }, statuses = { ready = false } }
cfg = addon.Settings()
Check(cfg.enabled and cfg.wowheadDatabase == "auto" and cfg.sound == "ready", "malformed settings normalized")
Check(cfg.progressColor.r == 0 and cfg.progressColor.g == 1 and cfg.progressColor.b == ns.Defaults.progressColor.b, "saved color bounds and NaN normalization")
Check(cfg.itemX == 0 and not cfg.statuses.ready and cfg.statuses.accepted, "secret setting fallback and explicit false preserved")
addon.Reset(); Pump()
Check(addon.Settings().statuses.ready and not addon.Settings().questItem, "reset fresh defaults")
Check(nativeUpdates == 0 and trackingWrites == 0, "addon never invokes native layout or changes tracking")

-- Supported Forever behavior without a secret API; missing menu API is harmless.
issecretvalue = nil; EUI_CLIENT_FOREVER = true
Check(addon.WowheadURL("quest", 20):find("classic/quest=20", 1, true), "Forever without secret API URL")
Check(addon.NearestQuestItem().questID == 10, "Forever readable distance path")
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
