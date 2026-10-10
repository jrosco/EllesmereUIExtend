-- A disabled/missing host must not install hooks, paint stale plates or lose rules.
SlashCmdList = {}
local frames, timers, messages, writes = {}, {}, {}, 0
local originalPrint = print
function print(message) messages[#messages + 1] = message end
function UnitFullName() return "MissingHost", "TestRealm" end
function CreateFrame()
    local frame = { events = {}, scripts = {} }
    frames[#frames + 1] = frame
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    return frame
end
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
function hooksecurefunc() error("inactive host must not install hooks") end
local plate = { unit = "nameplate1", SetScale = function() writes = writes + 1 end }
EllesmereNameplates_NS = { plates = { nameplate1 = plate } }
local private = {}
assert(loadfile("Core/Core.lua"))("EllesmereUIExtendNameplates")
assert(loadfile("Core/Sync.lua"))("EllesmereUIExtendNameplates")
assert(loadfile("Core/Options.lua"))("EllesmereUIExtendNameplates")
for _, name in ipairs({ "Helpers", "Nameplates", "Borders", "Glows", "Text", "Scaling",
    "TargetArrows", "CastStyles", "RuleIO", "Preview", "Options" }) do
    assert(loadfile("Nameplates/" .. name .. ".lua"))("EllesmereUIExtendNameplates", private)
end
local core, api = EllesmereUIExtend, EllesmereUIExtendNameplates
api.GetRules()[1].name = "Preserved missing-host rule"
local function Fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
    while #timers > 0 do
        local pending = timers; timers = {}
        for _, callback in ipairs(pending) do callback() end
    end
end
Fire("ADDON_LOADED", "EllesmereUIExtendNameplates")
Fire("PLAYER_LOGIN")
assert(#messages == 1 and messages[1]:find("Styling is inactive", 1, true), "missing-host login guidance")
assert(not core.pluginRegistered and writes == 0, "missing host cannot register UI or paint plates")
assert(api.GetRules()[1].name == "Preserved missing-host rule", "missing host preserves saved rules")
EUICoreStandaloneNameplates = { RegisterPlugin = function() error("inert host must not register") end }
__EUISTANDALONE_NAMEPLATES_INERT = true
api.Refresh(); Fire("PLAYER_ENTERING_WORLD")
assert(core.GetHost() == nil and not core.RegisterOptions() and writes == 0, "inert host fails closed")
assert(api.GetRules()[1].name == "Preserved missing-host rule", "inert host preserves saved rules")
Fire("PLAYER_LOGOUT")
assert(EllesmereUIExtendNameplatesProfiles.data.profiles.Default.nameplates.rules[1].name == "Preserved missing-host rule",
    "missing-host settings persist in the existing feature snapshot")
local snapshot = EllesmereUIExtendNameplatesProfiles
EUI_CLIENT_BLOCKED = true
EllesmereUIExtend, EllesmereUIExtendNameplates = nil, nil
assert(loadfile("Core/Core.lua"))("EllesmereUIExtendNameplates")
assert(loadfile("Core/Sync.lua"))("EllesmereUIExtendNameplates")
assert(loadfile("Core/Options.lua"))("EllesmereUIExtendNameplates")
for _, name in ipairs({ "Helpers", "Nameplates", "Borders", "Glows", "Text", "Scaling",
    "TargetArrows", "CastStyles", "RuleIO", "Preview", "Options" }) do
    assert(loadfile("Nameplates/" .. name .. ".lua"))("EllesmereUIExtendNameplates", {})
end
assert(EllesmereUIExtend == nil and EllesmereUIExtendNameplates == nil,
    "blocked client loads no runtime even with optional host dependencies")
assert(EllesmereUIExtendNameplatesProfiles == snapshot, "blocked loading leaves saved snapshots untouched")
print = originalPrint
print("PASS: missing/inert/blocked host loading, login guidance, no hooks/paint and snapshot preservation")
