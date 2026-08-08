# Licensing

Three different things live under the Skydex Feeder name; they carry
different licenses. This file is the map.

## 1. The Skydex Feeder app (the DMG's `.app`, minus the decoder)

Proprietary, © Skydex. Free to download and use; not open source. It
never links the libraries below — the decoder runs as a separate,
supervised process.

## 2. The bundled decoder (`Contents/Resources/bin/readsb`)

A combined work distributed under the **GPL-3.0**:

| Component | Upstream | License |
| --- | --- | --- |
| readsb | <https://github.com/wiedehopf/readsb> | GPL-3.0-or-later |
| librtlsdr | <https://github.com/osmocom/rtl-sdr> | GPL-2.0-or-later (statically linked) |
| libusb | <https://github.com/libusb/libusb> | LGPL-2.1 (statically linked) |
| zstd | <https://github.com/facebook/zstd> | BSD-3-Clause / GPL-2.0 dual (statically linked) |

librtlsdr's "or later" clause is what makes the GPL-2 + GPL-3 static
link compatible; the resulting executable is GPL-3.0.

**Corresponding source:** we ship readsb unmodified, with zero patches.
[`scripts/build-readsb.sh`](scripts/build-readsb.sh) in this repository
fetches the pinned upstream sources and reproduces the exact universal
binary found in the DMG; the readsb tag used by each release is recorded
in that release's notes. Full license texts are also installed inside
the app bundle at `Contents/Resources/licenses/`.

## 3. This repository's own content

The build script, this documentation and everything else committed here
is released under the **MIT License** (see [LICENSE](LICENSE)) — use the
build recipe however you like.
