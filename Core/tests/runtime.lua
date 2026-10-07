-- Run from the repository root with Lua or Fengari. Uses real feature adapters.
SlashCmdList = {}
local frames, checks, registered, registrations = {}, 0, nil, 0
local player, realm, editing, activeModule = "CoreCharacter", "TestRealm", false, nil
local inputPopup, confirmPopup, rows = nil, nil, {}
local secret = {}
function issecretvalue(value) return rawequal(value, secret) end
function UnitFullName() return player, realm end
function CreateFrame()
    local frame = { events = {}, scripts = {} }
    frames[#frames + 1] = frame
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    return frame
end
C_Timer = { After = function() end }
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Event(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
end
local invalidated, rebuilds = {}, 0
EllesmereUI = {
    RegisterPlugin = function(id, spec)
        Check(id == "EllesmereUIExtend", "one shared plugin ID")
        Check(spec.label == "Extend" and not spec.label:lower():find("^ellesmere")
            and not spec.label:lower():find("^eui"), "shared label respects EUI's reserved-label policy")
        registrations, registered = registrations + 1, spec
        return true
    end,
    IsUnlockModeActive = function() return editing end,
    GetActiveModule = function() return activeModule end,
    GetPluginModuleKey = function(_, key) return "plugin:EllesmereUIExtend:" .. key end,
    InvalidateModulePageCache = function(_, key) invalidated[key] = true end,
    RefreshPage = function() rebuilds = rebuilds + 1 end,
    ClearContentHeader = function() end,
    IsSearchPrebuild = function() return false end,
    ShowInputPopup = function(_, spec) inputPopup = spec end,
    ShowConfirmPopup = function(_, spec) confirmPopup = spec end,
    PrintError = function() end,
    OpenPlugin = function(id, key) Check(id == "EllesmereUIExtend" and key == "Profiles", "core slash opens profiles") end,
    Widgets = {
        SectionHeader = function() return {}, 30 end,
        Dropdown = function(_, _, label, _, _, get, set)
            rows[label] = { get = get, set = set }; return {}, 40
        end,
        WideButton = function(_, _, label, _, click)
            rows[label] = { click = click }; return {}, 40
        end,
    },
}

local function Load(which, forever)
    frames, registrations, registered, rows = {}, 0, nil, {}
    EllesmereUIExtend, EllesmereUIExtendDB = nil, nil
    EllesmereUIExtendNameplatesProfiles, EllesmereUIExtendQuestTrackerProfiles = nil, nil
    EUI_CLIENT_FOREVER = forever
    if which ~= "quest" then
        assert(loadfile("Core/Core.lua"))("EllesmereUIExtendNameplates")
        assert(loadfile("Core/Options.lua"))("EllesmereUIExtendNameplates")
        local ns = {}
        assert(loadfile("Nameplates/Helpers.lua"))("EllesmereUIExtendNameplates", ns)
        assert(loadfile("Nameplates/Nameplates.lua"))("EllesmereUIExtendNameplates", ns)
        assert(loadfile("Nameplates/Options.lua"))("EllesmereUIExtendNameplates", ns)
    end
    if which ~= "nameplates" then
        assert(loadfile("Core/Core.lua"))("EllesmereUIExtendQuestTracker")
        assert(loadfile("Core/Options.lua"))("EllesmereUIExtendQuestTracker")
        local ns = {}
        assert(loadfile("QuestTracker/Compatibility.lua"))("EllesmereUIExtendQuestTracker", ns)
        assert(loadfile("QuestTracker/QuestTracker.lua"))("EllesmereUIExtendQuestTracker", ns)
        assert(loadfile("QuestTracker/Options.lua"))("EllesmereUIExtendQuestTracker", ns)
    end
    Check(registrations == 0, "feature registration waits until login")
    Check(EllesmereUIExtendDB == nil, "no early saved database initialization")
    if which ~= "quest" then Event("ADDON_LOADED", "EllesmereUIExtendNameplates") end
    if which ~= "nameplates" then Event("ADDON_LOADED", "EllesmereUIExtendQuestTracker") end
    Event("PLAYER_LOGIN")
    Check(registrations == 1, "hub registered exactly once at login")
    local keys = {}
    for _, spec in ipairs(registered.modules) do keys[spec.key] = true end
    Check(keys.Profiles and ((not not keys.NameplateStyle) == (which ~= "quest"))
        and ((not not keys.QuestTracker) == (which ~= "nameplates")), "only installed feature modules appear")
    Check(EllesmereUIExtend.RegisterOptions() and registrations == 1, "hub registration is idempotent")
    return EllesmereUIExtend
end

-- Old databases must be ignored and left untouched, not migrated or aliased.
EllesmereUIExtendNameplatesDB = { sentinel = "old nameplates" }
EllesmereUIExtendQuestTrackerDB = { sentinel = "old quests" }
local oldNP, oldQT = EllesmereUIExtendNameplatesDB, EllesmereUIExtendQuestTrackerDB
for _, forever in ipairs({ false, true }) do
    for _, which in ipairs({ "nameplates", "quest", "both" }) do Load(which, forever) end
end
Check(EllesmereUIExtendNameplatesDB == oldNP and EllesmereUIExtendQuestTrackerDB == oldQT,
    "old addon databases are untouched")
local core = EllesmereUIExtend
local np, qt = EllesmereUIExtendNameplates, EllesmereUIExtendQuestTracker
local defaultsNP, defaultsQT = np.GetSettings(), qt.Settings()
Check(defaultsNP == EllesmereUIExtendDB.profiles.Default.nameplates
    and defaultsQT == EllesmereUIExtendDB.profiles.Default.questTracker, "both adapters use the same saved profile root")
defaultsNP.rules[1].name = "Shared default rule"
defaultsQT.itemX = 246
EllesmereUIExtendDB.profiles.Default.absentFeature = { nested = { preserve = true } }
local absent = EllesmereUIExtendDB.profiles.Default.absentFeature
Check(core.CreateProfile("Tank"), "create shared profile")
Check(np.GetProfileInfo().active == "Tank" and np.GetSettings() ~= defaultsNP and qt.Settings() ~= defaultsQT,
    "both features switch together")
Check(np.GetSettings().rules[1].name ~= "Shared default rule" and qt.Settings().itemX == 0,
    "new profiles start with independent fresh defaults")
np.GetSettings().rules[1].name = "Tank rule"
qt.Settings().itemX = 777
local tankQT = qt.Settings()
Check(core.ResetFeature("nameplates") and qt.Settings() == tankQT and tankQT.itemX == 777,
    "feature reset cannot reset the other feature")
Check(core.RenameProfile("Raid"), "rename shared profile")
Check(core.GetProfileInfo().active == "Raid" and qt.Settings() == tankQT, "rename preserves settings identity")
Check(not core.CreateProfile("raid") and not core.CreateProfile("Default") and not core.CreateProfile(string.rep("x", 33)),
    "duplicate, reserved and overlong names rejected")
player = "OtherCharacter"
Check(core.GetProfileInfo().active == "Default" and qt.Settings().itemX == 246, "unassigned character starts on Default")
Check(core.SelectProfile("Raid") and qt.Settings().itemX == 777, "another character shares named settings")
Check(core.RenameProfile("Shared Raid"), "rename from second character")
player = "CoreCharacter"
Check(core.GetProfileInfo().active == "Shared Raid", "rename updates all assigned characters")
editing = true
Check(not core.SelectProfile("Default") and not core.DeleteProfile() and not core.CreateProfile("Blocked"),
    "profile management is gated during EUI Edit Mode")
editing = secret
Check(not core.SelectProfile("Default"), "unreadable edit state fails closed")
editing = false
Check(core.DeleteProfile("Shared Raid"), "delete shared profile")
Check(core.GetProfileInfo().active == "Default" and qt.Settings() == defaultsQT
    and EllesmereUIExtendDB.profiles.Default.absentFeature == absent, "delete restores Default and preserves absent feature data")
player = "OtherCharacter"
Check(core.GetProfileInfo().active == "Default", "delete updates all assigned characters")
Check(not core.DeleteProfile() and not core.RenameProfile("Not Default"), "Default is protected")

local profiles
for _, spec in ipairs(registered.modules) do if spec.key == "Profiles" then profiles = spec end end
Check(#profiles.pages == 1 and profiles.pages[1] == "Profiles", "shared Profiles has no About tab")
activeModule = "plugin:EllesmereUIExtend:Profiles"
profiles.buildPage("Profiles", {}, 0)
rows["Create Profile"].click(); inputPopup.onConfirm("UI Profile")
Check(core.GetProfileInfo().active == "UI Profile", "actual profile UI create callback")
profiles.buildPage("Profiles", {}, 0)
rows["Rename Profile"].click()
Check(core.SelectProfile("Default"), "switch while rename popup is open")
inputPopup.onConfirm("Stale rename")
Check(EllesmereUIExtendDB.profiles["Stale rename"] == nil, "stale rename cannot affect another profile")
Check(core.SelectProfile("UI Profile"), "restore UI profile")
profiles.buildPage("Profiles", {}, 0)
rows["Delete Active Profile"].click()
Check(core.SelectProfile("Default"), "switch while delete popup is open")
confirmPopup.onConfirm()
Check(EllesmereUIExtendDB.profiles["UI Profile"] ~= nil, "stale delete cannot affect another profile")
Check(invalidated["plugin:EllesmereUIExtend:NameplateStyle"] and invalidated["plugin:EllesmereUIExtend:QuestTracker"]
    and invalidated["plugin:EllesmereUIExtend:Profiles"] and rebuilds > 0, "switch invalidates extension pages and refreshes active hub page")
SlashCmdList.ELLESMEREUIEXTEND()

-- Saved root replacement/reload and clients with missing or restricted identity APIs.
EllesmereUIExtendDB = core.Copy(EllesmereUIExtendDB)
Check(qt.Settings() ~= defaultsQT and qt.Settings().itemX == 246, "replacement root rebinds feature adapters")
player = secret
Check(not core.GetProfileInfo().canManage and not core.CreateProfile("Secret"), "secret character names are never inspected")
player, realm = "OtherCharacter", secret
Check(not core.GetProfileInfo().canManage, "unknown realm cannot collide with another character")
realm = "TestRealm"
issecretvalue = nil
Check(core.GetProfileInfo().canManage and core.SelectProfile("UI Profile"), "Forever readable fallback without secret API")
Check(not core.RegisterModule({ key = "Late" }), "startup-only module contract rejects late registrations")
Check(not core.RegisterFeature("questTracker", { defaults = {} }), "duplicate feature keys rejected")
print("PASS: " .. checks .. " shared core, real feature adapters, install combinations, profiles, UI, preservation and client gates")
