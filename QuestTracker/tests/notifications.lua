-- Focused notification integration; no game client or upstream checkout needed.
local ns, frames, messages, sounds, sends, widgets = {}, {}, {}, {}, {}, {}
local now, combat, prebuild, checks = 100, false, false, 0
local playedFiles, peonFilesAvailable = {}, true
local sendFailure = false
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
    function frame:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function frame:SetText(text) self.text = text end
    function frame:SetJustifyH(alignment) self.justifyH = alignment end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:SetColorTexture(...) self.colorTexture = { ... } end
    function frame:CreateFontString() return CreateFrame("FontString", nil, self) end
    function frame:CreateTexture() return CreateFrame("Texture", nil, self) end
    function frame:GetFrameLevel() return 1 end
    function frame:ClearAllPoints() self.point = nil end
    function frame:GetWidth() return self.width or 600 end
    for _, method in ipairs({ "RegisterEvent", "SetPoint", "SetSize", "SetWidth", "SetHeight", "SetAllPoints",
        "SetFrameStrata", "EnableMouse", "SetJustifyV", "SetWordWrap" }) do frame[method] = Noop end
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
local function Send(text, channel)
    sends[#sends + 1] = { text = text, channel = channel }
    if sendFailure then return false end
end
C_ChatInfo = { SendChatMessage = Send, InChatMessagingLockdown = function() return restricted end }
local title, objectiveText, count, finished, ready, questCount = "A Test Quest", "Collect samples: 0/3", 0, false, false, 1
C_QuestLog = {
    GetNumQuestLogEntries = function() return questCount end,
    GetInfo = function() return { questID = 100, isHeader = false, title = title } end,
    GetTitleForQuestID = function() return title end,
    GetQuestObjectives = function() return { { text = objectiveText, numFulfilled = count, finished = finished } } end,
    ReadyForTurnIn = function() return ready end,
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
            local leftRegion, rightRegion = CreateFrame("Frame"), CreateFrame("Frame")
            leftRegion._control, rightRegion._control = CreateFrame("Button"), CreateFrame("Button")
            return { _leftRegion = leftRegion, _rightRegion = rightRegion }, 50
        end,
    },
    BuildVisOptsCBDropdown = function(parent, width, level, items, get, set, _, _, _, _, _, opts)
        Check(not prebuild, "no native checklist work during search prebuild")
        checklist = { items = items, get = get, set = set, opts = opts }
        return CreateFrame("Button", nil, parent), Noop
    end,
    RegisterWidgetRefresh = Noop,
}
assert(loadfile("Core/Core.lua"))("EllesmereUIExtend")
assert(loadfile("Core/Sync.lua"))("EllesmereUIExtend")
assert(loadfile("Core/Options.lua"))("EllesmereUIExtend")
for _, file in ipairs({ "Compatibility", "QuestTracker", "NotificationOutput", "Notifications", "Options" }) do
    assert(loadfile("QuestTracker/" .. file .. ".lua"))("EllesmereUIExtendQuestTracker", ns)
end
assert(EllesmereUIExtend.RegisterOptions())
local addon = ns.Addon
ns.initialized = true
local cfg = addon.Settings()
ns.RefreshNotifications()
cfg.statusSounds.progress = "ready"
Check(ns.StatusSupported("progress") and ns.StatusSupported("ready")
    and not ns.StatusSupported("accepted") and not ns.StatusSupported("objective")
    and not ns.StatusSupported("failed") and not ns.StatusSupported("turnedIn"),
    "only objective progress and ready-for-turn-in statuses are supported")
Check(#messages == 0 and #sounds == 0 and #sends == 0, "silent baseline")
Check(cfg.notificationDestinations.localChat and not cfg.notificationDestinations.toast and not cfg.notificationDestinations.guild,
    "local-chat-only defaults")
Check(cfg.toastOpacity == 0.92 and cfg.toastX == 0 and cfg.toastY == 210,
    "toast opacity and anchor defaults")
local function Progress()
    now, count = now + 2, count + 1
    objectiveText = "Collect samples: " .. count .. "/3"
    ns.ScanNotifications(false)
end
local function Ready(advance)
    ready = false; ns.ScanNotifications(true)
    ready = true
    if advance ~= false then now = now + 2 end
    ns.ScanNotifications(false)
    ready = false; ns.ScanNotifications(true)
end
Progress()
Check(#messages == 1 and #sends == 0 and messages[1]:find("|cffffcc66Objective progress|r", 1, true)
    and messages[1]:find("(#100)", 1, true), "colored local status includes title and quest ID")
cfg.sounds = true; cfg.statusSounds.progress = "complete"; cfg.soundChannel = "SFX"
Progress()
Check(sounds[#sounds].id == 2 and sounds[#sounds].channel == "SFX", "status sound and output channel honored")
for kind in pairs(cfg.statusSounds) do
    cfg.statusSounds[kind] = "tell"
    Check(ns.NotificationSoundID(kind) == 3, "independent sound for " .. kind)
    cfg.statusSounds[kind] = "none"
    Check(ns.NotificationSoundID(kind) == nil, "None silences " .. kind)
    cfg.statusSounds[kind] = kind == "ready" and "ready" or "none"
end
cfg.statusSounds.progress = "tell"; Progress()
Check(sounds[#sounds].id == 3, "selected status sound plays at event delivery")
local beforeUnavailable = #sounds
SOUNDKIT.TELL_MESSAGE = nil; Progress()
Check(#sounds == beforeUnavailable, "unavailable status sound stays silent without a global fallback")
SOUNDKIT.TELL_MESSAGE = 3
cfg.statusSounds.progress = "none"
local beforeSounds, beforeText, beforeSend = #sounds, #messages, #sends
Progress()
Check(#sounds == beforeSounds and #messages == beforeText and #sends == beforeSend,
    "per-status None disables local and shared messages as well as sound")
cfg.statusSounds.progress = "complete"; cfg.statusSounds.ready = "tell"
Progress(); Ready(false)
Check(sounds[#sounds].id == 2 and #sounds == beforeSounds + 1, "one-second sound burst throttle preserves first status sound")
Ready(); Check(sounds[#sounds].id == 3, "ready status uses its own sound")
cfg.soundChannel = "Dialog"; Progress()
Check(sounds[#sounds].channel == "Dialog", "selected audio channel reaches playback API")
PlaySound = function() return false end; Progress()
PlaySound = Sound
Ready(false)
Check(sounds[#sounds].id == 3, "failed playback does not consume sound throttle")

cfg.sounds = false
for key in pairs(cfg.notificationDestinations) do cfg.notificationDestinations[key] = key ~= "toast" end
party, guild = true, true
local start = #sends
Progress()
Check(#sends == start + 2 and sends[start + 1].channel == "PARTY" and sends[start + 2].channel == "GUILD",
    "multi-select sends to eligible party and guild only")
local last = #sends
Ready(false)
Check(#sends == last, "per-destination burst throttle suppresses immediate second status")
raid, instance = true, true
start = #sends; Progress()
Check(#sends == start + 3 and sends[start + 1].channel == "RAID" and sends[start + 2].channel == "INSTANCE_CHAT",
    "raid excludes party, instance group routes to INSTANCE_CHAT")
party, raid, guild = false, false, false
start = #sends; Progress()
Check(#sends == start + 1 and sends[#sends].channel == "INSTANCE_CHAT", "instance-only group never sends to regular party")
now = now + 2; sendFailure = true
start = #sends; Progress()
Check(#sends == start + 1, "explicitly failed chat send is attempted")
sendFailure = false; now = now + 2
start = #sends; Progress()
Check(#sends == start + 1, "explicitly failed chat send does not consume destination throttle")
restricted = true
start = #sends; local beforeMessages = #messages
Progress()
Check(#sends == start and #messages == beforeMessages + 1, "chat lockdown preserves local notification and skips broadcast")
restricted = secret; Progress()
Check(#sends == start, "unreadable chat lockdown fails closed")
restricted = false; instance = secret; guild = secret; party = secret
Progress(); Check(#sends == start, "unreadable group membership fails closed")
instance, guild, party = true, false, false
C_ChatInfo = nil; SendChatMessage = Send; EUI_CLIENT_FOREVER = true
Progress(); Check(#sends == start + 1, "Forever legacy chat sender fallback")
SendChatMessage = nil
Progress(); Check(#sends == start + 1, "missing send API does not affect local output")
C_ChatInfo = { SendChatMessage = function() error("restricted send") end }; Progress()
Check(#sends == start + 1, "throwing send does not escape notification handler")
C_ChatInfo = { SendChatMessage = Send, InChatMessagingLockdown = function() return false end }
EUI_CLIENT_FOREVER = nil
cfg.messages = false; cfg.sounds = true
local noText, noSend, withSound = #messages, #sends, #sounds
Progress()
Check(#messages == noText and #sends == noSend and #sounds == withSound + 1, "message master does not silence enabled audio")
cfg.statusSounds.progress = "none"
withSound = #sounds; Progress()
Check(#sounds == withSound and #messages == noText and #sends == noSend, "disabled status suppresses every output")
cfg.statusSounds.progress = "ready"; cfg.messages = true
for key in pairs(cfg.notificationDestinations) do cfg.notificationDestinations[key] = false end
Progress()
Check(#messages == noText and #sends == noSend and #sounds == withSound + 1, "empty destinations suppress messages but keep independent audio")
cfg.sounds = false

local formatted = ns.FormatQuestNotification("progress", 100, "|cffff0000Title|r\n|Tbad|t", "|Hbad|hDetails|h\rtest")
Check(formatted.plain:find("Title", 1, true) and not formatted.plain:find("|", 1, true)
    and not formatted.plain:find("\n", 1, true), "outbound text strips injected colors textures links and controls")
formatted = ns.FormatQuestNotification("progress", 100, string.rep("é", 100), string.rep("界", 150))
Check(#formatted.plain <= 255 and utf8.len(formatted.plain) ~= nil, "long localized messages are byte bounded without broken UTF-8")
Check(ns.FormatQuestNotification("accepted", secret, "Title") == nil
    and ns.FormatQuestNotification("progress", 100, secret) == nil, "unknown statuses and secret titles never formatted")
cfg.notificationDestinations.localChat = true
cfg.statusSounds.progress = "ready"
ns.RefreshNotifications(); count = count + 1; objectiveText = "Collect samples: " .. count .. "/3"
ns.ScanNotifications(false)
Check(messages[#messages]:find(objectiveText, 1, true), "objective progress carries readable objective detail")
beforeMessages = #messages; ns.ScanNotifications(false)
Check(#messages == beforeMessages, "unchanged objectives do not repeat")
finished = true; ns.ScanNotifications(false)
Check(#messages == beforeMessages, "finishing an objective without progress does not create a removed status")
finished = false
questCount = 0; ns.ScanNotifications(false)
questCount = 1; count = 3; objectiveText = "Collect samples: 3/3"
beforeMessages = #messages; ns.ScanNotifications(false)
Check(#messages == beforeMessages, "re-added quest seeds a fresh baseline without stale progress notification")

-- Toast lifecycle: three reusable, non-clickable local frames with timed fade.
for key in pairs(cfg.notificationDestinations) do cfg.notificationDestinations[key] = key == "toast" end
start = #sends; beforeMessages = #messages
for _ = 1, 4 do Progress() end
local toastFrames = {}
for _, frame in ipairs(frames) do if frame.heading and frame.body then toastFrames[#toastFrames + 1] = frame end end
Check(#toastFrames == 3 and #sends == start and #messages == beforeMessages, "toast-only output uses bounded local frame pool")
local newest = toastFrames[1]
Check(newest.body.text:find("A Test Quest", 1, true), "toast has readable quest details")
Check(Near(newest.alpha, 1) and Near(newest.bg.colorTexture[4], 0.92)
    and newest.heading.text:find("|cffe69e29", 1, true) and newest.accent == nil and newest.border == nil,
    "toast applies default opacity to background and heading color without accent frames")
cfg.toastOpacity = 0.5; cfg.toastAccentColor = { r = 0.2, g = 0.4, b = 0.8 }
ns.RefreshToastAppearance()
Check(Near(newest.alpha, 1) and Near(newest.bg.colorTexture[4], 0.5)
    and newest.heading.text:find("|cff3366cc", 1, true),
    "toast background opacity and configurable heading color update live")
now = now + 4.5; newest.scripts.OnUpdate(newest)
Check(Near(newest.alpha, 0.5) and Near(newest.bg.colorTexture[4], 0.5), "toast exit animation still fades all surfaces")
now = now + 1; newest.scripts.OnUpdate(newest)
Check(not newest.shown and newest.scripts.OnUpdate == nil, "expired toast releases update handler")
Progress(); ns.RefreshNotificationOutput()
for _, frame in ipairs(toastFrames) do Check(not frame.shown and frame.scripts.OnUpdate == nil, "refresh hides toast and stops updates") end
Progress(); cfg.messages = false
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
Check(HasLayout("QUEST MESSAGE NOTIFICATIONS", "Notification messages", "Message destinations"),
    "message toggle and destinations share a row under Quest Message Notifications")
Check(HasLayout("LOCAL TOAST APPEARANCE & POSITION", "Toast opacity", "Toast heading color"),
    "toast appearance pair is under its matching heading")
Check(HasLayout("QUEST SOUND NOTIFICATIONS", "Notification sounds", "Sound output channel"),
    "sound enable and channel share a row under Sound Output")
Check(HasLayout("QUEST STATUS SOUNDS", "Objective progress sound", "Play")
    and HasLayout("QUEST STATUS SOUNDS", "Ready for turn-in sound", "Play"),
    "only the two supported statuses have sound selectors")
Check(widgets["Quest accepted sound"] == nil and widgets["Quest failed sound"] == nil
    and widgets["Quest turned in sound"] == nil and widgets["Objective completed sound"] == nil,
    "removed statuses are absent from notification settings")
Check(widgets["Global notification sound"] == nil, "global sound selector is removed")
widgets["Notification messages"].setValue(false)
Check(widgets["Message destinations"].disabled() and widgets["Toast opacity"].disabled(),
    "message dependent controls lock immediately when messages are disabled")
widgets["Notification messages"].setValue(true)
widgets["Notification sounds"].setValue(false)
Check(widgets["Sound output channel"].disabled()
    and widgets["Objective progress sound"].disabled() and widgets["Ready for turn-in sound"].disabled(),
    "sound dependent controls lock immediately when sounds are disabled")
widgets["Notification sounds"].setValue(true)
Check(widgets["Toast opacity"].min == 0 and widgets["Toast opacity"].max == 100
    and widgets["Toast opacity"].getValue() == 92, "toast opacity control uses a 0–100 percent scale")
checklist.set("toast", false)
local opacityBefore = cfg.toastOpacity
widgets["Toast opacity"].setValue(40)
Check(cfg.toastOpacity == opacityBefore and widgets["Toast opacity"].disabled(), "toast style controls lock until Local toast is selected")
checklist.set("localChat", true); checklist.set("guild", true)
checklist.set("toast", true)
widgets["Toast opacity"].setValue(60)
widgets["Toast heading color"].setValue(0.1, 0.3, 0.7)
Check(Near(cfg.toastOpacity, 0.6) and Near(cfg.toastAccentColor.b, 0.7), "toast style controls update saved appearance")
widgets["Toast text alignment"].setValue("center")
Check(cfg.toastTextAlign == "center" and newest.heading.justifyH == "CENTER" and newest.body.justifyH == "CENTER",
    "toast alignment applies to heading and body")
widgets["Toast text alignment"].setValue("right")
Check(newest.heading.justifyH == "RIGHT" and newest.body.justifyH == "RIGHT", "right toast alignment updates both text regions")
widgets["Toast text alignment"].setValue("left")
widgets["Toast opacity"].setValue(0)
Check(cfg.toastOpacity == 0, "zero-percent toast background opacity is supported")
widgets["Toast opacity"].setValue(100)
Check(cfg.toastOpacity == 1 and widgets["Toast opacity"].getValue() == 100, "100-percent toast background opacity is supported")
widgets["Toast opacity"].setValue(60)
local toastPosition = { cfg.toastX, cfg.toastY }
widgets["Toast position"].onClick()
Check(cfg.toastX == 0 and cfg.toastY == 210, "Toast position Reset restores default anchor")
cfg.toastX, cfg.toastY = toastPosition[1], toastPosition[2]
Check(checklist.get("toast") and checklist.get("localChat") and checklist.get("guild"), "multiple destinations remain independently selected")
checklist.set(secret, true)
cfg.messages = false; cfg.sounds = false
checklist.set("localChat", false)
widgets["Objective progress sound"].setValue("tell")
Check(cfg.notificationDestinations.localChat and cfg.statusSounds.progress == "ready",
    "disabled message and sound outputs make their related settings inactive")
cfg.messages = true; cfg.sounds = true
local toastMover, toastEditListener
EllesmereUI.MakeUnlockElement = function(opts) toastMover = opts; return opts end
EllesmereUI.RegisterUnlockElements = Noop
EllesmereUI.RegisterUnlockModeListener = function(_, _, callback) toastEditListener = callback end
EllesmereUI.IsUnlockModeActive = function() return false end
Check(ns.RegisterToastMover(), "toast mover registers for preview alignment coverage")
local editorSample = toastMover.getFrame()
cfg.toastTextAlign = "center" -- Simulate a saved setting changed before the editor opens.
editorSample.heading.justifyH, editorSample.body.justifyH = "LEFT", "LEFT"
editorSample:Show()
Check(editorSample.heading.justifyH == "CENTER" and editorSample.body.justifyH == "CENTER",
    "showing a cached toast editor sample refreshes text alignment")
editorSample:Hide()
toastEditListener(true)
Check(editorSample.shown and editorSample.heading.justifyH == "CENTER" and editorSample.body.justifyH == "CENTER",
    "opening the toast editor refreshes both text alignments from current settings")
toastEditListener(false, "exit")
widgets["Objective progress sound"].setValue("none")
Check(cfg.statusSounds.progress == "none", "per-status selector saves explicit silence")
widgets["Objective progress sound"].setValue("raidWarning")
widgets["Sound output channel"].setValue("Music")
Check(ns.NotificationSoundID("progress") == 4 and cfg.soundChannel == "Music", "per-status sound and audio selector callbacks")
local beforePreview = #sounds
previewButtons[1].onClick()
Check(#sounds == beforePreview + 1 and sounds[#sounds].id == 4 and sounds[#sounds].channel == "Music",
    "per-status preview button plays chosen built-in sound")
beforePreview = #sounds; now = now + 0.4
previewButtons[2].onClick()
Check(#sounds == beforePreview + 1 and sounds[#sounds].id == 3, "ready status preview plays its own selected sound")
widgets["Objective progress sound"].setValue("raidWarning")
now = now + 0.4; beforePreview = #sounds
previewButtons[1].onClick()
Check(#sounds == beforePreview + 1 and sounds[#sounds].id == 4, "per-status preview plays selected individual kit")
widgets["Objective progress sound"].setValue("peonBuildingComplete1")
now = now + 0.4; beforePreview = #playedFiles
previewButtons[1].onClick()
Check(#playedFiles == beforePreview + 1 and playedFiles[#playedFiles].file == ns.SoundFileIDs.peonBuildingComplete1,
    "per-status dropdown preview plays the requested Peon audio file")
cfg.statusSounds.progress = "none"
Check(previewButtons[1].disabled(), "None status preview is disabled")
cfg.statusSounds.progress = "none"
widgets["Objective progress sound"].setValue("ready")
Check(cfg.statusSounds.progress == "ready", "choosing an individual sound re-enables a None-disabled status")
local destination = checklist.items[6]
C_ChatInfo.SendChatMessage = nil
checklist.set("guild", false); checklist.set("guild", true)
Check(not cfg.notificationDestinations.guild and destination.lockedFn(), "unsupported destination can be cleared but not newly selected")
EllesmereUI.BuildVisOptsCBDropdown = nil
layoutRows = {}
module.buildPage("Notifications", UIParent, 0)
Check(HasLayout("QUEST MESSAGE NOTIFICATIONS", "Local chat", "Local toast")
    and HasLayout("QUEST MESSAGE NOTIFICATIONS", "Party", "Raid")
    and HasLayout("QUEST MESSAGE NOTIFICATIONS", "Instance/Battleground", "Guild"),
    "older EUI destination toggles remain paired under Quest Notifications")
widgets["Local chat"].setValue(false)
Check(not cfg.notificationDestinations.localChat, "older EUI supports destinations through independent toggles")
ns.settings = nil
EllesmereUIExtendDB = { profiles = { Default = { questTracker = { soundChannel = "bad", statusSounds = { accepted = "bad", failed = "none", progress = "none", ready = "none" },
    notificationDestinations = { localChat = false, guild = secret } } } } }
cfg = addon.Settings()
Check(cfg.soundChannel == "Master" and cfg.statusSounds.progress == "none" and cfg.statusSounds.ready == "none"
    and cfg.statusSounds.accepted == nil and cfg.statusSounds.failed == nil,
    "malformed sound selections normalize without losing explicit None")
Check(not cfg.notificationDestinations.localChat and not cfg.notificationDestinations.guild, "explicit false and secret destination normalization")
Check(cfg.statusSounds.progress == "none", "explicit None is preserved")
local catalog, catalogOrder = ns.SoundKitOptions(true)
Check(#catalogOrder == 14 and catalog.raidWarning == "Raid warning" and catalog.achievement == "Achievement"
    and catalog.global == nil,
    "curated built-in sound catalog is exposed")
Check(catalog.peonYes3 == "Peon: Work, Work" and catalog.peonBuildingComplete1 == "Peon: Work complete"
    and ns.SoundFileIDs.peonYes3 == 558147
    and ns.SoundFileIDs.peonBuildingComplete1 == 558132,
    "both requested Peon sounds map to their FileDataIDs")
SOUNDKIT.RAID_WARNING = nil
catalog, catalogOrder = ns.SoundKitOptions(true, "raidWarning")
Check(catalog.raidWarning == "Raid warning (unavailable)", "selected sound stays explainable when unsupported by client")
SOUNDKIT.RAID_WARNING = 4
cfg.soundChannel = "Dialog"; now = now + 1
Check(ns.PreviewNotificationSound("complete"), "selected sound preview plays")
Check(sounds[#sounds].id == 2 and sounds[#sounds].channel == "Dialog" and sounds[#sounds].forceNoDuplicates == true,
    "preview uses selected audio channel and duplicate protection")
now = now + 0.4
cfg.statusSounds.progress = "complete"
Check(ns.PreviewNotificationSound(cfg.statusSounds.progress), "status preview plays its selected sound directly")
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
cfg.statusSounds.progress = "peonYes3"
Check(not ns.PlayStatusNotificationSound("progress") and #sounds == oldSoundCount,
    "unavailable selected sound stays silent without a global fallback")
peonFilesAvailable = true
cfg.statusSounds.progress = "peonBuildingComplete1"
Check(ns.PlayStatusNotificationSound("progress") and playedFiles[#playedFiles].file == ns.SoundFileIDs.peonBuildingComplete1,
    "status plays requested building-complete file")
peonFilesAvailable = false; oldSoundCount = #sounds
Check(not ns.PlayStatusNotificationSound("progress") and #sounds == oldSoundCount,
    "failed selected sound does not fall back to another sound")
peonFilesAvailable = true; cfg.statusSounds.progress = "ready"
print("PASS: " .. checks .. " notification sound, destination, formatting, toast and UI regression checks")
