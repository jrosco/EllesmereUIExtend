local _, ns = ...
local addon = ns.Addon
if not addon then return end

local snapshots, titles, recent, removedTitles = {}, {}, {}, {}
local initialized = false
local lastSound = -math.huge
ns.SoundNames = { ready = "Quest ready", complete = "Quest completed", tell = "Whisper" }
local soundKeys = { ready = "UI_AUTO_QUEST_COMPLETE", complete = "IG_QUEST_LIST_COMPLETE", tell = "TELL_MESSAGE" }
local labels = { accepted = "Accepted", progress = "Objective progress", objective = "Objective completed",
    ready = "Ready for turn-in", failed = "Failed", turnedIn = "Turned in" }

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
    local kits = ns.Table(_G.SOUNDKIT)
    local name = soundKeys[key]
    return kits and name and ns.ID(kits[name])
end

local function Notify(kind, id, title, detail)
    local cfg = addon.Settings()
    if not ns.Active() or not cfg.notifications or not cfg.statuses[kind] or not ns.StatusSupported(kind) then return end
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
        ns.Print(labels[kind] .. ": " .. title .. (detail and detail ~= "" and " — " .. detail or ""))
    end
    if cfg.sounds and now - lastSound >= 1 then
        local sound = ns.SoundID(cfg.sound)
        if sound and type(PlaySound) == "function" then
            pcall(PlaySound, sound, "Master")
            lastSound = now
        end
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
    if not ns.Active() or not cfg.notifications then initialized = false; return end
    local scanned = ns.EachQuest(function(id, _, info)
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
    if scanned then initialized = true end
end

function ns.RefreshNotifications()
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
