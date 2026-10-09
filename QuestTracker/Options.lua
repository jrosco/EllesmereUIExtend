local addonName, ns = ...
local addon = ns.Addon
if not addon then return end

local function Changed() addon.Refresh() end
local function RefreshWidgetStates()
    local refreshList = EllesmereUI and EllesmereUI._widgetRefreshList
    if type(refreshList) ~= "table" then return end
    for i = 1, #refreshList do
        if type(refreshList[i]) == "function" then pcall(refreshList[i]) end
    end
end

local function BuildAboutPage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local function Paragraph(text)
        local row, height = W:Spacer(parent, y, 56)
        if not EllesmereUI.IsSearchPrebuild() then
            local PP = EllesmereUI.PanelPP
            local pad = EllesmereUI.CONTENT_PAD + 20
            local label = EllesmereUI.MakeFont(row, 13, nil, 1, 1, 1, 0.8)
            PP.Point(label, "TOPLEFT", row, "TOPLEFT", pad, -8)
            label:SetWidth(math.max(100, parent:GetWidth() - pad * 2))
            label:SetJustifyH("LEFT")
            label:SetWordWrap(true)
            local displayText = EllesmereUI.L(text)
            label:SetText(displayText)
            height = math.ceil(label:GetStringHeight()) + 20
            PP.Size(row, parent:GetWidth(), height)
            row._isSpacer = nil
            row._labelText = text
            row._labelTextLoc = displayText ~= text and displayText or nil
        end
        y = y - height
    end
    local function Section(title, text)
        local _, height = W:SectionHeader(parent, title, y)
        y = y - height
        Paragraph(text)
    end

    local version
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if type(getMetadata) == "function" then
        local ok, value = pcall(getMetadata, addonName, "Version")
        if ok then version = ns.String(value) end
    end
    local versionText = version and version ~= "" and ("Version " .. version .. ". ") or ""
    Section("QUEST TRACKER EXTENSION", versionText ..
        "Adds Wowhead links, objective colors, independent notification messages and sounds, and an optional navigation-tracked quest item. Supports Retail and Forever.")
    Section("HELP", "See README.md for setup and details. Use /eqtx status for capability diagnostics.")
    return math.abs(y)
end

local function BuildPage(page, parent, yOffset)
    local W, y = EllesmereUI.Widgets, yOffset
    local prebuild = EllesmereUI.IsSearchPrebuild and EllesmereUI.IsSearchPrebuild()
    if not prebuild then
        if page == "Quest Item" and type(EllesmereUI.SetContentHeader) == "function" and ns.BuildQuestItemHeader then
            EllesmereUI:SetContentHeader(ns.BuildQuestItemHeader)
        elseif type(EllesmereUI.ClearContentHeader) == "function" then
            EllesmereUI:ClearContentHeader()
        end
    end
    local function Row(left, right)
        local _, height = W:DualRow(parent, y, left, right)
        y = y - height
    end
    local function Section(text)
        local _, height = W:SectionHeader(parent, text, y)
        y = y - height
    end
    local function ToggleConfig(label, key, tip, extraLock, lockTip, onChanged)
        local function Disabled() return (extraLock and extraLock()) or false end
        return { type = "toggle", text = label, tooltip = tip,
            disabled = Disabled, disabledTooltip = lockTip or "This option is unavailable on this client.",
            getValue = function() return addon.Settings()[key] end,
            setValue = function(value)
                if Disabled() then return end
                addon.Settings()[key] = value
                if onChanged then onChanged() else Changed() end
                RefreshWidgetStates()
            end,
        }
    end
    local function Toggle(label, key, tip, extraLock, lockTip, onChanged)
        Row(ToggleConfig(label, key, tip, extraLock, lockTip, onChanged))
    end
    local function Note(label, tip)
        Row({ type = "spacer", text = label, tooltip = tip })
    end

    if page == "General" then
        Section("WOWHEAD")
        local function NoMenus() return not ns.HasMenus() end
        local function DatabaseLocked() return NoMenus() or not addon.Settings().wowhead end
        Row(ToggleConfig("Wowhead URL menus", "wowhead", "Add a copyable URL to supported quest-log and tracker right-click menus.",
            NoMenus, "This client must support tagged native menus."),
        { type = "dropdown", text = "Wowhead database", tooltip = "Auto uses Retail on Retail and Classic on Forever. Custom content may not exist on Wowhead.",
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
            function() return not ns.HasObjectives() end, "This client must provide ordinary native objective trackers and secure post-hooks.")
        local function ColorLocked() return not addon.Settings().objectiveColors or not ns.HasObjectives() end
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
        Section("QUEST MESSAGE NOTIFICATIONS")
        local function NotificationLocked() return not ns.HasQuestLog() end
        local messageToggle = ToggleConfig("Notification messages", "messages",
            "Send formatted quest status updates to your selected local and shared destinations.",
            function() return not ns.HasQuestLog() end, "This client must provide quest-log APIs.")
        local function DestinationsLocked() return NotificationLocked() or not addon.Settings().messages end
        local function GetDestination(key) return addon.Settings().notificationDestinations[key] == true end
        local function SetDestination(key, value)
            key = ns.String(key)
            if not key then return end
            if DestinationsLocked() or ns.Boolean(value) == nil or addon.Settings().notificationDestinations[key] == nil then return end
            if value and not ns.NotificationDestinationSupported(key) then return end
            addon.Settings().notificationDestinations[key] = value
            ns.RefreshNotificationOutput()
            RefreshWidgetStates()
        end
        if type(EllesmereUI.BuildVisOptsCBDropdown) == "function" then
            local destinationDropdown = { type = "dropdown", text = "Message destinations",
                tooltip = "Choose any combination of Local chat, Local toast, Party, Raid, Instance/Battleground and Guild. Shared destinations send real chat messages; unavailable groups are skipped. Empty means no messages.",
                values = { selection = "Choose destinations" }, order = { "selection" },
                disabled = DestinationsLocked, disabledTooltip = "Enable notification messages first.",
                getValue = function() return "selection" end, setValue = function() end }
            local row, height = W:DualRow(parent, y, messageToggle, destinationDropdown)
            y = y - height
            if not prebuild then
                local region = row._rightRegion
                local items = {}
                for _, entry in ipairs(ns.NotificationDestinations) do
                    local key = entry.key
                    items[#items + 1] = { key = key, label = entry.label, tooltip = entry.tooltip,
                        lockedFn = function() return not GetDestination(key) and not ns.NotificationDestinationSupported(key) end,
                        lockedTooltip = "This client does not provide the required chat APIs or group-category support." }
                end
                if region._control then region._control:Hide() end
                local dropdown, refresh = EllesmereUI.BuildVisOptsCBDropdown(region, 230, region:GetFrameLevel() + 2,
                    items, GetDestination, SetDestination, nil, 6, nil, nil, nil,
                    { noAllLabel = true, disabled = DestinationsLocked, disabledTooltip = "Enable notification messages first." })
                dropdown:SetPoint("RIGHT", region, "RIGHT", -20, 0)
                region._control = dropdown
                region._lastInline = nil
                if type(EllesmereUI.RegisterWidgetRefresh) == "function" then EllesmereUI.RegisterWidgetRefresh(refresh) end
            end
        else
            Row(messageToggle)
            -- Older EUI builds retain every destination as independent toggles.
            local function DestinationToggle(entry)
                local key = entry.key
                local function LockedDestination()
                    return DestinationsLocked() or (not GetDestination(key) and not ns.NotificationDestinationSupported(key))
                end
                return { type = "toggle", text = entry.label, tooltip = entry.tooltip,
                    disabled = LockedDestination, disabledTooltip = "Enable notification messages on a client with the required destination APIs.",
                    getValue = function() return GetDestination(key) end,
                    setValue = function(value) SetDestination(key, value) end }
            end
            for i = 1, #ns.NotificationDestinations, 2 do
                Row(DestinationToggle(ns.NotificationDestinations[i]),
                    ns.NotificationDestinations[i + 1] and DestinationToggle(ns.NotificationDestinations[i + 1]) or nil)
            end
        end
        Section("LOCAL TOAST APPEARANCE & POSITION")
        local function ToastLocked()
            return NotificationLocked() or not addon.Settings().messages
                or not addon.Settings().notificationDestinations.toast
        end
        Row({ type = "slider", text = "Toast opacity", min = 0, max = 100, step = 1,
            tooltip = "Adjust the opacity of the local toast background only (0–100%).",
            disabled = ToastLocked, disabledTooltip = "Enable Notification messages and select Local toast first.",
            getValue = function() return addon.Settings().toastOpacity * 100 end,
            setValue = function(value)
                if ToastLocked() or not ns.Number(value) then return end
                addon.Settings().toastOpacity = ns.Clamp(value, 0, 100, 92) / 100
                ns.RefreshToastAppearance()
            end,
        }, { type = "colorpicker", text = "Toast heading color", hasAlpha = false,
            tooltip = "Color of the toast status heading.",
            disabled = ToastLocked, disabledTooltip = "Enable Notification messages and select Local toast first.",
            getValue = function()
                local c = addon.Settings().toastAccentColor
                return c.r, c.g, c.b, 1
            end,
            setValue = function(r, g, b)
                if ToastLocked() or not ns.Number(r) or not ns.Number(g) or not ns.Number(b) then return end
                addon.Settings().toastAccentColor = { r = ns.Clamp(r, 0, 1, 0.9),
                    g = ns.Clamp(g, 0, 1, 0.62), b = ns.Clamp(b, 0, 1, 0.16) }
                ns.RefreshToastAppearance()
            end,
        })
        Row({ type = "dropdown", text = "Toast text alignment",
            values = { left = "Left", center = "Center", right = "Right" }, order = { "left", "center", "right" },
            tooltip = "Align both the status heading and message body.",
            disabled = ToastLocked, disabledTooltip = "Enable Notification messages and select Local toast first.",
            getValue = function() return addon.Settings().toastTextAlign end,
            setValue = function(value)
                if ToastLocked() or not ns.String(value)
                    or (value ~= "left" and value ~= "center" and value ~= "right") then return end
                addon.Settings().toastTextAlign = value
                ns.RefreshToastAppearance()
            end,
        })
        Row({ type = "labeledButton", text = "Toast position", buttonText = "Reset",
            tooltip = "Reset the local toast anchor. Move it in EUI Edit/Unlock Mode using Quest Notification Toast.",
            disabled = function() return ToastLocked() or ns.InCombat() end,
            disabledTooltip = "Enable Local toast and leave combat first.",
            onClick = function() if not ToastLocked() and not ns.InCombat() then ns.ResetToastPosition() end end,
        })
        local function SoundLocked()
            return not ns.HasQuestLog() or not addon.Settings().sounds
                or (type(PlaySound) ~= "function" and type(PlaySoundFile) ~= "function")
        end
        local function SoundSelector(label, getSound, setSound, disabled, tip)
            local selected = getSound()
            local values, order = ns.SoundKitOptions(true, selected)
            local function PreviewDisabled()
                return disabled() or (type(PlaySound) ~= "function" and type(PlaySoundFile) ~= "function")
                    or getSound() == "none" or not ns.SoundAvailable(getSound())
            end
            Row({ type = "dropdown", text = label, tooltip = tip, values = values, order = order,
                disabled = disabled, disabledTooltip = "Enable notification sounds first.",
                getValue = getSound,
                setValue = function(value)
                    if disabled() or not ns.String(value) or not values[value] then return end
                    if value ~= "none" and not ns.SoundAvailable(value) then return end
                    setSound(value)
                end,
            }, { type = "labeledButton", text = "", buttonText = "Play",
                tooltip = "Play this sound using the currently selected WoW audio channel.",
                disabled = PreviewDisabled,
                disabledTooltip = "Choose an available sound and enable notification sounds.",
                onClick = function()
                    if PreviewDisabled() then return end
                    ns.PreviewNotificationSound(getSound())
                end,
            })
        end
        Section("QUEST SOUND NOTIFICATIONS")
        Row(ToggleConfig("Notification sounds", "sounds", "Play a sound for selected changes, at most once per second.",
            function() return NotificationLocked() or not ns.HasNotificationSounds() end,
            "This client must provide a supported sound."),
        { type = "dropdown", text = "Sound output channel", values = ns.SoundChannels,
            order = { "Master", "SFX", "Music", "Ambience", "Dialog" },
            tooltip = "Route notification sounds through this WoW audio channel. Volume and mute follow the game's settings for that channel; Master is the default.",
            disabled = SoundLocked, disabledTooltip = "Enable notification sounds first.",
            getValue = function() return addon.Settings().soundChannel end,
            setValue = function(value)
                if SoundLocked() or not ns.String(value) or not ns.SoundChannels[value] then return end
                addon.Settings().soundChannel = value
            end,
        })
        Section("QUEST STATUS SOUNDS")
        local statuses = { { "progress", "Objective progress" }, { "ready", "Ready for turn-in" } }
        for _, option in ipairs(statuses) do
            local key, label = option[1], option[2]
            local function StatusLocked()
                return NotificationLocked() or not addon.Settings().sounds or not ns.StatusSupported(key)
            end
            SoundSelector(label .. " sound",
                function() return addon.Settings().statusSounds[key] end,
                function(value) addon.Settings().statusSounds[key] = value end, StatusLocked,
                "Choose this status's sound. None disables this status's messages and sound; an unavailable sound stays silent.")
        end
    elseif page == "Quest Item" then
        Section("NAVIGATION-TRACKED QUEST ITEM")
        local function ItemUnavailable() return not addon.Capabilities().questItem end
        local function ItemLocked() return not addon.Settings().questItem or ItemUnavailable() end
        local function ItemChanged() if ns.RefreshQuestItem then ns.RefreshQuestItem() end end
        Toggle("Show tracked quest item", "questItem", "Show the item for the quest selected for Blizzard navigation (super-tracked). Distance and selection update out of combat only.",
            ItemUnavailable, "This feature requires readable quest distance, tracking/item APIs, a timer and a secure item template.", ItemChanged)
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
        local borderValues, borderOrder = ns.ItemBorderOptions()
        local function BordersLocked() return ItemLocked() or not ns.HasItemBorders() end
        local function BorderOff() return BordersLocked() or addon.Settings().itemBorderTexture == "none" end
        Row(ToggleConfig("Retail style background", "itemRetailArt", "Show Blizzard's decorative extra-action artwork. This is independent of the icon border.",
            ItemLocked, "Enable the quest-item button first.", ItemChanged),
        { type = "slider", text = "Button size", min = 24, max = 112, step = 1,
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
        }, { type = "slider", text = "Border thickness / size", min = 1, max = 4, step = 1,
            tooltip = "Solid uses pixel thickness (1–4). Textured borders use EUI's four size steps.",
            disabled = BorderOff, disabledTooltip = "Choose a border style other than None first.",
            getValue = function() return addon.Settings().itemBorderSize end,
            setValue = function(value)
                if BorderOff() or not ns.Number(value) then return end
                addon.Settings().itemBorderSize = math.floor(ns.Clamp(value, 1, 4, 1) + 0.5); ItemChanged()
            end,
        })
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
        Section("PROXIMITY")
        Row({ type = "slider", text = "Quest proximity (yards)", min = 1, max = 1000, step = 1,
            tooltip = "Show inside the super-tracked quest's highlighted area, or at or below this navigation distance in yards (1–1000, default 100), on both Retail and Forever. If the area check is unavailable or unreadable, only valid navigation distance qualifies. Changes apply out of combat.",
            disabled = ItemLocked, disabledTooltip = "Enable the quest-item button first.",
            getValue = ns.ItemProximityYards,
            setValue = function(value)
                if ItemLocked() or not ns.Number(value) then return end
                addon.Settings().itemProximityYards = math.floor(ns.Clamp(value, 1, 1000, 100) + 0.5); ItemChanged()
            end,
        })
        Section("POSITION")
        Row({ type = "labeledButton", text = "Button position", buttonText = "Reset", tooltip = "Return the item button to its default position. Move it with EUI Edit Mode; right-drag is the fallback when that API is unavailable.",
            disabled = function() return ItemLocked() or ns.InCombat() end, disabledTooltip = "Enable the tracked quest item and leave combat first.",
            onClick = function() if not ItemLocked() and not ns.InCombat() then addon.ResetItemPosition() end end,
        })
        -- Note("Move with EUI Edit Mode", "Enable the quest-item button, enter EUI Edit/Unlock Mode, and move Tracked Quest Item. A non-clickable preview appears even without an available item. Save & Exit commits; Exit Without Saving or Discard restores the previous position.")
        -- Note("Combat keeps the last configured item", "Secure item, size, border and proximity changes wait until combat ends. Native visibility conditions such as combat and group state remain live through a secure driver.")
        -- Note("Blizzard's Extra Action Button is preserved", "This extension has its own button. EUI's quest-item hotkey also remains unchanged.")
    elseif page == "About" then
        return BuildAboutPage(parent, yOffset)
    else
        Section("SUPPORTED FEATURES")
        Note("About information unavailable", "Open the About page in a current EllesmereUI options build.")
    end
    return math.abs(y)
end

function ns.RegisterOptions()
    if ns.optionsRegistered then return true end
    local result = EllesmereUIExtend.RegisterModule({ key = "QuestTracker", title = "Quest Tracker",
            description = "Quest links, objective colors, notifications and the navigation-tracked quest item.",
            pages = { "General", "Notifications", "Quest Item", "About" }, buildPage = BuildPage,
            getHeaderBuilder = function(page)
                if page == "Quest Item" and type(EllesmereUI.SetContentHeader) == "function" then
                    return ns.BuildQuestItemHeader
                end
            end,
            onPageCacheRestore = function(page)
                if page == "Quest Item" and ns.RefreshQuestItemHeader then ns.RefreshQuestItemHeader(true) end
            end,
            onReset = function() addon.Reset() end,
    })
    ns.optionsRegistered = result == true
    return ns.optionsRegistered
end

ns.RegisterOptions()
