-- Run from the repository root with Lua or fengari.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("ui-locks")
local api, rows, checks = f.api, f.rows, 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
UnitClass = function() return "Mage", "MAGE", 8 end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 } }
EllesmereUI:RefreshPage()
local first = api.GetRules()[1]
Check(not rows["Class-colored health bar"].get() and not rows["Class-colored player name"].get()
    and not rows["Show class emblem"].get(), "new settings remain opt-in on existing rules")
Check(rows["Class emblem size"].disabled(), "icon controls require emblem")
rows["Class-colored health bar"].set(true)
rows["Class-colored player name"].set(true)
rows["Show class emblem"].set(true)
rows["Class emblem side"].set("right")
rows["Class emblem size"].set(32)
rows["Class emblem X offset"].set(10)
rows["Class emblem Y offset"].set(-8)
f.Flush()
Check(first.style.healthClassColor and first.style.nameClassColor and first.style.classIconEnabled,
    "independent class styling saved")
Check(rows["Health-bar color"].disabled(), "custom fill picker gated by class mode without deleting color")
local preview = f.GetPreview()
Check(preview.health._bar.color[1] == 0.25 and preview.name.textColor[1] == 0.25,
    "live preview class colors use an explicit Mage sample")
Check(preview.title.text:find("Sample Mage", 1, true), "preview labels sample class explicitly")
Check(preview.classIcon:IsShown() and preview.classIcon.width == 32 and preview.classIcon.point[1] == "LEFT"
    and preview.classIcon.point[4] == 16 and preview.classIcon.point[5] == -8, "live icon side size offsets")
rows["Show class emblem"].set(false)
Check(not f.GetPreview().classIcon:IsShown() and first.style.classIconSize == 32, "disable preserves saved icon appearance")
rows["Show class emblem"].set(true)
local code = assert(api.ExportRuleSet())
Check(api.ImportRuleSet(code), "class appearance export/import roundtrip")
EllesmereUI:RefreshPage()
first = api.GetRules()[1]
Check(first.style.healthClassColor and first.style.nameClassColor and first.style.classIconSize == 32
    and first.style.classIconY == -8, "sharing retains all class fields")
local oldSize, oldName = rows["Class emblem size"].set, rows["Class-colored player name"].set
rows["Rule enabled"].set(false)
oldSize(40); oldName(false)
Check(first.style.classIconSize == 32 and first.style.nameClassColor, "disabled rule rejects stale class callbacks")
rows["Rule enabled"].set(true)
local oldIcon = rows["Show class emblem"].set
rows["Enable Nameplate styling"].set(false); oldIcon(false)
Check(first.style.classIconEnabled, "global lock rejects stale icon callback")
rows["Enable Nameplate styling"].set(true)
local oldCount = #api.GetRules()
rows["Add PvP preset"].click()
local preset = api.GetRules()[1]
Check(#api.GetRules() == oldCount + 1 and api.GetRules()[2] == first, "preset inserted only by explicit action; existing rules retained")
Check(preset.name == "PvP Players" and preset.conditions.unitType.player and preset.conditions.reaction.enemy
    and next(preset.conditions.target) == nil and next(preset.conditions.instanceType) == nil,
    "preset matches enemy players independent of target and includes open-world PvP")
Check(preset.style.healthClassColor and preset.style.nameClassColor and preset.style.classIconEnabled
    and preset.style.classIconSide == "left" and preset.style.borderSize == 0, "PvP preset defaults")
oldSize(50); oldName(false); oldIcon(false)
Check(first.style.classIconSize == 32 and preset.style.nameClassColor and preset.style.classIconEnabled,
    "old rule controls cannot mutate newly selected rule")
local staleName = rows["Class-colored player name"].set
local stalePreset = rows["Add PvP preset"].click
local current = api.GetSettings()
EllesmereUIExtend.CreateProfile("Class other profile")
staleName(false)
stalePreset()
Check(current.rules[1].style.nameClassColor and api.GetSettings() ~= current, "profile switch rejects stale callbacks")
Check(#current.rules == oldCount + 1 and #api.GetRules() == 4, "stale preset cannot add to another profile")
EllesmereUI:RefreshPage()
rows["Show class emblem"].set(true)
local savedIcon = rows["Show class emblem"].set
CLASS_ICON_TCOORDS = nil
savedIcon(false)
Check(api.GetRules()[1].style.classIconEnabled, "missing artwork gates stale toggle without deleting setting")
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 } }
UnitClass = nil
Check(rows["Class-colored player name"].disabled() and rows["Show class emblem"].disabled(), "missing APIs gate class controls")
UnitClass = function() return "Mage", "MAGE", 8 end
local rule = api.GetRules()[1]
for key, bad in pairs({ healthClassColor = "true", nameClassColor = 1, classIconEnabled = "yes",
    classIconSide = "top", classIconSize = 65, classIconX = -201, classIconY = 201 }) do
    local old = rule.style[key]; rule.style[key] = bad
    local result, reason = api.ExportRuleSet()
    Check(not result and reason:find(key, 1, true), "invalid class field rejected: " .. key)
    rule.style[key] = old
end
local serializer = EllesmereUI._Serializer
code = assert(api.ExportRuleSet())
local payload = serializer.Deserialize(code:sub(18))
payload.rules[1].style.classIconSide = "top"
local before = api.GetRules()
Check(not api.ImportRuleSet("!EUI_NPEX_RULES2!" .. serializer.Serialize(payload)) and api.GetRules() == before,
    "malformed imported class style rejected atomically")
local presetClick = rows["Add PvP preset"].click
rows["Enable Nameplate styling"].set(false); presetClick()
Check(api.GetRules() == before and #before == 4, "master lock rejects stale preset callback")
rows["Enable Nameplate styling"].set(true)
local settings, saved = api.GetSettings(), api.GetRules()
settings.rules = {}
for index = 1, api.MaxRules do settings.rules[index] = f.namespace.CopyTable(rule) end
EllesmereUI:RefreshPage()
rows["Add PvP preset"].click()
Check(#settings.rules == api.MaxRules and rows["Add PvP preset"].disabled(), "preset respects rule limit")
settings.rules = saved
print("PASS: " .. checks .. " class editor, optional PvP preset, preview, sharing, capability gates and stale callbacks")
