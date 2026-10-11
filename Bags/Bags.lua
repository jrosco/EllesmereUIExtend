local addonName, ns = ...
if EUI_CLIENT_BLOCKED then return end
local core = EllesmereUIExtend
if not core then return end
local addon = {}
ns.Addon = addon
_G.EllesmereUIExtendBags = addon
ns.FrameStrataValues = { BACKGROUND = "Background", LOW = "Low", MEDIUM = "Medium", HIGH = "High", DIALOG = "Dialog" }
ns.FrameStrataOrder = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }
function ns.WindowScale(value)
    return math.floor(math.max(0.5, math.min(1.5, ns.Number(value) or 1)) * 20 + 0.5) / 20
end
function ns.WindowStrata(value)
    return ns.String(value) and ns.FrameStrataValues[value] and value or "DIALOG"
end

function addon.Settings() return core.GetSettings("bags") end
function addon.Refresh()
    if ns.RefreshInventoryCapture then ns.RefreshInventoryCapture() end
    if ns.RefreshCountTooltips then ns.RefreshCountTooltips() end
    if ns.AttachButton then ns.AttachButton() end
    if ns.RefreshViewer then ns.RefreshViewer() end
end
core.RegisterFeature("bags", {
    defaults = { showButton = true, groupByCategory = false, display = "match", collapsedCategories = {},
        windowScale = 1, frameStrata = "DIALOG", sidebarCollapsed = false, tooltipBankCounts = false,
        altBagsEnabled = false, bankViewerEnabled = true, compressTooltipCounts = true,
        window = { width = 620, height = 510, x = 0, y = 0, locked = false } },
    normalize = function(settings)
        settings.showButton = not ns.Secret(settings.showButton) and settings.showButton ~= false
        settings.groupByCategory = not ns.Secret(settings.groupByCategory) and settings.groupByCategory == true
        settings.sidebarCollapsed = not ns.Secret(settings.sidebarCollapsed) and settings.sidebarCollapsed == true
        settings.tooltipBankCounts = not ns.Secret(settings.tooltipBankCounts) and settings.tooltipBankCounts == true
        -- Consolidate the two current tooltip preferences once. No inventory or
        -- legacy addon settings are imported; the existing bank preference is
        -- now the shared snapshot-tooltip switch.
        if not ns.Secret(settings.tooltipBagCounts) and settings.tooltipBagCounts == true then settings.tooltipBankCounts = true end
        settings.tooltipBagCounts = nil
        settings.bankViewerEnabled = not ns.Secret(settings.bankViewerEnabled) and settings.bankViewerEnabled ~= false
        settings.compressTooltipCounts = not ns.Secret(settings.compressTooltipCounts) and settings.compressTooltipCounts ~= false
        settings.altBagsEnabled = not ns.Secret(settings.altBagsEnabled) and settings.altBagsEnabled == true
        settings.windowScale = ns.WindowScale(settings.windowScale)
        settings.frameStrata = ns.WindowStrata(settings.frameStrata)
        local collapsed = {}
        if not ns.Secret(settings.collapsedCategories) and type(settings.collapsedCategories) == "table" then
            for key, value in pairs(settings.collapsedCategories) do
                if ns.String(key) and #key <= 256 and not ns.Secret(value) and value == true then collapsed[key] = true end
            end
        end
        settings.collapsedCategories = collapsed
        local window = type(settings.window) == "table" and settings.window or {}
        window.width = math.max(620, math.min(1600, ns.Number(window.width) or 620))
        window.height = math.max(480, math.min(1200, ns.Number(window.height) or 510))
        window.x = math.max(-10000, math.min(10000, ns.Number(window.x) or 0))
        window.y = math.max(-10000, math.min(10000, ns.Number(window.y) or 0))
        window.locked = not ns.Secret(window.locked) and window.locked == true
        settings.window = window
        if not ns.String(settings.display) or (settings.display ~= "grid" and settings.display ~= "compact" and settings.display ~= "list") then
            settings.display = "match"
        end
        return settings
    end,
    refresh = addon.Refresh,
})

local frame = CreateFrame("Frame")
ns.EventFrame = frame
local elapsed = 0
local function Poll(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.25 then return end
    elapsed = 0
    if ns.Capture then ns.Capture() end
end
local function StartBank()
    if not ns.GetHost() then return end
    ns.BankOpen, ns.Pending, ns.CapturedThisVisit = true, nil, false
    elapsed = 0
    frame:SetScript("OnUpdate", Poll)
end
local function StopBank()
    ns.BankOpen, ns.Pending = false, nil
    frame:SetScript("OnUpdate", nil)
end
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED", "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED",
    "BANK_TABS_CHANGED", "BANK_TAB_SETTINGS_UPDATED", "PLAYER_REGEN_ENABLED", "GET_ITEM_INFO_RECEIVED" }) do
    pcall(frame.RegisterEvent, frame, event)
end
local host = ns.GetHost()
if host and host.IS_FOREVER then pcall(frame.RegisterEvent, frame, "BAG_CONTAINER_UPDATE") end
frame:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGOUT" then
        if ns.StopInventoryCapture then ns.StopInventoryCapture() end
    elseif event == "PLAYER_LOGIN" or event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED"
        or event == "BAG_CONTAINER_UPDATE" or event == "GET_ITEM_INFO_RECEIVED" then
        if ns.RequestInventoryCapture then ns.RequestInventoryCapture() end
    end
    if event == "ADDON_LOADED" then
        if name == addonName and ns.InitializeDB then ns.InitializeDB() end
    elseif event == "PLAYER_LOGIN" then
        if ns.InitializeDB then ns.InitializeDB() end
        if not ns.GetHost() and type(print) == "function" then
            print("EllesmereUI Extend Bags: enable EllesmereUI and its Bags module, or EUI Standalone Bags. Saved snapshots are unchanged.")
        end
        addon.Refresh()
    elseif event == "BANKFRAME_OPENED" then
        StartBank()
        if ns.RefreshCountTooltips then ns.RefreshCountTooltips() end
    elseif event == "BANKFRAME_CLOSED" or event == "PLAYER_LOGOUT" then
        -- Never query bank containers after access closes, even to do a final scan.
        StopBank()
        if ns.RefreshCountTooltips then ns.RefreshCountTooltips() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        addon.Refresh()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if ns.RefreshViewer then ns.RefreshViewer() end
    elseif ns.BankOpen then
        ns.Pending = nil -- Require two stable scans again after native inventory changes.
    end
end)
SLASH_ELLESMEREUIEXTENDBAGS1 = "/ebags"
SlashCmdList.ELLESMEREUIEXTENDBAGS = function() if ns.ToggleViewer then ns.ToggleViewer() end end
