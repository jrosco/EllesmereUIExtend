-- Focused gate ownership/lifecycle checks; run from the repository root.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local addon, plate = f.namespace, f.plate
local G = assert(loadfile("Nameplates/tests/glow-mocks.lua"))()
EllesmereUI.Glows = G
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local style = { healthEnabled = true, healthGlowStyle = 1, castEnabled = true, castGlowStyle = 1 }
local context = { glowChanged = true, available = true, flag = true,
    candidates = { me = { style = style }, notMe = { style = style }, fallback = { style = style } } }
local setAlpha = addon.SetTargetAlpha
addon.SetTargetAlpha = function(frame, value, expected)
    local written = setAlpha(frame, value, expected)
    return written, frame:GetParent() == plate.cast and "cast gate" or "health gate"
end
plate._importantCastOverlay = CreateFrame("Frame", nil, plate.cast)
plate._importantCastOverlay:SetAlpha(0.35)
local function Apply() addon.ApplyRuleGlows(plate, style, context) end
Apply()
local health, cast = addon.GetRuleGlowFrames(plate)
local yesHealth, yesCast = addon.GetConditionalRuleGlowFrames(plate)
local healthGate, castGate = health:GetParent(), cast:GetParent()
local yesHealthGate, yesCastGate = yesHealth:GetParent(), yesCast:GetParent()
Check(addon.GetRuleCastGlowGate(plate) == yesCastGate, "cast accessor returns the target-side frame, not gate metadata")
Check(healthGate ~= castGate and yesHealthGate ~= yesCastGate and castGate ~= yesCastGate,
    "each prefix and inverse state owns an independent gate")
Check(castGate:GetAlpha() == 0 and yesCastGate:GetAlpha() == 1, "zero alpha is successful inverse gating")
Check(cast._mockGlowActive and yesCast._mockGlowActive, "transparent alternative keeps its animation running")
Check(addon.GetTargetedCastGlowStatus(plate) == "cast gate; renderer=bar", "cast diagnostics use the cast result")
local starts = G.starts
context.flag = false; Apply()
Check(castGate:GetAlpha() == 1 and yesCastGate:GetAlpha() == 0, "inverse gates switch live")
Check(G.starts == starts, "target changes reuse running animations")
Check(health:GetParent() == healthGate and yesCast:GetParent() == yesCastGate, "target refresh reuses gates")

style.castEnabled = false; Apply()
Check(addon.GetTargetedCastGlowStatus(plate) == "glow stopped; cast bar hidden or no glow style",
    "health-only updates cannot leak health or stale cast diagnostics")
style.castEnabled = true; Apply()
Check(plate._importantCastOverlay:GetAlpha() == 0.35, "conditional gates preserve native important cast glow")

addon.ApplyRuleGlows(plate, style)
Check(health:GetParent() == plate.health and cast:GetParent() == plate.cast, "ordinary hosts return to their bars")
Check(healthGate:GetAlpha() == 0 and castGate:GetAlpha() == 0, "detached gates become transparent")
Check(not yesHealth._mockGlowActive and not yesCast._mockGlowActive, "removing context stops targeted alternatives")
Check(addon.GetRuleCastGlowGate(plate) == yesCastGate, "cast gate accessor retains its cached frame")
Apply()
Check(health:GetParent() == healthGate and cast:GetParent() == castGate
    and yesHealth:GetParent() == yesHealthGate and yesCast:GetParent() == yesCastGate,
    "re-enabling context reparents hosts to their original gates")

context.flag = f.secret; Apply()
Check(cast._mockGlowSpec.kind == "engine" and yesCast._mockGlowSpec.kind == "engine", "secret Pixel uses native engine")
context.flag = true; Apply()
Check(cast._mockGlowSpec.kind == "bar" and yesCast._mockGlowSpec.kind == "bar", "readable refresh cannot inherit cached secret metadata")
addon.SetTargetAlpha = setAlpha
print("PASS: " .. checks .. " per-prefix glow gates, cast diagnostics, inverse zero-alpha success and gate reuse")
