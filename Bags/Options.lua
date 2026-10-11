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
        "Use /ebags or the buttons below EUI bags; Alt Bags sits left of Bank Snapshot. Header icons switch modes without closing, preserving character, search and window geometry; the settings icon opens Bags > Snapshot Bags. Opening selects your current character; missing banks show Visit the banker first. Browse characters, Tabs and Categories, and choose Grid, Compact or List. With Alt Bags enabled, search shows labelled Inventory Bags and Bank Snapshot sections across all storage for the selected character, and separate Bags/Bank matching occupied-slot counts. The x clears search.")
    Section("SNAPSHOT STOCK TOOLTIPS",
        "Show snapshot counts in tooltips defaults off. One Snapshot stock section shows Bags: quantity / Bank: quantity, including zero for a missing source. Compress tooltip counts defaults on for Current/Other rows; turn it off for named, class-coloured character rows everywhere. Opening bags, banks or snapshots never changes this format. Inventory counts require Alt Bags enabled. Cached item-ID lookups avoid live container reads on hover; unknown classes use neutral grey until that character logs in.")
    Section("PROFILES AND WINDOW",
        "Snapshot Bags is the first settings tab, combining both modes. Extend profiles share display, grouping, category collapse, sidebar, window position/size, lock, scale and strata. Hiding the Bank Snapshot button leaves other access intact. Disabling the Bank Snapshot viewer blocks its button, switching and /ebags but keeps bank capture and saved contents. Disabling Alt Bags stops inventory capture. Profile changes and resets never erase snapshots. Settings and window editing respect EUI Edit Mode.")
    Section("HELP", "Use /eextend for shared profiles. See README.md for setup and snapshot details. Retail and Forever both require in-game verification of native tooltips, bank timing, rendering and secure behaviour.")
    return math.abs(y - yOffset)
end
EllesmereUIExtend.RegisterModule({
    key = "Bags", title = "Bags", pages = { "Snapshot Bags", "About" },
    buildPage = function(page, parent, yOffset)
        if not EllesmereUI.IsSearchPrebuild or not EllesmereUI.IsSearchPrebuild() then
            if EllesmereUI.ClearContentHeader then EllesmereUI:ClearContentHeader() end
        end
        if page == "About" then return BuildAboutPage(parent, yOffset) end
        local W, y = EllesmereUI.Widgets, yOffset
        local ownerSettings = ns.Addon.Settings()
        local function Locked(value)
            return ns.Editing() or ownerSettings ~= ns.Addon.Settings() or ns.Secret(value)
        end
        local _, height = W:SectionHeader(parent, "SNAPSHOT BAGS", y)
        y = y - height
        _, height = W:DualRow(parent, y, {
            type = "toggle", text = "Show snapshot counts in tooltips",
            tooltip = "Off by default. Show saved Bags: quantity / Bank: quantity together in EUI bag/bank and snapshot tooltips. Zero sources remain explicit; rows with both zero are omitted. Inventory counts require Alt Bags enabled. Snapshots may be outdated; tooltip hovers never scan containers.",
            getValue = function() return ns.Addon.Settings().tooltipBankCounts == true end,
            setValue = function(value)
                if Locked(value) then return end
                ns.Addon.Settings().tooltipBankCounts = value == true
                ns.Addon.Refresh()
            end,
        }, {
            type = "toggle", text = "Compress tooltip counts",
            tooltip = "On by default: combine quantities into Current and Other rows. Turn off to list each character with class-coloured names. This setting controls all supported tooltips, even with live bank or snapshot windows open.",
            disabled = function() return ns.Addon.Settings().tooltipBankCounts ~= true end,
            disabledTooltip = "Enable Show snapshot counts in tooltips first.",
            getValue = function() return ns.Addon.Settings().compressTooltipCounts ~= false end,
            setValue = function(value)
                if Locked(value) or ns.Addon.Settings().tooltipBankCounts ~= true then return end
                ns.Addon.Settings().compressTooltipCounts = value == true
                ns.Addon.Refresh()
            end,
        })
        y = y - height
        _, height = W:DualRow(parent, y, {
            type = "toggle", text = "Enable Bank Snapshot viewer",
            tooltip = "On by default. Disable to block the bank viewer, its footer button, header switching and /ebags. Bank capture and saved snapshots remain intact; bank search results and tooltip stock stay available in Alt Bags.",
            getValue = function() return ns.BankViewerEnabled() end,
            setValue = function(value)
                if Locked(value) then return end
                ns.Addon.Settings().bankViewerEnabled = value == true
                ns.Addon.Refresh()
            end,
        }, {
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
        })
        y = y - height
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
            tooltip = "Use the current EUI bag categories in both snapshot modes. Display, grouping and category-collapse preferences are shared.",
            getValue = function() return ns.Addon.Settings().groupByCategory == true end,
            setValue = function(value)
                if Locked(value) then return end
                ns.Addon.Settings().groupByCategory = value == true
                ns.Addon.Refresh()
            end,
        }, {
            type = "dropdown", text = "Snapshot display",
            values = { match = "Match EUI", grid = "Grid", compact = "Compact", list = "List" },
            order = { "match", "grid", "compact", "list" },
            tooltip = "Choose a layout shared by both snapshot modes. Match EUI follows live inventory for Alt Bags and live bank for Bank Snapshot.",
            getValue = function() return ns.Addon.Settings().display or "match" end,
            setValue = function(value)
                if Locked(value) then return end
                if value ~= "match" and value ~= "grid" and value ~= "compact" and value ~= "list" then return end
                ns.Addon.Settings().display = value
                ns.Addon.Refresh()
            end,
        })
        y = y - height
        _, height = W:DualRow(parent, y, {
            type = "toggle", text = "Show Bank Snapshot button",
            tooltip = "Show the bank entry button below EUI bags while its viewer is enabled. Hiding only this button does not block header switching or /ebags and never stops bank capture.",
            disabled = function() return not ns.BankViewerEnabled() end,
            disabledTooltip = "Enable Bank Snapshot viewer first.",
            getValue = function() return ns.Addon.Settings().showButton end,
            setValue = function(value)
                if Locked(value) or not ns.BankViewerEnabled() then return end
                ns.Addon.Settings().showButton = value == true
                ns.Addon.Refresh()
            end,
        }, { type = "spacer", text = "Settings apply to both snapshot modes.",
            tooltip = "Bank capture continues when its viewer is disabled. Alt Bags captures carried inventory only while enabled. Shared profile changes and reset never erase either source." })
        y = y - height
        _, height = W:DualRow(parent, y, { type = "spacer", text = "Visit a banker to capture personal storage.",
            tooltip = "Opens on your current character, showing Visit the banker first before capture. Use the character dropdown to browse other captured banks. Snapshots update during banker visits; profile resets never clear inventory. No Warband storage." })
        return math.abs(y - height)
    end,
})
