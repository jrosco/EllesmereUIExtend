-- Run from the repository root with Lua or fengari.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local api, addon, plate, np, checks = f.api, f.namespace, f.plate, EllesmereNameplates_NS, 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
plate.healthTextFrame = CreateFrame("Frame", nil, plate)
plate.topTextFrame = CreateFrame("Frame", nil, plate)
for _, key in ipairs({ "name", "hpText", "hpNumber", "levelText", "totText" }) do
    plate[key] = plate.healthTextFrame:CreateFontString()
    plate[key]:SetFont("native.ttf", 12, "OUTLINE")
end
for _, key in ipairs({ "castName", "castTarget", "castTimer" }) do
    plate[key] = plate.cast:CreateFontString()
    plate[key]:SetFont("native.ttf", 10, "OUTLINE")
end
np.db = { profile = { textSlotTop = "enemyName", textSlotRight = "healthNumber",
    textSlotTopSize = 12, textSlotTopXOffset = 7, textSlotTopYOffset = -3,
    textSlotRightSize = 11, textSlotRightXOffset = 9, textSlotRightYOffset = 2,
    castNameOffsetX = 8, castNameOffsetY = 4, castNameSize = 10 } }
np.GetTextSlot = function(key) return np.db.profile[key] or "none" end
np.GetHealthBarWidth = function() return 180 end
plate.name:SetPoint("BOTTOM", plate.health, "TOP", 7, 1)
plate.castName:SetPoint("LEFT", plate.cast, "LEFT", 13, 4)
local style = { textEnabled = true, healthEnabled = false, borderSize = 0,
    textSlots = { textSlotRight = "healthCurrent" },
    textSlotLayout = { textSlotTop = { size = 18, x = 15, y = 9 },
        textSlotRight = { size = 20, x = 25, y = 6 }, castName = { size = 16, x = 2, y = -5 } } }
local rule = { name = "Layout rule", enabled = true, conditions = { target = { yes = true } }, style = style }
api.GetSettings().rules = { rule }
local function Refresh() api.Refresh(); f.Flush() end
Refresh()
local _, fonts = addon.GetRuleTextFrames(plate)
Check(plate.name.fontSize == 18 and plate.name.fontPath == "native.ttf", "inherited native content accepts size override without changing font")
Check(plate.name.point[4] == 15 and plate.name.point[5] == 13, "configured offsets are replaced, not added, retaining base anchor")
Check(plate.castName.fontSize == 16 and plate.castName.point[4] == 7 and plate.castName.point[5] == -5, "cast offsets use OffsetX/OffsetY and retain cast inset")
Check(fonts.textSlotRight.fontSize == 20 and fonts.textSlotRight.point[4] == 23 and fonts.textSlotRight.point[5] == 6, "replacement content honors size and absolute offsets")
Check(np.db.profile.textSlotTopXOffset == 7 and np.db.profile.castNameSize == 10, "EUI profile is not modified")
-- New EUI writes are captured as restoration targets while overrides remain.
np.db.profile.textSlotTopXOffset, np.db.profile.textSlotTopYOffset = 20, 6
plate.name:SetFont("new-native.ttf", 14, "THICKOUTLINE")
plate.name:ClearAllPoints()
plate.name:SetPoint("BOTTOM", plate.health, "TOP", 20, 16) -- 10px dynamic base
Check(plate.name.fontSize == 18 and plate.name.fontPath == "new-native.ttf", "engine font updates retain selected size")
Check(plate.name.point[4] == 15 and plate.name.point[5] == 19, "engine reanchor retains new dynamic base with replaced offsets")
plate.name:SetFontHeight(15)
Check(plate.name.fontSize == 18, "native font-height writes retain selected override size")
style.textSlotLayout.textSlotTop.size = nil
Refresh()
Check(plate.name.fontSize == 15 and plate.name.fontFlags == "THICKOUTLINE", "size off restores latest native font/size even with in-place settings edits")
plate.name:SetFontHeight(14)
style.textSlotLayout.textSlotTop.x, style.textSlotLayout.textSlotTop.y = nil, nil
Refresh()
Check(plate.name.point[4] == 20 and plate.name.point[5] == 16, "offsets off restores latest EUI anchor")
style.textSlotLayout.textSlotTop = { size = 21, x = -4, y = 3 }
Refresh()
style.textEnabled = false
Refresh()
Check(plate.name.fontSize == 14 and plate.name.point[4] == 20 and plate.castName.fontSize == 10, "master off restores native layout")
style.textEnabled = true
Refresh()
plate._interrupted = true
Refresh()
Check(plate.castName.fontSize == 10 and plate.castName.point[4] == 13, "interrupted text remains native")
plate._interrupted = nil
rule.conditions.target = { no = true }
Refresh()
Check(plate.name.fontSize == 14 and plate.name.point[4] == 20, "unmatched rule restores layout")
rule.conditions.target = { yes = true }
Refresh()
plate:ClearUnit()
Check(plate.name.fontSize == 14 and plate.name.point[4] == 20, "recycled plate restores layout")
plate.unit = "nameplate1"
np.db.profile.textSlotTop, np.db.profile.textSlotLeft = "none", "enemyName"
np.db.profile.textSlotLeftXOffset, np.db.profile.textSlotLeftYOffset = 3, 5
style.textSlotLayout.textSlotLeft = { size = 19, x = 4, y = 8 }
plate.name:ClearAllPoints()
plate.name:SetPoint("LEFT", plate.health, "LEFT", 7, 5)
Refresh()
Check(plate.name.fontSize == 19 and plate.name.point[4] == 8 and plate.name.point[5] == 8,
    "native font string changing slots uses its new slot's authored offset baseline")
np.db.profile.textSlotTop, np.db.profile.textSlotLeft = "enemyName", "none"
style.textSlotLayout.textSlotLeft = nil
plate.name:ClearAllPoints()
plate.name:SetPoint("BOTTOM", plate.health, "TOP", 20, 16)
Refresh()
-- Secret geometry is passed back only to native setters, never inspected or
-- subtracted. Read failures skip geometry until a readable engine write.
plate.name:SetPoint("BOTTOM", plate.health, "TOP", f.secret, f.secret)
Refresh()
Check(plate.name.point[4] == f.secret and plate.name.point[5] == f.secret, "secret anchor values never enter offset arithmetic")
plate.name:SetPoint("BOTTOM", plate.health, "TOP", 20, 16)
Check(plate.name.point[4] == -4 and plate.name.point[5] == 13, "readable engine reanchor resumes overrides")
-- A new native owner with restricted getters must not reuse the old owner's
-- initial snapshot. Setter hooks can later recover without geometry getters.
local replacement = plate.topTextFrame:CreateFontString()
replacement:SetFont("restricted.ttf", 13, "OUTLINE")
replacement:SetPoint("BOTTOM", plate.health, "TOP", 20, 16)
replacement.GetNumPoints = function() error("restricted geometry") end
plate.name = replacement
Refresh()
Check(replacement.fontSize == 21 and replacement.point[4] == 20, "restricted geometry getter fails closed while size remains supported")
replacement:SetPoint("BOTTOM", plate.health, "TOP", 20, 16)
Check(replacement.point[4] == -4, "setter-authored anchors recover without restricted reads")
replacement.GetFont = function() return f.secret, f.secret, f.secret end
local secretFont = plate.cast:CreateFontString()
secretFont:SetFont("untouched.ttf", 10, "OUTLINE")
secretFont.GetFont = replacement.GetFont
plate.castName = secretFont
Refresh()
Check(secretFont.fontPath == "untouched.ttf" and secretFont.fontSize == 10, "unreadable native font fails closed")
local multiple = plate.topTextFrame:CreateFontString()
multiple:SetFont("multi.ttf", 12, "OUTLINE")
local anchors = {}
multiple.SetPoint = function(_, point, relative, relativePoint, x, y) anchors[point] = { point, relative, relativePoint, x, y } end
multiple.GetNumPoints = function() local count = 0; for _ in pairs(anchors) do count = count + 1 end; return count end
multiple.GetPoint = function(_, index) local i = 0; for _, point in pairs(anchors) do i = i + 1; if i == index then return unpack(point) end end end
multiple.ClearAllPoints = function() anchors = {} end
multiple:SetPoint("LEFT", plate.health, "LEFT", 24, 6)
multiple:SetPoint("RIGHT", plate.health, "RIGHT", 18, 6)
plate.name = multiple
Refresh()
Check(anchors.LEFT[4] == 0 and anchors.RIGHT[4] == -6, "all native anchors preserve their distinct base geometry")
multiple:SetPoint("TOP", plate.health, "TOP", 20, 10)
Check(anchors.TOP[4] == -4 and anchors.LEFT[4] == 0, "new engine anchor does not compound existing overridden anchors")
style.textSlotLayout.textSlotTop = nil
Refresh()
Check(anchors.LEFT[4] == 24 and anchors.RIGHT[4] == 18 and anchors.TOP[5] == 10, "all latest native anchors restore without clearing unrelated points")
for _, bad in ipairs({ { textSlotLayout = true }, { textSlotLayout = { unknown = {} } },
    { textSlotLayout = { textSlotTop = { size = 31 } } }, { textSlotLayout = { castName = { x = 201 } } },
    { textSlotLayout = { textSlotRight = { y = 0 / 0 } } }, { textSlotLayout = { textSlotTop = { strata = "HIGH" } } } }) do
    Check(not api.ValidateRuleText(bad), "invalid slot layout rejected")
end
print("PASS: " .. checks .. " text size/absolute offsets, native/restored layout, dynamic bases, secret/restricted geometry and validation")
