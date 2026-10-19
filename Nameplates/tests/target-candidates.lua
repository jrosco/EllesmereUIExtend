-- Candidate contract and palette-only glow ownership; run from repository root.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local api, addon, plate = f.api, f.namespace, f.plate
f.mocks.casting = { "Spell", nil, nil, nil, nil, nil, nil, false }
PlayerIsSpellTarget = function() return true end
local calls = {}
api.RegisterCondition("candidateProbe", function(_, _, _, rule)
    calls[rule] = (calls[rule] or 0) + 1
    return true
end)
local ordinary = { enabled = true, conditions = { candidateProbe = true }, style = { scale = 120 } }
local targeted = { enabled = true, conditions = { candidateProbe = true, castTarget = { me = true } },
    style = { castEnabled = true, castColorEnabled = true, castColor = { r = 0.9, g = 0.2, b = 0.3 } } }
api.GetSettings().rules = { ordinary, targeted }
local winner, index, traits, candidates = addon.FindRule(plate.unit)
assert(winner == ordinary and index == 1 and traits.castState == "casting", "first three selector results unchanged")
for _, key in ipairs({ "fallback", "me", "notMe" }) do
    local candidate = candidates[key]
    assert(candidate.rule == ordinary and candidate.index == 1, "ordinary priority in " .. key)
    assert(next(candidate.castColors) == nil, "direct selector does not build palettes")
end
assert(candidates.fallback.style == ordinary.style, "fallback retains ordinary style")
assert(candidates.me.style.scale == nil, "conditional style excludes ordinary-only appearance")
assert(calls[ordinary] == 1 and calls[targeted] == nil, "direct selector remains lazy")
calls = {}
local captured
local painter = addon.ApplyCastStyle
addon.ApplyCastStyle = function(p, style, conditions, colors, context)
    if p == plate then captured = context end
    return painter(p, style, conditions, colors, context)
end
addon.RefreshAll(); f.Flush()
assert(captured and captured.glowChanged == false, "palette-only context preserves ordinary glow ownership")
local palette = captured.candidates.me.castColors
assert(palette.interruptible.rule == targeted and palette.interruptible.index == 2, "lower conditional palette priority")
assert(palette.interruptible == palette.interruptOnCD and palette.interruptible == palette.uninterruptible,
    "all-state palette preserves shared entry identity")
assert(next(captured.candidates.fallback.castColors) == nil and next(captured.candidates.notMe.castColors) == nil,
    "other branches retain empty palettes")
assert(calls[ordinary] == 1 and calls[targeted] == 1, "all branches share one refresh snapshot")
api.GetSettings().rules = { targeted }
winner, index, traits, candidates = addon.FindRule(plate.unit)
assert(winner == nil and index == nil and candidates.fallback.rule == nil and candidates.fallback.style == nil,
    "missing fallback retains explicit empty candidate")
assert(candidates.me.rule == targeted and candidates.me.index == 1 and next(candidates.notMe.castColors) == nil,
    "single-choice rule retains branch index and empty opposite candidate")
assert(addon.FindTargetedCastColorOverrides == nil, "unused targeted selector export removed")
print("PASS: unified target candidates, selector contract, lazy predicates, shared palettes and glow ownership")
