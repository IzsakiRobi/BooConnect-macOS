<p align="center">
<img width="412" height="462" align="center" alt="Teaser" src="https://github.com/IzsakiRobi/BooConnect-macOS/blob/main/Screenshots/Teaser.png?raw=true" />
</p>

# BooConnect for macOS

**BooConnect** is a small menu bar GUI for OpenConnect / Cisco AnyConnect VPN connections on macOS.

The app is distributed as a portable `.app` bundle with OpenConnect and its required libraries inside the bundle resources.

## Download

The ready-to-run portable app package is included here:

```sh
dist/BooConnect-macOS.zip
```

Unzip it, move `BooConnect.app` wherever you prefer, then launch it.

On first run, open Preferences and set:

```text
Host
User
PIN
Mac Pass
```

`Mac Pass` is used for the local `sudo` prompt because OpenConnect needs elevated privileges.

## Custom vpnc-script

The app does not require a bundled custom script by default.

If you need custom routing or split-DNS behavior, copy:

```sh
BooConnect.app/Contents/Resources/vpnc-script.example
```

to:

```sh
BooConnect.app/Contents/Resources/vpnc-script
```

Then edit it for your own network. The included example is intentionally generic and contains no company-specific hosts, routes, domains, or DNS data.

## Build

The source lives in:

```text
Source/main.swift
```

To build the GUI wrapper:

```sh
./build.sh
```

The build script creates `BooConnect.app` from the Swift source and resources. It does not build OpenConnect itself.

## Source Layout

```text
Source/main.swift             Swift/AppKit menu bar app
Resources/                    App icons, status icons, alert sound, script example
Packaging/Info.plist          macOS app bundle metadata
dist/BooConnect-macOS.zip     Ready portable app bundle
```

## Notes

- BooConnect keeps OpenConnect attached so it can detect prompts and send PIN/token responses.
- The menu bar icon reflects disconnected, waiting, and connected states.
- The included `vpnc-script.example` is only a starting point for advanced users.

## License

MIT
