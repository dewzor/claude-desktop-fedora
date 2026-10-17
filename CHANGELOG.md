# Changelog

## v9.2 (2026-10-16)

**Verified downloads, full desktop integration.**

- `build-official.sh` now downloads the `.deb` from Anthropic's signed apt repository instead of the `claude.ai` redirect. It checks the `InRelease` signature against Anthropic's release key, which the script pins by fingerprint. It refuses an index past its `Valid-Until` date. It checks the `Packages` index and the `.deb` against the signed SHA256s, and checks that the package version matches the index. The apt repository doesn't need the browser-shaped User-Agent, so that's gone.
- `--print-latest` verifies the index and prints the newest version without downloading anything.
- `claude-desktop-update` finds the current build through `--print-latest`, so the daily timer only installs builds that pass the signature check.
- The RPM now packages three things the upstream `postinst` copies in at install time: the GNOME Shell search provider, which puts "Ask Claude" in Activities search; the MIME types for `.mcpb`/`.dxt` extensions and `.skill` files; and the `ccd` launcher link, when the build ships it.
- The RPM now also recommends the rest of the `.deb`'s Recommends: `bubblewrap`, `socat`, `openssh-clients`, `pipewire-libs`, and `gjs`, which runs the search provider.
- `claude-desktop-builder` 1.0.2 on COPR, which now requires `gnupg2`.

## v9.1 (2026-10-16)

**Faster RPM step.** Started by [@itsnitinr](https://github.com/itsnitinr) in [#5](https://github.com/dewzor/claude-desktop-fedora/pull/5).

- The build looked stuck at "building RPM": Fedora's default zstd level 19 on one core took about 4 minutes on the ~530 MB payload. #5 made it multithreaded.
- On top of #5 the payload now uses zstd level 3 on one core. The RPM is built on your machine and installed right away, so the smaller file wasn't worth the wait. Measured on Fedora 43, 44 and rawhide: about 20 seconds instead of about 4 minutes, under 0.7 GB of memory, and it also works on a 2 GB machine, where level 19 on all cores ran out of memory. The RPM is about 46 MB bigger; the installed files are identical.
- `claude-desktop-update.service` now runs at the lowest CPU and I/O priority.
- `claude-desktop-builder` 1.0.1 on COPR.

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
