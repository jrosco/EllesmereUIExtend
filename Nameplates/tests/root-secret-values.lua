-- Run from the repository root with Lua or fengari. Sentinels deliberately
-- fail arithmetic/order operations; they do not emulate Retail's secret VM.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local api, plate, np = f.api, f.plate, EllesmereNameplates_NS
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Near(actual, expected, label)
    Check(type(actual) == "number" and math.abs(actual - expected) < 0.00001,
        label .. ": expected " .. expected .. ", got " .. tostring(actual))
end
local secret = setmetatable({}, {
    __mul = function() error("secret arithmetic") end,
    __lt = function() error("secret comparison") end,
    __tostring = function() error("secret formatting") end,
})
local originalSecret = issecretvalue
function issecretvalue(value) return rawequal(value, secret) or originalSecret(value) end
local function Instrument(p)
    p.rootWrites = { Scale = 0, Alpha = 0 }
    for _, suffix in ipairs({ "Scale", "Alpha" }) do
        local key = suffix:lower()
        local originalSet = p["Set" .. suffix]
        p["Get" .. suffix] = function(self)
            local mode = self["get" .. suffix]
            if mode == "throw" then error("restricted root getter") end
            if mode == "secret" then return secret end
            if mode == "invalid" then return false end
            return self[key]
        end
        p["Set" .. suffix] = function(self, value)
            if self["reject" .. suffix] then error("restricted root setter") end
            self.rootWrites[suffix] = self.rootWrites[suffix] + 1
            originalSet(self, value)
        end
    end
end
Instrument(plate)
plate.health:SetParent(plate)
local initialSecret = CreateFrame()
initialSecret.unit, initialSecret.health = "nameplate2", CreateFrame()
initialSecret.health.color = { 1, 1, 1, 1 }
initialSecret.scale, initialSecret.alpha = secret, secret
Instrument(initialSecret)
local initialFailure = CreateFrame()
initialFailure.unit, initialFailure.health = "nameplate3", CreateFrame()
initialFailure.health.color = { 1, 1, 1, 1 }
Instrument(initialFailure)
initialFailure.getScale, initialFailure.getAlpha = "throw", "throw"
np.plates.nameplate2, np.plates.nameplate3 = initialSecret, initialFailure
EllesmereUIExtendDB = { profiles = { Default = { nameplates = { enabled = true, rules = {
    { name = "Root safety", conditions = {}, style = { scale = 150, opacity = 50,
        healthEnabled = false, scaleElements = { healthBar = false } } },
} } } } }
f.Fire("ADDON_LOADED", "EllesmereUIExtendNameplates")
local rule = api.GetRules()[1]
local function Refresh() api.Refresh(); f.Flush() end
Near(plate.scale, 1.5, "readable root multiplier")
Near(plate.health:GetScale(), 1 / 1.5, "unchecked category compensates root")
Near(plate.alpha, 0.5, "readable root opacity")
Check(initialSecret.rootWrites.Scale == 0 and initialSecret.rootWrites.Alpha == 0,
    "initial secrets must not authorize replacement writes")
Check(initialFailure.rootWrites.Scale == 0 and initialFailure.rootWrites.Alpha == 0,
    "throwing initial getters must not fabricate bases")
initialSecret:SetScale(1.1); initialSecret:SetAlpha(0.9)
f.Flush()
Near(initialSecret.scale, 1.65, "initial secret scale recovers on readable native write")
Near(initialSecret.alpha, 0.45, "initial secret alpha recovers on readable native write")

-- Secret engine arguments invalidate older readable bases. The hooks run
-- directly, outside ApplyStyle's pcall, and must not compare/multiply them.
plate:SetScale(secret)
plate:SetAlpha(secret)
Check(rawequal(plate.scale, secret) and rawequal(plate.alpha, secret), "native secret writes preserved")
Near(plate.health:GetScale(), 1, "secret root releases previous child compensation immediately")
Refresh()
rule.enabled = false; Refresh()
Check(rawequal(plate.scale, secret) and rawequal(plate.alpha, secret), "unmatched does not restore stale readable bases")
api.GetSettings().enabled = false; Refresh()
Check(rawequal(plate.scale, secret) and rawequal(plate.alpha, secret), "disable preserves latest secret bases")

plate:SetScale(1.2); plate:SetAlpha(0.8)
api.GetSettings().enabled, rule.enabled = true, true
Refresh()
Near(plate.scale, 1.8, "readable engine scale resumes styling")
Near(plate.alpha, 0.4, "readable engine alpha resumes styling")
Near(plate.health:GetScale(), 1 / 1.5, "child compensation resumes")
plate:SetScale(1.4); plate:SetAlpha(0.6)
Near(plate.scale, 2.1, "native scale animation multiplied exactly once")
Near(plate.alpha, 0.3, "latest native opacity composed exactly once")
Refresh(); Refresh()
Near(plate.scale, 2.1, "refresh cannot recapture plugin scale")
Near(plate.alpha, 0.3, "refresh cannot recapture plugin alpha")
rule.enabled = false; Refresh()
Near(plate.scale, 1.4, "unmatched restores latest native scale")
Near(plate.alpha, 0.6, "unmatched restores latest native alpha")

-- A getter can become restricted without any setter hook. Remove existing
-- paint using captured native values, but never multiply or compare the getter.
rule.enabled = true; Refresh()
plate.getScale, plate.getAlpha = "secret", "secret"
Refresh()
Near(plate.scale, 1.4, "secret getter removes owned scale adjustment")
Near(plate.alpha, 0.6, "secret getter removes owned alpha adjustment")
Near(plate.health:GetScale(), 1, "restricted root cannot retain compensation policy")
local scaleWrites, alphaWrites = plate.rootWrites.Scale, plate.rootWrites.Alpha
Refresh()
Check(plate.rootWrites.Scale == scaleWrites and plate.rootWrites.Alpha == alphaWrites,
    "unreadable getters with no owned paint leave native state alone")
plate.getScale, plate.getAlpha = "throw", "throw"
plate:SetScale(1.3); plate:SetAlpha(0.7)
Refresh()
Near(plate.scale, 1.3, "throwing getter does not interrupt native scale hook")
Near(plate.alpha, 0.7, "throwing getter does not interrupt native alpha hook")
plate.getScale, plate.getAlpha = "secret", "secret"
plate:SetScale(1.1); plate:SetAlpha(0.9)
Refresh()
Near(plate.scale, 1.1, "secret getter cannot authorize multiplying readable scale argument")
Near(plate.alpha, 0.9, "secret getter cannot authorize multiplying readable alpha argument")
plate.getScale, plate.getAlpha = "invalid", "invalid"
Refresh()
Near(plate.scale, 1.1, "invalid getter fails closed")
plate.getScale, plate.getAlpha = nil, nil
initialFailure.getScale, initialFailure.getAlpha = nil, nil
Refresh()
Near(initialFailure.scale, 1.5, "initial getter failure recovers from native getter")
Near(initialFailure.alpha, 0.5, "initial alpha failure recovers")

-- Failed addon writes must always clear reentrancy flags. A later native write
-- must replace the base rather than being mistaken for our own write.
plate.rejectScale, plate.rejectAlpha = true, true
rule.style.scale, rule.style.opacity = 175, 25
Refresh()
plate.rejectScale, plate.rejectAlpha = nil, nil
plate:SetScale(1.6); plate:SetAlpha(0.4)
f.Flush()
Near(plate.scale, 2.8, "scale setter failure clears writer guard")
Near(plate.alpha, 0.1, "alpha setter failure clears writer guard")
Near(plate.health:GetScale(), 1 / 1.75, "readable write resumes compensation after rejected setter")
rule.style.opacity = 0; Refresh()
plate:SetAlpha(0.2)
Near(plate.alpha, 0, "zero opacity still captures latest native alpha")
rule.enabled = false; Refresh()
Near(plate.alpha, 0.2, "zero opacity restores without division")

-- Readable release follows EUI's full-alpha pool contract even when its cached
-- setter is skipped. Secret writes are not replaced by that readable reset.
rule.enabled = true; rule.style.opacity = 50; Refresh()
plate._ntCurAlpha = nil
plate:ClearUnit()
Near(plate.scale, 1, "pool release restores native reset scale")
Near(plate.alpha, 1, "pool release clears plugin alpha if EUI skips setter")
plate.unit = "nameplate1"; Refresh()
Near(plate.alpha, 0.5, "recycled unit starts with native full alpha")
plate:SetAlpha(secret)
plate:ClearUnit()
Check(rawequal(plate.alpha, secret), "release does not fabricate a readable secret-alpha reset")
plate.unit = "nameplate1"
plate:SetAlpha(1); plate:SetScale(1)

-- Forever has no secret API. The five category combinations still follow the
-- existing selection contract (exhaustive effective-scale coverage: scaling.lua).
issecretvalue = nil
rule.style.scale, rule.style.opacity = 150, 50
for _, option in ipairs(api.ScaleElementOptions) do
    rule.style.scaleElements = { [option.key] = false }
    Refresh()
    Near(plate.scale, option.key == "other" and 1 or 1.5, "Forever category root: " .. option.key)
    Near(plate.health:GetScale(), option.key == "healthBar" and 1 / 1.5
        or (option.key == "other" and 1.5 or 1), "Forever health compensation: " .. option.key)
end
api.GetSettings().enabled = false; Refresh()
Near(plate.scale, 1, "Forever disable restores root")
Near(plate.alpha, 1, "Forever disable restores opacity")
print("PASS: " .. checks .. " root secret-value checks")
