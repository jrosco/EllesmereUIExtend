local addonName, ns = ...
if EUI_CLIENT_BLOCKED then return end
local core = EllesmereUIExtend
if not core then return end
local addon = {}
ns.Addon = addon
_G.EllesmereUIExtendBags = addon

function addon.Settings() return core.GetSettings("bags") end
function addon.Refresh()
    if ns.AttachButton then ns.AttachButton() end
    if ns.RefreshViewer then ns.RefreshViewer() end
end
core.RegisterFeature("bags", {
    defaults = { showButton = true },
    normalize = function(settings)
        settings.showButton = settings.showButton ~= false
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
if EllesmereUI and EllesmereUI.IS_FOREVER then pcall(frame.RegisterEvent, frame, "BAG_CONTAINER_UPDATE") end
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == addonName and ns.InitializeDB then ns.InitializeDB() end
    elseif event == "PLAYER_LOGIN" then
        if ns.InitializeDB then ns.InitializeDB() end
        addon.Refresh()
    elseif event == "BANKFRAME_OPENED" then
        StartBank()
    elseif event == "BANKFRAME_CLOSED" or event == "PLAYER_LOGOUT" then
        -- Never query bank containers after access closes, even to do a final scan.
        StopBank()
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
