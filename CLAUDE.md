# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

MountSense is a World of Warcraft retail addon (pure Lua, WoW addon API — no npm/build toolchain). It lets players build named "lists" of mounts and attach conditions to each list (current zone context, active specialization, currently-worn Transmog Outfit). On summon, it randomly picks a mount from whichever list(s) match the player's current situation.

## Development workflow

There is no compiler, linter, or automated test suite — this is a WoW addon, and correctness can only really be verified by loading it in the actual game client and testing interactively (mention this to the user if asked to "verify" a change; do not claim a fix works without in-game confirmation).

**Deploy to the local WoW client for testing:**
```bash
deploy.bat
```
This mirrors the repo into `World of Warcraft/_retail_/Interface/AddOns/MountSense` (path is hardcoded in `deploy.bat` — machine-specific, not portable). After deploying, `/reload` or relog in-game to pick up changes.

**In-game diagnostics** (no external debugger exists, so these slash commands are the primary debugging tool):
- `/ms debug` — prints current context/spec detection and which lists currently match.
- `/ms outfitdebug` — dumps raw `C_TransmogOutfitInfo` data (outfits, resolved slots, active outfit).
- `/run <expr>` — for ad-hoc API probing. WoW enforces a **255-character limit** per command, so probes must be kept short.

**Refresh embedded/external data:**
```bash
python tools/update_db.py          # regenerates tools/MountSenseDB_External.lua (mount family data, scraped from MountJournalEnhanced)
pwsh tools/update_library.ps1      # re-downloads Libs/LibStub and Libs/MountsRarity from upstream
```
Both also run automatically every Monday via `.github/workflows/refresh-data.yml`, which commits any resulting diff straight to `master`.

**Release a new version:**
1. Bump `## Version:` in `MountSense.toc`.
2. Commit, then `git tag vX.Y.Z` and push with `--follow-tags`.
3. `.github/workflows/release.yml` packages and publishes the tag to CurseForge via BigWigsMods/packager (project ID is `## X-Curse-Project-ID:` in the `.toc`).

## Architecture

### Module pattern

Every file follows the same shape and is order-sensitive — module load order is declared explicitly in `MountSense.toc`, and later files depend on earlier ones being loaded (e.g. `MountSenseEditor.lua` calls into `addon.Data` and `addon.Conditions`):

```lua
local addonName, addon = ...
local ThisModule = {}
addon.ThisModule = ThisModule
```

All modules share the single `addon` table (the addon's private namespace, obtained from `...` in every file). `MountSense.lua` also exposes it globally as `MountSense` so macros/other addons can call it. Load order (from the `.toc`): `Libs/*` → `tools/MountSenseDB_External.lua` → `Data` → `Conditions` → `Summon` → `UI` → `Browser` → `Transmog` → `Inspect` → `Editor` → `Settings` → `Minimap` → `MountSense.lua` (entry point, registered last so every module it wires up in `Initialize`/event handlers already exists).

### Module responsibilities

- **MountSense.lua** — entry point: event registration (`ADDON_LOADED`, `PLAYER_LOGIN`, spec/equipment/zone-change events that trigger a mount re-pick), lifecycle (`Initialize`/`OnPlayerLogin`/`OnEnteringWorld`), and the `/ms` slash command family.
- **MountSenseData.lua** — SavedVariables schema and CRUD. Owns `MountSenseDB` (merged against `Data.defaults` on load, two levels deep, so new option keys added later get backfilled into existing players' saved data). Also owns the in-memory mount cache (`Data:BuildMountCache`, rebuilt on login/zone-in) that enriches each mount with category, family, and rarity — see "Mount categorization" below.
- **MountSenseConditions.lua** — pure condition-evaluation logic: detects current context/spec/worn outfit and evaluates a list's `conditions` against them (`EvaluateList`), plus `GetMatchingLists()` which picks the best-matching set of lists. Also owns the Transmog Outfit API layer (see below).
- **MountSenseSummon.lua** — the floating summon button and `PickRandomMount`/`SummonRandom`, which call into `Conditions:GetMatchingLists()` and apply the smart aquatic/flyable/anti-repeat filters (see below).
- **MountSenseUI.lua** — the main window shell: style palette (`UI.C`), shared widget factories (buttons, dropdowns, checkboxes), and the 3-tab system (Browse / My Lists / Settings) that `Editor`/`Browser`/`Settings` render into.
- **MountSenseBrowser.lua** — the "Browse" tab: mount grid, search/filter/sort, bulk-add to a list.
- **MountSenseEditor.lua** — the "My Lists" tab: list CRUD, drag-to-reorder priority, and the per-list condition editor (contexts, specs, Transmog Outfits).
- **MountSenseTransmog.lua** — the Transmog Outfit picker modal (search + checklist) and its live 3D preview (`DressUpModel`), including the async "settle" logic described below.
- **MountSenseInspect.lua** — inspects your mouseover (falling back to your target) for a mount you own but haven't listed anywhere, and opens a picker to add it to one or more lists. Reachable via `/ms inspect` (guaranteed fallback) or the "MountSense" header keybind in Blizzard's Key Bindings UI. Uses `AuraUtil.ForEachAura` + `C_MountJournal.GetMountFromSpell` to identify the mount from the unit's buffs — this works even for mounts you don't personally own, since mount data (unlike collection state) is global per spellID. Unverified in-game as of introduction; probe with `/run` if aura detection misbehaves on a client patch.
- **MountSenseSettings.lua** / **MountSenseMinimap.lua** — the Settings tab and the minimap icon, respectively.

### Keybindings

`BINDING_NAME_*` globals (set in Lua, e.g. `MountSenseInspect.lua`) only supply the **display text** for a binding action — they do **not** by themselves make anything show up in Blizzard's Key Bindings UI. The action itself must be declared in `Bindings.xml` at the addon root, whose body is the Lua to run (a plain global function call is enough; no secure/CLICK-button indirection needed unless the action must remain legal during combat lockdown). `Bindings.xml` is auto-loaded by the client and must **not** be listed in `MountSense.toc`. Every addon-defined keybind should also get a `/ms <name>` slash command fallback, since it doesn't depend on the client having registered the binding correctly.

**Getting your own named section in the list is done via `category`, not `header`.** Confirmed in-game: `Bindings.xml`'s `header` attribute (+ a matching `BINDING_HEADER_*` global) does **not** currently give a binding its own row — it silently falls into whichever section precedes it in the list (in practice, the shared "Add-ons" bucket used by every `category="ADDONS"` binding that relies on `header`). Putting the addon's own name directly as the `category` value instead (e.g. `category="MountSense"`) is what actually produces a distinct, named row — this is how other addons (Raider.IO, MDT, etc.) get their own clean section. `category` is *not* restricted to Blizzard's built-in values (`ADDONS`, `MOVEMENT`, ...) the way older documentation implies; an arbitrary string works and is used as the display label directly, no `BINDING_HEADER_*` needed. Don't reintroduce `header="..."` expecting it to visually separate a binding — verified not to work as of this client version.

`Settings:CreateKeybindRow`/`SetInspectBinding` (`MountSenseSettings.lua`) let the player assign the "MountSense" keybind from inside the addon itself — click to capture the next key, right-click to clear — rather than sending them to Blizzard's own panel. Pattern (ignored-keys list, SHIFT-/CTRL-/ALT- prefixing, `SetBinding` + `SaveBindings(GetCurrentBindingSet())`) is adapted from the widely-used [PhanxConfig-KeyBinding](https://github.com/phanx-wow/PhanxConfig-KeyBinding) library rather than written from scratch. If MountSense ever grows a second keybind, generalize this into a reusable row factory (action name + label as params) instead of copy-pasting it.

### List matching model

Each list has `conditions = { contexts, specs, transmogOutfits }` (all arrays). Within a category, membership is OR ("any of these contexts"); across categories it's AND ("this context AND this spec"). A list with **no** conditions set is a global fallback. `Conditions:GetMatchingLists()` returns *only* condition-having ("strict") matches if any exist; it falls back to global lists only when zero strict matches exist — see `MountSenseConditions.lua:295-317`. Don't change this precedence without confirming with the user; it's intentional priority behavior, not an oversight.

### Smart summon filters (aquatic / flyable / anti-repeat)

`Summon:PickRandomMount` (`MountSenseSummon.lua`) narrows the candidate pool through up to three independently-toggleable filters (`Data.db.options.smartAquatic` / `smartFlyable` / `antiRepeat`, all on by default), each following the same "narrow the pool, but only if it doesn't go empty" pattern:
1. **Aquatic** (`Conditions:IsSwimming()`) is checked first and takes priority over flyable — while swimming it locks the pool to `AQUATIC` mounts and skips the flyable filter entirely (`aquaticLockedIn`), since zone flyability doesn't matter mid-swim.
2. **Flyable** (`Conditions:CanFly()`) — prefers `FLYING` mounts in flyable zones, excludes them otherwise. Same logic as before, just now skipped when the aquatic filter already locked in.
3. **Anti-repeat** — excludes mounts in `Summon.history`, an in-memory (not saved) FIFO of the last 3 **actually-summoned** mount IDs. Recording only happens in `SummonRandom()`, never in `PickRandomMount()` itself — the latter also runs on every passive context-change event (zone/spec/equipment change) just to refresh the button's "next mount" preview, and must not pollute history with mounts that were never actually ridden.

### Mount categorization (GROUND/FLYING/AQUATIC/OTHER, family, rarity)

Three independent, differently-sourced pieces of per-mount metadata get merged onto each `mountData` entry in `Data:BuildMountCache`:
- **Category** (Ground/Flying/Aquatic/Other) — `Data.MOUNT_TYPE_MAP`, a hand-maintained table of `mountTypeID → category` in `MountSenseData.lua`. These IDs come from Blizzard's `MountType.db2` and can drift across patches; unknown IDs fall back to `OTHER`.
- **Family** (Cats, Dragons, etc.) — `addon.ExternalData.MountFamilies`, loaded from `tools/MountSenseDB_External.lua`, an auto-generated file scraped from the MountJournalEnhanced addon's family database by `tools/update_db.py`. Do not hand-edit that file — it's regenerated wholesale by the script (and weekly by CI).
- **Rarity** (% of players who own the mount) — read live from the embedded `MountsRarity` library (`Libs/MountsRarity/`, loaded via `LibStub`), not our own data. The library is refreshed from upstream by `tools/update_library.ps1` / the weekly CI workflow, not by anything in this repo's own logic.

### Transmog Outfit condition

Uses `C_TransmogOutfitInfo` — this is specifically the API behind the Transmogrifier NPC's own "Save Outfit" feature, and is **not** the same as `C_TransmogSets` (Blizzard's curated sets) or `C_TransmogCollection` Custom Sets (the "dressing room" combos), both of which were deliberately rejected during this feature's design. A few hard-won, non-obvious behaviors to preserve:
- **Never call protected Transmog functions** (e.g. `C_TransmogOutfitInfo.ClearOutfit()`) from addon code — they're Blizzard-UI-only and hard-crash/block the addon under WoW's taint system. Probe any new/uncertain API call via a safe `/run` chat command first (fails gracefully in chat) before wiring it into addon code.
- Reading an outfit's per-slot contents goes through a stateful "viewed outfit" session (`ChangeViewedOutfit` + `GetViewedOutfitSlotInfo`) that can return **stale data for a short, unpredictable window** right after switching from a different previously-viewed outfit — no fixed delay reliably covers it. `MountSenseTransmog.lua`'s `SettleOutfitSlots` handles this by re-reading until two consecutive reads agree before trusting/caching the result; don't replace that with a fixed `C_Timer.After` delay.
- The correct per-slot filter for "does this outfit define this slot" is `info.isTransmogrified == true`, **not** `info.transmogID > 0` — a not-really-set slot can still return a nonzero, plausible-looking `transmogID`.
