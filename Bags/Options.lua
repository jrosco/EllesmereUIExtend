local _, ns = ...
if not ns.Addon then return end
EllesmereUIExtend.RegisterModule({
    key = "Bags", title = "Bags", pages = { "Bank Snapshot" },
    buildPage = function(_, parent, yOffset)
        if not EllesmereUI.IsSearchPrebuild or not EllesmereUI.IsSearchPrebuild() then
            if EllesmereUI.ClearContentHeader then EllesmereUI:ClearContentHeader() end
        end
        local W, y = EllesmereUI.Widgets, yOffset
        local ownerSettings = ns.Addon.Settings()
        local _, height = W:SectionHeader(parent, "BANK SNAPSHOT", y)
        y = y - height
        _, height = W:DualRow(parent, y, {
            type = "slider", text = "Window Scale", min = 50, max = 150, step = 5,
            tooltip = "Scale the bank snapshot window only. 100% is the default; EUI's live bags and bank are unchanged.",
            getValue = function() return math.floor(ns.WindowScale(ns.Addon.Settings().windowScale) * 100 + 0.5) end,
            setValue = function(value)
                if ns.Editing() or not ns.Number(value) then return end
                ns.Addon.Settings().windowScale = ns.WindowScale(value / 100)
                ns.Addon.Refresh()
            end,
        }, {
            type = "dropdown", text = "Frame Strata",
            tooltip = "Controls which overlapping windows appear above the snapshot viewer. Higher strata put it above lower-strata frames. EUI's live windows are unchanged.",
            values = EllesmereUI.FRAME_STRATA_LABELS or ns.FrameStrataValues,
            order = EllesmereUI.FRAME_STRATA_ORDER_BASE or ns.FrameStrataOrder,
            getValue = function() return ns.WindowStrata(ns.Addon.Settings().frameStrata) end,
            setValue = function(value)
                if ns.Editing() or not ns.String(value) or not ns.FrameStrataValues[value] then return end
                ns.Addon.Settings().frameStrata = value
                ns.Addon.Refresh()
            end,
        })
        y = y - height
        _, height = W:DualRow(parent, y, {
            type = "toggle", text = "Group by Category",
            tooltip = "Use the current EUI bag categories within the selected bank tabs.",
            getValue = function() return ns.Addon.Settings().groupByCategory == true end,
            setValue = function(value)
                if ns.Editing() then return end
                ns.Addon.Settings().groupByCategory = value == true
                ns.Addon.Refresh()
            end,
        }, {
            type = "dropdown", text = "Bank display",
            values = { match = "Match EUI bank", grid = "Grid", compact = "Compact", list = "List" },
            order = { "match", "grid", "compact", "list" },
            tooltip = "Match EUI's bank display or choose a read-only snapshot layout.",
            getValue = function() return ns.Addon.Settings().display or "match" end,
            setValue = function(value)
                if ns.Editing() then return end
                if value ~= "match" and value ~= "grid" and value ~= "compact" and value ~= "list" then return end
                ns.Addon.Settings().display = value
                ns.Addon.Refresh()
            end,
        })
        y = y - height
        _, height = W:DualRow(parent, y, {
            type = "toggle", text = "Show Bank Snapshot button",
            tooltip = "Add a read-only bank viewer button below the EUI bag window. /ebags also opens the viewer.",
            getValue = function() return ns.Addon.Settings().showButton end,
            setValue = function(value)
                if ns.Editing() then return end
                ns.Addon.Settings().showButton = value == true
                ns.Addon.Refresh()
            end,
        }, {
            type = "toggle", text = "Show bank stock in tooltips",
            tooltip = "Show current/other saved bank counts in EUI bags. While the live bank or snapshot viewer is open, list stock by character with class-coloured names. Only positive saved personal-bank quantities are shown; snapshots may be outdated. No bag scanning, Warband or guild storage.",
            getValue = function() return ns.Addon.Settings().tooltipBankCounts == true end,
            setValue = function(value)
                if ns.Editing() or ns.Secret(value) or ownerSettings ~= ns.Addon.Settings() then return end
                ns.Addon.Settings().tooltipBankCounts = value == true
                ns.Addon.Refresh()
            end,
        })
        y = y - height
        _, height = W:DualRow(parent, y, { type = "spacer", text = "Visit a banker to capture personal storage.",
            tooltip = "Opens on your current character, showing Visit the banker first before capture. Use the character dropdown to browse other captured banks. Snapshots update during banker visits; profile resets never clear inventory. No Warband storage." })
        return math.abs(y - height)
    end,
})
