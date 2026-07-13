#!/usr/bin/env python3
"""Batch Path-B patcher: runs patch_gr2_positions logic over the work lists.
Run from ClothMorph_Build. Writes _pathb/out_sbbf|out_bcb/<name>.GR2 and
_pathb/batch_manifest.json. Resumable (skips existing outputs)."""
import importlib.util, json, os, sys

spec = importlib.util.spec_from_file_location('p', os.path.join('_pathb', 'patch_gr2_positions.py'))
P = importlib.util.module_from_spec(spec); spec.loader.exec_module(P)

def run(name, defdir, outdir):
    gr2p = os.path.join('_pathb', 'gr2_ordered', name + '.GR2')
    refp = os.path.join('_mesh_glb', name + '.glb')
    defp = os.path.join(defdir, name + '.glb')
    outp = os.path.join(outdir, name + '.GR2')
    rec = {'name': name, 'out': outp}
    try:
        gr2 = bytearray(open(gr2p, 'rb').read())
        rj, rb = P.load_glb(refp)
        dj, db = P.load_glb(defp)
        dmesh = {m['name']: m for m in dj['meshes']}
        patched, cloth, und = [], [], []
        for m in rj['meshes']:
            nm = m['name']
            if nm not in dmesh:
                rec['error'] = f'mesh {nm} missing in deformed glb'; return rec
            van = P.positions(rj, rb, m); de = P.positions(dj, db, dmesh[nm])
            if len(van) != len(de):
                rec['error'] = f'count mismatch {nm}'; return rec
            if P.cloth_physics(m):
                cloth.append(nm); continue
            if van == de:
                und.append(nm); continue
            hits = P.find_buffer(bytes(gr2), van)
            if len(hits) != 1:
                rec['error'] = f'{nm}: {len(hits)} buffer candidates'; return rec
            start, stride = hits[0]
            for k, pos in enumerate(de):
                o = start + k * stride
                gr2[o:o+12] = pos
            patched.append(nm)
        open(outp, 'wb').write(gr2)
        rec.update(patched=patched, cloth_skipped=cloth, undeformed=und, ok=True)
    except Exception as e:
        rec['error'] = repr(e)
    return rec

def main():
    man = {'sbbf': [], 'bcb': []}
    for body, lst, defdir in [('sbbf', '_pathb/list_sbbf.txt', '_mesh_refit_glb'),
                              ('bcb', '_pathb/list_bcb.txt', '_mesh_refit_glb_bcb')]:
        outdir = os.path.join('_pathb', 'out_' + body)
        os.makedirs(outdir, exist_ok=True)
        names = [l.strip() for l in open(lst) if l.strip()]
        for i, name in enumerate(names):
            outp = os.path.join(outdir, name + '.GR2')
            if os.path.exists(outp):
                man[body].append({'name': name, 'ok': True, 'resumed': True}); continue
            rec = run(name, defdir, outdir)
            man[body].append(rec)
            if 'error' in rec:
                print(f'[{body}] FAIL {name}: {rec["error"]}')
        ok = sum(1 for r in man[body] if r.get('ok'))
        print(f'{body}: {ok}/{len(names)} ok')
    json.dump(man, open('_pathb/batch_manifest.json', 'w'), indent=1)
    # cloth keep-lists per body (items with >=1 ClothPhysics submesh, successfully patched)
    for body in ('sbbf', 'bcb'):
        keep = sorted(r['name'] for r in man[body] if r.get('ok') and r.get('cloth_skipped'))
        open(f'_pathb/keep_cloth_{body}.txt', 'w').write('\n'.join(keep) + '\n')
        print(f'keep_cloth_{body}: {len(keep)}')

if __name__ == '__main__':
    main()
