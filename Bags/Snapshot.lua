local _, ns = ...
if not ns.Addon then return end
local MAX_SLOTS = 1000

function ns.InitializeDB()
    ns.DB = nil
    local db = EllesmereUIExtendBagsDB
    if db == nil then db = { format = 1, characters = {} }; EllesmereUIExtendBagsDB = db end
    -- Unsupported data is preserved, not silently migrated or overwritten.
    if type(db) == "table" and db.format == 1 and type(db.characters) == "table" then ns.DB = db end
    if ns.InvalidateBankCounts then ns.InvalidateBankCounts() end
    if ns.InvalidateBagCounts then ns.InvalidateBagCounts() end
    if ns.RememberCharacterClass then ns.RememberCharacterClass() end
end

local function Integer(value, min, max)
    value = ns.Number(value)
    return value and value >= min and value <= max and value % 1 == 0 and value or nil
end
local function Equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

function ns.ValidSnapshot(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.tabs) ~= "table" or #snapshot.tabs > 10 then return false end
    if snapshot.updatedAt ~= nil and not Integer(snapshot.updatedAt, 0, 9007199254740990) then return false end
    local seen = {}
    for _, tab in ipairs(snapshot.tabs) do
        if type(tab) ~= "table" or not ns.Number(tab.bagID) or seen[tab.bagID]
            or not ns.String(tab.name) or not Integer(tab.numSlots, 1, MAX_SLOTS)
            or type(tab.items) ~= "table" then return false end
        seen[tab.bagID] = true
        for slot, item in pairs(tab.items) do
            if not Integer(slot, 1, tab.numSlots) or type(item) ~= "table"
                or not Integer(item.itemID, 1, 2147483647) or not Integer(item.count, 1, 2147483647)
                or not ns.String(item.link) then return false end
            if item.icon ~= nil and not ns.Number(item.icon) and not ns.String(item.icon) then return false end
            if item.quality ~= nil and not Integer(item.quality, 0, 8) then return false end
            if item.setID ~= nil and not Integer(item.setID, 0, 2147483647) then return false end
            for _, field in ipairs({ "quest", "bound" }) do
                if ns.Secret(item[field]) or (item[field] ~= nil and type(item[field]) ~= "boolean") then return false end
            end
        end
    end
    return true
end

local function Discover()
    local indices = Enum and Enum.BagIndex
    if not indices or not C_Container or type(C_Container.GetContainerNumSlots) ~= "function"
        or type(C_Container.GetContainerItemInfo) ~= "function" then return end
    local tabs, seen = {}, {}
    local function Add(id, name, required)
        id = ns.Number(id)
        if not id or seen[id] then return true end
        local slots = Integer(ns.Read(C_Container.GetContainerNumSlots, id), 0, MAX_SLOTS)
        if not slots or (required and slots == 0) then return false end
        if slots > 0 then
            seen[id] = true
            tabs[#tabs + 1] = { bagID = id, name = name, numSlots = slots, items = {} }
        end
        return true
    end
    local bankType = Enum.BankType and Enum.BankType.Character
    local metadata
    if C_Bank and type(C_Bank.FetchPurchasedBankTabData) == "function" and bankType ~= nil then
        local data, ok = ns.Read(C_Bank.FetchPurchasedBankTabData, bankType)
        if not ok then return end
        -- Retail promises an array: nil means unavailable, not permission to
        -- invent a partial tab list. EUI's custom Forever adapter allows nil.
        local host = ns.GetHost()
        if data == nil and not (host and host.IS_FOREVER) then return end
        metadata = data
    end
    if metadata ~= nil then
        local data = metadata
        if type(data) ~= "table" or #data == 0 or #data > 9 then return end
        for i, tab in ipairs(data) do
            if ns.Secret(tab) or type(tab) ~= "table" then return end
            local id = indices["CharacterBankTab_" .. i]
            if ns.Number(id) == nil or not Add(id, ns.String(tab.name) or ("Bank Tab " .. i), true) then return end
        end
    else
        for i = 1, 9 do
            if not Add(indices["CharacterBankTab_" .. i], "Bank Tab " .. i, false) then return end
        end
        -- Capability-only fallback for older clients that still expose bank bag enums.
        if #tabs == 0 then
            if not Add(indices.Bank, "Bank", true) then return end
            for i = 1, 7 do
                if not Add(indices["BankBag_" .. i], "Bank Bag " .. i, false) then return end
            end
        end
    end
    local reagent = indices.Reagentbank or indices.ReagentBank
    if not Add(reagent, "Reagent Storage", false) then return end
    if #tabs == 0 then return end
    -- Enum-only discovery cannot distinguish an unavailable tab from a removed one.
    -- Do not drop previously captured storage on an incomplete fallback scan.
    local key = ns.CharacterKey()
    local previous = ns.DB and key and ns.DB.characters[key]
    if metadata == nil and ns.ValidSnapshot(previous) then
        for _, tab in ipairs(previous.tabs) do if not seen[tab.bagID] then return end end
    end
    return tabs
end

local function ScanTabs(tabs)
    local manager = EUI_CategoryManager
    local lookup = manager and ns.Read(manager.GetSetGearLookup, manager)
    for _, tab in ipairs(tabs) do
        for slot = 1, tab.numSlots do
            local info, ok = ns.Read(C_Container.GetContainerItemInfo, tab.bagID, slot)
            if not ok then return end
            if info ~= nil then
                if type(info) ~= "table" then return end
                local id = Integer(info.itemID, 1, 2147483647)
                local count = Integer(info.stackCount, 1, 2147483647)
                if not id or not count then return end
                local link = ns.String(info.hyperlink)
                if not link and type(C_Container.GetContainerItemLink) == "function" then
                    link = ns.String(ns.Read(C_Container.GetContainerItemLink, tab.bagID, slot))
                end
                -- A missing link can mean item data is still loading; retain the last snapshot.
                if not link then return end
                tab.items[slot] = { itemID = id, count = count, link = link,
                    icon = ns.Number(info.iconFileID) or ns.String(info.iconFileID),
                    quality = Integer(info.quality, 0, 8) }
                local item = tab.items[slot]
                if not ns.Secret(info.isBound) and type(info.isBound) == "boolean" then item.bound = info.isBound end
                local quest = ns.Read(C_Container.GetContainerItemQuestInfo, tab.bagID, slot)
                if type(quest) == "table" then
                    if not ns.Secret(quest.isQuestItem) and quest.isQuestItem == true then item.quest = true end
                    if ns.Number(quest.questID) then item.quest = true end
                end
                if type(lookup) == "table" then item.setID = Integer(lookup[tab.bagID * 1000 + slot], 0, 2147483647) end
            end
        end
    end
    return tabs
end

function ns.Scan()
    if not ns.CanCapture() then return end
    local tabs = Discover()
    if tabs then return ScanTabs(tabs) end
end

function ns.AltBagsEnabled()
    local settings = ns.Addon.Settings()
    return ns.GetHost() and settings and not ns.Secret(settings.altBagsEnabled) and settings.altBagsEnabled == true
end

function ns.InventoryAvailable()
    local indices = Enum and Enum.BagIndex
    if not indices or not C_Container or type(C_Container.GetContainerNumSlots) ~= "function"
        or type(C_Container.GetContainerItemInfo) ~= "function" then return false end
    local seen = {}
    for _, field in ipairs({ "Backpack", "Bag_1", "Bag_2", "Bag_3", "Bag_4" }) do
        local id = ns.Number(indices[field])
        if not id or seen[id] then return false end
        seen[id] = true
    end
    return true
end

-- Inventory is a new, independent section. Never import or overwrite historical
-- db.bags data, and leave unsupported sections/database formats untouched.
function ns.Snapshot(source, key)
    local store
    if ns.DB then
        if source == "bags" then store = ns.DB.inventories else store = ns.DB.characters end
    end
    local snapshot = type(store) == "table" and key and store[key]
    if ns.ValidSnapshot(snapshot) then return snapshot end
end

function ns.ScanBags()
    if not ns.AltBagsEnabled() or not ns.InventoryAvailable() or not ns.DB
        or (ns.DB.inventories ~= nil and type(ns.DB.inventories) ~= "table") then return end
    local indices = Enum and Enum.BagIndex
    local tabs, seen = {}, {}
    for _, field in ipairs({ "Backpack", "Bag_1", "Bag_2", "Bag_3", "Bag_4", "ReagentBag" }) do
        local id = ns.Number(indices[field])
        if not id and field ~= "ReagentBag" then return end
        if id and not seen[id] then
            seen[id] = true
            local slots = Integer(ns.Read(C_Container.GetContainerNumSlots, id), 0, MAX_SLOTS)
            if not slots or (field == "Backpack" and slots == 0) then return end
            if slots > 0 then
                tabs[#tabs + 1] = { bagID = id, name = field == "Backpack" and "Backpack"
                    or (field == "ReagentBag" and "Reagent Bag" or ("Bag " .. field:sub(-1))), numSlots = slots, items = {} }
            end
        end
    end
    return ScanTabs(tabs)
end

local inventoryFrame, inventoryEnabled, inventoryPending, inventoryElapsed, inventoryAge
function ns.StopInventoryCapture()
    inventoryPending = nil
    if inventoryFrame then inventoryFrame:SetScript("OnUpdate", nil) end
end
function ns.CaptureBags()
    local key = ns.CharacterKey()
    if not key then inventoryPending = nil; return false end
    local tabs = ns.ScanBags()
    if not tabs then inventoryPending = nil; return false end
    if not inventoryPending or not Equal(inventoryPending, tabs) then inventoryPending = tabs; return false end
    ns.StopInventoryCapture()
    ns.DB.inventories = ns.DB.inventories or {}
    ns.DB.inventories[key] = { tabs = tabs, updatedAt = Integer(ns.Read(GetServerTime), 0, 9007199254740990) }
    ns.InvalidateBagCounts()
    ns.RememberCharacterClass()
    ns.Addon.Refresh()
    return true
end
function ns.RequestInventoryCapture()
    if not ns.AltBagsEnabled() or not ns.InventoryAvailable() or not ns.DB
        or (ns.DB.inventories ~= nil and type(ns.DB.inventories) ~= "table") then ns.StopInventoryCapture(); return end
    if not inventoryFrame then
        inventoryFrame = CreateFrame("Frame")
        ns.InventoryEventFrame = inventoryFrame
    end
    inventoryPending, inventoryElapsed, inventoryAge = nil, 0, 0
    inventoryFrame:SetScript("OnUpdate", function(_, delta)
        if not ns.AltBagsEnabled() then ns.StopInventoryCapture(); return end
        inventoryElapsed, inventoryAge = inventoryElapsed + delta, inventoryAge + delta
        if inventoryAge > 8 then ns.StopInventoryCapture(); return end
        if inventoryElapsed >= 0.25 then inventoryElapsed = 0; ns.CaptureBags() end
    end)
end
function ns.RefreshInventoryCapture()
    local enabled = ns.AltBagsEnabled() == true
    if enabled ~= inventoryEnabled then
        inventoryEnabled = enabled
        if enabled then ns.RequestInventoryCapture() else ns.StopInventoryCapture(); ns.InvalidateBagCounts() end
    end
end

function ns.Capture()
    if not ns.DB then return false end
    local key = ns.CharacterKey()
    if not key then return false end
    local tabs = ns.Scan()
    if not tabs then ns.Pending = nil; return false end
    -- Avoid replacing good data with a partially loaded/transient opening scan.
    if not ns.Pending or not Equal(ns.Pending, tabs) then ns.Pending = tabs; return false end
    local previous = ns.DB.characters[key]
    if ns.ValidSnapshot(previous) and Equal(previous.tabs, tabs) and ns.CapturedThisVisit then return false end
    local at = Integer(ns.Read(GetServerTime), 0, 9007199254740990)
    ns.DB.characters[key] = { tabs = tabs, updatedAt = at }
    ns.InvalidateBankCounts()
    ns.RememberCharacterClass()
    ns.CapturedThisVisit = true
    ns.Addon.Refresh() -- Refresh the viewer and current-character first-visit tooltip.
    return true
end

function ns.Characters(source)
    local keys, seen = {}, {}
    if ns.DB then
        local stores = { source == "bags" and (ns.DB.inventories or {}) or ns.DB.characters }
        if source == "all" then stores[#stores + 1] = ns.DB.inventories or {} end
        for _, store in ipairs(stores) do
            if type(store) == "table" then
                for key, snapshot in pairs(store) do
                    if ns.String(key) and not seen[key] and ns.ValidSnapshot(snapshot) then
                        keys[#keys + 1], seen[key] = key, true
                    end
                end
            end
        end
    end
    table.sort(keys)
    return keys
end

local indexes, indexedDBs = {}, {}
function ns.InvalidateBankCounts() indexes.bank, indexedDBs.bank = nil, nil end
function ns.InvalidateBagCounts() indexes.bags, indexedDBs.bags = nil, nil end
function ns.RememberCharacterClass()
    local key = ns.CharacterKey()
    if not key or not ns.DB or type(UnitClass) ~= "function" then return end
    local ok, _, token = pcall(UnitClass, "player")
    token = ok and ns.String(token) or nil
    if not token then return end
    if ns.DB.classes ~= nil and type(ns.DB.classes) ~= "table" then return end
    ns.DB.classes = ns.DB.classes or {}
    ns.DB.classes[key] = token
end
function ns.Stock(source, itemID)
    itemID = Integer(itemID, 1, 2147483647)
    if not itemID or not ns.DB then return end
    local store
    if source == "bags" then store = ns.DB.inventories else store = ns.DB.characters end
    if type(store) ~= "table" then return end
    if not indexes[source] or indexedDBs[source] ~= ns.DB then
        indexes[source], indexedDBs[source] = {}, ns.DB
        local index = indexes[source]
        local keys = {}
        for key in pairs(store) do if ns.String(key) then keys[#keys + 1] = key end end
        table.sort(keys)
        -- Build once on demand after load/capture. Hovers subsequently read only
        -- this item-ID index, never live bags or every stored inventory again.
        for _, key in ipairs(keys) do
            local snapshot = store[key]
            local valid, ok = ns.Read(ns.ValidSnapshot, snapshot)
            if ok and valid == true then
                local counts = {}
                for _, tab in ipairs(snapshot.tabs) do
                    for _, item in pairs(tab.items) do counts[item.itemID] = (counts[item.itemID] or 0) + item.count end
                end
                for id, count in pairs(counts) do
                    local entry = index[id] or { total = 0, characters = {} }
                    index[id] = entry
                    entry.total = entry.total + count
                    entry.characters[#entry.characters + 1] = { key = key, count = count }
                end
            end
        end
    end
    local entry = indexes[source][itemID]
    if entry and entry.total <= 9007199254740990 then return entry end
end
function ns.BankStock(itemID) return ns.Stock("bank", itemID) end
function ns.BagStock(itemID) return ns.Stock("bags", itemID) end
function ns.BankSnapshotCount(itemID)
    local entry = ns.BankStock(itemID)
    return entry and entry.total or 0
end

function ns.Items(snapshot, tabID, query)
    local items = {}
    query = (query or ""):lower()
    if type(snapshot) ~= "table" or type(snapshot.tabs) ~= "table" then return items end
    for _, tab in ipairs(snapshot.tabs) do
        if tabID == nil or tab.bagID == tabID then
            for slot = 1, tab.numSlots do
                local item = tab.items[slot]
                if item then
                    local name = ns.String(ns.Read(C_Item and C_Item.GetItemInfo or GetItemInfo, item.link))
                    local text = (name or item.link):lower()
                    if query == "" or text:find(query, 1, true) or tostring(item.itemID):find(query, 1, true) then
                        items[#items + 1] = { item = item, tab = tab.name, slot = slot }
                    end
                end
            end
        end
    end
    return items
end
