-- The debuffs Forever ADF knows out of the box.
--
-- key     stable id used in the saved variables
-- name    English name, for readers of this file only
-- ids     spell ids of the aura (all ranks). The client shows a debuff in its slot by these ids, and the label
--         comes from the client's own spell name, so the addon works in every language. An entry of which the
--         client knows no id is left out.
-- icon    fallback icon (file name in Interface\Icons) when the client has no texture for the ids
-- note    where the debuff comes from, when the aura name alone does not say it
-- default shown on a fresh install
local _, ns = ...

ns.Debuffs = {
	{ key = "sunder", name = "Sunder Armor", ids = { 7386, 7405, 8380, 11596, 11597 },
		icon = "Ability_Warrior_Sunder", default = true },
	{ key = "expose", name = "Expose Armor", ids = { 8647, 8649, 8650, 11197, 11198 },
		icon = "Ability_Warrior_Riposte", default = true },
	{ key = "faerie", name = "Faerie Fire", ids = { 770, 778, 9749, 9907, 16857, 17390, 17391, 17392 },
		icon = "Spell_Nature_FaerieFire", default = true },
	{ key = "cor", name = "Curse of Recklessness", ids = { 704, 7658, 7659, 11717 },
		icon = "Spell_Shadow_UnholyStrength", default = true },
	{ key = "shatter", name = "Armor Shatter", ids = { 16928 }, note = "Annihilator",
		icon = "INV_Axe_12", default = true },
	{ key = "coe", name = "Curse of the Elements", ids = { 1490, 11721, 11722 },
		icon = "Spell_Shadow_ChillTouch", default = true },
	{ key = "cos", name = "Curse of Shadow", ids = { 17862, 17937 },
		icon = "Spell_Shadow_CurseOfAchimonde", default = true },
	{ key = "scorch", name = "Fire Vulnerability", ids = { 22959 }, note = "Improved Scorch",
		icon = "Spell_Fire_SoulBurn", default = true },
	{ key = "winterschill", name = "Winter's Chill", ids = { 12579 },
		icon = "Spell_Frost_ChillingBlast", default = true },
	{ key = "isb", name = "Shadow Vulnerability", ids = { 17794, 17797, 17798, 17799, 17800 }, note = "Improved Shadow Bolt",
		icon = "Spell_Shadow_ShadowBolt", default = true },
	{ key = "shadowweaving", name = "Shadow Vulnerability", ids = { 15258 }, note = "Shadow Weaving",
		icon = "Spell_Shadow_BlackPlague", default = true },
	{ key = "nightfall", name = "Spell Vulnerability", ids = { 23605 }, note = "Nightfall",
		icon = "Spell_Holy_ElunesGrace", default = true },
	{ key = "ignite", name = "Ignite", ids = { 12654 },
		icon = "Spell_Fire_Incinerate" },
	{ key = "jow", name = "Judgement of Wisdom", ids = { 20186, 20354, 20355 },
		icon = "Spell_Holy_RighteousnessAura" },
	{ key = "jol", name = "Judgement of Light", ids = { 20185, 20344, 20345, 20346 },
		icon = "Spell_Holy_HealingAura" },
	{ key = "jotc", name = "Judgement of the Crusader", ids = { 21183, 20188, 20300, 20301, 20302, 20303 },
		icon = "Spell_Holy_HolySmite" },
	{ key = "demoshout", name = "Demoralizing Shout", ids = { 1160, 6190, 11554, 11555, 11556 },
		icon = "Ability_Warrior_WarCry" },
	{ key = "demoroar", name = "Demoralizing Roar", ids = { 99, 1735, 9490, 9747, 9898 },
		icon = "Ability_Druid_DemoralizingRoar" },
	{ key = "thunderclap", name = "Thunder Clap", ids = { 6343, 8198, 8204, 8205, 11580, 11581 },
		icon = "Spell_Nature_ThunderClap" },
	{ key = "huntersmark", name = "Hunter's Mark", ids = { 1130, 14323, 14324, 14325 },
		icon = "Ability_Hunter_SniperShot" },
	{ key = "cow", name = "Curse of Weakness", ids = { 702, 1108, 6205, 7646, 11707, 11708 },
		icon = "Spell_Shadow_CurseOfMannoroth" },
	{ key = "cot", name = "Curse of Tongues", ids = { 1714, 11719 },
		icon = "Spell_Shadow_CurseOfTounges" },
}
