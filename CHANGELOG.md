# Changelog

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
