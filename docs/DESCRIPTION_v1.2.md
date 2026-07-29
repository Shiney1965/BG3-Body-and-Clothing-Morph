# Body and Clothing Morph for SBBF and BCB — v1.2

*Pick a female body shape per character — Vanilla, SBBF, or BCB — and your armor or clothing refits to match.*

**Update — New in v1.2:** the BCB clothing add-on (154 BCB garments morphed so they fit Vanilla and SBBF bodies), **Githyanki support** (Githyanki including Lae'zel can now morph, via a bundled add-on), and **improved SCO fits on SBBF** (the chest-opening now grows with the bust). *(v1.1 added Drow and Half-Drow Tav/Durge support.)* Also new — **improved compatibility with SBBF and BCB:** you can now change party-member bodies even with those mods installed. An External Designer Clothing add-on (outfits from several permission-cleared clothing mods), Tiefling support, and more and better BCB and SCO morphs are in progress for a future update.

*Note: this mod adapts existing textures and meshes on garments and bodies — with permission where the items were previously modded. It contains no original garment textures or body meshes. Many thanks to the mod authors whose permissions made this possible; see Credits.*

**FAQ:** see the pinned post in the comments.
**Source:** https://github.com/Shiney1965/BG3-Body-and-Clothing-Morph

## Overview

Body and Clothing Morph lets you choose a vanilla, SBBF or BCB female body shape per character and applies it to the currently controlled character. The choice is stored per character in your save game and persists across save/load. If you are wearing a garment (torso clothing or armor) covered by the mod, your equipped clothing or armor is automatically refitted to the selected body. Almost all garments shipping with the vanilla game are covered, plus others. You can change the shape three ways: the **MCM** (Mod Configuration Menu) UI, **console commands** (e.g. `!cm_setbody vanilla|sbbf|bcb`), or optional **hotkeys**.

## What's included (garment counts)

This build covers the following. Full per-garment included/excluded lists are in **GARMENT_LISTS_v1.2.md** (shipped alongside this file).

- **Base-game garments — Vanilla / SBBF / BCB (ClothMorphContent):** about **405** base-game garment refit meshes, each fitted to the Vanilla, SBBF, and BCB body, plus **74** clean-vanilla clones (revealing tops given a proper covered Vanilla version).
- **BCB.pak (from Sindae) add-on (ClothMorphBCB):** **154** garments from Sindae's BCB.pak, morphed to fit Vanilla and SBBF (they keep their native fit on the BCB body). **27** of the 181 scoped BCB garments are excluded (a complex-mesh conversion limitation) and are candidates for a future update.
- **Scantily Camp Outfits (SCO) add-on (ClothMorphSCO):** **76** SCO garment meshes. The v1.2 chest-aperture fix improves the SBBF fit on **58** of them; the remaining **18** keep their prior look (mostly unconvertible meshes). Additional improvements are in progress for the next version.
- **Githyanki add-on (ClothMorphGithyanki):** brings the body switch and clothing refits to Githyanki females, including **Lae'zel**.

## Features

- **BCB and SBBF mods are not required** to run the basic version of this mod, but one or the other is compatible (in part) with this mod.
- **Per-character body shape** — Vanilla / SBBF / BCB, applied to the controlled character and saved per character. In practice you can swap the body of your Tav or Durge if they use a human/elf/half-elf/drow/half-drow (BT1) body, and of **Shadowheart** — and, as of v1.2, **Lae'zel** through the included Githyanki add-on. Hirelings, Minthara, or an extra Tav/Durge from another mod should also be covered by the mod if they use the right body type (not thoroughly tested). If you run the standalone BCB or SBBF body mods, that mod governs every BT1 human-type character other than your Tav/Durge — but you should be able to control the body of any player-controlled character with this mod.
- **Automatic clothing/armor refit** to the chosen body.
- **BCB clothing add-on** — morphs 154 BCB outfits so they fit Vanilla and SBBF too (native BCB fit retained).
- **Githyanki support** — the body switch and refits for Githyanki females (Lae'zel).
- **Improved SCO on SBBF** — fixes the "chest opening doesn't grow with the bust" problem; garments that couldn't be validated keep their previous look.
- **MCM configuration UI** — a "Body shape" radio picker.
- **Console commands** — `!cm_setbody`, plus diagnostics.
- **Optional hotkeys** via MCM keybindings (cycle + direct-set), all unbound by default — you bind them yourself.
- **Permission-flag system** letting other clothing-mod authors opt their items in (see *For mod authors*).
- **Compatible with BCB and SBBF** — and unlike earlier versions, you can change the body of any character while you control it, including eligible companions, overriding the body those mods set.
- Please report any questions or problems — and if you like the mod, please endorse it.

**Incompatibilities:** Any mod that changes bodies or clothing may be incompatible. The mod is most reliable for base-game clothing in a game without the original BCB mod or SBBF mod separately loaded, and without any other body-changing mod. Most modded garments are not supported at this time (they may still work, and if made for the BCB or SBBF body will probably fit that body). SCO and the full BCB.pak (Sindae) clothing catalog are partially covered by their add-ons (each with a short exclusion list — see the garment lists).

## Requirements (hard)

- **BG3 Mod Configuration Menu (MCM)** — Nexus 9162, by Volitio/AtilioA — **v1.19 or newer** (required for the hotkey feature).
- **BG3 Script Extender (BG3SE)** — by Norbyte.
- **For the SCO add-on only:** Scantily Clad Camp Outfits (SCO) by Crosscrusade — Nexus 2617. The Mod.io version will probably work as well.
- **For the BCB add-on only:** BCB.pak by Sindae — Nexus 2351.

Each add-on bundles only the fitted refit meshes; the garments themselves come from the game or source mod, so that source mod is required for that particular mod add-on. The base mod (which uses base-game garments) needs none of these additional mods.

## Soft requirements (optional / compatibility — for the base mod)

- **SBBF — Stylized Beautiful Body for Female** (Nexus 4864, FredKarrera) + its **Vanilla Outfits Patch** (Nexus 5040) — for SBBF bodies on NPCs and SBBF-only clothing. (Note that clothing will not morph for other body types.)
- **BCB by Sindae** (Nexus 2351) — for the BCB body on NPCs and BCB-only clothing designed by Sindae. (Note only some of that clothing will morph for other body types.)

## Installation & load order

Install the hard requirements, then install Body and Clothing Morph with your mod manager. **Load the ClothMorph paks ABOVE BCB.** Component paks:

- **ClothMorphRuntime** — the engine / Script Extender logic.
- **ClothMorphContent** — the Vanilla/SBBF refit meshes (~405) plus BCB support meshes.
- **ClothMorphBCB** — the BCB clothing add-on (requires BCB, Nexus 2351).
- **ClothMorphSCO** *(optional)* — the SCO add-on (requires SCO, Nexus 2617).
- **ClothMorphGithyanki** — Githyanki female bodies and clothing (Lae'zel).

## How to use

- **MCM:** open the Mod Configuration Menu and use the "Body shape" radio picker (Vanilla / SBBF / BCB) for the controlled character.
- **Hotkeys:** in MCM keybindings, bind the "cycle body" key and/or the direct-set keys. Unbound by default (requires MCM 1.19+).
- **Console:** `!cm_setbody vanilla|sbbf|bcb`, plus the diagnostic commands.

## Coverage & limitations (as of v1.2)

- **Base-game garments (Vanilla / SBBF / BCB):** broad coverage (~405 garment meshes) plus the optional SCO add-on.
- **BCB add-on:** 154 garments morphed to Vanilla/SBBF (native BCB fit retained); 27 excluded — see the garment lists.
- **SCO on SBBF:** substantially improved (the chest-aperture fix); 18 garments keep their prior look.
- **Vanilla-mode note:** *Some garments from Sindae's BCB.pak may appear too large in Vanilla mode, resulting in partial nudity.* These use Sindae's revealing BCB designs; Vanilla and SBBF are otherwise broadly covered.
- **Revealing BCB designs:** in BCB mode, some vanilla armours render Sindae's own revealing BCB look (e.g. a chest-cutout). That is the BCB art, by design.
- **Items outside the covered sets pass through unchanged** — that is by design. For example, *Mercenary Armor* is a vanilla item this mod does not cover, so it looks the same in all modes; the body still morphs, only that armor is out of scope.
- **Nightsong's Armor** renders nude on the player because it is Aylin's NPC armor (no proper player-body visual) — a base-game/source limitation, not a morph defect.
- **Moonshadow Armor (SBBF):** shows the leather body and pants correctly; its small decorative top layer is absent when BCB (BCBPak) is installed (scheduled for a proper fit in a future update).
- **Draped/slinky dresses on BCB** conform only approximately (a conservative reverse-deform, to avoid flattening the flare).
- **Baked-body garments** (e.g. *Full Metal Dress* / CorsetSkirtArm) keep their original BCB version by design.
- **Shar Leggings + Oathbreaker Heels** is excluded (the morph does not apply in testing).
- **Body coverage:** human/elf/half-elf/drow females (HUM_F), plus Githyanki females via the included add-on. **Tiefling** females such as Karlach are not yet supported: with BCB (BCBPak) installed they always show the BCB body and cannot be set to Vanilla/SBBF; without BCBPak they stay vanilla. Tiefling support is planned.
- **Multiplayer** support is limited/experimental.

## For mod authors

Clothing-mod authors can opt their items in to automatic refitting by shipping a small marker file, **ClothMorphPermission.json**, inside their pak (under `Mods/<TheirModFolder>/`). It records their permission, the credit line to show, and which bodies/items are in scope. No third-party assets are adapted without permission (posted or provided), and the author's credit line ships verbatim. Full spec in the mod's docs.

## Permissions

This mod is **FREE** and must always stay free; it is not for sale. Donation Points are fine.

## Credits

- **Sindae** — BCB (Nexus 2351) — body and clothing assets, used with permission. This mod's BCB support would not exist without Sindae's work.
- **FredKarrera** — SBBF (Nexus 4864) and the Vanilla Outfits Patch (Nexus 5040).
- **Volitio / AtilioA** — Mod Configuration Menu (Nexus 9162).
- **Norbyte** — BG3 Script Extender.
- **Crosscrusade** — Scantily Clad Camp Outfits (Nexus 2617), for the SCO add-on.

## AI disclosure

This mod was made with the assistance of Claude (Fable 5, Opus 5, Opus 4.8) for coding, including modifying garment meshes to fit alternative body shapes, and documentation drafting.  No textures or artwork were generated by AI. The concept, scope, steering, design, and significant architecture choices are the human author's, as is all in-game testing and debugging. (In other words — Claude is great, but it's still a helluva lot of work.)
