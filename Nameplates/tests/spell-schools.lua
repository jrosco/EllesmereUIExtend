-- Run from the repository root with Lua or fengari. Reuses the unchanged mocks,
-- but owns its school cases and API variants (no shared fixture modifications).
local fixture = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local api, namespace, mocks = fixture.api, fixture.namespace, fixture.mocks
local cases, readerCalls, queued = 0, 0, 0
local restrictedValue
local originalSecret = issecretvalue
issecretvalue = function(value)
    return originalSecret(value) or (restrictedValue ~= nil and value == restrictedValue)
end
bit = { band = function(a, b)
    assert(not issecretvalue or not issecretvalue(a), "bit operation on restricted school")
    return math.floor(a / b) % 2 == 1 and b or 0
end }
fixture.Fire("ADDON_LOADED", "EllesmereUIExtendNameplates")
local frame
for _, candidate in ipairs(fixture.frames) do
    if candidate.events.NAME_PLATE_UNIT_ADDED then frame = candidate; break end
end
assert(frame, "runtime event frame missing")
local function Equal(actual, expected, label)
    cases = cases + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local rule = { name = "School probe", enabled = true, conditions = { spellSchool = { fire = true } }, style = {} }
api.GetSettings().enabled = true
api.GetSettings().rules = { rule }
local spellID = 1000
local payload = {}
local function Reader()
    readerCalls = readerCalls + 1
    return unpack(payload, 1, 14)
end
local function Refresh() api.Refresh(); fixture.Flush() end
local function Cast(id)
    mocks.casting = { "Cast", nil, nil, nil, nil, nil, nil, false, id }
end
local function School()
    local _, _, traits = namespace.FindRule("nameplate1")
    return traits.spellSchool
end
local function Emit(subevent, id, mask)
    payload = { [2] = subevent, [12] = id, [14] = mask }
    -- Direct invocation also exercises stale callbacks after capability changes.
    frame.scripts.OnEvent(frame, "COMBAT_LOG_EVENT_UNFILTERED")
end
local originalAfter = C_Timer.After
C_Timer.After = function(delay, callback) queued = queued + 1; originalAfter(delay, callback) end

C_CombatLog, CombatLogGetCurrentEventInfo = nil, nil
Refresh()
Equal(frame.events.COMBAT_LOG_EVENT_UNFILTERED, nil, "missing reader does not subscribe")
Cast(spellID)
Emit("SPELL_CAST_START", spellID, 4)
Equal(School(), "unknown", "missing reader leaves school unknown")
Equal(namespace.FindRule("nameplate1"), nil, "selected unknown school fails closed")
rule.conditions.spellSchool = {}
Equal(namespace.FindRule("nameplate1"), rule, "empty Any accepts unknown school")
rule.conditions.spellSchool = "any"
Equal(namespace.FindRule("nameplate1"), rule, "scalar Any accepts unknown school")
rule.conditions.spellSchool = { fire = true }
Equal(api.RegisterSpellSchool(spellID, "fire"), true, "manual seed without API")
Equal(namespace.FindRule("nameplate1"), rule, "seeded selected school matches")
fixture.Flush()

-- Forever: no restriction query or secret-value API; legacy reader stays valid.
issecretvalue, CombatLogGetCurrentEventInfo = nil, Reader
Refresh()
Equal(frame.events.COMBAT_LOG_EVENT_UNFILTERED, true, "legacy reader subscribes")
local schools = { { 1, "physical" }, { 2, "holy" }, { 4, "fire" }, { 8, "nature" },
    { 16, "frost" }, { 32, "shadow" }, { 64, "arcane" }, { 20, "mixed" }, { 127, "mixed" } }
for _, school in ipairs(schools) do
    spellID = spellID + 1; Cast(spellID)
    Emit("SPELL_CAST_START", spellID, school[1])
    Equal(School(), school[2], "legacy school mask " .. school[1])
    fixture.Flush()
end
issecretvalue = function(value)
    return originalSecret(value) or (restrictedValue ~= nil and value == restrictedValue)
end

-- Verified renamed reader wins over legacy; errors do not retry a deprecated
-- reader as a way around restriction. Both readers are protected by pcall.
C_CombatLog = { GetCurrentEventInfo = Reader, IsCombatLogRestricted = function() return false end }
CombatLogGetCurrentEventInfo = function() error("legacy reader must not be used") end
spellID = spellID + 1; Cast(spellID)
Emit("SPELL_CAST_START", spellID, 4)
Equal(School(), "fire", "namespace reader preferred")
fixture.Flush()
local function Rejected(label, subevent, id, mask)
    local before = queued
    Emit(subevent, id, mask)
    Equal(queued, before, label .. " does not queue paint")
    Equal(School(), "unknown", label .. " leaves unknown")
    Equal(namespace.FindRule("nameplate1"), nil, label .. " selected filter fails closed")
    rule.conditions.spellSchool = {}
    Equal(namespace.FindRule("nameplate1"), rule, label .. " Any stays unrestricted")
    rule.conditions.spellSchool = { fire = true }
end
spellID = spellID + 1; Cast(spellID)
C_CombatLog.GetCurrentEventInfo = function() error("restricted getter") end
Rejected("throwing namespace reader", "SPELL_CAST_START", spellID, 4)
C_CombatLog.GetCurrentEventInfo = Reader
for _, value in ipairs({ true, fixture.secret, "false" }) do
    local before = readerCalls
    C_CombatLog.IsCombatLogRestricted = function() return value end
    Rejected("restricted/invalid query", "SPELL_CAST_START", spellID, 4)
    Equal(readerCalls, before, "restriction query rejects before reading")
end
C_CombatLog.IsCombatLogRestricted = function() error("query unavailable") end
Rejected("throwing restriction query", "SPELL_CAST_START", spellID, 4)
C_CombatLog.IsCombatLogRestricted = function() return false end
restrictedValue = false
local callsBeforeSecretQuery = readerCalls
Rejected("secret false restriction query", "SPELL_CAST_START", spellID, 4)
Equal(readerCalls, callsBeforeSecretQuery, "secret false query rejects before reading")
restrictedValue = "SPELL_CAST_START"
Rejected("secret string subevent", "SPELL_CAST_START", spellID, 4)
restrictedValue = spellID
Rejected("secret numeric ID", "SPELL_CAST_START", spellID, 4)
restrictedValue = 4
Rejected("secret numeric school", "SPELL_CAST_START", spellID, 4)
restrictedValue = nil
Rejected("wrong subevent", "SPELL_CAST_SUCCESS", spellID, 4)
Rejected("missing subevent", nil, spellID, 4)
Rejected("malformed subevent", {}, spellID, 4)
Rejected("missing ID", "SPELL_CAST_START", nil, 4)
Rejected("NaN ID", "SPELL_CAST_START", 0/0, 4)
for _, mask in ipairs({ 0, -1, 128, 132, 4.5, math.huge, "4", fixture.secret }) do
    Rejected("invalid mask", "SPELL_CAST_START", spellID, mask)
end
Rejected("NaN mask", "SPELL_CAST_START", spellID, 0/0)
Rejected("missing mask", "SPELL_CAST_START", spellID, nil)
local savedBit = bit
bit = nil
Rejected("missing bit library", "SPELL_CAST_START", spellID, 4)
bit = {}; Rejected("missing band method", "SPELL_CAST_START", spellID, 4)
bit = savedBit
C_CombatLog = nil
CombatLogGetCurrentEventInfo = function() error("legacy getter unavailable") end
Rejected("throwing legacy reader", "SPELL_CAST_START", spellID, 4)

for _, id in ipairs({ 0, -1, 1.5, math.huge, "123", fixture.secret }) do
    Equal(api.RegisterSpellSchool(id, "fire"), false, "invalid manual ID rejected")
end
Equal(api.RegisterSpellSchool(0/0, "fire"), false, "NaN manual ID rejected")
restrictedValue = "fire"
Equal(api.RegisterSpellSchool(spellID, "fire"), false, "secret manual school rejected before indexing")
restrictedValue = nil
Equal(api.RegisterSpellSchool(spellID, "unknown"), false, "unknown manual school rejected")
Equal(api.RegisterSpellSchool(spellID, "mixed"), true, "mixed manual seed accepted")
Equal(School(), "mixed", "seed works after throwing discovery API")
fixture.Flush()
CombatLogGetCurrentEventInfo = Reader
Emit("SPELL_CAST_START", spellID, fixture.secret)
Equal(School(), "mixed", "restricted payload preserves seeded metadata")
Equal(api.RegisterSpellSchool(spellID, {}), false, "malformed manual school rejected")
Cast(fixture.secret)
Equal(School(), "unknown", "secret cast ID cannot access seeded cache")
Cast(spellID)
mocks.casting = {}
Equal(namespace.FindRule("nameplate1"), nil, "school filter requires active cast")
Cast(spellID)

CombatLogGetCurrentEventInfo = Reader
rule.conditions.spellSchool = {}
Refresh()
Equal(frame.events.COMBAT_LOG_EVENT_UNFILTERED, nil, "Any unsubscribes")
rule.conditions.spellSchool = { fire = true }; rule.enabled = false
Refresh()
Equal(frame.events.COMBAT_LOG_EVENT_UNFILTERED, nil, "disabled rule does not subscribe")
rule.enabled = true; api.GetSettings().enabled = false
Refresh()
Equal(frame.events.COMBAT_LOG_EVENT_UNFILTERED, nil, "disabled feature does not subscribe")
api.GetSettings().enabled = true
local register = frame.RegisterEvent
for _, result in ipairs({ false, fixture.secret, "throw" }) do
    frame.RegisterEvent = function(_, event)
        assert(event == "COMBAT_LOG_EVENT_UNFILTERED")
        if result == "throw" then error("unsupported event") end
        return result
    end
    Refresh()
    Equal(frame.events.COMBAT_LOG_EVENT_UNFILTERED, nil, "failed/secret registration tolerated")
end
frame.RegisterEvent = register
Refresh()
Equal(frame.events.COMBAT_LOG_EVENT_UNFILTERED, true, "registration retries after unsupported event")
CombatLogGetCurrentEventInfo = nil
Refresh()
Equal(frame.events.COMBAT_LOG_EVENT_UNFILTERED, nil, "lost reader unsubscribes")
print("PASS: " .. cases .. " spell-school compatibility, restriction, seed and registration checks")
