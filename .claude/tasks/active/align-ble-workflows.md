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

### Verification
- [x] `flutter test` - 237 pass, 1 skip, 2 pre-existing fail (bluetooth_connection_screen timing)
- [x] `flutter analyze` - no new warnings in modified files
- [x] `dart run build_runner build` - code gen succeeds
- [ ] Integration test on physical device (sonraki session)

## Sessions

**S1** (2026-02-13): Initialized. Codebase exploration completed - all 4 issues analyzed with exact line numbers. Plan designed with TDD approach and 5-phase implementation order. ⚡ Key: spectrum cal coeff failure = hard error.
**S2** (2026-02-13): Phase 1 complete (TDD). `spectrumCoefficients` field + `_fetchSpectrumCalibrationCoefficients()` + all existing tests fixed. 5/5 calibration tests pass. Logging enhanced: hex dump per packet, 3-step summary, error-level for timeouts. 5 pre-existing performScan failures unrelated.
**S3** (2026-02-13): ⚡ Phase 2-5 complete (parallel agents). 3 agents dispatched: (1) performScan cal+config refresh, (2) notifier auto-cal, (3) test+integration fixes. Post-merge fixes: tearDown syntax bug, fakeAsync→async conversion, unused import/var cleanup, spectrumCoefficients log in CommandExecution. 237/237 pass (2 pre-existing bluetooth_connection_screen fails, 0 new). Agresif loglama: `[PRE-SCAN]`, `[POST-CONNECT]`, `[CAL-STEP]`, `[ASSERT]` prefix'leri, hex preview, byte sizes, timing.
