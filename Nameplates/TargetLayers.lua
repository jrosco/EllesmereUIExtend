if EUI_CLIENT_BLOCKED then return end
local _, addon = ...
local api = EllesmereUIExtendNameplates
local Secret = addon.IsSecret

-- Opt-in proof of concept, not a rule renderer. Never suppress/reparent native
-- regions: first establish whether separate authored layers can be anchored and
-- gated on the actual clients. No prototype state belongs in SavedVariables.
local active, updater, elapsed
local frames = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local function FailureReason(value)
    if Secret(value) or type(value) ~= "string" then return "unavailable error details" end
    return value
end
local function HideFrame(frame)
    pcall(frame.SetAlpha, frame, 0)
    pcall(frame.Hide, frame)
end
local function Hide(session)
    for _, entry in ipairs(session.layers) do
        HideFrame(entry.frame)
    end
end
function addon.StopTargetLayerPrototype()
    if active then Hide(active); active = nil end
    if updater then updater:Hide() end
end

local function HookOwner(plate)
    if hooked[plate] then return end
    hooked[plate] = true
    local function Stop()
        if active and active.plate == plate then addon.StopTargetLayerPrototype() end
    end
    if type(plate.ClearUnit) == "function" then hooksecurefunc(plate, "ClearUnit", Stop) end
    if type(plate.HookScript) == "function" then plate:HookScript("OnHide", Stop) end
end

local function Update(session)
    local plate = session.plate
    if Secret(plate.unit) or plate.unit ~= session.unit or api.GetSettings() ~= session.settings
        or session.settings.enabled == false or Secret(plate._castOverlayLifted)
        or plate._castOverlayLifted ~= session.castLifted then
        addon.StopTargetLayerPrototype()
        return
    end
    local ok, flag = addon.ReadSpellTarget(session.unit)
    if not ok then flag = false end
    local running = 0
    for _, entry in ipairs(session.layers) do
        if not entry.failed then
            if plate[entry.cast and "cast" or "health"] ~= entry.bar then
                addon.StopTargetLayerPrototype()
                return
            end
            if entry.fill then
                local fill = entry.bar:GetStatusBarTexture()
                if Secret(fill) or fill ~= entry.fill then
                    addon.StopTargetLayerPrototype()
                    return
                end
            end
            local value = flag
            -- Never cover an interrupted-cast flash, including an unreadable stamp.
            if entry.cast and (Secret(plate._interrupted) or plate._interrupted) then value = false end
            if not addon.SetTargetAlpha(entry.frame, value, true) then
                entry.failed = true
                HideFrame(entry.frame)
            else
                running = running + 1
            end
        end
    end
    if running == 0 then addon.StopTargetLayerPrototype() end
end

local function Layer(session, bar, prefix, kind, configure)
    local entry = { bar = bar, cast = prefix == "cast", kind = prefix .. " " .. kind }
    local ok, err = pcall(function()
        local cache = frames[session.plate]
        if not cache then cache = {}; frames[session.plate] = cache end
        entry.frame = cache[entry.kind]
        if not entry.frame or entry.frame:GetParent() ~= bar then
            entry.frame = CreateFrame("Frame", nil, bar)
            cache[entry.kind] = entry.frame
        end
        -- Configure geometry before introducing secret alpha. A successful call
        -- today is not proof that this anchor works on another client/style.
        entry.frame:Hide()
        entry.frame:SetAlpha(0)
        entry.frame:EnableMouse(false)
        entry.frame:SetAllPoints(bar)
        local level = bar:GetFrameLevel()
        if Secret(level) or type(level) ~= "number" then error("restricted frame level") end
        local strata = session.plate._castOverlayLifted and prefix == "cast" and bar:GetFrameStrata() or "MEDIUM"
        if Secret(strata) or type(strata) ~= "string" then error("restricted frame strata") end
        entry.frame:SetFrameStrata(strata)
        entry.frame:SetFrameLevel(level + 2)
        configure(entry.frame, entry)
        entry.frame:Show()
    end)
    if not ok then
        if entry.frame then HideFrame(entry.frame) end
        session.failures[#session.failures + 1] = entry.kind .. ": " .. FailureReason(err)
        return
    end
    session.layers[#session.layers + 1] = entry
end

function addon.StartTargetLayerPrototype(plate)
    addon.StopTargetLayerPrototype()
    if not plate or Secret(plate.unit) or type(plate.unit) ~= "string" or not addon.SupportsSpellTarget() then
        return false, "A visible nameplate and spell-target API are required."
    end
    local settings = api.GetSettings()
    if settings.enabled == false then return false, "Enable Nameplate styling first." end
    if Secret(plate._castOverlayLifted) then return false, "Cast-layer ownership is unavailable." end
    HookOwner(plate)
    local session = { plate = plate, unit = plate.unit, settings = settings,
        castLifted = plate._castOverlayLifted, layers = {}, failures = {} }
    for _, prefix in ipairs({ "health", "cast" }) do
        local bar = prefix == "health" and plate.health or plate.cast
        if bar then
            Layer(session, bar, prefix, "texture", function(frame, entry)
                if (prefix == "health" and plate._blizzBarBg) or (prefix == "cast" and plate._blizzCastArt) then
                    error("stock atlas ownership")
                end
                local fill = bar:GetStatusBarTexture()
                if Secret(fill) or not fill then error("missing native fill") end
                entry.bar, entry.fill = bar, fill
                local texture = frame._prototypeTexture or frame:CreateTexture(nil, "ARTWORK")
                frame._prototypeTexture = texture
                texture:SetAllPoints(fill) -- native progress geometry, no Lua measurement
                local loaded = texture:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
                if Secret(loaded) or loaded ~= true then
                    loaded = texture:SetTexture("Interface\\Buttons\\WHITE8x8")
                    if Secret(loaded) or loaded ~= true then error("missing texture") end
                end
                texture:SetVertexColor(0.8, 0.25, 1, 1)
            end)
            Layer(session, bar, prefix, "border", function(frame)
                if not api.SupportsBorderStyles() then error("missing border renderer") end
                addon.RenderBorderStyle(frame, 2, { r = 0.8, g = 0.25, b = 1, a = 1 }, "solid", true)
            end)
            Layer(session, bar, prefix, "text", function(frame)
                local font = GameFontNormal
                if not font or type(font.GetFont) ~= "function" then error("missing font") end
                local path = font:GetFont()
                if Secret(path) or type(path) ~= "string" then error("unavailable font") end
                local text = frame._prototypeText or frame:CreateFontString(nil, "OVERLAY")
                frame._prototypeText = text
                local set = text:SetFont(path, 13, "OUTLINE")
                if Secret(set) or set ~= true then error("unavailable font") end
                text:SetPoint("CENTER", bar, "CENTER", 0, 0)
                text:SetText("TARGET LAYER TEST")
            end)
        end
    end
    if #session.layers == 0 then return false, "No prototype layers could be configured: " .. table.concat(session.failures, ", ") end
    active = session
    if not updater then
        elapsed = 0
        updater = CreateFrame("Frame")
        updater:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed < 0.1 then return end
            elapsed = 0
            if active then
                local ok, err = pcall(Update, active)
                if not ok then
                    addon.StopTargetLayerPrototype()
                    print("Extend Nameplates: target-layer prototype stopped: " .. FailureReason(err))
                end
            end
        end)
    end
    elapsed = 0
    updater:Show()
    local ok, err = pcall(Update, session)
    if not ok then addon.StopTargetLayerPrototype(); return false, "Prototype setup failed: " .. FailureReason(err) end
    if active ~= session then return false, "Prototype stopped: owner changed or no usable layers remain." end
    local failed = {}
    for _, kind in ipairs(session.failures) do failed[#failed + 1] = kind end
    for _, entry in ipairs(session.layers) do if entry.failed then failed[#failed + 1] = entry.kind .. " alpha" end end
    return true, "Experimental overlays configured (not confirmed visible); ignores rule filters."
        .. (#failed > 0 and (" Unavailable: " .. table.concat(failed, ", ")) or "")
end

function addon.ToggleTargetLayerPrototype(plate)
    if active then addon.StopTargetLayerPrototype(); return true, "Target-layer prototype stopped." end
    return addon.StartTargetLayerPrototype(plate)
end
addon.GetTargetLayerPrototype = function() return active end
