-- Run from the repository root with Lua or fengari.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local api, addon = f.api, f.namespace

for _, state in ipairs({ "casting", "channel", "empowered", "unknown" }) do
    assert(addon.IsActiveCastState(state), state .. " is an active cast")
end
assert(not addon.IsActiveCastState("none"), "idle is not an active cast")
assert(not addon.IsActiveCastState(nil), "missing cast state fails closed")
assert(not addon.IsActiveCastState(false), "boolean cast state fails closed")
assert(not addon.IsActiveCastState(1), "numeric cast state fails closed")
assert(not addon.IsActiveCastState(f.secret), "secret cast state fails closed")
local originalSecret = issecretvalue
issecretvalue = nil
assert(addon.IsActiveCastState("casting") and not addon.IsActiveCastState("none"), "Forever without secret API")
issecretvalue = originalSecret

local function SetCast(state)
    f.mocks.casting, f.mocks.channel = nil, nil
    if state == "casting" then
        f.mocks.casting = { "Spell", nil, nil, nil, nil, nil, nil, false }
    elseif state ~= "none" then
        f.mocks.channel = { "Channel", nil, nil, nil, nil, nil, false, nil,
            state == "empowered" }
        if state == "unknown" then f.mocks.channel[9] = f.secret end
    end
end

local rule = { name = "Eligibility", enabled = true, conditions = {}, style = {} }
api.GetSettings().rules = { rule }
local targets = {
    { label = "Targeting Me", selection = { me = true }, mode = "me" },
    { label = "Not Targeting Me", selection = { notMe = true }, mode = "notMe" },
    { label = "Both", selection = { me = true, notMe = true } },
    { label = "Neither", selection = {} },
    { label = "Missing" },
}
local casts = {
    { label = "Any" },
    { label = "Empty Any", selection = {} },
    { label = "None", selection = { none = true }, states = { none = true } },
    { label = "Casting", selection = { casting = true }, active = true },
    { label = "Channel", selection = { channel = true }, states = { channel = true } },
    { label = "Empowered", selection = { empowered = true }, states = { empowered = true } },
    { label = "Interruptible", selection = { interruptible = true }, active = true },
    { label = "Interrupt on CD", selection = { interruptOnCD = true }, active = true },
    { label = "Uninterruptible", selection = { uninterruptible = true }, active = true },
    { label = "None or Channel", selection = { none = true, channel = true }, states = { none = true, channel = true } },
}

-- Exercise the actual matcher rather than reimplementing its cast checklist.
-- State flags imply broad active-cast eligibility, not readable interrupt state.
for _, style in ipairs({ "eui", "blizzard" }) do
    EllesmereNameplates_NS.NP_Style = function() return style end
    for _, target in ipairs(targets) do
        rule.conditions.castTarget = target.selection
        for _, cast in ipairs(casts) do
            rule.conditions.castState = cast.selection
            for _, state in ipairs({ "none", "casting", "channel", "empowered", "unknown" }) do
                SetCast(state)
                local ordinary, _, traits, candidates = addon.FindRule("nameplate1")
                assert(traits.castState == state, "fixture must produce " .. state)
                local eligible = cast.states == nil or cast.states[state] == true
                if cast.active then eligible = state ~= "none" end
                if target.mode then eligible = eligible and state ~= "none" end
                local context = style .. ": " .. target.label .. " / " .. cast.label .. " / " .. state
                assert((ordinary == rule) == (eligible and target.mode == nil), context .. " ordinary")
                assert((candidates.me.rule == rule) == (eligible and target.mode ~= "notMe"), context .. " me")
                assert((candidates.notMe.rule == rule) == (eligible and target.mode ~= "me"), context .. " notMe")
            end
        end
    end
end

print("PASS: cast-target eligibility (single choices require active casts; both/neither preserve explicit cast filters)")
