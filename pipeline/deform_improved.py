#!/usr/bin/env python3
"""
Improved body-driven clothing deformation for the BG3 "Clothing Morph for
Specialized Bodies" sidecar.

Pipeline (per clothing item):
  1. Build a per-vertex displacement field on the SOURCE body
     (vanilla_body -> sbbf_body). If the two bodies are vertex-aligned
     (same vertex count + tiny correspondence residual) the field is the exact
     1:1 delta. Otherwise we fall back to nearest-surface correspondence.
  2. Transfer that displacement field to every clothing vertex with smooth,
     normalized k-nearest weights (Shepard / Gaussian falloff in body-bbox
     units). This is the "drive the clothing by the body delta" step and
     replaces the prior MLS/IDW affine-fit transfer, which over-rotated thin
     shells and left residual clipping.
  3. CLIPPING FIX PASS: build a signed-distance test against the deformed
     (target) body surface; any clothing vertex that lands inside the body
     (or closer than a small target offset) is pushed back out along the body
     surface normal to a small positive offset. Run a couple of relaxation
     iterations so neighbours don't tear.

Public API:
    deform_clothing(body_src, body_dst, clothing_src, **params) -> trimesh.Trimesh

Everything is parameterized so the sidecar can batch it per clothing item.

CLI:
    python3 deform_improved.py BODY_SRC BODY_DST CLOTHING_SRC \
        [--out OUT.glb] [--png COMPARE.png] [--metrics METRICS.json] \
        [--mls MLS.glb --idw IDW.glb]   # optional priors to beat in the report
"""
from __future__ import annotations
import argparse, json, os
import numpy as np

try:
    import trimesh
except Exception as e:  # pragma: no cover
    raise SystemExit("trimesh is required: pip install --break-system-packages trimesh") from e

from scipy.spatial import cKDTree


# --------------------------------------------------------------------------- #
# IO helpers
# --------------------------------------------------------------------------- #
def _is_lod_name(name: str) -> bool:
    """True for explicit LOD>=1 geometry names (e.g. '..._LOD1')."""
    import re
    return bool(re.search(r"_LOD[1-9]\d*$", name, re.IGNORECASE))


def load_lod0(path: str) -> "trimesh.Trimesh":
    """Load a GLB/GLTF; if it is a Scene, return the highest-vertex non-LOD
    geometry (assumed LOD0). process=False keeps the original vertex order."""
    g = trimesh.load(path, process=False)
    if isinstance(g, trimesh.Scene):
        if not g.geometry:
            raise ValueError(f"{path}: empty scene")
        cands = {k: v for k, v in g.geometry.items() if not _is_lod_name(k)} or g.geometry
        m = max(cands.values(), key=lambda x: len(x.vertices))
    else:
        m = g
    return m


def load_clothing_lod0_parts(path: str):
    """Return {name: Trimesh} for every LOD0 (non-LOD-suffixed) submesh of a
    clothing GLB. A single outfit can have several render meshes (e.g. a body
    piece + a skirt) -- ALL of them must be deformed, not just the largest.
    Returns the original load object too so we can re-export the full scene."""
    g = trimesh.load(path, process=False)
    if isinstance(g, trimesh.Scene):
        parts = {k: v for k, v in g.geometry.items() if not _is_lod_name(k)}
        if not parts:
            parts = dict(g.geometry)
        return parts, g
    return {"mesh": g}, g


def _verts(m) -> np.ndarray:
    return np.asarray(m.vertices, dtype=np.float64)


def _all_lod0_verts(path: str) -> np.ndarray:
    """Stacked vertices of every LOD0 submesh of a GLB (for fair comparison
    of priors that may also be multi-part)."""
    parts, _ = load_clothing_lod0_parts(path)
    return np.vstack([_verts(m) for m in parts.values()])


# --------------------------------------------------------------------------- #
# 1. Body displacement field
# --------------------------------------------------------------------------- #
def body_correspondence(P: np.ndarray, Q: np.ndarray,
                        align_tol_frac: float = 1e-3):
    """Return (Qmatched, info) where Qmatched[i] is the target position
    corresponding to source body vertex P[i].

    If P and Q have identical vertex counts AND the straight index-aligned
    residual is tiny relative to the bbox diagonal, the meshes are treated as
    vertex-aligned (BG3 specialized bodies are typically edits of the vanilla
    mesh, so this is the common, exact case). Otherwise we map each source
    vertex to its nearest target vertex.
    """
    diag = float(np.linalg.norm(Q.max(0) - Q.min(0)))
    info = {"body_diag": diag}
    if P.shape == Q.shape:
        resid = np.linalg.norm(P - Q, axis=1)
        # If most verts already coincide the field is degenerate; the real
        # signal is the index-aligned delta. Use the *aligned* residual to
        # decide topology, not whether they're identical.
        nn_resid = float(np.median(resid))
        info["index_aligned_median_resid"] = nn_resid
        info["index_aligned_max_resid"] = float(resid.max())
        # Vertex-aligned if the index-aligned mapping is at least as good as a
        # nearest-neighbour mapping would be (i.e. no large index scrambling).
        tree = cKDTree(Q)
        nn_d, _ = tree.query(P)
        info["nearest_median_resid"] = float(np.median(nn_d))
        # Aligned when index residual ~ nearest residual (same correspondence).
        aligned = nn_resid <= np.median(nn_d) + align_tol_frac * diag
        info["vertex_aligned"] = bool(aligned)
        if aligned:
            info["mode"] = "index-aligned (shared topology)"
            return Q.copy(), info
    info["vertex_aligned"] = info.get("vertex_aligned", False)
    info["mode"] = "nearest-vertex (no shared topology)"
    tree = cKDTree(Q)
    _, idx = tree.query(P)
    return Q[idx], info


# --------------------------------------------------------------------------- #
# 2. Smooth weighted transfer of the displacement field to the clothing
# --------------------------------------------------------------------------- #
def transfer_displacement(O: np.ndarray, P: np.ndarray, D: np.ndarray,
                          k: int = 12, sigma_frac: float = 0.05,
                          power: float = 2.0, eps: float = 1e-12,
                          diag: float | None = None) -> np.ndarray:
    """Move clothing verts O by the body displacement field D defined at body
    verts P, using normalized k-nearest Gaussian * inverse-distance weights.

    sigma_frac sets the Gaussian falloff as a fraction of the body bbox
    diagonal, giving a smooth, scale-invariant blend that follows the body
    surface without the affine over-rotation of MLS.
    """
    if diag is None:
        diag = float(np.linalg.norm(P.max(0) - P.min(0)))
    sigma = max(sigma_frac * diag, 1e-9)
    k = int(min(k, len(P)))
    tree = cKDTree(P)
    dist, idx = tree.query(O, k=k)
    if k == 1:
        dist = dist[:, None]; idx = idx[:, None]
    # Gaussian falloff + inverse-distance, both normalized per query point.
    w = np.exp(-(dist ** 2) / (2.0 * sigma ** 2)) / (dist ** power + eps)
    w /= (w.sum(axis=1, keepdims=True) + eps)
    disp = np.einsum("nk,nkj->nj", w, D[idx])
    return O + disp


# --------------------------------------------------------------------------- #
# 3. Clipping fix pass (signed distance vs target body surface)
# --------------------------------------------------------------------------- #
def signed_distance_to_body(V: np.ndarray, body: "trimesh.Trimesh",
                            body_tree: cKDTree, body_normals: np.ndarray):
    """Signed distance of points V to the body surface, using the nearest body
    vertex and its (outward) normal. Negative = inside the body.

    Uses vertex-normal projection (robust, no watertight requirement) rather
    than trimesh.proximity, which needs a watertight mesh for reliable signs.
    Returns (signed, nearest_idx, nearest_normal)."""
    d, idx = body_tree.query(V)
    n = body_normals[idx]
    signed = np.einsum("ij,ij->i", V - body.vertices[idx], n)
    return signed, idx, n


def clipping_fix(V: np.ndarray, body: "trimesh.Trimesh", body_tree: cKDTree,
                 body_normals: np.ndarray, offset: float,
                 iters: int = 3, relax: float = 0.5):
    """Push any clothing vertex that is inside the body (signed < offset) back
    out along the body normal to +offset. Iterate so corrections settle and
    don't introduce sharp pokes. Returns (V_fixed, n_fixed_initial)."""
    V = V.copy()
    n_fixed0 = 0
    for it in range(iters):
        signed, idx, n = signed_distance_to_body(V, body, body_tree, body_normals)
        violate = signed < offset
        nv = int(violate.sum())
        if it == 0:
            n_fixed0 = nv
        if nv == 0:
            break
        # Move each violating vertex outward by (offset - signed) along normal,
        # damped by `relax` so overlapping corrections converge smoothly.
        push = (offset - signed)[:, None] * n
        step = np.zeros_like(V)
        step[violate] = relax * push[violate]
        V = V + step
    return V, n_fixed0


# --------------------------------------------------------------------------- #
# Metrics
# --------------------------------------------------------------------------- #
def penetration_stats(V: np.ndarray, body: "trimesh.Trimesh",
                      body_tree: cKDTree, body_normals: np.ndarray,
                      offset: float) -> dict:
    signed, _, _ = signed_distance_to_body(V, body, body_tree, body_normals)
    inside = signed < 0.0
    below_offset = signed < offset
    return {
        "n_verts": int(len(V)),
        "n_penetrating": int(inside.sum()),
        "pct_penetrating": float(100.0 * inside.mean()),
        "max_penetration_depth": float(-signed.min()) if inside.any() else 0.0,
        "n_below_offset": int(below_offset.sum()),
        "mean_signed_dist": float(signed.mean()),
        "min_signed_dist": float(signed.min()),
    }


def surface_distance_stats(V: np.ndarray, body_tree: cKDTree) -> dict:
    """Unsigned nearest-surface distance (mean / Hausdorff-ish max)."""
    d, _ = body_tree.query(V)
    return {"mean_surface_dist": float(d.mean()),
            "max_surface_dist": float(d.max())}


# --------------------------------------------------------------------------- #
# Top-level reusable API
# --------------------------------------------------------------------------- #
def _deform_one(O, P, D, bdst, body_tree, body_normals, diag, offset,
                k, sigma_frac, fix_iters, relax):
    """Deform one clothing vertex array O against a prebuilt body field/surface.
    Returns (fixed_verts, before_stats, after_stats)."""
    deformed = transfer_displacement(O, P, D, k=k, sigma_frac=sigma_frac, diag=diag)
    before = penetration_stats(deformed, bdst, body_tree, body_normals, offset)
    fixed, _ = clipping_fix(deformed, bdst, body_tree, body_normals,
                            offset=offset, iters=fix_iters, relax=relax)
    after = penetration_stats(fixed, bdst, body_tree, body_normals, offset)
    after.update(surface_distance_stats(fixed, body_tree))
    return fixed, before, after


def deform_clothing(body_src, body_dst, clothing_src,
                    k: int = 12, sigma_frac: float = 0.05,
                    offset_frac: float = 0.004, fix_iters: int = 4,
                    relax: float = 0.6, return_info: bool = False):
    """Deform a single clothing mesh fitted to body_src so it fits body_dst.

    This is the simple, batchable entry point: pass ONE clothing Trimesh (or a
    GLB whose LOD0 is a single mesh) and get one deformed Trimesh back. For a
    multi-part outfit GLB (e.g. body + skirt), use deform_clothing_scene, which
    deforms every LOD0 submesh and re-exports the full scene.

    Parameters
    ----------
    body_src, body_dst, clothing_src : str path | trimesh.Trimesh
    k : k-nearest body verts used for displacement transfer.
    sigma_frac : Gaussian falloff as fraction of body bbox diagonal.
    offset_frac : target clearance (and clip threshold) as fraction of diagonal.
    fix_iters, relax : clipping-fix relaxation controls.

    Returns
    -------
    trimesh.Trimesh, or (Trimesh, info) if return_info.
    """
    bsrc = load_lod0(body_src) if isinstance(body_src, str) else body_src
    bdst = load_lod0(body_dst) if isinstance(body_dst, str) else body_dst
    cloth = load_lod0(clothing_src) if isinstance(clothing_src, str) else clothing_src

    P = _verts(bsrc)
    Qfull = _verts(bdst)
    O = _verts(cloth)
    diag = float(np.linalg.norm(Qfull.max(0) - Qfull.min(0)))
    offset = offset_frac * diag

    Qmatched, corr_info = body_correspondence(P, Qfull)
    D = Qmatched - P
    body_tree = cKDTree(bdst.vertices)
    body_normals = np.asarray(bdst.vertex_normals, dtype=np.float64)

    fixed, before, after = _deform_one(O, P, D, bdst, body_tree, body_normals,
                                       diag, offset, k, sigma_frac, fix_iters, relax)
    out = cloth.copy()
    out.vertices = fixed
    info = {
        "correspondence": corr_info, "body_diag": diag,
        "offset": offset, "offset_frac": offset_frac,
        "params": {"k": k, "sigma_frac": sigma_frac, "offset_frac": offset_frac,
                   "fix_iters": fix_iters, "relax": relax},
        "clipping_before_fix": before, "clipping_after_fix": after,
        "mean_vertex_move": float(np.linalg.norm(fixed - O, axis=1).mean()),
    }
    return (out, info) if return_info else out


def deform_clothing_scene(body_src, body_dst, clothing_src,
                          k: int = 12, sigma_frac: float = 0.05,
                          offset_frac: float = 0.004, fix_iters: int = 4,
                          relax: float = 0.6):
    """Deform EVERY LOD0 submesh of a (possibly multi-part) outfit GLB and
    return (scene, info). The returned trimesh.Scene preserves all original
    geometry (including untouched LOD1+ meshes); only LOD0 parts are deformed
    in place so the GLB re-exports with the same structure.

    Returns
    -------
    (trimesh.Scene, info_dict). info_dict has per-part + combined metrics.
    """
    bsrc = load_lod0(body_src) if isinstance(body_src, str) else body_src
    bdst = load_lod0(body_dst) if isinstance(body_dst, str) else body_dst
    parts, scene_obj = load_clothing_lod0_parts(clothing_src) \
        if isinstance(clothing_src, str) else ({"mesh": clothing_src}, None)

    P = _verts(bsrc)
    Qfull = _verts(bdst)
    diag = float(np.linalg.norm(Qfull.max(0) - Qfull.min(0)))
    offset = offset_frac * diag

    Qmatched, corr_info = body_correspondence(P, Qfull)
    D = Qmatched - P
    body_tree = cKDTree(bdst.vertices)
    body_normals = np.asarray(bdst.vertex_normals, dtype=np.float64)

    per_part, all_O, all_fixed = {}, [], []
    for name, mesh in parts.items():
        O = _verts(mesh)
        fixed, before, after = _deform_one(O, P, D, bdst, body_tree, body_normals,
                                           diag, offset, k, sigma_frac, fix_iters, relax)
        # write deformed verts back into the live geometry (mutates the scene)
        mesh.vertices = fixed
        per_part[name] = {"n_verts": int(len(O)),
                          "clipping_before_fix": before,
                          "clipping_after_fix": after,
                          "mean_vertex_move": float(np.linalg.norm(fixed - O, axis=1).mean())}
        all_O.append(O); all_fixed.append(fixed)

    O_all = np.vstack(all_O); F_all = np.vstack(all_fixed)
    combined_before = penetration_stats(
        transfer_displacement(O_all, P, D, k=k, sigma_frac=sigma_frac, diag=diag),
        bdst, body_tree, body_normals, offset)
    combined_after = penetration_stats(F_all, bdst, body_tree, body_normals, offset)
    combined_after.update(surface_distance_stats(F_all, body_tree))

    info = {
        "correspondence": corr_info, "body_diag": diag, "offset": offset,
        "offset_frac": offset_frac,
        "params": {"k": k, "sigma_frac": sigma_frac, "offset_frac": offset_frac,
                   "fix_iters": fix_iters, "relax": relax},
        "parts": per_part,
        "combined_clipping_before_fix": combined_before,
        "combined_clipping_after_fix": combined_after,
        "n_lod0_parts": len(parts),
    }
    return scene_obj, info, F_all, O_all


# --------------------------------------------------------------------------- #
# Comparison render
# --------------------------------------------------------------------------- #
def render_compare(png_path, body_dst, panels, title):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    Q = _verts(body_dst)
    n = len(panels)
    fig = plt.figure(figsize=(4.6 * n, 6))
    s = slice(None, None, max(1, len(Q) // 4000))
    for j, (ptitle, V) in enumerate(panels, 1):
        ax = fig.add_subplot(1, n, j, projection="3d")
        # BG3 is Y-up; plot (x, z, y) so the figure stands upright.
        ax.scatter(Q[s, 0], Q[s, 2], Q[s, 1], s=2, c="lightgray", alpha=0.5)
        so = slice(None, None, max(1, len(V) // 4000))
        ax.scatter(V[so, 0], V[so, 2], V[so, 1], s=3, c="crimson", alpha=0.7)
        ax.set_title(ptitle, fontsize=10); ax.set_axis_off()
        ax.view_init(elev=12, azim=-65)
        try:
            ax.set_box_aspect((1, 1, 2.2))
        except Exception:
            pass
    fig.suptitle(title, fontsize=12)
    fig.tight_layout()
    fig.savefig(png_path, dpi=110)
    plt.close(fig)


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("body_src")
    ap.add_argument("body_dst")
    ap.add_argument("clothing_src")
    ap.add_argument("--out", default="vanilla_leather_IMPROVED.glb")
    ap.add_argument("--png", default="improved_compare.png")
    ap.add_argument("--metrics", default="metrics.json")
    ap.add_argument("--mls", default=None, help="prior MLS glb to include in report")
    ap.add_argument("--idw", default=None, help="prior IDW glb to include in report")
    ap.add_argument("--k", type=int, default=12)
    ap.add_argument("--sigma-frac", type=float, default=0.05)
    ap.add_argument("--offset-frac", type=float, default=0.004)
    ap.add_argument("--fix-iters", type=int, default=4)
    ap.add_argument("--relax", type=float, default=0.6)
    a = ap.parse_args()

    bdst = load_lod0(a.body_dst)

    # Deform ALL LOD0 submeshes (e.g. leather body + skirt) and re-export the
    # full scene so no geometry is dropped.
    scene_obj, info, F_all, O_all = deform_clothing_scene(
        a.body_src, bdst, a.clothing_src,
        k=a.k, sigma_frac=a.sigma_frac, offset_frac=a.offset_frac,
        fix_iters=a.fix_iters, relax=a.relax)

    if scene_obj is not None:
        scene_obj.export(a.out)
    else:  # single-mesh fallback
        out = load_lod0(a.clothing_src); out.vertices = F_all; out.export(a.out)
    print(f"[export] {a.out}  ({len(F_all)} LOD0 verts across {info['n_lod0_parts']} part(s))")

    # Metrics for the priors + original, on the same target body / offset.
    body_tree = cKDTree(bdst.vertices)
    body_normals = np.asarray(bdst.vertex_normals, dtype=np.float64)
    offset = info["offset"]

    def stats_for(V):
        s = penetration_stats(V, bdst, body_tree, body_normals, offset)
        s.update(surface_distance_stats(V, body_tree))
        return s

    metrics = {
        "info": info,
        "ORIGINAL_on_target": stats_for(O_all),
        "IMPROVED": info["combined_clipping_after_fix"],
    }
    panels = [("Vanilla Leather on SBBF\n(original - clips)", O_all)]
    if a.mls and os.path.exists(a.mls):
        Vm = _all_lod0_verts(a.mls); metrics["MLS"] = stats_for(Vm)
        panels.append(("Prior MLS", Vm))
    if a.idw and os.path.exists(a.idw):
        Vi = _all_lod0_verts(a.idw); metrics["IDW"] = stats_for(Vi)
        panels.append(("Prior IDW", Vi))
    panels.append(("IMPROVED\n(body-driven + clip fix)", F_all))

    with open(a.metrics, "w") as f:
        json.dump(metrics, f, indent=2)
    print(f"[metrics] {a.metrics}")

    try:
        render_compare(a.png, bdst, panels,
                       "Vanilla Leather refit onto SBBF body: original vs priors vs IMPROVED")
        print(f"[render] {a.png}")
    except Exception as e:
        print(f"[render skipped: {e}]")

    # console summary
    b = info["combined_clipping_before_fix"]; af = info["combined_clipping_after_fix"]
    print("\n== clipping (penetrating clothing verts) ==")
    print(f"  before fix : {b['n_penetrating']:5d} / {b['n_verts']} "
          f"({b['pct_penetrating']:.2f}%)  max depth {b['max_penetration_depth']:.5f}")
    print(f"  after  fix : {af['n_penetrating']:5d} / {af['n_verts']} "
          f"({af['pct_penetrating']:.2f}%)  max depth {af['max_penetration_depth']:.5f}")
    print(f"  body diag {info['body_diag']:.4f} | offset {offset:.5f} | "
          f"corr mode: {info['correspondence']['mode']}")


if __name__ == "__main__":
    main()
