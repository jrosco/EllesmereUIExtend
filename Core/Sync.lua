-- Shared-profile synchronization. Feature copies initialize this module once.
local core = EllesmereUIExtend
if not core or not core.InitializePersistence then return end

core.InitializePersistence(function(core, Root, owners, features, owner)
    local Copy = core.Copy
    local records, assignments, settings, names, loaded = {}, {}, {}, {}, {}
    local revision, clock, sequence = 0, 0, 0
    local MAX_INTEGER = 9007199254740990

    local function Integer(value)
        return type(value) == "number" and value >= 0 and value <= MAX_INTEGER and value % 1 == 0
    end
    local function StampValid(stamp)
        return type(stamp) == "table" and Integer(stamp.at) and Integer(stamp.sequence)
            and type(stamp.owner) == "string"
    end
    local function Newer(a, b)
        if not b then return true end
        if a.at ~= b.at then return a.at > b.at end
        if a.sequence ~= b.sequence then return a.sequence > b.sequence end
        return a.owner > b.owner
    end
    local function Observe(stamp)
        clock, sequence = math.max(clock, stamp.at), math.max(sequence, stamp.sequence)
    end
    local function Stamp()
        if type(GetServerTime) == "function" then
            local ok, now = pcall(GetServerTime)
            if ok and not (type(issecretvalue) == "function" and issecretvalue(now)) and Integer(now) then
                clock = math.max(clock, now)
            end
        end
        sequence = sequence + 1
        return { at = clock, sequence = sequence, owner = owner }
    end
    local function Equal(a, b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return a == b end
        for key, value in pairs(a) do if not Equal(value, b[key]) then return false end end
        for key in pairs(b) do if a[key] == nil then return false end end
        return true
    end
    local function Ensure()
        for name in pairs(Root().profiles) do
            if not names[name] then
                local stamp = Stamp()
                local id = name == "Default" and "Default"
                    or stamp.owner .. ":" .. stamp.at .. ":" .. stamp.sequence
                names[name] = id
                records[id] = { name = name, deleted = false, stamp = stamp }
            end
        end
    end
    local function Valid(snapshot)
        if type(snapshot) ~= "table" or snapshot.format ~= 1 or not Integer(snapshot.revision)
            or type(snapshot.data) ~= "table" or type(snapshot.data.profiles) ~= "table"
            or type(snapshot.data.profiles.Default) ~= "table"
            or type(snapshot.data.characterProfiles) ~= "table" then return false end
        for name, profile in pairs(snapshot.data.profiles) do
            if type(name) ~= "string" or name == "" or type(profile) ~= "table" then return false end
            for key in pairs(profile) do if type(key) ~= "string" then return false end end
        end
        if snapshot.sync == nil then return true end
        local sync = snapshot.sync
        if type(sync) ~= "table" or sync.version ~= 1 or type(sync.profiles) ~= "table"
            or type(sync.assignments) ~= "table" or type(sync.features) ~= "table" then return false end
        local seen = {}
        for id, record in pairs(sync.profiles) do
            if type(id) ~= "string" or type(record) ~= "table" or type(record.name) ~= "string"
                or record.name == "" or type(record.deleted) ~= "boolean" or not StampValid(record.stamp)
                or (id == "Default" and (record.name ~= "Default" or record.deleted)) then return false end
            if not record.deleted then
                if seen[record.name] or type(snapshot.data.profiles[record.name]) ~= "table" then return false end
                for key in pairs(snapshot.data.profiles[record.name]) do
                    if type(key) ~= "string" or type(sync.features[id]) ~= "table"
                        or not StampValid(sync.features[id][key]) then return false end
                end
                seen[record.name] = true
            end
        end
        if not sync.profiles.Default then return false end
        for name in pairs(snapshot.data.profiles) do if not seen[name] then return false end end
        for character, entry in pairs(sync.assignments) do
            if type(character) ~= "string" or type(entry) ~= "table" or type(entry.id) ~= "string"
                or not StampValid(entry.stamp) then return false end
        end
        for id, entries in pairs(sync.features) do
            if type(id) ~= "string" or not sync.profiles[id] or type(entries) ~= "table" then return false end
            for key, stamp in pairs(entries) do
                if type(key) ~= "string" or not StampValid(stamp) then return false end
            end
        end
        return true
    end
    local function Metadata(snapshot, source)
        if snapshot.sync then return snapshot.sync end
        -- Additive metadata for current embedded snapshots without sync fields;
        -- never read standalone-core or legacy addon SavedVariables.
        local sync = { version = 1, profiles = {}, assignments = {}, features = {} }
        local stamp = { at = 0, sequence = snapshot.revision, owner = source }
        for name, profile in pairs(snapshot.data.profiles) do
            if type(name) == "string" and name ~= "" and type(profile) == "table" then
                local id = name == "Default" and "Default" or "profile:" .. name
                sync.profiles[id] = { name = name, deleted = false, stamp = stamp }
                sync.features[id] = {}
                for key in pairs(profile) do
                    -- A feature's own file is authoritative for pre-sync data.
                    local own = (key == "nameplates" and source == "EllesmereUIExtendNameplates")
                        or (key == "questTracker" and source == "EllesmereUIExtendQuestTracker")
                    sync.features[id][key] = own and stamp or { at = 0, sequence = 0, owner = source }
                end
            end
        end
        for character, name in pairs(snapshot.data.characterProfiles) do
            if type(character) == "string" and type(name) == "string" then
                sync.assignments[character] = { id = name == "Default" and "Default" or "profile:" .. name, stamp = stamp }
            end
        end
        return sync
    end
    local function Rebuild()
        local root = { profiles = {}, characterProfiles = {} }
        names = {}
        local ids = {}
        for id, record in pairs(records) do if not record.deleted then ids[#ids + 1] = id end end
        table.sort(ids, function(a, b)
            if a == b then return false end
            if a == "Default" then return true end
            if b == "Default" then return false end
            if Newer(records[a].stamp, records[b].stamp) then return true end
            if Newer(records[b].stamp, records[a].stamp) then return false end
            return a < b
        end)
        for _, id in ipairs(ids) do
            local record = records[id]
            local name, suffix = record.name, 2
            while names[name] do name = record.name .. " (" .. suffix .. ")"; suffix = suffix + 1 end
            -- Keep colliding independent creations, rather than dropping data.
            record.name, names[name], root.profiles[name] = name, id, {}
            for key, entry in pairs(settings[id] or {}) do root.profiles[name][key] = Copy(entry.value) end
        end
        if not root.profiles.Default then root.profiles.Default = {} end
        for character, entry in pairs(assignments) do
            local record = records[entry.id]
            root.characterProfiles[character] = record and not record.deleted and record.name or "Default"
        end
        EllesmereUIExtendDB = root
    end
    local function Load(name)
        loaded[name] = true
        local snapshot = _G[owners[name]]
        if not Valid(snapshot) then return end
        revision = math.max(revision, snapshot.revision)
        local sync = Metadata(snapshot, name)
        for id, record in pairs(sync.profiles) do
            Observe(record.stamp)
            local current = records[id]
            -- A deleted identity stays deleted, even if an offline stale copy
            -- is renamed later. Recreating a name creates a different identity.
            if not current or (record.deleted and not current.deleted)
                or (record.deleted == current.deleted and Newer(record.stamp, current.stamp)) then
                records[id] = Copy(record)
            end
            local profile = snapshot.data.profiles[record.name]
            if not record.deleted and type(profile) == "table" then
                settings[id] = settings[id] or {}
                for key, value in pairs(profile) do
                    local stamp = sync.features[id] and sync.features[id][key] or record.stamp
                    Observe(stamp)
                    if not settings[id][key] or Newer(stamp, settings[id][key].stamp) then
                        settings[id][key] = { value = Copy(value), stamp = Copy(stamp) }
                    end
                end
            end
        end
        for character, entry in pairs(sync.assignments) do
            Observe(entry.stamp)
            if not assignments[character] or Newer(entry.stamp, assignments[character].stamp) then
                assignments[character] = Copy(entry)
            end
        end
        Rebuild()
    end
    local function Save()
        Ensure()
        local root = Root()
        for name, profile in pairs(root.profiles) do
            local id = names[name]
            settings[id] = settings[id] or {}
            for key, value in pairs(profile) do
                local previous = settings[id][key]
                -- Only loaded features author changes; stale absent sections
                -- retain their original stamps when carried forward.
                if not previous or (features[key] and not Equal(previous.value, value)) then
                    settings[id][key] = { value = Copy(value), stamp = Stamp() }
                end
            end
        end
        local sync = { version = 1, profiles = Copy(records), assignments = Copy(assignments), features = {} }
        for id, entries in pairs(settings) do
            sync.features[id] = {}
            for key, entry in pairs(entries) do sync.features[id][key] = Copy(entry.stamp) end
        end
        revision = revision + 1
        for name in pairs(loaded) do
            _G[owners[name]] = { format = 1, revision = revision, data = Copy(root), sync = Copy(sync) }
        end
    end
    return {
        Ensure = Ensure, Load = Load, Save = Save,
        Select = function(character, name)
            assignments[character] = { id = names[name], stamp = Stamp() }
        end,
        Create = function(name)
            local stamp = Stamp()
            local id = stamp.owner .. ":" .. stamp.at .. ":" .. stamp.sequence
            names[name], records[id] = id, { name = name, deleted = false, stamp = stamp }
        end,
        Rename = function(old, name)
            local id = names[old]
            names[old], names[name] = nil, id
            records[id].name, records[id].stamp = name, Stamp()
        end,
        Delete = function(name)
            local id = names[name]
            names[name] = nil
            records[id].deleted, records[id].stamp = true, Stamp()
        end,
    }
end)
