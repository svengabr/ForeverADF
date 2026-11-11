# AGENTS.md

Notes for AI agents working on Forever ADF.

## What the addon does

A port in spirit of aDF (Turtle WoW armor/debuff frame: github.com/Zebouski/aDF, github.com/Autignem/aDF) to
WoW: Forever. Written from scratch; the originals carry no license, so do not paste their code.

- `Data.lua` – the built-in debuffs (key, English name, spell ids of all ranks, fallback icon).
- `Locale.lua` – English keys, deDE overrides.
- `Core.lua` – namespace (`ForeverADF` global = `ns`), saved variables, debuff index (`ns.BuildIndex`), target
  reading (`ns.Update`, every 0.25 s and on events), chat, slash command.
- `Frame.lua` – the frame on screen (`ns.HUD`, `Layout` after option changes, `Render` on every update).
- `Options.lua` – the options window, built on first use.

## Client facts

- Interface 16001, Blizzard UI source: Gethe/wow-ui-source, branch `forever` (a 12.x-based client, vanilla-style
  classes and spell ranks, level 60).
- Secret restrictions exist on Forever. Never compare or do maths on an API value without `ns.Plain`. A font
  string may show a secret (`SetText` in a `pcall`), the addon may not look at it.
- Unit tokens like `targettarget` can be refused by aura and stat functions; every such call is in a `pcall`.
- Debuffs are matched by spell id first, then by the client's localized spell name. A name shared by two entries
  (both "Shadow Vulnerability" debuffs) is matched by id only.

## Rules

- English only in the repo (code, comments, commits, docs). German lives in `Locale.lua` only.
- Conventional Commits.
- No unit tests; in-game behaviour can only be checked in the client – say so honestly.
- luacheck: `docker run --rm -v "$PWD:/data" -w /data ghcr.io/lunarmodules/luacheck .` – add new globals to
  `.luacheckrc`.
