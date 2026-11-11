# Changelog

## 2.0.0

Forever ADF is now a pure debuff frame. Everything the Forever client does not support was removed:

- Removed the armor line and the resistance line: the client answers 0 for both on every enemy.
- Removed chat announcements and the armor total: in combat the client does not let addons know which debuffs
  are up, so both only ever worked outside of fights.
- Own debuffs are added by spell ID only; entries by name could not be shown in combat and were dropped.
- The icons are drawn by the game's aura container alone, in and out of combat. `/adf debug` is gone.

## 1.2.2

- The resistance line is hidden while the client answers 0 for every school, which it does for all enemies.
- Options window: wider debuff columns, no more overlapping label, button and tooltip.
- Built-in debuffs whose spell does not exist in the client (on Forever: Curse of the Elements, Curse of Shadow,
  Ignite) are left out of the list. Add them by their Forever spell ID if they exist under another one.

## 1.2.1

- Out of combat the addon may read whether a slot is lit, in combat the client refuses (tested in the client).
  So in combat the icons work, and the armor line shows `?`; the total and the chat announcements are back as
  soon as the fight ends.
- Where a debuff's rank is hidden, the estimate assumes the highest rank you know yourself instead of the
  highest in the game.

## 1.1.1

- The armor line no longer shows `0` in combat; it shows `?` there, as intended.

## 1.1.0

- Debuff icons now work in combat. The client hides a target's debuffs from addons while you fight, so the icons
  are drawn by the game's own aura container: one slot per tracked debuff, filled in by the client with icon,
  stacks and remaining time.
- In combat the armor line shows `?`, because the addon cannot add up debuffs it is not allowed to read.
  Announcements of single debuffs and of the armor total work out of combat only.
- Debuffs added by name only (no spell ID) cannot get a slot and show `?` in combat. Add them by spell ID.

## 1.0.1

- The client does not hand out an enemy's armor. Instead of a false `0`, the frame now shows how much armor the
  active debuffs take off (vanilla values), e.g. `-1525`; right-click announces that number.
- In combat the client hides the names of a target's debuffs. The addon now remembers debuffs it identified
  before, asks the client for each tracked debuff directly, and only shows `?` where it really cannot tell.
- With "announce when armor goes back up" on, a lost armor debuff is reported even without an armor value.
- `/adf debug` prints what the client hands out about the target, for bug reports.

## 1.0.0

First release: a port of the Turtle WoW addon aDF to WoW: Forever.

- Target armor with damage reduction tooltip, optional resistances.
- Debuff icons with stacks and remaining time, 22 debuffs built in, own debuffs by spell ID or name.
- Friendly targets show what they are attacking.
- Right-click announcements, optional message when the armor goes back up.
- Options window (`/adf`), English and German.
