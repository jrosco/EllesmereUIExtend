-- Run from the repository root with Lua or fengari.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("ui-locks")
local api, rows, np, checks = f.api, f.rows, EllesmereNameplates_NS, 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Popup(slot, label)
    for _, control in ipairs(rows[slot .. " settings"].rows) do if control.label == label then return control end end
    error("Missing popup control: " .. slot .. "/" .. label)
end
rows["Override text"].set(true); f.Flush()
local rule = api.GetRules()[1]
np.db = { profile = { textSlotTop = "enemyName", textSlotTopSize = 13, textSlotTopXOffset = 3, textSlotTopYOffset = -2,
    castTimerSize = 10, castTimerOffsetX = 1, castTimerOffsetY = 2 } }
rule.style.textSlots = { textSlotTop = "healthCurrentMax", textSlotLeft = "name", castTimer = "castElapsedTotal" }
rule.style.textSlotColors = { textSlotTop = { r = 0.2, g = 0.6, b = 0.8 }, castTimer = { r = 0.8, g = 0.6, b = 0.2 } }
rule.style.textColors = { name = { r = 0.45, g = 0.5, b = 0.6 } }
local timerLayout = { size = 17, x = -5, y = 4 }
rule.style.textSlotLayout = { textSlotTop = { size = 20, x = 15, y = 9 }, castTimer = timerLayout }
EllesmereUI:RefreshPage()
local reset = Popup("Top text", "Reset to EUI")
Check(not reset.hidden(), "reset visible while editing")
-- Reset reads current EUI settings, not those saved when the popup opened.
np.db.profile.textSlotTopSize, np.db.profile.textSlotTopXOffset, np.db.profile.textSlotTopYOffset = 19, 7, -6
np.db.profile.textSlotTopColor = { r = 0.3, g = 0.4, b = 0.5 }
reset.action(); f.Flush()
Check(rule.style.textSlotLayout.textSlotTop == nil and rule.style.textSlotLayout.castTimer == timerLayout, "reset clears only selected slot layout")
Check(rule.style.textSlots.textSlotTop == nil and rule.style.textSlotColors.textSlotTop == false, "reset inherits EUI content/color")
Check(Popup("Top text", "Content").get() == "eui" and not Popup("Top text", "Override color").get(), "reset updates content choice and color toggle")
Check(rule.style.textSlots.textSlotLeft == "name" and rule.style.textColors.name.r == 0.45, "reset preserves other slots and content-wide saved colors")
Check(not Popup("Top text", "Override size").get() and not Popup("Top text", "Override offsets").get(), "reset turns layout toggles off")
Check(Popup("Top text", "Size").disabled() and Popup("Top text", "X Offset").disabled(), "reset disables override sliders")
Check(Popup("Top text", "Size").get() == 19 and Popup("Top text", "X Offset").get() == 7 and Popup("Top text", "Y Offset").get() == -6,
    "reset getters follow current EUI values")
local hero = f.GetPreview()
Check(hero.textFonts.textSlotTop.fontSize == 19 and hero.textFonts.textSlotTop.point[4] == 7 and hero.textFonts.textSlotTop.point[5] == -2,
    "reset updates preview size/offsets immediately")
Check(hero.textFonts.textSlotTop.text == "Enemy Name" and hero.textFonts.textSlotTop.textColor[1] == 0.3, "preview uses current EUI content/color despite saved content-wide color")
Check(hero.textFonts.textSlotLeft.textColor[1] == 0.45, "other slot sharing content-wide color is unchanged")
reset.action()
Check(rule.style.textSlotLayout.castTimer == timerLayout, "repeat reset is harmless")
np.db.profile.castTimerSize, np.db.profile.castTimerOffsetX, np.db.profile.castTimerOffsetY = 14, -4, 3
Popup("Cast timer text", "Reset to EUI").action(); f.Flush()
Check(rule.style.textSlotLayout == nil, "last slot reset prunes empty layout table")
Check(rule.style.textSlots.castTimer == nil and rule.style.textSlotColors.castTimer == false, "cast reset inherits cast content/color")
hero = f.GetPreview()
Check(hero.textFonts.castTimer.fontSize == 14 and hero.textFonts.castTimer.point[5] == 3, "cast reset uses current cast settings")
Check(hero.textElements.castTimer == "castRemaining", "cast content returns to EUI timer mode")
-- Reset still works when content/color are the only saved overrides. The
-- inherited EUI slot is empty, so the compact row must disappear.
local resetLeft = Popup("Left text", "Reset to EUI")
resetLeft.action(); f.Flush()
Check(rule.style.textSlots == nil and rule.style.textSlotColors.textSlotLeft == false, "content/color-only reset prunes empty content table")
Check(resetLeft.hidden() and not f.GetPreview().textFonts.textSlotLeft:IsShown(), "reset to empty EUI content removes slot")
Check(rule.style.textColors.name.r == 0.45, "reset does not delete saved colors shared by other slots")
-- The stale action is guarded even on EUI versions that ignore row.hidden.
rule.style.textSlotLayout = { textSlotTop = { size = 22 } }
rows["Rule enabled"].set(false)
Check(reset.hidden(), "reset hidden while rule is disabled")
reset.action()
Check(rule.style.textSlotLayout.textSlotTop.size == 22, "disabled rule blocks reset")
rows["Rule enabled"].set(true)
rows["Enable Nameplate styling"].set(false)
reset.action()
Check(rule.style.textSlotLayout.textSlotTop.size == 22, "global disable blocks reset")
rows["Enable Nameplate styling"].set(true)
rows["Override text"].set(false); reset.action()
Check(rule.style.textSlotLayout.textSlotTop.size == 22, "text master off blocks reset")
rows["Override text"].set(true); f.Flush()
reset = Popup("Top text", "Reset to EUI")
rows["Top text"].set("none"); f.Flush()
reset.action()
Check(rule.style.textSlotLayout.textSlotTop.size == 22, "removed slot blocks stale reset")
rows["+ Add Text Slot add menu"].setValue("textSlotTop"); f.Flush()
reset = Popup("Top text", "Reset to EUI")
local other = { name = "Other reset rule", enabled = true, conditions = {}, style = {} }
for key, value in pairs(rule.style) do other.style[key] = value end
other.style.textSlotLayout = { textSlotTop = { size = 24 } }
api.GetRules()[2] = other
EllesmereUI:RefreshPage()
rows["Edit rule"].set("2"); reset.action()
Check(rule.style.textSlotLayout.textSlotTop.size == 22 and other.style.textSlotLayout.textSlotTop.size == 24, "another selected rule blocks stale reset")
rows["Edit rule"].set("1")
reset = Popup("Top text", "Reset to EUI")
Check(api.CreateProfile("Text reset profile"), "profile created")
local profileRule = api.GetRules()[1]
profileRule.style.textEnabled = true
profileRule.style.textSlotLayout = { textSlotTop = { size = 26 } }
EllesmereUI:RefreshPage(); reset.action()
Check(rule.style.textSlotLayout.textSlotTop.size == 22 and profileRule.style.textSlotLayout.textSlotTop.size == 26, "profile switch blocks stale reset")
print("PASS: " .. checks .. " per-slot Reset to EUI, inherited content/color/layout, other-slot preservation and stale reset locks")
