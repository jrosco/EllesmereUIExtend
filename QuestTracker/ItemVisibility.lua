local _, ns = ...
local addon = ns.Addon
if not addon then return end

local macroOptions = {
    { "visOnlyMounted", "nomounted" }, { "visHideMounted", "mounted" },
    { "visHideNoTarget", "noexists" }, { "visHideWithTarget", "exists" },
    { "visHideNoEnemy", "noharm" }, { "visHideWithEnemy", "harm" },
}

local function SimpleVisibility(store)
    if store.visibility ~= "always" and store.visibility ~= "never" then return nil end
    for key, value in pairs(store) do
        if type(value) == "boolean" and value then return nil end
        if key == "visibilityModes" then
            for _, selected in pairs(value) do if selected then return nil end end
        end
    end
    return store.visibility == "always" and "show" or "hide"
end

function ns.BuildItemVisibilityDriver()
    local store = addon.Settings().itemVisibility
    if not ns.HasItemVisibility() then return SimpleVisibility(store) or "hide" end
    local prefix = "[petbattle] hide; "
    local vm = ns.Table(ns.Call(EllesmereUI.GetActiveVisibilityModes, store, "visibility"))
    if store.visibility == "never" then return "hide" end
    if store.visibilityMatch == "any" then
        -- Exactly the shared tail used by action bars. Lua-only conditions are
        -- evaluated at build time, not recomputed through protected Lua writes.
        return prefix .. (ns.String(ns.Call(EllesmereUI.BuildAnyMatchTail, store, "visibility", vm)) or "hide")
    end
    local veto = ns.Call(EllesmereUI.CheckVisibilityOptionsNonMacro, store, true)
    if ns.IsSecret(veto) or veto ~= false then return "hide" end
    for _, option in ipairs(macroOptions) do
        if store[option[1]] then prefix = prefix .. "[" .. option[2] .. "] hide; " end
    end
    local selection = vm or ns.Table(ns.Call(EllesmereUI.GetVisibilitySelection, store, "visibility"))
    if not selection then return "hide" end
    return ns.String(ns.Call(EllesmereUI.BuildVisibilityDriverString, prefix, selection)) or "hide"
end

function ns.ItemVisibilityAlpha(frame, hovered)
    if not frame then return end
    local store = addon.Settings().itemVisibility
    local alpha = 1
    local selectedHover = store.visibility == "mouseover" or (store.visibilityModes and store.visibilityModes.mouseover)
    if selectedHover then
        local wants = ns.Boolean(ns.Call(EllesmereUI and EllesmereUI.VisWantsMouseover, store, "visibility"))
        if wants == nil or (wants and not hovered) then alpha = 0 end
    end
    ns.Call(frame.SetAlpha, frame, alpha)
end

function ns.ApplyItemVisibility(frame, eligible, hovered)
    if not frame or ns.InCombat() then return end
    local driver = eligible and ns.BuildItemVisibilityDriver() or "hide"
    if type(RegisterStateDriver) == "function" and type(UnregisterStateDriver) == "function" then
        if frame.questItemDriver ~= driver then
            local ok = pcall(RegisterStateDriver, frame, "visibility", driver)
            if ok then
                frame.questItemDriver = driver
            else
                pcall(UnregisterStateDriver, frame, "visibility")
                frame.questItemDriver = nil
                frame:Hide()
            end
        end
    elseif eligible and driver == "show" then
        frame:Show()
    else
        frame:Hide()
    end
    ns.ItemVisibilityAlpha(frame, hovered)
end
