local addonName = ...
if EUI_CLIENT_BLOCKED then return end

-- Every feature embeds these files. Only the first copy creates the runtime.
local existing = _G.EllesmereUIExtend
if existing and existing.EmbeddedVersion then
    existing.RegisterOwner(addonName)
    return
end
local core = { PluginID = "EllesmereUIExtend", MaxProfiles = 100, APIVersion = 1, EmbeddedVersion = 1 }
_G.EllesmereUIExtend = core
local features, modules = {}, {}
local store, activeName, character
local owners = {}
local persistence
-- This is an in-memory root, not a SavedVariable. Old standalone-core data
-- is deliberately not imported into the embedded architecture.
_G.EllesmereUIExtendDB = nil

function core.RegisterOwner(name)
    if name == "EllesmereUIExtendNameplates" then
        owners[name] = "EllesmereUIExtendNameplatesProfiles"
    elseif name == "EllesmereUIExtendQuestTracker" then
        owners[name] = "EllesmereUIExtendQuestTrackerProfiles"
    elseif name == "EllesmereUIExtendBags" then
        owners[name] = "EllesmereUIExtendBagsProfiles"
    end
end
core.RegisterOwner(addonName)

-- The standalone bundles the same APIs under a private core name. Never
-- publish aliases or select a standalone that upstream has made inert.
function core.GetHost()
    if EUI_CLIENT_BLOCKED then return nil end
    if _G.EllesmereUI then return _G.EllesmereUI end
    if not _G.__EUISTANDALONE_NAMEPLATES_INERT then
        return _G.EUICoreStandaloneNameplates
    end
end

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end
core.Copy = Copy

local function ReadString(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value, second = pcall(func, ...)
    if not ok then return nil end
    if Secret(value) or type(value) ~= "string" or value == "" then value = nil end
    if Secret(second) or type(second) ~= "string" or second == "" then second = nil end
    return value, second
end

local function CharacterKey()
    local name, realm = ReadString(UnitFullName, "player")
    name = name or ReadString(UnitName, "player")
    if not name then return nil end
    realm = realm or ReadString(GetRealmName)
    if not realm then return nil end
    return name .. " - " .. realm
end

local function Store()
    local saved = _G.EllesmereUIExtendDB
    if type(saved) ~= "table" then saved = {} end
    if type(saved.profiles) ~= "table" then saved.profiles = {} end
    if type(saved.profiles.Default) ~= "table" then saved.profiles.Default = {} end
    if type(saved.characterProfiles) ~= "table" then saved.characterProfiles = {} end
    -- Do not normalize absent feature sections: a disabled/uninstalled addon
    -- retains its exact settings until it is installed and accesses them again.
    if store ~= saved then
        for name, profile in pairs(saved.profiles) do
            if type(name) ~= "string" or name == "" or type(profile) ~= "table" then
                saved.profiles[name] = nil
            end
        end
    end
    character = CharacterKey()
    local selected = character and saved.characterProfiles[character]
    if type(selected) ~= "string" or type(saved.profiles[selected]) ~= "table" then selected = "Default" end
    if character then saved.characterProfiles[character] = selected end
    store, activeName = saved, selected
    _G.EllesmereUIExtendDB = saved
    return saved.profiles[selected]
end

function core.InitializePersistence(factory)
    persistence = factory(core, function() Store(); return store end, owners, features, addonName)
    core.InitializePersistence = nil
end

function core.RegisterFeature(key, spec)
    if type(key) ~= "string" or not key:match("^%a[%w_]*$") or features[key]
        or type(spec) ~= "table" or type(spec.defaults) ~= "table" then return false end
    features[key] = { defaults = Copy(spec.defaults), normalize = spec.normalize, refresh = spec.refresh,
        normalized = setmetatable({}, { __mode = "k" }) }
    return true
end

function core.GetSettings(key)
    local feature = assert(features[key], "Unregistered EllesmereUI Extend feature")
    local profile = Store()
    local settings = profile[key]
    if type(settings) ~= "table" then settings = Copy(feature.defaults); profile[key] = settings end
    if not feature.normalized[settings] then
        if feature.normalize then settings = feature.normalize(settings) end
        assert(type(settings) == "table", "Feature normalizer must return a settings table")
        profile[key], feature.normalized[settings] = settings, true
    end
    return settings, activeName, store
end

function core.GetProfileInfo()
    Store()
    local names, other = { "Default" }, {}
    for name in pairs(store.profiles) do if name ~= "Default" then other[#other + 1] = name end end
    table.sort(other, function(a, b) return a:lower() < b:lower() end)
    for _, name in ipairs(other) do names[#names + 1] = name end
    return { active = activeName, names = names, character = character or "Character not available yet",
        canManage = character ~= nil }
end

local function Changed()
    for key, feature in pairs(features) do
        core.GetSettings(key)
        if feature.refresh then feature.refresh() end
    end
    if core.RefreshOptions then core.RefreshOptions() end
end

local function Manage()
    Store()
    if persistence then persistence.Ensure() end
    if not character then return false, "The character name and realm are not available yet." end
    local host = core.GetHost()
    if host and type(host.IsUnlockModeActive) == "function" then
        local ok, editing = pcall(host.IsUnlockModeActive, host)
        if not ok or Secret(editing) or editing then return false, "Finish EUI Edit Mode before changing profiles." end
    end
    return true
end

local function CleanName(name)
    if Secret(name) or type(name) ~= "string" then return nil, "Enter a profile name." end
    name = name:gsub("|", ""):gsub("%c", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > 32 then return nil, "Use a profile name of 1-32 characters." end
    if name:lower() == "default" then return nil, "Default is reserved." end
    for existing in pairs(store.profiles) do
        if existing:lower() == name:lower() and existing ~= activeName then
            return nil, "A profile with that name already exists."
        end
    end
    return name
end

function core.SelectProfile(name)
    local ok, err = Manage()
    if not ok then return false, err end
    if Secret(name) or type(name) ~= "string" or type(store.profiles[name]) ~= "table" then
        return false, "That profile does not exist."
    end
    store.characterProfiles[character] = name
    if persistence then persistence.Select(character, name) end
    Changed()
    return true
end

function core.CreateProfile(name)
    local ok, err = Manage()
    if not ok then return false, err end
    name, err = CleanName(name)
    if not name then return false, err end
    for existing in pairs(store.profiles) do
        if existing:lower() == name:lower() then return false, "A profile with that name already exists." end
    end
    local count = 0
    for _ in pairs(store.profiles) do count = count + 1 end
    if count >= core.MaxProfiles then return false, "You can have up to 100 profiles." end
    store.profiles[name] = {}
    store.characterProfiles[character] = name
    if persistence then persistence.Create(name); persistence.Select(character, name) end
    Changed()
    return true
end

function core.RenameProfile(name)
    local ok, err = Manage()
    if not ok then return false, err end
    if activeName == "Default" then return false, "Default cannot be renamed." end
    name, err = CleanName(name)
    if not name then return false, err end
    if name == activeName then return true end
    local old = activeName
    store.profiles[name], store.profiles[old] = store.profiles[old], nil
    if persistence then persistence.Rename(old, name) end
    for key, assigned in pairs(store.characterProfiles) do
        if assigned == old then store.characterProfiles[key] = name end
    end
    Changed()
    return true
end

function core.DeleteProfile(expectedName)
    local ok, err = Manage()
    if not ok then return false, err end
    -- Confirmations may outlive a profile switch. Never delete a different profile.
    if Secret(expectedName) then return false, "The active profile is unreadable." end
    if expectedName and expectedName ~= activeName then return false, "The active profile changed." end
    if activeName == "Default" then return false, "Default cannot be deleted." end
    local old = activeName
    store.profiles[old] = nil
    if persistence then persistence.Delete(old) end
    for key, assigned in pairs(store.characterProfiles) do
        if assigned == old then store.characterProfiles[key] = "Default" end
    end
    Changed()
    return true
end

function core.ResetFeature(key)
    local current = core.GetSettings(key)
    local feature = features[key]
    local fresh = Copy(feature.defaults)
    if feature.normalize then fresh = feature.normalize(fresh) end
    for name in pairs(current) do current[name] = nil end
    for name, value in pairs(fresh) do current[name] = value end
    if feature.refresh then feature.refresh() end
    if core.RefreshOptions then core.RefreshOptions() end
    return true
end

function core.RegisterModule(spec)
    if core.pluginRegistered or type(spec) ~= "table" or type(spec.key) ~= "string" or modules[spec.key] then
        return false
    end
    modules[spec.key] = spec
    return true
end

function core.GetModules()
    local result = {}
    for _, spec in pairs(modules) do result[#result + 1] = spec end
    table.sort(result, function(a, b) return a.key < b.key end)
    return result
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and owners[name] then
        if persistence then persistence.Load(name) end
        Store()
    end
    if event == "PLAYER_LOGIN" then
        Changed()
        if core.RegisterOptions then core.RegisterOptions() end
    end
    if event == "PLAYER_LOGOUT" then
        if persistence then persistence.Save() end
    end
end)
