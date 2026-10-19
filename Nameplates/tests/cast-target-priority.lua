-- Run from the repository root with Lua or fengari.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local api, addon, plate = f.api, f.namespace, f.plate
local value, secretTruth, unavailable, reads = true, true, false, 0
local function ReadTarget(unit)
    assert(unit == plate.unit)
    reads = reads + 1
    if unavailable then error("restricted target getter") end
    return value
end
PlayerIsSpellTarget = ReadTarget
UnitIsSpellTarget = nil

local originalSecret = issecretvalue
issecretvalue = function(v)
    return originalSecret(v) or (type(v) == "table" and v.opaque == true)
end
local function NativeValue(v)
    if type(v) == "table" and v.opaque then return v.value end
    return v
end
C_CurveUtil = { EvaluateColorValueFromBoolean = function(flag, yes, no)
    -- Only this simulated native boundary may inspect the secret sentinel.
    local truth = flag
    if flag == f.secret then truth = secretTruth end
    local selected
    if truth then selected = yes else selected = no end
    if flag == f.secret or issecretvalue(selected) then
        return { opaque = true, value = NativeValue(selected) }
    end
    return selected
end }

local function Style(red)
    return { healthColorEnabled = true, healthColor = { r = red, g = 0.2, b = 0.3 },
        castEnabled = true, castColorEnabled = true,
        castColor = { r = red, g = 0.4, b = 0.5 } }
end
local ordinary = { enabled = true, conditions = {}, style = Style(0.1) }
ordinary.style.castColorEnabled = false
local targeted = { enabled = true, conditions = { castTarget = { me = true } }, style = Style(0.9) }
local notTargeted = { enabled = true, conditions = { castTarget = { notMe = true } }, style = Style(0.7) }
api.GetSettings().rules = { ordinary, targeted, notTargeted }
f.mocks.casting = { "Spell", nil, nil, nil, nil, nil, nil, false }
local nativeCastRed = NativeValue(plate.cast:GetStatusBarTexture().vertexColor[1])
local function CheckColors(castRed)
    for index, expected in ipairs({ 0.1, 0.2, 0.3, 1 }) do
        assert(math.abs(NativeValue(plate.health.color[index]) - expected) < 0.00001,
            "target polling must preserve the higher unrestricted health color")
    end
    assert(math.abs(NativeValue(plate.cast:GetStatusBarTexture().vertexColor[1]) - castRed) < 0.00001,
        "lower targeting cast palettes must remain live independently of health priority")
end
local function Tick(castRed, expectRead)
    local previousReads = reads
    for _, frame in ipairs(f.frames) do
        if frame:IsShown() and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.11) end
    end
    if expectRead then assert(reads > previousReads, "palette-only context must actually poll targeting") end
    CheckColors(castRed)
end

addon.RefreshAll(); f.Flush()
local me, fallback, notMe = addon.GetCastTargetRuleCandidates(plate)
assert(me == ordinary and fallback == ordinary and notMe == ordinary,
    "a cast-palette-only context must retain the unrestricted health winner in both branches")
CheckColors(0.9)
value = false; Tick(0.7, true)
value = true; Tick(0.9, true)
value = f.secret; secretTruth = false; Tick(0.7, true)
secretTruth = true; Tick(0.9, true)
unavailable = true; Tick(nativeCastRed, true)
unavailable = false; value = false; Tick(0.7, true)
PlayerIsSpellTarget = nil; Tick(nativeCastRed)
PlayerIsSpellTarget = ReadTarget; value = true; Tick(0.9, true)
C_CurveUtil = nil
value = false; Tick(0.7, true)
value = f.secret; Tick(nativeCastRed, true)

print("PASS: unrestricted health priority survives live targeting cast palettes, secret targets and unavailable-target fallbacks")
