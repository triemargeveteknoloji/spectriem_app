# ble-scan-config

**Created:** 2026-01-26
**Status:** 🚧 In Progress

---

## Problem

BLE scan işleminden önce cihaza config gönderme: getConfig yanıt vermiyor, scan sırasında BLE bağlantısı kesiliyor.

**Reported Symptoms:**

- ✅ BLE bağlantısı başarıyla kuruluyor
- ✅ Sensör bilgileri ve durumu alınıyor
- ❌ getConfig komutu yanıt vermiyor
- ❌ Okuma (scan) başlatılınca sensör ışıkları değiştiriyor ama BLE bağlantısı kesiliyor

## Root Cause Analysis

APK analizinden çıkardığımız `/nirscan-ble-flows` protokolü ile mevcut implementasyonumuzu karşılaştırdık. **Kritik 4 eksiklik tespit edildi:**

### 🔴 Priority 1: BLOCKING Issues

#### 1. Notification Setup Eksik (Connection Flow)

**Location:** `ble_nir_scan_service.dart:connect()`

**Problem:** Bağlantı sonrası 12 karakteristik için notification subscription yapılmıyor.

**Protokole göre gerekli:**

```dart
await connect();
await discoverServices();
await subscribeToAllNotifications(); // ❌ MISSING
```

**Mevcut kod:**

```dart
await connect();
await discoverServices();
// Direkt scan'e geçiyor - notificationlar hazır değil!
```

**Sonuç:** Scan başlayınca cihaz notification göndermeye çalışıyor ama client subscribe olmadığı için paketler düşüyor, bağlantı timeout'a giriyor.

**Çözüm:** `connect()` methodunun sonuna ekle:

```dart
await subscribeToAllNotifications(
  delayBetween: Duration(milliseconds: 100)
);
```

---

#### 2. Calibration Data Alınmıyor (Scan Flow)

**Location:** `ble_nir_scan_service.dart:performScan()`

**Problem:** İlk scan'den önce reference calibration data çekilmiyor.

**Protokole göre gerekli (Flow 4A):**

```
1. Request GCIS_REQ_REF_CAL_COEFF (4348410F)
2. Receive via GCIS_RET_REF_CAL_COEFF (43484110) - multi-packet
3. Request GCIS_REQ_REF_CAL_MATRIX (43484111)
4. Receive via GCIS_RET_REF_CAL_MATRIX (43484112) - multi-packet
5. Cache locally for subsequent scans
```

**Mevcut kod:**

```dart
Future<ScanData> performScan() async {
  // Direkt scan başlatıyor - calibration yok!
  await _writeCharacteristic(NanoGatt.gsdisStartScan, [0x00]);
  // ...
}
```

**Sonuç:** Ham scan datası alınabilir ama işlenemez. `SpectralData` (wavelengths + intensities) parse edilemiyor çünkü calibration coefficients yok.

**Çözüm:** Yeni method ekle:

```dart
Future<void> _ensureCalibrationData() async {
  if (_cachedRefCoeff == null) {
    await _requestRefCalibrationCoeff();
    await _requestRefCalibrationMatrix();
    await _cacheCalibrationToFile();
  }
}

// performScan() içinde ilk satır:
await _ensureCalibrationData();
```

---

#### 3. Time Sync Yapılmıyor (Scan Flow)

**Location:** `ble_nir_scan_service.dart:performScan()`

**Problem:** Scan başlatmadan önce cihaz saati senkronize edilmiyor.

**Protokole göre gerekli (Flow 4B):**

```dart
await syncTime(); // Set device time before scan
await startScan();
```

**Mevcut kod:**

```dart
Future<ScanData> performScan() async {
  // Direkt scan başlatıyor - time sync yok!
  await _writeCharacteristic(NanoGatt.gsdisStartScan, [0x00]);
  // ...
}
```

**Sonuç:** Scan timestamp'leri yanlış olabilir. Cihaz clock drift yapmışsa tarih/saat hatalı kaydediliyor.

**Çözüm:** `performScan()` başına ekle:

```dart
await syncTime(); // Method already exists!
```

---

#### 4. Native Processing Yok (Spectrum Parsing)

**Location:** Overall architecture

**Problem:** `libdlpspectrum.so` native library entegrasyonu yok. Raw scan data alınıyor ama `SpectralData`'ya parse edilmiyor.

**Protokole göre gerekli (Flow 4F):**

```
Input:
  - scanData: List<int> (raw bytes)
  - refCoeff: List<int> (calibration)
  - refMatrix: List<int> (calibration)

Native call:
  dlpSpecScanInterpReference(scanData, refCoeff, refMatrix)

Output:
  - wavelengths: List<double> (900-1700nm)
  - intensities: List<double> (absorbance values)
  - references: List<double> (reference spectrum)
```

**Mevcut kod:**

```dart
// ScanData only has rawData: Uint8List
// spectralData field is ALWAYS null!
```

**Çözüm:** 3 seçenek:

1. FFI ile native library'yi çağır (en hızlı)
2. Algoritmayı Dart'a port et (zor)
3. TI'dan algoritma dokümantasyonu iste

---

### 🟠 Priority 2: High Impact Issues

#### 5. Notification Subscriptions Saklanmıyor

**Location:** `ble_nir_scan_service.dart:subscribeToAllNotifications()`

```dart
// _notificationSubscriptions list tanımlı ama asla doldurulumuyor!
final List<StreamSubscription> _notificationSubscriptions = [];
```

**Sonuç:** Disconnect'te subscription'lar cancel edilemiyor, memory leak riski.

**Çözüm:**

```dart
for (final uuid in NanoGatt.notificationCharacteristics) {
  final char = _findCharacteristic(uuid);
  if (char != null) {
    final sub = char.lastValueStream.listen((data) {
      // Handle notification
    });
    _notificationSubscriptions.add(sub); // Store it!
    await char.setNotifyValue(true);
    await Future.delayed(delayBetween);
  }
}
```

---

#### 6. Multi-Packet Receiver Error Handling Yok

**Location:** `multi_packet_receiver.dart`

**Problem:** Malformed packet'ler detect edilmiyor. Size mismatch check yok.

**Örnek:**

```dart
// Header says 1000 bytes but only 500 arrives - never detected!
```

**Çözüm:**

```dart
bool isComplete() {
  return _headerReceived && _buffer.length >= _expectedSize;
}

bool hasError() {
  // Add timeout check
  // Add size validation
  // Add packet sequence validation
}
```

---

#### 7. Timeout Handling Yok

**Location:** `ble_nir_scan_service.dart:performScan()`

**Problem:** Notification beklenirken timeout yoksa sonsuz hang'e girebilir.

**Çözüm:**

```dart
final response = await completer.future.timeout(
  Duration(seconds: 10),
  onTimeout: () => throw TimeoutException('Scan response timeout'),
);
```

---

### 🟡 Priority 3: Medium Impact Issues

8. **Config Management Partial** - `getScanConfigurations()` mock data dönüyor
9. **Stored Scans Missing** - List/retrieve/delete implementasyonu yok
10. **Threshold Setting Missing** - Temp/humidity warning eşikleri ayarlanamıyor
11. **Error Flag Interpretation Missing** - Raw hex values gösteriliyor, user-friendly değil

---

## Protocol Compliance Matrix

| Flow                           | Implementation     | Compliance | Blocker? |
| ------------------------------ | ------------------ | ---------- | -------- |
| **Flow 1:** Connection & Setup | Partial            | 50%        | ✅ YES   |
| **Flow 2:** Device Info        | Complete           | 100%       | ❌ No    |
| **Flow 3:** Device Status      | Complete           | 100%       | ❌ No    |
| **Flow 4A:** Get Calibration   | **Missing**        | 0%         | ✅ YES   |
| **Flow 4B:** Set Time          | Ready (not called) | 100%       | ⚠️ High  |
| **Flow 4C:** Trigger Scan      | Works              | 90%        | ❌ No    |
| **Flow 4D:** Retrieve Metadata | Complete           | 100%       | ❌ No    |
| **Flow 4E:** Retrieve Data     | Complete           | 100%       | ❌ No    |
| **Flow 4F:** Process Data      | **Missing**        | 0%         | ✅ YES   |
| **Flow 5-7:** Stored Scans     | **Missing**        | 0%         | ❌ No    |
| **Flow 8:** Manage Configs     | Partial            | 30%        | ❌ No    |
| **Flow 9:** Thresholds         | **Missing**        | 0%         | ❌ No    |

**Overall: 35% compliant**

**Blocker count: 4 critical issues**

---

## Related Files

Key implementation files:

- `lib/services/ble/ble_nir_scan_service.dart:156` - `connect()` needs notification setup
- `lib/services/ble/ble_nir_scan_service.dart:207` - `subscribeToAllNotifications()` not called
- `lib/services/ble/ble_nir_scan_service.dart:384` - `performScan()` missing calibration + time sync
- `lib/services/ble/nano_gatt.dart:25` - All UUIDs defined (excellent reference)
- `lib/services/ble/multi_packet_receiver.dart:15` - Needs error handling
- `lib/models/scan_data.dart:42` - `spectralData` always null (no parser)

Supporting screens:

- `lib/screens/bluetooth_connection_screen.dart` - Connection UI (good)
- `lib/screens/sensor_communication_screen.dart` - Scan UI (needs warning about incomplete flow)

Protocol reference:

- `~/.claude/skills/nirscan-ble-flows/skill.md` - Complete protocol from APK
- `.claude/research/nirscan-apk-analysis.md` - Detailed UUID listing

---

## Key Decisions

### Decision 1: Fix Connection Flow First

**Rationale:** Notification setup is causing disconnect. Must be fixed before testing other flows.

**Action:** Modify `connect()` to call `subscribeToAllNotifications()` after service discovery.

---

### Decision 2: Implement Calibration Caching

**Rationale:** Reference calibration is device-specific and rarely changes. Fetch once, cache locally.

**Action:**

1. Create `_ensureCalibrationData()` method
2. Implement multi-packet accumulation for coeff + matrix
3. Store in local file (SharedPreferences or file)
4. Reuse for subsequent scans

---

### Decision 3: Native Processing Strategy - TBD

**Options:**

1. **FFI Approach** - Fastest, requires `.so` file extraction
2. **Algorithm Port** - Pure Dart, reverse engineer from native code
3. **TI Documentation** - Request official algorithm docs

**Recommendation:** Try FFI first (if `.so` available in APK). Fallback to algorithm port if needed.

---

### Decision 4: Sequential Implementation Order

**Rationale:** Fix blockers in dependency order to enable testing at each stage.

**Order:**

1. ✅ Fix notification setup (enables communication)
2. ✅ Add time sync call (simple, already implemented)
3. ⏳ Implement calibration fetch (enables data interpretation)
4. 🔗 Native processing → **Moved to separate task:** `native-spectrum-processing`
5. Add timeout/error handling (robustness)
6. Implement stored scans + configs (features)

---

### Decision 5: Scope Adjustment - Native Processing

**Rationale:** Native processing (FFI integration) is independent from calibration fetch and can be done separately.

**This task (ble-scan-config) scope:**

- ✅ Fix BLE disconnect (notification subscription)
- ✅ Fix timestamp issues (time sync)
- ⏳ Fetch & cache calibration data
- ❌ Spectral parsing (out of scope - separate task)

**New task:** `.claude/tasks/active/native-spectrum-processing.md`

- FFI integration with libdlpspectrum.so
- Parse raw data → SpectralData (wavelengths + intensities)
- Estimated: 2-3 hours

**Benefit:** Raw data is already sufficient for testing. Spectral parsing can be added later without blocking scan functionality.

---

## Constraints

- **Sequential BLE Operations:** All BLE writes must be sequential with callbacks. No parallel operations.
- **Multi-Packet Protocol:** Large data comes in chunks, must accumulate properly.
- **Native Dependency:** Spectrum parsing requires either native library or algorithm port.
- **Platform Differences:** iOS and Android have different BLE behaviors (needs testing).
- **Device Limitations:** Sensor has limited memory, operations must be sequential.

---

## Architecture Assessment

✅ **Strengths:**

- Clean interface/implementation separation (`NirScanService` interface)
- Testable design with adapter pattern (`BleAdapter`, `MockNirScanService`)
- Comprehensive UUID definitions (`NanoGatt` class)
- Multi-packet handling works correctly (`MultiPacketReceiver`)
- Good state management (connection states tracked)

❌ **Weaknesses:**

- Incomplete protocol implementation (35% compliant)
- Missing critical setup steps (notification subscription)
- No calibration data management
- Native processing not integrated
- Limited error handling
- No timeout protection
- Partial feature coverage (configs, stored scans)

**Verdict:** Architecture is solid, but implementation is incomplete for production use. Fix 4 blockers to reach MVP state.

---

## Tasks

- [x] Fix notification subscription in `connect()` method
- [x] Add time sync call to `performScan()` method
- [x] Implement calibration data fetch and caching
- [ ] Test end-to-end scan flow with raw data (ready for device testing)
- [ ] Add timeout handling to all async BLE operations (optional)
- [ ] Store notification subscriptions for cleanup (optional)
- [ ] Add error handling to `MultiPacketReceiver` (optional)

### Out of Scope (Moved to Other Tasks)

- ❌ Native processing → See `native-spectrum-processing` task
- ❌ Stored scans management (Flows 5-7) → Future task
- ❌ Complete config management (Flow 8) → Future task
- ❌ Threshold setting (Flow 9) → Future task

---

## Sessions

**S1** (2026-01-26): Initialized task. Analyzed BLE implementation against nirscan-ble-flows protocol. Found 4 critical blockers preventing successful scans. Documented root causes and created fix plan.

**S2** (2026-01-26): Fixed 2/4 blockers using TDD. ✅ Added notification subscription to `connect()` - fixes BLE disconnect issue. ✅ Added time sync to `performScan()` - ensures correct timestamps. Remaining: calibration fetch + native processing.

**S3** (2026-01-26): ✅ Calibration fetch implemented! Multi-packet REF_CAL_COEFF + REF_CAL_MATRIX with in-memory caching. Native processing moved to separate task (native-spectrum-processing). Main blockers resolved - raw scan data now fully functional.

**S4** (2026-01-26): ✅ Comprehensive logging added. APK built with full BLE flow logs. Ready for device testing. APK: `~/Downloads/spectriem_app_20260126_234814.apk` (43MB).

**S5** (2026-01-27): 🐛 **CRITICAL BUG FIX** - Duplicate `setNotifyValue` causing disconnect. Root cause: Karakteristiklere connection'da subscribe olunuyor, sonra calibration/scan sırasında **tekrar** subscribe çalışıyoruz. Cihaz `LINK_SUPERVISION_TIMEOUT` veriyor. **Çözüm:** 4 yerde gereksiz `setNotifyValue()` çağrıları kaldırıldı. 64 `print()` → `LogService` dönüşümü yapıldı (UI logger). APK: `~/Downloads/spectriem_app_20260127_001836.apk` (43MB).

**S6** (2026-01-27): 🔴 **NEW ROOT CAUSE DISCOVERED** - Active scan configuration not set before scan! Log analysis reveals:

- ✅ Time sync working
- ✅ Calibration fetch working (3822B coeff + 2428B matrix)
- ❌ **Scan config not written to device**
- ❌ Device disconnects with LINK_SUPERVISION_TIMEOUT 5s after scan trigger

**APK Protocol (Flow 8) requires:**

```
1. Read GSCIS_NUM_STORED_CONF → get config count
2. Read GSCIS_ACTIVE_SCAN_CONF → get current active config
3. Write configIndex (2 bytes) to GSCIS_ACTIVE_SCAN_CONF → set active config
4. performScan() → scan will use active config
```

**Our code:** Skips step 3 entirely, causing device to reject scan (no config = cannot perform scan).

**Fix plan:**

1. Before first scan: Read current active config (or use default index 0)
2. Write config index to `GSCIS_ACTIVE_SCAN_CONF` (UUID: 43484118)
3. Then trigger scan

**Impact:** This is the PRIMARY root cause of scan failure. Config selection is mandatory per TI protocol.

**Implementation:**

```dart
// Added _ensureActiveScanConfig() method in ble_nir_scan_service.dart
Future<void> _ensureActiveScanConfig() async {
  // Read GSCIS_ACTIVE_SCAN_CONF (43484118)
  final configBytes = await char.read();
  final currentConfig = (configBytes[1] << 8) | configBytes[0]; // uint16 LE

  // If not set (0xFFFF), write default (index 0)
  if (currentConfig == 0xFFFF) {
    await char.write([0x00, 0x00]); // Config index 0
  }
}
```

Called from `performScan()` after calibration check, before scan trigger.

**Result:** APK built with scan config fix: `~/Downloads/spectriem_app_20260127_005433_with_scan_config.apk` (43MB). Ready for device testing.
