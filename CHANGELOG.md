# Changelog

What changed in each shipped build of Skydex Feeder, with the exact
versions of every bundled component and the SHA-256 of the DMG served at
<https://feed.skydex.online/download> — so you can verify that what you
downloaded is what is declared here:

```sh
shasum -a 256 SkydexFeeder-<version>.dmg
```

## 0.1.1 — 2026-08-08

**Feed other networks without touching a config file.** Settings gained an
"Also feed other networks" section: toggles for adsb.lol, airplanes.live,
adsb.fi and ADSBExchange, a feeder-UUID field with a Generate button, a
link to each network's registration page, and "Add custom…" for anything
else that accepts a beast stream. Previously this meant hand-editing
`extraConnectors` in `config.json`; hand-editing still works and the two
stay in sync.

**Station key field.** The UUID from "Connect a receiver" now has a home
in Settings and in the setup wizard, and accepts either the bare UUID or
the whole connector line copied from the site.

**Fixed: the wizard hung forever on "Use My Location"** (macOS silently
refuses the location prompt without the right entitlement and never calls
back; the fetch also gained timeouts).

**"Open Skydex Live Map" opens the coverage map** (tar1090) instead of
the game — what a feeder wants from that menu item is whether their own
antenna is showing up.

**Artifact:**

| | |
| --- | --- |
| File | `SkydexFeeder-0.1.1.dmg` |
| SHA-256 | `985231b07405645b52b4d3fdc0f0772e72507a05472d8e11f29e2356cb893eb0` |
| Signed / notarized | Developer ID Application: Essotek, TOV · notarized by Apple |

**Bundled components (corresponding source):**

| Component | Version |
| --- | --- |
| readsb | 3.16.15 — wiedehopf git `v3.16-84-g05df27d` (commit `05df27d`) |
| librtlsdr | v2.0.2 |
| libusb | 1.0.30 |
| zstd | 1.5.6 |

Reproduce with [`scripts/build-readsb.sh`](scripts/build-readsb.sh)
(pin `READSB_REF` to the commit above). No patches are applied.

*Known erratum:* the license README inside this build's
`Contents/Resources/licenses/` mislabels readsb as BSD-3-Clause; readsb
is GPL-3.0-or-later and the combined executable is GPL-3.0 (see
[LICENSING.md](LICENSING.md)). The text is corrected for the next build;
the actual license texts bundled alongside it are the correct upstream
ones.

## 0.1.0 — 2026-08-08

First public build. Menu bar app (no Dock icon) supervising a bundled
universal `readsb`: three-step setup wizard, gray/orange/green/red
status, automatic restart with backoff, crash-loop detection with "Copy
Diagnostics", launch-at-login, local beast output on port 30005 for
fr24feed/rbfeed. Notarized DMG, macOS 13+, Apple silicon and Intel.
Superseded by 0.1.1 the same day; the 0.1.0 DMG is no longer served.
