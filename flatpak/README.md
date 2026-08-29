# Flatpak

The Flatpak manifest for Claude Desktop lives in its own repo, which is also the Flathub app-id home:

https://github.com/dewzor/ClaudeDesktop

Flathub submission: https://github.com/flathub/flathub/pull/9971

Build it yourself:

```
git clone https://github.com/dewzor/ClaudeDesktop
cd ClaudeDesktop
flatpak-builder --user --install --force-clean build-dir io.github.dewzor.ClaudeDesktop.yaml
```

Once Flathub accepts it, `flatpak install flathub io.github.dewzor.ClaudeDesktop` replaces the build step.
