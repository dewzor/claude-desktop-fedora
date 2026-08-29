# Changelog

## v9 (2026-08-29)

**Official Linux build.** New primary path, `build-official.sh`, contributed by [@sharpandpearl](https://github.com/sharpandpearl) in [#4](https://github.com/dewzor/claude-desktop-fedora/pull/4).

- Builds the RPM from Anthropic's official Linux x86_64 `.deb` instead of repacking the Windows installer.
- Payload is unmodified upstream content: no `app.asar` patching, no native-module stub, no CSS, no launcher wrapper.
- Claude Code tab works (real `@ant/claude-native` + `node-pty` ELF modules). Cowork works.
- Chromium sandbox stays enabled; `chrome-sandbox` setuid 4755 preserved and verified post-build.
- Debian-only `postinst` behaviour dropped (AppArmor userns profile, apt repo registration).
- `build-fedora.sh` retained as the legacy path for 0.14.x-era builds; not maintained against current releases.
- README rewritten around the official build.

## v8 — 2025-12-04

**Root-cause titlebar fix.**

- Patches titlebar height constants in Claude Desktop's bundled JS: `?0:36` → `?0:0`. The 36px gap no longer renders because the layout doesn't reserve space for a Windows titlebar.
- Simplified CSS backup with a negative-margin safety net (`margin-top:-36px; height:calc(100% + 36px)`).
- Removed earlier DOM-manipulation workaround — no longer needed.

## v7 — 2025-12-04

Grid-collapse approach to the titlebar gap. Partially eliminated the dark gap but left residual pixels under some KDE setups. Superseded by v8's root-cause fix.

## v6 and earlier — 2025-11-14

- Auto-download latest Claude Desktop via Anthropic's official redirect URL.
- Cloudflare download blocking bypassed with browser-style headers.
- Launcher script improvements and titlebar validation.
- Initial double-titlebar fix for Claude Desktop v0.14.10.

## Older history

Iterative build-script polish — Fedora detection improvements (`os-release` fallback), `sqlite3` dependency, `StartupWMClass` icon fix, non-x86_64 architecture support. See git log for full detail.
