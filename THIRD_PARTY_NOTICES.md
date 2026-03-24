# Third-Party Notices

This repository includes prebuilt third-party tools and dynamic libraries under [`Vendor/libimobiledevice`](Vendor/libimobiledevice).

## Included artifacts

### Executables

- `Vendor/libimobiledevice/bin/idevice_id`
- `Vendor/libimobiledevice/bin/ideviceinfo`
- `Vendor/libimobiledevice/bin/idevicediagnostics`
- `Vendor/libimobiledevice/bin/idevicesyslog`
- `Vendor/libimobiledevice/bin/wificonnection`
- `Vendor/libimobiledevice/bin/comptest`
- `Vendor/libimobiledevice/bin/watchregistryprobe`

### Dynamic libraries

- `Vendor/libimobiledevice/lib/libimobiledevice-1.0.6.dylib`
- `Vendor/libimobiledevice/lib/libimobiledevice-glue-1.0.0.dylib`
- `Vendor/libimobiledevice/lib/libplist-2.0.4.dylib`
- `Vendor/libimobiledevice/lib/libusbmuxd-2.0.7.dylib`
- `Vendor/libimobiledevice/lib/libcrypto.3.dylib`
- `Vendor/libimobiledevice/lib/libssl.3.dylib`

## Upstream projects

### libimobiledevice

- Upstream: https://github.com/libimobiledevice/libimobiledevice
- Used for iPhone / iPad discovery and diagnostics
- Repository license metadata indicates LGPL-2.1 and GPL-2.0 components

### libimobiledevice-glue

- Upstream: https://github.com/libimobiledevice/libimobiledevice-glue
- Shared support library used by the bundled mobile device tooling
- Repository license metadata indicates LGPL-2.1

### libplist

- Upstream: https://github.com/libimobiledevice/libplist
- Used for plist parsing support in the bundled toolchain
- Repository license metadata indicates LGPL-2.1

### libusbmuxd

- Upstream: https://github.com/libimobiledevice/libusbmuxd
- Provides usbmuxd communication support for the bundled toolchain
- Repository license metadata indicates LGPL-2.1, with some GPL-2.0 components in the upstream repository

### OpenSSL

- Upstream: https://github.com/openssl/openssl
- Provides `libcrypto.3.dylib` and `libssl.3.dylib`
- Repository license metadata indicates Apache-2.0

## Local license materials

- Bundled GNU GPL text from the upstream package: [`Vendor/libimobiledevice/COPYING`](Vendor/libimobiledevice/COPYING)

## Distribution note

The application source code in this repository is MIT-licensed, but the bundled third-party binaries remain under their respective upstream licenses. If you redistribute this repository or ship builds containing the bundled `Vendor/libimobiledevice` artifacts, review the upstream license obligations before distribution.
