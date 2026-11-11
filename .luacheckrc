-- luacheck config: every WoW global the addon touches is listed, so typos fail instead of erroring in the client.
std = "lua51"
max_line_length = false
unused_args = false
exclude_files = { ".luacheckrc" }

globals = { "ForeverADF", "ForeverADFCharDB", "SlashCmdList", "SLASH_FOREVERADF1", "SLASH_FOREVERADF2" }

read_globals = {
	"C_Spell",
	"C_StringUtil",
	"C_Timer",
	"CreateFrame",
	"Enum",
	"GameFontNormal",
	"GameTooltip",
	"GameTooltip_Hide",
	"GetLocale",
	"InCombatLockdown",
	"IsInGroup",
	"IsShiftKeyDown",
	"UIParent",
	"UISpecialFrames",
	"UnitCanAttack",
	"UnitExists",
	"issecretvalue",
	"strlower",
	"strtrim",
}
