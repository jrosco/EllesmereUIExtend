if EUI_CLIENT_BLOCKED then return end
local _, addon = ...
local api = EllesmereUIExtendNameplates
local Secret, Number = addon.IsSecret, addon.ClampNumber
local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
    DEATHKNIGHT = true, SHAMAN = true, MAGE = true, WARLOCK = true, MONK = true, DRUID = true,
    DEMONHUNTER = true, EVOKER = true }
local ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local ICON_STYLES = { blizzard = "Blizzard", modern = "Modern", pixel = "Pixel", pixelsComic = "Pixels Comic",
    glyph = "Glyph", arcade = "Arcade", legend = "Legend", midnight = "Midnight", runic = "Runic" }
local ICON_ORDER = { "blizzard", "modern", "pixel", "pixelsComic", "glyph", "arcade", "legend", "midnight", "runic" }
local icons = setmetatable({}, { __mode = "k" })

function api.SupportsClassColors()
    return type(UnitIsPlayer) == "function" and type(UnitClass) == "function"
end
function addon.GetPlayerClass(unit)
    if Secret(unit) or type(unit) ~= "string" or not api.SupportsClassColors() then return end
    local ok, player = pcall(UnitIsPlayer, unit)
    if not ok or Secret(player) or player ~= true then return end
    local valid, _, token = pcall(UnitClass, unit)
    if valid and not Secret(token) and type(token) == "string" and CLASSES[token] then return token end
end
function addon.GetClassColor(token)
    if Secret(token) or type(token) ~= "string" or not CLASSES[token] then return end
    local color
    if C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local ok, result = pcall(C_ClassColor.GetClassColor, token)
        if ok and not Secret(result) and type(result) == "table" then color = result end
    end
    color = color or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[token])
    if Secret(color) or type(color) ~= "table" then return end
    for _, key in ipairs({ "r", "g", "b" }) do
        local value = color[key]
        if Secret(value) or type(value) ~= "number" or value ~= value or value < 0 or value > 1 then return end
    end
    return color
end
function addon.GetPlayerClassColor(unit)
    return addon.GetClassColor(addon.GetPlayerClass(unit))
end
local function Coordinates(token, map)
    if Secret(token) or type(token) ~= "string" or not CLASSES[token] then return end
    if Secret(map) or type(map) ~= "table" then return end
    local coords = map[token]
    if Secret(coords) or type(coords) ~= "table" then return end
    for index = 1, 4 do
        local value = coords[index]
        if Secret(value) or type(value) ~= "number" or value ~= value or value < 0 or value > 1 then return end
    end
    return coords
end
function api.ValidateClassIconStyle(key)
    return not Secret(key) and (key == nil or (type(key) == "string" and ICON_STYLES[key] ~= nil))
end
local function ThemeSource(key)
    local host = addon.GetHost()
    local media = host and host.MEDIA_PATH
    if not host or Secret(media) or type(media) ~= "string" or media == "" then return end
    return media .. "icons\\class-full\\" .. key .. ".tga", host.CLASS_ICON_SPRITE_COORDS
end
function api.GetClassIconArtwork(key, token)
    if not api.ValidateClassIconStyle(key) then return end
    if key ~= nil and key ~= "blizzard" then
        local texture, map = ThemeSource(key)
        local coords = Coordinates(token, map)
        if texture and coords then return texture, coords end
    end
    local coords = Coordinates(token, CLASS_ICON_TCOORDS)
    if coords then return ICON_TEXTURE, coords end
end
function api.SupportsClassIconStyle(key)
    if not api.SupportsClassColors() or not api.ValidateClassIconStyle(key) then return false end
    local map = CLASS_ICON_TCOORDS
    if key ~= nil and key ~= "blizzard" then
        local texture
        texture, map = ThemeSource(key)
        if not texture then return false end
    end
    for token in pairs(CLASSES) do if Coordinates(token, map) then return true end end
    return false
end
function api.GetClassIconStyleOptions()
    local values, order = addon.CopyTable(ICON_STYLES), addon.CopyTable(ICON_ORDER)
    values._menuOpts = { itemHeight = 28, icon = function(key)
        if not api.SupportsClassIconStyle(key) then return end
        local texture, coords = api.GetClassIconArtwork(key, "MAGE")
        if coords then return texture, unpack(coords, 1, 4) end
    end }
    return values, order
end
function api.SupportsClassIcons()
    if not api.SupportsClassColors() then return false end
    for _, key in ipairs(ICON_ORDER) do if api.SupportsClassIconStyle(key) then return true end end
    return false
end
local function RenderIcon(host, anchor, style, token)
    local texture, coords
    if style and style.classIconEnabled == true then texture, coords = api.GetClassIconArtwork(style.classIconStyle, token) end
    if not coords then host:Hide(); return end
    local icon = host._classIcon
    if not icon then
        icon = host:CreateTexture(nil, "OVERLAY")
        host._classIcon = icon
        icon:SetAllPoints(host)
    end
    local ok, loaded = pcall(icon.SetTexture, icon, texture)
    if not ok or Secret(loaded) or loaded == false then
        if texture == ICON_TEXTURE then host:Hide(); return end
        texture, coords = api.GetClassIconArtwork("blizzard", token)
        if not coords then host:Hide(); return end
        ok, loaded = pcall(icon.SetTexture, icon, texture)
        if not ok or Secret(loaded) or loaded == false then host:Hide(); return end
    end
    icon:SetTexCoord(unpack(coords, 1, 4))
    local size = Number(style.classIconSize, 24, 12, 64)
    local x, y = Number(style.classIconX, 0, -200, 200), Number(style.classIconY, 0, -200, 200)
    local right = style.classIconSide == "right"
    host:SetSize(size, size)
    host:ClearAllPoints()
    host:SetPoint(right and "LEFT" or "RIGHT", anchor, right and "RIGHT" or "LEFT", x + (right and 6 or -6), y)
    host:Show()
end
function api.RenderClassIcon(host, anchor, style, token)
    -- Only addon-owned geometry is changed. Restrictions on a child/anchor
    -- must not interrupt EUI's paint or the rest of this rule's appearance.
    local ok = pcall(RenderIcon, host, anchor, style, token)
    if not ok then pcall(host.Hide, host) end
end
function addon.ApplyClassIcon(plate, style)
    local host = icons[plate]
    local token = style and style.classIconEnabled == true and addon.GetPlayerClass(plate.unit)
    local texture = style and api.GetClassIconArtwork(style.classIconStyle, token)
    if not texture then if host then host:Hide() end; return end
    if not host then
        host = CreateFrame("Frame", nil, plate)
        host:EnableMouse(false)
        icons[plate] = host
    end
    api.RenderClassIcon(host, plate.health, style, token)
end
function addon.GetClassIconFrame(plate) return icons[plate] end
