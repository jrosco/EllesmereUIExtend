-- Run from the repository root with Lua or fengari; no upstream dependencies.
local addon = {}
assert(loadfile("Nameplates/Helpers.lua"))("EllesmereUIExtendNameplates", addon)
local checks = 0
local function Check(value, label)
    checks = checks + 1
    assert(value, label)
end

issecretvalue = nil
Check(not addon.IsSecret(5), "Forever works without a secret-value API")
Check(addon.ClampNumber(5, 3, 1, 10) == 5, "readable number is unchanged")
Check(addon.ClampNumber(-5, 3, 1, 10) == 1, "lower bound")
Check(addon.ClampNumber(15, 3, 1, 10) == 10, "upper bound")
Check(addon.ClampNumber(math.huge, 3, 1, 10) == 10, "infinity retains existing clamp behavior")
for _, value in ipairs({ false, "5", {}, 0 / 0 }) do
    Check(addon.ClampNumber(value, 3, 1, 10) == 3, "invalid number uses fallback")
end
Check(addon.ClampNumber(nil, 3, 1, 10) == 3, "missing number uses fallback")
local secret = setmetatable({}, {
    __eq = function() error("secret comparison") end,
    __lt = function() error("secret comparison") end,
})
issecretvalue = function(value) return rawequal(value, secret) end
Check(addon.IsSecret(secret), "secret checker is detected after helper loading")
Check(addon.ClampNumber(secret, 3, 1, 10) == 3, "secret number is rejected before comparisons")
issecretvalue = nil

local predicate = function() return true end
local source = { conditions = { custom = { nested = { value = 7 } } },
    style = { textColors = { name = { r = 1, g = 0, b = 0 } } }, predicate = predicate }
local copy = addon.CopyTable(source)
Check(copy ~= source and copy.conditions ~= source.conditions, "rule tables are independent")
Check(copy.conditions.custom.nested ~= source.conditions.custom.nested, "deep custom conditions are independent")
Check(copy.style.textColors.name ~= source.style.textColors.name, "nested colors are independent")
copy.conditions.custom.nested.value = 8
copy.style.textColors.name.r = 0
Check(source.conditions.custom.nested.value == 7 and source.style.textColors.name.r == 1, "copy edits preserve source")
Check(copy.predicate == predicate, "non-table values retain identity")
Check(addon.CopyTable(false) == false and addon.CopyTable(nil) == nil, "scalar copying")

local flat = "Interface\\Buttons\\WHITE8x8"
EllesmereUI, EllesmereNameplates_NS = nil, nil
Check(addon.ResolveBarTexturePath(nil) == nil and addon.ResolveBarTexturePath("eui") == nil, "native textures remain untouched")
Check(addon.ResolveBarTexturePath("flat") == flat, "flat texture needs no EUI API")
Check(addon.ResolveBarTexturePath("missing") == flat, "missing EUI uses fallback")
local calls = 0
EllesmereUI = { ResolveTexturePath = function(paths, key, fallback)
    calls = calls + 1
    Check(paths == EllesmereNameplates_NS.healthBarTextures and fallback == flat, "shared resolver arguments")
    return paths[key] or fallback
end }
Check(addon.ResolveBarTexturePath("custom") == flat and calls == 0, "missing native texture table is gated")
EllesmereNameplates_NS = { healthBarTextures = { custom = "custom-path", ["sm:Pack"] = "media-path" } }
Check(addon.ResolveBarTexturePath("custom") == "custom-path", "native texture keys")
Check(addon.ResolveBarTexturePath("sm:Pack") == "media-path", "SharedMedia keys")
Check(addon.ResolveBarTexturePath("unknown") == flat, "unknown texture fallback")
Check(calls == 3, "configured textures delegate to EUI")
EllesmereUI.ResolveTexturePath = nil
Check(addon.ResolveBarTexturePath("custom") == flat, "older EUI without resolver preserves fallback")
print("PASS: " .. checks .. " private helper, secret-check gating, deep copying and texture fallback checks")
