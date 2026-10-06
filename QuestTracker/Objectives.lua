local _, ns = ...
local addon = ns.Addon
if not addon then return end

local records = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local painting = false

local function SetColor(fs, color)
    painting = true
    pcall(fs.SetTextColor, fs, color[1], color[2], color[3], color[4])
    painting = false
end

local function Release(fs, record)
    if record.applied then
        record.applied = false
        SetColor(fs, record.native)
    end
end

function ns.ObjectiveState(style)
    style = ns.Table(style)
    local colors = ns.Table(_G.OBJECTIVE_TRACKER_COLOR)
    if not style or not colors then return nil end
    local complete, normal, highlight = ns.Table(colors.Complete), ns.Table(colors.Normal), ns.Table(colors.NormalHighlight)
    if complete and (style == complete or style == ns.Table(complete.reverse)) then return "completed" end
    if (normal and (style == normal or style == ns.Table(normal.reverse)))
        or (highlight and style == highlight) then return "progress" end
    -- Failed/ineligible/unknown lines keep their native authored color.
end

local function Acquire(fs)
    fs = ns.Table(fs)
    if not fs or type(fs.SetTextColor) ~= "function" or type(hooksecurefunc) ~= "function" then return nil end
    local record = records[fs]
    if record then return record end
    local r, g, b, a = ns.Call(fs.GetTextColor, fs)
    if (not ns.IsSecret(r) and type(r) ~= "number")
        or (not ns.IsSecret(g) and type(g) ~= "number")
        or (not ns.IsSecret(b) and type(b) ~= "number") then return nil end
    -- Native secrets may be stored and forwarded to the setter, never inspected.
    record = { native = { r, g, b, a }, applied = false }
    records[fs] = record
    local ok = pcall(hooksecurefunc, fs, "SetTextColor", function(_, cr, cg, cb, ca)
        if painting then return end
        record.native = { cr, cg, cb, ca }
        record.applied = false
        if ns.Active() and addon.Settings().objectiveColors then
            ns.Queue("objectives", ns.PaintObjectives)
        end
    end)
    if not ok then records[fs] = nil; return nil end
    return record
end

function ns.PaintObjectives()
    local active = {}
    local enabled = ns.Active() and addon.Settings().objectiveColors
    if enabled then
        ns.EachBlock(function(block)
            local lines = ns.Table(block.usedLines)
            if not lines then return end
            for _, line in pairs(lines) do
                line = ns.Table(line)
                local fs = line and ns.Table(line.Text)
                local state = fs and ns.ObjectiveState(fs.colorStyle)
                if state and ns.Boolean(line.used) == true then
                    local record = Acquire(fs)
                    if record then
                        local c = addon.Settings()[state == "completed" and "completedColor" or "progressColor"]
                        active[fs] = true
                        record.applied = true
                        SetColor(fs, { c.r, c.g, c.b, record.native[4] })
                    end
                end
            end
        end)
    end
    for fs, record in pairs(records) do
        if not active[fs] then Release(fs, record) end
    end
end

function ns.RefreshObjectives()
    if type(hooksecurefunc) == "function" then
        for _, name in ipairs(ns.TrackerNames) do
            local tracker = ns.Table(_G[name])
            if tracker and not hooked[tracker] and type(tracker.Update) == "function" then
                local ok = pcall(hooksecurefunc, tracker, "Update", function()
                    if ns.Active() and addon.Settings().objectiveColors then
                        ns.Queue("objectives", ns.PaintObjectives)
                    end
                end)
                if ok then hooked[tracker] = true end
            end
        end
    end
    ns.Queue("objectives", ns.PaintObjectives)
end
