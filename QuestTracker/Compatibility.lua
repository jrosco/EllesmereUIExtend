local _, ns = ...
if EUI_CLIENT_BLOCKED then return end

function ns.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

function ns.Number(value)
    if ns.IsSecret(value) or type(value) ~= "number" then return nil end
    if value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

function ns.ID(value)
    value = ns.Number(value)
    if value and value > 0 and value <= 2147483647 and value == math.floor(value) then return value end
end

function ns.Boolean(value)
    if not ns.IsSecret(value) and type(value) == "boolean" then return value end
end

function ns.Table(value)
    if not ns.IsSecret(value) and type(value) == "table" then return value end
end

function ns.String(value)
    if not ns.IsSecret(value) and type(value) == "string" then return value end
end

-- A successful pcall does NOT make its results readable. Consumers validate them.
function ns.Call(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(func, ...)
    if ok then return a, b, c, d, e end
end

function ns.InCombat()
    if type(InCombatLockdown) ~= "function" then return true end
    local value = ns.Boolean(ns.Call(InCombatLockdown))
    return value ~= false
end

function ns.Forever()
    return EUI_CLIENT_FOREVER == true or (EllesmereUI and EllesmereUI.IS_FOREVER == true) or false
end

function ns.HasQuestLog()
    return C_QuestLog and type(C_QuestLog.GetNumQuestLogEntries) == "function"
        and type(C_QuestLog.GetInfo) == "function" or false
end

function ns.HasMenus()
    return Menu and type(Menu.ModifyMenu) == "function" or false
end

function ns.HasQuestItems()
    return ns.HasQuestLog() and type(C_QuestLog.GetQuestWatchType) == "function"
        and ns.HasQuestNavigation()
        and type(C_QuestLog.IsComplete) == "function"
        and type(GetQuestLogSpecialItemInfo) == "function"
        and C_Timer and type(C_Timer.NewTicker) == "function"
        and ((C_Item and type(C_Item.GetItemCount) == "function") or type(GetItemCount) == "function")
        or false
end

function ns.HasItemMover()
    return EllesmereUI and type(EllesmereUI.MakeUnlockElement) == "function"
        and type(EllesmereUI.RegisterUnlockElements) == "function"
        and type(EllesmereUI.RegisterUnlockModeListener) == "function"
        and type(EllesmereUI.IsUnlockModeActive) == "function" or false
end

function ns.HasQuestNavigation()
    return C_Navigation and type(C_Navigation.GetDistance) == "function"
        and C_SuperTrack and type(C_SuperTrack.GetSuperTrackedQuestID) == "function"
        and type(C_SuperTrack.IsSuperTrackingQuest) == "function" or false
end

function ns.HasItemBorders()
    return EllesmereUI and type(EllesmereUI.ApplyBorderStyle) == "function"
        and type(EllesmereUI.GetBorderTextureDropdown) == "function" or false
end

function ns.HasItemVisibility()
    return type(RegisterStateDriver) == "function" and type(UnregisterStateDriver) == "function"
        and EllesmereUI and type(EllesmereUI.GetActiveVisibilityModes) == "function"
        and type(EllesmereUI.GetVisibilitySelection) == "function"
        and type(EllesmereUI.BuildVisibilityDriverString) == "function"
        and type(EllesmereUI.BuildAnyMatchTail) == "function"
        and type(EllesmereUI.CheckVisibilityOptionsNonMacro) == "function"
        and type(EllesmereUI.VisWantsMouseover) == "function" or false
end

function ns.Clamp(value, low, high, fallback)
    value = ns.Number(value) or fallback
    return math.max(low, math.min(high, value))
end

function ns.Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do copy[key] = ns.Copy(child) end
    return copy
end

function ns.EachQuest(callback)
    if not ns.HasQuestLog() then return false end
    local count = ns.Number(ns.Call(C_QuestLog.GetNumQuestLogEntries))
    if not count or count < 0 or count > 10000 then return false end
    for index = 1, count do
        local info = ns.Table(ns.Call(C_QuestLog.GetInfo, index))
        if info and ns.Boolean(info.isHeader) == false then
            local id = ns.ID(info.questID)
            if id then callback(id, index, info) end
        end
    end
    return true
end

ns.TrackerNames = { "QuestObjectiveTracker", "CampaignQuestObjectiveTracker", "AchievementObjectiveTracker" }

function ns.HasObjectives()
    if type(hooksecurefunc) ~= "function" then return false end
    for _, name in ipairs(ns.TrackerNames) do
        local tracker = ns.Table(_G[name])
        if tracker and type(tracker.Update) == "function" then return true end
    end
    return false
end

function ns.EachBlock(callback)
    -- Never enumerate ScenarioObjectiveTracker or UIWidgetObjectiveTracker.
    for _, name in ipairs(ns.TrackerNames) do
        local tracker = ns.Table(_G[name])
        local templates = tracker and ns.Table(tracker.usedBlocks)
        if templates then
            for _, blocks in pairs(templates) do
                blocks = ns.Table(blocks)
                if blocks then
                    for _, block in pairs(blocks) do
                        block = ns.Table(block)
                        if block then callback(block, tracker) end
                    end
                end
            end
        end
    end
end
