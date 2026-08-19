# Claude Desktop for Fedora 44

A native [Claude Desktop](https://claude.ai) build for **Fedora Linux** — auto-downloads the latest version from Anthropic, bundles Electron 37, fixes the titlebar gap at the source, and packages it as a proper Fedora RPM. Tested on **Fedora 43** and **Fedora 44** with KDE Plasma (Wayland and X11). Should also work on GNOME — see notes below.

> Unofficial build. If you hit a bug, open an issue here — don't bug Anthropic about it.

![Claude Desktop running on Fedora with MCP servers connected](https://github.com/user-attachments/assets/93080028-6f71-48bd-8e59-5149d148cd45)

## Current versions need the official Linux build

Claude Desktop now publishes an **official Linux x86_64 build**, and recent
releases can no longer be served by repacking the Windows installer.

Two native modules are the blocker:

- **`@ant/claude-native`** — the app hard-requires it for filesystem
  containment and explicitly refuses to degrade without it:
  `@ant/claude-native is required for safe-fs containment but failed to load;
  refusing to fall back to a path-based open (CC-2885)`. The JS stub this
  script installs cannot satisfy that, and the module also moved from
  `claude-native` to `@ant/claude-native`, so a stub at the old path is never
  loaded. In a Windows repack the real module is a PE32+ DLL:
  `ERR_DLOPEN_FAILED: invalid ELF header`.
- **`node-pty`** — Claude Code's terminal needs `prebuilds/linux-x64/pty.node`.
  The Windows package ships only `prebuilds/win32-x64/conpty.node`.

Net effect on a current release built from the Windows installer: the app
starts, but **the Claude Code tab does not work**.

`build-official.sh` builds an RPM from Anthropic's official Linux `.deb`
instead, where both modules are real ELF x86-64 objects:

```bash
./build-official.sh
sudo dnf install build/official/claude-desktop-*.rpm
```

The payload is unmodified upstream content, so none of the `app.asar` patching
in `build-fedora.sh` is needed — including the titlebar work, since the official
build already draws a correct native frame. Two Debian-specific `postinst`
behaviours are dropped: the AppArmor `flags=(unconfined)` userns profile (only
needed on Ubuntu 24.04+, which restricts unprivileged userns; Fedora does not)
and apt repo registration. `chrome-sandbox` stays setuid `4755` and the Chromium
sandbox stays enabled — no `--no-sandbox`, and no launcher wrapper.

`build-fedora.sh` is unchanged and still builds 0.14.x-era releases if you need
one.

## What works

| Feature | Status |
| --- | --- |
| Fedora 43 | Tested |
| Fedora 44 | Tested |
| KDE Plasma | Native window frame |
| GNOME | Likely works (X11 backend, untested) |
| Ctrl+Alt+Space global popup | Working |
| System tray | Working |
| MCP (Model Context Protocol) | Supported |
| Google Sign-In | Native module stub |
| Auto-download latest Claude | Yes — official redirect URL |
| Bundled Electron 37 | No system-Electron conflicts |
| Titlebar gap | Fixed at source (v8) |

## Quick install

```bash
# Install build dependencies (the script will install missing ones automatically)
sudo dnf install rpm-build p7zip nodejs npm

# Clone and build
git clone https://github.com/dewzor/claude-desktop-fedora.git
cd claude-desktop-fedora
chmod +x build-fedora.sh
sudo ./build-fedora.sh

# Install the RPM that the build produced
sudo dnf install build/electron-app/$(uname -m)/claude-desktop-*.rpm

# Launch
claude-desktop
```

The script fetches the latest Claude Desktop from Anthropic's official redirect URL — no version pinning required. Re-run anytime to update.

## What v8 fixes

The 36px titlebar gap that appeared in earlier builds is fixed at the source.

Claude Desktop's bundled JavaScript reserves 36px for a Windows-style titlebar via ternary patterns like `oR=hn?0:36`. v8 patches those constants from `36` to `0` so the gap doesn't render in the first place. A CSS backup with a negative-margin rule covers any residual pixels.

Other things v8 ships:

- **Auto-download latest Claude Desktop** via Anthropic's official redirect URL (no manual version updates, browser-style headers bypass Cloudflare blocks)
- **Bundled Electron v37.0.0** — avoids GTK/Wayland conflicts with Fedora 42+ system Electron
- **Native window frame** on KDE Plasma (no double titlebar)
- **Menu bar removed**
- **Window maximize / resize** forced relayout fix
- **Google Sign-In** via Linux native module stub
- **IPC origin validation** fix for `file://` URLs
- **GPU sandbox disabled** in the launcher for Wayland stability

![Ctrl+Alt+Space global popup on Fedora Linux](https://github.com/user-attachments/assets/1deb4604-4c06-4e4b-b63f-7f6ef9ef28c1)

![Claude Desktop tray menu on KDE Plasma](https://github.com/user-attachments/assets/ba209824-8afb-437c-a944-b53fd9ecd559)

## Requirements

- Fedora 43 or Fedora 44 (works on Fedora 41+, actively tested on 43 and 44)
- Node.js ≥ 12 and npm
- Root / sudo for dependency install and RPM install

`rpm-build`, `p7zip`, `wrestool`, `icotool`, `imagemagick`, and `sqlite3` are pulled in by the build script automatically with `dnf`.

## Updating

Re-run the build:

```bash
sudo ./build-fedora.sh
sudo dnf install build/electron-app/$(uname -m)/claude-desktop-*.rpm
```

The script always fetches the latest version. To pin a specific Claude Desktop version (testing or compatibility), edit `CLAUDE_DOWNLOAD_URL` at the top of `build-fedora.sh`.

## MCP setup

MCP (Model Context Protocol) servers are configured at:

```
~/.config/Claude/claude_desktop_config.json
```

Same format as macOS and Windows Claude Desktop — drop in your `mcpServers` block and restart the app.

## How it works

Claude Desktop ships as an Electron app wrapped in a Windows installer. The build script:

1. Downloads the official Windows installer from Anthropic (always-latest redirect URL)
2. Extracts `app.asar` and resources
3. Replaces the Windows-only `claude-native-bindings` module with a Linux-compatible JavaScript stub
4. Patches the bundled JS:
   - Titlebar height constants (`?0:36` → `?0:0`)
   - `titleBarStyle` configuration for native window frame
   - Menu bar removal
   - Window resize / maximize handlers
   - Google Sign-In native module stub
5. Adds CSS overrides as a backup for any residual titlebar pixels
6. Bundles standalone Electron 37.0.0 inside the package
7. Packs everything into a Fedora RPM with desktop entry, icons, and proper dependencies

### Native module replacement

The only platform-specific component in Claude Desktop is `claude-native-bindings` — a native Node module that provides:

- Keyboard input (the Ctrl+Alt+Space popup)
- Window management
- System tray integration
- Monitor enumeration

The Linux stub matches the original API surface, implements keyboard handling with correct X11 key codes, and stubs out Windows-only calls. The rest of Claude Desktop runs unmodified — it doesn't know it's not on Windows.

### Launcher

`/usr/bin/claude-desktop` starts the bundled Electron with:

- `GDK_BACKEND=x11` and `GTK_USE_PORTAL=0` — avoids GTK conflicts on Fedora 42+ Wayland sessions
- `--ozone-platform=x11` — forces the stable X11 backend
- `--disable-gpu-sandbox --no-sandbox` — required for unprivileged user launch
- File-based logging at `~/.claude-desktop.log`

## FAQ

### Does this work on Fedora 43?
Yes, tested.

### Does this work on Fedora 44?
Yes — tested on Wayland (KDE Plasma) and X11.

### How do I fix the double titlebar / titlebar gap on KDE?
v8 fixes it at the source. Rebuild with `sudo ./build-fedora.sh`.

### Does MCP (Model Context Protocol) work?
Yes. Config lives at `~/.config/Claude/claude_desktop_config.json`.

### Does the Ctrl+Alt+Space popup work?
Yes — handled by the Linux native module stub.

### Does Google Sign-In work?
Yes — via a Linux-compatible native module stub.

### Does it work on GNOME?
Probably, but it's not actively tested. The build is KDE Plasma-focused — the v8 titlebar fix targets the gap that appears under KDE, and the launcher forces XWayland (`--ozone-platform=x11`, `GDK_BACKEND=x11`) which works on GNOME Wayland too. Two caveats:
- GNOME under Wayland uses Mutter for window decorations on XWayland apps. The native frame should render, but exact appearance depends on your Mutter version.
- Portals are disabled (`GTK_USE_PORTAL=0`), which can affect file pickers, screen sharing, and notifications on GNOME more than on KDE.

If you try it on GNOME, open an issue with what you see — the README will get more honest over time.

### Will it work on Fedora 41 or 42?
The script targets any Fedora-based distro (checks `/etc/fedora-release` and `/etc/os-release`). 41 and 42 should work — they're not actively tested, but the build is generic enough.

### Why bundle Electron 37 instead of using the system Electron?
Fedora 42+ ships system Electron versions that conflict with Claude's Windows build (GTK/Wayland crashes). Bundling Electron 37 inside the RPM avoids the conflict entirely.

### How do I uninstall?
```bash
sudo dnf remove claude-desktop
```

## License

Dual-licensed under MIT and Apache 2.0. See [LICENSE-MIT](LICENSE-MIT) and [LICENSE-APACHE](LICENSE-APACHE).

The Claude Desktop application is not included in this repository and is covered by [Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms).

> Note: The build script was originally generated with Claude's assistance.
