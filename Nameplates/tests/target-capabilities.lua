-- Run from the repository root with Lua or fengari; no upstream dependencies.
local addon = {}
assert(loadfile("Nameplates/Helpers.lua"))("EllesmereUIExtendNameplates", addon)
local checks = 0
local function Check(value, label)
    checks = checks + 1
    assert(value, label)
end

-- Opaque tokens simulate native inputs/outputs, not the Retail secret-value VM.
-- Lua cannot trap a truthiness test on a table: false-token results and native
-- call arguments below catch accidental Lua selection without claiming VM proof.
local secrets = {}
local function Secret(value)
    local token = setmetatable({}, {
        __eq = function() error("secret comparison") end,
        __lt = function() error("secret comparison") end,
        __add = function() error("secret arithmetic") end,
        __mul = function() error("secret arithmetic") end,
        __tostring = function() error("secret formatting") end,
    })
    secrets[token] = { value = value }
    return token
end
issecretvalue = function(value) return secrets[value] ~= nil end
-- Only native mocks and assertions may unwrap opaque tokens.
local function NativeValue(value)
    local wrapped = secrets[value]
    if wrapped then return wrapped.value end
    return value
end
local secretTrue, secretFalse = Secret(true), Secret(false)
local yes, no = { 0.9, 0.2, 0.3, 0.8 }, { 0.1, 0.6, 0.7, 0.4 }
local function NativeEvaluate(flag, on, off)
    local selected
    if NativeValue(flag) then selected = on else selected = off end
    if issecretvalue(flag) then return Secret(selected) end
    return selected
end
local function Frame(booleanSink)
    local frame = { alpha = 0.75, writes = {}, booleanCalls = 0 }
    function frame:SetAlpha(alpha)
        self.writes[#self.writes + 1] = alpha
        self.alpha = alpha
    end
    if booleanSink then
        function frame:SetAlphaFromBoolean(flag, on, off)
            self.booleanCalls = self.booleanCalls + 1
            self.lastFlag, self.lastOn, self.lastOff = flag, on, off
            self.alpha = NativeEvaluate(flag, on, off)
        end
    end
    return frame
end
local function Color(flag, palette, label, secret)
    local ok, r, g, b, a = addon.SelectTargetColor(flag, yes, no)
    Check(ok, label .. " selects a color")
    for index, value in ipairs({ r, g, b, a }) do
        Check(NativeValue(value) == palette[index], label .. " component " .. index)
        if secret then Check(issecretvalue(value), label .. " preserves secret component " .. index) end
    end
end
local function NoColor(flag, label)
    local ok, r, g, b, a = addon.SelectTargetColor(flag, yes, no)
    Check(ok == false and r == nil and g == nil and b == nil and a == nil,
        label .. " exposes no partial palette")
end
local function Alpha(frame, flag, expected, value, status, label)
    local ok, actualStatus = addon.SetTargetAlpha(frame, flag, expected)
    Check(ok and actualStatus == status, label .. " capability")
    Check(NativeValue(frame.alpha) == value, label .. " alpha")
end
local function FailedAlpha(frame, flag, label)
    local ok, status = addon.SetTargetAlpha(frame, flag, true)
    Check(ok == false and status == "no usable alpha sink", label .. " fails closed")
    Check(frame.writes[#frame.writes] == 0, label .. " attempts final zero")
end

-- No curves: native boolean alpha is useful even though secret colors cannot be
-- selected. Test both truth values and inversion; do not unify these tiers.
C_CurveUtil = nil
for _, flag in ipairs({ secretTrue, secretFalse }) do
    NoColor(flag, "secret without curves")
    for _, expected in ipairs({ true, false }) do
        local frame = Frame(true)
        local value = NativeValue(flag) == expected and 1 or 0
        Alpha(frame, flag, expected, value, "native boolean alpha", "independent boolean sink")
        Check(rawequal(frame.lastFlag, flag), "boolean sink receives original secret flag")
        Check(frame.lastOn == (expected and 1 or 0) and frame.lastOff == (expected and 0 or 1),
            "boolean sink receives authored inverse alternatives")
        Check(#frame.writes == 0 and issecretvalue(frame.alpha), "secret boolean is not selected in Lua")
    end
end
for _, flag in ipairs({ true, false }) do
    Color(flag, flag and yes or no, "readable without curves")
    for _, expected in ipairs({ true, false }) do
        Alpha(Frame(false), flag, expected, flag == expected and 1 or 0,
            "readable alpha fallback", "readable inversion")
    end
end
local frame = Frame(false)
FailedAlpha(frame, secretFalse, "secret without any native sink")
Check(frame.alpha == 0, "failed secret gate clears stale visibility")

-- Native curves retain secret components through selection and the alpha sink.
C_CurveUtil = { EvaluateColorValueFromBoolean = NativeEvaluate }
for _, flag in ipairs({ secretTrue, secretFalse }) do
    Color(flag, NativeValue(flag) and yes or no, "secret curve", true)
    for _, expected in ipairs({ true, false }) do
        frame = Frame(true)
        Alpha(frame, flag, expected, NativeValue(flag) == expected and 1 or 0,
            "native curve alpha", "curve inversion")
        Check(frame.booleanCalls == 0 and issecretvalue(frame.writes[1]),
            "curve alpha goes directly to native setter before boolean fallback")
    end
end

-- A throwing curve falls back to readable color selection; secret flags still
-- need a native sink. Alpha independently retries boolean/readable sinks.
C_CurveUtil.EvaluateColorValueFromBoolean = function() error("restricted evaluator") end
for _, flag in ipairs({ true, false }) do
    Color(flag, flag and yes or no, "throwing curve with readable flag")
    Alpha(Frame(false), flag, false, flag and 0 or 1,
        "readable alpha fallback", "throwing curve readable recovery")
end
NoColor(secretFalse, "throwing curve with secret flag")
for badIndex = 2, 4 do
    for _, flag in ipairs({ true, false, secretTrue, secretFalse }) do
        local calls = 0
        C_CurveUtil.EvaluateColorValueFromBoolean = function(value, on, off)
            calls = calls + 1
            if calls == badIndex then error("later component restricted") end
            return NativeEvaluate(value, on, off)
        end
        if issecretvalue(flag) then
            NoColor(flag, "later throwing component with secret flag")
        else
            Color(flag, flag and yes or no, "later throwing component with readable flag")
        end
        Check(calls == badIndex, "throwing color evaluation stops immediately")
    end
end
C_CurveUtil.EvaluateColorValueFromBoolean = function() error("restricted evaluator") end
Alpha(Frame(true), secretFalse, false, 1, "native boolean alpha", "throwing curve native recovery")
frame = Frame(false)
FailedAlpha(frame, secretFalse, "throwing curve without secret sink")
Check(frame.alpha == 0, "throwing curve failure clears stale alpha")

-- Invalid component types must never escape to a color/alpha setter. Fail on
-- each RGBA position to check that a partial palette is never exposed.
local invalid = { { value = nil }, { value = false }, { value = "1" }, { value = {} } }
for _, entry in ipairs(invalid) do
    for badIndex = 1, 4 do
        for _, flag in ipairs({ true, false, secretTrue, secretFalse }) do
            local calls = 0
            C_CurveUtil.EvaluateColorValueFromBoolean = function(value, on, off)
                calls = calls + 1
                if calls == badIndex then return entry.value end
                return NativeEvaluate(value, on, off)
            end
            if issecretvalue(flag) then
                NoColor(flag, "invalid evaluator component " .. badIndex)
            else
                Color(flag, flag and yes or no, "invalid curve readable recovery " .. badIndex)
            end
            Check(calls == badIndex, "invalid color evaluation stops immediately")
        end
    end
    C_CurveUtil.EvaluateColorValueFromBoolean = function() return entry.value end
    frame = Frame(true)
    Alpha(frame, secretFalse, false, 1, "native boolean alpha", "invalid curve native fallback")
    Check(#frame.writes == 0, "invalid evaluated alpha is not written")
    Alpha(Frame(false), false, false, 1, "readable alpha fallback", "invalid curve readable fallback")
    frame = Frame(false)
    FailedAlpha(frame, secretFalse, "invalid curve without secret fallback")
    Check(frame.alpha == 0, "invalid evaluated alpha clears stale visibility")
end

-- A throwing SetAlpha may already have written. Continue to other native sinks
-- without inspecting the resulting alpha, or clear to zero when all fail.
C_CurveUtil.EvaluateColorValueFromBoolean = NativeEvaluate
frame = Frame(true)
local setAlpha = frame.SetAlpha
frame.SetAlpha = function(self, alpha)
    setAlpha(self, alpha)
    if issecretvalue(alpha) then error("restricted alpha setter") end
end
Alpha(frame, secretFalse, false, 1, "native boolean alpha", "curve setter failure recovery")
Check(#frame.writes == 1 and frame.booleanCalls == 1, "throwing curve setter retries boolean sink")
Color(secretFalse, no, "alpha setter failure does not disable colors", true)

frame = Frame(true)
frame.SetAlphaFromBoolean = function(self)
    self.booleanCalls = self.booleanCalls + 1
    self.alpha = 0.9
    error("partially written boolean setter")
end
C_CurveUtil = nil
Alpha(frame, false, false, 1, "readable alpha fallback", "boolean setter readable recovery")
Check(frame.booleanCalls == 1, "throwing boolean setter was attempted")
FailedAlpha(frame, secretFalse, "partially written boolean setter")
Check(frame.alpha == 0, "failed boolean setter is forcibly zeroed")

C_CurveUtil = { EvaluateColorValueFromBoolean = NativeEvaluate }
frame = Frame(true)
frame.SetAlpha = function(self, alpha)
    setAlpha(self, alpha)
    if issecretvalue(alpha) then error("restricted alpha setter") end
end
frame.SetAlphaFromBoolean = function(self)
    self.alpha = 0.9
    error("restricted boolean setter")
end
FailedAlpha(frame, secretFalse, "both native setters throw")
Check(frame.alpha == 0 and #frame.writes == 2, "partial native writes end with zero")

-- Even the emergency clear can throw: return failure without leaking an error.
frame = Frame(false)
frame.SetAlpha = function(self, alpha)
    self.writes[#self.writes + 1] = alpha
    error("all alpha writes forbidden")
end
FailedAlpha(frame, secretFalse, "zero setter also throws")
Check(#frame.writes == 2, "failed native write still attempts emergency zero")

-- Forever-style absence of the secret API retains readable behavior.
issecretvalue, C_CurveUtil = nil, nil
Color(false, no, "Forever readable color")
Alpha(Frame(false), false, false, 1, "readable alpha fallback", "Forever readable alpha")
for _, entry in ipairs(invalid) do
    -- false is a valid flag, unlike the other malformed evaluator results above.
    if type(entry.value) ~= "boolean" then
        NoColor(entry.value, "unavailable/malformed flag without curves")
        frame = Frame(false)
        FailedAlpha(frame, entry.value, "unavailable/malformed flag without native sink")
        Check(frame.alpha == 0, "malformed flag clears stale alpha")
    end
end
print("PASS: " .. checks .. " independent target color/alpha capability checks")
