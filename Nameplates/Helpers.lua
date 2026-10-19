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

function addon.CastTargetSelection(rule)
    local selection = rule and rule.conditions and rule.conditions.castTarget
    if type(selection) ~= "table" then return nil end
    local me, other = selection.me == true, selection.notMe == true
    if me == other then return nil end
    return me and "me" or "notMe"
end
function addon.IsTargetedRule(rule)
    return addon.CastTargetSelection(rule) ~= nil
end

-- A single Cast target choice requires an active cast even when Cast state is
-- Any. Keep this separate from the explicit Cast state checklist and renderer
-- capability gates. "unknown" is still an active cast with an unreadable kind.
function addon.IsActiveCastState(value)
    return not addon.IsSecret(value) and type(value) == "string" and value ~= "none"
end

function addon.SupportsSpellTarget()
    return type(PlayerIsSpellTarget) == "function" or type(UnitIsSpellTarget) == "function"
end

function addon.TargetedAppearanceStyle(style)
    local allowed = { healthEnabled = true, healthColorEnabled = true, healthColor = true,
        castEnabled = true, castColorEnabled = true, castColor = true }
    local filtered = { borderEnabled = false, castBorderEnabled = false, textEnabled = false }
    for key, value in pairs(style or {}) do
        if allowed[key] or (type(key) == "string" and (key:match("^healthGlow") or key:match("^castGlow"))) then
            if key ~= "castGlowTargetMe" then filtered[key] = value end
        end
    end
    return filtered
end

function addon.ReadSpellTarget(unit)
    if addon.IsSecret(unit) or type(unit) ~= "string" or not addon.SupportsSpellTarget() then
        return false, "spell-target API unavailable"
    end
    local ok, value
    if type(PlayerIsSpellTarget) == "function" then ok, value = pcall(PlayerIsSpellTarget, unit)
    else ok, value = pcall(UnitIsSpellTarget, unit, "player") end
    if not ok then return false, "spell-target API failed" end
    if not addon.IsSecret(value) and type(value) ~= "boolean" then return false, "spell-target result unavailable" end
    return true, value
end

-- Native-only selection shared by rule glows and the opt-in layer prototype.
-- expected is addon-authored; value and evaluated alpha may remain secret.
function addon.SetTargetAlpha(frame, value, expected)
    local yes, no = expected and 1 or 0, expected and 0 or 1
    local evaluate = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
    if type(evaluate) == "function" then
        local ok, alpha = pcall(evaluate, value, yes, no)
        if ok and (addon.IsSecret(alpha) or type(alpha) == "number") then
            if pcall(frame.SetAlpha, frame, alpha) then return true, "native curve alpha" end
        end
    end
    if type(frame.SetAlphaFromBoolean) == "function" then
        if pcall(frame.SetAlphaFromBoolean, frame, value, yes, no) then return true, "native boolean alpha" end
    end
    if not addon.IsSecret(value) and type(value) == "boolean" then
        local alpha
        if value then alpha = yes else alpha = no end
        if pcall(frame.SetAlpha, frame, alpha) then return true, "readable alpha fallback" end
    end
    -- A failed setter may have partially written. Clear stale visibility even
    -- when the caller has not pre-cleared the gate; never branch on its alpha.
    pcall(frame.SetAlpha, frame, 0)
    return false, "no usable alpha sink"
end

-- Both alternatives are authored/cached color arrays. Results can stay secret
-- all the way to native setters; never use them as Lua rule-selection facts.
function addon.SelectTargetColor(flag, yes, no)
    local evaluate = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
    if type(evaluate) == "function" then
        local result = {}
        for index = 1, 4 do
            local ok, value = pcall(evaluate, flag, yes[index], no[index])
            if not ok or (not addon.IsSecret(value) and type(value) ~= "number") then
                result = nil
                break
            end
            result[index] = value
        end
        if result then return true, result[1], result[2], result[3], result[4] end
    end
    -- A missing or failing native evaluator does not prevent readable selection.
    -- Discard any partial native palette; secret flags still require that sink.
    if addon.IsSecret(flag) or type(flag) ~= "boolean" then return false end
    if flag then return true, yes[1], yes[2], yes[3], yes[4] end
    return true, no[1], no[2], no[3], no[4]
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
