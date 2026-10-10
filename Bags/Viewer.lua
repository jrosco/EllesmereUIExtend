local _, ns = ...
if not ns.Addon then return end
local viewer, selectedCharacter, selectedTab, page = nil, nil, nil, 1
local PAGE_SIZE = 80

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
    bg:SetColorTexture(0.035, 0.035, 0.035, 0.97)
    local pp = EllesmereUI and EllesmereUI.PanelPP
    if pp and type(pp.CreateBorder) == "function" then pp.CreateBorder(frame, 0.25, 0.25, 0.25, 1, 1) end
end
local function Button(parent, text, width, click, tip)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 24)
    Skin(button)
    button.label = Font(button, text)
    button.label:SetPoint("CENTER")
    button.tip = tip
    button:SetScript("OnClick", click)
    button:SetScript("OnEnter", function()
        button.label:SetTextColor(0.05, 0.82, 0.62)
        if button.tip and EllesmereUI and EllesmereUI.ShowWidgetTooltip then
            EllesmereUI.ShowWidgetTooltip(button, button.tip)
        end
    end)
    button:SetScript("OnLeave", function()
        button.label:SetTextColor(0.9, 0.9, 0.9)
        if EllesmereUI and EllesmereUI.HideWidgetTooltip then EllesmereUI.HideWidgetTooltip() end
    end)
    return button
end
local function HideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end
local function ChangeCharacter(direction)
    local keys = ns.Characters()
    if #keys == 0 then return end
    local index = 1
    for i, key in ipairs(keys) do if key == selectedCharacter then index = i; break end end
    selectedCharacter = keys[((index - 1 + direction) % #keys) + 1]
    selectedTab, page = nil, 1
    HideTooltip()
    ns.RefreshViewer()
end
local function Build()
    local f = CreateFrame("Frame", "EllesmereUIExtendBagsViewer", UIParent)
    viewer = f
    f:SetSize(620, 470)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    Skin(f)
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(34)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() if not ns.Editing() then f:StartMoving() end end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f.title = Font(header, "Bank Snapshot | Read only", 14)
    f.title:SetPoint("LEFT", 12, 0)
    local close = Button(header, "X", 24, function() f:Hide() end)
    close:SetPoint("RIGHT", -8, 0)
    f.previousCharacter = Button(f, "<", 24, function() ChangeCharacter(-1) end, "Previous captured character")
    f.previousCharacter:SetPoint("TOPLEFT", 12, -40)
    f.nextCharacter = Button(f, ">", 24, function() ChangeCharacter(1) end, "Next captured character")
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
        page = 1
        ns.RefreshViewer()
    end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.updated = Font(f, "Last updated: never", 11)
    f.updated:SetPoint("TOPLEFT", 12, -74)
    f.message = Font(f)
    f.message:SetPoint("TOPLEFT", 170, -110)
    f.message:SetWidth(425)
    f.message:SetJustifyH("LEFT")
    f.message:SetWordWrap(true)
    f.tabs, f.slots = {}, {}
    -- A bounded grid: no live container templates or secure item actions.
    for i = 1, PAGE_SIZE do
        local button = CreateFrame("Button", nil, f)
        button:SetSize(36, 36)
        button:SetPoint("TOPLEFT", 170 + ((i - 1) % 10) * 42, -110 - math.floor((i - 1) / 10) * 40)
        Skin(button)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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
        -- Intentionally no OnClick, OnDragStart, item attributes or container identity.
        f.slots[i] = button
    end
    f.previousPage = Button(f, "<", 24, function() page = math.max(1, page - 1); ns.RefreshViewer() end)
    f.previousPage:SetPoint("BOTTOMLEFT", 170, 12)
    f.nextPage = Button(f, ">", 24, function() page = page + 1; ns.RefreshViewer() end)
    f.nextPage:SetPoint("BOTTOMRIGHT", -12, 12)
    f.page = Font(f)
    f.page:SetPoint("BOTTOM", 70, 18)
    f:SetScript("OnHide", function() search:ClearFocus(); f:StopMovingOrSizing(); HideTooltip() end)
    f:SetScript("OnShow", function() ns.RefreshViewer() end)
    if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "EllesmereUIExtendBagsViewer" end
    f:Hide()
    return f
end

function ns.RefreshViewer()
    if not viewer or not viewer:IsShown() then return end
    local f, keys = viewer, ns.Characters()
    if not selectedCharacter or not ns.DB or not ns.ValidSnapshot(ns.DB.characters[selectedCharacter]) then
        local current = ns.CharacterKey()
        selectedCharacter = ns.DB and current and ns.ValidSnapshot(ns.DB.characters[current]) and current or keys[1]
    end
    local snapshot = ns.DB and selectedCharacter and ns.DB.characters[selectedCharacter]
    f.character:SetText(selectedCharacter or "No captured characters")
    f.previousCharacter:SetEnabled(#keys > 1)
    f.nextCharacter:SetEnabled(#keys > 1)
    local timestamp = snapshot and snapshot.updatedAt
    local formatted = timestamp and ns.String(ns.Read(date, "%Y-%m-%d %H:%M", timestamp))
    f.updated:SetText("Last updated: " .. (formatted or (snapshot and "time unavailable" or "never")))
    for _, button in ipairs(f.tabs) do button:Hide() end
    local tabs = snapshot and snapshot.tabs or {}
    local found = selectedTab == nil
    for _, tab in ipairs(tabs) do if tab.bagID == selectedTab then found = true end end
    if not found then selectedTab, page = nil, 1 end
    for i = 0, #tabs do
        local index, id = i + 1, i > 0 and tabs[i].bagID or nil
        local button = f.tabs[index]
        if not button then
            button = Button(f, "", 145, function(self)
                selectedTab, page = self.tabID, 1
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
    local pages = math.max(1, math.ceil(#items / PAGE_SIZE))
    page = math.min(page, pages)
    for i, button in ipairs(f.slots) do
        local entry = items[(page - 1) * PAGE_SIZE + i]
        button.entry = entry
        if entry then
            button.icon:SetTexture(entry.item.icon or 134400)
            button.count:SetText(entry.item.count > 1 and tostring(entry.item.count) or "")
            button:Show()
        else button:Hide() end
    end
    local message = ""
    if not ns.DB then message = "Snapshot storage is unavailable (unsupported database format)."
    elseif not snapshot then message = "Visit a banker to create a snapshot."
    elseif #items == 0 then message = "No items in this view." end
    f.message:SetText(message)
    f.previousPage:SetEnabled(page > 1)
    f.nextPage:SetEnabled(page < pages)
    f.page:SetText("Page " .. page .. "/" .. pages .. " | " .. #items .. " stacks")
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
            "Browse read-only bank snapshots for captured characters. Visit a banker to update your snapshot.")
        button:SetClampedToScreen(true)
        button:SetPoint("TOPRIGHT", bags, "BOTTOMRIGHT", -8, -4)
        ns.BagButton = button
        bags:HookScript("OnShow", function() ns.Addon.Refresh() end)
    end
    ns.BagButton:SetShown(ns.Addon.Settings().showButton)
end
