-- Forever ADF: armor and debuff frame for WoW: Forever.
-- A from-scratch port of the Turtle WoW addon aDF (Atreyyo, Zebouski, Autignem).
--
-- Core: saved variables, the debuff index, reading the target, chat announcements, events and the slash command.
-- The client is 12.x-based and may hand out aura and stat values as "secrets" (values an addon can show but not
-- compare or calculate with). Every API value goes through Plain() before the addon looks at it.
local ADDON, ns = ...
ForeverADF = ns

local L = ns.L

ns.MAX_ENTRIES = 30 -- what the options window has room for (two columns of 15)
ns.CHANNELS = { "AUTO", "SAY", "YELL", "PARTY", "RAID", "RAID_WARNING", "SELF" }
ns.CHANNEL_LABELS = {
	AUTO = "Automatic", SAY = "Say", YELL = "Yell", PARTY = "Party", RAID = "Raid",
	RAID_WARNING = "Raid warning", SELF = "Only me",
}

local DEFAULTS = {
	enabled = true,
	x = 0, y = -160,
	iconSize = 30,
	perRow = 7,
	showArmor = true,
	showResists = false,
	showTimers = true,
	hideOOC = false,
	hideSolo = false,
	hideNoTarget = false,
	locked = false,
	clickThrough = false,
	channel = "AUTO",
	announceDrops = false,
	debuffs = {}, -- [key] = true/false, overrides the default of the entry
	custom = {}, -- list of { id = number } or { name = string }, optional icon
}

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local RESIST_SCHOOLS = { 2, 3, 4, 5, 6 } -- fire, nature, frost, shadow, arcane

-------------------------------------------------------------------------------
-- Utilities
-------------------------------------------------------------------------------

local issecretvalue = issecretvalue or function() return false end

-- The value, or nil if the client hands it out as a secret.
local function Plain(value)
	if issecretvalue(value) then return nil end
	return value
end
ns.Plain = Plain
ns.IsSecret = issecretvalue

function ns.Print(...)
	print("|cffF5F54AForever ADF|r:", ...)
end

-- Calls an API function; nil if it is missing or errors (restricted unit tokens raise errors on this client).
local function Try(func, ...)
	if not func then return nil end
	local ok, a, b, c, d = pcall(func, ...)
	if ok then return a, b, c, d end
	return nil
end
ns.Try = Try

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
-- Debuff index
-------------------------------------------------------------------------------

ns.entries = {} -- every known debuff, built-in first, then the player's own
ns.visible = {} -- the enabled ones, in display order
ns.byKey = {}
local byId, byName = {}, {}

function ns.IsEnabled(key)
	local saved = ns.db.debuffs[key]
	if saved ~= nil then return saved end
	local entry = ns.byKey[key]
	return entry ~= nil and (entry.custom or entry.default) or false
end

function ns.SetEnabled(key, enabled)
	ns.db.debuffs[key] = enabled and true or false
	ns.Refresh()
end

function ns.CustomKey(custom)
	if custom.id then return "id:" .. custom.id end
	return "name:" .. custom.name
end

-- (Re)builds the list of debuffs and the lookup tables. Runs at login and whenever the player's own list changes.
function ns.BuildIndex()
	local entries, byKey, nameOwner = {}, {}, {}
	byId, byName = {}, {}

	-- A name that two entries share (both "Shadow Vulnerability" debuffs) identifies neither; those need the id.
	local function Claim(name, key)
		if nameOwner[name] == nil then
			nameOwner[name] = key
		elseif nameOwner[name] ~= key then
			nameOwner[name] = false
		end
	end

	for _, def in ipairs(ns.Debuffs) do
		local entry = {
			key = def.key, armor = def.armor, default = def.default, names = {},
			ids = def.ids, reduce = def.reduce, perStack = def.perStack,
		}
		for _, id in ipairs(def.ids) do
			byId[id] = def.key
			local name = SpellName(id)
			if name then
				entry.spellId = entry.spellId or id
				entry.names[name] = true
				Claim(name, def.key)
			end
		end
		entry.names[def.name] = true
		Claim(def.name, def.key)
		entry.label = (entry.spellId and SpellName(entry.spellId)) or def.name
		entry.chatName = entry.label
		if def.note then entry.label = entry.label .. " (" .. def.note .. ")" end
		entry.icon = (entry.spellId and SpellTexture(entry.spellId)) or ("Interface\\Icons\\" .. def.icon)
		entries[#entries + 1] = entry
		byKey[entry.key] = entry
	end

	for _, custom in ipairs(ns.db.custom) do
		local key = ns.CustomKey(custom)
		if not byKey[key] then
			local entry = { key = key, custom = custom, names = {}, ids = { custom.id } }
			if custom.id then
				if not byId[custom.id] then byId[custom.id] = key end
				entry.spellId = custom.id
				entry.label = SpellName(custom.id) or ("#" .. custom.id)
				entry.icon = SpellTexture(custom.id) or custom.icon or QUESTION_MARK
				local name = SpellName(custom.id)
				if name then
					entry.names[name] = true
					Claim(name, key)
				end
			else
				entry.label = custom.name
				entry.icon = custom.icon or QUESTION_MARK
				entry.names[custom.name] = true
				Claim(custom.name, key)
			end
			entry.chatName = entry.label
			entries[#entries + 1] = entry
			byKey[key] = entry
		end
	end

	for name, key in pairs(nameOwner) do
		if key then byName[name] = key end
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

-- Adds a debuff by spell id or by its exact name. Returns the label on success, or nil and a message.
function ns.AddCustom(text)
	text = strtrim(text or "")
	if text == "" then return nil end
	if #ns.entries >= ns.MAX_ENTRIES then
		return nil, L["The list is full (%d debuffs)."]:format(ns.MAX_ENTRIES)
	end
	local custom
	local id = tonumber(text)
	if id then
		id = math.floor(id)
		local name = SpellName(id)
		if not name then return nil, L["There is no spell with ID %d in this client."]:format(id) end
		if byId[id] then return nil, L["%s is already in the list."]:format(name) end
		custom = { id = id }
	else
		if byName[text] then return nil, L["%s is already in the list."]:format(text) end
		for _, entry in ipairs(ns.entries) do
			if entry.names[text] then return nil, L["%s is already in the list."]:format(text) end
		end
		custom = { name = text }
	end
	table.insert(ns.db.custom, custom)
	ns.db.debuffs[ns.CustomKey(custom)] = true
	ns.BuildIndex()
	ns.Refresh()
	return ns.byKey[ns.CustomKey(custom)].label
end

function ns.RemoveCustom(key)
	for index, custom in ipairs(ns.db.custom) do
		if ns.CustomKey(custom) == key then
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
-- Reading the target
-------------------------------------------------------------------------------

-- unit       the unit the frame describes: "target", "targettarget" or nil
-- found      [key] = { id, stacks, expires, duration } for every tracked debuff on the unit
-- unknown    [key] = true where the client hid the debuffs and the addon cannot tell
-- armor      number, or nil when the client does not hand it out
-- armorText  what to print for the armor (may be a secret the addon can only pass on)
-- reduction  armor the active debuffs take off, by the vanilla values
-- resists    list of numbers in RESIST_SCHOOLS order, or nil
local state = { found = {}, unknown = {}, reduction = 0 }
ns.state = state

local inCombat = false
local lastGUID, lastArmor, lastArmorSet

-- [auraInstanceID] = key for debuffs identified while the client still handed out their names. In combat the
-- client hides spell ids and names of auras, but the instance id stays readable.
local instanceKeys = {}

-- The unit to describe: a hostile target, or what a friendly target is fighting (a tank's or healer's target).
local function PickUnit()
	if not Try(UnitExists, "target") then return nil end
	if Try(UnitCanAttack, "player", "target") then return "target" end
	if Try(UnitExists, "targettarget") and Try(UnitCanAttack, "player", "targettarget") then
		return "targettarget"
	end
	return nil
end

local function ReadAuraFields(aura)
	return aura.spellId, aura.name, aura.applications, aura.expirationTime, aura.duration, aura.icon,
		aura.auraInstanceID
end

local function Hit(id, stacks, expires, duration)
	return { id = Plain(id), stacks = Plain(stacks) or 0, expires = Plain(expires), duration = Plain(duration) }
end

-- Asks the client for one debuff directly. The question itself contains nothing secret, so this can work where
-- reading the list does not.
local function Lookup(unit, entry)
	local getById = C_UnitAuras.GetUnitAuraBySpellID
	if getById then
		for _, id in ipairs(entry.ids) do
			local ok, aura = pcall(getById, unit, id)
			if ok and not issecretvalue(aura) and aura then
				local read, _, _, stacks, expires, duration = pcall(ReadAuraFields, aura)
				if read then return Hit(id, stacks, expires, duration) end
				return Hit(id)
			end
		end
	end
	local getByName = C_UnitAuras.GetAuraDataBySpellName
	if getByName then
		for name in pairs(entry.names) do
			local ok, aura = pcall(getByName, unit, name, "HARMFUL")
			if ok and not issecretvalue(aura) and aura then
				local read, id, _, stacks, expires, duration = pcall(ReadAuraFields, aura)
				if read then return Hit(id, stacks, expires, duration) end
				return Hit()
			end
		end
	end
	return nil
end

-- True if the client may be hiding this debuff right now; false if "not found" really means "not there".
local function MayBeHidden(entry)
	local check = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
	if not check or not entry.spellId then return true end
	for _, id in ipairs(entry.ids) do
		local ok, secret = pcall(check, id)
		if not ok or issecretvalue(secret) or secret then return true end
	end
	return false
end

local function ScanAuras(unit)
	local found, unknown, restricted = {}, {}, false
	local getByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not getByIndex then return found, unknown, true end

	for index = 1, 80 do
		local ok, aura = pcall(getByIndex, unit, index, "HARMFUL")
		if not ok or issecretvalue(aura) then
			restricted = true
			break
		end
		if not aura then break end
		local read, id, name, stacks, expires, duration, icon, instance = pcall(ReadAuraFields, aura)
		id, name, instance = Plain(id), Plain(name), Plain(instance)
		local key
		if read and (id ~= nil or name ~= nil) then
			key = (id and byId[id]) or (name and byName[name])
			if key and instance then instanceKeys[instance] = key end
		else
			restricted = true
			key = read and instance and instanceKeys[instance] or nil
		end
		if key and not found[key] then
			found[key] = Hit(id, stacks, expires, duration)
			-- Learn the icon of the player's own entries the first time the debuff is seen.
			local entry = ns.byKey[key]
			icon = Plain(icon)
			if entry and entry.custom and icon and entry.custom.icon ~= icon and entry.icon == QUESTION_MARK then
				entry.custom.icon = icon
				entry.icon = icon
				ns.iconsChanged = true
			end
		end
	end

	if restricted then
		-- Part of the list was hidden. Ask for each missing debuff directly; where that finds nothing and the
		-- client may be hiding the debuff, say "unknown" instead of claiming it is missing.
		for _, entry in ipairs(ns.visible) do
			if not found[entry.key] then
				-- The client draws the debuff into the entry's slot; whether that slot is showing is the one
				-- thing the addon can still see in combat. Rank and (often) stacks stay hidden.
				local active, stacks = ns.HUD:SlotActive(entry.key, unit)
				if active then
					found[entry.key] = Hit(nil, stacks)
					found[entry.key].fromSlot = true
					found[entry.key].stacksUnknown = stacks == nil
				elseif active == nil then
					local hit = Lookup(unit, entry)
					if hit then
						found[entry.key] = hit
					elseif MayBeHidden(entry) then
						unknown[entry.key] = true
					end
				end
			end
		end
	end
	return found, unknown, restricted
end

local function PlayerKnows(id)
	local known = (C_SpellBook and Try(C_SpellBook.IsSpellKnown, id)) or Try(IsPlayerSpell, id) or Try(IsSpellKnown, id)
	return Plain(known) and true or false
end

-- The reduction to assume when the rank on the mob is hidden: the highest rank the player knows (their own
-- Faerie Fire or Sunder is the likely one), otherwise the highest rank there is.
local function AssumedReduction(entry)
	local own, highest = 0, 0
	for id, value in pairs(entry.reduce) do
		highest = math.max(highest, value)
		if PlayerKnows(id) then own = math.max(own, value) end
	end
	return own > 0 and own or highest
end

-- Armor the active debuffs take off, by the vanilla values. An unknown rank is assumed (see above) and
-- unknown stacks count as one; the second return says that the total is such an estimate.
local function ArmorReduction(found)
	local total, estimate = 0, false
	for key, hit in pairs(found) do
		local entry = ns.byKey[key]
		if entry and entry.reduce then
			local amount = hit.id and entry.reduce[hit.id]
			if not amount then
				amount = AssumedReduction(entry)
				if next(entry.reduce, next(entry.reduce)) then estimate = true end -- more than one rank
			end
			if entry.perStack then
				amount = amount * math.max(hit.stacks, 1)
				if hit.stacksUnknown then estimate = true end
			end
			total = total + amount
		end
	end
	return total, estimate
end

local function ReadArmor(unit)
	local ok, base, effective, real = pcall(UnitArmor, unit)
	if not ok then return nil, nil end
	if issecretvalue(effective) then return nil, nil end
	-- The client answers 0 for units whose armor it does not hand out (enemies, as it turned out).
	for _, value in ipairs({ effective or 0, Plain(real) or 0, Plain(base) or 0 }) do
		if type(value) == "number" and value > 0 then return value, tostring(value) end
	end
	return nil, nil
end

local function ReadResists(unit)
	local resists = {}
	for index, school in ipairs(RESIST_SCHOOLS) do
		local ok, _, total = pcall(UnitResistance, unit, school)
		total = ok and Plain(total) or nil
		if type(total) ~= "number" then return nil end
		resists[index] = total
	end
	return resists
end

local function UnitLabel(unit)
	local name = Plain(Try(UnitName, unit))
	if type(name) == "string" and name ~= "" then return name end
	return L["Target"]
end

-- The share of physical damage the armor absorbs from an attacker of the player's level.
function ns.ArmorReduction(armor)
	local level = Plain(Try(UnitLevel, "player")) or 60
	local reduction
	if C_PaperDollInfo and C_PaperDollInfo.GetArmorEffectiveness then
		reduction = Plain(Try(C_PaperDollInfo.GetArmorEffectiveness, armor, level))
		if type(reduction) == "number" and reduction > 0 and reduction <= 1 then reduction = reduction * 100 end
	end
	if type(reduction) ~= "number" then
		reduction = armor / (armor + 400 + 85 * level) * 100 -- the vanilla formula
	end
	return math.max(0, math.min(reduction, 75)), level
end

-------------------------------------------------------------------------------
-- Chat
-------------------------------------------------------------------------------

local function InGroup()
	return IsInGroup and IsInGroup() or false
end

local function InRaid()
	return IsInRaid and IsInRaid() or false
end

-- automatic: the message was not caused by a click. Say and yell need a key press or click outside instances,
-- so automatic messages never go there.
local function ResolveChannel(automatic)
	local channel = ns.db.channel
	if channel == "AUTO" then
		if InRaid() then
			channel = "RAID"
		elseif InGroup() then
			channel = "PARTY"
		else
			channel = "SAY"
		end
	end
	if channel == "RAID" and not InRaid() then channel = "PARTY" end
	if (channel == "PARTY" or channel == "RAID_WARNING") and not InGroup() then channel = "SELF" end
	if automatic and (channel == "SAY" or channel == "YELL") then channel = "SELF" end
	return channel
end

local function Send(message, automatic)
	local channel = ResolveChannel(automatic)
	local locked = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and Plain(Try(C_ChatInfo.InChatMessagingLockdown))
	if channel ~= "SELF" and not locked then
		local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
		if send and pcall(send, message, channel) then return end
	end
	ns.Print(message)
end

function ns.AnnounceArmor()
	local unit = state.unit
	if not unit then return ns.Print(L["Nothing to announce: no attackable target."]) end
	if state.armor then
		Send(L["%s has %d armor"]:format(UnitLabel(unit), state.armor))
	elseif state.armorUnknown then
		ns.Print(L["Nothing to announce: the client hides this value right now."])
	else
		local text = state.estimate and L["%s: armor reduced by about %d"] or L["%s: armor reduced by %d"]
		Send(text:format(UnitLabel(unit), state.reduction))
	end
end

function ns.AnnounceDebuff(key)
	local unit, entry = state.unit, ns.byKey[key]
	if not entry then return end
	if not unit then return ns.Print(L["Nothing to announce: no attackable target."]) end
	if state.unknown[key] then return ns.Print(L["Nothing to announce: the client hides this value right now."]) end
	local hit, who = state.found[key], UnitLabel(unit)
	if not hit then
		Send(L["[%s] is not active on %s"]:format(entry.chatName, who))
	elseif hit.stacks > 1 then
		Send(L["%s has %d [%s] stacks"]:format(who, hit.stacks, entry.chatName))
	else
		Send(L["[%s] is active on %s"]:format(entry.chatName, who))
	end
end

-- The armor of the same mob went up: an armor debuff ran out. Name the ones that were there before.
local function OnArmorRise(unit, before, after, hadBefore, found)
	if not ns.db.announceDrops then return end
	local dropped = {}
	for key in pairs(hadBefore) do
		if not found[key] and ns.byKey[key] then dropped[#dropped + 1] = ns.byKey[key].chatName end
	end
	local message = L["%s's armor: %d -> %d"]:format(UnitLabel(unit), before, after)
	if #dropped > 0 then
		table.sort(dropped)
		message = message .. L[" (dropped: %s)"]:format(table.concat(dropped, ", "))
	end
	Send(message, true)
end

-- Without an armor value: an armor debuff that was on the mob is gone.
local function OnArmorDebuffsLost(unit, hadBefore, found, unknown)
	if not ns.db.announceDrops then return end
	local dropped = {}
	for key in pairs(hadBefore) do
		if not found[key] and not unknown[key] and ns.byKey[key] then
			dropped[#dropped + 1] = ns.byKey[key].chatName
		end
	end
	if #dropped == 0 then return end
	table.sort(dropped)
	Send(L["%s lost: %s"]:format(UnitLabel(unit), table.concat(dropped, ", ")), true)
end

-------------------------------------------------------------------------------
-- Update
-------------------------------------------------------------------------------

local function ShouldShow()
	local db = ns.db
	if not db.enabled then return false end
	if db.hideOOC and not inCombat then return false end
	if db.hideSolo and not InGroup() then return false end
	if db.hideNoTarget and not state.unit then return false end
	return true
end

function ns.Update()
	if not ns.HUD then return end
	local unit = PickUnit()
	if unit and Try(UnitIsDead, unit) then unit = nil end
	state.unit = unit
	ns.HUD:BindUnit(unit)

	if not ShouldShow() then
		ns.HUD:Hide()
		if not unit then lastGUID, lastArmor, lastArmorSet = nil, nil, nil end
		return
	end

	if unit then
		state.found, state.unknown, state.restricted = ScanAuras(unit)
		state.armor, state.armorText = ReadArmor(unit)
		state.resists = ns.db.showResists and ReadResists(unit) or nil

		-- Only for the direct target: "targettarget" changes without an event, so two mobs can get mixed up.
		state.reduction, state.estimate = ArmorReduction(state.found)
		state.armorUnknown = false
		for key in pairs(state.unknown) do
			if ns.byKey[key] and ns.byKey[key].armor then state.armorUnknown = true end
		end
		local guid = unit == "target" and Plain(Try(UnitGUID, unit)) or nil
		if guid then
			local armorSet = {}
			for key in pairs(state.found) do
				if ns.byKey[key] and ns.byKey[key].armor then armorSet[key] = true end
			end
			if guid == lastGUID and lastArmorSet then
				if state.armor and lastArmor then
					if state.armor > lastArmor then
						OnArmorRise(unit, lastArmor, state.armor, lastArmorSet, state.found)
					end
				elseif not state.armor then
					OnArmorDebuffsLost(unit, lastArmorSet, state.found, state.unknown)
				end
				-- A debuff the client hides for a moment was not lost; keep remembering it.
				for key in pairs(lastArmorSet) do
					if state.unknown[key] then armorSet[key] = true end
				end
			end
			lastGUID, lastArmor, lastArmorSet = guid, state.armor, armorSet
		else
			lastGUID, lastArmor, lastArmorSet = nil, nil, nil
		end
	else
		state.found, state.unknown, state.restricted = {}, {}, false
		state.armor, state.armorText, state.resists, state.reduction = nil, nil, nil, 0
		state.armorUnknown = false
		lastGUID, lastArmor, lastArmorSet = nil, nil, nil
	end

	if ns.iconsChanged then
		ns.iconsChanged = nil
		ns.HUD:Layout()
	end
	ns.HUD:Show()
	ns.HUD:Render(state)
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
		MergeDefaults(ForeverADFCharDB, DEFAULTS)
		ns.db = ForeverADFCharDB
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		inCombat = InCombatLockdown and InCombatLockdown() or false
		ns.BuildIndex()
		ns.CreateHUD()
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("UNIT_AURA")
		self:RegisterEvent("UNIT_TARGET")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("GROUP_ROSTER_UPDATE")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		-- Armor has no event of its own for other units, and "targettarget" has none at all.
		C_Timer.NewTicker(0.25, ns.Update)
		ns.Update()
		ns.Print(L["Loaded. Type /adf for the options."])
	elseif event == "UNIT_AURA" then
		if arg1 == "target" or state.unit == "targettarget" then ns.Update() end
	elseif event == "UNIT_TARGET" then
		if arg1 == "target" then
			if ns.HUD then ns.HUD:BindUnit(state.unit, true) end
			ns.Update()
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
		ns.Update()
		if ns.debugArmed then
			ns.debugArmed = nil
			C_Timer.After(4, ns.Debug)
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		if ns.HUD and ns.HUD.pendingLayout then ns.HUD:Layout() end
		ns.Update()
	else
		if event == "PLAYER_TARGET_CHANGED" then
			lastGUID, lastArmor, lastArmorSet = nil, nil, nil
			instanceKeys = {}
			if ns.HUD then ns.HUD:BindUnit(nil, true) end -- "target" is another mob now: bind again in Update
		end
		ns.Update()
	end
end)

-------------------------------------------------------------------------------
-- /adf debug: what the client hands out about the target right now. For bug reports.
-------------------------------------------------------------------------------

local function Show(value)
	if issecretvalue(value) then return "<secret>" end
	return tostring(value)
end

function ns.Debug()
	local unit = state.unit or "target"
	local secrets = C_Secrets or {}
	ns.Print(("debug %s | combat %s | aurasSecret %s | statsSecret %s | restrictions %s"):format(unit,
		tostring(inCombat), Show(Try(secrets.ShouldAurasBeSecret)), Show(Try(secrets.ShouldUnitStatsBeSecret)),
		Show(Try(secrets.HasSecretRestrictions))))
	local ok, a, b, c, d = pcall(UnitArmor, unit)
	print(("  UnitArmor: %s %s %s %s %s | container %s bound %s"):format(tostring(ok), Show(a), Show(b), Show(c),
		Show(d), tostring(ns.HUD.container ~= nil), tostring(ns.HUD.boundUnit)))
	for index = 1, 40 do
		local got, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HARMFUL")
		if not got then
			print("  aura " .. index .. ": error " .. tostring(aura))
			break
		end
		if issecretvalue(aura) then
			print("  aura " .. index .. ": <secret table>")
			break
		end
		if not aura then break end
		local read, id, name, stacks, _, _, _, instance = pcall(ReadAuraFields, aura)
		print(("  aura %d: read %s id %s name %s stacks %s instance %s indexSecret %s"):format(index, tostring(read),
			Show(id), Show(name), Show(stacks), Show(instance),
			Show(Try(secrets.ShouldUnitAuraIndexBeSecret, unit, index, "HARMFUL"))))
	end
	for _, entry in ipairs(ns.visible) do
		local id = entry.ids[1]
		local hit = Lookup(unit, entry)
		print(("  %s (%s): shouldBeSecret %s lookup %s state %s | slot %s"):format(entry.label, tostring(id),
			Show(id and Try(secrets.ShouldSpellAuraBeSecret, id)), hit and "found" or "nil",
			state.found[entry.key] and "found" or state.unknown[entry.key] and "unknown" or "missing",
			ns.HUD:SlotInfo(entry.key)))
	end
end

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
	elseif command == "debug" then
		ns.Debug()
		if not inCombat then
			-- typing mid-fight is awkward: repeat the dump by itself in the next fight
			ns.debugArmed = true
			ns.Print("debug: I will print this again 4 seconds into your next fight.")
		end
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
