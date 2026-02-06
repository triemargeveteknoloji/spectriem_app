# sensor-integration-test

**Created:** 2026-02-02
**Status:** ✅ Completed
**Completed:** 2026-02-02

---

## Problem
Manuel test yerine gerçek Android cihaz + gerçek NIR sensör ile otomatize integration test. Tüm katmanlarda (BLE paketleri, GATT operasyonları, multi-packet akışı, state değişimleri) ne olduğunu görebilmek. Veri akışının doğru çalışıp çalışmadığını rahatça kontrol edebilmek.

## Approach
**Chosen:** Observable Integration Test Framework - Decorator pattern
**Why:** Production kodu değiştirmeden full observability. `ObservableBleNirScanService` ile BleNirScanService'i wrap ederek her operasyonu logla.

**Alternatives considered:**
- App içi test modu (UI butonu ile) - Reddedildi: Terminal-based daha esnek
- Mock service ile test - Zaten var ama gerçek cihaz testi için yetersiz

## Decisions
- **Decorator pattern**: Production kodu değişmez, test-only observability
- **Configurable mode**: `TEST_MODE=semi` env var ile auto/semi-auto seçimi
- **Range assertions**: Gerçek sensör verisi değişken, exact match yerine range check
- **Multiple small tests**: Her step ayrı test - kısmi çalıştırma ve izolasyon
- **Console output**: Colored terminal output, kategorili loglar (BLE, CAL, SCAN, STATE)

## Constraints
- Flutter `integration_test/` pattern kullanılacak
- Gerçek Android cihaz gerekli (desktop'ta BLE yok)
- Sensör açık ve yakında olmalı
- BLE inherently sequential - testler seri çalışacak

## Related Files
- `lib/services/ble/ble_nir_scan_service.dart` - Wrap edilecek production service
- `lib/services/ble/nir_scan_service.dart` - Interface - test steps bu interface'i kullanacak
- `lib/services/logging/log_service.dart` - Logger pattern referansı
- `lib/services/ble/multi_packet_receiver.dart` - Multi-packet progress logging için
- `test/screens/bluetooth_connection_screen_integration_test.dart` - Mevcut test pattern referansı

---

## Tasks

### Core Infrastructure
- [x] `integration_test/config/test_config.dart` - Config sınıfı + TestMode enum
- [x] `integration_test/core/test_context.dart` - Paylaşılan state (device, scan data)
- [x] `integration_test/core/step_executor.dart` - Auto/semi-auto logic + timing

### Observability Layer
- [x] `integration_test/observability/log_formatter.dart` - ANSI color codes
- [x] `integration_test/observability/integration_logger.dart` - Kategorili logger
- [x] `integration_test/observability/observable_service.dart` - Decorator pattern

### Assertions
- [x] `integration_test/assertions/sensor_assertions.dart` - Range assertions

### Test Steps
- [x] `integration_test/steps/scan_step.dart` - Device discovery
- [x] `integration_test/steps/connect_step.dart` - MTU negotiation dahil
- [x] `integration_test/steps/device_info_step.dart` - 6 DIS characteristic
- [x] `integration_test/steps/status_step.dart` - Battery, temp, humidity
- [x] `integration_test/steps/perform_scan_step.dart` - Spektral tarama
- [x] `integration_test/steps/calibration_step.dart` - Multi-packet calibration (implicit via scan)
- [x] `integration_test/steps/disconnect_step.dart` - Clean disconnect

### Flow & Entry Point
- [x] `integration_test/flows/full_sensor_flow.dart` - Step composition
- [x] `integration_test/integration_test.dart` - Main entry, setup/teardown

### Device UI (on-device status display)
- [x] `integration_test/ui/test_status_state.dart` - ChangeNotifier for step state
- [x] `integration_test/ui/test_status_widget.dart` - Material UI showing progress

---

## File Structure

```
integration_test/
├── integration_test.dart           # Main entry point
├── config/
│   └── test_config.dart            # Config + TestMode enum
├── core/
│   ├── step_executor.dart          # Auto/semi-auto execution + UI updates
│   └── test_context.dart           # Shared state
├── observability/
│   ├── integration_logger.dart     # Colored terminal output
│   ├── observable_service.dart     # Decorator for BleNirScanService
│   └── log_formatter.dart          # ANSI colors
├── assertions/
│   └── sensor_assertions.dart      # Range-based assertions
├── steps/
│   ├── scan_step.dart
│   ├── connect_step.dart
│   ├── device_info_step.dart
│   ├── status_step.dart
│   ├── perform_scan_step.dart
│   ├── calibration_step.dart
│   └── disconnect_step.dart
├── flows/
│   └── full_sensor_flow.dart       # Step composition
└── ui/
    ├── test_status_state.dart      # ChangeNotifier for UI state
    └── test_status_widget.dart     # On-device status display
```

---

## Usage

```bash
# Full auto mode (CI veya hızlı test)
flutter test integration_test/ -d <device-id>

# Semi-auto mode (step-by-step, Enter ile devam)
TEST_MODE=semi flutter test integration_test/ -d <device-id>

# Belirli device tercih et
DEVICE_NAME="NIRScan Nano" flutter test integration_test/ -d <device-id>
```

---

## Sample Output

```
14:32:15.123 [STEP] === NIRScan Integration Test Suite ===
14:32:15.124 [STEP] Mode: fullAuto
14:32:15.200 [STEP] SCAN: Scanning for NIRScan Nano devices
14:32:15.450 [BLE]  Found: NIRScan Nano B (AA:BB:CC:DD:EE:FF) RSSI: -45
14:32:17.200 [PASS] Selected device: NIRScan Nano B
14:32:17.201 [STEP] CONNECT: Connecting to selected device
14:32:17.300 [BLE]  MTU negotiation: 512 bytes
14:32:17.500 [STATE] Connection: connecting -> connected
14:32:17.520 [BLE]  Subscribing to 13 notification characteristics...
14:32:18.900 [PASS] Connected successfully (1699ms)
14:32:18.901 [STEP] DEVICE_INFO: Reading device information
14:32:19.100 [BLE]  TX DIS/ManufacturerName: read
14:32:19.150 [BLE]  RX: "Texas Instruments"
...
14:35:22.000 [STEP] === Test Suite Complete ===
```

---

## Timeouts

| Operation | Default Timeout |
|-----------|-----------------|
| Device scan | 10s |
| Connection | 15s |
| Device info | 5s |
| Perform scan | 60s |
| Calibration | 30s |
| Multi-packet | 10s |

---

## Sessions
**S1** (2026-02-02): Brainstorm complete. Full observability + configurable auto/semi-auto mode + decorator pattern kararlaştırıldı. Plan ready for implementation.
**S2** (2026-02-02): ⚡ Implementation complete via parallel agent dispatch (4 batches). 16 files created: config, observability layer (logger + decorator), assertions, 7 test steps, flow composition, main entry. Analysis passes with no issues.
**S3** (2026-02-02): Added on-device UI display - TestStatusWidget shows step progress, timing, pass/fail status on Android screen during test execution. Uses ChangeNotifier + Timer for periodic frame pumping.
**S4** (2026-02-02): Fixed scan step timeout issue - don't await startDeviceScan(), use Future.any() pattern.

## Commits
- `53d9c6f` (2026-02-02): test(integration): add real device integration test framework
