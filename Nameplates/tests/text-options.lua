-- Run from the repository root with Lua or fengari.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("ui-locks")
local api, rows, checks = f.api, f.rows, 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Popup(slot, label)
    for _, row in ipairs(rows[slot .. " settings"].rows) do if row.label == label then return row end end
    error("Missing popup control: " .. slot .. "/" .. label)
end
local function Add(key)
    rows["+ Add Text Slot add menu"].setValue(key)
    f.Flush()
end
Check(not rows["Override text"].get() and rows["Top text"].disabled(), "text overrides off by default")
Check(rows["+ Add Text Slot"].disabled(), "add locked with text master off")
rows["Override text"].set(true); f.Flush()
local rule = api.GetRules()[1]
Check(not rows["Top text"].disabled(), "text master unlocks inherited slots")
Check(rows["Top text"].values.eui and rows["Top text"].values.none == "Remove", "native and Remove choices")
Check(not rows["Left text"], "unused slots omitted")
Check(not rows["Override Name color"], "separate color rows removed")
Check(Popup("Top text", "Content").get() == "eui", "content available inside popup too")
Check(Popup("Top text", "Size").disabled() and Popup("Top text", "X Offset").disabled(), "layout overrides opt in independently")
Popup("Top text", "Override size").set(true)
Popup("Top text", "Size").set(18)
Popup("Top text", "Override offsets").set(true)
Popup("Top text", "X Offset").set(15)
Popup("Top text", "Y Offset").set(9)
Check(rule.style.textSlotLayout.textSlotTop.size == 18 and rule.style.textSlotLayout.textSlotTop.x == 15, "popup saves selected layout")
local menu = rows["+ Add Text Slot add menu"]
Check(menu.itemDisabled("textSlotTop") and not menu.itemDisabled("textSlotLeft"), "add menu only allows free slots")
local inherited = rule.style.textSlots
menu.setValue("textSlotTop")
Check(rule.style.textSlots == inherited, "add cannot overwrite inherited EUI text")
for _, key in ipairs({ "textSlotLeft", "textSlotCenter", "textSlotRight", "textSlotBottomLeft", "textSlotBottomRight" }) do Add(key) end
-- Native cast slots are listed; adding is only needed if EUI has them hidden.
for _, key in ipairs({ "castName", "castTarget", "castTimer" }) do
    if not rows[key == "castName" and "Cast name text" or key == "castTarget" and "Cast target text" or "Cast timer text"] then Add(key) end
end
local contents = { ["Top text"] = "name", ["Left text"] = "name", ["Center text"] = "healthPercent",
    ["Right text"] = "healthCurrentMax", ["Bottom-left text"] = "healthMax", ["Bottom-right text"] = "targetOfTarget",
    ["Cast name text"] = "spellName", ["Cast target text"] = "castTarget", ["Cast timer text"] = "castElapsedTotal" }
for label, value in pairs(contents) do rows[label].set(value); f.Flush() end
Check(rows["+ Add Text Slot"].disabled(), "full layout disables add")
Check(rows["Cast timer text"].values.castElapsedTotal and not rows["Cast timer text"].values.healthMax, "cast choices scoped")
Popup("Top text", "Override color").set(true)
Popup("Top text", "Text color").set(0.2, 0.6, 0.8)
Popup("Left text", "Override color").set(true)
Popup("Left text", "Text color").set(0.8, 0.6, 0.2)
local hero = f.GetPreview()
Check(hero.textFonts.textSlotTop.text == "Enemy Name" and hero.textFonts.textSlotRight.text == "6,600 / 8,800", "hero content")
Check(hero.textFonts.textSlotTop.textColor[1] == 0.2 and hero.textFonts.textSlotLeft.textColor[1] == 0.8,
    "same content has independent slot colors")
Check(hero.textFonts.textSlotTop.fontSize == 18 and hero.textFonts.textSlotTop.point[4] == 15 and hero.textFonts.textSlotTop.point[5] == 13,
    "hero immediately previews selected size/offsets")
Check(hero.textFonts.castName:GetParent() == hero.castTextHost, "cast labels retain raised preview host")
hero.scripts.OnUpdate(hero, 1)
Check(hero.textFonts.castTimer.text == "1.0 / 3.0", "custom timer animates")
local staleColor = Popup("Left text", "Text color").set
rows["Left text"].set("none"); f.Flush()
hero = f.GetPreview()
Check(not hero.textFonts.textSlotLeft:IsShown(), "Remove hides preview slot")
staleColor(1, 0, 0)
Check(rule.style.textSlotColors.textSlotLeft.r == 0.8, "removed slot blocks stale popup writes")
local move = rows["Top text position menu"]
Check(move.itemDisabled("textSlotRight") and move.itemDisabled("castName"), "move blocks occupied/cross-group slots")
move.setValue("textSlotRight")
Check(rule.style.textSlots.textSlotTop == "name", "blocked move changes nothing")
move.setValue("textSlotLeft"); f.Flush()
hero = f.GetPreview()
Check(rule.style.textSlots.textSlotTop == "none" and rule.style.textSlots.textSlotLeft == "name", "move transfers content")
Check(rule.style.textSlotColors.textSlotTop == nil and rule.style.textSlotColors.textSlotLeft.r == 0.2, "move carries color")
Check(rule.style.textSlotLayout.textSlotTop == nil and rule.style.textSlotLayout.textSlotLeft.size == 18,
    "move carries saved layout overrides")
Check(hero.textFonts.textSlotLeft.textColor[1] == 0.2 and not hero.textFonts.textSlotTop:IsShown(), "move updates preview")
move.setValue("textSlotCenter")
Check(rule.style.textSlots.textSlotCenter == "healthPercent", "stale removed-source menu cannot move")
Add("textSlotTop")
rows["Top text"].set("eui"); f.Flush()
Check(rule.style.textSlots.textSlotTop == nil, "Use EUI stores no content override")
local staleSlot = rows["Top text"].set
staleColor = Popup("Left text", "Text color").set
local staleSize = Popup("Left text", "Size").set
local staleOffset = Popup("Left text", "X Offset").set
local staleAdd = rows["+ Add Text Slot add menu"].setValue
local staleMove = rows["Left text position menu"].setValue
rows["Rule enabled"].set(false)
staleSlot("healthMax"); staleColor(1, 0, 0); staleAdd("textSlotTop"); staleMove("textSlotTop"); staleSize(25); staleOffset(100)
Check(rule.style.textSlots.textSlotTop == nil and rule.style.textSlotColors.textSlotLeft.r == 0.2, "rule lock guards stale controls/menus")
Check(rule.style.textSlotLayout.textSlotLeft.size == 18 and rule.style.textSlotLayout.textSlotLeft.x == 15, "rule lock guards layout callbacks")
rows["Rule enabled"].set(true)
rows["Enable Nameplate styling"].set(false)
Popup("Left text", "Override color").set(false)
Check(rule.style.textSlotColors.textSlotLeft.r == 0.2, "global lock guards popup writes")
rows["Enable Nameplate styling"].set(true)
local other = { name = "Other text rule", enabled = true, conditions = {}, style = { textEnabled = true } }
for key, value in pairs(rule.style) do other.style[key] = value end
other.style.textSlots, other.style.textColors, other.style.textSlotColors, other.style.textSlotLayout = nil, nil, nil, nil
api.GetSettings().rules[2] = other
EllesmereUI:RefreshPage()
rows["Edit rule"].set("2")
staleSlot("level"); staleColor(1, 0, 0); staleAdd("textSlotLeft"); staleMove("textSlotTop"); staleSize(25); staleOffset(100)
Check(other.style.textSlots == nil and other.style.textSlotColors == nil, "stale callbacks cannot edit another rule")
Check(other.style.textSlotLayout == nil, "stale layout callbacks cannot edit another rule")
rows["Edit rule"].set("1")
-- Existing content-wide colors remain readable without migration; slot Off
-- suppresses that fallback without affecting another slot's same content.
rule.style.textColors = { name = { r = 0.4, g = 0.5, b = 0.6 } }
EllesmereUI:RefreshPage()
Check(Popup("Top text", "Override color").get(), "existing content color remains accessible")
Popup("Top text", "Override color").set(false)
Check(rule.style.textSlotColors.textSlotTop == false and rule.style.textColors.name.r == 0.4, "slot Off preserves existing data")
local code = assert(api.ExportRuleSet())
Check(api.ImportRuleSet(code), "text rules import")
Check(api.GetRules()[1].style.textSlotColors.textSlotTop == false and api.GetRules()[1].style.textSlotColors.textSlotLeft.r == 0.2,
    "slot colors and explicit EUI coloring roundtrip")
Check(api.GetRules()[1].style.textSlotLayout.textSlotLeft.size == 18 and api.GetRules()[1].style.textSlotLayout.textSlotLeft.y == 9,
    "size and offsets sharing roundtrip")
local serializer = EllesmereUI._Serializer
for _, invalid in ipairs({ { textSlots = { unknown = "name" } }, { textSlots = { castTimer = "healthMax" } },
    { textSlotColors = { unknown = false } }, { textSlotColors = { textSlotTop = true } },
    { textSlotColors = { castName = { r = 2, g = 0, b = 0 } } }, { textSlotLayout = { textSlotTop = { size = 31 } } },
    { textSlotLayout = { castName = { x = "20" } } } }) do
    local payload = serializer.Deserialize(code:sub(18))
    for key, value in pairs(invalid) do payload.rules[1].style[key] = value end
    local before = api.GetRules()
    Check(not api.ImportRuleSet("!EUI_NPEX_RULES2!" .. serializer.Serialize(payload)) and api.GetRules() == before, "invalid text settings rejected atomically")
end
EllesmereUI:RefreshPage()
rows["Override text"].set(false); f.Flush()
hero = f.GetPreview()
Check(hero.name:IsShown() and (not hero.textFonts.textSlotLeft or not hero.textFonts.textSlotLeft:IsShown()), "master off restores preview baseline")
Check(api.GetRules()[1].style.textSlotColors.textSlotLeft.r == 0.2, "master off preserves settings")
-- Feature-detected menu fallback: older EUI can add the first free position
-- and move through a Position dropdown in the popup.
EllesmereUI.BuildRowLabelMenu, EllesmereUI.AttachButtonMenu = nil, nil
rows["Override text"].set(true); f.Flush()
rows["Left text"].set("none"); f.Flush()
rows["+ Add Text Slot"].click(); f.Flush()
Check(api.GetRules()[1].style.textSlots.textSlotLeft == "name", "missing menu API has safe add fallback")
Check(Popup("Left text", "Position") ~= nil, "missing label API has move fallback")
local oldRule = api.GetRules()[1]
local oldContent, oldColor = rows["Left text"].set, Popup("Left text", "Text color").set
local oldMove = Popup("Left text", "Position").set
local oldSize = Popup("Left text", "Size").set
Check(api.CreateProfile("Text popup profile"), "profile switch for stale-popup regression")
local profileRule = api.GetRules()[1]
profileRule.style.textEnabled = true
EllesmereUI:RefreshPage()
oldContent("level"); oldColor(1, 0, 0); oldMove("textSlotTop"); oldSize(24)
Check(profileRule.style.textSlots == nil and profileRule.style.textSlotColors == nil, "stale popup/position controls cannot write into another profile")
Check(oldRule.style.textSlots.textSlotLeft == "name", "profile switch also preserves old rule content")
Check(profileRule.style.textSlotLayout == nil and oldRule.style.textSlotLayout.textSlotLeft.size == 18, "profile switch guards layout writes")
-- Moving an inherited EUI slot uses explicit content at the destination,
-- rather than inheriting the destination's (empty) EUI setting.
-- Label menus are absent here, so use the supported popup fallback.
Popup("Top text", "Position").set("textSlotLeft"); f.Flush()
Check(profileRule.style.textSlots.textSlotTop == "none" and profileRule.style.textSlots.textSlotLeft == "name", "inherited content survives a move")
Check(profileRule.style.textSlotColors.textSlotLeft == false, "inherited EUI color stays unoverridden after move")
print("PASS: " .. checks .. " compact text slots/popups, add/remove/move, independent colors, locks, sharing and menu fallbacks")
