-- Standalone mock regression. Run from repository root; no upstream fixture.
-- NativeResolve models only the driver clauses used here, NOT WoW secure execution.
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Run(forever)
    EUI_CLIENT_FOREVER = forever
    local combat, dead, ghost, active = false, false, false, false
    local quest, distance, tracking = 10, 25, true
    local insideArea = false
    local counts, watches = { [110] = 1, [120] = 1 }, { [10] = 0, [20] = 0 }
    local frames, tickers, driverWrites, protectedWrites = {}, {}, 0, 0
    local combatWriteAttempts = 0
    local mover, listener
    local cfg = { questItem = true, itemProximityYards = 100, itemSize = 56,
        itemX = 0, itemY = -180, itemRetailArt = true, itemIconAlpha = 1,
        itemBorderTexture = "none", itemBorderSize = 1, itemBorderColor = { r = 1, g = 1, b = 1 },
        itemVisibility = { visibility = "always", visibilityMatch = "all" } }
    local function Noop() end
    local function Protected(frame)
        if frame.secure then
            if combat then combatWriteAttempts = combatWriteAttempts + 1 end
            assert(not combat, "protected write in combat")
            protectedWrites = protectedWrites + 1
        end
    end
    function InCombatLockdown() return combat end
    function UnitIsDeadOrGhost() return dead or ghost end
    function CreateFrame(kind, name, parent, template)
        if template == "SecureActionButtonTemplate" then
            if combat then combatWriteAttempts = combatWriteAttempts + 1 end
            assert(not combat, "secure creation in combat")
        end
        local f = { kind = kind, name = name, parent = parent, attrs = {}, scripts = {}, shown = true,
            secure = template == "SecureActionButtonTemplate" or (parent and parent.secure) or false }
        frames[#frames + 1] = f
        function f:SetScript(event, callback) self.scripts[event] = callback end
        function f:SetAttribute(key, value) Protected(self); self.attrs[key] = value end
        function f:SetSize(w, h) Protected(self); self.width, self.height = w, h end
        function f:SetPoint(...) Protected(self); self.point = { ... } end
        function f:ClearAllPoints() Protected(self); self.point = nil end
        function f:SetAllPoints() Protected(self) end
        function f:Show() Protected(self); self.shown = true end
        function f:Hide()
            Protected(self); self.shown = false
            if self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        function f:IsShown() return self.shown end
        function f:StartMoving() Protected(self); self.moving = true end
        function f:StopMovingOrSizing() Protected(self); self.moving = false end
        function f:GetCenter() assert(not (self.secure and combat)); return 500, 400 end
        function f:CreateTexture() return CreateFrame("Texture", nil, self) end
        function f:SetTexture(texture) self.texture = texture; return true end
        function f:SetAlpha(alpha) self.alpha = alpha end
        function f:GetAlpha() return self.alpha or 1 end
        function f:EnableMouse(enabled) self.mouseEnabled = enabled end
        function f:RegisterForClicks(...) self.clicks = { ... } end
        function f:RegisterForDrag(...) self.drag = { ... } end
        f.SetFrameStrata, f.SetClampedToScreen, f.SetMovable, f.SetHighlightTexture = Noop, Noop, Noop, Noop
        f.SetCooldown, f.Clear = Noop, Noop
        return f
    end
    UIParent = CreateFrame("Frame")
    GameTooltip = nil
    C_Timer = { NewTicker = function(_, callback)
        local t = { callback = callback, Cancel = function(self) self.cancelled = true end }
        tickers[#tickers + 1] = t; return t
    end }
    C_SuperTrack = { GetSuperTrackedQuestID = function() return quest end,
        IsSuperTrackingQuest = function() return tracking end }
    C_Navigation = { GetDistance = function() return distance end }
    C_Minimap = { IsInsideQuestBlob = function(id) assert(id == quest); return insideArea end }
    C_QuestLog = { GetNumQuestLogEntries = function() return 2 end,
        GetInfo = function(index) return { questID = index * 10, isHeader = false } end,
        GetQuestWatchType = function(id) return watches[id] end,
        GetDistanceSqToQuest = function(id) assert(id == quest); return distance * distance, true end,
        IsComplete = function() return false end,
        GetLogIndexForQuestID = function(id) return id / 10 end }
    C_Item = { GetItemCount = function(id) return counts[id] end }
    function GetQuestLogSpecialItemInfo(index) return "item:" .. (100 + index * 10), index, 0, false end
    function GetQuestLogSpecialItemCooldown() return 0, 0, 0 end
    local function NativeResolve(f)
        local driver = f.questItemDriver or "hide"
        local shown = driver ~= "hide"
        if driver:find("[combat] show", 1, true) then shown = combat end
        if driver:find("[nocombat] show", 1, true) then shown = not combat end
        if driver:find("[@player,dead] hide;", 1, true) and (dead or ghost) then shown = false end
        f.shown = shown -- Native model must not invoke insecure Show/Hide.
        if not shown and f.scripts.OnHide then f.scripts.OnHide(f) end
    end
    function RegisterStateDriver(f, state, driver)
        if combat then combatWriteAttempts = combatWriteAttempts + 1 end
        assert(not combat and state == "visibility", "driver write in combat")
        driverWrites = driverWrites + 1
        -- Resolve now, as the real registration does, before the cached field is set.
        local old = f.questItemDriver; f.questItemDriver = driver; NativeResolve(f); f.questItemDriver = old
    end
    function UnregisterStateDriver()
        if combat then combatWriteAttempts = combatWriteAttempts + 1 end
        assert(not combat, "driver removal in combat")
    end
    EllesmereUI = {
        GetActiveVisibilityModes = function() end,
        GetVisibilitySelection = function(store) return { [store.visibility] = true } end,
        CheckVisibilityOptionsNonMacro = function() return false end,
        BuildVisibilityDriverString = function(prefix, selection)
            if selection.in_combat then return prefix .. "[combat] show; hide" end
            if selection.out_of_combat then return prefix .. "[nocombat] show; hide" end
            return prefix .. "show"
        end,
        BuildAnyMatchTail = function() return "show" end,
        VisWantsMouseover = function(store) return store.visibility == "mouseover" end,
        MakeUnlockElement = function(opts) return opts end,
        RegisterUnlockElements = function(_, elements) assert(not combat); mover = elements[1] end,
        RegisterUnlockModeListener = function(_, _, callback) listener = callback end,
        IsUnlockModeActive = function() return active end,
    }
    local ns = {}
    assert(loadfile("QuestTracker/Compatibility.lua"))("EllesmereUIExtendQuestTracker", ns)
    ns.Addon = { Settings = function() return cfg end }
    ns.Active = function() return true end
    ns.Queue = function(_, callback) callback() end
    ns.Defaults = { itemX = 0, itemY = -180 }
    assert(loadfile("QuestTracker/ItemVisibility.lua"))("EllesmereUIExtendQuestTracker", ns)
    assert(loadfile("QuestTracker/QuestItem.lua"))("EllesmereUIExtendQuestTracker", ns)
    local function Button()
        for _, f in ipairs(frames) do if f.name == "EllesmereUIExtendQuestTrackerItem" then return f end end
    end
    local function EnterCombat() combat = true; ns.QuestItemEvent("PLAYER_REGEN_DISABLED") end
    local function LeaveCombat() combat = false; ns.QuestItemEvent("PLAYER_REGEN_ENABLED") end
    combat = true; ns.RefreshQuestItem()
    Check(not Button(), "enable/login in combat defers creation")
    LeaveCombat()
    local b = assert(Button())
    Check(b.shown and b.attrs.item1 == "item:110", "regen creates current eligible action")
    Check(b.clicks[1] == "AnyDown" and b.clicks[2] == "AnyUp" and b.attrs.useOnKeyDown == nil,
        "both phases registered without overriding cast-on-key-down preference")
    Check(b.attrs.type1 == "item" and b.attrs.type2 == nil and b.drag[1] == "RightButton",
        "left item action and separate right-drag fallback")
    local function Deferred(change, event, label)
        EnterCombat()
        local writes, drivers, item, shown = protectedWrites, driverWrites, b.attrs.item1, b.shown
        local width, iconAlpha = b.width, b.icon.alpha
        change(); ns.QuestItemEvent(event); tickers[#tickers].callback(); ns.RefreshQuestItem()
        Check(protectedWrites == writes and driverWrites == drivers and b.attrs.item1 == item and b.shown == shown
            and b.width == width and b.icon.alpha == iconAlpha,
            label .. " leaves protected state unchanged in combat")
        LeaveCombat()
    end
    Deferred(function() quest = 20 end, "SUPER_TRACKING_CHANGED", "navigation change")
    Check(b.attrs.item1 == "item:120" and b.shown, "regen selects latest navigation item")
    Deferred(function() counts[120] = 0 end, "BAG_UPDATE_DELAYED", "bag removal")
    Check(b.attrs.item1 == nil and not b.shown, "regen clears missing bag item")
    Deferred(function() counts[120] = 1 end, "BAG_UPDATE_DELAYED", "bag addition")
    Check(b.attrs.item1 == "item:120" and b.shown, "regen restores newly available bag item")
    Deferred(function() distance = 101 end, "QUEST_POI_UPDATE", "leaving proximity")
    Check(b.attrs.item1 == nil and not b.shown, "regen hides out-of-range item")
    Deferred(function() distance = 100 end, "QUEST_POI_UPDATE", "entering proximity")
    Check(b.attrs.item1 == "item:120" and b.shown, "regen reveals inclusive threshold candidate")
    distance = 300; ns.UpdateQuestItem()
    Check(not b.shown, "outside quest area and beyond navigation range hides")
    Deferred(function() insideArea = true end, "QUEST_POI_UPDATE", "entering quest area")
    Check(b.shown and b.attrs.item1 == "item:120", "regen reveals inside-area item despite distant navigation")
    Deferred(function() insideArea = false end, "QUEST_POI_UPDATE", "leaving quest area")
    Check(not b.shown and b.attrs.item1 == nil, "regen hides outside-area distant navigation item")
    distance = 100; ns.UpdateQuestItem()
    Deferred(function() watches[20] = nil end, "QUEST_WATCH_LIST_CHANGED", "unwatch")
    Check(b.attrs.item1 == nil and not b.shown, "regen clears unwatched quest")
    watches[20] = 0; ns.UpdateQuestItem()
    Deferred(function() tracking = false end, "SUPER_TRACKING_CHANGED", "user waypoint")
    Check(b.attrs.item1 == nil and not b.shown, "regen clears nonquest navigation")
    tracking = true; ns.UpdateQuestItem()
    Deferred(function() cfg.itemSize, cfg.itemIconAlpha = 84, 0.4 end, "ZONE_CHANGED", "appearance change")
    Check(b.width == 84 and b.icon.alpha == 0.4, "regen applies latest live appearance")
    Deferred(function() cfg.questItem = false end, "QUEST_LOG_UPDATE", "feature disable")
    Check(b.attrs.item1 == nil and not b.shown and tickers[#tickers].cancelled, "regen applies disable and stops polling")
    cfg.questItem = true; cfg.itemVisibility.visibility = "in_combat"; ns.RefreshQuestItem()
    Check(not b.shown, "combat-only driver hides outside combat")
    local drivers = driverWrites
    EnterCombat(); NativeResolve(b)
    Check(b.shown, "native model shows preconfigured action in combat")
    dead = true; NativeResolve(b); ns.QuestItemEvent("PLAYER_DEAD")
    Check(not b.shown and driverWrites == drivers, "native death gate without driver rewrite")
    dead, ghost = false, true; NativeResolve(b); ns.QuestItemEvent("PLAYER_ALIVE")
    Check(not b.shown, "ghost remains hidden")
    ghost = false; NativeResolve(b); ns.QuestItemEvent("PLAYER_UNGHOST")
    Check(b.shown and driverWrites == drivers, "combat resurrection permits existing action")
    LeaveCombat(); NativeResolve(b)
    Check(not b.shown, "regen respects combat-only native visibility")
    cfg.itemVisibility.visibility = "always"; ns.RefreshQuestItem()
    local polling = tickers[#tickers]
    active = true; listener(true)
    local p = assert(mover.getFrame())
    Check(p ~= b and not p.secure and p.kind == "Frame" and p.mouseEnabled == false and not p.scripts.OnClick,
        "mover preview is separate and non-clickable")
    Check(p.shown and not b.shown and b.attrs.item1 == nil and b.attrs.type1 == nil,
        "edit entry clears and hides live action")
    Check(polling.cancelled, "edit entry stops gameplay polling")
    p:SetPoint("CENTER", UIParent, "CENTER", 333, 444)
    local staged, x, y = p.point, cfg.itemX, cfg.itemY
    EnterCombat()
    local writes = protectedWrites
    mover.savePos(nil, "CENTER", "CENTER", 999, 999); mover.clearPos(); mover.applyPos()
    b.scripts.OnDragStart(b); b.scripts.OnDragStop(b)
    ns.Addon.ResetItemPosition(); ns.RefreshQuestItem()
    local sample = ns.CreateQuestItemSample(UIParent); sample.RefreshAppearance()
    Check(not p.shown and not mover.getFrame() and cfg.itemX == x and cfg.itemY == y and protectedWrites == writes,
        "combat rejects mover/drag/reset writes and hides preview")
    Check(not sample.secure and sample.mouseEnabled == false and not sample.scripts.OnClick and not sample.attrs.type1,
        "settings sample remains non-clickable in combat")
    LeaveCombat()
    Check(p.shown and p.point == staged and not b.shown, "regen preserves staged edit placement without live action")
    EnterCombat(); active = false; listener(false, "save")
    Check(not p.shown and not b.shown and not b.attrs.type1, "combat-time edit close defers live restoration")
    LeaveCombat()
    Check(b.shown and b.attrs.item1 == "item:120" and b.attrs.type1 == "item", "regen restores real action after edit close")
    -- Driver-less clients cannot change protected visibility in combat. Verify
    -- fail-closed death fallback out of combat without claiming native hiding.
    RegisterStateDriver, UnregisterStateDriver = nil, nil
    dead = true; ns.UpdateQuestItem()
    Check(not b.shown, "driver-less fallback hides death outside combat")
    dead, ghost = false, true; ns.UpdateQuestItem()
    Check(not b.shown, "driver-less fallback hides ghost outside combat")
    ghost = false; ns.UpdateQuestItem()
    Check(b.shown, "driver-less fallback restores alive eligible action")
    Check(combatWriteAttempts == 0, "no attempted protected combat writes, including swallowed pcall failures")
end
Run(false)
Run(true)
print("PASS: " .. checks .. " quest-item combat recovery and preview checks (Retail/Forever mocks)")
