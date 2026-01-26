# Bluetooth Connection UI - Context

## Key Files

| File | Purpose | Relevance |
|------|---------|-----------|
| `lib/services/ble/nir_scan_service.dart` | Abstract BLE interface | Core API to use |
| `lib/services/ble/real_nir_scan_service.dart` | Production BLE impl | Integration reference |
| `lib/services/ble/mock_nir_scan_service.dart` | Test mock | Development/testing |
| `lib/services/ble/nano_gatt.dart` | GATT UUIDs | Log metadata reference |
| `lib/models/device_info.dart` | Device info model | Display in UI |
| `lib/models/device_status.dart` | Device status model | Display battery, temp |
| `lib/app.dart` | App entry point | Route configuration |
| `lib/main.dart` | Main entry | Service initialization |

## Architecture Notes

### Current Service Pattern
```
NirScanService (abstract)
├── RealNirScanService (production)
└── MockNirScanService (testing)
```

### Stream-based State
Services use `StreamController<T>.broadcast()` for state updates:
```dart
final _connectionStateController = StreamController<NirConnectionState>.broadcast();
Stream<NirConnectionState> get connectionState => _connectionStateController.stream;
```

### Resource Management
All services implement `dispose()` for cleanup:
```dart
void dispose() {
  _connectionStateController.close();
  // ... cleanup
}
```

## Dependencies
- **External:**
  - `flutter_blue_plus: ^1.31.0` — BLE communication
  - `permission_handler: ^11.0.0` — Runtime permissions
- **Internal:**
  - `NirScanService` — BLE operations
  - Models: `DeviceInfo`, `DeviceStatus`, `NirScanDevice`

## Existing Patterns to Follow

### Service Layer
- Abstract interface + concrete implementations
- Constructor injection for dependencies
- Stream-based state exposure

### Model Design
- Immutable with `const` constructors
- Override `==`, `hashCode`, `toString()`
- Helper getters for computed values

### Naming Conventions
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Private: `_prefix`

### Testing
- Group related tests with `group()`
- Use `setUp()` / `tearDown()`
- Call `dispose()` in tearDown

## New Files to Create

```
lib/
├── services/
│   └── logging/
│       ├── log_service.dart        # Abstract interface + impl
│       └── log_entry.dart          # LogEntry model
├── screens/
│   └── bluetooth_connection_screen.dart
└── widgets/
    ├── log_viewer_widget.dart
    ├── device_list_widget.dart
    └── connection_status_widget.dart

test/
├── services/
│   └── logging/
│       └── log_service_test.dart
└── screens/
    └── bluetooth_connection_screen_test.dart
```

## NirScanService API Summary

```dart
// Discovery
Stream<List<NirScanDevice>> scanForDevices();
Future<void> stopScan();

// Connection
Future<void> connect(NirScanDevice device);
Future<void> disconnect();
Stream<NirConnectionState> get connectionState;
NirConnectionState get currentConnectionState;

// Device Info
Future<DeviceInfo> getDeviceInfo();
Future<DeviceStatus> getDeviceStatus();
```

## Decisions Log
| Date | Decision | Rationale | Alternatives Considered |
|------|----------|-----------|------------------------|
| 2026-01-26 | Stream-based Logger | Flutter idiomatic, testable | Riverpod (adds dependency), EventBus |
| 2026-01-26 | Expandable log panel | Full device list visible, log optional | Split view, tabs |
| 2026-01-26 | Ana ekran | Direct access, primary use case | Settings menu, splash |

## Session Notes
### Session 1 - 2026-01-26 (Initialization)
- Brainstorm completed: scope, logging approach, UI layout
- Approach selected: Stream-based Logger + Embed Widget
- Key files identified: BLE services, models
- TDD strategy defined: LogService first, then UI
- Ready to begin implementation

### Session 2 - 2026-01-26 (Completion)
- Fixed integration tests: refactored MockNirScanService with `deviceEmitInterval` parameter
- Discovered `runAsync + pump(Duration.zero)` pattern for async widget tests
- All 107 tests passing
- Made BluetoothConnectionScreen the app opening page
- Task completed successfully
