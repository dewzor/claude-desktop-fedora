# Changelog

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
