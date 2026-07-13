#!/usr/bin/env python3
"""Path B position patcher (ClothMorph, 2026-07-10).

Patches ONLY rigid-submesh POSITION floats inside an uncompressed,
vanilla-vertex-order GR2 (produced by a Divine GR2->GR2 rewrite), using
deformed positions from a refit GLB. Cloth-sim meshes (ClothPhysics extra)
and any mesh whose deformed positions equal vanilla are left untouched.

Inputs:
  --gr2        vanilla-order uncompressed GR2 (Divine rewrite of vanilla)
  --ref-glb    GLB exported FROM that GR2 (defines names/order/vanilla values)
  --def-glb    deformed GLB from the refit pipeline (same names/order)
  --out        output GR2 path

Method: for each mesh to patch, locate its interleaved vertex buffer in the
GR2 by finding vertex0's 12-byte position sequence, inferring the stride from
vertex1, then verifying EVERY vertex's vanilla position at start+i*stride
before writing deformed positions back at the same offsets. Aborts on any
ambiguity (0 or >1 verified candidate sites).
"""
import argparse, json, struct, sys

def load_glb(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'glTF', path
    jl = struct.unpack('<I', d[12:16])[0]
    j = json.loads(d[20:20+jl])
    off = 20 + jl
    bl, bt = struct.unpack('<I4s', d[off:off+8])
    assert bt.rstrip(b'\x00') == b'BIN'
    return j, d[off+8:off+8+bl]

def positions(j, b, mesh):
    a = j['accessors'][mesh['primitives'][0]['attributes']['POSITION']]
    bv = j['bufferViews'][a['bufferView']]
    stride = bv.get('byteStride', 12)
    start = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    return [b[start+k*stride:start+k*stride+12] for k in range(a['count'])]

def cloth_physics(mesh):
    e = (mesh.get('extensions') or {}).get('EXT_lslib_profile') or {}
    return bool(e.get('ClothPhysics'))

def find_buffer(gr2, van_pos):
    """Return (start, stride) of the vertex buffer holding van_pos in order."""
    n = len(van_pos)
    assert n >= 2
    v0, v1 = van_pos[0], van_pos[1]
    hits = []
    i = gr2.find(v0)
    while i != -1:
        # infer stride from vertex1 within a plausible window
        for stride in range(12, 129, 4):
            if gr2[i+stride:i+stride+12] == v1:
                ok = all(gr2[i+k*stride:i+k*stride+12] == van_pos[k]
                         for k in range(2, n))
                if ok:
                    hits.append((i, stride))
                    break
        i = gr2.find(v0, i+1)
    return hits

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--gr2', required=True)
    ap.add_argument('--ref-glb', required=True)
    ap.add_argument('--def-glb', required=True)
    ap.add_argument('--out', required=True)
    a = ap.parse_args()

    gr2 = bytearray(open(a.gr2, 'rb').read())
    rj, rb = load_glb(a.ref_glb)
    dj, db = load_glb(a.def_glb)
    dmesh = {m['name']: m for m in dj['meshes']}

    patched, skipped = [], []
    for m in rj['meshes']:
        name = m['name']
        if name not in dmesh:
            skipped.append((name, 'not-in-deformed-glb')); continue
        van = positions(rj, rb, m)
        de = positions(dj, db, dmesh[name])
        if len(van) != len(de):
            print(f'ABORT: vertex count mismatch {name} {len(van)} vs {len(de)}'); sys.exit(2)
        if cloth_physics(m):
            skipped.append((name, 'ClothPhysics')); continue
        if van == de:
            skipped.append((name, 'undeformed')); continue
        hits = find_buffer(bytes(gr2), van)
        if len(hits) != 1:
            print(f'ABORT: {name}: {len(hits)} candidate vertex buffers (need exactly 1)'); sys.exit(3)
        start, stride = hits[0]
        for k, pos in enumerate(de):
            o = start + k*stride
            gr2[o:o+12] = pos
        patched.append((name, len(van), start, stride))

    open(a.out, 'wb').write(gr2)
    for name, n, start, stride in patched:
        print(f'PATCHED {name}: {n} verts @0x{start:X} stride {stride}')
    for name, why in skipped:
        print(f'SKIPPED {name}: {why}')
    print(f'DONE out={a.out} bytes={len(gr2)} patched={len(patched)} skipped={len(skipped)}')

if __name__ == '__main__':
    main()
