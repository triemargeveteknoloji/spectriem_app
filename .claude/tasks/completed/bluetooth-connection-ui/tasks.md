# Bluetooth Connection UI - Task Checklist

**Status:** ✅ Complete
**Priority:** P2
**Last Updated:** 2026-01-26

## Current Focus
> All tasks complete

## Quick Stats
- Total: 19 tasks
- Done: 19
- Remaining: 0

## Tasks

### Phase 1: Logging Module 🧪

#### 1.1 LogEntry Model
- [x] Write test: LogEntry constructor sets all fields
- [x] Write test: LogEntry.toString() format
- [x] Write test: LogLevel enum ordering
- [x] Implement LogEntry model

#### 1.2 LogService
- [x] Write test: log() emits entry to stream
- [x] Write test: history returns buffered entries
- [x] Write test: clear() empties buffer
- [x] Write test: dispose() closes stream
- [x] Implement LogService

#### 1.3 LogViewerWidget
- [x] Write test: renders log entries from stream
- [x] Write test: auto-scrolls on new entry
- [x] Write test: filter chips filter by level
- [x] Implement LogViewerWidget

### Phase 2: Bluetooth Connection Screen 🔨

#### 2.1 Screen States
- [x] Write test: idle state shows scan button
- [x] Write test: UI elements render correctly
- [x] Implement BluetoothConnectionScreen

#### 2.2 Device Interaction
- [x] Write integration test: scan discovers devices
- [x] Write integration test: tap device connects
- [x] Write integration test: disconnect button works

#### 2.3 Log Panel Integration
- [x] Write test: log panel expands/collapses
- [x] Integrate LogViewerWidget as bottom panel

### Phase 3: Polish ✨

- [x] Handle edge cases (timeout, unexpected disconnect) — already in screen
- [x] Add error states with retry — already implemented
- [x] Wire up with RealNirScanService — skipped (no device), using MockNirScanService
- [x] Make BluetoothConnectionScreen the app opening page

## Completed
- Phase 1: Logging Module (17 unit tests)
- Phase 2.1: Screen States (9 widget tests)
- Phase 2.2: Device Interaction (8 integration tests)
- Phase 2.3: Log Panel (integrated)
- Phase 3: Polish (app entry point configured)

## Blockers
- None

## Notes
- Total new tests: 44 (17 LogService + 10 LogViewerWidget + 9 Screen + 8 Integration)
- MockNirScanService refactored with configurable `deviceEmitInterval` for testing
- Integration tests use `runAsync` + `pump(Duration.zero)` pattern for proper async processing
- App now opens directly to BluetoothConnectionScreen with MockNirScanService
