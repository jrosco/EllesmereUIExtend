local f = assert(loadfile("Nameplates/tests/runtime.lua"))("traits")
local addon, api, plate = f.namespace, f.api, f.plate
assert(addon.ToggleTargetLayerPrototype == nil and addon.GetTargetLayerPrototype == nil,
    "normal runtime fixture does not load the development-only prototype")
-- The general fixture's health getter returns a path-only table each call.
-- Model a real, stable StatusBar texture region for anchor/replacement checks.
local healthFill = plate.health:CreateTexture()
healthFill:SetTexture(plate.health.texture)
plate.health.GetStatusBarTexture = function() return healthFill end
local border = assert(loadfile("Nameplates/tests/border-mocks.lua"))()
for key, value in pairs(border) do EllesmereUI[key] = value end
GameFontNormal = CreateFrame("FontString")
GameFontNormal:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
local originalCreate = CreateFrame
local blocked, missingTexture = false, false
CreateFrame = function(...)
    local frame = originalCreate(...)
    local set = frame.SetTexture
    frame.SetTexture = function(self, path)
        if missingTexture then return false end
        set(self, path); return true
    end
    local points = frame.SetAllPoints
    frame.SetAllPoints = function(self, target)
        if blocked then error("forbidden layout aspect") end
        points(self, target)
    end
    return frame
end
assert(loadfile("Nameplates/TargetLayers.lua"))("EllesmereUIExtendNameplates", addon)
local target, throws = true, false
PlayerIsSpellTarget = function(unit)
    assert(unit == plate.unit)
    if throws then error("restricted spell-target getter") end
    return target
end
C_CurveUtil = { EvaluateColorValueFromBoolean = function(flag, yes, no)
    if flag == f.secret then return f.secret end
    return flag and yes or no
end }
local function Tick()
    for _, frame in ipairs(f.frames) do
        if frame:IsShown() and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.11) end
    end
end
local nativeTexture, nativeAlpha = plate.health:GetStatusBarTexture():GetTexture(), plate.health:GetAlpha()
local castTexture = plate.cast:GetStatusBarTexture():GetTexture()
local ok, status = addon.StartTargetLayerPrototype(plate)
assert(ok and status:find("ignores rule filters", 1, true))
local session = assert(addon.GetTargetLayerPrototype())
assert(#session.layers == 6 and #session.failures == 0, "six independent demo layers")
local first = session.layers[1].frame
for _, entry in ipairs(session.layers) do
    assert(entry.frame:GetAlpha() == 1 and entry.frame.mouseEnabled == false)
    if entry.fill then assert(entry.frame._prototypeTexture.allPoints == entry.fill, "fill follows native progress, not measured geometry") end
end
target = false; Tick()
for _, entry in ipairs(session.layers) do assert(entry.frame:GetAlpha() == 0) end
target = f.secret; Tick()
for _, entry in ipairs(session.layers) do assert(entry.frame:GetAlpha() == f.secret, "secret target stays in native alpha sink") end
target = true; plate._interrupted = true; Tick()
for _, entry in ipairs(session.layers) do assert(entry.frame:GetAlpha() == (entry.cast and 0 or 1), "native interrupted flash wins") end
plate._interrupted = f.secret; Tick()
for _, entry in ipairs(session.layers) do if entry.cast then assert(entry.frame:GetAlpha() == 0) end end
plate._interrupted = nil
throws = true; Tick()
for _, entry in ipairs(session.layers) do assert(entry.frame:GetAlpha() == 0, "unavailable target fails closed") end
throws = false
local curve = C_CurveUtil
C_CurveUtil = nil; target = f.secret; Tick()
for _, entry in ipairs(session.layers) do assert(entry.frame:GetAlpha() == f.secret, "direct native boolean-alpha fallback") end
C_CurveUtil = curve; target = true
local alpha, booleanAlpha = first.SetAlpha, first.SetAlphaFromBoolean
first.SetAlpha = function(self, value)
    if issecretvalue(value) then error("native secret-alpha sink rejected") end
    alpha(self, value)
end
first.SetAlphaFromBoolean = function() error("boolean-alpha sink rejected") end
target = f.secret; Tick()
assert(session.layers[1].failed and not first:IsShown() and first:GetAlpha() == 0,
    "rejected native alpha gates blank the layer without exposing targeting")
first.SetAlpha, first.SetAlphaFromBoolean = alpha, booleanAlpha
target = true
Tick()
assert(not first:IsShown() and first:GetAlpha() == 0, "failed layer stays quarantined until explicit restart")
assert(plate.health:GetStatusBarTexture():GetTexture() == nativeTexture and plate.health:GetAlpha() == nativeAlpha)
assert(plate.cast:GetStatusBarTexture():GetTexture() == castTexture, "prototype never changes native texture ownership")
local count = #f.frames
addon.ToggleTargetLayerPrototype(plate)
assert(not addon.GetTargetLayerPrototype())
for _, entry in ipairs(session.layers) do assert(not entry.frame:IsShown()) end
assert(addon.ToggleTargetLayerPrototype(plate))
assert(addon.GetTargetLayerPrototype().layers[1].frame == first and #f.frames == count, "repeated toggles reuse bounded layers")
local oldFill = plate.cast.fill
plate.cast.fill = plate.cast:CreateTexture(); Tick()
assert(not addon.GetTargetLayerPrototype(), "replaced native fill stops stale anchors")
plate.cast.fill = oldFill
assert(addon.ToggleTargetLayerPrototype(plate))
plate:ClearUnit(); assert(not addon.GetTargetLayerPrototype(), "pool release stops all layers immediately")
plate.unit = "nameplate2"
assert(addon.ToggleTargetLayerPrototype(plate))
plate:Show(); plate:Hide(); assert(not addon.GetTargetLayerPrototype(), "hidden plate tears down")
plate:Show()
assert(addon.ToggleTargetLayerPrototype(plate))
api.GetSettings().enabled = false; Tick()
assert(not addon.GetTargetLayerPrototype(), "master disable stops prototype")
api.GetSettings().enabled = true
assert(addon.ToggleTargetLayerPrototype(plate))
assert(api.CreateProfile("Prototype alternate")); Tick()
assert(not addon.GetTargetLayerPrototype(), "profile switch stops prototype")
blocked = true
ok, status = addon.ToggleTargetLayerPrototype(plate)
assert(not ok and not addon.GetTargetLayerPrototype(), "forbidden anchors do not show half-configured layers")
assert(status:find("forbidden layout aspect", 1, true), "setup diagnostics retain the actionable failure reason")
blocked = false; missingTexture = true
assert(addon.ToggleTargetLayerPrototype(plate))
session = addon.GetTargetLayerPrototype()
assert(#session.layers == 4 and #session.failures == 2, "missing texture disables only texture layers")
addon.StopTargetLayerPrototype(); missingTexture = false
local font = GameFontNormal; GameFontNormal = nil
assert(addon.ToggleTargetLayerPrototype(plate))
assert(#addon.GetTargetLayerPrototype().layers == 4, "missing font disables text without fabricating font assets")
addon.StopTargetLayerPrototype(); GameFontNormal = font
PlayerIsSpellTarget = nil
assert(not addon.ToggleTargetLayerPrototype(plate), "unsupported clients do not start prototype")
PlayerIsSpellTarget = function() return true end
assert(addon.StartTargetLayerPrototype(plate))
session = addon.GetTargetLayerPrototype()
local oldCast = plate.cast
plate.cast = CreateFrame("StatusBar"); Tick()
assert(not addon.GetTargetLayerPrototype(), "bar replacement invalidates every layer attached to it")
plate.cast = oldCast
assert(addon.StartTargetLayerPrototype(plate))
local lifted = plate._castOverlayLifted
plate._castOverlayLifted = not lifted; Tick()
assert(not addon.GetTargetLayerPrototype(), "cast lifting stops stale prototype strata")
plate._castOverlayLifted = lifted
assert(addon.StartTargetLayerPrototype(plate))
session = addon.GetTargetLayerPrototype()
for _, entry in ipairs(session.layers) do
    entry.frame.SetAlpha = function(self, value)
        if value ~= 0 then error("setter rejects nonzero alpha") end
        self.alpha = 0
    end
    entry.frame.SetAlphaFromBoolean = function() error("no boolean sink") end
end
Tick()
assert(not addon.GetTargetLayerPrototype(), "all failed layers stop polling")
for _, entry in ipairs(session.layers) do
    assert(not entry.frame:IsShown() and entry.frame:GetAlpha() == 0)
    entry.frame.SetAlpha, entry.frame.SetAlphaFromBoolean = alpha, booleanAlpha
end
assert(addon.ToggleTargetLayerPrototype(plate))
assert(addon.GetTargetLayerPrototype(), "manually loaded development prototype starts through its namespace")
addon.ToggleTargetLayerPrototype(plate)
assert(not addon.GetTargetLayerPrototype(), "namespace toggle stops the development prototype")
print("PASS: manually loaded development native texture/border/text layers, secrets, forbidden anchors, assets, bounded reuse, native ownership and lifecycle")
