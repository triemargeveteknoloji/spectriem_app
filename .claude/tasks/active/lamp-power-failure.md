# lamp-power-failure

**Created:** 2026-02-04
**Status:** 🚧 In Progress

---

## Problem

Sensör scan trigger'ı kabul ediyor ve notification gönderiyor, ancak 0xFF (success) yerine 0x01 (Lamp power failure) döndürüyor.

**Kaynak:** `scan-completion-timeout` task'ından ayrıldı

**Gözlemler:**
- USB üzerinden Windows uygulamasıyla tarama başarılı
- Bluetooth üzerinden aynı sensörde "Lamp power failure" hatası
- Error status: 0x80 (TMP006 sensor warning - muhtemelen kalıcı)
- Device status: 0x31
- Config index 6 geçerli listede ([4, 6]) ama yazma başarısız

**Integration Test Evidence:**
```log
[SCAN] Pre-scan error status: 0x0080
[SCAN] Current active config: 0x0006 (index: 6)
[SCAN] Active config 6 is valid, using as-is
[SCAN] Notification at T+1723ms | Size: 5B | First: 0x01
[SCAN] FAILED | Error: 0x01 (Lamp power failure)
```

---

## Collected Notes

**TI SDK'dan bilgiler:**
- 0x01 = SCAN_LAMP_FAILURE
- Config parametreleri out-of-range olabilir
- Default factory config ile başlamak önerilir
- Config yazma: device busy, invalid index, wrong char olabilir

**Potansiyel Nedenler:**
1. Config parametreleri (exposure time, lamp settings) uyumsuz
2. Config yazma başarısız - sensör yanlış config kullanıyor
3. Batarya/güç sorunu (BT'de daha fazla güç tüketimi?)
4. Firmware quirk - BT bağlantısında farklı davranış

---

## Approach

**Chosen:** Multi-phase pre-scan overhead reduction + GCS error reset
**Why:** USB'de çalışıp BT'de fail etmesi, BLE data transfer overhead'inin firmware'i scan moduna geçerken sorun yaratmasını gösteriyor. Birden fazla olası nedene karşı katmanlı yaklaşım.

**Phases implemented:**
1. Skip failed config indices (10s timeout savings)
2. Remove pre-scan config refresh (configs loaded at connection time)
3. Move diagnostic reads to post-failure only
4. Add 1s pre-scan cooldown after calibration refresh
5. GCS resetErrorStatus command (post-connection + retry)
6. Integration test retry logic (error reset + 5s delay + retry)

---

## Decisions

- ⚡ Config refresh removed from performScan - Android ref app da bunu yapmıyor, connection'da yükleniyor
- ⚡ Pre-scan cooldown only after actual calibration refresh (not in test mode)
- GCS error reset `[0x05, 0x04, 0x03, 0x00]` - hiç denenmemişti, investigation tool olarak eklendi
- Diagnostic reads moved to post-failure - pre-scan overhead azaltmak için

---

## Constraints

- USB'de çalışıyor, BT'de çalışmıyor
- Error status 0x80 kalıcı görünüyor (TMP006)
- Config yazma başarısız

---

## Related Files

- `lib/services/ble/ble_nir_scan_service.dart` - performScan, resetErrorStatus, _failedConfigIndices, _readDiagnosticStatus
- `lib/services/ble/nir_scan_service.dart` - resetErrorStatus interface
- `lib/services/ble/mock_nir_scan_service.dart` - resetErrorStatus no-op
- `lib/providers/sensor_communication_notifier.dart` - post-connection resetErrorStatus call
- `integration_test/steps/perform_scan_step.dart` - retry logic with error reset
- `integration_test/observability/observable_service.dart` - resetErrorStatus delegate
- `test/services/ble/ble_nir_scan_service_test.dart` - removed config refresh test
- `.claude/skills/dlpnirnanoevm-sensor/` - Protokol referans

---

## Tasks

- [x] Add _failedConfigIndices to skip timed-out config indices
- [x] Remove pre-scan config refresh from performScan
- [x] Move diagnostic reads to post-failure only
- [x] Add 1s pre-scan cooldown after calibration refresh
- [x] Implement GCS resetErrorStatus command
- [x] Add resetErrorStatus to post-connection init
- [x] Improve integration test retry logic (error reset + 5s delay)
- [x] Update observable_service with resetErrorStatus
- [x] Remove skipScanConfigCheckForTesting + dead _ensureActiveScanConfig
- [x] All unit tests pass (236 pass, 2 pre-existing failures)
- [x] flutter analyze clean (no new warnings)
- [ ] Integration test on physical device
- [ ] If still failing: increase cooldown to 2-3s
- [ ] If still failing: try removing pre-scan spectrum cal coeff fetch
- [ ] If still failing: try NNO_CMD_DLPC_ENABLE before scan

---

## Sessions

**S1** (2026-02-14): ⚡ Implemented 7-phase fix for lamp power failure. Removed pre-scan config refresh + diagnostic reads, added 1s cooldown, GCS resetErrorStatus, failed config index tracking. All unit tests pass. Needs physical device verification.
