local addonName, ns = ...
local addon = ns.Addon
if not addon then return end

ns.NotificationLabels = { accepted = "Accepted", progress = "Objective progress", objective = "Objective completed",
    ready = "Ready for turn-in", failed = "Failed", turnedIn = "Turned in" }
ns.NotificationDestinations = {
    { key = "localChat", label = "Local chat", tooltip = "Print in your own chat window." },
    { key = "toast", label = "Local toast", tooltip = "Show a short notification on your screen, visible only to you." },
    { key = "party", label = "Party", tooltip = "Send to your regular party when it is not a raid." },
    { key = "raid", label = "Raid", tooltip = "Send to your regular raid group." },
    { key = "instance", label = "Instance/Battleground", tooltip = "Send to your instance group, including battlegrounds and queued dungeon/raid groups." },
    { key = "guild", label = "Guild", tooltip = "Send to your guild when you are a member." },
}
local colors = { accepted = "66ccff", progress = "ffcc66", objective = "66ff99",
    ready = "ffd100", failed = "ff6666", turnedIn = "b399ff" }
local chatTypes = { party = "PARTY", raid = "RAID", instance = "INSTANCE_CHAT", guild = "GUILD" }
local lastSent, toasts, nextToast = {}, {}, 0
local toastPreview, toastEditing, toastSnapshot, toastMoverElement, toastMoverRegistered, toastMoverHidden
local TOAST_KEY, TOAST_WIDTH, TOAST_HEIGHT = "EQTX_NotificationToast", 400, 96
local toastColors = {
    accepted = "66ccff", progress = "ffcc66", objective = "66ff99",
    ready = "ffd100", failed = "ff6666", turnedIn = "b399ff",
}

-- Strip control/markup supplied by quest text before composing our own colors.
-- Truncation is byte-bounded for chat, but never cuts a UTF-8 codepoint in half.
local function ShortText(value, limit)
    local text = ns.String(value)
    if not text then return nil end
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
        :gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "")
        :gsub("[%c]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    if #text > limit then
        local n = limit - 3
        while n > 0 do
            local byte = text:byte(n + 1)
            if not byte or byte < 128 or byte >= 192 then break end
            n = n - 1
        end
        text = text:sub(1, n) .. "..."
    end
    if text ~= "" then return text end
end

function ns.FormatQuestNotification(kind, id, title, detail)
    local label, color = ns.NotificationLabels[kind], colors[kind]
    id, title, detail = ns.ID(id), ShortText(title, 100), ShortText(detail, 140)
    if not label or not id or not title then return nil end
    local quest = "[" .. title .. "] (#" .. string.format("%.0f", id) .. ")"
    return {
        heading = label,
        title = title,
        detail = detail,
        color = color,
        chat = "|cff" .. color .. label .. "|r: |cffffd100" .. quest .. "|r"
            .. (detail and " |cffcccccc— " .. detail .. "|r" or ""),
        plain = ShortText("[EUI Quest] " .. label .. ": " .. quest .. (detail and " - " .. detail or ""), 255),
        toast = quest .. (detail and "\n" .. detail or ""),
    }
end

local function SendAPI()
    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then return C_ChatInfo.SendChatMessage end
    if type(SendChatMessage) == "function" then return SendChatMessage end
end

function ns.NotificationDestinationSupported(key)
    if key == "localChat" or key == "toast" then return true end
    if not SendAPI() then return false end
    if key == "guild" then return type(IsInGuild) == "function" end
    if key == "instance" then return type(IsInGroup) == "function" and ns.Number(LE_PARTY_CATEGORY_INSTANCE) ~= nil end
    if key == "party" or key == "raid" then
        return type(IsInGroup) == "function" and type(IsInRaid) == "function" and ns.Number(LE_PARTY_CATEGORY_HOME) ~= nil
    end
    return false
end

local function CanSend(key)
    if not ns.NotificationDestinationSupported(key) then return false end
    if C_ChatInfo and type(C_ChatInfo.InChatMessagingLockdown) == "function"
        and ns.Boolean(ns.Call(C_ChatInfo.InChatMessagingLockdown)) ~= false then return false end
    if key == "guild" then return ns.Boolean(ns.Call(IsInGuild)) == true end
    if key == "instance" then return ns.Boolean(ns.Call(IsInGroup, LE_PARTY_CATEGORY_INSTANCE)) == true end
    local group = ns.Boolean(ns.Call(IsInGroup, LE_PARTY_CATEGORY_HOME))
    local raid = ns.Boolean(ns.Call(IsInRaid, LE_PARTY_CATEGORY_HOME))
    return group == true and ((key == "party" and raid == false) or (key == "raid" and raid == true))
end

local function ToastFrame(parent, isPreview)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
    frame:SetFrameStrata(isPreview and "DIALOG" or "DIALOG")
    frame:EnableMouse(false)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.025, 0.035, 0.05, 1)
    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(5)
    local border = {}
    border.top = frame:CreateTexture(nil, "OVERLAY")
    border.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    border.top:SetHeight(2)
    border.bottom = frame:CreateTexture(nil, "OVERLAY")
    border.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border.bottom:SetHeight(2)
    border.left = frame:CreateTexture(nil, "OVERLAY")
    border.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    border.left:SetWidth(1)
    border.right = frame:CreateTexture(nil, "OVERLAY")
    border.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border.right:SetWidth(1)
    local heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -11)
    heading:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -11)
    heading:SetJustifyH("LEFT")
    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -7)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 11)
    body:SetJustifyH("LEFT"); body:SetJustifyV("TOP")
    body:SetWordWrap(true)
    frame.bg, frame.accent, frame.border = bg, accent, border
    frame.heading, frame.body, frame.isPreview = heading, body, isPreview == true
    frame:SetScript("OnHide", function(self)
        if not self.isPreview then self:SetScript("OnUpdate", nil) end
    end)
    return frame
end

local function AccentColor()
    local color = ns.Table(addon.Settings().toastAccentColor) or {}
    return ns.Clamp(color.r, 0, 1, 0.9), ns.Clamp(color.g, 0, 1, 0.62), ns.Clamp(color.b, 0, 1, 0.16)
end

local function PositionToast(frame, index)
    local cfg = addon.Settings()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", cfg.toastX, cfg.toastY - ((index or 1) - 1) * 104)
end

local function StyleToast(frame, message, fade)
    if not frame or not message then return end
    local r, g, b = AccentColor()
    frame.accent:SetColorTexture(r, g, b, 1)
    for _, edge in pairs(frame.border) do edge:SetColorTexture(r, g, b, 0.95) end
    frame.heading:SetText("|cff" .. message.color .. message.heading .. "|r")
    frame.body:SetText(message.toast)
    frame:SetAlpha(addon.Settings().toastOpacity * (fade or 1))
end

local function ToastPreviewEnabled()
    local cfg = addon.Settings()
    return ns.Active() and cfg.messages and cfg.notificationDestinations.toast
end

local function CreateToastPreview()
    if toastPreview or ns.InCombat() then return toastPreview end
    toastPreview = ToastFrame(UIParent, true)
    toastPreview.message = { heading = "Ready for turn-in", color = toastColors.ready,
        toast = "[Sample Quest] (#12345)\nAn objective was completed." }
    StyleToast(toastPreview, toastPreview.message)
    PositionToast(toastPreview, 1)
    toastPreview:Hide()
    return toastPreview
end

local function RefreshToastPositions()
    if toastPreview then PositionToast(toastPreview, 1) end
    for i, frame in ipairs(toasts) do PositionToast(frame, i) end
end

function ns.RefreshToastAppearance()
    for _, frame in ipairs(toasts) do
        if frame.message then
            local now = ns.Number(ns.Call(GetTime))
            local fade = now and frame.startedAt and math.max(0, math.min(1, 5 - (now - frame.startedAt))) or 1
            StyleToast(frame, frame.message, fade)
        end
    end
    if toastPreview then StyleToast(toastPreview, toastPreview.message) end
end

local function ShowToast(message, now)
    if toastEditing then return end
    nextToast = nextToast % 3 + 1
    local frame = toasts[nextToast]
    if not frame then
        frame = ToastFrame(UIParent, false)
        toasts[nextToast] = frame
    end
    frame.message, frame.startedAt = message, now
    PositionToast(frame, nextToast)
    StyleToast(frame, message)
    frame:Show()
    frame:SetScript("OnUpdate", function(self)
        local cfg, time = addon.Settings(), ns.Number(ns.Call(GetTime))
        if not time or not ns.Active() or not cfg.messages
            or not cfg.notificationDestinations.toast or toastEditing or time - self.startedAt >= 5 then
            self:Hide()
            return
        end
        StyleToast(self, self.message, math.max(0, math.min(1, 5 - (time - self.startedAt))))
    end)
end

local function ToastMoverEnabled()
    return ToastPreviewEnabled() and ns.HasItemMover()
end

local function ToastPosition()
    local cfg = addon.Settings()
    return { point = "CENTER", relPoint = "CENTER", x = cfg.toastX, y = cfg.toastY }
end

function ns.ResetToastPosition()
    if ns.InCombat() then return end
    addon.Settings().toastX, addon.Settings().toastY = ns.Defaults.toastX, ns.Defaults.toastY
    RefreshToastPositions()
end

local function ToastEditChanged(active, closeAction)
    active = ns.Boolean(active)
    if active == nil then return end
    if active then
        if toastEditing then return end
        toastSnapshot = ToastPosition()
        toastEditing = true
        for _, frame in ipairs(toasts) do frame:Hide() end
        local sample = CreateToastPreview()
        if sample then
            PositionToast(sample, 1)
            if ToastMoverEnabled() then sample:Show() else sample:Hide() end
        end
    elseif toastEditing then
        if ns.String(closeAction) ~= "save" and toastSnapshot then
            addon.Settings().toastX, addon.Settings().toastY = toastSnapshot.x, toastSnapshot.y
        end
        toastEditing, toastSnapshot = false, nil
        if toastPreview then toastPreview:Hide() end
        RefreshToastPositions()
    end
end

function ns.RegisterToastMover()
    if toastMoverRegistered or ns.InCombat() or not ns.HasItemMover() then return toastMoverRegistered end
    local isActive = ns.Boolean(ns.Call(EllesmereUI.IsUnlockModeActive, EllesmereUI))
    if isActive == nil then return false end
    if isActive then ToastEditChanged(true) end
    local opts = {
        key = TOAST_KEY, label = "Quest Notification Toast", group = "Extend Quest Tracker", order = 960,
        noResize = true, noAnchorTo = true, noAnchorTarget = true, noSizeMatchTarget = true,
        isHidden = function() return not ToastMoverEnabled() end,
        getFrame = function()
            if ToastMoverEnabled() and not ns.InCombat() then return CreateToastPreview() end
        end,
        getSize = function() return TOAST_WIDTH, TOAST_HEIGHT end,
        loadPos = ToastPosition,
        savePos = function(_, point, relPoint, x, y)
            if not ToastMoverEnabled() or ns.InCombat() then return end
            if ns.String(point) ~= "CENTER" or ns.String(relPoint) ~= "CENTER" then return end
            x, y = ns.Number(x), ns.Number(y)
            if not x or not y then return end
            local cfg = addon.Settings()
            cfg.toastX, cfg.toastY = math.max(-10000, math.min(10000, x)), math.max(-10000, math.min(10000, y))
            RefreshToastPositions()
        end,
        clearPos = ns.ResetToastPosition,
        applyPos = RefreshToastPositions,
    }
    toastMoverElement = ns.Table(ns.Call(EllesmereUI.MakeUnlockElement, opts))
    if not toastMoverElement then
        if isActive then ToastEditChanged(false, "exit") end
        return false
    end
    toastMoverRegistered = true
    toastMoverHidden = not ToastMoverEnabled()
    local ok = pcall(EllesmereUI.RegisterUnlockElements, EllesmereUI, { toastMoverElement }, addonName)
    if ok then ok = pcall(EllesmereUI.RegisterUnlockModeListener, EllesmereUI, TOAST_KEY, ToastEditChanged) end
    if not ok then
        toastMoverRegistered = false
        if type(EllesmereUI.UnregisterUnlockElement) == "function" then
            pcall(EllesmereUI.UnregisterUnlockElement, EllesmereUI, TOAST_KEY)
        end
        if isActive then ToastEditChanged(false, "exit") end
        return false
    end
    return true
end

function ns.RefreshNotificationOutput()
    for _, toast in ipairs(toasts) do toast:Hide() end
    ns.RegisterToastMover()
    local enabled = ToastMoverEnabled() and not ns.InCombat()
    if toastMoverRegistered and toastMoverHidden ~= (not enabled) then
        toastMoverHidden = not enabled
        if type(EllesmereUI.RegisterUnlockElements) == "function" and toastMoverElement then
            pcall(EllesmereUI.RegisterUnlockElements, EllesmereUI, { toastMoverElement }, addonName)
        end
    end
    if toastPreview then
        StyleToast(toastPreview, toastPreview.message)
        if enabled and toastEditing then toastPreview:Show() else toastPreview:Hide() end
    end
end

function ns.DeliverQuestNotification(kind, id, title, detail, now)
    local message = ns.FormatQuestNotification(kind, id, title, detail)
    if not message then return end
    local destinations = addon.Settings().notificationDestinations
    if destinations.localChat then ns.Print(message.chat) end
    if destinations.toast then ShowToast(message, now) end
    for _, entry in ipairs(ns.NotificationDestinations) do
        local key = entry.key
        if chatTypes[key] and destinations[key] and CanSend(key) and now - (lastSent[key] or -math.huge) >= 1 then
            -- No backlog: skipped/restricted messages must not burst out later.
            local ok = pcall(SendAPI(), message.plain, chatTypes[key])
            if ok then lastSent[key] = now end
        end
    end
end
