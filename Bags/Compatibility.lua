local _, ns = ...
if EUI_CLIENT_BLOCKED then return end

-- Feature-specific host selection: a standalone Nameplates core cannot supply
-- Bags APIs. Never publish aliases or revive an upstream-disabled standalone.
function ns.GetHost()
    if EUI_CLIENT_BLOCKED then return nil end
    return _G.EllesmereUI or (not _G.__EUISTANDALONE_BAGS_INERT and _G.EUICoreStandaloneBags) or nil
end
function ns.MediaPath(file)
    local folder = ns.GetHost() == _G.EllesmereUI and "EllesmereUI" or "EUIStandaloneBags"
    return "Interface\\AddOns\\" .. folder .. "\\media\\" .. file
end
function ns.HostDB()
    local host = ns.GetHost()
    if not host then return nil end
    if host == _G.EllesmereUI then return _G.EllesmereUIDB end
    return _G.EUICoreStandaloneBagsDB
end
function ns.HostModule()
    local host = ns.GetHost()
    local registry = host and host._ModuleNS
    return registry and registry[host == _G.EllesmereUI and "EllesmereUIBags" or "EUIStandaloneBags"]
end

function ns.Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end
function ns.String(value)
    if not ns.Secret(value) and type(value) == "string" and value ~= "" then return value end
end
function ns.Number(value)
    if not ns.Secret(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge then return value end
end
function ns.Read(func, ...)
    if type(func) ~= "function" then return nil, false end
    local ok, value = pcall(func, ...)
    if not ok or ns.Secret(value) then return nil, false end
    return value, true
end
function ns.CharacterKey()
    local name, realm
    if type(UnitFullName) == "function" then
        local ok, n, r = pcall(UnitFullName, "player")
        if ok then name, realm = ns.String(n), ns.String(r) end
    end
    name = name or ns.String(ns.Read(UnitName, "player"))
    realm = realm or ns.String(ns.Read(GetRealmName))
    if name and realm then return name .. " - " .. realm end
end
function ns.Editing()
    local eui = ns.GetHost()
    if not eui then return true end
    if type(eui.IsUnlockModeActive) ~= "function" then return false end
    local value, ok = ns.Read(eui.IsUnlockModeActive, eui)
    return not ok or value ~= false
end
function ns.CanCapture()
    if not ns.GetHost() then return false end
    if not ns.BankOpen then return false end
    local interaction = Enum and Enum.PlayerInteractionType
    if C_PlayerInteractionManager and type(C_PlayerInteractionManager.IsInteractingWithNpcOfType) == "function"
        and interaction and interaction.AccountBanker then
        local account, ok = ns.Read(C_PlayerInteractionManager.IsInteractingWithNpcOfType, interaction.AccountBanker)
        if not ok or account ~= false then return false end
    end
    local types = Enum and Enum.BankType
    if C_Bank and type(C_Bank.CanUseBank) == "function" and types then
        local value, ok = ns.Read(C_Bank.CanUseBank, types.Character)
        return ok and value == true
    end
    return true -- Older clients: BANKFRAME_OPENED is the access boundary.
end
