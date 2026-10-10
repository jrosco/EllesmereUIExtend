local _, ns = ...
if not ns.Addon then return end
EllesmereUIExtend.RegisterModule({
    key = "Bags", title = "Bags", pages = { "Bank Snapshot" },
    buildPage = function(_, parent, yOffset)
        if not EllesmereUI.IsSearchPrebuild or not EllesmereUI.IsSearchPrebuild() then
            if EllesmereUI.ClearContentHeader then EllesmereUI:ClearContentHeader() end
        end
        local W, y = EllesmereUI.Widgets, yOffset
        local _, height = W:SectionHeader(parent, "BANK SNAPSHOT", y)
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
        })
        y = y - height
        _, height = W:DualRow(parent, y, { type = "spacer", text = "Visit a banker to capture personal storage.",
            tooltip = "Snapshots update during banker visits. Choose any captured character in the viewer. Inventory data is independent of UI profiles; resetting settings never clears it. Warband storage is not captured." })
        return math.abs(y - height)
    end,
})
