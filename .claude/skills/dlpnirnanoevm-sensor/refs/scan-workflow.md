# Tarama İş Akışı

> Kaynak: DLPU030G User's Guide, Section 5.2.1, 5.4.2

## Genel Bakış

NIRscan Nano ile tarama yapmak için şu adımlar izlenir:
1. BLE bağlantısı kur
2. Kalibrasyon verilerini al (ilk bağlantıda)
3. Tarama konfigürasyonunu seç/ayarla
4. Tarama başlat
5. Tarama verisini al ve yorumla

---

## 1. BLE Bağlantı Akışı

```
┌─────────────────┐
│   BLE Scan      │
│   Başlat        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ "NIRScan" ile   │
│ başlayan cihaz  │
│ bul             │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ connectGatt()   │
│ autoConnect:    │
│ false           │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ STATE_CONNECTED │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ discoverServices│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ GATT_SUCCESS    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Notification    │
│ Subscription    │
│ (Sıralı)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Cihaz Hazır     │
└─────────────────┘
```

### Notification Subscription Sırası

Bağlantı sonrası aşağıdaki karakteristiklere sırayla subscribe olunmalıdır:

```dart
final subscriptionOrder = [
  'GCIS_RET_REF_CAL_COEFF',      // 1
  'GCIS_RET_REF_CAL_MATRIX',     // 2
  'GSDIS_START_SCAN',            // 3
  'GSDIS_RET_SCAN_NAME',         // 4
  'GSDIS_RET_SCAN_TYPE',         // 5
  'GSDIS_RET_SCAN_DATE',         // 6
  'GSDIS_RET_PKT_FMT_VER',       // 7
  'GSDIS_RET_SER_SCAN_DATA',     // 8
  'GSCIS_RET_STORED_CONF_LIST',  // 9
  'GSDIS_SD_STORED_SCAN_IND',    // 10
  'GSDIS_CLEAR_SCAN',            // 11
  'GSCIS_RET_SCAN_CONF_DATA',    // 12
];

for (final charName in subscriptionOrder) {
  await subscribeToCharacteristic(charName);
  await Future.delayed(Duration(milliseconds: 100));
}
```

---

## 2. Kalibrasyon Verisi Alma (İlk Bağlantı)

İlk bağlantıda kalibrasyon verileri alınmalıdır. Bu veriler cihaza özgüdür ve spektrum hesaplamaları için gereklidir.

```
┌──────────────────────────┐
│ Subscribe to             │
│ GCIS_RET_SPEC_CAL_COEFF  │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Write to                 │
│ GCIS_REQ_SPEC_CAL_COEFF  │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Wait for Notification    │
│ (Multi-packet data)      │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Subscribe to             │
│ GCIS_RET_REF_CAL_COEFF   │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Write to                 │
│ GCIS_REQ_REF_CAL_COEFF   │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Wait for Notification    │
│ (Multi-packet data)      │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Subscribe to             │
│ GCIS_RET_REF_CAL_MATRIX  │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Write to                 │
│ GCIS_REQ_REF_CAL_MATRIX  │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Wait for Notification    │
│ (Multi-packet data)      │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Parse & Store            │
│ Calibration Data         │
└──────────────────────────┘
```

### Kalibrasyon Katsayıları Yapısı

Spectrum Calibration Coefficients: 6 adet double (48 byte)
- Wavelength to pixel mapping için polynomial katsayıları

Reference Calibration: Serialized struct
- Factory referans tarama verileri

---

## 3. Tarama Konfigürasyonu

### Mevcut Konfigürasyonları Listele

```
┌──────────────────────────┐
│ Read                     │
│ GSCIS_NUM_STORED_CONF    │
└───────────┬──────────────┘
            │ count
            ▼
┌──────────────────────────┐
│ Write to                 │
│ GSCIS_REQ_STORED_CONF    │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Wait for Notification    │
│ GSCIS_RET_STORED_CONF    │
│ (List of indices)        │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ For each index:          │
│ Write index to           │
│ GSCIS_REQ_SCAN_CONF_DATA │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Wait for Notification    │
│ GSCIS_RET_SCAN_CONF_DATA │
│ (Serialized config)      │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ dlpspec_deserialize()    │
└──────────────────────────┘
```

### Aktif Konfigürasyonu Ayarla

```dart
// Aktif konfigürasyonu oku
final activeIndex = await readCharacteristic(GSCIS_ACTIVE_SCAN_CONF);

// Aktif konfigürasyonu değiştir
await writeCharacteristic(GSCIS_ACTIVE_SCAN_CONF, [newIndex & 0xFF, newIndex >> 8]);
```

### Scan Configuration Parametreleri

| Parametre | Açıklama | Tipik Değerler |
|-----------|----------|----------------|
| Name | Konfigürasyon adı | "Column1", "Hadamard1" |
| Scans to Average | Ortalama alınacak tarama | 1-18 |
| Sections | Tarama bölümü sayısı | 1-5 |
| Method | Column veya Hadamard | 0, 1 |
| Start Wavelength | Başlangıç dalga boyu | 900 nm |
| End Wavelength | Bitiş dalga boyu | 1700 nm |
| Width (nm) | Çözünürlük genişliği | 8, 10, 15, 20 nm |
| Digital Resolution | Dalga boyu noktası sayısı | 80-248 |
| Exposure Time | Pozlama süresi | 0.635-60.960 ms |

---

## 4. Tarama Başlatma

```
┌──────────────────────────┐
│ setTime()                │
│ → GDTS_TIME write        │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ setStub(prefix)          │
│ → GSDIS_SET_SCAN_NAME    │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ startScan(saveToSD)      │
│ → GSDIS_START_SCAN write │
│   [0x00 or 0x01]         │
└───────────┬──────────────┘
            │
            │ Wait for notification
            ▼
┌──────────────────────────┐
│ GSDIS_START_SCAN notify  │
│ data[0] == 0xFF          │
│ Scan Complete!           │
│ data[1-4] = scan index   │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Request scan metadata    │
└──────────────────────────┘
```

### Dart Implementasyonu

```dart
Future<ScanResult> performScan({bool saveToSd = false}) async {
  // 1. Cihaz saatini senkronize et
  await setDeviceTime(DateTime.now());

  // 2. Tarama adı prefix'i ayarla (opsiyonel)
  await setScanNameStub('MyScan');

  // 3. Tarama başlat
  final saveFlag = saveToSd ? 0x01 : 0x00;
  await writeCharacteristic(GSDIS_START_SCAN, [saveFlag]);

  // 4. Tarama tamamlanmasını bekle
  final notification = await waitForNotification(GSDIS_START_SCAN);

  if (notification[0] != 0xFF) {
    throw ScanException('Scan failed');
  }

  // 5. Scan index'i al
  final scanIndex = ScanIndex.fromBytes(notification.sublist(1, 5));

  // 6. Tarama verisini al
  return await getScanData(scanIndex);
}
```

---

## 5. Tarama Verisi Alma

### Metadata Alma

```
┌──────────────────────────┐
│ Write scan index to      │
│ GSDIS_REQ_SCAN_NAME      │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Wait for                 │
│ GSDIS_RET_SCAN_NAME      │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Write scan index to      │
│ GSDIS_REQ_SCAN_TYPE      │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Wait for                 │
│ GSDIS_RET_SCAN_TYPE      │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Write scan index to      │
│ GSDIS_REQ_SCAN_DATE      │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Wait for                 │
│ GSDIS_RET_SCAN_DATE      │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Write scan index to      │
│ GSDIS_REQ_PKT_FMT_VER    │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Wait for                 │
│ GSDIS_RET_PKT_FMT_VER    │
└──────────────────────────┘
```

### Serialized Scan Data Alma

```
┌──────────────────────────┐
│ Write scan index to      │
│ GSDIS_REQ_SER_SCAN_DATA  │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Receive first packet     │
│ data[0] = 0x00           │
│ data[1-2] = total size   │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Receive data packets     │
│ data[0] = packet index   │
│ data[1-19] = data bytes  │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ Repeat until             │
│ all bytes received       │
└───────────┬──────────────┘
            │
            ▼
┌──────────────────────────┐
│ dlpspec_scan_interpret() │
│ Parse serialized data    │
└──────────────────────────┘
```

### Dart Multi-Packet Handler

```dart
class MultiPacketReceiver {
  int _expectedSize = 0;
  final List<int> _buffer = [];
  final Completer<List<int>> _completer = Completer();

  Future<List<int>> get data => _completer.future;

  void onPacketReceived(List<int> packet) {
    if (packet.isEmpty) return;

    if (packet[0] == 0x00) {
      // Header packet
      _expectedSize = (packet[2] << 8) | (packet[1] & 0xFF);
      _buffer.clear();
    } else {
      // Data packet
      for (int i = 1; i < packet.length && _buffer.length < _expectedSize; i++) {
        _buffer.add(packet[i]);
      }
    }

    if (_buffer.length >= _expectedSize && !_completer.isCompleted) {
      _completer.complete(List.from(_buffer));
    }
  }

  bool get isComplete => _buffer.length >= _expectedSize;
  double get progress => _expectedSize > 0 ? _buffer.length / _expectedSize : 0;
}
```

---

## 6. Firmware Tarama Süreci (Tiva Tarafı)

Tiva firmware tarama sırasında şu adımları izler:

1. **Başlangıç (100ms)**
   - DLP Subsystem güç ver (PROJ_ON high)
   - Lambaları aç (OPA567 enable)
   - Timer başlat

2. **Bekleme (625ms)**
   - Lamba stabilizasyonu için bekle
   - HDC1000'den nem/sıcaklık oku

3. **Quick Scan**
   - PGA gain ayarı için hızlı tarama
   - ADC satürasyonu olmayan maksimum gain bul

4. **Ana Tarama**
   - Tiva LCD interface üzerinden pattern'leri DLPC150'ye stream et
   - Her pattern için ADC değerlerini oku
   - Tekrar sayısı kadar tekrarla

5. **Sonlandırma**
   - TMP006 ve HDC1000'den son okumalar
   - Lambaları kapat
   - DLP Subsystem güç kes
   - Scan data struct'ı doldur

### Tarama Süresi Hesaplama

```
Total Time = Lamp Warmup (725ms)
           + Quick Scan Time
           + Main Scan Time
           + Overhead (100ms)

Quick Scan Time ∝ Digital Resolution × Exposure Time

Main Scan Time = Digital Resolution × Exposure Time × Scans to Average
```

**Not:** "Keep Lamp ON" özelliği aktifken lamp warmup süresi atlanır.

---

## 7. Kayıtlı Taramaları Listeleme

```dart
Future<List<ScanInfo>> getStoredScans() async {
  // 1. SD karttaki tarama sayısını oku
  final countData = await readCharacteristic(GSDIS_NUM_SD_STORED_SCANS);
  final count = ByteData.sublistView(Uint8List.fromList(countData))
      .getUint32(0, Endian.little);

  if (count == 0) return [];

  // 2. Tarama index listesini iste
  await writeCharacteristic(GSDIS_SD_STORED_SCAN_IND_LIST, []);

  // 3. Index listesini al (multi-packet)
  final indices = await receiveMultiPacketData(GSDIS_SD_STORED_SCAN_IND_LIST_DATA);

  // 4. Her index için metadata al
  final scans = <ScanInfo>[];
  for (int i = 0; i < indices.length; i += 4) {
    final index = ScanIndex.fromBytes(indices.sublist(i, i + 4));
    final info = await getScanMetadata(index);
    scans.add(info);
  }

  return scans;
}
```

---

## 8. Tarama Silme

```dart
Future<void> deleteScan(ScanIndex index) async {
  // 1. Silme komutu gönder
  await writeCharacteristic(GSDIS_CLEAR_SCAN, index.toBytes());

  // 2. Onay bekle
  final result = await waitForNotification(GSDIS_CLEAR_SCAN);

  if (result[0] != 0x00) {
    throw DeleteException('Failed to delete scan: ${result[0]}');
  }
}
```

---

## Hata Durumları

| Durum | Açıklama | Çözüm |
|-------|----------|-------|
| Timeout | Tarama yanıtı gelmedi | Timeout süresini artır, cihazı kontrol et |
| 0xFF dışı notify | Tarama başarısız | Hata kodunu kontrol et, yeniden dene |
| Multi-packet eksik | Veri transfer hatası | Bağlantıyı kontrol et, yeniden iste |
| Kalibrasyon yok | İlk bağlantı tamamlanmadı | Kalibrasyon akışını tekrarla |

### Tarama Timeout Değerleri

```dart
// Tarama süresini önceden hesapla
final estimatedTime = await readScanTime(); // ms
final timeout = Duration(milliseconds: estimatedTime + 5000); // +5s buffer
```
