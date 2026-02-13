# BLE Workflow Karsilastirma Raporu

**Tarih:** 2026-02-13

Yeni kaynak (TI manual s.53-57 diagramlar) + Serhat abi'nin notlarıyla mevcut uygulamadaki BLE akışlarını karşılaştırma. Üç kaynak arasındaki bariz farkları tespit etme.

**Kaynaklar:**
- **Manual**: TI User's Guide s.53-57 flowchart diagramları
- **Skill docs**: `.claude/skills/dlpnirnanoevm-sensor/`
- **nirscan-android**: `.claude/skills/nirscan-android/` referans uygulama analizi
- **App**: `lib/services/ble/ble_nir_scan_service.dart` mevcut implementasyon

---

## FARK 1 - KRITIK: Spectrum Calibration Coefficients Eksik

### Manual diyor:
```
GATT Calibration Service:
  1. Subscribe to Return Spectrum Calibration Coefficients notification
  2. Write to Request Spectrum Calibration Coefficients
  3. DLP NIRscan Nano returns spectrum calibration coefficients
  4. (sonra Reference Cal Coeff)
  5. (sonra Reference Cal Matrix)
```
**UC adim** - Spectrum Cal Coeff ilk sirada.

### Skill docs:
- `gcisReqSpecCalCoeff` (0x4348410D) / `gcisRetSpecCalCoeff` (0x4348410E) - 6 x float64 = 48 byte
- Wavelength-to-pixel mapping polynomial (p0-p4 + shift)
- Dokumanlanmis, "first connection'da alinmali" diyor

### nano_gatt.dart:
- UUID'ler **tanimli**: `gcisReqSpecCalCoeff` (satir 156), `gcisRetSpecCalCoeff` (satir 161)
- `notificationCharacteristics` listesinde **ilk sirada** (satir 291)
- Yani subscribe ediliyor, ama **hic kullanilmiyor**

### App (ble_nir_scan_service.dart):
- `_ensureCalibrationData()` (satir 1341): Sadece **2 adim**:
  1. `_fetchCalibrationCoefficients()` -> `gcisReqRefCalCoeff` (Reference, Spectrum degil!)
  2. `_fetchCalibrationMatrix()` -> `gcisReqRefCalMatrix`
- `getCalibrationData()` (satir 1495): `CalibrationData(coefficients, matrix)` - sadece ref coeff + matrix
- **Spectrum Cal Coeff HICBIR YERDE FETCH EDILMIYOR**

### CalibrationData modeli (nir_scan_service.dart:112):
```dart
class CalibrationData {
  final Uint8List coefficients;  // Reference Cal Coeff
  final Uint8List matrix;        // Reference Cal Matrix
  // Spectrum Cal Coeff icin ALAN YOK
}
```

### Etki:
Spectrum calibration coefficients, wavelength-to-pixel donusumu icin polynomial katsayilari icerir (6 x float64 = 48 byte). Bunlar olmadan dalga boyu hesaplamalari **yanlis** olabilir. `CalibrationData` modelinde bu veri icin alan bile tanimlanmamis.

### nirscan-android:
Android uygulamasi da kalibrasyon akisinda reference coefficients + matrix cekiyor. Spectrum cal coeff ayri bir adim olarak gorulmuyor referans kodda, ama manual acikca gosteriyor.

---

## FARK 2 - KRITIK: Kalibrasyon Her Scan Oncesi Cekilmiyor

### Manual (Serhat abi notu, s.53-57):
> "calibrationlar her cihaza baglanma ve her yeni okuma oncesi indirilmeli"

### App:
```dart
// _ensureCalibrationData() - satir 1341
Future<void> _ensureCalibrationData() async {
  if (_cachedRefCalCoeff != null && _cachedRefCalMatrix != null) {
    return; // Already cached - BIR DAHA CEKILMIYOR
  }
  // ... fetch only if null
}
```

- Kalibrasyon **bir kez** cekilip cache'leniyor (per-connection)
- `performScan()` (satir 462): Sadece **varligini kontrol ediyor**, yoksa exception atiyor
- Cache invalidation sadece disconnect'te oluyor

### Manual vs App:
| | Manual | App |
|---|---|---|
| Baglanti sonrasi | Her baglantigta cek | Sadece manual buton |
| Scan oncesi | Her scan oncesi cek | Cache'den kullan |
| Invalidation | Her scan cycle | Sadece disconnect |

### Skill docs farki:
Skill docs "Do NOT retry during normal operations" diyor - bu manual ile celisiyor. Manual daha yeni/guncel kaynak olarak oncelikli olmali.

---

## FARK 3 - ONEMLI: Kalibrasyon Otomatik Degil

### Manual akisi:
```
Baglan -> Kalibrasyon Cek -> Scan Config Cek -> Scan Yap
```
Kalibrasyon flow'un **zorunlu parcasi**.

### App akisi:
```dart
// SensorCommunicationNotifier._onConnectionStateChanged (satir 43)
if (isNowConnected && !wasConnected) {
  loadConfigurations();  // Sadece config yukleniyor!
  // Kalibrasyon YUKLENMIYOR - manual buton gerekli
}
```

```dart
// performScan (satir 462-470)
final hasCalibration = _cachedRefCalCoeff != null && _cachedRefCalMatrix != null;
if (!hasCalibration) {
  throw const CalibrationRequiredException(); // Exception atiyor, auto-fetch yok
}
```

### Sonuc:
Kullanici baglanti sonrasi **onceden** "Get Calibration" butonuna tiklamamissa, scan basarisiz olur. Manual'e gore otomatik olmali.

---

## FARK 4 - ONEMLI: Scan Configuration Her Scan Oncesi Cekilmiyor

### Manual (Serhat abi notu):
> "Aynisi scan configuration icin de gecerli"
> "tum scan configurationlari cekmeniz lazim diyor"

### Manual diagrami:
Scan config akisi, scan oncesinde cagrilacak sekilde gosteriliyor.

### App:
- `loadConfigurations()`: Sadece **baglanti aninda** bir kez cagiriliyor (satir 50)
- `performScan()` -> `_ensureActiveScanConfig()`: Config **index'leri** okuyor ama **full config data** cekmiyor
- `_ensureActiveScanConfig()` (satir 1508): numConfigs + indices okuyor, active config verify ediyor ama config iceriklerini yeniden cekmiyor

### Manual vs App:
| | Manual | App |
|---|---|---|
| Baglanti sonrasi | Tum configleri cek | Tum configleri cek (otomatik) |
| Scan oncesi | Tum configleri yeniden cek | Sadece index/active verify |
| Config degisikligi | Her seferinde guncel | Stale olabilir |

---

## FARK 5 - ORTA: Scan Config Iterasyon Yaklasimi

### Manual diagrami:
```
For each config:
  Write scan config ID -> Receive that specific config -> Loop
```
**Tek tek** her config icin ayri request.

### App (ble_nir_scan_service.dart satir 910-924):
```dart
for (final index in configIndices) {
  final fetchedConfigs = await _fetchAllConfigsData(index);
  for (final config in fetchedConfigs) {
    configMap[config.index] = config; // Deduplicate
  }
}
```
- `_fetchAllConfigsData` yorumu (satir 991-992): "TI firmware returns all configs in one response regardless of requested index"
- Her index icin request atiyor AMA firmware her seferinde TUM configleri donduruyor
- configMap ile deduplicate ediyor -> **N kere ayni veriyi parse ediyor**

### Etki:
Yaklasim calisiyor ama verimsiz. Manual'in one-at-a-time yaklasimi firmware davranisiyla uyusmayabilir (firmware her zaman tum configleri donduruyor olabilir).

---

## FARK 6 - DUSUK: Scan Sonrasi Serialized Data Request

### Manual diagrami (New Scan):
```
Start Scan -> Subscribe metadata notifications -> Request metadata -> INTERPRET
```
Manual'de yeni scan icin **serialized scan data structure** request'i acikca **gosterilmiyor**. "Interpret data" adimina direkt gidiyor.

### App + nirscan-android:
Her ikisi de scan sonrasi **acikca** serialized scan data request ediyor:
```
Start Scan -> Get metadata -> Request Serialized Scan Data -> Return raw data
```

### Yorum:
Manual diagrami bu adimi atlamis olabilir (simplified). Gercekte scan data'yi almadan interpret yapilamaz. Bu fark muhtemelen diagram'in basitlestirilmesinden kaynakli.

---

## FARK 7 - DUSUK: Subscription Zamanlama

### Manual diagrami:
Her islemde ayri "Subscribe to X notification" adimi gosteriyor.

### App:
Tum notification'lar **baglanti aninda bir kez** subscribe ediliyor (13 characteristic, 100ms arayla - `notificationCharacteristics` listesi, nano_gatt.dart satir 290-304).

### Yorum:
App yaklasimi dogru ve optimize. BLE notification subscription'lari kalici, her islem oncesi yeniden subscribe etmeye gerek yok. Manual sadece protokol akisini gosteriyor.

---

## FARK 8 - BILGI: Lamp Power Error Handling

### Manual + Skill docs:
```
Start Scan response:
  0xFF = success
  0x01 = Lamp power failure
  0x02 = ADC overflow/saturation
  0x03 = Pattern stream error
  0x04 = DLP subsystem failure
```

Ayrica GGIS error status (0x43484104) okunarak detayli error flag'leri alinabiliyor.

### App:
- `performScan()`: Pre-scan error status okuyor (satir 482-502) - **iyi**
- Scan response'da 0xFF kontrolu var - **iyi**
- Error durumunda `[SCAN] Device returned error: $firstByte` loglaniyor - **iyi**
- Ama spesifik error code mapping (lamp power = 0x01 vs ADC = 0x02 vs ...) gorunmuyor

### Yorum:
Error detection mevcut ama kullaniciya spesifik hata mesaji (ornegin "Lamba gucu hatasi") gosterilmiyor. Genel "error" olarak raporlaniyor.

---

## OZET TABLOSU

| # | Fark | Seviye | Manual | App | Durum |
|---|------|--------|--------|-----|-------|
| 1 | Spectrum Cal Coeff | **KRITIK** | 3 adimli kalibrasyon | 2 adim (spectrum eksik) | UUID tanimli ama kullanilmiyor |
| 2 | Kalibrasyon tekrari | **KRITIK** | Her scan oncesi | Cache, 1 kez per-connection | Manual farkli diyor |
| 3 | Auto kalibrasyon | **ONEMLI** | Otomatik flow'da | Manual buton gerekli | Auto-fetch olmali |
| 4 | Config tekrari | **ONEMLI** | Her scan oncesi tum configler | 1 kez per-connection | Manual farkli diyor |
| 5 | Config iterasyon | ORTA | Tek tek request | Bulk parse + deduplicate | Calisiyor ama verimsiz |
| 6 | Scan data request | DUSUK | Acikca gosterilmiyor | Acikca request ediliyor | Manual simplified olabilir |
| 7 | Subscription zamanlama | DUSUK | Per-operation | Per-connection (optimize) | App yaklasimi dogru |
| 8 | Error code mapping | BILGI | Spesifik kodlar | Genel error log | Iyilestirilebilir |

---

## KAYNAKLAR

Bu farklar dogrudan kod okuma ve kaynak karsilastirmasi ile tespit edilmistir:
- `nano_gatt.dart`: UUID tanimlari (spectrum cal coeff mevcut ama kullanilmiyor)
- `ble_nir_scan_service.dart`: `_ensureCalibrationData()` sadece ref coeff + matrix
- `sensor_communication_notifier.dart`: `_onConnectionStateChanged()` sadece config yukleme
- Manual diagramlar (TI User's Guide s.53-57): 3 adimli kalibrasyon + her scan oncesi refresh
- Serhat abi notlari: "calibrationlar her cihaza baglanma ve her yeni okuma oncesi indirilmeli"
