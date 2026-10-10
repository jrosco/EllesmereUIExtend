-- Run the complete production runtime/UI fixture with ONLY the renamed host.
assert(loadfile("Nameplates/tests/runtime.lua"))("standalone")
local core, host = EllesmereUIExtend, EUICoreStandaloneNameplates
assert(EllesmereUI == nil and host, "standalone does not create a full-suite global alias")
assert(core.GetHost() == host, "shared settings and renderers select standalone")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local saved = EllesmereUIExtendDB
host.IsUnlockModeActive = function() return true end
Check(not core.CreateProfile("Locked"), "standalone editor locks shared profile mutation")
host.IsUnlockModeActive = function() return false end
Check(core.CreateProfile("Standalone"), "standalone can create a shared profile")
Check(core.SelectProfile("Default"), "standalone can switch back to saved settings")
Check(EllesmereUIExtendDB == saved, "host support preserves Extend profile identity")

local widgets, popup, clicked, selection = host.Widgets
host.Widgets = {
    SectionHeader = function() return {}, 30 end,
    Dropdown = function(_, _, _, _, _, get, set) selection = { get = get, set = set }; return {}, 40 end,
    WideButton = function(_, _, label, _, click) clicked = clicked or {}; clicked[label] = click; return {}, 40 end,
}
host.ShowInputPopup = function(_, spec) popup = spec end
local profiles
for _, spec in ipairs(core.GetModules()) do if spec.key == "Profiles" then profiles = spec end end
profiles.buildPage("Profiles", {}, 0)
Check(selection.get() == "Default", "shared Profiles UI uses standalone widgets")
clicked["Create Profile"](); popup.onConfirm("Standalone UI")
Check(core.GetProfileInfo().active == "Standalone UI", "shared Profiles popup uses standalone host")
selection.set("Default")
Check(core.GetProfileInfo().active == "Default", "shared profile dropdown callback works")
host.OpenPlugin = function(id, module, page)
    Check(id == core.PluginID and module == "Profiles" and page == "Profiles",
        "eextend opens the standalone profile page")
end
SlashCmdList.ELLESMEREUIEXTEND()
host.Widgets = widgets

local private = {}
assert(loadfile("Nameplates/Helpers.lua"))("EllesmereUIExtendNameplates", private)
Check(private.GetHost() == host, "private helpers use selected core")
EllesmereUI = { sentinel = "suite" }
Check(core.GetHost() == EllesmereUI and private.GetHost() == EllesmereUI,
    "full suite takes precedence, never mixes cores")
EllesmereUI = nil
__EUISTANDALONE_NAMEPLATES_INERT = true
Check(core.GetHost() == nil and private.GetHost() == nil, "upstream conflict guard fails closed")
Check(not core.RegisterOptions(), "an inactive host cannot reuse a prior registration")
SlashCmdList.ELLESMEREUIEXTEND()
EllesmereUIExtendNameplates.Refresh()
Check(EllesmereUIExtendDB == saved, "inactive refresh preserves saved settings")
__EUISTANDALONE_NAMEPLATES_INERT = nil
EUI_CLIENT_BLOCKED = true
Check(core.GetHost() == nil and private.GetHost() == nil, "blocked client cannot select a host")
EUI_CLIENT_BLOCKED = nil
EUICoreStandaloneNameplates = nil
Check(core.GetHost() == nil and private.GetHost() == nil, "missing host fails closed")

-- Older embedded copies can win the singleton race after independent updates.
EllesmereUIExtend = { EmbeddedVersion = 1 }
EUICoreStandaloneNameplates = host
Check(private.GetHost() == host, "private adapter supports older embedded cores")
__EUISTANDALONE_NAMEPLATES_INERT = true
Check(private.GetHost() == nil, "older-core fallback respects conflict guard")
__EUISTANDALONE_NAMEPLATES_INERT = nil
EllesmereUIExtend = core
Check(_G.EllesmereUI == nil, "all host cases leave full-suite global untouched")
print("PASS: " .. checks .. " standalone host, UI/runtime, profiles, locks, conflict and missing-host checks")
