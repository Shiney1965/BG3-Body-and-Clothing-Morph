#!/usr/bin/env python3
"""Generate refit VisualBank Resource nodes (one per vanilla VisualResource)
+ the REFIT_BY_VR runtime map, data-driven from vanilla_armor_material_map.json.

Each refit VB: minted ID (uuid5 of vanilla id), refit GR2 SourceFile/Template,
vanilla Name (prefixed), vanilla Slot, LOD0 Objects with vanilla MaterialIDs +
ObjectIDs (unchanged - refit GR2 preserves the container so mesh names match),
Bounds computed from the refit mesh LOD0 AABB.
"""
import argparse, json, os, re, struct, sys, uuid
import numpy as np
sys.path.insert(0, "/tmp/cm_driver/02_sidecar_deform")
import deform_improved as di

NS = uuid.UUID("c7a11e5e-0000-4b0d-9e57-5bbf00000000")  # ClothMorph refit namespace
GR2_DIR = "Generated/Public/ClothMorphContent/Assets/Characters/_Models/Humans/_Female/Resources"

def mint(vanilla_id): return str(uuid.uuid5(NS, "sbbf-refit:" + vanilla_id.lower()))

def glb_lod0_aabb(path):
    parts, _ = di.load_clothing_lod0_parts(path)
    V = np.vstack([np.asarray(m.vertices, dtype=np.float64) for m in parts.values()])
    return V.min(0), V.max(0)

def dae_lod0_aabb(path):
    s = open(path).read()
    def is_lod(n): return bool(re.search(r"_LOD[1-9]\d*", n or "", re.I))
    verts=[]
    for gm in re.finditer(r'<geometry id="([^"]*)"[^>]*>(.*?)</geometry>', s, re.S):
        gid, body = gm.group(1), gm.group(2)
        if is_lod(gid): continue
        pm = re.search(r'<float_array id="[^"]*positions-array" count="(\d+)">(.*?)</float_array>', body, re.S)
        if not pm: continue
        arr = np.array(pm.group(2).split(), dtype=np.float64).reshape(-1,3)
        verts.append(arr)
    V = np.vstack(verts)
    return V.min(0), V.max(0)

def fvec3(a): return "%.8g %.8g %.8g" % (float(a[0]), float(a[1]), float(a[2]))

RES_TMPL = '''\t\t\t\t<node id="Resource">
\t\t\t\t\t<attribute id="AttachBone" type="FixedString" value="" />
\t\t\t\t\t<attribute id="AttachmentSkeletonResource" type="FixedString" value="" />
\t\t\t\t\t<attribute id="BlueprintInstanceResourceID" type="FixedString" value="" />
\t\t\t\t\t<attribute id="BoundsMax" type="fvec3" value="{bmax}" />
\t\t\t\t\t<attribute id="BoundsMin" type="fvec3" value="{bmin}" />
\t\t\t\t\t<attribute id="ClothColliderResourceID" type="FixedString" value="" />
\t\t\t\t\t<attribute id="HairPresetResourceId" type="FixedString" value="" />
\t\t\t\t\t<attribute id="HairType" type="uint8" value="0" />
\t\t\t\t\t<attribute id="ID" type="FixedString" value="{rid}" />
\t\t\t\t\t<attribute id="MaterialType" type="uint8" value="0" />
\t\t\t\t\t<attribute id="Name" type="LSString" value="ClothMorph_{name}" />
\t\t\t\t\t<attribute id="NeedsSkeletonRemap" type="bool" value="False" />
\t\t\t\t\t<attribute id="RemapperSlotId" type="FixedString" value="" />
\t\t\t\t\t<attribute id="ScalpMaterialId" type="FixedString" value="" />
\t\t\t\t\t<attribute id="SkeletonResource" type="FixedString" value="" />
\t\t\t\t\t<attribute id="SkeletonSlot" type="FixedString" value="" />
\t\t\t\t\t<attribute id="Slot" type="FixedString" value="{slot}" />
\t\t\t\t\t<attribute id="SoftbodyResourceID" type="FixedString" value="" />
\t\t\t\t\t<attribute id="SourceFile" type="LSString" value="{gr2dir}/{gr2}.GR2" />
\t\t\t\t\t<attribute id="SupportsVertexColorMask" type="bool" value="True" />
\t\t\t\t\t<attribute id="Template" type="FixedString" value="{gr2dir}/{gr2}.Dummy_Root.0" />
\t\t\t\t\t<children>
\t\t\t\t\t\t<node id="Base" />
\t\t\t\t\t\t<node id="ClothProxyMapping" />
{objects}
\t\t\t\t\t</children>
\t\t\t\t</node>'''

OBJ_TMPL = '''\t\t\t\t\t\t<node id="Objects">
\t\t\t\t\t\t\t<attribute id="LOD" type="uint8" value="0" />
\t\t\t\t\t\t\t<attribute id="MaterialID" type="FixedString" value="{mat}" />
\t\t\t\t\t\t\t<attribute id="ObjectID" type="FixedString" value="{oid}" />
\t\t\t\t\t\t</node>'''

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--map", required=True)
    ap.add_argument("--vr-list", required=True, help="file of vanilla VR ids, one per line")
    ap.add_argument("--glb-dir", required=True)
    ap.add_argument("--dae-dir", required=True)
    ap.add_argument("--out-lsx", required=True)
    ap.add_argument("--out-map", required=True)
    ap.add_argument("--out-gr2list", required=True)
    a=ap.parse_args()
    mp={r["id"].lower():r for r in json.load(open(a.map))}
    vrids=[l.strip().lower() for l in open(a.vr_list) if l.strip()]
    nodes=[]; refit_by_vr={}; gr2set=set(); rows=[]
    for vid in vrids:
        rec=mp.get(vid)
        if not rec: print("  MISSING VR in map:",vid); continue
        gr2=os.path.splitext(os.path.basename(rec["sourceFile"]))[0]
        # bounds from refit mesh
        glb=os.path.join(a.glb_dir,gr2+".glb"); dae=os.path.join(a.dae_dir,gr2+".dae")
        if os.path.exists(glb): bmin,bmax=glb_lod0_aabb(glb)
        elif os.path.exists(dae): bmin,bmax=dae_lod0_aabb(dae)
        else: print("  NO refit mesh for",gr2); continue
        # inflate generously so animation pose never leaves the static bounds
        bmin=np.asarray(bmin,float); bmax=np.asarray(bmax,float)
        c=(bmin+bmax)/2.0; h=(bmax-bmin)/2.0; h=h*1.5+0.15
        bmin=c-h; bmax=c+h
        lod0=[p for p in rec["parts"] if p["lod"]=="0"]
        objs="\n".join(OBJ_TMPL.format(mat=p["materialId"],oid=p["objectId"]) for p in lod0)
        rid=mint(vid)
        nodes.append(RES_TMPL.format(bmax=fvec3(bmax),bmin=fvec3(bmin),rid=rid,
            name=rec["name"],slot=rec["slot"],gr2dir=GR2_DIR,gr2=gr2,objects=objs))
        refit_by_vr[vid]=rid; gr2set.add(gr2)
        rows.append((vid,rid,gr2,rec["name"],rec["slot"],len(lod0)))
    header='<?xml version="1.0" encoding="utf-8"?>\n<save>\n\t<version major="4" minor="0" revision="9" build="0" lslib_meta="v1,bswap_guids,lsf_adjacency" />\n\t<region id="VisualBank">\n\t\t<node id="VisualBank">\n\t\t\t<children>\n'
    footer='\n\t\t\t</children>\n\t\t</node>\n\t</region>\n</save>\n'
    open(a.out_lsx,"w",encoding="utf-8").write(header + "\n".join(nodes) + footer)
    json.dump(refit_by_vr, open(a.out_map,"w"), indent=1)
    open(a.out_gr2list,"w").write("\n".join(sorted(gr2set))+"\n")
    print("Generated %d refit VBs, %d GR2 files" % (len(nodes),len(gr2set)))
    for r in rows: print("  VR %s -> refit %s  gr2=%s slot=%s lod0parts=%d (%s)"%(r[0][:8],r[1][:8],r[2],r[4],r[5],r[3]))

if __name__=="__main__": main()
