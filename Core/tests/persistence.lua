-- Embedded copies, independent SavedVariables and uninstall/reinstall sessions.
SlashCmdList = {}
local frames, registrations, checks = {}, 0, 0
local clock = 1000
function GetServerTime() return clock end
function UnitFullName() return "Player", "Realm" end
function CreateFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    frames[#frames + 1] = frame
    return frame
end
EllesmereUI = { RegisterPlugin = function(id, spec)
    assert(id == "EllesmereUIExtend" and spec.label == "Extend Addons")
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
    clock = clock + 10
    frames, registrations = {}, 0
    EllesmereUIExtend = nil
    EllesmereUIExtendDB = { oldStandalone = true }
    EllesmereUIExtendNameplatesProfiles, EllesmereUIExtendQuestTrackerProfiles = nil, nil
    local first
    for _, key in ipairs(order) do
        local owner = owners[key]
        assert(loadfile("Core/Core.lua"))(owner)
        assert(loadfile("Core/Sync.lua"))(owner)
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
-- A single counter for the whole root used to discard one of these edits.
for _, reverse in ipairs({ false, true }) do
    local order = reverse and { "questTracker", "nameplates" } or { "nameplates", "questTracker" }
    local core = Start({ "nameplates", "questTracker" })
    Check(core.CreateProfile("Shared"), "fork base profile")
    core.GetSettings("nameplates").value = 1
    core.GetSettings("questTracker").value = 2
    local base = Save(core)
    core = Start({ "nameplates" }, { nameplates = base.nameplates })
    core.GetSettings("nameplates").value = 101
    Check(core.RenameProfile("Renamed"), "rename preserves stable profile identity")
    local np = Save(core)
    core = Start({ "questTracker" }, { questTracker = base.questTracker })
    core.GetSettings("questTracker").value = 202
    local qt = Save(core)
    for _ = 1, 3 do
        core = Start({ "questTracker" }, { questTracker = qt.questTracker })
        qt = Save(core)
    end
    Check(qt.questTracker.revision > np.nameplates.revision, "unchanged stale sessions can have higher diagnostic revisions")
    core = Start(order, { nameplates = np.nameplates, questTracker = qt.questTracker })
    Check(core.GetProfileInfo().active == "Renamed" and EllesmereUIExtendDB.profiles.Shared == nil,
        "rename is shared even when other feature edited stale name")
    Check(core.GetSettings("nameplates").value == 101 and core.GetSettings("questTracker").value == 202,
        "independent feature edits survive even when stale snapshot has more sessions")
    local combined = Save(core)
    core = Start(order, combined)
    Check(core.GetSettings("nameplates").value == 101 and core.GetSettings("questTracker").value == 202,
        "merged edits survive another reload")

    core = Start({ "nameplates" }, { nameplates = combined.nameplates })
    Check(core.DeleteProfile("Renamed"), "delete named fork profile")
    local deleted = Save(core)
    core = Start({ "questTracker" }, { questTracker = combined.questTracker })
    core.GetSettings("questTracker").value = 303
    local laterEdit = Save(core)
    core = Start(order, { nameplates = deleted.nameplates, questTracker = laterEdit.questTracker })
    Check(EllesmereUIExtendDB.profiles.Renamed == nil and core.GetProfileInfo().active == "Default",
        "even a later stale feature edit cannot resurrect an explicitly deleted profile")
    core = Start({ "questTracker" }, { questTracker = combined.questTracker })
    Check(core.RenameProfile("Stale rename"), "offline stale copy can rename before learning of deletion")
    local staleRename = Save(core)
    core = Start(order, { nameplates = deleted.nameplates, questTracker = staleRename.questTracker })
    Check(EllesmereUIExtendDB.profiles["Stale rename"] == nil and core.GetProfileInfo().active == "Default",
        "deletion wins even over a later stale rename")
    Check(core.CreateProfile("Renamed"), "recreating deleted name gets a new identity")
    Check(core.GetSettings("questTracker").value == 0, "recreated profile cannot inherit deleted-generation settings")

    local invalid = { format = 1, revision = 999, data = {} }
    core = Start(order, { nameplates = combined.nameplates, questTracker = invalid })
    Check(core.GetSettings("nameplates").value == 101, "empty high-revision snapshot cannot replace valid profiles")
    invalid = core.Copy(combined.questTracker)
    invalid.sync.profiles.Default.stamp.sequence = math.huge
    core = Start(order, { nameplates = combined.nameplates, questTracker = invalid })
    Check(core.GetSettings("questTracker").value == 202, "invalid sync metadata is rejected before any partial merge")
    invalid = core.Copy(combined.questTracker)
    invalid.sync = nil
    core = Start(order, { nameplates = combined.nameplates, questTracker = invalid })
    Check(core.GetSettings("nameplates").value == 101 and core.GetSettings("questTracker").value == 202,
        "snapshot without required metadata cannot replace a valid snapshot")
    core = Start({ "questTracker" }, { questTracker = invalid })
    Check(core.GetSettings("questTracker").value == 0 and core.GetProfileInfo().active == "Default",
        "snapshot without required metadata rejected rather than converted")
end

local core = Start({ "nameplates", "questTracker" })
local base = Save(core)
core = Start({ "nameplates" }, { nameplates = base.nameplates })
Check(core.CreateProfile("Same name"), "independent Nameplates profile")
core.GetSettings("nameplates").value = 111
local np = Save(core)
core = Start({ "questTracker" }, { questTracker = base.questTracker })
Check(core.CreateProfile("Same name"), "independent QuestTracker profile")
core.GetSettings("questTracker").value = 222
local qt = Save(core)
for _, order in ipairs({ { "nameplates", "questTracker" }, { "questTracker", "nameplates" } }) do
    core = Start(order, { nameplates = np.nameplates, questTracker = qt.questTracker })
    local foundNP, foundQT = false, false
    for _, profile in pairs(EllesmereUIExtendDB.profiles) do
        if profile.nameplates and profile.nameplates.value == 111 then foundNP = true end
        if profile.questTracker and profile.questTracker.value == 222 then foundQT = true end
    end
    Check(foundNP and foundQT and EllesmereUIExtendDB.profiles["Same name (2)"],
        "same-name independent creations are retained with deterministic suffix")
end
GetServerTime = function() error("unavailable clock") end
core = Start({ "nameplates" }, { nameplates = np.nameplates })
Check(core.RenameProfile("Clock fallback"), "unavailable server clock uses logical stamp fallback")
Check(Save(core).nameplates.sync ~= nil, "clock fallback still persists sync metadata")
print("PASS: " .. checks .. " embedded singleton, load orders, profile snapshots, reload, uninstall and stale reinstall checks")
