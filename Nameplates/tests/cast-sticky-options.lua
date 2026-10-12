local f = assert(loadfile("Nameplates/tests/runtime.lua"))("ui-locks")
local api, rows = f.api, f.rows
local rule = api.GetRules()[1]
local function Rebuild() f.spec.modules[1].buildPage("Style", f.parent, 0) end
local function Toggle()
    local popup = assert(rows["Cast state settings"], "Cast state cog is missing")
    assert(popup.anchorTo == rows["Cast state"].button, "cog must anchor to the Cast state dropdown")
    assert(popup.captureRegion == rows["Cast state"].button:GetParent(), "cog must belong to the Cast state region")
    local toggle = assert(popup.rows[1])
    assert(toggle.type == "toggle" and toggle.label == "Keep active after cast ends")
    assert(toggle.tooltip and toggle.disabledTooltip, "popup toggle needs help and lock explanations")
    return toggle
end
rule.conditions.castState = { casting = true }
Rebuild()
assert(rows["Keep active after cast ends"] == nil, "cog-capable EUI must not duplicate the standalone toggle")
local toggle = Toggle()
assert(not toggle.disabled())
toggle.set(true); f.Flush()
assert(rule.style.persistCastColor == true)
local code = assert(api.ExportRuleSet())
rule.style.persistCastColor = false
assert(api.ImportRuleSet(code))
rule = api.GetRules()[1]
assert(rule.style.persistCastColor == true, "persistence must round-trip through sharing")
rule.style.persistCastColor = "yes"
assert(not api.ExportRuleSet(), "persistence must validate as boolean")
rule.style.persistCastColor = true
rule.conditions.castState = {}; Rebuild()
assert(Toggle().disabled())
Toggle().set(false)
assert(rule.style.persistCastColor, "prerequisite lock preserves saved value")
rule.conditions.castState = { casting = true }; Rebuild()
toggle = Toggle()
rule.enabled = false
toggle.set(false)
assert(rule.style.persistCastColor, "disabled rules lock the callback")
rule.enabled = true
api.GetSettings().enabled = false
toggle.set(false)
assert(rule.style.persistCastColor, "disabled styling locks the callback")
api.GetSettings().enabled = true
assert(api.CreateProfile("Sticky options alternate"))
toggle.set(false)
assert(rule.style.persistCastColor, "stale controls cannot mutate the old profile")
assert(not api.GetRules()[1].style.persistCastColor, "stale controls cannot mutate the new profile")
assert(api.SelectProfile("Default"))
rule = api.GetRules()[1]
local cog = EllesmereUI.BuildInlineCog
EllesmereUI.BuildInlineCog = nil
Rebuild()
local fallback = assert(rows["Keep active after cast ends"], "older EUI needs an inline fallback")
assert(fallback.get() == true, "fallback preserves the saved selection")
fallback.set(false); f.Flush()
assert(rule.style.persistCastColor == false, "fallback updates the same setting")
EllesmereUI.BuildInlineCog = cog
rows["Keep active after cast ends"] = nil
Rebuild()
assert(Toggle().get() == false and rows["Keep active after cast ends"] == nil,
    "returning to cog-capable EUI preserves values without duplicating controls")
print("PASS: Cast state persistence cog, anchors, locks, stale callbacks, sharing and older-EUI fallback")
