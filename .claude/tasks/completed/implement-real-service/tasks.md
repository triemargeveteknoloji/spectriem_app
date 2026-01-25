# implement-real-service - Task Checklist

**Status:** ✅ Completed
**Priority:** P2
**Last Updated:** 2026-01-26

## Current Focus
> ✅ All phases complete - Ready for review/testing

## Quick Stats
- Total: 21 tasks
- Done: 21
- Remaining: 0

## Tasks

### Phase 1: Test Foundation 🧪
- [x] Create `test/services/ble/multi_packet_receiver_test.dart`
  - [x] Test: header packet detection (data[0] == 0x00)
  - [x] Test: size extraction from header
  - [x] Test: data packet accumulation
  - [x] Test: completion detection
  - [x] Test: incomplete state handling
- [x] Create `test/services/ble/real_nir_scan_service_test.dart`
  - [x] Test: connection state stream emission
  - [x] Test: device discovery filtering
  - [x] Test: disconnect cleanup
- [x] Create test mocks/helpers for BluetoothDevice (via mockito @GenerateMocks)

### Phase 2: Core BLE Infrastructure 🔧
- [x] Create `lib/services/ble/multi_packet_receiver.dart`
  - [x] onPacketReceived(List<int>) method
  - [x] isComplete getter
  - [x] data getter (List<int>)
  - [x] progress getter
  - [x] reset() method
  - [ ] timeout handling (future enhancement)
- [x] Create `lib/services/ble/real_nir_scan_service.dart` scaffold
- [x] Implement startDeviceScan()
- [x] Implement stopDeviceScan()
- [x] Implement connect(deviceId)
- [x] Implement disconnect()
- [x] Implement connectionState stream

### Phase 3: Read Operations 📖
- [x] Create characteristic read helper (_readStringCharacteristic, _readUint16Characteristic)
- [x] Implement getDeviceInfo()
  - [x] Read DIS_MANUF_NAME
  - [x] Read DIS_MODEL_NUMBER
  - [x] Read DIS_SERIAL_NUMBER
  - [x] Read DIS_HW_REV
  - [x] Read DIS_TIVA_FW_REV
  - [x] Read DIS_SPECC_REV
- [x] Implement getDeviceStatus()
  - [x] Read BAS_BATT_LVL
  - [x] Read GGIS_TEMP_MEASUREMENT
  - [x] Read GGIS_HUMID_MEASUREMENT
  - [x] Read GGIS_DEV_STATUS
  - [x] Read GGIS_ERR_STATUS
- [x] Implement notification subscription helper
- [x] Subscribe to notification characteristics (sıralı)

### Phase 4: Scan Foundation 🔬
- [x] Implement syncTime()
- [x] Implement performScan() basic flow
- [x] Implement multi-packet scan data handling
- [x] Stub remaining methods (throw UnsupportedError)

## Completed
(none yet)

## Blockers
(none yet)

## Notes
- TDD: Her task için önce test yaz, sonra implement et
- flutter_blue_plus mock'ları için mockito kullan
- Gerçek sensör testleri ayrı integration test olarak işaretle
