# Forever ADF

Armor and debuff frame for **WoW: Forever**. A small frame that shows what matters about your target's defences:
its armor, its resistances and whether the important raid debuffs are up.

It is a port of the Turtle WoW addon [aDF](https://turtle-wow.fandom.com/wiki/ADF), written from scratch for the
Forever client.

## Features

- **Armor**: how much armor the active debuffs take off your target (the client keeps the real value to itself).
- **Resistances** (fire, nature, frost, shadow, arcane) in a line above the armor, optional.
- **Debuff icons**: bright when the debuff is on the target, dimmed when it is missing, with stack count and
  remaining time.
- **Friendly target?** Then the frame describes what your target is attacking, so healers see the boss through
  the tank.
- **Announce** with a right-click: the armor value, or whether a debuff is up, to say, yell, party, raid or raid
  warning. "Automatic" picks raid, then party, then say.
- **Armor went back up?** Optionally tells your group when a debuff ran out, and which one.
- **Your own debuffs**: add any debuff by spell ID or by its exact name.
- Works in every client language: debuffs are matched by spell ID and by the client's own spell names.
- English and German interface.

### Debuffs out of the box

Shown by default: Sunder Armor, Expose Armor, Faerie Fire (both forms), Curse of Recklessness, Armor Shatter
(Annihilator), Curse of the Elements, Curse of Shadow, Fire Vulnerability (Improved Scorch), Winter's Chill,
Shadow Vulnerability (Improved Shadow Bolt), Shadow Vulnerability (Shadow Weaving), Spell Vulnerability
(Nightfall).

Available in the options: Ignite, Judgement of Wisdom, Judgement of Light, Judgement of the Crusader,
Demoralizing Shout, Demoralizing Roar, Thunder Clap, Hunter's Mark, Curse of Weakness, Curse of Tongues.

## Usage

| Command | What it does |
| --- | --- |
| `/adf` or `/adf options` | Open the options |
| `/adf show` | Show the frame |
| `/adf hide` | Hide the frame |
| `/adf lock` | Lock or unlock the position |
| `/adf reset` | Put the frame back to its default position |
| `/adf debug` | Print what the client hands out about the target |

- **Move**: hold Shift and drag the frame with the left mouse button.
- **Announce**: right-click the armor number or a debuff icon.
- **Remove one of your own debuffs**: right-click it in the options.

Settings are saved per character.

## Installation

Copy the folder into `World of Warcraft/_forever_/Interface/AddOns/` and name it `ForeverADF`.

## Good to know

- **No real armor value for enemies.** The Forever client does not hand out an enemy's armor to addons. The
  frame shows how much armor the active debuffs take off instead (vanilla values, e.g. `-1525`). Should the
  client hand out an armor value, the frame shows that.
- **Combat hides debuffs from addons.** While you fight, the client does not let addons read a target's
  debuffs, and it refuses every question about them. The icons still work, because the game draws them itself
  (its aura container, one slot per spell ID). What does not work in combat: the armor total (the line shows
  `?`) and the chat announcements. Both are back the moment the fight ends.
- Debuffs you add by name only show `?` in combat. Add them by spell ID and they work like the built-in ones.
- Say and yell need a click outside of instances. The automatic "armor went back up" message therefore goes to
  party or raid only; without a group it is printed to your own chat.
- `/adf debug` prints what the client hands out about your target. Add its output to bug reports.

## Differences to aDF

- No SuperWoW, no tooltip scanning: the modern aura API gives spell IDs, stacks and real remaining times.
- The reason for an armor rise comes from the debuffs that disappeared, not from a table of armor values.
- Debuffs that do not exist on Forever simply stay dark; add what your raid needs as your own entries.

## Credits

aDF was created by **Atreyyo** (Vanillagaming.org), maintained for Turtle WoW by **Zebouski** with contributions
by **Goffauxs**, and rewritten as 4.x by **Autignem**. Forever ADF shares the idea and the look, not the code.

## License

GPL-3.0-or-later, see [LICENSE](LICENSE).
