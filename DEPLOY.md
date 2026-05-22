# Deploy — Connect IQ Store

The store package is a `.iq` file (the `.prg` is only for simulator / sideload).

## Build the package

    ./scripts/dev.sh package

This runs `monkeybrains.jar` with `-e` (package) and `-r` (release / strip debug),
signed with the developer key.

## Upload

Upload `bin/GarminPrayerTimes.iq` manually to the Connect IQ Store developer
dashboard. There is no CI/CD.

## Critical: signing key

Every version MUST be signed with the original developer key at
`~/Library/Application Support/Garmin/ConnectIQ/developer_key`.
A different keypair fails the store signature check.
