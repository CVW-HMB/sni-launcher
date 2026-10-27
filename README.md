# SNI Launcher

A small macOS app for starting [SNI](https://github.com/CVW-HMB/sni) and the Super Nintendo File Manager
([SNFM](https://github.com/CVW-HMB/snfm)) from one window.

- **Start SNI / Restart SNI** starts SNI, or restarts it if it is already running. Restarting stops every
  running SNI, including copies started some other way, since they all listen on the same ports.
- **Open File Manager** starts SNI first if needed, then opens SNFM, or brings it to the front if it is
  already open.

Closing the launcher leaves SNI running in the menu bar.

## What's inside

`SNI Launcher.app` carries both apps in `Contents/Resources`:

- `SNI.app`: SNI from the `macos-fxpak-fixes` branch of [CVW-HMB/sni](https://github.com/CVW-HMB/sni),
  which includes the FXPak Pro USB fixes and keeps App Nap from stalling USB while SNI sits in the menu bar.
- `SNFM.app`: `manage_files` from the `manage-files-fixes` branch of
  [CVW-HMB/snfm](https://github.com/CVW-HMB/snfm/tree/manage-files-fixes), which fixes rename (the old name
  showing through the edit box, non-ASCII names, Rename also triggering Refresh), right-click targeting,
  deleting a folder together with its contents, and device selection, and adds a delete confirmation and
  macOS menu icons.

Everything is universal (Apple Silicon and Intel) and needs macOS 15 (Sequoia) or later.

## Install

Download the zip from [Releases](https://github.com/CVW-HMB/sni-launcher/releases), unzip it, and move
`SNI Launcher.app` wherever you like (the Desktop or Applications).

The app is not signed with an Apple Developer ID, so macOS blocks it the first time. Either right-click it,
choose **Open**, then **Open** again, or run:

```
xattr -dr com.apple.quarantine "SNI Launcher.app"
```

## Windows

`SNI-Launcher-v<version>-windows-x64.zip` has `SNI Launcher.exe` (same buttons as the macOS app) next to SNI
and SNFM from the [CVW-HMB/sni `v0.0.104-fxpak1`](https://github.com/CVW-HMB/sni/releases/tag/v0.0.104-fxpak1)
release. Unzip it anywhere and run `SNI Launcher.exe`.

- The `manage_files.exe` in the Windows zip is upstream's build; the SNFM fixes above are not in it yet,
  because the Windows build needs Visual Studio.
- `manage_files.exe` needs the [Microsoft Visual C++ Redistributable (x64)](https://aka.ms/vs/17/release/vc_redist.x64.exe).
  Without it, it does not start.
- The exes are not code-signed, so Windows SmartScreen may warn the first time: choose **More info**, then
  **Run anyway**.

## Building

The scripts expect sibling checkouts:

```
alttpr/
  sni/            CVW-HMB/sni, branch macos-fxpak-fixes
  snfm/           CVW-HMB/snfm, branch manage-files-fixes, with the sni submodule initialised
  vcpkg/          microsoft/vcpkg, bootstrapped
  sni-launcher/   this repo
```

Requirements: Xcode (for `swiftc`), Go, and Homebrew `cmake ninja pkg-config autoconf automake
autoconf-archive libtool`.

```
./build-snfm.sh          # universal SNFM.app; the first run builds gRPC, protobuf and wxWidgets
./build.sh --zip         # SNI Launcher.app plus the release zip in out/
./build.sh --install     # also copy it to the Desktop
./build-windows.sh       # Windows zip in out/; SNFM_EXE=path/to/manage_files.exe swaps in another SNFM
```

`build-windows.sh` cross-compiles the launcher in `windows/` (Go, lxn/walk) and needs `go-winres`
(`go install github.com/tc-hib/go-winres@latest`).

The version comes from `VERSION`.
