# Cutting a release

Operator checklist — public on purpose (nothing here is secret, and the
process being visible is part of the trust story).

1. In the app repo: pin `READSB_REF` in `scripts/build-readsb.sh` to an
   exact readsb tag (never release off `latest` — the release notes must
   name the tag), sync the copy of the script into this repo, bump
   `MARKETING_VERSION` in `project.yml`, then build:

   ```sh
   make test && ./scripts/release-local.sh
   ```

   That signs with the Developer ID, notarizes and staples locally. (Tagging
   `vX.Y.Z` runs the same steps in CI once the signing secrets are set; the
   local script exists so a release doesn't depend on that, and so a
   notarization failure can be debugged interactively.)
2. Verify the artifact locally before publishing:
   ```sh
   xcrun stapler validate "Skydex Feeder.dmg"
   spctl -a -vv -t install "Skydex Feeder.app"   # accepted · notarized
   ```
3. Publish the download (self-hosted from the site VPS): commit the DMG
   as `feedsite/download/SkydexFeeder-X.Y.Z.dmg` in the site repo and
   bump the version in the `location = /download` redirect on the feed
   vhost (`nginx/conf.d/default.conf`) — that one line is the whole
   publish step; <https://feed.skydex.online/download> always points at
   the current version. After deploy, verify the redirect serves
   `application/x-apple-diskimage`, not `text/html`.
4. Update the pages that state a version or a claim:
   `feedsite/mac.html` (the version line in the hero **and** the "What's new"
   list), `feedsite/mac-changelog.html`, and `CHANGELOG.md` here. A download
   page that names the previous version is worse than one that names none.
5. Create a GitHub release **in this repo** for the same `vX.Y.Z` tag —
   release notes only (assets optional, as a mirror). Notes must include
   the bundled-components table (this is the GPL source-offer
   precision):

   | Component | Version |
   | --- | --- |
   | readsb | vX.Y.Z (tag) |
   | librtlsdr | v2.0.2 |
   | libusb | 1.0.30 |
   | zstd | 1.5.6 |

   …plus user-facing changes, in plain words.
6. v0.2+: update the Sparkle appcast in this repo after the release
   assets are up (appcast entries point at the archival-name asset, not
   the stable-name one).
