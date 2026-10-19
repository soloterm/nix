#!/usr/bin/env bash
# Check the built package: the expected programs exist, and no binary still
# expects an FHS loader or library path, which NixOS does not have.
set -euo pipefail

out=$(realpath "${1:-result}")

for bin in Solo mcp solo; do
  [[ -x $out/bin/$bin ]] || { echo "missing $out/bin/$bin" >&2; exit 1; }
done
[[ -d $out/lib/Solo ]] || { echo "missing $out/lib/Solo resources" >&2; exit 1; }
[[ -f $out/share/applications/Solo.desktop ]] || { echo "missing desktop entry" >&2; exit 1; }

status=0
while IFS= read -r -d '' file; do
  head -c 4 "$file" | grep -q $'\x7fELF' || continue
  interpreter=$(patchelf --print-interpreter "$file" 2>/dev/null || true)
  if [[ -n $interpreter && $interpreter != /nix/store/* ]]; then
    echo "$file still uses $interpreter" >&2
    status=1
  fi
done < <(find "$out/" -type f -print0)

"$out/bin/solo" --help >/dev/null
echo "layout ok: $out"
exit "$status"
