SlashCmdList = {}
local frames, checks, registrations = {}, 0, 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
function UnitFullName() return "Player", "Realm" end
function GetServerTime() return 1000 end
function CreateFrame()
    local f = { events = {}, scripts = {} }
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(event, callback) self.scripts[event] = callback end
    frames[#frames + 1] = f
    return f
end
EllesmereUI = { RegisterPlugin = function() registrations = registrations + 1; return true end }
local function Event(event, name)
    for _, f in ipairs(frames) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, name) end end
end
local owners = { bags = "Bags", nameplates = "Nameplates", questTracker = "QuestTracker" }
local orders = { { "bags" }, { "bags", "nameplates" }, { "nameplates", "bags" },
    { "bags", "questTracker" }, { "questTracker", "bags" },
    { "bags", "nameplates", "questTracker" }, { "bags", "questTracker", "nameplates" },
    { "nameplates", "bags", "questTracker" }, { "nameplates", "questTracker", "bags" },
    { "questTracker", "bags", "nameplates" }, { "questTracker", "nameplates", "bags" } }
local bank = { format = 1, characters = { ["Player - Realm"] = { inventoryMarker = true } } }
for _, order in ipairs(orders) do
    frames, registrations = {}, 0
    EllesmereUIExtend, EllesmereUIExtendDB = nil, nil
    EllesmereUIExtendNameplatesProfiles, EllesmereUIExtendQuestTrackerProfiles, EllesmereUIExtendBagsProfiles = nil, nil, nil
    EllesmereUIExtendBagsDB = bank
    for _, key in ipairs(order) do
        local name = "EllesmereUIExtend" .. owners[key]
        for _, file in ipairs({ "Core", "Sync", "Options" }) do assert(loadfile("Core/" .. file .. ".lua"))(name) end
        if key == "bags" then
            local ns = {}
            assert(loadfile("Bags/Compatibility.lua"))(name, ns)
            assert(loadfile("Bags/Bags.lua"))(name, ns)
        else EllesmereUIExtend.RegisterFeature(key, { defaults = { value = 0 } }) end
        Event("ADDON_LOADED", name)
    end
    Event("PLAYER_LOGIN")
    local core = EllesmereUIExtend
    Check(registrations == 1, "one combined settings registration in every load order")
    Check(core.GetSettings("bags").showButton == true, "Bags defaults available")
    Check(core.CreateProfile("Other"), "Bags can create shared profile")
    core.GetSettings("bags").showButton = false
    Check(core.SelectProfile("Default"), "Bags can switch shared profiles")
    Check(core.GetSettings("bags").showButton, "Bags settings isolated by profile")
    Check(core.SelectProfile("Other"), "restore selected profile")
    Check(not core.GetSettings("bags").showButton, "selected profile retains settings")
    core.ResetFeature("bags")
    Check(core.GetSettings("bags").showButton and EllesmereUIExtendBagsDB == bank, "reset does not touch inventory")
    Event("PLAYER_LOGOUT")
    Check(EllesmereUIExtendBagsProfiles and EllesmereUIExtendBagsProfiles.format == 1, "Bags owner persists independently")
    Check(EllesmereUIExtendBagsProfiles.data.profiles.Other.bags.showButton, "Bags settings included in own profile snapshot")
    for _, key in ipairs(order) do
        local snapshot = _G["EllesmereUIExtend" .. owners[key] .. "Profiles"]
        Check(snapshot.data.profiles.Other.bags.showButton, "other installed owners preserve Bags feature section")
    end
    -- Reload only Bags with its own snapshot (other extensions uninstalled).
    local saved = core.Copy(EllesmereUIExtendBagsProfiles)
    frames, registrations = {}, 0
    EllesmereUIExtend, EllesmereUIExtendDB = nil, nil
    for _, file in ipairs({ "Core", "Sync", "Options" }) do assert(loadfile("Core/" .. file .. ".lua"))("EllesmereUIExtendBags") end
    EllesmereUIExtend.RegisterFeature("bags", { defaults = { showButton = true } })
    EllesmereUIExtendBagsProfiles = saved
    Event("ADDON_LOADED", "EllesmereUIExtendBags")
    Event("PLAYER_LOGIN")
    Check(EllesmereUIExtend.GetProfileInfo().active == "Other", "Bags-alone reload preserves shared assignments")
    Check(EllesmereUIExtendBagsDB == bank, "inventory survives uninstall/reload and profile restoration")
end
print("PASS: " .. checks .. " Bags independent persistence and all shared load orders")
