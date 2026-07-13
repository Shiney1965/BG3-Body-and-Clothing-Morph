# ClothMorph — Cloth-Sim Explosion: Hard Review & Root Cause (2026-07-10, evening session)

**TL/DR:** The cloth-sim explosions (v3 and v3.2) were never caused by the deformation, by "pinned seams," or by "the sim being enabled at all." The root cause — **proven offline this session** — is that Divine/lslib's GLB→GR2 import **permutes vertex order** inside every rebuilt GR2 (same vertex set, different order: 0/16,027 body verts and 1/700 cloth verts at their vanilla index). The vanilla `ClothProxyMapping.ClosestVertices` buffers are **index-based against vanilla GR2 vertex order**, so restoring them over any rebuilt GR2 scrambles the cloth↔render correspondence → spiky-shred explosion. The "sim-restore approach is DEAD" verdict is **retracted**: a validated fix path exists (vanilla-order GR2 container + positions-only binary patch), and its two enabling properties were verified offline today.

---

## 1. What was verified this session (all offline, reproducible)

All tests on `HUM_F_ARM_Platemail_B_Body` (= Armour of Persistence mesh). Artifacts in `ClothMorph_Build\_review_tmp\`. GLB parsing scripts run in the sandbox against workspace files; Divine runs via Desktop Commander (`C:\bg3-sidecar-work\Tools\Divine.exe`).

| # | Test | Result |
|---|------|--------|
| V1 | Deform pipeline output (`_mesh_refit_glb`) vs vanilla GLB (`_mesh_glb`), stride-aware byte compare | **POSITION only differs**; NORMAL, TANGENT, COLOR_0, WEIGHTS_0, JOINTS_0, TEXCOORD_0, index buffers **byte-identical**. GLB chain is clean. |
| V2 | Clothfix GLB (`_clothfix_glb`) cloth submesh vs vanilla | Cloth submesh byte-identical to vanilla on **all** attributes (the v3.2 revert itself was correct). |
| V3 | `EXT_lslib_profile` extras (Cloth / ClothPhysics / ExportOrder flags) across vanilla, refit, clothfix GLBs, and a GLB re-export of our rebuilt GR2 | All flags **survive** the full roundtrip (ClothPhysics=True on `*_Cloth_Mesh`). Flag loss is NOT the problem. |
| V4 | **GLB→GR2→GLB roundtrip vertex order** (`rebuilt_roundtrip.glb` vs source `_clothfix_glb`) | **PERMUTED.** Body_Mesh 0/16,027 verts at same index (same-index position delta up to 1.19 m); Cloth_Mesh 1/700. Vertex *sets* identical (exact permutation). Disabling `compact-tris`/`deduplicate-vertices` via `-e` changes nothing — the reorder is inherent to lslib's GLTF importer (first-use canonical order). |
| V5 | Second roundtrip (GR2→GLB→GR2→GLB) | **Byte-stable fixpoint** ⇒ GLTF *import* permutes to a canonical order; **GR2→GLB export preserves GR2 internal order**. A GLB export of any shipped GR2 reveals its true internal vertex order. |
| V6 | **Divine GR2→GR2 rewrite of the vanilla GR2** (839,288 B compressed → 1,568,744 B uncompressed) | **Preserves vanilla vertex order exactly** (GLB export byte-equal to vanilla GLB export on every attribute of every mesh) and the output is uncompressed/strings-scannable ⇒ binary-patchable. |
| V7 | `ClosestVertices` ScratchBuffer decoded (vanilla `Content__Female_Armor.lsx`, Platemail node) | zlib+base64 → **int16 array of cloth-proxy vertex indices** (max 618 < 700 proxy verts; −1 sentinels; `Nb` always divisible by 3 ⇒ triplets of closest proxy verts per cloth-influenced render vertex). Index-based ⇒ order-sensitive. Red vertex-color channel (0/255 paint) is the cloth-influence mask, but the exact enumeration predicate didn't match red>0 counts exactly (2,876 triplets vs 2,735 red-painted skirt verts) — engine-side enumeration still to be confirmed from bg3se source. |
| V8 | Vanilla Platemail VB node structure | ClothProxyMapping maps the proxy to **both** `Skirt_Sleeves_Mesh` (8,628 entries) **and** `Body_Mesh` (10,425 entries) — the plate body itself is partially cloth-driven. Plus two `ClothParams` nodes (LOD0+LOD1 proxies) keyed by `<GR2>.<Cloth_Mesh>.<exportIdx>`. |
| V9 | LSX census across builds | `refit_full.lsx`/`_lodfix`: 0 ClothParams, 0 mappings (cloth fully inert pre-v3). `_v3`: 573 ClothParams + 442 MapKeys. `_v3_1`: **573 ClothParams kept, 0 MapKeys** — the "sim-off" build left all sim parameters in place. `_v32`: 573 ClothParams + 360 MapKeys. |

## 2. Corrected failure chain

- **pre-v3** (original generator `_gen_visualbanks.py`): emitted `<node id="ClothProxyMapping" />` empty, no ClothParams → cloth truly inert → skirts rigid-but-intact, no explosion, no swirl (many AoP screenshot rounds, none reported a swirl).
- **v3** (wholesale vanilla-node clone): vanilla ClothParams + vanilla mappings restored **over permuted-order rebuilt GR2s** → index-space scramble → explosion. The deformation was blamed, but the permutation alone is sufficient.
- **v3.1** (strip mappings, **keep ClothParams**): no explosion, but the retained ClothParams most plausibly left the sim *active and unanchored* → the "swirl"/"translucent sheet" (motion artifacts). The prior diagnosis — "authored curled rest pose renders because sim is off" — verified only that the rest pose is curled, not that the render was static, and cannot explain why pre-v3 (equally "sim-off") never showed the swirl. The ClothParams retention is the one variable that changed.
- **v3.2** (revert cloth positions to vanilla + restore mappings): cloth *values* correctly reverted (V2), but the Divine rebuild re-permuted vertex *order* (V4) → mappings still scrambled → explosion again. The conclusion drawn ("enabling the sim at all explodes; approach dead") was a confounded read: the experiment never isolated the container from the sim.

## 3. Critique of the prior assessments

1. **The core correctness property was never tested.** Every deep-verify counted strings (maskSlots=2173, mapKeys, LOD1 presence) or compared hashes of our own rebuilds against each other. Nothing ever checked that the shipped GR2's vertex order matched the vanilla order that all restored index-based buffers assume. The v3.2 "provenance gate" (file-size match between two Divine rebuilds) is verification theater with respect to this property.
2. **The "pinned-seam / rest-state mismatch" hypothesis was weak on its own evidence and untested.** v3 deformed cloth and rigid *consistently* and still exploded — under the seam hypothesis a consistent deform should have been the *most* stable configuration. This anomaly was never confronted.
3. **The v3.1 partial strip introduced the swirl regression that motivated the entire v3.2 detour.** Stripping the mapping while keeping 573 ClothParams nodes created a state that exists nowhere in vanilla data. The correct "sim-off" control was pre-v3 (neither params nor mapping).
4. **"Sim-restore approach is DEAD" was a category error** — it declared an architecture dead based on a data-pipeline artifact. The corrected statement: *vanilla index-based cloth data is incompatible with Divine-GLB-rebuilt GR2 containers.* The architecture is fine; the container is the bug.
5. **Also noted, secondary:** the deform pipeline (`deform_clothing_scene`) deforms `*_Cloth_Mesh` panels with the body-displacement field plus a clipping-fix push-out — inappropriate for free-hanging panels and a plausible independent contributor to v3's bad cloth rest states; and "Simple Robe drapes fine in v3.2" was left unexplained (see open items).

## 4. The fix — validated path to generalizable morphed armor WITH working cloth

**Path B (recommended, both enabling properties proven in V5/V6): vanilla-order container + positions-only binary patch.**

1. For each garment: `Divine convert-model vanillaGR2 → GR2` (uncompressed rewrite, vanilla vertex order preserved — V6).
2. Binary-patch **only the position floats of rigid submeshes** in that file with the deformed positions from the existing `_mesh_refit_glb` GLBs (same vertex count and order as the vanilla GLB export — V1; interleaved vertex stride located by matching the known vanilla position sequence). Leave `*_Cloth_Mesh` positions vanilla (v3.2 semantics, done right).
3. Ship with the full vanilla-clone VB node (v3's clone incl. ClothParams + mappings — that part of v3 was correct).
4. **Offline gate before deploy:** export each patched GR2 → GLB and verify byte-equality with vanilla on every attribute except rigid-submesh POSITION, and vertex order identity. This is the invariant the old pipeline never checked.
5. Pilot on Platemail_B only (one-item pak), in-game A/B: expect morph-fitted plate + draping, non-exploding tabard.

- The 17 DAE-path items need a separate positions-source treatment; defer.
- **Path A (fallback if B's engine behavior surprises):** rebake `ClosestVertices` triplets in shipped-order space. Feasible — format decoded (V7), shipped order recoverable (V5) — but blocked on confirming the engine's render-vertex enumeration predicate from Norbyte's bg3se source (`ClothProxyMapping`/`NbClosestVertices` consumers).
- **Interim now (v3.1b, zero-risk, better than vanilla-passthrough):** strip **ClothParams too** (mapping already stripped) → reproduce pre-v3 rigid-but-intact skirts while keeping all v3 mask/LOD gains and full morph fit. This should remove the swirl without giving up fit. The previously-planned Option A (drop ~147 cloth items from `REFIT_BY_VR`, render vanilla) is strictly worse than v3.1b if the swirl theory is right, and is retained only as a fallback.

## 5. Open items / honest unknowns

1. **v3.1b swirl theory is high-confidence but unproven** — one content rebuild + retest decides it (and it's the right interim ship state regardless).
2. **Simple Robe drapes fine in v3.2** — unexplained. Identify its GR2 (wear it, run `!cm_visdump`), then check `_clothfix_apply_sbbf.txt`/`_clothfix_skip_sbbf.txt`. No "Simple" basename exists in the manifest; the display-name→mesh mapping was never established.
3. **Path B assumes the engine reads cloth influence masks/enumeration from data that survives the vanilla-order container untouched** — it does by construction (everything except rigid positions is byte-vanilla), so the residual risk is only whether *deformed rigid anchor positions* with valid indices sim stably. If pilot shows instability (not scramble-shreds but oscillation), that's the real "seam-stretch" signal, and the anchors can be relaxed by blending the deform to zero near cloth attachment verts (identifiable via the mapping's render-vertex sets).
4. B5 (3 unmatched VBs) unchanged.

## 6. Session artifacts

`_review_tmp\`: `rebuilt_roundtrip.glb`, `vanilla_recheck.glb`, `ordered.GR2`+`ordered_back.glb` (options test), `second.GR2`/`second_back.glb` (fixpoint), `shipped_stage_back.glb`, `van_rewrite.GR2`/`van_rewrite_back.glb` (order-preserving rewrite proof), `_rt_test*.ps1`. Live paks unchanged this session (content v3.1 `0875A44B…`, runtime v4.5 `5DAC4B45…`).
