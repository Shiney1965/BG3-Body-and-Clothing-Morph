#!/usr/bin/env python3
"""v4.0 LSX generator. Same as make_v33_lsx.py but KEEP comes from a file.
KEEP items (Path-B staged cloth items): full vanilla-clone node retained
(ClothParams + populated ClothProxyMapping). All other resources: ClothParams
removed + ClothProxyMapping emptied (true sim-off)."""
import re, sys

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
    out, i = [], 0
    for m in re.finditer(r'<node id="(ClothParams|ClothProxyMapping)"\s*(/?)>', block):
        if m.start() < i:
            continue
        out.append(block[i:m.start()])
        if m.group(2) == '/':
            if m.group(1) == 'ClothProxyMapping':
                out.append(m.group(0))
            i = m.end()
            continue
        end = match_end(block, m.end())
        if m.group(1) == 'ClothProxyMapping':
            out.append('<node id="ClothProxyMapping" />')
        i = end
    out.append(block[i:])
    return ''.join(out)

def main(src, keepfile, dst):
    keep = set(l.strip() for l in open(keepfile) if l.strip())
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
        if base in keep:
            out.append(block); kept += 1
        else:
            nb = transform_resource(block)
            out.append(nb)
            if nb != block: stripped += 1
        i = end
    out.append(txt[i:])
    new = ''.join(out)
    open(dst, 'w', encoding='utf-8', newline='').write(new)
    print(f'{src} -> {dst}: kept-intact={kept} stripped={stripped}')
    for pat in ['<node id="ClothParams">', 'id="MapKey"',
                '<node id="ClothProxyMapping">', 'VertexColorMaskSlots']:
        print(f'  {pat!r}: {new.count(pat)} (was {txt.count(pat)})')

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])
