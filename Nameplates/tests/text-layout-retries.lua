-- Run from the repository root with Lua or fengari.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local plate, addon, np, checks = f.plate, f.namespace, EllesmereNameplates_NS, 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
np.db = { profile = { textSlotTop = "enemyName", textSlotTopXOffset = 2, textSlotTopYOffset = 3 } }
np.GetTextSlot = function(key) return np.db.profile[key] or "none" end
local fs = plate:CreateFontString()
plate.name = fs
local fontFailure, blocked, anchors, pointCalls, fontCalls = nil, {}, {}, {}, 0
local setFont = fs.SetFont
fs.SetFont = function(self, ...)
    fontCalls = fontCalls + 1
    if fontFailure == "throw" then error("temporarily restricted font") end
    if fontFailure == "false" then return false end
    return setFont(self, ...)
end
fs.SetPoint = function(_, point, relative, relativePoint, x, y)
    pointCalls[point] = (pointCalls[point] or 0) + 1
    if blocked[point] then error("temporarily restricted anchor") end
    anchors[point] = { point, relative, relativePoint, x, y }
end
fs.GetNumPoints = function() local count = 0; for _ in pairs(anchors) do count = count + 1 end; return count end
fs.GetPoint = function(_, index)
    local i = 0; for _, point in pairs(anchors) do i = i + 1; if i == index then return unpack(point) end end
end
fs.ClearAllPoints = function() anchors = {} end
fs:SetFont("native.ttf", 12, "OUTLINE")
fs:SetPoint("LEFT", plate.health, "LEFT", 12, 7)
fs:SetPoint("RIGHT", plate.health, "RIGHT", 18, 7)
local style = { textEnabled = true, textSlotLayout = { textSlotTop = { size = 18, x = 5, y = 6 } } }
local function Apply(value) addon.ApplyRuleText(plate, value) end
Apply(style)
Check(fs.fontSize == 18 and anchors.LEFT[4] == 15 and anchors.RIGHT[4] == 21, "overrides applied before restricted restoration")
fs:SetFont("latest.ttf", 14, "THICKOUTLINE")
fs:SetPoint("LEFT", plate.health, "LEFT", 22, 13)
Check(fs.fontSize == 18 and anchors.LEFT[4] == 25, "latest native writes captured under overrides")
fontFailure, blocked.RIGHT = "throw", true
Apply(nil)
Check(fs.fontSize == 18 and anchors.RIGHT[4] == 21, "failed restorations remain pending")
Check(anchors.LEFT[4] == 22 and anchors.LEFT[5] == 13, "readable anchor restores even when another anchor fails")
local leftCalls, rightCalls, previousFontCalls = pointCalls.LEFT, pointCalls.RIGHT, fontCalls
Apply(nil)
Check(pointCalls.LEFT == leftCalls and pointCalls.RIGHT > rightCalls and fontCalls > previousFontCalls,
    "later released refresh retries only unresolved writes")
fontFailure, blocked.RIGHT = "false", nil
Apply(nil)
Check(anchors.RIGHT[4] == 18 and fs.fontSize == 18, "anchor can restore independently of non-throwing font failure")
rightCalls = pointCalls.RIGHT
fontFailure = nil
Apply(nil)
Check(fs.fontPath == "latest.ttf" and fs.fontSize == 14 and fs.fontFlags == "THICKOUTLINE", "font retry restores latest tuple after SetFont returned false")
Check(pointCalls.RIGHT == rightCalls, "successfully restored anchor is not retried")
previousFontCalls = fontCalls
Apply(nil)
Check(fontCalls == previousFontCalls and pointCalls.LEFT == leftCalls and pointCalls.RIGHT == rightCalls, "successful restoration clears all retry debt")
-- Clearing just the fields (as the editor does) must retain pending debt even
-- while the text master stays enabled and the desired layout is empty/nil.
Apply(style)
fontFailure, blocked.LEFT = "throw", true
style.textSlotLayout.textSlotTop = {}
Apply(style)
Check(fs.fontSize == 18 and anchors.LEFT[4] == 25, "empty desired layout does not discard restoration failures")
fontFailure, blocked.LEFT = nil, nil
Apply(style)
Check(fs.fontSize == 14 and anchors.LEFT[4] == 22, "empty-layout refresh restores after restrictions lift")
-- New desired overrides must supersede pending restoration rather than
-- restoring a stale previous layout first.
style.textSlotLayout.textSlotTop = { size = 18, x = 5, y = 6 }
Apply(style)
fontFailure, blocked.RIGHT = "throw", true
Apply(nil)
style.textSlotLayout.textSlotTop = { size = 22, x = 7, y = 9 }
fontFailure, blocked.RIGHT = nil, nil
Apply(style)
Check(fs.fontSize == 22 and anchors.LEFT[4] == 27 and anchors.RIGHT[4] == 23, "new overrides supersede pending release with unchanged native baselines")
Apply(nil)
Check(fs.fontSize == 14 and anchors.LEFT[4] == 22 and anchors.RIGHT[4] == 18, "new override still releases to latest native values")
-- Native engine writes during a pending release retire the old debt and
-- become the new restoration targets; they must not be overwritten by it.
Apply(style)
fontFailure, blocked.RIGHT = "throw", true
Apply(nil)
fontFailure = nil
fs:SetFont("newer.ttf", 16, "")
blocked.RIGHT = nil
fs:SetPoint("RIGHT", plate.health, "RIGHT", 30, 11)
Apply(nil)
Check(fs.fontPath == "newer.ttf" and fs.fontSize == 16 and anchors.RIGHT[4] == 30 and anchors.RIGHT[5] == 11,
    "engine writes replace pending restoration targets without stale replay")
-- A failed override write never creates false ownership of native state.
fontFailure = "false"
style.textSlotLayout.textSlotTop = { size = 24 }
Apply(style)
previousFontCalls = fontCalls
Apply(nil)
Check(fontCalls == previousFontCalls and fs.fontSize == 16, "failed override application does not schedule unnecessary restoration")
print("PASS: " .. checks .. " text layout restoration retries, partial failures, false SetFont results and latest native ownership")
