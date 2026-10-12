local f = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local api, addon, mocks, plate = f.api, f.namespace, f.mocks, f.plate
local guid, guidFail = "Creature-A", false
UnitGUID = function()
    if guidFail then error("restricted identity") end
    return guid
end
local function Rule(name, selection, color, persist)
    return { name = name, enabled = true, conditions = { castState = selection },
        style = { persistCastColor = persist, healthColorEnabled = true,
            healthColor = { r = color, g = 0.2, b = 0.3 }, scale = 125, opacity = 80,
            castEnabled = true, castColorEnabled = true, castGlowStyle = "pixel" } }
end
local rule = Rule("Remember", { casting = true }, 0.6, true)
local function Cast()
    mocks.casting = { "Spell", nil, nil, nil, nil, nil, nil, false }
    mocks.channel = nil
end
local function Stop() mocks.casting, mocks.channel = nil, nil end
local function Refresh() addon.RefreshAll(); f.Flush() end
local function Winner(expected)
    assert(addon.FindRule("nameplate1") == expected, "unexpected retained ordinary winner")
end
api.GetSettings().rules = { rule }
Cast()
Winner(rule) -- Diagnostics must not arm history.
Stop(); Refresh(); Winner(nil)
Cast(); Refresh(); Stop(); Refresh(); Winner(rule)
assert(plate.health.color[1] == 0.6 and plate:GetScale() == 1.25 and plate:GetAlpha() == 0.8,
    "full ordinary appearance must persist")
assert(not next(addon.FindCastColorOverrides("nameplate1")), "stopped casts must not retain palettes")

-- Non-cast conditions remain live; changing them invalidates history.
rule.conditions.reaction = { friendly = true }; Refresh(); Winner(nil)
rule.conditions.reaction = { enemy = true }; Refresh(); Winner(nil)
Cast(); Refresh(); Stop(); Refresh(); Winner(rule)
mocks.attackable = false; Refresh(); Winner(nil)
mocks.attackable = true; Refresh(); Winner(rule)

-- Live cast effects can come from a lower live rule, never the retained one.
local other = Rule("Live", { casting = true }, 0.9, false)
rule.conditions.castState = { channel = true }
mocks.channel = { "Channel", nil, nil, nil, nil, nil, false, nil, false }
Refresh(); Stop(); Refresh(); Winner(rule)
api.GetSettings().rules = { rule, other }
local castStyle, glowStyle
local originalCast, originalGlow = addon.ApplyCastStyle, addon.ApplyRuleGlows
addon.ApplyCastStyle = function(_, style) castStyle = style end
addon.ApplyRuleGlows = function(_, style) glowStyle = style end
Cast(); Refresh(); Winner(rule)
assert(castStyle == other.style and glowStyle.castEnabled == true, "cast effects follow live matching")
Stop(); Refresh()
assert(castStyle == nil and not glowStyle.castEnabled, "retained appearance must release cast effects")
addon.ApplyCastStyle, addon.ApplyRuleGlows = originalCast, originalGlow

-- Reordering and renaming keep history; disabling and appearance edits clear it.
rule.name = "Renamed"; api.GetSettings().rules = { other, rule }; Refresh(); Winner(rule)
rule.enabled = false; Refresh(); Winner(nil)
rule.enabled = true; Refresh(); Winner(nil)
rule.conditions.castState = { casting = true }
Cast(); Refresh(); Stop(); Refresh(); Winner(rule)
rule.style.opacity = 75; Refresh(); Winner(nil)

-- A channel cannot arm an empowered-only rule, nor can another rule's cast.
local empowered = Rule("Empowered", { empowered = true }, 0.4, true)
api.GetSettings().rules = { empowered }
mocks.channel = { "Channel", nil, nil, nil, nil, nil, false, nil, false }
Refresh(); Stop(); Refresh(); Winner(nil)
mocks.channel = { "Empowered", nil, nil, nil, nil, nil, false, nil, true }
Refresh(); Stop(); Refresh(); Winner(empowered)

-- Same-GUID reuse retains memory. Different or unreadable identity never does.
plate:ClearUnit(); plate.unit = "nameplate1"; Refresh(); Winner(empowered)
guid = "Creature-B"; Refresh(); Winner(nil)
guid = f.secret; Refresh(); Winner(nil)
guidFail = true; Refresh(); Winner(nil)
guidFail, guid = false, nil
Cast(); Refresh(); Stop(); Refresh(); Winner(nil)
guid = "Creature-A"; Refresh(); Winner(empowered)
api.GetSettings().enabled = false; Refresh(); Winner(nil)
api.GetSettings().enabled = true; Refresh(); Winner(nil)

-- Profile replacement/import identities cannot inherit prior rules' memory.
Cast(); api.GetSettings().rules = { rule }; Refresh(); Stop(); Refresh(); Winner(rule)
assert(api.CreateProfile("Sticky alternate")); Refresh()
assert(api.SelectProfile("Default")); Refresh(); Winner(nil)
api.GetSettings().rules = { Rule("Imported", { casting = true }, 0.6, true) }
Refresh(); Winner(nil)

-- Nonpersistent rules revert, and latest native health paint is restored.
local instant = Rule("Instant", { casting = true }, 0.7, false)
api.GetSettings().rules = { instant }
Cast(); Refresh(); Winner(instant)
plate.health:SetStatusBarColor(0.11, 0.22, 0.33, 1)
Stop(); Refresh(); Winner(nil)
assert(plate.health.color[1] == 0.11, "cast end must restore latest engine color")

-- Live and remembered paths share custom predicate results per refresh.
local calls = 0
addon.RegisterCondition("stickyProbe", function() calls = calls + 1; return true end)
rule.conditions.stickyProbe = true
api.GetSettings().rules = { rule }
Cast(); calls = 0; addon.RefreshAll()
assert(calls == 1, "arming a live match must not run a predicate twice")
Stop(); calls = 0; addon.RefreshAll()
assert(calls == 1, "retained matching must evaluate non-cast predicates once")
f.Flush()
print("PASS: rule-specific observed-cast memory, live effects, conditions, edits/profiles, diagnostics and secret-safe GUID reuse")
