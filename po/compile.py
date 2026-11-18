#!/usr/bin/env python3
"""Compiles po/*.po into the widget's locale folder (no gettext install needed)."""
import ast, os, struct, sys

def parse(path):
    entries, cur, key = {}, {}, None
    for line in open(path, encoding="utf-8").read().splitlines() + [""]:
        line = line.strip()
        if not line:
            if "msgid" in cur:
                entries[cur["msgid"]] = cur.get("msgstr", "")
            cur, key = {}, None
        elif line.startswith("#"):
            continue
        elif line.startswith(("msgid ", "msgstr ")):
            key, val = line.split(" ", 1)
            cur[key] = ast.literal_eval(val)
        elif line.startswith('"') and key:
            cur[key] += ast.literal_eval(line)
    return entries

def write_mo(entries, out):
    keys = sorted(k.encode() for k in entries)
    vals = [entries[k.decode()].encode() for k in keys]
    n = len(keys)
    koff = 7 * 4 + 16 * n
    data, kt, vt = b"", [], []
    for k in keys:
        kt.append((len(k), koff + len(data))); data += k + b"\0"
    for v in vals:
        vt.append((len(v), koff + len(data))); data += v + b"\0"
    out.write(struct.pack("<7I", 0x950412de, 0, n, 28, 28 + 8 * n, 0, 0))
    for l, o in kt + vt:
        out.write(struct.pack("<2I", l, o))
    out.write(data)

here = os.path.dirname(os.path.abspath(__file__))
dest = os.path.join(here, "..", "plasmoid", "org.multitheme.switcher", "contents", "locale")
for name in sorted(os.listdir(here)):
    if name.endswith(".po"):
        lang = name[:-3]
        d = os.path.join(dest, lang, "LC_MESSAGES")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "plasma_applet_org.multitheme.switcher.mo"), "wb") as f:
            write_mo(parse(os.path.join(here, name)), f)
        print("compiled", lang)
