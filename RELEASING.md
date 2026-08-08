# Cutting a release

Operator checklist — public on purpose (nothing here is secret, and the
process being visible is part of the trust story).

1. In the app repo: pin `READSB_REF` in `scripts/build-readsb.sh` to an
   exact readsb tag (never release off `latest` — the release notes must
   name the tag), sync the copy of the script into this repo, tag
   `vX.Y.Z` → CI builds, signs (Developer ID) and notarizes the DMG.
2. Verify the artifact locally before publishing:
   ```sh
   xcrun stapler validate "Skydex Feeder.dmg"
   spctl -a -vv -t install "Skydex Feeder.app"   # accepted · notarized
   ```
3. Create the GitHub release **in this repo**, tag `vX.Y.Z`, and attach
   **two copies** of the artifact:
   - `Skydex-Feeder-X.Y.Z.dmg` — the archival name;
   - `Skydex-Feeder.dmg` — stable name, so
     `…/releases/latest/download/Skydex-Feeder.dmg` is a permanent
     direct-download URL for landing pages.
4. Release notes must include the bundled-components table (this is the
   GPL source-offer precision):

   | Component | Version |
   | --- | --- |
   | readsb | vX.Y.Z (tag) |
   | librtlsdr | v2.0.2 |
   | libusb | 1.0.30 |
   | zstd | 1.5.6 |

   …plus user-facing changes, in plain words.
5. v0.2+: update the Sparkle appcast in this repo after the release
   assets are up (appcast entries point at the archival-name asset, not
   the stable-name one).
