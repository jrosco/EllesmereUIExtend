SlashCmdList, UISpecialFrames = {}, {}
local checks, frames, modules = 0, {}, {}
local secret = {}
function issecretvalue(value) return rawequal(value, secret) end
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Noop() end
local methods = { SetSize = Noop, SetHeight = Noop, SetWidth = Noop, SetPoint = Noop,
    SetAllPoints = Noop, SetColorTexture = Noop, SetTextColor = Noop, SetFont = Noop,
    SetFrameStrata = Noop, SetClampedToScreen = Noop, SetMovable = Noop, EnableMouse = Noop,
    RegisterForDrag = Noop, StartMoving = Noop, StopMovingOrSizing = Noop, SetAutoFocus = Noop,
    SetFontObject = Noop, SetTextInsets = Noop, SetMaxLetters = Noop, SetJustifyH = Noop,
    SetWordWrap = Noop, SetTexCoord = Noop, Raise = Noop, ClearFocus = Noop, ClearAllPoints = Noop,
    EnableMouseWheel = Noop, SetOrientation = Noop, SetValueStep = Noop, SetThumbTexture = Noop,
    SetResizable = Noop, SetResizeBounds = Noop, SetDesaturated = Noop, SetRotation = Noop }
local function Widget(kind, name, parent, template)
    Check(template == nil, "no secure/container templates")
    local f = { kind = kind, name = name, parent = parent, scripts = {}, events = {}, shown = true,
        hooks = {}, text = "" }
    setmetatable(f, { __index = methods })
    function f:SetScript(event, callback) self.scripts[event] = callback end
    function f:GetScript(event) return self.scripts[event] end
    function f:HookScript(event, callback)
        self.hooks[event] = self.hooks[event] or {}
        table.insert(self.hooks[event], callback)
    end
    function f:RegisterEvent(event) self.events[event] = true end
    function f:Show()
        local wasShown = self.shown
        self.shown = true
        if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
        if not wasShown then for _, hook in ipairs(self.hooks.OnShow or {}) do hook(self) end end
    end
    function f:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:SetShown(value) if value then self:Show() else self:Hide() end end
    function f:IsShown() return self.shown end
    function f:SetEnabled(value) self.enabled = value end
    function f:SetText(text) self.text = text; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
    function f:GetText() return self.text end
    function f:SetSize(width, height)
        local changed = self.width ~= width or self.height ~= height
        self.width, self.height = width, height
        if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, width, height) end
    end
    function f:SetWidth(width) self.width = width end
    function f:SetHeight(height) self.height = height end
    function f:GetWidth() return self.width or 0 end
    function f:GetHeight() return self.height or 0 end
    function f:GetCenter() return self.centerX or 1000, self.centerY or 600 end
    function f:SetScale(scale) self.scale = scale end
    function f:GetEffectiveScale() return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1) end
    function f:SetFrameStrata(strata) self.strata = strata end
    function f:GetFrameLevel() return self.level or 1 end
    function f:SetFrameLevel(level) self.level = level end
    function f:SetAlpha(alpha) self.alpha = alpha end
    function f:SetPoint(...) self.point = { ... } end
    function f:StartMoving() self.moving = true end
    function f:StartSizing(point) self.sizing = point end
    function f:StopMovingOrSizing() self.moving, self.sizing = nil, nil end
    function f:SetScrollChild(child) self.scrollChild = child end
    function f:GetVerticalScroll() return self.scroll or 0 end
    function f:GetVerticalScrollRange() return math.max(0, self.scrollChild:GetHeight() - self:GetHeight()) end
    function f:SetVerticalScroll(value)
        self.scroll = value
        if self.scripts.OnVerticalScroll then self.scripts.OnVerticalScroll(self, value) end
        for _, hook in ipairs(self.hooks.OnVerticalScroll or {}) do hook(self, value) end
    end
    function f:SetMinMaxValues(min, max) self.min, self.max = min, max end
    function f:SetValue(value)
        self.value = value
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
    end
    function f:SetTexture(texture) self.texture, self.atlas = texture, nil end
    function f:SetAtlas(atlas) self.atlas = atlas; self.texture = nil end
    function f:SetTexCoord(...) self.coords = { ... } end
    function f:CreateFontString() return Widget("FontString", nil, self) end
    function f:CreateTexture() return Widget("Texture", nil, self) end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
CreateFrame = Widget
UIParent = Widget("Frame")
GameFontHighlightSmall = {}
local player, clock, access, editing, combat = "Player", 1000, true, false, false
function UnitFullName() return player, "Realm" end
function GetServerTime() return clock end
function date(_, at) return "time:" .. at end
function InCombatLockdown() return combat end
local settings = { showButton = true }
EllesmereUIExtend = {
    RegisterFeature = function(key, spec) Check(key == "bags", "bags feature identity"); modules.feature = spec end,
    GetSettings = function() return settings end,
    RegisterModule = function(spec) modules.options = spec end,
}
local rows, rightRows = {}, {}
EllesmereUI = { IsUnlockModeActive = function() return editing end, Widgets = {
    SectionHeader = function() return {}, 30 end,
    DualRow = function(_, _, _, left, right) rows[#rows + 1] = left; if right then rightRows[#rightRows + 1] = right end; return {}, 40 end,
} }
local borders = 0
EllesmereUI.MakeBorder = function(_, r, g, b, a)
    Check(r == 1 and g == 1 and b == 1 and a == 0.15, "bank skin uses native EUI border contract")
    borders = borders + 1
    return { SetColor = function(self, ...) self.color = { ... } end }
end
Enum = { BagIndex = { CharacterBankTab_1 = 6, CharacterBankTab_2 = 7, AccountBankTab_1 = 12,
    Reagentbank = -3, ReagentBag = 5 }, BankType = { Character = 0, Account = 2 } }
local sizes, contents, metadata = {}, {}, { { name = "Main" }, { name = "Materials" } }
C_Bank = { CanUseBank = function(kind) Check(kind == 0, "only personal access checked"); return access end,
    FetchPurchasedBankTabData = function(kind) Check(kind == 0, "only personal metadata queried"); return metadata end }
C_Container = {
    GetContainerNumSlots = function(id) Check(id ~= 12 and id ~= 5, "Warband/carried reagent never scanned"); return sizes[id] or 0 end,
    GetContainerItemInfo = function(id, slot) return contents[id] and contents[id][slot] end,
}
C_Item = { GetItemInfo = function(link) return link:find("100", 1, true) and "Silver Ore" or "Other Item" end }
local tooltips = 0
GameTooltip = { SetOwner = Noop, SetHyperlink = function(_, link) tooltips = tooltips + 1; Check(type(link) == "string", "tooltip uses saved link") end,
    AddLine = Noop, Show = Noop, Hide = Noop }
local ns = {}
for _, file in ipairs({ "Compatibility", "Bags", "Snapshot", "Tooltip", "Viewer", "Options" }) do
    assert(loadfile("Bags/" .. file .. ".lua"))("EllesmereUIExtendBags", ns)
end
local function Event(event, ...)
    ns.EventFrame.scripts.OnEvent(ns.EventFrame, event, ...)
end
local function Tick()
    local callback = ns.EventFrame.scripts.OnUpdate
    if callback then callback(ns.EventFrame, 0.25) end
end
local function Item(id, count) return { itemID = id, stackCount = count, hyperlink = "item:" .. id, iconFileID = id, quality = 2 } end
Event("ADDON_LOADED", "EllesmereUIExtendBags")
Check(ns.DB == EllesmereUIExtendBagsDB and ns.DB.format == 1, "inventory initializes only after SavedVariables")
Check(not ns.Scan(), "closed bank never scanned")
Event("BANKFRAME_OPENED")
Tick(); Tick()
Check(#ns.Characters() == 0, "zero slot counts cannot replace data on opening")
sizes = { [6] = 2, [7] = 2, [-3] = 1 }
contents = { [6] = { Item(100, 4) }, [7] = { Item(200, 1) }, [-3] = { Item(300, 8) } }
Tick()
Check(#ns.Characters() == 0, "first valid scan is staged")
Tick()
local key = "Player - Realm"
local snapshot = ns.DB.characters[key]
Check(snapshot and #snapshot.tabs == 3 and snapshot.tabs[1].items[1].count == 4, "personal and reagent storage captured")
Check(snapshot.updatedAt == 1000, "successful capture timestamp")
contents[6][1].stackCount = 9
Check(snapshot.tabs[1].items[1].count == 4, "saved data detached from native tables")
Event("BAG_UPDATE", 6); Tick(); Tick()
Check(ns.DB.characters[key].tabs[1].items[1].count == 9, "bank visit updates stack count")
snapshot = ns.DB.characters[key]
sizes[7] = 0
Tick(); Tick()
Check(ns.DB.characters[key] == snapshot, "partially loaded tab retains previous snapshot")
sizes[7] = 2
contents[6][1].stackCount = secret
Tick(); Tick()
Check(ns.DB.characters[key] == snapshot, "secret count preserves snapshot")
contents[6][1].stackCount = 9
contents[6][1].itemID = secret
Tick(); Tick()
Check(ns.DB.characters[key] == snapshot, "secret ID preserves snapshot")
contents[6][1].itemID = 100
contents[6][1].hyperlink = nil
Tick(); Tick()
Check(ns.DB.characters[key] == snapshot, "missing link preserves snapshot")
contents[6][1].hyperlink = "item:100"
local getInfo = C_Container.GetContainerItemInfo
C_Container.GetContainerItemInfo = function() error("restricted") end
Tick(); Tick()
Check(ns.DB.characters[key] == snapshot, "throwing getter preserves snapshot")
C_Container.GetContainerItemInfo = getInfo
local fetchTabs = C_Bank.FetchPurchasedBankTabData
C_Bank.FetchPurchasedBankTabData = function() return nil end
Tick(); Tick()
Check(ns.DB.characters[key] == snapshot, "unavailable Retail metadata cannot commit a partial bank")
C_Bank.FetchPurchasedBankTabData = function() return secret end
Tick(); Tick()
Check(ns.DB.characters[key] == snapshot, "secret tab metadata preserves snapshot")
C_Bank.FetchPurchasedBankTabData = function() error("not ready") end
Tick(); Tick()
Check(ns.DB.characters[key] == snapshot, "throwing tab metadata preserves snapshot")
C_Bank.FetchPurchasedBankTabData = fetchTabs
Enum.PlayerInteractionType = { AccountBanker = 42 }
C_PlayerInteractionManager = { IsInteractingWithNpcOfType = function() return true end }
Check(not ns.Scan(), "portable account storage excluded even if personal access helper says yes")
C_PlayerInteractionManager.IsInteractingWithNpcOfType = function() return secret end
Check(not ns.Scan(), "secret account-only interaction fails closed")
C_PlayerInteractionManager = nil
access = false
contents[6][1].stackCount = 12
Tick(); Tick()
Check(ns.DB.characters[key] == snapshot, "account-only access cannot capture personal bank")
access = secret
Tick(); Tick()
Check(ns.DB.characters[key] == snapshot, "unreadable permission fails closed")
access = true
Event("BANKFRAME_CLOSED")
Check(not ns.BankOpen and ns.EventFrame.scripts.OnUpdate == nil, "bank close stops poller")
Tick()
Check(ns.DB.characters[key] == snapshot, "no post-close capture")
Event("BANKFRAME_OPENED"); Tick(); Tick()
Check(ns.DB.characters[key].tabs[1].items[1].count == 12, "reopening refreshes snapshot")
clock = 2000
Event("BANKFRAME_CLOSED"); Event("BANKFRAME_OPENED"); Tick(); Tick()
Check(ns.DB.characters[key].updatedAt == 2000, "unchanged bank receives fresh visit timestamp")
contents = {}
Event("BAG_UPDATE"); Tick(); Tick()
Check(next(ns.DB.characters[key].tabs[1].items) == nil, "empty bank is valid, not stale items")
player = "Alt"
contents = { [6] = { Item(100, 3) } }
Event("BANKFRAME_CLOSED"); Event("BANKFRAME_OPENED"); Tick(); Tick()
Check(#ns.Characters() == 2, "multiple character snapshots retained")
Check(#ns.Items(ns.DB.characters["Alt - Realm"], nil, "silver") == 1, "name search")
Check(#ns.Items(ns.DB.characters["Alt - Realm"], 7, "") == 0, "tab filtering")
Check(#ns.Items(ns.DB.characters["Alt - Realm"], nil, "100") == 1, "ID search")
Check(#ns.Items(ns.DB.characters["Alt - Realm"], nil, "%") == 0, "search is literal")
C_Item.GetItemInfo = function() return secret end
Check(#ns.Items(ns.DB.characters["Alt - Realm"], nil, "100") == 1, "uncached/secret name uses saved ID/link")
C_Item.GetItemInfo = nil
Event("BANKFRAME_CLOSED")
-- Forever/older capability path: enum-only discovery, no metadata or access helper.
player = "Fallback"
EllesmereUI.IS_FOREVER = true
C_Bank.FetchPurchasedBankTabData = function() return nil end
Event("BANKFRAME_OPENED"); Tick(); Tick()
Check(ns.DB.characters["Fallback - Realm"] ~= nil, "Forever nil-metadata fallback supports bank snapshots")
C_Bank = nil
EllesmereUI.IS_FOREVER = false
local fallback = ns.DB.characters["Fallback - Realm"]
sizes[7] = 0
Tick(); Tick()
Check(ns.DB.characters["Fallback - Realm"] == fallback, "fallback cannot silently drop old tabs")
sizes[7] = 2
Enum.PlayerInteractionType = { AccountBanker = 42 }
C_PlayerInteractionManager = { IsInteractingWithNpcOfType = function() return true end }
Check(not ns.Scan(), "portable account bank gated without CanUseBank")
C_PlayerInteractionManager = nil
Event("BANKFRAME_CLOSED")
-- Viewer, native ownership, settings callbacks and profile-independent inventory.
EUI_Bags = Widget("Frame")
combat = true
ns.Addon.Refresh()
Check(not ns.BagButton, "attachment defers in combat")
combat = false
local capturedDB = ns.DB
ns.DB = { format = 1, characters = {} }
Event("PLAYER_REGEN_ENABLED")
Check(ns.BagButton and ns.BagButton.parent == EUI_Bags, "button attached to actual EUI bag frame")
Check(ns.BagButton.enabled, "no snapshots still allows opening empty bank")
local shownTip
EllesmereUI.ShowWidgetTooltip = function(_, tip) shownTip = tip end
ns.BagButton.scripts.OnEnter()
Check(shownTip == "Visit the banker first", "button explains current-character banker prerequisite")
ns.BagButton.scripts.OnClick()
local viewer = EllesmereUIExtendBagsViewer
local function PickCharacter(key)
    local host = EllesmereUIExtendBagsViewer
    host.characterDropdown.scripts.OnClick(host.characterDropdown)
    for _, row in ipairs(host.characterMenu.rows) do
        if row:IsShown() and row.label.text == key then row.scripts.OnClick(); return end
    end
    error("missing dropdown character " .. key)
end
Check(viewer:IsShown() and viewer.message.text == "Visit the banker first", "button opens first-visit empty bank")
Check(viewer.character.text == "Fallback - Realm", "uncaptured current character still labels empty bank")
Check(viewer.characterDropdown.enabled, "current character remains selectable without snapshots")
for _, slot in ipairs(viewer.slots) do Check(not slot:IsShown() and slot.entry == nil, "uncaptured bank has no item icons") end
Event("BANKFRAME_OPENED"); Tick(); Tick()
Check(viewer.slots[1]:IsShown() and viewer.message.text == "", "first capture fills open viewer without reopening bags")
Check(not ns.BagButton.tip:find("first", 1, true), "first capture updates button help")
ns.DB = capturedDB
Event("BANKFRAME_CLOSED")
player = "Uncaptured"
ns.Addon.Refresh(); ns.Addon.Refresh()
Check(ns.BagButton.enabled and viewer.message.text == "Visit the banker first", "uncaptured player never falls back to alt snapshot")
Check(viewer.character.text == "Uncaptured - Realm" and not viewer.slots[1]:IsShown(), "current player owns empty viewer despite saved alts")
Check(viewer.characterDropdown.enabled, "uncaptured player can browse saved alts")
PickCharacter("Alt - Realm")
Check(viewer.character.text == "Alt - Realm" and viewer.slots[1]:IsShown(), "right arrow browses captured alt from empty current bank")
ns.Addon.Refresh()
Event("GET_ITEM_INFO_RECEIVED")
Check(viewer.character.text == "Alt - Realm", "refresh and item data arrival preserve selected alt")
PickCharacter("Uncaptured - Realm")
Check(viewer.character.text == "Uncaptured - Realm" and viewer.message.text == "Visit the banker first",
    "left arrow returns to uncaptured current player")
PickCharacter("Alt - Realm")
viewer:Hide()
SlashCmdList.ELLESMEREUIEXTENDBAGS()
Check(viewer.character.text == "Uncaptured - Realm" and viewer.message.text == "Visit the banker first",
    "slash reopening defaults to current player instead of last browsed alt")
player = "Fallback"
Check(#EUI_Bags.hooks.OnShow == 1, "one native OnShow hook")
viewer:Hide()
ns.BagButton.scripts.OnClick()
Check(viewer and viewer:IsShown(), "bag button opens separate viewer")
local slots = {}
for _, frame in ipairs(frames) do
    if frame.parent == viewer.scrollChild and frame.icon then
        slots[#slots + 1] = frame
        Check(frame.scripts.OnClick == nil and frame.scripts.OnDragStart == nil, "snapshot icon has no item action")
    end
end
Check(#slots > 0 and slots[1].entry and viewer.scrollFrame.scrollChild == viewer.scrollChild,
    "snapshot items render inside clipped scroll child")
slots[1].scripts.OnEnter(slots[1])
Check(tooltips == 1, "stored-link tooltip shown")
Check(viewer.character.text == "Fallback - Realm" and viewer.characterDropdown and not viewer.previousCharacter and not viewer.nextCharacter,
    "viewer opens on current player with dropdown replacing arrows")
PickCharacter("Alt - Realm")
Check(viewer.character.text == "Alt - Realm", "right arrow browses other captured character")
Event("BANKFRAME_OPENED"); Tick(); Tick()
Check(viewer.character.text == "Alt - Realm", "current player's capture preserves intentionally browsed alt")
Event("BANKFRAME_CLOSED")
viewer.tabs[3].scripts.OnClick(viewer.tabs[3])
viewer.search:SetText("no-match")
viewer:Hide()
ns.BagButton.scripts.OnClick()
Check(viewer.character.text == "Fallback - Realm" and viewer.search:GetText() == "" and slots[1]:IsShown(),
    "bag-button reopening resets alt selection, tab and search to current player")
viewer.search:SetText("no-match")
Check(not slots[1]:IsShown() and viewer.message.text == "No items in this view.", "search hides unrelated icons")
viewer.search:SetText("")
local before = ns.DB
modules.options.buildPage("Bank Snapshot", {}, 0)
editing = true
rows[1].setValue(false)
Check(settings.showButton, "stale setting callback honors editor lock")
viewer:Hide(); ns.ToggleViewer()
Check(not viewer:IsShown(), "viewer open blocked in edit mode")
editing = false
settings = { showButton = false }
ns.Addon.Refresh()
Check(not ns.BagButton:IsShown() and ns.DB == before, "profile change hides button without deleting bank data")
settings = modules.feature.normalize({ showButton = true })
modules.feature.refresh()
Check(ns.BagButton:IsShown() and ns.DB == before, "settings reset preserves inventory")
ns.ToggleViewer()
Check(viewer:IsShown(), "slash-access viewer independent of button visibility")
local alt = ns.DB.characters["Alt - Realm"]
for i = 1, 100 do alt.tabs[1].items[i] = { itemID = 100, count = 1, link = "item:100" } end
alt.tabs[1].numSlots = 100
player = "Alt"
ns.RefreshViewer()
Check(viewer.character.text == "Alt - Realm", "refresh uses current identity, not prior selection")
Check(not viewer.nextPage and not viewer.previousPage and viewer.scrollFrame:GetVerticalScrollRange() > 0,
    "large banks scroll without stack pagination arrows")
Check(viewer.slots[100]:IsShown() and viewer.total.text == "100 stacks", "every stack is in continuous scroll content")
viewer.scrollFrame.scripts.OnMouseWheel(viewer.scrollFrame, -1)
Check(viewer.scrollFrame:GetVerticalScroll() == 40, "bank wheel uses EUI's 40-pixel step")
viewer.scrollFrame.scripts.OnMouseWheel(viewer.scrollFrame, -1000)
Check(viewer.scrollFrame:GetVerticalScroll() == viewer.scrollFrame:GetVerticalScrollRange(), "wheel clamps to bottom")
ns.Addon.Refresh()
Check(viewer.scrollFrame:GetVerticalScroll() > 0, "capture/profile refresh preserves scroll when view is unchanged")
viewer.scrollTrack:SetValue(20)
Check(viewer.scrollFrame:GetVerticalScroll() == 20, "older EUI scrollbar can drag to position")
viewer.search:SetText("no-match")
Check(viewer.scrollFrame:GetVerticalScroll() == 0 and not viewer.scrollTrack:IsShown()
    and not viewer.slots[100]:IsShown(), "search resets scroll and hides unused pooled items")
viewer.search:SetText("")
viewer.slots[1].scripts.OnMouseWheel(viewer.slots[1], -1)
Check(viewer.scrollFrame:GetVerticalScroll() == 40, "wheel over plain item buttons scrolls")
viewer:Hide()
SlashCmdList.ELLESMEREUIEXTENDBAGS()
Check(viewer.slots[100]:IsShown() and viewer.scrollFrame:GetVerticalScroll() == 0, "reopening resets scroll to top")
EllesmereUIExtendBagsDB = { format = 99, characters = {} }
ns.InitializeDB()
Check(ns.DB == nil and EllesmereUIExtendBagsDB.format == 99, "unsupported DB preserved, not migrated")
ns.Addon.Refresh()
Check(ns.BagButton.enabled and ns.BagButton.tip:find("unsupported", 1, true), "unsupported database keeps diagnostic viewer accessible")
ns.RefreshViewer()
Check(viewer.message.text:find("unsupported", 1, true), "unsupported DB explains unavailable storage")
EllesmereUIExtendBagsDB = { format = 1, characters = { Broken = { tabs = { { bagID = 6 } } } } }
ns.InitializeDB()
Check(#ns.Characters() == 0, "malformed saved records ignored without deleting them")
ns.Addon.Refresh()
Check(ns.BagButton.enabled, "malformed records still allow first-visit guidance")
ns.RefreshViewer()
Check(viewer.message.text == "Visit the banker first", "malformed records cannot break viewer")
viewer:Hide()
ns.BagButton.scripts.OnClick()
Check(viewer:IsShown() and viewer.message.text == "Visit the banker first", "button reopens first-visit guidance")
viewer:Hide()
SlashCmdList.ELLESMEREUIEXTENDBAGS()
Check(viewer:IsShown() and viewer.message.text == "Visit the banker first", "slash opens same first-visit guidance")
ns.DB = { format = 1, characters = { ["Alt - Realm"] = { tabs = { { bagID = 6, name = "Bank", numSlots = 1, items = {} } } } } }
ns.Addon.Refresh()
Check(viewer.message.text == "No items in this view.", "captured empty current bank is distinct from uncaptured bank")
local fullName = UnitFullName
UnitFullName = function() return secret, secret end
ns.RefreshViewer()
Check(viewer.character.text == "Current character unavailable" and viewer.message.text == "Visit the banker first",
    "unreadable character identity cannot select saved alt data")
Check(not viewer.slots[1]:IsShown(), "unreadable identity clears prior icons")
UnitFullName = fullName
Check(ns.DB.characters["Alt - Realm"] ~= nil, "viewer preserves other stored character data")
-- Snapshot layouts use current EUI configuration without querying live containers.
modules.feature.normalize(settings)
Check(settings.display == "match" and settings.groupByCategory == false, "new settings normalize to EUI display and ungrouped")
EllesmereUI._bagsDB = { profile = { bankCompactView = true } }
Check(ns.DisplayMode() == "compact", "match follows EUI compact bank")
EllesmereUI._bagsDB.profile.bankListView = true
Check(ns.DisplayMode() == "list", "EUI list wins when both native switches are set")
settings.display = "grid"
Check(ns.DisplayMode() == "grid", "explicit override ignores native bank mode")
local cats = { { name = "Materials", _defaultName = "Trade Goods" },
    { name = "Quests", types = { 12 } }, { name = "Set Gear", isSetGear = true },
    { name = "Junk", isJunk = true }, { name = "Other", isCatchAll = true } }
EUI_CategoryManager = {
    GetCategories = function() return cats end,
    ClassifyItem = function(_, link, id, bag, slot)
        Check(bag == nil and slot == nil, "snapshot classifier never sees live bag coordinates")
        return id == 100 and 1 or 5
    end,
    GetSetGearLookup = function() return { [6001] = 42 } end,
}
local entries = {}
for i = 1, 100 do entries[i] = { item = { itemID = i % 2 == 0 and 100 or 200, link = "item:100", count = 2, quality = 2 } } end
settings.groupByCategory = true
for _, mode in ipairs({ "grid", "compact", "list" }) do
    settings.display = mode
    local layout, resolved = ns.Layout(entries)
    local total, seen = 0, {}
        Check(#layout.slots == 100, "layouts include every stack in one scroll child")
        for _, placement in ipairs(layout.slots) do
            total = total + 1
            Check(placement.x >= 0 and placement.x < 420 and placement.y >= 0
                and placement.y + (mode == "list" and 24 or 40) <= layout.height, "layout fits continuous content bounds")
            Check(not seen[placement.entry], "scroll layout never duplicates a stack")
            seen[placement.entry] = true
        end
    Check(total == 100 and resolved == mode, "all stacks survive continuous category layout in " .. mode)
    Check(layout.headings[1].text == "Materials", "EUI names and order reused")
end
EllesmereUI._bagsDB.profile.bagDisabledCategories = { ["Trade Goods"] = true }
local layouts = ns.Layout({ entries[2] })
Check(layouts.headings[1].text == "Other", "disabled EUI categories route to catch-all")
EllesmereUI._bagsDB.profile.bagDisabledCategories = nil
local specialItem = { itemID = 200, link = "item:200", count = 1, quality = 2, quest = true, setID = 42 }
layouts = ns.Layout({ { item = specialItem } })
Check(layouts.headings[1].text == "Quests", "captured quest status precedes equipment set")
specialItem.quest = nil
layouts = ns.Layout({ { item = specialItem } })
Check(layouts.headings[1].text == "Set Gear", "captured equipment membership supports alt grouping")
specialItem.quality = 0
layouts = ns.Layout({ { item = specialItem } })
Check(layouts.headings[1].text == "Junk", "junk precedes equipment set")
EllesmereUIDB = { bagItemAssignments = { [200] = "Trade Goods" } }
layouts = ns.Layout({ { item = specialItem } })
Check(layouts.headings[1].text == "Materials", "current EUI assignment overrides captured special membership")
EllesmereUIDB = nil
EUI_CategoryManager = nil
layouts = ns.Layout(entries)
Check(layouts.headings[1].text == "Other", "missing category API retains every item in catch-all")
EUI_CategoryManager = { GetCategories = function() error("unavailable") end }
Check(#ns.Layout(entries).slots == 100, "throwing category API has safe fallback")
EllesmereUI._bagsDB.profile.bagListColumns = { "name", "track", "count", "unknown", "name", "bind" }
local columns = ns.ListColumns()
Check(#columns == 4 and columns[1] == "name" and columns[4] == "bind", "EUI column order retained, unknowns and duplicates omitted")
local oldInfo = C_Item.GetItemInfo
Enum.ItemBind = { OnEquip = 2, ToBnetAccount = 8 }
C_Item.GetItemInfo = function() return "Named Item", nil, 2, 40, 10, "Armor", "Plate", nil, nil, nil, 12345, nil, nil, 2 end
C_Item.GetDetailedItemLevelInfo = function() return 42 end
local values = ns.ListValues({ link = "item:100", count = 2, bound = true })
Check(values.name == "Named Item" and values.ilvl == "42" and values.type == "Plate" and values.bind == "SB", "available list metadata resolved from stored links")
Check(values.sell == "2g 46s 90c" and not values.track, "stack vendor value computed, unknown track blank")
C_Item.GetItemInfo = function() return "Named Item", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 8 end
Check(ns.ListValues({ link = "item:100", count = 1, bound = true }).bind == "WB", "account-bound items are not mislabeled soulbound")
C_Item.GetItemInfo = function() return secret, nil, secret, secret, secret, secret, secret, nil, nil, nil, secret end
C_Item.GetDetailedItemLevelInfo = function() return secret end
values = ns.ListValues({ link = "item:100", count = 1 })
Check(values.name == "item:100" and values.ilvl == "" and not values.sell, "secret metadata left blank without arithmetic")
C_Item.GetItemInfo = oldInfo
settings.display = "list"
ns.RefreshViewer()
Check(viewer.display.label.text == "List", "viewer reflects persistent mode")
editing = true
viewer.display.scripts.OnClick(); viewer.grouping.scripts.OnClick()
Check(settings.display == "list" and settings.groupByCategory, "stale viewer controls honor editor lock")
editing = false
viewer.display.scripts.OnClick()
Check(settings.display == "match", "viewer cycles to Match EUI bank persistently")
viewer.grouping.scripts.OnClick()
Check(not settings.groupByCategory, "viewer grouping changes saved setting")
modules.options.buildPage(nil, UIParent, 0)
local displayControl
for _, row in ipairs(rightRows) do if row.text == "Bank display" then displayControl = row end end
Check(displayControl.text == "Bank display", "settings exposes four-choice display dropdown")
editing = true
displayControl.setValue("compact")
Check(settings.display == "match", "stale settings dropdown honors editor lock")
editing = false
displayControl.setValue("compact")
Check(settings.display == "compact", "settings dropdown applies persistent override")
EUI_CategoryManager = { GetSetGearLookup = function() return { [6001] = 42 } end }
C_Container.GetContainerItemQuestInfo = function() return { isQuestItem = true } end
sizes, contents = { [6] = 1, [7] = 1 }, { [6] = { Item(100, 1) } }
contents[6][1].isBound = true
Event("BANKFRAME_OPENED")
local scan = ns.Scan()
Check(scan[1].items[1].quest and scan[1].items[1].setID == 42 and scan[1].items[1].bound,
    "banker scan captures quest, equipment membership and binding")
Event("BANKFRAME_CLOSED")
ns.DB = { format = 1, characters = { [ns.CharacterKey()] = { tabs = scan } } }
settings.display, settings.groupByCategory = "list", false
C_Item.GetItemInfo = function() return "Silver Ore", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 2 end
viewer:Hide()
SlashCmdList.ELLESMEREUIEXTENDBAGS()
ns.RefreshViewer()
Check(viewer.slots[1]:IsShown() and viewer.slots[1].cells[1].text == "Silver Ore",
    "list draws current EUI name column from stored link")
Check(viewer.slots[1].cells[2].text == "" and viewer.slots[1].cells[3].text == "1",
    "list draws blank track and stack count")
Check(viewer.slots[1].cells[4].text == "SB" and not viewer.slots[1].icon:IsShown(),
    "list supports captured binding and omitted icon column")
Check(borders > 80, "window and plain item buttons reuse native EUI border styling")
settings.display = "grid"
ns.RefreshViewer()
Check(viewer.slots[1].icon:IsShown() and not viewer.slots[1].cells[1]:IsShown(),
    "switching back to grid clears pooled list cells")
Check(viewer.slots[1]:GetScript("OnClick") == nil and viewer.slots[1]:GetScript("OnDragStart") == nil,
    "list and grid retain non-actionable snapshot icons")
-- The native default puts the icon first, leaving cells[1] absent on fresh rows.
scan[1].numSlots = 2
scan[1].items[2] = { itemID = 200, link = "item:200", count = 3, quality = 2 }
EllesmereUI._bagsDB.profile.bagListColumns = nil
C_Item.GetItemInfo = function() return "Silver Ore", nil, 2, 42, nil, nil, nil, nil, nil, nil, 10000 end
C_Item.GetDetailedItemLevelInfo = function() return 42 end
for _, target in ipairs({ "grid", "compact" }) do
    settings.display = "list"
    ns.RefreshViewer()
    local fresh = viewer.slots[2]
    Check(fresh.cells[1] == nil and fresh.cells[3]:IsShown() and fresh.cells[5]:IsShown(),
        "icon-first List has sparse text cells for item level and vendor price")
    settings.display = target
    ns.RefreshViewer()
    Check(fresh.icon:IsShown(), "icon restored after List to " .. target)
    for _, button in ipairs(viewer.slots) do
        for _, cell in pairs(button.cells) do
            Check(not cell:IsShown(), "all sparse List cells hidden after switching to " .. target)
        end
    end
    for _, label in ipairs(viewer.columnLabels) do
        Check(not label:IsShown(), "List headers hidden outside List")
    end
end
-- Native EUI scrollbar integration uses only addon-owned snapshot frames.
viewer:Hide()
local attachments, updates, stops = 0, 0, 0
EllesmereUI._ModuleNS = { EllesmereUIBags = {
    AttachGridScrollbar = function(host, sf, clamp, rawWheel)
        attachments = attachments + 1
        Check(host.name == "EllesmereUIExtendBagsViewer" and sf.parent == host and clamp and rawWheel,
            "reuse the verified EUI bank scrollbar contract on snapshot-owned frames")
        local track = Widget("Button", nil, host)
        track:SetScript("OnMouseUp", function() stops = stops + 1 end)
        return track, Widget("Texture", nil, track), function() updates = updates + 1 end
    end,
} }
assert(loadfile("Bags/Viewer.lua"))("EllesmereUIExtendBags", ns)
settings.display = "list"
scan[1].numSlots = 100
for i = 1, 100 do scan[1].items[i] = { itemID = 100, link = "item:100", count = 1 } end
ns.ToggleViewer()
local native = EllesmereUIExtendBagsViewer
Check(attachments == 1 and updates > 0 and native.slots[100]:IsShown(), "native helper attached once for continuous content")
native.scripts.OnMouseWheel(native, -3)
Check(native.scrollFrame:GetVerticalScroll() == 120, "native helper viewer scrolls on EUI wheel step")
native.tabs[2].scripts.OnClick(native.tabs[2])
Check(native.scrollFrame:GetVerticalScroll() == 0, "changing bank tabs resets scroll")
native.scripts.OnMouseWheel(native, -2)
settings.display = "grid"
ns.Addon.Refresh()
Check(native.scrollFrame:GetVerticalScroll() == 0, "display changes reset scroll and retain every stack")
native.scripts.OnMouseWheel(native, -2)
settings.groupByCategory = not settings.groupByCategory
ns.Addon.Refresh()
Check(native.scrollFrame:GetVerticalScroll() == 0, "grouping changes reset scroll")
native.scripts.OnMouseWheel(native, -2)
ns.DB.characters["Browse - Realm"] = { tabs = scan }
PickCharacter("Browse - Realm")
Check(native.scrollFrame:GetVerticalScroll() == 0, "character dropdown resets scroll")
local priorStops = stops
native:Hide()
Check(stops == priorStops + 1, "hiding viewer releases shared scrollbar drag state")
ns.ToggleViewer()
Check(attachments == 1, "reopening does not duplicate shared scrollbar attachment")
-- Profile-owned geometry, responsive content and stale drag/resize locks.
settings = modules.feature.normalize({ showButton = true, display = "grid" })
ns.Addon.Refresh()
Check(not settings.window.locked and settings.window.width == 620 and native.resize:IsShown(),
    "new profile window defaults unlocked with resize grip")
native.resize.scripts.OnMouseDown(native.resize, "LeftButton")
Check(native.sizing == "BOTTOMRIGHT", "unlocked bottom-right control starts resizing")
native:SetSize(1040, 740)
Check(native.scrollFrame:GetWidth() == 840 and native.scrollFrame:GetHeight() == 560,
    "live resize increases columns and scroll viewport without recursion")
local wide = ns.Layout(entries, 20)
Check(wide.slots[20].x == 798 and wide.slots[21].x == 0, "wide grid uses newly available columns")
native.centerX, native.centerY = 1120, 680
native.resize.scripts.OnMouseUp()
Check(settings.window.width == 1040 and settings.window.height == 740 and settings.window.x == 120
    and settings.window.y == 80, "resize end saves position and size to active profile")
settings.display = "list"
ns.Addon.Refresh()
Check(native:GetWidth() == 1040 and native:GetHeight() == 740, "display changes cannot overwrite chosen size")
native:Hide(); ns.ToggleViewer()
Check(native:GetWidth() == 1040 and native.point[4] == 120 and native.point[5] == 80,
    "reopening restores profile geometry")
native.lock.scripts.OnClick()
Check(settings.window.locked and not native.resize:IsShown()
    and native.lock.icon.texture:find("eui-lock-locked", 1, true), "lock icon disables resizing and reflects state")
native.header.scripts.OnDragStart()
native.resize.scripts.OnMouseDown(native.resize, "LeftButton")
Check(not native.moving and not native.sizing, "locked stale drag and resize callbacks cannot start gestures")
native.lock.scripts.OnClick()
native.header.scripts.OnDragStart()
Check(native.moving, "unlocked heading starts movement")
native.centerX, native.centerY = 1180, 720
native.header.scripts.OnDragStop()
Check(settings.window.x == 180 and settings.window.y == 120, "header drag saves current position")
local originalSettings = settings
native.resize.scripts.OnMouseDown(native.resize, "LeftButton")
native:SetSize(1200, 800)
settings = modules.feature.normalize({ showButton = true, window = { width = 700, height = 600, x = -20, y = 30, locked = true } })
ns.Addon.Refresh()
native.resize.scripts.OnMouseUp()
Check(settings.window.width == 700 and native:GetWidth() == 700 and settings.window.locked
    and originalSettings.window.width == 1040, "profile switch cancels active sizing without overwriting either profile")
settings = originalSettings
ns.Addon.Refresh()
Check(native:GetWidth() == 1040 and not settings.window.locked, "profile switch restores independent size and lock")
editing = true
native.lock.scripts.OnClick(); native.header.scripts.OnDragStart()
native.resize.scripts.OnMouseDown(native.resize, "LeftButton")
Check(not settings.window.locked and not native.moving and not native.sizing, "editor lock applies inside all stale controls")
editing = false
native.resize.scripts.OnMouseDown(native.resize, "LeftButton")
native:SetSize(900, 700)
editing = true
native.resize.scripts.OnMouseUp()
Check(settings.window.width == 1040 and native:GetWidth() == 1040,
    "entering Edit Mode mid-resize discards unsaved size")
editing = false
local normalized = modules.feature.normalize({ window = { width = secret, height = -5, x = secret, y = 1 / 0, locked = secret } })
Check(normalized.window.width == 620 and normalized.window.height == 480 and normalized.window.x == 0
    and normalized.window.y == 0 and not normalized.window.locked, "secret and invalid window values normalize safely")
native.resize.scripts.OnMouseDown(native.resize, "LeftButton")
native:SetSize(100, 200)
Check(native:GetWidth() == 620 and native:GetHeight() == 480, "live resize clamps sizes even without native bounds enforcement")
native:SetSize(10000, 10000)
Check(native:GetWidth() == 1600 and native:GetHeight() == 1200, "live resize enforces maximum safe dimensions")
native.resize.scripts.OnMouseUp()
Check(native.lock.parent == native and native.resize.point[1] == "BOTTOMRIGHT"
    and native.lock.point[2] == native.resize, "unframed lock and grip sit together in bottom-right footer")
Check(native.resize.icon.texture:find("resize_element.png", 1, true)
    and native.lock:GetWidth() == 13 and native.lock:GetHeight() == 17, "footer controls match native EUI icon art and dimensions")
native.lock.scripts.OnEnter()
Check(native.lock.alpha == 0.8, "footer icon hover matches EUI alpha")
native.lock.scripts.OnLeave()
Check(native.lock.alpha == 0.4, "footer icon idle matches EUI alpha")
local positionX, positionY = settings.window.x, settings.window.y
native.resize.scripts.OnDoubleClick()
Check(settings.window.width == 620 and settings.window.height == 510
    and settings.window.x == positionX and settings.window.y == positionY, "grip double-click resets size without moving window")
native.lock.scripts.OnClick()
native.resize.scripts.OnDoubleClick()
Check(settings.window.locked, "stale double-click cannot reset locked window")
Check(native.lock.point[1] == "BOTTOMRIGHT" and not native.resize:IsShown(), "locked icon occupies corner alone like EUI bags")
ITEM_QUALITY_COLORS = { [2] = { r = 0.1, g = 0.8, b = 0.2 } }
scan[1].items[1].quality = 2
settings.display, settings.groupByCategory = "list", false
EllesmereUI._bagsDB.profile.bagListColumns = nil
ns.Addon.Refresh()
local colored = native.slots[1]
Check(colored.snapshotBorder.color[1] == 1 and colored.snapshotBorder.color[4] == 0.15,
    "List row border stays neutral instead of inheriting item quality")
Check(colored.iconFrame:IsShown() and colored.iconFrame.snapshotBorder.color[1] == 0.1
    and colored.iconFrame.snapshotBorder.color[4] == 0.8, "List item quality border belongs to icon only")
EllesmereUI._bagsDB.profile.bagListColumns = { "name", "count" }
ns.Addon.Refresh()
Check(not colored.iconFrame:IsShown(), "List with no icon column hides its quality border")
for _, mode in ipairs({ "grid", "compact" }) do
    settings.display = mode
    ns.Addon.Refresh()
    Check(not colored.iconFrame:IsShown() and colored.snapshotBorder.color[1] == 0.1,
        "switching to " .. mode .. " restores the existing icon-sized quality border")
end
-- List-only collapse uses stable EUI identities and current profile callbacks.
EUI_CategoryManager = {
    GetCategories = function() return cats end,
    ClassifyItem = function()
        for i, cat in ipairs(cats) do if cat._defaultName == "Trade Goods" then return i end end
    end,
}
settings.display, settings.groupByCategory, settings.collapsedCategories = "list", true, {}
ns.Addon.Refresh()
local categoryHeader = native.headings[1]
Check(categoryHeader.label.text:find("- Materials (", 1, true), "List category header shows expanded indicator and stack count")
categoryHeader.scripts.OnClick(categoryHeader)
Check(settings.collapsedCategories["category:Trade Goods"] and #ns.Layout(entries).slots == 0,
    "click collapses all matching category stacks by stable identity")
Check(categoryHeader.label.text:find("+ Materials (", 1, true) and native.scrollChild:GetHeight() == 20
    and not native.slots[1]:IsShown(), "collapsed category retains clickable heading without empty row space")
cats[1].name = "Renamed Materials"
ns.Addon.Refresh()
Check(categoryHeader.label.text:find("+ Renamed Materials", 1, true), "category rename preserves saved collapse state")
cats[1], cats[5] = cats[5], cats[1]
ns.Addon.Refresh()
Check(not native.slots[1]:IsShown() and native.headings[1].categoryKey == "category:Trade Goods",
    "category reordering preserves collapse by stable identity instead of index")
cats[1], cats[5] = cats[5], cats[1]
native.search:SetText("no-match")
native.headings[1].scripts.OnClick(native.headings[1])
Check(settings.collapsedCategories["category:Trade Goods"], "hidden filtered-out heading cannot toggle saved collapse")
native.search:SetText("")
Check(not native.slots[1]:IsShown(), "search does not erase collapsed-category preference")
native:Hide(); ns.ToggleViewer()
Check(not native.slots[1]:IsShown(), "reopening retains profile category collapse state")
local collapsedProfile = settings
settings = modules.feature.normalize({ showButton = true, display = "list", groupByCategory = true })
ns.Addon.Refresh()
Check(native.slots[1]:IsShown() and not settings.collapsedCategories["category:Trade Goods"],
    "new profile starts independently expanded")
editing = true
native.headings[1].scripts.OnClick(native.headings[1])
Check(not settings.collapsedCategories["category:Trade Goods"], "stale category callbacks honor Edit Mode")
editing = false
local staleHeader = native.headings[1]
settings = collapsedProfile
staleHeader.scripts.OnClick(staleHeader)
Check(settings.collapsedCategories["category:Trade Goods"], "unrefreshed header cannot change newly selected profile")
ns.Addon.Refresh()
for _, mode in ipairs({ "grid", "compact" }) do
    settings.display = mode
    ns.Addon.Refresh()
    Check(native.slots[1]:IsShown() and #ns.Layout(entries).slots == 100, "saved List collapse never hides stacks in " .. mode)
    native.headings[1].scripts.OnClick(native.headings[1])
    Check(settings.collapsedCategories["category:Trade Goods"], "non-List callbacks cannot change collapse preferences")
end
settings.display = "list"
ns.Addon.Refresh()
native.headings[1].scripts.OnClick(native.headings[1])
Check(not settings.collapsedCategories["category:Trade Goods"] and native.slots[1]:IsShown(), "clicking collapsed heading expands its items")
settings.collapsedCategories["category:Trade Goods"] = true
settings.groupByCategory = false
ns.Addon.Refresh()
Check(native.slots[1]:IsShown() and not native.headings[1]:IsShown(), "disabling grouping ignores saved collapse state")
-- Independent viewer scale/strata with scale-correct geometry persistence.
settings = modules.feature.normalize({ showButton = true, windowScale = 1.25, frameStrata = "LOW" })
ns.Addon.Refresh()
Check(native.scale == 1.25 and native.strata == "LOW", "profile window scale and strata apply to viewer")
Check(not EUI_Bags.scale and not ns.BagButton.scale and not ns.BagButton.strata,
    "window appearance leaves EUI bags and attached snapshot button untouched")
modules.options.buildPage(nil, UIParent, 0)
local scaleControl, strataControl
for _, row in ipairs(rows) do if row.text == "Window Scale" then scaleControl = row end end
for _, row in ipairs(rightRows) do if row.text == "Frame Strata" then strataControl = row end end
Check(scaleControl.min == 50 and scaleControl.max == 150 and scaleControl.step == 5 and scaleControl.getValue() == 125,
    "settings exposes matching EUI percentage scale range")
Check(strataControl.getValue() == "LOW" and #strataControl.order == 5, "strata dropdown follows EUI base strata")
editing = true
scaleControl.setValue(150); strataControl.setValue("HIGH")
Check(settings.windowScale == 1.25 and settings.frameStrata == "LOW", "stale scale and strata controls honor Edit Mode")
editing = false
scaleControl.setValue(150); strataControl.setValue("HIGH")
Check(native.scale == 1.5 and native.strata == "HIGH", "settings update visible window appearance immediately")
native.header.scripts.OnDragStart()
native.centerX, native.centerY = 800, 500
native.header.scripts.OnDragStop()
Check(settings.window.x == 200 and settings.window.y == 150, "scaled drag saves offsets in UIParent coordinates")
Check(math.abs(native.point[4] - 200 / 1.5) < 0.001 and native.point[5] == 100,
    "scaled position restoration converts anchor offsets correctly")
scaleControl.setValue(50)
Check(native.point[4] == 400 and native.point[5] == 300 and settings.window.x == 200,
    "scale changes preserve saved window position")
native.resize.scripts.OnMouseDown(native.resize, "LeftButton")
native:SetSize(900, 700)
scaleControl.setValue(100)
Check(not native.sizing and settings.window.width == 620 and native:GetWidth() == 620,
    "scale changes during a gesture cancel unsaved geometry")
strataControl.setValue("INVALID"); scaleControl.setValue(secret)
Check(settings.frameStrata == "HIGH" and settings.windowScale == 1, "invalid strata and secret slider inputs cannot be applied")
local appearanceProfile = settings
settings = modules.feature.normalize({ showButton = true })
ns.Addon.Refresh()
Check(native.scale == 1 and native.strata == "DIALOG", "new profile uses default scale and original viewer strata")
settings = appearanceProfile
ns.Addon.Refresh()
Check(native.strata == "HIGH", "profile switch restores independent strata")
native:Hide(); ns.ToggleViewer()
Check(native.scale == settings.windowScale and native.strata == "HIGH", "reopening retains scale and strata")
local invalidAppearance = modules.feature.normalize({ windowScale = secret, frameStrata = secret })
Check(invalidAppearance.windowScale == 1 and invalidAppearance.frameStrata == "DIALOG",
    "unreadable appearance values safely default")
Check(ns.WindowScale(5) == 1.5 and ns.WindowScale(0.1) == 0.5 and ns.WindowScale(1.23) == 1.25,
    "scale normalization clamps and snaps to five-percent steps")
-- Combined Tabs/Categories sidebar and independent profile-owned collapse state.
settings = modules.feature.normalize({ showButton = true, display = "grid" })
local function SavedItem(id) return { itemID = id, count = 1, link = "item:" .. id } end
ns.DB = { format = 1, characters = { [ns.CharacterKey()] = { tabs = {
    { bagID = 6, name = "Tab One", numSlots = 2, items = { SavedItem(100), SavedItem(200) } },
    { bagID = 7, name = "Tab Two", numSlots = 1, items = { SavedItem(100) } },
} } } }
EUI_CategoryManager = {
    GetCategories = function() return cats end,
    ClassifyItem = function(_, _, id) return id == 100 and 1 or 5 end,
}
ns.Addon.Refresh()
Check(native.tabs[2]:IsShown() and native.categoryButtons[2]:IsShown() and native.tabsTitle.text == "Tabs"
    and native.categoriesTitle.text == "Categories", "both navigation sections visible together")
native.categoryButtons[2].scripts.OnClick(native.categoryButtons[2])
Check(native.total.text == "2 stacks" and native.slots[1].entry.item.itemID == 100, "category filters all selected tabs")
native.tabs[2].scripts.OnClick(native.tabs[2])
Check(native.total.text == "1 stacks" and native.slots[1].entry.tab == "Tab One", "category selection filters within selected bank tab")
native.categoryButtons[3].scripts.OnClick(native.categoryButtons[3])
Check(native.slots[1].entry.item.itemID == 200 and native.total.text == "1 stacks", "category navigation works without grouping")
native.tabs[3].scripts.OnClick(native.tabs[3])
Check(native.slots[1].entry.item.itemID == 100 and native.categoryButtons[1].navIcon.alpha == 1,
    "missing category in new tab returns to All categories")
local widthBeforeCollapse = native.scrollFrame:GetWidth()
native.sidebarToggle.scripts.OnClick()
Check(settings.sidebarCollapsed and native.sidebar:GetWidth() == 32 and not native.tabs[2].label:IsShown()
    and native.tabs[2].navIcon.texture and not native.categoryButtons[2].tip,
    "collapse retains icon-only navigation without category tooltips")
local oldWidgetTooltip, sidebarTips = EllesmereUI.ShowWidgetTooltip, 0
EllesmereUI.ShowWidgetTooltip = function() sidebarTips = sidebarTips + 1 end
for _, button in ipairs(native.categoryButtons) do button.scripts.OnEnter() end
Check(sidebarTips == 0, "sidebar category buttons never show tooltips")
for _, button in ipairs(native.tabs) do button.scripts.OnEnter() end
Check(sidebarTips == 0, "sidebar tab buttons never show tooltips")
EllesmereUI.ShowWidgetTooltip = oldWidgetTooltip
Check(native.scrollFrame:GetWidth() > widthBeforeCollapse and native.scrollFrame.point[2] == 56,
    "collapsed sidebar releases width for item layout")
native:Hide(); ns.ToggleViewer()
Check(settings.sidebarCollapsed and native.tabs[1].navIcon.alpha == 1 and native.categoryButtons[1].navIcon.alpha == 1,
    "reopening remembers sidebar collapse but resets tab/category selection")
local railProfile = settings
settings = modules.feature.normalize({ showButton = true })
ns.Addon.Refresh()
Check(not settings.sidebarCollapsed and native.sidebar:GetWidth() == 145, "new profile starts expanded")
settings = railProfile
ns.Addon.Refresh()
Check(native.sidebar:GetWidth() == 32, "switching profiles restores sidebar collapse")
editing = true
native.sidebarToggle.scripts.OnClick()
native.categoryButtons[2].scripts.OnClick(native.categoryButtons[2])
Check(settings.sidebarCollapsed and native.categoryButtons[1].navIcon.alpha == 1, "sidebar controls honor Edit Mode")
editing = false
local manyCats, manyItems = {}, {}
for i = 1, 35 do
    manyCats[i] = { name = "Category " .. i, _defaultName = "Custom " .. i, icon = i }
    manyItems[i] = SavedItem(100 + i)
end
ns.DB.characters[ns.CharacterKey()].tabs = { { bagID = 6, name = "Many", numSlots = 35, items = manyItems } }
EUI_CategoryManager = { GetCategories = function() return manyCats end,
    ClassifyItem = function(_, _, id) return id - 100 end }
ns.Addon.Refresh()
native.sidebarScroll.scripts.OnMouseWheel(native.sidebarScroll, -100)
Check(native.sidebarScroll:GetVerticalScroll() == native.sidebarScroll:GetVerticalScrollRange()
    and native.sidebarScroll:GetVerticalScroll() > 0, "long sidebar scrolls and clamps within separate clipped region")
native.sidebarToggle.scripts.OnClick()
Check(not settings.sidebarCollapsed and native.tabs[1].label:IsShown(), "expanding restores navigation labels")
-- Use EUI category atlas metadata and its client-specific texture substitutions.
local iconWidget = Widget("Texture")
C_Texture = { GetAtlasInfo = function(name) return name == "category-atlas" and {} or nil end }
EllesmereUI.ClientIcon = function(icon) return icon == 7548911 and 133975 or icon end
ns.PaintCategoryIcon(iconWidget, "category-atlas", true)
Check(iconWidget.atlas == "category-atlas" and iconWidget.coords[1] == 0 and iconWidget.coords[2] == 1,
    "EUI atlas category icons use native atlas rendering without icon crop")
ns.PaintCategoryIcon(iconWidget, 7548911, false)
Check(iconWidget.texture == 133975 and iconWidget.coords[1] == 0.08,
    "texture category icons reuse EUI Forever mapping and crop")
ns.PaintCategoryIcon(iconWidget, "missing-atlas", true)
Check(iconWidget.texture == 134400, "unavailable atlas has safe texture fallback")
local setAtlas = iconWidget.SetAtlas
iconWidget.SetAtlas = nil
ns.PaintCategoryIcon(iconWidget, "category-atlas", true)
Check(iconWidget.texture == 134400, "older client without atlas setter falls back safely")
iconWidget.SetAtlas = setAtlas
manyCats[1].icon, manyCats[1].isAtlas = "category-atlas", true
ns.Addon.Refresh()
Check(native.categoryButtons[2].navIcon.atlas == "category-atlas", "sidebar preserves EUI category atlas flag")
manyCats[1].icon, manyCats[1].isAtlas = 7548911, nil
ns.Addon.Refresh()
Check(native.categoryButtons[2].navIcon.texture == 133975 and native.categoryButtons[1].navIcon.texture == 133633,
    "sidebar matches EUI category and All Items icon values")
-- Character dropdown: verified EUI menu contract and stale-callback guards.
local menuItems, menuOptions, menuAnchor
EllesmereUI.ShowContextMenu = function(anchor, items, options)
    menuAnchor, menuItems, menuOptions = anchor, items, options
end
ns.DB.characters["Dropdown Alt - Realm"] = { tabs = {} }
native.characterDropdown.scripts.OnClick(native.characterDropdown)
Check(menuAnchor == native.characterDropdown and menuOptions.below and menuOptions.minWidth == 364
    and menuItems[1].text == ns.CharacterKey() and menuItems[1].isActive,
    "EUI character dropdown anchors below selector and includes uncaptured current player first")
local altChoice
for _, item in ipairs(menuItems) do if item.text == "Dropdown Alt - Realm" then altChoice = item.onClick end end
Check(altChoice ~= nil, "dropdown includes captured alts by name and realm")
editing = true
altChoice()
Check(native.character.text == ns.CharacterKey(), "already-open character dropdown honors Edit Mode")
editing = false
local menuProfile = settings
settings = modules.feature.normalize({ showButton = true })
altChoice()
Check(native.character.text == ns.CharacterKey(), "stale dropdown cannot select after profile switch")
settings = menuProfile
native:Hide(); ns.ToggleViewer()
altChoice()
Check(native.character.text == ns.CharacterKey(), "reopening invalidates prior character menu callbacks")
native.characterDropdown.scripts.OnClick(native.characterDropdown)
for _, item in ipairs(menuItems) do if item.text == "Dropdown Alt - Realm" then altChoice = item.onClick end end
altChoice()
Check(native.character.text == "Dropdown Alt - Realm", "EUI dropdown directly selects requested alt")
native:Hide(); ns.ToggleViewer()
Check(native.character.text == ns.CharacterKey(), "dropdown preserves current-character opening contract")
EllesmereUI.ShowContextMenu = nil
native.characterDropdown.scripts.OnClick(native.characterDropdown)
Check(native.characterMenu:IsShown(), "older EUI offers addon-owned character dropdown")
native.characterDropdown.scripts.OnClick(native.characterDropdown)
Check(not native.characterMenu:IsShown(), "fallback selector toggles menu closed")
-- Optional snapshot counts: combined quantities by ID, never live inventory.
settings = modules.feature.normalize({ showButton = true })
native:Hide()
local function CountItem(id, count, link) return { itemID = id, count = count, link = link or ("item:" .. id) } end
local function CountTab(id, items) return { bagID = id, name = "Saved bank", numSlots = 10, items = items } end
ns.DB = { format = 1, characters = {
    [ns.CharacterKey()] = { tabs = { CountTab(6, { CountItem(100, 2), CountItem(100, 3, "item:100:variant") }) } },
    ["Count Alt - Realm"] = { tabs = { CountTab(6, { CountItem(100, 4), CountItem(101, 9) }),
        CountTab(-3, { [5] = CountItem(100, 7) }) } },
    ["Empty - Realm"] = { tabs = {} },
    ["Broken - Realm"] = { tabs = { CountTab(6, { CountItem(100, secret) }) } },
} }
Check(ns.BankSnapshotCount(100) == 16 and ns.BankSnapshotCount(101) == 9,
    "snapshot totals combine stack quantities and item variants across characters and reagent storage")
Check(ns.BankSnapshotCount(999) == 0 and ns.BankSnapshotCount(secret) == 0 and ns.BankSnapshotCount(-1) == 0,
    "missing stock and unreadable/invalid item IDs add no counts")
local inventoryReads = 0
C_Container.GetContainerItemInfo = function() inventoryReads = inventoryReads + 1; error("no live reads for tooltip totals") end
Check(ns.BankSnapshotCount(100) == 16 and inventoryReads == 0, "totals use saved snapshots outside bank access")
ns.DB.bags = { [ns.CharacterKey()] = { preservedCarriedData = true } }
local savedBagData = ns.DB.bags
ns.DB.classes = { [ns.CharacterKey()] = "MAGE", ["Count Alt - Realm"] = "WARRIOR" }
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
Check(not ns.ScanBags and not ns.CaptureBags and not ns.InventoryEventFrame,
    "bank-only tooltip design has no carried-bag scanner, captures or polling frame")
local countControl
rows, rightRows = {}, {}
modules.options.buildPage("Bank Snapshot", {}, 0)
for _, row in ipairs(rightRows) do if row.text == "Show bank stock in tooltips" then countControl = row end end
Check(countControl and not countControl.getValue() and countControl.tooltip:find("outdated", 1, true),
    "optional tooltip control is discoverable, off by default and explains snapshot freshness")
editing = true; countControl.setValue(true)
Check(not settings.tooltipBankCounts, "new count toggle honors Edit Mode")
editing = false
local countProfile = settings
settings = modules.feature.normalize({ showButton = true })
countControl.setValue(true)
Check(not settings.tooltipBankCounts, "stale count toggle cannot mutate another profile")
settings = countProfile
countControl.setValue(secret)
Check(not settings.tooltipBankCounts, "count toggle rejects secret booleans")

GameTooltip = Widget("GameTooltip")
GameTooltip.lines = {}
function GameTooltip:SetOwner(owner) self.owner = owner end
function GameTooltip:GetOwner() return self.owner end
function GameTooltip:GetItem() return "Saved item", self.link end
function GameTooltip:AddLine(text, r, g, b) self.lines[#self.lines + 1] = text; self.colors[#self.lines] = { r, g, b } end
function GameTooltip:AddDoubleLine(left, right, r, g, b, rr, rg, rb)
    self.lines[#self.lines + 1] = left .. ": " .. right
    self.colors[#self.lines] = { r, g, b, rr, rg, rb }
end
function GameTooltip:SetHyperlink(link) self.link = link end
local function ClearCountTip(owner, link)
    GameTooltip.lines, GameTooltip.colors, GameTooltip.owner, GameTooltip.link = {}, {}, owner, link or "item:100"
    for _, hook in ipairs(GameTooltip.hooks.OnTooltipCleared or {}) do hook(GameTooltip) end
end
local bagParent = Widget("Frame", nil, EUI_Bags)
local bagItem = Widget("Button", nil, bagParent)
function bagParent:GetParent() return self.parent end
function bagItem:GetParent() return self.parent end
TooltipDataProcessor = nil
ns.InstallCountTooltips(); ns.InstallCountTooltips()
Check(#GameTooltip.hooks.OnTooltipCleared == 1 and #GameTooltip.hooks.OnTooltipSetItem == 1,
    "legacy tooltip hooks install once without altering item buttons")
local legacyHook = GameTooltip.hooks.OnTooltipSetItem[1]
ClearCountTip(bagItem)
legacyHook(GameTooltip)
Check(#GameTooltip.lines == 0, "default-off tooltip feature adds no bank stock lines")
countControl.setValue(true)
legacyHook(GameTooltip); legacyHook(GameTooltip)
Check(#GameTooltip.lines == 4 and GameTooltip.lines[2] == "Bank stock (snapshots)"
    and GameTooltip.lines[3] == "Current bank: 5" and GameTooltip.lines[4] == "Other banks: 11",
    "Forever legacy bag tooltip shows compact positive current/other bank stock")
Check(GameTooltip.colors[2][1] == 1 and GameTooltip.colors[3][1] ~= GameTooltip.colors[4][1]
    and GameTooltip.colors[3][4] == 1, "gold heading, varied muted labels and bright counts separate the tooltip visually")
ClearCountTip(bagItem, "item:999"); legacyHook(GameTooltip)
Check(#GameTooltip.lines == 0, "zero stock has no tooltip line")
ClearCountTip(bagItem, secret); legacyHook(GameTooltip)
Check(#GameTooltip.lines == 0, "secret legacy link fails closed")
local originalGetItem = GameTooltip.GetItem
GameTooltip.GetItem = function() error("restricted") end
legacyHook(GameTooltip)
Check(#GameTooltip.lines == 0, "throwing legacy getter fails closed")
GameTooltip.GetItem = originalGetItem

local postHook, postInstalls = nil, 0
Enum.TooltipDataType = { Item = 0 }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, callback)
    Check(kind == 0, "Retail registers only item tooltip processing")
    postHook, postInstalls = callback, postInstalls + 1
end }
ns.InstallCountTooltips(); ns.InstallCountTooltips()
Check(postInstalls == 1, "Retail item processor installs only once")
ClearCountTip(bagItem)
postHook(GameTooltip, { id = 100 }); legacyHook(GameTooltip); postHook(GameTooltip, { id = 100 })
Check(#GameTooltip.lines == 4, "Retail processing and old fallback never duplicate four stock rows")
ClearCountTip(bagItem)
postHook(GameTooltip, { id = secret }); postHook(GameTooltip, secret); postHook(GameTooltip, nil)
Check(#GameTooltip.lines == 0, "secret and missing Retail item data fail closed without guessing")
for _, owner in ipairs({ UIParent, Widget("Button", nil, UIParent) }) do
    ClearCountTip(owner)
    postHook(GameTooltip, { id = 100 })
    Check(#GameTooltip.lines == 0, "non-bag tooltip owner is excluded")
end
ClearCountTip(bagItem)
local comparison = Widget("GameTooltip")
comparison.owner = bagItem; comparison.lines = {}
comparison.colors = {}
comparison.GetOwner, comparison.AddLine = GameTooltip.GetOwner, GameTooltip.AddLine
postHook(comparison, { id = 100 })
Check(#comparison.lines == 0, "shopping/comparison tooltip is excluded even with bag ownership")
local originalOwner = GameTooltip.GetOwner
GameTooltip.GetOwner = function() return secret end
postHook(GameTooltip, { id = 100 })
Check(#GameTooltip.lines == 0, "secret tooltip owner fails closed")
GameTooltip.GetOwner = originalOwner
native:Show()
ClearCountTip(native.slots[1])
native.slots[1].scripts.OnEnter(native.slots[1])
Check(GameTooltip.lines[3] == ns.CharacterKey() .. " (you): 5" and GameTooltip.lines[4] == "Count Alt - Realm: 11",
    "snapshot viewer lists named bank stock with current character first")
Check(GameTooltip.colors[3][1] == RAID_CLASS_COLORS.MAGE.r and GameTooltip.colors[4][1] == RAID_CLASS_COLORS.WARRIOR.r,
    "current player and alts use their saved class colours")
Check(#GameTooltip.lines == 4, "snapshot item tooltip has stock rows without tab/slot or read-only footer text")
local beforePost = #GameTooltip.lines
postHook(GameTooltip, { id = 100 })
Check(#GameTooltip.lines == beforePost, "global hook does not duplicate snapshot viewer's explicit count")
countControl.setValue(false)
Check(not GameTooltip:IsShown(), "disabling counts removes already-visible added stock via tooltip dismissal")
ClearCountTip(native.slots[1])
native.slots[1].scripts.OnEnter(native.slots[1])
Check(#GameTooltip.lines == 0, "disabled stock counts leave snapshot item tooltip with native item content only")
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
Check(#GameTooltip.lines == 0, "disable takes effect in existing native callbacks")
settings.tooltipBankCounts = true
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
Check(#GameTooltip.lines == 4, "count enabled for updated snapshot test")
ns.DB.characters["Count Alt - Realm"].tabs[1].items[1].count = 14
ns.InvalidateBankCounts()
ns.Addon.Refresh()
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
Check(GameTooltip.lines[4] == "Count Alt - Realm: 21", "updated bank snapshots rebuild cached named counts")
native:Hide()
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
Check(GameTooltip.lines[3] == "Current bank: 5" and GameTooltip.lines[4] == "Other banks: 21",
    "closing snapshot viewer returns bag tooltips to compact rows")
ns.DB.characters[ns.CharacterKey()] = nil
ns.InvalidateBankCounts()
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
Check(#GameTooltip.lines == 3 and GameTooltip.lines[3] == "Other banks: 21", "missing own bank omits the current bank row")
ns.DB.characters[ns.CharacterKey()] = { tabs = { CountTab(6, { CountItem(100, 5) }) } }
ns.DB.characters["Count Alt - Realm"] = { tabs = {} }
ns.InvalidateBankCounts()
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
Check(#GameTooltip.lines == 3 and GameTooltip.lines[3] == "Current bank: 5", "zero other-bank stock omits the other banks row")
local ownSnapshot = ns.DB.characters[ns.CharacterKey()]
ns.DB.characters[ns.CharacterKey()] = { tabs = {} }
ns.InvalidateBankCounts()
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
Check(#GameTooltip.lines == 0, "no stock in any captured bank adds no heading or rows")
ns.DB.characters[ns.CharacterKey()] = ownSnapshot
ns.DB.characters["Count Alt - Realm"] = { tabs = { CountTab(6, { CountItem(100, 11) }) } }
ns.InvalidateBankCounts()
EUI_ReagentBagFrame = Widget("Frame", nil, UIParent)
local detached = Widget("Button", nil, EUI_ReagentBagFrame)
function detached:GetParent() return self.parent end
ClearCountTip(detached); postHook(GameTooltip, { id = 100 })
Check(GameTooltip.lines[4] == "Other banks: 11", "detached EUI reagent-bag tooltips use bank-only compact stock")
EUI_BankFrame = Widget("Frame", nil, UIParent)
local bankItem = Widget("Button", nil, EUI_BankFrame)
function bankItem:GetParent() return self.parent end
ClearCountTip(bankItem); postHook(GameTooltip, { id = 100 })
Check(GameTooltip.lines[3] == ns.CharacterKey() .. " (you): 5" and GameTooltip.lines[4] == "Count Alt - Realm: 11",
    "live EUI bank item tooltips show named stock without actionable item overrides")
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
Check(GameTooltip.lines[4] == "Count Alt - Realm: 11", "bag tooltips use named character rows while live bank window is open")
EUI_BankFrame:Hide()
ns.BankOpen = true
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
Check(GameTooltip.lines[4] == "Count Alt - Realm: 11", "bank access event supports named mode before EUI bank shows")
ns.BankOpen = false
ns.DB.classes["Count Alt - Realm"] = nil
ClearCountTip(bankItem); postHook(GameTooltip, { id = 100 })
Check(GameTooltip.colors[4][1] == 0.75, "missing alt class information uses neutral colour without guessing")
function UnitClass() return "Mage", "MAGE", 8 end
ns.RememberCharacterClass()
Check(ns.DB.classes[ns.CharacterKey()] == "MAGE", "login/capture metadata can learn current class independently from bank inventory")
UnitClass = function() return "Restricted", secret, secret end
ns.RememberCharacterClass()
Check(ns.DB.classes[ns.CharacterKey()] == "MAGE", "secret class token cannot overwrite saved readable metadata")
UnitClass = function() error("restricted") end
ns.RememberCharacterClass()
Check(ns.DB.classes[ns.CharacterKey()] == "MAGE", "throwing class getter preserves latest readable class metadata")
UnitClass = function() return "Mage", "MAGE", 8 end
C_ClassColor = { GetClassColor = function() return { r = secret, g = 0.5, b = 0.5 } end }
ClearCountTip(bankItem); postHook(GameTooltip, { id = 100 })
Check(GameTooltip.colors[3][1] == 0.75, "unreadable native class colour is never compared or formatted")
C_ClassColor = nil
local originalValidation, validations = ns.ValidSnapshot, 0
ns.ValidSnapshot = function(snapshot) validations = validations + 1; return originalValidation(snapshot) end
ns.InvalidateBankCounts()
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
local firstValidations = validations
for _ = 1, 20 do ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 }) end
Check(firstValidations > 0 and validations == firstValidations, "repeated tooltip hovers reuse item index without revalidating every inventory")
settings.tooltipBankCounts = false
ns.RefreshCountTooltips()
settings.tooltipBankCounts = true
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
Check(validations > firstValidations, "disabling releases cached bank index, rebuilt lazily on re-enable")
ns.ValidSnapshot = originalValidation
local originalScan = ns.Scan
ns.Scan = function() return ns.DB.characters[ns.CharacterKey()].tabs end
ns.Pending, ns.CapturedThisVisit, ns.BankOpen = nil, false, true
ns.DB.characters[ns.CharacterKey()].tabs[1].items[1].count = 15
Check(not ns.Capture() and ns.Capture() and ns.BankSnapshotCount(100) == 26,
    "successful bank capture automatically invalidates the tooltip count index")
ns.Scan, ns.BankOpen = originalScan, false
local doubleLine = GameTooltip.AddDoubleLine
GameTooltip.AddDoubleLine = nil
ClearCountTip(bankItem); postHook(GameTooltip, { id = 100 })
Check(GameTooltip.lines[4]:find("Count Alt - Realm", 1, true) and GameTooltip.lines[4]:find("|cffffebb8", 1, true),
    "older tooltip without double-line support keeps coloured labels and bright counts")
GameTooltip.AddDoubleLine = doubleLine
local oldPlayer = player
player = secret
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
Check(#GameTooltip.lines == 0, "unreadable current identity cannot misclassify current versus other stock")
player = oldPlayer
Check(ns.DB.bags == savedBagData and ns.DB.bags[oldPlayer .. " - Realm"].preservedCarriedData,
    "stopping bag capture preserves old stored carried data without counting or deleting it")
ns.DB = nil
ClearCountTip(bagItem); postHook(GameTooltip, { id = 100 })
Check(#GameTooltip.lines == 0, "unsupported/missing snapshot database has no tooltip count")
Check(inventoryReads == 0, "bank-stock tooltip hovers never query live bag or bank containers")
print("PASS: " .. checks .. " Bags capture, capability, read-only viewer and UI checks")
