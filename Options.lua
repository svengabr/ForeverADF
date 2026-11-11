-- The options window (/adf). Built on first use.
local _, ns = ...
local L = ns.L

local GOLD = { 1, 0.82, 0 }
local ROWS_PER_COLUMN = 15
local ROW_HEIGHT = 22
local COLUMN_WIDTH = 240

local window
local checks, sliders, debuffRows = {}, {}, {}
local channelButton

local BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function Heading(parent, text, x, y)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("TOPLEFT", x, y)
	label:SetText(text)
	label:SetTextColor(unpack(GOLD))
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
	line:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
	line:SetSize(220, 1)
	return label
end

local function Tooltip(frame, title, text)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 0.82, 0)
		if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", GameTooltip_Hide)
end

local function Check(parent, key, text, x, y, tooltip)
	local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	box:SetSize(24, 24)
	box:SetPoint("TOPLEFT", x, y)
	box.label = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	box.label:SetPoint("LEFT", box, "RIGHT", 2, 0)
	box.label:SetText(text)
	box:SetHitRectInsets(0, -math.min(box.label:GetStringWidth() or 0, 200), 0, 0)
	box:SetScript("OnClick", function(self)
		ns.db[key] = self:GetChecked() and true or false
		ns.Refresh()
	end)
	if tooltip then Tooltip(box, text, tooltip) end
	checks[key] = box
	return box
end

local function Slider(parent, key, text, low, high, x, y)
	local slider = CreateFrame("Slider", nil, parent)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(200, 16)
	slider:SetPoint("TOPLEFT", x, y - 16)
	slider:EnableMouse(true)

	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetColorTexture(1, 1, 1, 0.15)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	track:SetHeight(4)

	slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	local thumb = slider:GetThumbTexture()
	if thumb then thumb:SetSize(24, 24) end

	slider.label = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	slider.label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 2)

	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(1)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	slider.text = text
	slider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		self.label:SetText(("%s: |cffffffff%d|r"):format(self.text, value))
		if ns.db[key] ~= value then
			ns.db[key] = value
			ns.Refresh()
		end
	end)
	sliders[key] = slider
	return slider
end

local function Button(parent, text, width, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

-------------------------------------------------------------------------------
-- The debuff checklist
-------------------------------------------------------------------------------

local function DebuffRow(parent, index)
	local row = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	row:SetSize(20, 20)
	local column = math.floor((index - 1) / ROWS_PER_COLUMN)
	local line = (index - 1) % ROWS_PER_COLUMN
	row:SetPoint("TOPLEFT", 270 + column * COLUMN_WIDTH, -66 - line * ROW_HEIGHT)
	row:SetHitRectInsets(0, -(COLUMN_WIDTH - 26), 0, 0)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(16, 16)
	row.icon:SetPoint("LEFT", row, "RIGHT", 2, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.label:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.label:SetWidth(COLUMN_WIDTH - 50)
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)

	row:SetScript("OnClick", function(self, mouseButton)
		local entry = self.entry
		if not entry then return end
		if mouseButton == "RightButton" then
			self:SetChecked(ns.IsEnabled(entry.key)) -- the click toggled the box; put it back
			if entry.custom and ns.RemoveCustom(entry.key) then
				ns.Print(L["Removed %s."]:format(entry.label))
				ns.RefreshOptions()
			end
			return
		end
		ns.SetEnabled(entry.key, self:GetChecked() and true or false)
	end)
	row:SetScript("OnEnter", function(self)
		local entry = self.entry
		if not entry then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", COLUMN_WIDTH - 30, 0)
		GameTooltip:SetText(entry.label, 1, 0.82, 0)
		if entry.custom then GameTooltip:AddLine(L["Your own entry. Right-click to remove it."], 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	return row
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

local function Build()
	window = CreateFrame("Frame", "ForeverADFOptions", UIParent, "BackdropTemplate")
	window:Hide()
	window:SetSize(770, 560)
	window:SetPoint("CENTER")
	window:SetFrameStrata("DIALOG")
	window:SetToplevel(true)
	window:SetBackdrop(BACKDROP)
	window:SetBackdropColor(0.05, 0.05, 0.07, 0.96)
	window:SetBackdropBorderColor(0.6, 0.6, 0.6)
	window:EnableMouse(true)
	window:SetMovable(true)
	window:SetClampedToScreen(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", window.StopMovingOrSizing)
	table.insert(UISpecialFrames, "ForeverADFOptions") -- Esc closes it

	local title = window:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Forever ADF – " .. L["Options"])

	local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

	-- Left column
	local x, y = 20, -44
	Heading(window, L["Display"], x, y)
	y = y - 22
	local displayChecks = {
		{ "enabled", L["Show the frame"] },
		{ "showArmor", L["Show armor"] },
		{ "showResists", L["Show resistances"], L["The Forever client currently answers 0 for every enemy resistance. The line only appears when the client hands out real values."] },
		{ "showTimers", L["Show remaining time"] },
		{ "hideOOC", L["Hide out of combat"] },
		{ "hideSolo", L["Hide when not in a group"] },
		{ "hideNoTarget", L["Hide without a target"] },
		{ "locked", L["Lock position"] },
		{ "clickThrough", L["Click-through"], L["The frame ignores the mouse: no tooltips, no announcing by right-click, no moving."] },
	}
	for _, def in ipairs(displayChecks) do
		Check(window, def[1], def[2], x, y, def[3])
		y = y - 24
	end
	y = y - 8
	Slider(window, "iconSize", L["Icon size"], 16, 60, x + 4, y)
	y = y - 42
	Slider(window, "perRow", L["Icons per row"], 1, 15, x + 4, y)
	y = y - 46

	Heading(window, L["Announcements"], x, y)
	y = y - 24
	channelButton = Button(window, "", 220, function()
		local current = 1
		for index, channel in ipairs(ns.CHANNELS) do
			if channel == ns.db.channel then current = index end
		end
		ns.db.channel = ns.CHANNELS[current % #ns.CHANNELS + 1]
		ns.RefreshOptions()
	end)
	channelButton:SetPoint("TOPLEFT", x, y)
	Tooltip(channelButton, L["Click to switch the channel."], L["Automatic picks raid, then party, then say."])
	y = y - 26
	Check(window, "announceDrops", L["Announce when armor goes back up"], x, y,
		L["Tells the channel when a debuff ran out and the target's armor went back up. Outside of a group this only prints to your own chat."])
	y = y - 34

	Heading(window, L["Add your own debuff"], x, y)
	y = y - 24
	local input = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
	input:SetSize(110, 20)
	input:SetPoint("TOPLEFT", x + 6, y)
	input:SetAutoFocus(false)
	input:SetMaxLetters(60)
	Tooltip(input, L["Add your own debuff"], L["Spell ID or exact debuff name"])
	local function AddFromInput()
		local label, problem = ns.AddCustom(input:GetText())
		if label then
			ns.Print(L["Added %s."]:format(label))
			input:SetText("")
			ns.RefreshOptions()
		elseif problem then
			ns.Print(problem)
		end
		input:ClearFocus()
	end
	input:SetScript("OnEnterPressed", AddFromInput)
	input:SetScript("OnEscapePressed", input.ClearFocus)
	local add = Button(window, L["Add"], 100, AddFromInput)
	add:SetPoint("LEFT", input, "RIGHT", 6, 0)

	-- Right column
	Heading(window, L["Tracked debuffs"], 270, -44)

	-- Bottom
	local done = Button(window, L["Close"], 110, function() window:Hide() end)
	done:SetPoint("BOTTOMRIGHT", -16, 14)
	local reset = Button(window, L["Reset position"], 160, function()
		ns.ResetPosition()
		ns.Print(L["Position reset."])
	end)
	reset:SetPoint("RIGHT", done, "LEFT", -8, 0)
end

-- Brings every control in line with the saved options.
function ns.RefreshOptions()
	if not window then return end
	local db = ns.db
	for key, box in pairs(checks) do
		box:SetChecked(db[key] and true or false)
	end
	for key, slider in pairs(sliders) do
		slider.label:SetText(("%s: |cffffffff%d|r"):format(slider.text, db[key]))
		slider:SetValue(db[key])
	end
	channelButton:SetText(L["Channel: %s"]:format(L[ns.CHANNEL_LABELS[db.channel] or "Automatic"]))

	for index, entry in ipairs(ns.entries) do
		if index > ns.MAX_ENTRIES then break end
		local row = debuffRows[index]
		if not row then
			row = DebuffRow(window, index)
			debuffRows[index] = row
		end
		row.entry = entry
		row.icon:SetTexture(entry.icon)
		row.label:SetText(entry.label)
		if entry.custom then
			row.label:SetTextColor(0.6, 0.85, 1)
		else
			row.label:SetTextColor(1, 1, 1)
		end
		row:SetChecked(ns.IsEnabled(entry.key))
		row:Show()
	end
	for index = #ns.entries + 1, #debuffRows do
		debuffRows[index].entry = nil
		debuffRows[index]:Hide()
	end
end

function ns.ToggleOptions()
	if not window then Build() end
	if window:IsShown() then
		window:Hide()
	else
		ns.RefreshOptions()
		window:Show()
	end
end
