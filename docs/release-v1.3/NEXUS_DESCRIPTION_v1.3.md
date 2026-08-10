# Body and Clothing Morph for SBBF and BCB — v1.3

*Pick a female body shape per character — Vanilla, SBBF, or BCB — and your armor or clothing refits to match.*

## New tattoo bleedthrough fix — choose your policy in MCM

v1.3 fixes unintended SBBF/BCB body-tattoo bleedthrough and incorrect-atlas behavior on supported naked HUM_F bodies. After installation, open MCM and find **SBBF/BCB body tattoos**:

- **Match Vanilla** — the default. Preserves the character's saved tattoo selection and applies compatible tattoo behavior to naked SBBF and BCB bodies.
- **Hide on SBBF/BCB** — hides the body tattoo on naked SBBF and BCB bodies while leaving Vanilla and the saved tattoo selection untouched.

You can switch policies while playing. Both policies, including switching between them, passed the v1.3 gameplay smoke test in the tested KAVT NVP/non-VT setup. KAVT is optional; no KAVT tattoo textures are included.

**Update — New in v1.3:** the tattoo fix and MCM policies above; **six gameplay-approved SCO garment corrections** (Scalemail Armor and Soul Vest families); **32 camp-clothing variants backed by 18 proper SBBF meshes**; an extended SCO tightening pass for both SBBF and BCB; and a simpler **three-PAK layout**. The required `ClothMorphRuntime.pak` now contains the body switcher, base-game garments, Githyanki support, and tattoo fix. The BCB add-on remains unchanged from v1.2.1.

*Note: this mod adapts existing textures and meshes on garments and bodies — with permission where the items were previously modded. It contains no original garment textures or body meshes. Many thanks to the mod authors whose permissions made this possible; see Credits.*

**FAQ:** see the pinned post in the comments.
**Source:** https://github.com/Shiney1965/BG3-Body-and-Clothing-Morph

## Overview

Body and Clothing Morph lets you choose a vanilla, SBBF or BCB female body shape per character and applies it to the currently controlled character. The choice is stored per character in your save game and persists across save/load. If you are wearing a garment (torso clothing or armor) covered by the mod, your equipped clothing or armor is automatically refitted to the selected body. Almost all garments shipping with the vanilla game are covered, plus others. You can change the shape three ways: the **MCM** (Mod Configuration Menu) UI, **console commands** (e.g. `!cm_setbody vanilla|sbbf|bcb`), or optional **hotkeys**.

## What's included (garment counts)

This build covers the following. Full per-garment included/excluded lists are in **GARMENT_LISTS_v1.3.md** (shipped alongside this file).

- **Main file (ClothMorphRuntime):** the body switcher, tattoo fix, Githyanki support, and base-game garment library in one required PAK. It contains **343 distinct base-game garment meshes** and **1,321 active visual refits** (479 Vanilla, 437 SBBF, and 405 BCB), including proper SBBF meshes for **32 camp-clothing variants backed by 18 meshes**.
- **BCB.pak (from Sindae) add-on (ClothMorphBCB):** **154** garments from Sindae's BCB.pak, morphed to fit Vanilla and SBBF (they keep their native fit on the BCB body). **27** of the 181 scoped BCB garments are excluded (a complex-mesh conversion limitation). This add-on is unchanged from v1.2.1.
- **Scantily Camp Outfits (SCO) add-on (ClothMorphSCO):** **79** meshes in each of its SBBF and BCB folders. The v1.3 tightening pass reduced recorded problem vertices from **2,187 to 122** across 33 comparable garments (**94.4%**) with no measured garment worsening. Six corrected Scalemail Armor/Soul Vest meshes also passed gameplay review. **16** unconvertible garments still use SCO's original mesh and may clip on SBBF/BCB.
- **Githyanki support:** the body switch and clothing refits for Githyanki females, including **Lae'zel**, are now bundled in the Main Runtime rather than a separate PAK.

## Features

- **BCB and SBBF mods are not required** to run the basic version of this mod, but one or the other is compatible (in part) with this mod.
- **Per-character body shape** — Vanilla / SBBF / BCB, applied to the controlled character and saved per character. In practice you can swap the body of your Tav or Durge if they use a human/elf/half-elf/drow/half-drow (BT1) body, and of **Shadowheart** — and, as of v1.2, **Lae'zel** through the Githyanki support included in the Main Runtime. Hirelings, Minthara, or an extra Tav/Durge from another mod should also be covered by the mod if they use the right body type (not thoroughly tested). If you run the standalone BCB or SBBF body mods, that mod governs every BT1 human-type character other than your Tav/Durge — but you should be able to control the body of any player-controlled character with this mod.
- **Automatic clothing/armor refit** to the chosen body.
- **BCB clothing add-on** — morphs 154 BCB outfits so they fit Vanilla and SBBF too (native BCB fit retained).
- **Githyanki support** — the body switch and refits for Githyanki females (Lae'zel), now included in the Main Runtime.
- **Improved SCO fits** — retains the v1.2 SBBF chest-opening correction, extends tightening to the BCB cuts, and corrects the six gameplay-approved Scalemail Armor/Soul Vest meshes.
- **Tattoo policy in MCM** — **Match Vanilla** or **Hide on SBBF/BCB** for naked SBBF/BCB bodies.
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

- **ClothMorphRuntime** *(required / Main)* — engine, body switcher, base-game garment refits, Githyanki support, and tattoo fix.
- **ClothMorphBCB** *(optional)* — the BCB clothing add-on (requires BCB, Nexus 2351).
- **ClothMorphSCO** *(optional)* — the SCO add-on (requires SCO, Nexus 2617).

**Upgrading from v1.2.x:** deactivate and remove the retired `ClothMorphContent.pak` and `ClothMorphGithyanki.pak` before installing v1.3; their content is now inside `ClothMorphRuntime.pak`. Do not leave duplicate older ClothMorph PAKs in the Mods folder. See **UPGRADING_TO_v1.3.md** for the complete sequence.

## How to use

- **MCM:** open the Mod Configuration Menu and use the "Body shape" radio picker (Vanilla / SBBF / BCB) for the controlled character. Use **SBBF/BCB body tattoos** to select **Match Vanilla** or **Hide on SBBF/BCB**.
- **Hotkeys:** in MCM keybindings, bind the "cycle body" key and/or the direct-set keys. Unbound by default (requires MCM 1.19+).
- **Console:** `!cm_setbody vanilla|sbbf|bcb`, plus the diagnostic commands.

## Coverage & limitations (as of v1.3)

- **Base-game garments (Vanilla / SBBF / BCB):** broad coverage (343 distinct meshes / 1,321 active refits) plus the optional SCO add-on.
- **BCB add-on:** 154 garments morphed to Vanilla/SBBF (native BCB fit retained); 27 excluded — see the garment lists.
- **SCO:** the v1.2 SBBF chest-aperture improvement remains; v1.3 extends tightening to BCB and corrects six gameplay-approved Scalemail Armor/Soul Vest meshes. Sixteen unconvertible garments still use SCO's original mesh and may clip on SBBF/BCB.
- **Vanilla-mode note:** *Some garments from Sindae's BCB.pak may appear too large in Vanilla mode, resulting in partial nudity.* These use Sindae's revealing BCB designs; Vanilla and SBBF are otherwise broadly covered.
- **Revealing BCB designs:** in BCB mode, some vanilla armours render Sindae's own revealing BCB look (e.g. a chest-cutout). That is the BCB art, by design.
- **Items outside the covered sets pass through unchanged** — that is by design. For example, *Mercenary Armor* is a vanilla item this mod does not cover, so it looks the same in all modes; the body still morphs, only that armor is out of scope.
- **Nightsong's Armor** renders nude on the player because it is Aylin's NPC armor (no proper player-body visual) — a base-game/source limitation, not a morph defect.
- **Moonshadow Armor (SBBF):** shows the leather body and pants correctly; its small decorative top layer is absent when BCB (BCBPak) is installed (scheduled for a proper fit in a future update).
- **Draped/slinky dresses on BCB** conform only approximately (a conservative reverse-deform, to avoid flattening the flare).
- **Baked-body garments** (e.g. *Full Metal Dress* / CorsetSkirtArm) keep their original BCB version by design.
- **Shar Leggings + Oathbreaker Heels** is excluded (the morph does not apply in testing).
- **Body coverage:** human/elf/half-elf/drow females (HUM_F), plus Githyanki females via support included in the Main Runtime. **Tiefling** females such as Karlach are not yet supported: with BCB (BCBPak) installed they always show the BCB body and cannot be set to Vanilla/SBBF; without BCBPak they stay vanilla. Tiefling support is planned.
- **Multiplayer** support is limited/experimental.

## For mod authors

Clothing-mod authors can opt their items in to automatic refitting by shipping a small marker file, **ClothMorphPermission.json**, inside their pak (under `Mods/<TheirModFolder>/`). It records their permission, the credit line to show, and which bodies/items are in scope. No third-party assets are adapted without permission (posted or provided), and the author's credit line ships verbatim. Full spec in the mod's docs.

## Permissions

This mod is **FREE** and must always stay free; it is not for sale. Because v1.3 ships KAVT compatibility definitions under the KAVT author's published permission terms, **Donation Points must remain disabled for this release**.

## Credits

- **Sindae** — BCB (Nexus 2351) — body and clothing assets, used with permission. This mod's BCB support would not exist without Sindae's work.
- **FredKarrera** — SBBF (Nexus 4864) and the Vanilla Outfits Patch (Nexus 5040).
- **Volitio / AtilioA** — Mod Configuration Menu (Nexus 9162).
- **Norbyte** — BG3 Script Extender.
- **Crosscrusade** — Scantily Clad Camp Outfits (Nexus 2617), for the SCO add-on.
- **Kazstralities / Astralities / Kaz** — KAVT - Kazstra's Virtual Tav x Tattoo Makeup and Scar Extender (Nexus 16325), for the v1.3 compatibility definitions. No KAVT tattoo textures are bundled.

## AI disclosure

This mod was made with the assistance of Claude (Fable 5, Opus 5, Opus 4.8) for coding, including modifying garment meshes to fit alternative body shapes, and documentation drafting.  No textures or artwork were generated by AI. The concept, scope, steering, design, and significant architecture choices are the human author's, as is all in-game testing and debugging. (In other words — Claude is great, but it's still a helluva lot of work.)
