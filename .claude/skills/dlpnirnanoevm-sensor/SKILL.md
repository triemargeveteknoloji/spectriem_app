# DLPNIRNANOEVM NIR Sensor Skill

Texas Instruments DLP NIRscan Nano EVM sensörü ile Bluetooth Low Energy üzerinden iletişim kurma rehberi.

## Sensör Genel Bilgileri

### Donanım Özellikleri
- **Model:** DLPNIRNANOEVM (DLP NIRscan Nano EVM)
- **DMD:** DLP2010NIR Digital Micromirror Device
- **MCU:** Tiva TM4C1297NCZAD (TI RTOS, Bluetopia stack)
- **BLE Modülü:** CC2564MODN (Bluetooth 4.0 LE)
- **Dalga Boyu:** 900-1700nm (Near-Infrared)
- **Çözünürlük:** 10nm tipik
- **Batarya:** Dahili Li-ion, şarj edilebilir
- **Boyut:** Kompakt, el tipi form faktörü

### Bağlantı Arayüzleri
1. **Bluetooth Low Energy 4.0** - Birincil kablosuz arayüz
2. **USB** - Alternatif bağlantı ve şarj

## Bluetooth Low Energy (BLE) Protokolü

### Bağlantı Özellikleri
- **Bluetooth Sürümü:** 4.0 Low Energy
- **Profil:** GATT (Generic Attribute Profile)
- **Eşleştirme:** PIN gerektirmez (GAP kullanır)
- **MTU:** 20 byte (büyük veriler multi-packet)
- **Scan Period:** ~6 saniye önerilen

### Cihaz Keşfi
```dart
// Cihaz adı pattern'i
const String NANO_NAME_PREFIX = "NIRScan";
const String NANO_NAME_PATTERN = r"NIRScan.*Nano.*";

// Scan filter
scanFilter: ScanFilter(
  name: "NIRScan",
  // veya service UUID ile filtreleme
)
```

### Bağlantı Akışı
```
1. BLE Scan başlat
2. "NIRScan" prefix'li cihaz bul
3. connectGatt() ile bağlan (autoConnect: false, transport: LE)
4. onConnectionStateChange -> STATE_CONNECTED
5. discoverServices() çağır
6. onServicesDiscovered -> GATT_SUCCESS
7. Notification subscription'ları ayarla (sıralı)
8. Cihaz kullanıma hazır
```

## GATT Servisleri ve Karakteristikleri

### 1. Device Information Service (DIS)
Standard Bluetooth SIG servisi.

| Karakteristik | Açıklama | Yön |
|---------------|----------|-----|
| `DIS_MANUF_NAME` | Üretici adı | Read |
| `DIS_MODEL_NUMBER` | Model numarası | Read |
| `DIS_SERIAL_NUMBER` | Seri numarası | Read |
| `DIS_HW_REV` | Hardware revision | Read |
| `DIS_TIVA_FW_REV` | Tiva firmware sürümü | Read |
| `DIS_SPECC_REV` | Spectrum C Library sürümü | Read |

### 2. Battery Service (BAS)
| Karakteristik | Açıklama | Yön | Format |
|---------------|----------|-----|--------|
| `BAS_BATT_LVL` | Batarya seviyesi (0-100) | Read | uint8 |

### 3. General Information Service (GGIS)
| Karakteristik | Açıklama | Yön | Format |
|---------------|----------|-----|--------|
| `GGIS_TEMP_MEASUREMENT` | Sıcaklık (°C) | Read | int16 LE / 100 |
| `GGIS_HUMID_MEASUREMENT` | Nem (%) | Read | int16 LE / 100 |
| `GGIS_DEV_STATUS` | Cihaz durumu | Read | hex string |
| `GGIS_ERR_STATUS` | Hata durumu | Read | hex string |
| `GGIS_TEMP_THRESH` | Sıcaklık eşiği | Write | bytes |
| `GGIS_HUMID_THRESH` | Nem eşiği | Write | bytes |
| `GGIS_HOURS_OF_USE` | Kullanım saati | Read | - |
| `GGIS_NUM_BATT_RECHARGE` | Şarj sayısı | Read | - |
| `GGIS_LAMP_HOURS` | Lamba saati | Read | - |
| `GGIS_ERR_LOG` | Hata logu | Read | - |

### 4. Date/Time Service (GDTS)
| Karakteristik | Açıklama | Yön |
|---------------|----------|-----|
| `GDTS_TIME` | Cihaz saati ayarla | Write |

### 5. Calibration Information Service (GCIS)
| Karakteristik | Açıklama | Yön |
|---------------|----------|-----|
| `GCIS_REQ_SPEC_CAL_COEFF` | Spectrum kalibrasyon katsayıları iste | Write |
| `GCIS_RET_SPEC_CAL_COEFF` | Spectrum kalibrasyon katsayıları dön | Notify |
| `GCIS_REQ_REF_CAL_COEFF` | Referans kalibrasyon katsayıları iste | Write |
| `GCIS_RET_REF_CAL_COEFF` | Referans kalibrasyon katsayıları dön | Notify |
| `GCIS_REQ_REF_CAL_MATRIX` | Referans kalibrasyon matrisi iste | Write |
| `GCIS_RET_REF_CAL_MATRIX` | Referans kalibrasyon matrisi dön | Notify |

### 6. Scan Configuration Service (GSCIS)
| Karakteristik | Açıklama | Yön |
|---------------|----------|-----|
| `GSCIS_NUM_STORED_CONF` | Kayıtlı konfigürasyon sayısı | Read |
| `GSCIS_REQ_STORED_CONF_LIST` | Konfigürasyon listesi iste | Write |
| `GSCIS_RET_STORED_CONF_LIST` | Konfigürasyon listesi dön | Notify |
| `GSCIS_REQ_SCAN_CONF_DATA` | Konfigürasyon verisi iste | Write |
| `GSCIS_RET_SCAN_CONF_DATA` | Konfigürasyon verisi dön | Notify |
| `GSCIS_ACTIVE_SCAN_CONF` | Aktif konfigürasyon | Read/Write |

### 7. Scan Data Information Service (GSDIS)
| Karakteristik | Açıklama | Yön |
|---------------|----------|-----|
| `GSDIS_START_SCAN` | Tarama başlat | Write/Notify |
| `GSDIS_CLEAR_SCAN` | Tarama sil | Write/Notify |
| `GSDIS_SET_SCAN_NAME_STUB` | Tarama adı prefix'i | Write |
| `GSDIS_NUM_SD_STORED_SCANS` | SD'de kayıtlı tarama sayısı | Read |
| `GSDIS_SD_STORED_SCAN_IND_LIST` | Kayıtlı tarama indexleri iste | Write |
| `GSDIS_SD_STORED_SCAN_IND_LIST_DATA` | Kayıtlı tarama indexleri dön | Notify |
| `GSDIS_REQ_SCAN_NAME` | Tarama adı iste | Write |
| `GSDIS_RET_SCAN_NAME` | Tarama adı dön | Notify |
| `GSDIS_REQ_SCAN_TYPE` | Tarama tipi iste | Write |
| `GSDIS_RET_SCAN_TYPE` | Tarama tipi dön | Notify |
| `GSDIS_REQ_SCAN_DATE` | Tarama tarihi iste | Write |
| `GSDIS_RET_SCAN_DATE` | Tarama tarihi dön | Notify |
| `GSDIS_REQ_PKT_FMT_VER` | Paket format versiyonu iste | Write |
| `GSDIS_RET_PKT_FMT_VER` | Paket format versiyonu dön | Notify |
| `GSDIS_REQ_SER_SCAN_DATA_STRUCT` | Serileştirilmiş tarama verisi iste | Write |
| `GSDIS_RET_SER_SCAN_DATA_STRUCT` | Serileştirilmiş tarama verisi dön | Notify |

## Komut ve Veri Akışları

### Notification Subscription Sırası
Bağlantı sonrası descriptor'lar bu sırayla yazılmalı:
```
1. GCIS_RET_REF_CAL_COEFF
2. GCIS_RET_REF_CAL_MATRIX
3. GSDIS_START_SCAN
4. GSDIS_RET_SCAN_NAME
5. GSDIS_RET_SCAN_TYPE
6. GSDIS_RET_SCAN_DATE
7. GSDIS_RET_PKT_FMT_VER
8. GSDIS_RET_SER_SCAN_DATA_STRUCT
9. GSCIS_RET_STORED_CONF_LIST
10. GSDIS_SD_STORED_SCAN_IND_LIST_DATA
11. GSDIS_CLEAR_SCAN
12. GSCIS_RET_SCAN_CONF_DATA
→ ACTION_NOTIFY_DONE broadcast
```

### CCCD UUID
```dart
const String CCCD_UUID = "00002902-0000-1000-8000-00805f9b34fb";
```

### Cihaz Bilgisi Alma
```
1. getManufacturerName() → DIS_MANUF_NAME read
2. (callback) → getModelNumber()
3. (callback) → getSerialNumber()
4. (callback) → getHardwareRev()
5. (callback) → getFirmwareRev()
6. (callback) → getSpectrumCRev()
7. (callback) → ACTION_INFO broadcast
```

### Cihaz Durumu Alma
```
1. getBatteryLevel() → BAS_BATT_LVL read
2. (callback) → getTemp() → GGIS_TEMP_MEASUREMENT
3. (callback) → getHumidity() → GGIS_HUMID_MEASUREMENT
4. (callback) → getDeviceStatus() → GGIS_DEV_STATUS
5. (callback) → getErrorStatus() → GGIS_ERR_STATUS
6. (callback) → ACTION_STATUS broadcast
```

### Tarama Başlatma
```
1. setTime() → GDTS_TIME write
2. (callback) → setStub(prefix) → GSDIS_SET_SCAN_NAME_STUB
3. (callback) → requestRefCalCoefficients() (ilk bağlantıda)
   VEYA startScan(saveToSD) → GSDIS_START_SCAN write
4. Tarama tamamlandığında → GSDIS_START_SCAN notify (data[0] == 0xFF)
5. Scan index alınır → requestScanName(index)
6. → requestScanType(index)
7. → requestScanDate(index)
8. → requestPacketFormatVersion(index)
9. → requestSerializedScanDataStruct(index)
10. Multi-packet veri alımı → SCAN_DATA broadcast
```

### Multi-Packet Veri Alımı
```dart
// İlk paket (data[0] == 0x00): boyut bilgisi
if (data[0] == 0x00) {
  size = (data[2] << 8) | (data[1] & 0xFF);
  buffer.reset();
}
// Sonraki paketler: veri
else {
  for (int i = 1; i < data.length; i++) {
    buffer.write(data[i]);
  }
}
// Tamamlanma kontrolü
if (buffer.size == size) {
  // İşlem tamamlandı
}
```

### Tarama Başlatma Komutu
```dart
// saveToSD: true -> 0x01, false -> 0x00
void startScan(bool saveToSD) {
  final data = [saveToSD ? 0x01 : 0x00];
  writeCharacteristic(GSDIS_START_SCAN, data);
}
```

## Veri Formatları

### Sıcaklık/Nem
```dart
// Little-endian 16-bit signed, /100 ile °C veya %
double parseTemp(List<int> data) {
  int raw = (data[1] << 8) | (data[0] & 0xFF);
  return raw / 100.0;
}
```

### Tarama Index
```dart
// 4 byte array
class ScanIndex {
  final int b0, b1, b2, b3;

  List<int> toBytes() => [b0, b1, b2, b3];
}
```

### Tarih Formatı
```dart
// Her byte bir rakam (00-99 arası)
String parseDate(List<int> data) {
  return data.map((b) => b.toString().padLeft(2, '0')).join();
}
```

## Test ve Mock Stratejisi

### Mock BLE Service
Sensör olmadan test için mock servis:

```dart
abstract class NirScanService {
  Stream<ConnectionState> get connectionState;
  Stream<ScanResult> get scanResults;

  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connect(String deviceId);
  Future<void> disconnect();

  Future<DeviceInfo> getDeviceInfo();
  Future<DeviceStatus> getDeviceStatus();
  Future<ScanData> performScan({bool saveToSd = false});
  Future<List<ScanConfiguration>> getScanConfigurations();
}

class MockNirScanService implements NirScanService {
  // Simüle edilmiş cihaz davranışları
  // Configurable delay'ler
  // Örnek spektral veri
}

class RealNirScanService implements NirScanService {
  // Gerçek BLE implementasyonu
}
```

### Test Data Generator
```dart
class MockSpectrumGenerator {
  // Farklı madde tipleri için örnek spektrum
  static List<double> generateWaterSpectrum();
  static List<double> generatePlasticSpectrum();
  static List<double> generateOrganicSpectrum();

  // Noise ekleme
  static List<double> addNoise(List<double> spectrum, double level);
}
```

## Hata Durumları

### Yaygın Hatalar
| Kod | Açıklama | Çözüm |
|-----|----------|-------|
| 0x01 | Lamp error | Cihazı yeniden başlat |
| 0x02 | Battery low | Şarj et |
| 0x04 | Temperature out of range | Ortam sıcaklığını kontrol et |
| 0x08 | Calibration needed | Kalibrasyon yap |

### BLE Bağlantı Hataları
- `STATE_DISCONNECTED`: Cihaz bağlantısı kesildi
- `GATT_FAILURE`: GATT işlemi başarısız
- `SERVICE_NOT_FOUND`: Servis bulunamadı

## Kaynaklar

### Resmi Dokümantasyon
- [TI DLPNIRNANOEVM Product Page](https://www.ti.com/tool/DLPNIRNANOEVM)
- [DLP NIRscan Nano EVM User's Guide (DLPU030G)](https://www.ti.com/lit/ug/dlpu030g/dlpu030g.pdf)

### SDK ve Örnek Kodlar
- [Android SDK - GitHub](https://github.com/kstechnologies/NIRScanNano_Android)
- [iOS SDK - GitHub](https://github.com/kstechnologies/NIRScanNano_iOS)

### Not
DLP Spectrum Library kaynak kodu için Texas Instruments ile NDA gereklidir.

## Flutter Implementasyon Notları

### Önerilen Paketler
```yaml
dependencies:
  flutter_blue_plus: ^1.31.0  # BLE iletişimi

dev_dependencies:
  mockito: ^5.4.0  # Mock testing
  build_runner: ^2.4.0
```

### Platform Konfigürasyonu

#### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

#### iOS (ios/Runner/Info.plist)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>NIR sensör ile iletişim için Bluetooth gereklidir</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>NIR sensör ile iletişim için Bluetooth gereklidir</string>
```

### Mimari Önerisi
```
lib/
├── services/
│   └── ble/
│       ├── nir_scan_service.dart      # Abstract interface
│       ├── real_nir_scan_service.dart # BLE implementation
│       ├── mock_nir_scan_service.dart # Mock for testing
│       └── nano_gatt.dart             # UUID constants
├── models/
│   ├── device_info.dart
│   ├── device_status.dart
│   ├── scan_data.dart
│   └── scan_configuration.dart
└── providers/
    └── sensor_provider.dart           # State management
```
