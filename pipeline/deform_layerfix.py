#!/usr/bin/env python3
"""Layer-preserving batch deform (v4.1 robe-fix experiment, 2026-07-13).

Hypothesis (Alan, 90%): the robe 'gray patch' clipping is LAYERED-GARMENT
INVERSION caused by deform_improved.clipping_fix pushing every vertex below
the single global clearance out to exactly that clearance -- an inner lining
authored at ~1mm and the outer shell at ~4mm both land on ~5.6mm, collapsing
(and under animation, inverting) the layer order.

Fix implemented here: per-vertex clearance preservation.
  s0_i = signed distance of ORIGINAL garment vertex to the SOURCE body.
  t_i  = clip(s0_i, floor, cap)   # snug verts stay snug, cap avoids ballooning
  After the (unchanged) displacement-field transfer, any vertex with signed
  distance to the TARGET body below t_i is pushed out to t_i (damped iters).
Relative layer offsets are preserved because each vertex keeps (a clipped copy
of) its own authored clearance instead of a shared global one.

Only POSITIONS are changed, patched into a byte-copy of the original GLB via
patch_positions_into_glb (same as the original batch driver).
"""
import argparse, json, os, re, sys, time
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(BUILD, "02_sidecar_deform"))
import deform_improved as di
import patch_positions_into_glb as pp
from scipy.spatial import cKDTree


def deform_scene_layerfix(bsrc, bdst, clothing_path,
                          k=12, sigma_frac=0.05,
                          floor_frac=0.0002, cap_frac=0.004,
                          fix_iters=4, relax=0.6):
    parts, scene_obj = di.load_clothing_lod0_parts(clothing_path)
    P = di._verts(bsrc)
    Q = di._verts(bdst)
    diag = float(np.linalg.norm(Q.max(0) - Q.min(0)))
    floor_off = floor_frac * diag
    cap_off = cap_frac * diag

    Qm, corr = di.body_correspondence(P, Q)
    D = Qm - P
    src_tree = cKDTree(bsrc.vertices)
    src_normals = np.asarray(bsrc.vertex_normals, dtype=np.float64)
    dst_tree = cKDTree(bdst.vertices)
    dst_normals = np.asarray(bdst.vertex_normals, dtype=np.float64)

    per_part = {}
    for name, mesh in parts.items():
        O = di._verts(mesh)
        # per-vertex authored clearance vs SOURCE body
        s0, _, _ = di.signed_distance_to_body(O, bsrc, src_tree, src_normals)
        target = np.clip(s0, floor_off, cap_off)
        V = di.transfer_displacement(O, P, D, k=k, sigma_frac=sigma_frac, diag=diag)
        n0 = 0
        for it in range(fix_iters):
            s1, idx, n = di.signed_distance_to_body(V, bdst, dst_tree, dst_normals)
            violate = s1 < target
            nv = int(violate.sum())
            if it == 0:
                n0 = nv
            if nv == 0:
                break
            push = (target - s1)[:, None] * n
            step = np.zeros_like(V)
            step[violate] = relax * push[violate]
            V = V + step
        mesh.vertices = V
        s1, _, _ = di.signed_distance_to_body(V, bdst, dst_tree, dst_normals)
        per_part[name] = {"n_verts": int(len(V)), "pushed_initial": int(n0),
                          "min_signed_after": float(s1.min()),
                          "floor": floor_off, "cap": cap_off}
    return scene_obj, {"correspondence": corr, "parts": per_part}


def patch_into_original(orig_path, deform_path, out_path):
    oraw, ojs, obin, obin_len = pp.load_glb(orig_path)
    draw, djs, dbin, _ = pp.load_glb(deform_path)
    def is_lod(n): return bool(re.search(r"_LOD[1-9]\d*$", n or "", re.I))
    common = sorted({m["name"] for m in ojs["meshes"] if not is_lod(m.get("name"))}
                    & {m["name"] for m in djs["meshes"] if not is_lod(m.get("name"))})
    patched = []
    for name in common:
        oacc = pp.mesh_pos_accessor(ojs, name); dacc = pp.mesh_pos_accessor(djs, name)
        if oacc is None or dacc is None: continue
        opos, ostart, ostride, octype, oncomp = pp.accessor_positions(ojs, oraw, obin, oacc)
        dpos = pp.accessor_positions(djs, draw, dbin, dacc)[0]
        if opos.shape != dpos.shape:
            return None, {"error": "vert mismatch " + name}
        pp.write_positions(oraw, ostart, ostride, octype, oncomp, dpos)
        ojs["accessors"][oacc]["min"] = [float(x) for x in dpos.min(axis=0)]
        ojs["accessors"][oacc]["max"] = [float(x) for x in dpos.max(axis=0)]
        patched.append(name)
    nbytes = pp.rebuild_glb(ojs, oraw, obin, obin_len, out_path)
    return nbytes, {"patched_submeshes": patched}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--glb-dir", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--body-src", required=True)
    ap.add_argument("--body-dst", required=True)
    ap.add_argument("--list", required=True)
    ap.add_argument("--report", required=True)
    ap.add_argument("--tmp-dir", default="/tmp/cm_layerfix_tmp")
    a = ap.parse_args()
    os.makedirs(a.out_dir, exist_ok=True); os.makedirs(a.tmp_dir, exist_ok=True)
    names = [l.strip() for l in open(a.list) if l.strip()]
    bsrc = di.load_lod0(a.body_src); bdst = di.load_lod0(a.body_dst)
    report = {"body_src": a.body_src, "body_dst": a.body_dst, "results": []}
    ok = fail = 0
    t0 = time.time()
    for i, name in enumerate(names, 1):
        rec = {"name": name}
        orig = os.path.join(a.glb_dir, name + ".glb")
        outp = os.path.join(a.out_dir, name + ".glb")
        if os.path.exists(outp) and os.path.getsize(outp) > 0:
            ok += 1; rec["status"] = "skip_exists"; report["results"].append(rec); continue
        try:
            scene_obj, info = deform_scene_layerfix(bsrc, bdst, orig)
            tmp = os.path.join(a.tmp_dir, name + ".glb")
            scene_obj.export(tmp)
            nbytes, pinfo = patch_into_original(orig, tmp, outp)
            os.remove(tmp)
            if nbytes is None:
                rec.update(status="patch_error", error=pinfo.get("error")); fail += 1
            else:
                rec.update(status="ok", parts=info["parts"]); ok += 1
        except Exception as e:
            rec.update(status="exception", error=repr(e)[:300]); fail += 1
        print(f"[{i}/{len(names)}] {name}: {rec['status']}")
        report["results"].append(rec)
    report["summary"] = {"ok": ok, "fail": fail, "elapsed_sec": round(time.time()-t0, 1)}
    json.dump(report, open(a.report, "w"), indent=1)
    print("DONE", report["summary"])


if __name__ == "__main__":
    main()
