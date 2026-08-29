#!/bin/bash
#
# Launcher used inside the Flatpak sandbox.
#
# zypak-wrapper comes from org.electronjs.Electron2.BaseApp. It intercepts
# Chromium's zygote and sandbox calls and maps them onto the Flatpak sandbox,
# so the app keeps a real renderer sandbox without the setuid chrome-sandbox
# helper, and without --no-sandbox.
#
# Electron writes scratch files, including the Claude Code terminal's, into
# TMPDIR. Point it at the per-app runtime directory so nothing leaks into a
# shared /tmp.
set -e

export TMPDIR="${XDG_RUNTIME_DIR}/app/${FLATPAK_ID}"
mkdir -p "${TMPDIR}"

exec zypak-wrapper /app/extra/claude-desktop "$@"
