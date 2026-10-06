local addonName, ns = ...
local addon = ns.Addon
if not addon then return end

local function Locked() return not addon.Settings().enabled end
local function Changed() addon.Refresh() end

local function BuildPage(page, parent, yOffset)
    local W, y = EllesmereUI.Widgets, yOffset
    local function Row(left, right)
        local _, height = W:DualRow(parent, y, left, right)
        y = y - height
    end
    local function Section(text)
        local _, height = W:SectionHeader(parent, text, y)
        y = y - height
    end
    local function Toggle(label, key, tip, extraLock, lockTip, onChanged)
        local function Disabled() return Locked() or (extraLock and extraLock()) or false end
        Row({ type = "toggle", text = label, tooltip = tip,
            disabled = Disabled, disabledTooltip = lockTip or "Enable the extension first.",
            getValue = function() return addon.Settings()[key] end,
            setValue = function(value)
                if Disabled() then return end
                addon.Settings()[key] = value
                if onChanged then onChanged() else Changed() end
            end,
        })
    end
    local function Note(label, tip)
        Row({ type = "spacer", text = label, tooltip = tip })
    end

    if page == "General" then
        Section("EXTENSION")
        local _, height = W:Toggle(parent, "Enable extension", y,
            function() return addon.Settings().enabled end,
            function(value) addon.Settings().enabled = value; Changed() end,
            "Enable links, colors, notifications and the optional quest-item button. EUI's native tracker remains untouched.")
        y = y - height
        Section("WOWHEAD")
        local function NoMenus() return not ns.HasMenus() end
        Toggle("Wowhead URL menus", "wowhead", "Add a copyable URL to supported quest-log and tracker right-click menus.",
            NoMenus, "Enable the extension. This client must support tagged native menus.")
        local function DatabaseLocked() return Locked() or NoMenus() or not addon.Settings().wowhead end
        Row({ type = "dropdown", text = "Wowhead database", tooltip = "Auto uses Retail on Retail and Classic on Forever. Custom content may not exist on Wowhead.",
            values = { auto = "Auto", retail = "Retail", classic = "Classic Era" }, order = { "auto", "retail", "classic" },
            disabled = DatabaseLocked, disabledTooltip = "Enable Wowhead URL menus on a supported client first.",
            getValue = function() return addon.Settings().wowheadDatabase end,
            setValue = function(value)
                if DatabaseLocked() or not ({ auto = true, retail = true, classic = true })[value] then return end
                addon.Settings().wowheadDatabase = value
            end,
        })
        Section("OBJECTIVE COLORS")
        Toggle("Custom objective colors", "objectiveColors", "Tint ordinary quest and achievement objectives. Failed or unknown states keep native colors.",
            function() return not ns.HasObjectives() end, "Enable the extension on a client with ordinary native objective trackers and secure post-hooks.")
        local function ColorLocked() return Locked() or not addon.Settings().objectiveColors or not ns.HasObjectives() end
        local function Color(label, key, tip)
            return { type = "colorpicker", text = label, tooltip = tip, hasAlpha = false,
                disabled = ColorLocked, disabledTooltip = "Enable custom objective colors first.",
                getValue = function() local c = addon.Settings()[key]; return c.r, c.g, c.b, 1 end,
                setValue = function(r, g, b)
                    if ColorLocked() then return end
                    r, g, b = ns.Number(r), ns.Number(g), ns.Number(b)
                    if not r or not g or not b then return end
                    addon.Settings()[key] = { r = math.max(0, math.min(1, r)), g = math.max(0, math.min(1, g)), b = math.max(0, math.min(1, b)) }
                    Changed()
                end,
            }
        end
        Row(Color("In-progress color", "progressColor", "Color for incomplete objectives."),
            Color("Completed color", "completedColor", "Color for completed objectives that Blizzard still displays."))
    elseif page == "Notifications" then
        Section("QUEST NOTIFICATIONS")
        Toggle("Quest status notifications", "notifications", "Notify on selected status changes. Login and enabling this option establish a silent baseline.",
            function() return not ns.HasQuestLog() end, "Enable the extension on a client with quest-log APIs.")
        local function NotificationLocked() return Locked() or not addon.Settings().notifications or not ns.HasQuestLog() end
        Toggle("Chat messages", "messages", "Print selected quest status changes in chat.", NotificationLocked, "Enable quest status notifications first.")
        Toggle("Notification sounds", "sounds", "Play a sound for selected changes, at most once per second.",
            function() return NotificationLocked() or type(PlaySound) ~= "function"
                or not (ns.SoundID("ready") or ns.SoundID("complete") or ns.SoundID("tell")) end,
            "Enable notifications. This client must provide a supported sound kit.")
        local function SoundLocked() return NotificationLocked() or not addon.Settings().sounds end
        local soundValues = {}
        for key, label in pairs(ns.SoundNames) do soundValues[key] = label .. (ns.SoundID(key) and "" or " (unavailable)") end
        Row({ type = "dropdown", text = "Notification sound", tooltip = "Choose an available Blizzard sound. Missing sounds are not substituted with guessed IDs.",
            values = soundValues, order = { "ready", "complete", "tell" }, disabled = SoundLocked,
            disabledTooltip = "Enable notification sounds first.",
            getValue = function() return addon.Settings().sound end,
            setValue = function(value)
                if SoundLocked() or not ns.SoundID(value) then return end
                addon.Settings().sound = value
            end,
        })
        Section("STATUS CHANGES")
        local statuses = { { "accepted", "Quest accepted" }, { "progress", "Objective progress" },
            { "objective", "Objective completed" }, { "ready", "Ready for turn-in" },
            { "failed", "Quest failed" }, { "turnedIn", "Quest turned in" } }
        for _, option in ipairs(statuses) do
            local key, label = option[1], option[2]
            local function StatusLocked() return NotificationLocked() or not ns.StatusSupported(key) end
            Row({ type = "toggle", text = label, tooltip = "Send enabled messages and sounds for this status. Unreadable status changes are skipped.",
                disabled = StatusLocked, disabledTooltip = "Enable notifications. This client must provide this status's quest API/event.",
                getValue = function() return addon.Settings().statuses[key] end,
                setValue = function(value)
                    if StatusLocked() then return end
                    addon.Settings().statuses[key] = value; Changed()
                end,
            })
        end
    elseif page == "Quest Item" then
        Section("NAVIGATION-TRACKED QUEST ITEM")
        local function ItemUnavailable() return not addon.Capabilities().questItem end
        local function ItemLocked() return Locked() or not addon.Settings().questItem or ItemUnavailable() end
        local function ItemChanged() if ns.RefreshQuestItem then ns.RefreshQuestItem() end end
        Toggle("Show tracked quest item", "questItem", "Show the item for the quest selected for Blizzard navigation (super-tracked). Distance and selection update out of combat only.",
            ItemUnavailable, "Enable the extension. This feature requires readable quest distance, tracking/item APIs, a timer and a secure item template.", ItemChanged)
        Section("VISIBILITY")
        if type(EllesmereUI.BuildVisibilityRow) == "function"
            and not (EllesmereUI.IsSearchPrebuild and EllesmereUI.IsSearchPrebuild()) then
            local lockedStore = ns.Copy(addon.Settings().itemVisibility)
            local function VisibilityLocked() return ItemLocked() or not ns.HasItemVisibility() end
            local _, height = EllesmereUI.BuildVisibilityRow(W, parent, y, {
                label = "Visibility", legacyKey = "visibility", caps = { partyIncludesRaid = false, noOverrideMouseover = true },
                getStore = function() return VisibilityLocked() and lockedStore or addon.Settings().itemVisibility end,
                getOption = function(key) return addon.Settings().itemVisibility[key] end,
                setOption = function(key, value)
                    if not VisibilityLocked() then addon.Settings().itemVisibility[key] = value end
                end,
                disabledFn = VisibilityLocked,
                disabledTooltip = "Enable the item button on a client with EUI's shared visibility and native secure state drivers.",
                tooltip = "EUI's action-bar visibility conditions. Always still requires an eligible quest item. Lua-only conditions and proximity/item changes refresh out of combat.",
                onChanged = function() if not VisibilityLocked() then ItemChanged() end end,
                onOptionChanged = function() if not VisibilityLocked() then ItemChanged() end end,
            })
            y = y - height
        else
            Note("Visibility", "EUI's shared action-bar visibility control requires a current EUI build and secure state drivers. Missing support keeps the default Always mode; non-default saved conditions fail closed.")
        end
        Section("APPEARANCE")
        Toggle("Retail style background", "itemRetailArt", "Show Blizzard's decorative extra-action artwork. This is independent of the icon border.",
            ItemLocked, "Enable the quest-item button first.", ItemChanged)
        Row({ type = "slider", text = "Button size", min = 24, max = 112, step = 1,
            tooltip = "Size of the square clickable button in pixels. Icon, cooldown, Retail artwork and Edit Mode preview follow its size.",
            disabled = ItemLocked, disabledTooltip = "Enable the quest-item button first.",
            getValue = ns.ItemSize,
            setValue = function(value)
                if ItemLocked() or not ns.Number(value) then return end
                addon.Settings().itemSize = math.floor(ns.Clamp(value, 24, 112, 56) + 0.5); ItemChanged()
            end,
        })
        Row({ type = "slider", text = "Quest icon opacity", min = 0, max = 1, step = 0.05,
            tooltip = "Opacity of the quest icon, Retail background artwork and border.",
            disabled = ItemLocked, disabledTooltip = "Enable the quest-item button first.",
            getValue = function() return addon.Settings().itemIconAlpha end,
            setValue = function(value)
                if ItemLocked() or not ns.Number(value) then return end
                local alpha = ns.Clamp(value, 0, 1, 1)
                addon.Settings().itemIconAlpha = alpha
                ItemChanged()
            end,
        })
        Row({ type = "slider", text = "Quest proximity (yards)", min = 1, max = 1000, step = 1,
            tooltip = "Show at or below this navigation distance in yards (1–1000, default 100). Uses the unrounded distance for the super-tracked quest. Changes apply out of combat.",
            disabled = ItemLocked, disabledTooltip = "Enable the quest-item button first.",
            getValue = ns.ItemProximityYards,
            setValue = function(value)
                if ItemLocked() or not ns.Number(value) then return end
                addon.Settings().itemProximityYards = math.floor(ns.Clamp(value, 1, 1000, 100) + 0.5); ItemChanged()
            end,
        })
        local borderValues, borderOrder = ns.ItemBorderOptions()
        local function BordersLocked() return ItemLocked() or not ns.HasItemBorders() end
        local function BorderOff() return BordersLocked() or addon.Settings().itemBorderTexture == "none" end
        Row({ type = "dropdown", text = "Button border style", values = borderValues, order = borderOrder,
            tooltip = "Choose None or an EUI/SharedMedia border texture. The Retail background toggle remains independent.",
            disabled = BordersLocked, disabledTooltip = "Enable the item button on an EUI build with the shared border renderer.",
            getValue = function() return addon.Settings().itemBorderTexture end,
            setValue = function(value)
                if BordersLocked() or not ns.String(value) or not borderValues[value] then return end
                addon.Settings().itemBorderTexture = value; ItemChanged()
            end,
        }, { type = "colorpicker", text = "Button border color", hasAlpha = false,
            tooltip = "Tint the chosen icon border. None adds no border, including no green outline.",
            disabled = BorderOff, disabledTooltip = "Enable the item button and choose a border style other than None.",
            getValue = function() local c = addon.Settings().itemBorderColor; return c.r, c.g, c.b, 1 end,
            setValue = function(r, g, b)
                if BorderOff() or not ns.Number(r) or not ns.Number(g) or not ns.Number(b) then return end
                addon.Settings().itemBorderColor = { r = ns.Clamp(r, 0, 1, 1), g = ns.Clamp(g, 0, 1, 1), b = ns.Clamp(b, 0, 1, 1) }
                ItemChanged()
            end,
        })
        Row({ type = "slider", text = "Border thickness / size", min = 1, max = 4, step = 1,
            tooltip = "Solid uses pixel thickness (1–4). Textured borders use EUI's four size steps.",
            disabled = BorderOff, disabledTooltip = "Choose a border style other than None first.",
            getValue = function() return addon.Settings().itemBorderSize end,
            setValue = function(value)
                if BorderOff() or not ns.Number(value) then return end
                addon.Settings().itemBorderSize = math.floor(ns.Clamp(value, 1, 4, 1) + 0.5); ItemChanged()
            end,
        })
        Section("POSITION")
        Row({ type = "labeledButton", text = "Button position", buttonText = "Reset", tooltip = "Return the item button to its default position. Move it with EUI Edit Mode; right-drag is the fallback when that API is unavailable.",
            disabled = function() return Locked() or ns.InCombat() end, disabledTooltip = "Enable the extension and leave combat first.",
            onClick = function() if not Locked() and not ns.InCombat() then addon.ResetItemPosition() end end,
        })
        Note("Move with EUI Edit Mode", "Enable the quest-item button, enter EUI Edit/Unlock Mode, and move Tracked Quest Item. A non-clickable preview appears even without an available item. Save & Exit commits; Exit Without Saving or Discard restores the previous position.")
        Note("Combat keeps the last configured item", "Secure item, size, border and proximity changes wait until combat ends. Native visibility conditions such as combat and group state remain live through a secure driver.")
        Note("Blizzard's Extra Action Button is preserved", "This extension has its own button. EUI's quest-item hotkey also remains unchanged.")
    else
        Section("SUPPORTED FEATURES")
        Note("Wowhead links, objective colors and notifications", "Supported features use this addon's own settings and native API capability gates. See README.md for installation and client testing.")
        Note("Navigation-tracked quest-item button", "Requires readable navigation distance and super-tracked quest identity. Missing data hides the item.")
        Section("INTEGRATION LIMITATIONS")
        Note("Display-only quest filters are not available", "Current zone, quest type and relative-level filters need a safe native display-filter API. This build never untracks your quests, replaces layout methods or leaves invisible click targets.")
        Note("Native collapse extensions are omitted", "Collapse binding, auto-collapse in instances and restoring collapse at login enter the native layout path that EUI documents as unsafe. No auto-hide substitute is used.")
        Note("Achievements remain unfiltered", "Quest filters do not translate to achievement criteria. Native tracking and collapse remain unchanged.")
        Note("Retail and Forever require in-game verification", "Mocked tests cannot reproduce the secret-value VM, native hardware clicks or menu/map taint. Use /eqtx status for capability diagnostics.")
    end
    return math.abs(y)
end

function ns.RegisterOptions()
    if ns.optionsRegistered then return true end
    if not EllesmereUI or type(EllesmereUI.RegisterPlugin) ~= "function" then return false end
    local ok, result = pcall(EllesmereUI.RegisterPlugin, addonName, {
        label = "Extend Quest Tracker",
        modules = { { key = "QuestTracker", title = "Quest Tracker",
            description = "Quest links, objective colors, notifications and the navigation-tracked quest item.",
            pages = { "General", "Notifications", "Quest Item", "About" }, buildPage = BuildPage,
            onReset = function() addon.Reset() end,
        } },
    })
    ns.optionsRegistered = ok and result == true
    return ns.optionsRegistered
end

ns.RegisterOptions()
