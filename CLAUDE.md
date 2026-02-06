# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NIR (Near-Infrared) spectroscopy Flutter application for Texas Instruments DLP NIRscan Nano EVM sensor via Bluetooth Low Energy.

## Commands

```bash
# Install dependencies
flutter pub get

# Run tests
flutter test

# Run single test file
flutter test test/path/to/test_file.dart

# Run tests with coverage
flutter test --coverage

# Code generation (after modifying @freezed or @riverpod classes)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
dart run build_runner watch --delete-conflicting-outputs

# Run app
flutter run

# Build
flutter build apk --release
flutter build ios --release

# Analyze code
flutter analyze
```

## Architecture

### Layer Overview

```
UI Layer (screens/, widgets/)
    ↓ WidgetRef
State Layer (providers/) - Riverpod StateNotifiers + @freezed states
    ↓ Dependencies
Service Layer (services/ble/)
    ↓ Abstraction
BLE Layer (flutter_blue_plus via BleAdapter)
```

### State Management: Riverpod + Freezed

- **Providers** (`lib/providers/`): Use `@riverpod` annotation for code generation
- **State classes**: Use `@freezed` for immutable state with `copyWith()`
- **Generated files**: `*.g.dart` (riverpod), `*.freezed.dart` (freezed)

Key providers:

- `nirScanServiceProvider` - Platform-aware BLE service (real on mobile, mock on desktop)
- `bluetoothConnectionNotifierProvider` - Connection screen state machine
- `sensorCommunicationNotifierProvider` - Sensor operations state
- `logEntriesProvider` - Real-time log entries

### BLE Service Architecture

```
NirScanService (abstract interface)
├── BleNirScanService - Production implementation using flutter_blue_plus
└── MockNirScanService - Development/test implementation

BleAdapter (abstract)
└── FlutterBluePlusAdapter - Wraps flutter_blue_plus for mockability
```

Service selection is automatic via `nirScanServiceProvider` based on platform.

### GATT Protocol

UUID definitions in `lib/services/ble/nano_gatt.dart`. Custom TI services follow pattern: `434841XX-444C-5020-4E49-52204E616E6F`

Key services:

- **GSDIS** - Scan data (start scan, retrieve results)
- **GCIS** - Calibration data (coefficients, matrices)
- **GSCIS** - Scan configurations
- **GGIS** - Device status (temperature, humidity, errors)

Detailed protocol docs: `.claude/skills/dlpnirnanoevm-sensor`

### Multi-Packet Protocol

Large BLE responses (calibration, scan data) use chunked transfer:

- Header packet: `[0x00, sizeLow, sizeHigh]`
- Data packets: `[packetIndex, ...data]`

Handled by `MultiPacketReceiver` class.

## Key Patterns

### Logging

Use `LogService` for all logging - it feeds both console and UI log viewer:

```dart
final log = ref.read(logServiceProvider);
log.info('Message', tag: 'BLE');  // Tags: BLE, CAL, SCAN, UI
log.debug('Details');
log.error('Failed', tag: 'BLE');
```

### Testing

```dart
// Override service with mock in tests
final container = ProviderContainer(overrides: [
  nirScanServiceProvider.overrideWithValue(MockNirScanService()),
]);
```

Mock implementations support configurable delays and error simulation.

### Integration Testing

Real device tests in `integration_test/`. Uses actual `BleNirScanService` (not mocks).

```bash
# List connected devices
flutter devices

# Run integration test on physical device
flutter test integration_test/integration_test.dart -d <device_id>

# Filter BLE diagnostic logs
flutter test integration_test/integration_test.dart -d <device_id> 2>&1 | grep -E "\[DIAG\]|\[SCAN\]|\[BLE\]"
```

**Test flow:** Scan → Connect → Device Info → Status → Perform Scan → Calibration → Disconnect

**Log tags:**
- `[DIAG]` - Diagnostic (CCCD status, all incoming notifications)
- `[SCAN]` - Scan operation timing and results
- `[BLE]` - General BLE operations

### State Updates in Notifiers

Use `scheduleMicrotask()` when updating state from listeners to avoid build-phase conflicts:

```dart
_subscription = stream.listen((data) {
  scheduleMicrotask(() => state = state.copyWith(data: data));
});
```

## File Naming Conventions

- Services: `*_service.dart`
- Notifiers: `*_notifier.dart` (class) / `*_provider.dart` (file)
- Models: Simple names (`device_info.dart`, `scan_data.dart`)
- Generated: `*.g.dart`, `*.freezed.dart`

## Related Skills

- `/dlpnirnanoevm-sensor` - Sensor protocol and BLE communication
- `.claude/research/nirscan-apk-analysis.md` - APK reverse engineering notes
