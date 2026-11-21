# Changelog

## v9.4 (2026-11-21)

**Claude Desktop 6.28899.2 builds again, and Fedora 45 is supported.** Build fix by [@sin4ch](https://github.com/sin4ch) in [#12](https://github.com/dewzor/claude-desktop-fedora/pull/12).

- Claude Desktop 6.28899.2 ships a new icon, `/usr/share/pixmaps/claude-desktop.png`, and `rpmbuild` stopped with "Installed (but unpackaged) file(s) found". The daily `claude-desktop-update` timer failed the same way, so installs stayed on 5.11492.5. The RPM now packages the icon when the payload has it; older payloads still build.
- Fedora 45: the COPR project now builds `claude-desktop-builder` for it, so `dnf` no longer gets a 404 ([#10](https://github.com/dewzor/claude-desktop-fedora/issues/10)). Tested in a clean Fedora 45 container.
- Fedora 43 with Xfce (X11) tested by [@antoine79](https://github.com/antoine79) in [#9](https://github.com/dewzor/claude-desktop-fedora/pull/9).
- Troubleshooting: a workaround for Ctrl+Alt+Space not working on KDE Plasma Wayland ([#11](https://github.com/dewzor/claude-desktop-fedora/issues/11)).
- `claude-desktop-builder` 1.0.4 on COPR.

## v9.3 (2026-10-22)

**Your locale no longer matters.** Reported and fixed by [@anilsrml](https://github.com/anilsrml) in [#7](https://github.com/dewzor/claude-desktop-fedora/issues/7) and [#8](https://github.com/dewzor/claude-desktop-fedora/pull/8).

- On Turkish systems `build-official.sh` stopped with "unexpected Filename in the signed index". Bash matches ranges like `[A-Za-z]` by the locale's sort order, and Turkish puts `i` and `I` outside them. Azerbaijani, Crimean Tatar, Kurdish (Turkey) and Tatar failed the same way.
- In legacy CJK encodings such as EUC-JP, EUC-KR, GB2312 and Big5, `sort` crashed instead.
- The script now runs under `C.UTF-8` whatever your locale is. On Fedora 44 we ran the signed index check under all 891 locales glibc ships: 39 failed before, none fail now. A full build and install under Turkish works too. Messages from the tools it runs, such as `rpmbuild`, are now in English.
- The `claude-desktop-update` timer failed on these systems too, because systemd passes the system locale to the service. It runs `build-official.sh`, so the same fix covers it.
- `claude-desktop-builder` 1.0.3 on COPR.

## v9.2 (2026-10-21)

**Verified downloads, full desktop integration.** Contributed by [@arcanistzed](https://github.com/arcanistzed) in [#6](https://github.com/dewzor/claude-desktop-fedora/pull/6).

- `build-official.sh` now downloads the `.deb` from Anthropic's signed apt repository instead of the `claude.ai` redirect. It checks the `InRelease` signature against Anthropic's release key, which the script pins by fingerprint. It refuses an index past its `Valid-Until` date. It checks the `Packages` index and the `.deb` against the signed SHA256s, and checks that the package version matches the index. The apt repository doesn't need the browser-shaped User-Agent, so that's gone.
- The signature check refuses expired or revoked keys and bad signatures, not just signatures from the wrong key. The index fields are checked before use.
- `--print-latest` verifies the index and prints the newest version without downloading the app.
- `claude-desktop-update` finds the current build through `--print-latest`, so the daily timer only installs builds that pass the signature check. It builds exactly the entry it checked (`--expect-sha256`) and records the `.deb`'s SHA256 once the install succeeds. The first run after upgrading rebuilds the current version once from the signed repository, so existing installs get the new desktop files too. `--force` now really reinstalls when the version is unchanged.
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
