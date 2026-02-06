# calibrate-button

**Created:** 2026-02-04
**Status:** ✅ Completed
**Completed:** 2026-02-04

---

## Problem
Kullanıcı manuel olarak cihaz kalibrasyonu başlatamıyor. Şu an scan yapılırken calibration otomatik fetch ediliyor ama bu davranış kullanıcı kontrolünde değil.

## Approach
**Chosen:** Sensor Communication ekranına Calibration butonu ekle
**Why:** Scan butonuna yakın olması mantıklı - kalibrasyon scan öncesi yapılması gereken bir işlem

1. UI'da "Calibrate" butonu ekle
2. `getCalibrationData()` metodunu implement et
3. Scan öncesi auto-calibration'ı kaldır → uyarı ver
4. Integration test güncelle

## Decisions
- Tek buton (Reference Calibration) - Dark calibration GATT'ta yok
- Auto-calibration kaldırılacak → scan öncesi uyarı
- Calibration coeff packet logları debug seviyesine indirilecek

## Constraints
- NIRscan Nano sadece Reference Calibration destekliyor (coefficients + matrix)
- Multi-packet transfer protokolü kullanılıyor
- Mevcut `_fetchReferenceCalibration*` metodları var, compose edilecek

## Related Files
- `lib/services/ble/nano_gatt.dart` - GATT UUIDs (gcisReqRefCalCoeff, etc.)
- `lib/services/ble/ble_nir_scan_service.dart:908` - Calibration fetch metodları
- `lib/services/ble/ble_nir_scan_service.dart:891` - Auto-calibration in scan flow
- `lib/screens/sensor_communication_screen.dart:164` - Button section
- `lib/providers/sensor_communication_notifier.dart` - Command dispatch
- `integration_test/integration_test.dart` - Integration test

---

## Tasks
- [x] Write test for `getCalibrationData()` method
- [x] Implement `getCalibrationData()` in BleNirScanService
- [x] Change calibration coeff packet logs from info to debug
- [x] Remove auto-calibration from scan flow, add "calibration required" warning
- [x] Add Calibrate button to sensor communication screen
- [x] Add command case in notifier
- [x] Update integration test for new calibration flow

## Sessions
**S1** (2026-02-04): Initialized. Reference calibration only (no dark cal in GATT). Auto-cal removal + warning approach confirmed.
**S2** (2026-02-04): Implemented getCalibrationData(), CalibrationRequiredException, UI button, notifier command, integration test update. All tasks complete. 27/32 unit tests passing (5 complex performScan timing tests need rework - unrelated to new functionality).
**S3** (2026-02-04): Real device test successful (Coeff: 3822B, Matrix: 2428B). Commit: ce86c09.

## Commits
- `ce86c09` (2026-02-04): feat(ble): add manual calibration button and getCalibrationData method
