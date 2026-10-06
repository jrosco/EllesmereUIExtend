local _, ns = ...
local addon = ns.Addon
if not addon then return end

local snapshots, titles, recent, removedTitles = {}, {}, {}, {}
local initialized = false
local lastSound = -math.huge
ns.SoundNames = {
    ready = "Quest ready", complete = "Quest completed", tell = "Whisper",
    raidWarning = "Raid warning", readyCheck = "Ready check", levelUp = "Level up",
    epicLoot = "Epic loot", lootOpen = "Loot window", battlegroundFinished = "Battleground finished",
    achievement = "Achievement", missionComplete = "Mission complete",
    peonYes3 = "Peon: Yes 3", peonBuildingComplete1 = "Peon: Building complete",
}
local soundKeys = {
    ready = "UI_AUTO_QUEST_COMPLETE", complete = "IG_QUEST_LIST_COMPLETE", tell = "TELL_MESSAGE",
    raidWarning = "RAID_WARNING", readyCheck = "READY_CHECK", levelUp = "LEVEL_UP",
    epicLoot = "UI_EPICLOOT_TOAST", lootOpen = "LOOT_WINDOW_OPEN",
    battlegroundFinished = "UI_BATTLEGROUND_COUNTDOWN_FINISHED", achievement = "ACHIEVEMENT_MENU_OPEN",
    missionComplete = "UI_GARRISON_MISSION_COMPLETE",
}
-- Game-data paths are not accepted by current PlaySoundFile; use FileDataIDs.
ns.SoundFileIDs = {
    peonYes3 = 558147,
    peonBuildingComplete1 = 558132,
}
ns.SoundChannels = { Master = "Master", SFX = "Sound effects", Music = "Music", Ambience = "Ambience", Dialog = "Dialog" }

function ns.StatusSupported(kind)
    if not ns.HasQuestLog() then return false end
    if kind == "progress" or kind == "objective" then return type(C_QuestLog.GetQuestObjectives) == "function" end
    if kind == "failed" then return type(C_QuestLog.IsFailed) == "function" end
    if kind == "ready" then
        return type(C_QuestLog.ReadyForTurnIn) == "function" or type(C_QuestLog.IsComplete) == "function"
    end
    if kind == "accepted" then return ns.RegisteredEvents.QUEST_ACCEPTED == true end
    if kind == "turnedIn" then return ns.RegisteredEvents.QUEST_TURNED_IN == true end
    return false
end

function ns.SoundID(key)
    key = ns.String(key)
    if not key then return nil end
    local kits = ns.Table(_G.SOUNDKIT)
    local name = soundKeys[key]
    return kits and name and ns.ID(kits[name])
end

function ns.SoundAvailable(key)
    return ns.SoundID(key) ~= nil or ns.ID(ns.SoundFileIDs[key]) ~= nil
end

local function PlaybackAccepted(ok, result)
    if not ok then return false end
    local readable = ns.Boolean(result)
    if readable ~= nil then return readable end
    return not ns.IsSecret(result) and result == nil
end

function ns.PlayNotificationSoundKey(key, channel)
    key = ns.String(key)
    if not key then return false end
    local kit = ns.SoundID(key)
    if kit and type(PlaySound) == "function" then
        local ok, played = pcall(PlaySound, kit, channel, true)
        if PlaybackAccepted(ok, played) then return true end
    end
    local fileDataID = ns.ID(ns.SoundFileIDs[key])
    if fileDataID and type(PlaySoundFile) == "function" then
        local ok, played = pcall(PlaySoundFile, fileDataID, channel)
        if PlaybackAccepted(ok, played) then return true end
    end
    return false
end

function ns.HasNotificationSounds()
    if type(PlaySound) ~= "function" and type(PlaySoundFile) ~= "function" then return false end
    for key in pairs(ns.SoundNames) do
        if ns.SoundAvailable(key) then return true end
    end
    return false
end

function ns.SoundKitOptions(includeNone, includeGlobal, selectedKey)
    local values, order = {}, {}
    if includeGlobal then values.global = "Use global sound"; order[#order + 1] = "global" end
    if includeNone then values.none = "None"; order[#order + 1] = "none" end
    for key, label in pairs(ns.SoundNames) do
        if ns.SoundAvailable(key) then
            values[key] = label
            order[#order + 1] = key
        end
    end
    table.sort(order, function(a, b)
        if a == b then return false end
        if a == "global" then return true end
        if b == "global" then return false end
        if a == "none" then return true end
        if b == "none" then return false end
        return ns.SoundNames[a] < ns.SoundNames[b]
    end)
    if selectedKey and selectedKey ~= "global" and selectedKey ~= "none" and not values[selectedKey]
        and ns.SoundNames[selectedKey] then
        values[selectedKey] = ns.SoundNames[selectedKey] .. " (unavailable)"
        local insertAt = 1
        while order[insertAt] == "global" or order[insertAt] == "none" do insertAt = insertAt + 1 end
        table.insert(order, insertAt, selectedKey)
    end
    return values, order
end

local lastSoundPreview = -math.huge
function ns.PreviewNotificationSound(key)
    if not ns.SoundAvailable(key) then return false end
    local now = ns.Number(ns.Call(GetTime))
    if not now or now - lastSoundPreview < 0.35 then return false end
    if ns.PlayNotificationSoundKey(key, addon.Settings().soundChannel) then
        lastSoundPreview = now
        return true
    end
    return false
end

function ns.PreviewEffectiveNotificationSound(kind)
    local key = ns.NotificationSoundKey(kind)
    local cfg = addon.Settings()
    if not key then return false end
    local now = ns.Number(ns.Call(GetTime))
    if not now or now - lastSoundPreview < 0.35 then return false end
    local played = ns.PlayNotificationSoundKey(key, cfg.soundChannel)
    if not played and key ~= cfg.sound and cfg.sound ~= "none" then
        played = ns.PlayNotificationSoundKey(cfg.sound, cfg.soundChannel)
    end
    if played then
        lastSoundPreview = now
        return true
    end
    return false
end

function ns.NotificationSoundKey(kind)
    local cfg = addon.Settings()
    local key = cfg.statusSounds[kind]
    if key == "none" then return nil end
    if key and key ~= "global" then
        if ns.SoundAvailable(key) then return key end
    end
    if cfg.sound ~= "none" and ns.SoundAvailable(cfg.sound) then return cfg.sound end
end

function ns.NotificationSoundID(kind)
    return ns.SoundID(ns.NotificationSoundKey(kind))
end

function ns.NotificationSoundAvailable(kind)
    return ns.NotificationSoundKey(kind) ~= nil
end

function ns.PlayStatusNotificationSound(kind)
    local cfg = addon.Settings()
    local individual = cfg.statusSounds[kind]
    if individual == "none" then return false end
    if individual and individual ~= "global" then
        if ns.PlayNotificationSoundKey(individual, cfg.soundChannel) then return true end
        if cfg.sound == "none" then return false end
        return ns.PlayNotificationSoundKey(cfg.sound, cfg.soundChannel)
    end
    if cfg.sound == "none" then return false end
    return ns.PlayNotificationSoundKey(cfg.sound, cfg.soundChannel)
end

local function Notify(kind, id, title, detail)
    local cfg = addon.Settings()
    if not ns.Active() or cfg.statusSounds[kind] == "none" or not ns.StatusSupported(kind) then return end
    title = ns.String(title)
    if not title or title == "" then return end
    local now = ns.Number(ns.Call(GetTime))
    if not now then return end
    -- Short-lived per-quest status memory. Progress details can
    -- change every loot tick: do not retain a key for each intermediate count.
    for questID, entry in pairs(recent) do
        if now - entry.time > 5 then recent[questID] = nil end
    end
    recent[id] = recent[id] or {}
    local previous = recent[id][kind]
    detail = ns.String(detail)
    if previous and previous.detail == detail and now - previous.time < 1 then return end
    recent[id].time = now
    recent[id][kind] = { time = now, detail = detail }
    if cfg.messages then
        ns.DeliverQuestNotification(kind, id, title, detail, now)
    end
    if cfg.sounds and now - lastSound >= 1 then
        if ns.PlayStatusNotificationSound(kind) then lastSound = now end
    end
end

local function ReadSnapshot(id)
    local ready
    if type(C_QuestLog.ReadyForTurnIn) == "function" then
        ready = ns.Boolean(ns.Call(C_QuestLog.ReadyForTurnIn, id))
    else
        ready = ns.Boolean(ns.Call(C_QuestLog.IsComplete, id))
    end
    local result = { ready = ready, failed = ns.Boolean(ns.Call(C_QuestLog.IsFailed, id)), objectives = {} }
    local objectives = ns.Table(ns.Call(C_QuestLog.GetQuestObjectives, id))
    if objectives then
        for index, objective in ipairs(objectives) do
            objective = ns.Table(objective)
            if objective then
                result.objectives[index] = { finished = ns.Boolean(objective.finished),
                    count = ns.Number(objective.numFulfilled), text = ns.String(objective.text) }
            end
        end
    end
    return result
end

function ns.ScanNotifications(silent)
    if not ns.HasQuestLog() then return end
    local cfg = addon.Settings()
    if not ns.Active() then initialized = false; return end
    local present = {}
    local scanned = ns.EachQuest(function(id, _, info)
        present[id] = true
        local title = ns.String(info.title) or ns.String(ns.Call(C_QuestLog.GetTitleForQuestID, id))
        if title then titles[id] = title end
        local current, old = ReadSnapshot(id), snapshots[id]
        if initialized and not silent and old then
            if old.failed == false and current.failed == true then
                Notify("failed", id, title)
            else
                if old.ready == false and current.ready == true then Notify("ready", id, title) end
                for index, objective in pairs(current.objectives) do
                    local previous = old.objectives[index]
                    if previous then
                        if previous.finished == false and objective.finished == true then
                            Notify("objective", id, title, objective.text)
                        elseif previous.count and objective.count and objective.count > previous.count then
                            Notify("progress", id, title, objective.text)
                        end
                    end
                end
            end
        end
        snapshots[id] = current
    end)
    if scanned then
        -- Forget log state for quests that disappeared. Turn-in titles have a
        -- separate short-lived cache populated by the removal/turn-in events.
        for id in pairs(snapshots) do
            if not present[id] then snapshots[id] = nil end
        end
        for id in pairs(titles) do
            if not present[id] then titles[id] = nil end
        end
        local now = ns.Number(ns.Call(GetTime))
        if now then
            for id, entry in pairs(recent) do
                if not entry.time or now - entry.time > 5 then recent[id] = nil end
            end
        end
        initialized = true
    end
end

function ns.RefreshNotifications()
    if ns.RefreshNotificationOutput then ns.RefreshNotificationOutput() end
    snapshots, titles, recent, removedTitles = {}, {}, {}, {}
    initialized = false
    lastSound = -math.huge
    ns.ScanNotifications(true)
end

function ns.NotificationEvent(event, id)
    if event == "PLAYER_ENTERING_WORLD" then
        -- A loading screen can encompass completed quest updates: seed silently.
        ns.RefreshNotifications()
        return
    end
    if event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" then
        id = ns.ID(id)
        if not id then return end
        local now = ns.Number(ns.Call(GetTime))
        if now then
            for questID, entry in pairs(removedTitles) do
                if now - entry.time > 5 then removedTitles[questID] = nil end
            end
        else
            removedTitles = {}
        end
        local title = titles[id] or (C_QuestLog and ns.String(ns.Call(C_QuestLog.GetTitleForQuestID, id)))
            or (removedTitles[id] and removedTitles[id].title)
        if event == "QUEST_ACCEPTED" then
            removedTitles[id] = nil
            Notify("accepted", id, title)
        elseif event == "QUEST_TURNED_IN" then
            Notify("turnedIn", id, title)
        end
        if event ~= "QUEST_ACCEPTED" then
            -- Some clients remove the log entry before QUEST_TURNED_IN. Keep a
            -- short-lived readable title, never infer a status from removal.
            if title and now then removedTitles[id] = { title = title, time = now } end
            snapshots[id], titles[id] = nil, nil
        end
    end
    if event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED"
        or event == "QUEST_TURNED_IN" or event == "QUEST_DATA_LOAD_RESULT" then
        ns.Queue("notifications", function() ns.ScanNotifications(false) end)
    end
end
