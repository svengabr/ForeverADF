-- The frame on screen: a grid of debuff icons.
--
-- Each icon is two layers. Below, the addon's own dimmed icon: it says "this debuff is tracked and missing".
-- On top, a slot of the client's aura container: the addon names the spell ids a slot is for, and the client
-- itself shows icon, stacks and remaining time while the debuff is on the unit. That is the only way to show a
-- unit's debuffs in combat on this client; the addon never learns which slots are lit.
-- Recipe: CreateFrame("AuraContainer", ..., "CustomAuraContainerTemplate"), as used by Platynator.
local _, ns = ...
local L = ns.L

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

function ns.CreateHUD()
	local hud = CreateFrame("Frame", "ForeverADFFrame", UIParent)
	ns.HUD = hud
	hud:SetFrameStrata("LOW")
	hud:SetMovable(true)
	hud:SetClampedToScreen(true)
	hud.icons = {}
	hud.slots = {} -- [key] = slot frame, or false where none could be made

	local made, container = pcall(CreateFrame, "AuraContainer", nil, hud, "CustomAuraContainerTemplate")
	if made and container and container.AddAuraSlot then
		hud.container = container
		container:SetAllPoints(hud)
		container:SetFrameLevel((hud:GetFrameLevel() or 0) + 5)
		Safe(container, "SetEnabled", false)
	else
		ns.Print(L["This client has no aura container; the icons cannot light up."])
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
	-- The addon's own icons (lower layer)
	---------------------------------------------------------------------------

	local function IconEnter(self)
		local entry = self.entry
		if not entry then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText(entry.label, 1, 0.82, 0)
		GameTooltip:AddLine(L["Lit: on the target. Dark: missing."], 1, 1, 1, true)
		if not ns.db.locked then GameTooltip:AddLine(L["Shift + drag: move"], 0.5, 0.8, 1) end
		GameTooltip:Show()
	end

	local function CreateIcon()
		local button = CreateFrame("Button", nil, hud)
		button:RegisterForDrag("LeftButton")
		button:SetScript("OnDragStart", StartMove)
		button:SetScript("OnDragStop", StopMove)
		button:SetScript("OnEnter", IconEnter)
		button:SetScript("OnLeave", GameTooltip_Hide)

		button.bg = button:CreateTexture(nil, "BACKGROUND")
		button.bg:SetAllPoints()
		button.bg:SetColorTexture(0, 0, 0, 1)

		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetPoint("TOPLEFT", 1, -1)
		button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
		button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		button.icon:SetDesaturated(true)
		button.icon:SetAlpha(0.3)
		return button
	end

	---------------------------------------------------------------------------
	-- The client's slots (upper layer)
	---------------------------------------------------------------------------

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

		-- the mouse belongs to the addon's own icon below
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

	---------------------------------------------------------------------------
	-- Layout
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
		local rows = math.max(1, math.ceil(count / perRow))
		local mouse = not db.clickThrough
		local lockdown = InCombatLockdown and InCombatLockdown()
		local used = {}
		self.pendingLayout = nil

		self:SetSize(size * perRow, rows * size)

		for index, entry in ipairs(ns.visible) do
			local button = self.icons[index]
			if not button then
				button = CreateIcon()
				self.icons[index] = button
			end
			local row = math.floor((index - 1) / perRow)
			local column = (index - 1) % perRow
			local x, y = column * size, -(row * size)
			button.entry = entry
			button:SetSize(size, size)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
			button:EnableMouse(mouse)
			button.icon:SetTexture(entry.icon)
			button:Show()

			local slot = EnsureSlot(entry)
			if slot then
				used[entry.key] = true
				Safe(self.container, "SetAuraSlotEnabled", entry.key, true)
				-- the client's own frames may only be moved out of combat; try, and repeat after the fight
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
		end
		for index = count + 1, #self.icons do
			self.icons[index].entry = nil
			self.icons[index]:Hide()
		end
		for key, slot in pairs(self.slots) do
			if slot and not used[key] then Safe(self.container, "SetAuraSlotEnabled", key, false) end
		end
		self:ApplyPosition()
	end

	hud:Layout()
	return hud
end
