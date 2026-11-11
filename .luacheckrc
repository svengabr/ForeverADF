-- luacheck config: every WoW global the addon touches is listed, so typos fail instead of erroring in the client.
std = "lua51"
max_line_length = false
unused_args = false
exclude_files = { ".luacheckrc" }

globals = { "ForeverADF", "ForeverADFCharDB", "SlashCmdList", "SLASH_FOREVERADF1", "SLASH_FOREVERADF2" }

read_globals = {
	"C_ChatInfo",
	"C_PaperDollInfo",
	"C_Secrets",
	"C_Spell",
	"C_Timer",
	"C_UnitAuras",
	"CreateFrame",
	"GameFontNormal",
	"GameTooltip",
	"GameTooltip_Hide",
	"GetLocale",
	"GetTime",
	"InCombatLockdown",
	"IsInGroup",
	"IsInRaid",
	"IsShiftKeyDown",
	"SendChatMessage",
	"UIParent",
	"UISpecialFrames",
	"UnitArmor",
	"UnitCanAttack",
	"UnitExists",
	"UnitGUID",
	"UnitIsDead",
	"UnitLevel",
	"UnitName",
	"UnitResistance",
	"issecretvalue",
	"strlower",
	"strtrim",
}
