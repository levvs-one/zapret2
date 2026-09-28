#!/usr/bin/env bash
# Feeds the command line Prosvet builds for winws2 to the Linux build of the
# same zapret2 release (nfqws2 --dry-run). Both share the option parser, so
# this catches typos in profiles, filters and Lua desync arguments.
set -euo pipefail

version=v1.0.5.2
sha256=f585590bea6da82ac2c74926f6ac17e6204ee8b53e455c2ba2edae0c58c5d4ac
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

curl -fsSL -o "$work/z.zip" \
  "https://github.com/bol-van/zapret2/releases/download/$version/zapret2-$version.zip"
echo "$sha256  $work/z.zip" | sha256sum -c -
unzip -q "$work/z.zip" -d "$work"
src="$work/zapret2-$version"

eng="$work/engine"
mkdir -p "$eng/lua" "$eng/lists" "$eng/state"
cp "$src"/lua/zapret-{lib,antidpi,auto}.lua "$root"/engine/lua/*.lua "$eng/lua/"
cp "$root"/engine/lists/*.txt "$eng/lists/"

cd "$root"
ENGINE_DIR="$eng" flutter test tools/dump_winws_args.dart --reporter=silent \
  | sed -n 's/^ARGS\t//p' | tr '\t' '\n' | sed 's#\\#/#g' | grep -v '^--wf-' > "$work/args"

mapfile -t args < "$work/args"
"$src/binaries/linux-x86_64/nfqws2" --qnum=200 --dry-run "${args[@]}"
