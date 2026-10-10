if EUI_CLIENT_BLOCKED then return end
local _, addon = ...

function addon.GetHost()
    local core = _G.EllesmereUIExtend
    if core and core.GetHost then return core.GetHost() end
    -- Older embedded cores can load first when extensions update separately.
    if EUI_CLIENT_BLOCKED then return nil end
    return _G.EllesmereUI or (not _G.__EUISTANDALONE_NAMEPLATES_INERT and _G.EUICoreStandaloneNameplates) or nil
end

-- Private utilities shared by this addon's runtime and options modules.
-- Keep the secret check dynamic: Forever may not provide issecretvalue.
function addon.IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

function addon.ClampNumber(value, fallback, minimum, maximum)
    if addon.IsSecret(value) or type(value) ~= "number" or value ~= value then
        return fallback
    end
    return math.max(minimum, math.min(maximum, value))
end

-- Settings and validated sharing payloads are acyclic plain tables. Copy all
-- nesting levels so custom conditions never share mutable tables with a copy.
function addon.CopyTable(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = addon.CopyTable(child)
    end
    return copy
end

function addon.ResolveBarTexturePath(key)
    -- nil/eui leave the engine's current texture untouched.
    if key == nil or key == "eui" then return nil end
    local fallback = "Interface\\Buttons\\WHITE8x8"
    if key == "flat" then return fallback end
    local np = _G.EllesmereNameplates_NS
    local host = addon.GetHost()
    if host and host.ResolveTexturePath and np and np.healthBarTextures then
        return host.ResolveTexturePath(np.healthBarTextures, key, fallback)
    end
    return fallback
end
