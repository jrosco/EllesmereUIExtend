-- Run from the repository root; standalone, no upstream fixture required.
-- Structure fixture: Retail 12.1.0 (69933), wow-ui-source 09b9db7948abc9b9648dedaab51eb0cf3ee67b31.
local unpack = table.unpack or unpack
local ns, checks, pending, updates = {}, 0, {}, 0
local secret = setmetatable({}, {
    __index = function() error("secret indexing") end,
    __eq = function() error("secret comparison") end,
})
function issecretvalue(value) return rawequal(value, secret) end
local function Check(value, label)
    checks = checks + 1
    assert(value, label)
end
local function Forbidden() error("native ownership violated") end
local enabled = true
local settings = {
    objectiveColors = true,
    progressColor = { r = 0.2, g = 0.4, b = 0.6 },
    completedColor = { r = 0.3, g = 0.7, b = 0.9 },
}
ns.Addon = { Settings = function() return settings end }
ns.Active = function() return enabled end
ns.Queue = function(key, callback) pending[key] = callback end
local function Pump()
    local batch = pending
    pending = {}
    for _, callback in pairs(batch) do callback() end
    Check(next(pending) == nil, "painting does not recursively queue itself")
end
function hooksecurefunc(owner, method, callback)
    local original = owner[method]
    assert(type(original) == "function")
    owner[method] = function(...)
        original(...)
        callback(...)
    end
end
local function Tracker()
    return {
        usedBlocks = {},
        Update = function() updates = updates + 1 end,
        SetCollapsed = Forbidden, LayoutContents = Forbidden, SetParent = Forbidden,
    }
end
QuestObjectiveTracker, CampaignQuestObjectiveTracker, AchievementObjectiveTracker = Tracker(), Tracker(), Tracker()
local trackers = { QuestObjectiveTracker, CampaignQuestObjectiveTracker, AchievementObjectiveTracker }
for _, name in ipairs({ "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "WorldQuestObjectiveTracker",
    "BonusObjectiveTracker", "AdventureObjectiveTracker", "MonthlyActivitiesObjectiveTracker" }) do
    _G[name] = setmetatable({}, { __index = Forbidden, __pairs = Forbidden })
end
-- Shared.lua uses identity-based styles and reciprocal hover colors; Complete has no reverse.
OBJECTIVE_TRACKER_COLOR = {
    Normal = { r = 0.8, g = 0.8, b = 0.8 }, NormalHighlight = {}, Complete = { r = 0.6, g = 0.6, b = 0.6 },
    Failed = {}, FailedHighlight = {}, Header = {}, TimeLeft = {},
}
local colors = OBJECTIVE_TRACKER_COLOR
colors.Normal.reverse, colors.NormalHighlight.reverse = colors.NormalHighlight, colors.Normal
colors.Failed.reverse, colors.FailedHighlight.reverse = colors.FailedHighlight, colors.Failed
local function Font(style)
    local fs = { colorStyle = style, color = { 0.8, 0.8, 0.8, 0.65 }, writes = 0 }
    function fs:GetTextColor() return unpack(self.color) end
    function fs:SetTextColor(...) self.color = { ... }; self.writes = self.writes + 1 end
    fs.SetAlpha, fs.SetParent, fs.SetPoint = Forbidden, Forbidden, Forbidden
    return fs
end
local function Line(style)
    local fs = Font(style)
    return { Text = fs, used = true, state = "Completing", SetState = Forbidden,
        GlowAnim = setmetatable({}, { __index = Forbidden }),
        FadeOutAnim = setmetatable({}, { __index = Forbidden }),
        Dash = Font(colors.Normal), Icon = setmetatable({}, { __index = Forbidden }) }, fs
end
local function IsColor(fs, r, g, b, a)
    return fs.color[1] == r and fs.color[2] == g and fs.color[3] == b and fs.color[4] == a
end
assert(loadfile("QuestTracker/Compatibility.lua"))("EllesmereUIExtendQuestTracker", ns)
assert(loadfile("QuestTracker/Objectives.lua"))("EllesmereUIExtendQuestTracker", ns)
Check(ns.HasObjectives(), "current Retail tracker capability")
local hook = hooksecurefunc
hooksecurefunc = nil
Check(not ns.HasObjectives(), "missing hook API gates controls")
hooksecurefunc = hook
for _, name in ipairs(ns.TrackerNames) do _G[name] = nil end
Check(not ns.HasObjectives(), "unrelated trackers do not enable objectives")
for index, name in ipairs(ns.TrackerNames) do _G[name] = trackers[index] end

local fixtures = {}
for index, tracker in ipairs(trackers) do
    local progress, fs = Line(colors.Normal)
    local complete, completed = Line(colors.Complete)
    local failed, failedFS = Line(colors.Failed)
    -- Multiple templates and sparse/non-numeric objective keys are native, not arrays.
    local block = { usedLines = { [3] = progress, [19] = complete, Failed = failed }, SetParent = Forbidden }
    tracker.usedBlocks = { QuestTemplate = { [index * 100] = block }, OtherTemplate = {} }
    fixtures[index] = { line = progress, fs = fs, complete = completed, failed = failedFS, block = block }
end
local visited = {}
ns.EachBlock(function(block, tracker) visited[block] = tracker end)
for index, fixture in ipairs(fixtures) do
    Check(visited[fixture.block] == trackers[index], "nested template/ID enumeration for tracker " .. index)
end
ns.RefreshObjectives(); Pump()
Check(updates == 0, "refresh hooks Update without calling it")
for index, fixture in ipairs(fixtures) do
    Check(IsColor(fixture.fs, 0.2, 0.4, 0.6, 0.65), "progress color for tracker " .. index)
    Check(IsColor(fixture.complete, 0.3, 0.7, 0.9, 0.65), "complete color for tracker " .. index)
    Check(fixture.failed.writes == 0, "failed/ineligible line untouched for tracker " .. index)
    Check(fixture.line.state == "Completing" and fixture.line.Dash.writes == 0,
        "animation state and dash untouched for tracker " .. index)
end
local f, tracker = fixtures[1], trackers[1]
for _, style in ipairs({ colors.Normal, colors.NormalHighlight }) do
    f.fs.colorStyle = style
    f.fs:SetTextColor(0.91, 0.92, 0.93, 0.4)
    Pump()
    Check(IsColor(f.fs, 0.2, 0.4, 0.6, 0.4), "hover progress preserves latest native alpha")
end
settings.objectiveColors = false
ns.PaintObjectives()
Check(IsColor(f.fs, 0.91, 0.92, 0.93, 0.4), "disable restores latest hover/EUI color, not initial snapshot")
settings.objectiveColors = true
ns.PaintObjectives()
for _, style in ipairs({ colors.Failed, colors.FailedHighlight, colors.Header, colors.TimeLeft,
    { r = 0.8, g = 0.8, b = 0.8 }, secret }) do
    f.fs.colorStyle = style
    f.fs:SetTextColor(0.9, 0.1, 0.2, 0.75)
    local writes = f.fs.writes
    Pump()
    Check(f.fs.writes == writes and IsColor(f.fs, 0.9, 0.1, 0.2, 0.75),
        "failed/highlight/unknown/secret styles retain native color")
end
f.fs.colorStyle = colors.Normal
ns.PaintObjectives()
for _, used in ipairs({ false, secret, 1 }) do
    f.line.used = used
    ns.PaintObjectives()
    Check(IsColor(f.fs, 0.9, 0.1, 0.2, 0.75), "unreadable/non-boolean/unused line releases override")
    f.line.used = true
    ns.PaintObjectives()
end
f.line.used = nil
ns.PaintObjectives()
Check(IsColor(f.fs, 0.9, 0.1, 0.2, 0.75), "missing used flag releases override")
f.line.used = true

-- Unknown containers are deliberately not adapted. Restore anything previously painted.
local originalBlocks, originalLines = tracker.usedBlocks, f.block.usedLines
for _, broken in ipairs({ false, 123, "changed", secret, {} }) do
    ns.PaintObjectives()
    f.block.usedLines = broken
    ns.PaintObjectives()
    Check(IsColor(f.fs, 0.9, 0.1, 0.2, 0.75), "missing/changed/secret usedLines releases override")
    f.block.usedLines = originalLines
    ns.PaintObjectives()
    tracker.usedBlocks = broken
    ns.PaintObjectives()
    Check(IsColor(f.fs, 0.9, 0.1, 0.2, 0.75), "missing/changed/secret usedBlocks releases override")
    tracker.usedBlocks = originalBlocks
end
tracker.usedBlocks = nil
ns.PaintObjectives()
Check(IsColor(f.fs, 0.9, 0.1, 0.2, 0.75), "absent usedBlocks is safe")
tracker.usedBlocks = originalBlocks
f.block.usedLines = nil
ns.PaintObjectives()
Check(IsColor(f.fs, 0.9, 0.1, 0.2, 0.75), "absent usedLines is safe")
f.block.usedLines = originalLines
-- Bad siblings do not hide valid blocks/lines, and no speculative .lines adapter exists.
tracker.usedBlocks.BadTemplate = secret
originalBlocks.QuestTemplate.BadBlock = secret
originalLines.BadLine, originalLines.BadText = secret, { Text = secret, used = true }
local ignored = Font(colors.Normal)
originalLines.NoMethods = { Text = { colorStyle = colors.Normal }, used = true }
f.block.lines = { { Text = ignored, used = true } }
ns.PaintObjectives()
Check(IsColor(f.fs, 0.2, 0.4, 0.6, 0.75) and ignored.writes == 0, "valid siblings paint; alternate line map ignored")
f.line.Text = nil
ns.PaintObjectives()
Check(IsColor(f.fs, 0.9, 0.1, 0.2, 0.75), "missing Text restores detached font string")
f.line.Text = f.fs
ns.PaintObjectives()
tracker.usedBlocks = { [100] = f.block }
ns.PaintObjectives()
Check(IsColor(f.fs, 0.9, 0.1, 0.2, 0.75), "flat changed block shape is not invented/adapted")
tracker.usedBlocks = originalBlocks

local secretLine, secretFS = Line(colors.Normal)
secretFS.color = { secret, secret, secret, secret }
originalLines.SecretRGB = secretLine
ns.PaintObjectives()
Check(rawequal(secretFS.color[4], secret), "secret native alpha forwarded without inspection")
enabled = false
ns.PaintObjectives()
Check(rawequal(secretFS.color[1], secret) and rawequal(secretFS.color[4], secret), "native secret RGB/alpha restored verbatim")
Check(IsColor(f.fs, 0.9, 0.1, 0.2, 0.75), "inactive addon restores overrides")
enabled = true
originalLines.SecretRGB = nil
tracker:Update(); Pump()
Check(updates == 1 and IsColor(f.fs, 0.2, 0.4, 0.6, 0.75), "external native Update post-hook schedules painting")
ns.RefreshObjectives(); Pump()
Check(updates == 1, "repeat refresh still never calls native Update")
OBJECTIVE_TRACKER_COLOR = nil
ns.PaintObjectives()
Check(IsColor(f.fs, 0.9, 0.1, 0.2, 0.75), "missing style registry releases overrides")
issecretvalue = nil
OBJECTIVE_TRACKER_COLOR = colors
originalLines.BadLine, originalLines.BadText, originalBlocks.BadTemplate = nil, nil, nil
originalBlocks.QuestTemplate.BadBlock = nil
ns.PaintObjectives()
Check(IsColor(f.fs, 0.2, 0.4, 0.6, 0.75), "readable Forever-style data works without secret API")
print("PASS: " .. checks .. " objective tracker structure checks")
