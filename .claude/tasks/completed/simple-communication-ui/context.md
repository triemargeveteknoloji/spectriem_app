# simple-communication-ui - Context

## Key Files (Auto-discovered)

| File | Purpose | Relevance |
|------|---------|-----------|
| `lib/screens/bluetooth_connection_screen.dart` | Connection UI | Reference pattern - copy structure |
| `lib/widgets/log_viewer_widget.dart` | Log display | Reuse directly |
| `lib/services/ble/nir_scan_service.dart` | BLE interface | All command methods |
| `lib/services/ble/real_nir_scan_service.dart` | BLE implementation | Understand behavior |
| `lib/services/logging/log_service.dart` | Logging | For command/response logs |
| `lib/models/device_info.dart` | Device info model | Response display |
| `lib/models/device_status.dart` | Device status model | Response display |
| `lib/models/scan_data.dart` | Scan result model | Response display |
| `lib/models/scan_configuration.dart` | Config model | Dropdown |
| `lib/main.dart` | App entry | Service injection pattern |

## Architecture Notes

### Screen State Pattern (from connection_screen)
```dart
enum _ScreenState { idle, loading, success, error }

class _State extends State<Screen> {
  _ScreenState _state = _ScreenState.idle;
  bool _logPanelExpanded = false;

  // Service injected via constructor
  late final NirScanService _bleService;
  late final LogService _logService;
}
```

### Log Panel Pattern
```dart
// AppBar action
IconButton(
  icon: Icon(Icons.terminal, color: _logPanelExpanded ? activeColor : null),
  onPressed: _toggleLogPanel,
)

// Body structure
Column(
  children: [
    Expanded(child: _buildMainContent()),
    if (_logPanelExpanded) _buildLogPanel(),
  ],
)

// Log panel
Widget _buildLogPanel() => Container(
  height: 200,
  child: LogViewerWidget(logService: widget.logService),
);
```

### Service Methods to Use
```dart
// Device info
Future<DeviceInfo> getDeviceInfo();
Future<DeviceStatus> getDeviceStatus();

// Scan operations
Future<ScanData> performScan({bool saveToSd = false});

// Configuration
Future<List<ScanConfiguration>> getScanConfigurations();
Future<void> setActiveScanConfiguration(int index);

// Device control
Future<void> syncTime();
```

## Dependencies
- **External:** flutter_blue_plus (indirect via service)
- **Internal:** NirScanService, LogService, LogViewerWidget, Models

## Existing Patterns to Follow
1. StatefulWidget with setState for UI updates
2. StreamSubscription management in initState/dispose
3. Service injection via constructor
4. Enum-based state management
5. Conditional log panel rendering
6. Tag-based logging ('BLE', 'UI')

## Decisions Log
| Date | Decision | Rationale | Alternatives Considered |
|------|----------|-----------|------------------------|
| 2026-01-26 | Preset buttons only | Basic functionality sufficient | Text input, command palette |
| 2026-01-26 | Unified log | Cleaner UX | Split view, tabs |
| 2026-01-26 | Reuse LogViewerWidget | Consistency, less code | Custom log component |

## Session Notes

### Session 1 - 2026-01-26 (Complete Implementation)
- Discovery completed via brainstorm
- Approach selected: SensorCommunicationScreen with preset buttons + unified log
- Key files identified: connection_screen (pattern), log_viewer (reuse), nir_scan_service (interface)
- TDD strategy defined: widget tests first, then implementation phases
- **Implementation completed:**
  - Phase 1-6 all completed
  - 17 tests written and passing
  - Navigation with BottomNavigationBar added
  - Config dropdown with auto-load implemented
  - All 124 project tests passing
