-- Optional hosts must not permit stale native hooks, viewer creation or bank reads.
SlashCmdList = {}
local frames, messages = {}, {}
local originalPrint = print
function print(message) messages[#messages + 1] = message end
function UnitFullName() return "MissingHost", "TestRealm" end
function CreateFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    frames[#frames + 1] = frame
    return frame
end
local function Forbidden() error("inactive host must not touch native UI or containers") end
EUI_Bags = { HookScript = Forbidden }
GameTooltip = { HookScript = Forbidden }
C_Container = { GetContainerNumSlots = Forbidden }
EllesmereUIExtendBagsDB = { format = 1, characters = {}, marker = "preserve inventory" }
local inventory = EllesmereUIExtendBagsDB
local ns = {}
local function Load()
    for _, file in ipairs({ "Core", "Sync", "Options" }) do
        assert(loadfile("Core/" .. file .. ".lua"))("EllesmereUIExtendBags")
    end
    for _, file in ipairs({ "Compatibility", "Bags", "Snapshot", "Tooltip", "Viewer", "Options" }) do
        assert(loadfile("Bags/" .. file .. ".lua"))("EllesmereUIExtendBags", ns)
    end
end
local function Fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
end
Load()
Fire("ADDON_LOADED", "EllesmereUIExtendBags")
Fire("PLAYER_LOGIN")
assert(#messages == 1 and messages[1]:find("EUI Standalone Bags", 1, true), "missing host explains requirements at login")
local count = #frames
SlashCmdList.ELLESMEREUIEXTENDBAGS()
Fire("BANKFRAME_OPENED")
assert(#frames == count and not ns.BankOpen and not ns.BagButton, "missing host builds no viewer/button and starts no capture")
assert(not EllesmereUIExtend.pluginRegistered and EllesmereUIExtendBagsDB == inventory, "missing host preserves database without settings registration")
EUICoreStandaloneBags = { RegisterPlugin = Forbidden }
__EUISTANDALONE_BAGS_INERT = true
ns.Addon.Refresh()
assert(ns.GetHost() == nil and not EllesmereUIExtend.RegisterOptions(), "inert standalone never registers or hooks stale frames")
Fire("PLAYER_LOGOUT")
assert(EllesmereUIExtendBagsProfiles.data.profiles.Default.bags.showButton, "missing host still saves Extend UI profiles")
assert(EllesmereUIExtendBagsDB == inventory and inventory.marker == "preserve inventory", "inventory remains intact through logout")
local saved = EllesmereUIExtendBagsProfiles
EUI_CLIENT_BLOCKED = true
EllesmereUIExtend, EllesmereUIExtendBags, ns = nil, nil, {}
Load()
assert(EllesmereUIExtend == nil and EllesmereUIExtendBags == nil, "blocked clients create no addon runtime")
assert(EllesmereUIExtendBagsProfiles == saved and EllesmereUIExtendBagsDB == inventory, "blocked loading preserves both SavedVariables")
print = originalPrint
print("PASS: missing/inert/blocked Bags hosts, login guidance, no hooks/capture/viewer and preserved profiles/inventory")
