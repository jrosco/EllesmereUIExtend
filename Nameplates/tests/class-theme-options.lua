-- Run from the repository root with Lua or fengari.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("ui-locks")
local api, rows, host, checks = f.api, f.rows, EllesmereUI, 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
UnitClass = function() return "Mage", "MAGE" end
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 } }
host.MEDIA_PATH = "Interface\\AddOns\\EllesmereUI\\media\\"
host.CLASS_ICON_SPRITE_COORDS = { MAGE = { 0.125, 0.25, 0, 0.125 } }
host:RefreshPage()
local rule = api.GetRules()[1]
local cog = assert(rows["Class emblem settings"])
Check(cog.captureRegion == rows["Show class emblem"].row._leftRegion, "cog attached beside Show class emblem toggle")
Check(cog.disabled() and #cog.rows == 5, "all five cog settings require enabled emblem")
local function LayoutControls(popup)
    local controls = {}
    for _, control in ipairs(popup.rows) do controls[control.label] = control end
    return controls
end
local function ChangeLayout(controls)
    controls["Class emblem side"].set("left")
    controls["Class emblem size"].set(44)
    controls["Class emblem X offset"].set(-20)
    controls["Class emblem Y offset"].set(30)
end
local function OriginalLayout(rule)
    return rule.style.classIconSide == "right" and rule.style.classIconSize == 36
        and rule.style.classIconX == 12 and rule.style.classIconY == -7
end
local oldStyle = cog.rows[1]
oldStyle.set("modern")
Check(rule.style.classIconStyle == nil, "disabled emblem blocks stale style callback")
ChangeLayout(LayoutControls(cog))
Check(rule.style.classIconSide == nil and rule.style.classIconSize == nil and rule.style.classIconX == nil
    and rule.style.classIconY == nil, "disabled emblem blocks all layout callbacks")
rows["Show class emblem"].set(true)
cog = rows["Class emblem settings"]
local controls = LayoutControls(cog)
controls["Class emblem side"].set("right")
controls["Class emblem size"].set(36)
controls["Class emblem X offset"].set(12)
controls["Class emblem Y offset"].set(-7)
Check(OriginalLayout(rule), "cog saves side size and both offsets")
local sample = f.GetPreview().classIcon
Check(sample.width == 36 and sample.point[1] == "LEFT" and sample.point[4] == 18 and sample.point[5] == -7,
    "geometry cog settings update preview immediately")
Check(controls["Class emblem size"].min == 12 and controls["Class emblem size"].max == 64
    and controls["Class emblem X offset"].min == -200 and controls["Class emblem Y offset"].max == 200,
    "cog retains existing layout ranges")
controls["Class emblem side"].set("top")
Check(rule.style.classIconSide == "right", "invalid side callback rejected")
local picker = cog.rows[1]
Check(not cog.disabled() and picker.get() == "blizzard", "existing rules default to Blizzard")
Check(picker.label == "Class emblem style" and #picker.order == 9, "cog contains all eight EUI themes plus Blizzard")
for _, key in ipairs(picker.order) do
    Check(picker.values[key] and not picker.itemDisabled(key), "theme offered and unlocked: " .. key)
    picker.set(key)
    Check(rule.style.classIconStyle == key, "per-rule theme selection saved: " .. key)
    local path = f.GetPreview().classIcon._classIcon:GetTexture()
    Check(key == "blizzard" or path == host.MEDIA_PATH .. "icons\\class-full\\" .. key .. ".tga", "selected theme updates live preview: " .. key)
end
picker.set("glyph")
local code = assert(api.ExportRuleSet())
Check(api.ImportRuleSet(code), "theme sharing roundtrip")
host:RefreshPage(); rule = api.GetRules()[1]
Check(rule.style.classIconStyle == "glyph" and OriginalLayout(rule), "sharing preserves selected theme and cog geometry")
picker = rows["Class emblem settings"].rows[1]
controls = LayoutControls(rows["Class emblem settings"])
rows["Rule enabled"].set(false); picker.set("modern")
ChangeLayout(controls)
Check(rule.style.classIconStyle == "glyph" and OriginalLayout(rule), "disabled rule blocks all stale cog settings")
rows["Rule enabled"].set(true)
picker = rows["Class emblem settings"].rows[1]
controls = LayoutControls(rows["Class emblem settings"])
rows["Enable Nameplate styling"].set(false); picker.set("pixel")
ChangeLayout(controls)
Check(rule.style.classIconStyle == "glyph" and OriginalLayout(rule), "master lock blocks all stale cog settings")
rows["Enable Nameplate styling"].set(true)
picker = rows["Class emblem settings"].rows[1]
controls = LayoutControls(rows["Class emblem settings"])
rows["Add PvP preset"].click(); picker.set("legend")
ChangeLayout(controls)
Check(rule.style.classIconStyle == "glyph" and OriginalLayout(rule) and api.GetRules()[1].style.classIconStyle == nil
    and api.GetRules()[1].style.classIconX == nil, "rule selection invalidates all old cog settings")
picker = rows["Class emblem settings"].rows[1]
controls = LayoutControls(rows["Class emblem settings"])
local old = api.GetSettings()
EllesmereUIExtend.CreateProfile("Theme profile"); picker.set("runic")
ChangeLayout(controls)
Check(old.rules[1].style.classIconStyle == nil and old.rules[1].style.classIconX == nil and api.GetSettings() ~= old,
    "profile switch invalidates all cog settings")
host:RefreshPage(); rows["Show class emblem"].set(true)
rule = api.GetRules()[1]; picker = rows["Class emblem settings"].rows[1]
picker.set("modern")
host.CLASS_ICON_SPRITE_COORDS = nil
Check(picker.itemDisabled("pixel"), "unsupported theme entries explain host requirement")
picker.set("pixel")
Check(rule.style.classIconStyle == "modern", "host capability loss blocks stale dropdown write")
api.Refresh(); f.Flush()
f.GetPreview().Update()
Check(f.GetPreview().classIcon._classIcon:GetTexture():find("UI-CHARACTERCREATE-CLASSES", 1, true), "unavailable saved theme previews Blizzard fallback")
local codeUnavailable = assert(api.ExportRuleSet())
Check(api.ImportRuleSet(codeUnavailable) and api.GetRules()[1].style.classIconStyle == "modern", "unavailable known styles share without erasure")
host.CLASS_ICON_SPRITE_COORDS = { MAGE = { 0.125, 0.25, 0, 0.125 } }
host:RefreshPage(); rule = api.GetRules()[1]
local buildCog = host.BuildInlineCog
host.BuildInlineCog = nil
rows["Class emblem style"] = nil
host:RefreshPage()
local fallback = assert(rows["Class emblem style"])
Check(fallback.get() == "modern" and not fallback.disabled(), "older EUI exposes direct dropdown fallback")
for _, label in ipairs({ "Class emblem side", "Class emblem size", "Class emblem X offset", "Class emblem Y offset" }) do
    Check(rows[label] and not rows[label].disabled(), "older EUI retains geometry setting: " .. label)
end
fallback.set("arcade")
rows["Class emblem side"].set("right")
rows["Class emblem size"].set(36)
rows["Class emblem X offset"].set(12)
rows["Class emblem Y offset"].set(-7)
Check(rule.style.classIconStyle == "arcade", "fallback selection updates saved appearance")
Check(OriginalLayout(rule), "older-EUI fallback saves all geometry settings")
local staleFallback = fallback.set
local staleFallbackControls = {}
for _, label in ipairs({ "Class emblem side", "Class emblem size", "Class emblem X offset", "Class emblem Y offset" }) do
    staleFallbackControls[label] = rows[label]
end
EllesmereUIExtend.CreateProfile("Fallback profile"); staleFallback("pixel")
ChangeLayout(staleFallbackControls)
Check(rule.style.classIconStyle == "arcade" and OriginalLayout(rule), "older-EUI fallback blocks all stale profile callbacks")
host.BuildInlineCog = buildCog
host:RefreshPage(); rule = api.GetRules()[1]
local serializer = host._Serializer
for _, bad in ipairs({ "../modern", "dark", "unknown", 1, true, {} }) do
    rule.style.classIconStyle = bad
    local result, reason = api.ExportRuleSet()
    Check(not result and reason:find("classIconStyle", 1, true), "invalid theme export rejected")
end
rule.style.classIconStyle = nil
code = assert(api.ExportRuleSet())
local payload = serializer.Deserialize(code:sub(18))
payload.rules[1].style.classIconStyle = "unknown"
local before = api.GetRules()
Check(not api.ImportRuleSet("!EUI_NPEX_RULES2!" .. serializer.Serialize(payload)) and api.GetRules() == before, "bad theme import rejected atomically")
payload.rules[1].style.classIconStyle = nil
Check(api.ImportRuleSet("!EUI_NPEX_RULES2!" .. serializer.Serialize(payload)) and api.GetRules()[1].style.classIconStyle == nil,
    "older codes keep implicit Blizzard default without migration")
print("PASS: " .. checks .. " class-theme cog, live previews, sharing, capability gates, locks and older-EUI fallback")
