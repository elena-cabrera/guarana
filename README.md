# Guarana

A tiny, playful macOS menu bar app that keeps your Mac awake.

**[Website](https://elena-cabrera.github.io/guarana/) · [Download the latest build](https://github.com/elena-cabrera/guarana/releases/latest/download/Guarana.dmg)**

- **Keep awake** with one tap: 15m, 30m, 1h, 2h, 4h, or ∞
- **Custom times**: dial in hours and minutes, then save them as your own chips (hover a chip and click × to forget it)
- **Lid closed: Yes / No**: keeps a MacBook running with the lid shut
- **Screen on: Yes / No**: choose whether the display may sleep
- Open at login, live countdown, and a fruit that opens its eye while it's keeping your Mac awake

## Build

Only the Command Line Tools are needed (no Xcode).

```sh
scripts/build-app.sh   # → build/Guarana.app (universal, ad-hoc signed)
scripts/make-dmg.sh    # → build/Guarana.dmg (the installer)
```

Set `SIGN_IDENTITY="Developer ID Application: …"` to sign for distribution. You still need to notarize before shipping it to other people.

## CI

Every push to `main` runs [`.github/workflows/release.yml`](.github/workflows/release.yml). It builds the app and DMG on macOS, publishes them as a new release (`v1.0.<run number>`, marked latest), and redeploys `site/` to GitHub Pages. The site's download buttons point to `releases/latest/download/Guarana.dmg`, so they always serve the newest build. Pull requests get a build check only.

## Layout

| Path | What |
| --- | --- |
| `Sources/GuaranaArt` | The fruit, drawn in CoreGraphics. Used for the menu bar icon, app icon and installer art |
| `Sources/Guarana` | The app (SwiftUI `MenuBarExtra`) |
| `Sources/GuaranaAssets` | Renders the app icon, DMG background and web images |
| `installer/` | dmgbuild settings for the drag-to-Applications window |
| `site/` | Landing page (static HTML). Put `Guarana.dmg` next to `index.html` when deploying |

`Guarana --snapshot <dir>` renders the popover to PNGs (used for `site/assets`).

## How it works

- Awake: IOKit power assertions (`PreventUserIdleSystemSleep`, plus `PreventUserIdleDisplaySleep` when Screen on is Yes), the same mechanism `caffeinate` uses.
- Lid closed: needs `pmset -a disablesleep 1`, which requires root. The first time you choose Yes, Guarana asks for your admin password once and installs `/etc/sudoers.d/guarana`. That rule allows only `pmset -a disablesleep 1|0`. Guarana restores normal sleep when a session ends, when you quit, and on the next launch after a crash. To remove the rule: `sudo rm /etc/sudoers.d/guarana`.
