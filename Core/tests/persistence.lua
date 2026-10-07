-- Embedded copies, independent SavedVariables and uninstall/reinstall sessions.
SlashCmdList = {}
local frames, registrations, checks = {}, 0, 0
function UnitFullName() return "Player", "Realm" end
function CreateFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    frames[#frames + 1] = frame
    return frame
end
EllesmereUI = { RegisterPlugin = function(id, spec)
    assert(id == "EllesmereUIExtend" and spec.label == "Extend")
    registrations = registrations + 1
    return true
end }
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Event(event, name)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.scripts.OnEvent(frame, event, name) end
    end
end
local owners = { nameplates = "EllesmereUIExtendNameplates", questTracker = "EllesmereUIExtendQuestTracker" }
local function Start(order, snapshots)
    frames, registrations = {}, 0
    EllesmereUIExtend = nil
    EllesmereUIExtendDB = { oldStandalone = true }
    EllesmereUIExtendNameplatesProfiles, EllesmereUIExtendQuestTrackerProfiles = nil, nil
    local first
    for _, key in ipairs(order) do
        local owner = owners[key]
        assert(loadfile("Core/Core.lua"))(owner)
        assert(loadfile("Core/Options.lua"))(owner)
        if first then Check(first == EllesmereUIExtend, "embedded copies share one runtime") end
        first = EllesmereUIExtend
        Check(first.RegisterFeature(key, { defaults = { value = 0 } }), "each feature registers once")
        -- WoW restores each feature's distinct SavedVariable before ADDON_LOADED.
        _G[owner .. "Profiles"] = snapshots and snapshots[key] and first.Copy(snapshots[key]) or nil
        Event("ADDON_LOADED", owner)
        first.GetSettings(key) -- early feature initialization before the other loads
    end
    Event("PLAYER_LOGIN")
    Check(registrations == 1, "only one Profiles UI/plugin registration")
    Check(EllesmereUIExtendDB.oldStandalone == nil, "no migration from standalone-core data")
    return first
end
local function Save(core)
    Event("PLAYER_LOGOUT")
    return { nameplates = core.Copy(EllesmereUIExtendNameplatesProfiles),
        questTracker = core.Copy(EllesmereUIExtendQuestTrackerProfiles) }
end

for _, forever in ipairs({ false, true }) do
    EUI_CLIENT_FOREVER = forever
    local core = Start({ "nameplates", "questTracker" })
    Check(core.CreateProfile("Shared"), "create shared named profile")
    core.GetSettings("nameplates").value = 11
    core.GetSettings("questTracker").value = 22
    EllesmereUIExtendDB.profiles.Shared.absentFeature = { value = 33 }
    local both = Save(core)
    Check(both.nameplates.revision == 1 and both.questTracker.revision == 1, "both owners save the same revision")
    Check(both.nameplates.data ~= both.questTracker.data, "each owner has an independent snapshot")
    for _, order in ipairs({ { "nameplates", "questTracker" }, { "questTracker", "nameplates" } }) do
        core = Start(order, both)
        Check(core.GetProfileInfo().active == "Shared" and core.GetSettings("nameplates").value == 11
            and core.GetSettings("questTracker").value == 22, "both loading orders restore shared settings")
    end
    -- Either extension can survive alone with the full shared data, even if the
    -- addon manager also removes the other feature's SavedVariables file.
    for _, remaining in ipairs({ "nameplates", "questTracker" }) do
        local alone = { [remaining] = both[remaining] }
        core = Start({ remaining }, alone)
        Check(core.GetProfileInfo().active == "Shared" and core.GetSettings(remaining).value ~= 0,
            "uninstalling either addon preserves surviving profiles")
        Check(EllesmereUIExtendDB.profiles.Shared.absentFeature.value == 33,
            "absent feature sections are preserved")
        Check(core.DeleteProfile("Shared"), "delete shared profile while other addon is absent")
        core.GetSettings(remaining).value = 44
        local updated = Save(core)
        Check(updated[remaining].revision == 2, "single-addon session advances revision")
        local reinstalled = { nameplates = both.nameplates, questTracker = both.questTracker }
        reinstalled[remaining] = updated[remaining]
        for _, order in ipairs({ { "nameplates", "questTracker" }, { "questTracker", "nameplates" } }) do
            core = Start(order, reinstalled)
            Check(core.GetProfileInfo().active == "Default" and EllesmereUIExtendDB.profiles.Shared == nil,
                "stale returning addon cannot resurrect deleted profile or assignment")
            Check(core.GetSettings(remaining).value == 44, "newer surviving settings win in either load order")
            local synchronized = Save(core)
            Check(synchronized.nameplates.revision == 3 and synchronized.questTracker.revision == 3,
                "returning addon receives current snapshot at logout")
            Check(synchronized.nameplates.data.profiles.Shared == nil
                and synchronized.questTracker.data.profiles.Shared == nil, "deletion persists to both files")
        end
    end
    core = Start({ "nameplates" }, { nameplates = { format = 1, revision = -1, data = {} } })
    Check(core.GetSettings("nameplates").value == 0, "invalid revision rejected")
    local snapshot = Save(core).nameplates
    Check(snapshot.revision == 1, "bad snapshot does not poison saved revision")
end
print("PASS: " .. checks .. " embedded singleton, load orders, profile snapshots, reload, uninstall and stale reinstall checks")
