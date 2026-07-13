#!/usr/bin/env python3
"""v3.3 LSX generator (Path B pilot + v3.1b).

Input = refit_*_v3.lsx (full vanilla-clone nodes: ClothParams + populated
ClothProxyMapping everywhere). Output = v3.3:
  - Resources whose GR2 basename is in KEEP: node left 100% intact
    (ClothParams + mapping preserved)  -> Path B pilot items.
  - All other Resources: ClothParams nodes REMOVED and populated
    ClothProxyMapping replaced by the empty self-closed form -> true sim-off
    (v3.1b; unlike v3.1 which left ClothParams in).
Balanced-node scanning throughout (regex-only stripping is known to corrupt
nested <children> - see the v3.2 build gotcha).
"""
import re, sys

KEEP = {"HUM_F_ARM_Platemail_B_Body"}

tok = re.compile(r'<node\b[^>]*?/>|<node\b[^>]*?>|</node>')

def match_end(text, after_open):
    depth = 1
    for m in tok.finditer(text, after_open):
        s = m.group(0)
        if s.endswith('/>'):
            continue
        if s == '</node>':
            depth -= 1
            if depth == 0:
                return m.end()
        else:
            depth += 1
    raise RuntimeError('unbalanced')

def transform_resource(block):
    """Strip ClothParams + empty the ClothProxyMapping inside one Resource."""
    out, i = [], 0
    for m in re.finditer(r'<node id="(ClothParams|ClothProxyMapping)"\s*(/?)>', block):
        if m.start() < i:
            continue  # nested inside an already-consumed span (shouldn't happen)
        out.append(block[i:m.start()])
        if m.group(2) == '/':          # already self-closed
            if m.group(1) == 'ClothProxyMapping':
                out.append(m.group(0))  # keep empty mapping node
            i = m.end()                 # drop self-closed ClothParams (none exist, but safe)
            continue
        end = match_end(block, m.end())
        if m.group(1) == 'ClothProxyMapping':
            out.append('<node id="ClothProxyMapping" />')
        # ClothParams block dropped entirely
        i = end
    out.append(block[i:])
    return ''.join(out)

def main(src, dst):
    txt = open(src, encoding='utf-8').read()
    out, i = [], 0
    kept = stripped = 0
    for m in re.finditer(r'<node id="Resource">', txt):
        if m.start() < i:
            continue
        end = match_end(txt, m.end())
        block = txt[m.start():end]
        sf = re.search(r'id="SourceFile"[^>]*value="[^"]*/([^"/]+)\.GR2"', block)
        base = sf.group(1) if sf else None
        out.append(txt[i:m.start()])
        if base in KEEP:
            out.append(block); kept += 1
        else:
            nb = transform_resource(block)
            out.append(nb)
            if nb != block: stripped += 1
        i = end
    out.append(txt[i:])
    new = ''.join(out)
    open(dst, 'w', encoding='utf-8', newline='').write(new)
    print(f'{src} -> {dst}')
    print(f'  resources kept-intact={kept} stripped={stripped}')
    for pat in ['<node id="ClothParams">', 'id="MapKey"', 'ClosestVertices',
                '<node id="ClothProxyMapping" />', '<node id="ClothProxyMapping">',
                'VertexColorMaskSlots']:
        print(f'  {pat!r}: {new.count(pat)} (was {txt.count(pat)})')

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
