-- Run from the repository root with Lua or fengari. No upstream dependency.
-- Sentinels catch unsafe arithmetic, not Retail's secret-value VM restrictions.
local secret = setmetatable({}, {
    __mul = function() error("secret arithmetic") end,
    __eq = function() error("secret comparison") end,
    __tostring = function() error("secret formatting") end,
})
function issecretvalue(value) return rawequal(value, secret) end
function hooksecurefunc(object, method, callback)
    local original = assert(object[method])
    object[method] = function(...) original(...); callback(...) end
end
EllesmereUIExtendNameplates = {}
local addon = { ResolveBarTexturePath = function() return nil end }
assert(loadfile("Nameplates/CastStyles.lua"))("EllesmereUIExtendNameplates", addon)
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Near(actual, expected, label)
    Check(type(actual) == "number" and math.abs(actual - expected) < 0.00001, label)
end
local style = { castEnabled = true, castOpacityEnabled = true, castOpacity = 50 }
local function Apply(plate, selected) addon.ApplyCastStyle(plate, selected, nil, {}) end
local function Fresh(alpha, mode)
    local cast = { alpha = alpha, writes = 0, mode = mode }
    function cast:GetStatusBarTexture() return nil end
    function cast:GetAlpha()
        if self.mode == "throw" then error("restricted alpha getter") end
        if self.mode == "secret" then return secret end
        if self.mode == "invalid" then return false end
        return self.alpha
    end
    function cast:SetAlpha(value)
        if self.reject then error("restricted alpha setter") end
        self.writes = self.writes + 1
        self.alpha = value -- Native sink may accept secret values.
    end
    return { cast = cast }
end

for _, mode in ipairs({ "secret", "throw", "invalid", "missing" }) do
    local plate = Fresh(0.8, mode)
    local cast = plate.cast
    local getter = cast.GetAlpha
    if mode == "missing" then cast.GetAlpha = nil end
    Apply(plate, style)
    Check(cast.writes == 0, mode .. " initial getter cannot authorize writes")
    cast:SetAlpha(0.6)
    Near(cast.alpha, 0.6, mode .. " getter cannot authorize multiplying native argument")
    Apply(plate, style)
    Near(cast.alpha, 0.6, mode .. " refresh remains suspended")
    cast.GetAlpha, cast.mode = getter, nil
    Apply(plate, style)
    Near(cast.alpha, 0.3, mode .. " readable getter resumes")
    Apply(plate, nil)
    Near(cast.alpha, 0.6, mode .. " latest native base restored")
end

do
    local plate = Fresh(secret)
    local cast = plate.cast
    Apply(plate, style)
    Check(cast.writes == 0, "initial secret base is not multiplied or replaced")
    cast:SetAlpha(0.8)
    Near(cast.alpha, 0.4, "readable native write resumes from initial secret")
    Apply(plate, style); Apply(plate, style)
    Near(cast.alpha, 0.4, "refresh never captures multiplied paint")
    cast:SetAlpha(secret)
    Check(rawequal(cast.alpha, secret), "latest secret native write remains untouched")
    local writes = cast.writes
    Apply(plate, style); Apply(plate, nil); Apply(plate, style)
    Check(cast.writes == writes and rawequal(cast.alpha, secret),
        "refresh, disable and reuse never restore stale readable base over secret")
    -- Native state can become readable without another hooked write.
    cast.alpha = 0.6
    Apply(plate, style)
    Near(cast.alpha, 0.3, "readable getter resumes after native secret state")
    cast:SetAlpha(0.4)
    Near(cast.alpha, 0.2, "latest readable native animation is composed once")
    Apply(plate, nil)
    Near(cast.alpha, 0.4, "disable restores latest readable native base")
end

for _, mode in ipairs({ "secret", "throw", "invalid", "missing" }) do
    local plate = Fresh(0.8)
    local cast = plate.cast
    Apply(plate, style)
    local getter = cast.GetAlpha
    cast.mode = mode
    if mode == "missing" then cast.GetAlpha = nil end
    Apply(plate, style)
    Near(cast.alpha, 0.8, mode .. " getter releases owned multiplier")
    local writes = cast.writes
    Apply(plate, style); Apply(plate, nil)
    Check(cast.writes == writes, mode .. " unowned native state is left alone")
    cast.GetAlpha, cast.mode = getter, nil
    Apply(plate, style)
    Near(cast.alpha, 0.4, mode .. " getter recovery reapplies saved multiplier")
end

do
    local plate = Fresh(0.8)
    local cast = plate.cast
    cast.reject = true
    Apply(plate, style)
    Near(cast.alpha, 0.8, "throwing setter leaves native state intact")
    cast.reject = nil
    cast:SetAlpha(0.6)
    Near(cast.alpha, 0.3, "failed setter clears writing guard for next native write")
    cast.reject = true
    Apply(plate, nil)
    cast.reject = nil
    Apply(plate, nil)
    Near(cast.alpha, 0.6, "failed restoration is retried")
    Apply(plate, style)
    local setter = cast.SetAlpha
    cast.SetAlpha = nil
    Apply(plate, nil)
    cast.SetAlpha = setter
    cast:SetAlpha(0.4)
    Near(cast.alpha, 0.4, "missing setter clears guard and preserves next native base")
    Apply(plate, style); Apply(plate, nil)
    Near(cast.alpha, 0.4, "restoration after missing setter uses latest native state")
end

do
    local plate = Fresh(0.8)
    local cast = plate.cast
    local setter = cast.SetAlpha
    cast.SetAlpha = nil
    Apply(plate, style)
    Check(cast.writes == 0, "missing initial setter cannot own opacity")
    cast.SetAlpha = setter
    Apply(plate, style)
    Near(cast.alpha, 0.4, "available setter installs native-write observation")
    cast:SetAlpha(0.6)
    Near(cast.alpha, 0.3, "late setter hook tracks native writes")
    issecretvalue = nil -- Forever/readable fallback.
    style.castOpacity = 0
    Apply(plate, style)
    cast:SetAlpha(0.2)
    Near(cast.alpha, 0, "zero opacity captures native state without division")
    Apply(plate, nil)
    Near(cast.alpha, 0.2, "Forever disable restores latest zero-opacity base")
end
print("PASS: " .. checks .. " cast opacity secret-value checks")
