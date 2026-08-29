#!/usr/bin/env bash
#
# build.sh - build and install the Claude Desktop Flatpak.
#
# The manifest uses an extra-data source, so the build itself is small and
# fast. Anthropic's .deb (about 160 MB) is downloaded at INSTALL time, not
# build time, and unpacked on your machine by the apply_extra script.
#
set -euo pipefail

cd "$(dirname "$0")"

APP_ID="io.github.dewzor.ClaudeDesktop"
MANIFEST="$APP_ID.yaml"
BUILD_DIR="build-dir"
REPO_DIR="repo"
RUNTIME_VERSION="25.08"
BUNDLE=0

die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[36m==>\033[0m %s\n' "$*"; }

usage() {
    cat <<USAGE
Usage: $0 [options]

  --bundle    Build through a local OSTree repo, write a single-file
              $APP_ID.flatpak next to this script, and install from
              the local repo. Read the note it prints: flatpak cannot
              install an extra-data bundle directly.
  -h, --help  Show this help.

With no options: build the app and install it for the current user.
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --bundle)  BUNDLE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *)         die "unknown option: $1 (try --help)" ;;
    esac
done

missing=()
command -v flatpak >/dev/null || missing+=(flatpak)
command -v flatpak-builder >/dev/null || missing+=(flatpak-builder)
if [ "${#missing[@]}" -gt 0 ]; then
    die "missing: ${missing[*]} (on Fedora: sudo dnf install ${missing[*]})"
fi

# We install everything into the per-user installation, so flathub has to
# exist there too. A system-wide flathub remote does not serve --user pulls.
if ! flatpak remotes --user --columns=name | grep -qx flathub; then
    info "adding the flathub remote for your user..."
    flatpak remote-add --if-not-exists --user flathub \
        https://flathub.org/repo/flathub.flatpakrepo
fi

info "checking runtimes..."
need=()
for rt in "org.freedesktop.Platform//$RUNTIME_VERSION" \
          "org.freedesktop.Sdk//$RUNTIME_VERSION" \
          "org.electronjs.Electron2.BaseApp//$RUNTIME_VERSION"; do
    flatpak info "$rt" >/dev/null 2>&1 || need+=("$rt")
done
if [ "${#need[@]}" -gt 0 ]; then
    info "installing: ${need[*]}"
    flatpak install -y --user flathub "${need[@]}"
fi

if [ "$BUNDLE" -eq 1 ]; then
    info "building into a local repo..."
    flatpak-builder --user --force-clean --repo="$REPO_DIR" \
        --install-deps-from=flathub "$BUILD_DIR" "$MANIFEST"

    info "writing bundle..."
    # --runtime-repo lets a machine without the runtimes pull them from
    # Flathub when it installs the bundle.
    flatpak build-bundle \
        --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo \
        "$REPO_DIR" "$APP_ID.flatpak" "$APP_ID"

    cat <<NOTE

Bundle written: $PWD/$APP_ID.flatpak (about 2.5 MB)

Read this before you copy it anywhere. The bundle holds the wrapper, the
icons and the metadata, not Claude Desktop itself. The application is an
extra-data source, so flatpak fetches it from Anthropic on the machine that
installs it, and flatpak then refuses to install it out of a bundle:

    error: Failed to install bundle: Extra data missing in detached metadata

Seen with flatpak 1.18.1 and flatpak-builder 1.4.10. So the bundle is good
for archiving or for mirroring into a repo, not for installing. To install on
another machine, copy this whole directory over and run ./build.sh there, or
copy the repo directory and add it as a local remote:

    flatpak remote-add --user --no-gpg-verify claude-local /path/to/repo
    flatpak install --user claude-local $APP_ID

Either way that machine needs network access at install time, because the
application is downloaded then.

NOTE

    info "installing from the local repo..."
    flatpak remote-add --user --no-gpg-verify --if-not-exists \
        claude-desktop-local "$PWD/$REPO_DIR"
    flatpak install -y --user --reinstall claude-desktop-local "$APP_ID"
else
    info "building and installing..."
    flatpak-builder --user --install --force-clean \
        --install-deps-from=flathub "$BUILD_DIR" "$MANIFEST"
fi

printf '\n\033[32mDone.\033[0m Launch with:\n    flatpak run %s\n' "$APP_ID"
echo "Or start Claude from your application menu."
