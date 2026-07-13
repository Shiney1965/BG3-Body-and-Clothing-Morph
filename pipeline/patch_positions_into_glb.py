#!/usr/bin/env python3
"""
Patch deformed LOD0 vertex POSITIONS from a trimesh-exported deformed GLB back
into a COPY of the ORIGINAL skinned GLB, preserving every other byte (skin,
joints, materials, accessors, LOD1-3). Output is then convertible to GR2 by
Divine/LSLib, because the original GLB's skin/skeleton structure is untouched.

Why: trimesh re-export of a skinned GLB breaks LSLib's GLTF skeleton importer
(ImportBone NPE). The original GLB converts to GR2 fine. So we keep the original
container and only overwrite POSITION floats for the LOD0 submeshes that moved.

Usage:
  python patch_positions_into_glb.py ORIGINAL.glb DEFORMED.glb OUT.glb
"""
import sys, json, struct
import numpy as np

COMP = {5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'}
NCOMP = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def load_glb(path):
    with open(path,'rb') as f: d=f.read()
    assert d[:4]==b'glTF', path+': not a GLB'
    off=12; js=None; bin_off=None; bin_len=0
    while off < len(d):
        clen,ctype = struct.unpack('<I4s', d[off:off+8])
        cdata = d[off+8:off+8+clen]
        if ctype==b'JSON': js=json.loads(cdata)
        elif ctype==b'BIN\x00': bin_off=off+8; bin_len=clen
        off += 8+clen
    return bytearray(d), js, bin_off, bin_len

def accessor_positions(js, raw, bin_off, acc_idx):
    acc=js['accessors'][acc_idx]
    bv=js['bufferViews'][acc['bufferView']]
    bvoff=bv.get('byteOffset',0); aoff=acc.get('byteOffset',0)
    start=bin_off+bvoff+aoff
    n=acc['count']; ncomp=NCOMP[acc['type']]; ctype=COMP[acc['componentType']]
    stride=bv.get('byteStride') or struct.calcsize('<'+ctype)*ncomp
    arr=np.empty((n,ncomp),dtype=np.float32)
    for i in range(n):
        s=start+i*stride
        arr[i]=struct.unpack_from('<'+ctype*ncomp, raw, s)
    return arr, start, stride, ctype, ncomp

def write_positions(raw, start, stride, ctype, ncomp, arr):
    for i in range(arr.shape[0]):
        s=start+i*stride
        struct.pack_into('<'+ctype*ncomp, raw, s, *[float(x) for x in arr[i]])

def mesh_pos_accessor(js, mesh_name):
    """Return the POSITION accessor index for the first primitive of the mesh
    whose name == mesh_name."""
    for m in js['meshes']:
        if m.get('name')==mesh_name:
            return m['primitives'][0]['attributes']['POSITION']
    return None

def rebuild_glb(js, raw, bin_off, bin_len, out_path):
    """Re-serialize a GLB from a (possibly edited) json dict + the ORIGINAL
    binary chunk bytes (unchanged). Recomputes JSON chunk padding so the file
    stays spec-valid even though the JSON length changed."""
    bin_bytes = bytes(raw[bin_off:bin_off+bin_len])
    js_bytes = json.dumps(js, separators=(',',':')).encode('utf-8')
    # pad JSON chunk to 4-byte boundary with spaces
    while len(js_bytes) % 4 != 0: js_bytes += b' '
    # pad BIN chunk to 4-byte boundary with zeros
    bin_pad = bin_bytes
    while len(bin_pad) % 4 != 0: bin_pad += b'\x00'
    total = 12 + 8 + len(js_bytes) + 8 + len(bin_pad)
    out = bytearray()
    out += b'glTF' + struct.pack('<II', 2, total)
    out += struct.pack('<I', len(js_bytes)) + b'JSON' + js_bytes
    out += struct.pack('<I', len(bin_pad)) + b'BIN\x00' + bin_pad
    with open(out_path,'wb') as f: f.write(out)
    return len(out)

def main():
    orig_p, deform_p, out_p = sys.argv[1], sys.argv[2], sys.argv[3]
    oraw,ojs,obin,obin_len = load_glb(orig_p)
    draw,djs,dbin,_ = load_glb(deform_p)

    # LOD0 submeshes = mesh names without _LOD[1-9] suffix that exist in BOTH.
    import re
    def is_lod(n): return bool(re.search(r'_LOD[1-9]\d*$', n or '', re.I))
    orig_names = {m['name'] for m in ojs['meshes'] if not is_lod(m.get('name'))}
    deform_names = {m['name'] for m in djs['meshes'] if not is_lod(m.get('name'))}
    common = sorted(orig_names & deform_names)
    print('LOD0 submeshes to patch:', common)

    patched=0
    for name in common:
        oacc = mesh_pos_accessor(ojs, name)
        dacc = mesh_pos_accessor(djs, name)
        if oacc is None or dacc is None:
            print('  SKIP (accessor missing):', name); continue
        opos, ostart, ostride, octype, oncomp = accessor_positions(ojs,oraw,obin,oacc)
        dpos, *_ = accessor_positions(djs,draw,dbin,dacc)
        if opos.shape != dpos.shape:
            print(f'  SKIP {name}: vert count mismatch orig={opos.shape} deform={dpos.shape}')
            continue
        moved = float(np.linalg.norm(dpos-opos,axis=1).mean())
        write_positions(oraw, ostart, ostride, octype, oncomp, dpos)
        # CRITICAL: update the accessor min/max bounds to the new positions, or
        # SharpGLTF's validator rejects the file ("out of bounds").
        ojs['accessors'][oacc]['min'] = [float(x) for x in dpos.min(axis=0)]
        ojs['accessors'][oacc]['max'] = [float(x) for x in dpos.max(axis=0)]
        print(f'  patched {name}: {opos.shape[0]} verts, mean move {moved:.5f}, '
              f'new bbox min {ojs["accessors"][oacc]["min"]}')
        patched+=1

    n = rebuild_glb(ojs, oraw, obin, obin_len, out_p)
    print(f'wrote {out_p} ({n} bytes), patched {patched} submesh(es)')

if __name__=='__main__':
    main()
