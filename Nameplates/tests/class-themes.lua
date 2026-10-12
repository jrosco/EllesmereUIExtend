-- Run from the repository root with Lua or fengari.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local api, addon, plate, host, checks = f.api, f.namespace, f.plate, EllesmereUI, 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local token = "MAGE"
UnitClass = function() return "Mage", token end
f.mocks.player = true
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 }, WARRIOR = { 0, 0.25, 0, 0.25 } }
host.MEDIA_PATH = "Interface\\AddOns\\EllesmereUI\\media\\"
host.CLASS_ICON_SPRITE_COORDS = { MAGE = { 0.125, 0.25, 0, 0.125 }, WARRIOR = { 0, 0.125, 0, 0.125 } }
local stock = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local style = { healthEnabled = false, classIconEnabled = true, classIconSize = 30, classIconSide = "right", classIconX = 10, classIconY = -3 }
api.GetSettings().rules = { { name = "Themes", enabled = true, conditions = {}, style = style } }
local function Refresh() api.Refresh(); f.Flush() end
Refresh()
local frame = assert(addon.GetClassIconFrame(plate))
local icon = frame._classIcon
Check(icon:GetTexture() == stock and icon.texCoord[1] == 0.25, "missing style retains original Blizzard artwork")
local values, order = api.GetClassIconStyleOptions()
Check(#order == 9 and values.pixelsComic == "Pixels Comic", "nine named artwork choices")
for _, key in ipairs(order) do
    Check(api.ValidateClassIconStyle(key) and api.SupportsClassIconStyle(key), "valid available theme: " .. key)
    style.classIconStyle = key; Refresh()
    local expected = key == "blizzard" and stock or host.MEDIA_PATH .. "icons\\class-full\\" .. key .. ".tga"
    Check(icon:GetTexture() == expected, "live texture selection: " .. key)
    Check(icon.texCoord[1] == (key == "blizzard" and 0.25 or 0.125), "correct sprite UVs: " .. key)
    Check(frame.width == 30 and frame.point[1] == "LEFT" and frame.point[4] == 16 and frame.point[5] == -3,
        "theme changes preserve size side offsets: " .. key)
    local thumbnail, left = values._menuOpts.icon(key)
    Check(thumbnail == expected and left == icon.texCoord[1], "menu thumbnail uses sample Mage: " .. key)
end
style.classIconStyle = "modern"
token = "WARRIOR"; Refresh()
Check(icon.texCoord[1] == 0, "recycled class uses new theme coordinates")
token = f.secret; Refresh()
Check(not frame:IsShown(), "secret identity never indexes themed map")
token = "MAGE"
f.mocks.player = false; Refresh()
Check(not frame:IsShown(), "NPCs cannot gain themed emblem")
f.mocks.player = true
local coords, media = host.CLASS_ICON_SPRITE_COORDS, host.MEDIA_PATH
host.CLASS_ICON_SPRITE_COORDS = nil; Refresh()
Check(icon:GetTexture() == stock and style.classIconStyle == "modern" and not api.SupportsClassIconStyle("modern"),
    "older host uses stock without erasing theme")
host.CLASS_ICON_SPRITE_COORDS = coords; host.MEDIA_PATH = nil; Refresh()
Check(icon:GetTexture() == stock and not api.SupportsClassIconStyle("modern"), "missing host media path uses stock")
host.MEDIA_PATH = f.secret; Refresh()
Check(icon:GetTexture() == stock, "secret media path is not concatenated")
host.MEDIA_PATH = media
coords.MAGE = nil; Refresh()
Check(icon:GetTexture() == stock and api.SupportsClassIconStyle("modern"), "missing class crop uses stock without disabling other supported classes")
coords.MAGE = { f.secret, 0.25, 0, 0.125 }; Refresh()
Check(icon:GetTexture() == stock, "secret sprite coordinates use stock")
coords.MAGE = { 0.125, 0.25, 0, 0.125 }
local setTexture = icon.SetTexture
icon.SetTexture = function(self, path)
    if path ~= stock then return false end
    return setTexture(self, path)
end
Refresh()
Check(icon:GetTexture() == stock and icon.texCoord[1] == 0.25 and frame:IsShown(), "failed theme texture falls back with stock UVs")
icon.SetTexture = function(self, path)
    if path ~= stock then error("missing theme file") end
    return setTexture(self, path)
end
Refresh()
Check(icon:GetTexture() == stock and frame:IsShown(), "throwing themed texture setter falls back")
icon.SetTexture = function(self, path)
    if path ~= stock then return f.secret end
    return setTexture(self, path)
end
Refresh()
Check(icon:GetTexture() == stock and frame:IsShown(), "unreadable texture-load result uses stock")
icon.SetTexture = function() return false end; Refresh()
Check(not frame:IsShown() and style.classIconStyle == "modern", "failed theme and fallback loads hide emblem without losing selection")
icon.SetTexture = setTexture; Refresh()
Check(icon:GetTexture():find("modern.tga", 1, true), "artwork recovers after temporary load failure")
CLASS_ICON_TCOORDS = nil; Refresh()
Check(frame:IsShown() and api.SupportsClassIcons(), "theme can render without Blizzard coordinate map")
host.CLASS_ICON_SPRITE_COORDS = nil; Refresh()
Check(not frame:IsShown() and not api.SupportsClassIcons(), "no readable artwork hides emblem")
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 } }
host.CLASS_ICON_SPRITE_COORDS = coords
local standalone = { MEDIA_PATH = "Interface\\AddOns\\EUIStandaloneNameplates\\media\\", CLASS_ICON_SPRITE_COORDS = coords }
EllesmereUI, EUICoreStandaloneNameplates = nil, standalone
issecretvalue = nil; Refresh()
Check(icon:GetTexture() == standalone.MEDIA_PATH .. "icons\\class-full\\modern.tga",
    "standalone routes to active host media without full-suite dependency; Forever needs no secret API")
standalone.CLASS_ICON_SPRITE_COORDS = nil; Refresh()
Check(icon:GetTexture() == stock and style.classIconStyle == "modern", "older standalone safely retains theme selection")
EllesmereUI, EUICoreStandaloneNameplates = host, nil
for _, bad in ipairs({ "../modern", "dark", "unknown", 1, true, {} }) do
    Check(not api.ValidateClassIconStyle(bad), "malformed or unsupported theme rejected")
end
style.classIconEnabled = false; Refresh()
Check(not frame:IsShown(), "disabling themed emblem releases decoration")
style.classIconEnabled = true; Refresh(); plate:ClearUnit()
Check(not frame:IsShown(), "pool release hides themed emblem")
print("PASS: " .. checks .. " class themes, artwork fallback, metadata restrictions, active-host media and lifecycle")
