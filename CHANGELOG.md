# Changelog

## 0.2.0

- Added named connection profiles with stable IDs, legacy settings migration,
  per-profile recent download paths, and opt-in QtKeychain password storage.
- Added a compiled Qt host and a bounded asynchronous local `.torrent` reader.
- Added paused torrent preparation, file selection before start, duplicate and
  unknown-timeout handling, safe draft cleanup, and crash-recovery records.
- Added a Files tab with a scalable folder tree, wanted controls, progress, and
  Low/Normal/High priority editing.
- Added colorful state/error indicators, bundled toolbar icons, and a sortable
  local-time Added on column with synchronized horizontal scrolling.
- Hardened reconnects and profile switching against stale callbacks and reused
  numeric torrent IDs by binding selection and mutations to profile and hash.
