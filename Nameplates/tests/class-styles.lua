-- Run from the repository root with Lua or fengari.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local api, addon, plate, np, checks = f.api, f.namespace, f.plate, EllesmereNameplates_NS, 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Near(actual, expected, label) Check(math.abs(actual - expected) < 0.00001, label) end
local token = "MAGE"
UnitClass = function() return "Mage", token, 8 end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 }, WARRIOR = { 0, 0.25, 0, 0.25 } }
f.mocks.player = true
plate.health:SetParent(plate)
plate.healthTextFrame = CreateFrame("Frame", nil, plate)
plate.name = plate.healthTextFrame:CreateFontString()
plate.name:SetText("Native player name"); plate.name:SetTextColor(0.8, 0.6, 0.4, 0.9)
function plate:UpdateName() end
np.db = { profile = { textSlotTop = "enemyName" } }
np.GetTextSlot = function(key) return np.db.profile[key] or "none" end
local style = { healthEnabled = true, healthClassColor = true, nameClassColor = true, classIconEnabled = true,
    classIconSide = "left", classIconSize = 24, classIconX = 3, classIconY = -2, borderSize = 0,
    healthColorEnabled = true, healthColor = { r = 1, g = 0, b = 0 }, scale = 150, opacity = 80 }
api.GetSettings().rules = { { name = "Players", enabled = true, conditions = {}, style = style } }
local function Refresh() api.Refresh(); f.Flush() end
Refresh()
Near(plate.health.color[1], 0.25, "health uses class rather than custom color")
Near(plate.name.textColor[1], 0.25, "native name gets class color without text override")
Check(plate.name.text == "Native player name", "native name content is untouched")
local icon = assert(addon.GetClassIconFrame(plate))
Check(icon:IsShown() and icon.width == 24 and icon.height == 24, "lazy class icon size")
Check(icon._classIcon.texCoord[1] == 0.25 and icon.point[1] == "RIGHT" and icon.point[4] == -3 and icon.point[5] == -2,
    "left sprite and absolute offsets")
Near(icon:GetEffectiveScale(), 1.5, "icon follows Other elements scaling")
style.scaleElements = { other = false }; Refresh()
Near(icon:GetEffectiveScale(), 1, "unchecked Other retains native size")
style.classIconSide = "right"; Refresh()
Check(icon.point[1] == "LEFT" and icon.point[4] == 9, "right side reverses default gap")
plate.health:SetStatusBarColor(0.4, 0.5, 0.6, 0.7)
plate.name:SetTextColor(0.7, 0.6, 0.5, 0.8)
f.Flush()
Near(plate.name.textColor[1], 0.25, "class tint survives native repaint")
token = "WARRIOR"; Refresh()
Near(plate.health.color[1], 0.78, "class changes refresh health")
Near(plate.name.textColor[1], 0.78, "class changes refresh name")
Check(icon._classIcon.texCoord[1] == 0, "class changes refresh emblem")
token = f.secret; Refresh()
Near(plate.health.color[1], 0.4, "secret class releases health to latest native color")
Near(plate.name.textColor[1], 0.7, "secret class releases name to latest native color")
Check(not icon:IsShown(), "secret class never indexes icon map")
token = "MAGE"
f.mocks.player = f.secret; Refresh()
Check(not icon:IsShown() and plate.health.color[1] == 0.4, "secret player flag fails closed")
f.mocks.player = false; Refresh()
Check(not icon:IsShown() and plate.name.textColor[1] == 0.7, "NPCs retain native style in class mode")
f.mocks.player = true
UnitClass = function() error("restricted identity") end; Refresh()
Check(not icon:IsShown() and plate.health.color[1] == 0.4, "throwing class getter fails closed")
UnitClass = nil; Refresh()
Check(not api.SupportsClassColors() and not icon:IsShown(), "missing API preserves native appearance")
UnitClass = function() return "Mage", token end
issecretvalue = nil; Refresh()
Near(plate.health.color[1], 0.25, "Forever readable class fallback")
Check(icon:IsShown(), "Forever client sprite fallback")
UnitIsTapDenied = function() return true end; Refresh()
Near(plate.health.color[1], 0.4, "tapped units retain native color")
UnitIsTapDenied = function() return false end
C_ClassColor = { GetClassColor = function() return { r = 0.3, g = 0.4, b = 0.5 } end }; Refresh()
Near(plate.health.color[1], 0.3, "Retail class color API")
C_ClassColor.GetClassColor = function() error("unavailable") end; Refresh()
Near(plate.health.color[1], 0.25, "throwing color API falls back to RAID colors")
issecretvalue = function(value) return value == f.secret end
C_ClassColor.GetClassColor = function() return { r = f.secret, g = 0.4, b = 0.5 } end; Refresh()
Near(plate.health.color[1], 0.4, "secret color channel is not inspected")
C_ClassColor = nil
CLASS_ICON_TCOORDS = nil; Refresh()
Check(not api.SupportsClassIcons() and not icon:IsShown(), "missing client artwork hides icon")
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 } }
local setPoint = icon.SetPoint
icon.SetPoint = function() error("restricted anchor") end; Refresh()
Check(not icon:IsShown(), "restricted icon anchor hides owned decoration without breaking paint")
icon.SetPoint = setPoint; Refresh()
Check(icon:IsShown(), "restricted icon anchor recovery")
style.textEnabled = true; style.textSlots = { textSlotTop = "name" }
style.textColors = { name = { r = 1, g = 0, b = 0 } }; Refresh()
local _, fonts = addon.GetRuleTextFrames(plate)
Near(fonts.textSlotTop.textColor[1], 0.25, "replacement name class color wins over saved custom color")
style.nameClassColor = false; Refresh()
Near(fonts.textSlotTop.textColor[1], 1, "disabling class mode restores saved custom name color")
style.textEnabled = false; style.healthClassColor = false; style.classIconEnabled = false; Refresh()
Near(plate.name.textColor[1], 0.7, "releasing name override restores latest EUI state")
Near(plate.health.color[1], 1, "disabling class mode restores rule custom health color")
Check(not icon:IsShown(), "disabling emblem hides it")
style.classIconEnabled = true; style.nameClassColor = true; style.healthClassColor = true; Refresh()
api.GetRules()[1].enabled = false; Refresh()
Check(not icon:IsShown() and plate.name.textColor[1] == 0.7 and plate.health.color[1] == 0.4,
    "disabled rule releases all class styling")
api.GetRules()[1].enabled = true; Refresh()
api.GetSettings().enabled = false; Refresh()
Check(not icon:IsShown() and plate.name.textColor[1] == 0.7, "master disable releases class styling")
api.GetSettings().enabled = true; Refresh()
api.GetRules()[1].conditions.unitType = { npc = true }; Refresh()
Check(not icon:IsShown() and plate.health.color[1] == 0.4, "unmatched player releases class styling")
api.GetRules()[1].conditions.unitType = {}; Refresh()
plate:ClearUnit()
Check(not icon:IsShown(), "pool release hides departing player's class")
Near(plate.name.textColor[1], 0.7, "pool release restores native name tint")
plate.unit = "nameplate2"; token = "WARRIOR"; f.mocks.player = false; Refresh()
Check(not icon:IsShown(), "recycled NPC never keeps departing class emblem")
print("PASS: " .. checks .. " class styles, restricted identity, native restoration, icon lifecycle and client fallbacks")
