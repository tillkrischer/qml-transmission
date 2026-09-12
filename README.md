# QML Transmission

A small desktop client for a remote Transmission 4.1+ daemon. The Qt/C++ host
provides desktop credential storage and safe local `.torrent` reads; RPC and the
application UI remain in QML.

## Requirements and launch

- Qt 6.5 or newer, including Quick, Quick Controls, Quick Dialogs, and Concurrent
- QtKeychain for Qt 6
- CMake 3.21 or newer and a C++17 compiler

Build and run from this directory:

```sh
cmake -S . -B build -G Ninja
cmake --build build
./build/qml-transmission
```

If Qt is not installed globally, a suitable `nix-shell` can provide the `qml`,
`qmllint`, and `qmltestrunner` commands.

```sh
nix-shell --run 'cmake -S . -B build -G Ninja && cmake --build build'
nix-shell --run './build/qml-transmission'
```

Use **Profiles** to save one or more named servers. Password persistence is
opt-in and uses the desktop credential store through QtKeychain. A password is
never placed in the application INI file, and there is no plaintext fallback if
the keyring is locked or unavailable. The last selected profile is connected on
startup, and selecting another profile switches the connection automatically.

## Supported workflow

The client lists, searches, filters by status, download folder, or tracker domain,
and sorts torrents; shows general and file details; edits wanted files and
Low/Normal/High priority; uploads local `.torrent` files; and adds magnet links or
remote torrent URLs. Torrent removal can optionally delete downloaded data after
explicit confirmation. Local files and torrent URLs are prepared paused so file
choices can be applied before starting. Draft cleanup always preserves downloaded
data. Download paths refer to the daemon host, not the computer running this
application.

Magnets are added directly because their file metadata may not exist yet. Their
files can be selected from the Files tab after metadata arrives; pre-start magnet
file selection is not supported.

Only Transmission's RPC protocol 6.0.0 and newer (Transmission 4.1+) is
supported. During connection loss, existing rows remain visible as stale data
and the client reconnects with bounded exponential backoff.

## Checks

```sh
nix-shell --run 'cmake -S . -B build -G Ninja -DBUILD_TESTING=ON && cmake --build build'
nix-shell --run 'ctest --test-dir build --output-on-failure'
nix-shell --run 'qmltestrunner -input tests -platform offscreen'
nix-shell --run 'qmllint -I build *.qml tests/*.qml'
```

## Current limitations

Only one saved server is active at a time. Simultaneous server tabs, peer/tracker
editing, queue management, remote directory browsing,
batch torrent selection, and tray integration are outside version 0.2.
