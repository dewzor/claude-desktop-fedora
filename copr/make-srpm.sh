#!/usr/bin/env bash
#
# make-srpm.sh - build the claude-desktop-builder source RPM from this tree.
#
# Produces copr/build/SOURCES/claude-desktop-builder-<version>.tar.gz and
# copr/build/SRPMS/claude-desktop-builder-<version>-<release>.src.rpm.
# Upload that SRPM to COPR, or rebuild it locally with:
#
#     rpmbuild --rebuild copr/build/SRPMS/claude-desktop-builder-*.src.rpm
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
NAME="claude-desktop-builder"
SPEC="$HERE/$NAME.spec"
TOP="$HERE/build"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v rpmbuild >/dev/null || die "rpmbuild not found; install it with: sudo dnf install rpm-build"
[ -f "$SPEC" ] || die "no spec file at $SPEC"

VERSION="$(sed -n 's/^Version:[[:space:]]*//p' "$SPEC" | head -1)"
[ -n "$VERSION" ] || die "could not read Version: from $SPEC"

rm -rf "$TOP"
mkdir -p "$TOP"/{SOURCES,SPECS,BUILD,BUILDROOT,RPMS,SRPMS}

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

DEST="$STAGE/$NAME-$VERSION"
mkdir -p "$DEST/copr"

# Everything the spec installs, laid out the way %prep expects it.
cp -- "$REPO/build-official.sh" "$DEST/"
cp -- "$REPO/README.md" "$DEST/"
cp -- "$REPO/LICENSE-MIT" "$DEST/"
cp -- "$HERE/claude-desktop-update" "$DEST/copr/"
cp -- "$HERE/claude-desktop-update.service" "$DEST/copr/"
cp -- "$HERE/claude-desktop-update.timer" "$DEST/copr/"
cp -- "$HERE/claude-desktop-update.1" "$DEST/copr/"
chmod 0755 "$DEST/build-official.sh" "$DEST/copr/claude-desktop-update"

tar -czf "$TOP/SOURCES/$NAME-$VERSION.tar.gz" \
    --owner=root --group=root -C "$STAGE" "$NAME-$VERSION"

cp -- "$SPEC" "$TOP/SPECS/"
rpmbuild --define "_topdir $TOP" -bs "$TOP/SPECS/$NAME.spec"

SRPM="$(find "$TOP/SRPMS" -type f -name '*.src.rpm' -print -quit)"
[ -n "$SRPM" ] || die "rpmbuild reported success but produced no source RPM"

printf '\nBuilt: %s\n' "$SRPM"
