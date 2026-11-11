-- The frame on screen: the armor reading, the resistance line above it and the grid of debuff icons below.
local _, ns = ...
local L = ns.L

local RESIST_COLORS = { "ffff4040", "ff40ff40", "ff4ae8f5", "ffb060ff", "ffffffff" }
local RESIST_LABELS = { "FR", "NR", "FrR", "SR", "AR" }

local BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 10,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local function FontFile()
	local file = GameFontNormal and GameFontNormal:GetFont()
	return file or "Fonts\\FRIZQT__.TTF"
end

-- Calls a method that may not exist or may be refused on this client.
local function Safe(object, method, ...)
	local func = object and object[method]
	if not func then return false end
	return pcall(func, object, ...)
end

-- Number format for the remaining time the client writes into a slot: seconds, then minutes.
local durationFormatter
local function DurationFormatter()
	if durationFormatter == nil then
		durationFormatter = false
		pcall(function()
			local formatter = C_StringUtil.CreateNumericRuleFormatter()
			local down = Enum.NumericRuleFormatRounding.Down
			formatter:SetBreakpoints({
				{ threshold = 0, step = 1, format = "%d", rounding = down },
				{ threshold = 60, format = "%dm", components = { { div = 60, step = 1, rounding = down } } },
			})
			durationFormatter = formatter
		end)
	end
	return durationFormatter or nil
end

local function FormatTime(seconds)
	if seconds >= 60 then return ("%dm"):format(math.floor(seconds / 60 + 0.5)) end
	return ("%d"):format(math.floor(seconds + 0.5))
end

function ns.CreateHUD()
	local hud = CreateFrame("Frame", "ForeverADFFrame", UIParent)
	ns.HUD = hud
	hud:SetFrameStrata("LOW")
	hud:SetMovable(true)
	hud:SetClampedToScreen(true)
	hud.icons = {}

	-- In combat the client hides a unit's debuffs from addons. It offers a container instead: the addon names
	-- the spell ids a slot is for, and the client itself shows the icon, stacks and time while the debuff is
	-- up. Each slot sits on top of the addon's own (dimmed) icon.
	hud.slots = {} -- [key] = slot frame, or false where none could be made
	local made, container = pcall(CreateFrame, "AuraContainer", nil, hud, "CustomAuraContainerTemplate")
	if made and container and container.AddAuraSlot then
		hud.container = container
		container:SetAllPoints(hud)
		container:SetFrameLevel((hud:GetFrameLevel() or 0) + 5)
		Safe(container, "SetEnabled", false)
	end

	local function StartMove()
		if not ns.db.locked and IsShiftKeyDown() then
			hud.moving = true
			hud:StartMoving()
		end
	end

	local function StopMove()
		if not hud.moving then return end
		hud.moving = false
		hud:StopMovingOrSizing()
		local x, y = hud:GetCenter()
		local ux, uy = UIParent:GetCenter()
		if x and ux then
			ns.db.x, ns.db.y = math.floor(x - ux + 0.5), math.floor(y - uy + 0.5)
		end
		hud:ApplyPosition()
	end

	---------------------------------------------------------------------------
	-- Armor box
	---------------------------------------------------------------------------

	local header = CreateFrame("Button", nil, hud, "BackdropTemplate")
	hud.header = header
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetBackdrop(BACKDROP)
	header:SetBackdropColor(0, 0, 0, 0.75)
	header:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
	header:RegisterForClicks("RightButtonUp")
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", StartMove)
	header:SetScript("OnDragStop", StopMove)
	header:SetScript("OnClick", function() ns.AnnounceArmor() end)

	header.armor = header:CreateFontString(nil, "OVERLAY")
	header.armor:SetPoint("CENTER")
	header.armor:SetShadowOffset(1, -1)

	header.resists = header:CreateFontString(nil, "OVERLAY")
	header.resists:SetPoint("BOTTOM", header, "TOP", 0, 2)
	header.resists:SetShadowOffset(1, -1)

	header:SetScript("OnEnter", function(self)
		local state = ns.state
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText(L["Armor"], 1, 0.82, 0)
		if not state.unit then
			GameTooltip:AddLine(L["No attackable target"], 0.7, 0.7, 0.7)
		elseif state.armor then
			local reduction, level = ns.ArmorReduction(state.armor)
			GameTooltip:AddLine(L["Physical damage reduction against level %d: %.1f%%"]:format(level, reduction), 1, 1, 1, true)
		else
			GameTooltip:AddLine(L["The client does not hand out this target's armor."], 0.7, 0.7, 0.7, true)
		end
		if state.unit and state.armorUnknown then
			GameTooltip:AddLine(L["In combat the client hides the debuffs from addons, so there is no total. The icons below still show what is active."], 1, 0.8, 0.3, true)
		elseif state.unit then
			GameTooltip:AddLine(L["Armor taken off by the active debuffs: %d"]:format(state.reduction), 0.4, 1, 0.4, true)
			if state.estimate then
				GameTooltip:AddLine(L["An estimate: in combat the client hides rank and stacks, so your own rank (or the highest one) and one stack are assumed."], 1, 0.8, 0.3, true)
			end
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Right-click: announce in chat"], 0.5, 0.8, 1)
		if not ns.db.locked then GameTooltip:AddLine(L["Shift + drag: move"], 0.5, 0.8, 1) end
		GameTooltip:Show()
	end)
	header:SetScript("OnLeave", GameTooltip_Hide)

	---------------------------------------------------------------------------
	-- Debuff icons
	---------------------------------------------------------------------------

	local function IconEnter(self)
		local entry, state = self.entry, ns.state
		if not entry then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText(entry.label, 1, 0.82, 0)
		local hit = state.found[entry.key]
		if not state.unit then
			GameTooltip:AddLine(L["No attackable target"], 0.7, 0.7, 0.7)
		elseif hit then
			if hit.stacks > 1 then
				GameTooltip:AddLine(L["Active (%d stacks)"]:format(hit.stacks), 0.3, 1, 0.3)
			else
				GameTooltip:AddLine(L["Active"], 0.3, 1, 0.3)
			end
		elseif state.unknown[entry.key] and self.slot then
			GameTooltip:AddLine(L["In combat the game draws this icon itself: lit means active, dark means missing."], 1, 0.8, 0.3, true)
		elseif state.unknown[entry.key] then
			GameTooltip:AddLine(L["Unknown: the client hides this target's debuffs right now."], 1, 0.8, 0.3, true)
		else
			GameTooltip:AddLine(L["Missing"], 1, 0.3, 0.3)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Right-click: announce in chat"], 0.5, 0.8, 1)
		if not ns.db.locked then GameTooltip:AddLine(L["Shift + drag: move"], 0.5, 0.8, 1) end
		GameTooltip:Show()
	end

	local function CreateIcon()
		local button = CreateFrame("Button", nil, hud)
		button:RegisterForClicks("RightButtonUp")
		button:RegisterForDrag("LeftButton")
		button:SetScript("OnDragStart", StartMove)
		button:SetScript("OnDragStop", StopMove)
		button:SetScript("OnClick", function(self) if self.entry then ns.AnnounceDebuff(self.entry.key) end end)
		button:SetScript("OnEnter", IconEnter)
		button:SetScript("OnLeave", GameTooltip_Hide)

		button.bg = button:CreateTexture(nil, "BACKGROUND")
		button.bg:SetAllPoints()
		button.bg:SetColorTexture(0, 0, 0, 1)

		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetPoint("TOPLEFT", 1, -1)
		button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
		button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

		button.count = button:CreateFontString(nil, "OVERLAY")
		button.count:SetPoint("BOTTOMRIGHT", -1, 1)
		button.count:SetShadowOffset(1, -1)

		button.timer = button:CreateFontString(nil, "OVERLAY")
		button.timer:SetPoint("TOP", 0, -1)
		button.timer:SetShadowOffset(1, -1)
		button.timer:SetTextColor(1, 0.9, 0.4)
		return button
	end

	local function InitSlot(frame)
		local size = ns.db.iconSize
		frame:SetSize(size, size)

		frame.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
		frame.bg:SetAllPoints()
		frame.bg:SetColorTexture(0, 0, 0, 1)

		frame.Icon = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
		frame.Icon:SetPoint("TOPLEFT", 1, -1)
		frame.Icon:SetPoint("BOTTOMRIGHT", -1, 1)
		frame.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		Safe(frame, "SetIcon", frame.Icon)

		frame.Count = frame:CreateFontString(nil, "OVERLAY")
		frame.Count:SetFont(FontFile(), 12, "OUTLINE")
		frame.Count:SetPoint("BOTTOMRIGHT", -1, 1)
		Safe(frame, "SetApplicationCount", frame.Count, {})

		frame.Timer = frame:CreateFontString(nil, "OVERLAY")
		frame.Timer:SetFont(FontFile(), 10, "OUTLINE")
		frame.Timer:SetPoint("TOP", 0, -1)
		frame.Timer:SetTextColor(1, 0.9, 0.4)
		local formatter = DurationFormatter()
		if formatter then Safe(frame, "SetDurationText", frame.Timer, { textFormatter = formatter }) end

		-- clicks and tooltips belong to the addon's own icon below
		Safe(frame, "SetCollapsesLayout", true)
		Safe(frame, "EnableMouse", false)
		Safe(frame, "EnableMouseMotion", false)
	end

	local function EnsureSlot(entry)
		if not hud.container then return nil end
		local slot = hud.slots[entry.key]
		if slot ~= nil then return slot or nil end
		local ids = {}
		for _, id in ipairs(entry.ids) do ids[id] = true end
		if not next(ids) then
			hud.slots[entry.key] = false -- an entry known by name only
			return nil
		end
		local ok, frame = pcall(hud.container.AddAuraSlot, hud.container, entry.key, "HARMFUL", {
			initializeFrame = function(frame) pcall(InitSlot, frame) end,
			candidateFilters = { includeSpellIDs = ids },
		})
		hud.slots[entry.key] = ok and frame or false
		return ok and frame or nil
	end

	-- Points the container at the unit. force: the token stayed the same but now means another mob.
	function hud:BindUnit(unit, force)
		local box = self.container
		if not box or (unit == self.boundUnit and not force) then return end
		self.boundUnit = unit
		if unit then
			local ok = Safe(box, "SetUnit", unit)
			Safe(box, "SetEnabled", ok)
		else
			Safe(box, "SetEnabled", false)
		end
	end

	-- Whether the client is showing a debuff in the entry's slot: true, false, or nil when the addon cannot
	-- tell (no slot, another unit, or the client refuses the question). Second return: the stacks, if readable.
	function hud:SlotActive(key, unit)
		local slot = self.slots[key]
		if not slot or self.boundUnit ~= unit then return nil end
		local ok, shown = pcall(slot.IsShown, slot)
		-- In combat the client refuses every question about a slot frame (seen in the client: IsShown,
		-- IsVisible, GetAlpha and the text of its font strings all raise errors, HookScript is refused).
		if not ok or ns.IsSecret(shown) then return nil end
		if not shown then return false end
		local okAlpha, alpha = pcall(slot.GetAlpha, slot)
		if okAlpha and not ns.IsSecret(alpha) and type(alpha) == "number" and alpha <= 0 then return false end
		local okText, text = pcall(slot.Count.GetText, slot.Count)
		local stacks = okText and not ns.IsSecret(text) and tonumber(text) or nil
		return true, stacks
	end

	-- For /adf debug: what the addon can see of a slot.
	function hud:SlotInfo(key)
		local slot = self.slots[key]
		if slot == nil then return "none" end
		if slot == false then return "failed" end
		local function Probe(object, method)
			local func = object and object[method]
			if not func then return "n/a" end
			local ok, value = pcall(func, object)
			if not ok then return "error" end
			if ns.IsSecret(value) then return "<secret>" end
			return tostring(value)
		end
		return ("shown %s visible %s alpha %s count %s"):format(Probe(slot, "IsShown"), Probe(slot, "IsVisible"),
			Probe(slot, "GetAlpha"), Probe(slot.Count, "GetText"))
	end

	---------------------------------------------------------------------------
	-- Layout and rendering
	---------------------------------------------------------------------------

	function hud:ApplyPosition()
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "CENTER", ns.db.x, ns.db.y)
	end

	-- Sizes and places everything; runs after an option changed.
	function hud:Layout()
		local db = ns.db
		local size, perRow = db.iconSize, db.perRow
		local font = FontFile()
		local count = #ns.visible
		local rows = math.ceil(count / perRow)
		local headerHeight = db.showArmor and size or 0
		local mouse = not db.clickThrough

		self:SetSize(size * perRow, math.max(headerHeight + rows * size, 1))

		header:SetShown(db.showArmor)
		header:SetHeight(math.max(headerHeight, 1))
		header:EnableMouse(mouse)
		header.armor:SetFont(font, math.floor(size * 0.72), "OUTLINE")
		header.resists:SetFont(font, math.max(9, math.floor(size * 0.38)), "OUTLINE")
		header.resists:SetShown(db.showResists)

		local lockdown = InCombatLockdown and InCombatLockdown()
		local used = {}
		self.pendingLayout = nil
		for index, entry in ipairs(ns.visible) do
			local button = self.icons[index]
			if not button then
				button = CreateIcon()
				self.icons[index] = button
			end
			local row = math.floor((index - 1) / perRow)
			local column = (index - 1) % perRow
			local x, y = column * size, -(headerHeight + row * size)
			button.entry = entry
			button:SetSize(size, size)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)

			local slot = EnsureSlot(entry)
			button.slot = slot
			if slot then
				used[entry.key] = true
				Safe(self.container, "SetAuraSlotEnabled", entry.key, true)
				-- the client's own frames may only be moved out of combat
				if lockdown then self.pendingLayout = true end
				pcall(function()
					slot:SetSize(size, size)
					slot:ClearAllPoints()
					slot:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
					slot.Count:SetFont(font, math.max(9, math.floor(size * 0.45)), "OUTLINE")
					slot.Timer:SetFont(font, math.max(8, math.floor(size * 0.36)), "OUTLINE")
					slot.Timer:SetShown(db.showTimers)
				end)
			end
			button:EnableMouse(mouse)
			button.icon:SetTexture(entry.icon)
			button.count:SetFont(font, math.max(9, math.floor(size * 0.45)), "OUTLINE")
			button.timer:SetFont(font, math.max(8, math.floor(size * 0.36)), "OUTLINE")
			button:Show()
		end
		for index = count + 1, #self.icons do
			self.icons[index].entry = nil
			self.icons[index].slot = nil
			self.icons[index]:Hide()
		end
		for key, slot in pairs(self.slots) do
			if slot and not used[key] then Safe(self.container, "SetAuraSlotEnabled", key, false) end
		end
		self:ApplyPosition()
	end

	function hud:Render(state)
		local db = ns.db

		if not state.unit then
			header.armor:SetTextColor(0.5, 0.5, 0.5)
			header.armor:SetText("aDF")
		else
			-- Only a real number counts. In combat the client hands out a secret instead, and that secret is
			-- the same 0 it answers for every enemy out of combat.
			if state.armor then
				header.armor:SetText(state.armorText)
				header.armor:SetTextColor(1, 1, 1)
			elseif state.armorUnknown then
				-- in combat the client shows the debuffs itself; the addon cannot add them up
				header.armor:SetTextColor(0.6, 0.6, 0.6)
				header.armor:SetText("?")
			elseif state.reduction > 0 then
				-- no armor value from the client: show what the debuffs take off
				header.armor:SetTextColor(0.4, 1, 0.4)
				header.armor:SetText((state.estimate and "~-" or "-") .. state.reduction)
			else
				header.armor:SetTextColor(0.6, 0.6, 0.6)
				header.armor:SetText("-0")
			end
		end

		if db.showResists and state.resists then
			local parts = {}
			for index, value in ipairs(state.resists) do
				parts[index] = ("|c%s%s %d|r"):format(RESIST_COLORS[index], L[RESIST_LABELS[index]], value)
			end
			header.resists:SetText(table.concat(parts, " "))
		else
			header.resists:SetText("")
		end

		local now = GetTime()
		for index, entry in ipairs(ns.visible) do
			local button = self.icons[index]
			if not button then break end
			local hit = state.found[entry.key]
			if hit then
				button.icon:SetAlpha(1)
				button.icon:SetDesaturated(false)
				button.count:SetText(hit.stacks > 1 and hit.stacks or "")
				local left = db.showTimers and hit.expires and hit.expires > 0 and (hit.expires - now) or nil
				button.timer:SetText(left and left > 0 and FormatTime(left) or "")
			elseif state.unknown[entry.key] and not button.slot then
				-- no slot (an entry known by name only): the addon really cannot tell
				button.icon:SetAlpha(0.6)
				button.icon:SetDesaturated(true)
				button.count:SetText("?")
				button.timer:SetText("")
			else
				button.icon:SetAlpha(0.3)
				button.icon:SetDesaturated(true)
				button.count:SetText("")
				button.timer:SetText("")
			end
		end
	end

	hud:Layout()
	return hud
end
