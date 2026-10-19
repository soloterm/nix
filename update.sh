#!/usr/bin/env bash
# Point source.json at the Linux release soloterm.com serves to everyone.
#
# The update manifest only returns fully published releases, never staged
# rollouts, so Nix users move when the website moves. The AppImage must carry a
# valid signature from Solo's updater key before its hash is recorded.
#
# Needs curl, jq, minisign and nix. Prints `updated=<version>` to
# $GITHUB_OUTPUT when source.json changes.
set -euo pipefail

cd "$(dirname "$0")"

manifest_url="https://soloterm.com/api/v1/updates/manifest?platform=linux-x86_64"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail() {
  echo "error: $*" >&2
  exit 1
}

status=$(curl -sS --retry 3 -o "$work/manifest.json" -w '%{http_code}' "$manifest_url")
if [[ $status == 204 ]]; then
  echo "soloterm.com does not publish a Linux release yet"
  exit 0
fi
[[ $status == 200 ]] || fail "update manifest returned HTTP $status"

version=$(jq -er '.version' "$work/manifest.json")
url=$(jq -er '.url' "$work/manifest.json")
signature=$(jq -er '.signature' "$work/manifest.json")

[[ $version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
  fail "unexpected version: $version"
file="Solo_${version}_amd64.AppImage"
[[ $url == "https://releases.soloterm.com/linux/x86_64/$file" ]] ||
  fail "unexpected download URL: $url"

current=$(jq -r '.version // empty' source.json 2>/dev/null || true)
if [[ $current == "$version" ]]; then
  echo "source.json already tracks $version"
  exit 0
fi

curl -sSfL --retry 3 -o "$work/$file" "$url"
base64 -d <<<"$signature" >"$work/$file.minisig"
trusted=$(minisign -Vm "$work/$file" -p solo-updater.pub -x "$work/$file.minisig")
# Tauri signs the file name into the trusted comment; reject a signature that
# belongs to a different artifact.
signed_file=$(sed -n 's/^Trusted comment: //p' <<<"$trusted" | tr '\t' '\n' | sed -n 's/^file://p')
[[ $signed_file == "$file" ]] || fail "signature is for ${signed_file:-an unnamed file}, not $file"

hash=$(nix hash file --type sha256 --sri "$work/$file")
jq -n --arg version "$version" --arg url "$url" --arg hash "$hash" \
  '{version: $version, url: $url, hash: $hash}' >source.json

echo "source.json: ${current:-none} -> $version"
if [[ -n ${GITHUB_OUTPUT:-} ]]; then
  echo "updated=$version" >>"$GITHUB_OUTPUT"
fi
