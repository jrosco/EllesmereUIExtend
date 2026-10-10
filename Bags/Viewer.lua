local _, ns = ...
if not ns.Addon then return end
local viewer, selectedCharacter, currentCharacter, selectedTab = nil, nil, nil, nil
local resetScroll = true
local function ViewHeight(f) return math.max(1, f:GetHeight() - 180) end
local function WindowSettings()
    return ns.Addon.Settings().window or { width = 620, height = 510, x = 0, y = 0, locked = false }
end
local DISPLAY_ORDER = { "match", "grid", "compact", "list" }
local DISPLAY_NAMES = { match = "Match EUI bank", grid = "Grid", compact = "Compact", list = "List" }
local function EUIProfile()
    return (EllesmereUI and EllesmereUI._bagsDB and EllesmereUI._bagsDB.profile) or {}
end
function ns.DisplayMode()
    local mode = ns.Addon.Settings().display
    if mode == "grid" or mode == "compact" or mode == "list" then return mode end
    local profile = EUIProfile()
    if profile.bankListView == true then return "list" end
    return profile.bankCompactView == true and "compact" or "grid"
end
local function Category(item, cats, manager)
    local assignments = EllesmereUIDB and EllesmereUIDB.bagItemAssignments
    local assigned = assignments and assignments[item.itemID]
    for i, cat in ipairs(cats) do
        if assigned and cat._defaultName == assigned then return i end
    end
    for i, cat in ipairs(cats) do
        if cat.itemIDs and cat.itemIDs[item.itemID] then return i end
    end
    if item.quest then
        local questClass = Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12
        for i, cat in ipairs(cats) do
            for _, class in ipairs(cat.types or {}) do if class == questClass then return i end end
        end
    end
    if item.quality == 0 then
        for i, cat in ipairs(cats) do if cat.isJunk then return i end end
    end
    if item.quality ~= 0 and item.setID then
        if selectedCharacter == ns.CharacterKey() then
            for i, cat in ipairs(cats) do if cat.isEquipSet and cat.equipSetID == item.setID then return i end end
        end
        for i, cat in ipairs(cats) do if cat.isSetGear and not cat.isEquipSet then return i end end
    end
    -- Never pass stored bag/slot coordinates to a classifier querying live containers.
    local index = manager and ns.Number(ns.Read(manager.ClassifyItem, manager, item.link, item.itemID, nil, nil, item.quality))
    if index and cats[index] then return index end
    for i, cat in ipairs(cats) do if cat.isCatchAll then return i end end
    return 0
end
local COLUMN_NAMES = { icon = "", name = "Name", ilvl = "iLvl", reqlvl = "Req", type = "Type",
    bind = "Bind", track = "Track", count = "#", sell = "Sell Price" }
local COLUMN_WIDTHS = { icon = 26, ilvl = 36, reqlvl = 32, type = 96, bind = 40, track = 40, count = 40, sell = 100 }
function ns.ListColumns()
    local configured = EUIProfile().bagListColumns or { "icon", "name", "ilvl", "count", "sell" }
    local columns, seen = {}, {}
    for _, key in ipairs(configured) do
        if COLUMN_NAMES[key] and not seen[key] then columns[#columns + 1] = key; seen[key] = true end
    end
    if #columns == 0 then return { "icon", "name", "count" } end
    return columns
end
function ns.ListValues(item)
    local values = { name = ns.String(item.name) or item.link, count = tostring(item.count), bind = "" }
    local getter = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(getter) == "function" then
        local data = { pcall(getter, item.link) }
        if data[1] then
            values.name = ns.String(data[2]) or values.name
            values.reqlvl = ns.Number(data[6]) and tostring(data[6]) or ""
            values.type = ns.String(data[8]) or ""
            local binding = ns.Number(data[15])
            local binds = Enum and Enum.ItemBind
            if binding and binds then
                local labels = { OnAcquire = "BoP", OnEquip = "BoE", OnUse = "BoU", Quest = "Quest",
                    ToWoWAccount = "BoA", ToBnetAccount = "WB", ToBnetAccountUntilEquipped = "WuE" }
                for key, label in pairs(labels) do
                    if binds[key] == binding then
                        values.bind = label
                        if item.bound and (key == "OnEquip" or key == "OnUse" or key == "ToBnetAccountUntilEquipped") then
                            values.bind = "SB"
                        elseif item.bound == nil and (key == "OnEquip" or key == "OnUse" or key == "ToBnetAccountUntilEquipped") then
                            values.bind = ""
                        end
                        break
                    end
                end
            end
            local price = ns.Number(data[12])
            if price and price >= 0 and price * item.count < 9007199254740991 then
                local copper = math.floor(price * item.count)
                values.sell = math.floor(copper / 10000) .. "g " .. math.floor(copper / 100) % 100 .. "s " .. copper % 100 .. "c"
            end
        end
    end
    local level = ns.Number(ns.Read(C_Item and C_Item.GetDetailedItemLevelInfo, item.link))
    values.ilvl = level and tostring(level) or ""
    -- Upgrade tracks and uncaptured binding state must not be guessed.
    return values
end
function ns.Layout(items, columns)
    columns = columns or 10
    local mode, groups = ns.DisplayMode(), {}
    local manager = EUI_CategoryManager
    local cats = manager and ns.Read(manager.GetCategories, manager)
    if type(cats) ~= "table" then cats = {} end
    if ns.Addon.Settings().groupByCategory then
        local buckets = {}
        for _, entry in ipairs(items) do
            local index = Category(entry.item, cats, manager)
            local cat = cats[index]
            local disabled = EUIProfile().bagDisabledCategories or {}
            if cat and (disabled[cat._defaultName] or (cat.isEquipSet and disabled["Item Set Gear"])) then
                index = 0
                for i, candidate in ipairs(cats) do if candidate.isCatchAll then index = i; break end end
            end
            buckets[index] = buckets[index] or {}
            table.insert(buckets[index], entry)
        end
        for i = 0, #cats do
            if buckets[i] then
                local cat = cats[i]
                groups[#groups + 1] = { name = i == 0 and "Other" or cat.name, items = buckets[i],
                    key = i == 0 and "fallback:other" or ("category:" .. (ns.String(cat._defaultName) or ns.String(cat.name) or tostring(i))) }
            end
        end
    else groups[1] = { items = items } end
    local layout, x, y, band = { slots = {}, headings = {}, height = 0 }, 0, 0, 0
    for _, group in ipairs(groups) do
        local collapsed = mode == "list" and group.key and (ns.Addon.Settings().collapsedCategories or {})[group.key] == true
        local visibleItems = collapsed and {} or group.items
        local width = mode == "compact" and math.min(columns, math.max(1, math.ceil(math.sqrt(#group.items)))) or columns
        local cellHeight = mode == "list" and 24 or 40
        if mode ~= "compact" or x + width > columns then y, x = y + band, 0; band = 0 end
        local function Heading()
            if group.name then
                table.insert(layout.headings, { text = group.name, x = x * 42, y = y, width = width * 42,
                    key = group.key, collapsed = collapsed, count = #group.items })
                return 20
            end
            return 0
        end
        local offset, row = Heading(), 0
        for i, entry in ipairs(visibleItems) do
            local column = mode == "list" and 0 or (i - 1) % width
            if i > 1 and column == 0 then row = row + 1 end
            table.insert(layout.slots, { entry = entry, x = x * 42 + column * 42, y = y + offset + row * cellHeight })
        end
        local groupHeight = offset + (#visibleItems > 0 and (row + 1) * cellHeight or 0)
        if mode == "compact" then x = x + width; band = math.max(band, groupHeight)
        else y = y + groupHeight; band = 0 end
        layout.height = math.max(layout.height, y + band)
    end
    return layout, mode
end

local function Font(parent, text, size)
    local label = parent:CreateFontString(nil, "OVERLAY")
    local path = ns.String(ns.Read(EllesmereUI and EllesmereUI.GetFontPath, "bags")) or STANDARD_TEXT_FONT
    label:SetFont(path or "Fonts\\FRIZQT__.TTF", size or 12, "")
    label:SetTextColor(0.9, 0.9, 0.9)
    label:SetText(text or "")
    return label
end
local function Skin(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\AddOns\\EllesmereUI\\media\\modern_blizz.png")
    local overlay = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    overlay:SetAllPoints()
    overlay:SetColorTexture(0, 0, 0, 0.25)
    local pp = EllesmereUI and EllesmereUI.PanelPP
    if EllesmereUI and type(EllesmereUI.MakeBorder) == "function" then
        frame.snapshotBorder = EllesmereUI.MakeBorder(frame, 1, 1, 1, 0.15, EllesmereUI.PP)
    elseif pp and type(pp.CreateBorder) == "function" then pp.CreateBorder(frame, 0.25, 0.25, 0.25, 1, 1) end
end
local function Button(parent, text, width, click, tip, plain)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 24)
    if not plain then Skin(button) elseif plain ~= "header" then button:SetAlpha(0.4) end
    button.label = Font(button, text)
    button.label:SetPoint("CENTER")
    button.tip = tip
    button:SetScript("OnClick", click)
    button:SetScript("OnEnter", function()
        if plain and plain ~= "header" then button:SetAlpha(0.8) end
        button.label:SetTextColor(0.05, 0.82, 0.62)
        if button.tip and EllesmereUI and EllesmereUI.ShowWidgetTooltip then
            EllesmereUI.ShowWidgetTooltip(button, button.tip)
        end
    end)
    button:SetScript("OnLeave", function()
        if plain and plain ~= "header" then button:SetAlpha(0.4) end
        button.label:SetTextColor(0.9, 0.9, 0.9)
        if EllesmereUI and EllesmereUI.HideWidgetTooltip then EllesmereUI.HideWidgetTooltip() end
    end)
    return button
end
local function HideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end
local function CurrentSnapshot()
    local key = ns.CharacterKey()
    local snapshot = ns.DB and key and ns.DB.characters[key]
    if not ns.ValidSnapshot(snapshot) then snapshot = nil end
    return snapshot, key
end
local function CharacterChoices()
    local current = ns.CharacterKey()
    if not current then return {} end
    -- Keep the current player selectable even before their first bank visit.
    local keys = { current }
    for _, key in ipairs(ns.Characters()) do
        if key ~= current then keys[#keys + 1] = key end
    end
    return keys
end
local function ChangeCharacter(direction)
    local keys = CharacterChoices()
    if #keys < 2 then return end
    local index = 1
    for i, key in ipairs(keys) do if key == selectedCharacter then index = i; break end end
    selectedCharacter = keys[((index - 1 + direction) % #keys) + 1]
    selectedTab, resetScroll = nil, true
    HideTooltip()
    ns.RefreshViewer()
end
local function Build()
    local f = CreateFrame("Frame", "EllesmereUIExtendBagsViewer", UIParent)
    viewer = f
    f:SetSize(620, 510)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if type(f.SetResizeBounds) == "function" then f:SetResizeBounds(620, 480, 1600, 1200) end
    -- Refresh also clamps live sizes when an older client has no native bounds API.
    f:EnableMouse(true)
    Skin(f)
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(34)
    local headerBG = header:CreateTexture(nil, "BACKGROUND")
    headerBG:SetAllPoints()
    headerBG:SetColorTexture(0, 0, 0, 0.5)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    f.header = header
    local function SaveGeometry()
        local settings = ns.Addon.Settings()
        if not f.gestureSettings or f.gestureSettings ~= settings or ns.Editing() or WindowSettings().locked then return end
        local window = WindowSettings()
        local width, height = ns.Number(f:GetWidth()), ns.Number(f:GetHeight())
        local ok, x, y = pcall(f.GetCenter, f)
        local parentOK, px, py = pcall(UIParent.GetCenter, UIParent)
        x, y, px, py = ns.Number(x), ns.Number(y), ns.Number(px), ns.Number(py)
        if not width or not height or not ok or not parentOK or not x or not y or not px or not py then return end
        settings.window = { width = math.max(620, math.min(1600, width)), height = math.max(480, math.min(1200, height)),
            x = x - px, y = y - py, locked = window.locked }
        f.geometrySettings, f.geometryWindow = nil, nil
    end
    local function StopGesture()
        f:StopMovingOrSizing()
        SaveGeometry()
        f.gestureSettings = nil
        if f.resize then f.resize:SetAlpha(ns.Read(f.resize.IsMouseOver, f.resize) == true and 0.8 or 0.4) end
        f.geometrySettings, f.geometryWindow = nil, nil
        ns.RefreshViewer()
    end
    f.StopGesture = StopGesture
    header:SetScript("OnDragStart", function()
        if ns.Editing() or WindowSettings().locked then return end
        f.gestureSettings = ns.Addon.Settings()
        f:StartMoving()
    end)
    header:SetScript("OnDragStop", StopGesture)
    f.title = Font(header, "Bank Snapshot | Read only", 14)
    f.title:SetPoint("LEFT", 12, 0)
    local close = Button(header, "X", 24, function() f:Hide() end)
    close:SetPoint("RIGHT", -8, 0)
    f.lock = Button(f, "", 13, function()
        if ns.Editing() then return end
        StopGesture()
        local settings = ns.Addon.Settings()
        local window = WindowSettings()
        if not settings.window then settings.window = window end
        window.locked = not window.locked
        ns.Addon.Refresh()
    end, "Lock or unlock the window's position and size.", true)
    f.lock:SetSize(13, 17)
    f.lock:SetPoint("BOTTOMRIGHT", -4, 4)
    f.lock.icon = f.lock:CreateTexture(nil, "ARTWORK")
    f.lock.icon:SetAllPoints()
    f.lock.icon:SetDesaturated(true)
    f.resize = Button(f, "", 18, nil, "Drag to resize. Double-click to reset size.", true)
    f.resize:SetSize(18, 18)
    f.resize:SetPoint("BOTTOMRIGHT", -2, 2)
    f.resize.icon = f.resize:CreateTexture(nil, "ARTWORK")
    f.resize.icon:SetAllPoints()
    f.resize.icon:SetDesaturated(true)
    local resizeLoaded = ns.Read(f.resize.icon.SetTexture, f.resize.icon,
        "Interface\\AddOns\\EllesmereUI\\media\\icons\\resize_element.png")
    f.resize.label:SetText(resizeLoaded == true and "" or "/")
    f.resize:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or ns.Editing() or WindowSettings().locked then return end
        f.gestureSettings = ns.Addon.Settings()
        f.resize:SetAlpha(0.8)
        f:StartSizing("BOTTOMRIGHT")
    end)
    f.resize:SetScript("OnMouseUp", StopGesture)
    f.resize:SetScript("OnDoubleClick", function()
        if ns.Editing() or WindowSettings().locked then return end
        StopGesture()
        local settings, window = ns.Addon.Settings(), WindowSettings()
        settings.window = { width = 620, height = 510, x = window.x, y = window.y, locked = false }
        ns.Addon.Refresh()
    end)
    f:SetScript("OnSizeChanged", function()
        if not f.applyingGeometry and f:IsShown() and f.scrollFrame then ns.RefreshViewer() end
    end)
    f.previousCharacter = Button(f, "<", 24, function() ChangeCharacter(-1) end, "Previous character's bank")
    f.previousCharacter:SetPoint("TOPLEFT", 12, -40)
    f.nextCharacter = Button(f, ">", 24, function() ChangeCharacter(1) end, "Next character's bank")
    f.nextCharacter:SetPoint("TOPLEFT", 352, -40)
    f.character = Font(f)
    f.character:SetPoint("LEFT", f.previousCharacter, "RIGHT", 8, 0)
    f.character:SetWidth(300)
    f.character:SetJustifyH("LEFT")
    f.character:SetWordWrap(false)
    local search = CreateFrame("EditBox", nil, f)
    search:SetSize(220, 24)
    search:SetPoint("TOPRIGHT", -12, -40)
    search:SetAutoFocus(false)
    search:SetFontObject(GameFontHighlightSmall)
    search:SetTextInsets(6, 6, 0, 0)
    search:SetMaxLetters(100)
    Skin(search)
    f.search = search
    local hint = Font(search, "Search name or item ID")
    hint:SetPoint("LEFT", 6, 0)
    hint:SetTextColor(0.5, 0.5, 0.5)
    search:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        resetScroll = true
        ns.RefreshViewer()
    end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.updated = Font(f, "Last updated: never", 11)
    f.updated:SetPoint("TOPLEFT", 12, -74)
    f.grouping = Button(f, "Group by Category", 170, function()
        if ns.Editing() then return end
        local settings = ns.Addon.Settings()
        settings.groupByCategory = not settings.groupByCategory
        resetScroll = true
        ns.Addon.Refresh()
    end, "Group the selected tabs using the current EUI bag categories.")
    f.grouping:SetSize(215, 24)
    f.grouping:SetPoint("TOPLEFT", 170, -94)
    f.grouping.label:SetWidth(205)
    f.grouping.label:SetWordWrap(false)
    f.display = Button(f, "", 225, function()
        if ns.Editing() then return end
        local settings = ns.Addon.Settings()
        local index = 1
        for i, mode in ipairs(DISPLAY_ORDER) do if settings.display == mode then index = i end end
        settings.display = DISPLAY_ORDER[index % #DISPLAY_ORDER + 1]
        resetScroll = true
        ns.Addon.Refresh()
    end, "Cycle Match EUI bank, Grid, Compact and List.")
    f.display:SetSize(180, 24)
    f.display:SetPoint("TOPLEFT", 395, -94)
    f.message = Font(f)
    f.message:SetPoint("TOPLEFT", 170, -142)
    f.message:SetWidth(425)
    f.message:SetJustifyH("LEFT")
    f.message:SetWordWrap(true)
    f.tabs, f.slots, f.headings = {}, {}, {}
    local sf = CreateFrame("ScrollFrame", nil, f)
    sf:SetPoint("TOPLEFT", 170, -142)
    sf:SetSize(420, ViewHeight(f))
    sf:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(420, 1)
    child:EnableMouse(false)
    sf:SetScrollChild(child)
    f.scrollFrame, f.scrollChild = sf, child
    local module = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS.EllesmereUIBags
    if module and type(module.AttachGridScrollbar) == "function" then
        -- Same helper/contract used by EUI_Bank; only our own frames are passed.
        local track, _, update = module.AttachGridScrollbar(f, sf, true, true)
        f.scrollTrack, f.updateScrollbar = track, update
    else
        -- Older EUI: template-free slider, styled like the bank's slim scrollbar.
        local track = CreateFrame("Slider", nil, f)
        track:SetOrientation("VERTICAL")
        track:SetWidth(12)
        track:SetValueStep(1)
        track:SetMinMaxValues(0, 0)
        local bg = track:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.06)
        local thumb = track:CreateTexture(nil, "ARTWORK")
        thumb:SetSize(4, 20); thumb:SetColorTexture(1, 1, 1, 0.25)
        track:SetThumbTexture(thumb)
        track:SetScript("OnValueChanged", function(_, value)
            if not f.updatingScrollbar then sf:SetVerticalScroll(value) end
        end)
        f.scrollTrack = track
        f.updateScrollbar = function()
            f.updatingScrollbar = true
            local range = math.max(0, child:GetHeight() - ViewHeight(f))
            track:SetMinMaxValues(0, range)
            track:SetValue(sf:GetVerticalScroll())
            track:SetShown(range > 0)
            f.updatingScrollbar = false
        end
    end
    f.scrollTrack:SetPoint("TOPRIGHT", -4, -142)
    f.scrollTrack:SetPoint("BOTTOMRIGHT", -4, 38)
    local function Wheel(_, delta)
        local range = math.max(0, child:GetHeight() - ViewHeight(f))
        sf:SetVerticalScroll(math.max(0, math.min(range, sf:GetVerticalScroll() - delta * 40)))
        HideTooltip()
        f.updateScrollbar()
    end
    sf:SetScript("OnMouseWheel", Wheel)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", Wheel)
    sf:HookScript("OnVerticalScroll", function() HideTooltip(); f.updateScrollbar() end)
    function f.CreateSlot(i)
        local button = CreateFrame("Button", nil, child)
        button:SetSize(36, 36)
        Skin(button)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.iconFrame = CreateFrame("Frame", nil, button)
        button.iconFrame:SetAllPoints(button.icon)
        button.iconFrame:EnableMouse(false)
        if EllesmereUI and type(EllesmereUI.MakeBorder) == "function" then
            button.iconFrame.snapshotBorder = EllesmereUI.MakeBorder(button.iconFrame, 1, 1, 1, 0.15, EllesmereUI.PP)
        end
        button.iconFrame:Hide()
        button.count = Font(button, "", 11)
        button.count:SetPoint("BOTTOMRIGHT", -1, 1)
        button:SetScript("OnEnter", function(self)
            local entry = self.entry
            if not entry or not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if not pcall(GameTooltip.SetHyperlink, GameTooltip, entry.item.link) then HideTooltip(); return end
            GameTooltip:AddLine("Snapshot: " .. entry.tab .. " | Slot " .. entry.slot, 0.05, 0.82, 0.62)
            GameTooltip:AddLine("Read only — visit a banker to move items.", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", HideTooltip)
        button:EnableMouseWheel(true)
        button:SetScript("OnMouseWheel", Wheel)
        -- Intentionally no OnClick, OnDragStart, item attributes or container identity.
        f.slots[i] = button
        return button
    end
    f.total = Font(f)
    f.total:SetPoint("BOTTOM", 70, 18)
    f:SetScript("OnHide", function()
        search:ClearFocus(); f:StopMovingOrSizing(); SaveGeometry(); f.gestureSettings = nil; HideTooltip()
        f.geometrySettings, f.geometryWindow = nil, nil
        local stop = f.scrollTrack:GetScript("OnMouseUp")
        if stop then stop(f.scrollTrack) end
    end)
    f:SetScript("OnShow", function()
        currentCharacter = ns.CharacterKey()
        selectedCharacter, selectedTab, resetScroll = currentCharacter, nil, true
        HideTooltip()
        -- Reopening must not retain an alt's tab, scroll or search filter.
        if search:GetText() ~= "" then search:SetText("") else ns.RefreshViewer() end
    end)
    if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "EllesmereUIExtendBagsViewer" end
    f:Hide()
    return f
end

function ns.RefreshViewer()
    if not viewer or not viewer:IsShown() then return end
    local f = viewer
    local settings = ns.Addon.Settings()
    local window = WindowSettings()
    if f.gestureSettings and (f.gestureSettings ~= settings or window.locked or ns.Editing()) then
        f:StopMovingOrSizing()
        f.gestureSettings = nil
        f.geometrySettings, f.geometryWindow = nil, nil
    end
    if not f.gestureSettings and (f.geometrySettings ~= settings or f.geometryWindow ~= settings.window) then
        f.applyingGeometry = true
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", window.x, window.y)
        f:SetSize(window.width, window.height)
        f.applyingGeometry = false
        f.geometrySettings, f.geometryWindow = settings, settings.window
    end
    local iconLoaded = ns.Read(f.lock.icon.SetTexture, f.lock.icon,
        "Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-lock-" .. (window.locked and "locked" or "unlocked") .. ".png")
    f.lock.label:SetText(iconLoaded == true and "" or (window.locked and "L" or "U"))
    f.lock.tip = window.locked and "Unlock window position and size." or "Lock window position and size."
    f:SetMovable(not window.locked and not ns.Editing())
    f:SetResizable(not window.locked and not ns.Editing())
    f.resize:SetShown(not window.locked and not ns.Editing())
    f.lock:ClearAllPoints()
    if f.resize:IsShown() then f.lock:SetPoint("RIGHT", f.resize, "LEFT", -2, 0)
    else f.lock:SetPoint("BOTTOMRIGHT", -4, 4) end
    local boundedWidth = math.max(620, math.min(1600, f:GetWidth()))
    local boundedHeight = math.max(480, math.min(1200, f:GetHeight()))
    if boundedWidth ~= f:GetWidth() or boundedHeight ~= f:GetHeight() then
        f.applyingGeometry = true
        f:SetSize(boundedWidth, boundedHeight)
        f.applyingGeometry = false
    end
    local current = ns.CharacterKey()
    local snapshot = ns.DB and selectedCharacter and ns.DB.characters[selectedCharacter]
    if currentCharacter ~= current or (selectedCharacter ~= current and not ns.ValidSnapshot(snapshot)) then
        currentCharacter = current
        selectedCharacter, selectedTab, resetScroll = current, nil, true
        HideTooltip()
    end
    snapshot = ns.DB and selectedCharacter and ns.DB.characters[selectedCharacter]
    if not ns.ValidSnapshot(snapshot) then snapshot = nil end
    f.character:SetText(selectedCharacter or "Current character unavailable")
    local keys = CharacterChoices()
    f.previousCharacter:SetEnabled(#keys > 1)
    f.nextCharacter:SetEnabled(#keys > 1)
    local timestamp = snapshot and snapshot.updatedAt
    local formatted = timestamp and ns.String(ns.Read(date, "%Y-%m-%d %H:%M", timestamp))
    f.updated:SetText("Last updated: " .. (formatted or (snapshot and "time unavailable" or "never")))
    for _, button in ipairs(f.tabs) do button:Hide() end
    local tabs = snapshot and snapshot.tabs or {}
    local found = selectedTab == nil
    for _, tab in ipairs(tabs) do if tab.bagID == selectedTab then found = true end end
    if not found then selectedTab, resetScroll = nil, true end
    for i = 0, #tabs do
        local index, id = i + 1, i > 0 and tabs[i].bagID or nil
        local button = f.tabs[index]
        if not button then
            button = Button(f, "", 145, function(self)
                selectedTab, resetScroll = self.tabID, true
                HideTooltip()
                ns.RefreshViewer()
            end)
            button:SetPoint("TOPLEFT", 12, -110 - i * 28)
            button.label:SetWidth(135)
            button.label:SetWordWrap(false)
            f.tabs[index] = button
        end
        button.tabID = id
        button.tip = i == 0 and "All captured personal storage" or tabs[i].name
        button.label:SetText(i == 0 and "All tabs" or tabs[i].name)
        button.label:SetTextColor(selectedTab == id and 0.05 or 0.9, selectedTab == id and 0.82 or 0.9, selectedTab == id and 0.62 or 0.9)
        button:Show()
    end
    local items = ns.Items(snapshot, selectedTab, f.search:GetText())
    local availableWidth = math.max(420, f:GetWidth() - 200)
    local layout, mode = ns.Layout(items, math.max(1, math.floor(availableWidth / 42)))
    local layoutKey = mode .. ":" .. tostring(ns.Addon.Settings().groupByCategory == true)
    if f.layoutKey ~= layoutKey then resetScroll = true; f.layoutKey = layoutKey end
    f.grouping.label:SetText("Group by Category: " .. (ns.Addon.Settings().groupByCategory and "On" or "Off"))
    f.display.label:SetText(DISPLAY_NAMES[ns.Addon.Settings().display or "match"] or DISPLAY_NAMES.match)
    for _, heading in ipairs(f.headings) do heading:Hide() end
    for i, data in ipairs(layout.headings) do
        local heading = f.headings[i]
        if not heading then
            heading = Button(f.scrollChild, "", 420, function(self)
                local currentSettings = ns.Addon.Settings()
                if ns.Editing() or not self:IsShown() or self.ownerSettings ~= currentSettings
                    or ns.DisplayMode() ~= "list" or not currentSettings.groupByCategory or not self.categoryKey then return end
                currentSettings.collapsedCategories = currentSettings.collapsedCategories or {}
                local collapsed = currentSettings.collapsedCategories
                collapsed[self.categoryKey] = not collapsed[self.categoryKey] or nil
                HideTooltip()
                ns.RefreshViewer()
            end, nil, "header")
            heading:SetAlpha(1)
            heading.label:ClearAllPoints()
            heading.label:SetPoint("LEFT", 0, 0)
            heading.label:SetWordWrap(false)
            heading.label:SetJustifyH("LEFT")
            heading:EnableMouseWheel(true)
            heading:SetScript("OnMouseWheel", f.scrollFrame:GetScript("OnMouseWheel"))
        end
        f.headings[i] = heading
        heading.ownerSettings, heading.categoryKey = settings, data.key
        heading:ClearAllPoints()
        heading:SetPoint("TOPLEFT", data.x, -data.y)
        heading:SetSize(mode == "list" and availableWidth or data.width, 20)
        heading.label:SetWidth((mode == "list" and availableWidth or data.width) - 4)
        heading.label:SetText(mode == "list" and ((data.collapsed and "+ " or "- ") .. (data.text or "Other") .. " (" .. data.count .. ")")
            or (data.text or "Other"))
        heading:EnableMouse(mode == "list")
        heading.tip = mode == "list" and (data.collapsed and "Expand category" or "Collapse category") or nil
        heading:Show()
    end
    local columns = ns.ListColumns()
    local fixed, widths, offsets, offset = 0, {}, {}, 0
    for _, key in ipairs(columns) do fixed = fixed + (COLUMN_WIDTHS[key] or 0) end
    local contentWidth = availableWidth
    local nameWidth = math.max(60, contentWidth - fixed)
    local scale = fixed + nameWidth > contentWidth and contentWidth / (fixed + nameWidth) or 1
    for i, key in ipairs(columns) do
        widths[i], offsets[i] = (COLUMN_WIDTHS[key] or nameWidth) * scale, offset
        offset = offset + widths[i]
    end
    f.scrollFrame:SetSize(contentWidth, ViewHeight(f))
    f.scrollChild:SetSize(contentWidth, math.max(1, layout.height))
    f.columnLabels = f.columnLabels or {}
    for _, label in ipairs(f.columnLabels) do label:Hide() end
    if mode == "list" then
        for i, key in ipairs(columns) do
            local label = f.columnLabels[i] or Font(f, "", 10)
            f.columnLabels[i] = label
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", 170 + offsets[i], -124)
            label:SetWidth(widths[i] - 4)
            label:SetJustifyH("LEFT")
            label:SetText(COLUMN_NAMES[key]); label:Show()
        end
    end
    for i = #f.slots + 1, #layout.slots do f.CreateSlot(i) end
    for i, button in ipairs(f.slots) do
        local placement = layout.slots[i]
        local entry = placement and placement.entry
        button.entry = entry
        button.cells = button.cells or {}
        -- Icon columns have no text cell, so this table can have gaps.
        for _, cell in pairs(button.cells) do cell:Hide() end
        if entry then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", placement.x, -placement.y)
            button:SetSize(mode == "list" and contentWidth or 36, mode == "list" and 22 or 36)
            button.icon:ClearAllPoints()
            button.icon:SetPoint("TOPLEFT", 2, -2)
            button.icon:SetSize(mode == "list" and 18 or 32, mode == "list" and 18 or 32)
            local zoom = ns.Number(EUIProfile().bagItemIconZoom) or 0.08
            zoom = math.max(0, math.min(0.45, zoom))
            button.icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
            button.icon:SetTexture(entry.item.icon or 134400)
            local color = ITEM_QUALITY_COLORS and entry.item.quality and ITEM_QUALITY_COLORS[entry.item.quality]
            if button.snapshotBorder and type(button.snapshotBorder.SetColor) == "function" then
                local rowColor = mode ~= "list" and color or nil
                button.snapshotBorder:SetColor(rowColor and rowColor.r or 1, rowColor and rowColor.g or 1, rowColor and rowColor.b or 1, rowColor and 0.8 or 0.15)
            end
            local iconBorder = button.iconFrame.snapshotBorder
            if iconBorder and type(iconBorder.SetColor) == "function" then
                iconBorder:SetColor(color and color.r or 1, color and color.g or 1, color and color.b or 1, color and 0.8 or 0.15)
            end
            button.count:SetText(entry.item.count > 1 and tostring(entry.item.count) or "")
            button.count:SetShown(mode ~= "list")
            button.icon:SetShown(mode ~= "list")
            if mode == "list" then
                local values = ns.ListValues(entry.item)
                for column, key in ipairs(columns) do
                    if key == "icon" then
                        button.icon:ClearAllPoints()
                        button.icon:SetPoint("TOPLEFT", offsets[column] + 2, -2)
                        button.icon:Show()
                    else
                        local cell = button.cells[column] or Font(button, "", 10)
                        button.cells[column] = cell
                        cell:ClearAllPoints()
                        cell:SetPoint("LEFT", button, "LEFT", offsets[column], 0)
                        cell:SetWidth(widths[column] - 4); cell:SetWordWrap(false); cell:SetJustifyH("LEFT")
                        cell:SetText(values[key] or ""); cell:Show()
                    end
                end
            end
            button.iconFrame:SetShown(mode == "list" and button.icon:IsShown())
            button:Show()
        else button:Hide() end
    end
    local message = ""
    if not ns.DB then message = "Snapshot storage is unavailable (unsupported database format)."
    elseif not snapshot then message = "Visit the banker first"
    elseif #items == 0 then message = "No items in this view." end
    f.message:SetText(message)
    f.scrollFrame:SetVerticalScroll(resetScroll and 0 or math.min(f.scrollFrame:GetVerticalScroll(), math.max(0, layout.height - ViewHeight(f))))
    resetScroll = false
    f.updateScrollbar()
    f.total:SetText((#layout.slots < #items and (#layout.slots .. "/") or "") .. #items .. " stacks")
end

function ns.ToggleViewer()
    if ns.Editing() then return end
    local f = viewer or Build()
    if f:IsShown() then f:Hide() else f:Show(); f:Raise() end
end

function ns.AttachButton()
    if type(InCombatLockdown) == "function" then
        local combat, ok = ns.Read(InCombatLockdown)
        if not ok or combat ~= false then return end
    end
    local bags = _G.EUI_Bags
    if not bags then return end
    if not ns.BagButton then
        -- An attached tab below the window avoids EUI's dynamic header/currency layout.
        local button = Button(bags, "Bank Snapshot", 125, function() ns.ToggleViewer() end,
            "View your character's read-only bank snapshot.")
        button:SetClampedToScreen(true)
        button:SetPoint("TOPRIGHT", bags, "BOTTOMRIGHT", -8, -4)
        ns.BagButton = button
        bags:HookScript("OnShow", function() ns.Addon.Refresh() end)
    end
    local button = ns.BagButton
    local snapshot = CurrentSnapshot()
    button.tip = snapshot and "View your character's read-only bank snapshot. Visit a banker to update it."
        or (ns.DB and "Visit the banker first"
            or "Bank snapshot storage is unavailable (unsupported database format).")
    button:SetEnabled(true) -- Keep the empty-state guidance accessible before the first visit.
    ns.BagButton:SetShown(ns.Addon.Settings().showButton)
end
