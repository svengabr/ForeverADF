-- Forever ADF: debuff frame for WoW: Forever.
-- A from-scratch port of the Turtle WoW addon aDF (Atreyyo, Zebouski, Autignem).
--
-- Core: saved variables, the list of debuffs, which unit the frame describes, events and the slash command.
--
-- What the original also showed, the target's armor and resistances, does not exist here: the Forever client
-- answers 0 for both on every enemy. And while the player is in combat it lets addons read nothing about a
-- unit's debuffs. So the addon reads no debuffs at all: the client draws them itself (see Frame.lua).
local ADDON, ns = ...
ForeverADF = ns

local L = ns.L

ns.MAX_ENTRIES = 30 -- what the options window has room for (two columns of 15)

local DEFAULTS = {
	enabled = true,
	x = 0, y = -160,
	iconSize = 30,
	perRow = 7,
	showTimers = true,
	hideOOC = false,
	hideSolo = false,
	hideNoTarget = false,
	locked = false,
	clickThrough = false,
	debuffs = {}, -- [key] = true/false, overrides the default of the entry
	custom = {}, -- list of { id = number }: the player's own debuffs
}

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

-------------------------------------------------------------------------------
-- Utilities
-------------------------------------------------------------------------------

local issecretvalue = issecretvalue or function() return false end

-- The value, or nil if the client hands it out as a secret (a value an addon may show but not look at).
local function Plain(value)
	if issecretvalue(value) then return nil end
	return value
end

function ns.Print(...)
	print("|cffF5F54AForever ADF|r:", ...)
end

-- Calls an API function; nil if it is missing or errors (restricted unit tokens raise errors on this client).
local function Try(func, ...)
	if not func then return nil end
	local ok, a, b = pcall(func, ...)
	if ok then return a, b end
	return nil
end

local function SpellName(id)
	if not (C_Spell and C_Spell.GetSpellName) then return nil end
	local name = Plain(Try(C_Spell.GetSpellName, id))
	if type(name) == "string" and name ~= "" then return name end
	return nil
end

local function SpellTexture(id)
	if not (C_Spell and C_Spell.GetSpellTexture) then return nil end
	return Plain(Try(C_Spell.GetSpellTexture, id))
end

local function MergeDefaults(dst, src)
	for key, value in pairs(src) do
		if type(value) == "table" then
			if type(dst[key]) ~= "table" then dst[key] = {} end
			MergeDefaults(dst[key], value)
		elseif dst[key] == nil then
			dst[key] = value
		end
	end
end

-------------------------------------------------------------------------------
-- Debuff list
-------------------------------------------------------------------------------

ns.entries = {} -- every known debuff, built-in first, then the player's own
ns.visible = {} -- the enabled ones, in display order
ns.byKey = {}
local idOwner = {} -- [spell id] = key

function ns.IsEnabled(key)
	local saved = ns.db.debuffs[key]
	if saved ~= nil then return saved end
	local entry = ns.byKey[key]
	return entry ~= nil and (entry.custom ~= nil or entry.default == true) or false
end

function ns.SetEnabled(key, enabled)
	ns.db.debuffs[key] = enabled and true or false
	ns.Refresh()
end

-- (Re)builds the list of debuffs. Runs at login and whenever the player's own list changes.
function ns.BuildIndex()
	local entries, byKey = {}, {}
	idOwner = {}

	for _, def in ipairs(ns.Debuffs) do
		local entry = { key = def.key, default = def.default, ids = {} }
		for _, id in ipairs(def.ids) do
			-- ids the client does not know are left out: Forever dropped or renumbered some vanilla spells
			if SpellName(id) then
				entry.ids[#entry.ids + 1] = id
				idOwner[id] = def.key
			end
		end
		local first = entry.ids[1]
		if first then
			entry.label = SpellName(first)
			if def.note then entry.label = entry.label .. " (" .. def.note .. ")" end
			entry.icon = SpellTexture(first) or ("Interface\\Icons\\" .. def.icon)
			entries[#entries + 1] = entry
			byKey[entry.key] = entry
		end
	end

	for _, custom in ipairs(ns.db.custom) do
		local key = "id:" .. custom.id
		if not byKey[key] and not idOwner[custom.id] then
			idOwner[custom.id] = key
			local entry = {
				key = key, custom = custom, ids = { custom.id },
				label = SpellName(custom.id) or ("#" .. custom.id),
				icon = SpellTexture(custom.id) or QUESTION_MARK,
			}
			entries[#entries + 1] = entry
			byKey[key] = entry
		end
	end

	ns.entries, ns.byKey = entries, byKey
	ns.BuildVisible()
end

function ns.BuildVisible()
	local visible = {}
	for _, entry in ipairs(ns.entries) do
		if ns.IsEnabled(entry.key) then visible[#visible + 1] = entry end
	end
	ns.visible = visible
end

-- Adds a debuff by spell id. Returns the label on success, or nil and a message.
function ns.AddCustom(text)
	text = strtrim(text or "")
	if text == "" then return nil end
	local id = tonumber(text)
	if not id then return nil, L["Please enter a spell ID (a number)."] end
	id = math.floor(id)
	local name = SpellName(id)
	if not name then return nil, L["There is no spell with ID %d in this client."]:format(id) end
	if idOwner[id] then return nil, L["%s is already in the list."]:format(name) end
	if #ns.entries >= ns.MAX_ENTRIES then
		return nil, L["The list is full (%d debuffs)."]:format(ns.MAX_ENTRIES)
	end
	table.insert(ns.db.custom, { id = id })
	ns.db.debuffs["id:" .. id] = true
	ns.BuildIndex()
	ns.Refresh()
	return name
end

function ns.RemoveCustom(key)
	for index, custom in ipairs(ns.db.custom) do
		if "id:" .. custom.id == key then
			table.remove(ns.db.custom, index)
			ns.db.debuffs[key] = nil
			ns.BuildIndex()
			ns.Refresh()
			return true
		end
	end
	return false
end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------

local inCombat = false

-- The unit to describe: a hostile target, or what a friendly target is fighting (a tank's or healer's target).
local function PickUnit()
	if not Try(UnitExists, "target") then return nil end
	if Try(UnitCanAttack, "player", "target") then return "target" end
	if Try(UnitExists, "targettarget") and Try(UnitCanAttack, "player", "targettarget") then
		return "targettarget"
	end
	return nil
end

local function ShouldShow(unit)
	local db = ns.db
	if not db.enabled then return false end
	if db.hideOOC and not inCombat then return false end
	if db.hideSolo and not (IsInGroup and IsInGroup()) then return false end
	if db.hideNoTarget and not unit then return false end
	return true
end

-- rebind: the unit token is the same as before but now means another mob.
function ns.Update(rebind)
	local hud = ns.HUD
	if not hud then return end
	local unit = PickUnit()
	ns.unit = unit
	hud:BindUnit(unit, rebind == true)
	hud:SetShown(ShouldShow(unit))
end

-- After an option changed: rebuild what is shown.
function ns.Refresh()
	ns.BuildVisible()
	if ns.HUD then ns.HUD:Layout() end
	ns.Update()
end

function ns.ResetPosition()
	ns.db.x, ns.db.y = DEFAULTS.x, DEFAULTS.y
	if ns.HUD then ns.HUD:ApplyPosition() end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		if type(ForeverADFCharDB) ~= "table" then ForeverADFCharDB = {} end
		local db = ForeverADFCharDB
		MergeDefaults(db, DEFAULTS)
		-- settings of features that were removed in 2.0.0
		db.showArmor, db.showResists, db.channel, db.announceDrops = nil, nil, nil, nil
		for index = #db.custom, 1, -1 do
			if type(db.custom[index]) ~= "table" or type(db.custom[index].id) ~= "number" then
				table.remove(db.custom, index) -- entries by name cannot be shown in combat
			end
		end
		ns.db = db
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		inCombat = InCombatLockdown and InCombatLockdown() or false
		ns.BuildIndex()
		ns.CreateHUD()
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("UNIT_TARGET")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("GROUP_ROSTER_UPDATE")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		-- "targettarget" becoming attackable or not has no event of its own
		C_Timer.NewTicker(0.5, function() ns.Update() end)
		ns.Update()
		ns.Print(L["Loaded. Type /adf for the options."])
	elseif event == "PLAYER_TARGET_CHANGED" then
		ns.Update(true)
	elseif event == "UNIT_TARGET" then
		if arg1 == "target" then ns.Update(true) end
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
		ns.Update()
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		if ns.HUD and ns.HUD.pendingLayout then ns.HUD:Layout() end
		ns.Update()
	else
		ns.Update()
	end
end)

-------------------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------------------

SLASH_FOREVERADF1 = "/adf"
SLASH_FOREVERADF2 = "/foreveradf"
SlashCmdList["FOREVERADF"] = function(message)
	local command = strlower(strtrim(message or ""))
	if not ns.db or not ns.HUD then return end
	if command == "" or command == "options" or command == "config" then
		ns.ToggleOptions()
	elseif command == "show" then
		ns.db.enabled = true
		ns.Update()
		ns.Print(L["Frame shown."])
	elseif command == "hide" then
		ns.db.enabled = false
		ns.Update()
		ns.Print(L["Frame hidden. Type /adf show to bring it back."])
	elseif command == "lock" or command == "unlock" then
		ns.db.locked = command == "lock" and not ns.db.locked
		ns.Refresh()
		ns.Print(ns.db.locked and L["Frame locked."] or L["Frame unlocked. Hold Shift and drag to move it."])
	elseif command == "reset" then
		ns.ResetPosition()
		ns.Print(L["Position reset."])
	else
		ns.Print(L["Commands:"])
		print("  /adf – " .. L["open the options"])
		print("  /adf show – " .. L["show the frame"])
		print("  /adf hide – " .. L["hide the frame"])
		print("  /adf lock – " .. L["lock or unlock the frame"])
		print("  /adf reset – " .. L["reset the position"])
		return
	end
	if ns.RefreshOptions then ns.RefreshOptions() end
end
