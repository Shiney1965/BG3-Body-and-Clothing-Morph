# ClothMorphBCB Add-on — excluded garments (v1.3)

_Unchanged from v1.2: the BCB add-on pak received no changes in v1.3, so this exclusion list is identical to the one shipped with v1.2._


27 of the 181 scoped Sindae BCB garments are **not included** in this release due to a mesh-conversion limitation in the GR2->GLB toolchain (Divine/LSLib's glTF exporter rejects a class of complex multi-submesh meshes; the source data is intact but has no vertex-order-preserving conversion path). They are candidates for a future update.

| # | Garment | reason |
|---|---|---|
| 1 | HUM_F_ARM_GTYOrpheusSet_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 2 | HUM_F_ARM_GTYOrpheusSet_Skimpy_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 3 | HUM_F_ARM_Orin_Jewelry_KEL2 | Path-B could not map (reordered/ambiguous verts) |
| 4 | HUM_F_CLT_Apron_Cook_A_Revealing_KEL | Path-B could not map (reordered/ambiguous verts) |
| 5 | HUM_F_CLT_BlackDress_LegSlitTrans_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 6 | HUM_F_CLT_BlackDress_LegSlit_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 7 | HUM_F_CLT_BodySuitReverse_Skirtless_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 8 | HUM_F_CLT_BodySuitReverse_Window_Skirtless_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 9 | HUM_F_CLT_BreastArmour_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 10 | HUM_F_CLT_CutTopBanditBeltSunSkirt_BCB_KEL | no GLB (both routes failed) |
| 11 | HUM_F_CLT_DancerMetal_BCB_KEL | no GLB (both routes failed) |
| 12 | HUM_F_CLT_DancerPiercings_CorsetBody_KEL | no GLB (both routes failed) |
| 13 | HUM_F_CLT_JewleryBody_BodyPieces_BCB_KEL | no GLB (both routes failed) |
| 14 | HUM_F_CLT_JewleryBody_BodyPieces_Cloth_BCB_KEL | no GLB (both routes failed) |
| 15 | HUM_F_CLT_JewleryBody_MizoraPieces_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 16 | HUM_F_CLT_JewleryBody_MizoraPieces_Cloth_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 17 | HUM_F_CLT_KeeperManteauOnly_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 18 | HUM_F_CLT_SundressSkirtOnly_BanditBelt_BCB_KEL | no GLB (both routes failed) |
| 19 | HUM_F_CLT_SundressSkirtOnly_BanditBelt_HighWaist_BCB_KEL | no GLB (both routes failed) |
| 20 | HUM_F_CLT_Sundress_BCB_KEL | no GLB (both routes failed) |
| 21 | HUM_F_CLT_TinyShortsTop_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 22 | HUM_F_CLT_VampirellaOutfit_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 23 | HUM_F_CLT_WitchHat_Nightreign_KEL | no GLB (both routes failed) |
| 24 | HUM_F_Desire_Dress_Feathers_KEL | Path-B could not map (reordered/ambiguous verts) |
| 25 | HUM_F_Desire_Dress_KEL | Path-B could not map (reordered/ambiguous verts) |
| 26 | MMY_HUM_F_ARM_Accessories_C_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| 27 | MMY_HUM_F_ARM_Laces_C_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
