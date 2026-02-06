# display-raw-scan-data

**Created:** 2026-02-04
**Status:** 🚧 In Progress

---

## Problem
Raw scan data is retrieved from the NIR sensor as `Uint8List` but only metadata (name, type, date, size) is displayed in the UI. No way to inspect actual byte content for debugging BLE protocol or verifying data integrity.

## Approach
**Chosen:** Expandable hex dump + logging
**Why:** Provides both quick visibility (logs) and detailed inspection (UI) without cluttering either

- **UI Display:** Expandable hex viewer widget
  - Shows first 64 bytes by default (classic hex editor format with offsets)
  - "Show all (N bytes)" button to expand
  - Monospace font, 16 bytes per row

- **Logging:** Summary to existing LogService
  - First 64 bytes as hex string
  - Tag: `SCAN`
  - Logged when scan completes

## Decisions
- Hex editor style format: `0000: 1A 2B 3C... | ASCII`
- 64 bytes default display threshold
- Use existing LogService (no file export)
- Reusable widget for potential future use

## Constraints
- No new dependencies (pure Flutter)
- Follow existing widget patterns (see `log_viewer_widget.dart`)
- Monospace font for alignment

## Related Files
- `lib/screens/sensor_communication_screen.dart:207` - Current `_buildScanDataResponse()` displays only metadata
- `lib/models/scan_data.dart:1` - `ScanData` model with `rawData: Uint8List`
- `lib/widgets/log_viewer_widget.dart:1` - Pattern for styled widget
- `lib/services/log_service.dart` - LogService for logging

---

## Tasks
- [x] Write test for hex formatting utility (bytes → hex string)
- [x] Implement hex formatting utility
- [x] Write test for HexDumpWidget (renders, expands)
- [x] Implement HexDumpWidget with expandable display
- [x] Add logging of raw data on scan completion
- [x] Integrate HexDumpWidget into sensor_communication_screen
- [ ] Verify with real device (integration test)

## Sessions
**S1** (2026-02-04): Initialized. Approach: expandable hex dump UI + LogService logging. 64 bytes default, classic hex editor format.
**S2** (2026-02-04): ⚡ Parallel implementation complete. HexFormat utility (19 tests), HexDumpWidget (8 tests), logging at scan completion, UI integration. 6/7 tasks done - only device verification remains.
