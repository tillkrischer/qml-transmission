# QML Transmission

A small desktop client for a remote Transmission 4.1+ daemon. It uses the
JSON-RPC 2.0 API directly from QML and has no compiled application component.

## Requirements and launch

- Qt 6.5 or newer
- Qt Quick, Qt Quick Controls, Qt Quick Layouts, Qt QML, and QtCore QML modules

Run from this directory:

```sh
qml Main.qml
```

If Qt is not installed globally, a suitable `nix-shell` can provide the `qml`,
`qmllint`, and `qmltestrunner` commands.

```sh
nix-shell --run 'qml Main.qml'
```

Open **Connection**, enter the full RPC URL (normally
`http://host:9091/transmission/rpc`), and optionally enter HTTP Basic
authentication credentials. The URL and username are remembered; the password
is never written to settings.

## Supported workflow

The client lists, searches, filters, and sorts torrents; shows selected-torrent
details; adds magnet links or remote torrent URLs; and starts, stops, or removes
a torrent. Removal always preserves downloaded data. Download paths are paths on
the daemon host.

Only Transmission's RPC protocol 6.0.0 and newer (Transmission 4.1+) is
supported. During connection loss, existing rows remain visible as stale data
and the client reconnects with bounded exponential backoff.

## Checks

```sh
nix-shell --run 'qmllint *.qml tests/*.qml'
nix-shell --run 'qmltestrunner -input tests'
```

## Current limitations

There is one server profile and one selected torrent. Local `.torrent` uploads,
deleting downloaded data, file/peer/tracker editing, queue management, and tray
integration are intentionally outside v0.1.

