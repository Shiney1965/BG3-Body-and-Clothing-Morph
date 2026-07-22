# Body and Clothing Morph for SBBF and BCB

Pick a female body shape per character — Vanilla, SBBF, or BCB — and your armor or clothing refits to match.

<https://github.com/Shiney1965/BG3-Body-and-Clothing-Morph>

## Overview

Body and Clothing Morph lets you choose a female body shape per character and applies it to the currently controlled character. The choice is stored per character in your savegame and persists across save/load. Your equipped clothing and armor is automatically refitted to the selected body.

You can change the body shape three ways:

- The MCM (Mod Configuration Menu) UI
- Console commands (e.g. `!cm_setbody vanilla|sbbf|bcb`)
- Optional hotkeys

## Features

- **Per-character body shape** — Vanilla / SBBF / BCB, applied to the controlled character and saved per character.
- **Automatic clothing/armor refit** to the chosen body.
- **MCM configuration UI** — a "Body shape" radio picker.
- **Console commands** — `!cm_setbody`, plus diagnostics.
- **Optional hotkeys** via MCM keybindings: a "cycle body" key plus direct-set keys for Vanilla / SBBF / BCB. All unbound by default (so they never clash out of the box) — you bind them yourself in MCM.
- **Permission-flag system** that lets other clothing-mod authors opt their items in to being auto-refitted by this mod (see *For mod authors* below).
- Incorporates clothing mods where permissions allow — SCO, BCB and others (with limitations).
- Compatible with BCB and SBBF (with some limits — mod only works on a Tav, not an Origin character).

## Requirements

- [BG3 Mod Configuration Menu (MCM)](https://www.nexusmods.com/baldursgate3/mods/9162), by Volitio/AtilioA — NexusMods mod 9162, version 1.19 or newer (required for the hotkey/keybinding feature).
- BG3 Script Extender (BG3SE), by Norbyte.

**For the SBBF body option** — soft requirement (compatible if you want SBBF on NPCs or special SBBF-only clothing):

- [SBBF — Stylized Beautiful Body for Female](https://www.nexusmods.com/baldursgate3/mods/4864), by FredKarrera — NexusMods mod 4864 (and its [Vanilla Outfits Patch](https://www.nexusmods.com/baldursgate3/mods/5040), mod 5040).

**For the BCB body and BCB clothing** — soft requirement (compatible if you want BCB on NPCs or special BCB-only clothing):

- [BCB by Sindae](https://www.nexusmods.com/baldursgate3/mods/2351) — NexusMods mod 2351.

**For the BCB clothing add-on (`ClothMorphBCB`)** — required **only if you install that optional add-on**:

- [BCB by Sindae](https://www.nexusmods.com/baldursgate3/mods/2351) — NexusMods mod 2351. Like the SCO add-on, `ClothMorphBCB` ships **only** the vanilla- and SBBF-fitted refit meshes; the BCB garments themselves, and their native BCB appearance, come from BCBPak. BCBPak must therefore be installed and enabled for the BCB add-on to have any effect — without it, `ClothMorphBCB` does nothing. (This is separate from the soft-requirement note above, which is about using the BCB *body* on NPCs.)

**For the SCO add-on (`ClothMorphSCO`)** — required **only if you install that optional add-on**:

- [Scantily Clad Camp Outfits (SCO)](https://www.nexusmods.com/baldursgate3/mods/2617), by Crosscrusade — NexusMods mod 2617. The SCO add-on ships **only** the SBBF- and BCB-fitted refit meshes for these outfits; the outfits themselves, and their Vanilla appearance, come from the SCO mod. SCO must therefore be installed and enabled for the SCO add-on to have any effect — without it, `ClothMorphSCO` does nothing. (The base Body and Clothing Morph mod does **not** need SCO; this requirement applies only to the optional SCO add-on.)

## Installation

- Install the hard requirements above.
- Install Body and Clothing Morph with your mod manager.
- Load order: load Body and Clothing Morph (the ClothMorph paks) **ABOVE BCB** in the load order.

### For the technically curious — load order

Internal component paks:

- **ClothMorphRuntime** — the engine / Script Extender logic.
- **ClothMorphContent** — the Vanilla/SBBF refit meshes (~405 garments).
- **ClothMorphBCB** — the BCB clothing add-on. Requires BCBPak by Sindae (NexusMods 2351) to be installed and enabled.
- **ClothMorphSCO** (optional) — Scantily Clad Camp Outfits add-on. Requires the Scantily Clad Camp Outfits mod (NexusMods 2617) to be installed and enabled.

## How to use

**MCM:** Open the Mod Configuration Menu and use the "Body shape" radio picker to choose Vanilla, SBBF, or BCB for the currently controlled character.

**Hotkeys:** In MCM keybindings, bind the "cycle body" key and/or the direct-set keys for Vanilla / SBBF / BCB. These are unbound by default — set them to whatever you like. (Requires MCM 1.19 or newer.)

**Console:** Use commands such as `!cm_setbody vanilla`, `!cm_setbody sbbf`, or `!cm_setbody bcb`, plus the diagnostic commands.

## Coverage & Limitations

As of initial release:

- Vanilla and SBBF bodies: broad vanilla clothing coverage with SCO optional add-on (the ClothMorphContent set, ~405 garments).
- BCB body/clothing: in progress. Some BCB items are validated for use with non-BCB bodies via this mod. Some will only fit BCB bodies, or will apply the BCB body regardless of the mod setting.

Known limitations:

- On the BCB body, some draped/slinky dresses conform only approximately (the refit is a reverse-deform, kept conservative to avoid flattening the dress's flare).
- Some garments that bake their own body into the mesh (e.g. the "Full Metal Dress" / CorsetSkirtArm) intentionally render as their original BCB version and do not morph — this is by design, to avoid a worse artifact.
- The "Shar Leggings + Oathbreaker Heels" outfit is excluded (the body morph does not apply to it in testing).
- Female human/elf/half-elf/drow bodies only (HUM_F). Other races and body types are not yet covered.
- Multiplayer support is limited/experimental.

## For mod authors

Other clothing-mod authors can opt their items in to automatic refitting by shipping a small marker file named `ClothMorphPermission.json` inside their pak (under `Mods/<TheirModFolder>/`). It records their explicit permission, the credit line they want shown, and which bodies/items are in scope.

No third-party assets are adapted without the author's permission either posted or otherwise provided, and the author's credit line ships verbatim. The full spec is in the mod's docs.

## Permissions

This mod is FREE and must always stay free; it is not for sale. Donation Points are fine.

## Credits

- **Sindae — BCB** (NexusMods mod 2351) — body and clothing assets, used with permission. Credit required, and gladly given: this mod's BCB support would not exist without Sindae's work.
- **FredKarrera — SBBF** (Stylized Beautiful Body for Female, NexusMods mod 4864) and the Vanilla Outfits Patch (mod 5040).
- **Volitio / AtilioA — Mod Configuration Menu** (NexusMods mod 9162).
- **Norbyte — BG3 Script Extender.**
- **Crosscrusade — Scantily Clad Camp Outfits** (NexusMods mod 2617) (if the SCO add-on is included).
