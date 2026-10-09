local _, private = ...
local addon = EllesmereUIExtendNameplates
if not addon then return end

local PLUGIN_ID = "EllesmereUIExtend"
local MAX_RULES = addon.MaxRules or 12
local rulesHeaderBuilder, rulesPreview

local UNIT_TYPES = { any = "Any unit", player = "Player", npc = "NPC", pet = "Player-controlled pet", creature = "Any creature" }
local UNIT_ORDER = { "any", "player", "npc", "pet", "creature" }
local REACTIONS = { any = "Any reaction", enemy = "Enemy", friendly = "Friendly", neutral = "Neutral" }
local REACTION_ORDER = { "any", "enemy", "friendly", "neutral" }
local CLASSIFICATIONS = { any = "Any rank", normal = "Normal", elite = "Elite", rare = "Rare", rareelite = "Rare Elite", boss = "Boss", minus = "Minor" }
local CLASSIFICATION_ORDER = { "any", "normal", "elite", "rare", "rareelite", "boss", "minus" }
local TARGETS = { any = "Any target state", yes = "Current target", no = "Not current target", none = "No target selected" }
local TARGET_ORDER = { "any", "yes", "no", "none" }
local THREATS = { any = "Any threat", nonTank = "Non-tank threat", tank = "Tank threat", me = "Threat on me" }
local THREAT_ORDER = { "any", "nonTank", "tank", "me" }
local PLAYER_COMBAT = { any = "Any combat state", inCombat = "In combat", outOfCombat = "Out of combat" }
local PLAYER_COMBAT_ORDER = { "any", "inCombat", "outOfCombat" }
local INSTANCES = { any = "Any instance type", world = "Open world", dungeon = "Dungeon", raid = "Raid",
    battleground = "Battleground", arena = "Arena", scenario = "Scenario", delve = "Delve" }
local INSTANCE_ORDER = { "any", "world", "dungeon", "raid", "battleground", "arena", "scenario", "delve" }
local CONDITION_TIPS = {
    unitType = {
        player = "Player characters.", npc = "Non-player characters, excluding player-controlled pets.",
        pet = "Player-controlled pets.", creature = "NPCs and player-controlled pets.",
    },
    reaction = {
        friendly = "Units friendly to you.", enemy = "Units you can attack, excluding neutral units.",
        neutral = "Neutral units, including those you can attack.",
    },
    classification = {
        normal = "Units with normal classification.", elite = "Elite units.", rare = "Rare units.",
        rareelite = "Rare elite units.", boss = "Units classified as bosses.", minus = "Minor units.",
    },
    target = {
        yes = "Your current target.", no = "Other units while you have a target selected.",
        none = "Units while you have no target selected.",
    },
    threat = {
        nonTank = "A damage dealer or healer holds this unit's aggro.",
        tank = "A tank holds this unit's aggro.", me = "You hold this unit's aggro, regardless of your role.",
    },
    playerCombat = { inCombat = "Your character is in combat.", outOfCombat = "Your character is out of combat." },
    instanceType = {
        world = "Outside an instance.", dungeon = "Inside a dungeon.", raid = "Inside a raid instance.",
        battleground = "Inside a battleground.", arena = "Inside an arena. Unavailable on WoW Forever.",
        scenario = "Inside a scenario, excluding delves. Unavailable on WoW Forever.",
        delve = "Inside a delve, even after completion. Unavailable on WoW Forever.",
    },
    castState = {
        none = "Units with no active cast or channel.",
        casting = "Any active cast, including channels and empowered casts. Custom color applies to all cast states.",
        channel = "Units channeling a spell, excluding empowered casts.", empowered = "Units casting an empowered spell.",
        interruptible = "Cast color when your interrupt is ready. Other appearance settings apply to all active casts.",
        interruptOnCD = "Cast color when your interrupt is on cooldown. Other appearance settings apply to all active casts.",
        uninterruptible = "Cast color for spells that cannot be interrupted. Other appearance settings apply to all active casts.",
    },
}
local ACTION_TIPS = {
    ["Add Rule"] = "Add a current-target rule at the top of the list.",
    ["Copy Rule"] = "Duplicate this rule and place the copy directly below it.",
    ["Delete Rule"] = "Delete this rule after confirmation. At least one rule must remain.",
    ["Move Rule Up"] = "Move this rule up to give it higher priority.",
    ["Move Rule Down"] = "Move this rule down to give it lower priority.",
}
local CAST_STATES = {
    any = "Any cast state", none = "Not casting", casting = "Casting", channel = "Channeling",
    empowered = "Empowered cast", interruptible = "Interruptible cast", interruptOnCD = "Interrupt on CD", uninterruptible = "Uninterruptible cast",
}
local CAST_ORDER = { "any", "none", "casting", "channel", "empowered", "interruptible", "interruptOnCD", "uninterruptible" }

local CUSTOM_CAST_STATES = { interruptible = true, interruptOnCD = true, uninterruptible = true }
local CUSTOM_CAST_STYLE_TIP = "Enable EUI or Classic WoW UI nameplate style and reload the UI to use this cast-color state."
local function GetBarTextureOptions()
    local np = _G.EllesmereNameplates_NS
    local names = np and np.healthBarTextureNames or {}
    local order = np and np.healthBarTextureOrder or {}
    local paths = np and np.healthBarTextures or {}
    local values = { eui = "Use EUI texture", flat = "Flat" }
    local keys = { "eui", "flat", "---" }
    local seen = { eui = true, flat = true }
    for _, key in ipairs(order) do
        if key == "---" then
            if keys[#keys] ~= "---" then keys[#keys + 1] = key end
        else
            if not seen[key] then
                values[key] = names[key] or key
                keys[#keys + 1] = key
                seen[key] = true
            end
        end
    end
    values._menuOpts = {
        itemHeight = 28,
        background = function(key) return paths[key] end,
    }
    return values, keys
end

local function DB()
    return addon.GetSettings()
end

local function GetRule()
    local db = DB()
    local index = math.max(1, math.min(tonumber(db.selectedRule) or 1, #db.rules))
    db.selectedRule = index
    return db.rules[index], index
end

local function Changed()
    addon.Refresh()
end

local CopyRule = private.CopyTable

local function Rebuild()
    local key = EllesmereUI.GetPluginModuleKey(PLUGIN_ID, "NameplateStyle")
    if key then EllesmereUI:InvalidateModulePageCache(key) end
    EllesmereUI:RefreshPage(true)
end

local function ExportRuleSet()
    local code, err = addon.ExportRuleSet()
    if not code then
        EllesmereUI.PrintError(err or "Could not export Extend Nameplates rules.")
        return
    end
    EllesmereUI:ShowCopyPopup("Export Nameplate Rules", "Copy this code to share the rule set between characters.", code)
end

local function ImportRuleSet()
    local function OnImport(code)
        local ok, err = addon.ImportRuleSet(code)
        if not ok then
            EllesmereUI.PrintError(err or "Could not import Extend Nameplates rules.")
            return
        end
        Rebuild()
        EllesmereUI.Print("Extend Nameplates rules imported.")
    end
    if EllesmereUI.ShowImportStringPopup then
        EllesmereUI:ShowImportStringPopup(
            "Import Nameplate Rules",
            "Paste a rule-set code from another character. Import replaces this profile's current rules.",
            "Import Rules", OnImport)
    elseif EllesmereUI.ShowInputPopup then
        -- Older EUI builds do not yet include the scrollable import/export-style
        -- popup. Keep import usable there with the standard one-line code field.
        EllesmereUI:ShowInputPopup({
            title = "Import Nameplate Rules",
            message = "Paste the complete rule-set code. Import replaces this profile's current rules.",
            placeholder = "Paste rule-set code here...",
            confirmText = "Import Rules",
            cancelText = "Cancel",
            maxLetters = addon.RuleSetMaxCodeLength or 64000,
            onConfirm = OnImport,
        })
    else
        EllesmereUI.PrintError("Update EllesmereUI to import Extend Nameplates rule sets.")
    end
end

local function AttachTooltip(control, text)
    if not control or not text or type(control.HookScript) ~= "function" then return end
    -- Keep EUI's existing hover styling and click handlers.
    control:HookScript("OnEnter", function() EllesmereUI.ShowWidgetTooltip(control, text) end)
    control:HookScript("OnLeave", function() EllesmereUI.HideWidgetTooltip() end)
end

local function ButtonTooltips(row, ...)
    -- Search prebuild rows are frameless placeholders, not native controls.
    if EllesmereUI.IsSearchPrebuild() then return end
    for index, button in ipairs({ row:GetChildren() }) do
        AttachTooltip(button, select(index, ...))
    end
end

local function BuildSharingPage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local _, h
    _, h = W:SectionHeader(parent, "SHARE THIS PROFILE'S RULES", y); y = y - h
    _, h = W:SectionHeader(parent,
        "Export creates a copyable code. Import replaces the rules in the selected character profile.", y)
    y = y - h
    local row
    row, h = W:WideDualButton(parent, "Export Rule Set", "Import Rule Set", y,
        ExportRuleSet, ImportRuleSet, 230)
    ButtonTooltips(row, "Copy a code containing this profile's rules, not its character assignments.",
        "Replace this profile's rules with a shared code. Other characters using this profile are also affected.")
    y = y - h
    return math.abs(y)
end

local function NewRule(index)
    return {
        name = "Custom Rule " .. index,
        enabled = true,
        conditions = { unitType = {}, reaction = {}, classification = {}, target = { yes = true }, castState = {} },
        style = { healthColorEnabled = true, healthColor = { r = 1, g = 0.72, b = 0.15 }, scale = 100, opacity = 100, borderSize = 2, borderColor = { r = 1, g = 0.72, b = 0.15 }, texture = "eui" },
    }
end

local function BuildStylePage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local _, h
    local db = DB()
    local rule, selected = GetRule()
    local barTextureValues, barTextureOrder = GetBarTextureOptions()
    local borderTextureValues, borderTextureOrder = addon.GetBorderStyleOptions()
    local glowValues, glowOrder = addon.GetRuleGlowOptions()
    local previewUpdates, notifyChanged = {}, Changed
    local function Changed()
        notifyChanged()
        for _, update in ipairs(previewUpdates) do update() end
    end

    local function GlobalLocked() return DB().enabled == false end
    local function RuleLocked()
        return GlobalLocked() or rule.enabled == false or GetRule().enabled == false
    end
    local function LockTip()
        if GlobalLocked() then return "Enable Nameplate styling to edit rules." end
        return "Enable this rule to edit its settings."
    end
    local function LockConfig(cfg, scope)
        if not cfg or cfg.type == "spacer" then return cfg end
        local locked = scope == "global" and GlobalLocked or RuleLocked
        local disabled, disabledTip, setValue = cfg.disabled, cfg.disabledTooltip, cfg.setValue
        cfg.disabled = function() return locked() or (disabled and disabled()) or false end
        cfg.disabledTooltip = function()
            if locked() then return LockTip() end
            if type(disabledTip) == "function" then return disabledTip() end
            return disabledTip
        end
        if setValue then
            cfg.setValue = function(...)
                if cfg.disabled() then return end
                return setValue(...)
            end
        end
        return cfg
    end
    local function LockedRow(left, right, leftScope, rightScope)
        return W:DualRow(parent, y, LockConfig(left, leftScope), LockConfig(right, rightScope))
    end
    local function AttachLock(control, locked, tip, label)
        local block = CreateFrame("Frame", nil, control:GetParent())
        block:SetAllPoints(control)
        block:SetFrameLevel(control:GetFrameLevel() + 10)
        block:EnableMouse(true)
        block:SetScript("OnEnter", function() EllesmereUI.ShowWidgetTooltip(control, tip()) end)
        block:SetScript("OnLeave", function() EllesmereUI.HideWidgetTooltip() end)
        local function Update()
            local off = locked()
            control:SetAlpha(off and 0.3 or 1)
            control:EnableMouse(not off)
            if label then label:SetAlpha(off and 0.3 or 1) end
            if off then block:Show() else block:Hide() end
        end
        EllesmereUI.RegisterWidgetRefresh(Update)
        Update()
    end

    if not EllesmereUI.IsSearchPrebuild() and EllesmereUI.SetContentHeader then
        rulesHeaderBuilder = function(headerParent, headerWidth)
            local height, preview = addon.BuildRulePreview(headerParent, headerWidth, GetRule,
                function() return GlobalLocked() or GetRule().enabled == false end)
            if preview then
                rulesPreview = preview
                previewUpdates[#previewUpdates + 1] = preview.Update
                EllesmereUI.RegisterWidgetRefresh(preview.Update)
            end
            return height
        end
        EllesmereUI:SetContentHeader(rulesHeaderBuilder)
    end

    local function GlowRow(prefix, off, barTip)
        local title = prefix == "health" and "Health" or "Cast"
        local function Locked()
            return RuleLocked() or DB() ~= db or GetRule() ~= rule or off() or not addon.SupportsRuleGlows()
        end
        local function Tip()
            if RuleLocked() then return LockTip() end
            if not addon.SupportsRuleGlows() then return "Update EllesmereUI to use border glows." end
            return barTip
        end
        local function NoGlow()
            local value = rule.style[prefix .. "GlowStyle"] or 0
            return Locked() or value == 0 or not addon.ValidateRuleGlowStyle(value)
        end
        local row, height = LockedRow({ type = "dropdown", text = title .. " border glow", values = glowValues, order = glowOrder,
            disabled = Locked, disabledTooltip = Tip,
            getValue = function()
                local value = GetRule().style[prefix .. "GlowStyle"] or 0
                return addon.ValidateRuleGlowStyle(value) and value or 0
            end,
            setValue = function(value)
                value = tonumber(value) or 0
                if not addon.ValidateRuleGlowStyle(value) then return end
                GetRule().style[prefix .. "GlowStyle"] = value; Changed(); Rebuild()
            end,
            tooltip = (prefix == "health" and "Add an animated glow around the health bar. No custom border is required."
                or "Add an animated glow around the cast bar. Replaces EUI's Important Cast Glow while active.")
                .. " Retail may use Pixel Glow when Shine cannot animate.",
        }, { type = "colorpicker", text = title .. " glow color", hasAlpha = false,
            tooltip = "Choose the " .. title:lower() .. " bar's glow color.",
            disabled = NoGlow, disabledTooltip = function() return Locked() and Tip() or "Choose a border glow first." end,
            getValue = function()
                local c = addon.GetRuleGlowColor(GetRule().style, prefix)
                return c.r, c.g, c.b, 1
            end,
            setValue = function(r, g, b) GetRule().style[prefix .. "GlowColor"] = { r = r, g = g, b = b }; Changed() end,
        })
        if not EllesmereUI.IsSearchPrebuild() and EllesmereUI.BuildInlineCog then
            local function NotPixel() return Locked() or rule.style[prefix .. "GlowStyle"] ~= 1 end
            local function NotShine() return Locked() or rule.style[prefix .. "GlowStyle"] ~= 3 end
            local function Set(key, value, shine)
                if (shine and NotShine()) or (not shine and NotPixel()) then return end
                rule.style[prefix .. key] = value
                Changed()
            end
            EllesmereUI.BuildInlineCog(row._leftRegion, {
                title = title .. " glow settings", captureRegion = row._leftRegion,
                tip = "Adjust the glow's appearance and animation.",
                disabled = function() return Locked() or (NotPixel() and NotShine()) end,
                disabledTooltip = function() return Locked() and Tip() or "Choose Pixel Glow or Auto-Cast Shine first." end,
                rows = rule.style[prefix .. "GlowStyle"] == 3 and {
                    { type = "slider", label = "Sparkle size (%)", min = 50, max = 200, step = 5,
                        disabled = NotShine, disabledTooltip = "Choose Auto-Cast Shine first.",
                        tooltip = "Size of each sparkle. 100% uses EUI's normal size.",
                        get = function() return rule.style[prefix .. "GlowShineSize"] or 100 end,
                        set = function(value) Set("GlowShineSize", value, true) end },
                } or {
                    { type = "slider", label = "Lines", min = 2, max = 16, step = 1, disabled = NotPixel,
                        disabledTooltip = "Choose Pixel Glow first.", tooltip = "Number of glowing lines around the bar.",
                        get = function() return rule.style[prefix .. "GlowLines"] or 8 end,
                        set = function(value) Set("GlowLines", value) end },
                    { type = "slider", label = "Thickness", min = 1, max = 4, step = 1, disabled = NotPixel,
                        disabledTooltip = "Choose Pixel Glow first.", tooltip = "Thickness of the glowing lines.",
                        get = function() return rule.style[prefix .. "GlowThickness"] or 2 end,
                        set = function(value) Set("GlowThickness", value) end },
                    { type = "slider", label = "Speed", min = 1, max = 8, step = 1, disabled = NotPixel,
                        disabledTooltip = "Choose Pixel Glow first.", tooltip = "How fast the glow moves. Higher values are faster.",
                        get = function() return 9 - (rule.style[prefix .. "GlowSpeed"] or 4) end,
                        set = function(value) Set("GlowSpeed", 9 - value) end },
                    { type = "toggle", label = "Background", disabled = NotPixel,
                        disabledTooltip = "Choose Pixel Glow first.", tooltip = "Show a colored background behind the glow.",
                        get = function() return rule.style[prefix .. "GlowBackground"] == true end,
                        set = function(value) Set("GlowBackground", value) end },
                    { type = "colorpicker", label = "Background Color",
                        disabled = function() return NotPixel() or rule.style[prefix .. "GlowBackground"] ~= true end,
                        disabledTooltip = "Enable Pixel Glow Background first.",
                        tooltip = "Choose the glow's background color.",
                        get = function()
                            local c = rule.style[prefix .. "GlowBackgroundColor"] or { r = 0, g = 0, b = 0 }
                            return c.r, c.g, c.b
                        end,
                        set = function(r, g, b)
                            if rule.style[prefix .. "GlowBackground"] ~= true then return end
                            Set("GlowBackgroundColor", { r = r, g = g, b = b })
                        end },
                },
            })
        end
        return height
    end

    _, h = W:SectionHeader(parent, "NAMEPLATE STYLING", y); y = y - h
    _, h = W:Toggle(parent, "Enable Nameplate styling", y,
        function() return DB().enabled ~= false end,
        function(value) DB().enabled = value; Changed(); Rebuild() end,
        "Apply this profile's rules. Off restores EUI styling and locks editing without deleting your rules.")
    y = y - h

    -- Search stores exact section names on first indexing. Keep them stable;
    -- the selector and name field below show the current rule's context.
    _, h = W:SectionHeader(parent, "RULE ORDER", y)
    y = y - h
    local labels, order = {}, {}
    for i, item in ipairs(db.rules) do
        local key = tostring(i)
        labels[key] = ("[%d] %s"):format(i, item.name or ("Rule " .. i))
        order[#order + 1] = key
    end
    _, h = LockedRow({
        type = "dropdown", text = "Edit rule", values = labels, order = order,
        getValue = function() return tostring(DB().selectedRule or 1) end,
        setValue = function(value)
            DB().selectedRule = tonumber(value) or 1
            Rebuild()
        end,
        tooltip = "Choose a rule to edit. Rules are checked from top to bottom; the first enabled match wins.",
    }, {
        type = "input",
        text = "Rule name",
        inputWidth = 260,
        inputStyle = "popup",
        tooltip = "Rename this rule. Press Enter or click outside to save.",
        getValue = function() return rule.name or ("Rule " .. selected) end,
        setValue = function(value)
            local name = value:gsub("|", ""):gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
            if name == "" or name == rule.name then return end
            -- Bind to this page's rule so a focus-loss commit cannot rename a newly selected rule.
            rule.name = name
            Rebuild()
        end,
    }, "global"); y = y - h
    local actions = {}
    local function Action(text, onClick)
        local locked = text == "Add Rule" and GlobalLocked or RuleLocked
        actions[#actions + 1] = { text = text, tooltip = ACTION_TIPS[text], locked = locked, onClick = function()
            if locked() then return end
            onClick()
        end }
    end
    Action("Add Rule", function()
        local current = DB()
        if #current.rules >= MAX_RULES then return end
        table.insert(current.rules, 1, NewRule(#current.rules + 1))
        current.selectedRule = 1
        Rebuild()
        Changed()
    end)
    Action("Copy Rule", function()
        local current = DB()
        if #current.rules >= MAX_RULES then return end
        local index = current.selectedRule
        local source = current.rules[index]
        if not source then return end
        local copy = CopyRule(source)
        local baseName = source.name or ("Rule " .. index)
        local name = baseName .. " Copy"
        local suffix = 2
        local used = {}
        for _, item in ipairs(current.rules) do used[item.name] = true end
        while used[name] do
            name = baseName .. " Copy " .. suffix
            suffix = suffix + 1
        end
        copy.name = name
        table.insert(current.rules, index + 1, copy)
        current.selectedRule = index + 1
        Rebuild()
        Changed()
    end)
    Action("Delete Rule", function()
        local current = DB()
        if #current.rules <= 1 then return end
        local rule = current.rules[current.selectedRule]
        if not rule then return end
        if not EllesmereUI.ShowConfirmPopup then
            EllesmereUI.PrintError("This EUI version does not provide rule-delete confirmation.")
            return
        end
        EllesmereUI:ShowConfirmPopup({
            title = "Delete Nameplate Rule?",
            message = ("Delete '%s'? This cannot be undone."):format(rule.name or "Unnamed Rule"),
            confirmText = "Delete Rule",
            cancelText = "Keep Rule",
            onConfirm = function()
                -- A popup can remain open while the user changes character profiles
                -- or edits rules. Delete only the rule that opened this dialog.
                local latest = DB()
                if latest ~= current or GlobalLocked() or rule.enabled == false or #latest.rules <= 1 then return end
                local index
                for i, candidate in ipairs(latest.rules) do
                    if candidate == rule then index = i; break end
                end
                if not index then return end
                table.remove(latest.rules, index)
                latest.selectedRule = math.min(index, #latest.rules)
                Rebuild()
                Changed()
            end,
        })
    end)
    Action("Move Rule Up", function()
        local current = DB()
        local index = current.selectedRule
        if index <= 1 then return end
        current.rules[index], current.rules[index - 1] = current.rules[index - 1], current.rules[index]
        current.selectedRule = index - 1
        Rebuild()
        Changed()
    end)
    Action("Move Rule Down", function()
        local current = DB()
        local index = current.selectedRule
        if index >= #current.rules then return end
        current.rules[index], current.rules[index + 1] = current.rules[index + 1], current.rules[index]
        current.selectedRule = index + 1
        Rebuild()
        Changed()
    end)
    if EllesmereUI.IsSearchPrebuild() then
        -- Index each action through the frameless factory without creating UI.
        for i, action in ipairs(actions) do
            local _, height = W:Button(parent, action.text, y, action.onClick)
            if i == 1 then h = height end
        end
    else
        -- One search/layout row owns all five controls, so search cannot split
        -- independently tagged wrappers into separate vertical positions.
        local row
        row, h = W:Button(parent, actions[1].text, y, actions[1].onClick)
        local PP, pad = EllesmereUI.PanelPP, EllesmereUI.CONTENT_PAD
        local width, gap = parent:GetWidth() - pad * 2, 8
        local buttonWidth = (width - gap * (#actions - 1)) / #actions
        PP.Size(row, width, h)
        PP.Point(row, "TOPLEFT", parent, "TOPLEFT", pad, y)
        local firstButton = row:GetChildren()
        local names, localizedNames = {}, {}
        for i, action in ipairs(actions) do
            names[i], localizedNames[i] = action.text, EllesmereUI.L(action.text)
            local button = firstButton
            if i > 1 then
                button = CreateFrame("Button", nil, row)
                button:SetFrameLevel(row:GetFrameLevel() + 1)
                EllesmereUI.MakeStyledButton(button, action.text, 13, EllesmereUI.RB_COLOURS, action.onClick)
                local wi = EllesmereUI._widgetInternals
                if wi and wi.IndexSlotForSearch then
                    wi.IndexSlotForSearch(parent, action.text, action.tooltip)
                elseif EllesmereUI._RegisterSearchEntry then
                    local section = parent._currentSection and parent._currentSection._sectionName
                    local selector = EllesmereUI._buildingSelector
                    EllesmereUI._RegisterSearchEntry(action.text, localizedNames[i], action.tooltip,
                        EllesmereUI._buildingModule, EllesmereUI._buildingPage, section,
                        selector and selector.setter, selector and selector.key)
                end
            end
            button:ClearAllPoints()
            PP.Size(button, buttonWidth, 32)
            PP.Point(button, "LEFT", row, "LEFT", (i - 1) * (buttonWidth + gap), 0)
            AttachTooltip(button, action.tooltip)
            AttachLock(button, action.locked, LockTip)
        end
        row._labelText = table.concat(names, " ")
        local localized = table.concat(localizedNames, " ")
        row._labelTextLoc = localized ~= row._labelText and localized or nil
    end
    y = y - h

    _, h = W:SectionHeader(parent, "MATCH CONDITIONS", y); y = y - h
    _, h = LockedRow({ type = "toggle", text = "Rule enabled",
        tooltip = "Use this rule when all its conditions match. Off keeps its settings but skips the rule.",
        getValue = function() return GetRule().enabled ~= false end,
        setValue = function(value) GetRule().enabled = value; Rebuild(); Changed() end,
    }, nil, "global")
    y = y - h

    local function ConditionMultiDropdown(label, key, values, keys, tooltip)
        local items = {}
        for _, value in ipairs(keys) do
            if value ~= "any" then
                local item = { key = value, label = values[value] }
                item.tooltip = CONDITION_TIPS[key] and CONDITION_TIPS[key][value]
                local requiresStyle = key == "castState" and CUSTOM_CAST_STATES[value]
                local unavailableInstance = function() return key == "instanceType" and not addon.SupportsInstanceType(value) end
                item.lockedFn = function() return RuleLocked() or (requiresStyle and not addon.SupportsCastColorStates()) or unavailableInstance() or false end
                item.lockedTooltip = function()
                    if RuleLocked() then return LockTip() end
                    if unavailableInstance() then return "This instance type is not available on WoW Forever." end
                    return CUSTOM_CAST_STYLE_TIP
                end
                items[#items + 1] = item
            end
        end
        local function GetSelection()
            local value = GetRule().conditions[key]
            if type(value) == "table" then return value end
            if type(value) == "string" and value ~= "any" then return { [value] = true } end
            return {}
        end
        return {
            text = label,
            tooltip = tooltip .. " Any selected option can match. Leave empty for Any.",
            items = items,
            emptyLabel = values.any,
            getSelected = function(option) return GetSelection()[option] == true end,
            setSelected = function(option, selected)
                if RuleLocked() then return end
                if key == "castState" and CUSTOM_CAST_STATES[option] and not addon.SupportsCastColorStates() then return end
                if key == "instanceType" and selected and not addon.SupportsInstanceType(option) then return end
                local current = GetRule()
                local value = GetSelection()
                current.conditions[key] = value
                value[option] = selected and true or nil
                if key == "castState" and selected and
                    (option == "empowered" or option == "interruptible" or option == "interruptOnCD" or option == "uninterruptible") then
                    -- A subtype does not expose the broad Casting checkbox as
                    -- selected. Selecting Casting explicitly afterward means all.
                    value.casting = nil
                end
                Changed()
            end,
        }
    end
    local function BuildConditionMultiDropdown(region, condition)
        local PP = EllesmereUI.PanelPP
        local label = EllesmereUI.MakeFont(region, 14, nil, 1, 1, 1)
        PP.Point(label, "LEFT", region, "LEFT", 20, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:SetMaxLines(1)
        label:SetText(EllesmereUI.L(condition.text))

        local ddBtn, refresh = EllesmereUI.BuildVisOptsCBDropdown(
            region, 170, region:GetFrameLevel() + 2, condition.items,
            condition.getSelected, condition.setSelected, nil, nil, nil, nil, nil,
            { emptyLabel = condition.emptyLabel, label = condition.text })
        PP.Point(ddBtn, "RIGHT", region, "RIGHT", -20, 0)
        EllesmereUI.RegisterWidgetRefresh(refresh)
        AttachLock(ddBtn, RuleLocked, LockTip, label)

        if condition.tooltip then
            local hitFrame = CreateFrame("Frame", nil, region)
            hitFrame:SetPoint("TOPLEFT", label, "TOPLEFT", -5, 5)
            hitFrame:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 5, -5)
            hitFrame:SetFrameLevel(region:GetFrameLevel() + 10)
            hitFrame:EnableMouse(true)
            hitFrame:SetScript("OnEnter", function()
                EllesmereUI.ShowWidgetTooltip(label, RuleLocked() and LockTip() or condition.tooltip)
            end)
            hitFrame:SetScript("OnLeave", function() EllesmereUI.HideWidgetTooltip() end)
            hitFrame:SetMouseClickEnabled(false)
        end
    end
    local conditions = {
        ConditionMultiDropdown("Unit type", "unitType", UNIT_TYPES, UNIT_ORDER,
            "Choose unit types. Any creature includes NPCs and player-controlled pets."),
        ConditionMultiDropdown("Reaction", "reaction", REACTIONS, REACTION_ORDER,
            "Choose whether units are friendly, enemy or neutral to you."),
        ConditionMultiDropdown("Classification", "classification", CLASSIFICATIONS, CLASSIFICATION_ORDER,
            "Choose unit ranks, such as elite, rare or boss."),
        ConditionMultiDropdown("Target state", "target", TARGETS, TARGET_ORDER,
            "Choose whether units are your target, other units, or shown while you have no target."),
        ConditionMultiDropdown("Player combat state", "playerCombat", PLAYER_COMBAT, PLAYER_COMBAT_ORDER,
            "Choose your character's combat state, not the unit's."),
        ConditionMultiDropdown("Instance Type", "instanceType", INSTANCES, INSTANCE_ORDER,
            "Choose where your character is, not your group type. Arena, scenario and delve are unavailable on Forever."),
        ConditionMultiDropdown("Cast state", "castState", CAST_STATES, CAST_ORDER,
            "Choose cast types or cast-color states. Color-state choices apply other styling to all active casts."),
        ConditionMultiDropdown("Threat", "threat", THREATS, THREAT_ORDER,
            "Choose who holds the unit's aggro. Unknown threat or roles cannot match the corresponding choice."),
    }
    for index = 1, #conditions, 2 do
        local left, right = conditions[index], conditions[index + 1]
        -- Use spacer slots for the row shell, then attach the shared checkbox
        -- dropdowns directly. This works with installed row factories that
        -- predate custom checkbox-dropdown row types.
        local row, rowHeight = W:DualRow(parent, y,
            { type = "spacer", text = left.text, tooltip = left.tooltip },
            right and { type = "spacer", text = right.text, tooltip = right.tooltip } or nil)
        -- The search factory returns absorbers, whose regions are not native
        -- UI parents. DualRow above still indexes both labels and tooltips.
        if not EllesmereUI.IsSearchPrebuild() then
            BuildConditionMultiDropdown(row._leftRegion, left)
            if right then BuildConditionMultiDropdown(row._rightRegion, right) end
        end
        y = y - rowHeight
    end
    _, h = LockedRow({
        type = "toggle", text = "Quest Objective",
        getValue = function() return GetRule().conditions.questObjective == "yes" end,
        setValue = function(value)
            GetRule().conditions.questObjective = value and "yes" or "any"
            Changed()
        end,
        tooltip = "Match only incomplete objectives in your quest log. Follows EUI's Show In Instances setting. Off ignores quest status.",
    })
    y = y - h
    _, h = W:SectionHeader(parent, "APPEARANCE - NAMEPLATE", y); y = y - h
    local sizeRow
    sizeRow, h = LockedRow({
        type = "slider", text = "Nameplate size (%)", min = 50, max = 200, step = 5,
        getValue = function() return GetRule().style.scale or 100 end,
        setValue = function(value) GetRule().style.scale = value; Changed() end,
        tooltip = "Scale selected elements relative to EUI's size. 100% keeps EUI's size. Use the cog to choose elements.",
    }, {
        type = "slider", text = "Opacity (%)", min = 0, max = 100, step = 5,
        getValue = function() return GetRule().style.opacity or 100 end,
        setValue = function(value) GetRule().style.opacity = value; Changed() end,
        tooltip = "Fade the whole nameplate. 100% keeps EUI's opacity; 0% hides it.",
    })
    if not EllesmereUI.IsSearchPrebuild() and EllesmereUI.BuildInlineCog then
        -- A popup can outlive its page/profile. Bind it to the rule that opened
        -- it and recheck both editor locks and selection on every write.
        local function CogLocked() return RuleLocked() or DB() ~= db or GetRule() ~= rule end
        local cogRows = {
            { type = "toggle", label = "Scale all", disabled = CogLocked, disabledTooltip = LockTip,
                tooltip = "Select all elements for scaling. Off clears every selection.",
                get = function()
                    for _, option in ipairs(addon.ScaleElementOptions) do
                        if not addon.IsScaleElementEnabled(rule.style, option.key) then return false end
                    end
                    return true
                end,
                set = function(value)
                    if CogLocked() then return end
                    local selection
                    if not value then
                        selection = {}
                        for _, option in ipairs(addon.ScaleElementOptions) do selection[option.key] = false end
                    end
                    rule.style.scaleElements = selection
                    Changed()
                end,
            },
        }
        for _, option in ipairs(addon.ScaleElementOptions) do
            local key = option.key
            cogRows[#cogRows + 1] = {
                type = "toggle", label = option.label, tooltip = option.tooltip,
                disabled = CogLocked, disabledTooltip = LockTip,
                get = function() return addon.IsScaleElementEnabled(rule.style, key) end,
                set = function(value)
                    if CogLocked() then return end
                    local selection = rule.style.scaleElements or {}
                    if value then selection[key] = nil else selection[key] = false end
                    rule.style.scaleElements = next(selection) and selection or nil
                    Changed()
                end,
            }
        end
        EllesmereUI.BuildInlineCog(sizeRow._leftRegion, {
            title = "Nameplate scaling", rows = cogRows, captureRegion = sizeRow._leftRegion,
            disabled = CogLocked, disabledTooltip = LockTip,
            tip = "Choose which elements scale. Unchecked elements keep EUI's size.",
        })
    end
    y = y - h
    _, h = W:SectionHeader(parent, "APPEARANCE - HEALTH BAR", y); y = y - h
    _, h = LockedRow({ type = "toggle", text = "Override health bar",
        getValue = function() return GetRule().style.healthEnabled ~= false end,
        setValue = function(value) GetRule().style.healthEnabled = value; Changed(); Rebuild() end,
        tooltip = "Apply this rule's health-bar appearance. Off restores EUI's health bar; nameplate size and opacity are unchanged.",
    })
    y = y - h
    local function HealthOff() return GetRule().style.healthEnabled == false end
    local function BorderTip(toggle)
        return function()
            if not addon.SupportsBorderStyles() then return "Update EllesmereUI to use border overrides." end
            return "Enable " .. toggle .. " first."
        end
    end
    local function HealthBorderOff()
        local style = GetRule().style
        return HealthOff() or style.borderEnabled == false or (style.borderSize or 0) <= 0 or not addon.SupportsBorderStyles()
    end
    _, h = LockedRow({
        type = "toggle", text = "Custom health color", disabled = HealthOff,
        tooltip = "Use this rule's health-bar color. Tapped enemies keep EUI's tapped color.",
        disabledTooltip = "Enable Override health bar first.",
        getValue = function() return GetRule().style.healthColorEnabled ~= false end,
        setValue = function(value) GetRule().style.healthColorEnabled = value; Changed(); Rebuild() end,
    }, {
        type = "colorpicker", text = "Health-bar color", hasAlpha = false,
        tooltip = "Choose the health bar's fill color.",
        disabled = function() return HealthOff() or GetRule().style.healthColorEnabled == false end,
        disabledTooltip = "Enable Custom health color first.",
        getValue = function()
            local color = GetRule().style.healthColor
            return color.r, color.g, color.b, 1
        end,
        setValue = function(r, g, b) GetRule().style.healthColor = { r = r, g = g, b = b }; Changed() end,
    }); y = y - h
    _, h = LockedRow({
        type = "dropdown", text = "Health-bar texture", values = barTextureValues, order = barTextureOrder,
        disabled = HealthOff, disabledTooltip = "Enable Override health bar first.",
        tooltip = "Choose the health bar's fill texture. Use EUI texture keeps EUI's current choice.",
        getValue = function() return GetRule().style.texture or "eui" end,
        setValue = function(value) GetRule().style.texture = value; Changed() end,
    }, nil)
    y = y - h
    _, h = LockedRow({
        type = "toggle", text = "Override health border", disabled = function() return HealthOff() or not addon.SupportsBorderStyles() end,
        tooltip = "Replace the health bar's border with this rule's border. Off restores EUI's border.",
        disabledTooltip = BorderTip("Override health bar"),
        getValue = function()
            local style = GetRule().style
            return style.borderEnabled ~= false and (style.borderSize or 0) > 0
        end,
        setValue = function(value)
            local style = GetRule().style
            style.borderEnabled = value
            if value and (style.borderSize or 0) <= 0 then style.borderSize = 2 end
            Changed(); Rebuild()
        end,
    }, {
        type = "colorpicker", text = "Health border color", hasAlpha = false,
        tooltip = "Choose the health bar's border color.",
        disabled = HealthBorderOff, disabledTooltip = BorderTip("Override health border"),
        getValue = function()
            local color = GetRule().style.borderColor
            return color.r, color.g, color.b, 1
        end,
        setValue = function(r, g, b) GetRule().style.borderColor = { r = r, g = g, b = b }; Changed() end,
    }); y = y - h
    _, h = LockedRow({
        type = "dropdown", text = "Health border texture", values = borderTextureValues, order = borderTextureOrder,
        disabled = HealthBorderOff, disabledTooltip = BorderTip("Override health border"),
        getValue = function() return GetRule().style.borderTexture or "solid" end,
        setValue = function(value) GetRule().style.borderTexture = value; Changed(); Rebuild() end,
        tooltip = "Choose the health bar's border style.",
    }, {
        type = "slider", text = "Health border size", min = 1, max = (GetRule().style.borderTexture or "solid") == "solid" and 8 or 4, step = 1,
        disabled = HealthBorderOff, disabledTooltip = BorderTip("Override health border"),
        tooltip = "Set border thickness in pixels for Solid, or size step for textured borders.",
        getValue = function() return math.max(1, GetRule().style.borderSize or 2) end,
        setValue = function(value) GetRule().style.borderSize = value; Changed() end,
    }); y = y - h

    h = GlowRow("health", HealthOff, "Enable Override health bar first."); y = y - h
    _, h = W:SectionHeader(parent, "APPEARANCE - CAST BAR", y); y = y - h
    _, h = LockedRow({ type = "toggle", text = "Override cast bar",
        getValue = function() return GetRule().style.castEnabled == true end,
        setValue = function(value) GetRule().style.castEnabled = value; Changed(); Rebuild() end,
        tooltip = "Apply this rule's cast-bar appearance. Off restores EUI's cast bar. Does not add cast bars to friendly plates.",
    })
    y = y - h
    local defaults = addon.CastStyleDefaults
    local function CastOff() return GetRule().style.castEnabled ~= true end
    local function CastToggle(text, key, tooltip)
        return {
            type = "toggle", text = text, disabled = CastOff,
            tooltip = tooltip,
            disabledTooltip = "Enable Override cast bar first.",
            getValue = function() return GetRule().style[key] == true end,
            setValue = function(value) GetRule().style[key] = value; Changed(); Rebuild() end,
        }
    end
    local function CastColor(text, key, enabledKey)
        return {
            type = "colorpicker", text = text, hasAlpha = false,
            tooltip = key == "castColor" and "Choose the cast bar's fill color." or "Choose the cast bar's border color.",
            disabled = function() return CastOff() or GetRule().style[enabledKey] ~= true end,
            disabledTooltip = key == "castBorderColor" and BorderTip("Override cast border")
                or "Enable Custom cast color first.",
            getValue = function()
                local color = GetRule().style[key] or defaults[key]
                return color.r, color.g, color.b, 1
            end,
            setValue = function(r, g, b) GetRule().style[key] = { r = r, g = g, b = b }; Changed() end,
        }
    end
    local colorToggle = CastToggle("Custom cast color", "castColorEnabled",
        "Use this rule's cast color. The first matching rule wins per color state. Interrupted flashes keep EUI's appearance.")
    _, h = LockedRow(colorToggle,
        CastColor("Cast fill color", "castColor", "castColorEnabled")); y = y - h
    _, h = LockedRow({
        type = "dropdown", text = "Cast-bar texture", values = barTextureValues, order = barTextureOrder,
        disabled = CastOff, disabledTooltip = "Enable Override cast bar first.",
        tooltip = "Choose the cast bar's fill texture. Use EUI texture keeps EUI's choice. Stock Blizzard-style artwork is unchanged.",
        getValue = function() return GetRule().style.castTexture or "eui" end,
        setValue = function(value) GetRule().style.castTexture = value; Changed() end,
    }, nil)
    y = y - h
    _, h = LockedRow(CastToggle("Custom cast opacity", "castOpacityEnabled", "Use a separate opacity for the cast bar."), {
        type = "slider", text = "Cast opacity (%)", min = 0, max = 100, step = 5,
        disabled = function() return CastOff() or GetRule().style.castOpacityEnabled ~= true end,
        disabledTooltip = "Enable Custom cast opacity first.",
        tooltip = "Fade the cast bar, icon and text in addition to nameplate opacity. 100% adds no extra fading.",
        getValue = function() return GetRule().style.castOpacity or defaults.castOpacity end,
        setValue = function(value) GetRule().style.castOpacity = value; Changed() end,
    }); y = y - h
    local castBorderToggle = CastToggle("Override cast border", "castBorderEnabled",
        "Replace the cast bar's border with this rule's border. Off restores EUI's border.")
    castBorderToggle.disabled = function() return CastOff() or not addon.SupportsBorderStyles() end
    castBorderToggle.disabledTooltip = BorderTip("Override cast bar")
    _, h = LockedRow(castBorderToggle,
        CastColor("Cast border color", "castBorderColor", "castBorderEnabled")); y = y - h
    local function CastBorderOff() return CastOff() or GetRule().style.castBorderEnabled ~= true or not addon.SupportsBorderStyles() end
    _, h = LockedRow({
        type = "dropdown", text = "Cast border texture", values = borderTextureValues, order = borderTextureOrder,
        disabled = CastBorderOff, disabledTooltip = BorderTip("Override cast border"),
        getValue = function() return GetRule().style.castBorderTexture or "solid" end,
        setValue = function(value) GetRule().style.castBorderTexture = value; Changed(); Rebuild() end,
        tooltip = "Choose the cast bar's border style.",
    }, {
        type = "slider", text = "Cast border size", min = 1, max = (GetRule().style.castBorderTexture or "solid") == "solid" and 8 or 4, step = 1,
        disabled = CastBorderOff,
        disabledTooltip = BorderTip("Override cast border"),
        tooltip = "Set border thickness in pixels for Solid, or size step for textured borders. The icon separator is unchanged.",
        getValue = function() return GetRule().style.castBorderSize or defaults.castBorderSize end,
        setValue = function(value) GetRule().style.castBorderSize = value; Changed() end,
    }); y = y - h

    h = GlowRow("cast", CastOff, "Enable Override cast bar first."); y = y - h
    _, h = W:SectionHeader(parent, "APPEARANCE - TEXT", y); y = y - h
    _, h = LockedRow({ type = "toggle", text = "Override text",
        disabled = function() return DB() ~= db or GetRule() ~= rule end,
        disabledTooltip = "Select this rule again to edit its text.",
        getValue = function() return GetRule().style.textEnabled == true end,
        setValue = function(value) GetRule().style.textEnabled = value; Changed(); Rebuild() end,
        tooltip = "Apply this rule's text content and colors. Off restores EUI's text. Bar overrides are not required.",
    }); y = y - h
    local function TextOff() return DB() ~= db or GetRule() ~= rule or GetRule().style.textEnabled ~= true end
    local function TextSlot(slot)
        local values, order = addon.GetRuleTextChoices(slot.cast)
        return { type = "dropdown", text = slot.label .. " content", values = values, order = order,
            disabled = TextOff, disabledTooltip = "Enable Override text first.",
            getValue = function() return GetRule().style.textSlots and GetRule().style.textSlots[slot.key] or "eui" end,
            setValue = function(value)
                local style = GetRule().style
                style.textSlots = style.textSlots or {}
                if value == "eui" then style.textSlots[slot.key] = nil else style.textSlots[slot.key] = value end
                Changed()
            end,
            tooltip = "Choose what this slot shows. Use EUI setting keeps its content; None hides it. Position and font follow EUI."
                .. (slot.cast and " Cast-target text is unavailable on Forever." or "") .. " Unavailable data stays blank.",
        }
    end
    for index = 1, #addon.RuleTextSlots, 2 do
        local right = addon.RuleTextSlots[index + 1]
        _, h = LockedRow(TextSlot(addon.RuleTextSlots[index]), right and TextSlot(right) or nil); y = y - h
    end
    _, h = W:SectionHeader(parent, "TEXT COLORS", y); y = y - h
    for _, key in ipairs(addon.RuleTextElements) do
        local label = addon.RuleTextLabels[key]
        local function ColorOff() return TextOff() or not (GetRule().style.textColors and GetRule().style.textColors[key]) end
        _, h = LockedRow({ type = "toggle", text = "Override " .. label .. " color", disabled = TextOff,
            tooltip = "Use a custom color for " .. label:lower() .. " text. Off keeps EUI's color."
                .. ((key == "name" or key == "level") and " Combined name/level labels may keep EUI's colors." or ""),
            disabledTooltip = "Enable Override text first.",
            getValue = function() return GetRule().style.textColors and GetRule().style.textColors[key] ~= nil or false end,
            setValue = function(value)
                local style = GetRule().style; style.textColors = style.textColors or {}
                if value then style.textColors[key] = { r = 1, g = 1, b = 1 } else style.textColors[key] = nil end
                Changed(); Rebuild()
            end,
        }, { type = "colorpicker", text = label .. " text color", hasAlpha = false,
            tooltip = "Choose the color of " .. label:lower() .. " text.",
            disabled = ColorOff, disabledTooltip = "Enable Override " .. label .. " color first.",
            getValue = function()
                local c = GetRule().style.textColors and GetRule().style.textColors[key] or { r = 1, g = 1, b = 1 }
                return c.r, c.g, c.b, 1
            end,
            setValue = function(r, g, b) GetRule().style.textColors[key] = { r = r, g = g, b = b }; Changed() end,
        }); y = y - h
    end
    _, h = W:SectionHeader(parent, "APPEARANCE - TARGET ARROWS", y); y = y - h
    local arrowValues, arrowOrder = addon.GetTargetArrowOptions()
    local function ArrowsUnavailable() return not addon.SupportsTargetArrows() end
    _, h = LockedRow({ type = "toggle", text = "Override target arrows",
        disabled = ArrowsUnavailable, disabledTooltip = "Update EllesmereUI Nameplates to use its target-arrow styles.",
        getValue = function() return GetRule().style.targetArrowsEnabled == true end,
        setValue = function(value) GetRule().style.targetArrowsEnabled = value; Changed(); Rebuild() end,
        tooltip = "Show this rule's arrows on your current target, even if EUI's arrows are off. Color and size follow EUI. Off restores EUI's arrows.",
    }); y = y - h
    local function ArrowsOff() return ArrowsUnavailable() or GetRule().style.targetArrowsEnabled ~= true end
    _, h = LockedRow({ type = "dropdown", text = "Target-arrow style",
        tooltip = "Choose the target arrows' artwork. Use EUI arrow style keeps EUI's current choice.",
        values = arrowValues, order = arrowOrder, disabled = ArrowsOff,
        disabledTooltip = function()
            if ArrowsUnavailable() then return "Update EllesmereUI Nameplates to use its target-arrow styles." end
            return "Enable Override target arrows first."
        end,
        getValue = function() return GetRule().style.targetArrowStyle or "eui" end,
        setValue = function(value) GetRule().style.targetArrowStyle = value; Changed() end,
    }, nil)
    y = y - h

    return math.abs(y)
end

local function BuildAboutPage(parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local _, h
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
            -- Informational rows are searchable text, rather than blank spacers.
            row._isSpacer = nil
            row._labelText = text
            row._labelTextLoc = displayText ~= text and displayText or nil
        end
        y = y - height
    end
    local function Section(title, text)
        _, h = W:SectionHeader(parent, title, y); y = y - h
        Paragraph(text)
    end
    local version
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if type(getMetadata) == "function" then version = getMetadata("EllesmereUIExtendNameplates", "Version") end
    local versionText = type(version) == "string" and version ~= "" and ("Version " .. version .. ". ") or ""
    Section("NAMEPLATE EXTENSION", versionText ..
        "Adds customizable, rule-based styling to EllesmereUI Nameplates so important units and casts stand out. Requires EllesmereUI, the Extend core and EllesmereUI Nameplates.")
    Section("CUSTOM APPEARANCE",
        "Adjust nameplate size and opacity, health-bar colors and textures, borders, animated border glows, and target-arrow styles. Apply styles based on unit type, reaction, classification, quest objectives, targets, threat and casts.")
    Section("CAST COLORS",
        "Customize cast-bar appearance, including separate colors for interruptible casts, interrupts on cooldown and uninterruptible casts.")
    Section("PROFILES AND SHARING",
        "Use Extend > Profiles for shared profiles across extensions and characters, and export or import your rules on Sharing. Enable Nameplate styling on the Style tab pauses styling without deleting your setup.")
    local row
    row, h = W:Button(parent, "Open Nameplate Style", y, function()
        EllesmereUI.OpenPlugin(PLUGIN_ID, "NameplateStyle", "Style")
    end)
    ButtonTooltips(row, "Open the Style tab to edit nameplate rules.")
    y = y - h
    return math.abs(y)
end

local function Register()
    if addon.pluginRegistered then return true end
    local registered = EllesmereUIExtend.RegisterModule({
                key = "NameplateStyle",
                title = "Nameplate",
                description = "Rule-based nameplate styling by unit, target, cast and rank.",
                pages = { "Style", "Sharing", "About" },
                buildPage = function(pageName, parent, yOffset)
                    if pageName ~= "Style" and not EllesmereUI.IsSearchPrebuild() and EllesmereUI.ClearContentHeader then EllesmereUI:ClearContentHeader() end
                    if pageName == "Sharing" then return BuildSharingPage(parent, yOffset) end
                    if pageName == "About" then return BuildAboutPage(parent, yOffset) end
                    return BuildStylePage(parent, yOffset)
                end,
                getHeaderBuilder = function(pageName) if pageName == "Style" then return rulesHeaderBuilder end end,
                onPageCacheRestore = function(pageName)
                    if pageName == "Style" and rulesPreview then rulesPreview.Update(true) end
                end,
                onReset = function()
                    addon.ResetActiveProfile()
                    Rebuild()
                    Changed()
                end,
    })
    addon.pluginRegistered = registered == true
    addon.pluginRegistrationError = addon.pluginRegistered and nil
        or "The shared core rejected the Nameplates module"
    return addon.pluginRegistered
end

-- Register immediately after EUI's hard dependency has loaded. Retry at login
-- and on addon loads in case an older/LoD EUI load order exposes the API later.
addon.RegisterOptions = Register
if not Register() then
    local retry = CreateFrame("Frame")
    retry:RegisterEvent("ADDON_LOADED")
    retry:RegisterEvent("PLAYER_LOGIN")
    retry:SetScript("OnEvent", function(self)
        if Register() then
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
        end
    end)
end
