-- /adf shots: takes the reference screenshots the gallery images are made from (media/gallery/gallery.py picks
-- them up from the game's Screenshots folder). Nobody has a raid at hand that keeps Sunder Armor and three curses
-- on a mob for a picture, so during the run the frame shows made-up debuffs: the addon lights its own icons and
-- writes stacks and times on them. Everything else in the pictures is the game as it is.
-- The game names a screenshot after the second it was taken in, so the pictures are two seconds apart.
local _, ns = ...

-- [key] = { stacks, time left }: what the frame pretends to see. Entries not listed stay dark.
local DEMO = {
	sunder = { 5, "24" },
	faerie = { nil, "33" },
	cor = { nil, "1m" },
	scorch = { 3, "18" },
	isb = { 4, "9" },
	shadowweaving = { 5, "12" },
}

-- name of the picture (gallery.py reads this list), then what shows it
local SHOTS -- filled below, the steps need the functions

local demoOn = false

local function FontFile()
	local file = GameFontNormal and GameFontNormal:GetFont()
	return file or "Fonts\\FRIZQT__.TTF"
end

-- Lights the addon's own icons with the made-up debuffs, or puts them back to "missing".
local function Demo(on)
	local hud = ns.HUD
	if not hud then return end
	demoOn = on and true or false
	-- the client's slots would draw real debuffs over the made-up ones
	if hud.container then
		pcall(hud.container.SetEnabled, hud.container, not on and hud.boundUnit ~= nil)
	end
	local size, font = ns.db.iconSize, FontFile()
	for _, button in ipairs(hud.icons) do
		if not rawget(button, "count") then
			button.count = button:CreateFontString(nil, "OVERLAY")
			button.count:SetPoint("BOTTOMRIGHT", -1, 1)
			button.timer = button:CreateFontString(nil, "OVERLAY")
			button.timer:SetPoint("TOP", 0, -1)
			button.timer:SetTextColor(1, 0.9, 0.4)
		end
		button.count:SetFont(font, math.max(9, math.floor(size * 0.45)), "OUTLINE")
		button.timer:SetFont(font, math.max(8, math.floor(size * 0.36)), "OUTLINE")
		local demo = on and button.entry and DEMO[button.entry.key]
		if demo then
			button.icon:SetDesaturated(false)
			button.icon:SetAlpha(1)
			button.count:SetText(demo[1] or "")
			button.timer:SetText(ns.db.showTimers and demo[2] or "")
		else
			button.icon:SetDesaturated(true)
			button.icon:SetAlpha(0.3)
			button.count:SetText("")
			button.timer:SetText("")
		end
	end
	if on then hud:Show() end
end

-- /adf shots demo: the same for pictures taken by hand
function ns.ToggleDemo()
	Demo(not demoOn)
	ns.Print("shots: made-up debuffs " .. (demoOn and "on" or "off"))
	if not demoOn then ns.Update(true) end
end

-- A plain dark sheet over the whole screen, right behind the frame and the options window: the pictures show
-- them alone, and gallery.py finds them by looking for what is not sheet.
local backdrop
local function Backdrop(on)
	local hud = ns.HUD
	if not on then
		if backdrop then backdrop:Hide() end
		if hud then hud:SetFrameStrata("LOW") end
		return
	end
	if not backdrop then
		backdrop = CreateFrame("Frame", nil, UIParent)
		backdrop:SetAllPoints(UIParent)
		backdrop.Fill = backdrop:CreateTexture(nil, "BACKGROUND")
		-- beyond UIParent's edges too (an ultrawide screen, a UI scale that leaves a margin)
		backdrop.Fill:SetPoint("TOPLEFT", -2000, 2000)
		backdrop.Fill:SetPoint("BOTTOMRIGHT", 2000, -2000)
		backdrop.Fill:SetColorTexture(0.07, 0.07, 0.08, 1)
		backdrop:EnableMouse(true) -- nothing behind it lights up under the mouse
	end
	backdrop:SetFrameStrata("DIALOG")
	backdrop:SetFrameLevel(0)
	hud:SetFrameStrata("DIALOG")
	hud:SetFrameLevel(20)
	backdrop:Show()
end

local function Options(show)
	local window = rawget(_G, "ForeverADFOptions")
	local shown = window and window:IsShown() or false
	if shown ~= show then ns.ToggleOptions() end
	window = rawget(_G, "ForeverADFOptions")
	if show and window then window:Raise() end
	return window
end

SHOTS = {
	-- the frame in the game world, wherever the player stands
	{ "01-world", function()
		Options(false)
		Backdrop(false)
	end },
	-- the frame alone: gallery.py reads from this picture where on the screen the frame is
	{ "02-frame", function()
		Backdrop(true)
	end },
	-- the options, with the frame above them
	{ "03-options", function()
		local window = Options(true)
		if window then
			ns.HUD:ClearAllPoints()
			ns.HUD:SetPoint("BOTTOM", window, "TOP", 0, 30)
		end
	end },
}

local STEP = 2 -- seconds per picture: shown, one second to settle, the picture, one second to the next
local running

function ns.TakeShots()
	local shoot = rawget(_G, "Screenshot")
	if running then return end
	if not shoot then return ns.Print("shots: this client has no Screenshot()") end
	if not ns.HUD then return end
	running = true
	-- the "screen captured" line of one picture would be in the next one
	local status = rawget(_G, "ActionStatus")
	if status and status.UnregisterEvent then status:UnregisterEvent("SCREENSHOT_SUCCEEDED") end
	local hadOptions = rawget(_G, "ForeverADFOptions") and ForeverADFOptions:IsShown() or false
	ns.Print(("shots: %d pictures, about %d seconds. Leave mouse and keyboard alone."):format(#SHOTS, #SHOTS * STEP))
	Demo(true)
	for index, shot in ipairs(SHOTS) do
		C_Timer.After((index - 1) * STEP, function()
			pcall(shot[2])
			Demo(true) -- the options may have laid the frame out anew
			if GameTooltip then GameTooltip:Hide() end
		end)
		C_Timer.After((index - 1) * STEP + 1, function()
			if GameTooltip then GameTooltip:Hide() end -- of whatever the resting mouse is on
			pcall(shoot)
		end)
	end
	C_Timer.After(#SHOTS * STEP, function()
		running = nil
		if status and status.RegisterEvent then status:RegisterEvent("SCREENSHOT_SUCCEEDED") end
		pcall(Options, hadOptions)
		Backdrop(false)
		Demo(false)
		ns.HUD:ApplyPosition()
		ns.Update(true)
		ns.Print("shots: done. Build the gallery with: python media/gallery/gallery.py \"<Screenshots folder>\"")
	end)
end

-- The ticker in Core.lua shows and hides the frame; during pictures it stays as it is.
function ns.ShotsBusy()
	return running or demoOn
end
