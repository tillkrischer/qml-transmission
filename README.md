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

Launch from `nix-shell` when using the Nix build so Qt uses the expected runtime
environment and file-dialog integration.

## Declarative Nix installation

`default.nix` builds a wrapped package with a desktop launcher. Use
`pkgs.callPackage /path/to/qml-transmission/default.nix {}` to instantiate it.
The installed package runs without entering `nix-shell`.

Add the repository as a non-flake input in your configuration's `flake.nix`:

```nix
inputs.qml-transmission = {
  url = "github:tillkrischer/qml-transmission";
  flake = false;
};
```

Pass the input to Home Manager through `extraSpecialArgs` and install it with
`pkgs.callPackage "${qmlTransmissionSource}/default.nix" {}` in `home.packages`.
For example, with `inputs` bound in your flake's `outputs` function:

```nix
extraSpecialArgs = { qmlTransmissionSource = inputs.qml-transmission; };
```

Your Home Manager module must accept `qmlTransmissionSource` as an argument.
The configuration in `~/nixos` is set up this way. Apply it with:

```sh
home-manager switch --flake ~/nixos#till@nixos
```

After pushing app changes to GitHub, refresh the pinned revision before rebuilding:

```sh
nix flake update qml-transmission --flake ~/nixos
home-manager switch --flake ~/nixos#till@nixos
```

The source revision is pinned in your configuration's `flake.lock`; no local app
checkout is needed to rebuild.

## Usage

Use **Profiles** to save one or more named servers. Password persistence is
opt-in and uses the desktop credential store through QtKeychain. A password is
never placed in the application INI file, and there is no plaintext fallback if
the keyring is locked or unavailable. The last selected profile is connected on
startup, and selecting another profile switches the connection automatically.

## Supported workflow

The client lists, searches, filters by status, download folder, or tracker domain,
and sorts torrents; shows general and file details; edits wanted files and
Low/Normal/High priority; uploads local `.torrent` files; and adds magnet links.
Torrent removal can optionally delete downloaded data after explicit confirmation.

Use **Torrent files** to select one or more files. Each torrent gets its own
dialog for download location and file selection; confirming opens the next one.
Use **Magnet link** to paste a link, then confirm to open the same options dialog.
Torrents are prepared paused so choices can be applied before starting.
Draft cleanup always preserves downloaded data. Download paths refer to the daemon host, not the computer running this
application.

Magnet file metadata may not exist yet. In that case, their
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
