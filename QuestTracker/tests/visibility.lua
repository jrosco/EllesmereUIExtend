-- Read-only integration with the actual EUI shared visibility compiler.
-- Set EUI_TEST_ROOT to the upstream checkout. No WoW rendering is simulated.
local root = (os.getenv and os.getenv("EUI_TEST_ROOT")) or "../jrosco-EllesmereUI"
EllesmereUI = {}
local inRaid, inParty, inInstance, hovering = false, false, false, false
function IsInRaid() return inRaid end
function IsInGroup() return inRaid or inParty end
function InCombatLockdown() return false end
function IsFlying() return false end
function IsMounted() return false end
function UnitExists() return false end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function GetTime() return 100 end
C_Timer = { After = function() end }
function CreateFrame()
    return { RegisterEvent = function() end, RegisterUnitEvent = function() end, SetScript = function() end }
end
function RegisterStateDriver() end
function UnregisterStateDriver() end
assert(loadfile(root .. "/EllesmereUI_VisibilityRules.lua"))()
assert(loadfile(root .. "/EllesmereUI_Visibility.lua"))()
EllesmereUI.IsInInstancedContent = function() return inInstance end
EllesmereUI.IsPlayerSkyriding = function() return false end
EllesmereUI.IsPartyModeActive = function() return false end
local ns, store = {}, {}
assert(loadfile("QuestTracker/Compatibility.lua"))("EllesmereUIExtendQuestTracker", ns)
ns.Addon = { Settings = function() return { itemVisibility = store } end }
assert(loadfile("QuestTracker/ItemVisibility.lua"))("EllesmereUIExtendQuestTracker", ns)
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Select(selection, match, options)
    store = options or {}
    store.visibilityMatch = match or "all"
    EllesmereUI.SetVisibilitySelection(store, "visibility", selection)
end
local function Contains(text) return ns.BuildItemVisibilityDriver():find(text, 1, true) ~= nil end
Select({ always = true })
Check(ns.HasItemVisibility(), "real shared compiler API available")
Check(Contains("[petbattle] hide; show"), "Always native tail")
Select({ never = true })
Check(ns.BuildItemVisibilityDriver() == "hide", "Never terminal")
Select({ in_combat = true })
Check(Contains("[combat] show; hide"), "combat remains live in the native driver")
Select({ out_of_combat = true })
Check(Contains("[nocombat] show; hide"), "out-of-combat native driver")
Select({ in_combat = true, in_raid = true })
Check(Contains("[combat,group:raid] show; hide"), "All combines axes")
Select({ in_combat = true, in_raid = true }, "any")
Check(Contains("[combat] show;") and Contains("[group:raid] show;"), "Any emits disjuncts")
Select({ in_party = true })
Check(Contains("[group:party,nogroup:raid] show;"), "party excludes raid as in Action Bars")
Select({ always = true }, "all", { visHideMounted = true, visHideWithTarget = true })
Check(Contains("[mounted] hide;") and Contains("[exists] hide;"), "native option Hide gates")
Select({ always = true }, "all", { visOnlyInstances = true })
Check(ns.BuildItemVisibilityDriver() == "hide", "Lua-only instance requirement fails closed outside instances")
inInstance = true
Check(Contains("show"), "Lua-only instance requirement recompiled inside instances")
Select({ in_combat = true }, "any", { visOnlyInstances = true })
inInstance = false
Check(Contains("[combat] show;"), "Any still uses live combat disjunct when instance does not match")
Select({ mouseover = true })
local frame = { SetAlpha = function(self, alpha) self.alpha = alpha end }
ns.ItemVisibilityAlpha(frame, false)
Check(frame.alpha == 0, "mouseover starts faded")
ns.ItemVisibilityAlpha(frame, true)
Check(frame.alpha == 1, "mouseover reveals on hover")
Select({ mouseover = true, in_raid = true }, "any")
inRaid = true
ns.ItemVisibilityAlpha(frame, false)
Check(frame.alpha == 1, "Any passing condition shows outright, no hover required")
inRaid = false
ns.ItemVisibilityAlpha(frame, false)
Check(frame.alpha == 0, "Any fallback remains hover-revealable")
Select({ hide_in_combat = true })
Check(Contains("nocombat") or Contains("[combat] hide"), "hide-only mode set compiles a veto")
Select({ in_combat = true }, "any", { visHideInstances = true })
inInstance = true
Check(ns.BuildItemVisibilityDriver():match("hide$") and not Contains("[combat] show"), "Any does not override a Lua Hide veto")
Select({ always = true })
local compiler = EllesmereUI.BuildVisibilityDriverString
EllesmereUI.BuildVisibilityDriverString = function() error("restricted visibility probe") end
Check(ns.BuildItemVisibilityDriver() == "hide", "compiler failures do not fabricate a visible result")
EllesmereUI.BuildVisibilityDriverString = compiler
Select({ mouseover = true })
local hoverProbe = EllesmereUI.VisWantsMouseover
EllesmereUI.VisWantsMouseover = function() error("unreadable hover condition") end
ns.ItemVisibilityAlpha(frame, true)
Check(frame.alpha == 0, "hover cannot reveal unreadable conditions")
EllesmereUI.VisWantsMouseover = hoverProbe
print("PASS: " .. checks .. " real-EUI visibility compiler and mouseover integration checks")
