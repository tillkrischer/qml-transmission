# 0.2 implementation plan

Status: implemented; automated build and unit checks are documented below. The
two-daemon integration matrix and desktop keyring/UI smoke test remain release
validation steps for an environment with those services available.

This covers [whishlist.md](whishlist.md), based on the current QML implementation.
Use [Transmission Remote GUI](https://github.com/transmission-remote-gui/transgui)
as the reference for connection profiles, a compact torrent list, and file controls.

## Release scope and assumptions

| Wishlist item | Proposed 0.2 behavior |
| --- | --- |
| Persist credentials | Optional “Remember password” per profile, stored in the desktop credential store. |
| Multiple connections | Named saved profiles with a toolbar selector; one active connection at a time. |
| Colorful status icons | A consistent icon and color for each torrent state, with an error override and readable status text. |
| Toolbar icons | Icons for Add, Start, Stop, Remove, Connect, Disconnect, and profile management. |
| Added on column | Local date/time display, sorted by the underlying timestamp. |
| Add `.torrent` file | Native local file picker and binary upload to the remote daemon. |
| Download location | Server default plus editable path and recent paths per profile. |
| Choose files when adding | A paused preparation step for local `.torrent` files and torrent URLs, followed by file selection and optional start. |
| Bottom Files tab with priority | Folder tree, wanted checkboxes, progress, and Low/Normal/High priority controls. |

Two scope assumptions need to remain visible: “multiple connections” means switching
saved servers, not simultaneous server tabs; magnets without metadata cannot offer
the same immediate file preview as a `.torrent` file. In 0.2, magnets retain the
add/start workflow and expose file selection in the Files tab after metadata arrives.
Selection before starting a magnet is not included in this proposal. The dialog
must explain this before submission; it must not silently pretend all sources have
the same preview capability.

Keep the existing Transmission 4.1+ requirement and preservation of downloaded data
on removal. Tray support, peers/trackers, queue management, batch torrent selection,
and remote directory browsing remain outside this release.

## Architecture decision

Introduce a small C++ Qt executable hosting the existing QML, with two native
services: `CredentialStore` and `TorrentFileReader`. Keep the RPC transport, torrent
store, and UI in QML. This changes the current `qml Main.qml` launch contract and
requires CMake and a compiled executable; include that work explicitly in 0.2.

Use QtKeychain for credential storage. It supports Qt 6 and desktop credential
backends, and can report unavailable storage without falling back to plaintext.
Keep insecure fallback disabled. See the [QtKeychain documentation](https://github.com/frankosterfeld/qtkeychain).

Use the [Qt Quick FileDialog](https://doc.qt.io/qt-6/qml-qtquick-dialogs-filedialog.html)
to choose a local file, then pass its URL to the native reader. The reader converts
the URL to a local path, reads bytes, and returns Base64. It does not parse torrent
metadata: the daemon supplies the authoritative file list in the preparation step.

## 1. Make connection changes safe

Files: `TransmissionClient.qml`, `TorrentStore.qml`, `Main.qml`; new lifecycle tests.

The current client already has a request generation counter, but aborting requests
drops their callbacks. `TorrentStore.refreshInFlight` is only cleared by those
callbacks, so disconnecting during a refresh can leave subsequent polling blocked.
The current store also retains rows and numeric selection across endpoint changes.

- Centralize connection invalidation: cancel requests/timers, reset refresh state,
  and advance a store generation. Ignore results from previous generations.
- Separate reconnecting to the same profile from selecting another profile.
  Same-profile network loss keeps stale rows; switching clears rows, speeds,
  errors, selection, and detail data before enabling actions on the new server.
- Make profile activation perform one disconnect/configure/connect sequence.
  Avoid the current possibility of both `configure()` and its caller starting it.
- Bind asynchronous operations to profile ID, connection generation, and torrent
  identity. Clear operation busy states when a generation is invalidated.
- Resolve a torrent by hash again after reconnect before continuing any operation
  that survived a connection loss. Never reuse an old numeric ID after reconnect.

Acceptance: switch between two servers that both have torrent ID 1 while a poll is
pending. No old row, callback, selection, or mutation may affect the new server.
Disconnect/reconnect during either half of the list/stats refresh resumes polling.

## 2. Add native services and saved profiles

New files: `CMakeLists.txt`, `src/main.cpp`, `src/CredentialStore.{h,cpp}`,
`src/TorrentFileReader.{h,cpp}`, `ConnectionProfiles.qml`.
Modify `ConnectionDialog.qml`, `Main.qml`, `shell.nix`, and `README.md`.

- Register native services with the QML engine and package QML/JS/icon resources.
  Set application identity before loading QML. Keep the existing settings path so
  window geometry and old connection settings remain discoverable.
- Extend the Nix shell with the compiler/build tools, QtKeychain for Qt 6, and
  required Qt modules. Provide documented build, launch, lint, and test commands.
- Implement asynchronous read/write/delete credential operations identified by
  request ID and stable profile UUID; renaming a profile must not change its key.
- Implement asynchronous local file reads, explicit cancellation/result tokens,
  and useful errors for unreadable, empty, non-local, or oversized inputs. Adopt
  a documented initial 32 MiB metainfo limit and read at most limit + 1 bytes.
- Persist a versioned profile array containing UUID, name, endpoint, username,
  remember-password preference, default directory override, and recent directories.
  Persist the last selected UUID separately. Passwords never enter that array.
- Migrate the legacy endpoint/username into one “Default” profile exactly once.
  Write and sync the new schema before marking migration complete; preserve
  legacy keys for recovery. Existing settings contain no saved password to migrate.
- Expand the connection dialog into a profile editor with Add, Rename, Delete,
  Save, and Connect actions. Allow editing while disconnected or connected.
  Put a profile selector and a separate connection action in the toolbar.
- “Remember password” is opt-in. Report a failed save accurately while allowing
  connection with the in-memory password. A locked/unavailable keyring allows
  manual entry; do not repeatedly prompt during automatic reconnect.
- Turning remembering off deletes the saved secret. Profile deletion also deletes
  it; retain enough profile information to retry if deletion fails. Discard late
  credential reads when the user switches profiles or edits the password.

Acceptance: two profiles retain distinct credentials after restart; renaming,
deletion, save failure, locked storage, and legacy migration behave predictably.
Inspect the INI file to confirm passwords are absent. Smoke-test a real desktop
keyring as well as an injected fake credential backend in automated tests.

## 3. Add icons and the Added on column

Files: `TorrentList.qml`, `Main.qml`, `TorrentStore.qml`, `js/Format.js`;
new `StatusIcon.qml` and bundled vector assets under `icons/`.

- Add the creation timestamp and numeric error indicator to the lightweight list
  query. Add a date formatter that handles Unix seconds, local timezone, and
  missing/invalid values. Sort dates numerically, with a defined unknown-value order.
- Use blue downloading, green seeding, amber verification, muted queued states,
  neutral stopped, and red error. Pair shape/color with existing status labels and
  error tooltips; retain selection contrast in light and dark themes.
- Set toolbar action icons with bundled fallbacks so an absent desktop icon theme
  does not produce empty controls. Retain labels/tooltips and keyboard activation.
- Centralize column widths and provide shared horizontal scrolling for the header
  and rows. The current fixed-width row already exceeds the narrowest window;
  adding a timestamp must not make controls inaccessible or misalign headers.

Acceptance: exercise every state and error override; check numeric date sorting,
timezone formatting, missing dates, 820 px width, and both palette variants.

## 4. Build a reusable file model and bottom Files tab

New files: `TorrentFilesStore.qml`, `TorrentFilesView.qml`, `js/FileTree.js`.
Modify `TorrentDetails.qml`, `Main.qml`, and `TransmissionClient.qml`.

- Convert the bottom panel to General and Files tabs, preserving existing details.
- Fetch file names/sizes on selection or metadata availability; poll mutable file
  state only for the selected torrent while Files is visible. Do not put every
  torrent's file list into the two-second main list query.
- Build a flattened expandable folder tree for a virtualized list. Keep each leaf's
  original daemon index separate from visual position, sorting, and expansion.
- Show wanted checkbox, path/name, size, completed bytes/progress, and priority.
  Folder rows aggregate progress, show mixed wanted/priority values, and apply
  edits to their descendant leaves. Include Select all and Select none.
- Keep wanted state separate from priority: skipping a file does not erase its
  priority. Present unavailable metadata, loading, no selection, and errors as
  distinct states.
- Send one targeted mutation for a user action, disable conflicting edits while it
  is pending, then refresh authoritative state. On error show the failure and restore
  confirmed values. Preserve expansion, scroll, and row identity during polling.
- Reuse this view in draft mode for the add dialog: changes edit local draft state
  until the user confirms, rather than sending individual mutations.

RPC contract: request `files`, `file_stats`, and `metadata_percent_complete` with
`torrent_get`. File indices are positions in the returned array. Apply wanted state
with `torrent_set.files_wanted` / `files_unwanted` and priorities with
`priority_low` / `priority_normal` / `priority_high`. Omit unused array parameters:
an empty array means all files. Always supply a validated, nonempty torrent target.
The same specification defines `added_date` for the list column.
See [Transmission's RPC specification](https://raw.githubusercontent.com/transmission/transmission/main/docs/rpc-spec.md).

Acceptance: a nested multifile torrent supports leaf and folder edits, mixed state,
and all three priorities; sorting never changes which daemon file is edited.
Switching selection during a request cannot populate the wrong torrent's Files tab.
Exercise a synthetic 10,000-file tree for responsiveness and stable scrolling.

## 5. Implement local upload and the add workflow

Files: `AddTorrentDialog.qml`, `TransmissionClient.qml`, `TorrentStore.qml`,
`Main.qml`; new `AddTorrentController.qml`.

The existing directory field and RPC argument already work. Extend them with the
server's default directory, a per-profile override, and the ten most recent successful
locations. Keep this an editable server path; a local folder picker would select
the wrong machine. Refresh the server default after connecting. Do not silently
reuse the previous profile's directory.

The dialog has File and Link input modes, a location field, and a Start when ready
checkbox. Keep the dialog open during requests and errors; disable duplicate
submission. Lock source and directory once preparation creates a torrent.

For local files and torrent URLs, use these explicit controller states:

`editing → preparing paused torrent → loading files → choosing files → applying → starting (optional) → done`

1. “Next: choose files” explains that it creates a paused torrent on the selected
   server. Read local bytes through `TorrentFileReader`; submit URLs directly.
2. Prepare the torrent paused and retain the returned hash, ID, and ownership flag.
3. Load its file list into the draft file view. Default to all wanted and normal
   priority; show selected count and bytes. Allow zero wanted files only if the
   torrent will remain paused.
4. “Add” applies the draft. Start only after successful application and only when
   requested. If application or start fails, retain the paused torrent and offer
   a targeted retry with an accurate message.
5. Cancel after preparation removes only the newly created draft torrent, preserving
   downloaded data. Before preparation, Cancel simply closes the dialog.

For local input send `torrent_add.metainfo` as Base64; for links send `filename`.
Preparation uses `paused: true` and `download_dir`. Distinguish `torrent_added`
from `torrent_duplicate`; a duplicate is an existing torrent, never an owned draft.
Removal uses `delete_local_data: false`.
See the [Transmission 4.1 add/remove contract](https://github.com/transmission/transmission/blob/4.1.0/docs/rpc-spec.md).

Handle the non-happy paths as part of the feature:

- A duplicate offers to select the existing torrent and exits preparation without
  changing its location, files, running state, or priority.
- An add timeout has unknown outcome. Do not automatically resubmit or remove a
  matching torrent based only on a later list result; present reconciliation and
  let the user select the existing torrent. Ownership requires a confirmed add result.
- Before cancelling while a request is in flight, await its bounded completion and
  clean up only a confirmed owned draft. Failed cleanup reports that the paused
  torrent remains, with a retry action.
- Block profile switching during an active draft until it is completed, cancelled,
  or explicitly left paused on its original server. Closing the app uses the same
  decision. Persist a small confirmed-draft recovery record containing profile ID
  and hash, without passwords or metainfo; after a crash offer resume/keep/remove
  once the user reconnects to that profile. Never remove automatically on startup.
- Magnet input uses the existing immediate add path and clearly explains that
  files become selectable after metadata is available. A paused magnet can remain
  without metadata; do not show an endless preview spinner or auto-start it.

Acceptance: add a local multifile torrent to another machine, choose a destination
and subset, and verify selection is applied before start. Repeat for a torrent URL.
Test invalid file, duplicate, each request failure, cancel, crash recovery, zero
selection, and a magnet that has not yet obtained metadata.

## 6. Verify and document the release

Add focused QML tests for connection generations, profile migration, draft workflow,
tree/index mapping, and mutation argument construction. Use an injectable RPC fake
or local test HTTP server so failures and delayed responses are reproducible.
Add Qt tests for binary file fidelity and native-service error handling. Keep the
existing protocol/format tests and extend the formatter cases for dates.

Run CMake build/CTest, QML lint with the built module import path, and QML tests.
For integration, use two disposable Transmission 4.1+ daemons with separate temp
config/download directories and controlled torrent fixtures. Verify server identity,
saved profiles, paused add/cancel, directory, wanted flags, priority, 409 session
renewal, authentication failure, and reconnect behavior. Compare file state against
the daemon's own response, not only displayed UI values.

Finally update README launch instructions, new dependencies, supported features,
credential behavior, and the magnet limitation. Add a 0.2 changelog and perform a
desktop smoke test for native dialogs, actual keyring persistence, layout, and focus.

## Suggested implementation slices

| Slice | Depends on | Completion boundary |
| --- | --- | --- |
| 1. Connection lifecycle | None | Disconnect/reconnect and server isolation tests pass. |
| 2. Native host and services | None | Build/launch works; credential and binary-read services tested. |
| 3. Saved profiles | 1, 2 | Migration, switching, and persistence work end to end. |
| 4. List/toolbar improvements | 1 | Icons, date sorting, and narrow layout verified. |
| 5. Files tab and shared file view | 1 | Wanted/priority edits verified against a daemon. |
| 6. Add controller and file upload | 2, 3, 5 | Preparation, subset selection, cancellation, recovery verified. |
| 7. Release verification/docs | All | Integration checks and desktop smoke test pass. |

The main implementation risk is the add workflow's partial failures and ownership
tracking, followed by native packaging/keyring integration. Complete these before
treating the visible wishlist checkboxes as done. No application tests were run
for this planning-only change.
