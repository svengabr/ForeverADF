# Forever ADF

Debuff frame for **WoW: Forever**. A small grid of icons that shows at a glance which of the important raid
debuffs are on your target, in and out of combat.

It is a port of the Turtle WoW addon [aDF](https://turtle-wow.fandom.com/wiki/ADF), written from scratch for the
Forever client.

## Features

- **Debuff icons**: lit when the debuff is on the target, dark when it is missing, with stack count and
  remaining time.
- **Works in combat.** The icons are drawn by the game's own aura display, so they keep working while you fight.
- **Friendly target?** Then the frame shows the debuffs of what your target is attacking, so healers see the
  boss through the tank.
- **Your own debuffs**: add any debuff by its spell ID.
- Works in every client language. English and German interface.

### Debuffs out of the box

Shown by default: Sunder Armor, Expose Armor, Faerie Fire (both forms), Curse of Recklessness, Armor Shatter
(Annihilator), Fire Vulnerability (Improved Scorch), Winter's Chill, Shadow Vulnerability (Improved Shadow Bolt),
Shadow Vulnerability (Shadow Weaving), Spell Vulnerability (Nightfall).

Available in the options: Judgement of Wisdom, Judgement of Light, Judgement of the Crusader, Demoralizing
Shout, Demoralizing Roar, Thunder Clap, Hunter's Mark, Curse of Weakness, Curse of Tongues.

A debuff whose spell does not exist in your client is left out of the list.

## Usage

| Command | What it does |
| --- | --- |
| `/adf` or `/adf options` | Open the options |
| `/adf show` | Show the frame |
| `/adf hide` | Hide the frame |
| `/adf lock` | Lock or unlock the position |
| `/adf reset` | Put the frame back to its default position |

- **Move**: hold Shift and drag the frame with the left mouse button.
- **Remove one of your own debuffs**: right-click it in the options.

Settings are saved per character.

## Installation

Copy the folder into `World of Warcraft/_forever_/Interface/AddOns/` and name it `ForeverADF`.

## What is missing compared to aDF, and why

aDF on Turtle WoW also shows the target's armor and resistances and announces them in chat. Forever ADF does
not, because the Forever client does not make it possible:

- **Armor and resistances.** The client answers `0` for the armor and every resistance of every enemy.
- **Chat announcements and armor totals.** While you are in combat, the client lets addons read nothing about a
  unit's debuffs. The game can draw them (that is how the icons work), but the addon never learns which ones
  are up, so it cannot announce them or add up their armor reduction.

Should a later client patch hand out those values, they can come back.

Three debuffs of the original list do not exist in the Forever client under their vanilla spell IDs and are
therefore not listed: Curse of the Elements, Curse of Shadow and Ignite. If they exist under other IDs, add them
as your own debuffs.

## Credits

aDF was created by **Atreyyo** (Vanillagaming.org), maintained for Turtle WoW by **Zebouski** with contributions
by **Goffauxs**, and rewritten as 4.x by **Autignem**. Forever ADF shares the idea and the look, not the code.
The way to show debuffs in combat was learned from **Platynator**.

## License

GPL-3.0-or-later, see [LICENSE](LICENSE).
