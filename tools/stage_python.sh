#!/bin/bash
# Stage the BeeWare CPython 3.13 iOS runtime into TGExtra.bundle-adjacent Python/ dir.
set -euo pipefail
VER=3.13-b18
OUT=${1:-python_runtime}
curl -fsSL "https://github.com/beeware/Python-Apple-support/releases/download/$VER/Python-3.13-iOS-support.b18.tar.gz" -o /tmp/py.tgz
rm -rf /tmp/pyx && mkdir -p /tmp/pyx && tar xzf /tmp/py.tgz -C /tmp/pyx
X=/tmp/pyx/Python.xcframework
rm -rf "$OUT" && mkdir -p "$OUT/lib"
cp -a "$X/ios-arm64/Python.framework" "$OUT/"
cp -a "$X/lib/python3.13" "$OUT/lib/"
cp -a "$X/ios-arm64/lib-arm64/python3.13/." "$OUT/lib/python3.13/"
cd "$OUT/lib/python3.13"
rm -rf test idlelib tkinter turtledemo ensurepip pydoc_data lib2to3 venv __phello__ site-packages/* config-* 2>/dev/null || true
find . -name '__pycache__' -prune -exec rm -rf {} +
cd lib-dynload
for f in *.so; do
  # extensions reference @rpath/Python.framework/Python; point them at our copy
  install_name_tool -change @rpath/Python.framework/Python @loader_path/../../../Python.framework/Python "$f" 2>/dev/null || true
done


echo "runtime staged: $(du -sh "$OUT" | cut -f1)"
