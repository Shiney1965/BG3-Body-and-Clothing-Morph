# Upgrading to Body and Clothing Morph v1.3

## From v1.2.x

v1.3 uses a consolidated three-PAK layout. The separate `ClothMorphContent.pak` and `ClothMorphGithyanki.pak` are retired because their content is now inside `ClothMorphRuntime.pak`.

1. In BG3 Mod Manager, deactivate `ClothMorphContent` and `ClothMorphGithyanki`, then save the load order.
2. Remove `ClothMorphContent.pak` and `ClothMorphGithyanki.pak` from the Mods folder.
3. Replace the old `ClothMorphRuntime.pak` with the v1.3 Runtime from Main or AIO.
4. Replace `ClothMorphSCO.pak` if you use SCO.
5. `ClothMorphBCB.pak` is unchanged; replacing it is harmless but unnecessary when its SHA-256 is `9E315B49F54F29B278313E974198674ACC951E55A7BC0C81BB05B800B1E91062`.
6. Activate the v1.3 Runtime and any add-ons, keep ClothMorph above BCB, and save the load order.
7. Open MCM and choose **Match Vanilla** or **Hide on SBBF/BCB** under **SBBF/BCB body tattoos**.

Leaving the retired Content or Githyanki PAK installed can let older definitions override the consolidated Runtime. Deactivating before removal avoids a mod-manager load-order reset; ClothMorph itself adds no unique save-required items or characters.

The Runtime and add-on module UUIDs are unchanged, so this is an in-place update. Existing per-character body choices use the same Runtime/save identity. If upgrading specifically from v1.2.0 and a character had previously been disabled with `!cm_revert`, run `!cm_revert` once again for that character after updating; older save records could not distinguish a revert from a Vanilla selection.

## Uninstalling

Deactivate all ClothMorph modules, save the load order, and then remove the ClothMorph PAK files. Characters return to their original body behavior.
