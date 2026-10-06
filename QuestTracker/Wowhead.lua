local _, ns = ...
local addon = ns.Addon
if not addon then return end

function addon.WowheadURL(kind, id)
    id = ns.ID(id)
    if not id or (kind ~= "quest" and kind ~= "achievement") then return nil end
    local database = addon.Settings().wowheadDatabase
    if database == "auto" then database = ns.Forever() and "classic" or "retail" end
    return "https://www.wowhead.com/" .. (database == "classic" and "classic/" or "")
        .. kind .. "=" .. string.format("%.0f", id)
end

local popup
function addon.ShowURL(kind, id)
    if not ns.Active() or not addon.Settings().wowhead then return end
    local url = addon.WowheadURL(kind, id)
    if not url then return end
    if not popup then
        popup = CreateFrame("Frame", "EllesmereUIExtendQuestTrackerURL", UIParent)
        popup:SetSize(490, 140)
        popup:SetPoint("CENTER")
        popup:SetFrameStrata("DIALOG")
        popup:EnableMouse(true)
        local bg = popup:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.035, 0.035, 0.035, 0.98)
        local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -14)
        title:SetText("Wowhead URL")
        local hint = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        hint:SetPoint("TOP", 0, -38)
        hint:SetText("Press Ctrl+C to copy, then paste into your browser.")
        local edit = CreateFrame("EditBox", nil, popup)
        edit:SetSize(450, 28)
        edit:SetPoint("TOP", 0, -62)
        edit:SetFontObject("GameFontHighlight")
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() popup:Hide() end)
        edit:SetScript("OnEnterPressed", function() popup:Hide() end)
        popup.edit = edit
        local close = CreateFrame("Button", nil, popup)
        close:SetSize(100, 24)
        close:SetPoint("BOTTOM", 0, 8)
        close:SetNormalFontObject("GameFontNormal")
        close:SetText("Close")
        close:SetScript("OnClick", function() popup:Hide() end)
        popup:SetScript("OnHide", function() edit:ClearFocus() end)
        if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "EllesmereUIExtendQuestTrackerURL") end
    end
    popup.edit:SetText(url)
    popup:Show()
    popup.edit:SetFocus()
    popup.edit:HighlightText()
end

-- The native quest-tracker menu supplies its container, NOT the quest block.
-- Resolve only the currently hovered ordinary quest header. No title matching,
-- stale "last quest", native click forwarding, or OnClick replacement is used.
function ns.TrackerMenuQuestID()
    local foci = ns.Table(ns.Call(GetMouseFoci))
    if not foci then return nil end
    for _, focus in ipairs(foci) do
        local frame = ns.Table(focus)
        for _ = 1, 4 do
            if not frame then break end
            local parent = ns.Table(ns.Call(frame.GetParent, frame))
            local module = parent and ns.Table(parent.parentModule)
            if parent and module and ns.Table(parent.HeaderButton) == frame
                and (module == _G.QuestObjectiveTracker or module == _G.CampaignQuestObjectiveTracker) then
                return ns.ID(parent.id)
            end
            frame = parent
        end
    end
end

local registered = {}
function ns.InitMenus()
    if popup and (not ns.Active() or not addon.Settings().wowhead) then popup:Hide() end
    if not ns.HasMenus() then return end
    local menus = {
        MENU_QUEST_MAP_LOG_TITLE = function(owner) return "quest", ns.ID(ns.Table(owner) and owner.questID) end,
        MENU_QUEST_OBJECTIVE_TRACKER = function(_, context)
            if ns.IsSecret(context) then return "quest", nil end
            if context ~= nil then return "quest", ns.ID(ns.Table(context) and context.id) end
            return "quest", ns.TrackerMenuQuestID()
        end,
        MENU_ACHIEVEMENT_TRACKER = function(_, context)
            return "achievement", ns.ID(ns.Table(context) and context.id)
        end,
    }
    for tag, resolve in pairs(menus) do
        if not registered[tag] then
            local ok = pcall(Menu.ModifyMenu, tag, function(owner, description, context)
                if not ns.Active() or not addon.Settings().wowhead then return end
                local kind, id = resolve(owner, context)
                if not id then return end
                description:CreateButton("Wowhead URL", function() addon.ShowURL(kind, id) end)
            end)
            if ok then registered[tag] = true end
        end
    end
end
