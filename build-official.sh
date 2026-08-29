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
REDIRECT="https://claude.ai/api/desktop/linux/x64/deb/latest/redirect"
# Cloudflare 403s requests without a browser-shaped UA.
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

WORK=""
DEB=""
OUTDIR="$PWD/build/official"
KEEP=0
RELEASE="1"

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
  -h, --help     Show this help.

With no options: fetch the current official Linux build and produce an RPM
in ./build/official, then print the dnf command to install it.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --deb)     DEB="${2:?--deb needs a path}"; shift 2 ;;
        --outdir)  OUTDIR="${2:?--outdir needs a path}"; shift 2 ;;
        --release) RELEASE="${2:?--release needs a value}"; shift 2 ;;
        --keep)    KEEP=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *)         die "unknown option: $1 (try --help)" ;;
    esac
done

[ "$(uname -m)" = "$ARCH_RPM" ] || die "this script builds $ARCH_RPM only; this host is $(uname -m)"

for c in curl ar tar xz rpmbuild file; do
    command -v "$c" >/dev/null || die "missing required command: $c"
done
[ -x /usr/bin/rpmbuild ] || command -v rpmbuild >/dev/null \
    || die "rpmbuild not found — install it with: sudo dnf install rpm-build"

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

# ---------------------------------------------------------------- fetch ------
if [ -n "$DEB" ]; then
    [ -f "$DEB" ] || die "no such file: $DEB"
    info "using local package: $DEB"
    cp -- "$DEB" "$WORK/claude.deb"
else
    info "resolving the current official Linux build..."
    URL="$(curl -sS -o /dev/null -w '%{redirect_url}' --max-time 30 \
             -A "$UA" \
             -H 'Sec-Fetch-Dest: document' \
             -H 'Sec-Fetch-Mode: navigate' \
             -H 'Sec-Fetch-Site: none' \
             "$REDIRECT")" || die "could not reach $REDIRECT"
    [ -n "$URL" ] || die "no redirect target returned; Anthropic's download endpoint may have moved"
    info "found: ${URL##*/}"
    info "downloading (~165 MB)..."
    curl -fSL --progress-bar --max-time 900 -A "$UA" -o "$WORK/claude.deb" "$URL" \
        || die "download failed"
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

%post
/usr/bin/update-desktop-database %{_datadir}/applications &>/dev/null || :
/usr/bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :
/usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :

%postun
/usr/bin/update-desktop-database %{_datadir}/applications &>/dev/null || :
/usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :

%changelog
* $(LC_ALL=C date '+%a %b %d %Y') build-official.sh - $VERSION-$RELEASE
- Repackage Anthropic's official Linux $ARCH_RPM build $VERSION for Fedora
SPEC

info "building RPM (this takes a minute; the payload is ~530 MB)..."
rpmbuild --define "_topdir $RB" -bb "$RB/SPECS/claude-desktop.spec" \
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
