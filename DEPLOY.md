# Releasing & Deploying

## Build outputs

| File | Purpose | Built by |
|------|---------|----------|
| `bin/GarminPrayerTimes.prg` | Side-load / simulator — one device | `./scripts/dev.sh build` |
| `bin/GarminPrayerTimes.iq`  | Connect IQ Store package — all devices | `./scripts/dev.sh package` |

`bin/` is **git-ignored** — compiled binaries are not committed. They are
regenerated from source and published as GitHub Release assets (see below).

## 1. Test on a real watch (side-load)

```bash
DEVICE=epix2pro47mm ./scripts/dev.sh build    # use your watch's device id
```

Connect the watch by USB; it mounts as a `GARMIN` drive. Copy
`bin/GarminPrayerTimes.prg` into `GARMIN/Apps/`, eject, and pick **Prayer
Times** from the watch's face list.

Test what the simulator cannot: real GPS, weather sync over Bluetooth, the
live-seconds battery cost, and always-on mode.

## 2. Connect IQ Store

```bash
./scripts/dev.sh package
```

Upload `bin/GarminPrayerTimes.iq` to the
[Connect IQ Store developer dashboard](https://apps.garmin.com). There is no
CI/CD — the upload is manual. Garmin reviews each submission.

**Signing key — critical:** every version MUST be signed with the original
developer key at `~/Library/Application Support/Garmin/ConnectIQ/developer_key`.
A different keypair fails the store signature check. `scripts/dev.sh` always
uses that key.

The beta and the published listing need different `id` values in
`manifest.xml` — the store treats them as separate apps.

## 3. GitHub Release

Tag the version and attach the build artifacts so each release is archived and
downloadable without committing binaries to git:

```bash
./scripts/dev.sh build && ./scripts/dev.sh package
git tag v0.3.0
git push origin v0.3.0
gh release create v0.3.0 \
  bin/GarminPrayerTimes.iq bin/GarminPrayerTimes.prg \
  --title "v0.3.0 — Dynamic & realistic" \
  --notes-from-file CHANGELOG.md
```

Keep the tag in step with [`CHANGELOG.md`](CHANGELOG.md).
