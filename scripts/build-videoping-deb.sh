#!/bin/bash
# Build the videoping .deb on Debian 13 with videoping's own packaging/deb/build-deb.sh and put it
# into debs/ (the image takes every .deb from there).
#
# Skipped when debs/ already holds a videoping_*.deb, unless VP_REBUILD_DEB=1.
# Source: the host folder VP_SRC (mounted at /videoping-src; default ../videoping), else a clone of
# VP_REPO (default https://github.com/toastbrotch/videoping.git) at VP_REF (default main).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEBS="$ROOT/debs"
mkdir -p "$DEBS"

if ls "$DEBS"/videoping_*.deb >/dev/null 2>&1 && [ "${VP_REBUILD_DEB:-0}" != 1 ]; then
  echo "deb: using $(ls "$DEBS"/videoping_*.deb) (VP_REBUILD_DEB=1 builds a new one)"
  exit 0
fi

source "$HOME/.cargo/env"
SRC="$HOME/videoping"
if [ -d /videoping-src ] && [ -f /videoping-src/Cargo.toml ]; then
  echo "deb: source from the host folder (VP_SRC)"
  mkdir -p "$SRC"
  rsync -a --delete \
    --exclude /target --exclude /.git --exclude /vagrant --exclude /dist \
    --exclude '/NDI SDK for Linux' --exclude '/Install_NDI_SDK_*' \
    /videoping-src/ "$SRC/"
  export GIT_DIR_SRC=/videoping-src
else
  REPO="${VP_REPO:-https://github.com/toastbrotch/videoping.git}"
  REF="${VP_REF:-main}"
  echo "deb: source from $REPO ($REF)"
  rm -rf "$SRC"
  git clone --depth 1 --branch "$REF" "$REPO" "$SRC"
  unset GIT_DIR_SRC
fi

[ -x "$SRC/packaging/deb/build-deb.sh" ] || {
  echo "deb: $SRC has no packaging/deb/build-deb.sh (videoping's .deb packaging); use a videoping"
  echo "     version that has it (VP_SRC=<folder> or VP_REF=<branch>), or put a .deb into debs/"
  exit 1
}
OUT="$(mktemp -d)"
"$SRC/packaging/deb/build-deb.sh" "$OUT"
rm -f "$DEBS"/videoping_*.deb
cp "$OUT"/videoping_*.deb "$DEBS/"
rm -rf "$OUT"
echo "deb: $(ls "$DEBS"/videoping_*.deb)"
