# Flathub submission

Everything here is prepared but not submitted. Submitting needs a GitHub account
and a few judgment calls, so it stops at this file on purpose.

Source of truth: <https://docs.flathub.org/docs/for-app-authors/submission>
and <https://docs.flathub.org/docs/for-app-authors/requirements>.

## State as of 2026-08-29

Built and installed on Fedora 44 KDE Wayland with flatpak 1.18.1 and
flatpak-builder 1.4.10. The app starts, reaches the claude.ai login page, and
logs `[CCD] Initialized with version 2.1.247`. Renderers run with
`--enable-sandbox` through zypak, so no `--no-sandbox` anywhere.

The Flathub linter was run against both the manifest and the built repo:

```bash
flatpak install -y flathub org.flatpak.Builder
flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest io.github.dewzor.ClaudeDesktop.yaml
flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo repo
```

The manifest lint returns two errors, both of them permissions a reviewer has
to agree to:

```json
{
    "errors": [
        "finish-args-flatpak-spawn-access",
        "finish-args-home-filesystem-access"
    ]
}
```

The repo lint adds the screenshot and app ID errors below. Nothing else was
flagged: no end-of-life runtime, no metainfo problems.

## Four things that need you before any PR

### 1. A GitHub repo whose name matches the app ID

The linter says:

```
appid-url-not-reachable: Tried https://github.com/dewzor/claudedesktop | Status: 404
```

Flathub derives a repository URL from a `io.github.*` ID by taking the last
component as-is. `io.github.dewzor.ClaudeDesktop` therefore has to live at
`https://github.com/dewzor/ClaudeDesktop`, and that repo does not exist yet.

Two ways out, pick one:

- Create `github.com/dewzor/ClaudeDesktop` and put the contents of this
  `flatpak/` directory in it. This is the normal shape for a Flathub app: the
  manifest gets its own repo. Keep the ID as it is.
- Or rename the ID to `io.github.dewzor.claude-desktop-fedora`, which maps to
  this repo. A dash is allowed in the last component. The downside is that the
  Flatpak works on every distro, so a name with "fedora" in it will read wrong
  on the Flathub page forever, and renaming an ID later means resubmitting.

The first option is the recommendation.

### 2. Screenshots

```
metainfo-missing-screenshots
appstream-screenshots-not-mirrored-in-ostree
```

Flathub needs at least one screenshot in the metainfo, served over HTTPS, and
it mirrors them at build time. Take two or three of the running app, one of
them showing the Claude Code tab, commit them to the repo from step 1, and add
this to `io.github.dewzor.ClaudeDesktop.metainfo.xml` just after
`</description>`:

```xml
<screenshots>
  <screenshot type="default">
    <image>https://raw.githubusercontent.com/dewzor/ClaudeDesktop/main/screenshots/code.png</image>
    <caption>Chatting with Claude</caption>
  </screenshot>
  <screenshot>
    <image>https://raw.githubusercontent.com/dewzor/ClaudeDesktop/main/screenshots/code.png</image>
    <caption>Claude Code running in the integrated terminal</caption>
  </screenshot>
</screenshots>
```

Shoot them at 16:9 if you can, and do not include anything private. They end up
on a public store page.

### 3. An exception for home directory access

```
finish-args-home-filesystem-access
```

This one is not a mistake to fix, it is a permission that needs a reviewer to
agree. Say it plainly in the PR: Claude Code and Cowork read and write the
user's own project files, and the agent opens files the user never clicked, so
a portal file chooser cannot express what the app does. Point out that every
other permission in the manifest is narrow, that there is no
`--socket=session-bus` and no `--device=all`.

Flathub may still say no, or ask for `--filesystem=host` to be avoided (it
already is). If they refuse home access the app is not worth shipping without
it, and that is a fair outcome to accept rather than argue.

### 4. An exception for host command execution

```
finish-args-flatpak-spawn-access
```

`--talk-name=org.freedesktop.Flatpak` lets the app run a command on the host.
Claude Code needs it. A Claude Code session runs git, then whatever the project
builds with: node, python, make, the user's own scripts. None of that is in the
freedesktop runtime. Bundling git would not fix this. It would silence the app's
git check while every command still ran against a sandbox holding none of the
user's tools and none of the hooks in their repositories.

The manifest uses it in three narrow places, all visible in `claude-desktop.sh`,
`host-shell.sh`, `host-exec.sh` and `host-git.sh`:

- `$SHELL` points at `/app/bin/host-shell`, so the two places the app reads it
  land on the host: the worker that resolves the login-shell environment, and
  the Claude Code terminal.
- `$CLAUDE_CODE_SHELL_PREFIX` points at `/app/bin/host-exec`. The agent picks
  its own shell by name and only accepts a path containing bash or zsh, so
  `$SHELL` never reaches it. It does wrap every Bash tool command in this
  prefix, so the prefix is what puts the agent's own commands on the host.
- `/app/bin/git` and `/app/bin/git-lfs` are symlinks to a wrapper that runs the
  host's git.

All three are set only after the launcher has probed the portal. If the portal
does not answer, none of them is set and the app falls back to its old
sandbox-only behaviour.

Say in the PR that this is the same permission the VS Code, VSCodium and
JetBrains Flatpaks carry, granted for the same reason, and that it is what makes
the app's coding agent honest rather than merely quiet. Flathub's requirements
already anticipate development tools asking for it.

The helper is [host-spawn](https://github.com/1player/host-spawn), MIT, built
from a pinned release tarball with its three Go dependencies vendored from
pinned tarballs, so the build stays offline. It is used instead of
`flatpak-spawn` because it allocates a pseudo-terminal for the host process and
forwards window-size changes and signals, which the Claude Code terminal needs.

## Two risks worth knowing before you spend the time

**Someone else may get there first.** gordonmessmer already maintains a
`com.anthropic.Claude` manifest in public. Flathub rejects duplicate
submissions of the same app, and an ID under `com.anthropic.` would be the
better one if Anthropic ever verifies it. If he submits, ours is the duplicate.
Worth opening an issue on his repo and asking what he plans before doing the
work twice.

**Claude Desktop contains a coding agent with a terminal.** Flathub's
requirements say development tools, terminals and IDEs "are generally not
well-suited for Flatpak due to inherent sandboxing limitations" and are
normally only accepted from upstream. A reviewer may read Claude Code that way.
The counter-argument is that Claude Desktop is a chat app first and works fully
inside the sandbox, which the build on Fedora 44 shows. Have it ready.

Third party submissions of proprietary apps are allowed as long as the app's
terms do not block it. Anthropic's consumer terms are at
<https://www.anthropic.com/legal/consumer-terms>. Read them once yourself
before submitting; that is not a call for an agent to make.

## The submission itself

Once the three gates above are cleared:

```bash
gh repo fork --clone flathub/flathub
cd flathub
git checkout --track origin/new-pr
git checkout -b claude-desktop-submission new-pr
```

Copy in the manifest and everything it references, so the branch holds:

```
io.github.dewzor.ClaudeDesktop.yaml
io.github.dewzor.ClaudeDesktop.metainfo.xml
io.github.dewzor.ClaudeDesktop.desktop
claude-desktop.sh
host-shell.sh
host-exec.sh
host-git.sh
icons/claude-desktop-16.png
icons/claude-desktop-32.png
icons/claude-desktop-48.png
icons/claude-desktop-128.png
icons/claude-desktop-256.png
flathub.json
```

`flathub.json` does not exist yet. Create it with this, because Anthropic only
publishes an x86_64 Linux build:

```json
{
  "only-arches": ["x86_64"]
}
```

Do not set `disable-external-data-checker`. The manifest already carries
`x-checker-data` of type `rotating-url` pointing at Anthropic's latest-build
redirect, which is what lets Flathub open update pull requests on its own.

Then:

```bash
git add .
git commit -m "Add io.github.dewzor.ClaudeDesktop"
git push -u origin claude-desktop-submission
```

Open the pull request against the `new-pr` branch, not `master`. Title it
exactly:

```
Add io.github.dewzor.ClaudeDesktop
```

## PR body

Fill in the template Flathub puts in the PR, do not delete it, and use this as
the description part:

> Claude Desktop is Anthropic's desktop client for Claude. It does chat, an
> integrated coding agent called Claude Code, and a longer-running task mode
> called Cowork.
>
> This is a third party submission. I am not affiliated with Anthropic. The
> application is proprietary, so nothing proprietary is redistributed here: the
> manifest uses `extra-data` and Flatpak downloads Anthropic's official `.deb`
> on the user's machine at install time. `x-checker-data` follows Anthropic's
> published latest-build redirect, so the external data checker can keep the
> version current.
>
> Built and tested on Fedora 44, KDE Plasma on Wayland. The app starts, signs
> in, and logs `[CCD] Initialized`. Renderers run under zypak with
> `--enable-sandbox`; there is no `--no-sandbox` anywhere.
>
> On permissions, two need an exception and I would like to ask for both.
>
> `--filesystem=home`: Claude Code and Cowork read and write the user's project
> files, and the agent opens files the user never picked in a dialog, so the file
> chooser portal cannot cover it.
>
> `--talk-name=org.freedesktop.Flatpak`: Claude Code is a coding agent. Its
> sessions run git, and then whatever the project builds with. None of that is in
> the runtime. Bundling git would only silence the app's git check while every
> command still ran against a toolless sandbox. The app uses the portal in three
> places: `$SHELL` points at a wrapper that runs the user's host shell,
> `$CLAUDE_CODE_SHELL_PREFIX` points at a wrapper that runs the agent's own
> commands on the host, and `/app/bin/git` is a wrapper that runs the host's
> git. The helper is host-spawn (MIT), built from source with vendored
> dependencies. This is the same permission the VS Code, VSCodium and JetBrains
> Flatpaks carry.
>
> Everything else is narrow: no `--socket=session-bus`, no `--device=all`.
> `--device=kvm` is there because Cowork can run tasks in a VM; without it that
> one feature is unavailable and the rest still works.
>
> The manifest is based on gordonmessmer's com.anthropic.Claude
> (https://github.com/gordonmessmer/com.anthropic.Claude), which bundles the
> payload at build time. This version switches to `extra-data` so it can be
> hosted here.

## After a merge

You get write access to a new `flathub/io.github.dewzor.ClaudeDesktop` repo.
Accept the invite within a week and turn on 2FA on GitHub first, or it lapses.
Updates then arrive as bot pull requests from the external data checker; you
review and merge them. Updates never go through the submission process again.
