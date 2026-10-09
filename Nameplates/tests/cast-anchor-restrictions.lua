-- Run from the repository root with Lua or fengari. No upstream dependency.
unpack = unpack or table.unpack
local secret = setmetatable({}, {
    __eq = function() error("secret comparison") end,
    __lt = function() error("secret ordering") end,
    __index = function() error("secret indexing") end,
})
function issecretvalue(value) return rawequal(value, secret) end
function hooksecurefunc(object, method, callback)
    local original = assert(object[method])
    object[method] = function(...) original(...); callback(...) end
end
EllesmereUIExtendNameplates = {}
EllesmereNameplates_NS = {}
function EllesmereNameplates_NS.ApplyCastBarTexture(plate, path)
    plate.cast:SetStatusBarTexture(path)
    plate.castBarOverlay:SetTexture(path)
    if plate.engineReanchors then plate.castSpark.points[1][2] = plate.cast.fill end
end
local addon = { ResolveBarTexturePath = function(path) return path end }
assert(loadfile("Nameplates/CastStyles.lua"))("EllesmereUIExtendNameplates", addon)
local function Texture(path)
    local t = { path = path, color = { 0.2, 0.3, 0.4, 1 } }
    function t:GetTexture() return self.path end
    function t:SetTexture(value) self.path = value end
    function t:GetVertexColor() return unpack(self.color) end
    function t:SetVertexColor(...) self.color = { ... } end
    function t:SetAllPoints(fill) self.allPoints = fill end
    return t
end
local function Fresh()
    local cast = { fill = Texture("engine"), alpha = 1, parent = {} }
    function cast:GetStatusBarTexture() return self.fill end
    function cast:SetStatusBarTexture(path) self.fill = Texture(path) end
    function cast:GetAlpha() return self.alpha end
    function cast:SetAlpha(alpha) self.alpha = alpha end
    local spark = { points = {}, writes = 0, clears = 0, reads = 0 }
    function spark:GetNumPoints()
        if self.countThrows then error("restricted count") end
        if self.countSecret then return secret end
        return self.countOverride or #self.points
    end
    function spark:GetPoint(i)
        self.reads = self.reads + 1
        if self.pointThrows == i then error("restricted point") end
        local a = self.points[i]
        local values = { unpack(a, 1, 5) }
        if self.secretIndex and (not self.secretPoint or self.secretPoint == i) then
            values[self.secretIndex] = secret
        end
        return unpack(values, 1, 5)
    end
    function spark:ClearAllPoints() self.clears = self.clears + 1; self.points = {} end
    function spark:SetPoint(point, relative, relativePoint, x, y)
        if self.setterThrows then error("restricted setter") end
        self.writes = self.writes + 1
        for i, a in ipairs(self.points) do
            if a[1] == point then self.points[i] = { point, relative, relativePoint, x, y }; return end
        end
        self.points[#self.points + 1] = { point, relative, relativePoint, x, y }
    end
    spark.points = { { "CENTER", cast.fill, "RIGHT", 0, 3 } }
    local plate = { cast = cast, castSpark = spark, castBarOverlay = Texture("overlay"), _castLift = {} }
    return plate, spark, cast.fill
end
local style = { castEnabled = true, castTexture = "custom" }
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Apply(plate, selected) addon.ApplyCastStyle(plate, selected, nil, {}) end
local function Follows(plate, spark, label)
    Check(spark.points[1][2] == plate.cast.fill, label .. " follows fill")
    Check(spark.points[1][4] == 0 and spark.points[1][5] == 3, label .. " preserves offsets")
    Check(spark.clears == 0, label .. " never clears anchors")
end
do
    local plate, spark = Fresh()
    local parent, lift = plate.cast.parent, plate._castLift
    local unrelated = {}
    spark.points[2] = { "TOP", unrelated, "BOTTOM", 4, -7 }
    Apply(plate, style); Follows(plate, spark, "replacement")
    Check(plate.castBarOverlay.allPoints == plate.cast.fill, "overlay follows replacement")
    Check(spark.points[2][2] == unrelated and spark.points[2][5] == -7, "unrelated anchor untouched")
    Apply(plate, nil); Follows(plate, spark, "restoration")
    Check(plate.cast.fill.path == "engine", "original engine texture restored")
    Apply(plate, style)
    plate.engineReanchors = true
    EllesmereNameplates_NS.ApplyCastBarTexture(plate, "latest-engine")
    Follows(plate, spark, "engine replacement under override")
    Apply(plate, nil); Follows(plate, spark, "latest restoration")
    Check(plate.cast.fill.path == "latest-engine", "latest engine texture restored")
    Check(plate.cast.parent == parent and plate._castLift == lift, "hierarchy and lifting untouched")
    plate._interrupted = true
    Apply(plate, style); Follows(plate, spark, "interrupted replacement")
    Check(plate._interrupted == true, "interrupted flag untouched")
    Apply(plate, nil)
    EllesmereNameplates_NS.ApplyCastBarTexture(plate, "recycled-engine")
    Apply(plate, style); Apply(plate, nil); Follows(plate, spark, "recycle")
    Check(plate.cast.fill.path == "recycled-engine", "recycled texture restored")
end
for _, count in ipairs({ -1, 1.5, math.huge, "unknown" }) do
    local plate, spark = Fresh()
    spark.countOverride = count
    Apply(plate, style)
    Check(spark.reads == 0 and spark.writes == 0 and spark.clears == 0,
        "invalid count defers without reading or clearing")
    spark.countOverride = nil
    Apply(plate, style); Follows(plate, spark, "invalid count recovery")
end
do
    local plate, spark = Fresh()
    local getter = spark.GetPoint
    spark.GetPoint = nil
    Apply(plate, style)
    Check(spark.writes == 0 and spark.clears == 0, "missing method defers")
    spark.GetPoint = getter
    Apply(plate, style); Follows(plate, spark, "method recovery")
end
local failures = {
    { "throwing count", function(s) s.countThrows = true end, function(s) s.countThrows = nil end },
    { "secret count", function(s) s.countSecret = true end, function(s) s.countSecret = nil end },
    { "throwing later point", function(s) s.pointThrows = 2 end, function(s) s.pointThrows = nil end },
    { "restricted setter", function(s) s.setterThrows = true end, function(s) s.setterThrows = nil end },
}
for i = 1, 5 do
    failures[#failures + 1] = { "secret component " .. i,
        function(s) s.secretIndex = i; s.secretPoint = 2 end,
        function(s) s.secretIndex = nil end }
end
for _, case in ipairs(failures) do
    local plate, spark, original = Fresh()
    spark.points[2] = { "TOP", original, "RIGHT", 1, 2 }
    case[2](spark)
    Apply(plate, style)
    Check(spark.writes == 0 and spark.clears == 0, case[1] .. " preserves all anchors")
    Check(spark.points[1][2] == original, case[1] .. " keeps native relative")
    Check(plate.cast.fill.path == "custom", case[1] .. " does not interrupt texture styling")
    if spark.countSecret then Check(spark.reads == 0, "secret count never drives GetPoint") end
    -- Even another fill swap while restricted must retain the old relative for retry.
    Apply(plate, nil)
    case[3](spark)
    Apply(plate, nil); Follows(plate, spark, case[1] .. " retry on unchanged fill")
    Check(spark.points[2][2] == plate.cast.fill, case[1] .. " retries all affected points")
end
for _, result in ipairs({ true, secret, "throw" }) do
    local plate, spark = Fresh()
    function spark:IsAnchoringRestricted()
        if result == "throw" then error("restricted probe") end
        return result
    end
    Apply(plate, style)
    Check(spark.reads == 0 and spark.writes == 0, "restricted/secret/failing probe defers")
    function spark:IsAnchoringRestricted() return false end
    Apply(plate, style); Follows(plate, spark, "restriction cleared")
end
do
    local plate, spark, original = Fresh()
    spark.countThrows = true
    Apply(plate, style)
    local native = {}
    spark.points[1] = { "CENTER", native, "LEFT", 9, -4 }
    spark.countThrows = nil
    Apply(plate, nil)
    Check(spark.points[1][2] == native and spark.points[1][5] == -4,
        "retry uses latest native anchors, not a saved snapshot")
    Check(spark.writes == 0 and spark.clears == 0, "unrelated native rewrite untouched")
    Check(original ~= plate.cast.fill, "fill really changed")
end
do
    local plate, spark, original = Fresh()
    plate._blizzCastArt = true
    Apply(plate, style)
    Check(plate.cast.fill == original and spark.writes == 0, "stock artwork keeps texture ownership")
end
do
    local plate, spark = Fresh()
    issecretvalue = nil -- Forever/missing optional API and restriction method.
    Apply(plate, style); Follows(plate, spark, "Forever replacement")
    Apply(plate, nil); Follows(plate, spark, "Forever restoration")
end
print("PASS: " .. checks .. " cast anchor restriction, retry, restoration and ownership checks")
