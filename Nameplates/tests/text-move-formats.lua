-- Run from the repository root with Lua or fengari.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("ui-locks")
local api, rows, np, checks = f.api, f.rows, EllesmereNameplates_NS, 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
np.db = { profile = { textSlotTop = "enemyName", textSlotLeft = "none", textSlotRight = "none" } }
np.GetTextSlot = function(key) return np.db.profile[key] or "none" end
rows["Override text"].set(true); f.Flush()
local rule = api.GetRules()[1]
rule.style.textSlotColors = { textSlotTop = { r = 0.2, g = 0.4, b = 0.6 } }
rule.style.textSlotLayout = { textSlotTop = { size = 18, x = 5 } }
EllesmereUI:RefreshPage()
local menu = rows["Top text position menu"]
local color, layout = rule.style.textSlotColors.textSlotTop, rule.style.textSlotLayout.textSlotTop
local formats = { "levelName", "nameLevel", "healthPctNum", "healthNumPct", "healthPctNumDash", "healthNumPctDash", "healthPercentNoSign", "unknownFutureFormat" }
for _, format in ipairs(formats) do
    -- Menu outlives a change to EUI's underlying content: checks must read the
    -- current raw format at click time, not its normalized color category.
    np.db.profile.textSlotTop = format
    local tip = menu.itemDisabled("textSlotLeft")
    Check(type(tip) == "string" and tip:find("explicit rule content", 1, true), "lossy inherited move has an explanatory tooltip: " .. format)
    Check(not menu.itemDisabled("textSlotTop"), "current position remains selectable")
    menu.setValue("textSlotLeft")
    Check(rule.style.textSlots == nil and rule.style.textSlotColors.textSlotTop == color and rule.style.textSlotLayout.textSlotTop == layout,
        "blocked inherited move leaves all rule data unchanged: " .. format)
    Check(np.db.profile.textSlotTop == format, "blocked move leaves EUI settings unchanged")
end
np.db.profile.textSlotTop = "healthPercent"
np.db.profile.textSlotTopPctDecimal = true
Check(type(menu.itemDisabled("textSlotLeft")) == "string", "inherited percentage decimals are not silently discarded")
np.db.profile.textSlotTopPctDecimal = false
Check(not menu.itemDisabled("textSlotLeft"), "plain inherited percent is movable")
np.db.profile.textSlotTop = "enemyName"
EllesmereUI.IS_FOREVER = true
np.db.profile.textSlotTopNameFormat = "first"
Check(type(menu.itemDisabled("textSlotLeft")) == "string", "Forever short-name format is not silently discarded")
np.db.profile.textSlotTopNameFormat = "full"
Check(not menu.itemDisabled("textSlotLeft"), "Forever full name remains movable")
EllesmereUI.IS_FOREVER = false
np.db.profile.textSlotTopNameFormat = nil
np.db.profile.textSlotTop = "healthNumber"
Check(not menu.itemDisabled("textSlotLeft"), "harmless native health-number alias remains movable")
menu.setValue("textSlotLeft"); f.Flush()
Check(rule.style.textSlots.textSlotLeft == "healthCurrent" and rule.style.textSlots.textSlotTop == "none", "lossless native alias moves to supported rule content")
Check(rule.style.textSlotColors.textSlotLeft.r == 0.2 and rule.style.textSlotLayout.textSlotLeft.size == 18, "lossless move carries saved color/layout")
-- Explicit rule content is intentional: it may move even when underlying
-- EUI settings have a composite format the rule no longer inherits.
np.db.profile.textSlotTop = "levelName"
rows["Left text position menu"].setValue("textSlotRight"); f.Flush()
rows["+ Add Text Slot add menu"].setValue("textSlotTop"); f.Flush()
menu = rows["Top text position menu"]
Check(not menu.itemDisabled("textSlotLeft"), "explicit content may move independently of native composite format")
menu.setValue("textSlotLeft"); f.Flush()
Check(rule.style.textSlots.textSlotLeft == "name", "explicit name moved without changing chosen content")
np.db.profile.castCombineNameTarget = true
local castMenu = rows["Cast name text position menu"]
rows["Cast target text"].set("none"); f.Flush()
Check(type(castMenu.itemDisabled("castTarget")) == "string", "combined inherited spell/target label cannot silently lose its target")
castMenu.setValue("castTarget")
Check(rule.style.textSlots.castName == nil, "combined cast move makes no changes")
rows["Cast name text"].set("spellName"); f.Flush()
castMenu = rows["Cast name text position menu"]
Check(not castMenu.itemDisabled("castTarget"), "explicit spell name remains movable with native combine enabled")
-- Older EUI's Position popup uses the same click-time safety check.
EllesmereUI.BuildRowLabelMenu = nil
np.db.profile.textSlotTop = "nameLevel"
rows["+ Add Text Slot add menu"].setValue("textSlotTop"); f.Flush()
rows["Top text"].set("eui"); f.Flush()
local position
for _, control in ipairs(rows["Top text settings"].rows) do if control.label == "Position" then position = control end end
Check(position and type(position.itemDisabled("textSlotBottomLeft")) == "string", "fallback Position popup explains blocked inherited formats")
position.set("textSlotBottomLeft")
Check(rule.style.textSlots.textSlotTop == nil and rule.style.textSlots.textSlotBottomLeft == nil, "fallback cannot write lossy move")
print("PASS: " .. checks .. " inherited-format move protection, composite/decimal/Forever formats, click-time checks and menu fallbacks")
