local _, ns = ...
if not ns.Addon then return end

local marked = setmetatable({}, { __mode = "k" })
local hookedTooltip, processorInstalled, legacyInstalled
local function Enabled()
    if not ns.GetHost() then return false end
    local settings = ns.Addon.Settings()
    if not settings then return false end
    return not ns.Secret(settings.tooltipBankCounts) and settings.tooltipBankCounts == true
end
function ns.ClearCountTooltip(tooltip) marked[tooltip] = nil end
local function ClassColor(key)
    local classes = ns.DB and ns.DB.classes
    local token = type(classes) == "table" and ns.String(classes[key])
    local color = token and ns.Read(C_ClassColor and C_ClassColor.GetClassColor, token)
    if type(color) ~= "table" and token and type(RAID_CLASS_COLORS) == "table" then color = RAID_CLASS_COLORS[token] end
    if not ns.Secret(color) and type(color) == "table" then
        local r, g, b = ns.Number(color.r), ns.Number(color.g), ns.Number(color.b)
        if r and g and b then return math.max(0, math.min(1, r)), math.max(0, math.min(1, g)), math.max(0, math.min(1, b)) end
    end
    return 0.75, 0.75, 0.75 -- Do not guess classes for previously captured alts.
end
function ns.AddSnapshotCounts(tooltip, itemID)
    if not Enabled() or marked[tooltip] or type(tooltip.AddLine) ~= "function" then return end
    local bank = ns.BankStock(itemID)
    local bags = ns.AltBagsEnabled() and ns.BagStock(itemID) or nil
    if not bank and not bags then return end
    local current = ns.CharacterKey()
    if not current then return end
    ns.Read(tooltip.AddLine, tooltip, " ")
    local _, headingOK = ns.Read(tooltip.AddLine, tooltip, "Snapshot stock", 1, 0.82, 0.45)
    if headingOK then marked[tooltip] = true end
    local function Row(label, bagCount, bankCount, r, g, b)
        if bagCount <= 0 and bankCount <= 0 then return end
        local text = string.format("Bags: %.0f / Bank: %.0f", bagCount, bankCount)
        local _, ok = ns.Read(tooltip.AddDoubleLine, tooltip, label, text, r, g, b, 1, 0.92, 0.72)
        if not ok then
            _, ok = ns.Read(tooltip.AddLine, tooltip, label .. ": |cffffebb8" .. text .. "|r", r, g, b)
        end
        if ok then marked[tooltip] = true end
    end
    local counts, keys = {}, {}
    local function Include(stock, field)
        for _, character in ipairs(stock and stock.characters or {}) do
            if not counts[character.key] then
                counts[character.key] = { bags = 0, bank = 0 }
                keys[#keys + 1] = character.key
            end
            counts[character.key][field] = character.count
        end
    end
    Include(bank, "bank"); Include(bags, "bags")
    local own = counts[current] or { bags = 0, bank = 0 }
    local settings = ns.Addon.Settings()
    if not ns.Secret(settings.compressTooltipCounts) and settings.compressTooltipCounts ~= false then
        Row("Current", own.bags, own.bank, 0.4, 0.85, 0.72)
        Row("Other", (bags and bags.total or 0) - own.bags, (bank and bank.total or 0) - own.bank, 0.65, 0.72, 0.95)
    else
        Row(current .. " (you)", own.bags, own.bank, ClassColor(current))
        table.sort(keys)
        for _, key in ipairs(keys) do
            if key ~= current then Row(key, counts[key].bags, counts[key].bank, ClassColor(key)) end
        end
    end
end
local function TooltipContext(tooltip)
    if tooltip ~= GameTooltip then return end
    local owner = ns.Read(tooltip.GetOwner, tooltip)
    -- Inspect only the actual EUI bag/bank hierarchy. Other owners and shopping
    -- tooltips remain untouched; snapshot items append explicitly in Viewer.lua.
    for _ = 1, 12 do
        if not owner then return end
        if owner == EUI_Bags or owner == EUI_ReagentBagFrame or owner == EUI_BagsReagent then return "bag" end
        if owner == EUI_BankFrame then return "bank" end
        owner = ns.Read(owner.GetParent, owner)
    end
end
local function PostItem(tooltip, data)
    if not Enabled() or ns.Secret(data) or type(data) ~= "table" then return end
    local context = TooltipContext(tooltip)
    if not context then return end
    ns.AddSnapshotCounts(tooltip, ns.Number(data.id))
    if marked[tooltip] then ns.Read(tooltip.Show, tooltip) end
end
local function LegacyItem(tooltip)
    if not Enabled() or type(tooltip.GetItem) ~= "function" then return end
    local context = TooltipContext(tooltip)
    if not context then return end
    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    link = ok and ns.String(link) or nil
    if not link then return end
    local id = tonumber(link:match("item:(%d+)"))
    ns.AddSnapshotCounts(tooltip, id)
    if marked[tooltip] then ns.Read(tooltip.Show, tooltip) end
end
function ns.InstallCountTooltips()
    if not ns.GetHost() then return end
    local tooltip = GameTooltip
    if not tooltip or type(tooltip.HookScript) ~= "function" then return end
    if hookedTooltip ~= tooltip then
        -- A native rebuild clears our de-duplication marker before item postcalls.
        local ok, success = pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", ns.ClearCountTooltip)
        if not ok or ns.Secret(success) or success == false then return end
        pcall(tooltip.HookScript, tooltip, "OnHide", ns.ClearCountTooltip)
        hookedTooltip = tooltip
    end
    if not processorInstalled and TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
        and Enum and Enum.TooltipDataType and ns.Number(Enum.TooltipDataType.Item) then
        local ok = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, PostItem)
        if ok then processorInstalled = true; return end
    end
    if not processorInstalled and not legacyInstalled then
        -- Forever/older clients may still provide this script instead of the
        -- Retail processor. Unsupported scripts fail closed without replacements.
        local ok, success = pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", function(self)
            if not processorInstalled then LegacyItem(self) end
        end)
        if ok and not ns.Secret(success) and success ~= false then legacyInstalled = true end
    end
end
function ns.RefreshCountTooltips()
    ns.InstallCountTooltips()
    if not Enabled() then ns.InvalidateBankCounts() end
    if not Enabled() or not ns.AltBagsEnabled() then ns.InvalidateBagCounts() end
    -- Remove an already-visible added line after profile/reset/capture changes;
    -- native content is rebuilt on its next hover/update, never edited in place.
    if GameTooltip and marked[GameTooltip] then
        marked[GameTooltip] = nil
        ns.Read(GameTooltip.Hide, GameTooltip)
    end
end
