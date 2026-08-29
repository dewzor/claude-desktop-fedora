# Claude Desktop for Fedora 44

Install **Claude Desktop on Fedora 44** as a native RPM, built from Anthropic's **official Linux x86_64 build**. Unmodified upstream payload, Chromium sandbox on, Claude Code and Cowork working. Tested on Fedora 44 with KDE Plasma (Wayland) and GNOME (Wayland); should work on Fedora 43 and later.

**TL;DR:** `./build-official.sh && sudo dnf install build/official/claude-desktop-*.rpm`

> Unofficial packaging. Anthropic ships the app; this repo only rewraps it for `dnf`. If you hit a packaging bug, open an issue here, not with Anthropic.

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

## Auto-updates via COPR

```bash
sudo dnf copr enable dewzor/claude-desktop
sudo dnf install claude-desktop-builder
```

`claude-desktop-builder` is a small MIT-licensed package. It does not contain Claude Desktop, and it never will. Claude Desktop is proprietary, so no repository is allowed to ship it. What the package ships is the build itself: `build-official.sh`, a `claude-desktop-update` command, and a systemd timer.

The timer runs once a day. It asks Anthropic's download endpoint which Linux build is current. If that build is already installed, it stops there and downloads nothing. If a newer build has shipped, it fetches Anthropic's own `.deb` on your machine, repackages the payload as an RPM, and installs it with `dnf`. You get exactly the package `build-official.sh` produces by hand, without having to remember to run it.

Run it yourself any time:

```bash
sudo claude-desktop-update --check   # says whether a new build exists
sudo claude-desktop-update           # rebuilds and installs if there is one
```

Removing the package leaves Claude Desktop alone:

```bash
sudo dnf remove claude-desktop-builder
```

## Flatpak

There is a Flatpak manifest in `flatpak/`. It builds Claude Desktop for any distro
that runs Flatpak, not just Fedora.

```bash
cd flatpak
./build.sh
flatpak run io.github.dewzor.ClaudeDesktop
```

The build itself is small. The application is an `extra-data` source, so Flatpak
downloads Anthropic's official `.deb` on your machine at install time and unpacks it
there. Nothing proprietary is redistributed. That is the same approach Flathub uses
for Spotify and Slack.

Flathub submission is pending. `flatpak/FLATHUB-SUBMISSION.md` has the steps and the
four things that still need a human: a repo named to match the app ID, screenshots, and
reviewer exceptions for home directory access and for running commands on the host.

The Code tab runs on the host through the Flatpak portal, the same way the VS Code
Flatpak does it. Your shell, your `PATH`, your git and your project tools are the real
ones, not the runtime's.

The sandbox trade-off, in short. The RPM keeps Chromium's setuid sandbox and otherwise
runs with your full user rights; the Flatpak drops the setuid helper and sandboxes the
renderers with zypak instead, which works and needs no `--no-sandbox`. In exchange the
whole app runs inside the Flatpak sandbox, and because Claude Code and Cowork open
files you never clicked, the manifest asks for `--filesystem=home`, so the sandbox
protects your system but not your home directory. `--talk-name=org.freedesktop.Flatpak`
is the second broad permission, and it is what lets the Code tab reach the host.

Two things behave differently from the RPM. MCP servers are started by the app itself
rather than through your shell, so one that calls `npx` may still not find it. Claude
Desktop keeps its config and logs at
`~/.var/app/io.github.dewzor.ClaudeDesktop/config/Claude/` instead of `~/.config/Claude/`,
so the two installs do not share a login.

The manifest follows [gordonmessmer's com.anthropic.Claude](https://github.com/gordonmessmer/com.anthropic.Claude),
which worked out the finish args and the zypak launcher. His version bundles the payload
at build time. This one uses `extra-data` so it can go to Flathub.

## What works on Fedora 44

| Feature | Status |
| --- | --- |
| Fedora 44, KDE Plasma (Wayland) | Tested |
| Fedora 44, GNOME (Wayland) | Tested |
| Claude Code tab (integrated terminal) | Working |
| Cowork | Working |
| MCP (Model Context Protocol) | Working |
| Chrome extension MCP bridge | Working |
| Native window frame | Yes, no patching needed |
| Chromium sandbox | Enabled (`chrome-sandbox` setuid 4755, no `--no-sandbox`) |
| System tray | Working |
| Auto-download latest Claude | Yes, via the official redirect URL |
| Architecture | x86_64 only (see FAQ) |
| Auto-update | Optional, via the `claude-desktop-builder` COPR package |

## How the Fedora RPM is built

Anthropic publishes an official Linux build of Claude Desktop, but only as a `.deb`. The payload inside is ordinary, self-contained Linux content under `/usr/lib/claude-desktop`. Nothing in it is Debian-specific except the wrapper and dependency names.

`build-official.sh`:

1. Resolves and downloads the current official `.deb` from `https://claude.ai/api/desktop/linux/x64/deb/latest/redirect` (~165 MB; browser-shaped UA to satisfy Cloudflare)
2. Unpacks it and reads the version from the control file
3. Verifies that `@ant/claude-native` and `node-pty` are real ELF x86-64 objects, and fails loudly if not
4. Maps the Debian dependencies to Fedora package names
5. Builds an RPM with `rpmbuild`, preserving `chrome-sandbox` setuid via `%attr(4755,root,root)`
6. Confirms the setuid bit survived into the package metadata

The payload is **unmodified upstream content**. No `app.asar` patching, no stubs, no injected CSS, no launcher wrapper.

Two Debian-specific `postinst` behaviours are intentionally dropped:

- The AppArmor `flags=(unconfined)` userns profile. That one is only needed on Ubuntu 24.04+, which restricts unprivileged user namespaces. Fedora leaves them enabled.
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

Same format as macOS and Windows Claude Desktop. Drop in your `mcpServers` block and restart the app.

Logs live in `~/.config/Claude/logs/` (`main.log`, `mcp.log`, `ssh.log`, …).

## Why not the Windows repack any more?

Earlier versions of this repo (`build-fedora.sh`, still in the tree) rebuilt Claude Desktop from the **Windows installer**: extract `app.asar`, swap the native module for a JS stub, patch the titlebar constants, bundle Electron 37. That worked through the 0.14.x era. Current releases can't be served that way:

- **`@ant/claude-native`** is now hard-required for filesystem containment, and the app explicitly refuses to degrade without it:
  `@ant/claude-native is required for safe-fs containment but failed to load; refusing to fall back to a path-based open (CC-2885)`.
  A JS stub can't satisfy that, and the module also moved from `claude-native` to `@ant/claude-native`, so the old stub path is never even loaded. In a Windows repack the real module is a PE32+ DLL: `ERR_DLOPEN_FAILED: invalid ELF header`.
- **`node-pty`**: Claude Code's terminal needs `prebuilds/linux-x64/pty.node`. The Windows package only ships `prebuilds/win32-x64/conpty.node`.

Net effect: the app starts, but **the Claude Code tab does not work**. The official Linux build ships both modules as real ELF x86-64 objects, and its native frame is already correct, so none of the old patching is needed.

## Troubleshooting on Fedora 44

Exact error strings and what they mean. All of these are fixed by building with `build-official.sh`.

### `@ant/claude-native is required for safe-fs containment but failed to load` / `CC-2885`
You're running a Windows-repack build (`build-fedora.sh` or any of the older Fedora scripts). Current Claude Desktop hard-requires the real native module and refuses to start Claude Code without it. Rebuild from the official Linux build.

### `ERR_DLOPEN_FAILED: invalid ELF header` / `Failed to load Claude Native`
The `claude-native-binding.node` in your install is a Windows PE32+ DLL, not a Linux ELF object. Same cause as above, a Windows repack. Rebuild with `build-official.sh`; it verifies both native modules are ELF x86-64 before packaging.

### Claude Code tab not working / blank / terminal never appears
Claude Code's terminal needs `node-pty`'s `prebuilds/linux-x64/pty.node`. Windows packages only ship `win32-x64/conpty.node`. Rebuild from the official Linux build and check `~/.config/Claude/logs/main.log` for `[CCD] Initialized`.

### `⚠ titleBarStyle pattern not found` during `build-fedora.sh`
The legacy script's titlebar `sed` no longer matches current releases. It's harmless but it's also a sign you're on the wrong path. The official build already draws a correct native frame. Use `build-official.sh`.

### Build fails with HTTP 403 / Cloudflare page
Anthropic's download endpoint sits behind Cloudflare and rejects non-browser user agents. `build-official.sh` sends a browser-shaped UA. If it still fails, download the `.deb` in a browser and pass `--deb PATH`.

### `'--ozone-platform=wayland' is not compatible with Vulkan`
Chromium noise on Wayland sessions. Cosmetic; ignore.

### Cowork says the VM sandbox is unavailable
Install the optional VM stack: `sudo dnf install qemu-system-x86 edk2-ovmf virtiofsd`. The RPM lists these as `Suggests:`.

### Package conflicts with `claude-desktop-unofficial`
That's [aaddrick/claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian)'s RPM, which adds a launcher wrapper and a `--doctor`. Both packages share `~/.config/Claude`, so run one or the other, not both.

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
Yes, tested on Fedora 44 with KDE Plasma (Wayland) and GNOME (Wayland).

### Does it work on Fedora 43 or older?
It should. The payload is self-contained (bundled Electron), so the only real constraint is the runtime dependency list, which resolves on 43. Not actively tested. If you try it, open an issue with what you see.

### Does the Claude Code tab work?
Yes. That's the whole point of the official-build path. Look for `[CCD] Initialized` in `~/.config/Claude/logs/main.log`.

### Does Cowork work?
Yes. Cowork's optional full-VM sandbox needs `qemu-system-x86`, `edk2-ovmf` and `virtiofsd`; they're listed as `Suggests:` in the RPM and are harmless to omit.

### Does MCP work?
Yes. Config lives at `~/.config/Claude/claude_desktop_config.json`.

### Why x86_64 only?
Anthropic's direct-download endpoint only serves x86_64. An `aarch64` build exists in their apt repo; if you need it, fetch that `.deb` yourself and pass it in with `--deb PATH` (the script currently refuses non-x86_64 hosts, patches welcome).

### I see a Wayland/Vulkan warning in the logs
`'--ozone-platform=wayland' is not compatible with Vulkan` is Chromium noise. It's cosmetic.

### The build fails with a Cloudflare 403
The script sends a browser-shaped User-Agent and `Sec-Fetch-*` headers to get past Cloudflare. If Anthropic changes the endpoint, download the `.deb` in a browser and use `--deb PATH`.

### How do I uninstall Claude Desktop from Fedora?
```bash
sudo dnf remove claude-desktop
```

## Credits

- [@sharpandpearl](https://github.com/sharpandpearl): `build-official.sh` and the analysis of why the Windows repack stopped working ([#4](https://github.com/dewzor/claude-desktop-fedora/pull/4)).
- [@randy-johnson](https://github.com/randy-johnson): `titleBarOverlay` regex fix on the legacy script ([#3](https://github.com/dewzor/claude-desktop-fedora/pull/3)).
- [@gordonmessmer](https://github.com/gordonmessmer): the [com.anthropic.Claude](https://github.com/gordonmessmer/com.anthropic.Claude) Flatpak manifest that the one in `flatpak/` is based on.

## License

Dual-licensed under MIT and Apache 2.0. See [LICENSE-MIT](LICENSE-MIT) and [LICENSE-APACHE](LICENSE-APACHE).

The Claude Desktop application is not included in this repository and is covered by [Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms).
