local core = EllesmereUIExtend
if not core or core.optionsLoaded then return end
local GetHost = core.GetHost or function() return _G.EllesmereUI end
core.optionsLoaded = true

function core.RefreshOptions()
    local eui = GetHost()
    if not eui or not core.pluginRegistered or type(eui.GetPluginModuleKey) ~= "function" then return end
    local active = type(eui.GetActiveModule) == "function" and eui:GetActiveModule()
    local rebuild = false
    for _, spec in ipairs(core.GetModules()) do
        local key = eui.GetPluginModuleKey(core.PluginID, spec.key)
        if key and type(eui.InvalidateModulePageCache) == "function" then eui:InvalidateModulePageCache(key) end
        if key == active then rebuild = true end
    end
    if rebuild and type(eui.RefreshPage) == "function" then eui:RefreshPage(true) end
end

local function Report(ok, err)
    if not ok and GetHost().PrintError then GetHost().PrintError(err or "Could not update profiles.") end
end

local function ButtonTooltip(row, text)
    if type(GetHost().IsSearchPrebuild) == "function" and GetHost().IsSearchPrebuild() then return end
    if not row or type(row.GetChildren) ~= "function" then return end
    local button = row:GetChildren()
    if not button or type(button.HookScript) ~= "function" then return end
    button:HookScript("OnEnter", function()
        if GetHost().ShowWidgetTooltip then GetHost().ShowWidgetTooltip(button, text) end
    end)
    button:HookScript("OnLeave", function()
        if GetHost().HideWidgetTooltip then GetHost().HideWidgetTooltip() end
    end)
end

local function Prompt(rename)
    local old = core.GetProfileInfo().active
    GetHost():ShowInputPopup({ title = rename and "Rename Extend Profile" or "Create Extend Profile",
        message = "Profiles share all installed extensions across assigned characters. New profiles start with defaults.",
        placeholder = "Enter profile name...", initialText = rename and old or "", maxLetters = 32,
        confirmText = rename and "Rename" or "Create", cancelText = "Cancel",
        onConfirm = function(name)
            if rename and core.GetProfileInfo().active ~= old then
                Report(false, "The active profile changed."); return
            end
            if rename then Report(core.RenameProfile(name)) else Report(core.CreateProfile(name)) end
        end })
end

local function Profiles(_, parent, y)
    local W, h = GetHost().Widgets
    local info = core.GetProfileInfo()
    _, h = W:SectionHeader(parent, "CHARACTER PROFILE - " .. info.character, y); y = y - h
    local values = {}
    for _, name in ipairs(info.names) do values[name] = name end
    _, h = W:Dropdown(parent, "Profile for this character", y, values,
        function() return core.GetProfileInfo().active end,
        function(name) Report(core.SelectProfile(name)) end, info.names,
        "Choose one profile for all installed EllesmereUI extensions. This does not change EUI's own profile.")
    y = y - h
    local row
    row, h = W:WideButton(parent, "Create Profile", y, function() Prompt(false) end, 420); y = y - h
    ButtonTooltip(row, "Create a shared profile with fresh defaults for every installed extension.")
    if info.active ~= "Default" then
        row, h = W:WideButton(parent, "Rename Profile", y, function() Prompt(true) end, 420); y = y - h
        ButtonTooltip(row, "Rename the shared profile for every assigned character and extension.")
        row, h = W:WideButton(parent, "Delete Active Profile", y, function()
            local selected = core.GetProfileInfo().active
            GetHost():ShowConfirmPopup({ title = "Delete Extend Profile?",
                message = "Delete '" .. selected .. "' for every extension? Assigned characters will use Default.",
                confirmText = "Delete Profile", cancelText = "Cancel",
                onConfirm = function() Report(core.DeleteProfile(selected)) end })
        end, 420); y = y - h
        ButtonTooltip(row, "Delete this shared profile. Assigned characters switch to Default.")
    end
    _, h = W:SectionHeader(parent, "DEFAULT IS SHARED AND CANNOT BE RENAMED OR DELETED", y); y = y - h
    return math.abs(y)
end

core.RegisterModule({ key = "Profiles", title = "Profiles", pages = { "Profiles" },
    description = "Shared character profiles for independently installed extensions.",
    buildPage = function(page, parent, y)
        if type(GetHost().IsSearchPrebuild) ~= "function" or not GetHost().IsSearchPrebuild() then
            if GetHost().ClearContentHeader then GetHost():ClearContentHeader() end
        end
        return Profiles(page, parent, y)
    end })

function core.RegisterOptions()
    local host = GetHost()
    if not host or type(host.RegisterPlugin) ~= "function" then return false end
    if core.pluginRegistered then return true end
    local specs = core.GetModules()
    -- Feature modules first; the shared profile manager is last.
    table.sort(specs, function(a, b)
        if a.key == "Profiles" then return false end
        if b.key == "Profiles" then return true end
        return a.key < b.key
    end)
    local ok, result = pcall(host.RegisterPlugin, core.PluginID,
        { label = "Extend Addons", modules = specs })
    core.pluginRegistered = ok and result == true
    core.pluginRegistrationError = core.pluginRegistered and nil
        or (ok and "EUI rejected the Extend Addons settings hub." or tostring(result))
    return core.pluginRegistered
end

SLASH_ELLESMEREUIEXTEND1 = "/eextend"
SlashCmdList.ELLESMEREUIEXTEND = function()
    if core.RegisterOptions() and type(GetHost().OpenPlugin) == "function" then
        GetHost().OpenPlugin(core.PluginID, "Profiles", "Profiles")
    end
end
