#!/usr/bin/env bash
#
# build-official.sh — repackage Anthropic's official Claude Desktop Linux build
#                as a Fedora RPM.
#
# Anthropic publishes an official Linux x86_64 build of Claude Desktop, but
# only as a .deb. The payload inside is ordinary, self-contained Linux
# content under /usr/lib/claude-desktop — nothing Debian-specific. This
# script unwraps that payload and rebuilds it as a native RPM, so dnf can
# install, upgrade and remove it.
#
# Why not repack the Windows installer (as older Fedora scripts do): recent
# Claude Desktop hard-requires the native module @ant/claude-native for
# filesystem containment and refuses to start Claude Code without it
# (error CC-2885), and Claude Code's terminal needs node-pty. In a Windows
# repack both are win32 binaries, so Claude Code cannot work. The official
# Linux build ships both as real ELF x86_64 objects.
#
# Runs entirely as your own user; root is only needed to install the result.
#
set -euo pipefail

ARCH_DEB="amd64"
ARCH_RPM="x86_64"
# Anthropic's apt repository for the official Linux build. Its index is
# signed with Anthropic's release key; KEY_FPR is the fingerprint published
# in the Claude Code setup docs, and the key below is the one served at
# https://downloads.claude.ai/claude-desktop/key.asc and installed for apt by
# the official .deb. Pinning it here means nothing fetched at build time is
# trusted until that signature checks out.
APT_BASE="https://downloads.claude.ai/claude-desktop/apt/stable"
KEY_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
anthropic_key() {
    cat <<'KEY'
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBGnK73ABEACnbytJXkjweYrwIr0aLEFRlH+C0nF44KxFc7gQmJ6PjSPMGZAD
dxZcaixU7zZl8WxEpVO0wLmIH8cf2zGOdyuZg1Yaugk1vHb2b8WBhAGCQJdPgB8W
XquedepEYtk56uP/gCoTjJDUZluEGBHnlnuujSJ4orxEdhSykEoAUfJZGEILPpMd
bphFt/Sn+Eb/TxM5jpKPdwnv8AShNF/1mZU1fWTQq9tRKJUakZj04gdaDFElQXak
CtTij+GT6yoYCARSHwGO+PC/Pr6q4tc+D7LRjxSBvUWDoFSmlqb/PJ1hj9D/7I2O
e4XXniAPWMR56KvxHlzOzrNQdJujbJdSkCwh1ZijkSd3y8ayW5WYUTGdRab99NUw
agzlabe/VVF6kzJ0Scn5q3PihB2Y9Bwo0CKnkYk7a7KT77EWv0Kkq+VHmOtqX3a2
hhX+b6a6ve9rzJ1qZYGj+obv/C3Sx1LzUjAfqVy7RJDf2uAoP5t2g8u/TkSpUxhM
VEjZBkSxYZhMyzQM6t8IgkUfnSrIPTHixbDWARZ4beMOBjxyPZK1nP7OOrNR3TkK
JtwLMQAabURCDnL0PjS0iwBTU4jtumBD1XSULyWuoTvMljrpQr1nV1oDyOt0OLqa
KA2McWtd9PdXhC8y2EIg7TmrTlJLfHYbdmkiCYj4J49Q8HWkN/6WE+RTUwARAQAB
tD5BbnRocm9waWMgQ2xhdWRlIENvZGUgUmVsZWFzZSBTaWduaW5nIDxzZWN1cml0
eUBhbnRocm9waWMuY29tPokCUQQTAQoAOxYhBDHd3iTd+rZ59C170rqpKf8afsrO
BQJpyu9wAhsPBQsJCAcCAiICBhUKCQgLAgQWAgMBAh4HAheAAAoJELqpKf8afsrO
l5IP/2I8X1dFy5xYczWB/coIxGjuzS/V6ByZGZZEJsbr04pmuHiFUykJqPGWGQ6q
U0YF5iEwvEkaagS5m7DzhSEf3FM3Cgafax/6d70tar9Vr1D+w6uPfxetu7u/WYJp
aolIsdh5fTrBh9zSM1Njl8FM8wG8CwZQjS33Oa7d8cwRkgdUWbt6LXgz+cTQNuBn
BgW6Ks7oZFI25dfu0ojDR+aDFJg4+4wZoyDLPvJz1SIrJ5WFGs67zsx9SfS3yZnf
XKmBe+f0dUy+GJ2nFZrXFf99+c0dPEHYO8DCeAHZizjkFrdYtUHdDU0YDYEGkLJa
bE+pgcpkHf5EvsZzHsyDbl95W/eh7pcXMbwkN+W4CBYUE9X4uHhqzWaC5yAVRWUA
1BJ9V4LjZfHPLEJt0I3TxzXiEg9/BVeaTYq9RjaxIFo9Nfk158HqJY6SA5jslBlx
Gv/No8u+xVcze2UJyGVfEIUfm92+0UAIkny3+5cuVV0ICzJxXlXj0CnLM9Lt50wE
p3suVwuBEviCbZ08eAH1Ht8gbBdSsiOkIU8CX3v/scwHHx5q0+NBL6xLrQObg13a
tRXBlKObfElkPN3lTUbUnJOW4U8uSjH8VRP+AujKWMDFe7x0zCs+iYY1mTOvbrTS
9n3CmZUmbynZ+E/QWNENpW/pDNZdWFy43PASmML5FHu4m9Sn
=oqMI
-----END PGP PUBLIC KEY BLOCK-----
KEY
}

WORK=""
DEB=""
OUTDIR="$PWD/build/official"
KEEP=0
RELEASE="1"
PRINT_LATEST=0

die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$*" >&2; }

usage() {
    cat <<EOF
Usage: $0 [options]

  --deb PATH     Use an already-downloaded .deb instead of fetching it.
  --outdir DIR   Where to write the finished RPM (default: ./build/official).
  --release N    RPM release field (default: 1).
  --keep         Keep the build tree for inspection.
  --print-latest Verify the signed index, print "VERSION SHA256 FILENAME" for
                 the newest build, and exit without downloading it.
  -h, --help     Show this help.

With no options: fetch the newest official Linux build from Anthropic's signed
apt repository, verify it, produce an RPM in ./build/official, then print the
dnf command to install it.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --deb)     DEB="${2:?--deb needs a path}"; shift 2 ;;
        --outdir)  OUTDIR="${2:?--outdir needs a path}"; shift 2 ;;
        --release) RELEASE="${2:?--release needs a value}"; shift 2 ;;
        --keep)    KEEP=1; shift ;;
        --print-latest) PRINT_LATEST=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *)         die "unknown option: $1 (try --help)" ;;
    esac
done

[ "$(uname -m)" = "$ARCH_RPM" ] || die "this script builds $ARCH_RPM only; this host is $(uname -m)"

for c in curl gpg sha256sum; do
    command -v "$c" >/dev/null || die "missing required command: $c"
done
if [ "$PRINT_LATEST" -eq 0 ]; then
    for c in ar tar xz rpmbuild file; do
        command -v "$c" >/dev/null || die "missing required command: $c"
    done
    [ -x /usr/bin/rpmbuild ] || command -v rpmbuild >/dev/null \
        || die "rpmbuild not found — install it with: sudo dnf install rpm-build"
fi

cleanup() {
    if [ -n "$WORK" ] && [ -d "$WORK" ]; then
        if [ "$KEEP" -eq 1 ]; then
            info "build tree kept at $WORK"
        else
            rm -rf "$WORK"
        fi
    fi
}
trap cleanup EXIT

WORK="$(mktemp -d -t claude-desktop-rpm.XXXXXXXX)"

sha256_of() { sha256sum -- "$1" | cut -d' ' -f1; }

# Walk the apt chain of trust: pinned key -> InRelease signature (and its
# Valid-Until, so an old index cannot be replayed) -> Packages checksum ->
# newest claude-desktop entry. Sets LATEST_VERSION, LATEST_SHA256,
# LATEST_FILENAME and LATEST_SIZE. Prints nothing on success.
resolve_latest() {
    local gnupg="$WORK/gnupg" status valid_until index want entry
    mkdir -p -m 700 "$gnupg"
    anthropic_key | gpg --homedir "$gnupg" --batch --quiet --import 2>/dev/null \
        || die "could not import Anthropic's release key"

    curl -fsS --max-time 60 -o "$WORK/InRelease" "$APT_BASE/dists/stable/InRelease" \
        || die "could not fetch $APT_BASE/dists/stable/InRelease"
    # --decrypt on a clearsigned file writes out only the signed text, so
    # nothing below reads bytes the signature does not cover.
    status="$(gpg --homedir "$gnupg" --batch --status-fd 1 \
                  --output "$WORK/Release" --decrypt "$WORK/InRelease" 2>/dev/null)" \
        || die "InRelease signature check failed"
    # VALIDSIG's last field is the fingerprint of the signing primary key.
    printf '%s\n' "$status" | awk -v f="$KEY_FPR" '$2 == "VALIDSIG" && $NF == f { ok = 1 } END { exit !ok }' \
        || die "InRelease is not signed by Anthropic's release key $KEY_FPR"

    valid_until="$(sed -n 's/^Valid-Until: //p' "$WORK/Release")"
    [ -n "$valid_until" ] || die "the signed index carries no Valid-Until date"
    [ "$(date -d "$valid_until" +%s)" -gt "$(date +%s)" ] \
        || die "the signed index expired on $valid_until; refusing a stale index"

    index="main/binary-$ARCH_DEB/Packages"
    want="$(awk -v p="$index" '/^SHA256:/ { s = 1; next } /^[^ ]/ { s = 0 } s && $3 == p { print $1 }' "$WORK/Release")"
    [ -n "$want" ] || die "the signed index does not list $index"
    curl -fsS --max-time 120 -o "$WORK/Packages" "$APT_BASE/dists/stable/$index" \
        || die "could not fetch $APT_BASE/dists/stable/$index"
    [ "$(sha256_of "$WORK/Packages")" = "$want" ] \
        || die "$index does not match the checksum in the signed index"

    # The index lists every published version; keep the newest.
    entry="$(awk -v RS= '{
            p = v = f = s = z = ""
            n = split($0, l, "\n")
            for (i = 1; i <= n; i++) {
                if (l[i] ~ /^Package: /)  p = substr(l[i], 10)
                if (l[i] ~ /^Version: /)  v = substr(l[i], 10)
                if (l[i] ~ /^Filename: /) f = substr(l[i], 11)
                if (l[i] ~ /^SHA256: /)   s = substr(l[i], 9)
                if (l[i] ~ /^Size: /)     z = substr(l[i], 7)
            }
            if (p == "claude-desktop" && v != "" && f != "" && s != "") print v, s, f, z
        }' "$WORK/Packages" | sort -V -k1,1 | tail -1)"
    [ -n "$entry" ] || die "no claude-desktop entry in the signed Packages index"
    read -r LATEST_VERSION LATEST_SHA256 LATEST_FILENAME LATEST_SIZE <<<"$entry"
    case "$LATEST_FILENAME" in
        pool/*.deb) ;;
        *) die "unexpected Filename in the signed index: $LATEST_FILENAME" ;;
    esac
    case "$LATEST_FILENAME" in *..*) die "unexpected Filename in the signed index: $LATEST_FILENAME" ;; esac
}

if [ "$PRINT_LATEST" -eq 1 ]; then
    resolve_latest
    printf '%s %s %s\n' "$LATEST_VERSION" "$LATEST_SHA256" "${LATEST_FILENAME##*/}"
    exit 0
fi

# ---------------------------------------------------------------- fetch ------
EXPECT_VERSION=""
if [ -n "$DEB" ]; then
    [ -f "$DEB" ] || die "no such file: $DEB"
    warn "using local package $DEB without checking it against the signed index"
    cp -- "$DEB" "$WORK/claude.deb"
else
    info "checking Anthropic's signed apt repository..."
    resolve_latest
    info "found: claude-desktop $LATEST_VERSION (signature and index checksum verified)"
    info "downloading (~$(( ${LATEST_SIZE:-0} / 1048576 )) MB)..."
    curl -fSL --progress-bar --max-time 900 -o "$WORK/claude.deb" "$APT_BASE/$LATEST_FILENAME" \
        || die "download failed"
    [ "$(sha256_of "$WORK/claude.deb")" = "$LATEST_SHA256" ] \
        || die "the downloaded .deb does not match the SHA256 in the signed index"
    info "download matches the signed SHA256"
    EXPECT_VERSION="$LATEST_VERSION"
fi

file -b "$WORK/claude.deb" | grep -q '^Debian binary package' \
    || die "downloaded file is not a Debian package"

# -------------------------------------------------------------- unpack -------
info "unpacking..."
mkdir -p "$WORK/ctrl" "$WORK/payload"
( cd "$WORK" && ar x claude.deb ) || die "ar could not read the .deb"

CTRL_TAR="$(find "$WORK" -maxdepth 1 -name 'control.tar.*' -print -quit)"
DATA_TAR="$(find "$WORK" -maxdepth 1 -name 'data.tar.*'    -print -quit)"
[ -n "$CTRL_TAR" ] || die "no control.tar.* inside the .deb"
[ -n "$DATA_TAR" ] || die "no data.tar.* inside the .deb"

tar -xf "$CTRL_TAR" -C "$WORK/ctrl"
VERSION="$(sed -n 's/^Version:[[:space:]]*//p' "$WORK/ctrl/control" | head -1)"
[ -n "$VERSION" ] || die "could not read Version: from the package control file"
[ -z "$EXPECT_VERSION" ] || [ "$VERSION" = "$EXPECT_VERSION" ] \
    || die "package says version $VERSION but the signed index says $EXPECT_VERSION"
# RPM forbids '-' in version; upstream has not used one, but be safe.
VERSION="${VERSION//-/.}"
info "version: $VERSION"

# Extracting as an unprivileged user drops the setuid bit on chrome-sandbox;
# the spec's %attr(4755,root,root) restores it in the package metadata, and
# the post-build check below confirms it survived.
tar -xf "$DATA_TAR" -C "$WORK/payload"
[ -d "$WORK/payload/usr/lib/claude-desktop" ] \
    || die "unexpected payload layout: usr/lib/claude-desktop not found"

# Sanity-check the two modules that make Claude Code work.
NATIVE="$WORK/payload/usr/lib/claude-desktop/resources/app.asar.unpacked/node_modules/@ant/claude-native/claude-native-binding.node"
PTY="$WORK/payload/usr/lib/claude-desktop/resources/app.asar.unpacked/node_modules/node-pty/prebuilds/linux-x64/pty.node"
for m in "$NATIVE" "$PTY"; do
    if [ -f "$m" ]; then
        file -b "$m" | grep -q '^ELF 64-bit.*x86-64' \
            || die "$(basename "$m") is not a Linux x86-64 binary — wrong package?"
    else
        warn "expected native module missing: ${m#"$WORK/payload/"}"
    fi
done
info "native modules verified as Linux x86-64 (claude-native, node-pty)"

DESKTOP_FILE="$(cd "$WORK/payload/usr/share/applications" && ls -1 *.desktop 2>/dev/null | head -1)"
[ -n "$DESKTOP_FILE" ] || die "no .desktop file in the payload"

# Upstream's postinst copies these out of resources/ at install time, only
# because electron-installer-debian cannot stage extra files. Packaging them
# directly lets rpm own and remove them. Each is optional so older payloads
# still build.
RES="usr/lib/claude-desktop/resources"
EXTRA_FILES=""
stage() {  # stage SRC-under-payload DEST-under-payload
    [ -f "$WORK/payload/$1" ] || { warn "not in this build, skipping: $1"; return 0; }
    install -Dm644 "$WORK/payload/$1" "$WORK/payload/$2"
    EXTRA_FILES+="/$2"$'\n'
}
stage "$RES/linux-mime/com.anthropic.Claude.xml" \
      usr/share/mime/packages/com.anthropic.Claude.xml
stage "$RES/gnome-search-provider/com.anthropic.Claude.search-provider.ini" \
      usr/share/gnome-shell/search-providers/com.anthropic.Claude.search-provider.ini
stage "$RES/gnome-search-provider/com.anthropic.Claude.SearchProvider.service" \
      usr/share/dbus-1/services/com.anthropic.Claude.SearchProvider.service
# gnome-shell owns these directories on GNOME; claim them as well so they are
# not left unowned on desktops without it.
if [ -f "$WORK/payload/usr/share/gnome-shell/search-providers/com.anthropic.Claude.search-provider.ini" ]; then
    EXTRA_FILES+="%dir /usr/share/gnome-shell"$'\n'"%dir /usr/share/gnome-shell/search-providers"$'\n'
fi
# The `ccd` launcher only ships in some builds; link it the way postinst does.
if [ -x "$WORK/payload/$RES/bin/ccd" ] && [ ! -e "$WORK/payload/usr/bin/ccd" ]; then
    ln -s ../lib/claude-desktop/resources/bin/ccd "$WORK/payload/usr/bin/ccd"
    EXTRA_FILES+="/usr/bin/ccd"$'\n'
fi

# ------------------------------------------------------------ rpm build ------
RB="$WORK/rpmbuild"
mkdir -p "$RB"/{SOURCES,SPECS,BUILD,BUILDROOT,RPMS,SRPMS}
info "staging payload..."
tar -cf "$RB/SOURCES/claude-desktop-$VERSION.tar" \
    --owner=root --group=root -C "$WORK/payload" usr

cat > "$RB/SPECS/claude-desktop.spec" <<SPEC
# Prebuilt upstream binaries: skip the usual post-install mangling, which
# would strip, re-link or generate bogus dependencies for a bundled Electron.
%global __os_install_post %{nil}
%global debug_package %{nil}
%global __brp_check_rpaths %{nil}
%global __brp_strip %{nil}
%global __brp_strip_static_archive %{nil}
%global __brp_strip_comment_note %{nil}
%global __requires_exclude_from ^%{_prefix}/lib/claude-desktop/.*\$
%global __provides_exclude_from ^%{_prefix}/lib/claude-desktop/.*\$

Name:           claude-desktop
Version:        $VERSION
Release:        $RELEASE%{?dist}
Summary:        Claude Desktop, repackaged from Anthropic's official Linux build
License:        Proprietary
URL:            https://claude.ai
Source0:        claude-desktop-$VERSION.tar
ExclusiveArch:  $ARCH_RPM
AutoReqProv:    no

Requires:       gtk3
Requires:       libnotify
Requires:       nss
Requires:       at-spi2-atk
Requires:       libdrm
Requires:       mesa-libgbm
Requires:       libsecret
Requires:       libXtst
Requires:       libuuid
Requires:       xdg-utils
Requires:       xdg-desktop-portal
Recommends:     xdg-desktop-portal-gtk
Recommends:     libappindicator-gtk3
Recommends:     gnome-keyring
Recommends:     alsa-lib
Recommends:     ca-certificates
# From upstream's Recommends: Claude Code / Cowork sandboxing, SSH remotes,
# audio capture, and the GNOME search provider (run with gjs).
Recommends:     bubblewrap
Recommends:     socat
Recommends:     openssh-clients
Recommends:     pipewire-libs
Recommends:     gjs
# Cowork's optional full-VM sandbox; harmless to omit.
Suggests:       qemu-system-x86
Suggests:       edk2-ovmf
Suggests:       virtiofsd

# Supersede any earlier locally-built claude-desktop package.
Obsoletes:      claude-desktop < %{version}-%{release}

%description
Claude Desktop for Linux, repackaged for Fedora from Anthropic's official
x86_64 build. The application payload is unmodified upstream content and
includes the Linux-native claude-native and node-pty modules that Claude
Code and filesystem containment require.

Debian-specific packaging behaviour from the upstream .deb is intentionally
omitted: the AppArmor "unconfined" userns profile, which exists for Ubuntu
24.04+ where unprivileged user namespaces are restricted, and apt
repository registration. Fedora leaves unprivileged userns enabled, and the
setuid chrome-sandbox helper is preserved either way.

Because this package is built locally, it does not auto-update. Re-run the
build script to pick up a new release.

%prep
%setup -q -c -n %{name}-%{version}

%build
# Nothing to compile: the payload is prebuilt upstream binaries.

%install
mkdir -p %{buildroot}
cp -a usr %{buildroot}/
# Debian packaging metadata, meaningless on Fedora.
rm -rf %{buildroot}%{_datadir}/lintian

%files
%dir %{_prefix}/lib/claude-desktop
%{_prefix}/lib/claude-desktop/*
# Chromium's SUID sandbox helper; upstream ships it 4755 and tar-as-user drops that.
%attr(4755,root,root) %{_prefix}/lib/claude-desktop/chrome-sandbox
%{_bindir}/claude-desktop
%{_datadir}/applications/$DESKTOP_FILE
%{_datadir}/icons/hicolor/*/apps/claude-desktop.png
%{_datadir}/doc/claude-desktop
$EXTRA_FILES
%post
/usr/bin/update-desktop-database %{_datadir}/applications &>/dev/null || :
/usr/bin/update-mime-database %{_datadir}/mime &>/dev/null || :
/usr/bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :
/usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :

%postun
/usr/bin/update-desktop-database %{_datadir}/applications &>/dev/null || :
/usr/bin/update-mime-database %{_datadir}/mime &>/dev/null || :
/usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :

%changelog
* $(LC_ALL=C date '+%a %b %d %Y') build-official.sh - $VERSION-$RELEASE
- Repackage Anthropic's official Linux $ARCH_RPM build $VERSION for Fedora
SPEC

info "building RPM (~530 MB payload, usually under a minute; log: $WORK/rpmbuild.log)..."
# Fedora's default payload compression is w19.zstdio: zstd level 19 on one
# core, several minutes on this payload. This RPM is built on your machine
# and installed right away, so a small file buys nothing. Level 3 on one
# core takes seconds and little memory, even on small machines.
rpmbuild --define "_topdir $RB" \
    --define "_binary_payload w3.zstdio" \
    -bb "$RB/SPECS/claude-desktop.spec" \
    > "$WORK/rpmbuild.log" 2>&1 \
    || { tail -30 "$WORK/rpmbuild.log" >&2; die "rpmbuild failed (full log: $WORK/rpmbuild.log)"; }

RPM="$(find "$RB/RPMS" -name '*.rpm' -print -quit)"
[ -n "$RPM" ] || die "rpmbuild reported success but produced no RPM"

mkdir -p "$OUTDIR"
cp -- "$RPM" "$OUTDIR/"
FINAL="$OUTDIR/$(basename "$RPM")"

# Confirm the setuid bit survived into the package metadata. Read the mode
# with awk rather than `grep -q`: grep would exit at the first match, and the
# resulting SIGPIPE trips `set -o pipefail` even though nothing went wrong.
SANDBOX_MODE="$(rpm -qlvp "$FINAL" 2>/dev/null | awk '/chrome-sandbox$/ {print $1}')"
case "$SANDBOX_MODE" in
    -rws*) info "chrome-sandbox setuid bit preserved" ;;
    "")    warn "chrome-sandbox not found in the built RPM" ;;
    *)     warn "chrome-sandbox is mode $SANDBOX_MODE, not setuid; Chromium will fall back to the userns sandbox" ;;
esac

printf '\n\033[32mBuilt:\033[0m %s\n\n' "$FINAL"
echo "Install with:"
echo "    sudo dnf install $FINAL"
echo
echo "Then launch 'Claude' from your application menu, or run: claude-desktop"
