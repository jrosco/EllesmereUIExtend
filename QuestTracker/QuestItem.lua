local addonName, ns = ...
local addon = ns.Addon
if not addon then return end

local button, current, ticker
local preview, editing, editSnapshot, moverElement, moverRegistered, moverHidden
local MOVER_KEY = "EQTX_QuestItem"
local SIZE = 56
local hovered, visibilityRegistered = false, false

function ns.ItemSize()
    return math.floor(ns.Clamp(addon.Settings().itemSize, 24, 112, SIZE) + 0.5)
end

function ns.ItemBorderOptions()
    local values, order = { none = "None" }, { "none" }
    if ns.HasItemBorders() then
        local nativeValues, nativeOrder = ns.Call(EllesmereUI.GetBorderTextureDropdown)
        nativeValues, nativeOrder = ns.Table(nativeValues), ns.Table(nativeOrder)
        if nativeValues and nativeOrder then
            for _, key in ipairs(nativeOrder) do
                key = ns.String(key)
                local label = key and ns.String(nativeValues[key])
                if label and not values[key] then values[key] = label; order[#order + 1] = key end
            end
        end
    end
    local saved = addon.Settings().itemBorderTexture
    if not values[saved] then values[saved] = saved .. " (unavailable)"; order[#order + 1] = saved end
    return values, order
end

local function Enabled()
    return ns.Active() and addon.Settings().questItem and ns.HasQuestItems() and not ns.itemTemplateUnavailable
end

local function SavedPosition()
    local cfg = addon.Settings()
    return { point = "CENTER", relPoint = "CENTER", x = cfg.itemX, y = cfg.itemY }
end

local function Place(frame)
    if not frame or ns.InCombat() then return end
    local pos = SavedPosition()
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

local function Artwork(frame)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    -- Blizzard's 52px extra-action icon uses a 256x128 style texture. Preserve
    -- that authored rectangle: a square squeezes its opening around the icon.
    -- Our 56px hit/mover frame leaves a 52px icon, without an added color border.
    frame.art = frame:CreateTexture(nil, "OVERLAY")
    frame.art:SetPoint("CENTER")
    frame.questItemArtLoaded = ns.Boolean(ns.Call(frame.art.SetTexture, frame.art, "Interface\\ExtraButton\\Default")) == true
end

local function Style(frame)
    if not frame or ns.InCombat() then return end
    local cfg = addon.Settings()
    local size, borderSize, color = ns.ItemSize(), cfg.itemBorderSize, cfg.itemBorderColor
    local signature = table.concat({ size, tostring(cfg.itemRetailArt), cfg.itemBorderTexture, borderSize,
        color.r, color.g, color.b, tostring(ns.HasItemBorders()) }, ":")
    if frame.questItemLook == signature then return end
    local ratio = size / SIZE
    frame:SetSize(size, size)
    frame.icon:ClearAllPoints()
    frame.icon:SetPoint("TOPLEFT", 2 * ratio, -2 * ratio)
    frame.icon:SetPoint("BOTTOMRIGHT", -2 * ratio, 2 * ratio)
    frame.art:SetSize(256 * ratio, 128 * ratio)
    if cfg.itemRetailArt and frame.questItemArtLoaded then frame.art:Show() else frame.art:Hide() end
    if frame.icon and frame.icon.SetAlpha then frame.icon:SetAlpha(cfg.itemIconAlpha or 1) end
    if frame.art and frame.art.SetAlpha then frame.art:SetAlpha(cfg.itemIconAlpha or 1) end
    if cfg.itemBorderTexture ~= "none" and ns.HasItemBorders() then
        if not frame.questItemBorder then
            frame.questItemBorder = CreateFrame("Frame", nil, frame)
            frame.questItemBorder:EnableMouse(false)
            frame.questItemBorder:SetPoint("CENTER", frame, "CENTER")
        end
        local host = frame.questItemBorder
        host:SetSize(52 * ratio, 52 * ratio)
        if host.SetAlpha then host:SetAlpha(cfg.itemBorderAlpha or 1) end
        ns.Call(EllesmereUI.ApplyBorderStyle, host, borderSize, color.r, color.g, color.b, 1,
            cfg.itemBorderTexture, nil, nil, nil, nil, "actionbars", borderSize)
    elseif frame.questItemBorder then
        if ns.HasItemBorders() then ns.Call(EllesmereUI.ApplyBorderStyle, frame.questItemBorder, 0) end
        frame.questItemBorder:Hide()
    end
    frame.questItemLook = signature
end

local function RefreshVisuals(frame)
    if not frame then return end
    local cfg = addon.Settings()
    if frame.icon and frame.icon.SetAlpha then frame.icon:SetAlpha(cfg.itemIconAlpha or 1) end
    if frame.art then
        if cfg.itemRetailArt and frame.questItemArtLoaded then
            frame.art:Show()
            if frame.art.SetAlpha then frame.art:SetAlpha(cfg.itemIconAlpha or 1) end
        else
            frame.art:Hide()
        end
    end
    if frame.questItemBorder and frame.questItemBorder.SetAlpha then
        frame.questItemBorder:SetAlpha(cfg.itemBorderAlpha or 1)
    end
end

local function CreatePreview()
    if preview or ns.InCombat() then return preview end
    -- Not a secure button, not its parent or anchor target. EUI can safely
    -- measure/move this frame; it cannot dispatch an item action.
    preview = CreateFrame("Frame", "EllesmereUIExtendQuestTrackerItemPreview", UIParent)
    preview:Hide()
    preview:EnableMouse(false)
    Artwork(preview)
    Style(preview)
    preview.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    RefreshVisuals(preview)
    Place(preview)
    return preview
end

function addon.NearestQuestItem()
    if not ns.HasQuestItems() then return nil end
    local onlyZone = addon.Settings().itemZoneOnly
    local zoneQuests = onlyZone and ns.CurrentZoneQuests()
    if onlyZone and not zoneQuests then return nil end
    local closest
    ns.EachQuest(function(id, index)
        if onlyZone and not zoneQuests[id] then return end
        local watch = ns.Number(ns.Call(C_QuestLog.GetQuestWatchType, id))
        if watch == nil then return end
        local complete = ns.Boolean(ns.Call(C_QuestLog.IsComplete, id))
        if complete == nil then return end
        local link, icon, _, showWhenComplete = ns.Call(GetQuestLogSpecialItemInfo, index)
        link = ns.String(link)
        if not link or (complete and ns.Boolean(showWhenComplete) ~= true) then return end
        local itemID = ns.ID(tonumber(link:match("item:(%d+)")))
        if not itemID then return end
        local countFunc = C_Item and C_Item.GetItemCount or GetItemCount
        local count = ns.Number(ns.Call(countFunc, itemID, false))
        if not count or count <= 0 then return end
        local distance, sameContinent = ns.Call(C_QuestLog.GetDistanceSqToQuest, id)
        distance = ns.Number(distance)
        if not distance or distance < 0 or ns.Boolean(sameContinent) ~= true then return end
        if not closest or distance < closest.distance or (distance == closest.distance and id < closest.questID) then
            closest = { questID = id, index = index, itemID = itemID, icon = ns.Number(icon) or ns.String(icon), distance = distance }
        end
    end)
    return closest
end

local function Position()
    -- Never overwrite EUI's in-progress preview position during a refresh.
    if editing then return end
    Place(button)
    Place(preview)
end

local function CreateButton()
    if button or ns.InCombat() or ns.itemTemplateUnavailable then return button end
    local ok, frame = pcall(CreateFrame, "Button", "EllesmereUIExtendQuestTrackerItem", UIParent, "SecureActionButtonTemplate")
    if not ok or not frame then ns.itemTemplateUnavailable = true; return nil end
    button = frame
    button:Hide()
    Artwork(button)
    Style(button)
    button:SetMovable(true)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:RegisterForDrag("RightButton")
    button:SetAttribute("type1", "item")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local cooldownOK, cooldown = pcall(CreateFrame, "Cooldown", nil, button, "CooldownFrameTemplate")
    if cooldownOK then
        button.cooldown = cooldown
        cooldown:SetAllPoints(button.icon)
    end
    button:SetScript("OnDragStart", function(self)
        if not ns.InCombat() and not editing and not (moverRegistered and ns.HasItemMover()) then self:StartMoving() end
    end)
    button:SetScript("OnDragStop", function(self)
        if ns.InCombat() then return end
        self:StopMovingOrSizing()
        if editing or (moverRegistered and ns.HasItemMover()) then Position(); return end
        local x, y = ns.Call(self.GetCenter, self)
        local px, py = ns.Call(UIParent.GetCenter, UIParent)
        x, y, px, py = ns.Number(x), ns.Number(y), ns.Number(px), ns.Number(py)
        if x and y and px and py then
            addon.Settings().itemX, addon.Settings().itemY = x - px, y - py
        end
        Position()
    end)
    button:SetScript("OnEnter", function(self)
        hovered = true
        ns.ItemVisibilityAlpha(self, hovered)
        if not current or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(current.itemID) end
        local title = C_QuestLog and ns.String(ns.Call(C_QuestLog.GetTitleForQuestID, current.questID))
        if title and GameTooltip.AddLine then GameTooltip:AddLine(title, 1, 0.82, 0.25) end
        if GameTooltip.AddLine then
            GameTooltip:AddLine(moverRegistered and ns.HasItemMover() and "Move with EUI Edit Mode."
                or "Right-drag to move out of combat.", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        hovered = false
        ns.ItemVisibilityAlpha(self, hovered)
        if GameTooltip then GameTooltip:Hide() end
    end)
    button:SetScript("OnHide", function() hovered = false; if GameTooltip then GameTooltip:Hide() end end)
    Position()
    return button
end

local function Cooldown()
    if editing then return end
    if not button or not button.cooldown then return end
    local index = current and C_QuestLog and ns.ID(ns.Call(C_QuestLog.GetLogIndexForQuestID, current.questID))
    local start, duration, enable
    if index then start, duration, enable = ns.Call(GetQuestLogSpecialItemCooldown, index) end
    start, duration, enable = ns.Number(start), ns.Number(duration), ns.Number(enable)
    if start and duration and enable and duration > 0 and enable > 0 then
        pcall(button.cooldown.SetCooldown, button.cooldown, start, duration)
    elseif button.cooldown.Clear then
        pcall(button.cooldown.Clear, button.cooldown)
    end
end

function ns.UpdateQuestItem()
    -- Includes Show/Hide, anchors and attributes, not just candidate selection.
    if ns.InCombat() then
        if preview then preview:Hide() end
        ns.ItemVisibilityAlpha(button, hovered)
        return
    end
    local enabled = Enabled()
    if editing then
        if button then
            button:StopMovingOrSizing()
            button:SetAttribute("item1", nil)
            button:SetAttribute("type1", nil)
            ns.ApplyItemVisibility(button, false, false)
        end
        current = nil
        if enabled then
            local p = CreatePreview()
            Style(p)
            RefreshVisuals(p)
            p:Show()
        elseif preview then preview:Hide() end
        return
    end
    if preview then preview:Hide() end
    if not enabled then
        current = nil
        if button then button:SetAttribute("item1", nil); ns.ApplyItemVisibility(button, false, false) end
        return
    end
    local found = addon.NearestQuestItem()
    if not found then
        current = nil
        if button then button:SetAttribute("item1", nil); ns.ApplyItemVisibility(button, false, false) end
        return
    end
    if not CreateButton() then
        if ns.itemTemplateUnavailable and ticker then ticker:Cancel(); ticker = nil end
        return
    end
    if not current or found.itemID ~= current.itemID then
        button:SetAttribute("item1", "item:" .. string.format("%.0f", found.itemID))
    end
    current = found
    Style(button)
    RefreshVisuals(button)
    button:SetAttribute("type1", "item")
    button.icon:SetTexture(found.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    ns.ApplyItemVisibility(button, true, hovered)
    Cooldown()
end

local function BeginEdit()
    if editing then return end
    editSnapshot = SavedPosition()
    editing = true
    if ticker then ticker:Cancel(); ticker = nil end
    if preview then Place(preview) end
end

local function UnlockChanged(active, closeAction)
    active = ns.Boolean(active)
    if active == nil then return end
    if active then
        BeginEdit()
    elseif editing then
        -- EUI normally reverts first. Our snapshot also covers registration
        -- midway through a session, before EUI has a snapshot for this key.
        if ns.String(closeAction) ~= "save" and editSnapshot then
            local cfg = addon.Settings()
            cfg.itemX, cfg.itemY = editSnapshot.x, editSnapshot.y
        end
        editing, editSnapshot = false, nil
        if preview then preview:Hide() end
    end
    ns.RefreshQuestItem()
end

function ns.RegisterQuestItemMover()
    if not ns.HasItemMover() or ns.InCombat() then return end
    local hidden = not Enabled()
    if moverRegistered then
        -- Refresh an already-open mover's visibility when the feature changes.
        if moverHidden ~= hidden then
            local ok = pcall(EllesmereUI.RegisterUnlockElements, EllesmereUI, { moverElement }, addonName)
            if ok then moverHidden = hidden end
        end
        return
    end
    local active = ns.Boolean(ns.Call(EllesmereUI.IsUnlockModeActive, EllesmereUI))
    if active == nil then return end
    if active then BeginEdit() end
    local opts = {
        key = MOVER_KEY, label = "Nearest Quest Item", group = "Extend Quest Tracker", order = 950,
        noResize = true, noAnchorTo = true, noAnchorTarget = true, noSizeMatchTarget = true,
        isHidden = function() return not Enabled() end,
        getFrame = function()
            if Enabled() and not ns.InCombat() then return CreatePreview() end
        end,
        getSize = function() local size = ns.ItemSize(); return size, size end,
        loadPos = SavedPosition,
        savePos = function(_, point, relPoint, x, y)
            if not Enabled() or ns.InCombat() then return end
            -- EUI's SaveBarPosition canonicalizes mover coordinates to CENTER.
            if ns.String(point) ~= "CENTER" or ns.String(relPoint) ~= "CENTER" then return end
            x, y = ns.Number(x), ns.Number(y)
            if not x or not y then return end
            local cfg = addon.Settings()
            cfg.itemX, cfg.itemY = math.max(-10000, math.min(10000, x)), math.max(-10000, math.min(10000, y))
            Position()
        end,
        clearPos = function()
            if Enabled() and not ns.InCombat() then addon.ResetItemPosition() end
        end,
        applyPos = Position,
    }
    moverElement = ns.Table(ns.Call(EllesmereUI.MakeUnlockElement, opts))
    if not moverElement then
        if active then editing, editSnapshot = false, nil end
        return
    end
    -- Set before registration: EUI may synchronously notify an open session.
    moverRegistered = true
    moverHidden = hidden
    local ok = pcall(EllesmereUI.RegisterUnlockElements, EllesmereUI, { moverElement }, addonName)
    if ok then ok = pcall(EllesmereUI.RegisterUnlockModeListener, EllesmereUI, MOVER_KEY, UnlockChanged) end
    if not ok then
        moverRegistered = false
        if type(EllesmereUI.UnregisterUnlockElement) == "function" then
            pcall(EllesmereUI.UnregisterUnlockElement, EllesmereUI, MOVER_KEY)
        end
        if active then editing, editSnapshot = false, nil end
        return
    end
    moverHidden = hidden
    ns.UpdateQuestItem()
end

function ns.RefreshQuestItem()
    if ticker then ticker:Cancel(); ticker = nil end
    ns.RegisterQuestItemMover()
    if not visibilityRegistered and EllesmereUI and type(EllesmereUI.RegisterVisibilityUpdater) == "function" then
        visibilityRegistered = pcall(EllesmereUI.RegisterVisibilityUpdater, ns.UpdateQuestItem)
    end
    local enabled = Enabled() and not editing
    if enabled and C_Timer and type(C_Timer.NewTicker) == "function" then
        ticker = C_Timer.NewTicker(1, ns.UpdateQuestItem)
    end
    if button then Position() end
    ns.UpdateQuestItem()
end

function ns.QuestItemEvent(event)
    if event == "PLAYER_REGEN_DISABLED" then
        if preview then preview:Hide() end
        return
    end
    if event == "SPELL_UPDATE_COOLDOWN" then Cooldown(); return end
    if event == "PLAYER_REGEN_ENABLED" then
        if button and not ns.InCombat() then button:StopMovingOrSizing(); Position() end
        ns.RefreshQuestItem()
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_LIST_CHANGED" or event == "QUEST_REMOVED"
        or event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" or event == "BAG_UPDATE_DELAYED"
        or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "QUEST_POI_UPDATE" then
        ns.Queue("questItem", ns.UpdateQuestItem)
    end
end

function addon.ResetItemPosition()
    if ns.InCombat() then return end
    addon.Settings().itemX, addon.Settings().itemY = ns.Defaults.itemX, ns.Defaults.itemY
    if editing then Place(preview) else Position() end
end
