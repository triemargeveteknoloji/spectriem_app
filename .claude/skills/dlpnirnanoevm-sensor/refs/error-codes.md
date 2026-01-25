# Hata Kodları ve Troubleshooting

> Kaynak: DLPU030G User's Guide, Appendix K, NNOStatusDefs.h

## LED İndikatörleri

### Yeşil LED (Güç)
| Durum | Açıklama |
|-------|----------|
| Saniyede 1 yanıp sönme | Sistem aktif ve normal |
| Saniyede 2 yanıp sönme | Hata durumu |
| Kapalı | Hibernation modu veya güç yok |

### Mavi LED (Bluetooth)
| Durum | Açıklama |
|-------|----------|
| Sürekli açık | Bluetooth reklam veriyor (advertising) |
| Saniyede 1 yanıp sönme | BLE bağlantısı kuruldu |
| Saniyede 2 yanıp sönme | Bluetooth hatası |
| Kapalı | Bluetooth kapalı |

### Sarı LED (Tarama)
| Durum | Açıklama |
|-------|----------|
| Sürekli açık | Tarama devam ediyor |
| Saniyede 2 yanıp sönme | Tarama hatası |

### Kırmızı LED (Şarj)
| Durum | Açıklama |
|-------|----------|
| Sürekli açık | Batarya şarj oluyor |
| 256μs yanıp sönme | Battery Manager hatası |

---

## Error Status Flags

`NNO_CMD_READ_ERROR_STATUS` komutu ile okunan hata bayrakları:

### Flag Bitleri

| Bit | Maske | Hata Türü | Açıklama |
|-----|-------|-----------|----------|
| 0 | 0x001 | Scan Error | Tarama hatası |
| 1 | 0x002 | ADC Error | ADC veri okuma hatası |
| 2 | 0x004 | SD Card Error | SD kart okuma/yazma hatası |
| 3 | 0x008 | EEPROM Error | EEPROM erişim hatası |
| 4 | 0x010 | Bluetooth Error | BLE iletişim hatası |
| 5 | 0x020 | Spectrum Library Error | Spektrum hesaplama hatası |
| 6 | 0x040 | Hardware Error | Donanım hatası |
| 7 | 0x080 | TMP006 Error | Sıcaklık sensörü hatası |
| 8 | 0x100 | HDC1000 Error | Nem sensörü hatası |
| 9 | 0x200 | Battery Discharged | Batarya boş |
| 10 | 0x400 | Memory Error | SDRAM hatası |
| 11 | 0x800 | UART Error | UART iletişim hatası |

---

## Yaygın Hata Durumları ve Çözümleri

### 1. Scan Error (0x01)

**Olası Nedenler:**
- Lambalar yanmıyor
- DLP subsystem başlatılamadı
- ADC satürasyonu
- Invalid scan configuration

**Çözümler:**
1. Cihazı resetle
2. Güç kaynağını kontrol et (USB hub yerine doğrudan bağla)
3. Aktif scan configuration'ı kontrol et
4. Firmware'i güncelle

```dart
if (errorStatus.hasScanError) {
  // 1. Önce cihaz durumunu kontrol et
  final status = await getDeviceStatus();

  if (!status.tivaActive) {
    // Cihazı yeniden başlat
    await resetDevice();
  }

  // 2. Hata detayını oku
  final scanErrorCode = errorStatus.scanError;
  // ... handle specific error code
}
```

### 2. Battery Low / Discharged (0x02, 0x200)

**Belirtiler:**
- Tarama başarısız
- Cihaz kapanıyor
- Düşük batarya uyarısı

**Çözümler:**
1. USB ile şarj et
2. USB power adapter kullan (min 1A)
3. Batarya termistör bağlantısını kontrol et

```dart
Future<void> checkBattery() async {
  final level = await getBatteryLevel();

  if (level < 20) {
    throw LowBatteryException('Battery level: $level%');
  }
}
```

### 3. Temperature Out of Range (0x04)

**Belirtiler:**
- Tarama tutarsız sonuçlar
- Kalibrasyon hataları

**Çözümler:**
1. Cihazı 0-50°C aralığında kullan
2. Doğrudan güneş ışığından kaçın
3. Cihazın soğumasını/ısınmasını bekle

```dart
Future<void> checkTemperature() async {
  final temp = await readTemperature();

  if (temp < 0 || temp > 50) {
    throw TemperatureOutOfRangeException(
      'Temperature $temp°C is out of operating range (0-50°C)',
    );
  }
}
```

### 4. Calibration Needed (0x08)

**Belirtiler:**
- Absorbance değerleri tutarsız
- Referans verileri eksik/bozuk

**Çözümler:**
1. Factory kalibrasyon verilerini kontrol et
2. Reference kalibrasyon yenile
3. Cihazı factory reset yap

### 5. SD Card Error (0x04)

**Belirtiler:**
- Tarama kaydedilmiyor
- Kayıtlı taramalar okunamıyor

**Çözümler:**
1. SD kartı çıkarıp takın
2. SD kartı formatla (FAT32)
3. Farklı SD kart dene
4. SD kart kapasitesini kontrol et

### 6. Bluetooth Error (0x10)

**Belirtiler:**
- Bağlantı kurulamıyor
- Bağlantı düşüyor
- Veri transfer hatası

**Çözümler:**
1. Bluetooth'u kapatıp açın (cihaz ve telefon)
2. Diğer BLE cihazlardan uzaklaş
3. Cihazı resetle
4. Telefon Bluetooth cache temizle

```dart
// Android Bluetooth cache temizleme gerekebilir
// Settings > Apps > Bluetooth > Clear Cache
```

### 7. Memory Error (0x400)

**Belirtiler:**
- Pattern oluşturulamıyor
- Tarama başlatılamıyor

**Çözümler:**
1. Cihazı resetle
2. Firmware'i güncelle
3. SDRAM testi çalıştır

---

## BLE Bağlantı Sorunları

### Cihaz Bulunamıyor

**Kontrol Listesi:**
1. Bluetooth 4.0 LE destekli telefon mu?
2. Konum izni verildi mi? (Android)
3. Bluetooth açık mı?
4. Cihaz advertising yapıyor mu? (Mavi LED)
5. Scan timeout yeterli mi? (min 6 saniye)

```dart
// Android için gerekli izinler
// AndroidManifest.xml:
// BLUETOOTH, BLUETOOTH_ADMIN, BLUETOOTH_SCAN,
// BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION
```

### Bağlantı Düşüyor

**Olası Nedenler:**
- MTU mismatch
- Çok uzak mesafe
- RF interference
- Timeout

**Çözümler:**
```dart
// 1. Connection parameters optimize et
// 2. Auto-reconnect implementasyonu ekle
// 3. Keep-alive mechanism kullan

class BleConnectionManager {
  Timer? _keepAliveTimer;

  void startKeepAlive() {
    _keepAliveTimer = Timer.periodic(
      Duration(seconds: 30),
      (_) => _sendKeepAlive(),
    );
  }

  Future<void> _sendKeepAlive() async {
    try {
      await readBatteryLevel(); // Simple read operation
    } catch (e) {
      // Reconnect if disconnected
      await reconnect();
    }
  }
}
```

### Service Discovery Başarısız

**Çözümler:**
1. Bağlantıdan sonra 1 saniye bekle
2. discoverServices() timeout'u artır
3. Cihazı yeniden başlat

```dart
await device.connect(autoConnect: false);
await Future.delayed(Duration(seconds: 1));
await device.discoverServices();
```

### Notification Alınamıyor

**Çözümler:**
1. CCCD'ye write yapıldığından emin ol
2. Subscription sırasını kontrol et
3. Her subscription arasında delay ekle

```dart
for (final char in characteristicsToSubscribe) {
  await char.setNotifyValue(true);
  await Future.delayed(Duration(milliseconds: 100));
}
```

---

## Tarama Sorunları

### Intensity Variability (Değişken Yoğunluk)

**Olası Nedenler:**
- Lamba bağlantı problemi
- Lamba yaşlanması
- Numune pozisyonu tutarsız

**Çözümler:**
1. Lamba konektörünü kontrol et
2. Birkaç deneme taraması yap (ısınma)
3. Keep Lamp ON özelliğini kullan
4. Numune pencereye tam temas etsin

### Scan Timeout

**Çözümler:**
1. Tarama süresini önceden hesapla
2. Timeout değerini artır
3. Daha basit scan configuration dene

```dart
Future<ScanData> performScanWithRetry({int maxRetries = 3}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      // Tarama süresini al
      final estimatedMs = await readScanTime();
      final timeout = Duration(milliseconds: estimatedMs + 10000);

      return await performScan().timeout(timeout);
    } on TimeoutException {
      if (i == maxRetries - 1) rethrow;
      await resetDevice();
    }
  }
  throw ScanException('Max retries exceeded');
}
```

### Invalid Scan Configuration

**Belirtiler:**
- Pattern sayısı 624'ü aşıyor
- Wavelength aralığı geçersiz

**Kontroller:**
```dart
void validateScanConfig(ScanConfiguration config) {
  // Wavelength range check
  if (config.startWavelength < 900 || config.endWavelength > 1700) {
    throw InvalidConfigException('Wavelength out of range (900-1700nm)');
  }

  // Pattern count check
  int totalPatterns = 0;
  for (final section in config.sections) {
    totalPatterns += section.digitalResolution;
  }
  if (totalPatterns > 624) {
    throw InvalidConfigException('Pattern count exceeds 624');
  }
}
```

---

## Güç Sorunları

### Cihaz Açılmıyor

**Kontrol Listesi:**
1. USB kablosu çalışıyor mu?
2. USB portu yeterli güç veriyor mu? (500mA+)
3. Batarya bağlı ve şarjlı mı?
4. Reset butonuna bas

### Yetersiz Güç

**Belirtiler:**
- Tarama sırasında kapanma
- Lamba yanıp sönüyor
- Reset loop

**Çözümler:**
1. Powered USB hub kullan
2. USB 3.0 port kullan
3. 1A+ USB adapter kullan
4. Kısa, kaliteli USB kablosu kullan

---

## Firmware Sorunları

### Version Mismatch

**Çözüm:**
GUI, Tiva firmware ve DLPC150 firmware'i uyumlu versiyonlara güncelle.

```
Uyumlu versiyon setleri:
- GUI 2.1 + Tiva 2.1 + DLPC150 2.0
```

### System Not Responding

**Çözümler:**
1. Scan butonunu basılı tutarak reset (bootloader modu)
2. SKIP_CFG dosyası ile boot
3. Firmware güncelle

```
SD Kart ile recovery:
1. SD kartta [SERIAL_NUMBER]/SKIP_CFG dosyası oluştur
2. Cihazı bu SD kart ile başlat
3. Invalid configuration atlanır
```

---

## Hata Kodu Detayları

### Scan Error Codes
| Kod | Açıklama |
|-----|----------|
| 0x01 | Lamp power failure |
| 0x02 | ADC overflow/saturation |
| 0x03 | Pattern stream error |
| 0x04 | DLP subsystem failure |

### ADC Error Codes
| Kod | Açıklama |
|-----|----------|
| 0x01 | Communication timeout |
| 0x02 | Data overflow |
| 0x03 | Calibration mismatch |

### Bluetooth Error Codes
| Kod | Açıklama |
|-----|----------|
| 0x0001 | Stack initialization failed |
| 0x0002 | Advertising failed |
| 0x0003 | Connection lost |
| 0x0004 | GATT operation failed |

---

## Dart Exception Hierarchy

```dart
/// Base exception for all NIRscan Nano errors
class NanoException implements Exception {
  final String message;
  final int? errorCode;

  NanoException(this.message, [this.errorCode]);

  @override
  String toString() => 'NanoException: $message (code: $errorCode)';
}

class ConnectionException extends NanoException {
  ConnectionException(String message) : super(message);
}

class ScanException extends NanoException {
  ScanException(String message, [int? code]) : super(message, code);
}

class CalibrationException extends NanoException {
  CalibrationException(String message) : super(message);
}

class LowBatteryException extends NanoException {
  LowBatteryException(String message) : super(message);
}

class TemperatureOutOfRangeException extends NanoException {
  TemperatureOutOfRangeException(String message) : super(message);
}

class InvalidConfigException extends NanoException {
  InvalidConfigException(String message) : super(message);
}
```

---

## Diagnostic Checklist

Sorun giderme için sistematik kontrol listesi:

```dart
Future<DiagnosticReport> runDiagnostics() async {
  final report = DiagnosticReport();

  // 1. Connection check
  report.connectionOk = await checkConnection();

  // 2. Battery check
  report.batteryLevel = await getBatteryLevel();
  report.batteryOk = report.batteryLevel > 20;

  // 3. Temperature check
  report.temperature = await readTemperature();
  report.temperatureOk = report.temperature >= 0 && report.temperature <= 50;

  // 4. Error status check
  report.errorStatus = await readErrorStatus();
  report.noErrors = !report.errorStatus.hasAnyError;

  // 5. SD card check
  report.sdCardPresent = (await getDeviceStatus()).sdCardPresent;

  // 6. Calibration check
  report.calibrationOk = await verifyCalibration();

  return report;
}
```
