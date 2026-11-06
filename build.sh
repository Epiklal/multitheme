#!/bin/sh
# Baut multitheme.plasmoid – installierbar über
# „Neue Miniprogramme holen → Aus lokaler Datei installieren“.
set -e
cd "$(dirname "$0")"
out="$PWD/multitheme.plasmoid"
rm -f "$out"
(cd plasmoid/org.multitheme.switcher && zip -qr -X "$out" metadata.json contents -x '*/__pycache__/*')
echo "Gebaut: $out"
