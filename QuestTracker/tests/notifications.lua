-- Focused notification integration; no game client or upstream checkout needed.
local ns, frames, messages, sounds, sends, widgets = {}, {}, {}, {}, {}, {}
local now, combat, prebuild, checks = 100, false, false, 0
local playedFiles, peonFilesAvailable = {}, true
local secret = setmetatable({}, { __tostring = function() error("secret formatting") end,
    __index = function() error("secret indexing") end, __lt = function() error("secret comparison") end })
function issecretvalue(value) return rawequal(value, secret) end
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Near(a, b) return math.abs(a - b) < 0.0001 end
local function Noop() end
function GetTime() return now end
function InCombatLockdown() return combat end
function CreateFrame(kind, name, parent)
    local frame = { scripts = {}, shown = true, parent = parent }
    frames[#frames + 1] = frame
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function frame:Show() self.shown = true end
    function frame:SetText(text) self.text = text end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:SetColorTexture(...) self.colorTexture = { ... } end
    function frame:CreateFontString() return CreateFrame("FontString", nil, self) end
    function frame:CreateTexture() return CreateFrame("Texture", nil, self) end
    function frame:GetFrameLevel() return 1 end
    function frame:ClearAllPoints() self.point = nil end
    function frame:GetWidth() return self.width or 600 end
    for _, method in ipairs({ "RegisterEvent", "SetPoint", "SetSize", "SetWidth", "SetHeight", "SetAllPoints",
        "SetFrameStrata", "EnableMouse", "SetJustifyH", "SetJustifyV", "SetWordWrap" }) do frame[method] = Noop end
    return frame
end
UIParent = CreateFrame("Frame")
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) messages[#messages + 1] = text end }
SOUNDKIT = { UI_AUTO_QUEST_COMPLETE = 1, IG_QUEST_LIST_COMPLETE = 2, TELL_MESSAGE = 3,
    RAID_WARNING = 4, READY_CHECK = 5, LEVEL_UP = 6, UI_EPICLOOT_TOAST = 7,
    LOOT_WINDOW_OPEN = 8, UI_BATTLEGROUND_COUNTDOWN_FINISHED = 9,
    ACHIEVEMENT_MENU_OPEN = 10, UI_GARRISON_MISSION_COMPLETE = 11 }
local function Sound(id, channel, forceNoDuplicates)
    sounds[#sounds + 1] = { id = id, channel = channel, forceNoDuplicates = forceNoDuplicates }
    return true
end
PlaySound = Sound
function PlaySoundFile(file, channel)
    playedFiles[#playedFiles + 1] = { file = file, channel = channel }
    return peonFilesAvailable
end
function SetCVar() error("notification must not change global volume") end
C_CVar = { SetCVar = SetCVar }
LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = 1, 2
local party, raid, instance, guild, restricted = false, false, false, false, false
function IsInGroup(category) if category == 2 then return instance end; return party end
function IsInRaid(category) assert(category == 1); return raid end
function IsInGuild() return guild end
local function Send(text, channel) sends[#sends + 1] = { text = text, channel = channel } end
C_ChatInfo = { SendChatMessage = Send, InChatMessagingLockdown = function() return restricted end }
local title, objectiveText, count, finished, ready, failed = "A Test Quest", "Collect samples: 0/3", 0, false, false, false
C_QuestLog = {
    GetNumQuestLogEntries = function() return 1 end,
    GetInfo = function() return { questID = 100, isHeader = false, title = title } end,
    GetTitleForQuestID = function() return title end,
    GetQuestObjectives = function() return { { text = objectiveText, numFulfilled = count, finished = finished } } end,
    ReadyForTurnIn = function() return ready end,
    IsFailed = function() return failed end,
}
local module, checklist, previewButtons = nil, nil, {}
local currentSection, layoutRows = nil, {}
EllesmereUI = {
    RegisterPlugin = function(_, spec) module = spec.modules[1]; return true end,
    IsSearchPrebuild = function() return prebuild end,
    Widgets = {
        SectionHeader = function(_, _, text) currentSection = text; return {}, 30 end,
        DualRow = function(_, _, _, left, right)
            layoutRows[#layoutRows + 1] = { section = currentSection, left = left.text,
                right = right and (right.text ~= "" and right.text or right.buttonText) or nil }
            widgets[left.text] = left
            if right then
                widgets[right.text] = right
                if right.type == "labeledButton" then previewButtons[#previewButtons + 1] = right end
            end
            if prebuild then return {}, 50 end
            local region = CreateFrame("Frame")
            region._control = CreateFrame("Button")
            return { _leftRegion = region }, 50
        end,
    },
    BuildVisOptsCBDropdown = function(parent, width, level, items, get, set, _, _, _, _, _, opts)
        Check(not prebuild, "no native checklist work during search prebuild")
        checklist = { items = items, get = get, set = set, opts = opts }
        return CreateFrame("Button", nil, parent), Noop
    end,
    RegisterWidgetRefresh = Noop,
}
for _, file in ipairs({ "Compatibility", "QuestTracker", "NotificationOutput", "Notifications", "Options" }) do
    assert(loadfile("QuestTracker/" .. file .. ".lua"))("EllesmereUIExtendQuestTracker", ns)
end
local addon = ns.Addon
ns.initialized = true
local cfg = addon.Settings()
ns.RefreshNotifications()
Check(#messages == 0 and #sounds == 0 and #sends == 0, "silent baseline")
Check(cfg.notificationDestinations.localChat and not cfg.notificationDestinations.toast and not cfg.notificationDestinations.guild,
    "local-chat-only defaults")
Check(cfg.toastOpacity == 0.92 and cfg.toastX == 0 and cfg.toastY == 210,
    "toast opacity and anchor defaults")
local function Accept() now = now + 2; ns.NotificationEvent("QUEST_ACCEPTED", 100) end
Accept()
Check(#messages == 1 and #sends == 0 and messages[1]:find("|cff66ccffAccepted|r", 1, true)
    and messages[1]:find("(#100)", 1, true), "colored local status includes title and quest ID")
cfg.sounds = true; cfg.sound = "complete"; cfg.soundChannel = "SFX"
Accept()
Check(sounds[#sounds].id == 2 and sounds[#sounds].channel == "SFX", "global fallback and output channel honored")
for kind in pairs(cfg.statusSounds) do
    cfg.statusSounds[kind] = "tell"
    Check(ns.NotificationSoundID(kind) == 3, "independent sound for " .. kind)
    cfg.statusSounds[kind] = "none"
    Check(ns.NotificationSoundID(kind) == nil, "None suppresses fallback for " .. kind)
    cfg.statusSounds[kind] = "global"
end
cfg.statusSounds.accepted = "tell"; Accept()
Check(sounds[#sounds].id == 3, "individual sound overrides global at event delivery")
SOUNDKIT.TELL_MESSAGE = nil; Accept()
Check(sounds[#sounds].id == 2, "missing individual sound falls back to global")
SOUNDKIT.TELL_MESSAGE = 3
cfg.statusSounds.accepted = "none"
local beforeSounds, beforeText, beforeSend = #sounds, #messages, #sends
Accept()
Check(#sounds == beforeSounds and #messages == beforeText and #sends == beforeSend,
    "per-status None disables local and shared messages as well as sound")
cfg.statusSounds.accepted = "global"; cfg.sound = "none"
Accept()
Check(#sounds == beforeSounds and #messages == beforeText + 1, "global None mutes inherited sound without disabling status messages")
cfg.sound = "ready"; cfg.statusSounds.accepted = "complete"; cfg.statusSounds.turnedIn = "tell"
Accept()
ns.NotificationEvent("QUEST_TURNED_IN", 100)
Check(sounds[#sounds].id == 2 and #sounds == beforeSounds + 1, "one-second sound burst throttle preserves first status sound")
now = now + 2; ns.NotificationEvent("QUEST_TURNED_IN", 100)
Check(sounds[#sounds].id == 3, "later turned-in status uses its own sound")
cfg.soundChannel = "Dialog"; Accept()
Check(sounds[#sounds].channel == "Dialog", "selected audio channel reaches playback API")
PlaySound = function() return false end; Accept()
PlaySound = Sound
ns.NotificationEvent("QUEST_TURNED_IN", 100)
Check(sounds[#sounds].id == 3, "failed playback does not consume sound throttle")

cfg.sounds = false
for key in pairs(cfg.notificationDestinations) do cfg.notificationDestinations[key] = key ~= "toast" end
party, guild = true, true
local start = #sends
Accept()
Check(#sends == start + 2 and sends[start + 1].channel == "PARTY" and sends[start + 2].channel == "GUILD",
    "multi-select sends to eligible party and guild only")
local last = #sends
ns.NotificationEvent("QUEST_TURNED_IN", 100)
Check(#sends == last, "per-destination burst throttle suppresses immediate second status")
raid, instance = true, true
start = #sends; Accept()
Check(#sends == start + 3 and sends[start + 1].channel == "RAID" and sends[start + 2].channel == "INSTANCE_CHAT",
    "raid excludes party, instance group routes to INSTANCE_CHAT")
party, raid, guild = false, false, false
start = #sends; Accept()
Check(#sends == start + 1 and sends[#sends].channel == "INSTANCE_CHAT", "instance-only group never sends to regular party")
restricted = true
start = #sends; local beforeMessages = #messages
Accept()
Check(#sends == start and #messages == beforeMessages + 1, "chat lockdown preserves local notification and skips broadcast")
restricted = secret; Accept()
Check(#sends == start, "unreadable chat lockdown fails closed")
restricted = false; instance = secret; guild = secret; party = secret
Accept(); Check(#sends == start, "unreadable group membership fails closed")
instance, guild, party = true, false, false
C_ChatInfo = nil; SendChatMessage = Send; EUI_CLIENT_FOREVER = true
Accept(); Check(#sends == start + 1, "Forever legacy chat sender fallback")
SendChatMessage = nil
Accept(); Check(#sends == start + 1, "missing send API does not affect local output")
C_ChatInfo = { SendChatMessage = function() error("restricted send") end }; Accept()
Check(#sends == start + 1, "throwing send does not escape notification handler")
C_ChatInfo = { SendChatMessage = Send, InChatMessagingLockdown = function() return false end }
EUI_CLIENT_FOREVER = nil
cfg.messages = false; cfg.sounds = true
local noText, noSend, withSound = #messages, #sends, #sounds
Accept()
Check(#messages == noText and #sends == noSend and #sounds == withSound + 1, "message master does not silence enabled audio")
cfg.statusSounds.accepted = "none"
withSound = #sounds; Accept()
Check(#sounds == withSound and #messages == noText and #sends == noSend, "disabled status suppresses every output")
cfg.statusSounds.accepted = "global"; cfg.messages = true
for key in pairs(cfg.notificationDestinations) do cfg.notificationDestinations[key] = false end
Accept()
Check(#messages == noText and #sends == noSend and #sounds == withSound + 1, "empty destinations suppress messages but keep independent audio")
cfg.sounds = false

local formatted = ns.FormatQuestNotification("progress", 100, "|cffff0000Title|r\n|Tbad|t", "|Hbad|hDetails|h\rtest")
Check(formatted.plain:find("Title", 1, true) and not formatted.plain:find("|", 1, true)
    and not formatted.plain:find("\n", 1, true), "outbound text strips injected colors textures links and controls")
formatted = ns.FormatQuestNotification("progress", 100, string.rep("é", 100), string.rep("界", 150))
Check(#formatted.plain <= 255 and utf8.len(formatted.plain) ~= nil, "long localized messages are byte bounded without broken UTF-8")
Check(ns.FormatQuestNotification("accepted", secret, "Title") == nil
    and ns.FormatQuestNotification("accepted", 100, secret) == nil, "secret IDs/titles never formatted")
cfg.notificationDestinations.localChat = true
cfg.statusSounds.progress = "global"
ns.RefreshNotifications(); count = 2; objectiveText = "Collect samples: 2/3"
ns.ScanNotifications(false)
Check(messages[#messages]:find("Collect samples: 2/3", 1, true), "objective progress carries readable objective detail")
beforeMessages = #messages; ns.ScanNotifications(false)
Check(#messages == beforeMessages, "unchanged objectives do not repeat")

-- Toast lifecycle: three reusable, non-clickable local frames with timed fade.
for key in pairs(cfg.notificationDestinations) do cfg.notificationDestinations[key] = key == "toast" end
start = #sends; beforeMessages = #messages
for _ = 1, 4 do Accept() end
local toastFrames = {}
for _, frame in ipairs(frames) do if frame.heading and frame.body then toastFrames[#toastFrames + 1] = frame end end
Check(#toastFrames == 3 and #sends == start and #messages == beforeMessages, "toast-only output uses bounded local frame pool")
local newest = toastFrames[1]
Check(newest.body.text:find("A Test Quest", 1, true), "toast has readable quest details")
Check(Near(newest.alpha, 0.92) and newest.accent.colorTexture[1] == cfg.toastAccentColor.r,
    "toast applies default opacity and accent color")
cfg.toastOpacity = 0.5; cfg.toastAccentColor = { r = 0.2, g = 0.4, b = 0.8 }
ns.RefreshToastAppearance()
Check(Near(newest.alpha, 0.5) and newest.accent.colorTexture[3] == 0.8,
    "toast opacity and accent color update live")
now = now + 4.5; newest.scripts.OnUpdate(newest)
Check(Near(newest.alpha, 0.25), "toast fades from configured opacity")
now = now + 1; newest.scripts.OnUpdate(newest)
Check(not newest.shown and newest.scripts.OnUpdate == nil, "expired toast releases update handler")
Accept(); ns.RefreshNotificationOutput()
for _, frame in ipairs(toastFrames) do Check(not frame.shown and frame.scripts.OnUpdate == nil, "refresh hides toast and stops updates") end
Accept(); cfg.messages = false
for _, frame in ipairs(toastFrames) do if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame) end end
Check(not toastFrames[3].shown, "message disable stops active toast")
cfg.messages = true
cfg.toastOpacity = 0.92; cfg.toastAccentColor = { r = 0.9, g = 0.62, b = 0.16 }

-- EUI multi-choice row, search prebuild and already-open callback locks.
prebuild = true; local nframes = #frames
module.buildPage("Notifications", UIParent, 0)
Check(#frames == nframes and checklist == nil, "notification page search builds no dropdown frames")
prebuild = false; previewButtons, layoutRows = {}, {}; module.buildPage("Notifications", UIParent, 0)
Check(#checklist.items == 6, "six supported destination choices")
local function HasLayout(section, left, right)
    for _, row in ipairs(layoutRows) do
        if row.section == section and row.left == left and row.right == right then return true end
    end
    return false
end
Check(HasLayout("QUEST NOTIFICATIONS", "Notification messages", nil),
    "message output has its own control under Quest Notifications")
Check(HasLayout("LOCAL TOAST APPEARANCE & POSITION", "Toast opacity", "Toast accent color"),
    "toast appearance pair is under its matching heading")
Check(HasLayout("SOUND OUTPUT", "Notification sounds", "Sound output channel"),
    "sound enable and channel share a row under Sound Output")
Check(HasLayout("SOUND OUTPUT", "Global notification sound", "Play"),
    "global sound selector and preview align under Sound Output")
Check(HasLayout("STATUS CHANGES", "Quest accepted sound", "Play")
    and HasLayout("STATUS CHANGES", "Quest turned in sound", "Play"),
    "status selectors and previews remain paired under Status Changes")
widgets["Notification messages"].setValue(false)
Check(widgets["Message destinations"].disabled() and widgets["Toast opacity"].disabled(),
    "message dependent controls lock immediately when messages are disabled")
widgets["Notification messages"].setValue(true)
widgets["Notification sounds"].setValue(false)
Check(widgets["Global notification sound"].disabled() and widgets["Sound output channel"].disabled()
    and widgets["Quest accepted sound"].disabled(),
    "sound dependent controls lock immediately when sounds are disabled")
widgets["Notification sounds"].setValue(true)
checklist.set("toast", false)
local opacityBefore = cfg.toastOpacity
widgets["Toast opacity"].setValue(0.4)
Check(cfg.toastOpacity == opacityBefore and widgets["Toast opacity"].disabled(), "toast style controls lock until Local toast is selected")
checklist.set("localChat", true); checklist.set("guild", true)
checklist.set("toast", true)
widgets["Toast opacity"].setValue(0.6)
widgets["Toast accent color"].setValue(0.1, 0.3, 0.7)
Check(Near(cfg.toastOpacity, 0.6) and Near(cfg.toastAccentColor.b, 0.7), "toast style controls update saved appearance")
local toastPosition = { cfg.toastX, cfg.toastY }
widgets["Toast position"].onClick()
Check(cfg.toastX == 0 and cfg.toastY == 210, "Toast position Reset restores default anchor")
cfg.toastX, cfg.toastY = toastPosition[1], toastPosition[2]
Check(checklist.get("toast") and checklist.get("localChat") and checklist.get("guild"), "multiple destinations remain independently selected")
checklist.set(secret, true)
cfg.messages = false; cfg.sounds = false
checklist.set("localChat", false)
widgets["Quest accepted sound"].setValue("tell")
Check(cfg.notificationDestinations.localChat and cfg.statusSounds.accepted == "global",
    "disabled message and sound outputs make their related settings inactive")
cfg.messages = true; cfg.sounds = true
widgets["Quest accepted sound"].setValue("none")
Check(cfg.statusSounds.accepted == "none", "per-status selector saves explicit silence")
widgets["Global notification sound"].setValue("raidWarning")
widgets["Quest accepted sound"].setValue("global")
widgets["Sound output channel"].setValue("Music")
Check(ns.NotificationSoundID("accepted") == 4 and cfg.soundChannel == "Music", "expanded sound catalog, fallback and audio selector callbacks")
local beforePreview = #sounds
previewButtons[1].onClick()
Check(#sounds == beforePreview + 1 and sounds[#sounds].id == 4 and sounds[#sounds].channel == "Music",
    "adjacent global preview button plays chosen built-in sound")
beforePreview = #sounds; now = now + 0.4
previewButtons[2].onClick()
Check(#sounds == beforePreview + 1 and sounds[#sounds].id == 4, "adjacent per-status button previews effective fallback")
widgets["Quest accepted sound"].setValue("raidWarning")
now = now + 0.4; beforePreview = #sounds
previewButtons[2].onClick()
Check(#sounds == beforePreview + 1 and sounds[#sounds].id == 4, "per-status preview plays selected individual kit")
widgets["Quest accepted sound"].setValue("peonBuildingComplete1")
now = now + 0.4; beforePreview = #playedFiles
previewButtons[2].onClick()
Check(#playedFiles == beforePreview + 1 and playedFiles[#playedFiles].file == ns.SoundFileIDs.peonBuildingComplete1,
    "per-status dropdown preview plays the requested Peon audio file")
cfg.statusSounds.accepted = "none"
Check(previewButtons[2].disabled(), "None status preview is disabled")
cfg.statusSounds.accepted = "global"
cfg.statusSounds.accepted = "none"
widgets["Quest accepted sound"].setValue("ready")
Check(cfg.statusSounds.accepted == "ready", "choosing an individual sound re-enables a None-disabled status")
local destination = checklist.items[6]
C_ChatInfo.SendChatMessage = nil
checklist.set("guild", false); checklist.set("guild", true)
Check(not cfg.notificationDestinations.guild and destination.lockedFn(), "unsupported destination can be cleared but not newly selected")
EllesmereUI.BuildVisOptsCBDropdown = nil
layoutRows = {}
module.buildPage("Notifications", UIParent, 0)
Check(HasLayout("QUEST NOTIFICATIONS", "Local chat", "Local toast")
    and HasLayout("QUEST NOTIFICATIONS", "Party", "Raid")
    and HasLayout("QUEST NOTIFICATIONS", "Instance/Battleground", "Guild"),
    "older EUI destination toggles remain paired under Quest Notifications")
widgets["Local chat"].setValue(false)
Check(not cfg.notificationDestinations.localChat, "older EUI supports destinations through independent toggles")
ns.settings = nil
EllesmereUIExtendQuestTrackerDB = { soundChannel = "bad", statusSounds = { accepted = "bad", failed = "none" }, statuses = { progress = false },
    notificationDestinations = { localChat = false, guild = secret } }
cfg = addon.Settings()
Check(cfg.soundChannel == "Master" and cfg.statusSounds.accepted == "global" and cfg.statusSounds.failed == "none",
    "malformed sound selections normalize without losing explicit None")
Check(not cfg.notificationDestinations.localChat and not cfg.notificationDestinations.guild, "explicit false and secret destination normalization")
Check(cfg.statusSounds.progress == "none", "old disabled status is preserved as None")
local catalog, catalogOrder = ns.SoundKitOptions(true, true)
Check(#catalogOrder == 15 and catalog.raidWarning == "Raid warning" and catalog.achievement == "Achievement",
    "curated built-in sound catalog is exposed")
Check(catalog.peonYes3 == "Peon: Yes 3" and catalog.peonBuildingComplete1 == "Peon: Building complete"
    and ns.SoundFileIDs.peonYes3 == 558147
    and ns.SoundFileIDs.peonBuildingComplete1 == 558132,
    "both requested Peon sounds map to their FileDataIDs")
SOUNDKIT.RAID_WARNING = nil
catalog, catalogOrder = ns.SoundKitOptions(true, true, "raidWarning")
Check(catalog.raidWarning == "Raid warning (unavailable)", "selected sound stays explainable when unsupported by client")
SOUNDKIT.RAID_WARNING = 4
cfg.sound = "complete"; cfg.soundChannel = "Dialog"; now = now + 1
Check(ns.PreviewNotificationSound("complete"), "global sound preview plays")
Check(sounds[#sounds].id == 2 and sounds[#sounds].channel == "Dialog" and sounds[#sounds].forceNoDuplicates == true,
    "preview uses selected audio channel and duplicate protection")
now = now + 0.4
Check(ns.PreviewEffectiveNotificationSound("accepted"), "individual/effective status sound preview plays")
local previewCount = #sounds
Check(not ns.PreviewNotificationSound("none") and #sounds == previewCount, "None has no preview audio")
now = now + 1
PlaySound = function() error("preview sound restricted") end
Check(not ns.PreviewNotificationSound("ready"), "preview playback errors are safely contained")
PlaySound = Sound
now = now + 1
Check(ns.SoundAvailable("peonYes3") and ns.SoundAvailable("peonBuildingComplete1"), "Peon file sounds are selectable")
Check(ns.PreviewNotificationSound("peonYes3") and playedFiles[#playedFiles].file == ns.SoundFileIDs.peonYes3
    and playedFiles[#playedFiles].channel == cfg.soundChannel, "Peon file preview uses selected channel")
peonFilesAvailable = false; local oldSoundCount = #sounds
cfg.statusSounds.accepted = "peonYes3"; cfg.sound = "complete"
Check(ns.PlayStatusNotificationSound("accepted") and #sounds == oldSoundCount + 1
    and sounds[#sounds].id == SOUNDKIT.IG_QUEST_LIST_COMPLETE,
    "unavailable Peon audio file falls back to global SoundKit playback")
peonFilesAvailable = true
cfg.statusSounds.accepted = "peonBuildingComplete1"
Check(ns.PlayStatusNotificationSound("accepted") and playedFiles[#playedFiles].file == ns.SoundFileIDs.peonBuildingComplete1,
    "status plays requested building-complete file")
peonFilesAvailable = false; cfg.sound = "complete"
Check(ns.PlayStatusNotificationSound("accepted") and sounds[#sounds].id == SOUNDKIT.IG_QUEST_LIST_COMPLETE,
    "failed built-in file playback falls back to global SoundKit sound")
peonFilesAvailable = true; cfg.statusSounds.accepted = "global"
print("PASS: " .. checks .. " notification sound, destination, formatting, toast and UI regression checks")
