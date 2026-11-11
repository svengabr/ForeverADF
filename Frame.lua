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
			GameTooltip:AddLine(L["The client does not hand out this target's armor right now."], 0.7, 0.7, 0.7, true)
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

		for index, entry in ipairs(ns.visible) do
			local button = self.icons[index]
			if not button then
				button = CreateIcon()
				self.icons[index] = button
			end
			local row = math.floor((index - 1) / perRow)
			local column = (index - 1) % perRow
			button.entry = entry
			button:SetSize(size, size)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", self, "TOPLEFT", column * size, -(headerHeight + row * size))
			button:EnableMouse(mouse)
			button.icon:SetTexture(entry.icon)
			button.count:SetFont(font, math.max(9, math.floor(size * 0.45)), "OUTLINE")
			button.timer:SetFont(font, math.max(8, math.floor(size * 0.36)), "OUTLINE")
			button:Show()
		end
		for index = count + 1, #self.icons do
			self.icons[index].entry = nil
			self.icons[index]:Hide()
		end
		self:ApplyPosition()
	end

	function hud:Render(state)
		local db = ns.db

		if not state.unit then
			header.armor:SetTextColor(0.5, 0.5, 0.5)
			header.armor:SetText("aDF")
		else
			header.armor:SetTextColor(1, 1, 1)
			-- armorText can be a secret: the font string may show it, the addon may not look at it
			if state.armorText == nil or not pcall(header.armor.SetText, header.armor, state.armorText) then
				header.armor:SetText("?")
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
			elseif state.unknown[entry.key] then
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
