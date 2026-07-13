# Clothing Morph for Specialized Bodies — Approach & Open Questions

*Date: 2026-06-20. Status: research synthesis + locked design decisions. Not yet a build spec — one gating feasibility question remains (see §4).*

## 1. Goal (restated)

A mod that makes clothing/armor fit a player's chosen specialized female body — **SBBF** (Stylized Beautiful Body for Female) and **BCB** (Beautiful Curvy Body). Vanilla items first; modded items only when the original author has opted in via a marker.

## 2. Locked design decisions (from 2026-06-20 Q&A)

- **Architecture:** BG3SE runtime selection — a Script Extender script redirects an equipped item's visual to the body-correct mesh at runtime, rather than globally overriding vanilla files.
- **Target bodies:** Both SBBF and BCB, from one design.
- **Scope (v1):** Body Type 1 — Feminine Regular (BodyShape 0 / BodyType 1) — across **all** armor slots.
- **Permission for modded clothing:** an **in-mod marker** (a marker file or a tag in the author's `meta.lsx`) that the mod scans for before touching that item.

## 3. The unavoidable dependency every architecture shares

BG3 has **no runtime mesh deformation for armor**. A garment "fits" a body only because someone pre-baked a weight-painted, body-shaped GR2 mesh in Blender. Armor meshes are skinned to the body armature and, on skin-tight pieces, **the body mesh cannot be hidden** — the body shape is effectively baked into the garment ([Weight Painting Armor](https://wiki.bg3.community/Tutorials/Visual/Weight-Painting-Armor), [Body Models](https://bg3.wiki/wiki/Modding:Body_Models)). That is exactly why a body replacer needs its outfits refitted, and why the existing *SBBF Vanilla Outfits Patch* and *BCB* ship refitted garment meshes ([SBBF Vanilla Outfits Patch](https://www.nexusmods.com/baldursgate3/mods/5040), [BCB ref](https://www.nexusmods.com/baldursgate3/mods/8556)).

**Consequence:** runtime selection does not remove the need to author/ship a library of SBBF-fit and BCB-fit GR2 meshes. It only changes *how they are applied*. The SE layer **selects among meshes that must already exist** — it cannot create fit ([bg3se](https://github.com/Norbyte/bg3se), [Dynamic Appearance Framework](https://www.nexusmods.com/baldursgate3/mods/2276)). So the project is really two pieces:

1. **A refit-mesh library** (build-time authoring) — SBBF-fit and BCB-fit meshes for vanilla BT1-female outfits.
2. **A runtime selector** (BG3SE) — picks the right mesh per character based on chosen body + permission marker.

For vanilla items, the library can lean on the existing SBBF/BCB outfit patches as the mesh source (with our mod redirecting to them per-character), and we only author gap-fill refits where coverage is missing. This is the genuine advantage of the runtime approach over the existing static patches: the existing patches override **globally** (every BT1-female NPC changes); an SE selector can apply the refit **only to chosen characters** and **conditionally** (permission marker, chosen body).

## 4. KEY RISK — gating feasibility spike (must resolve before the build spec)

The chosen architecture's linchpin is: *can SE replace an equipped item's mesh, per character, cleanly?* The current evidence is **mixed/cautionary**:

- The Dynamic Appearance Framework author states that using `Osi.AddCustomVisualOverride` for **equipment** appearances is "technically possible" but "non-trivial," requiring `CharacterCreationSharedVisual` setup and a way to **hide the existing gear** — and the API is currently **additive** (it *adds* a visual; it does not natively *replace/suppress* the equipped armor's own mesh) ([Dynamic Appearance Framework](https://www.nexusmods.com/baldursgate3/mods/2276), [Changing Character Visuals](https://wiki.bg3.community/Tutorials/Visual/Changing-CharacterVisuals)).

If the only available mechanism is additive overlay, we'd get the refit mesh *plus* the original garment mesh both rendering — unacceptable. So before committing, we need to prove one of these works:

- **(a)** SE can mutate the equipped item entity's **visual component** directly (swap its `VisualResourceID` to the refit resource), or
- **(b)** SE can change the character's/item's **EquipmentRace** resolution at runtime so the engine itself picks the refit mesh from the item's `Visuals` map, or
- **(c)** the additive-override path with reliable suppression of the original gear visual is achievable.

**Spike:** on one character, one chest piece, attempt (a)→(b)→(c) in order; success = the refit mesh renders alone, no clipping double-mesh, stats unchanged, survives save/load and re-equip. If **all three fail**, the honest fallback is the **static override pack** (like the existing patches) with body chosen at install time — losing per-character/conditional behavior but guaranteed to work. I recommend we run this spike first; it determines whether the chosen architecture is buildable as imagined.

## 5. Permission marker scheme (modded clothing)

Because refitting redistributes a reshaped copy of another author's mesh — or at minimum redirects to one — the marker is fundamentally a **redistribution/consent opt-in**, not a gameplay flag. In-mod marker (your choice) keeps consent inside the author's own package. Proposed: a small file at a known path in the author's mod (e.g. `Mods/<ModName>/clothmorph_optin.json`) and/or a recognizable tag in their `meta.lsx`, declaring opted-in item UUIDs and which bodies they permit. Our SE selector enumerates loaded mods at boot, reads markers, and only redirects flagged items. Unflagged modded items are left untouched.

## 6. Mesh-refit pipeline (build-time, my/your machine — not the player's)

Tooling that exists and is proven: **Outfit Builder** and **BG3 Lazy Tailor** (weight-transfer + rig-driven shape morph between body presets, supports custom presets incl. SBBF), plus **NullFit** for batch ([Outfit Builder refit](https://bg3.wiki/wiki/Modding:Use_Outfit_Builder_To_Refit_Outfits), [Lazy Tailor](https://www.nexusmods.com/baldursgate3/mods/15414) / [source](https://github.com/V0ln0/BG3_Lazy_Tailor), [SBBF blend template](https://www.nexusmods.com/baldursgate3/mods/11586)). GR2 ↔ DAE/glTF conversion via **LSLib** (ExportTool already in the workspace), so a semi-automated, batch refit is realistic. The actual mesh morph step needs Blender on a Windows machine; my sandbox can drive LSLib conversions and scripting but not the Blender morph.

## 7. Resources I need from you

1. **SBBF** — the body mod itself, and its **Vanilla Outfits Patch** (the refit meshes — our likely mesh source / reference for BT1-female outfit coverage).
2. **BCB** — the body mod and its converted-outfits package.
3. **One modded outfit** to serve as the permission-marker test case (an OBSC set already in the workspace can stand in; I'll add a test marker).
4. **Blender confirmation** — version installed, and whether Lazy Tailor / the Collada (GR2) exporter are set up, since the morph step runs there.

## 8. Recommended immediate next steps

1. **Run the §4 SE feasibility spike** — this gates the whole architecture; do it before writing a build spec.
2. **Obtain SBBF + BCB packages** so I can inventory their BT1-female outfit mesh coverage and folder/override structure.
3. Once both are in hand, I'll write the full build spec (refit library layout, SE selector logic, marker schema, body-detection, load order, compatibility with your CompatibleBodiesTooltip work).

## 9. Follow-up research (2026-06-20): body selection & sidecar generation

**Q1 — runtime body selection across multiple installed body mods.** Possible *only after repackaging*. SBBF and BCB both install as loose-file **replacers of the same vanilla body resource** (`...\_Models\Humans\_Female\Resources`, the `HUM_F_NKD_Body` path), so two replacers collide and load order collapses them to a single body at runtime — SE has nothing to choose between ([Body Models](https://bg3.wiki/wiki/Modding:Body_Models), [load order](https://wiki.bg3.community/en/Tutorials/Mod-Use/general-load-order)). To enable selection, repackage vanilla/SBBF/BCB as **uniquely-GUID'd, non-overriding** resources; SE then assigns the chosen body **per character** via `Osi.AddCustomVisualOverride(character_uuid, visual_uuid)` (asset must match race/gender) ([Changing Character Visuals](https://wiki.bg3.community/Tutorials/Visual/Changing-CharacterVisuals)). Per-character unique bodies are a proven pattern (e.g. Unique Tav). Implication: repackaging the bodies touches the body authors' assets — same permission/redistribution concern as clothing applies to the **bodies** too, unless the sidecar builds them locally from the user's own installed copy.

**Q2 — sidecar-generated refits for flagged modded items.** Feasible as a user-machine preprocess (same pattern as the existing tooltip sidecar): scan mods for the marker → extract GR2 (LSLib) → **morph via Blender-headless driving Lazy Tailor** (pure-Python, GPL-3.0 addon; weight-transfer + rigged shape morph; needs Blender 4.2/4.3 + LSLib + dos2de collada exporter — [repo](https://github.com/V0ln0/BG3_Lazy_Tailor)) → export GR2 → assemble selectable resource set → pack into `Mods`. Assets then load normally at runtime (no per-frame cost). Caveats: (a) batch morph quality is "bulk done, some manual cleanup" — the tool author states there is no one-size-fits-all; (b) Blender + LSLib dependency is heavier than the tooltip sidecar; (c) local generation from the user's own mods is the cleanest consent model (no asset redistribution). Does **not** remove the §4 SE equipped-item visual-swap spike — that still gates *how* the meshes get applied.

## 10. Body-package analysis (2026-06-21)

Unpacked and inspected the downloaded packages (BCB paks read with a pure-Python LSPK v18 parser, since `divine.exe` is Windows-only and unavailable in the analysis sandbox). **Headline: SBBF and BCB use opposite distribution models, which changes how each must be made "selectable."**

### SBBF — loose-file *replacer* (overwrites vanilla)
- **Body** (`Stylized Beautiful Body for Female (L)`): 7 nude-body GR2s, dropped into **vanilla paths** (`...Public/Shared|SharedDev/Assets/Characters/_Models/{Humans,Tieflings,Githyanki,Dragonborn,HalfOrcs}/_Female` and `_FemaleStrong`). **No `meta.lsx`, no RootTemplate/visual edits** — pure file overwrite. Covers regular **and** strong female.
- **Vanilla Outfits Patch (VOP)**: **827 refit outfit GR2s**, also loose at vanilla paths, named after the vanilla meshes (`HUM_F_ARM_Barbarian`, `HUM_FS_ARM_Leather`, named NPCs Astarion/Jaheira/Karlach/Lae'zel, etc.). **186** are strong-body (`HUM_FS_`), the rest regular (`HUM_F_`). This is a near-complete, per-vanilla-outfit refit library for BT1 **and** BT3 — exactly the mesh source we want, but delivered as global overrides.
- **Consequence for us:** SBBF is *not* individually addressable — its meshes literally replace vanilla files, so two replacers can't coexist and SE can't select among them. To make SBBF selectable we must **re-namespace** these GR2s into a unique mod folder and author CharacterVisual/RootTemplate entries keyed to an SBBF body.

### BCB — self-contained `.pak` *add-on* (already namespaced)
- `BCBPak.pak`: LSPK v18, **706 files**; author **Sindae**, UUID **`1d24059d-ff23-4a79-8892-57c85d512416`**, Type `Add-on`. **698 GR2s all under its own namespace** `Generated/Public/BCBPak/Assets/Characters/_Models/...` (Humans female 480, Githyanki 24, Tieflings 18) — **does not overwrite vanilla mesh files**.
- Ships its **own** `[PAK]_CharacterVisuals/_merged.lsf` (117 KB), `RootTemplates/_merged.lsf` (758 KB), and Stats `Armor.txt` = **312 new `_KEL` clothing entries** (e.g. `CLT_Rich_Body_*_KEL`, `ARM_Myrkul_KEL`) plus a TreasureTable. So BCB is a body **plus its own bespoke clothing line**, and appears to apply to vanilla NPCs by **overriding character-visual/template GUIDs** (not by file-path replacement). **Regular female only — no strong-body meshes.**
- **Consequence for us:** BCB is already ~90% of the "selectable, non-override, unique-GUID" pattern we said runtime selection needs — its meshes are addressable and coexist with vanilla. The work is to **suppress its global character-visual override** and instead point chosen characters at its (already namespaced) meshes via SE.

### Other packages (noted, not yet deep-analyzed)
MixArmour (`.pak`), "More Curvy Body & Armor"/YarzArmor (mod 12129, `.pak` + a loose `Conversion` data set), SBBF Basket/SCO (loose), `Patch_SBBF`/`Patch_BCB` (Utam bodysuit patches), `BCB Scantily Clad Camp Outfits` (`.pak`), and **`BCB Unique Tav Data`** — the last installs to a separate `unique_tav/BODY/...` namespace, another concrete example of the addressable/selectable pattern.

### What this means for the architecture
- The sidecar must handle **two input shapes**: re-namespace SBBF's replacer meshes; consume BCB's already-namespaced add-on directly.
- **Scope match:** SBBF covers BT1 **and** BT3; BCB is **BT1 only**. The agreed v1 (BT1 female, all slots) is fully covered by both.

### Next analysis step
Decode the BCB `CharacterVisuals` / `RootTemplates` **LSF → LSX** to read exact resource GUIDs and confirm whether/which vanilla character templates BCB overrides (needs `divine.exe` on Windows, or a Python LSF reader). That tells us precisely what an SE selector must suppress/redirect.

## 11. BCB LSF decode — correction & sharpened finding (2026-06-21)

Decoded BCB's `RootTemplates`, `CharacterVisuals`, and `Female_Clothing` banks (LSF→LSX via Divine.exe). This **corrects** the §10 guess that BCB "appears to override vanilla character-visual/template GUIDs":

- **BCB is purely additive — it does NOT override vanilla GameObjects.** 291 new clothing items, each with a **new unique UUID**, that merely **inherit** from 6 vanilla bases via `ParentTemplateId` (vanilla UUIDs appear only in the inherit-from slot, never as a MapKey). So BCB does **not** auto-replace vanilla outfits on NPCs.
- **Clothing uses the native chain:** item `VisualTemplate` → `Equipment.Visuals[EquipmentRace GUID] → VisualResource GUID → GR2`. BCB's 625 own GR2s live in its private `VisualBank` (782 VisualResource nodes). 
- **Dominant EquipmentRace = `71180b76-5752-4a97-b71f-911a69197f58` = Human Female (BT1)** (287/291 items), exactly the v1 scope. A second GUID `06aaae02-…` (14×) + a small tail cover other races.
- **Only global surface:** a small `CharacterVisualBank` re-skinning ~**18 named vanilla NPCs** via material/colour presets only — **no meshes**. Nothing force-applies BCB clothing meshes to existing NPCs.
- **Decoded files saved:** `I:\BG3_ClothMorph_Work\BCB_decoded\` (RootTemplates / CharacterVisuals / Female_Clothing / meta `.lsx`).

**Architecture implication (significant):** BCB is living proof that clothing meshes are selected through the **EquipmentRace → Visuals map** — i.e. the spike's **Approach B** is the engine's own mechanism, not a hack. This raises confidence that a selector keyed on EquipmentRace / the `Visuals` map (per character, per chosen body) is viable, and that BCB won't fight us (it doesn't override vanilla outfits). Net plan crystallizing: (1) make BCB's already-namespaced body+clothing **per-character selectable** instead of opt-in-by-equipping; (2) re-package SBBF's vanilla-outfit refits into addressable VisualResources keyed to a chosen-body EquipmentRace; (3) the SE selector flips the active body/EquipmentRace (or the resolved Visuals entry) per character. The §4 spike still confirms *which* field is runtime-mutable, but Approach B is now the front-runner.

**Toolchain note:** Divine.exe quirks found — multi-glob `-x` extraction matches nothing (extract one extension at a time); bracketed `[PAK]_` folder names break `convert-resource` (copy to a bracket-free name first). Recorded for the sidecar.

## 12. Toolchain verified end-to-end (2026-06-21)

Blender ↔ Divine GR2 round-trip **PASSES** on Alan's machine. Blender **4.2.21 LTS** + addon `bl_ext.user_default.io_scene_dos2de` **v3.1.0** (Norbyte), `lslib_path` → the verified Divine.exe, `gr2_default_enabled=True`, game preset `bg3`. Test: imported a real BG3 clothing GR2 (1087 verts) and exported back to a valid GR2 (re-converts to DAE cleanly).

**Exact operator usage for the sidecar (non-obvious — save these):**
- **Import:** `bpy.ops.import_scene.dos2de_collada(filepath=..., directory=..., files=[{"name": "<file>.gr2"}])`. `filepath` **alone silently imports nothing** — `directory` + `files` are required. GR2→DAE is auto-triggered by the `.gr2` extension (no flag). **Wrap in `try/except RuntimeError`:** BG3 clothing references the full body skeleton, so the importer raises a `RuntimeError` of ~55 `"Couldnt load metadata on bone '…'"` lines *after* the mesh is fully imported — non-fatal; treat as success if every error line contains `"metadata on bone"`.
- **Export:** `bpy.ops.export_scene.dos2de_collada(filepath="<...>.gr2", use_export_selected=True, ...)`. The `.gr2` extension triggers Divine DAE→GR2; **select both the mesh and its armature** first (skinned meshes need the skeleton). Benign `"unassigned weights"` warning is expected.

So the full pipeline (extract GR2 → import to Blender → Lazy Tailor morph → export GR2 → pack) is proven viable headless; only the morph step is still to be scripted. See `SE Spike Test Mod - Scope.md` for the SE spike fixture.

## 13. Dual-state selection — nude body AND clothed fit (2026-06-21, per Alan)

Clarified scope: full "selectable body type per character" has **two visible states**, each needing its own swap, and the mod must cover **both**:

- **Unclothed** → the **naked body mesh** (`*_NKD_Body_*.GR2`) is shown. Selecting body type = assign the chosen NKD mesh to that character. This is the *body* proper; it's what SBBF/BCB replace. Mechanism: per-character body-visual override (DAF-style `Osi.AddCustomVisualOverride` on the character body visual) — the **simpler, more proven** case.
- **Clothed** → the **garment mesh** (which bakes in the body shape) is shown and hides the naked body. Selecting body type = show the garment refitted to the chosen body. Mechanism: the equipped-item mesh swap — the **harder** case the §4 spike targets.

Both belong to the same per-character visual-resource-assignment family, so one selector handles both, keyed on (chosen body × equip state). The spike is extended to bundle an **SBBF NKD body mesh** as a third resource so we validate the nude swap alongside the armor swap. Net: the product is body-type selection for nude *and* clothed; the build/sidecar must produce both NKD bodies and fitted garments per body.

## 14. Corrected runtime-swap method (research 2026-06-22)

The live spike used `Osi.AddCustomVisualOverride`, which turned out to be the **wrong tool**: it is **additive** — it *adds* a visual on top of the character's existing one, it does not *replace* the base body — so handing it our SBBF body mesh just layered a second body that z-fights / hides, producing no clean change (confirmed across placeholder- and real-material builds). Meshes *are* an accepted type for it; the problem is the additive semantics. ([Dynamic Appearance Framework](https://www.nexusmods.com/baldursgate3/mods/2276), [Changing Character Visuals](https://wiki.bg3.community/Tutorials/Visual/Changing-CharacterVisuals))

What the research established:

- **Runtime equipment-visual swapping is a SOLVED problem** — BG3 transmog mods (Transmog Enhanced, Armory – Auto-Transmog) change the appearance of an equipped item at runtime while keeping its stats, via Script Extender. So the core feature is feasible. Their historical bugs (armor-type/proficiency drift, save-reload needed to keep stats) came from swapping the item's **template/stats**; our design must change **only the visual**. ([Transmog Enhanced](https://www.nexusmods.com/baldursgate3/mods/2922), [Armory](https://www.nexusmods.com/baldursgate3/mods/14717))
- **The clean, engine-native mechanism is the CharacterVisuals "Slots" system:** a character's appearance is a set of `Slot → VisualResource UUID` entries (Body, Head, Hair, Horns, Private Parts, armour…), explicitly designed "to switch the objects instead" of replacing them. So a **body swap = switch the character's body-slot VisualResource** to the chosen body — the clean replace the additive override couldn't do. ([Changing Character Visuals](https://wiki.bg3.community/Tutorials/Visual/Changing-CharacterVisuals))
- **Runtime API shape:** `Ext.Entity.Get(uuid)` → read/modify the entity's component → (replicate to client). Entities are component bundles SE can read and write. ([bg3se API.md](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md))

**Corrected spike test (replaces the one-liner):** a small SE **Lua script** shipped inside the test mod (BootstrapServer/Client + a registered console command/hotkey) that (a) switches the host character's **body-slot VisualResource** to our SBBF body resource, and (b) for clothing, swaps the **equipped item entity's visual** to our fitted VisualResource — each step logged. This tests the *right* mechanism and removes the manual long-command typing that the in-game console was rejecting.

**Remaining unknown:** the exact component/field name for the visual write at runtime — to be pinned from a transmog mod's Lua (or `bg3se/.../ExtIdeHelpers.lua`) during the build. Feasibility is no longer in question; only the precise field is.

## 15. BodySlide (Skyrim) comparison + bone-scaling as a partial runtime lever (2026-06-22)

### The Skyrim "body slider" paradigm has two layers
- **BodySlide / Outfit Studio — offline bake.** A reference body with named **sliders**; outfits are *conformed* to the reference so the same sliders morph them to match; **Build** bakes the chosen values into static meshes (`femalebody_0/1.nif` + per-outfit `.nif`). Build-time, fixed output. ([BodySlide & Outfit Studio](https://www.nexusmods.com/skyrimspecialedition/mods/201), [wiki](https://github.com/ousnius/BodySlide-and-Outfit-Studio/wiki))
- **RaceMenu "BodyMorph" / OBody — runtime morph.** OBody applies BodySlide presets *live*; it requires "RaceMenu morphs support" because SKSE/RaceMenu morphs the mesh **per-vertex at runtime**, and equipped armor (which carries the same morph data) morphs along with the body. ([OBody NG](https://www.nexusmods.com/skyrimspecialedition/mods/127862))

### How each maps to BG3
- **Offline bake = our sidecar (direct match).** "Reference + sliders + conform outfits + build static meshes" is exactly the Lazy-Tailor + sidecar pipeline. **Lazy Tailor + our sidecar is effectively "BodySlide for BG3."** Borrow its UX: a reference body with named sliders and per-outfit conform.
- **Live runtime slider = NOT portable.** BG3's engine has **no runtime per-vertex mesh morph** for bodies/armor, and BG3SE exposes nothing like SKSE/RaceMenu BodyMorph (same wall as the spike: BG3 can *select* a mesh, not *deform* one live). Confirmed by the community's standing, unmet request for a live "breast/body slider" — only **preset replacers** exist (e.g. Dulcet Bodies), never a live slider. ([Face/Body Sliders thread](https://steamcommunity.com/app/1086940/discussions/0/3471730015112385992/))
- **BG3-feasible middle ground:** sliders become **discrete pre-baked presets.** The sidecar bakes several shapes offline; the in-game choice **selects** among pre-baked bodies + pre-fitted outfits (the runtime-selection work in progress). A BG3 "Body Slider" UI is really a **preset picker** that triggers an offline bake for any new shape.

### Bone-scaling as a partial runtime lever (the one thing that might morph body + clothing live)
The appeal: in Skyrim, NiOverride **bone scaling** morphs body and armor together *without re-baking*, because the garment is skinned to the same bones — scaling a bone propagates through skinning to anything attached to it. If BG3 exposed per-bone runtime scale, you'd get body+clothing morphing together with **no per-outfit refit** — a fundamentally different, refit-free path.

Findings:
- **Uniform scale exists at runtime in BG3** — whole-body height/size (the IDE helper's `GameObjectVisualComponent.Scale`; height/resize mods use this). Real but limited to overall size, not shape.
- **Per-bone runtime scale is unproven in BG3.** No known mod does per-part body sliders via bone scale; SE docs surface no demonstrated per-bone transform write that affects rendering. The skeleton's bones exist (animations scale them in Blender), but a live SE-driven per-bone scale that renders — and propagates to equipped armor — has not been shown.
- **Even if possible, it's crude:** bone scaling only thickens/lengthens along bones; it cannot reproduce SBBF/BCB's *sculpted* shapes. So it would, at best, add simple live adjustments (e.g. overall bust/hip scale) — it does **not** replace the sidecar for real SBBF/BCB shapes.

**Verdict / next experiment:** worth a cheap probe. When the `cmdump` character dump lands, inspect it for a **skeleton / bone-transform component**; if one is writable, test whether setting a bone's scale (a) renders live and (b) propagates to equipped armor. If yes, it's a useful *refit-free* lever for simple shape tweaks and a possible live-"slider" feel; if no (likely), the offline-bake sidecar remains the only path to true SBBF/BCB shapes. Either way it does not change the core architecture — it's a potential bonus runtime feature, not a replacement.

## 16. Crimson Desert "Body Slider Outfitter" — a direct analog + a Blender-free technique (2026-06-22)

The mod Alan flagged: **Body Slider Outfitter** by zyd232 ([Crimson Desert mod 2993](https://www.nexusmods.com/crimsondesert/mods/2993)), which feeds the in-game **Body Slider Pro** ([mod 2727](https://www.nexusmods.com/crimsondesert/mods/2727)). It's almost exactly our architecture, validated by a shipping product:

- **Two-part split, same as ours:** (1) **Body Slider Pro** = the in-game body slider; (2) **Body Slider Outfitter** = an **offline batch tool** that pre-fits every outfit to every slider's target body. "If you have X outfits and Y sliders, X×Y target models will be generated" — i.e. it **pre-bakes** a mesh per (outfit × target shape). That is our **sidecar**, confirmed.
- **The transferable technique — scattered-data deformation, no Blender needed.** Its fit math is described explicitly: **Original Body → Target Body** defines a displacement, and an **"Outfit Mapping = mathematical deformation that fits outfits from Original Body to each Target Body,"** using **Rigid MLS (Moving Least Squares)** by default and **IDW (Inverse Distance Weighting)** as a fallback. These are general, well-documented point-based deformation algorithms (e.g. Schaefer et al., "Image Deformation Using Moving Least Squares"), implementable in a **pure-Python sidecar (numpy/scipy)** — no rigged armature, no Blender.
  - **How it'd work for us:** take the vanilla body verts and the SBBF/BCB body verts as a corresponding control-point set, build the MLS/IDW deformation field, and apply it to each vanilla outfit's verts → an SBBF/BCB-fitted outfit. Export GR2.
  - **Why this matters:** it's a potential **alternative to (or replacement for) the Blender + Lazy Tailor morph step**, removing the heaviest dependency (Blender 4.2 + Collada exporter). Worth prototyping against a Lazy-Tailor refit to compare quality.
  - **Correspondence caveat:** MLS/IDW need source↔target point correspondence. Trivial if SBBF/BCB preserve vanilla body topology (slider-style edits do); if they re-mesh, use landmark/closest-point correspondence. **Action:** verify SBBF/BCB body vertex topology vs vanilla.
- **Shared hard problem:** the mod notes the game "uses a 'shrink' mechanism to hide body parts under clothes" (BG3 hides the body under armor too) and lists a **"Penetration Fix Algorithm"** as still-to-do — i.e. clipping is the known hard part there as well; our sidecar will face the same.
- **Runtime slider still does NOT port (same conclusion as §15).** Body Slider Pro's *live* slider works because **Crimson Desert runs on its own proprietary engine**, whose runtime supports live mesh morphing / morph-target (blendshape) blending. That is an **engine capability, not a portable technique** — BG3 (Larian's Divinity 4.0 engine) has no equivalent, so BG3 can't blend/morph a body live; it can only **select among discrete pre-baked shapes**. So BG3's "slider" remains a **preset picker** over sidecar-baked shapes. The portability split is clean: the **offline deformation math is engine-agnostic and ports; the live slider is engine-locked and does not.**
- **IP note:** the mod's license is restrictive (no cross-game conversion, no asset reuse without permission). We would implement the **general public algorithm** (MLS/IDW), not their tool, code, or assets — so the technique is usable without touching their license. Do not reuse their files.

**Net:** strongest validation yet that the offline-bake sidecar is the right core, plus a concrete, Blender-free deformation method (MLS/IDW over the vanilla→SBBF/BCB displacement) to evaluate for the morph step.

## 17. MLS/IDW deformation prototype — built & validated (2026-06-22)

Implemented the Crimson-Desert-style scattered-data outfit deformation in **pure Python (numpy + scipy), no Blender / armature** — `MLS_IDW_Prototype/deform_prototype.py`. Two algorithms:
- **IDW** — inverse-distance-weighted displacement interpolation (simple, fast).
- **MLS** — affine Moving Least Squares (per-vertex weighted affine fit; handles local rotation+scale).
Both take the source-body→target-body vertex correspondence as control points and deform the outfit to conform.

**Synthetic validation** (vanilla-ish torso → curvier "SBBF-like" target; a tight top that clips the curvier body):
- **Original top on target:** 484/616 verts clipping, worst −0.182 (deep clip).
- **MLS-deformed:** **0/616 clipping**, mean gap +0.016 (sits just outside the body).
- **IDW-deformed:** **0/616 clipping**, mean gap +0.012.
Render (`MLS_IDW_Prototype/synthetic_compare.png`) shows the top reshaping to hug the curvier body for both. **Both algorithms eliminate clipping**; MLS gives a slightly smoother/looser fit, IDW a slightly tighter one.

**Takeaway:** the MLS/IDW approach is **viable and Blender-free** — a real alternative to the Lazy-Tailor/Blender morph step, and a candidate to be the sidecar's core deformation engine. MLS is the better default (smoother, handles rotation+scale); IDW is the cheap fallback (matches the CD tool's two-algorithm offering).

**Real-mesh test (task #20, 2026-06-22) — DONE, with honest caveats.** Converted three real meshes GR2→glb via Divine (vanilla `HUM_F_NKD_Body_A` 9,359 v from Models.pak; vanilla `HUM_F_ARM_Leather_A_Body` 4,997 v; SBBF body 9,382 v) and ran the deformation. Findings:
- **SBBF does NOT preserve vanilla topology** (9,382 vs 9,359 verts, no LOD1) → no 1:1 vertex match; used **spatial nearest-point correspondence**. (Also: vanilla GR2s are Granny-compressed and need `granny2.dll` on the DLL path to convert — sidecar note.)
- Clipping of the Leather into the SBBF body (approx nearest-vertex metric): **ORIGINAL 75/4997 → MLS 54 → IDW 40.** Both **reduce** clipping; **neither eliminates** it. Mean outfit movement was small (~0.3–0.5% of body size).
- **Why modest:** (a) Leather is a bulky/loose piece, so SBBF's shape delta in the covered region is small (a mild test case); (b) crude **nearest-point correspondence under-deforms** — it captures only small local displacements.
- **The real quality lever = body↔body correspondence.** The prototype's weakest link is the nearest-point matching; a proper **non-rigid registration** (ICP / deformation transfer of vanilla→SBBF) would yield a clean displacement field — and that registration is essentially what Lazy Tailor's rig provides for free. A **penetration-fix pass** is still needed for residual clipping (the same open problem zyd232 listed).

**Verdict:** MLS/IDW is a viable, Blender-free deformation engine and works end-to-end on real BG3 meshes, but to match Lazy-Tailor quality it needs (1) a good non-rigid body-to-body correspondence step (not nearest-point) and (2) a penetration-fix pass. **Next refinements:** improve correspondence (non-rigid registration), and stress-test with a skin-tight garment (where SBBF's curves — and any clipping — are far more pronounced than on Leather). Deformed outputs saved as `realdata/vanilla_leather_MLS.glb` / `_IDW.glb`.

## 18. Runtime-swap spike — in-game results (2026-06-23)

Built an SE Lua diagnostic (`!cmdump`) in the test mod and dumped live components on the host character + equipped chest item. Results:

- **Confirmed the exact field:** an equipped chest item's mesh is driven by the CHARACTER's client component **`ClientVisualsDesiredState.Slots["Breast"].VisualTemplates`** — a `FixedString[]` of visual-resource GUIDs (the chest had 3).
- **Our custom mesh GUID is ACCEPTED** there: setting the slot to our Resource S (`3da6db5b…`) stuck (read it back successfully). So a custom visual-resource GUID is a valid value in the live field.
- **Client write does NOT render, and is not authoritative.** The value persisted but the chest didn't change; `entity:Replicate(...)` on the client failed: *"Changes can only be replicated from server to client."* → the swap is **server-authoritative**.
- **SE API research (API.md + ExtIdeHelpers.lua):** documented primitives are `entity:CreateComponent(type)`, `entity:Replicate(type)` ("marks a component as changed so replication can propagate"), `SetReplicationFlags`. The one-frame visual request's ExtComponentType is **`"VisualChangeRequest"`** (class `VisualChangeRequestOneFrameComponent`, field `VisualTemplate`); our earlier attempt failed because it used the class name and `=` instead of `CreateComponent("VisualChangeRequest")`. The engine has a `"ReloadingVisuals"` client-character flag (a reload pass exists). **Not documented anywhere public:** a callable equipment-visual reload/refresh, and the *server* equipment-visual component name (the public type files omit component bodies; would need an in-game `Ext.Types` dump).

**Spike verdict:** feasibility and the precise mechanism are **proven**; the only missing piece is the **render trigger** for equipment visuals, which is an undocumented R&D item. Two open experiments: (a) client — set `VisualTemplates` then `CreateComponent("VisualChangeRequest")` and check if it re-renders; (b) server — dump server components in-game (`Ext.Types` / `!cmdump` server) to find the server equipment-visual component, set it + `Replicate`.

**Strategic note:** the **static-override pack** (sidecar-generated refit meshes, body chosen at install — exactly how SBBF/BCB ship) needs NONE of this render-trigger work and is the proven MVP path. Per-character *runtime* selection remains a v2 stretch goal contingent on cracking the trigger.

## 19. Runtime trigger CRACKED — read Transmog Enhanced's actual Lua (2026-06-23)

Extracted and read the Lua of the user's installed **Transmog Enhanced Revamped** (the proven runtime armor-appearance mod). The mechanism is **not** what we were attempting, and it explains why our field-write never rendered:

- It does **NOT** poke `ClientVisualsDesiredState` / any visual field, and there is **no** "refresh/reload" call anywhere. BG3 has no "set the mesh field then re-render" path.
- Instead it **swaps the equipped ITEM**: `Osi.TemplateAddTo(appearanceTemplate, …)` spawns a copy of the *appearance* item (whose RootTemplate carries the desired visual); the `Clone()` fn then **grafts the original item's gameplay components** onto that copy — a `Constants.Replications` component list + Armor/Weapon/Equipable/Tag/Boosts — via `NewItem:CreateComponent(type)` then `NewItem:Replicate(type)` per component; then it **equips the copy** (`Osi.Equip`) and stashes the original in a hidden container. **Visual comes from the copy's template; stats come from the cloned components.**
- It renders because it's a genuinely equipped item. **BG3 renders worn equipment from the equipped item's RootTemplate visual — period.** `entity:Replicate(comp)` (server→client) pushes the grafted gameplay components to the client.

**This resolves the spike.** There is no client-side "write the visual + trigger reload." Runtime armor-appearance change in BG3 = **equip an item whose template has the desired visual, graft stats onto it.** Consequences for our architecture:
- The field-poke mental model (writing `VisualTemplates`) was wrong — confirmed, definitively.
- **Per-character runtime** body selection of clothing is achievable the transmog way (equip a body-fitted-visual variant + graft stats) but is **heavy** — it needs body-fitted item/template variants and a stats-graft system per piece.
- The **engine-native, simplest** route for "make this character's clothes fit the chosen body" stays the **item-template / `Equipment.Visuals[EquipmentRace]` + (loose) override** path (BCB-proven), selected at install = the **static MVP**, needing no runtime trigger.
- The **nude body** is a *separate* mechanism (`CharacterCreationAppearance` / `AppearanceOverride` + `Replicate`) and may still be field-settable — to test on its own.

(Transmog Lua was read for API-mechanism learning only — no assets or code reused.)

## 20. Per-character NUDE-body mechanism CRACKED — read RemodelledFrameBody's Lua (2026-06-23)

Read RemodelledFrameBody (a per-character body-mesh mod). Per-character body visual is applied **server-side** via:
```lua
Osi.AddCustomVisualOverride(char, ccsvId)   -- remove: Osi.RemoveCustomVisualOverride(char, ccsvId)
```
where **`ccsvId` is a `CharacterCreationSharedVisual` (CCSV) resource ID — NOT a raw VisualBank `VisualResource`.** This is exactly why our earlier `AddCustomVisualOverride` with Resource N did nothing: Resource N was a raw mesh resource (wrong type). Details:
- The CCSV is chosen per character's shape from a map keyed `<race>_<bodytype><bodyshape>` (HUM_F, HUM_FS, GTY_F, TIF_F, TIF_FS…), read off `entity.CharacterCreationStats` (`Race`, `BodyType`, `BodyShape`).
- Avoid double-apply by checking the char's CC appearance for the id (their helper `FindCharacterCreationVisual`); **re-apply on `SavegameLoaded` / status changes to persist.**

**Recipe for us:** wrap each specialized body (SBBF/BCB) mesh as a `CharacterCreationSharedVisual` (per race/variant); apply per character with `Osi.AddCustomVisualOverride`; persist by re-applying on load from our saved per-character choices.

### Both halves of per-character runtime now have PROVEN mechanisms
- **Nude body:** CCSV + `Osi.AddCustomVisualOverride(char, ccsvId)` — RemodelledFrameBody-proven.
- **Clothed armor:** transmog-style item swap + component graft (`CreateComponent`+`Replicate`) — Transmog-Enhanced-proven (§19).

So the per-character runtime system is **architecturally de-risked** — both halves use techniques that ship in working mods. Division of labor: **sidecar** generates assets (body-fitted meshes + CCSV wrappers + transmog variant templates); **SE runtime** applies per-character choices + persists; **BG3MCM** = the in-game selection UI. (RemodelledFrameBody Lua read for API-mechanism learning only — no assets/code reused.)

## Sources

- bg3.wiki — [Weight Painting Armor](https://wiki.bg3.community/Tutorials/Visual/Weight-Painting-Armor), [Body Models](https://bg3.wiki/wiki/Modding:Body_Models), [Outfit Builder refit](https://bg3.wiki/wiki/Modding:Use_Outfit_Builder_To_Refit_Outfits), [Changing Character Visuals](https://wiki.bg3.community/Tutorials/Visual/Changing-CharacterVisuals)
- Nexus — [SBBF](https://www.nexusmods.com/baldursgate3/mods/4864), [SBBF Vanilla Outfits Patch](https://www.nexusmods.com/baldursgate3/mods/5040), [Mix Armour / BCB ref](https://www.nexusmods.com/baldursgate3/mods/8556), [Lazy Tailor](https://www.nexusmods.com/baldursgate3/mods/15414), [SBBF blend template](https://www.nexusmods.com/baldursgate3/mods/11586), [Dynamic Appearance Framework](https://www.nexusmods.com/baldursgate3/mods/2276)
- GitHub — [bg3se](https://github.com/Norbyte/bg3se), [BG3 Lazy Tailor](https://github.com/V0ln0/BG3_Lazy_Tailor)
- Internal — `bg3-equipment-race-system` skill (EquipmentRace GUID map, BodyShape/BodyType encoding, Visuals mesh map)
