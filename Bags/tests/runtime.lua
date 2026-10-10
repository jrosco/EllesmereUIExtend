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
    SetWordWrap = Noop, SetTexCoord = Noop, Raise = Noop, ClearFocus = Noop }
local function Widget(kind, name, parent, template)
    Check(template == nil, "no secure/container templates")
    local f = { kind = kind, name = name, parent = parent, scripts = {}, events = {}, shown = true,
        hooks = {}, text = "" }
    setmetatable(f, { __index = methods })
    function f:SetScript(event, callback) self.scripts[event] = callback end
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
    function f:SetTexture(texture) self.texture = texture end
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
local rows = {}
EllesmereUI = { IsUnlockModeActive = function() return editing end, Widgets = {
    SectionHeader = function() return {}, 30 end,
    DualRow = function(_, _, _, left) rows[#rows + 1] = left; return {}, 40 end,
} }
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
for _, file in ipairs({ "Compatibility", "Bags", "Snapshot", "Viewer", "Options" }) do
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
Event("PLAYER_REGEN_ENABLED")
Check(ns.BagButton and ns.BagButton.parent == EUI_Bags, "button attached to actual EUI bag frame")
ns.Addon.Refresh(); ns.Addon.Refresh()
Check(#EUI_Bags.hooks.OnShow == 1, "one native OnShow hook")
ns.BagButton.scripts.OnClick()
local viewer = EllesmereUIExtendBagsViewer
Check(viewer and viewer:IsShown(), "bag button opens separate viewer")
local slots = {}
for _, frame in ipairs(frames) do
    if frame.parent == viewer and frame.icon then
        slots[#slots + 1] = frame
        Check(frame.scripts.OnClick == nil and frame.scripts.OnDragStart == nil, "snapshot icon has no item action")
    end
end
Check(#slots == 80 and slots[1].entry, "bounded snapshot grid renders stored items")
slots[1].scripts.OnEnter(slots[1])
Check(tooltips == 1, "stored-link tooltip shown")
viewer.previousCharacter.scripts.OnClick()
Check(viewer.character.text ~= "Fallback - Realm", "character selector changes snapshot")
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
-- Walk selector to Alt deterministically.
for _ = 1, 3 do
    if viewer.character.text == "Alt - Realm" then break end
    viewer.nextCharacter.scripts.OnClick()
end
ns.RefreshViewer()
Check(viewer.nextPage.enabled, "large banks have pagination")
viewer.nextPage.scripts.OnClick()
Check(slots[20]:IsShown() and not slots[21]:IsShown(), "last page hides unused pooled icons")
EllesmereUIExtendBagsDB = { format = 99, characters = {} }
ns.InitializeDB()
Check(ns.DB == nil and EllesmereUIExtendBagsDB.format == 99, "unsupported DB preserved, not migrated")
ns.RefreshViewer()
Check(viewer.message.text:find("unsupported", 1, true), "unsupported DB explains unavailable storage")
EllesmereUIExtendBagsDB = { format = 1, characters = { Broken = { tabs = { { bagID = 6 } } } } }
ns.InitializeDB()
Check(#ns.Characters() == 0, "malformed saved records ignored without deleting them")
ns.RefreshViewer()
Check(viewer.message.text == "Visit a banker to create a snapshot.", "malformed records cannot break viewer")
print("PASS: " .. checks .. " Bags capture, capability, read-only viewer and UI checks")
