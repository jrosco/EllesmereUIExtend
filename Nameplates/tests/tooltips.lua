-- Run from the repository root with Lua or fengari.
local f = assert(loadfile("Nameplates/tests/runtime.lua"))("ui-locks")
local api, rows = f.api, f.rows
local checks, settings, choices = 0, 0, 0
local function Check(value, label)
    checks = checks + 1
    assert(value, label)
end
local function Tooltip(text, label)
    Check(type(text) == "string" and text:find("%S") ~= nil, label .. " needs a tooltip")
    Check(#text <= 240, label .. " tooltip should stay concise")
end

EllesmereUI.Glows = assert(loadfile("Nameplates/tests/glow-mocks.lua"))()
local rule = api.GetRules()[1]
rule.style.castEnabled, rule.style.textEnabled = true, true
rule.style.healthGlowStyle, rule.style.castGlowStyle = 1, 1
EllesmereUI:RefreshPage()
for name, row in pairs(rows) do
    if row.get and row.set then
        Tooltip(row.tooltip, name)
        settings = settings + 1
    end
    for _, item in ipairs(row.items or {}) do
        Tooltip(item.tooltip, name .. ": " .. item.label)
        choices = choices + 1
    end
    if row.rows then
        Tooltip(row.tip, name .. " cog")
        for _, control in ipairs(row.rows) do Tooltip(control.tooltip, name .. ": " .. control.label) end
    end
end
Check(settings >= 70 and choices >= 40, "review covers settings and condition choices")
Check(rows.Reaction.tooltip:find("Leave empty for Any", 1, true), "empty conditions remain explained")
Check(rows["Rule enabled"].tooltip:find("all its conditions", 1, true), "condition groups still combine with AND")
Check(rows["Cast state"].tooltip:find("all active casts", 1, true), "color-state appearance behavior remains explained")
local targetItems = {}
for _, item in ipairs(rows["Target state"].items) do targetItems[item.key] = item end
Check(targetItems.no.tooltip:find("target selected", 1, true), "non-target choice requires a selected target")
Check(targetItems.none.tooltip:find("no target selected", 1, true), "no-target choice is distinct")

-- Native action-button highlights and clicks must survive the added hover hooks.
local shown, hides = nil, 0
EllesmereUI.ShowWidgetTooltip = function(_, text) shown = text end
EllesmereUI.HideWidgetTooltip = function() hides = hides + 1 end
local function Hover(name)
    shown = nil
    local button = assert(rows[name].button, name .. " button")
    Check(type(button.scripts.OnEnter) == "function", name .. " has hover help")
    button.scripts.OnEnter(button)
    Tooltip(shown, name)
    local before = hides
    button.scripts.OnLeave(button)
    Check(hides == before + 1, name .. " hides its tooltip on leave")
    return button
end
for _, name in ipairs({ "Add Rule", "Copy Rule", "Delete Rule", "Move Rule Up", "Move Rule Down" }) do
    local button = Hover(name)
    Check(button.nativeHover == false and type(rows[name].click) == "function", name .. " retains native hover and click")
end
local button = rows["Copy Rule"].button
button.scripts.OnEnter(button)
Check(button.nativeHover == true, "native OnEnter still runs")
local lock
for _, frame in ipairs(f.frames) do
    if frame.allPoints == button and frame.scripts.OnEnter then lock = frame end
end
Check(lock ~= nil, "action keeps its editor-lock overlay")
rows["Enable rule styling"].set(false)
lock.scripts.OnEnter(lock)
Check(shown:find("Enable rule styling", 1, true), "lock explanation takes priority over normal action help")
rows["Enable rule styling"].set(true)
rule.style.healthGlowStyle, rule.style.castGlowStyle = 3, 3
EllesmereUI:RefreshPage()
for _, name in ipairs({ "Health glow settings", "Cast glow settings" }) do
    Tooltip(rows[name].tip, name)
    Tooltip(rows[name].rows[1].tooltip, name .. " sparkle size")
end
local renderBorder = EllesmereUI.ApplyBorderStyle
EllesmereUI.ApplyBorderStyle = nil
EllesmereUI:RefreshPage()
for _, name in ipairs({ "Override health border", "Health border texture", "Health border size",
    "Override cast border", "Cast border texture", "Cast border size" }) do
    Check(rows[name].disabled(), name .. " stays gated on older EUI")
    Check(rows[name].disabledTooltip():find("Update EllesmereUI", 1, true), name .. " explains the missing capability")
end
EllesmereUI.ApplyBorderStyle = renderBorder
EllesmereUI:RefreshPage()

local module = f.spec.modules[1]
module.buildPage("Profiles", f.parent, 0)
Tooltip(rows["Profile for this character"].tooltip, "character profile")
Hover("Create Profile")
Check(api.CreateProfile("Tooltip profile"), "named profile created")
module.buildPage("Profiles", f.parent, 0)
Hover("Create Profile"); Hover("Rename Profile"); Hover("Delete Active Profile")
module.buildPage("Sharing", f.parent, 0)
Hover("Export Rule Set"); Hover("Import Rule Set")
module.buildPage("About", f.parent, 0)
Hover("Open Nameplate Style Rules")
local count = #f.frames
EllesmereUI.IsSearchPrebuild = function() return true end
for _, page in ipairs({ "Profiles", "Sharing", "About" }) do module.buildPage(page, f.parent, 0) end
Check(#f.frames == count, "button tooltips create no frames during search prebuild")
print("PASS: " .. checks .. " tooltip checks across " .. settings .. " settings, " .. choices
    .. " condition choices, cogs, actions, profiles, sharing and native hover/lock handling")
