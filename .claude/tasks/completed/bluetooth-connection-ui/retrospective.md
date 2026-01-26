# Bluetooth Connection UI - Retrospective

**Completed:** 2026-01-26
**Total Duration:** 2026-01-26 → 2026-01-26 (single day)
**Sessions:** 2

## Summary
Built a complete Bluetooth Connection UI with integrated logging for NIR sensor device management. Implemented stream-based LogService, LogViewerWidget, and BluetoothConnectionScreen following TDD principles. All 107 tests pass with comprehensive coverage of unit, widget, and integration tests.

## Metrics
| Metric | Value |
|--------|-------|
| Tasks Completed | 19/19 |
| Tests Written | 44 new tests |
| Total Tests | 107 passing |
| Files Created | 8 |
| Files Modified | 3 |
| Sessions | 2 |

## What Went Well
- **TDD workflow** — Writing tests first caught design issues early, especially in LogService API
- **Stream-based architecture** — Flutter-idiomatic patterns made state management clean and testable
- **MockNirScanService refactoring** — Adding `deviceEmitInterval` parameter enabled proper async testing
- **Brainstorm phase** — Initial planning session defined clear scope and approach

## What Could Be Better
- **Flutter widget test async timing** — Significant debugging time spent on `pump()` vs `pumpAndSettle()` vs `runAsync()` behavior
- **Initial mock service design** — Hardcoded timers in MockNirScanService required refactoring mid-task
- **Integration test patterns** — Had to discover the `runAsync + pump(Duration.zero)` pattern through trial and error

## Lessons Learned
- **In Flutter widget tests, `pump()` processes UI frames but not microtasks from async/await chains** — Use `runAsync()` for business logic async operations, then `pump()` for UI updates
- **Broadcast StreamController delivers events synchronously to listeners** — But in tests, listener callbacks may not complete before the next event when not using await
- **Stream events emitted in a loop need yielding** — `await Future.value()` between emissions allows listeners to process each event

## Follow-up Items
- [ ] Add real device integration when hardware available
- [ ] Consider Riverpod for app-wide state management
- [ ] Add scan timeout indicator in UI
- [ ] Implement device reconnection on unexpected disconnect

## Key Decisions Made
| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Stream-based Logger | Flutter idiomatic, testable, no new dependencies | Clean separation, easy to test |
| Expandable log panel | Keep device list visible, log is secondary info | Good UX balance |
| MockNirScanService as default | No real device available | App fully functional for development |
| `deviceEmitInterval` param | Enable zero-delay testing | Integration tests work reliably |

## Code References
- `lib/services/logging/log_service.dart` - Core logging service
- `lib/screens/bluetooth_connection_screen.dart` - Main UI screen
- `lib/widgets/log_viewer_widget.dart` - Log display widget
- `lib/main.dart` - App entry point configuration
- `test/screens/bluetooth_connection_screen_integration_test.dart` - Integration tests
