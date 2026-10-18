local f = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local api, addon, plate = f.api, f.namespace, f.plate
EllesmereUI.Glows = assert(loadfile("Nameplates/tests/glow-mocks.lua"))()
local value, fail, secretTruth = true, false, true
PlayerIsSpellTarget = function(unit)
    assert(unit == plate.unit)
    if fail then error("restricted getter") end
    return value
end
local originalSecret = issecretvalue
issecretvalue = function(v) return originalSecret(v) or (type(v) == "table" and v.opaque == true) end
local function NativeValue(v) if type(v) == "table" and v.opaque then return v.value end; return v end
C_CurveUtil = { EvaluateColorValueFromBoolean = function(flag, yes, no)
    -- Simulate the native boundary, not legal addon inspection of secret values.
    local truth = flag
    if flag == f.secret then truth = secretTruth end
    local selected
    if truth then selected = yes else selected = no end
    if flag == f.secret or issecretvalue(selected) then return { opaque = true, value = NativeValue(selected) } end
    return selected
end }
f.mocks.casting = { "Spell", nil, nil, nil, nil, nil, nil, false }
local function Style(color)
    return { healthColorEnabled = true, healthColor = { r = color, g = 0.2, b = 0.3 },
        healthGlowStyle = 1, castEnabled = true, castColorEnabled = true,
        castColor = { r = color, g = 0.3, b = 0.4 }, castGlowStyle = 1 }
end
local targeted = { name = "Targeted", enabled = true, conditions = { castState = { casting = true }, castTarget = { me = true } }, style = Style(0.9) }
local fallback = { name = "Any", enabled = true, conditions = {}, style = Style(0.1) }
fallback.style.scale, fallback.style.opacity = 110, 75
targeted.style.scale, targeted.style.opacity = 180, 20
api.GetSettings().rules = { targeted, fallback }
local function Refresh() addon.RefreshAll(); f.Flush() end
local function Colors(expected)
    assert(math.abs(NativeValue(plate.health.color[1]) - expected) < 0.00001, "conditional health color")
    assert(math.abs(NativeValue(plate.cast:GetStatusBarTexture().vertexColor[1]) - expected) < 0.00001, "conditional cast color")
end
plate._importantCastOverlay = CreateFrame("Frame", nil, plate.cast)
plate._importantCastOverlay:SetAlpha(0.35)
Refresh(); Colors(0.9)
EllesmereNameplates_NS.ApplyCastBarTexture(plate)
Colors(0.9) -- Native texture refresh must retain the conditional palette.
assert(plate:GetScale() == 1.1 and plate:GetAlpha() == 0.75, "unsupported appearance stays with Any rule")
local th, tc = addon.GetConditionalRuleGlowFrames(plate)
local fh, fc = addon.GetRuleGlowFrames(plate)
assert(th and tc and fh and fc, "both health/cast glow alternatives must exist")
assert(NativeValue(th:GetParent():GetAlpha()) == 1 and NativeValue(fh:GetParent():GetAlpha()) == 0)
assert(plate._importantCastOverlay:GetAlpha() == 0.35, "conditional effects preserve native Important Cast")
value = false; Refresh(); Colors(0.1)
EllesmereNameplates_NS.ApplyCastBarTexture(plate)
Colors(0.1)
assert(NativeValue(tc:GetParent():GetAlpha()) == 0 and NativeValue(fc:GetParent():GetAlpha()) == 1)
UnitDetailedThreatSituation = function() return true end
targeted.conditions.threat = { me = true }
Refresh(); Colors(0.1) -- Untargeted AoE does not qualify merely because we hold aggro.
targeted.conditions.threat = nil
value = f.secret; secretTruth = true; Refresh(); Colors(0.9)
assert(th._mockGlowSpec.kind == "engine" and tc._mockGlowSpec.kind == "engine", "secret gates require native animation")
secretTruth = false
for _, frame in ipairs(f.frames) do if frame:IsShown() and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.11) end end
Colors(0.1)
assert(NativeValue(th:GetParent():GetAlpha()) == 0 and NativeValue(fh:GetParent():GetAlpha()) == 1, "live target changes update both alternatives")
EllesmereUI.IS_FOREVER = true; secretTruth = true; Refresh(); Colors(0.9)
api.GetSettings().rules = { fallback, targeted }; Refresh(); Colors(0.1)
assert(not th._mockGlowActive and not tc._mockGlowActive, "higher Any rule preempts targeted ordinary appearance")
api.GetSettings().rules = { targeted, fallback }; fail = true; Refresh(); Colors(0.1)
fail = false; PlayerIsSpellTarget = nil; Refresh(); Colors(0.1)
UnitIsSpellTarget = function(unit, target) assert(unit == plate.unit and target == "player"); return true end
Refresh(); Colors(0.9)
value = true; PlayerIsSpellTarget = function() return value end
targeted.conditions.reaction = { friendly = true }; Refresh(); Colors(0.1)
targeted.conditions.reaction = nil
Refresh(); Colors(0.9)
plate._interrupted = true
plate.cast:GetStatusBarTexture():SetVertexColor(0.55, 0.6, 0.7, 1)
assert(plate.cast:GetStatusBarTexture().vertexColor[1] == 0.55, "native interrupted flash wins")
plate._interrupted = nil
f.mocks.casting = nil; Refresh(); Colors(0.1)
assert(not tc._mockGlowActive, "cast end cannot retain targeted appearance or glows")
f.mocks.casting = { "Spell", nil, nil, nil, nil, nil, nil, false }
Refresh(); Colors(0.9)
plate:ClearUnit(); assert(not tc._mockGlowActive and not th._mockGlowActive)
plate.unit = "nameplate2"; value = false; Refresh(); Colors(0.1)
api.GetSettings().rules = { targeted }
value = true; Refresh(); Colors(0.9)
assert(plate:GetScale() == 1 and plate:GetAlpha() == 1, "without an Any rule, unsupported appearance remains EUI-owned")
plate.health:SetStatusBarColor(0.42, 0.5, 0.6, 1)
f.Flush()
value = false; Refresh()
assert(math.abs(NativeValue(plate.health.color[1]) - 0.42) < 0.00001, "unmatched targeting restores latest native health color")
assert(math.abs(NativeValue(plate.cast:GetStatusBarTexture().vertexColor[1]) - 0.55) < 0.00001,
    "unmatched targeting restores latest native cast paint")
targeted.enabled = false; Refresh()
assert(not tc._mockGlowActive and not th._mockGlowActive, "disabled targeted rule releases both categories")
targeted.enabled = true; value = true; Refresh(); Colors(0.9)
local curve = C_CurveUtil
C_CurveUtil = nil
Refresh(); Colors(0.9)
value = false; Refresh()
assert(math.abs(plate.health.color[1] - 0.42) < 0.00001, "readable targeting fallback restores native color without curves")
value = f.secret; Refresh()
assert(math.abs(plate.health.color[1] - 0.42) < 0.00001, "missing secret color selector fails closed")
C_CurveUtil = curve; value = true; Refresh(); Colors(0.9)
local function Tick()
    for _, frame in ipairs(f.frames) do
        if frame:IsShown() and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.11) end
    end
end
local paint, handler = plate.health.SetStatusBarColor, geterrorhandler
local errors, rejected = 0, 0
geterrorhandler = function() return function() errors = errors + 1 end end
plate.health.SetStatusBarColor = function(self, r, g, b, a)
    if NativeValue(r) == 0.9 then rejected = rejected + 1; error("restricted health setter") end
    return paint(self, r, g, b, a)
end
Tick()
assert(errors == 1 and rejected == 1, "poll failure must be reported once")
assert(not addon.GetCastTargetRuleCandidates(plate) and not tc._mockGlowActive and not th._mockGlowActive,
    "failed context must release its conditional glows and polling")
assert(math.abs(NativeValue(plate.health.color[1]) - 0.42) < 0.00001, "poll failure restores native health fallback")
Tick(); assert(errors == 1 and rejected == 1, "failed renderer must not retry every tick")
plate.health.SetStatusBarColor, geterrorhandler = paint, handler
plate.health:SetStatusBarColor(0.44, 0.5, 0.6, 1)
f.Flush(); Colors(0.9)
value = false; Tick()
assert(math.abs(NativeValue(plate.health.color[1]) - 0.44) < 0.00001,
    "failure must release write guard and preserve later engine paints")
value = true; Refresh(); Colors(0.9)
local notMe = { name = "Not me", enabled = true, conditions = { castTarget = { notMe = true } }, style = Style(0.7) }
PlayerIsSpellTarget = function() if fail then error("unavailable") end; return value end
api.GetSettings().rules = { targeted, notMe, fallback }
value = false; Refresh(); Colors(0.7)
value = true; Refresh(); Colors(0.9)
value = f.secret; secretTruth = false; Refresh(); Colors(0.7)
secretTruth = true; Tick(); Colors(0.9)
fail = true; Tick(); Colors(0.1)
local nh, nc = addon.GetRuleGlowFrames(plate)
assert(NativeValue(nh:GetParent():GetAlpha()) == 1 and not tc._mockGlowActive,
    "unavailable target uses the ordinary glow, never a single-choice rule")
fail = false; secretTruth = false; Tick(); Colors(0.7)
C_CurveUtil = nil; Refresh(); Colors(0.1)
C_CurveUtil = curve
f.mocks.casting = nil; value = false; Refresh(); Colors(0.1)
notMe.conditions.castTarget.me = true
notMe.style.scale = 130
Refresh(); Colors(0.7)
assert(plate:GetScale() == 1.3, "both selections remove targeting restriction even outside casts")
notMe.conditions.castTarget = {}; Refresh(); Colors(0.7)
notMe.conditions.castTarget = { notMe = true }; Refresh(); Colors(0.1)
f.mocks.casting = { "Spell", nil, nil, nil, nil, nil, nil, false }
api.GetSettings().rules = { notMe }
value = false; Refresh(); Colors(0.7)
fail = true; Tick()
assert(not nh._mockGlowActive and not nc._mockGlowActive, "missing target data with no ordinary rule stops fallback-side glows")
fail = false
-- Secret target alpha alone must not replace Shine with Pixel. Both rule
-- alternatives use independent alpha parents; renderer writes stay on children.
targeted.style.healthGlowStyle, targeted.style.castGlowStyle = 3, 3
notMe.style.healthGlowStyle, notMe.style.castGlowStyle = 3, 3
targeted.style.castGlowShineSize, notMe.style.castGlowShineSize = 150, 50
api.GetSettings().rules = { targeted, notMe, fallback }
value = f.secret; secretTruth = true; Refresh()
th, tc = addon.GetConditionalRuleGlowFrames(plate)
nh, nc = addon.GetRuleGlowFrames(plate)
assert(tc._mockGlowSpec.style == 3 and nc._mockGlowSpec.style == 3
    and th._mockGlowSpec.style == 3 and nh._mockGlowSpec.style == 3, "both secret-target alternatives retain Shine")
assert(tc._mockGlowSpec.scale == 1.5 and nc._mockGlowSpec.scale == 0.5, "Shine sizing remains rule-specific")
assert(NativeValue(tc:GetParent():GetAlpha()) == 1 and NativeValue(nc:GetParent():GetAlpha()) == 0)
local starts = EllesmereUI.Glows.starts
secretTruth = false
for _, frame in ipairs(f.frames) do if frame:IsShown() and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.11) end end
assert(NativeValue(tc:GetParent():GetAlpha()) == 0 and NativeValue(nc:GetParent():GetAlpha()) == 1,
    "Shine target gates update without inspecting the flag")
assert(EllesmereUI.Glows.starts == starts, "target changes must not restart Shine animations")
local visible = tc.IsVisible
tc.IsVisible = function() return f.secret end
Refresh()
assert(tc._mockGlowSpec.style == 1 and tc._mockGlowSpec.kind == "engine", "restricted visibility retains native Pixel fallback")
tc.IsVisible = function() error("forbidden visibility") end
Refresh()
assert(tc._mockGlowSpec.style == 1 and tc._mockGlowSpec.kind == "engine", "throwing visibility also fails over safely")
tc.IsVisible = visible; Refresh()
assert(tc._mockGlowSpec.style == 3 and targeted.style.castGlowStyle == 3, "readable visibility restores saved Shine")
assert(plate._importantCastOverlay:GetAlpha() == 0.35, "conditional Shine preserves native Important Cast")
api.GetSettings().enabled = false; Refresh()
assert(not tc._mockGlowActive and not fc._mockGlowActive)
assert(plate._importantCastOverlay:GetAlpha() == 0.35)
print("PASS: rule-priority health/cast colors and glows, native secrets, live targeting, AoE/threat distinction, fallbacks and lifecycle")
