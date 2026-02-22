# align-ble-workflows

**Created:** 2026-02-13
**Status:** 🚧 In Progress

---

## Collected Notes

Kaynak: `.claude/research/ble-workflow-comparison.md`

TI User's Guide s.53-57 diagramlari ve Serhat abi'nin notlariyla karsilastirma sonucu tespit edilen farklar dogrultusunda kod degisiklikleri yapilacak. Integration testi de buna gore guncellenecek.

### Kritik Farklar (implementasyon gerekli):
1. **Spectrum Calibration Coefficients eksik** - UUID tanimli (gcisReqSpecCalCoeff/gcisRetSpecCalCoeff) ama hic fetch edilmiyor. CalibrationData modelinde alan yok.
2. **Kalibrasyon her scan oncesi cekilmiyor** - Manual her baglanti + her scan oncesi diyor, app sadece cache'liyor.
3. **Kalibrasyon otomatik degil** - Baglanti sonrasi auto-fetch yok, manual buton gerekli.
4. **Scan config her scan oncesi cekilmiyor** - Manual her scan oncesi diyor, app sadece baglanti aninda yukluyor.

### Dusuk oncelikli (deferred):
5. Config iterasyon verimsizligi (N kere ayni veriyi parse)
6. Error code mapping (lamp power = 0x01 vs genel error)

---

## Problem

TI User's Guide (s.53-57) diagrams ve Serhat abi'nin notlari, uygulamamizin BLE workflow'unun manual'den 4 kritik noktada farklilasitigini gosteriyor:

1. **Spectrum Cal Coeff hic cekilmiyor** - Manual 3 adimli kalibrasyon tanim ediyor (Spectrum Cal Coeff → Ref Cal Coeff → Ref Cal Matrix). Uygulama sadece 2 adim yapiyor (Ref Cal Coeff + Ref Cal Matrix). Spectrum Cal Coeff wavelength-to-pixel donusumu icin polynomial katsayilari icerir (6 x float64 = 48 byte). UUID'ler `nano_gatt.dart`'ta tanimli (`gcisReqSpecCalCoeff` 0x4348410D / `gcisRetSpecCalCoeff` 0x4348410E) ve notification listesinde ilk sirada subscribe ediliyor, ama hicbir yerde kullanilmiyor.

2. **Kalibrasyon cache'leniyor, yenilenmiyor** - `_ensureCalibrationData()` (satir 1341) `_cachedRefCalCoeff != null` ise hemen donuyor. Manual her scan oncesi yeniden cekilmesini soyluyor. `performScan()` (satir 462) sadece cache'in var oldugunu kontrol ediyor, yoksa exception atiyor.

3. **Baglanti sonrasi otomatik kalibrasyon yok** - `_onConnectionStateChanged` (notifier satir 43-57) sadece `loadConfigurations()` cagiriyor. Manual akisi: Connect → Calibration → Config → Ready.

4. **Scan config scan oncesi yenilenmiyor** - `loadConfigurations()` baglanti aninda bir kez cagiriliyor. `_ensureActiveScanConfig()` (satir 1508) sadece index/active verify ediyor, full config data yeniden cekmiyor.

## Approach

**Chosen:** `performScan()` icinde calibration + config refresh, notifier'da auto-calibration

**Why:** Mevcut pattern'i takip ediyor - `performScan()` zaten `syncTime()` ve `_ensureActiveScanConfig()` cagiriyor. Kalibrasyon ve config refresh'i de buraya eklemek protocol dogrulugunu garanti eder, caller'larin yanlis kullanimi onlenir.

**Sira:** Phase 1 (Spectrum Cal Coeff) → Phase 2 (Cache Invalidation) → Phase 3 (Config Refresh) → Phase 4 (Auto-Cal Notifier) → Phase 5 (Test Fix + Integration)

Bu sira `ble_nir_scan_service.dart` degisikliklerini gruplayip context switch'i minimize ediyor.

## Decisions

- **Spectrum cal coeff hard error**: Fetch basarisiz olursa exception throw eder, scan'i bloklar. TI manual'inin zorunlu adimi.
- **`performScan()` internal refresh**: Calibration + config refresh `performScan()` icinde yapilir. Caller'in ayri cagirmasi gerekmez.
- **`spectrumCoefficients` raw `Uint8List`**: Mevcut `coefficients` ve `matrix` pattern'iyle tutarli. `Float64List` parse etme gelecekte ayri katmanda yapilir.
- **`isCalibrationLoaded` as `bool?`**: Notifier state'ine `null` = denenmedi, `true` = yuklendi, `false` = basarisiz. Basit ve yeterli.
- **`CalibrationRequiredException` korunuyor**: `performScan()` artik kendisi calibration cektigi icin oradan unreachable oluyor, ama API uyumlulugu icin kalir.

## Constraints

- TDD: Testler implementasyondan once yazilacak
- `BleNirScanService` ve `MockNirScanService` birlikte guncellenecek
- `CalibrationData` constructor degisikligi tum test dosyalarini etkiler
- Freezed state degisikligi `build_runner` gerektirir
- `getScanConfigurations()` `_withBleLock` kullaniyor; `performScan()` lock tutmuyor - deadlock riski yok
- Integration test fiziksel cihaz gerektiriyor - test kodu yazilir, dogrulama sonra yapilir

## Related Files

### Core (degisecek)
- `lib/services/ble/nir_scan_service.dart:111-120` - `CalibrationData` modeli (spectrumCoefficients eklenecek)
- `lib/services/ble/ble_nir_scan_service.dart:1324-1355` - Calibration cache + `_ensureCalibrationData()`
- `lib/services/ble/ble_nir_scan_service.dart:1357-1415` - `_fetchCalibrationCoefficients()` (kopyalanacak pattern)
- `lib/services/ble/ble_nir_scan_service.dart:462-480` - `performScan()` pre-scan checks (invalidate + refresh)
- `lib/services/ble/ble_nir_scan_service.dart:1495-1502` - `getCalibrationData()` return
- `lib/services/ble/ble_nir_scan_service.dart:1329-1332` - `setCalibrationDataForTesting()`
- `lib/services/ble/mock_nir_scan_service.dart:354-363` - Mock `getCalibrationData()`
- `lib/providers/sensor_communication_notifier.dart:14-21` - Freezed state (isCalibrationLoaded)
- `lib/providers/sensor_communication_notifier.dart:43-57` - `_onConnectionStateChanged()` (auto-cal)

### GATT (referans, degismez)
- `lib/services/ble/nano_gatt.dart:155-162` - Spectrum + Ref cal coeff UUID'leri
- `lib/services/ble/nano_gatt.dart:290-304` - Notification characteristics listesi

### Tests (guncellenecek)
- `test/services/ble/ble_nir_scan_service_test.dart` - Spectrum cal coeff, cache invalidation, config refresh testleri
- `test/services/ble/mock_nir_scan_service_test.dart` - Mock spectrum coeff testi
- `test/providers/sensor_communication_notifier_test.dart` - Auto-calibration testleri

### Integration (guncellenecek)
- `integration_test/steps/calibration_step.dart` - Spectrum coeff log
- `integration_test/assertions/sensor_assertions.dart` - `assertValidCalibrationData` guncelleme

### Referans
- `.claude/research/ble-workflow-comparison.md` - Karsilastirma raporu

---

## Tasks

### Phase 1: Spectrum Calibration Coefficients (ISSUE 1 - CRITICAL) ✅
- [x] Test: `getCalibrationData` returns spectrum + ref coeff + matrix
- [x] Test: mock `getCalibrationData` returns `spectrumCoefficients` field
- [x] Add `spectrumCoefficients` field to `CalibrationData` model
- [x] Add `_cachedSpecCalCoeff` cache field
- [x] Add `_fetchSpectrumCalibrationCoefficients()` method (pattern: `_fetchCalibrationCoefficients()`)
- [x] Update `_ensureCalibrationData()` - fetch spectrum first (per manual order)
- [x] Update `getCalibrationData()` return value
- [x] Update `setCalibrationDataForTesting()` signature (3 params)
- [x] Update `MockNirScanService.getCalibrationData()` - return `Uint8List(48)` spectrum

### Phase 2: Calibration Refresh Before Each Scan (ISSUE 2 - CRITICAL) ✅
- [x] Test: `performScan` re-fetches calibration each call (not cached)
- [x] Add `_invalidateCalibrationCache()` method (null all 3 fields)
- [x] Update `performScan()` - replace cache check with: invalidate → `_ensureCalibrationData()`
- [x] Update `disconnect()` / `_handleDisconnection()` to use `_invalidateCalibrationCache()`

### Phase 3: Scan Config Refresh Before Each Scan (ISSUE 4 - IMPORTANT) ✅
- [x] Test: `performScan` calls `getScanConfigurations()` before scanning
- [x] Update `performScan()` - call `getScanConfigurations()` before `_ensureActiveScanConfig()`

### Phase 4: Auto-Calibration After Connection (ISSUE 3 - IMPORTANT) ✅
- [x] Test: auto-fetches calibration on connection
- [x] Test: calibration fetched before configs
- [x] Test: calibration failure doesn't block config loading
- [x] Test: disconnect clears calibration state
- [x] Add `bool? isCalibrationLoaded` to freezed state
- [x] Add `_initializePostConnection()` method (try cal → then configs)
- [x] Update `_onConnectionStateChanged` to call `_initializePostConnection()`
- [x] Clear `isCalibrationLoaded` on disconnect
- [x] Run `build_runner` for freezed regeneration

### Phase 5: Fix Existing Tests + Integration ✅
- [x] Fix all `CalibrationData(...)` constructor calls in tests (add spectrumCoefficients)
- [x] Fix `setCalibrationDataForTesting()` calls (add 3rd arg)
- [x] Fix `CommandExecution` test lifecycle (keepAlive + AsyncValue.guard behavior)
- [x] Update `calibration_step.dart` - log spectrum coeff size + hex preview
- [x] Update `assertValidCalibrationData` - validate spectrum >= 48 bytes + hex dump on failure
- [x] Update `observable_service.dart` - spectrum coeff size + hex preview logging
- [x] Update `test_context.dart` - spectrumCoefficients field
- [x] Add `cal()` convenience method to integration_logger

### Phase 6: Integration Test Resilience (Timeout + Error Reset) ✅
- [x] Add `resetErrorStatus()` post-connect step in `full_sensor_flow.dart`
- [x] Add `TimeoutException` catch in `perform_scan_step.dart` with retry logic
- [ ] Commit + push changes

### Phase 7: Disconnect Investigation (Scan-Time Disconnect) ✅
- [x] Test: performScan completes with error immediately on disconnect (not 30s timeout)
- [x] Log `disconnectReason` (platform, code, description) in disconnect handler
- [x] Detect disconnect during scan wait - complete scanCompleter with error
- [x] Integration test: disconnect-aware scan retry (skip scan 2 on disconnect)
- [x] Physical device test: test_log(4) — no disconnect, lamp power failure instead (see Log Analysis below)

### Verification
- [x] `flutter test` - 237 pass, 1 skip, 2 pre-existing fail (bluetooth_connection_screen timing)
- [x] `flutter analyze` - no new warnings in modified files
- [x] `dart run build_runner build` - code gen succeeds
- [x] Integration test on physical device — test_log(4) analyzed (see Log Analysis)

---

## Log Analysis: test_log(4) — 2026-02-17

**Source:** `~/Downloads/test_log (4).txt` | **Device:** C370145, FW 2.1.0 | **Test result:** PASS (failures handled gracefully)

### Sonuc: Lamp Power Failure (0x01) + Coklu Donanim Hatasi

BLE baglanti stabil (disconnect yok), ancak her iki scan 0x01 (lamp power failure) ile basarisiz.

### Error Status Decode: 0x008C

| Bit | Maske | Hata | Durumu |
|-----|-------|------|--------|
| 2 | 0x004 | SD Card Error | SET |
| 3 | 0x008 | EEPROM Error | SET |
| 7 | 0x080 | TMP006 Error (sicaklik sensoru) | SET |

`resetErrorStatus` sonrasi bile ayni 0x008C — donanim kaynaklı, yazilimla temizlenemiyor.

### Timeline Ozeti

- Connect → CCCD → resetError → DeviceInfo → Config (idx 4 timeout, idx 6 OK, active=7 "Hadamard 1") → Cal (3-step OK)
- **Scan 1:** cal refresh (3.2s) → cooldown → trigger → **0x01 @ T+748ms** → error=0x008C, device=0x0033
- resetErrorStatus → 5s bekleme
- **Scan 2:** cal refresh (3.5s) → cooldown → trigger → **0x01 @ T+2057ms** → error=0x008C, device=0x0033
- Test teardown → PASS

### Onemli Gozlemler

1. **BLE disconnect yok** — test_log(3)'teki disconnect sorunu bu logda mevcut degil
2. **TMP006 hatasi** — sicaklik sensoru arizasi lamp power failure'in olasi root cause'u (firmware lamp kontolunde temp feedback kullaniyor)
3. **Config index 4** — her zaman timeout, muhtemelen corrupt/eksik (bilinen sorun)
4. **Kalibrasyon akisi dogru** — 3-step fetch, invalidate+refresh, boyutlar tutarli (144B+3822B+2428B)
5. **specCoeff 144B** — TI serialized struct (header+metadata dahil), 48B raw polynomial degil — dogru

### Root Cause Adaylari (oncelik sirasi)

1. **TMP006 arizasi** → lamp guc regulasyonu bozuk
2. **Guc kaynagi yetersizligi** → USB port/kablo kalitesi
3. **SD+EEPROM hatalari** → firmware pipeline etkisi (dolayli)

### Onerilen Donanim Aksiyon

- Cihazi power cycle (tam kapat-ac, sadece reconnect degil)
- Farkli USB port/kablo (1A+ adapter)
- 0x008C devam ederse donanim servisi gerekli

## Sessions

**S1-S3** (2026-02-13): Phase 1-5 complete. Codebase analysis, TDD implementation, parallel agent dispatch. specCoeff+refCoeff+matrix 3-step cal, cache invalidation, config refresh, auto-cal notifier, all test+integration fixes. 237 pass.
  ⚡ Key: spectrum cal coeff failure = hard error (TI manual zorunlu adim)
**S4** (2026-02-15): Phase 6 - Integration test resilience. post-connect `resetErrorStatus()` + `TimeoutException` retry logic eklendi.
**S5** (2026-02-16): ⚡ Phase 7 - Disconnect investigation. test_log(3): scan-time BLE disconnect. Fix: `disconnectReason` logging, `_onDisconnectCallbacks` ile aninda fail, disconnect-aware retry. 237 pass.
**S6** (2026-02-23): test_log(4) analizi. BLE disconnect yok (fix calisiyor), ancak lamp power failure (0x01) her iki scan'de. Error status 0x008C = SD Card + EEPROM + TMP006 (sicaklik sensoru) hatalari. Root cause muhtemelen donanim kaynakli. Yazilim tarafi dogru calisiyor.
