# Skydex Feeder for macOS — downloads & bundled-decoder sources

**Skydex Feeder** is a native macOS menu bar app that turns an RTL-SDR
stick into an ADS-B feeder: bundled decoder, two-minute setup wizard, no
terminal, no Docker, no Raspberry Pi. It feeds the
[Skydex network](https://feed.skydex.online/) and — deliberately,
non-exclusively — any other network in parallel.

**Product page, screenshots and FAQ: <https://feed.skydex.online/mac>**

## Download

⬇ **<https://feed.skydex.online/download>** — the current signed &
notarized DMG (a stable link that always redirects to the latest
version). Product page: <https://feed.skydex.online/mac>.

- macOS 13 (Ventura) or newer
- Apple silicon and Intel (universal binary)
- Any RTL2832U SDR stick (RTL-SDR v3, FlightAware FlightStick, generic
  DVB-T dongles)
- Free — no tiers, no account required to feed

## What this repository is

The Skydex Feeder app itself is closed-source (its codebase seeds our
mobile app). This repository is the app's public home:

1. **Release notes** — one entry per shipped version, listing the exact
   versions of all bundled components (downloads themselves are served
   from [feed.skydex.online/download](https://feed.skydex.online/download)).
2. **Decoder sources** — the app bundles [readsb](https://github.com/wiedehopf/readsb)
   (GPL-3.0-or-later), statically linked with
   [librtlsdr](https://github.com/osmocom/rtl-sdr) (GPL-2.0-or-later) and
   [libusb](https://github.com/libusb/libusb) (LGPL-2.1). The combined
   `readsb` executable inside the app is distributed under the GPL-3.0,
   and this repo is the corresponding-source offer:
   [`scripts/build-readsb.sh`](scripts/build-readsb.sh) fetches the exact
   upstream sources and reproduces the universal binary we ship,
   unmodified. We carry **no patches** — the decoder is bone-stock; if
   that ever changes, the patches will live in this repo. See
   [LICENSING.md](LICENSING.md).
3. **Issues** — bug reports and feature requests for the app are welcome
   right here, or in our
   [Discord #feeders](https://feed.skydex.online/api/public/feeders/discord)
   channel where a human answers.

## Reproducing the bundled decoder

On macOS with Xcode command line tools:

```sh
brew install cmake autoconf automake libtool pkg-config
./scripts/build-readsb.sh
# → vendor/bin/readsb (universal, ad-hoc signed) + vendor/licenses/
```

The script pins libusb/zstd/librtlsdr versions; the readsb tag used for
each release is recorded in that release's notes.

## What the app sends

The `beast_reduce_plus` stream your stick receives — the same compact
format all community aggregators use — to `feed.skydex.online:30004`,
plus whatever other networks you enable. Nothing else. Diagnostics you
copy manually redact your station key and round your coordinates.

## Verifying a download

Every DMG is signed with our Apple Developer ID and notarized. To check:

```sh
spctl -a -vv -t install "Skydex Feeder.app"   # → accepted, notarized
```

If Gatekeeper shows anything stronger than the standard first-launch
prompt, you are not holding our build — download only from this
repository or [feed.skydex.online/mac](https://feed.skydex.online/mac).
