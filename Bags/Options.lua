local addonName, ns = ...
if not ns.Addon then return end
local EllesmereUI = ns.GetHost()
if not EllesmereUI then return end
local function BuildAboutPage(parent, yOffset)
    local EUI, W, y = EllesmereUI, EllesmereUI.Widgets, yOffset
    local prebuild = EUI.IsSearchPrebuild and EUI.IsSearchPrebuild()
    local function Section(title, text)
        local _, height = W:SectionHeader(parent, title, y)
        y = y - height
        if prebuild then
            -- EUI's search absorber indexes DualRow text, not Spacer metadata.
            _, height = W:DualRow(parent, y, { type = "spacer", text = text, tooltip = text })
        elseif type(W.Spacer) == "function" and type(EUI.MakeFont) == "function" then
            local row
            row, height = W:Spacer(parent, y, 56)
            local displayText = type(EUI.L) == "function" and EUI.L(text) or text
            row._isSpacer, row._labelText = nil, text
            row._labelTextLoc = displayText ~= text and displayText or nil
            if not prebuild then
                local pad = (ns.Number(EUI.CONTENT_PAD) or 12) + 20
                local label = EUI.MakeFont(row, 13, nil, 1, 1, 1, 0.8)
                local PP = EUI.PanelPP
                if PP and type(PP.Point) == "function" then PP.Point(label, "TOPLEFT", row, "TOPLEFT", pad, -8)
                else label:SetPoint("TOPLEFT", row, "TOPLEFT", pad, -8) end
                label:SetWidth(math.max(100, parent:GetWidth() - pad * 2))
                label:SetJustifyH("LEFT")
                label:SetWordWrap(true)
                label:SetText(displayText)
                height = math.ceil(label:GetStringHeight()) + 20
                if PP and type(PP.Size) == "function" then PP.Size(row, parent:GetWidth(), height)
                else row:SetSize(parent:GetWidth(), height) end
            end
        else
            -- Older EUI: retain informational text and search indexing without
            -- requiring the newer font/spacer helpers or creating a viewer.
            _, height = W:DualRow(parent, y, { type = "spacer", text = text, tooltip = text })
        end
        y = y - height
    end
    local metadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = ns.String(ns.Read(metadata, addonName, "Version"))
    Section("BAGS EXTENSION", (version and ("Version " .. version .. ". ") or "") ..
        "Read-only bank and optional Alt Bags inventory snapshots for EllesmereUI Bags. Requires EllesmereUI with its Bags module, or EUI Standalone Bags; no other Extend addon or standalone Core installation is needed. Supports Retail and WoW Forever.")
    Section("BANK SNAPSHOTS",
        "Visit a banker on each character to capture personal bank tabs and supported reagent storage. Enable Alt Bags (off by default), then log into each character to record their backpack, inventory bags and carried reagent bag. Inventory updates after bag changes; offline snapshots may be outdated. Complete stable scans retain previous contents on unavailable reads. Equipped gear, Warband and guild storage are excluded. Snapshot items cannot be used or transferred.")
    Section("VIEWER AND SEARCH",
        "Use /ebags or the buttons below EUI bags; Alt Bags sits left of Bank Snapshot. Header icons switch modes without closing, preserving character, search and window geometry. Opening selects your current character; missing banks show Visit the banker first. Browse characters, Tabs and Categories, and choose Grid, Compact or List. With Alt Bags enabled, search shows labelled Inventory Bags and Bank Snapshot sections across all storage for the selected character, and separate Bags/Bank matching occupied-slot counts. The x clears search.")
    Section("BANK STOCK TOOLTIPS",
        "Bank and inventory tooltip counts have separate toggles, both off by default; inventory counts also require Alt Bags enabled. Normal EUI bags show positive current/other counts under distinct Bank stock and Inventory bags headings. Opening the live bank or either snapshot mode shows named, class-coloured character quantities. Cached item-ID lookups avoid live container reads on hover; unknown classes use neutral grey until that character logs in.")
    Section("PROFILES AND WINDOW",
        "Extend profiles remember separate mode display/grouping preferences and shared sidebar, window position/size, lock, scale and strata. Drag the heading to move the viewer, use the bottom-right grip to resize, or lock both position and size. Disabling Alt Bags, profile changes and resets never erase captured bank or inventory snapshots. Settings and window editing respect EUI Edit Mode.")
    Section("HELP", "Use /eextend for shared profiles. See README.md for setup and snapshot details. Retail and Forever both require in-game verification of native tooltips, bank timing, rendering and secure behaviour.")
    return math.abs(y - yOffset)
end
EllesmereUIExtend.RegisterModule({
    key = "Bags", title = "Bags", pages = { "Bank Snapshot", "Alt Bags", "About" },
    buildPage = function(page, parent, yOffset)
        if not EllesmereUI.IsSearchPrebuild or not EllesmereUI.IsSearchPrebuild() then
            if EllesmereUI.ClearContentHeader then EllesmereUI:ClearContentHeader() end
        end
        if page == "About" then return BuildAboutPage(parent, yOffset) end
        local W, y = EllesmereUI.Widgets, yOffset
        local ownerSettings = ns.Addon.Settings()
        local altPage = page == "Alt Bags"
        local function DisplaySettings() return altPage and (ns.Addon.Settings().altBags or {}) or ns.Addon.Settings() end
        local function Locked(value)
            return ns.Editing() or ownerSettings ~= ns.Addon.Settings() or ns.Secret(value)
        end
        local _, height = W:SectionHeader(parent, altPage and "ALT BAGS" or "BANK SNAPSHOT", y)
        y = y - height
        if altPage then
            _, height = W:DualRow(parent, y, {
                type = "toggle", text = "Enable Alt Bags",
                tooltip = "Off by default. Capture your backpack, inventory bags and carried reagent bag at login and after bag changes. Log into each character with this enabled to record them. Disabling stops capture and hides access without deleting snapshots.",
                disabled = function() return not ns.InventoryAvailable() and not ns.AltBagsEnabled() end,
                disabledTooltip = "Inventory capture APIs or bag enums are unavailable on this client.",
                getValue = function() return ns.Addon.Settings().altBagsEnabled == true end,
                setValue = function(value)
                    if Locked(value) or (value == true and not ns.InventoryAvailable()) then return end
                    ns.Addon.Settings().altBagsEnabled = value == true
                    ns.Addon.Refresh()
                end,
            }, {
                type = "toggle", text = "Show inventory stock in tooltips",
                tooltip = "Off by default. Add saved current/other inventory quantities to EUI bag and bank tooltips. Either snapshot viewer shows named, class-coloured counts. Inventory and bank totals have separate headings; offline snapshots may be outdated.",
                disabled = function() return not ns.AltBagsEnabled() end,
                disabledTooltip = "Enable Alt Bags first.",
                getValue = function() return ns.Addon.Settings().tooltipBagCounts == true end,
                setValue = function(value)
                    if Locked(value) or not ns.AltBagsEnabled() then return end
                    ns.Addon.Settings().tooltipBagCounts = value == true
                    ns.Addon.Refresh()
                end,
            })
            y = y - height
        end
        _, height = W:DualRow(parent, y, {
            type = "slider", text = "Window Scale", min = 50, max = 150, step = 5,
            tooltip = "Scale the shared Bank Snapshot / Alt Bags window. 100% is the default; EUI's live bags and bank are unchanged.",
            getValue = function() return math.floor(ns.WindowScale(ns.Addon.Settings().windowScale) * 100 + 0.5) end,
            setValue = function(value)
                if Locked(value) or not ns.Number(value) then return end
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
                if Locked(value) or not ns.String(value) or not ns.FrameStrataValues[value] then return end
                ns.Addon.Settings().frameStrata = value
                ns.Addon.Refresh()
            end,
        })
        y = y - height
        _, height = W:DualRow(parent, y, {
            type = "toggle", text = "Group by Category",
            tooltip = "Use the current EUI bag categories within the selected storage. This preference belongs to this mode.",
            getValue = function() return DisplaySettings().groupByCategory == true end,
            setValue = function(value)
                if Locked(value) then return end
                DisplaySettings().groupByCategory = value == true
                ns.Addon.Refresh()
            end,
        }, {
            type = "dropdown", text = altPage and "Inventory display" or "Bank display",
            values = { match = altPage and "Match EUI bags" or "Match EUI bank", grid = "Grid", compact = "Compact", list = "List" },
            order = { "match", "grid", "compact", "list" },
            tooltip = "Match the corresponding EUI display or choose a read-only snapshot layout. This preference belongs to this mode.",
            getValue = function() return DisplaySettings().display or "match" end,
            setValue = function(value)
                if Locked(value) then return end
                if value ~= "match" and value ~= "grid" and value ~= "compact" and value ~= "list" then return end
                DisplaySettings().display = value
                ns.Addon.Refresh()
            end,
        })
        y = y - height
        if altPage then
            _, height = W:DualRow(parent, y, { type = "spacer", text = "Log into each character with Alt Bags enabled to capture inventory.",
                tooltip = "Read-only snapshots include carried reagent bags, not equipped gear or bank/Warband/guild storage. Search both sources with separately labelled slot counts. Mode switches preserve character and search; window geometry is shared. Disabling or resetting never deletes inventory." })
            return math.abs(y - height)
        end
        _, height = W:DualRow(parent, y, {
            type = "toggle", text = "Show Bank Viewer button",
            tooltip = "Add a read-only bank viewer button below the EUI bag window. /ebags also opens the viewer.",
            getValue = function() return ns.Addon.Settings().showButton end,
            setValue = function(value)
                if Locked(value) then return end
                ns.Addon.Settings().showButton = value == true
                ns.Addon.Refresh()
            end,
        }, {
            type = "toggle", text = "Show bank stock in tooltips",
            tooltip = "Show current/other saved bank counts in EUI bags. While the live bank or either snapshot mode is open, list stock by character with class-coloured names. Only positive saved personal-bank quantities are shown; snapshots may be outdated. Tooltip hovers never scan containers. No Warband or guild storage.",
            getValue = function() return ns.Addon.Settings().tooltipBankCounts == true end,
            setValue = function(value)
                if Locked(value) then return end
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
