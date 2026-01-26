# remove-mock-connection

**Created:** 2026-01-26
**Status:** 🚧 In Progress
**Priority:** P2

## Quick Note
Platform-based service selection: Use RealNirScanService on Android, MockNirScanService on Linux desktop.

## Summary
Currently `main.dart` hardcodes `MockNirScanService`. Need to detect platform at runtime and use appropriate service implementation.

## Related Files
- `lib/main.dart` - Service instantiation (lines 5, 20, 27)
- `lib/services/ble/nir_scan_service.dart` - Abstract interface
- `lib/services/ble/real_nir_scan_service.dart` - Real BLE impl
- `lib/services/ble/mock_nir_scan_service.dart` - Mock impl

## Tags
- ble
- mock
- platform-detection
