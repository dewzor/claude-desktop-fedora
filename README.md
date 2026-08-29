# Claude Desktop for Fedora 44

Install **Claude Desktop on Fedora 44** as a native RPM, built from Anthropic's **official Linux x86_64 build**. Unmodified upstream payload, Chromium sandbox on, Claude Code and Cowork working. Tested on Fedora 44 with KDE Plasma (Wayland) and GNOME (Wayland); should work on Fedora 43 and later.

**TL;DR:** `./build-official.sh && sudo dnf install build/official/claude-desktop-*.rpm`

> Unofficial packaging. Anthropic ships the app; this repo only rewraps it for `dnf`. If you hit a packaging bug, open an issue here — don't bug Anthropic about it.

## Install Claude Desktop on Fedora 44

```bash
sudo dnf install rpm-build binutils file xz curl

git clone https://github.com/dewzor/claude-desktop-fedora.git
cd claude-desktop-fedora
./build-official.sh
sudo dnf install build/official/claude-desktop-*.rpm
```

Launch **Claude** from your application menu, or run `claude-desktop`. The launcher also ships two desktop actions: *New Chat* and *New Claude Code Session*.

The build runs entirely as your own user; root is only needed for the final `dnf install`.

## What works on Fedora 44

| Feature | Status |
| --- | --- |
| Fedora 44 — KDE Plasma (Wayland) | Tested |
| Fedora 44 — GNOME (Wayland) | Tested |
| Claude Code tab (integrated terminal) | Working |
| Cowork | Working |
| MCP (Model Context Protocol) | Working |
| Chrome extension MCP bridge | Working |
| Native window frame | Yes — no patching needed |
| Chromium sandbox | Enabled (`chrome-sandbox` setuid 4755, no `--no-sandbox`) |
| System tray | Working |
| Auto-download latest Claude | Yes — official redirect URL |
| Architecture | x86_64 only (see FAQ) |
| Auto-update | No — re-run the build script |

## How the Fedora RPM is built

Anthropic publishes an official Linux build of Claude Desktop, but only as a `.deb`. The payload inside is ordinary, self-contained Linux content under `/usr/lib/claude-desktop` — nothing Debian-specific except the wrapper and dependency names.

`build-official.sh`:

1. Resolves and downloads the current official `.deb` from `https://claude.ai/api/desktop/linux/x64/deb/latest/redirect` (~165 MB; browser-shaped UA to satisfy Cloudflare)
2. Unpacks it and reads the version from the control file
3. Verifies that `@ant/claude-native` and `node-pty` are real ELF x86-64 objects — fails loudly if not
4. Maps the Debian dependencies to Fedora package names
5. Builds an RPM with `rpmbuild`, preserving `chrome-sandbox` setuid via `%attr(4755,root,root)`
6. Confirms the setuid bit survived into the package metadata

The payload is **unmodified upstream content**. No `app.asar` patching, no stubs, no injected CSS, no launcher wrapper.

Two Debian-specific `postinst` behaviours are intentionally dropped:

- The AppArmor `flags=(unconfined)` userns profile — only needed on Ubuntu 24.04+, which restricts unprivileged user namespaces. Fedora leaves them enabled.
- apt repository registration.

### Options

```
--deb PATH     Use an already-downloaded .deb instead of fetching it.
--outdir DIR   Where to write the finished RPM (default: ./build/official).
--release N    RPM release field (default: 1).
--keep         Keep the build tree for inspection.
```

## Updating Claude Desktop on Fedora

The RPM does not auto-update. To pick up a new release:

```bash
./build-official.sh
sudo dnf install build/official/claude-desktop-*.rpm
```

The spec carries `Obsoletes: claude-desktop < %{version}-%{release}`, so a newer build cleanly replaces any earlier locally-built package, including ones from the legacy script.

## MCP setup on Fedora

MCP servers are configured at:

```
~/.config/Claude/claude_desktop_config.json
```

Same format as macOS and Windows Claude Desktop — drop in your `mcpServers` block and restart the app.

Logs live in `~/.config/Claude/logs/` (`main.log`, `mcp.log`, `ssh.log`, …).

## Why not the Windows repack any more?

Earlier versions of this repo (`build-fedora.sh`, still in the tree) rebuilt Claude Desktop from the **Windows installer**: extract `app.asar`, swap the native module for a JS stub, patch the titlebar constants, bundle Electron 37. That worked through the 0.14.x era. Current releases can't be served that way:

- **`@ant/claude-native`** is now hard-required for filesystem containment, and the app explicitly refuses to degrade without it:
  `@ant/claude-native is required for safe-fs containment but failed to load; refusing to fall back to a path-based open (CC-2885)`.
  A JS stub can't satisfy that, and the module also moved from `claude-native` to `@ant/claude-native`, so the old stub path is never even loaded. In a Windows repack the real module is a PE32+ DLL: `ERR_DLOPEN_FAILED: invalid ELF header`.
- **`node-pty`** — Claude Code's terminal needs `prebuilds/linux-x64/pty.node`. The Windows package only ships `prebuilds/win32-x64/conpty.node`.

Net effect: the app starts, but **the Claude Code tab does not work**. The official Linux build ships both modules as real ELF x86-64 objects, and its native frame is already correct, so none of the old patching is needed.

## Legacy: `build-fedora.sh`

Kept for anyone who needs a 0.14.x-era build. It is no longer the recommended path and is not maintained against current releases.

```bash
sudo dnf install rpm-build p7zip nodejs npm
sudo ./build-fedora.sh
sudo dnf install build/electron-app/$(uname -m)/claude-desktop-*.rpm
```

Known limits on current releases: the Claude Code tab doesn't work (see above), and the `titleBarStyle` sed no longer matches (`⚠ titleBarStyle pattern not found`). History of what it did and why is in [CHANGELOG.md](CHANGELOG.md).

## FAQ

### Does Claude Desktop work on Fedora 44?
Yes — tested on Fedora 44 with KDE Plasma (Wayland) and GNOME (Wayland).

### Does it work on Fedora 43 or older?
It should. The payload is self-contained (bundled Electron), so the only real constraint is the runtime dependency list, which resolves on 43. Not actively tested — open an issue with what you see.

### Does the Claude Code tab work?
Yes. That's the whole point of the official-build path. Look for `[CCD] Initialized` in `~/.config/Claude/logs/main.log`.

### Does Cowork work?
Yes. Cowork's optional full-VM sandbox needs `qemu-system-x86`, `edk2-ovmf` and `virtiofsd`; they're listed as `Suggests:` in the RPM and are harmless to omit.

### Does MCP work?
Yes. Config lives at `~/.config/Claude/claude_desktop_config.json`.

### Why x86_64 only?
Anthropic's direct-download endpoint only serves x86_64. An `aarch64` build exists in their apt repo; if you need it, fetch that `.deb` yourself and pass it in with `--deb PATH` (the script currently refuses non-x86_64 hosts — patches welcome).

### I see a Wayland/Vulkan warning in the logs
`'--ozone-platform=wayland' is not compatible with Vulkan` is Chromium noise. It's cosmetic.

### The build fails with a Cloudflare 403
The script sends a browser-shaped User-Agent and `Sec-Fetch-*` headers to get past Cloudflare. If Anthropic changes the endpoint, download the `.deb` in a browser and use `--deb PATH`.

### How do I uninstall Claude Desktop from Fedora?
```bash
sudo dnf remove claude-desktop
```

## Credits

- [@sharpandpearl](https://github.com/sharpandpearl) — `build-official.sh` and the analysis of why the Windows repack stopped working ([#4](https://github.com/dewzor/claude-desktop-fedora/pull/4)).
- [@randy-johnson](https://github.com/randy-johnson) — `titleBarOverlay` regex fix on the legacy script ([#3](https://github.com/dewzor/claude-desktop-fedora/pull/3)).

## License

Dual-licensed under MIT and Apache 2.0. See [LICENSE-MIT](LICENSE-MIT) and [LICENSE-APACHE](LICENSE-APACHE).

The Claude Desktop application is not included in this repository and is covered by [Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms).
