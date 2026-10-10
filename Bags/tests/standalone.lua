-- Exercise the complete Bags fixture with the private standalone host only.
assert(loadfile("Bags/tests/runtime.lua"))("standalone")
local fixture = ExtendBagsTest
ExtendBagsTest = nil
local ns, host = fixture.ns, fixture.host
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
Check(EllesmereUI == nil and ns.GetHost() == host, "standalone integration never publishes a suite alias")
Check(ns.HostModule() == host._ModuleNS.EUIStandaloneBags, "scrollbar helper uses the actual standalone module registry")
EUICoreStandaloneBagsDB = { bagItemAssignments = { marker = "standalone" } }
EllesmereUIDB = { bagItemAssignments = { marker = "suite" } }
Check(ns.HostDB() == EUICoreStandaloneBagsDB, "standalone category assignments never read the suite database")
Check(ns.MediaPath("icons\\resize_element.png") == "Interface\\AddOns\\EUIStandaloneBags\\media\\icons\\resize_element.png",
    "standalone artwork resolves inside the installed host")
local media = 0
for _, frame in ipairs(fixture.frames) do
    if type(frame.texture) == "string" then
        Check(not frame.texture:find("Interface\\AddOns\\EllesmereUI\\media\\", 1, true), "standalone viewer does not require full-suite artwork")
        if frame.texture:find("Interface\\AddOns\\EUIStandaloneBags\\media\\", 1, true) then media = media + 1 end
    end
end
Check(media > 5, "standalone viewer skins, arrows and lock/resize controls use host media")
local inventory = EllesmereUIExtendBagsDB
local framesBefore = #fixture.frames
__EUISTANDALONE_BAGS_INERT = true
Check(ns.GetHost() == nil and ns.Editing(), "upstream-disabled standalone fails closed for stale editing callbacks")
ns.ToggleViewer()
ns.AttachButton()
Check(#fixture.frames == framesBefore and not ns.BagButton:IsShown(), "inert host creates no viewer and hides the attached button")
ns.BankOpen = true
Check(not ns.CanCapture(), "inert host cannot start bank reads")
Check(EllesmereUIExtendBagsDB == inventory, "inert host preserves captured inventory")
__EUISTANDALONE_BAGS_INERT = nil
EUI_CLIENT_BLOCKED = true
Check(ns.GetHost() == nil, "blocked clients cannot select the standalone")
EUI_CLIENT_BLOCKED = nil
EUICoreStandaloneBags = nil
EUICoreStandaloneNameplates = { sentinel = "other feature" }
Check(ns.GetHost() == nil, "Bags never borrows a standalone Nameplates host")
EUICoreStandaloneNameplates = nil
EUICoreStandaloneBags = host
EllesmereUI = { sentinel = "suite" }
Check(ns.GetHost() == EllesmereUI and ns.HostDB() == EllesmereUIDB, "full suite takes precedence without mixing databases")
local suiteDB = EllesmereUIDB
EllesmereUIDB = nil
Check(ns.HostDB() == nil, "missing suite database cannot fall through to saved standalone assignments")
EllesmereUIDB = suiteDB
Check(ns.MediaPath("modern_blizz.png") == "Interface\\AddOns\\EllesmereUI\\media\\modern_blizz.png", "suite media stays unchanged")
EllesmereUI = nil
local oldCore = EllesmereUIExtend
EllesmereUIExtend = { EmbeddedVersion = 1 }
Check(ns.GetHost() == host, "private adapter supports older embedded cores")
EllesmereUIExtend = oldCore
EUICoreStandaloneBagsDB, EllesmereUIDB = nil, nil
-- Real embedded core, all independent owners/load orders and persisted profiles.
assert(loadfile("Bags/tests/profiles.lua"))("standalone")
Check(EllesmereUI == nil and EllesmereUIExtend.GetHost() == EUICoreStandaloneBags,
    "shared registration and profile persistence use standalone without a suite alias")
local core, profileHost = EllesmereUIExtend, EUICoreStandaloneBags
local selection, popup, createProfile
profileHost.Widgets = {
    SectionHeader = function() return {}, 30 end,
    Dropdown = function(_, _, _, _, _, get, set) selection = { get = get, set = set }; return {}, 40 end,
    WideButton = function(_, _, text, _, click)
        if text == "Create Profile" then createProfile = click end
        return {}, 40
    end,
}
profileHost.ShowInputPopup = function(_, spec) popup = spec end
for _, spec in ipairs(core.GetModules()) do
    if spec.key == "Profiles" then spec.buildPage("Profiles", {}, 0) end
end
Check(selection and selection.get() == "Other", "shared Profiles page uses standalone Bags widgets and saved assignments")
createProfile(); popup.onConfirm("Standalone UI")
Check(core.GetProfileInfo().active == "Standalone UI", "shared profile popup uses standalone Bags host")
profileHost.IsUnlockModeActive = function() return true end
Check(not core.CreateProfile("Locked"), "standalone Bags edit lock protects shared profile mutations")
profileHost.IsUnlockModeActive = function() return false end
selection.set("Default")
Check(core.GetProfileInfo().active == "Default", "standalone shared profile dropdown switches profiles")
profileHost.OpenPlugin = function(id, module, page)
    Check(id == core.PluginID and module == "Profiles" and page == "Profiles", "eextend opens standalone Bags shared profiles")
end
SlashCmdList.ELLESMEREUIEXTEND()
__EUISTANDALONE_BAGS_INERT = true
Check(core.GetHost() == nil and not core.RegisterOptions(), "shared settings never register an inert standalone Bags host")
__EUISTANDALONE_BAGS_INERT = nil
print("PASS: " .. checks .. " standalone Bags host, media, assignments, guards and real shared profiles checks")
