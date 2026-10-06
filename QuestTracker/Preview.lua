local _, ns = ...
if not ns.Addon then return end

local activeHeader

local function Prebuilding()
    return EllesmereUI and type(EllesmereUI.IsSearchPrebuild) == "function" and EllesmereUI.IsSearchPrebuild()
end

function ns.RefreshQuestItemHeader(forceHeight)
    if activeHeader and not Prebuilding() then activeHeader.Refresh(forceHeight) end
end

function ns.BuildQuestItemHeader(parent, parentWidth)
    if Prebuilding() or not ns.CreateQuestItemSample then return 0 end
    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", parent, "TOPLEFT")
    root:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
    root:EnableMouse(false)
    local title = root:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", root, "TOP", 0, -12)
    title:SetText("Quest Item Preview")
    local caption = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    caption:SetPoint("BOTTOM", root, "BOTTOM", 0, 12)
    caption:SetText("Sample icon - appearance only")
    local sample = ns.CreateQuestItemSample(root)
    sample:SetPoint("CENTER", root, "CENTER")
    root.sample = sample

    local busy, building, height = false, true, 0
    local function Refresh(forceHeight)
        if busy or Prebuilding() then return end
        if not building and ns.Boolean(ns.Call(root.IsVisible, root)) ~= true then return end
        busy = true
        sample.RefreshAppearance()
        local size = ns.ItemSize()
        local art = ns.Addon.Settings().itemRetailArt and sample.questItemArtLoaded
        local artWidth, artHeight = size + 24, size + 24
        if art then artWidth, artHeight = 256 * size / 56, 128 * size / 56 end
        local width = ns.Number(ns.Call(root.GetWidth, root))
        if not width or width <= 0 then width = ns.Number(parentWidth) or 600 end
        local scale = math.min(1, math.max(1, width - 48) / artWidth)
        sample:SetScale(scale)
        local h = math.max(180, math.ceil(artHeight * scale + 80))
        -- Older EUI builds without dynamic header sizing reserve maximum space.
        local canResize = EllesmereUI and type(EllesmereUI.UpdateContentHeaderHeight) == "function"
        if not canResize then h = 336 end
        root:SetHeight(h)
        if not building and canResize and (h ~= height or forceHeight == true) then
            EllesmereUI:UpdateContentHeaderHeight(h)
        end
        height = h
        busy = false
        return h
    end
    root.Refresh = Refresh
    root:SetScript("OnShow", function()
        activeHeader = root
        Refresh(true)
    end)
    root:SetScript("OnHide", function()
        if activeHeader == root then activeHeader = nil end
    end)
    root:SetScript("OnSizeChanged", function() Refresh() end)
    activeHeader = root
    Refresh()
    building = false
    return height
end
