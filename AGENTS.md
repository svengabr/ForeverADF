# AGENTS.md

Notes for AI agents working on Forever ADF.

## What the addon does

A port in spirit of aDF (Turtle WoW armor/debuff frame: github.com/Zebouski/aDF, github.com/Autignem/aDF) to
WoW: Forever. Written from scratch; the originals carry no license, so do not paste their code.

On Forever only the debuff half of aDF is possible (see "Client facts"), so this is a debuff frame.

- `Data.lua` – the built-in debuffs (key, spell ids of all ranks, fallback icon).
- `Locale.lua` – English keys, one table of overrides per language (deDE, frFR, esES/esMX, ptBR, ruRU). The
  translations other than German were written by the AI and not checked by a native speaker.
- `Core.lua` – namespace (`ForeverADF` global = `ns`), saved variables, the debuff list (`ns.BuildIndex`), which
  unit is shown (`ns.Update`), slash command.
- `Frame.lua` – the frame on screen (`ns.HUD`): per debuff a dimmed icon of the addon and, on top, a slot of
  the client's aura container. `Layout` runs after option changes.
- `Options.lua` – the options window, built on first use.

## Client facts (all seen in the client, November 2026)

- Interface 16001, Blizzard UI source: Gethe/wow-ui-source, branch `forever` (a 12.x-based client, vanilla-style
  classes and spell ranks, level 60).
- `UnitArmor` and `UnitResistance` of an enemy answer `0` out of combat and a secret in combat. There is no
  armor or resistance to show.
- In combat (`C_Secrets.ShouldAurasBeSecret()` true) `C_UnitAuras.GetAuraDataByIndex` raises "Auras cannot be
  accessed when secret", and `GetUnitAuraBySpellID` / `GetAuraDataBySpellName` return nil.
- The way to show auras in combat is the client's `AuraContainer` (`CustomAuraContainerTemplate`):
  `AddAuraSlot(key, "HARMFUL", { initializeFrame, candidateFilters = { includeSpellIDs } })`, `SetUnit`,
  `SetEnabled`, `SetAuraSlotEnabled`; on the slot frame `SetIcon`, `SetApplicationCount`, `SetDurationText`.
  Recipe taken from Platynator (`Display/Auras/AurasNext.lua`). Slot frames may only be moved out of combat.
- In combat a slot frame answers nothing: `IsShown`, `IsVisible`, `GetAlpha`, `GetTexture` of its icon and
  `GetText` of its font strings raise errors, `HookScript("OnShow")` is refused. The addon cannot know in combat
  which debuffs are up. Versions 1.0–1.2 tried (armor total, chat announcements); do not try again.
- Vanilla spells missing in the Forever client: Curse of the Elements (1490), Curse of Shadow (17862),
  Ignite (12654).

## Rules

- English only in the repo (code, comments, commits, docs). Other languages live in `Locale.lua` and the TOC notes only.
- Conventional Commits.
- No unit tests; in-game behaviour can only be checked in the client – say so honestly.
- luacheck: `docker run --rm -v "$PWD:/data" -w /data ghcr.io/lunarmodules/luacheck .` – add new globals to
  `.luacheckrc`.

## Release

Publishing is automatic via `.github/workflows/release.yml` (BigWigsMods/packager) to CurseForge and GitHub
Releases, **only on tags** `v*`, never on a plain push. It needs the repo secret `CF_API_KEY` and the line
`## X-Curse-Project-ID: <id>` in the TOC.

1. Add the new version to `CHANGELOG.md` (heading `## X.Y.Z`) and commit.
2. Create an annotated tag `vX.Y.Z` and push it; that starts the upload.

Don't replace `## Version: @project-version@` by hand, the packager sets it from the tag; a source checkout
shows `dev`. The README is also the CurseForge project description: after README changes, remind the maintainer
to paste it there by hand, without the title, the logo and the gallery images (the CurseForge page already shows
them above the description). Tags and pushes only after the maintainer approves.

## Artwork

`media/logo.svg` is drawn by hand (no game assets; CurseForge rejects those as a logo). `sh media/render-logo.sh`
renders `media/logo.png` and the in-game `Icon.tga`.

The gallery pictures are real in-game screenshots, not retouched. `/adf shots` (`Shots.lua`) lights made-up
debuffs on the frame and takes three screenshots: the frame in the world, the frame alone in front of a plain
sheet, and the options in front of that sheet. `/adf shots demo` switches the made-up debuffs on and off for
pictures taken by hand. Then

    python media/gallery/gallery.py "<WoW folder>/_forever_/Screenshots"

copies the run to `media/gallery/src/` (git-ignored) and writes `01-ingame.jpg` and `02-options.jpg`
(1920×1080). Needs Pillow and numpy.
