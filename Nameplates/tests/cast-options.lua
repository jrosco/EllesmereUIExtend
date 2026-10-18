local f = assert(loadfile("Nameplates/tests/runtime.lua"))("ui-locks")
local api, rows = f.api, f.rows
EllesmereUI.Glows = assert(loadfile("Nameplates/tests/glow-mocks.lua"))()
PlayerIsSpellTarget = function() return f.secret end
local rule = api.GetRules()[1]
rule.conditions.castState = { casting = true }
rule.style.castEnabled, rule.style.castGlowStyle = true, 1
local function Rebuild() f.spec.modules[1].buildPage("Style", f.parent, 0) end
Rebuild()
local target = assert(rows["Cast target"])
assert(target.emptyLabel == "Any cast target" and #target.items == 2 and target.items[1].key == "me"
    and target.items[2].key == "notMe")
target.set("me", true); f.Flush()
assert(rule.conditions.castTarget.me)
assert(target.items[1].tooltip:find("Untargeted AoE", 1, true))
for _, label in ipairs({ "Nameplate size (%)", "Opacity (%)", "Health-bar texture", "Cast-bar texture",
    "Override text", "Target-arrow style" }) do
    assert(rows[label].disabled(), label .. " must be gated on targeted rules")
end
local size = rule.style.scale
rows["Nameplate size (%)"].set(180)
assert(rule.style.scale == size, "locked appearance must preserve saved values")
assert(not rows["Health-bar color"].disabled() and not rows["Cast glow color"].disabled())
rows["Cast target"].set("notMe", true); f.Flush()
assert(rule.conditions.castTarget.me and rule.conditions.castTarget.notMe and not rows["Nameplate size (%)"].disabled(),
    "both choices unlock ordinary controls")
rows["Cast target"].set("me", false); f.Flush()
assert(rows["Nameplate size (%)"].disabled(), "Not Targeting Me alone gates unsupported controls")
rows["Cast target"].set("me", true); f.Flush()
rows["Cast target"].set("notMe", false); f.Flush()
for _, row in ipairs(rows["Cast glow settings"].rows) do
    assert(row.label ~= "Only glow when targeting me", "targeting must no longer live in glow cog")
end
local preview = f.GetPreview()
local previousScale = preview.health._appearance:GetScale()
rule.style.scale, rule.style.opacity = 180, 20
Rebuild()
assert(f.GetPreview().health._appearance:GetScale() == previousScale, "unsupported saved scaling must not appear in targeted preview")
local code = assert(api.ExportRuleSet())
assert(api.ImportRuleSet(code))
rule = api.GetRules()[1]
assert(rule.conditions.castTarget.me, "target condition must round-trip through sharing")
Rebuild(); target = rows["Cast target"]
PlayerIsSpellTarget = nil
assert(target.items[1].lockedFn())
target.set("me", false)
assert(rule.conditions.castTarget.me, "unsupported clients preserve selections")
PlayerIsSpellTarget = function() return true end
rule.enabled = false; target.set("me", false); assert(rule.conditions.castTarget.me)
rule.enabled = true
assert(api.CreateProfile("Targeted rule alternate"))
target.set("me", false)
assert(rule.conditions.castTarget.me and not api.GetRules()[1].conditions.castTarget.me,
    "stale dropdown cannot edit either profile")
assert(api.SelectProfile("Default"))
rule = api.GetRules()[1]
EllesmereUI.BuildInlineCog = nil; Rebuild()
rows["Cast target"].set("me", false); f.Flush()
assert(not rule.conditions.castTarget.me and not rows["Nameplate size (%)"].disabled(), "Any unlocks ordinary appearance on older EUI too")
print("PASS: rule-based cast targeting, supported controls, live-only persistence, preview, sharing, API gates and stale locks")
