# Context: remove-mock-connection

## Codebase Context

### Service Architecture
- `NirScanService` - Abstract interface defining BLE operations
- `RealNirScanService` - Real flutter_blue_plus implementation
- `MockNirScanService` - Mock for testing without hardware

### Current State
`main.dart` hardcodes `MockNirScanService`:
```dart
late final MockNirScanService _bleService;
_bleService = MockNirScanService();
```

### Target State
Platform-aware service creation:
- Android/iOS → RealNirScanService
- Linux/macOS/Windows → MockNirScanService

## Session Notes

### Session 1 (2026-01-26)
- Task initialized from draft
- Analyzed codebase structure
- Chose simple platform check approach over factory pattern
- Ready to implement
